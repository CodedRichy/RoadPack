import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/commute_watch.dart';

/// The false-alarm escape hatch (FR-044).
///
/// Design constraints this control is built around, in order:
///
/// 1. **One tap.** The default press adds 30 minutes and returns immediately.
///    No sheet, no confirm, no picker. A rider does this at a traffic light
///    with one thumb; anything that needs two interactions gets abandoned, and
///    an abandoned dismissal becomes a call to somebody's mother.
/// 2. **[AppSpace.gloveTarget], not 48.** Pressed with gloves on.
/// 3. **Attention tier, never emergency.** Nobody has been alerted yet.
/// 4. **Says what it will do before it is pressed.** "+30 min" is on the face
///    of the button, so the rider is never guessing what they just bought.
///
/// The hour is offered as a separate, smaller control rather than as a choice
/// inside a dialog — two visible buttons cost one tap each, a dialog costs two
/// for both.
class RunningLateButton extends StatelessWidget {
  const RunningLateButton({
    required this.onSnooze,
    this.enabled = true,
    super.key,
  });

  /// Called with the chosen extension. Must not notify the circle.
  final ValueChanged<RunningLateSnooze> onSnooze;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SnoozeAction(
          key: const Key('running-late-30'),
          label: l10n.commuteRunningLateLabel,
          trailing: l10n.commuteSnoozeTrailing(
            RunningLateSnooze.thirty.minutes,
          ),
          prominent: true,
          enabled: enabled,
          onPressed: () => onSnooze(RunningLateSnooze.thirty),
        ),
        const SizedBox(height: AppSpace.sm),
        _SnoozeAction(
          key: const Key('running-late-60'),
          label: l10n.commuteMuchLaterLabel,
          trailing: l10n.commuteSnoozeTrailing(
            RunningLateSnooze.sixty.minutes,
          ),
          prominent: false,
          enabled: enabled,
          onPressed: () => onSnooze(RunningLateSnooze.sixty),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          l10n.commuteNobodyToldCaption,
          textAlign: TextAlign.center,
          style: AppType.bodyStyle(AppType.bodySm).copyWith(color: s.textMuted),
        ),
      ],
    );
  }
}

class _SnoozeAction extends StatelessWidget {
  const _SnoozeAction({
    required this.label,
    required this.trailing,
    required this.prominent,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final String label;
  final String trailing;
  final bool prominent;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final height = prominent ? AppSpace.gloveTarget : AppSpace.tapTarget;

    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.commuteSnoozeSemantics(label, trailing),
      excludeSemantics: true,
      child: Material(
        color: prominent ? s.attentionAccent : s.surface2,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: AppRadius.mdAll,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              border: prominent
                  ? null
                  : Border.all(
                      color: s.border,
                      width: AppStroke.resolve(
                        AppStroke.hairline,
                        sunlight: s.isSunlight,
                      ),
                    ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppType.bodyStyle(
                      prominent ? AppType.bodyMd : AppType.bodySm,
                      weight: FontWeight.w600,
                    ).copyWith(color: prominent ? s.canvas : s.textPrimary),
                  ),
                ),
                Text(
                  trailing,
                  style: AppType.figure(
                    prominent ? AppType.bodyMd : AppType.bodySm,
                  ).copyWith(color: prominent ? s.canvas : s.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
