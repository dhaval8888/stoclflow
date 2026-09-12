import '../data/models/analytics_models.dart';

enum AnalyticsLoadStatus { initial, loading, loaded, error }

/// Shared state for the dashboard summary (Owner/Manager)
class DashboardState {
  final DashboardSummary? summary;
  final AnalyticsLoadStatus status;
  final String? errorMessage;

  const DashboardState({
    this.summary,
    this.status = AnalyticsLoadStatus.initial,
    this.errorMessage,
  });

  bool get isLoading => status == AnalyticsLoadStatus.loading;
  bool get isLoaded => status == AnalyticsLoadStatus.loaded;
  bool get hasError => status == AnalyticsLoadStatus.error;

  DashboardState copyWith({
    DashboardSummary? summary,
    AnalyticsLoadStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      summary: summary ?? this.summary,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// State for the Analytics screen tabs
class AnalyticsSalesState {
  final List<SalesTrendPoint> trend;
  final int selectedDays; // 7, 30, or 90
  final AnalyticsLoadStatus status;
  final String? errorMessage;

  const AnalyticsSalesState({
    this.trend = const [],
    this.selectedDays = 30,
    this.status = AnalyticsLoadStatus.initial,
    this.errorMessage,
  });

  bool get isLoading => status == AnalyticsLoadStatus.loading;
  bool get isEmpty => status == AnalyticsLoadStatus.loaded && trend.isEmpty;

  AnalyticsSalesState copyWith({
    List<SalesTrendPoint>? trend,
    int? selectedDays,
    AnalyticsLoadStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AnalyticsSalesState(
      trend: trend ?? this.trend,
      selectedDays: selectedDays ?? this.selectedDays,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AnalyticsProductsState {
  final List<TopProduct> topProducts;
  final List<SlowProduct> slowProducts;
  final int selectedDays;
  final AnalyticsLoadStatus topStatus;
  final AnalyticsLoadStatus slowStatus;
  final String? errorMessage;

  const AnalyticsProductsState({
    this.topProducts = const [],
    this.slowProducts = const [],
    this.selectedDays = 30,
    this.topStatus = AnalyticsLoadStatus.initial,
    this.slowStatus = AnalyticsLoadStatus.initial,
    this.errorMessage,
  });

  bool get isLoading =>
      topStatus == AnalyticsLoadStatus.loading ||
      slowStatus == AnalyticsLoadStatus.loading;

  AnalyticsProductsState copyWith({
    List<TopProduct>? topProducts,
    List<SlowProduct>? slowProducts,
    int? selectedDays,
    AnalyticsLoadStatus? topStatus,
    AnalyticsLoadStatus? slowStatus,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AnalyticsProductsState(
      topProducts: topProducts ?? this.topProducts,
      slowProducts: slowProducts ?? this.slowProducts,
      selectedDays: selectedDays ?? this.selectedDays,
      topStatus: topStatus ?? this.topStatus,
      slowStatus: slowStatus ?? this.slowStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AnalyticsProfitState {
  final ProfitReport? report;
  final int selectedDays;
  final AnalyticsLoadStatus status;
  final String? errorMessage;

  const AnalyticsProfitState({
    this.report,
    this.selectedDays = 30,
    this.status = AnalyticsLoadStatus.initial,
    this.errorMessage,
  });

  bool get isLoading => status == AnalyticsLoadStatus.loading;

  AnalyticsProfitState copyWith({
    ProfitReport? report,
    int? selectedDays,
    AnalyticsLoadStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AnalyticsProfitState(
      report: report ?? this.report,
      selectedDays: selectedDays ?? this.selectedDays,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
