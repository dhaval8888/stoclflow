import 'package:dio/dio.dart';

/// Typed API exception with user-facing messages
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const ApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConnectionError =>
      statusCode == 408 || statusCode == 503 || statusCode == 504 || statusCode == null;

  factory ApiException.fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message: 'Connection timed out. Please check your network and try again.',
          statusCode: 408,
        );

      case DioExceptionType.badResponse:
        final response = error.response;
        final statusCode = response?.statusCode;
        final data = response?.data;

        String message = 'An unexpected error occurred. Please try again.';
        dynamic details;

        if (data is Map<String, dynamic>) {
          if (data['message'] != null && data['message'].toString().isNotEmpty) {
            message = data['message'].toString();
          } else if (data['error'] != null && data['error'].toString().isNotEmpty) {
            message = data['error'].toString();
          }

          if (data['errors'] != null) {
            details = data['errors'];
            if (details is List && details.isNotEmpty) {
              final first = details.first;
              if (first is Map && first['message'] != null) {
                message = first['message'].toString();
              } else if (first is String) {
                message = first;
              }
            }
          }
        } else if (statusCode == 401) {
          message = 'Session expired or unauthorized. Please sign in again.';
        } else if (statusCode == 403) {
          message = 'You do not have permission to perform this action.';
        } else if (statusCode == 404) {
          message = 'The requested resource was not found.';
        } else if (statusCode != null && statusCode >= 500) {
          message = 'Server is temporarily unavailable. Please try again later.';
        }

        return ApiException(
          message: message,
          statusCode: statusCode,
          details: details,
        );

      case DioExceptionType.connectionError:
        return const ApiException(
          message: 'No internet connection. Please verify your connection or API server status.',
          statusCode: 503,
        );

      case DioExceptionType.cancel:
        return const ApiException(
          message: 'Request was cancelled.',
        );

      default:
        return ApiException(
          message: error.message ?? 'A network error occurred. Please try again.',
        );
    }
  }

  /// Extracts a clean, user-friendly error message from any exception or error object
  static String getErrorMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred.';
    if (error is ApiException) return error.message;
    if (error is DioException) return ApiException.fromDioError(error).message;
    if (error is String) return error;

    final str = error.toString();
    if (str.startsWith('Exception: ')) {
      return str.substring(11);
    }
    return str;
  }

  @override
  String toString() => message;
}
