import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/l10n.dart';
import '../models/offline_region.dart';
import '../providers/offline_cache_provider.dart';

/// Cache-management UI for FR-052: what is stored, how big it is, clear it.
///
/// It also states, in the product surface and not just in a code comment, that
/// the base map still needs a connection. Shipping a "Downloaded" badge over a
/// map that will be blank at the roadside is precisely the class of lie this
/// product exists to avoid.
class OfflineCachePanel extends StatelessWidget {
  const OfflineCachePanel({
    super.key,
    required this.stats,
    required this.isDurable,
    required this.onClearAll,
  });

  final TileCacheStats stats;
  final bool isDurable;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;

    return Container(
      padding: AppSpace.card,
      decoration: BoxDecoration(
        color: s.surface1,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: s.hairline,
          width: AppStroke.resolve(AppStroke.hairline, sunlight: s.isSunlight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.mapStoredOnPhoneEyebrow,
            style: AppType.eyebrow(
              AppType.labelSm,
            ).copyWith(color: s.textMuted),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                stats.formattedSize,
                style: AppType.figure(
                  AppType.titleMd,
                ).copyWith(color: s.textPrimary),
              ),
              const SizedBox(width: AppSpace.md),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l10n.mapTileCount(stats.tileCount),
                  style: AppType.figure(
                    AppType.bodySm,
                  ).copyWith(color: s.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          // The honesty clause: offline areas are planned and measured, but
          // the base map still needs a connection.
          _Notice(text: l10n.mapOfflineLimitationNotice),
          if (!isDurable) ...[
            const SizedBox(height: AppSpace.sm),
            _Notice(text: l10n.mapCacheInMemoryOnlyNotice),
          ],
          const SizedBox(height: AppSpace.lg),
          SizedBox(
            height: AppSpace.gloveTarget,
            child: OutlinedButton.icon(
              onPressed: stats.isEmpty ? null : onClearAll,
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.mapClearCachedDataButton),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: AppRadius.smAll,
        border: Border(
          left: BorderSide(
            color: s.attentionAccent,
            width: AppStroke.resolve(AppStroke.emphatic, sunlight: s.isSunlight),
          ),
        ),
      ),
      child: Text(
        text,
        style: AppType.bodyStyle(
          AppType.labelMd,
        ).copyWith(color: s.textSecondary),
      ),
    );
  }
}

/// One learned route and the tile coverage its 5 km buffer would need.
class OfflineRegionTile extends StatelessWidget {
  const OfflineRegionTile({super.key, required this.view});

  final OfflineRegionPlanView view;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final plan = view.plan;
    final estimatedSize = TileCacheStats.formatBytes(
      plan.coverage.estimatedBytes,
    );
    final bufferKm = (plan.coverage.bufferMeters / 1000).round();
    final coverageLine = view.isApproximateCorridor
        ? l10n.mapRegionCoverageLineCorridor(
            plan.plannedTiles,
            plan.coverage.zoomLevels.length,
            estimatedSize,
            bufferKm,
          )
        : l10n.mapRegionCoverageLine(
            plan.plannedTiles,
            plan.coverage.zoomLevels.length,
            estimatedSize,
            bufferKm,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyStyle(
                    AppType.bodyMd,
                  ).copyWith(color: s.textPrimary),
                ),
              ),
              Text(
                plan.status.label(l10n),
                style: AppType.figure(
                  AppType.labelMd,
                ).copyWith(color: s.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            coverageLine,
            style: AppType.bodyStyle(
              AppType.labelMd,
            ).copyWith(color: s.textMuted),
          ),
        ],
      ),
    );
  }
}
