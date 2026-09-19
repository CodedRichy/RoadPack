import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/models/circle_member.dart';
import 'package:roadpack/features/consent/models/visibility_report.dart';

Circle _circle(
  String id, {
  String name = 'Circle',
  CircleType type = CircleType.family,
  Map<String, dynamic> settings = const {},
}) => Circle(
  id: id,
  name: name,
  type: type,
  createdBy: 'me',
  settings: settings,
  createdAt: DateTime(2026, 1, 1),
);

CircleMember _member(
  String circleId,
  String userId, {
  String? name,
  CircleRole role = CircleRole.member,
  DateTime? acceptedAt,
}) => CircleMember(
  circleId: circleId,
  userId: userId,
  role: role,
  userName: name,
  acceptedAt: acceptedAt,
  joinedAt: DateTime(2026, 1, 1),
);

void main() {
  group('readSharingFlag mirrors can_view_location', () {
    test('a missing key is off, as COALESCE(..., false) says', () {
      expect(VisibilityReport.readSharingFlag(const {}), isFalse);
    });

    test('an explicit false is off', () {
      expect(
        VisibilityReport.readSharingFlag(const {'location_sharing': false}),
        isFalse,
      );
    });

    test('json true and the text "true" are both on, as ->>::BOOLEAN is', () {
      expect(
        VisibilityReport.readSharingFlag(const {'location_sharing': true}),
        isTrue,
      );
      expect(
        VisibilityReport.readSharingFlag(const {'location_sharing': 'true'}),
        isTrue,
      );
    });

    test('a non-boolean value is off, never a truthy accident', () {
      expect(
        VisibilityReport.readSharingFlag(const {'location_sharing': 'maybe'}),
        isFalse,
      );
      expect(
        VisibilityReport.readSharingFlag(const {'location_sharing': null}),
        isFalse,
      );
    });
  });

  group('VisibilityReport lists exactly who can_view_location permits', () {
    test('a sharing circle exposes its other members, and only those', () {
      final sharing = _circle(
        'c1',
        name: 'Home',
        settings: const {'location_sharing': true},
      );
      final silent = _circle('c2', name: 'College', type: CircleType.commute);

      final report = VisibilityReport.from(
        selfUserId: 'me',
        circles: [sharing, silent],
        membersByCircleId: {
          'c1': [
            _member('c1', 'me', name: 'Me', role: CircleRole.admin),
            _member('c1', 'amma', name: 'Amma'),
          ],
          'c2': [
            _member('c2', 'me', name: 'Me'),
            _member('c2', 'warden', name: 'Warden'),
          ],
        },
      );

      expect(report.watchers.map((w) => w.userId), ['amma']);
      expect(report.watcherCount, 1);
      expect(
        report.circles.firstWhere((c) => c.circle.id == 'c2').watchers,
        isEmpty,
        reason: 'a circle with no location_sharing key exposes nobody',
      );
    });

    test('the user is never listed as watching themselves', () {
      final report = VisibilityReport.from(
        selfUserId: 'me',
        circles: [
          _circle('c1', settings: const {'location_sharing': true}),
        ],
        membersByCircleId: {
          'c1': [_member('c1', 'me', name: 'Me')],
        },
      );
      expect(report.watchers, isEmpty);
      expect(report.isPrivate, isTrue);
    });

    test('a member who has not accepted still counts, because SQL says so', () {
      // can_view_location joins circle_members with no accepted_at
      // predicate. Filtering here would tell the user they are private when
      // the server would hand over their position.
      final report = VisibilityReport.from(
        selfUserId: 'me',
        circles: [
          _circle('c1', settings: const {'location_sharing': true}),
        ],
        membersByCircleId: {
          'c1': [
            _member('c1', 'me'),
            _member('c1', 'pending', name: 'Pending', acceptedAt: null),
          ],
        },
      );
      expect(report.watchers.map((w) => w.userId), ['pending']);
    });

    test(
      'one person in two sharing circles is listed once, with both reasons',
      () {
        final a = _circle(
          'c1',
          name: 'Home',
          settings: const {'location_sharing': true},
        );
        final b = _circle(
          'c2',
          name: 'Riders',
          type: CircleType.friends,
          settings: const {'location_sharing': true},
        );
        final report = VisibilityReport.from(
          selfUserId: 'me',
          circles: [a, b],
          membersByCircleId: {
            'c1': [_member('c1', 'me'), _member('c1', 'raju', name: 'Raju')],
            'c2': [_member('c2', 'me'), _member('c2', 'raju', name: 'Raju')],
          },
        );
        expect(report.watcherCount, 1);
        expect(report.watchersOf('raju'), hasLength(2));
        expect(
          report.watchersOf('raju').map((w) => w.circleName),
          containsAll(<String>['Home', 'Riders']),
        );
      },
    );

    test('admin status decides whether the user may change the setting', () {
      final report = VisibilityReport.from(
        selfUserId: 'me',
        circles: [
          _circle('c1', settings: const {'location_sharing': true}),
          _circle('c2', settings: const {'location_sharing': true}),
        ],
        membersByCircleId: {
          'c1': [_member('c1', 'me', role: CircleRole.admin)],
          'c2': [_member('c2', 'me', role: CircleRole.member)],
        },
      );
      expect(report.circles[0].viewerIsAdmin, isTrue);
      expect(report.circles[1].viewerIsAdmin, isFalse);
    });

    test('an unnamed member is still shown, never silently dropped', () {
      final report = VisibilityReport.from(
        selfUserId: 'me',
        circles: [
          _circle('c1', settings: const {'location_sharing': true}),
        ],
        membersByCircleId: {
          'c1': [_member('c1', 'me'), _member('c1', 'ghost', name: '  ')],
        },
      );
      expect(report.watchers, hasLength(1));
      expect(report.watchers.single.name, 'Someone in this circle');
    });

    test('an unknown report is not the same as a private one', () {
      const unknown = VisibilityReport.unknown();
      expect(unknown.isKnown, isFalse);
      expect(unknown.isPrivate, isFalse);
    });
  });
}
