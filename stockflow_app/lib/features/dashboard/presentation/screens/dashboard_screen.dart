import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../analytics/application/analytics_controller.dart';
import '../../../analytics/data/models/analytics_models.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final isCashier = user?.isCashier ?? true;

    if (isCashier) {
      return const _CashierDashboard();
    }
    return const _ManagerDashboard();
  }
}

// ─── Owner / Manager Dashboard ─────────────────────────────────────────────────

class _ManagerDashboard extends ConsumerWidget {
  const _ManagerDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final user = ref.watch(authControllerProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return RefreshIndicator(
      onRefresh: () => ref.read(dashboardControllerProvider.notifier).refresh(),
      child: Builder(
        builder: (context) {
          if (state.isLoading && state.summary == null) {
            return const LoadingView(message: 'Loading dashboard...');
          }
          if (state.hasError && state.summary == null) {
            return ErrorStateView(
              message: state.errorMessage ?? 'Failed to load dashboard',
              onRetry: () => ref.read(dashboardControllerProvider.notifier).refresh(),
            );
          }

          final s = state.summary;

          return ListView(
            padding: const EdgeInsets.all(AppDimensions.space16),
            children: [
              // ── Header ──────────────────────────────────────────
              _Header(
                greeting: _greeting(),
                name: user?.fullName ?? 'User',
                subtitle: DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
              ),
              const SizedBox(height: AppDimensions.space20),

              // ── Today's KPIs ─────────────────────────────────────
              _SectionLabel('TODAY'),
              const SizedBox(height: AppDimensions.space8),
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      label: 'Sales',
                      value: '${s?.todaySales ?? 0}',
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: _KpiCard(
                      label: 'Revenue',
                      value: s != null ? CurrencyFormatter.amount(s.todayRevenue) : '—',
                      icon: Icons.paid_outlined,
                      color: AppColors.inStock,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space12),
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      label: "Today's Profit",
                      value: s != null ? CurrencyFormatter.amount(s.todayProfit) : '—',
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: _KpiCard(
                      label: 'Total Profit',
                      value: s != null ? CurrencyFormatter.amount(s.totalProfit) : '—',
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFF06B6D4),
                      onTap: () => context.go('/analytics'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space12),
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      label: 'Low Stock',
                      value: '${s?.lowStockCount ?? 0}',
                      icon: Icons.warning_amber_outlined,
                      color: AppColors.lowStock,
                      onTap: () => context.go('/inventory'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: _KpiCard(
                      label: 'Out of Stock',
                      value: '${s?.outOfStockCount ?? 0}',
                      icon: Icons.remove_shopping_cart_outlined,
                      color: AppColors.outOfStock,
                      onTap: () => context.go('/inventory'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space20),

              // ── This Week ────────────────────────────────────────
              _SectionLabel('THIS WEEK'),
              const SizedBox(height: AppDimensions.space8),
              _SummaryRow(
                children: [
                  _SummaryCell(label: 'Sales', value: '${s?.weekSales ?? 0}'),
                  _SummaryCell(
                    label: 'Revenue',
                    value: s != null ? CurrencyFormatter.amount(s.weekRevenue) : '—',
                  ),
                  _SummaryCell(
                    label: 'Profit',
                    value: s != null ? CurrencyFormatter.amount(s.weekProfit) : '—',
                  ),
                  _SummaryCell(
                    label: 'Products',
                    value: '${s?.activeProducts ?? 0}',
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space20),

              // ── All-Time Overview ────────────────────────────────
              _SectionLabel('ALL-TIME OVERVIEW'),
              const SizedBox(height: AppDimensions.space8),
              _SummaryRow(
                children: [
                  _SummaryCell(label: 'Total Sales', value: '${s?.totalSales ?? 0}'),
                  _SummaryCell(
                    label: 'Total Revenue',
                    value: s != null ? CurrencyFormatter.amount(s.totalRevenue) : '—',
                  ),
                  _SummaryCell(
                    label: 'Total Profit',
                    value: s != null ? CurrencyFormatter.amount(s.totalProfit) : '—',
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space20),

              // ── Quick Actions ─────────────────────────────────────
              _SectionLabel('QUICK ACTIONS'),
              const SizedBox(height: AppDimensions.space8),
              Wrap(
                spacing: AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: [
                  _ActionChip(
                    label: 'New Sale',
                    icon: Icons.add_shopping_cart_outlined,
                    onTap: () => context.go('/sales'),
                  ),
                  _ActionChip(
                    label: 'Add Product',
                    icon: Icons.inventory_2_outlined,
                    onTap: () => context.go('/products/new'),
                  ),
                  _ActionChip(
                    label: 'Inventory',
                    icon: Icons.warehouse_outlined,
                    onTap: () => context.go('/inventory'),
                  ),
                  _ActionChip(
                    label: 'Analytics',
                    icon: Icons.bar_chart_outlined,
                    onTap: () => context.go('/analytics'),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space20),

              // ── Recent Sales ─────────────────────────────────────
              if (s != null && s.recentSales.isNotEmpty) ...[
                _SectionLabel('RECENT SALES'),
                const SizedBox(height: AppDimensions.space8),
                _RecentSalesList(sales: s.recentSales),
                const SizedBox(height: AppDimensions.space20),
              ],

              if (state.hasError && s != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space12),
                  child: Text(
                    'Could not refresh: ${state.errorMessage}',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ─── Cashier Dashboard ──────────────────────────────────────────────────────

class _CashierDashboard extends ConsumerWidget {
  const _CashierDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.space16),
      children: [
        // ── Header ────────────────────────────────────────────
        _Header(
          greeting: _greeting(),
          name: user?.fullName ?? 'User',
          subtitle: DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
        ),
        const SizedBox(height: AppDimensions.space20),

        // ── Primary Action ─────────────────────────────────────
        Card(
          child: InkWell(
            onTap: () => context.go('/sales'),
            borderRadius: AppDimensions.borderRadiusMd,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.space20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: AppDimensions.borderRadiusMd,
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Sale',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          'Scan barcode or add products to cart',
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: textMuted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.space12),

        // ── Other Shortcuts ────────────────────────────────────
        Card(
          child: Column(
            children: [
              _CashierTile(
                icon: Icons.inventory_2_outlined,
                label: 'Browse Products',
                subtitle: 'Search and view product catalogue',
                onTap: () => context.go('/products'),
              ),
              const Divider(height: 1),
              _CashierTile(
                icon: Icons.receipt_long_outlined,
                label: 'Sales History',
                subtitle: 'View your recent transactions',
                onTap: () => context.go('/sales'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.space20),

        // ── Info Note ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(AppDimensions.space12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
            borderRadius: AppDimensions.borderRadiusMd,
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: textMuted),
              const SizedBox(width: AppDimensions.space8),
              Expanded(
                child: Text(
                  'Business analytics and reports are available to managers and owners only.',
                  style: TextStyle(fontSize: 12, color: textMuted, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ─── Shared Widgets ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String greeting;
  final String name;
  final String subtitle;

  const _Header({
    required this.greeting,
    required this.name,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $name',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppDimensions.space2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimensions.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.space8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: AppDimensions.space2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<_SummaryCell> children;
  const _SummaryRow({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.space12,
          horizontal: AppDimensions.space16,
        ),
        child: Row(
          children: children.map((cell) {
            final isLast = cell == children.last;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cell.value,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          cell.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    VerticalDivider(
                      thickness: 1,
                      width: AppDimensions.space24,
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SummaryCell {
  final String label;
  final String value;
  const _SummaryCell({required this.label, required this.value});
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space8,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: AppDimensions.space6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSalesList extends StatelessWidget {
  final List<RecentSaleItem> sales;
  const _RecentSalesList({required this.sales});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Column(
        children: [
          for (int i = 0; i < sales.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _RecentSaleRow(sale: sales[i], isDark: isDark),
          ],
        ],
      ),
    );
  }
}

class _RecentSaleRow extends StatelessWidget {
  final RecentSaleItem sale;
  final bool isDark;

  const _RecentSaleRow({required this.sale, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final timeStr = sale.createdAt != null
        ? DateFormat('HH:mm').format(sale.createdAt!.toLocal())
        : '—';
    final dateStr = sale.createdAt != null
        ? DateFormat('d MMM').format(sale.createdAt!.toLocal())
        : '';

    return InkWell(
      onTap: () => context.push('/sales/receipt/${sale.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.cashierName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    '${sale.itemCount} item${sale.itemCount != 1 ? 's' : ''} · ${sale.paymentMethod}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.amount(sale.totalAmount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  '$dateStr $timeStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CashierTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _CashierTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}
