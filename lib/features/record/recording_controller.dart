import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'package:turkmen_ses/core/config/app_config.dart';
import 'package:turkmen_ses/core/storage/app_database.dart';
import 'package:turkmen_ses/features/sync/sync_service.dart';

enum RecorderStage { idle, recording, review, saving }

@immutable
class RecorderState {
  const RecorderState({
    this.stage = RecorderStage.idle,
    this.elapsedMs = 0,
    this.amplitudes = const <double>[],
    this.path,
    this.recordingId,
    this.sentenceId = 'sentence_000001',
    this.text = '',
    this.category = 'general',
    this.packageId = '',
    this.localOnly = false,
    this.error,
  });

  final RecorderStage stage;
  final int elapsedMs;
  final List<double> amplitudes;
  final String? path;
  final String? recordingId;
  final String sentenceId;
  final String text;
  final String category;
  final String packageId;
  final bool localOnly;
  final String? error;

  bool get isRecording => stage == RecorderStage.recording;
  bool get canSave => path != null && stage == RecorderStage.review;
  double get seconds => elapsedMs / 1000;

  RecorderState copyWith({
    RecorderStage? stage,
    int? elapsedMs,
    List<double>? amplitudes,
    String? path,
    String? recordingId,
    String? sentenceId,
    String? text,
    String? category,
    String? packageId,
    bool? localOnly,
    String? error,
  }) {
    return RecorderState(
      stage: stage ?? this.stage,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      amplitudes: amplitudes ?? this.amplitudes,
      path: path ?? this.path,
      recordingId: recordingId ?? this.recordingId,
      sentenceId: sentenceId ?? this.sentenceId,
      text: text ?? this.text,
      category: category ?? this.category,
      packageId: packageId ?? this.packageId,
      localOnly: localOnly ?? this.localOnly,
      error: error,
    );
  }
}

/// Records with the `record` plugin using the **WAV** encoder.
///
/// The first release used `AudioEncoder.pcm16bits` while naming the file
/// `*.wav`; that produced header-less raw PCM which Whisper / ffmpeg could
/// not read.  Here we ask the plugin for a real WAV container at 16 kHz mono
/// 16 bit — exactly the training format of the backend.
class RecorderController extends Notifier<RecorderState> {
  AudioRecorder? _recorder;
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  DateTime? _startedAt;
  final List<double> _amplitudes = <double>[];

  @override
  RecorderState build() {
    ref.onDispose(() async {
      _timer?.cancel();
      await _amplitudeSubscription?.cancel();
      await _recorder?.dispose();
    });
    return const RecorderState();
  }

  AudioRecorder get _audioRecorder => _recorder ??= AudioRecorder();

  void prepare({required String sentenceId, required String text, required String category, required String packageId}) {
    state = state.copyWith(
      sentenceId: sentenceId,
      text: text,
      category: category,
      packageId: packageId,
    );
  }

  Future<void> start() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      state = state.copyWith(error: 'Mikrofon rugsady berilmedi. Sazlamalardan rugsat beriň.');
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(directory.path, 'recordings'));
    await folder.create(recursive: true);
    final id = const Uuid().v4();
    final path = p.join(folder.path, '$id.wav');

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: AppConfig.targetSampleRate,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: path,
    );

    _amplitudes
      ..clear()
      ..addAll(List<double>.filled(48, 0.04));
    _startedAt = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final started = _startedAt;
      if (started == null) {
        return;
      }
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      state = state.copyWith(elapsedMs: elapsed);
      if (elapsed >= AppConfig.maxRecordingMs) {
        unawaited(stop());
      }
    });
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amplitude) {
      final level = ((amplitude.current + 60) / 60).clamp(0.03, 1.0);
      _amplitudes.add(level);
      while (_amplitudes.length > 48) {
        _amplitudes.removeAt(0);
      }
      state = state.copyWith(amplitudes: List<double>.from(_amplitudes));
    });

    state = state.copyWith(
      stage: RecorderStage.recording,
      recordingId: id,
      path: path,
      elapsedMs: 0,
      amplitudes: List<double>.from(_amplitudes),
      error: null,
    );
  }

  Future<void> stop() async {
    if (!state.isRecording) {
      return;
    }
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    final path = await _audioRecorder.stop();
    final elapsed = state.elapsedMs;

    if (path == null || elapsed < AppConfig.minRecordingMs) {
      await _deleteFile(path);
      state = RecorderState(
        sentenceId: state.sentenceId,
        text: state.text,
        category: state.category,
        packageId: state.packageId,
        error: 'Ýazgy gysga boldy (iň az 0.5 sekunt). Täzeden synanyşyň.',
      );
      return;
    }
    state = state.copyWith(
      stage: RecorderStage.review,
      path: path,
      elapsedMs: elapsed,
      amplitudes: List<double>.from(_amplitudes),
    );
  }

  Future<void> reset() async {
    _timer?.cancel();
    await _amplitudeSubscription?.cancel();
    final current = state.path;
    await _deleteFile(current);
    state = RecorderState(
      sentenceId: state.sentenceId,
      text: state.text,
      category: state.category,
      packageId: state.packageId,
    );
  }

  /// Persists the take locally first — uploading is the sync service's job.
  Future<bool> save({
    required String consentType,
    required bool serverReachable,
    bool pushImmediately = true,
  }) async {
    final path = state.path;
    final id = state.recordingId;
    if (path == null || id == null) {
      return false;
    }
    state = state.copyWith(stage: RecorderStage.saving);

    final database = ref.read(databaseProvider);
    await database.saveRecording(
      RecordingsCompanion.insert(
        id: id,
        sentenceId: state.sentenceId,
        textValue: state.text,
        audioPath: path,
        durationMs: state.elapsedMs,
        status: const Value('pending'),
        consentType: Value(consentType),
        createdAt: DateTime.now(),
        category: Value(state.category),
        packageId: Value(state.packageId),
      ),
    );
    await database.addDailyActivity(seconds: (state.elapsedMs / 1000).round(), recordings: 1);

    if (serverReachable && pushImmediately) {
      await ref.read(syncControllerProvider.notifier).run();
    }
    state = RecorderState(
      sentenceId: state.sentenceId,
      text: state.text,
      category: state.category,
      packageId: state.packageId,
    );
    return true;
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) {
      return;
    }
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
      } on FileSystemException {
        // keep the queue consistent even if the file is locked
      }
    }
  }
}

final recorderProvider = NotifierProvider<RecorderController, RecorderState>(RecorderController.new);
