import 'package:flutter/material.dart';

/// StockFlow Enterprise Color Palette
/// Designed for high-legibility, professional business tooling.
class AppColors {
  AppColors._();

  // Primary & Brand
  static const Color primary = Color(0xFF0F172A); // Slate 900
  static const Color primaryLight = Color(0xFF1E293B); // Slate 800
  static const Color accent = Color(0xFF2563EB); // Royal Blue / Cobalt
  static const Color accentHover = Color(0xFF1D4ED8);

  // Surfaces & Backgrounds - Light
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFF1F5F9); // Slate 100
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color dividerLight = Color(0xFFCBD5E1); // Slate 300

  // Surfaces & Backgrounds - Dark
  static const Color backgroundDark = Color(0xFF0B0F17);
  static const Color surfaceDark = Color(0xFF111827); // Gray 900
  static const Color surfaceElevatedDark = Color(0xFF1F2937); // Gray 800
  static const Color borderDark = Color(0xFF374151); // Gray 700
  static const Color dividerDark = Color(0xFF4B5563);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569); // Slate 600
  static const Color textMutedLight = Color(0xFF94A3B8); // Slate 400

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  // Semantic Status Colors
  static const Color inStock = Color(0xFF059669); // Emerald 600
  static const Color inStockBg = Color(0xFFECFDF5);
  static const Color lowStock = Color(0xFFD97706); // Amber 600
  static const Color lowStockBg = Color(0xFFFFFBEB);
  static const Color outOfStock = Color(0xFFE11D48); // Rose 600
  static const Color outOfStockBg = Color(0xFFFFF1F2);

  // General Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}
