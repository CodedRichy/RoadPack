import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/tracking_gate.dart';

/// Says, in one card, whether RoadPack is allowed to track the user and — if
/// not — exactly what is missing.
///
/// Attention tier when blocked, protected tier when clear. Never emergency:
/// "you have not finished setting up" and "you have crashed" must not share
/// a colour.
class TrackingGateCard extends StatelessWidget {
  const TrackingGateCard({
    super.key,
    required this.gate,
    this.onFixParentalConsent,
  });

  final TrackingGate gate;

  /// Route into the parental flow. Only offered when the age gate is the
  /// blocker.
  final VoidCallback? onFixParentalConsent;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final ok = gate.mayStart;
    final accent = ok ? s.protectedAccent : s.attentionAccent;

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: ok ? s.protectedFill : s.surface2,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: accent,
          width: AppStroke.resolve(AppStroke.regular, sunlight: s.isSunlight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ok
                ? context.l10n.consentGateReadyTitle
                : context.l10n.consentGateBlockedTitle,
            style: AppType.displayStyle(
              AppType.titleSm,
              weight: FontWeight.w600,
            ).copyWith(color: s.textPrimary),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            ok
                ? context.l10n.consentGateReadyBody
                : context.l10n.consentGateBlockedBody,
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textSecondary),
          ),
          for (final blocker in gate.blockers) ...[
            const SizedBox(height: AppSpace.md),
            _BlockerRow(blocker: blocker),
          ],
          if (gate.needsParentalConsent && onFixParentalConsent != null) ...[
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              height: AppSpace.gloveTarget,
              width: double.infinity,
              child: FilledButton(
                onPressed: onFixParentalConsent,
                child: Text(context.l10n.consentGateAskParentAction),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BlockerRow extends StatelessWidget {
  const _BlockerRow({required this.blocker});

  final TrackingBlocker blocker;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.xs),
          child: Container(
            width: AppSpace.sm,
            height: AppSpace.sm,
            decoration: BoxDecoration(
              color: s.attentionAccent,
              borderRadius: AppRadius.pillAll,
            ),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                blocker.title(context.l10n),
                style: AppType.bodyStyle(
                  AppType.bodySm,
                  weight: FontWeight.w600,
                ).copyWith(color: s.textPrimary),
              ),
              Text(
                blocker.explanation(context.l10n),
                style: AppType.bodyStyle(
                  AppType.labelMd,
                ).copyWith(color: s.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
