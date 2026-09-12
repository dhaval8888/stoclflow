import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/state_views.dart';
import '../../application/analytics_controller.dart';
import '../../application/analytics_state.dart';
import '../../data/models/analytics_models.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Sales'),
                Tab(text: 'Products'),
                Tab(text: 'Profit'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _SalesTab(),
                _ProductsTab(),
                _ProfitTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sales Tab ─────────────────────────────────────────────────────────────────

class _SalesTab extends ConsumerWidget {
  const _SalesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsSalesControllerProvider);
    final ctrl = ref.read(analyticsSalesControllerProvider.notifier);

    return RefreshIndicator(
      onRefresh: () async => ctrl.load(state.selectedDays),
      child: ListView(
        padding: const EdgeInsets.all(AppDimensions.space16),
        children: [
          _DayFilter(
            selected: state.selectedDays,
            onChanged: ctrl.load,
          ),
          const SizedBox(height: AppDimensions.space16),
          if (state.isLoading)
            const _TabLoading()
          else if (state.status == AnalyticsLoadStatus.error)
            ErrorStateView(
              message: state.errorMessage ?? 'Failed to load sales trend',
              onRetry: () => ctrl.load(state.selectedDays),
            )
          else if (state.isEmpty)
            const EmptyStateView(
              icon: Icons.bar_chart_outlined,
              title: 'No sales data',
              subtitle: 'No completed sales found for this period.',
            )
          else
            _SalesTrendSection(trend: state.trend, days: state.selectedDays),
        ],
      ),
    );
  }
}

class _SalesTrendSection extends StatelessWidget {
  final List<SalesTrendPoint> trend;
  final int days;

  const _SalesTrendSection({required this.trend, required this.days});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    // Summary statistics
    final totalRevenue = trend.fold(0.0, (sum, p) => sum + p.revenue);
    final totalSales = trend.fold(0, (sum, p) => sum + p.salesCount);
    final totalProfit = trend.fold(0.0, (sum, p) => sum + p.profit);
    final avgDaily = trend.isEmpty ? 0.0 : totalRevenue / trend.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary row
        _SummaryCard(
          children: [
            _MetricCell(label: 'Total Sales', value: '$totalSales'),
            _MetricCell(label: 'Total Revenue', value: CurrencyFormatter.amount(totalRevenue)),
            _MetricCell(label: 'Total Profit', value: CurrencyFormatter.amount(totalProfit)),
            _MetricCell(label: 'Avg / Day', value: CurrencyFormatter.amount(avgDaily)),
          ],
        ),
        const SizedBox(height: AppDimensions.space20),

        // Revenue line chart
        Text(
          'Revenue Trend ($days days)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppDimensions.space12),
        _RevenueLineChart(trend: trend),
        const SizedBox(height: AppDimensions.space20),

        // Data table
        Text(
          'Daily Breakdown',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppDimensions.space8),
        _TrendTable(trend: trend, isDark: isDark, textSecondary: textSecondary),
      ],
    );
  }
}

class _RevenueLineChart extends StatelessWidget {
  final List<SalesTrendPoint> trend;

