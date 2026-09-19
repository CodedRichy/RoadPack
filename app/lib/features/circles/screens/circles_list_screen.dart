import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../models/circle_member.dart';
import '../providers/circles_provider.dart';
import '../widgets/circle_card.dart';

class CirclesListScreen extends ConsumerWidget {
  const CirclesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circlesAsync = ref.watch(circlesProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSafetyCircles),
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: l10n.circlesJoinCircleTitle,
            onPressed: () => context.go('/circles/join'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/circles/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.circlesCreateCircle),
      ),
      body: circlesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.circlesLoadError),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.read(circlesProvider.notifier).refresh(),
                child: Text(l10n.circlesRetry),
              ),
            ],
          ),
        ),
        data: (circles) {
          if (circles.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(circlesProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: circles.length,
              itemBuilder: (context, index) {
                final circle = circles[index];
                return CircleCard(
                  circle: circle,
                  memberCount: circle.maxMembers ?? 0,
                  userRole: CircleRole.member,
                  onTap: () => context.go('/circles/${circle.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.circlesEmptyTitle,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.circlesEmptyBody,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/circles/new'),
              icon: const Icon(Icons.add),
              label: Text(l10n.circlesCreateCircle),
            ),
          ],
        ),
      ),
    );
  }
}
