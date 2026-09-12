class InventoryTransactionModel {
  final String id;
  final String productId;
  final String? productName;
  final String? sku;
  final String? unit;
  final String? userName;
  final String type; // STOCK_IN, STOCK_OUT, ADJUSTMENT, SALE, VOID_RETURN
  final int quantity; // Delta
  final int quantityBefore;
  final int quantityAfter;
  final String? note;
  final DateTime? createdAt;

  const InventoryTransactionModel({
    required this.id,
    required this.productId,
    this.productName,
    this.sku,
    this.unit = 'pcs',
    this.userName,
    required this.type,
    required this.quantity,
    required this.quantityBefore,
    required this.quantityAfter,
    this.note,
    this.createdAt,
  });

  factory InventoryTransactionModel.fromJson(Map<String, dynamic> json) {
    return InventoryTransactionModel(
      id: json['id'] as String,
      productId: (json['product_id'] ?? json['productId']) as String,
      productName: json['product_name'] as String?,
      sku: json['sku'] as String?,
      unit: (json['unit'] as String?) ?? 'pcs',
      userName: (json['user_name'] ?? json['userName']) as String?,
      type: json['type'] as String,
      quantity: (double.tryParse((json['quantity'] ?? '0').toString()) ?? 0).round(),
      quantityBefore: (double.tryParse((json['quantity_before'] ?? json['quantityBefore'] ?? '0').toString()) ?? 0).round(),
      quantityAfter: (double.tryParse((json['quantity_after'] ?? json['quantityAfter'] ?? '0').toString()) ?? 0).round(),
      note: json['note'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}
