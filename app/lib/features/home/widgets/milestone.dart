import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../screens/home_screen.dart';

/// The protection state, drawn as a kilometre stone.
///
/// Every Indian rider already reads a highway milestone at 60 km/h without
/// stopping -- rounded cap, coloured band, one number that matters -- so
/// borrowing that silhouette makes protection status legible before a single
/// word is. The cap band carries the state; the slab carries the detail.
///
/// This is the one place in the app allowed to be shaped like something. Every
/// other surface is a plain rectangle.
class Milestone extends StatelessWidget {
  const Milestone({required this.status, super.key});

  /// The "fix this" control, keyed so tests can assert it is glove-sized.
  static const gapActionKey = ValueKey('protection-gap-action');

  final ProtectionStatus status;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final spec = _MilestoneSpec.of(status.level, s, l10n);

    // A named gap outranks the generic per-level copy. "Partly covered" tells
    // a rider nothing they can act on; "Nobody to call" does.
    final gap = status.gap;
    final headline = gap?.headline(l10n) ?? spec.headline;
    final detail = gap?.detail(l10n) ?? spec.detail;

    // The cap radius is half the slab's width, so the silhouette holds its
    // proportion on a 360dp budget phone and a 480dp large one alike.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final radius = AppRadius.milestoneCap(width);

        return Semantics(
          label:
              '${l10n.milestoneSemantics(headline, detail, status.activeCount)} '
              '${status.emergencyContact ? l10n.milestoneSemanticsContactSet : l10n.milestoneSemanticsContactMissing}',
          excludeSemantics: true,
          child: AnimatedContainer(
            duration: AppMotion.respectReducedMotion(
              context,
              AppMotion.settled,
            ),
            curve: AppMotion.mechanical,
            decoration: BoxDecoration(
              color: s.surface1,
              borderRadius: radius,
              border: Border.all(
                color: spec.emergency ? spec.band : s.hairline,
                width: AppStroke.resolve(
                  spec.emergency ? AppStroke.heavy : AppStroke.hairline,
                  sunlight: s.isSunlight,
                ),
              ),
              boxShadow: AppElevation.shadow(
                AppElevation.raised,
                sunlight: s.isSunlight,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CapBand(spec: spec, width: width),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl,
                    AppSpace.xl,
                    AppSpace.xl,
                    AppSpace.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.protectionEyebrow,
                        style: AppType.eyebrow(
                          AppType.labelMd,
                        ).copyWith(color: s.textMuted),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        headline,
                        // The headline is the only fluid type on the screen:
                        // it is the thing read at a glance, so it takes the
                        // extra width a larger phone offers.
                        style: AppType.displayStyle(
                          AppType.fluid(
                            context,
                            min: AppType.displaySm,
                            max: AppType.displayMd,
                          ),
                          weight: FontWeight.w700,
                        ).copyWith(color: spec.headlineColour),
                        textScaler: AppType.clampScale(context, max: 1.25),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        detail,
                        style: AppType.bodyStyle(
                          AppType.bodyMd,
                        ).copyWith(color: s.textSecondary),
                      ),
                      if (gap != null) ...[
                        const SizedBox(height: AppSpace.xl),
                        SizedBox(
                          key: gapActionKey,
                          height: AppSpace.gloveTarget,
                          child: FilledButton(
                            onPressed: () => context.push(gap.route),
                            child: Text(gap.actionLabel(l10n)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The coloured cap. On a real milestone the cap colour tells you what class
/// of road you are on; here it tells you what class of cover you have.
class _CapBand extends StatelessWidget {
  const _CapBand({required this.spec, required this.width});

  final _MilestoneSpec spec;
  final double width;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.respectReducedMotion(context, AppMotion.settled),
      curve: AppMotion.mechanical,
      height: width * 0.28,
      decoration: BoxDecoration(
        color: spec.band,
        borderRadius: AppRadius.milestoneCap(width),
      ),
      alignment: Alignment.center,
      child: Text(
        spec.capLabel,
        style: AppType.eyebrow(AppType.labelMd).copyWith(color: spec.onBand),
      ),
    );
  }
}

/// Everything the milestone needs to render one state, resolved in one place
/// so a new state cannot be half-added.
@immutable
class _MilestoneSpec {
  const _MilestoneSpec({
    required this.capLabel,
    required this.headline,
    required this.detail,
    required this.band,
    required this.onBand,
    required this.headlineColour,
    required this.emergency,
  });

  final String capLabel;
  final String headline;
  final String detail;
  final Color band;
  final Color onBand;
  final Color headlineColour;
  final bool emergency;

  static _MilestoneSpec of(
    ProtectionLevel level,
    AppSemantics s,
    AppLocalizations l10n,
  ) {
    switch (level) {
      case ProtectionLevel.armed:
        return _MilestoneSpec(
          capLabel: l10n.milestoneCapArmed,
          headline: l10n.milestoneHeadlineArmed,
          detail: l10n.milestoneDetailArmed,
          band: s.protectedFill,
          onBand: s.onHazard,
          headlineColour: s.textPrimary,
          emergency: false,
        );
      case ProtectionLevel.partial:
        return _MilestoneSpec(
          capLabel: l10n.milestoneCapPartial,
          headline: l10n.milestoneHeadlinePartial,
          detail: l10n.milestoneDetailPartial,
          band: s.attentionAccent,
          onBand: AppColors.paper,
          headlineColour: s.textPrimary,
          emergency: false,
        );
      case ProtectionLevel.off:
        return _MilestoneSpec(
          capLabel: l10n.milestoneCapOff,
          headline: l10n.milestoneHeadlineOff,
          detail: l10n.milestoneDetailOff,
          band: s.border,
          onBand: s.textPrimary,
          headlineColour: s.textSecondary,
          emergency: false,
        );
      case ProtectionLevel.incident:
        // The emergency tier. Home never becomes the emergency screen -- the
        // countdown and SOS screens own that canvas -- but the milestone drops
        // its ordinary palette entirely so the two are never confusable.
        return _MilestoneSpec(
          capLabel: l10n.milestoneCapIncident,
          headline: l10n.milestoneHeadlineIncident,
          detail: l10n.milestoneDetailIncident,
          band: s.emergency,
          onBand: s.onEmergency,
          headlineColour: s.emergency,
          emergency: true,
        );
    }
  }
}
