import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/category.dart';
import '../data/repositories/category_repository.dart';
import 'database_provider.dart';

class CategoryManagementState {
  final List<Category> allCategories;
  final bool isLoading;
  final String? error;

  const CategoryManagementState({
    this.allCategories = const [],
    this.isLoading = false,
    this.error,
  });

  List<Category> get expenseCategories =>
      allCategories.where((c) => c.type == 'expense').toList();

  List<Category> get incomeCategories =>
      allCategories.where((c) => c.type == 'income').toList();

  List<Category> get transferCategories =>
      allCategories.where((c) => c.type == 'transfer').toList();

  CategoryManagementState copyWith({
    List<Category>? allCategories,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CategoryManagementState(
      allCategories: allCategories ?? this.allCategories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CategoryManagementNotifier extends Notifier<CategoryManagementState> {
  CategoryRepository get _repository => ref.read(categoryRepositoryProvider);

  @override
  CategoryManagementState build() {
    Future.microtask(loadCategories);
    return const CategoryManagementState(isLoading: true);
  }

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _repository.getAllCategories();
      if (!ref.mounted) return;
      state = state.copyWith(allCategories: list, isLoading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createCategory(Category category) async {
    try {
      await _repository.createCategory(category);
      await loadCategories();
      ref.invalidate(categoriesProvider);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create category: $e');
      return false;
    }
  }

  Future<bool> updateCategory(Category category) async {
    try {
      await _repository.updateCategory(category);
      await loadCategories();
      ref.invalidate(categoriesProvider);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update category: $e');
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      await _repository.deleteCategory(id);
      await loadCategories();
      ref.invalidate(categoriesProvider);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete category: $e');
      return false;
    }
  }

  Future<int> getTransactionCount(String id) async {
    return await _repository.getCategoryTransactionCount(id);
  }
}

final categoryManagementProvider =
    NotifierProvider<CategoryManagementNotifier, CategoryManagementState>(
  CategoryManagementNotifier.new,
);

final categoriesProvider = FutureProvider.family<List<Category>, String?>((ref, type) async {
  // Watching categoryManagementProvider ensures this FutureProvider re-evaluates when categories change
  final mgmt = ref.watch(categoryManagementProvider);
  if (type == null || type == 'all') {
    return mgmt.allCategories;
  }
  return mgmt.allCategories.where((c) => c.type == type).toList();
});

