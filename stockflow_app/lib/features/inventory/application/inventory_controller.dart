import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../products/application/products_controller.dart';
import '../data/models/inventory_item_model.dart';
import '../data/models/inventory_transaction_model.dart';
import '../data/repositories/inventory_repository.dart';

class InventoryState {
  final List<InventoryItemModel> items;
  final List<InventoryTransactionModel> transactions;
  final int totalItems;
  final int lowStockCount;
  final int outOfStockCount;
  final bool isLoading;
  final bool isLoadingTransactions;
  final String? errorMessage;
  final String searchQuery;
  final int selectedTab; // 0: All, 1: Low, 2: Out, 3: Audit

  const InventoryState({
    this.items = const [],
    this.transactions = const [],
    this.totalItems = 0,
    this.lowStockCount = 0,
    this.outOfStockCount = 0,
    this.isLoading = false,
    this.isLoadingTransactions = false,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedTab = 0,
  });

  List<InventoryItemModel> get filteredItems {
    if (searchQuery.trim().isEmpty) {
      if (selectedTab == 1) return items.where((i) => i.isLowStock).toList();
      if (selectedTab == 2) return items.where((i) => i.isOutOfStock).toList();
      return items;
    }

    final q = searchQuery.toLowerCase();
    final list = items.where((i) {
      return i.productName.toLowerCase().contains(q) ||
          (i.sku?.toLowerCase().contains(q) ?? false) ||
          (i.barcode?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (selectedTab == 1) return list.where((i) => i.isLowStock).toList();
    if (selectedTab == 2) return list.where((i) => i.isOutOfStock).toList();
    return list;
  }

  InventoryState copyWith({
    List<InventoryItemModel>? items,
    List<InventoryTransactionModel>? transactions,
    int? totalItems,
    int? lowStockCount,
    int? outOfStockCount,
    bool? isLoading,
    bool? isLoadingTransactions,
    String? errorMessage,
    String? searchQuery,
    int? selectedTab,
  }) {
    return InventoryState(
      items: items ?? this.items,
      transactions: transactions ?? this.transactions,
      totalItems: totalItems ?? this.totalItems,
      lowStockCount: lowStockCount ?? this.lowStockCount,
      outOfStockCount: outOfStockCount ?? this.outOfStockCount,
      isLoading: isLoading ?? this.isLoading,
      isLoadingTransactions: isLoadingTransactions ?? this.isLoadingTransactions,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}

final inventoryControllerProvider =
    StateNotifierProvider<InventoryController, InventoryState>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return InventoryController(repo, ref);
});

class InventoryController extends StateNotifier<InventoryState> {
  final InventoryRepository _repository;
  final Ref _ref;

  InventoryController(this._repository, this._ref) : super(const InventoryState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final stockRes = await _repository.getStock(limit: 100);
      final lowStockList = await _repository.getLowStock();
      final outOfStockList = await _repository.getOutOfStock();

      state = state.copyWith(
        items: stockRes.items,
        totalItems: stockRes.total,
        lowStockCount: lowStockList.length,
        outOfStockCount: outOfStockList.length,
        isLoading: false,
      );

      // Also background fetch recent audit transactions
      loadTransactions();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ApiException.getErrorMessage(e),
      );
    }
  }

  Future<void> loadTransactions() async {
    state = state.copyWith(isLoadingTransactions: true);
    try {
      final txRes = await _repository.getTransactions(limit: 50);
      state = state.copyWith(
        transactions: txRes.transactions,
        isLoadingTransactions: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingTransactions: false,
        errorMessage: ApiException.getErrorMessage(e),
      );
    }
  }

  void setTab(int tabIndex) {
    state = state.copyWith(selectedTab: tabIndex);
  }

  void onSearchChanged(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<InventoryTransactionModel> performMovement({
    required String productId,
    required String type, // 'STOCK_IN', 'STOCK_OUT', 'ADJUSTMENT'
    required int quantity,
    String? note,
  }) async {
    try {
      final tx = await _repository.createTransaction(
        productId: productId,
        type: type,
        quantity: quantity,
        note: note,
      );

      // Refresh local inventory state
      await loadAll();

      // Trigger products refresh so catalog displays updated stock quantity
      _ref.read(productsControllerProvider.notifier).refresh();

      return tx;
    } catch (e) {
      rethrow;
    }
  }
}
