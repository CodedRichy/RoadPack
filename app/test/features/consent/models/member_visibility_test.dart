import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/models/circle_member.dart';
import 'package:roadpack/features/consent/models/visibility_report.dart';

Circle _circle(String id, {bool sharing = true}) => Circle(
  id: id,
  name: 'Home',
  type: CircleType.family,
  createdBy: 'me',
  settings: sharing ? const {'location_sharing': true} : const {},
  createdAt: DateTime(2026, 1, 1),
);

CircleMember _member(
  String userId, {
  Map<String, dynamic> permissions = const {},
  CircleRole role = CircleRole.member,
}) => CircleMember(
  circleId: 'c1',
  userId: userId,
  role: role,
  permissions: permissions,
  userName: userId,
  joinedAt: DateTime(2026, 1, 1),
);

VisibilityReport _report({
  required Map<String, dynamic> selfPermissions,
  required bool enforced,
  bool circleSharing = true,
}) => VisibilityReport.from(
  selfUserId: 'me',
  circles: [_circle('c1', sharing: circleSharing)],
  membersByCircleId: {
    'c1': [_member('me', permissions: selfPermissions), _member('amma')],
  },
  memberOptOutEnforced: enforced,
);

void main() {
  group('readMemberSharingFlag mirrors COALESCE(..., true)', () {
    test('an absent key is sharing — absence of an opt-out is not one', () {
      expect(VisibilityReport.readMemberSharingFlag(const {}), isTrue);
    });

    test('an explicit false opts out', () {
      expect(
        VisibilityReport.readMemberSharingFlag(const {'share_location': false}),
        isFalse,
      );
      expect(
        VisibilityReport.readMemberSharingFlag(const {
          'share_location': 'false',
        }),
        isFalse,
      );
    });

    test('an unrelated permissions bag does not opt the user out', () {
      expect(
        VisibilityReport.readMemberSharingFlag(const {'can_edit': false}),
        isTrue,
      );
    });
  });

  group('a member who has stopped sharing is not visible', () {
    test('own opt-out hides the user from an otherwise sharing circle', () {
      final report = _report(
        selfPermissions: const {'share_location': false},
        enforced: true,
      );
      expect(report.watchers, isEmpty);
      expect(report.isPrivate, isTrue);
      expect(report.circles.single.sharingEnabled, isTrue);
      expect(report.circles.single.selfSharingEnabled, isFalse);
      expect(report.circles.single.exposesSelf, isFalse);
    });

    test('without the opt-out the same circle does expose the user', () {
      final report = _report(selfPermissions: const {}, enforced: true);
      expect(report.watchers.map((w) => w.userId), ['amma']);
      expect(report.circles.single.exposesSelf, isTrue);
    });

    test('another member opting out does not hide *you*', () {
      // can_view_location tests the target's flag, not the viewer's. A
      // watcher who has stopped broadcasting can still watch.
      final report = VisibilityReport.from(
        selfUserId: 'me',
        circles: [_circle('c1')],
        membersByCircleId: {
          'c1': [
            _member('me'),
            _member('amma', permissions: const {'share_location': false}),
          ],
        },
        memberOptOutEnforced: true,
      );
      expect(report.watchers.map((w) => w.userId), ['amma']);
    });
  });

  group('the screen and can_view_location agree', () {
    /// The rule the server runs, transcribed from migration 00005 (plus the
    /// member term migration 00021 adds). If these two ever disagree, the
    /// screen is lying to the user about who can see them.
    bool canViewLocation({
      required String viewer,
      required String target,
      required List<Circle> circles,
      required Map<String, List<CircleMember>> membersByCircleId,
      required bool memberTermEnforced,
    }) {
      for (final c in circles) {
        final members = membersByCircleId[c.id] ?? const <CircleMember>[];
        final cm1 = members.where((m) => m.userId == viewer);
        final cm2 = members.where((m) => m.userId == target);
        if (cm1.isEmpty || cm2.isEmpty) continue;
        if (!VisibilityReport.readSharingFlag(c.settings)) continue;
        if (memberTermEnforced &&
            !VisibilityReport.readMemberSharingFlag(cm2.first.permissions)) {
          continue;
        }
        return true;
      }
      return false;
    }

    final cases =
        <String, ({Map<String, dynamic> settings, Map<String, dynamic> perms})>{
          'sharing on, no opt-out': (
            settings: {'location_sharing': true},
            perms: {},
          ),
          'sharing on, opted out': (
            settings: {'location_sharing': true},
            perms: {'share_location': false},
          ),
          'sharing off, no opt-out': (settings: {}, perms: {}),
          'sharing off, opted out': (
            settings: {},
            perms: {'share_location': false},
          ),
          'sharing as text true': (
            settings: {'location_sharing': 'true'},
            perms: {},
          ),
        };

    for (final enforced in [false, true]) {
      for (final entry in cases.entries) {
        test('${entry.key} (member term enforced: $enforced)', () {
          final circle = Circle(
            id: 'c1',
            name: 'Home',
            type: CircleType.family,
            createdBy: 'me',
            settings: entry.value.settings,
            createdAt: DateTime(2026, 1, 1),
          );
          final members = [
            _member('me', permissions: entry.value.perms),
            _member('amma'),
          ];

          final serverSays = canViewLocation(
            viewer: 'amma',
            target: 'me',
            circles: [circle],
            membersByCircleId: {'c1': members},
            memberTermEnforced: enforced,
          );

          final screenSays = VisibilityReport.from(
            selfUserId: 'me',
            circles: [circle],
            membersByCircleId: {'c1': members},
            memberOptOutEnforced: enforced,
          ).watchers.any((w) => w.userId == 'amma');

          expect(
            screenSays,
            serverSays,
            reason: 'the screen must never disagree with can_view_location',
          );
        });
      }
    }
  });

  test('the member opt-out is not offered before the server enforces it', () {
    // Applying it early would make the screen under-report: it would tell a
    // user nobody can see them while the server still hands the position
    // over. Ship the control only when it does something.
    final report = _report(
      selfPermissions: const {'share_location': false},
      enforced: kMemberLocationOptOutEnforced,
    );
    expect(
      report.circles.single.exposesSelf,
      !kMemberLocationOptOutEnforced,
      reason: 'client behaviour tracks the server, not the wish',
    );
  });
}
