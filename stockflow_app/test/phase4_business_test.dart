import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_app/features/categories/data/models/category_model.dart';
import 'package:stockflow_app/features/products/data/models/product_model.dart';
import 'package:stockflow_app/features/inventory/data/models/inventory_item_model.dart';
import 'package:stockflow_app/features/inventory/data/models/inventory_transaction_model.dart';
import 'package:stockflow_app/features/sales/application/cart_controller.dart';
import 'package:stockflow_app/features/sales/data/models/sale_model.dart';
import 'package:stockflow_app/features/sales/data/models/receipt_model.dart';

void main() {
  group('1. Categories Module Tests', () {
    test('parses CategoryModel from JSON correctly', () {
      final json = {
        'id': 'cat-123',
        'name': 'Beverages',
        'description': 'Hot and cold drinks',
        'color': '#2563EB',
        'icon': 'coffee',
        'is_active': true,
      };

      final category = CategoryModel.fromJson(json);
      expect(category.id, 'cat-123');
      expect(category.name, 'Beverages');
      expect(category.color, '#2563EB');
      expect(category.isActive, true);

      final outJson = category.toJson();
      expect(outJson['name'], 'Beverages');
      expect(outJson['color'], '#2563EB');
    });
  });

  group('2. Products & Role-Aware Sensitive Data Tests', () {
    test('computes profit margins when costPrice is provided (Owner/Manager)', () {
      final json = {
        'id': 'prod-1',
        'business_id': 'biz-1',
        'name': 'Espresso Beans 500g',
        'cost_price': 10.0,
        'selling_price': 25.0,
        'low_stock_threshold': 5,
        'current_quantity': 15,
        'stock_status': 'IN_STOCK',
        'is_active': true,
      };

      final product = ProductModel.fromJson(json);
      expect(product.costPrice, 10.0);
      expect(product.sellingPrice, 25.0);
      expect(product.isLowStock, false);
      expect(product.isOutOfStock, false);

      // Profit margin: ((25 - 10) / 25) * 100 = 60%
      expect(product.profitMargin, 60.0);
    });

    test('handles sanitized costPrice for Cashiers (null costPrice)', () {
      final json = {
        'id': 'prod-2',
        'business_id': 'biz-1',
        'name': 'Matcha Green Tea',
        // cost_price omitted / stripped by backend for CASHIER role
        'selling_price': 18.0,
        'low_stock_threshold': 5,
        'current_quantity': 3,
        'stock_status': 'LOW_STOCK',
        'is_active': true,
      };

      final product = ProductModel.fromJson(json);
      expect(product.costPrice, isNull);
      expect(product.profitMargin, isNull);
      expect(product.isLowStock, true);
      expect(product.isOutOfStock, false);
    });

    test('detects out of stock state correctly', () {
      final json = {
        'id': 'prod-3',
        'business_id': 'biz-1',
        'name': 'Paper Cups',
        'selling_price': 5.0,
        'low_stock_threshold': 10,
        'current_quantity': 0,
        'stock_status': 'OUT_OF_STOCK',
        'is_active': true,
      };

      final product = ProductModel.fromJson(json);
      expect(product.isOutOfStock, true);
    });
  });

  group('3. Inventory Movement Semantics Tests', () {
    test('parses inventory item stock levels and status', () {
      final json = {
        'id': 'inv-1',
        'product_id': 'prod-1',
        'product_name': 'Arabica Beans',
        'unit': 'kg',
        'current_quantity': 42,
        'low_stock_threshold': 10,
        'stock_status': 'IN_STOCK',
      };

      final item = InventoryItemModel.fromJson(json);
      expect(item.currentQuantity, 42);
      expect(item.unit, 'kg');
      expect(item.isLowStock, false);
      expect(item.isOutOfStock, false);
    });

    test('parses physical count adjustment transaction audit delta', () {
      final json = {
        'id': 'tx-1',
        'product_id': 'prod-1',
        'product_name': 'Arabica Beans',
        'type': 'ADJUSTMENT',
        'quantity': -3, // delta (42 -> 39)
        'quantity_before': 42,
        'quantity_after': 39,
        'note': 'Physical shelf count audit',
      };

      final tx = InventoryTransactionModel.fromJson(json);
      expect(tx.type, 'ADJUSTMENT');
      expect(tx.quantity, -3);
      expect(tx.quantityBefore, 42);
      expect(tx.quantityAfter, 39);
      expect(tx.note, 'Physical shelf count audit');
    });
  });

  group('4. POS Cart & UI Calculation Tests', () {
    const activeProduct = ProductModel(
      id: 'p1',
      businessId: 'b1',
      name: 'Cold Brew 250ml',
      sellingPrice: 4.50,
      currentQuantity: 10,
      isActive: true,
      stockStatus: 'IN_STOCK',
    );

    test('adds active in-stock product to cart and previews subtotal', () {
      final cartController = CartController();
      cartController.addProduct(activeProduct);

      expect(cartController.state.items.length, 1);
      expect(cartController.state.items.first.quantity, 1);
      expect(cartController.state.subtotalPreview, 4.50);
      expect(cartController.state.grandTotalPreview, 4.50);
    });

    test('increments quantity up to available stock limit', () {
      final cartController = CartController();
      cartController.addProduct(activeProduct);
      cartController.increment('p1');
      cartController.increment('p1');

      expect(cartController.state.items.first.quantity, 3);
      expect(cartController.state.subtotalPreview, 13.50);

      cartController.decrement('p1');
      expect(cartController.state.items.first.quantity, 2);
      expect(cartController.state.subtotalPreview, 9.00);
    });

    test('applies discounts and tax previews properly', () {
      final cartController = CartController();
      cartController.addProduct(activeProduct); // 4.50
      cartController.increment('p1'); // 9.00
      cartController.setDiscount(2.00); // 9.00 - 2.00 = 7.00

      expect(cartController.state.subtotalPreview, 9.00);
      expect(cartController.state.discountAmount, 2.00);
      expect(cartController.state.grandTotalPreview, 7.00);

      cartController.clearCart();
      expect(cartController.state.isEmpty, true);
    });

    test('rejects adding inactive or out-of-stock product to cart', () {
      const outOfStockProduct = ProductModel(
        id: 'p2',
        businessId: 'b1',
        name: 'Sold Out Pastry',
        sellingPrice: 3.00,
        currentQuantity: 0,
        isActive: true,
        stockStatus: 'OUT_OF_STOCK',
      );

      final cartController = CartController();
      cartController.addProduct(outOfStockProduct);
      expect(cartController.state.isEmpty, true);
    });
  });

  group('5. Sale & Receipt Verification Tests', () {
    test('parses receipt with line items and status', () {
      final json = {
        'business': {
          'name': 'StockFlow Central',
          'phone': '+1 555-0199',
          'address': '100 Market Street',
        },
        'sale': {
          'id': 'sale-999',
          'invoice_number': 'INV-2026-001',
          'business_id': 'b1',
          'cashier_id': 'u1',
          'cashier_name': 'Sarah Cashier',
          'status': 'COMPLETED',
          'payment_method': 'CASH',
          'subtotal': 20.0,
          'discount_amount': 2.0,
          'tax_amount': 0.90,
          'total_amount': 18.90,
        },
        'items': [
          {
            'id': 'item-1',
            'sale_id': 'sale-999',
            'product_id': 'p1',
            'product_name': 'Organic Coffee',
            'quantity': 2,
            'unit_price': 10.0,
            'subtotal': 20.0,
            'discount_amount': 2.0,
            'total_price': 18.0,
          }
        ],
      };

      final receipt = ReceiptModel.fromJson(json);
      expect(receipt.business.name, 'StockFlow Central');
      expect(receipt.sale.invoiceNumber, 'INV-2026-001');
      expect(receipt.sale.isCompleted, true);
      expect(receipt.sale.isVoided, false);
      expect(receipt.items.length, 1);
      expect(receipt.items.first.totalPrice, 18.0);
    });

    test('parses voided sale state correctly', () {
      final json = {
        'id': 'sale-999',
        'invoice_number': 'INV-2026-001',
        'business_id': 'b1',
        'cashier_id': 'u1',
        'status': 'VOIDED',
        'payment_method': 'CASH',
        'subtotal': 20.0,
        'total_amount': 20.0,
      };

      final sale = SaleModel.fromJson(json);
      expect(sale.isCompleted, false);
      expect(sale.isVoided, true);
    });
  });
}
