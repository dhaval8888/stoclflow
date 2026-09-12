import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_app/core/network/api_exceptions.dart';
import 'package:stockflow_app/features/products/application/products_controller.dart';
import 'package:stockflow_app/features/products/application/products_state.dart';
import 'package:stockflow_app/features/products/data/models/product_model.dart';
import 'package:stockflow_app/features/products/data/repositories/products_repository.dart';

class FakeProductsRepository extends ProductsRepository {
  PaginatedProductsResponse? responseToReturn;
  Exception? errorToThrow;
  Future<PaginatedProductsResponse> Function({
    int page,
    int limit,
    String? search,
    String? categoryId,
    String? stockStatus,
    bool? isActive,
  })? customGetProducts;

  int callCount = 0;
  int? lastPage;
  String? lastSearch;

  FakeProductsRepository() : super(Dio());

  @override
  Future<PaginatedProductsResponse> getProducts({
    int page = 1,
    int limit = 20,
    String? search,
    String? categoryId,
    String? stockStatus,
    bool? isActive,
  }) async {
    callCount++;
    lastPage = page;
    lastSearch = search;

    if (customGetProducts != null) {
      return customGetProducts!(
        page: page,
        limit: limit,
        search: search,
        categoryId: categoryId,
        stockStatus: stockStatus,
        isActive: isActive,
      );
    }

    if (errorToThrow != null) throw errorToThrow!;
    return responseToReturn ??
        PaginatedProductsResponse(
          products: [],
          total: 0,
          page: page,
          limit: limit,
          totalPages: 1,
          hasNext: false,
          hasPrev: false,
        );
  }
}

ProductModel _createProduct(String id, String name, {int qty = 10}) {
  return ProductModel(
    id: id,
    businessId: 'biz-1',
    name: name,
    sellingPrice: 25.0,
    currentQuantity: qty,
    stockStatus: qty > 0 ? 'IN_STOCK' : 'OUT_OF_STOCK',
  );
}

