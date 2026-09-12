import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/utils/debouncer.dart';
import '../data/models/product_model.dart';
import '../data/models/product_image_model.dart';
import '../data/repositories/products_repository.dart';
import 'products_state.dart';

final productsControllerProvider =
    StateNotifierProvider<ProductsController, ProductsState>((ref) {
  final repo = ref.watch(productsRepositoryProvider);
  return ProductsController(repo);
});

class ProductsController extends StateNotifier<ProductsState> {
  final ProductsRepository _repository;
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 400));
  int _activeRequestId = 0;

  ProductsController(this._repository) : super(const ProductsState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    final requestId = ++_activeRequestId;
    state = state.copyWith(
      status: ProductsPaginationStatus.initialLoading,
      clearError: true,
      clearPaginationError: true,
    );

    try {
      final res = await _repository.getProducts(
        page: 1,
        limit: state.limit,
        search: state.searchQuery,
        categoryId: state.selectedCategoryId,
        stockStatus: state.stockStatusFilter,
        isActive: state.isActiveFilter,
      );

      // Discard response if a newer search/filter request was issued in the meantime
      if (requestId != _activeRequestId) return;

      state = state.copyWith(
        products: res.products,
        status: ProductsPaginationStatus.loaded,
        page: 1,
        total: res.total,
        hasMore: res.hasNext,
        clearError: true,
        clearPaginationError: true,
      );
    } catch (e) {
      if (requestId != _activeRequestId) return;
      state = state.copyWith(
        status: ProductsPaginationStatus.error,
        errorMessage: ApiException.getErrorMessage(e),
      );
    }
  }

  Future<void> refresh() async {
    final requestId = ++_activeRequestId;
    state = state.copyWith(
      status: ProductsPaginationStatus.refreshing,
      clearError: true,
      clearPaginationError: true,
    );

    try {
      final res = await _repository.getProducts(
        page: 1,
        limit: state.limit,
        search: state.searchQuery,
        categoryId: state.selectedCategoryId,
        stockStatus: state.stockStatusFilter,
        isActive: state.isActiveFilter,
      );

      if (requestId != _activeRequestId) return;

      state = state.copyWith(
        products: res.products,
        status: ProductsPaginationStatus.loaded,
        page: 1,
        total: res.total,
        hasMore: res.hasNext,
        clearError: true,
        clearPaginationError: true,
      );
    } catch (e) {
      if (requestId != _activeRequestId) return;
      state = state.copyWith(
        status: ProductsPaginationStatus.error,
        errorMessage: ApiException.getErrorMessage(e),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isInitialLoading || state.isRefreshing) {
      return;
    }

    state = state.copyWith(
      status: ProductsPaginationStatus.loadingMore,
      clearPaginationError: true,
    );
    final nextPage = state.page + 1;

    try {
      final res = await _repository.getProducts(
        page: nextPage,
        limit: state.limit,
        search: state.searchQuery,
        categoryId: state.selectedCategoryId,
        stockStatus: state.stockStatusFilter,
        isActive: state.isActiveFilter,
      );

      // Deduplicate products by ID to prevent duplicate list keys
      final existingIds = state.products.map((p) => p.id).toSet();
      final uniqueNew = res.products.where((p) => !existingIds.contains(p.id)).toList();

      state = state.copyWith(
        products: [...state.products, ...uniqueNew],
        status: ProductsPaginationStatus.loaded,
        page: nextPage,
        total: res.total,
        hasMore: res.hasNext,
        clearPaginationError: true,
      );
    } catch (e) {
      // Non-destructive: preserve currently loaded items!
      state = state.copyWith(
        status: ProductsPaginationStatus.loaded,
        paginationErrorMessage: ApiException.getErrorMessage(e),
      );
    }
  }

  Future<void> retryLoadMore() async {
    state = state.copyWith(clearPaginationError: true);
    await loadMore();
  }

  void onSearchChanged(String query) {
    final trimmed = query.trim();
    if (state.searchQuery == trimmed) return;

    // Update query immediately in state for UI synchronization
    state = state.copyWith(searchQuery: trimmed);

    // Debounce network call by ~400ms
    _debouncer.run(() {
      loadInitial();
    });
  }

  void onCategorySelected(String? categoryId) {
    if (state.selectedCategoryId == categoryId) return;
    _debouncer.cancel();
    state = state.copyWith(
      selectedCategoryId: categoryId,
      clearCategory: categoryId == null,
    );
    loadInitial();
  }

  void onStockFilterSelected(String? status) {
    if (state.stockStatusFilter == status) return;
    _debouncer.cancel();
    state = state.copyWith(
      stockStatusFilter: status,
      clearStockStatus: status == null,
    );
    loadInitial();
  }

  void onActiveFilterChanged(bool? isActive) {
    _debouncer.cancel();
    state = state.copyWith(isActiveFilter: isActive);
    loadInitial();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  Future<ProductModel> createProduct({
    required String name,
    String? description,
    String? categoryId,
    String? sku,
    String? barcode,
    String unit = 'pcs',
    required double costPrice,
    required double sellingPrice,
    int lowStockThreshold = 10,
    int initialStock = 0,
  }) async {
    try {
      final product = await _repository.createProduct(
        name: name,
        description: description,
        categoryId: categoryId,
        sku: sku,
        barcode: barcode,
        unit: unit,
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        lowStockThreshold: lowStockThreshold,
        initialStock: initialStock,
      );

      // Refresh products list
      refresh();
      return product;
    } catch (e) {
      rethrow;
    }
  }

  Future<ProductModel> updateProduct(
    String id, {
    String? name,
    String? description,
    String? categoryId,
    String? sku,
    String? barcode,
    String? unit,
    double? costPrice,
    double? sellingPrice,
    int? lowStockThreshold,
  }) async {
    try {
      final updated = await _repository.updateProduct(
        id,
        name: name,
        description: description,
        categoryId: categoryId,
        sku: sku,
        barcode: barcode,
        unit: unit,
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        lowStockThreshold: lowStockThreshold,
      );

      // Update in local state list
      state = state.copyWith(
        products: state.products.map((p) => p.id == id ? updated : p).toList(),
      );
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deactivateProduct(String id) async {
    try {
      await _repository.softDeleteProduct(id);
      // Soft-delete sets is_active = false
      state = state.copyWith(
        products: state.products.map((p) => p.id == id ? p.copyWith(isActive: false) : p).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<ProductImageModel> uploadProductImage(
    String productId,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final img = await _repository.uploadProductImage(productId, file, onProgress: onProgress);
      // Update local product image
      final updatedProducts = state.products.map((p) {
        if (p.id == productId) {
          final updatedImages = [...p.images, img];
          return p.copyWith(images: updatedImages);
        }
        return p;
      }).toList();
      state = state.copyWith(products: updatedProducts);
      return img;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProductImage(String productId, String imageId) async {
    try {
      await _repository.deleteProductImage(productId, imageId);
      final updatedProducts = state.products.map((p) {
        if (p.id == productId) {
          final updatedImages = p.images.where((img) => img.id != imageId).toList();
          return p.copyWith(images: updatedImages);
        }
        return p;
      }).toList();
      state = state.copyWith(products: updatedProducts);
    } catch (e) {
      rethrow;
    }
  }
}
