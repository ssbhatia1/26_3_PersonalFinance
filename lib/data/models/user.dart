class User {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String passwordHash;
  final String salt;
  final String? resetToken;
  final DateTime? resetTokenExpiry;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.passwordHash,
    required this.salt,
    this.resetToken,
    this.resetTokenExpiry,
    required this.createdAt,
    required this.updatedAt,
  });

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? fullName,
    String? passwordHash,
    String? salt,
    String? resetToken,
    DateTime? resetTokenExpiry,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      resetToken: resetToken ?? this.resetToken,
      resetTokenExpiry: resetTokenExpiry ?? this.resetTokenExpiry,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email.toLowerCase().trim(),
      'username': username.toLowerCase().trim(),
      'full_name': fullName.trim(),
      'password_hash': passwordHash,
      'salt': salt,
      'reset_token': resetToken,
      'reset_token_expiry': resetTokenExpiry?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      email: map['email'] as String,
      username: map['username'] as String,
      fullName: (map['full_name'] as String?) ?? '',
      passwordHash: map['password_hash'] as String,
      salt: map['salt'] as String,
      resetToken: map['reset_token'] as String?,
      resetTokenExpiry: map['reset_token_expiry'] != null
          ? DateTime.tryParse(map['reset_token_expiry'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
