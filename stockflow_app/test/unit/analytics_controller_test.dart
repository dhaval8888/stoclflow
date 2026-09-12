import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_app/core/network/api_exceptions.dart';
import 'package:stockflow_app/features/analytics/application/analytics_controller.dart';
import 'package:stockflow_app/features/analytics/application/analytics_state.dart';
import 'package:stockflow_app/features/analytics/data/models/analytics_models.dart';
import 'package:stockflow_app/features/analytics/data/repositories/analytics_repository.dart';

class FakeAnalyticsRepository extends AnalyticsRepository {
  Exception? error;
  DashboardSummary? summaryToReturn;
  List<SalesTrendPoint> trendToReturn = [];
  ProfitReport? profitToReturn;

  FakeAnalyticsRepository() : super(Dio());

  @override
  Future<DashboardSummary> getSummary() async {
    if (error != null) throw error!;
    return summaryToReturn ??
        const DashboardSummary(
          todaySales: 15,
          todayRevenue: 1250.50,
          weekSales: 80,
          weekRevenue: 6400.0,
          monthSales: 320,
          monthRevenue: 25000.0,
          totalSales: 1200,
          totalRevenue: 95000.0,
          totalProducts: 45,
          activeProducts: 42,
          lowStockCount: 3,
          outOfStockCount: 1,
          recentSales: [],
        );
  }

  @override
  Future<List<SalesTrendPoint>> getSalesTrend(int days) async {
    if (error != null) throw error!;
    return trendToReturn;
  }

  @override
  Future<ProfitReport> getProfitReport(int days) async {
    if (error != null) throw error!;
    return profitToReturn ??
        const ProfitReport(
          days: 30,
          totalRevenue: 5000.0,
          totalCost: 3200.0,
          estimatedGrossProfit: 1800.0,
          totalDiscounts: 50.0,
          totalSales: 120,
          totalUnitsSold: 350.0,
        );
  }
}

void main() {
  group('Analytics & Dashboard Controllers Unit Tests', () {
    late FakeAnalyticsRepository repo;

    setUp(() {
      repo = FakeAnalyticsRepository();
    });

    test('DashboardController loads summary successfully', () async {
      final controller = DashboardController(repo);
      await Future.delayed(Duration.zero);

      expect(controller.state.status, AnalyticsLoadStatus.loaded);
      expect(controller.state.summary?.todaySales, 15);
      expect(controller.state.summary?.todayRevenue, 1250.50);
      expect(controller.state.summary?.lowStockCount, 3);
    });

    test('DashboardController handles API error cleanly', () async {
      repo.error = const ApiException(message: 'Failed to connect', statusCode: 503);
      final controller = DashboardController(repo);
      await Future.delayed(Duration.zero);

      expect(controller.state.status, AnalyticsLoadStatus.error);
      expect(controller.state.errorMessage, 'Failed to connect');
    });

    test('AnalyticsSalesController changes period and updates state', () async {
      repo.trendToReturn = [
        SalesTrendPoint(
          date: DateTime.now(),
          salesCount: 5,
          revenue: 250.0,
          discounts: 10.0,
        ),
      ];
      final controller = AnalyticsSalesController(repo);
      await Future.delayed(Duration.zero);

      expect(controller.state.status, AnalyticsLoadStatus.loaded);
      expect(controller.state.selectedDays, 30);
      expect(controller.state.trend.length, 1);

      // Change period to 7 days
      await controller.load(7);
      expect(controller.state.selectedDays, 7);
      expect(controller.state.status, AnalyticsLoadStatus.loaded);
    });

    test('AnalyticsProfitController computes profit metrics correctly', () async {
      final controller = AnalyticsProfitController(repo);
      await Future.delayed(Duration.zero);

      expect(controller.state.status, AnalyticsLoadStatus.loaded);
      expect(controller.state.report?.totalRevenue, 5000.0);
      expect(controller.state.report?.estimatedGrossProfit, 1800.0);
      expect(controller.state.report?.grossMarginPercent, 36.0);
    });

    test('DashboardSummary parses all profit metrics from JSON correctly', () {
      final json = {
        'sales': {
          'today_sales': 3,
          'today_revenue': '150.00',
          'today_profit': '45.50',
          'week_sales': 12,
          'week_revenue': '600.00',
          'week_profit': '180.25',
          'month_sales': 50,
          'month_revenue': '2500.00',
          'month_profit': '750.00',
          'total_sales': 150,
          'total_revenue': '7500.00',
          'total_profit': '2250.00',
        },
        'products': {'total_products': 10, 'active_products': 8},
        'alerts': {'low_stock_count': 1, 'out_of_stock_count': 0},
        'recentSales': [],
      };

      final summary = DashboardSummary.fromJson(json);
      expect(summary.todayProfit, 45.50);
      expect(summary.weekProfit, 180.25);
      expect(summary.monthProfit, 750.00);
      expect(summary.totalProfit, 2250.00);
      expect(summary.totalRevenue, 7500.00);
    });

    test('SalesTrendPoint parses profit from JSON correctly', () {
      final json = {
        'date': '2026-09-12',
        'sales_count': 4,
        'revenue': '300.00',
        'profit': '90.50',
        'total_discounts': '10.00',
      };

      final point = SalesTrendPoint.fromJson(json);
      expect(point.profit, 90.50);
      expect(point.revenue, 300.00);
      expect(point.salesCount, 4);
    });
  });
}
