import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(dioProvider));
});

class AnalyticsRepository {
  final Dio _dio;

  AnalyticsRepository(this._dio);

  Future<DashboardSummary> getSummary() async {
    try {
      final res = await _dio.get(ApiEndpoints.analyticsSummary);
      if (res.data['success'] == true) {
        return DashboardSummary.fromJson(res.data['data'] as Map<String, dynamic>);
      }
      throw ApiException(message: res.data['message'] ?? 'Failed to load summary');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<SalesTrendPoint>> getSalesTrend(int days) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.analyticsSalesTrend,
        queryParameters: {'days': days},
      );
      if (res.data['success'] == true) {
        final raw = res.data['data']['trend'] as List<dynamic>? ?? [];
        return raw.map((e) => SalesTrendPoint.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw ApiException(message: res.data['message'] ?? 'Failed to load sales trend');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<TopProduct>> getTopProducts(int days, {int limit = 10}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.analyticsTopProducts,
        queryParameters: {'days': days, 'limit': limit},
      );
      if (res.data['success'] == true) {
        final raw = res.data['data']['products'] as List<dynamic>? ?? [];
        return raw.map((e) => TopProduct.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw ApiException(message: res.data['message'] ?? 'Failed to load top products');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<SlowProduct>> getSlowProducts(int days) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.analyticsSlowProducts,
        queryParameters: {'days': days},
      );
      if (res.data['success'] == true) {
        final raw = res.data['data']['products'] as List<dynamic>? ?? [];
        return raw.map((e) => SlowProduct.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw ApiException(message: res.data['message'] ?? 'Failed to load slow products');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ProfitReport> getProfitReport(int days) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.analyticsProfit,
        queryParameters: {'days': days},
      );
      if (res.data['success'] == true) {
        final data = res.data['data'] as Map<String, dynamic>;
        final reportDays = int.tryParse(data['days']?.toString() ?? '$days') ?? days;
        return ProfitReport.fromJson(data, days: reportDays);
      }
      throw ApiException(message: res.data['message'] ?? 'Failed to load profit report');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<PeriodReportPoint>> getReportByPeriod(String period) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.analyticsReport,
        queryParameters: {'period': period},
      );
      if (res.data['success'] == true) {
        final raw = res.data['data']['report'] as List<dynamic>? ?? [];
        return raw.map((e) => PeriodReportPoint.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw ApiException(message: res.data['message'] ?? 'Failed to load period report');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
