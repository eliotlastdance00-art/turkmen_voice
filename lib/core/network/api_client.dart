import 'package:dio/dio.dart';

import 'package:turkmen_ses/core/config/app_config.dart';
import 'package:turkmen_ses/core/network/api_contract.dart';
import 'package:turkmen_ses/core/network/api_exception.dart';

/// Thin, typed wrapper around the Türkmen Ses REST API.
///
/// Only the endpoints the app really uses are implemented, and every parsing
/// path tolerates missing keys (an old server must never crash the app).
class ApiClient implements ApiClientLike {
  ApiClient({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 60),
                headers: <String, String>{'Accept': 'application/json'},
              ),
            );

  final Dio _dio;

  String? token;
  String? deviceId;

  Map<String, String> get _authHeaders => <String, String>{
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
        if (deviceId != null && deviceId!.isNotEmpty) 'X-Device-Id': deviceId!,
      };

  // ----------------------------------------------------------------- health
  Future<Map<String, dynamic>> health() => _getMap('/health', auth: false);

  Future<Map<String, dynamic>> readiness() => _getMap('/health/ready', auth: false);

  // -------------------------------------------------------------- sentences
  Future<List<Map<String, dynamic>>> fetchPackages() async {
    final data = await _getList('/sentences/packages', auth: false);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchSentences({String? packageId, int limit = 500}) async {
    final data = await _getList(
      '/sentences',
      auth: false,
      query: <String, dynamic>{
        if (packageId != null && packageId.isNotEmpty) 'package_id': packageId,
        'limit': limit,
      },
    );
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchRandomSentence({String? packageId, List<String> exclude = const <String>[]}) {
    return _getMap(
      '/sentences/random',
      auth: false,
      query: <String, dynamic>{
        if (packageId != null && packageId.isNotEmpty) 'package_id': packageId,
        if (exclude.isNotEmpty) 'exclude': exclude.take(50).join(','),
      },
    );
  }

  // ------------------------------------------------------------------ users
  Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    String? displayName,
    int? avatarSeed,
    String consentType = 'dataset',
  }) {
    return _postMap(
      '/users/register',
      auth: false,
      data: <String, dynamic>{
        'device_id': deviceId,
        if (displayName != null && displayName.trim().isNotEmpty) 'display_name': displayName.trim(),
        'avatar_seed': ?avatarSeed,
        'consent_type': consentType,
      },
    );
  }

  Future<Map<String, dynamic>> fetchMe() => _getMap('/users/me', query: <String, dynamic>{});

  Future<Map<String, dynamic>> updateMe({String? displayName, int? avatarSeed, String? consentType}) {
    return _patchMap('/users/me', <String, dynamic>{
      'display_name': ?displayName,
      'avatar_seed': ?avatarSeed,
      'consent_type': ?consentType,
    });
  }

  // -------------------------------------------------------------- recordings
  @override
  Future<Map<String, dynamic>> uploadRecording({
    required String filePath,
    required Map<String, dynamic> metadata,
  }) async {
    final form = FormData.fromMap(<String, dynamic>{
      ...metadata,
      'audio_file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
        contentType: DioMediaType('audio', 'wav'),
      ),
    });
    return _postMap('/recordings', data: form);
  }

  Future<Map<String, dynamic>> fetchRecording(String recordingId) => _getMap('/recordings/$recordingId');

  Future<Map<String, dynamic>> recordingRatings(String recordingId) =>
      _getMap('/recordings/$recordingId/ratings');

  Future<void> deleteRecording(String recordingId) async {
    try {
      await _dio.delete<void>('/recordings/$recordingId', options: Options(headers: _authHeaders));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  // ---------------------------------------------------------------- ratings
  Future<List<Map<String, dynamic>>> fetchRatingQueue({int limit = 5}) async {
    final data = await _getList('/ratings/queue', query: <String, dynamic>{'limit': limit});
    return data.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>> submitRating({
    required String recordingId,
    required int score,
    required bool matchesText,
    String? comment,
  }) {
    return _postMap(
      '/recordings/$recordingId/ratings',
      data: <String, dynamic>{
        'score': score,
        'matches_text': matchesText,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> reportRecording(String recordingId, {String? reason}) {
    return _postMap(
      '/recordings/$recordingId/report',
      data: <String, dynamic>{if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
    );
  }

  // ------------------------------------------------------------------ stats
  Future<Map<String, dynamic>> fetchOverview() => _getMap('/stats/overview', auth: false);

  Future<Map<String, dynamic>> fetchMyStats() => _getMap('/stats/me');

  Future<Map<String, dynamic>> fetchLeaderboard({int limit = 20, String period = 'all'}) {
    return _getMap('/leaderboard', query: <String, dynamic>{'limit': limit, 'period': period});
  }

  // --------------------------------------------------------------- plumbing
  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    final data = await _request(
      () => _dio.get<Object?>(path, queryParameters: query, options: Options(headers: auth ? _authHeaders : null)),
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> _postMap(
    String path, {
    Object? data,
    bool auth = true,
  }) async {
    final response = await _request(
      () => _dio.post<Object?>(path, data: data, options: Options(headers: auth ? _authHeaders : null)),
    );
    return _asMap(response);
  }

  Future<Map<String, dynamic>> _patchMap(String path, Object? data) async {
    final response = await _request(
      () => _dio.patch<Object?>(path, data: data, options: Options(headers: _authHeaders)),
    );
    return _asMap(response);
  }

  Future<List<dynamic>> _getList(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    final data = await _request(
      () => _dio.get<Object?>(path, queryParameters: query, options: Options(headers: auth ? _authHeaders : null)),
    );
    if (data is List) {
      return data;
    }
    return const <dynamic>[];
  }

  Future<Object?> _request(Future<Response<Object?>> Function() call) async {
    try {
      final response = await call();
      return response.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }
}
