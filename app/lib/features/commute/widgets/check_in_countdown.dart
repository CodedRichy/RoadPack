import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';

/// The time left to answer before the circle is told.
///
/// Drawn as a depleting road rather than a ring: a straight bar reads as
/// distance-remaining at a glance, and the rider is already looking at a road.
/// The digits are Space Grotesk tabular so the seconds column does not jitter
/// as it ticks.
///
/// Attention tier throughout — this countdown is not an emergency, it is a
/// question. The emergency tier is reserved for an incident that has actually
/// escalated, and borrowing it here would teach riders to ignore it there.
class CheckInCountdown extends StatelessWidget {
  const CheckInCountdown({
    required this.remaining,
    required this.total,
    this.caption,
    super.key,
  });

  /// Time left before escalation.
  final Duration remaining;

  /// The full window the countdown started from, used for the bar's fill.
  final Duration total;

  /// One line under the digits saying what happens at zero.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final fraction = total.inMilliseconds <= 0
        ? 0.0
        : (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1,
      maxScaleFactor: 1.3,
      child: Semantics(
        liveRegion: true,
        label: l10n.commuteAnswerSemantics(_spoken(l10n, remaining)),
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.commuteTimeToAnswerHeading,
              style: AppType.eyebrow(
                AppType.labelSm,
              ).copyWith(color: s.textMuted),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              _digits(remaining),
              style: AppType.readout(
                AppType.fluid(context, min: 56, max: 72),
              ).copyWith(color: s.attentionAccent),
            ),
            const SizedBox(height: AppSpace.lg),
            _DepletingRoad(fraction: fraction),
            if (caption != null) ...[
              const SizedBox(height: AppSpace.md),
              Text(
                caption!,
                style: AppType.bodyStyle(
                  AppType.bodySm,
                ).copyWith(color: s.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _digits(Duration d) {
    final total = d.isNegative ? Duration.zero : d;
    final minutes = total.inMinutes;
    final seconds = total.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String _spoken(AppLocalizations l10n, Duration d) {
    final total = d.isNegative ? Duration.zero : d;
    if (total.inSeconds < 60) return l10n.commuteSpokenSeconds(total.inSeconds);
    return l10n.commuteSpokenMinutes(total.inMinutes);
  }
}

/// A lane that shortens. No animation of its own — the value changes once a
/// second and the implicit animation carries it, so nothing on this screen
/// moves faster than the thing it represents.
class _DepletingRoad extends StatelessWidget {
  const _DepletingRoad({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: AppSpace.sm,
          decoration: BoxDecoration(
            color: s.surface3,
            borderRadius: AppRadius.pillAll,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: AppMotion.respectReducedMotion(
                context,
                AppMotion.quick,
              ),
              curve: AppMotion.mechanical,
              width: constraints.maxWidth * fraction,
              decoration: BoxDecoration(
                color: s.attentionAccent,
                borderRadius: AppRadius.pillAll,
              ),
            ),
          ),
        );
      },
    );
  }
}
