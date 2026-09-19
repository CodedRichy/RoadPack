import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/pack_gap.dart';
import '../models/pack_status.dart';

/// Keys the suppression rules are asserted against.
///
/// [GapReadoutKeys.gapValue] exists on exactly one code path: the one where the server
/// said a number is safe to show. If a test finds it in an off-route, stale or
/// locating state, the honesty contract has been broken.
abstract final class GapReadoutKeys {
  static const gapValue = Key('pack-gap-value');
  static const suppressed = Key('pack-gap-suppressed');
  static const estimateMarker = Key('pack-gap-estimate-marker');
}

/// The gap between this rider and the front of the pack.
///
/// This single cell is the product. Everything else — the map, the roster, the
/// share sheet — is scaffolding around the question a rider actually asks at a
/// petrol pump: how far back is everyone?
///
/// It answers that question or it refuses to. There is no third mode. The
/// refusals are not degraded states to be minimised; they are the feature.
/// A pack that trusts a stale number waits at the wrong junction, or worse,
/// rides on believing someone is behind them who is not.
class GapReadout extends StatelessWidget {
  const GapReadout({
    required this.gap,
    super.key,
    this.lastSeenAt,
    this.now,
    this.size = AppType.titleSm,
  });

  final PackGap gap;

  /// When this member's position was last recorded. Only read in the stale
  /// state, and never used to project a position forward.
  final DateTime? lastSeenAt;

  /// Injectable clock, so "last seen 4m ago" is testable.
  final DateTime? now;

  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;

    // The gate. Off route, stale or not yet located and no number is drawn,
    // whatever gap_m happens to contain.
    if (!gap.canShowGap) {
      return _Suppressed(
        gap: gap,
        lastSeenAt: lastSeenAt,
        now: now,
        size: size,
      );
    }

    if (gap.isFront) {
      return Text(
        l10n.packGapFront,
        key: GapReadoutKeys.suppressed,
        style: AppType.bodyStyle(
          AppType.bodySm,
          weight: FontWeight.w600,
        ).copyWith(color: s.protectedAccent),
      );
    }

    final metres = gap.metresBehind!;
    final estimated = gap.gapEstimated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (estimated)
              Padding(
                key: GapReadoutKeys.estimateMarker,
                padding: const EdgeInsets.only(right: AppSpace.xs),
                child: Text(
                  '~',
                  style: AppType.figure(
                    size,
                  ).copyWith(color: s.attentionAccent),
                ),
              ),
            Text(
              formatDistance(metres),
              key: GapReadoutKeys.gapValue,
              style: AppType.figure(size).copyWith(color: s.attentionAccent),
            ),
          ],
        ),
        Text(
          _behindLabel(l10n, gap.gapS, estimated),
          style: AppType.eyebrow(AppType.labelSm).copyWith(color: s.textMuted),
        ),
      ],
    );
  }

  static String _behindLabel(
    AppLocalizations l10n,
    double? gapS,
    bool estimated,
  ) {
    if (gapS == null) {
      return estimated ? l10n.packBehindLabelEst : l10n.packBehindLabel;
    }
    final duration = formatDuration(Duration(seconds: gapS.abs().round()));
    return estimated
        ? l10n.packBehindWithDurationEst(duration)
        : l10n.packBehindWithDuration(duration);
  }
}

/// The three refusals. Each says what is actually known, and no more.
class _Suppressed extends StatelessWidget {
  const _Suppressed({
    required this.gap,
    required this.size,
    this.lastSeenAt,
    this.now,
  });

  final PackGap gap;
  final double size;
  final DateTime? lastSeenAt;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;

    final (
      String headline,
      String? detail,
      Color colour,
    ) = switch (gap.displayState) {
      // Off route beats stale beats locating — same precedence the RPC uses.
      // A rider who left the route and then lost signal is off route first;
      // that is the fact the pack has to act on.
      PackDisplayState.offRoute => (
        l10n.packOffRouteHeadline,
        gap.straightM == null
            ? l10n.packStraightLineUnknown
            : l10n.packDistanceAway(formatDistance(gap.straightM!)),
        s.attentionAccent,
      ),
      PackDisplayState.stale => (
        l10n.packLastSeenHeadline,
        _lastSeenLabel(l10n),
        s.textMuted,
      ),
      PackDisplayState.locating => (l10n.packLocatingHeadline, null, s.textMuted),
      _ => (l10n.packLocatingHeadline, null, s.textMuted),
    };

    return Column(
      key: GapReadoutKeys.suppressed,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headline,
          style: AppType.bodyStyle(
            AppType.bodySm,
            weight: FontWeight.w600,
          ).copyWith(color: colour),
        ),
        if (detail != null)
          Text(
            detail,
            style: AppType.bodyStyle(
              AppType.labelMd,
            ).copyWith(color: s.textMuted),
          ),
      ],
    );
  }

  String _lastSeenLabel(AppLocalizations l10n) {
    final at = lastSeenAt;
    if (at == null) return l10n.packNoFixYet;
    final elapsed = (now ?? DateTime.now().toUtc()).difference(at);
    if (elapsed.isNegative) return l10n.packJustNow;
    return l10n.packAgoCompact(formatDuration(elapsed));
  }
}

/// Distances in the units a rider reads on a signboard.
String formatDistance(double metres) {
  final m = metres.abs();
  if (m < 950) return '${m.round()} m';
  final km = m / 1000;
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}

/// Durations, coarsened deliberately. A gap reported to the second implies a
/// precision the ~5s tick and ~30s ingest latency do not have.
String formatDuration(Duration d) {
  final seconds = d.inSeconds.abs();
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}
