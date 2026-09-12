import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/inventory_item_model.dart';
import '../models/inventory_transaction_model.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return InventoryRepository(dio);
});

class PaginatedInventoryResponse {
  final List<InventoryItemModel> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNext;

  PaginatedInventoryResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNext,
  });

  factory PaginatedInventoryResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['inventory'] as List<dynamic>? ?? [])
        .map((e) => InventoryItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['meta'] as Map<String, dynamic>? ?? {};

    return PaginatedInventoryResponse(
      items: list,
      total: int.tryParse(meta['total']?.toString() ?? '0') ?? 0,
      page: int.tryParse(meta['page']?.toString() ?? '1') ?? 1,
      limit: int.tryParse(meta['limit']?.toString() ?? '20') ?? 20,
      totalPages: int.tryParse(meta['totalPages']?.toString() ?? '1') ?? 1,
      hasNext: meta['hasNext'] as bool? ?? false,
    );
  }
}

class PaginatedTransactionsResponse {
  final List<InventoryTransactionModel> transactions;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNext;

  PaginatedTransactionsResponse({
    required this.transactions,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNext,
  });

  factory PaginatedTransactionsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['transactions'] as List<dynamic>? ?? [])
        .map((e) => InventoryTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['meta'] as Map<String, dynamic>? ?? {};

    return PaginatedTransactionsResponse(
      transactions: list,
      total: int.tryParse(meta['total']?.toString() ?? '0') ?? 0,
      page: int.tryParse(meta['page']?.toString() ?? '1') ?? 1,
      limit: int.tryParse(meta['limit']?.toString() ?? '20') ?? 20,
      totalPages: int.tryParse(meta['totalPages']?.toString() ?? '1') ?? 1,
      hasNext: meta['hasNext'] as bool? ?? false,
    );
  }
}

class InventoryRepository {
  final Dio _dio;

  InventoryRepository(this._dio);

  Future<PaginatedInventoryResponse> getStock({
    int page = 1,
    int limit = 20,
    String? search,
    bool? lowStockOnly,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.inventory,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (lowStockOnly == true) 'lowStockOnly': 'true',
        },
      );

      if (response.data['success'] == true) {
        return PaginatedInventoryResponse.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to load stock');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<InventoryItemModel>> getLowStock() async {
    try {
      final response = await _dio.get(ApiEndpoints.inventoryLowStock);
      if (response.data['success'] == true) {
        final list = response.data['data']['products'] as List<dynamic>? ?? [];
        return list.map((e) => InventoryItemModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to load low stock items');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<InventoryItemModel>> getOutOfStock() async {
    try {
      final response = await _dio.get(ApiEndpoints.inventoryOutOfStock);
      if (response.data['success'] == true) {
        final list = response.data['data']['products'] as List<dynamic>? ?? [];
        return list.map((e) => InventoryItemModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to load out of stock items');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<InventoryTransactionModel> createTransaction({
    required String productId,
    required String type, // STOCK_IN, STOCK_OUT, ADJUSTMENT
    required int quantity,
    String? note,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.inventoryTransactions,
        data: {
          'productId': productId,
          'type': type,
          'quantity': quantity,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );

      if (response.data['success'] == true) {
        final txJson = response.data['data']['transaction'] as Map<String, dynamic>;
        return InventoryTransactionModel.fromJson(txJson);
      }
      throw ApiException(message: response.data['message'] ?? 'Stock movement failed');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<PaginatedTransactionsResponse> getTransactions({
    int page = 1,
    int limit = 20,
    String? productId,
    String? type,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.inventoryTransactions,
        queryParameters: {
          'page': page,
          'limit': limit,
          'productId': ?productId,
          'type': ?type,
        },
      );

      if (response.data['success'] == true) {
        return PaginatedTransactionsResponse.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to load audit trail');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
