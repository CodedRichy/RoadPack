import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../l10n/l10n.dart';

// `emergency_contacts` has exactly one model, and it lives in the feature
// that owns the table. Circles reads the same rows (observers, mirrored
// family members) rather than keeping a second, thinner copy of the type.
export '../../emergency_profile/models/emergency_contact.dart'
    show AlertMethod, EmergencyContact;

part 'circle_member.freezed.dart';

enum CircleRole {
  admin,
  member,
  observer;

  String get value => name;

  static CircleRole fromString(String s) =>
      CircleRole.values.firstWhere((e) => e.name == s);

  // Copy is resolved at render time, not stored on the enum — see
  // CircleType.displayName in circle.dart for the same pattern.
  String displayName(AppLocalizations l10n) => switch (this) {
    CircleRole.admin => l10n.circlesRoleAdmin,
    CircleRole.member => l10n.circlesRoleMember,
    CircleRole.observer => l10n.circlesRoleObserver,
  };
}

@freezed
class CircleMember with _$CircleMember {
  const CircleMember._();

  const factory CircleMember({
    required String circleId,
    required String userId,
    required CircleRole role,
    @Default(<String, dynamic>{}) Map<String, dynamic> permissions,
    DateTime? acceptedAt,
    required DateTime joinedAt,
    String? userName,
  }) = _CircleMember;

  factory CircleMember.fromJson(Map<String, dynamic> json) {
    final userMap = json['users'] as Map<String, dynamic>?;
    return CircleMember(
      circleId: json['circle_id'] as String,
      userId: json['user_id'] as String,
      role: CircleRole.fromString(json['role'] as String),
      permissions: (json['permissions'] as Map<String, dynamic>?) ?? const {},
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      userName: userMap?['name'] as String?,
    );
  }

  bool get isAdmin => role == CircleRole.admin;
}
