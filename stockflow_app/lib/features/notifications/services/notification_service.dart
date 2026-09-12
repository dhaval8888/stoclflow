import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

/// Provider for the NotificationService singleton
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(dioProvider));
});

/// Handles FCM token lifecycle:
///  - Registers current token with backend on startup
///  - Listens for token refreshes and re-registers
///  - Removes token on logout
///  - Degrades gracefully when Firebase is not configured
class NotificationService {
  final Dio _dio;
  bool _isInitialized = false;
  String? _currentToken;

  NotificationService(this._dio);

  /// Call once after a successful authenticated startup.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Verify Firebase is configured before using FirebaseMessaging
      Firebase.app();
    } catch (e) {
      dev.log(
        '[NotificationService] Firebase is not configured — notifications disabled.',
        name: 'StockFlow.Notifications',
      );
      _isInitialized = true;
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (iOS prompt; Android 13+ prompt)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      dev.log(
        '[NotificationService] Permission status: ${settings.authorizationStatus}',
        name: 'StockFlow.Notifications',
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        dev.log(
          '[NotificationService] User denied notifications — registration skipped.',
          name: 'StockFlow.Notifications',
        );
        _isInitialized = true;
        return;
      }

      // Get current FCM token and register with backend
      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token, 'android');
      }

      // Listen for token refreshes (FCM token rotation)
      messaging.onTokenRefresh.listen((newToken) async {
        dev.log(
          '[NotificationService] FCM token refreshed — re-registering.',
          name: 'StockFlow.Notifications',
        );
        await _registerToken(newToken, 'android');
      });

      _isInitialized = true;
      dev.log(
        '[NotificationService] Initialized successfully.',
        name: 'StockFlow.Notifications',
      );
    } catch (e) {
      // Non-blocking: log the error but don't crash or block the auth flow
      dev.log(
        '[NotificationService] Initialization failed: $e',
        name: 'StockFlow.Notifications',
        error: e,
      );
      _isInitialized = true;
    }
  }

  /// Registers (or re-registers) an FCM token with the backend.
  /// Skips if the same token is already registered (avoids duplicates).
  Future<void> _registerToken(String token, String platform) async {
    if (token == _currentToken) {
      dev.log(
        '[NotificationService] Token unchanged — skipping registration.',
        name: 'StockFlow.Notifications',
      );
      return;
    }

    try {
      await _dio.post(
        ApiEndpoints.notificationsToken,
        data: {'token': token, 'platform': platform},
      );
      _currentToken = token;
      dev.log(
        '[NotificationService] FCM token registered successfully.',
        name: 'StockFlow.Notifications',
      );
    } catch (e) {
      // Non-blocking — app continues working without push notifications
      dev.log(
        '[NotificationService] Token registration failed: $e',
        name: 'StockFlow.Notifications',
        error: e,
      );
    }
  }

  /// Removes the current device token on logout.
  Future<void> removeToken() async {
    final token = _currentToken;
    if (token == null) return;

    try {
      await _dio.delete(
        ApiEndpoints.notificationsToken,
        data: {'token': token},
      );
      _currentToken = null;
      dev.log(
        '[NotificationService] FCM token removed on logout.',
        name: 'StockFlow.Notifications',
      );
    } catch (e) {
      // Non-blocking — session revocation is still handled by auth logout
      dev.log(
        '[NotificationService] Token removal failed: $e',
        name: 'StockFlow.Notifications',
        error: e,
      );
    }
  }

  /// Reset state between sessions
  void reset() {
    _currentToken = null;
    _isInitialized = false;
  }
}
