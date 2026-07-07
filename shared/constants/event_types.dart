/// Shared event types used by both app and backend.
/// Backend Edge Functions reference the string values directly.

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

enum CircleType {
  family('family'),
  friends('friends'),
  commute('commute'),
  convoy('convoy');

  const CircleType(this.value);
  final String value;
}

enum CircleRole {
  admin('admin'),
  member('member'),
  observer('observer');

  const CircleRole(this.value);
  final String value;
}

enum CrashSensitivity {
  low('low'),
  medium('medium'),
  high('high');

  const CrashSensitivity(this.value);
  final String value;
}

enum ActivityState {
  stationary('stationary'),
  walking('walking'),
  riding('riding');

  const ActivityState(this.value);
  final String value;
}
