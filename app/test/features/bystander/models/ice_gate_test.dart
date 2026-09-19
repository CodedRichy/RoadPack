import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/bystander/models/bystander_session.dart';
import 'package:roadpack/features/bystander/models/ice_profile.dart';

const _ice = IceProfile(
  bloodGroup: 'O+',
  allergies: ['Penicillin'],
  conditions: ['Type 1 diabetes'],
  contacts: [IceContact(name: 'Asha', phone: '+919847012345', relation: 'Wife')],
);

BystanderSession _session({required bool active}) => BystanderSession(
  incidentId: 'i1',
  incidentActive: active,
  victimDisplayName: 'Rahul',
  lat: 9.9816,
  lng: 76.2999,
  locationAt: DateTime.utc(2026, 9, 8, 10),
  ice: _ice,
);

void main() {
  test('ICE payload is exposed during an active incident', () {
    final payload = IceQrPayload.forSession(_session(active: true));
    expect(payload, isNotNull);
    expect(payload!.data, contains('O+'));
    expect(payload.data, contains('Penicillin'));
  });

  test('ICE payload is withheld when the incident is not active', () {
    expect(IceQrPayload.forSession(_session(active: false)), isNull);
  });

  test('ICE payload is withheld when there is no profile', () {
    const s = BystanderSession(
      incidentId: 'i1',
      incidentActive: true,
      victimDisplayName: 'Rahul',
    );
    expect(IceQrPayload.forSession(s), isNull);
  });

  test('coordinates are formatted for reading aloud', () {
    final s = _session(active: true);
    expect(s.readableCoordinates, '9.98160 N, 76.29990 E');
    expect(s.spokenCoordinates, contains('North'));
    expect(s.spokenCoordinates, contains('East'));
  });

  test('a session with no fix reports no coordinates', () {
    const s = BystanderSession(
      incidentId: 'i1',
      incidentActive: true,
      victimDisplayName: 'Rahul',
    );
    expect(s.hasLocation, isFalse);
    expect(s.readableCoordinates, isNull);
  });
}
