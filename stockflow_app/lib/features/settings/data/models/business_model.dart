class BusinessModel {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String currency;
  final String? timezone;
  final String? logoUrl;
  final DateTime? updatedAt;

  const BusinessModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.currency = 'USD',
    this.timezone,
    this.logoUrl,
    this.updatedAt,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      currency: (json['currency'] ?? 'USD') as String,
      timezone: json['timezone'] as String?,
      logoUrl: json['logo_url'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'phone': phone,
        'email': email,
        'currency': currency,
        'timezone': timezone,
      };
}
