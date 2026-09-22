import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;

  ApiClient({Dio? dio, String? baseUrl}) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:8000/api/v1',
          ),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    );
  }

  Future<void> uploadRecording({
    required String filePath,
    required Map<String, dynamic> metadata,
  }) async {
    final form = FormData.fromMap({
      ...metadata,
      'audio_file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
        contentType: DioMediaType('audio', 'wav'),
      ),
    });

    await _dio.post('/recordings', data: form);
  }
}
