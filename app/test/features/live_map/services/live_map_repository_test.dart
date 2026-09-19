import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/live_map/live_map.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8, 12, 0, 0);

  Map<String, dynamic> row(String uid) => {
    'user_id': uid,
    'point': 'POINT(76.2999 9.9816)',
    'recorded_at': now.toIso8601String(),
    'speed': 12.5,
    'heading': 90.0,
    'battery_level': 64,
    'accuracy': 8.0,
  };

  test('members outside the entitlement set are absent entirely', () {
    final members = LiveMapRepository.assemble(
      entitled: const [
        MapMember(userId: 'u1', displayName: 'Asha', circleId: 'c1'),
        MapMember(userId: 'u2', displayName: 'Bino', circleId: 'c1'),
      ],
      locationRows: [row('u1'), row('u2'), row('stalker')],
    );
    expect(members.map((m) => m.userId), ['u1', 'u2']);
    expect(members.any((m) => m.userId == 'stalker'), isFalse);
  });

  test('an entitled member with no location row is kept but has no position', () {
    final members = LiveMapRepository.assemble(
      entitled: const [
        MapMember(userId: 'u1', displayName: 'Asha', circleId: 'c1'),
      ],
      locationRows: const [],
    );
    expect(members.single.position, isNull);
    expect(
      MemberPresence.resolve(position: members.single.position, now: now).state,
      MemberDisplayState.locating,
    );
  });

  test('only the newest row per member is used', () {
    final older = row('u1');
    older['recorded_at'] = now
        .subtract(const Duration(minutes: 5))
        .toIso8601String();
    final members = LiveMapRepository.assemble(
      entitled: const [
        MapMember(userId: 'u1', displayName: 'Asha', circleId: 'c1'),
      ],
      locationRows: [older, row('u1')],
    );
    expect(members.single.position?.recordedAt, now);
  });

  test('entitlement requires location_sharing on the shared circle', () {
    final entitled = LiveMapRepository.entitledFromRows(
      viewerId: 'me',
      rows: [
        {
          'circle_id': 'c1',
          'user_id': 'u1',
          'circles': {
            'id': 'c1',
            'settings': {'location_sharing': true},
          },
          'users': {'name': 'Asha'},
        },
        {
          'circle_id': 'c2',
          'user_id': 'u9',
          'circles': {
            'id': 'c2',
            'settings': {'location_sharing': false},
          },
          'users': {'name': 'Nope'},
        },
        {
          'circle_id': 'c3',
          'user_id': 'u8',
          'circles': {'id': 'c3', 'settings': <String, dynamic>{}},
          'users': {'name': 'AlsoNope'},
        },
      ],
    );
    expect(entitled.map((m) => m.userId), ['u1']);
  });

  test('the viewer is never listed as one of their own watched members', () {
    final entitled = LiveMapRepository.entitledFromRows(
      viewerId: 'me',
      rows: [
        {
          'circle_id': 'c1',
          'user_id': 'me',
          'circles': {
            'id': 'c1',
            'settings': {'location_sharing': true},
          },
          'users': {'name': 'Me'},
        },
      ],
    );
    expect(entitled, isEmpty);
  });

  test('parses a WKT point into lat/lng in the right order', () {
    final members = LiveMapRepository.assemble(
      entitled: const [
        MapMember(userId: 'u1', displayName: 'Asha', circleId: 'c1'),
      ],
      locationRows: [row('u1')],
    );
    final p = members.single.position;
    expect(p?.latitude, closeTo(9.9816, 1e-6));
    expect(p?.longitude, closeTo(76.2999, 1e-6));
    expect(p?.batteryLevel, 64);
  });
}
