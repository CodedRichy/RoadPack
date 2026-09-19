import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// How loudly an action shouts. There is exactly one [primary] on the screen.
enum BystanderActionEmphasis { primary, secondary }

/// A bystander action.
///
/// Sized well past the glove target because the reader may be shaking, and
/// bordered rather than shadowed so it survives the sunlight path.
class BystanderActionButton extends StatelessWidget {
  const BystanderActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.sublabel,
    this.footnote,
    this.onPressed,
    this.emphasis = BystanderActionEmphasis.secondary,
  });

  final String label;
  final String? sublabel;

  /// Small qualifying line -- provenance, staleness, "unverified".
  final String? footnote;

  final IconData icon;
  final VoidCallback? onPressed;
  final BystanderActionEmphasis emphasis;

  static const double minHeight = AppSpace.gloveTarget + AppSpace.lg;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final isPrimary = emphasis == BystanderActionEmphasis.primary;
    final enabled = onPressed != null;

    final background = isPrimary
        ? s.emergency
        : (enabled ? s.surface1 : s.canvas);
    final foreground = isPrimary
        ? s.onEmergency
        : (enabled ? s.textPrimary : s.textMuted);
    final borderColour = isPrimary ? s.emergencyDeep : s.border;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: Material(
        color: background,
        borderRadius: AppRadius.lgAll,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.lgAll,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: borderColour,
                width: AppStroke.resolve(
                  isPrimary ? AppStroke.regular : AppStroke.heavy,
                  sunlight: s.isSunlight,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.lg,
            ),
            child: Row(
              children: [
                Icon(icon, size: 32, color: foreground),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppType.displayStyle(
                          isPrimary ? AppType.titleMd : AppType.titleSm,
                          weight: FontWeight.w700,
                        ).copyWith(color: foreground),
                      ),
                      if (sublabel != null) ...[
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          sublabel!,
                          style: AppType.bodyStyle(
                            AppType.bodySm,
                          ).copyWith(color: foreground.withValues(alpha: 0.86)),
                        ),
                      ],
                      if (footnote != null) ...[
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          footnote!,
                          style: AppType.eyebrow(AppType.labelSm).copyWith(
                            color: isPrimary
                                ? foreground.withValues(alpha: 0.86)
                                : s.attentionAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
