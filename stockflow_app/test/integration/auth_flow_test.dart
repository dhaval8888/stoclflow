import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_app/core/network/api_exceptions.dart';
import 'package:stockflow_app/core/network/token_storage.dart';
import 'package:stockflow_app/features/auth/application/auth_controller.dart';
import 'package:stockflow_app/features/auth/application/auth_state.dart';
import 'package:stockflow_app/features/auth/data/models/user_model.dart';
import 'package:stockflow_app/features/auth/data/repositories/auth_repository.dart';

class InMemoryTokenStorage extends TokenStorageService {
  final Map<String, String> _store = {};

  InMemoryTokenStorage() : super(const FlutterSecureStorage());

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _store['access_token'] = accessToken;
    _store['refresh_token'] = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => _store['access_token'];

  @override
  Future<String?> getRefreshToken() async => _store['refresh_token'];

  @override
  Future<void> saveUserJson(String userJson) async => _store['user_data'] = userJson;

  @override
  Future<String?> getUserJson() async => _store['user_data'];

  @override
  Future<void> clearAll() async => _store.clear();
}

class MockBackendAuthRepository extends AuthRepository {
  User? currentUser;
  AuthTokens? activeTokens;
  Exception? serverError;
  bool wasLogoutCalled = false;

  MockBackendAuthRepository() : super(Dio());

  @override
  Future<AuthResponse> login({required String email, required String password}) async {
    if (serverError != null) throw serverError!;
    if (email == 'alex@stockflow.com' && password == 'correct_password') {
      final user = User(
        id: 'usr_owner_1',
        businessId: 'biz_flagship_1',
        fullName: 'Alex Reynolds',
        email: email,
        role: 'OWNER',
      );
      final tokens = const AuthTokens(
        accessToken: 'jwt_valid_access_token_123',
        refreshToken: 'jwt_valid_refresh_token_456',
      );
      currentUser = user;
      activeTokens = tokens;
      return AuthResponse(user: user, tokens: tokens);
    }
    throw const ApiException(message: 'Invalid email or password', statusCode: 401);
  }

  @override
  Future<User> getMe() async {
    if (serverError != null) throw serverError!;
    if (currentUser != null) return currentUser!;
    throw const ApiException(message: 'Unauthorized token', statusCode: 401);
  }

  @override
  Future<void> logout(String? refreshToken) async {
    wasLogoutCalled = true;
    currentUser = null;
    activeTokens = null;
  }
}

void main() {
  group('Auth Flow End-to-End Integration Tests (ProviderContainer Lifecycle)', () {
    late InMemoryTokenStorage tokenStorage;
    late MockBackendAuthRepository backendRepo;

    setUp(() {
      tokenStorage = InMemoryTokenStorage();
      backendRepo = MockBackendAuthRepository();
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(backendRepo),
        ],
      );
    }

    test('Complete Authentication Lifecycle: Login -> Session Storage -> App Restart -> Logout', () async {
      // Step 1: Fresh container represents clean app launch with no stored credentials
      final container1 = createContainer();
      final authNotifier1 = container1.read(authControllerProvider.notifier);

      expect(container1.read(authControllerProvider).status, AuthStatus.initial);

      // Perform auth check on cold start
      await authNotifier1.checkAuthStatus();
      expect(container1.read(authControllerProvider).status, AuthStatus.unauthenticated);

      // Step 2: User submits login form
      final loginSuccess = await authNotifier1.login(
        email: 'alex@stockflow.com',
        password: 'correct_password',
      );

      expect(loginSuccess, true);
      final loggedInState = container1.read(authControllerProvider);
      expect(loggedInState.status, AuthStatus.authenticated);
      expect(loggedInState.user?.fullName, 'Alex Reynolds');
      expect(loggedInState.user?.role, 'OWNER');

      // Tokens and user JSON must be securely written into storage
      expect(await tokenStorage.getAccessToken(), 'jwt_valid_access_token_123');
      expect(await tokenStorage.getRefreshToken(), 'jwt_valid_refresh_token_456');
      expect(await tokenStorage.getUserJson(), isNotNull);

      // Step 3: Simulate app restart (new container initialized with existing token storage)
      container1.dispose();
      final container2 = createContainer();
      final authNotifier2 = container2.read(authControllerProvider.notifier);

      // Cold start checks auth status and validates token with backend
      await authNotifier2.checkAuthStatus();

      final restoredState = container2.read(authControllerProvider);
      expect(restoredState.status, AuthStatus.authenticated);
      expect(restoredState.user?.fullName, 'Alex Reynolds');

      // Step 4: User initiates Logout
      await authNotifier2.logout();

      final loggedOutState = container2.read(authControllerProvider);
      expect(loggedOutState.status, AuthStatus.unauthenticated);
      expect(loggedOutState.user, isNull);

      // Backend was notified and local secure storage is wiped clean
      expect(backendRepo.wasLogoutCalled, true);
      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
      expect(await tokenStorage.getUserJson(), isNull);

      container2.dispose();
    });

    test('Session Invalidation: 401 Unauthorized during session check wipes local tokens', () async {
      // Pre-seed storage with expired tokens
      await tokenStorage.saveTokens(
        accessToken: 'expired_access_token',
        refreshToken: 'revoked_refresh_token',
      );
      await tokenStorage.saveUserJson(
        jsonEncode({
          'id': 'usr_revoked',
          'businessId': 'biz_1',
          'fullName': 'Former Employee',
          'email': 'former@stockflow.com',
          'role': 'CASHIER',
        }),
      );

      // Backend rejects token with 401
      backendRepo.serverError = const ApiException(
        message: 'Token has been revoked or business account suspended',
        statusCode: 401,
      );

      final container = createContainer();
      final authNotifier = container.read(authControllerProvider.notifier);

      await authNotifier.checkAuthStatus();

      // State must be forced to unauthenticated
      expect(container.read(authControllerProvider).status, AuthStatus.unauthenticated);
      expect(container.read(authControllerProvider).user, isNull);

      // Local storage must have been purged for security
      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
      expect(await tokenStorage.getUserJson(), isNull);

      container.dispose();
    });

    test('Offline Fallback: Network connection loss restores cached user without clearing tokens', () async {
      // Pre-seed valid session in storage
      await tokenStorage.saveTokens(
        accessToken: 'valid_access_token',
        refreshToken: 'valid_refresh_token',
      );
      final user = const User(
        id: 'usr_offline',
        businessId: 'biz_1',
        fullName: 'Offline Manager',
        email: 'manager@stockflow.com',
        role: 'MANAGER',
      );
      await tokenStorage.saveUserJson(jsonEncode(user.toJson()));

      // Backend throws connection timeout (offline)
      backendRepo.serverError = const ApiException(
        message: 'Connection timed out',
        statusCode: 503,
      );

      final container = createContainer();
      final authNotifier = container.read(authControllerProvider.notifier);

      await authNotifier.checkAuthStatus();

      // Should fall back to cached session so user can operate offline
      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.fullName, 'Offline Manager');
      expect(state.user?.role, 'MANAGER');

      // Tokens must NOT have been wiped
      expect(await tokenStorage.getAccessToken(), 'valid_access_token');
      expect(await tokenStorage.getRefreshToken(), 'valid_refresh_token');

      container.dispose();
    });
  });
}