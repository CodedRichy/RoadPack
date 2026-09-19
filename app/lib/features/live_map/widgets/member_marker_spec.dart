import 'package:flutter/painting.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';
import '../models/member_position.dart';
import '../models/member_presence.dart';

/// Everything needed to draw one member on the map, resolved from one fix.
///
/// The single most important property of this class: [latitude] and
/// [longitude] are copied straight off [MemberPosition] and never derived from
/// speed, heading or elapsed time. Passing a later `now` changes the colour,
/// the opacity and the label — it never changes where the marker sits. A
/// marker moves if, and only if, a new fix arrives.
class MemberMarkerSpec {
  const MemberMarkerSpec({
    required this.userId,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.presence,
    required this.color,
    required this.opacity,
    required this.label,
  });

  final String userId;
  final String displayName;
  final double latitude;
  final double longitude;
  final MemberPresence presence;
  final Color color;
  final double opacity;

  /// The marker's one-line state, e.g. `Live`, `Stopped`, `Last seen 7m ago`,
  /// `No signal`.
  final String label;

  bool get isLive => presence.isLive;

  bool get isStale => presence.isStale;

  /// A heading arrow is a claim about motion, so it is drawn only while live.
  bool get showsHeading => presence.trustedHeadingDegrees != null;

  double? get headingDegrees => presence.trustedHeadingDegrees;

  /// Stale markers sit under live ones: a live rider must never be hidden
  /// behind a ghost.
  int get zIndex => isLive ? 2 : 1;

  /// Builds a spec, or null when the member has no fix to place.
  static MemberMarkerSpec? tryFrom({
    required MapMember member,
    required DateTime now,
    required AppSemantics semantics,
    required AppLocalizations l10n,
  }) {
    final position = member.position;
    if (position == null) return null;
    return from(member: member, now: now, semantics: semantics, l10n: l10n);
  }

  /// Builds a spec for a member known to have a fix.
  static MemberMarkerSpec from({
    required MapMember member,
    required DateTime now,
    required AppSemantics semantics,
    required AppLocalizations l10n,
  }) {
    final position = member.position;
    if (position == null) {
      throw ArgumentError.value(
        member,
        'member',
        'has no fix; use tryFrom for members that may not be located',
      );
    }

    final presence = MemberPresence.resolve(position: position, now: now);

    return MemberMarkerSpec(
      userId: member.userId,
      displayName: member.displayName,
      // Straight from the fix. No projection, ever.
      latitude: position.latitude,
      longitude: position.longitude,
      presence: presence,
      color: colorFor(presence.state, semantics),
      opacity: opacityFor(presence.state),
      label: presence.headline(l10n),
    );
  }

  static List<MemberMarkerSpec> buildAll({
    required List<MapMember> members,
    required DateTime now,
    required AppSemantics semantics,
    required AppLocalizations l10n,
  }) => [
    for (final m in members)
      if (tryFrom(member: m, now: now, semantics: semantics, l10n: l10n)
          case final MemberMarkerSpec spec)
        spec,
  ];

  /// Circle presence lives in the cold [AppSemantics.watchAccent] tier and
  /// drops to a neutral grey when it can no longer be trusted. It never
  /// reaches the emergency tier: a watcher is information, not a hazard.
  static Color colorFor(MemberDisplayState state, AppSemantics semantics) {
    switch (state) {
      case MemberDisplayState.live:
      case MemberDisplayState.stationary:
        return semantics.watchAccent;
      case MemberDisplayState.stale:
      case MemberDisplayState.unreachable:
      case MemberDisplayState.locating:
        return semantics.textMuted;
    }
  }

  static double opacityFor(MemberDisplayState state) {
    switch (state) {
      case MemberDisplayState.live:
      case MemberDisplayState.stationary:
        return 1;
      case MemberDisplayState.stale:
        return 0.55;
      case MemberDisplayState.unreachable:
        return 0.4;
      case MemberDisplayState.locating:
        return 0;
    }
  }
}
