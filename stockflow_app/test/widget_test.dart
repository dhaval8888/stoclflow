import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_app/core/theme/app_theme.dart';
import 'package:stockflow_app/core/widgets/app_button.dart';
import 'package:stockflow_app/core/widgets/status_badge.dart';
import 'package:stockflow_app/features/auth/application/auth_controller.dart';
import 'package:stockflow_app/features/auth/application/auth_state.dart';
import 'package:stockflow_app/features/auth/data/models/user_model.dart';
import 'package:stockflow_app/features/auth/presentation/screens/login_screen.dart';

void main() {
  group('User Model Tests', () {
    test('parses User from JSON and computes role capabilities correctly', () {
      final json = {
        'id': 'u1',
        'business_id': 'b1',
        'full_name': 'Alice Owner',
        'email': 'alice@example.com',
        'role': 'OWNER',
        'is_active': true,
        'business_name': 'Alice Groceries',
      };

      final user = User.fromJson(json);

      expect(user.id, 'u1');
      expect(user.businessId, 'b1');
      expect(user.fullName, 'Alice Owner');
      expect(user.email, 'alice@example.com');
      expect(user.isOwner, true);
      expect(user.isManager, false);
      expect(user.isCashier, false);
      expect(user.canManageInventory, true);
      expect(user.canManageUsers, true);
      expect(user.canViewAnalytics, true);
    });

    test('verifies Cashier permissions are properly restricted', () {
      const cashier = User(
        id: 'u2',
        businessId: 'b1',
        fullName: 'Bob Cashier',
        email: 'bob@example.com',
        role: 'CASHIER',
      );

      expect(cashier.isCashier, true);
      expect(cashier.isOwner, false);
      expect(cashier.canManageUsers, false);
      expect(cashier.canManageInventory, false);
      expect(cashier.canViewAnalytics, false);
    });
  });

  group('AuthState Tests', () {
    test('initial state properties', () {
      const state = AuthState.initial();
      expect(state.isInitial, true);
      expect(state.isLoading, false);
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
    });

    test('authenticated state properties', () {
      const user = User(
        id: 'u1',
        businessId: 'b1',
        fullName: 'Test User',
        email: 'test@example.com',
        role: 'MANAGER',
      );

      const state = AuthState.authenticated(user);
      expect(state.isAuthenticated, true);
      expect(state.isLoading, false);
      expect(state.user?.fullName, 'Test User');
    });
  });

  group('Widget Tests', () {
    testWidgets('StatusBadge renders correctly for stock and roles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.stock('IN_STOCK'),
                StatusBadge.stock('LOW_STOCK'),
                StatusBadge.stock('OUT_OF_STOCK'),
                StatusBadge.role('OWNER'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('In Stock'), findsOneWidget);
      expect(find.text('Low Stock'), findsOneWidget);
      expect(find.text('Out of Stock'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);
    });

    testWidgets('AppButton displays loading spinner when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Save Item',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save Item'), findsOneWidget);
    });

    testWidgets('LoginScreen renders and validates empty inputs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => MockAuthController()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const LoginScreen(),
          ),
        ),
      );

      expect(find.text('Sign in to your account'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Tap Sign In without filling form
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });
  });
}

class MockAuthController extends StateNotifier<AuthState> implements AuthController {
  MockAuthController() : super(const AuthState.unauthenticated());

  @override
  Future<void> checkAuthStatus() async {}

  @override
  void clearError() {}

  @override
  Future<bool> login({required String email, required String password}) async {
    return false;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<bool> register({
    required String businessName,
    required String fullName,
    required String email,
    required String password,
    String? businessPhone,
    String? businessAddress,
  }) async {
    return false;
  }
}

