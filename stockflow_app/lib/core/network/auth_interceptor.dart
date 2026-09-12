import 'dart:async';
import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import 'token_storage.dart';

/// Interceptor that attaches access tokens and safely handles
/// concurrent token refresh using Completer synchronization.
class AuthInterceptor extends QueuedInterceptor {
  final TokenStorageService _tokenStorage;
  final Dio _dio;
  final Dio _refreshDio;
  final VoidCallback? _onSessionExpired;

  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  AuthInterceptor({
    required this._tokenStorage,
    required this._dio,
    this._onSessionExpired,
  })  : _refreshDio = Dio(BaseOptions(
          baseUrl: ApiEndpoints.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        ));

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Ignore 401s on login or refresh endpoints
    final isAuthEndpoint = path.contains(ApiEndpoints.login) ||
        path.contains(ApiEndpoints.refresh) ||
        path.contains(ApiEndpoints.register);

    if (statusCode == 401 && !isAuthEndpoint) {
      if (_isRefreshing) {
        // Wait for the active refresh request to finish
        try {
          final newToken = await _refreshCompleter?.future;
          if (newToken != null && newToken.isNotEmpty) {
            err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final response = await _dio.fetch(err.requestOptions);
            return handler.resolve(response);
          }
        } catch (_) {
          // Fall through to reject
        }
        return handler.next(err);
      }

      // First request to encounter 401 initiates the refresh
      _isRefreshing = true;
      _refreshCompleter = Completer<String?>();

      try {
        final currentRefreshToken = await _tokenStorage.getRefreshToken();
        if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
          throw Exception('No refresh token available');
        }

        final response = await _refreshDio.post(
          ApiEndpoints.refresh,
          data: {'refreshToken': currentRefreshToken},
        );

        if (response.statusCode == 200 && response.data['success'] == true) {
          final data = response.data['data'];
          final newAccessToken = data['accessToken'] as String;
          final newRefreshToken = (data['refreshToken'] ?? currentRefreshToken) as String;

          // Save both rotated tokens
          await _tokenStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          _isRefreshing = false;
          _refreshCompleter?.complete(newAccessToken);

          // Retry the original failed request
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResponse = await _dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        } else {
          throw Exception('Token refresh failed with status ${response.statusCode}');
        }
      } catch (refreshErr) {
        _isRefreshing = false;
        _refreshCompleter?.complete(null);

        // Clear session on refresh failure
        await _tokenStorage.clearAll();
        _onSessionExpired?.call();

        return handler.next(err);
      }
    }

    handler.next(err);
  }
}

typedef VoidCallback = void Function();
