import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../l10n/l10n.dart';

part 'circle.freezed.dart';

enum CircleType {
  family,
  friends,
  commute,
  convoy;

  String get value => name;

  static CircleType fromString(String s) =>
      CircleType.values.firstWhere((e) => e.name == s);

  // Copy is resolved at render time rather than stored on the enum: the type
  // is a fact about the circle, and that fact does not change when the
  // phone changes language. See ProtectionGap in home_screen.dart for the
  // same pattern.
  String displayName(AppLocalizations l10n) => switch (this) {
    CircleType.family => l10n.circlesTypeFamily,
    CircleType.friends => l10n.circlesTypeFriends,
    CircleType.commute => l10n.circlesTypeCommute,
    CircleType.convoy => l10n.circlesTypeConvoy,
  };

  String defaultName(AppLocalizations l10n) => switch (this) {
    CircleType.family => l10n.circlesTypeFamilyDefaultName,
    CircleType.friends => l10n.circlesTypeFriendsDefaultName,
    CircleType.commute => l10n.circlesTypeCommuteDefaultName,
    CircleType.convoy => l10n.circlesTypeConvoyDefaultName,
  };

  String description(AppLocalizations l10n) => switch (this) {
    CircleType.family => l10n.circlesTypeFamilyDescription,
    CircleType.friends => l10n.circlesTypeFriendsDescription,
    CircleType.commute => l10n.circlesTypeCommuteDescription,
    CircleType.convoy => l10n.circlesTypeConvoyDescription,
  };
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
