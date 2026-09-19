import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';

/// How many people are watching this ride.
///
/// Anti-stalking posture: a rider can always see the size of their audience.
/// This is drawn in the watch tier — cold blue, deliberately outside the
/// hazard family — because who is looking is information, never status. A
/// large number here is not a warning; it is a fact the rider is owed.
///
/// It renders at zero too. "Nobody is watching" is as much a disclosure as
/// "four people are", and a badge that only appears when someone is looking
/// teaches riders to stop looking for it.
class ViewerCountBadge extends StatelessWidget {
  const ViewerCountBadge({required this.count, super.key, this.isLive = true});

  final int count;

  /// False once the link is revoked, expired or the ride has ended.
  final bool isLive;

  static const badgeKey = Key('pack-viewer-count');

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final colour = isLive ? s.watchAccent : s.textMuted;

    return Container(
      key: badgeKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.pillAll,
        border: Border.all(
          color: colour,
          width: AppStroke.resolve(AppStroke.hairline, sunlight: s.isSunlight),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLive ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 14,
            color: colour,
          ),
          const SizedBox(width: AppSpace.xs),
          Text(
            isLive ? l10n.packWatchingCount(count) : l10n.packNotShared,
            style: AppType.figure(AppType.labelMd).copyWith(color: colour),
          ),
        ],
      ),
    );
  }
}
