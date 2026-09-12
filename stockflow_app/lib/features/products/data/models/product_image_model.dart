class ProductImageModel {
  final String id;
  final String productId;
  final String cloudinaryId;
  final String url;
  final bool isPrimary;
  final DateTime? createdAt;

  const ProductImageModel({
    required this.id,
    required this.productId,
    required this.cloudinaryId,
    required this.url,
    this.isPrimary = false,
    this.createdAt,
  });

  factory ProductImageModel.fromJson(Map<String, dynamic> json) {
    return ProductImageModel(
      id: json['id'] as String,
      productId: (json['product_id'] ?? json['productId']) as String? ?? '',
      cloudinaryId: (json['cloudinary_id'] ?? json['cloudinaryId']) as String? ?? '',
      url: json['url'] as String? ?? '',
      isPrimary: (json['is_primary'] ?? json['isPrimary']) as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'cloudinary_id': cloudinaryId,
      'url': url,
      'is_primary': isPrimary,
    };
  }
}
