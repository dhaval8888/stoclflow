import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_app/core/network/token_storage.dart';
import 'package:stockflow_app/features/analytics/application/analytics_controller.dart';
import 'package:stockflow_app/features/analytics/application/analytics_state.dart';
import 'package:stockflow_app/features/analytics/data/models/analytics_models.dart';
import 'package:stockflow_app/features/analytics/data/repositories/analytics_repository.dart';
import 'package:stockflow_app/features/auth/application/auth_controller.dart';
import 'package:stockflow_app/features/auth/application/auth_state.dart';
import 'package:stockflow_app/features/auth/data/models/user_model.dart';
import 'package:stockflow_app/features/auth/data/repositories/auth_repository.dart';
import 'package:stockflow_app/features/dashboard/presentation/screens/dashboard_screen.dart';

class MockTokenStorage extends Fake implements TokenStorageService {}

class MockAuthRepository extends AuthRepository {
  MockAuthRepository() : super(Dio());
}

class FakeAnalyticsRepository extends AnalyticsRepository {
  final DashboardSummary summary;
  FakeAnalyticsRepository(this.summary) : super(Dio());

  @override
  Future<DashboardSummary> getSummary() async => summary;
}

class FakeDashboardController extends DashboardController {
  FakeDashboardController(DashboardSummary summary)
      : super(FakeAnalyticsRepository(summary)) {
    state = DashboardState(
      summary: summary,
      status: AnalyticsLoadStatus.loaded,
    );
  }
}

void main() {
  group('Dashboard Role-Based View Tests', () {
    final fakeStorage = MockTokenStorage();
    final fakeAuthRepo = MockAuthRepository();

    const cashierUser = User(
      id: 'usr_cashier',
      businessId: 'biz_1',
      fullName: 'John Cashier',
      email: 'cashier@stockflow.com',
      role: 'CASHIER',
    );

    const ownerUser = User(
      id: 'usr_owner',
      businessId: 'biz_1',
      fullName: 'Alice Owner',
      email: 'owner@stockflow.com',
      role: 'OWNER',
    );

    const testSummary = DashboardSummary(
      todaySales: 12,
      todayRevenue: 850.0,
      weekSales: 60,
      weekRevenue: 4200.0,
      monthSales: 250,
      monthRevenue: 17500.0,
      totalSales: 1000,
      totalRevenue: 70000.0,
      totalProducts: 50,
      activeProducts: 48,
      lowStockCount: 2,
      outOfStockCount: 0,
      recentSales: [],
    );

    testWidgets('Cashier dashboard renders operational shortcuts and conceals business KPIs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(fakeStorage),
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            authControllerProvider.overrideWith(
              (ref) => AuthController(fakeAuthRepo, fakeStorage)
                ..state = const AuthState.authenticated(cashierUser),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DashboardScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Operational elements are present
      expect(find.text('New Sale'), findsOneWidget);
      expect(find.text('Browse Products'), findsOneWidget);
      expect(find.text('Sales History'), findsOneWidget);
      expect(
        find.text('Business analytics and reports are available to managers and owners only.'),
        findsOneWidget,
      );

      // Sensitive business KPIs are NOT shown to cashiers
      expect(find.text('TODAY'), findsNothing);
      expect(find.text('THIS WEEK'), findsNothing);
      expect(find.text('Low Stock'), findsNothing);
      expect(find.text('Out of Stock'), findsNothing);
    });

    testWidgets('Owner dashboard renders full business KPIs and revenue metrics', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(fakeStorage),
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            authControllerProvider.overrideWith(
              (ref) => AuthController(fakeAuthRepo, fakeStorage)
                ..state = const AuthState.authenticated(ownerUser),
            ),
            dashboardControllerProvider.overrideWith((ref) {
              return FakeDashboardController(testSummary);
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DashboardScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Business KPIs and sections are present
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Sales'), findsWidgets);
      expect(find.text('Revenue'), findsWidgets);
      expect(find.text('Low Stock'), findsOneWidget);
      expect(find.text('Out of Stock'), findsOneWidget);
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('QUICK ACTIONS'), findsOneWidget);
    });
  });
}
