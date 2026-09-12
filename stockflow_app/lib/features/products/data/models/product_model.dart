import 'product_image_model.dart';

class ProductModel {
  final String id;
  final String businessId;
  final String? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final String name;
  final String? description;
  final String? sku;
  final String? barcode;
  final String unit;
  final double? costPrice; // Sensitive: null for cashiers
  final double sellingPrice;
  final int lowStockThreshold;
  final bool isActive;
  final int currentQuantity;
  final String stockStatus; // IN_STOCK, LOW_STOCK, OUT_OF_STOCK
  final List<ProductImageModel> images;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.businessId,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    required this.name,
    this.description,
    this.sku,
    this.barcode,
    this.unit = 'pcs',
    this.costPrice,
    required this.sellingPrice,
    this.lowStockThreshold = 10,
    this.isActive = true,
    this.currentQuantity = 0,
    this.stockStatus = 'OUT_OF_STOCK',
    this.images = const [],
    this.createdAt,
    this.updatedAt,
  });

  String? get primaryImageUrl {
    if (images.isEmpty) return null;
    final primary = images.firstWhere((img) => img.isPrimary, orElse: () => images.first);
    return primary.url;
  }

  bool get isLowStock => currentQuantity > 0 && currentQuantity <= lowStockThreshold;
  bool get isOutOfStock => currentQuantity <= 0;

  double? get profitMargin {
    if (costPrice == null || costPrice! <= 0) return null;
    return ((sellingPrice - costPrice!) / sellingPrice) * 100;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final imagesList = (json['images'] as List<dynamic>? ?? [])
        .map((img) => ProductImageModel.fromJson(img as Map<String, dynamic>))
        .toList();

    return ProductModel(
      id: json['id'] as String,
      businessId: (json['business_id'] ?? json['businessId'] ?? '') as String,
      categoryId: (json['category_id'] ?? json['categoryId']) as String?,
      categoryName: (json['category_name'] ?? json['categoryName']) as String?,
      categoryColor: (json['category_color'] ?? json['categoryColor']) as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      unit: (json['unit'] as String?) ?? 'pcs',
      costPrice: json['cost_price'] != null ? double.tryParse(json['cost_price'].toString()) : null,
      sellingPrice: double.tryParse((json['selling_price'] ?? json['sellingPrice'] ?? '0').toString()) ?? 0.0,
      lowStockThreshold: (double.tryParse((json['low_stock_threshold'] ?? json['lowStockThreshold'] ?? '10').toString()) ?? 10).round(),
      isActive: json['is_active'] as bool? ?? true,
      currentQuantity: (double.tryParse((json['current_quantity'] ?? json['stock_quantity'] ?? json['currentQuantity'] ?? json['quantity'] ?? '0').toString()) ?? 0).round(),
      stockStatus: (json['stock_status'] ?? json['stockStatus'] ?? 'OUT_OF_STOCK') as String,
      images: imagesList,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      if (categoryId != null) 'category_id': categoryId,
      'name': name,
      if (description != null) 'description': description,
      if (sku != null) 'sku': sku,
      if (barcode != null) 'barcode': barcode,
      'unit': unit,
      if (costPrice != null) 'cost_price': costPrice,
      'selling_price': sellingPrice,
      'low_stock_threshold': lowStockThreshold,
      'is_active': isActive,
    };
  }

  ProductModel copyWith({
    String? id,
    String? businessId,
    String? categoryId,
    String? categoryName,
    String? categoryColor,
    String? name,
    String? description,
    String? sku,
    String? barcode,
    String? unit,
    double? costPrice,
    double? sellingPrice,
    int? lowStockThreshold,
    bool? isActive,
    int? currentQuantity,
    String? stockStatus,
    List<ProductImageModel>? images,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryColor: categoryColor ?? this.categoryColor,
      name: name ?? this.name,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isActive: isActive ?? this.isActive,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      stockStatus: stockStatus ?? this.stockStatus,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
