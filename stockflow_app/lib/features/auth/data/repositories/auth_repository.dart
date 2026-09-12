import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {'email': email.trim(), 'password': password},
      );

      if (response.data['success'] == true) {
        return AuthResponse.fromJson(response.data['data'] as Map<String, dynamic>);
      }
      throw ApiException(message: response.data['message'] ?? 'Login failed');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<AuthResponse> register({
    required String businessName,
    required String fullName,
    required String email,
    required String password,
    String? businessPhone,
    String? businessAddress,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.register,
        data: {
          'businessName': businessName.trim(),
          'fullName': fullName.trim(),
          'email': email.trim(),
          'password': password,
          if (businessPhone != null && businessPhone.isNotEmpty) 'businessPhone': businessPhone.trim(),
          if (businessAddress != null && businessAddress.isNotEmpty) 'businessAddress': businessAddress.trim(),
        },
      );

      if (response.data['success'] == true) {
        // Automatically login to get tokens and full session
        return await login(email: email, password: password);
      }
      throw ApiException(message: response.data['message'] ?? 'Registration failed');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<User> getMe() async {
    try {
      final response = await _dio.get(ApiEndpoints.me);
      if (response.data['success'] == true) {
        final profile = response.data['data']['profile'] as Map<String, dynamic>;
        return User.fromJson(profile);
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to fetch user');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> logout(String? refreshToken) async {
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _dio.post(
          ApiEndpoints.logout,
          data: {'refreshToken': refreshToken},
        );
      }
    } catch (_) {
      // Best-effort server-side logout
    }
  }
}
