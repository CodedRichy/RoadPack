import '../../emergency_profile/models/emergency_contact.dart';
import '../models/bystander_session.dart';
import '../models/ice_profile.dart';

/// A position fix that was taken on this device.
///
/// It carries [at] because the bystander screen is required to state the age
/// of the fix. A position without its timestamp cannot be shown honestly, so
/// the timestamp is not optional here.
class LocalFix {
  const LocalFix({
    required this.lat,
    required this.lng,
    required this.at,
    this.accuracyMeters,
  });

  final double lat;
  final double lng;

  /// When the fix was actually taken. Never `DateTime.now()` at read time.
  final DateTime at;

  final double? accuracyMeters;
}

/// The little the assembler needs to know about an incident.
///
/// Deliberately not `Incident`: the incident may have originated in the SOS
/// state machine, in crash detection, or (later) in a queued offline
/// dispatch, and none of those should have to agree on a wire model for a
/// stranger to be able to read a phone.
class LocalIncidentSnapshot {
  const LocalIncidentSnapshot({required this.id, required this.active});

  final String id;

  /// False the moment the incident is cancelled or resolved. This is what
  /// seals the ICE card, so it must go false promptly rather than eventually.
  final bool active;
}

/// What the screen says when we do not know the rider's name.
///
/// Not "Unknown": the bystander is looking at a person, and a screen that
/// says "Unknown" reads as a broken app rather than a missing field.
const kUnnamedRider = 'This rider';

/// Builds the [BystanderSession] from state this device already holds.
///
/// Every input is local. Nothing here fetches, awaits a server, or needs a
/// session token — the phone at a crash site frequently has neither network
/// nor a valid token, and the screen still has to come up.
class BystanderSessionAssembler {
  const BystanderSessionAssembler._();

  static BystanderSession assemble({
    required LocalIncidentSnapshot incident,
    String? victimName,
    LocalFix? fix,
    List<EmergencyContact> contacts = const [],
    String? bloodGroup,
    String? medicalNotes,
  }) {
    final contact = firstCallable(contacts);
    final ice = incident.active
        ? _ice(
            contacts: contacts,
            bloodGroup: bloodGroup,
            medicalNotes: medicalNotes,
          )
        : null;

    final name = victimName?.trim();

    return BystanderSession(
      incidentId: incident.id,
      incidentActive: incident.active,
      victimDisplayName: (name == null || name.isEmpty) ? kUnnamedRider : name,
      lat: fix?.lat,
      lng: fix?.lng,
      accuracyMeters: fix?.accuracyMeters,
      locationAt: fix?.at,
      contactName: contact?.name,
      contactPhone: contact?.phone,
      ice: ice,
    );
  }

  /// Contact #1: the first person the cascade would try, skipping anyone who
  /// opted out or has no number. `priority` is an ordering, not a severity.
  static EmergencyContact? firstCallable(List<EmergencyContact> contacts) {
    final callable =
        contacts
            .where((c) => !c.optedOut && c.phone.trim().isNotEmpty)
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));
    return callable.isEmpty ? null : callable.first;
  }

  /// Medical notes are free text on the `users` row. They are shown as
  /// conditions rather than parsed into allergies/medications: guessing which
  /// line is an allergy and being wrong is worse than showing the note.
  static IceProfile? _ice({
    required List<EmergencyContact> contacts,
    String? bloodGroup,
    String? medicalNotes,
  }) {
    final conditions = (medicalNotes ?? '')
        .split(RegExp(r'[\n;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final ordered =
        contacts
            .where((c) => !c.optedOut && c.phone.trim().isNotEmpty)
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));

    final iceContacts = [
      for (final c in ordered)
        IceContact(name: c.name, phone: c.phone, relation: c.relationship),
    ];

    final profile = IceProfile(
      bloodGroup: (bloodGroup ?? '').trim().isEmpty ? null : bloodGroup!.trim(),
      conditions: conditions,
      contacts: iceContacts,
    );
    return profile.isEmpty ? null : profile;
  }
}
