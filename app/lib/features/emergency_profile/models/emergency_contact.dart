import 'package:flutter/foundation.dart';

/// How a contact is reached when the cascade runs.
///
/// Maps to the `alert_method VARCHAR(20)[]` column on `emergency_contacts`
/// (migration 00004). Unknown wire values are dropped rather than thrown on:
/// a row written by a newer client must never break an older one's ability to
/// read its own emergency contacts.
enum AlertMethod {
  push,
  sms,
  call;

  String get wire => name;

  String get displayName {
    switch (this) {
      case AlertMethod.push:
        return 'Push';
      case AlertMethod.sms:
        return 'SMS';
      case AlertMethod.call:
        return 'Call';
    }
  }

  static AlertMethod? fromWire(String value) {
    for (final m in AlertMethod.values) {
      if (m.wire == value) return m;
    }
    return null;
  }

  /// What a contact gets if the column is null or unreadable. Deliberately
  /// excludes `call`: an unattended auto-dial to someone who never agreed to
  /// it is the one default we do not want to make on the user's behalf.
  static const Set<AlertMethod> defaults = {AlertMethod.push, AlertMethod.sms};
}

/// One row of `emergency_contacts`.
///
/// [priority] is an *ordering*, not a severity — priority 1 is simply the
/// first person the cascade tries. It is never rendered in a hazard tier
/// colour.
@immutable
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.priority,
    this.relationship,
    this.alertMethods = AlertMethod.defaults,
    this.notifiedAt,
    this.optedOut = false,
    this.isAppUser = false,
    this.appUserId,
    this.circleId,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    final raw = json['alert_method'];
    Set<AlertMethod> methods;
    if (raw is List) {
      methods = raw
          .map((e) => AlertMethod.fromWire('$e'))
          .whereType<AlertMethod>()
          .toSet();
      if (methods.isEmpty) methods = AlertMethod.defaults;
    } else {
      methods = AlertMethod.defaults;
    }

    return EmergencyContact(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      relationship: json['relationship'] as String?,
      priority: json['priority'] as int? ?? 1,
      alertMethods: methods,
      notifiedAt: json['notified_at'] != null
          ? DateTime.parse(json['notified_at'] as String)
          : null,
      optedOut: json['opted_out'] as bool? ?? false,
      isAppUser: json['is_app_user'] as bool? ?? false,
      appUserId: json['app_user_id'] as String?,
      circleId: json['circle_id'] as String?,
    );
  }

  final String id;
  final String userId;
  final String name;
  final String phone;
  final String? relationship;
  final int priority;
  final Set<AlertMethod> alertMethods;

  /// When the FR-024 "you were listed" notice was sent. Server-owned and
  /// write-once — see `EmergencyContactGateway.claimNotice`.
  final DateTime? notifiedAt;
  final bool optedOut;
  final bool isAppUser;
  final String? appUserId;

  /// Set when this row was created by the circles feature to mirror a circle
  /// member or observer, so leaving that circle can clean the row up again.
  final String? circleId;

  bool get isNotified => notifiedAt != null;

  /// True when this contact should still receive the one-time listed notice.
  bool get needsListedNotice => !isNotified && !optedOut && phone.isNotEmpty;

  /// Ordered for display and for the alert cascade.
  List<AlertMethod> get orderedAlertMethods =>
      AlertMethod.values.where(alertMethods.contains).toList();

  /// Insert/update payload. `id`, `notified_at` and `created_at` are
  /// server-owned and never written from here.
  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    'phone': phone,
    'relationship': relationship,
    'priority': priority,
    'alert_method': orderedAlertMethods.map((m) => m.wire).toList(),
    'opted_out': optedOut,
    'is_app_user': isAppUser,
    'app_user_id': appUserId,
    'circle_id': circleId,
  };

  EmergencyContact copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    Object? relationship = _unset,
    int? priority,
    Set<AlertMethod>? alertMethods,
    Object? notifiedAt = _unset,
    bool? optedOut,
    bool? isAppUser,
    Object? appUserId = _unset,
    Object? circleId = _unset,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: identical(relationship, _unset)
          ? this.relationship
          : relationship as String?,
      priority: priority ?? this.priority,
      alertMethods: alertMethods ?? this.alertMethods,
      notifiedAt: identical(notifiedAt, _unset)
          ? this.notifiedAt
          : notifiedAt as DateTime?,
      optedOut: optedOut ?? this.optedOut,
      isAppUser: isAppUser ?? this.isAppUser,
      appUserId: identical(appUserId, _unset)
          ? this.appUserId
          : appUserId as String?,
      circleId: identical(circleId, _unset)
          ? this.circleId
          : circleId as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmergencyContact &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          name == other.name &&
          phone == other.phone &&
          relationship == other.relationship &&
          priority == other.priority &&
          setEquals(alertMethods, other.alertMethods) &&
          notifiedAt == other.notifiedAt &&
          optedOut == other.optedOut &&
          isAppUser == other.isAppUser &&
          appUserId == other.appUserId &&
          circleId == other.circleId;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    phone,
    relationship,
    priority,
    Object.hashAllUnordered(alertMethods),
    notifiedAt,
    optedOut,
    isAppUser,
    appUserId,
    circleId,
  );

  @override
  String toString() =>
      'EmergencyContact(id: $id, name: $name, phone: $phone, '
      'priority: $priority, notifiedAt: $notifiedAt, optedOut: $optedOut)';
}

/// Sentinel distinguishing "argument omitted" from "explicitly null" in
/// [EmergencyContact.copyWith], matching the convention in `UserProfile`.
class _Unset {
  const _Unset();
}

const _unset = _Unset();
