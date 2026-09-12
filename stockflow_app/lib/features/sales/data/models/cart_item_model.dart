import '../../../products/data/models/product_model.dart';

class CartItemModel {
  final ProductModel product;
  final int quantity;
  final double discount; // discount in currency

  const CartItemModel({
    required this.product,
    this.quantity = 1,
    this.discount = 0.0,
  });

  double get unitPrice => product.sellingPrice;
  double get lineTotal => (unitPrice * quantity) - discount;

  CartItemModel copyWith({
    ProductModel? product,
    int? quantity,
    double? discount,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
    );
  }

  Map<String, dynamic> toApiJson() {
    return {
      'productId': product.id,
      'quantity': quantity,
      'discount': discount,
    };
  }
}
