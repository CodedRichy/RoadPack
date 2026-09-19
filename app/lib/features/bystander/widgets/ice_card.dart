import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../models/bystander_copy.dart';
import '../models/bystander_lang.dart';
import '../models/ice_profile.dart';
import 'bystander_section.dart';
import 'ice_qr_symbol.dart';

/// FR-094 / SG-08: medical facts, incident-gated.
///
/// The gate is upstream in the type system -- this widget takes an
/// [IceQrPayload], and the only way to build one is
/// [IceQrPayload.forSession] on an active incident. The widget cannot leak
/// what it cannot be handed.
///
/// The symbol is generated on device from the payload string. It never
/// fetches: a QR that needs a network is useless at the exact moment it is
/// needed. The facts are also printed as text underneath, because the
/// paramedic who arrives first may have no scanner at all.
class IceCard extends StatelessWidget {
  const IceCard({super.key, required this.payload, required this.lang});

  final IceQrPayload payload;
  final BystanderLang lang;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final ice = payload.profile;

    return BystanderSection(
      heading: BystanderCopy.iceHeading(lang),
      background: s.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: IceQrSymbol(payload: payload)),
          const SizedBox(height: AppSpace.lg),
          if (ice.bloodGroup != null && ice.bloodGroup!.isNotEmpty)
            _row(context, 'Blood group', ice.bloodGroup!, emphasise: true),
          if (ice.allergies.isNotEmpty)
            _row(context, 'Allergies', ice.allergies.join(', ')),
          if (ice.conditions.isNotEmpty)
            _row(context, 'Conditions', ice.conditions.join(', ')),
          if (ice.medications.isNotEmpty)
            _row(context, 'Medication', ice.medications.join(', ')),
          for (final c in ice.contacts)
            _row(context, c.relation ?? 'Contact', '${c.name} - ${c.phone}'),
          const SizedBox(height: AppSpace.sm),
          Text(
            BystanderCopy.iceGateNote(lang),
            style: AppType.bodyStyle(
              AppType.labelMd,
            ).copyWith(color: s.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool emphasise = false,
  }) {
    final s = context.semantics;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppType.eyebrow(
              AppType.labelSm,
            ).copyWith(color: s.textMuted),
          ),
          Text(
            value,
            style:
                (emphasise
                        ? AppType.figure(
                            AppType.titleSm,
                            weight: FontWeight.w700,
                          )
                        : AppType.bodyStyle(AppType.bodyMd))
                    .copyWith(color: s.textPrimary),
          ),
        ],
      ),
    );
  }
}
