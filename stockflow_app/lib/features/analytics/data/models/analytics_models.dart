/// Dashboard summary from GET /analytics/summary
/// Available to: OWNER, MANAGER
class DashboardSummary {
  final int todaySales;
  final double todayRevenue;
  final double todayProfit;
  final int weekSales;
  final double weekRevenue;
  final double weekProfit;
  final int monthSales;
  final double monthRevenue;
  final double monthProfit;
  final int totalSales;
  final double totalRevenue;
  final double totalProfit;

  final int totalProducts;
  final int activeProducts;

  final int lowStockCount;
  final int outOfStockCount;

  final List<RecentSaleItem> recentSales;

  const DashboardSummary({
    required this.todaySales,
    required this.todayRevenue,
    this.todayProfit = 0.0,
    required this.weekSales,
    required this.weekRevenue,
    this.weekProfit = 0.0,
    required this.monthSales,
    required this.monthRevenue,
    this.monthProfit = 0.0,
    required this.totalSales,
    required this.totalRevenue,
    this.totalProfit = 0.0,
    required this.totalProducts,
    required this.activeProducts,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.recentSales,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final sales = json['sales'] as Map<String, dynamic>? ?? {};
    final products = json['products'] as Map<String, dynamic>? ?? {};
    final alerts = json['alerts'] as Map<String, dynamic>? ?? {};
    final recentRaw = json['recentSales'] as List<dynamic>? ?? [];

    return DashboardSummary(
      todaySales: int.tryParse(sales['today_sales']?.toString() ?? '0') ?? 0,
      todayRevenue: double.tryParse(sales['today_revenue']?.toString() ?? '0') ?? 0.0,
      todayProfit: double.tryParse(sales['today_profit']?.toString() ?? '0') ?? 0.0,
      weekSales: int.tryParse(sales['week_sales']?.toString() ?? '0') ?? 0,
      weekRevenue: double.tryParse(sales['week_revenue']?.toString() ?? '0') ?? 0.0,
      weekProfit: double.tryParse(sales['week_profit']?.toString() ?? '0') ?? 0.0,
      monthSales: int.tryParse(sales['month_sales']?.toString() ?? '0') ?? 0,
      monthRevenue: double.tryParse(sales['month_revenue']?.toString() ?? '0') ?? 0.0,
      monthProfit: double.tryParse(sales['month_profit']?.toString() ?? '0') ?? 0.0,
      totalSales: int.tryParse(sales['total_sales']?.toString() ?? '0') ?? 0,
      totalRevenue: double.tryParse(sales['total_revenue']?.toString() ?? '0') ?? 0.0,
      totalProfit: double.tryParse(sales['total_profit']?.toString() ?? '0') ?? 0.0,
      totalProducts: int.tryParse(products['total_products']?.toString() ?? '0') ?? 0,
      activeProducts: int.tryParse(products['active_products']?.toString() ?? '0') ?? 0,
      lowStockCount: int.tryParse(alerts['low_stock_count']?.toString() ?? '0') ?? 0,
      outOfStockCount: int.tryParse(alerts['out_of_stock_count']?.toString() ?? '0') ?? 0,
      recentSales: recentRaw
          .map((e) => RecentSaleItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RecentSaleItem {
  final String id;
  final double totalAmount;
  final String paymentMethod;
  final String status;
  final DateTime? createdAt;
  final int itemCount;
  final String cashierName;

  const RecentSaleItem({
    required this.id,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
    this.createdAt,
    required this.itemCount,
    required this.cashierName,
  });

  factory RecentSaleItem.fromJson(Map<String, dynamic> json) {
    return RecentSaleItem(
      id: (json['id'] ?? '') as String,
      totalAmount: double.tryParse((json['total_amount'] ?? '0').toString()) ?? 0.0,
      paymentMethod: (json['payment_method'] ?? 'CASH') as String,
      status: (json['status'] ?? 'COMPLETED') as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      itemCount: int.tryParse((json['item_count'] ?? '0').toString()) ?? 0,
      cashierName: (json['cashier_name'] ?? 'Unknown') as String,
    );
  }
}

/// A single day's data from GET /analytics/sales-trend
class SalesTrendPoint {
  final DateTime date;
  final int salesCount;
  final double revenue;
  final double profit;
  final double discounts;

  const SalesTrendPoint({
    required this.date,
    required this.salesCount,
    required this.revenue,
    this.profit = 0.0,
    required this.discounts,
  });

  factory SalesTrendPoint.fromJson(Map<String, dynamic> json) {
    return SalesTrendPoint(
      date: DateTime.tryParse(json['date'].toString()) ?? DateTime.now(),
      salesCount: int.tryParse((json['sales_count'] ?? '0').toString()) ?? 0,
      revenue: double.tryParse((json['revenue'] ?? '0').toString()) ?? 0.0,
      profit: double.tryParse((json['profit'] ?? '0').toString()) ?? 0.0,
      discounts: double.tryParse((json['total_discounts'] ?? '0').toString()) ?? 0.0,
    );
  }
}

/// Top-selling product from GET /analytics/top-products
class TopProduct {
  final String productId;
  final String productName;
  final double totalQuantity;
  final double totalRevenue;
  final int saleCount;

  const TopProduct({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.saleCount,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      productId: (json['product_id'] ?? '') as String,
      productName: (json['product_name'] ?? 'Unknown') as String,
      totalQuantity: double.tryParse((json['total_quantity'] ?? '0').toString()) ?? 0.0,
      totalRevenue: double.tryParse((json['total_revenue'] ?? '0').toString()) ?? 0.0,
      saleCount: int.tryParse((json['sale_count'] ?? '0').toString()) ?? 0,
    );
  }
}

/// Slow-moving product from GET /analytics/slow-products
class SlowProduct {
  final String id;
  final String name;
  final String? sku;
  final String? categoryName;
  final int currentStock;
  final int unitsSoldInPeriod;
  final int lowStockThreshold;

  const SlowProduct({
    required this.id,
    required this.name,
    this.sku,
    this.categoryName,
    required this.currentStock,
    required this.unitsSoldInPeriod,
    required this.lowStockThreshold,
  });

  factory SlowProduct.fromJson(Map<String, dynamic> json) {
    return SlowProduct(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? 'Unknown') as String,
      sku: json['sku'] as String?,
      categoryName: json['category_name'] as String?,
      currentStock: int.tryParse((json['current_stock'] ?? '0').toString()) ?? 0,
      unitsSoldInPeriod: int.tryParse((json['units_sold_in_period'] ?? '0').toString()) ?? 0,
      lowStockThreshold: int.tryParse((json['low_stock_threshold'] ?? '10').toString()) ?? 10,
    );
  }
}

/// Profit report from GET /analytics/profit
class ProfitReport {
  final int days;
  final double totalRevenue;
  final double totalCost;
  final double estimatedGrossProfit;
  final double totalDiscounts;
  final int totalSales;
  final double totalUnitsSold;

  const ProfitReport({
    required this.days,
    required this.totalRevenue,
    required this.totalCost,
    required this.estimatedGrossProfit,
    required this.totalDiscounts,
    required this.totalSales,
    required this.totalUnitsSold,
  });

  double get grossMarginPercent {
    if (totalRevenue <= 0) return 0.0;
    return (estimatedGrossProfit / totalRevenue) * 100;
  }

  factory ProfitReport.fromJson(Map<String, dynamic> json, {int days = 30}) {
    return ProfitReport(
      days: days,
      totalRevenue: double.tryParse((json['total_revenue'] ?? '0').toString()) ?? 0.0,
      totalCost: double.tryParse((json['total_cost'] ?? '0').toString()) ?? 0.0,
      estimatedGrossProfit:
          double.tryParse((json['estimated_gross_profit'] ?? '0').toString()) ?? 0.0,
      totalDiscounts: double.tryParse((json['total_discounts'] ?? '0').toString()) ?? 0.0,
      totalSales: int.tryParse((json['total_sales'] ?? '0').toString()) ?? 0,
      totalUnitsSold: double.tryParse((json['total_units_sold'] ?? '0').toString()) ?? 0.0,
    );
  }
}

/// Period report point from GET /analytics/report
class PeriodReportPoint {
  final DateTime periodStart;
  final int salesCount;
  final double revenue;
  final double discounts;

  const PeriodReportPoint({
    required this.periodStart,
    required this.salesCount,
    required this.revenue,
    required this.discounts,
  });

  factory PeriodReportPoint.fromJson(Map<String, dynamic> json) {
    return PeriodReportPoint(
      periodStart: DateTime.tryParse(json['period_start'].toString()) ?? DateTime.now(),
      salesCount: int.tryParse((json['sales_count'] ?? '0').toString()) ?? 0,
      revenue: double.tryParse((json['revenue'] ?? '0').toString()) ?? 0.0,
      discounts: double.tryParse((json['discounts'] ?? '0').toString()) ?? 0.0,
    );
  }
}
