/// The part of the API the sync service depends on.
///
/// Declared separately so the offline queue can be tested with a fake
/// client without touching Dio.
abstract class ApiClientLike {
  Future<Map<String, dynamic>> uploadRecording({
    required String filePath,
    required Map<String, dynamic> metadata,
  });

  Future<Map<String, dynamic>> submitRating({
    required String recordingId,
    required int score,
    required bool matchesText,
    String? comment,
  });
}
