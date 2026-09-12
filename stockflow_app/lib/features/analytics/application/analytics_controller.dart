import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exceptions.dart';
import '../data/repositories/analytics_repository.dart';
import 'analytics_state.dart';

// ─── Dashboard Summary Controller ─────────────────────────────────────────────

final dashboardControllerProvider =
    StateNotifierProvider.autoDispose<DashboardController, DashboardState>((ref) {
  return DashboardController(ref.read(analyticsRepositoryProvider));
});

class DashboardController extends StateNotifier<DashboardState> {
  final AnalyticsRepository _repository;

  DashboardController(this._repository) : super(const DashboardState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: AnalyticsLoadStatus.loading, clearError: true);
    try {
      final summary = await _repository.getSummary();
      state = state.copyWith(summary: summary, status: AnalyticsLoadStatus.loaded);
    } catch (e) {
      state = state.copyWith(
        status: AnalyticsLoadStatus.error,
        errorMessage: ApiException.getErrorMessage(e),
      );
    }
  }

  Future<void> refresh() => load();
}

// ─── Sales Trend Controller ────────────────────────────────────────────────────

final analyticsSalesControllerProvider =
    StateNotifierProvider.autoDispose<AnalyticsSalesController, AnalyticsSalesState>((ref) {
  return AnalyticsSalesController(ref.read(analyticsRepositoryProvider));
});

class AnalyticsSalesController extends StateNotifier<AnalyticsSalesState> {
  final AnalyticsRepository _repository;

  AnalyticsSalesController(this._repository) : super(const AnalyticsSalesState()) {
    load(30);
  }

  Future<void> load(int days) async {
    state = state.copyWith(
      selectedDays: days,
      status: AnalyticsLoadStatus.loading,
      clearError: true,
    );
    try {
      final trend = await _repository.getSalesTrend(days);
      state = state.copyWith(trend: trend, status: AnalyticsLoadStatus.loaded);
    } catch (e) {
      state = state.copyWith(
        status: AnalyticsLoadStatus.error,
        errorMessage: ApiException.getErrorMessage(e),
      );
    }
  }
}

// ─── Products Analytics Controller ────────────────────────────────────────────

final analyticsProductsControllerProvider =
    StateNotifierProvider.autoDispose<AnalyticsProductsController, AnalyticsProductsState>(
        (ref) {
  return AnalyticsProductsController(ref.read(analyticsRepositoryProvider));
});

class AnalyticsProductsController extends StateNotifier<AnalyticsProductsState> {
  final AnalyticsRepository _repository;

  AnalyticsProductsController(this._repository) : super(const AnalyticsProductsState()) {
    load(30);
  }

  Future<void> load(int days) async {
    state = state.copyWith(
      selectedDays: days,
      topStatus: AnalyticsLoadStatus.loading,
      slowStatus: AnalyticsLoadStatus.loading,
      clearError: true,
    );
    try {
      final topFuture = _repository.getTopProducts(days);
      final slowFuture = _repository.getSlowProducts(days);
      final top = await topFuture;
      final slow = await slowFuture;
      state = state.copyWith(
        topProducts: top,
        slowProducts: slow,
        topStatus: AnalyticsLoadStatus.loaded,
        slowStatus: AnalyticsLoadStatus.loaded,
      );
    } catch (e) {
      state = state.copyWith(
        topStatus: AnalyticsLoadStatus.error,
        slowStatus: AnalyticsLoadStatus.error,
        errorMessage: ApiException.getErrorMessage(e),
      );
    }
  }
}

// ─── Profit Report Controller ──────────────────────────────────────────────────

final analyticsProfitControllerProvider =
    StateNotifierProvider.autoDispose<AnalyticsProfitController, AnalyticsProfitState>((ref) {
  return AnalyticsProfitController(ref.read(analyticsRepositoryProvider));
});

class AnalyticsProfitController extends StateNotifier<AnalyticsProfitState> {
  final AnalyticsRepository _repository;

  AnalyticsProfitController(this._repository) : super(const AnalyticsProfitState()) {
    load(30);
  }

  Future<void> load(int days) async {
    state = state.copyWith(
      selectedDays: days,
      status: AnalyticsLoadStatus.loading,
      clearError: true,
    );
    try {
      final report = await _repository.getProfitReport(days);
      state = state.copyWith(report: report, status: AnalyticsLoadStatus.loaded);
    } catch (e) {
      state = state.copyWith(
        status: AnalyticsLoadStatus.error,
        errorMessage: ApiException.getErrorMessage(e),
      );
    }
  }
}