  const _RevenueLineChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxY = trend.map((p) => p.revenue).reduce((a, b) => a > b ? a : b);
    final spots = trend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.revenue);
    }).toList();

    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        borderRadius: AppDimensions.borderRadiusMd,
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      ),
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY * 1.15,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 4 : 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: isDark
                  ? AppColors.borderDark.withValues(alpha: 0.5)
                  : AppColors.borderLight,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    CurrencyFormatter.compact(value),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (trend.length / 5).ceil().toDouble().clamp(1, double.infinity),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('d/M').format(trend[idx].date),
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.accent,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.accent.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendTable extends StatelessWidget {
  final List<SalesTrendPoint> trend;
  final bool isDark;
  final Color textSecondary;

  const _TrendTable({
    required this.trend,
    required this.isDark,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: AppDimensions.space8,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDimensions.radiusMd),
                topRight: Radius.circular(AppDimensions.radiusMd),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary))),
                SizedBox(width: 45, child: Text('Sales', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary), textAlign: TextAlign.right)),
                SizedBox(width: 75, child: Text('Revenue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary), textAlign: TextAlign.right)),
                SizedBox(width: 75, child: Text('Profit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary), textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Rows — most recent first
          for (int i = trend.length - 1; i >= 0; i--) ...[
            if (i < trend.length - 1) const Divider(height: 1),
            _TrendRow(point: trend[i], isDark: isDark, textSecondary: textSecondary),
          ],
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  final SalesTrendPoint point;
  final bool isDark;
  final Color textSecondary;

  const _TrendRow({required this.point, required this.isDark, required this.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('EEE, d MMM').format(point.date),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              '${point.salesCount}',
              style: TextStyle(fontSize: 13, color: textSecondary),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 75,
            child: Text(
              CurrencyFormatter.amount(point.revenue),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 75,
            child: Text(
              CurrencyFormatter.amount(point.profit),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF10B981),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Products Tab ───────────────────────────────────────────────────────────────

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsProductsControllerProvider);
    final ctrl = ref.read(analyticsProductsControllerProvider.notifier);

    return RefreshIndicator(
      onRefresh: () async => ctrl.load(state.selectedDays),
      child: ListView(
        padding: const EdgeInsets.all(AppDimensions.space16),
        children: [
          _DayFilter(
            selected: state.selectedDays,
            onChanged: ctrl.load,
          ),
          const SizedBox(height: AppDimensions.space16),
          if (state.isLoading)
            const _TabLoading()
          else if (state.topStatus == AnalyticsLoadStatus.error)
            ErrorStateView(
              message: state.errorMessage ?? 'Failed to load product analytics',
              onRetry: () => ctrl.load(state.selectedDays),
            )
          else ...[
            _TopProductsSection(
              products: state.topProducts,
              days: state.selectedDays,
            ),
            const SizedBox(height: AppDimensions.space24),
            _SlowProductsSection(
              products: state.slowProducts,
              days: state.selectedDays,
            ),
          ],
        ],
      ),
    );
  }
}

class _TopProductsSection extends StatelessWidget {
  final List<TopProduct> products;
  final int days;

  const _TopProductsSection({required this.products, required this.days});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Selling ($days days)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppDimensions.space12),
        if (products.isEmpty)
          const EmptyStateView(
            icon: Icons.emoji_events_outlined,
            title: 'No sales data',
            subtitle: 'No products sold in this period.',
          )
        else ...[
          _TopProductsBarChart(products: products),
          const SizedBox(height: AppDimensions.space12),
          _TopProductsTable(products: products, isDark: isDark),
        ],
      ],
    );
  }
}

class _TopProductsBarChart extends StatelessWidget {
  final List<TopProduct> products;

