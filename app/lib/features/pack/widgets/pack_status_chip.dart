import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/pack_status.dart';

/// The label a rider reads for a status, in their language.
///
/// Kept separate from [PackStatus.label] (the English identifier baked into
/// the model, mirrored from the backend enum) so a locale change never
/// touches the wire value. `unreachable` and `stopped` are deliberately
/// distinct words in every language — see [PackStatusChip]'s doc comment for
/// why that separation is load-bearing.
String packStatusLabel(PackStatus status, AppLocalizations l10n) =>
    switch (status) {
      PackStatus.riding => l10n.packStatusRiding,
      PackStatus.refueling => l10n.packStatusRefueling,
      PackStatus.takingBreak => l10n.packStatusTakingBreak,
      PackStatus.wrongTurn => l10n.packStatusWrongTurn,
      PackStatus.waiting => l10n.packStatusWaiting,
      PackStatus.stopped => l10n.packStatusStopped,
      PackStatus.done => l10n.packStatusDone,
      PackStatus.unexplainedStop => l10n.packStatusUnexplainedStop,
      PackStatus.unreachable => l10n.packStatusUnreachable,
      PackStatus.possibleIncident => l10n.packStatusPossibleIncident,
    };

/// How one status is drawn.
///
/// Pulled out of the widget so the rules below can be asserted directly rather
/// than inferred from pixels — "unreachable and stopped look different" is a
/// correctness property, not a style preference, and it deserves a test that
/// cannot pass by accident.
@immutable
class PackStatusVisual {
  const PackStatusVisual({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.fill,
    required this.outline,
    required this.isAutomatic,
  });

  final String label;
  final IconData icon;
  final Color foreground;

  /// Transparent means outline-only. Fill versus outline is the treatment
  /// difference that survives greyscale and a gloved glance.
  final Color fill;
  final Color outline;
  final bool isAutomatic;

  bool get isFilled => fill.a > 0;
}

/// A member's status, drawn.
///
/// Three separations are load-bearing here:
///
/// 1. **`unreachable` vs `stopped`.** A rider in a dead zone and a rider who
///    parked are different problems with different responses — go back and
///    look, versus wait. They differ by icon, by fill, and by colour tier, so
///    no single channel failing (glare, colour-vision deficiency, a thumb over
///    half the screen) collapses them together.
/// 2. **Automatic vs manual (PM-43).** An automatic status is the app's guess;
///    a manual one is a rider's word. The AUTO tag and the accent tier mark
///    which is which, because a rider deciding whether to turn around needs to
///    know whether a human said "I'm fine" or a sensor inferred it.
/// 3. **`possible_incident` alone gets the emergency tier.** If red appears
///    for a fuel stop, it stops meaning anything when it matters.
class PackStatusChip extends StatelessWidget {
  const PackStatusChip({
    required this.status,
    required this.isAutomatic,
    super.key,
    this.note,
  });

  final PackStatus status;
  final bool isAutomatic;
  final String? note;

  static Key keyFor(PackStatus status) => Key('pack-status-${status.wire}');

  static PackStatusVisual visualFor(
    PackStatus status,
    bool isAutomatic,
    AppSemantics s,
  ) {
    switch (status) {
      case PackStatus.possibleIncident:
        return PackStatusVisual(
          label: status.label,
          icon: Icons.crisis_alert,
          foreground: s.onEmergency,
          fill: s.emergency,
          outline: s.emergency,
          isAutomatic: true,
        );
      case PackStatus.unreachable:
        // Outline only, cell-signal icon. Nothing is being claimed about this
        // rider except that the phone went quiet.
        return PackStatusVisual(
          label: status.label,
          icon: Icons.signal_cellular_off,
          foreground: s.attentionAccent,
          fill: Colors.transparent,
          outline: s.attentionAccent,
          isAutomatic: true,
        );
      case PackStatus.unexplainedStop:
        // Solid attention field. Something is wrong and nobody has said what.
        return PackStatusVisual(
          label: status.label,
          icon: Icons.priority_high,
          foreground: s.onHazard,
          fill: s.attentionAccent,
          outline: s.attentionAccent,
          isAutomatic: true,
        );
      case PackStatus.stopped:
        // Neutral, filled, pause icon. A rider chose this; it is information,
        // not a warning.
        return PackStatusVisual(
          label: status.label,
          icon: Icons.pause_rounded,
          foreground: s.textSecondary,
          fill: s.surface2,
          outline: s.hairline,
          isAutomatic: false,
        );
      case PackStatus.riding:
        return PackStatusVisual(
          label: status.label,
          icon: Icons.two_wheeler,
          foreground: s.textSecondary,
          fill: s.surface2,
          outline: s.hairline,
          isAutomatic: isAutomatic,
        );
      case PackStatus.refueling:
        return _manual(s, status, Icons.local_gas_station, isAutomatic);
      case PackStatus.takingBreak:
        return _manual(s, status, Icons.local_cafe, isAutomatic);
      case PackStatus.wrongTurn:
        return _manual(s, status, Icons.u_turn_left, isAutomatic);
      case PackStatus.waiting:
        return _manual(s, status, Icons.hourglass_bottom, isAutomatic);
      case PackStatus.done:
        return PackStatusVisual(
          label: status.label,
          icon: Icons.flag,
          foreground: s.protectedAccent,
          fill: s.surface2,
          outline: s.hairline,
          isAutomatic: isAutomatic,
        );
    }
  }

  static PackStatusVisual _manual(
    AppSemantics s,
    PackStatus status,
    IconData icon,
    bool isAutomatic,
  ) => PackStatusVisual(
    label: status.label,
    icon: icon,
    foreground: s.textSecondary,
    fill: s.surface2,
    outline: s.hairline,
    isAutomatic: isAutomatic,
  );

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final v = visualFor(status, isAutomatic, s);
    final auto = v.isAutomatic || isAutomatic;
    final label = packStatusLabel(status, l10n);

    return Container(
      key: keyFor(status),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: v.fill,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: v.outline,
          width: AppStroke.resolve(
            v.isFilled ? AppStroke.hairline : AppStroke.heavy,
            sunlight: s.isSunlight,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(v.icon, size: 14, color: v.foreground),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Text(
              note == null || note!.isEmpty ? label : '$label — $note',
              overflow: TextOverflow.ellipsis,
              style: AppType.bodyStyle(
                AppType.labelMd,
                weight: FontWeight.w600,
              ).copyWith(color: v.foreground),
            ),
          ),
          if (auto) ...[
            const SizedBox(width: AppSpace.xs),
            Text(
              l10n.packAutoTag,
              key: const Key('pack-status-auto-tag'),
              style: AppType.eyebrow(
                AppType.labelSm,
              ).copyWith(color: v.foreground),
            ),
          ],
        ],
      ),
    );
  }
}
