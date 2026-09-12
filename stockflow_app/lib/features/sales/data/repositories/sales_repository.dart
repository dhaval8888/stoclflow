import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/cart_item_model.dart';
import '../models/receipt_model.dart';
import '../models/sale_model.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SalesRepository(dio);
});

class PaginatedSalesResponse {
  final List<SaleModel> sales;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNext;

  PaginatedSalesResponse({
    required this.sales,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNext,
  });

  factory PaginatedSalesResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['sales'] as List<dynamic>? ?? [])
        .map((e) => SaleModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['meta'] as Map<String, dynamic>? ?? {};

    return PaginatedSalesResponse(
      sales: list,
      total: int.tryParse(meta['total']?.toString() ?? '0') ?? 0,
      page: int.tryParse(meta['page']?.toString() ?? '1') ?? 1,
      limit: int.tryParse(meta['limit']?.toString() ?? '20') ?? 20,
      totalPages: int.tryParse(meta['totalPages']?.toString() ?? '1') ?? 1,
      hasNext: meta['hasNext'] as bool? ?? false,
    );
  }
}

class SalesRepository {
  final Dio _dio;

  SalesRepository(this._dio);

  Future<SaleModel> createSale({
    required List<CartItemModel> items,
    required String paymentMethod,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    String? note,
  }) async {
    try {
      final payload = {
        'items': items.map((i) => i.toApiJson()).toList(),
        'paymentMethod': paymentMethod,
        'discountAmount': discountAmount,
        'taxAmount': taxAmount,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      };

      final response = await _dio.post(ApiEndpoints.sales, data: payload);

      if (response.data['success'] == true) {
        final saleJson = response.data['data']['sale'] as Map<String, dynamic>;
        return SaleModel.fromJson(saleJson);
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to process sale');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<PaginatedSalesResponse> listSales({
    int page = 1,
    int limit = 20,
    String? status,
    String? paymentMethod,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.sales,
        queryParameters: {
          'page': page,
          'limit': limit,
          'status': ?status,
          'paymentMethod': ?paymentMethod,
        },
      );

      if (response.data['success'] == true) {
        return PaginatedSalesResponse.fromJson(response.data['data'] as Map<String, dynamic>);
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to load sales');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<SaleModel> getSaleById(String id) async {
    try {
      final response = await _dio.get('${ApiEndpoints.sales}/$id');
      if (response.data['success'] == true) {
        final saleJson = response.data['data']['sale'] as Map<String, dynamic>;
        return SaleModel.fromJson(saleJson);
      }
      throw ApiException(message: response.data['message'] ?? 'Sale not found');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ReceiptModel> getReceipt(String id) async {
    try {
      final response = await _dio.get('${ApiEndpoints.sales}/$id/receipt');
      if (response.data['success'] == true) {
        final receiptJson = response.data['data']['receipt'] as Map<String, dynamic>;
        return ReceiptModel.fromJson(receiptJson);
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to load receipt');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<SaleModel> voidSale(String id) async {
    try {
      final response = await _dio.post('${ApiEndpoints.sales}/$id/void');
      if (response.data['success'] == true) {
        final saleJson = response.data['data']['sale'] as Map<String, dynamic>;
        return SaleModel.fromJson(saleJson);
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to void sale');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
