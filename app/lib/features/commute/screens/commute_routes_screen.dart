import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/commute_route.dart';
import '../providers/commute_routes_provider.dart';
import '../providers/non_arrival_config_provider.dart';
import '../widgets/commute_route_card.dart';
import '../widgets/grace_window_picker.dart';
import 'route_editor_screen.dart';

/// The commute screen: what the app has learned, and what it will do about it
/// (FR-040, FR-041, FR-042).
///
/// The settings sit at the top rather than behind a gear icon, because the
/// grace window is the single number that decides how long the app waits
/// before worrying, and a rider should never have to go looking for it.
class CommuteRoutesScreen extends ConsumerWidget {
  const CommuteRoutesScreen({super.key});

  static const String routePath = '/commute';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.semantics;
    final l10n = context.l10n;
    final routesAsync = ref.watch(commuteRoutesProvider);

    return Scaffold(
      backgroundColor: s.canvas,
      appBar: AppBar(
        title: Text(
          l10n.commuteTitle,
          style: AppType.displayStyle(AppType.titleSm),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.commuteAddRoute),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(commuteRoutesProvider.notifier).refresh(),
        child: routesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              _Message(title: l10n.commuteLoadError, detail: '$err'),
          data: (routes) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.lg,
              AppSpace.gutter,
              AppSpace.huge + AppSpace.xxl,
            ),
            children: [
              const _NonArrivalSettings(),
              const SizedBox(height: AppSpace.xl),
              if (routes.isEmpty)
                const _EmptyState()
              else ...[
                Text(
                  l10n.commuteYourRoutesHeading,
                  style: AppType.eyebrow(
                    AppType.labelMd,
                  ).copyWith(color: s.textMuted),
                ),
                const SizedBox(height: AppSpace.md),
                for (final route in routes)
                  CommuteRouteCard(
                    route: route,
                    onTap: () => _openEditor(context, route: route),
                    onToggleNonArrival: (enabled) => ref
                        .read(commuteRoutesProvider.notifier)
                        .setNonArrivalEnabled(route.id, enabled),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, {CommuteRoute? route}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RouteEditorScreen(route: route)),
    );
  }
}

class _NonArrivalSettings extends ConsumerWidget {
  const _NonArrivalSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.semantics;
    final l10n = context.l10n;
    final config = ref.watch(nonArrivalConfigProvider);
    final controller = ref.read(nonArrivalConfigControllerProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.commuteNonArrivalTitle,
                  style: AppType.displayStyle(AppType.titleSm),
                ),
              ),
              Switch(
                value: config.enabled,
                onChanged: (value) => controller.setEnabled(value),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            config.enabled
                ? l10n.commuteNonArrivalEnabledBody(
                    l10n.commuteGraceWindowSemantics(
                      l10n.commuteSpokenMinutes(config.window.minutes),
                    ),
                  )
                : l10n.commuteNonArrivalDisabledBody,
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            l10n.commuteAskMeAfterHeading,
            style: AppType.eyebrow(
              AppType.labelSm,
            ).copyWith(color: s.textMuted),
          ),
          const SizedBox(height: AppSpace.sm),
          GraceWindowPicker(
            value: config.window,
            enabled: config.enabled,
            onChanged: (window) => controller.setWindow(window),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.commuteEmptyTitle,
          style: AppType.displayStyle(AppType.titleSm),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          l10n.commuteEmptyBody(CommuteRoute.learningThreshold),
          style: AppType.bodyStyle(
            AppType.bodyMd,
          ).copyWith(color: s.textSecondary),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;

    return ListView(
      padding: const EdgeInsets.all(AppSpace.gutter),
      children: [
        Text(title, style: AppType.displayStyle(AppType.titleSm)),
        const SizedBox(height: AppSpace.sm),
        Text(
          detail,
          style: AppType.bodyStyle(AppType.bodySm).copyWith(color: s.textMuted),
        ),
      ],
    );
  }
}
