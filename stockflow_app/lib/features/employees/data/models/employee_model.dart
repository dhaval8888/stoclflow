/// Employee model — maps to backend GET /users response
class EmployeeModel {
  final String id;
  final String businessId;
  final String fullName;
  final String email;
  final String? phone;
  final String role; // OWNER, MANAGER, CASHIER
  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  const EmployeeModel({
    required this.id,
    required this.businessId,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.isActive = true,
    this.lastLoginAt,
    this.createdAt,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  bool get isOwner => role.toUpperCase() == 'OWNER';
  bool get isManager => role.toUpperCase() == 'MANAGER';
  bool get isCashier => role.toUpperCase() == 'CASHIER';

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: (json['id'] ?? '') as String,
      businessId: (json['business_id'] ?? json['businessId'] ?? '') as String,
      fullName: (json['full_name'] ?? json['fullName'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      phone: json['phone'] as String?,
      role: (json['role_name'] ?? json['role'] ?? 'CASHIER') as String,
      isActive: (json['is_active'] ?? json['isActive'] ?? true) as bool,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.tryParse(json['last_login_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
