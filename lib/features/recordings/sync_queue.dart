import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/app_database.dart';

class SyncQueue {
  SyncQueue(
    this.database,
    this.api,
  );

  final AppDatabase database;
  final ApiClient api;

  Future<int> flush() async {
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity.contains(ConnectivityResult.none)) {
      return 0;
    }

    var uploaded = 0;

    final recordings = await database.pendingRecordings();

    for (final item in recordings) {
      try {
        await database.updateStatus(
          item.id,
          'uploading',
        );

        await api.uploadRecording(
          filePath: item.audioPath,
          metadata: {
            'recording_id': item.id,
            'sentence_id': item.sentenceId,
            'text': item.textValue,
            'language': 'tk',
            'consent_type': item.consentType,
            'duration_ms': item.durationMs,
          },
        );

        await database.updateStatus(
          item.id,
          'uploaded',
        );

        uploaded++;
      } catch (error) {
        await database.updateStatus(
          item.id,
          'failed',
          error: error.toString(),
        );
      }
    }

    return uploaded;
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(),
);

final syncQueueProvider = Provider<SyncQueue>(
  (ref) => SyncQueue(
    ref.watch(databaseProvider),
    ref.watch(apiClientProvider),
  ),
);}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final syncQueueProvider = Provider<SyncQueue>((ref) => SyncQueue(ref.watch(databaseProvider), ref.watch(apiClientProvider)));
