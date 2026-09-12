import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_app/core/network/token_storage.dart';
import 'package:stockflow_app/core/widgets/app_button.dart';
import 'package:stockflow_app/features/auth/application/auth_controller.dart';
import 'package:stockflow_app/features/auth/application/auth_state.dart';
import 'package:stockflow_app/features/auth/data/models/user_model.dart';
import 'package:stockflow_app/features/auth/data/repositories/auth_repository.dart';
import 'package:stockflow_app/features/auth/presentation/screens/login_screen.dart';

class MockTokenStorage extends TokenStorageService {
  MockTokenStorage() : super(const FlutterSecureStorage());

  @override
  Future<String?> getAccessToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<String?> getUserJson() async => null;
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {}
  @override
  Future<void> clearAll() async {}
}

class MockAuthRepository extends AuthRepository {
  MockAuthRepository() : super(Dio());

  @override
  Future<User> getMe() async => throw UnimplementedError();
}

Widget _buildLoginWidget({AuthState? initialState}) {
  final fakeStorage = MockTokenStorage();
  final fakeRepo = MockAuthRepository();

  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(fakeStorage),
      authRepositoryProvider.overrideWithValue(fakeRepo),
      if (initialState != null)
        authControllerProvider.overrideWith(
          (ref) => AuthController(fakeRepo, fakeStorage)..state = initialState,
        ),
    ],
    child: const MaterialApp(
      home: LoginScreen(),
    ),
  );
}

void main() {
  group('LoginScreen Form Validation Widget Tests', () {
    testWidgets('renders all essential input fields and buttons', (tester) async {
      await tester.pumpWidget(_buildLoginWidget());

      expect(find.text('Sign in to your account'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('shows validation error when fields are empty and submitted', (tester) async {
      await tester.pumpWidget(_buildLoginWidget());

      // Tap Sign In button with empty form
      await tester.tap(find.widgetWithText(AppButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows validation error for malformed email', (tester) async {
      await tester.pumpWidget(_buildLoginWidget());

      // Enter malformed email
      await tester.enterText(
        find.widgetWithText(TextField, '').first,
        'notanemail',
      );
      await tester.tap(find.widgetWithText(AppButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('displays error banner when auth state has errorMessage', (tester) async {
      await tester.pumpWidget(_buildLoginWidget(
        initialState: const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Account locked due to too many failed attempts',
        ),
      ));

      expect(find.text('Account locked due to too many failed attempts'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('displays loading spinner on Sign In button when authState is loading', (tester) async {
      await tester.pumpWidget(_buildLoginWidget(
        initialState: const AuthState(
          status: AuthStatus.loading,
        ),
      ));

      // CircularProgressIndicator must be rendered inside AppButton
      expect(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });
  });
}
