import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_app/core/network/api_exceptions.dart';
import 'package:stockflow_app/core/network/token_storage.dart';
import 'package:stockflow_app/features/auth/application/auth_controller.dart';
import 'package:stockflow_app/features/auth/application/auth_state.dart';
import 'package:stockflow_app/features/auth/data/models/user_model.dart';
import 'package:stockflow_app/features/auth/data/repositories/auth_repository.dart';

class FakeTokenStorageService extends TokenStorageService {
  final Map<String, String> _data = {};

  FakeTokenStorageService() : super(const FlutterSecureStorage());

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _data['access_token'] = accessToken;
    _data['refresh_token'] = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => _data['access_token'];

  @override
  Future<String?> getRefreshToken() async => _data['refresh_token'];

  @override
  Future<void> saveUserJson(String userJson) async => _data['user_data'] = userJson;

  @override
  Future<String?> getUserJson() async => _data['user_data'];

  @override
  Future<void> clearAll() async => _data.clear();
}

class FakeAuthRepository extends AuthRepository {
  User? userToReturn;
  AuthResponse? loginResponseToReturn;
  Exception? errorToThrow;
  String? lastLoggedOutToken;

  FakeAuthRepository() : super(Dio());

  @override
  Future<User> getMe() async {
    if (errorToThrow != null) throw errorToThrow!;
    return userToReturn!;
  }

  @override
  Future<AuthResponse> login({required String email, required String password}) async {
    if (errorToThrow != null) throw errorToThrow!;
    return loginResponseToReturn!;
  }

  @override
  Future<void> logout(String? refreshToken) async {
    lastLoggedOutToken = refreshToken;
  }
}

void main() {
  late FakeTokenStorageService fakeStorage;
  late FakeAuthRepository fakeRepo;
  late AuthController controller;

  const testUser = User(
    id: 'user-1',
    businessId: 'biz-1',
    fullName: 'Jane Owner',
    email: 'jane@example.com',
    role: 'OWNER',
  );

  const testTokens = AuthTokens(
    accessToken: 'access-token-123',
    refreshToken: 'refresh-token-456',
  );

  setUp(() {
    fakeStorage = FakeTokenStorageService();
    fakeRepo = FakeAuthRepository();
    controller = AuthController(fakeRepo, fakeStorage);
  });

  group('AuthController Unit Tests', () {
    test('initial state is unauthenticated/initial', () {
      expect(controller.state.status, AuthStatus.initial);
      expect(controller.state.user, isNull);
    });

    test('checkAuthStatus transitions to unauthenticated if no tokens saved', () async {
      await controller.checkAuthStatus();
      expect(controller.state.status, AuthStatus.unauthenticated);
    });

    test('checkAuthStatus validates tokens against backend and sets authenticated', () async {
      await fakeStorage.saveTokens(
        accessToken: testTokens.accessToken,
        refreshToken: testTokens.refreshToken,
      );
      fakeRepo.userToReturn = testUser;

      await controller.checkAuthStatus();

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user?.id, 'user-1');
      expect(controller.state.user?.fullName, 'Jane Owner');
    });

    test('checkAuthStatus with 401 unauthorized wipes storage and forces unauthenticated', () async {
      await fakeStorage.saveTokens(
        accessToken: 'expired-token',
        refreshToken: 'expired-rt',
      );
      await fakeStorage.saveUserJson(jsonEncode(testUser.toJson()));
      fakeRepo.errorToThrow = const ApiException(message: 'Invalid token', statusCode: 401);

      await controller.checkAuthStatus();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(await fakeStorage.getAccessToken(), isNull);
      expect(await fakeStorage.getRefreshToken(), isNull);
    });

    test('checkAuthStatus with network offline falls back to cached user', () async {
      await fakeStorage.saveTokens(
        accessToken: 'valid-token',
        refreshToken: 'valid-rt',
      );
      await fakeStorage.saveUserJson(jsonEncode(testUser.toJson()));
      fakeRepo.errorToThrow = const ApiException(
        message: 'No internet connection',
        statusCode: 503,
      );

      await controller.checkAuthStatus();

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user?.email, 'jane@example.com');
    });

    test('login success saves tokens and sets authenticated', () async {
      fakeRepo.loginResponseToReturn = const AuthResponse(
        user: testUser,
        tokens: testTokens,
      );

      final success = await controller.login(email: 'jane@example.com', password: 'password123');

      expect(success, true);
      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user?.fullName, 'Jane Owner');
      expect(await fakeStorage.getAccessToken(), 'access-token-123');
    });

    test('login failure sets error state with clean message', () async {
      fakeRepo.errorToThrow = const ApiException(
        message: 'Invalid email or password',
        statusCode: 401,
      );

      final success = await controller.login(email: 'wrong@example.com', password: 'wrong');

      expect(success, false);
      expect(controller.state.status, AuthStatus.error);
      expect(controller.state.errorMessage, 'Invalid email or password');
    });

    test('logout calls server logout and clears all stored tokens', () async {
      await fakeStorage.saveTokens(accessToken: 'token', refreshToken: 'rt');
      await fakeStorage.saveUserJson(jsonEncode(testUser.toJson()));

      await controller.logout();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(await fakeStorage.getAccessToken(), isNull);
      expect(await fakeStorage.getRefreshToken(), isNull);
      expect(await fakeStorage.getUserJson(), isNull);
      expect(fakeRepo.lastLoggedOutToken, 'rt');
    });
  });
}
