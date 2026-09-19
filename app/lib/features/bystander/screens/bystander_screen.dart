import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../models/bystander_copy.dart';
import '../models/bystander_lang.dart';
import '../models/ice_profile.dart';
import '../providers/bystander_providers.dart';
import '../widgets/widgets.dart';

/// FR-007 / FR-090 (Phase-1 notification variant) / FR-091.
///
/// The reader is a stranger who did not install this app, is probably
/// frightened, may be in direct sun, and cannot unlock the phone. So:
/// three actions and nothing that competes with them; the emergency tier,
/// which this is one of the few surfaces entitled to; borders instead of
/// shadows; text scale clamped so nothing reflows off screen.
///
/// It does NOT go over the lock screen -- that is Phase 2 (FR-090).
class BystanderScreen extends ConsumerWidget {
  const BystanderScreen({super.key});

  static const dial112Key = ValueKey('bystander.dial112');
  static const dialContactKey = ValueKey('bystander.dialContact');
  static const directionsKey = ValueKey('bystander.directions');
  static const iceKey = ValueKey('bystander.ice');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.semantics;
    final session = ref.watch(bystanderSessionProvider);
    final lang = ref.watch(bystanderLangProvider);
    final actions = ref.watch(bystanderActionsProvider);
    final hospitals = ref.watch(nearestHospitalsProvider);
    final nearest = hospitals.asData?.value.firstOrNull;
    final ice = IceQrPayload.forSession(session);

    return MediaQuery(
      // A countdown or a phone number that reflows off screen is worse than
      // one that is merely large.
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: AppType.clampScale(context, max: 1.3)),
      child: Scaffold(
        backgroundColor: s.canvas,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpace.xxl),
            children: [
              _Header(lang: lang, ref: ref),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.xl,
                  AppSpace.gutter,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BystanderActionButton(
                      key: dial112Key,
                      label: BystanderCopy.dial112(lang),
                      sublabel: BystanderCopy.dial112Sub(lang),
                      icon: Icons.call,
                      emphasis: BystanderActionEmphasis.primary,
                      onPressed: actions.dialEmergencyNumber,
                    ),
                    const SizedBox(height: AppSpace.md),
                    BystanderActionButton(
                      key: dialContactKey,
                      label: session.hasContact
                          ? BystanderCopy.dialContact(lang)
                          : BystanderCopy.noContact(lang),
                      sublabel: session.contactName,
                      icon: Icons.person_outline,
                      onPressed: session.hasContact
                          ? () => actions.dialContact(session.contactPhone!)
                          : null,
                    ),
                    const SizedBox(height: AppSpace.md),
                    BystanderActionButton(
                      key: directionsKey,
                      label: BystanderCopy.directions(lang),
                      sublabel: nearest == null
                          ? BystanderCopy.noHospital(lang)
                          : '${nearest.hospital.name} - '
                                '${nearest.distanceLabel} '
                                '(${BystanderCopy.straightLine(lang)})',
                      footnote: nearest == null || nearest.hospital.isVerified
                          ? null
                          : BystanderCopy.unverified(lang),
                      icon: Icons.local_hospital_outlined,
                      onPressed: nearest == null
                          ? null
                          : () => actions.openDirections(
                              lat: nearest.hospital.lat,
                              lng: nearest.hospital.lng,
                              label: nearest.hospital.name,
                            ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    CoordinatesPanel(session: session, lang: lang),
                    const SizedBox(height: AppSpace.md),
                    GoodSamaritanNotice(lang: lang),
                    const SizedBox(height: AppSpace.md),
                    FirstAidCard(lang: lang),
                    if (ice != null) ...[
                      const SizedBox(height: AppSpace.md),
                      IceCard(key: iceKey, payload: ice, lang: lang),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-bleed emergency field. Colour is not carrying the tier on its own --
/// the band is edge to edge and the type is oversized, so it still reads as
/// an emergency in greyscale, in glare, or at arm's length.
class _Header extends StatelessWidget {
  const _Header({required this.lang, required this.ref});

  final BystanderLang lang;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    return Container(
      width: double.infinity,
      color: s.emergencyDeep,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.xl,
        AppSpace.gutter,
        AppSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            BystanderCopy.title(lang),
            style: AppType.displayStyle(
              AppType.fluid(context, min: AppType.titleMd, max: AppType.titleLg),
              weight: FontWeight.w700,
            ).copyWith(color: s.onEmergency),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            BystanderCopy.subtitle(lang),
            style: AppType.bodyStyle(
              AppType.bodyMd,
            ).copyWith(color: s.onEmergency.withValues(alpha: 0.92)),
          ),
          const SizedBox(height: AppSpace.lg),
          BystanderLanguageSwitch(
            value: lang,
            onChanged: (l) => ref.read(bystanderLangProvider.notifier).set(l),
          ),
        ],
      ),
    );
  }
}
