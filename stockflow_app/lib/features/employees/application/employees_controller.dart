import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exceptions.dart';
import '../data/models/employee_model.dart';
import '../data/repositories/employees_repository.dart';

enum EmployeesStatus { initial, loading, loaded, error }

class EmployeesState {
  final List<EmployeeModel> employees;
  final EmployeesStatus status;
  final String? errorMessage;
  final String searchQuery;

  const EmployeesState({
    this.employees = const [],
    this.status = EmployeesStatus.initial,
    this.errorMessage,
    this.searchQuery = '',
  });

  bool get isLoading => status == EmployeesStatus.loading;
  bool get isLoaded => status == EmployeesStatus.loaded;
  bool get hasError => status == EmployeesStatus.error;
  bool get isEmpty => status == EmployeesStatus.loaded && employees.isEmpty;

  List<EmployeeModel> get filtered {
    if (searchQuery.isEmpty) return employees;
    final q = searchQuery.toLowerCase();
    return employees
        .where((e) =>
            e.fullName.toLowerCase().contains(q) ||
            e.email.toLowerCase().contains(q) ||
            e.role.toLowerCase().contains(q))
        .toList();
  }

  EmployeesState copyWith({
    List<EmployeeModel>? employees,
    EmployeesStatus? status,
    String? errorMessage,
    String? searchQuery,
    bool clearError = false,
  }) {
    return EmployeesState(
      employees: employees ?? this.employees,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final employeesControllerProvider =
    StateNotifierProvider.autoDispose<EmployeesController, EmployeesState>((ref) {
  return EmployeesController(ref.read(employeesRepositoryProvider));
});

class EmployeesController extends StateNotifier<EmployeesState> {
  final EmployeesRepository _repository;

  EmployeesController(this._repository) : super(const EmployeesState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: EmployeesStatus.loading, clearError: true);
    try {
      final res = await _repository.listEmployees(limit: 100);
      state = state.copyWith(
        employees: res.employees,
        status: EmployeesStatus.loaded,
      );
    } catch (e) {
      state = state.copyWith(
        status: EmployeesStatus.error,
        errorMessage: ApiException.getErrorMessage(e),
      );
    }
  }

  void onSearchChanged(String query) {
    state = state.copyWith(searchQuery: query.trim());
  }

  Future<bool> addEmployee({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    try {
      final newEmployee = await _repository.addEmployee(
        fullName: fullName,
        email: email,
        password: password,
        role: role,
        phone: phone,
      );
      state = state.copyWith(
        employees: [newEmployee, ...state.employees],
        status: EmployeesStatus.loaded,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: ApiException.getErrorMessage(e));
      return false;
    }
  }

  Future<bool> changeRole(String id, String newRole) async {
    try {
      final updated = await _repository.updateEmployee(id, role: newRole);
      state = state.copyWith(
        employees: state.employees.map((e) => e.id == id ? updated : e).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: ApiException.getErrorMessage(e));
      return false;
    }
  }

  Future<bool> deactivate(String id) async {
    try {
      await _repository.deactivateEmployee(id);
      // Mark local as inactive instead of removing (preserves list stability)
      state = state.copyWith(
        employees: state.employees
            .map((e) => e.id == id
                ? EmployeeModel(
                    id: e.id,
                    businessId: e.businessId,
                    fullName: e.fullName,
                    email: e.email,
                    phone: e.phone,
                    role: e.role,
                    isActive: false,
                    lastLoginAt: e.lastLoginAt,
                    createdAt: e.createdAt,
                  )
                : e)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: ApiException.getErrorMessage(e));
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
