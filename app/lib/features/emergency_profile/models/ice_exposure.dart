import 'package:flutter/foundation.dart';

import 'emergency_contact.dart';

/// Why the ICE card is currently exposed. There are exactly two lawful
/// reasons (FR-023 / FR-094); there is no "always on" third state.
enum IceExposureReason {
  activeIncident,
  activeCommute;

  String get displayName {
    switch (this) {
      case IceExposureReason.activeIncident:
        return 'Emergency in progress';
      case IceExposureReason.activeCommute:
        return 'Visible while you are riding';
    }
  }
}

/// A capability token proving the ICE card is allowed to be shown right now.
///
/// This exists to make SG-08 structural rather than advisory. The constructor
/// is library-private and [resolve] is the only mint, so no widget, screen or
/// future feature can render [IceCardBody]-class content by simply deciding
/// to: it must first hold a token, and a token cannot exist unless an
/// incident or an opted-in commute is genuinely active. A `bool showIce`
/// parameter would have been one careless `true` away from a permanent PII
/// leak; this cannot be.
@immutable
class IceAccess {
  const IceAccess._(this.reason, this.grantedAt);

  /// The only way to obtain an [IceAccess]. Returns null — meaning "no
  /// exposure" — in every state that is not an active incident or an
  /// opted-in active commute.
  static IceAccess? resolve({
    required bool incidentActive,
    required bool commuteActive,
    bool commuteExposureOptIn = false,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    if (incidentActive) {
      return IceAccess._(IceExposureReason.activeIncident, at);
    }
    if (commuteActive && commuteExposureOptIn) {
      return IceAccess._(IceExposureReason.activeCommute, at);
    }
    return null;
  }

  final IceExposureReason reason;
  final DateTime grantedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IceAccess &&
          reason == other.reason &&
          grantedAt == other.grantedAt;

  @override
  int get hashCode => Object.hash(reason, grantedAt);

  @override
  String toString() => 'IceAccess(${reason.name}, granted: $grantedAt)';
}

/// The payload a bystander reads off the ICE card.
///
/// Medical fields are read from the existing `users` row via `UserProfile`
/// (blood group, medical notes) — they are not duplicated in this feature.
@immutable
class IceCardData {
  const IceCardData({
    required this.ownerName,
    this.bloodGroup,
    this.medicalNotes,
    this.contacts = const [],
  });

  final String? ownerName;
  final String? bloodGroup;
  final String? medicalNotes;
  final List<EmergencyContact> contacts;

  bool get hasMedicalInfo =>
      (bloodGroup != null && bloodGroup!.isNotEmpty) ||
      (medicalNotes != null && medicalNotes!.isNotEmpty);

  /// Contacts a bystander should try, in cascade order, skipping anyone who
  /// opted out of being contacted.
  List<EmergencyContact> get callableContacts =>
      (contacts.where((c) => !c.optedOut && c.phone.isNotEmpty).toList()
        ..sort((a, b) => a.priority.compareTo(b.priority)));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IceCardData &&
          ownerName == other.ownerName &&
          bloodGroup == other.bloodGroup &&
          medicalNotes == other.medicalNotes &&
          listEquals(contacts, other.contacts);

  @override
  int get hashCode =>
      Object.hash(ownerName, bloodGroup, medicalNotes, Object.hashAll(contacts));
}
