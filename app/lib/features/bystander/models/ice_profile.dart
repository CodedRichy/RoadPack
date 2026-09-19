import 'bystander_session.dart';

/// One in-case-of-emergency contact.
class IceContact {
  const IceContact({
    required this.name,
    required this.phone,
    this.relation,
  });

  final String name;
  final String phone;
  final String? relation;
}

/// Medical facts a paramedic needs and a stranger must not keep.
///
/// Never persisted by this feature and never rendered outside an active
/// incident -- see [IceQrPayload.forSession] (FR-023 / FR-094 / SG-08).
class IceProfile {
  const IceProfile({
    this.bloodGroup,
    this.allergies = const [],
    this.conditions = const [],
    this.medications = const [],
    this.contacts = const [],
  });

  final String? bloodGroup;
  final List<String> allergies;
  final List<String> conditions;
  final List<String> medications;
  final List<IceContact> contacts;

  bool get isEmpty =>
      (bloodGroup == null || bloodGroup!.isEmpty) &&
      allergies.isEmpty &&
      conditions.isEmpty &&
      medications.isEmpty &&
      contacts.isEmpty;
}

/// The incident-gated ICE payload (FR-094).
///
/// The gate is the type itself: there is no public constructor, so the only
/// way to obtain a payload is [forSession], and that returns null unless the
/// incident is active. A widget that cannot construct one cannot leak one.
class IceQrPayload {
  const IceQrPayload._(this.incidentId, this.data, this.profile);

  /// Incident this payload is scoped to. It stops being valid when the
  /// incident resolves; nothing here is cached across incidents.
  final String incidentId;

  /// Encoded payload for the QR symbol.
  final String data;

  /// The same facts, for the human-readable card next to the symbol.
  final IceProfile profile;

  static IceQrPayload? forSession(BystanderSession session) {
    if (!session.incidentActive) return null;
    final ice = session.ice;
    if (ice == null || ice.isEmpty) return null;
    return IceQrPayload._(session.incidentId, _encode(session, ice), ice);
  }

  static String _encode(BystanderSession session, IceProfile ice) {
    final parts = <String>[
      'incident=${session.incidentId}',
      'name=${session.victimDisplayName}',
      if (ice.bloodGroup != null && ice.bloodGroup!.isNotEmpty)
        'blood=${ice.bloodGroup}',
      if (ice.allergies.isNotEmpty) 'allergies=${ice.allergies.join('|')}',
      if (ice.conditions.isNotEmpty) 'conditions=${ice.conditions.join('|')}',
      if (ice.medications.isNotEmpty) 'meds=${ice.medications.join('|')}',
      for (final c in ice.contacts) 'contact=${c.name}:${c.phone}',
    ];
    return 'roadpack:ice?${parts.join('&')}';
  }
}
