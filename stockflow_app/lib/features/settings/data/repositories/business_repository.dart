import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/business_model.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(ref.watch(dioProvider));
});

class BusinessRepository {
  final Dio _dio;

  BusinessRepository(this._dio);

  Future<BusinessModel> getBusiness() async {
    try {
      final res = await _dio.get(ApiEndpoints.business);
      if (res.data['success'] == true) {
        return BusinessModel.fromJson(
          res.data['data']['business'] as Map<String, dynamic>,
        );
      }
      throw ApiException(message: res.data['message'] ?? 'Failed to load business profile');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// OWNER only — backend enforces authorization
  Future<BusinessModel> updateBusiness({
    String? name,
    String? address,
    String? phone,
    String? email,
    String? currency,
    String? timezone,
  }) async {
    try {
      final res = await _dio.patch(
        ApiEndpoints.business,
        data: {
          'name': ?name,
          'address': ?address,
          'phone': ?phone,
          'email': ?email,
          'currency': ?currency,
          'timezone': ?timezone,
        },
      );
      if (res.data['success'] == true) {
        return BusinessModel.fromJson(
          res.data['data']['business'] as Map<String, dynamic>,
        );
      }
      throw ApiException(message: res.data['message'] ?? 'Failed to update business profile');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