void main() {
  late FakeProductsRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeProductsRepository();
  });

  group('ProductsController Unit Tests', () {
    test('initial load populates products and loaded status', () async {
      final p1 = _createProduct('p1', 'Product 1');
      final p2 = _createProduct('p2', 'Product 2');

      fakeRepo.responseToReturn = PaginatedProductsResponse(
        products: [p1, p2],
        total: 2,
        page: 1,
        limit: 20,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      );

      final controller = ProductsController(fakeRepo);
      // Wait for initial async load triggered in constructor
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.state.status, ProductsPaginationStatus.loaded);
      expect(controller.state.products.length, 2);
      expect(controller.state.products.first.name, 'Product 1');
      expect(controller.state.total, 2);
      expect(controller.state.hasMore, false);
      expect(fakeRepo.callCount, 1);
    });

    test('initial load error sets error status and clean message', () async {
      fakeRepo.errorToThrow = const ApiException(
        message: 'Database connection failed',
        statusCode: 500,
      );

      final controller = ProductsController(fakeRepo);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.state.status, ProductsPaginationStatus.error);
      expect(controller.state.errorMessage, 'Database connection failed');
      expect(controller.state.products, isEmpty);
    });

    test('loadMore appends new items and increments page', () async {
      final p1 = _createProduct('p1', 'Product 1');
      final p2 = _createProduct('p2', 'Product 2');

      fakeRepo.responseToReturn = PaginatedProductsResponse(
        products: [p1],
        total: 2,
        page: 1,
        limit: 1,
        totalPages: 2,
        hasNext: true,
        hasPrev: false,
      );

      final controller = ProductsController(fakeRepo);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(controller.state.products.length, 1);
      expect(controller.state.hasMore, true);

      // Now prepare page 2 response
      fakeRepo.responseToReturn = PaginatedProductsResponse(
        products: [p2],
        total: 2,
        page: 2,
        limit: 1,
        totalPages: 2,
        hasNext: false,
        hasPrev: true,
      );

      await controller.loadMore();

      expect(controller.state.products.length, 2);
      expect(controller.state.products[0].id, 'p1');
      expect(controller.state.products[1].id, 'p2');
      expect(controller.state.page, 2);
      expect(controller.state.hasMore, false);
    });

    test('loadMore deduplicates products sharing the same ID', () async {
      final p1 = _createProduct('p1', 'Product 1');
      final p2 = _createProduct('p2', 'Product 2');

      fakeRepo.responseToReturn = PaginatedProductsResponse(
        products: [p1, p2],
        total: 3,
        page: 1,
        limit: 2,
        totalPages: 2,
        hasNext: true,
        hasPrev: false,
      );

      final controller = ProductsController(fakeRepo);
      await Future.delayed(const Duration(milliseconds: 50));

      // Page 2 returns duplicate 'p2' and new 'p3'
      final p3 = _createProduct('p3', 'Product 3');
      fakeRepo.responseToReturn = PaginatedProductsResponse(
        products: [p2, p3],
        total: 3,
        page: 2,
        limit: 2,
        totalPages: 2,
        hasNext: false,
        hasPrev: true,
      );

      await controller.loadMore();

      // Should have 3 unique products, not 4
      expect(controller.state.products.length, 3);
      expect(controller.state.products.map((p) => p.id).toList(), ['p1', 'p2', 'p3']);
    });

    test('loadMore error is non-destructive and sets paginationErrorMessage', () async {
      final p1 = _createProduct('p1', 'Product 1');

      fakeRepo.responseToReturn = PaginatedProductsResponse(
        products: [p1],
        total: 10,
        page: 1,
        limit: 1,
        totalPages: 10,
        hasNext: true,
        hasPrev: false,
      );

      final controller = ProductsController(fakeRepo);
      await Future.delayed(const Duration(milliseconds: 50));

      // Page 2 fails
      fakeRepo.errorToThrow = const ApiException(
        message: 'Network timeout loading more products',
        statusCode: 408,
      );

      await controller.loadMore();

      // Page 1 products must NOT be destroyed!
      expect(controller.state.products.length, 1);
      expect(controller.state.products.first.id, 'p1');
      expect(controller.state.hasPaginationError, true);
      expect(controller.state.paginationErrorMessage, 'Network timeout loading more products');
      expect(controller.state.status, ProductsPaginationStatus.loaded);
    });

    test('retryLoadMore clears paginationErrorMessage and reloads', () async {
      final p1 = _createProduct('p1', 'Product 1');
      final p2 = _createProduct('p2', 'Product 2');

      fakeRepo.responseToReturn = PaginatedProductsResponse(
        products: [p1],
        total: 2,
        page: 1,
        limit: 1,
        totalPages: 2,
        hasNext: true,
        hasPrev: false,
      );

      final controller = ProductsController(fakeRepo);
      await Future.delayed(const Duration(milliseconds: 50));

      // First attempt fails
      fakeRepo.errorToThrow = const ApiException(message: 'Error');
      await controller.loadMore();
      expect(controller.state.hasPaginationError, true);

      // Retry succeeds
      fakeRepo.errorToThrow = null;
      fakeRepo.responseToReturn = PaginatedProductsResponse(
        products: [p2],
        total: 2,
        page: 2,
        limit: 1,
        totalPages: 2,
        hasNext: false,
        hasPrev: true,
      );

      await controller.retryLoadMore();

      expect(controller.state.hasPaginationError, false);
      expect(controller.state.paginationErrorMessage, isNull);
      expect(controller.state.products.length, 2);
    });

    test('onSearchChanged debounces network request by ~400ms', () async {
      fakeRepo.responseToReturn = PaginatedProductsResponse(
        products: [],
        total: 0,
        page: 1,
        limit: 20,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      );

      final controller = ProductsController(fakeRepo);
      await Future.delayed(const Duration(milliseconds: 50));
      final initialCount = fakeRepo.callCount;

      controller.onSearchChanged('w');
      controller.onSearchChanged('wi');
      controller.onSearchChanged('wid');
      controller.onSearchChanged('widget');

      // Before 400ms delay expires, no extra search call should have completed
      await Future.delayed(const Duration(milliseconds: 100));
      expect(fakeRepo.callCount, initialCount);

      // Wait for debouncer (400ms + buffer)
      await Future.delayed(const Duration(milliseconds: 450));
      expect(fakeRepo.callCount, initialCount + 1);
      expect(fakeRepo.lastSearch, 'widget');
    });

    test('race condition: out-of-order response discard when requestId mismatches', () async {
      final controller = ProductsController(fakeRepo);
      await Future.delayed(const Duration(milliseconds: 50));

      // Setup custom repository with controlled response orders
      // Request 1 takes 300ms, Request 2 takes 50ms
      fakeRepo.customGetProducts = ({
        page = 1,
        limit = 20,
        search,
        categoryId,
        stockStatus,
        isActive,
      }) async {
        if (search == 'slow_query') {
          await Future.delayed(const Duration(milliseconds: 250));
          return PaginatedProductsResponse(
            products: [_createProduct('p_slow', 'Slow Item')],
            total: 1,
            page: 1,
            limit: 20,
            totalPages: 1,
            hasNext: false,
            hasPrev: false,
          );
        } else {
          await Future.delayed(const Duration(milliseconds: 50));
          return PaginatedProductsResponse(
            products: [_createProduct('p_fast', 'Fast Item')],
            total: 1,
            page: 1,
            limit: 20,
            totalPages: 1,
            hasNext: false,
            hasPrev: false,
          );
        }
      };

      // Trigger slow search directly via loadInitial after setting query
      controller.onSearchChanged('slow_query');
      // Wait for debouncer to fire slow_query
      await Future.delayed(const Duration(milliseconds: 450));

      // While slow_query is in-flight, immediately trigger fast search
      controller.onSearchChanged('fast_query');
      await Future.delayed(const Duration(milliseconds: 450));

      // Wait for all in-flight futures to complete
      await Future.delayed(const Duration(milliseconds: 300));

      // State MUST contain Fast Item, and NOT be overwritten by Slow Item
      expect(controller.state.products.length, 1);
      expect(controller.state.products.first.id, 'p_fast');
      expect(controller.state.products.first.name, 'Fast Item');
    });

    test('refresh resets state and reloads initial page', () async {
      final p1 = _createProduct('p1', 'Product 1');
      fakeRepo.responseToReturn = PaginatedProductsResponse(
        products: [p1],
        total: 1,
        page: 1,
        limit: 20,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      );

      final controller = ProductsController(fakeRepo);
      await Future.delayed(const Duration(milliseconds: 50));

      await controller.refresh();

      expect(controller.state.status, ProductsPaginationStatus.loaded);
      expect(controller.state.products.length, 1);
      expect(fakeRepo.lastPage, 1);
    });
  });
}
