import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/l10n.dart';
import '../providers/offline_cache_provider.dart';
import '../widgets/offline_cache_panel.dart';

/// FR-052 cache management: what a known route would need offline, how much is
/// actually stored, and a way to clear it.
class OfflineMapsScreen extends ConsumerWidget {
  const OfflineMapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.semantics;
    final l10n = context.l10n;
    final stats = ref.watch(tileCacheStatsProvider);
    final plans = ref.watch(offlineRegionPlansProvider);
    final cache = ref.watch(offlineTileCacheProvider);

    return Scaffold(
      backgroundColor: s.canvas,
      appBar: AppBar(title: Text(l10n.settingsOfflineMaps)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.gutter,
          vertical: AppSpace.lg,
        ),
        children: [
          stats.when(
            data: (data) => OfflineCachePanel(
              stats: data,
              isDurable: cache.isDurable,
              onClearAll: () async {
                await cache.clear();
                ref.invalidate(tileCacheStatsProvider);
                ref.invalidate(offlineRegionPlansProvider);
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              l10n.mapCacheReadError(e.toString()),
              style: AppType.bodyStyle(
                AppType.bodySm,
              ).copyWith(color: s.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text(
            l10n.mapYourRoutesEyebrow,
            style: AppType.eyebrow(AppType.labelSm).copyWith(color: s.textMuted),
          ),
          const SizedBox(height: AppSpace.sm),
          plans.when(
            data: (views) => views.isEmpty
                ? Text(
                    l10n.mapNoRoutesLearned,
                    style: AppType.bodyStyle(
                      AppType.bodySm,
                    ).copyWith(color: s.textSecondary),
                  )
                : Column(
                    children: [
                      for (final view in views) OfflineRegionTile(view: view),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              l10n.mapRoutesReadError(e.toString()),
              style: AppType.bodyStyle(
                AppType.bodySm,
              ).copyWith(color: s.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
