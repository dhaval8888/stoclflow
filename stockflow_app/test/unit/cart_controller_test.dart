import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_app/features/products/data/models/product_model.dart';
import 'package:stockflow_app/features/sales/application/cart_controller.dart';

ProductModel _createTestProduct({
  required String id,
  required String name,
  required double price,
  int stock = 10,
  bool active = true,
}) {
  return ProductModel(
    id: id,
    businessId: 'biz-1',
    name: name,
    sellingPrice: price,
    currentQuantity: stock,
    isActive: active,
    stockStatus: stock > 0 ? 'IN_STOCK' : 'OUT_OF_STOCK',
  );
}

void main() {
  late CartController cartController;

  setUp(() {
    cartController = CartController();
  });

  group('CartController Unit Tests', () {
    test('initial state is empty with zero totals', () {
      expect(cartController.state.items, isEmpty);
      expect(cartController.state.isEmpty, true);
      expect(cartController.state.totalItemCount, 0);
      expect(cartController.state.subtotalPreview, 0.0);
      expect(cartController.state.taxPreview, 0.0);
      expect(cartController.state.grandTotalPreview, 0.0);
    });

    test('addProduct adds in-stock item to cart', () {
      final p1 = _createTestProduct(id: 'p1', name: 'Widget A', price: 20.0, stock: 5);

      cartController.addProduct(p1);

      expect(cartController.state.items.length, 1);
      expect(cartController.state.items.first.product.id, 'p1');
      expect(cartController.state.items.first.quantity, 1);
      expect(cartController.state.subtotalPreview, 20.0);
      expect(cartController.state.grandTotalPreview, 20.0);
      expect(cartController.state.isEmpty, false);
    });

    test('addProduct rejects inactive or out-of-stock items', () {
      final inactiveProduct = _createTestProduct(
        id: 'p_inactive',
        name: 'Discontinued',
        price: 15.0,
        active: false,
      );
      final outOfStockProduct = _createTestProduct(
        id: 'p_out',
        name: 'Empty Stock',
        price: 30.0,
        stock: 0,
      );

      cartController.addProduct(inactiveProduct);
      expect(cartController.state.items, isEmpty);

      cartController.addProduct(outOfStockProduct);
      expect(cartController.state.items, isEmpty);
    });

    test('addProduct increments quantity when same product is added up to stock limit', () {
      final p1 = _createTestProduct(id: 'p1', name: 'Limited Stock Item', price: 10.0, stock: 2);

      cartController.addProduct(p1);
      expect(cartController.state.items.first.quantity, 1);

      // Second add increments to 2
      cartController.addProduct(p1);
      expect(cartController.state.items.first.quantity, 2);

      // Third add exceeds stock limit (stock = 2), must NOT increment
      cartController.addProduct(p1);
      expect(cartController.state.items.first.quantity, 2);
      expect(cartController.state.subtotalPreview, 20.0);
    });

    test('increment increases quantity until stock limit', () {
      final p1 = _createTestProduct(id: 'p1', name: 'Item', price: 15.0, stock: 3);
      cartController.addProduct(p1);

      cartController.increment('p1');
      expect(cartController.state.items.first.quantity, 2);

      cartController.increment('p1');
      expect(cartController.state.items.first.quantity, 3);

      // Reached maximum stock limit
      cartController.increment('p1');
      expect(cartController.state.items.first.quantity, 3);
    });

    test('decrement decreases quantity and removes item when reaching 0', () {
      final p1 = _createTestProduct(id: 'p1', name: 'Item', price: 10.0, stock: 5);
      cartController.addProduct(p1);
      cartController.increment('p1'); // qty: 2

      cartController.decrement('p1');
      expect(cartController.state.items.first.quantity, 1);

      // Decrementing when qty is 1 removes the item from cart
      cartController.decrement('p1');
      expect(cartController.state.items, isEmpty);
      expect(cartController.state.isEmpty, true);
    });

    test('removeItem removes product directly', () {
      final p1 = _createTestProduct(id: 'p1', name: 'Item 1', price: 10.0);
      final p2 = _createTestProduct(id: 'p2', name: 'Item 2', price: 20.0);

      cartController.addProduct(p1);
      cartController.addProduct(p2);
      expect(cartController.state.items.length, 2);

      cartController.removeItem('p1');
      expect(cartController.state.items.length, 1);
      expect(cartController.state.items.first.product.id, 'p2');
    });

    test('preview calculations with order discount and tax rate', () {
      final p1 = _createTestProduct(id: 'p1', name: 'Item 1', price: 50.0, stock: 10);
      final p2 = _createTestProduct(id: 'p2', name: 'Item 2', price: 50.0, stock: 10);

      cartController.addProduct(p1);
      cartController.addProduct(p2);
      expect(cartController.state.subtotalPreview, 100.0);

      // Apply $10 discount
      cartController.setDiscount(10.0);
      expect(cartController.state.discountAmount, 10.0);

      // Apply 10% tax rate
      cartController.state = cartController.state.copyWith(taxRate: 0.10);

      // Subtotal = 100, Taxable = 100 - 10 = 90
      // Tax = 90 * 0.10 = 9.0
      // Grand Total = 90 + 9.0 = 99.0
      expect(cartController.state.subtotalPreview, 100.0);
      expect(cartController.state.taxPreview, 9.0);
      expect(cartController.state.grandTotalPreview, 99.0);
    });

    test('negative discount is clamped to zero', () {
      cartController.setDiscount(-20.0);
      expect(cartController.state.discountAmount, 0.0);
    });

    test('clearCart resets all items, discounts, and totals', () {
      final p1 = _createTestProduct(id: 'p1', name: 'Item 1', price: 25.0);
      cartController.addProduct(p1);
      cartController.setDiscount(5.0);

      expect(cartController.state.isEmpty, false);

      cartController.clearCart();

      expect(cartController.state.items, isEmpty);
      expect(cartController.state.discountAmount, 0.0);
      expect(cartController.state.grandTotalPreview, 0.0);
    });
  });
}
