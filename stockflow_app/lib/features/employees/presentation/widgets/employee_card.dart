import 'package:flutter/material.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/models/employee_model.dart';

class EmployeeCard extends StatelessWidget {
  final EmployeeModel employee;
  final bool isCurrentUser;
  final ValueChanged<String>? onRoleChangeRequested;
  final VoidCallback? onDeactivateRequested;

  const EmployeeCard({
    super.key,
    required this.employee,
    this.isCurrentUser = false,
    this.onRoleChangeRequested,
    this.onDeactivateRequested,
  });

  Color _avatarBg(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return AppColors.primary;
      case 'MANAGER':
        return AppColors.info;
      case 'CASHIER':
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.space12),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Initials Avatar with online/active indicator
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _avatarBg(employee.role),
                  child: Text(
                    employee.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: employee.isActive ? AppColors.success : AppColors.textMutedLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppDimensions.space12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          employee.fullName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: AppDimensions.space6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: AppDimensions.borderRadiusPill,
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space2),
                  Text(
                    employee.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                  if (employee.phone != null && employee.phone!.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.space2),
                    Text(
                      employee.phone!,
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.space8),
                  Wrap(
                    spacing: AppDimensions.space8,
                    runSpacing: AppDimensions.space4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBadge.role(employee.role),
                      if (!employee.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: AppDimensions.borderRadiusPill,
                          ),
                          child: const Text(
                            'Deactivated',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions Menu (Owner only can modify non-owner members)
            if (!isCurrentUser && !employee.isOwner && employee.isActive)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20, color: textSecondary),
                onSelected: (action) {
                  if (action == 'role') {
                    _showRoleDialog(context);
                  } else if (action == 'deactivate') {
                    _confirmDeactivation(context);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'role',
                    child: Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, size: 18),
                        const SizedBox(width: AppDimensions.space8),
                        Text(
                          employee.isManager ? 'Change to Cashier' : 'Promote to Manager',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: Row(
                      children: [
                        Icon(Icons.person_off_outlined, size: 18, color: AppColors.error),
                        SizedBox(width: AppDimensions.space8),
                        Text(
                          'Deactivate Employee',
                          style: TextStyle(fontSize: 13, color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showRoleDialog(BuildContext context) {
    final targetRole = employee.isManager ? 'CASHIER' : 'MANAGER';
    ConfirmDialog.show(
      context: context,
      title: 'Change Role',
      message:
          'Are you sure you want to change ${employee.fullName}\'s role to $targetRole?',
      confirmText: 'Change to $targetRole',
    ).then((confirmed) {
      if (confirmed == true) {
        onRoleChangeRequested?.call(targetRole);
      }
    });
  }

  void _confirmDeactivation(BuildContext context) {
    ConfirmDialog.show(
      context: context,
      title: 'Deactivate Employee',
      message:
          'Are you sure you want to deactivate ${employee.fullName}? They will no longer be able to log in.',
      confirmText: 'Deactivate',
      isDestructive: true,
    ).then((confirmed) {
      if (confirmed == true) {
        onDeactivateRequested?.call();
      }
    });
  }
}
