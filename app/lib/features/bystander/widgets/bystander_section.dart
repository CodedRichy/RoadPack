import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// A bordered block. No elevation anywhere on this screen -- under glare a
/// shadow is invisible and a border is not.
class BystanderSection extends StatelessWidget {
  const BystanderSection({
    super.key,
    required this.child,
    this.heading,
    this.background,
    this.borderColour,
    this.foreground,
  });

  final Widget child;
  final String? heading;
  final Color? background;
  final Color? borderColour;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final fg = foreground ?? s.textPrimary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: background ?? s.surface1,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: borderColour ?? s.hairline,
          width: AppStroke.resolve(AppStroke.regular, sunlight: s.isSunlight),
        ),
      ),
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heading != null) ...[
            Text(
              heading!,
              style: AppType.eyebrow(
                AppType.labelMd,
              ).copyWith(color: fg.withValues(alpha: 0.82)),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          child,
        ],
      ),
    );
  }
}
