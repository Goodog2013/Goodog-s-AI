import 'plan_limits.dart';
import 'user_plan.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.plan,
    required this.isBanned,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String displayName;
  final UserPlan plan;
  final bool isBanned;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlanLimits get limits => PlanLimits.forPlan(plan);

  factory UserProfile.initial({required String id, required String name}) {
    final now = DateTime.now();
    return UserProfile(
      id: id,
      displayName: name,
      plan: UserPlan.free,
      isBanned: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return UserProfile(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? (json['id'] as String).trim()
          : 'local_user',
      displayName: (json['displayName'] as String?)?.trim().isNotEmpty == true
          ? (json['displayName'] as String).trim()
          : 'User',
      plan: UserPlanX.parse(json['plan'] as String?),
      isBanned: json['isBanned'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }

  UserProfile copyWith({
    String? id,
    String? displayName,
    UserPlan? plan,
    bool? isBanned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      plan: plan ?? this.plan,
      isBanned: isBanned ?? this.isBanned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'plan': plan.code,
      'isBanned': isBanned,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
