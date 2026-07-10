import 'package:freezed_annotation/freezed_annotation.dart';

part 'circle.freezed.dart';

enum CircleType {
  family,
  friends,
  commute,
  convoy;

  String get value => name;

  static CircleType fromString(String s) =>
      CircleType.values.firstWhere((e) => e.name == s);

  String get displayName {
    switch (this) {
      case CircleType.family:
        return 'Family';
      case CircleType.friends:
        return 'Friends';
      case CircleType.commute:
        return 'Commute Group';
      case CircleType.convoy:
        return 'Convoy';
    }
  }

  String get defaultName {
    switch (this) {
      case CircleType.family:
        return 'My Family';
      case CircleType.friends:
        return 'Friends';
      case CircleType.commute:
        return 'Commute Group';
      case CircleType.convoy:
        return 'Convoy';
    }
  }

  String get description {
    switch (this) {
      case CircleType.family:
        return 'Your closest people. Members are automatically added as emergency contacts.';
      case CircleType.friends:
        return 'Friends who ride or commute. Add specific members as emergency contacts.';
      case CircleType.commute:
        return 'Regular commute group.';
      case CircleType.convoy:
        return 'Temporary group ride. Set a duration.';
    }
  }
}

@freezed
class Circle with _$Circle {
  const Circle._();

  const factory Circle({
    required String id,
    required String name,
    required CircleType type,
    required String createdBy,
    String? inviteCode,
    int? maxMembers,
    @Default(<String, dynamic>{}) Map<String, dynamic> settings,
    required DateTime createdAt,
    DateTime? expiresAt,
  }) = _Circle;

  factory Circle.fromJson(Map<String, dynamic> json) {
    return Circle(
      id: json['id'] as String,
      name: json['name'] as String,
      type: CircleType.fromString(json['type'] as String),
      createdBy: json['created_by'] as String,
      inviteCode: json['invite_code'] as String?,
      maxMembers: json['max_members'] as int?,
      settings: (json['settings'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isFamily => type == CircleType.family;
}
