import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class RecordingService {
  RecordingService({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();
  final AudioRecorder _recorder;
  final _uuid = const Uuid();

  Future<bool> requestPermission() => _recorder.hasPermission();

  Future<String> start() async {
    if (!await requestPermission()) throw StateError('Mikrofon rugsady berilmedi');
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'recordings'));
    await directory.create(recursive: true);
    final id = _uuid.v4();
    final path = p.join(directory.path, '$id.wav');
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: path);
    return id;
  }

  Future<String?> stop() => _recorder.stop();
  Future<void> cancel() => _recorder.cancel();
  Future<void> dispose() => _recorder.dispose();
}
