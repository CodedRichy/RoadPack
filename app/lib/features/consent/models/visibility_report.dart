import '../../../l10n/l10n.dart';
import '../../circles/models/circle.dart';
import '../../circles/models/circle_member.dart';

/// Whether the server's `can_view_location` also honours the *target's* own
/// `circle_members.permissions->>'share_location'` flag.
///
/// Migration 00021 added the per-member term, so it does:
/// `COALESCE((cm2.permissions->>'share_location')::BOOLEAN, true)`, where
/// `cm2` is the *target* — the person being looked at. A member can
/// therefore stop being watched without leaving the circle.
///
/// This constant ties the client to that reality on purpose. Applying the
/// member flag before the server did would have made "Who can see me"
/// *under* report — telling a user nobody can see them while the server
/// still handed their position over. That is the one direction this screen
/// must never be wrong in. If `can_view_location` is ever rolled back, set
/// this to false in the same change, or the screen starts lying.
const bool kMemberLocationOptOutEnforced = true;

/// One person who can currently see the user's location, and the reason.
///
/// "Why" is not decoration here. FR-014 is a counter-stalking control
/// (SG-01), and a list of names with no attached reason gives the user no
/// lever to pull.
class Watcher {
  const Watcher({
    required this.userId,
    required this.name,
    required this.circleId,
    required this.circleName,
    required this.circleType,
    required this.role,
  });

  final String userId;

  /// Display name, or a placeholder when the row has none. Never blank —
  /// an unnamed watcher in this list would read as no watcher at all.
  final String name;

  final String circleId;
  final String circleName;
  final CircleType circleType;
  final CircleRole role;

  /// The plain-language "why", in the user's own terms.
  ///
  /// Sentence frame and circle-type name are both localised (FR-005). The
  /// circle's own name is user data and is never translated.
  String reason(AppLocalizations l10n) => l10n.consentWatcherReason(
    circleType.displayName(l10n).toLowerCase(),
    circleName,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Watcher &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          name == other.name &&
          circleId == other.circleId &&
          circleName == other.circleName &&
          circleType == other.circleType &&
          role == other.role;

  @override
  int get hashCode =>
      Object.hash(userId, name, circleId, circleName, circleType, role);

  @override
  String toString() => 'Watcher($name via $circleName)';
}

/// One circle's contribution to the user's visibility.
class CircleVisibility {
  const CircleVisibility({
    required this.circle,
    required this.sharingEnabled,
    required this.selfSharingEnabled,
    required this.viewerIsAdmin,
    required this.watchers,
    this.selfMembership,
  });

  final Circle circle;

  /// Mirrors `COALESCE((circles.settings->>'location_sharing')::BOOLEAN,
  /// false)` — the exact expression `can_view_location` evaluates. Absent
  /// means off, because the server reads it that way.
  final bool sharingEnabled;

  /// The signed-in user's own `permissions->>'share_location'` on their
  /// membership row — the term `can_view_location` evaluates against the
  /// *target*, i.e. against the user reading this screen.
  final bool selfSharingEnabled;

  /// The signed-in user's own membership row, needed to write the
  /// member-side opt-out. Null if the user is somehow not a member of a
  /// circle their own list returned.
  final CircleMember? selfMembership;

  /// Whether anyone can actually see the user through this circle: the
  /// circle's setting AND the user's own. Both terms are the server's.
  bool get exposesSelf => sharingEnabled && selfSharingEnabled;

  /// Whether the signed-in user may change [sharingEnabled] for this
  /// circle. `circles_update` RLS is `is_circle_admin(...)`, so a plain
  /// member cannot turn this off — their lever is leaving the circle, and
  /// the screen has to say so rather than show a switch that silently
  /// fails.
  final bool viewerIsAdmin;

  /// The other members this circle exposes the user to. Empty when
  /// [sharingEnabled] is false.
  final List<Watcher> watchers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircleVisibility &&
          runtimeType == other.runtimeType &&
          circle == other.circle &&
          sharingEnabled == other.sharingEnabled &&
          selfSharingEnabled == other.selfSharingEnabled &&
          viewerIsAdmin == other.viewerIsAdmin &&
          _listEquals(watchers, other.watchers);

  @override
  int get hashCode => Object.hash(
    circle,
    sharingEnabled,
    selfSharingEnabled,
    viewerIsAdmin,
    watchers.length,
  );

