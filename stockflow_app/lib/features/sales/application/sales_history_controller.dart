import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../inventory/application/inventory_controller.dart';
import '../../products/application/products_controller.dart';
import '../data/models/sale_model.dart';
import '../data/repositories/sales_repository.dart';

class SalesHistoryState {
  final List<SaleModel> sales;
  final int total;
  final int page;
  final bool isLoading;
  final String? errorMessage;

  const SalesHistoryState({
    this.sales = const [],
    this.total = 0,
    this.page = 1,
    this.isLoading = false,
    this.errorMessage,
  });

  SalesHistoryState copyWith({
    List<SaleModel>? sales,
    int? total,
    int? page,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SalesHistoryState(
      sales: sales ?? this.sales,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final salesHistoryControllerProvider =
    StateNotifierProvider<SalesHistoryController, SalesHistoryState>((ref) {
  final repo = ref.watch(salesRepositoryProvider);
  return SalesHistoryController(repo, ref);
});

class SalesHistoryController extends StateNotifier<SalesHistoryState> {
  final SalesRepository _repository;
  final Ref _ref;

  SalesHistoryController(this._repository, this._ref) : super(const SalesHistoryState()) {
    loadSales();
  }

  Future<void> loadSales() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _repository.listSales(page: 1, limit: 50);
      state = state.copyWith(
        sales: res.sales,
        total: res.total,
        page: 1,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ApiException.getErrorMessage(e),
      );
    }
  }

  Future<void> voidSale(String saleId) async {
    try {
      await _repository.voidSale(saleId);

      // Update in local state list
      state = state.copyWith(
        sales: state.sales.map((s) => s.id == saleId ? s.copyWith(status: 'VOIDED') : s).toList(),
      );

      // Refresh inventory and products because inventory was atomically restored!
      _ref.read(inventoryControllerProvider.notifier).loadAll();
      _ref.read(productsControllerProvider.notifier).refresh();
    } catch (e) {
      rethrow;
    }
  }
}

extension SaleModelExtension on SaleModel {
  SaleModel copyWith({
    String? id,
    String? invoiceNumber,
    String? businessId,
    String? cashierId,
    String? cashierName,
    String? status,
    String? paymentMethod,
    double? subtotal,
    double? taxAmount,
    double? discountAmount,
    double? totalAmount,
    String? note,
    List<SaleItemModel>? items,
    DateTime? createdAt,
  }) {
    return SaleModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      businessId: businessId ?? this.businessId,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      note: note ?? this.note,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
