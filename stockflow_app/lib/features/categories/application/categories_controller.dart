import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/category_model.dart';
import '../data/repositories/categories_repository.dart';

final categoriesControllerProvider =
    StateNotifierProvider<CategoriesController, AsyncValue<List<CategoryModel>>>((ref) {
  final repo = ref.watch(categoriesRepositoryProvider);
  return CategoriesController(repo);
});

final activeCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final state = ref.watch(categoriesControllerProvider);
  return state.maybeWhen(
    data: (categories) => categories.where((c) => c.isActive).toList(),
    orElse: () => [],
  );
});

class CategoriesController extends StateNotifier<AsyncValue<List<CategoryModel>>> {
  final CategoriesRepository _repository;

  CategoriesController(this._repository) : super(const AsyncValue.loading()) {
    loadCategories();
  }

  Future<void> loadCategories({bool? isActive}) async {
    state = const AsyncValue.loading();
    try {
      final categories = await _repository.getCategories(isActive: isActive);
      state = AsyncValue.data(categories);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<CategoryModel> createCategory({
    required String name,
    String? description,
    String? color,
    String? icon,
  }) async {
    try {
      final created = await _repository.createCategory(
        name: name,
        description: description,
        color: color,
        icon: icon,
      );
      final current = state.value ?? [];
      state = AsyncValue.data([...current, created]);
      return created;
    } catch (e) {
      rethrow;
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
      final updated = await _repository.updateCategory(
        id,
        name: name,
        description: description,
        color: color,
        icon: icon,
        isActive: isActive,
      );
      final current = state.value ?? [];
      state = AsyncValue.data(
        current.map((c) => c.id == id ? updated : c).toList(),
      );
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _repository.deleteCategory(id);
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((c) => c.id != id).toList());
    } catch (e) {
      rethrow;
    }
  }
}
