import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// StockFlow API URL Constants
class ApiEndpoints {
  ApiEndpoints._();

  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    // 1. Compile-time --dart-define (used in production builds)
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    // 2. Runtime dotenv environment file (used for local development)
    if (dotenv.isInitialized) {
      final envUrl = dotenv.env['API_BASE_URL'];
      if (envUrl != null && envUrl.isNotEmpty) {
        return envUrl;
      }
    }

    // 3. Fallback defaults by platform
    if (kIsWeb) {
      return 'http://localhost:3000/api/v1';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Categories
  static const String categories = '/categories';

  // Products
  static const String products = '/products';

  // Inventory
  static const String inventory = '/inventory';
  static const String inventoryLowStock = '/inventory/low-stock';
  static const String inventoryOutOfStock = '/inventory/out-of-stock';
  static const String inventoryTransactions = '/inventory/transactions';

  // Sales
  static const String sales = '/sales';

  // Analytics — all require OWNER or MANAGER role
  static const String analyticsSummary = '/analytics/summary';
  static const String analyticsSalesTrend = '/analytics/sales-trend';    // ?days=N
  static const String analyticsTopProducts = '/analytics/top-products';  // ?days=N&limit=N
  static const String analyticsSlowProducts = '/analytics/slow-products'; // ?days=N
  static const String analyticsInventoryValue = '/analytics/inventory-value';
  static const String analyticsProfit = '/analytics/profit';             // ?days=N
  static const String analyticsReport = '/analytics/report';             // ?period=daily|weekly|monthly

  // Business Profile
  static const String business = '/business';

  // Users / Employees — OWNER only
  static const String users = '/users';

  // Notifications — all authenticated users
  static const String notificationsToken = '/notifications/token';
}
