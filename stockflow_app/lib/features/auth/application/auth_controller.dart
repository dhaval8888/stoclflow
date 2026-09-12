import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/token_storage.dart';
import '../../notifications/services/notification_service.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_state.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  final notifications = ref.watch(notificationServiceProvider);
  return AuthController(repository, tokenStorage, notifications);
});

/// Clean Listenable bridge connecting Riverpod AuthState to GoRouter
final authRouterNotifierProvider = Provider<AuthRouterNotifier>((ref) {
  return AuthRouterNotifier(ref);
});

class AuthRouterNotifier extends ChangeNotifier {
  final Ref _ref;

  AuthRouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        if (previous?.status != next.status) {
          notifyListeners();
        }
      },
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final TokenStorageService _tokenStorage;
  final NotificationService? _notifications;

  AuthController(
    this._repository,
    this._tokenStorage, [
    this._notifications,
  ]) : super(const AuthState.initial());

  /// Checks stored session tokens and validates against the backend
  Future<void> checkAuthStatus() async {
    state = const AuthState.loading();
    try {
      final token = await _tokenStorage.getAccessToken();
      final refreshToken = await _tokenStorage.getRefreshToken();

      if (token == null || refreshToken == null) {
        state = const AuthState.unauthenticated();
        return;
      }

      // Verify token with backend
      final user = await _repository.getMe();
      await _tokenStorage.saveUserJson(jsonEncode(user.toJson()));
      state = AuthState.authenticated(user);
      // Wire FCM token — non-blocking
      _notifications?.initialize();
    } catch (e) {
      // If token is expired, revoked, or rejected by backend (401/403), wipe and force login
      if (e is ApiException && (e.isUnauthorized || e.isForbidden)) {
        await _tokenStorage.clearAll();
        state = const AuthState.unauthenticated();
        return;
      }

      // For network connectivity errors only, allow offline session from cached user
      try {
        final cachedJson = await _tokenStorage.getUserJson();
        if (cachedJson != null) {
          final user = User.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
          state = AuthState.authenticated(user);
          return;
        }
      } catch (_) {
        // Cached user parse error
      }

      await _tokenStorage.clearAll();
      state = const AuthState.unauthenticated();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();
    try {
      final authResponse = await _repository.login(
        email: email,
        password: password,
      );

      await _tokenStorage.saveTokens(
        accessToken: authResponse.tokens.accessToken,
        refreshToken: authResponse.tokens.refreshToken,
      );
      await _tokenStorage.saveUserJson(jsonEncode(authResponse.user.toJson()));

      state = AuthState.authenticated(authResponse.user);
      // Wire FCM token — non-blocking
      _notifications?.initialize();
      return true;
    } catch (e) {
      state = AuthState.error(ApiException.getErrorMessage(e));
      return false;
    }
  }

  Future<bool> register({
    required String businessName,
    required String fullName,
    required String email,
    required String password,
    String? businessPhone,
    String? businessAddress,
  }) async {
    state = const AuthState.loading();
    try {
      final authResponse = await _repository.register(
        businessName: businessName,
        fullName: fullName,
        email: email,
        password: password,
        businessPhone: businessPhone,
        businessAddress: businessAddress,
      );

      await _tokenStorage.saveTokens(
        accessToken: authResponse.tokens.accessToken,
        refreshToken: authResponse.tokens.refreshToken,
      );
      await _tokenStorage.saveUserJson(jsonEncode(authResponse.user.toJson()));

      state = AuthState.authenticated(authResponse.user);
      // Wire FCM token — non-blocking
      _notifications?.initialize();
      return true;
    } catch (e) {
      state = AuthState.error(ApiException.getErrorMessage(e));
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final rt = await _tokenStorage.getRefreshToken();
      // Remove FCM token before invalidating session — non-blocking
      await _notifications?.removeToken();
      await _repository.logout(rt);
    } catch (_) {
      // Ignore network errors on logout
    } finally {
      _notifications?.reset();
      await _tokenStorage.clearAll();
      state = const AuthState.unauthenticated();
    }
  }

  void clearError() {
    if (state.status == AuthStatus.error) {
      state = const AuthState.unauthenticated();
    }
  }
}
