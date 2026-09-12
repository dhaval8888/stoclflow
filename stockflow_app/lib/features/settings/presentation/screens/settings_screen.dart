import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/business_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final businessState = ref.watch(businessControllerProvider);

    final initialLetter = (user != null && user.fullName.isNotEmpty)
        ? user.fullName[0].toUpperCase()
        : 'U';
    final isOwner = user?.isOwner ?? false;
    final isManagerOrOwner = (user?.isOwner ?? false) || (user?.isManager ?? false);

    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.space20),
        children: [
          // ─── 1. Profile Header Card ─────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.space16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      initialLetter,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'User',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space2),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space8),
                        StatusBadge.role(user?.role ?? 'CASHIER'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space24),

          // ─── 2. Business Details ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BUSINESS DETAILS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: textMuted,
                ),
              ),
              if (isOwner)
                TextButton(
                  onPressed: () => context.push('/settings/business'),
                  child: const Text('Edit Profile', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.space4),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.store_outlined, size: 20),
                  title: const Text('Business Name', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    businessState.business?.name ?? user?.businessName ?? 'StockFlow Store',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  trailing: isOwner
                      ? const Icon(Icons.chevron_right_rounded, size: 20)
                      : null,
                  onTap: isOwner ? () => context.push('/settings/business') : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.currency_exchange_rounded, size: 20),
                  title: const Text('Default Currency', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    businessState.business?.currency ?? 'USD',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (businessState.business?.phone != null &&
                    businessState.business!.phone!.isNotEmpty) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined, size: 20),
                    title: const Text('Contact Phone', style: TextStyle(fontSize: 14)),
                    subtitle: Text(
                      businessState.business!.phone!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space24),

          // ─── 3. Management & Tools ──────────────────────────────────────────
          if (isManagerOrOwner) ...[
            Text(
              'MANAGEMENT & TOOLS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: textMuted,
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            Card(
              child: Column(
                children: [
                  if (isOwner) ...[
                    ListTile(
                      leading: const Icon(Icons.people_outline_rounded, size: 20, color: AppColors.primary),
                      title: const Text('Team Management', style: TextStyle(fontSize: 14)),
                      subtitle: const Text(
                        'Add and manage cashiers and managers',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: () => context.push('/employees'),
                    ),
                    const Divider(height: 1),
                  ],
                  ListTile(
                    leading: const Icon(Icons.analytics_outlined, size: 20, color: AppColors.accent),
                    title: const Text('Business Analytics', style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                      'Revenue trends, top products, and estimated profit',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => context.push('/analytics'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.space24),
          ],

          // ─── 4. Appearance / Theme ──────────────────────────────────────────
          Text(
            'APPEARANCE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textMuted,
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space16,
                vertical: AppDimensions.space12,
              ),
              child: Row(
                children: [
                  const Icon(Icons.palette_outlined, size: 20),
                  const SizedBox(width: AppDimensions.space16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Theme', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('Choose your preferred theme mode', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto, size: 16),
                        tooltip: 'System',
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 16),
                        tooltip: 'Light',
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 16),
                        tooltip: 'Dark',
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selected) {
                      ref.read(themeModeProvider.notifier).setTheme(selected.first);
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space32),

          // ─── 5. Sign Out ────────────────────────────────────────────────────
          AppButton(
            text: 'Sign Out',
            variant: AppButtonVariant.destructive,
            icon: Icons.logout_rounded,
            onPressed: () async {
              final confirmed = await ConfirmDialog.show(
                context: context,
                title: 'Sign Out',
                message: 'Are you sure you want to sign out of this account?',
                confirmText: 'Sign Out',
                isDestructive: true,
              );
              if (confirmed == true) {
                ref.read(authControllerProvider.notifier).logout();
              }
            },
          ),
          const SizedBox(height: AppDimensions.space24),
        ],
      ),
    );
  }
}
