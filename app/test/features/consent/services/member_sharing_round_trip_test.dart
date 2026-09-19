import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/models/circle_member.dart';
import 'package:roadpack/features/consent/models/visibility_report.dart';
import 'package:roadpack/features/consent/services/circle_sharing_service.dart';

/// In-memory stand-in for `circles` + `circle_members`, applying the same
/// merge semantics as the Supabase writes: a jsonb bag is replaced wholesale
/// with the old keys plus the new one.
class FakeSharingStore implements CircleSharingGateway {
  FakeSharingStore({required this.circle, required this.members});

  Circle circle;
  List<CircleMember> members;

  @override
  Future<void> setLocationSharing({
    required Circle circle,
    required bool enabled,
  }) async {
    this.circle = circle.copyWith(
      settings: {...circle.settings, 'location_sharing': enabled},
    );
  }

  @override
  Future<void> setMemberSharing({
    required CircleMember membership,
    required bool enabled,
  }) async {
    members = [
      for (final m in members)
        if (m.circleId == membership.circleId && m.userId == membership.userId)
          m.copyWith(permissions: {...m.permissions, 'share_location': enabled})
        else
          m,
    ];
  }

  VisibilityReport get report => VisibilityReport.from(
    selfUserId: 'me',
    circles: [circle],
    membersByCircleId: {circle.id: members},
  );
}

FakeSharingStore _store({Map<String, dynamic> selfPermissions = const {}}) =>
    FakeSharingStore(
      circle: Circle(
        id: 'c1',
        name: 'Home',
        type: CircleType.family,
        createdBy: 'me',
        settings: const {'location_sharing': true},
        createdAt: DateTime(2026, 1, 1),
      ),
      members: [
        CircleMember(
          circleId: 'c1',
          userId: 'me',
          role: CircleRole.member,
          permissions: selfPermissions,
          userName: 'Me',
          joinedAt: DateTime(2026, 1, 1),
        ),
        CircleMember(
          circleId: 'c1',
          userId: 'amma',
          role: CircleRole.member,
          userName: 'Amma',
          joinedAt: DateTime(2026, 1, 1),
        ),
      ],
    );

void main() {
  test('the enforcement flag matches the shipped migration', () {
    // Migration 00021 added the member term to can_view_location. If this
    // ever goes back to false while the migration is live, the screen starts
    // over-reporting; if the migration is rolled back while this stays true,
    // it starts under-reporting. They move together or not at all.
    expect(kMemberLocationOptOutEnforced, isTrue);
  });

  group('member opt-out round-trips through the write path', () {
    test('switching off hides the user; switching on restores them', () async {
      final store = _store();
      expect(store.report.watchers.map((w) => w.userId), ['amma']);

      final me = store.report.circles.single.selfMembership!;
      await store.setMemberSharing(membership: me, enabled: false);

      expect(store.report.watchers, isEmpty);
      expect(store.report.circles.single.selfSharingEnabled, isFalse);
      expect(
        store.report.circles.single.sharingEnabled,
        isTrue,
        reason: 'the circle-wide setting is untouched',
      );

      await store.setMemberSharing(
        membership: store.report.circles.single.selfMembership!,
        enabled: true,
      );

      expect(store.report.watchers.map((w) => w.userId), ['amma']);
      expect(store.report.circles.single.selfSharingEnabled, isTrue);
    });

    test('the write targets the member own row, and only that row', () async {
      final store = _store();
      final me = store.report.circles.single.selfMembership!;
      await store.setMemberSharing(membership: me, enabled: false);

      final amma = store.members.firstWhere((m) => m.userId == 'amma');
      expect(
        amma.permissions,
        isEmpty,
        reason: 'no remote configuration of another member (SG-04)',
      );
    });

    test('unrelated permission keys survive the merge', () async {
      final store = _store(selfPermissions: const {'some_other_flag': true});
      final me = store.report.circles.single.selfMembership!;
      await store.setMemberSharing(membership: me, enabled: false);

      final mine = store.members.firstWhere((m) => m.userId == 'me');
      expect(mine.permissions['some_other_flag'], isTrue);
      expect(mine.permissions['share_location'], isFalse);
    });

    test('an opted-out member is still a member', () async {
      final store = _store();
      final me = store.report.circles.single.selfMembership!;
      await store.setMemberSharing(membership: me, enabled: false);

      expect(store.members.where((m) => m.userId == 'me'), hasLength(1));
      expect(
        store.report.circles.single.selfMembership,
        isNotNull,
        reason: 'stopping sharing is not leaving the safety net',
      );
    });

    test('the admin switch and the member switch are independent', () async {
      final store = _store();
      final me = store.report.circles.single.selfMembership!;

      await store.setMemberSharing(membership: me, enabled: false);
      await store.setLocationSharing(circle: store.circle, enabled: false);
      expect(store.report.watchers, isEmpty);

      await store.setLocationSharing(circle: store.circle, enabled: true);
      expect(
        store.report.watchers,
        isEmpty,
        reason: 'the admin re-enabling the circle must not undo my opt-out',
      );

      await store.setMemberSharing(
        membership: store.report.circles.single.selfMembership!,
        enabled: true,
      );
      expect(store.report.watchers.map((w) => w.userId), ['amma']);
    });
  });
}