  static bool _listEquals(List<Watcher> a, List<Watcher> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Who can see the signed-in user right now — derived by the same rule the
/// server enforces in `can_view_location(viewer, target)` (migration 00005):
///
/// ```sql
/// EXISTS (SELECT 1 FROM circle_members cm1
///         JOIN circle_members cm2 ON cm1.circle_id = cm2.circle_id
///         JOIN circles c ON c.id = cm1.circle_id
///         WHERE cm1.user_id = viewer AND cm2.user_id = target
///           AND COALESCE((c.settings->>'location_sharing')::BOOLEAN, false))
/// ```
///
/// Two consequences are load-bearing and must not be "improved" away:
///
/// 1. The circle setting is the *only* gate besides shared membership.
///    There is no `accepted_at` check server-side, so there is none here —
///    showing a pending member as unable to see you would be a lie in the
///    dangerous direction.
/// 2. A circle with no `location_sharing` key exposes nobody. The screen
///    must show that circle as "nobody can see you here", not omit it.
class VisibilityReport {
  const VisibilityReport(this.circles) : isKnown = true;

  /// Nothing is known yet (not loaded, or the fetch failed). Distinct from
  /// "nobody can see you": the screen says so instead of reassuring.
  const VisibilityReport.unknown() : circles = const [], isKnown = false;

  final List<CircleVisibility> circles;

  final bool isKnown;

  /// Builds the report from the circles the user belongs to and each
  /// circle's member list.
  ///
  /// [selfUserId] is excluded from the watcher lists — the user seeing
  /// themselves listed as watching themselves is noise that hides the
  /// entries that matter.
  factory VisibilityReport.from({
    required String selfUserId,
    required List<Circle> circles,
    required Map<String, List<CircleMember>> membersByCircleId,
    bool memberOptOutEnforced = kMemberLocationOptOutEnforced,
  }) {
    final out = <CircleVisibility>[];
    for (final circle in circles) {
      final sharing = readSharingFlag(circle.settings);
      final members = membersByCircleId[circle.id] ?? const <CircleMember>[];
      final viewerIsAdmin = members.any(
        (m) => m.userId == selfUserId && m.isAdmin,
      );
      final self = members.where((m) => m.userId == selfUserId);
      final selfSharing = !memberOptOutEnforced
          ? true
          : self.isEmpty || readMemberSharingFlag(self.first.permissions);
      final watchers = <Watcher>[];
      if (sharing && selfSharing) {
        for (final m in members) {
          if (m.userId == selfUserId) continue;
          watchers.add(
            Watcher(
              userId: m.userId,
              name: (m.userName == null || m.userName!.trim().isEmpty)
                  ? 'Someone in this circle'
                  : m.userName!.trim(),
              circleId: circle.id,
              circleName: circle.name,
              circleType: circle.type,
              role: m.role,
            ),
          );
        }
      }
      out.add(
        CircleVisibility(
          circle: circle,
          sharingEnabled: sharing,
          selfSharingEnabled: selfSharing,
          viewerIsAdmin: viewerIsAdmin,
          watchers: watchers,
          selfMembership: self.isEmpty ? null : self.first,
        ),
      );
    }
    return VisibilityReport(out);
  }

  /// Reads `settings->>'location_sharing'` the way Postgres does.
  ///
  /// The `->>` operator yields text, and the migration casts that text to
  /// BOOLEAN, so a JSON `true` and the string `"true"` both mean on, and a
  /// missing key means off via `COALESCE(..., false)`.
  static bool readSharingFlag(Map<String, dynamic> settings) {
    final raw = settings['location_sharing'];
    if (raw is bool) return raw;
    if (raw is String) {
      final v = raw.toLowerCase();
      return v == 'true' || v == 't' || v == 'yes' || v == 'on' || v == '1';
    }
    return false;
  }

  /// Reads `circle_members.permissions->>'share_location'` the way
  /// migration 00021's `can_view_location` does: `COALESCE(..., true)`.
  ///
  /// True by default because this is a member-side *restriction* only
  /// (SG-04): the absence of an opt-out is not an opt-out, and every row
  /// written before the feature existed must keep behaving as it did.
  static bool readMemberSharingFlag(Map<String, dynamic> permissions) {
    final raw = permissions['share_location'];
    if (raw is bool) return raw;
    if (raw is String) {
      final v = raw.toLowerCase();
      return !(v == 'false' || v == 'f' || v == 'no' || v == 'off' || v == '0');
    }
    return true;
  }

  /// Every distinct person who can see the user, first reason kept.
  List<Watcher> get watchers {
    final seen = <String>{};
    final out = <Watcher>[];
    for (final c in circles) {
      for (final w in c.watchers) {
        if (seen.add(w.userId)) out.add(w);
      }
    }
    return List.unmodifiable(out);
  }

  /// Every reason each person can see you, including duplicates across
  /// circles — leaving one circle may not be enough, and the user needs to
  /// see that.
  List<Watcher> watchersOf(String userId) => [
    for (final c in circles)
      for (final w in c.watchers)
        if (w.userId == userId) w,
  ];

  int get watcherCount => watchers.length;

  /// True when, right now, nobody can see the user's location.
  bool get isPrivate => isKnown && watcherCount == 0;
}