  const _TopProductsBarChart({required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayed = products.take(8).toList();
    final maxY = displayed.map((p) => p.totalQuantity).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 180,
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        borderRadius: AppDimensions.borderRadiusMd,
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          barTouchData: BarTouchData(enabled: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: isDark ? AppColors.borderDark.withValues(alpha: 0.5) : AppColors.borderLight,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    CurrencyFormatter.integer(value),
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= displayed.length) return const SizedBox.shrink();
                  final name = displayed[idx].productName;
                  final short = name.length > 6 ? '${name.substring(0, 5)}…' : name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      short,
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: displayed.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.totalQuantity,
                  color: AppColors.accent,
                  width: 14,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TopProductsTable extends StatelessWidget {
  final List<TopProduct> products;
  final bool isDark;

  const _TopProductsTable({required this.products, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Card(
      child: Column(
        children: [
          for (int i = 0; i < products.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space16,
                vertical: AppDimensions.space10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? AppColors.lowStock.withValues(alpha: 0.15)
                          : (isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: i == 0 ? AppColors.lowStock : textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: Text(
                      products[i].productName,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${products[i].totalQuantity.toStringAsFixed(0)} units',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SlowProductsSection extends StatelessWidget {
  final List<SlowProduct> products;
  final int days;

  const _SlowProductsSection({required this.products, required this.days});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Slow Moving ($days days)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppDimensions.space8),
        if (products.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppDimensions.space16),
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              borderRadius: AppDimensions.borderRadiusMd,
            ),
            child: const Center(
              child: Text('All products had activity in this period.', style: TextStyle(fontSize: 13)),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (int i = 0; i < products.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _SlowProductRow(p: products[i], isDark: isDark),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _SlowProductRow extends StatelessWidget {
  final SlowProduct p;
  final bool isDark;

  const _SlowProductRow({required this.p, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (p.categoryName != null)
                  Text(
                    p.categoryName!,
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
              ],
            ),
          ),
          Text(
            '${p.currentStock} in stock',
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Profit Tab ─────────────────────────────────────────────────────────────────

class _ProfitTab extends ConsumerWidget {
  const _ProfitTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsProfitControllerProvider);
    final ctrl = ref.read(analyticsProfitControllerProvider.notifier);

    return RefreshIndicator(
      onRefresh: () async => ctrl.load(state.selectedDays),
      child: ListView(
        padding: const EdgeInsets.all(AppDimensions.space16),
        children: [
          _DayFilter(
            selected: state.selectedDays,
            onChanged: ctrl.load,
          ),
          const SizedBox(height: AppDimensions.space16),
          if (state.isLoading)
            const _TabLoading()
          else if (state.status == AnalyticsLoadStatus.error)
            ErrorStateView(
              message: state.errorMessage ?? 'Failed to load profit report',
              onRetry: () => ctrl.load(state.selectedDays),
            )
          else if (state.report == null)
            const EmptyStateView(
              icon: Icons.show_chart_outlined,
              title: 'No profit data',
              subtitle: 'No completed sales in this period.',
            )
          else
            _ProfitSection(report: state.report!),
        ],
      ),
    );
  }
}

class _ProfitSection extends StatelessWidget {
  final ProfitReport report;
  const _ProfitSection({required this.report});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI summary
        _SummaryCard(
          children: [
            _MetricCell(label: 'Revenue', value: CurrencyFormatter.amount(report.totalRevenue)),
            _MetricCell(label: 'COGS', value: CurrencyFormatter.amount(report.totalCost)),
            _MetricCell(
              label: 'Gross Profit',
              value: CurrencyFormatter.amount(report.estimatedGrossProfit),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space16),

        // Detailed breakdown
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Breakdown — last ${report.days} days',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: AppDimensions.space16),
                _ProfitRow(
                  label: 'Total Revenue',
                  value: CurrencyFormatter.amount(report.totalRevenue),
                  isDark: isDark,
                ),
                _ProfitRow(
                  label: 'Cost of Goods Sold',
                  value: '− ${CurrencyFormatter.amount(report.totalCost)}',
                  isDark: isDark,
                  negative: true,
                ),
                _ProfitRow(
                  label: 'Discounts Given',
                  value: '− ${CurrencyFormatter.amount(report.totalDiscounts)}',
                  isDark: isDark,
                  negative: true,
                ),
                const Divider(height: AppDimensions.space24),
                _ProfitRow(
                  label: 'Est. Gross Profit',
                  value: CurrencyFormatter.amount(report.estimatedGrossProfit),
                  isDark: isDark,
                  highlighted: true,
                  profitValue: report.estimatedGrossProfit,
                ),
                const SizedBox(height: AppDimensions.space8),
                _ProfitRow(
                  label: 'Gross Margin',
                  value: CurrencyFormatter.percentDirect(report.grossMarginPercent),
                  isDark: isDark,
                ),
                _ProfitRow(
                  label: 'Total Sales',
                  value: '${report.totalSales} transactions',
                  isDark: isDark,
                ),
                _ProfitRow(
                  label: 'Units Sold',
                  value: report.totalUnitsSold.toStringAsFixed(0),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.space12),
        Container(
          padding: const EdgeInsets.all(AppDimensions.space12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
            borderRadius: AppDimensions.borderRadiusMd,
          ),
          child: Text(
            'Estimated profit uses product cost prices at the time of sale. Overhead and operational expenses are not included.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfitRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool negative;
  final bool highlighted;
  final double profitValue;

  const _ProfitRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.negative = false,
    this.highlighted = false,
    this.profitValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: highlighted ? textPrimary : textSecondary,
                fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
              color: highlighted
                  ? (profitValue >= 0 ? AppColors.inStock : AppColors.outOfStock)
                  : (negative ? AppColors.outOfStock : textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ────────────────────────────────────────────────────────────

class _DayFilter extends StatelessWidget {
  final int selected;
  final void Function(int) onChanged;

  const _DayFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [7, 30, 90].map((days) {
        final isSelected = selected == days;
        return Padding(
          padding: const EdgeInsets.only(right: AppDimensions.space8),
          child: ChoiceChip(
            label: Text('${days}d'),
            selected: isSelected,
            onSelected: (_) => onChanged(days),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.white : null,
            ),
            selectedColor: AppColors.accent,
          ),
        );
      }).toList(),
    );
  }
}

class _TabLoading extends StatelessWidget {
  const _TabLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<_MetricCell> children;
  const _SummaryCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space12,
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            cell.value,
                            style: TextStyle(
                              fontSize: children.length > 3 ? 14 : 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        Text(
                          cell.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    VerticalDivider(
                      thickness: 1,
                      width: AppDimensions.space12,
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

class _MetricCell {
  final String label;
  final String value;
  const _MetricCell({required this.label, required this.value});
}
