class InventoryItemModel {
  final String id;
  final String productId;
  final String productName;
  final String? sku;
  final String? barcode;
  final String unit;
  final String? categoryName;
  final String? categoryColor;
  final int currentQuantity;
  final int lowStockThreshold;
  final String stockStatus; // IN_STOCK, LOW_STOCK, OUT_OF_STOCK
  final DateTime? updatedAt;

  const InventoryItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.sku,
    this.barcode,
    this.unit = 'pcs',
    this.categoryName,
    this.categoryColor,
    required this.currentQuantity,
    required this.lowStockThreshold,
    required this.stockStatus,
    this.updatedAt,
  });

  bool get isLowStock => stockStatus == 'LOW_STOCK';
  bool get isOutOfStock => stockStatus == 'OUT_OF_STOCK';

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    final prodId = (json['product_id'] ?? json['productId'] ?? json['id'] ?? '') as String;
    return InventoryItemModel(
      id: (json['inventory_id'] ?? json['id'] ?? prodId) as String,
      productId: prodId,
      productName: (json['product_name'] ?? json['name'] ?? '') as String,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      unit: (json['unit'] as String?) ?? 'pcs',
      categoryName: json['category_name'] as String?,
      categoryColor: json['category_color'] as String?,
      currentQuantity: (double.tryParse((json['current_quantity'] ?? json['quantity'] ?? json['stock_quantity'] ?? '0').toString()) ?? 0).round(),
      lowStockThreshold: (double.tryParse((json['low_stock_threshold'] ?? '10').toString()) ?? 10).round(),
      stockStatus: (json['stock_status'] ?? 'OUT_OF_STOCK') as String,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}
