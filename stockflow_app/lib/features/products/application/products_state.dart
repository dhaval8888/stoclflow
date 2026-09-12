import '../data/models/product_model.dart';

enum ProductsPaginationStatus {
  initialLoading,
  refreshing,
  loadingMore,
  loaded,
  error,
}

class ProductsState {
  final List<ProductModel> products;
  final ProductsPaginationStatus status;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;
  final String? errorMessage;
  final String? paginationErrorMessage;
  final String searchQuery;
  final String? selectedCategoryId;
  final String? stockStatusFilter;
  final bool? isActiveFilter;

  const ProductsState({
    this.products = const [],
    this.status = ProductsPaginationStatus.initialLoading,
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.hasMore = false,
    this.errorMessage,
    this.paginationErrorMessage,
    this.searchQuery = '',
    this.selectedCategoryId,
    this.stockStatusFilter,
    this.isActiveFilter,
  });

  bool get isInitialLoading => status == ProductsPaginationStatus.initialLoading;
  bool get isRefreshing => status == ProductsPaginationStatus.refreshing;
  bool get isLoadingMore => status == ProductsPaginationStatus.loadingMore;
  bool get isLoaded => status == ProductsPaginationStatus.loaded;
  bool get hasError => status == ProductsPaginationStatus.error;
  bool get hasPaginationError => paginationErrorMessage != null;

  ProductsState copyWith({
    List<ProductModel>? products,
    ProductsPaginationStatus? status,
    int? page,
    int? limit,
    int? total,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
    String? paginationErrorMessage,
    bool clearPaginationError = false,
    String? searchQuery,
    String? selectedCategoryId,
    bool clearCategory = false,
    String? stockStatusFilter,
    bool clearStockStatus = false,
    bool? isActiveFilter,
  }) {
    return ProductsState(
      products: products ?? this.products,
      status: status ?? this.status,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      paginationErrorMessage: clearPaginationError
          ? null
          : (paginationErrorMessage ?? this.paginationErrorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      stockStatusFilter:
          clearStockStatus ? null : (stockStatusFilter ?? this.stockStatusFilter),
      isActiveFilter: isActiveFilter ?? this.isActiveFilter,
    );
  }
}

