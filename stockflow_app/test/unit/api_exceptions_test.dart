import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_app/core/network/api_exceptions.dart';

void main() {
  group('ApiException Unit Tests', () {
    test('parses timeout DioException correctly', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/v1/test'),
        type: DioExceptionType.connectionTimeout,
      );

      final exception = ApiException.fromDioError(dioError);
      expect(exception.statusCode, 408);
      expect(exception.isConnectionError, true);
      expect(exception.message, contains('timed out'));
    });

    test('parses connectionError (offline) DioException correctly', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/v1/test'),
        type: DioExceptionType.connectionError,
      );

      final exception = ApiException.fromDioError(dioError);
      expect(exception.statusCode, 503);
      expect(exception.isConnectionError, true);
      expect(exception.message, contains('No internet connection'));
    });

    test('parses 401 Unauthorized correctly', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/v1/products'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/products'),
          statusCode: 401,
          data: {'success': false, 'message': 'Invalid token'},
        ),
      );

      final exception = ApiException.fromDioError(dioError);
      expect(exception.statusCode, 401);
      expect(exception.isUnauthorized, true);
      expect(exception.message, 'Invalid token');
    });

    test('parses 403 Forbidden correctly with default message if empty data', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/v1/sales/void'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/sales/void'),
          statusCode: 403,
          data: null,
        ),
      );

      final exception = ApiException.fromDioError(dioError);
      expect(exception.statusCode, 403);
      expect(exception.isForbidden, true);
      expect(exception.message, contains('do not have permission'));
    });

    test('parses 404 Not Found correctly', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/v1/products/unknown'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/products/unknown'),
          statusCode: 404,
          data: null,
        ),
      );

      final exception = ApiException.fromDioError(dioError);
      expect(exception.statusCode, 404);
      expect(exception.isNotFound, true);
      expect(exception.message, contains('resource was not found'));
    });

    test('parses 422 Validation Error array message', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/v1/products'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/products'),
          statusCode: 422,
          data: {
            'success': false,
            'errors': [
              {'field': 'selling_price', 'message': 'Selling price must be positive'},
            ],
          },
        ),
      );

      final exception = ApiException.fromDioError(dioError);
      expect(exception.statusCode, 422);
      expect(exception.message, 'Selling price must be positive');
    });

    test('ApiException.getErrorMessage formats exceptions cleanly', () {
      expect(
        ApiException.getErrorMessage(const ApiException(message: 'Clean error')),
        'Clean error',
      );
      expect(
        ApiException.getErrorMessage(Exception('Wrapped message')),
        'Wrapped message',
      );
      expect(
        ApiException.getErrorMessage('Raw string error'),
        'Raw string error',
      );
      expect(
        ApiException.getErrorMessage(null),
        'An unexpected error occurred.',
      );
    });
  });
}
