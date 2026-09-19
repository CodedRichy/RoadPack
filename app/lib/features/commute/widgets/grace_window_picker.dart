import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/grace_window.dart';

/// Picks how late is late (FR-042).
///
/// Three segments, not a slider — see [GraceWindow]. The selected segment
/// carries the attention tier because this setting is the one that decides
/// when the app starts worrying, and it should look like the thing it is.
class GraceWindowPicker extends StatelessWidget {
  const GraceWindowPicker({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final GraceWindow value;
  final ValueChanged<GraceWindow> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Row(
        children: [
          for (final window in GraceWindow.values) ...[
            Expanded(
              child: _Segment(
                window: window,
                selected: window == value,
                onTap: enabled ? () => onChanged(window) : null,
              ),
            ),
            if (window != GraceWindow.values.last)
              const SizedBox(width: AppSpace.sm),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.window,
    required this.selected,
    required this.onTap,
  });

  final GraceWindow window;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;

    return Semantics(
      button: true,
      selected: selected,
      label: l10n.commuteGraceWindowSemantics(
        l10n.commuteSpokenMinutes(window.minutes),
      ),
      excludeSemantics: true,
      child: Material(
        color: selected ? s.attentionAccent : s.surface2,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: Container(
            height: AppSpace.tapTarget,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              border: selected
                  ? null
                  : Border.all(
                      color: s.hairline,
                      width: AppStroke.resolve(
                        AppStroke.hairline,
                        sunlight: s.isSunlight,
                      ),
                    ),
            ),
            child: Text(
              l10n.minutesShort(window.minutes),
              style: AppType.figure(
                AppType.bodySm,
              ).copyWith(color: selected ? s.canvas : s.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
