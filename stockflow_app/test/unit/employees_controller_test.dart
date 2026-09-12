import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_app/core/network/api_exceptions.dart';
import 'package:stockflow_app/features/employees/application/employees_controller.dart';
import 'package:stockflow_app/features/employees/data/models/employee_model.dart';
import 'package:stockflow_app/features/employees/data/repositories/employees_repository.dart';

class FakeEmployeesRepository extends EmployeesRepository {
  List<EmployeeModel> employees = [];
  Exception? error;

  FakeEmployeesRepository() : super(Dio());

  @override
  Future<PaginatedEmployeesResponse> listEmployees({
    int page = 1,
    int limit = 50,
    String? search,
    String? role,
    bool? isActive,
  }) async {
    if (error != null) throw error!;
    return PaginatedEmployeesResponse(
      employees: List.from(employees),
      total: employees.length,
      page: 1,
      limit: 50,
      hasNext: false,
    );
  }

  @override
  Future<EmployeeModel> addEmployee({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    if (error != null) throw error!;
    final emp = EmployeeModel(
      id: 'emp_new_1',
      businessId: 'biz_1',
      fullName: fullName,
      email: email,
      role: role,
      phone: phone,
      isActive: true,
    );
    employees.add(emp);
    return emp;
  }

  @override
  Future<EmployeeModel> updateEmployee(
    String id, {
    String? fullName,
    String? phone,
    String? role,
    bool? isActive,
  }) async {
    if (error != null) throw error!;
    final idx = employees.indexWhere((e) => e.id == id);
    final old = employees[idx];
    final updated = EmployeeModel(
      id: old.id,
      businessId: old.businessId,
      fullName: fullName ?? old.fullName,
      email: old.email,
      phone: phone ?? old.phone,
      role: role ?? old.role,
      isActive: isActive ?? old.isActive,
    );
    employees[idx] = updated;
    return updated;
  }

  @override
  Future<void> deactivateEmployee(String id) async {
    if (error != null) throw error!;
    final idx = employees.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final old = employees[idx];
      employees[idx] = EmployeeModel(
        id: old.id,
        businessId: old.businessId,
        fullName: old.fullName,
        email: old.email,
        phone: old.phone,
        role: old.role,
        isActive: false,
      );
    }
  }
}

void main() {
  group('EmployeesController Unit Tests', () {
    late FakeEmployeesRepository repo;

    setUp(() {
      repo = FakeEmployeesRepository();
      repo.employees = [
        const EmployeeModel(
          id: 'emp_1',
          businessId: 'biz_1',
          fullName: 'Alice Smith',
          email: 'alice@example.com',
          role: 'CASHIER',
          isActive: true,
        ),
        const EmployeeModel(
          id: 'emp_2',
          businessId: 'biz_1',
          fullName: 'Bob Johnson',
          email: 'bob@example.com',
          role: 'MANAGER',
          isActive: true,
        ),
      ];
    });

    test('initial load populates employees with loaded status', () async {
      final controller = EmployeesController(repo);
      await Future.delayed(Duration.zero); // await constructor load

      expect(controller.state.status, EmployeesStatus.loaded);
      expect(controller.state.employees.length, 2);
      expect(controller.state.employees.first.fullName, 'Alice Smith');
    });

    test('filtering by search query matches name, email, or role', () async {
      final controller = EmployeesController(repo);
      await Future.delayed(Duration.zero);

      controller.onSearchChanged('alice');
      expect(controller.state.filtered.length, 1);
      expect(controller.state.filtered.first.fullName, 'Alice Smith');

      controller.onSearchChanged('manager');
      expect(controller.state.filtered.length, 1);
      expect(controller.state.filtered.first.fullName, 'Bob Johnson');

      controller.onSearchChanged('nonexistent');
      expect(controller.state.filtered.isEmpty, true);

      controller.onSearchChanged('');
      expect(controller.state.filtered.length, 2);
    });

    test('addEmployee adds to state and returns true', () async {
      final controller = EmployeesController(repo);
      await Future.delayed(Duration.zero);

      final ok = await controller.addEmployee(
        fullName: 'Charlie Brown',
        email: 'charlie@example.com',
        password: 'password123',
        role: 'CASHIER',
      );

      expect(ok, true);
      expect(controller.state.employees.length, 3);
      expect(controller.state.employees.first.fullName, 'Charlie Brown');
    });

    test('changeRole updates the specific employee in state', () async {
      final controller = EmployeesController(repo);
      await Future.delayed(Duration.zero);

      final ok = await controller.changeRole('emp_1', 'MANAGER');

      expect(ok, true);
      final updated = controller.state.employees.firstWhere((e) => e.id == 'emp_1');
      expect(updated.role, 'MANAGER');
      expect(updated.isManager, true);
    });

    test('deactivate sets isActive to false in local state', () async {
      final controller = EmployeesController(repo);
      await Future.delayed(Duration.zero);

      final ok = await controller.deactivate('emp_1');

      expect(ok, true);
      final updated = controller.state.employees.firstWhere((e) => e.id == 'emp_1');
      expect(updated.isActive, false);
    });

    test('error handling sets error status and clean message on failure', () async {
      repo.error = const ApiException(message: 'Network timeout', statusCode: 504);
      final controller = EmployeesController(repo);
      await Future.delayed(Duration.zero);

      expect(controller.state.status, EmployeesStatus.error);
      expect(controller.state.errorMessage, 'Network timeout');
    });
  });
}
