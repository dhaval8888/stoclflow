import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/product_model.dart';
import '../models/product_image_model.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ProductsRepository(dio);
});

class PaginatedProductsResponse {
  final List<ProductModel> products;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  PaginatedProductsResponse({
    required this.products,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory PaginatedProductsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['products'] as List<dynamic>? ?? [])
        .map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
        .toList();
    final meta = json['meta'] as Map<String, dynamic>? ?? {};

    return PaginatedProductsResponse(
      products: list,
      total: int.tryParse(meta['total']?.toString() ?? '0') ?? 0,
      page: int.tryParse(meta['page']?.toString() ?? '1') ?? 1,
      limit: int.tryParse(meta['limit']?.toString() ?? '20') ?? 20,
      totalPages: int.tryParse(meta['totalPages']?.toString() ?? '1') ?? 1,
      hasNext: meta['hasNext'] as bool? ?? false,
      hasPrev: meta['hasPrev'] as bool? ?? false,
    );
  }
}

class ProductsRepository {
  final Dio _dio;

  ProductsRepository(this._dio);

  Future<PaginatedProductsResponse> getProducts({
    int page = 1,
    int limit = 20,
    String? search,
    String? categoryId,
    String? stockStatus,
    bool? isActive,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.products,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
          if (stockStatus != null && stockStatus.isNotEmpty) 'stockStatus': stockStatus,
          'isActive': ?isActive,
        },
      );

      if (response.data['success'] == true) {
        return PaginatedProductsResponse.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to fetch products');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ProductModel> getProductById(String id) async {
    try {
      final response = await _dio.get('${ApiEndpoints.products}/$id');
      if (response.data['success'] == true) {
        final productJson = response.data['data']['product'] as Map<String, dynamic>;
        return ProductModel.fromJson(productJson);
      }
      throw ApiException(message: response.data['message'] ?? 'Product not found');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ProductModel?> getProductByBarcode(String barcode) async {
    try {
      final response = await _dio.get('${ApiEndpoints.products}/barcode/$barcode');
      if (response.data['success'] == true) {
        final productJson = response.data['data']['product'] as Map<String, dynamic>;
        return ProductModel.fromJson(productJson);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDioError(e);
    }
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
      final response = await _dio.post(
        ApiEndpoints.products,
        data: {
          'name': name.trim(),
          if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
          if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
          if (sku != null && sku.trim().isNotEmpty) 'sku': sku.trim(),
          if (barcode != null && barcode.trim().isNotEmpty) 'barcode': barcode.trim(),
          'unit': unit,
          'costPrice': costPrice,
          'sellingPrice': sellingPrice,
          'lowStockThreshold': lowStockThreshold,
          if (initialStock > 0) 'initialStock': initialStock,
        },
      );

      if (response.data['success'] == true) {
        final productJson = response.data['data']['product'] as Map<String, dynamic>;
        return ProductModel.fromJson(productJson);
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to create product');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
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
      final response = await _dio.patch(
        '${ApiEndpoints.products}/$id',
        data: {
          if (name != null) 'name': name.trim(),
          'description': (description != null && description.trim().isNotEmpty) ? description.trim() : null,
          'categoryId': (categoryId != null && categoryId.trim().isNotEmpty) ? categoryId.trim() : null,
          'sku': (sku != null && sku.trim().isNotEmpty) ? sku.trim() : null,
          'barcode': (barcode != null && barcode.trim().isNotEmpty) ? barcode.trim() : null,
          'unit': ?unit,
          'costPrice': ?costPrice,
          'sellingPrice': ?sellingPrice,
          'lowStockThreshold': ?lowStockThreshold,
        },
      );

      if (response.data['success'] == true) {
        final productJson = response.data['data']['product'] as Map<String, dynamic>;
        return ProductModel.fromJson(productJson);
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to update product');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> softDeleteProduct(String id) async {
    try {
      final response = await _dio.delete('${ApiEndpoints.products}/$id');
      if (response.data['success'] != true) {
        throw ApiException(message: response.data['message'] ?? 'Failed to deactivate product');
      }
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ProductImageModel> uploadProductImage(
    String productId,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '${ApiEndpoints.products}/$productId/images',
        data: formData,
        onSendProgress: onProgress,
      );

      if (response.data['success'] == true) {
        final imageJson = response.data['data']['image'] as Map<String, dynamic>;
        return ProductImageModel.fromJson(imageJson);
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to upload image');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteProductImage(String productId, String imageId) async {
    try {
      final response = await _dio.delete('${ApiEndpoints.products}/$productId/images/$imageId');
      if (response.data['success'] != true) {
        throw ApiException(message: response.data['message'] ?? 'Failed to remove image');
      }
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
