import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/category_model.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return CategoriesRepository(dio);
});

class CategoriesRepository {
  final Dio _dio;

  CategoriesRepository(this._dio);

  Future<List<CategoryModel>> getCategories({bool? isActive}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.categories,
        queryParameters: {
          'isActive': ?isActive,
        },
      );

      if (response.data['success'] == true) {
        final list = response.data['data']['categories'] as List<dynamic>? ?? [];
        return list.map((json) => CategoryModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to load categories');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CategoryModel> createCategory({
    required String name,
    String? description,
    String? color,
    String? icon,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.categories,
        data: {
          'name': name.trim(),
          if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
          'color': ?color,
          'icon': ?icon,
        },
      );

      if (response.data['success'] == true) {
        final catJson = response.data['data']['category'] as Map<String, dynamic>;
        return CategoryModel.fromJson(catJson);
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to create category');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CategoryModel> updateCategory(
    String id, {
    String? name,
    String? description,
    String? color,
    String? icon,
    bool? isActive,
  }) async {
    try {
      final response = await _dio.put(
        '${ApiEndpoints.categories}/$id',
        data: {
          if (name != null) 'name': name.trim(),
          if (description != null) 'description': description.trim(),
          'color': ?color,
          'icon': ?icon,
          'isActive': ?isActive,
        },
      );

      if (response.data['success'] == true) {
        final catJson = response.data['data']['category'] as Map<String, dynamic>;
        return CategoryModel.fromJson(catJson);
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to update category');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      final response = await _dio.delete('${ApiEndpoints.categories}/$id');
      if (response.data['success'] != true) {
        throw ApiException(message: response.data['message'] ?? 'Failed to delete category');
      }
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
