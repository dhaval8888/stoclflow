import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/employee_model.dart';

final employeesRepositoryProvider = Provider<EmployeesRepository>((ref) {
  return EmployeesRepository(ref.watch(dioProvider));
});

class PaginatedEmployeesResponse {
  final List<EmployeeModel> employees;
  final int total;
  final int page;
  final int limit;
  final bool hasNext;

  PaginatedEmployeesResponse({
    required this.employees,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasNext,
  });

  factory PaginatedEmployeesResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['employees'] as List<dynamic>? ?? [])
        .map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['meta'] as Map<String, dynamic>? ?? {};

    final page = int.tryParse(meta['page']?.toString() ?? '1') ?? 1;
    final limit = int.tryParse(meta['limit']?.toString() ?? '20') ?? 20;
    final total = int.tryParse(meta['total']?.toString() ?? '0') ?? 0;
    final totalPages = int.tryParse(meta['totalPages']?.toString() ?? '1') ?? 1;

    return PaginatedEmployeesResponse(
      employees: list,
      total: total,
      page: page,
      limit: limit,
      hasNext: page < totalPages,
    );
  }
}

class EmployeesRepository {
  final Dio _dio;

  EmployeesRepository(this._dio);

  Future<PaginatedEmployeesResponse> listEmployees({
    int page = 1,
    int limit = 50,
    String? search,
    String? role,
    bool? isActive,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.users,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (role != null && role.isNotEmpty) 'role': role,
          'isActive': ?isActive,
        },
      );

      if (response.data['success'] == true) {
        return PaginatedEmployeesResponse.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to load employees');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<EmployeeModel> addEmployee({
    required String fullName,
    required String email,
    required String password,
    required String role, // MANAGER or CASHIER
    String? phone,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.users,
        data: {
          'fullName': fullName,
          'email': email,
          'password': password,
          'role': role,
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        },
      );

      if (response.data['success'] == true) {
        return EmployeeModel.fromJson(
          response.data['data']['employee'] as Map<String, dynamic>,
        );
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to add employee');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<EmployeeModel> updateEmployee(
    String id, {
    String? fullName,
    String? phone,
    String? role,
    bool? isActive,
  }) async {
    try {
      final response = await _dio.patch(
        '${ApiEndpoints.users}/$id',
        data: {
          'fullName': ?fullName,
          'phone': ?phone,
          'role': ?role,
          'isActive': ?isActive,
        },
      );

      if (response.data['success'] == true) {
        return EmployeeModel.fromJson(
          response.data['data']['employee'] as Map<String, dynamic>,
        );
      }
      throw ApiException(message: response.data['message'] ?? 'Failed to update employee');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deactivateEmployee(String id) async {
    try {
      final response = await _dio.delete('${ApiEndpoints.users}/$id');
      if (response.data['success'] != true) {
        throw ApiException(message: response.data['message'] ?? 'Failed to deactivate employee');
      }
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
