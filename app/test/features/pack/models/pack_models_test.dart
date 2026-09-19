import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/pack/models/pack_gap.dart';
import 'package:roadpack/features/pack/models/pack_member.dart';
import 'package:roadpack/features/pack/models/pack_ride.dart';
import 'package:roadpack/features/pack/models/pack_status.dart';

void main() {
  group('PackStatus mirrors the database CHECK constraint', () {
    test('every status_code value is represented exactly once', () {
      const fromMigration = {
        'riding',
        'refueling',
        'break',
        'wrong_turn',
        'waiting',
        'stopped',
        'done',
        'unexplained_stop',
        'possible_incident',
        'unreachable',
      };
      expect(PackStatus.values.map((s) => s.wire).toSet(), fromMigration);
    });

    test('the automatic-only values are not user-settable', () {
      expect(PackStatus.possibleIncident.userSettable, isFalse);
      expect(PackStatus.unreachable.userSettable, isFalse);
      expect(PackStatus.unexplainedStop.userSettable, isFalse);
      expect(
        PackStatus.settable.map((s) => s.wire),
        isNot(contains('possible_incident')),
      );
      expect(PackStatus.settable, hasLength(7));
    });

    test('precedence is possible_incident > unreachable > unexplained_stop > '
        'manual > riding', () {
      expect(
        PackStatus.possibleIncident.precedence,
        greaterThan(PackStatus.unreachable.precedence),
      );
      expect(
        PackStatus.unreachable.precedence,
        greaterThan(PackStatus.unexplainedStop.precedence),
      );
      expect(
        PackStatus.unexplainedStop.precedence,
        greaterThan(PackStatus.stopped.precedence),
      );
      expect(
        PackStatus.stopped.precedence,
        greaterThan(PackStatus.riding.precedence),
      );
    });

    test('an unknown wire value degrades to riding rather than throwing', () {
      expect(PackStatus.fromWire('teleported'), PackStatus.riding);
    });
  });

  group('PackDisplayState', () {
    test('off_route, stale and locating suppress the number; ok and estimated '
        'do not', () {
      expect(PackDisplayState.offRoute.suppressesGap, isTrue);
      expect(PackDisplayState.stale.suppressesGap, isTrue);
      expect(PackDisplayState.locating.suppressesGap, isTrue);
      expect(PackDisplayState.ok.suppressesGap, isFalse);
      expect(PackDisplayState.estimated.suppressesGap, isFalse);
    });

    test('an unrecognised state suppresses rather than guesses', () {
      expect(PackDisplayState.fromWire('???'), PackDisplayState.locating);
      expect(PackDisplayState.fromWire('???').suppressesGap, isTrue);
    });
  });

  group('PackGap', () {
    PackGap parse(Map<String, dynamic> overrides) => PackGap.fromJson({
      'user_id': 'u1',
      'role': 'rider',
      'chainage_m': 4200.0,
      'gap_m': -1400.0,
      'gap_s': -180.0,
      'gap_estimated': false,
      'display_state': 'ok',
      'status_code': 'riding',
      'status_auto': false,
      'off_route': false,
      'straight_m': null,
      'stale': false,
      ...overrides,
    });

    test('reads the RPC row shape', () {
      final gap = parse({});
      expect(gap.userId, 'u1');
      expect(gap.role, PackRole.rider);
      expect(gap.gapM, -1400.0);
      expect(gap.displayState, PackDisplayState.ok);
      expect(gap.canShowGap, isTrue);
      expect(gap.metresBehind, 1400.0);
    });

    test(
      'canShowGap is false in every suppressed state, even with a gap_m',
      () {
        for (final state in ['off_route', 'stale', 'locating']) {
          expect(
            parse({'display_state': state}).canShowGap,
            isFalse,
            reason: '$state must gate the number',
          );
        }
      },
    );

    test('canShowGap is false when the server returned no gap at all', () {
      expect(parse({'gap_m': null}).canShowGap, isFalse);
    });

    test('the front rider is detected, not computed from a sort', () {
      expect(parse({'gap_m': 0.0}).isFront, isTrue);
      expect(parse({'gap_m': -500.0}).isFront, isFalse);
    });

    test('round-trips through JSON', () {
      final gap = parse({'display_state': 'estimated', 'gap_estimated': true});
      expect(PackGap.fromJson(gap.toJson()), gap);
    });
  });

  group('PackRide', () {
    PackRide parse(Map<String, dynamic> overrides) => PackRide.fromJson({
      'id': 'r1',
      'circle_id': null,
      'leader_id': 'u1',
      'name': 'Munnar run',
      'status': 'active',
      'share_token': 'tok-123',
      'share_expires_at': '2026-09-08T22:00:00Z',
      'share_revoked_at': null,
      'route_length_m': 128000.0,
      'started_at': '2026-09-08T10:00:00Z',
      'ended_at': null,
      'expires_at': '2026-09-08T22:00:00Z',
      ...overrides,
    });

    final now = DateTime.utc(2026, 9, 8, 12);

    test('a live link is live', () {
      expect(parse({}).isShareLive(now), isTrue);
    });

    test('revoking kills the link', () {
      expect(
        parse({'share_revoked_at': '2026-09-08T11:00:00Z'}).isShareLive(now),
        isFalse,
      );
    });

    test('ending the ride kills the link', () {
      expect(parse({'status': 'ended'}).isShareLive(now), isFalse);
    });

    test('the hard TTL kills the link without anyone acting', () {
      final expired = parse({
        'share_expires_at': '2026-09-08T11:00:00Z',
        'expires_at': '2026-09-08T11:00:00Z',
      });
      expect(expired.isShareLive(now), isFalse);
    });

    test('a draft ride with a live token is still shareable', () {
      expect(parse({'status': 'draft'}).isShareLive(now), isTrue);
    });
  });

  group('PackMember', () {
    test('reads the joined display name', () {
      final member = PackMember.fromJson({
        'ride_id': 'r1',
        'user_id': 'u2',
        'role': 'sweep',
        'status_code': 'refueling',
        'status_auto': false,
        'chainage_m': 2000.0,
        'chainage_at': '2026-09-08T11:59:00Z',
        'off_route': false,
        'users': {'name': 'Reshma'},
      });

      expect(member.displayName, 'Reshma');
      expect(member.role, PackRole.sweep);
      expect(member.isSweep, isTrue);
      expect(member.statusCode, PackStatus.refueling);
      expect(member.chainageAt, DateTime.utc(2026, 9, 8, 11, 59));
    });

    test('a member with no fix carries no timestamp to project forward', () {
      final member = PackMember.fromJson({
        'ride_id': 'r1',
        'user_id': 'u3',
        'role': 'rider',
        'status_code': 'riding',
        'status_auto': false,
      });

      expect(member.chainageM, isNull);
      expect(member.chainageAt, isNull);
    });
  });
}
