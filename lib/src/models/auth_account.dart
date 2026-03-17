class AuthAccount {
  const AuthAccount({
    required this.id,
    required this.login,
    required this.email,
    required this.displayName,
    required this.passwordHash,
    required this.passwordSalt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String login;
  final String email;
  final String displayName;
  final String passwordHash;
  final String passwordSalt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AuthAccount.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return AuthAccount(
      id: (json['id'] as String? ?? '').trim(),
      login: (json['login'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? '').trim(),
      displayName: (json['displayName'] as String? ?? '').trim(),
      passwordHash: (json['passwordHash'] as String? ?? '').trim(),
      passwordSalt: (json['passwordSalt'] as String? ?? '').trim(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }

  AuthAccount copyWith({
    String? id,
    String? login,
    String? email,
    String? displayName,
    String? passwordHash,
    String? passwordSalt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AuthAccount(
      id: id ?? this.id,
      login: login ?? this.login,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'login': login,
      'email': email,
      'displayName': displayName,
      'passwordHash': passwordHash,
      'passwordSalt': passwordSalt,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toPublicJson() {
    return {
      'id': id,
      'login': login,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
