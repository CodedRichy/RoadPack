import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/emergency_contact.dart';
import '../models/ice_exposure.dart';
import '../providers/ice_gate_provider.dart';

/// The in-case-of-emergency card.
///
/// Read by a stranger, at the roadside, under stress, probably in daylight.
/// It carries nothing but facts: who this is, what a medic needs to know, who
/// to ring.
///
/// It renders **only** while [iceAccessProvider] hands out a token. That check
/// lives here rather than at the call site so that placing the widget on a
/// screen can never, by itself, expose anything (FR-023 / SG-08). If the
/// incident resolves while the card is on screen, the next build tears it
/// down.
class IceCard extends ConsumerWidget {
  const IceCard({super.key, required this.data});

  final IceCardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(iceAccessProvider);
    if (access == null) return const SizedBox.shrink();
    return IceCardBody(data: data, access: access);
  }
}

/// The rendered card. Constructing it requires an [IceAccess] token, and
/// [IceAccess.resolve] is the only mint.
class IceCardBody extends StatelessWidget {
  const IceCardBody({super.key, required this.data, required this.access});

  final IceCardData data;
  final IceAccess access;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final isIncident = access.reason == IceExposureReason.activeIncident;
    final bandColor = isIncident ? s.emergency : s.hazardBand;
    final onBand = isIncident ? s.onEmergency : s.onHazard;

    return MediaQuery(
      // A card that reflows off-screen at 200% text scale is worse than one
      // that is merely large.
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: AppType.clampScale(context)),
      child: Container(
        decoration: BoxDecoration(
          color: s.surface1,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: s.border,
            width: AppStroke.resolve(AppStroke.regular, sunlight: s.isSunlight),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _band(context, bandColor, onBand),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data.ownerName != null && data.ownerName!.isNotEmpty)
                    Text(
                      data.ownerName!,
                      style: AppType.displayStyle(
                        AppType.titleMd,
                      ).copyWith(color: s.textPrimary),
                    ),
                  const SizedBox(height: AppSpace.lg),
                  _bloodGroup(context, s),
                  if (data.medicalNotes != null &&
                      data.medicalNotes!.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.lg),
                    _label(context.l10n.settingsMedicalNotes, s),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      data.medicalNotes!,
                      style: AppType.bodyStyle(
                        AppType.bodyLg,
                      ).copyWith(color: s.textPrimary),
                    ),
                  ],
                  const SizedBox(height: AppSpace.xl),
                  _label(context.l10n.iceLabelCallThese, s),
                  const SizedBox(height: AppSpace.sm),
                  ...data.callableContacts.map((c) => _contactRow(c, s)),
                  if (data.callableContacts.isEmpty)
                    Text(
                      context.l10n.iceNoContacts,
                      style: AppType.bodyStyle(
                        AppType.bodyMd,
                      ).copyWith(color: s.textMuted),
                    ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    context.l10n.iceDisclaimer,
                    style: AppType.bodyStyle(
                      AppType.bodySm,
                    ).copyWith(color: s.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _band(BuildContext context, Color background, Color foreground) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.iceBandHeading,
            style: AppType.eyebrow(AppType.labelMd).copyWith(color: foreground),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            access.reason.displayName,
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: foreground),
          ),
        ],
      ),
    );
  }

  Widget _bloodGroup(BuildContext context, AppSemantics s) {
    final group = data.bloodGroup;
    final missing = group == null || group.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context.l10n.settingsBloodGroup, s),
        const SizedBox(height: AppSpace.sm),
        Text(
          missing ? context.l10n.iceBloodGroupMissing : group,
          style: AppType.readout(
            AppType.displaySm,
          ).copyWith(color: missing ? s.textMuted : s.textPrimary),
        ),
      ],
    );
  }

  Widget _contactRow(EmergencyContact contact, AppSemantics s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority is an ordering, not a severity: a neutral surface chip,
          // never a hazard tier.
          Container(
            width: AppSpace.xxl,
            height: AppSpace.xxl,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.surface2,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: s.hairline),
            ),
            child: Text(
              '${contact.priority}',
              style: AppType.figure(
                AppType.bodyMd,
              ).copyWith(color: s.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: AppType.bodyStyle(
                    AppType.bodyLg,
                    weight: FontWeight.w600,
                  ).copyWith(color: s.textPrimary),
                ),
                if (contact.relationship != null &&
                    contact.relationship!.isNotEmpty)
                  Text(
                    contact.relationship!,
                    style: AppType.bodyStyle(
                      AppType.bodySm,
                    ).copyWith(color: s.textSecondary),
                  ),
                Text(
                  contact.phone,
                  style: AppType.figure(
                    AppType.bodyLg,
                  ).copyWith(color: s.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, AppSemantics s) => Text(
    text.toUpperCase(),
    style: AppType.eyebrow(AppType.labelSm).copyWith(color: s.textSecondary),
  );
}
