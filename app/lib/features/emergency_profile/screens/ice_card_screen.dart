import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../providers/ice_gate_provider.dart';
import '../widgets/ice_card.dart';

/// FR-023 / FR-094: the ICE card surface.
///
/// There is no "preview my card" path that bypasses the gate. Outside an
/// active incident or an opted-in active commute this screen shows an
/// explanation of *when* the card appears, and nothing about the rider. That
/// is the point: a screen the user can reach at any time must not be a way to
/// harvest their PII off an unlocked phone.
class IceCardScreen extends ConsumerWidget {
  const IceCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.semantics;
    final data = ref.watch(iceCardDataProvider);

    return Scaffold(
      backgroundColor: s.canvas,
      appBar: AppBar(title: Text(context.l10n.iceScreenTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.gutter),
          child: data == null
              ? _sealed(context)
              : IceCard(data: data),
        ),
      ),
    );
  }

  Widget _sealed(BuildContext context) {
    final s = context.semantics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: s.surface1,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: s.hairline,
              width: AppStroke.resolve(
                AppStroke.hairline,
                sunlight: s.isSunlight,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.iceSealedEyebrow,
                style: AppType.eyebrow(
                  AppType.labelMd,
                ).copyWith(color: s.textSecondary),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                context.l10n.iceSealedBody,
                style: AppType.bodyStyle(
                  AppType.bodyMd,
                ).copyWith(color: s.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
