// lib/models/user_model.dart

class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String orgId;
  final bool isActive;
  final String? phone;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.orgId,
    required this.isActive,
    this.phone,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      role: json['role'] ?? 'employee',
      orgId: json['org_id'] ?? json['organization_id'] ?? '',
      isActive: json['is_active'] ?? true,
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'org_id': orgId,
      'is_active': isActive,
    };
  }
}

class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final User user;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
      user: User.fromJson(json['user'] ?? {}),
    );
  }
}
