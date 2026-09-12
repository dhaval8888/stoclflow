import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/employees_controller.dart';
import '../widgets/employee_card.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeesControllerProvider);
    final ctrl = ref.read(employeesControllerProvider.notifier);
    final currentUser = ref.watch(authControllerProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final employees = state.filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/employees/new'),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Member'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.space16,
              AppDimensions.space12,
              AppDimensions.space16,
              AppDimensions.space8,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: ctrl.onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or role...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ctrl.onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space16,
                  vertical: AppDimensions.space12,
                ),
                filled: true,
                fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: AppDimensions.borderRadiusMd,
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppDimensions.borderRadiusMd,
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ctrl.load(),
              child: Builder(
                builder: (context) {
                  if (state.isLoading && state.employees.isEmpty) {
                    return const LoadingView(message: 'Loading team members...');
                  }

                  if (state.hasError && state.employees.isEmpty) {
                    return ErrorStateView(
                      message: state.errorMessage ?? 'Failed to load team members',
                      onRetry: () => ctrl.load(),
                    );
                  }

                  if (employees.isEmpty) {
                    if (state.searchQuery.isNotEmpty) {
                      return EmptyStateView(
                        icon: Icons.search_off_rounded,
                        title: 'No matching team members',
                        subtitle: 'No employees found matching "${state.searchQuery}".',
                      );
                    }
                    return EmptyStateView(
                      icon: Icons.people_outline_rounded,
                      title: 'No team members added yet',
                      subtitle: 'Add cashiers and managers to help run your business.',
                      actionText: 'Add Member',
                      onAction: () => context.push('/employees/new'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(AppDimensions.space16),
                    itemCount: employees.length,
                    itemBuilder: (context, index) {
                      final emp = employees[index];
                      final isCurrent = emp.id == currentUser?.id;

                      return EmployeeCard(
                        employee: emp,
                        isCurrentUser: isCurrent,
                        onRoleChangeRequested: (newRole) async {
                          final success = await ctrl.changeRole(emp.id, newRole);
                          if (!context.mounted) return;
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${emp.fullName}\'s role changed to $newRole'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(state.errorMessage ?? 'Failed to update role'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                        onDeactivateRequested: () async {
                          final success = await ctrl.deactivate(emp.id);
                          if (!context.mounted) return;
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${emp.fullName} has been deactivated'),
                                backgroundColor: AppColors.textSecondaryLight,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(state.errorMessage ?? 'Failed to deactivate employee'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
