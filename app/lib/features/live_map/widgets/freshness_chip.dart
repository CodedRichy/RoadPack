import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/l10n.dart';
import '../models/member_presence.dart';

/// The state badge for one member.
///
/// The filled dot is the live affordance and it is drawn only while the device
/// is actually reporting. A stale member gets a hollow ring instead, in the
/// muted neutral: the badge should read as "we lost them" at a glance, without
/// relying on colour (roughly 8% of Indian men have red-green CVD), which is
/// why the fill/ring difference carries the meaning as well as the lightness.
class FreshnessChip extends StatelessWidget {
  const FreshnessChip({super.key, required this.presence});

  final MemberPresence presence;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final live = presence.isLive;
    final accent = live ? s.watchAccent : s.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: AppRadius.pillAll,
        border: Border.all(
          color: accent,
          width: AppStroke.resolve(AppStroke.hairline, sunlight: s.isSunlight),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: accent, filled: live),
          const SizedBox(width: AppSpace.sm),
          Text(
            presence.headline(context.l10n),
            style: AppType.figure(AppType.labelMd).copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? color : Colors.transparent,
      border: filled ? null : Border.all(color: color, width: 1.5),
    ),
  );
}
