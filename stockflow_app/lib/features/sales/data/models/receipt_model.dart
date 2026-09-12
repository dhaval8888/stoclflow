import 'sale_model.dart';

class BusinessReceiptInfo {
  final String name;
  final String? phone;
  final String? address;
  final String? currency;

  const BusinessReceiptInfo({
    required this.name,
    this.phone,
    this.address,
    this.currency = 'USD',
  });

  factory BusinessReceiptInfo.fromJson(Map<String, dynamic> json) {
    return BusinessReceiptInfo(
      name: (json['name'] ?? 'StockFlow Merchant') as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      currency: (json['currency'] ?? 'USD') as String,
    );
  }
}

class ReceiptModel {
  final BusinessReceiptInfo business;
  final SaleModel sale;
  final List<SaleItemModel> items;

  const ReceiptModel({
    required this.business,
    required this.sale,
    required this.items,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    final b = BusinessReceiptInfo.fromJson(json['business'] as Map<String, dynamic>? ?? {});
    final s = SaleModel.fromJson(json['sale'] as Map<String, dynamic>? ?? {});
    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((e) => SaleItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ReceiptModel(
      business: b,
      sale: s,
      items: itemsList,
    );
  }
}
