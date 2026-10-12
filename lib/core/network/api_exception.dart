import 'package:dio/dio.dart';

/// Every network failure surfaced to the UI goes through this type, so the
/// screens can show a Turkmen message instead of a raw stack trace.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.isNetwork = false,
    this.offline = false,
  });

  final String message;
  final int? statusCode;
  final bool isNetwork;
  final bool offline;

  factory ApiException.fromDio(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final detail = _detail(data);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          'Serwer jogap bermedi (wagt gutardy). Interneti barlaň.',
          statusCode: status,
          isNetwork: true,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return ApiException(
          'Serwere baglanyp bolmady. Internet ýok bolsa, ýazgylar telefonda saklanar.',
          statusCode: status,
          isNetwork: true,
          offline: true,
        );
      case DioExceptionType.cancel:
        return const ApiException('Sorag ýatyryldy.');
      case DioExceptionType.badCertificate:
        return const ApiException('Serweriň sertifikaty nädogry.');
      case DioExceptionType.badResponse:
        return ApiException(
          detail ?? _statusMessage(status),
          statusCode: status,
        );
    }
  }

  static String? _detail(Object? data) {
    if (data is Map) {
      final value = data['detail'] ?? data['message'];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
      if (value is List && value.isNotEmpty) {
        return value.map((item) => item.toString()).join(', ');
      }
    }
    if (data is String && data.trim().isNotEmpty && data.length < 300) {
      return data;
    }
    return null;
  }

  static String _statusMessage(int? status) {
    switch (status) {
      case 401:
        return 'Hasap tapylmady. Programmadan täzeden girip görüň.';
      case 403:
        return 'Bu amal üçin rugsadyňyz ýok.';
      case 404:
        return 'Maglumat tapylmady.';
      case 413:
        return 'Faýl örän uly.';
      case 415:
        return 'Diňe WAV görnüşi kabul edilýär.';
      case 422:
        return 'Maglumat barlagy şowsuz boldy.';
      case 429:
        return 'Günlük çäk doldy, bir azdan täzeden synanyşyň.';
      case 500:
      case 502:
      case 503:
        return 'Serwerde säwlik boldy. Birazdan täzeden synanyşyň.';
      default:
        return 'Garaşylmadyk ýalňyşlyk (${status ?? '?'}).';
    }
  }

  @override
  String toString() => message;
}
