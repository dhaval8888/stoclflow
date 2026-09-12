import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/employees/presentation/screens/employees_screen.dart';
import '../../features/employees/presentation/screens/employee_form_screen.dart';
import '../../features/inventory/presentation/screens/inventory_screen.dart';
import '../../features/navigation/presentation/app_shell.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/products/presentation/screens/product_form_screen.dart';
import '../../features/sales/presentation/screens/sales_screen.dart';
import '../../features/sales/presentation/screens/receipt_screen.dart';
import '../../features/settings/presentation/screens/business_profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authRouterNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.uri.path;

      final isSplash = location == '/splash';
      final isAuthScreen = location == '/login' || location == '/register';

      // 1. If checking auth or initial startup, show splash
      if (authState.isInitial || (authState.isLoading && isSplash)) {
        return isSplash ? null : '/splash';
      }

      // 2. If unauthenticated, redirect to login unless already on login/register
      if (authState.isUnauthenticated || authState.status == AuthStatus.error) {
        return isAuthScreen ? null : '/login';
      }

      // 3. If authenticated
      if (authState.isAuthenticated) {
        final user = authState.user;

        // Redirect away from splash, login, or register
        if (isSplash || isAuthScreen) {
          return '/dashboard';
        }

        // Role-based route guards:
        // Cashiers cannot access /analytics or /employees
        if (user?.isCashier == true) {
          if (location.startsWith('/analytics') || location.startsWith('/employees')) {
            return '/dashboard';
          }
        }

        // Managers cannot access /employees (Owner only)
        if (user?.isManager == true) {
          if (location.startsWith('/employees')) {
            return '/settings';
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/analytics',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/employees',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EmployeesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const EmployeeFormScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/settings/business',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BusinessProfileScreen(),
      ),

      // Main App Shell with persistent tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),

          // Branch 1: Products
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products',
                builder: (context, state) => const ProductsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ProductFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return ProductDetailScreen(productId: id);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Branch 2: Inventory
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (context, state) => const InventoryScreen(),
              ),
            ],
          ),

          // Branch 3: Sales
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sales',
                builder: (context, state) => const SalesScreen(),
                routes: [
                  GoRoute(
                    path: 'receipt/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return ReceiptScreen(saleId: id);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Branch 4: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
