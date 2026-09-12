class SaleItemModel {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final String? sku;
  final String unit;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final double discountAmount;
  final double totalPrice;

  const SaleItemModel({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    this.sku,
    this.unit = 'pcs',
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.discountAmount = 0.0,
    required this.totalPrice,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    return SaleItemModel(
      id: (json['id'] ?? '') as String,
      saleId: (json['sale_id'] ?? json['saleId'] ?? '') as String,
      productId: (json['product_id'] ?? json['productId'] ?? '') as String,
      productName: (json['product_name'] ?? json['productName'] ?? json['name'] ?? 'Product') as String,
      sku: json['sku'] as String?,
      unit: (json['unit'] as String?) ?? 'pcs',
      quantity: int.tryParse((json['quantity'] ?? '1').toString()) ?? 1,
      unitPrice: double.tryParse((json['unit_price'] ?? json['unitPrice'] ?? '0').toString()) ?? 0.0,
      subtotal: double.tryParse((json['subtotal'] ?? '0').toString()) ?? 0.0,
      discountAmount: double.tryParse((json['discount_amount'] ?? json['discountAmount'] ?? '0').toString()) ?? 0.0,
      totalPrice: double.tryParse((json['total_price'] ?? json['totalPrice'] ?? '0').toString()) ?? 0.0,
    );
  }
}

class SaleModel {
  final String id;
  final String invoiceNumber;
  final String businessId;
  final String cashierId;
  final String? cashierName;
  final String status; // COMPLETED, VOIDED, REFUNDED
  final String paymentMethod; // CASH, CARD, UPI, OTHER
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final String? note;
  final List<SaleItemModel> items;
  final DateTime? createdAt;

  const SaleModel({
    required this.id,
    required this.invoiceNumber,
    required this.businessId,
    required this.cashierId,
    this.cashierName,
    required this.status,
    required this.paymentMethod,
    required this.subtotal,
    this.taxAmount = 0.0,
    this.discountAmount = 0.0,
    required this.totalAmount,
    this.note,
    this.items = const [],
    this.createdAt,
  });

  bool get isCompleted => status == 'COMPLETED';
  bool get isVoided => status == 'VOIDED';

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((e) => SaleItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return SaleModel(
      id: json['id'] as String,
      invoiceNumber: (json['invoice_number'] ?? json['invoiceNumber'] ?? '') as String,
      businessId: (json['business_id'] ?? json['businessId'] ?? '') as String,
      cashierId: (json['cashier_id'] ?? json['cashierId'] ?? '') as String,
      cashierName: (json['cashier_name'] ?? json['cashierName']) as String?,
      status: (json['status'] ?? 'COMPLETED') as String,
      paymentMethod: (json['payment_method'] ?? json['paymentMethod'] ?? 'CASH') as String,
      subtotal: double.tryParse((json['subtotal'] ?? '0').toString()) ?? 0.0,
      taxAmount: double.tryParse((json['tax_amount'] ?? json['taxAmount'] ?? '0').toString()) ?? 0.0,
      discountAmount: double.tryParse((json['discount_amount'] ?? json['discountAmount'] ?? '0').toString()) ?? 0.0,
      totalAmount: double.tryParse((json['total_amount'] ?? json['totalAmount'] ?? '0').toString()) ?? 0.0,
      note: json['note'] as String?,
      items: itemsList,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}
