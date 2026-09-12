/// StockFlow Application Constants
class AppConstants {
  AppConstants._();

  // Storage Keys
  static const String keyAccessToken = 'stockflow_access_token';
  static const String keyRefreshToken = 'stockflow_refresh_token';
  static const String keyUserData = 'stockflow_user_data';

  // User Roles
  static const String roleOwner = 'OWNER';
  static const String roleManager = 'MANAGER';
  static const String roleCashier = 'CASHIER';

  // Demo Credentials (isolated for development/review only)
  static const String demoOwnerEmail = 'owner@demo.com';
  static const String demoManagerEmail = 'manager@demo.com';
  static const String demoCashierEmail = 'cashier@demo.com';
}
