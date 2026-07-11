/// Mirrors `shared/constants/event_types.dart` (repo root) for the enums the
/// SOS feature needs.
///
/// Dart cannot import files outside a package's `lib/` directory via a
/// relative import (verified: `dart analyze` reports `uri_does_not_exist`
/// for any path that escapes `app/lib/`), and `shared/` is not currently
/// wired up as an importable Dart package (no `pubspec.yaml`, no `lib/`
/// layout). Until that's addressed — e.g. by giving `shared/` its own
/// `pubspec.yaml` + `lib/` layout and adding it as a path dependency of
/// `app/pubspec.yaml` — this file must be kept in sync by hand with
/// `shared/constants/event_types.dart`.
library;

enum IncidentType {
  crashDetected('crash_detected'),
  sos('sos'),
  inactivity('inactivity'),
  nonArrival('non_arrival'),
  lostContact('lost_contact');

  const IncidentType(this.value);
  final String value;
}

enum IncidentSeverity {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  const IncidentSeverity(this.value);
  final String value;
}

enum IncidentStatus {
  detected('detected'),
  countdown('countdown'),
  cancelled('cancelled'),
  dispatched('dispatched'),
  acknowledged('acknowledged'),
  escalated('escalated'),
  resolved('resolved');

  const IncidentStatus(this.value);
  final String value;
}

enum AlertChannel {
  push('push'),
  sms('sms'),
  call('call'),
  whatsapp('whatsapp');

  const AlertChannel(this.value);
  final String value;
}

enum AlertStatus {
  queued('queued'),
  sent('sent'),
  delivered('delivered'),
  read('read'),
  failed('failed');

  const AlertStatus(this.value);
  final String value;
}
