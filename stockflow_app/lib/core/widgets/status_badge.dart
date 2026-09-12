import 'package:flutter/material.dart';
import '../constants/dimensions.dart';
import '../theme/colors.dart';

enum BadgeType { inStock, lowStock, outOfStock, role, status, custom }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeType type;
  final Color? customBg;
  final Color? customFg;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.customBg,
    this.customFg,
    this.icon,
  });

  factory StatusBadge.stock(String status) {
    switch (status.toUpperCase()) {
      case 'IN_STOCK':
        return const StatusBadge(
          label: 'In Stock',
          type: BadgeType.inStock,
          icon: Icons.check_circle_outline,
        );
      case 'LOW_STOCK':
        return const StatusBadge(
          label: 'Low Stock',
          type: BadgeType.lowStock,
          icon: Icons.warning_amber_rounded,
        );
      case 'OUT_OF_STOCK':
      default:
        return const StatusBadge(
          label: 'Out of Stock',
          type: BadgeType.outOfStock,
          icon: Icons.highlight_off_rounded,
        );
    }
  }

  factory StatusBadge.role(String role) {
    return StatusBadge(
      label: role.toUpperCase(),
      type: BadgeType.role,
      icon: Icons.admin_panel_settings_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;

    switch (type) {
      case BadgeType.inStock:
        bg = isDark ? AppColors.inStock.withValues(alpha: 0.2) : AppColors.inStockBg;
        fg = AppColors.inStock;
        break;
      case BadgeType.lowStock:
        bg = isDark ? AppColors.lowStock.withValues(alpha: 0.2) : AppColors.lowStockBg;
        fg = AppColors.lowStock;
        break;
      case BadgeType.outOfStock:
        bg = isDark ? AppColors.outOfStock.withValues(alpha: 0.2) : AppColors.outOfStockBg;
        fg = AppColors.outOfStock;
        break;
      case BadgeType.role:
        bg = isDark ? AppColors.accent.withValues(alpha: 0.2) : AppColors.accent.withValues(alpha: 0.1);
        fg = isDark ? AppColors.accent : AppColors.accentHover;
        break;
      case BadgeType.status:
        bg = isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;
        fg = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        break;
      case BadgeType.custom:
        bg = customBg ?? AppColors.surfaceElevatedLight;
        fg = customFg ?? AppColors.textPrimaryLight;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppDimensions.borderRadiusPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: AppDimensions.space4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
