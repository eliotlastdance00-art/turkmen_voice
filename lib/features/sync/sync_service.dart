import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:turkmen_ses/core/network/api_contract.dart';
import 'package:turkmen_ses/core/network/api_exception.dart';
import 'package:turkmen_ses/core/storage/app_database.dart';
import 'package:turkmen_ses/core/storage/app_preferences.dart';
import 'package:turkmen_ses/features/session/session.dart';

@immutable
class SyncProgress {
  const SyncProgress({
    this.running = false,
    this.total = 0,
    this.done = 0,
    this.uploaded = 0,
    this.failed = 0,
    this.ratings = 0,
    this.lastMessage,
    this.lastError,
  });

  final bool running;
  final int total;
  final int done;
  final int uploaded;
  final int failed;
  final int ratings;
  final String? lastMessage;
  final String? lastError;

  double get fraction => total == 0 ? 0 : done / total;

  SyncProgress copyWith({
    bool? running,
    int? total,
    int? done,
    int? uploaded,
    int? failed,
    int? ratings,
    String? lastMessage,
    String? lastError,
  }) {
    return SyncProgress(
      running: running ?? this.running,
      total: total ?? this.total,
      done: done ?? this.done,
      uploaded: uploaded ?? this.uploaded,
      failed: failed ?? this.failed,
      ratings: ratings ?? this.ratings,
      lastMessage: lastMessage ?? this.lastMessage,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Uploads the offline queue and flushes ratings the user gave offline.
class SyncService {
  SyncService({required this.database, required this.api, required this.preferences});

  final AppDatabase database;
  final ApiClientLike api;
  final AppPreferences preferences;

  Future<SyncProgress> flush({
    void Function(SyncProgress progress)? onProgress,
  }) async {
    var progress = SyncProgress(running: true, lastMessage: 'Nobat barlanýar...');
    onProgress?.call(progress);

    if (!await _hasConnection()) {
      progress = progress.copyWith(
        running: false,
        lastError: 'Internet baglanyşygy ýok.',
        lastMessage: 'Nobat saklandy.',
      );
      onProgress?.call(progress);
      return progress;
    }

    final pending = await database.pendingRecordings();
    progress = progress.copyWith(total: pending.length);
    onProgress?.call(progress);

    for (final item in pending) {
      try {
        await database.updateStatus(item.id, 'uploading');
        await api.uploadRecording(
          filePath: item.audioPath,
          metadata: <String, dynamic>{
            'recording_id': item.id,
            'sentence_id': item.sentenceId,
            'text': item.textValue,
            'language': 'tk',
            'consent_type': item.consentType,
            'duration_ms': item.durationMs,
            'category': item.category,
            'package_id': item.packageId,
            'sample_rate': 16000,
            'channels': 1,
            'bit_depth': 16,
          },
        );
        await database.markUploaded(item.id);
        progress = progress.copyWith(done: progress.done + 1, uploaded: progress.uploaded + 1);
      } catch (error) {
        await database.bumpSyncAttempt(item.id);
        await database.updateStatus(item.id, 'failed', error: error.toString());
        progress = progress.copyWith(done: progress.done + 1, failed: progress.failed + 1);
      }
      onProgress?.call(progress);
    }

    // offline ratings -----------------------------------------------------
    final queuedRatings = await database.pendingRatings();
    var syncedRatings = 0;
    for (final rating in queuedRatings) {
      try {
        await api.submitRating(
          recordingId: rating.recordingId,
          score: rating.score,
          matchesText: rating.matchesText,
          comment: rating.comment,
        );
        await database.markRatingSynced(rating.id);
        syncedRatings++;
      } on ApiException catch (error) {
        if (error.statusCode == 409 || error.statusCode == 422) {
          // already rated on another device / own take — drop it
          await database.deleteRating(rating.id);
          continue;
        }
        break;
      }
    }

    progress = progress.copyWith(
      running: false,
      ratings: syncedRatings,
      lastMessage: '${progress.uploaded} ýazgy, $syncedRatings baha iberildi.',
      lastError: progress.failed > 0 ? '${progress.failed} ýazgy şowsuz boldy.' : null,
    );
    onProgress?.call(progress);
    return progress;
  }

  Future<bool> _hasConnection() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      return false;
    }
    if (preferences.wifiOnly) {
      return results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet);
    }
    return true;
  }
}

class SyncController extends Notifier<SyncProgress> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  SyncProgress build() {
    final preferences = ref.watch(preferencesProvider);
    if (preferences.autoSync) {
      _listen();
    }
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return const SyncProgress();
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        unawaited(run());
      }
    });
  }

  Future<SyncProgress> run() async {
    if (state.running) {
      return state;
    }
    final service = SyncService(
      database: ref.read(databaseProvider),
      api: ref.read(apiClientProvider),
      preferences: ref.read(preferencesProvider),
    );
    final result = await service.flush(onProgress: (progress) => state = progress);
    if (result.uploaded > 0 || result.ratings > 0) {
      ref.invalidate(recordingsProvider);
      ref.invalidate(ratingsProvider);
      unawaited(ref.read(sessionProvider.notifier).refresh());
    }
    return result;
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncProgress>(SyncController.new);

final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none));
});

/// Stores a rating locally so it survives a crash / offline period; the
/// sync controller pushes it to the server later.
class RatingQueue {
  RatingQueue(this.database);

  final AppDatabase database;

  Future<void> queue({
    required String recordingId,
    required int score,
    required bool matchesText,
    String? comment,
    String? remoteText,
  }) async {
    await database.queueRating(
      RatingsCompanion.insert(
        id: const Uuid().v4(),
        recordingId: recordingId,
        score: score,
        createdAt: DateTime.now(),
        matchesText: Value(matchesText),
        comment: Value(comment),
        remoteText: Value(remoteText),
      ),
    );
    await database.addDailyActivity(ratings: 1);
  }
}

final ratingQueueServiceProvider = Provider<RatingQueue>((ref) => RatingQueue(ref.watch(databaseProvider)));
