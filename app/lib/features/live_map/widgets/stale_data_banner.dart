import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/l10n.dart';

/// Standing notice above the map when one or more members have gone quiet.
///
/// Uses the attention tier, never the emergency tier: silence is a gap in
/// information, not a declared incident. Escalating it to SOS red would train
/// riders to ignore SOS red.
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({
    super.key,
    required this.staleCount,
    required this.unreachableCount,
  });

  final int staleCount;
  final int unreachableCount;

  bool get _hasAnything => staleCount > 0 || unreachableCount > 0;

  @override
  Widget build(BuildContext context) {
    if (!_hasAnything) return const SizedBox.shrink();
    final s = context.semantics;
    final l10n = context.l10n;

    final String message;
    if (unreachableCount > 0 && staleCount > 0) {
      message = l10n.mapStaleBannerBoth(unreachableCount, staleCount);
    } else if (unreachableCount > 0) {
      message = l10n.mapStaleBannerNoSignalOnly(unreachableCount);
    } else {
      message = l10n.mapStaleBannerNotUpdatingOnly(staleCount);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: s.attentionAccent,
          width: AppStroke.resolve(AppStroke.regular, sunlight: s.isSunlight),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.timelapse, size: 18, color: s.attentionAccent),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              message,
              style: AppType.bodyStyle(
                AppType.labelMd,
              ).copyWith(color: s.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
