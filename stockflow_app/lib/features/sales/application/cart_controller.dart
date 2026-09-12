import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../products/data/models/product_model.dart';
import '../data/models/cart_item_model.dart';

class CartState {
  final List<CartItemModel> items;
  final double discountAmount; // Order-level discount
  final double taxRate; // e.g. 0.05 for 5% tax

  const CartState({
    this.items = const [],
    this.discountAmount = 0.0,
    this.taxRate = 0.0, // Default 0% unless specified
  });

  int get totalItemCount => items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotalPreview => items.fold(0.0, (sum, i) => sum + i.lineTotal);

  double get taxPreview {
    final taxable = subtotalPreview - discountAmount;
    return taxable > 0 ? taxable * taxRate : 0.0;
  }

  double get grandTotalPreview {
    final base = subtotalPreview - discountAmount;
    final total = base + taxPreview;
    return total > 0 ? total : 0.0;
  }

  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItemModel>? items,
    double? discountAmount,
    double? taxRate,
  }) {
    return CartState(
      items: items ?? this.items,
      discountAmount: discountAmount ?? this.discountAmount,
      taxRate: taxRate ?? this.taxRate,
    );
  }
}

final cartControllerProvider = StateNotifierProvider<CartController, CartState>((ref) {
  return CartController();
});

class CartController extends StateNotifier<CartState> {
  CartController() : super(const CartState());

  void addProduct(ProductModel product) {
    if (!product.isActive || product.currentQuantity <= 0) return;

    final existingIndex = state.items.indexWhere((i) => i.product.id == product.id);

    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      // Only allow if within available stock
      if (existing.quantity < product.currentQuantity) {
        final updatedList = [...state.items];
        updatedList[existingIndex] = existing.copyWith(quantity: existing.quantity + 1);
        state = state.copyWith(items: updatedList);
      }
    } else {
      state = state.copyWith(items: [...state.items, CartItemModel(product: product, quantity: 1)]);
    }
  }

  void increment(String productId) {
    final existingIndex = state.items.indexWhere((i) => i.product.id == productId);
    if (existingIndex < 0) return;

    final existing = state.items[existingIndex];
    if (existing.quantity < existing.product.currentQuantity) {
      final updatedList = [...state.items];
      updatedList[existingIndex] = existing.copyWith(quantity: existing.quantity + 1);
      state = state.copyWith(items: updatedList);
    }
  }

  void decrement(String productId) {
    final existingIndex = state.items.indexWhere((i) => i.product.id == productId);
    if (existingIndex < 0) return;

    final existing = state.items[existingIndex];
    if (existing.quantity > 1) {
      final updatedList = [...state.items];
      updatedList[existingIndex] = existing.copyWith(quantity: existing.quantity - 1);
      state = state.copyWith(items: updatedList);
    } else {
      removeItem(productId);
    }
  }

  void removeItem(String productId) {
    state = state.copyWith(items: state.items.where((i) => i.product.id != productId).toList());
  }

  void setDiscount(double discount) {
    state = state.copyWith(discountAmount: discount >= 0 ? discount : 0.0);
  }

  void clearCart() {
    state = const CartState();
  }
}
