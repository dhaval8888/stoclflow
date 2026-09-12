/// StockFlow User Model
class User {
  final String id;
  final String businessId;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final String? phone;
  final String? businessName;

  const User({
    required this.id,
    required this.businessId,
    required this.fullName,
    required this.email,
    required this.role,
    this.isActive = true,
    this.phone,
    this.businessName,
  });

  bool get isOwner => role.toUpperCase() == 'OWNER';
  bool get isManager => role.toUpperCase() == 'MANAGER';
  bool get isCashier => role.toUpperCase() == 'CASHIER';

  bool get canManageInventory => isOwner || isManager;
  bool get canManageUsers => isOwner;
  bool get canViewAnalytics => isOwner || isManager;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      businessId: (json['business_id'] ?? json['businessId'] ?? '') as String,
      fullName: (json['full_name'] ?? json['fullName'] ?? '') as String,
      email: json['email'] as String,
      role: (json['role'] ?? json['role_name'] ?? 'CASHIER') as String,
      isActive: (json['is_active'] ?? json['isActive'] ?? true) as bool,
      phone: json['phone'] as String?,
      businessName: (json['business_name'] ?? json['businessName']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'full_name': fullName,
      'email': email,
      'role': role,
      'is_active': isActive,
      'phone': phone,
      'business_name': businessName,
    };
  }

  User copyWith({
    String? id,
    String? businessId,
    String? fullName,
    String? email,
    String? role,
    bool? isActive,
    String? phone,
    String? businessName,
  }) {
    return User(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      phone: phone ?? this.phone,
      businessName: businessName ?? this.businessName,
    );
  }
}

/// Token Pair Model
class AuthTokens {
  final String accessToken;
  final String refreshToken;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}

/// Auth Response Model
class AuthResponse {
  final AuthTokens tokens;
  final User user;

  const AuthResponse({
    required this.tokens,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      tokens: AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
