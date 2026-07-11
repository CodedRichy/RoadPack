import 'package:freezed_annotation/freezed_annotation.dart';

part 'circle_member.freezed.dart';

enum CircleRole {
  admin,
  member,
  observer;

  String get value => name;

  static CircleRole fromString(String s) =>
      CircleRole.values.firstWhere((e) => e.name == s);

  String get displayName {
    switch (this) {
      case CircleRole.admin:
        return 'Admin';
      case CircleRole.member:
        return 'Member';
      case CircleRole.observer:
        return 'Observer';
    }
  }
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

@freezed
class EmergencyContact with _$EmergencyContact {
  const factory EmergencyContact({
    required String id,
    required String userId,
    required String name,
    required String phone,
    String? relationship,
    required int priority,
    @Default(<String>['push', 'sms']) List<String> alertMethod,
    @Default(false) bool optedOut,
    @Default(false) bool isAppUser,
    String? appUserId,
    String? circleId,
  }) = _EmergencyContact;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    final rawAlert = json['alert_method'];
    List<String> alertMethod;
    if (rawAlert is List) {
      alertMethod = rawAlert.cast<String>();
    } else {
      alertMethod = const ['push', 'sms'];
    }

    return EmergencyContact(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      relationship: json['relationship'] as String?,
      priority: json['priority'] as int,
      alertMethod: alertMethod,
      optedOut: json['opted_out'] as bool? ?? false,
      isAppUser: json['is_app_user'] as bool? ?? false,
      appUserId: json['app_user_id'] as String?,
      circleId: json['circle_id'] as String?,
    );
  }
}
