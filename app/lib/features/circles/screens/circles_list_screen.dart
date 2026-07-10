import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/circle_member.dart';
import '../providers/circles_provider.dart';
import '../widgets/circle_card.dart';

class CirclesListScreen extends ConsumerWidget {
  const CirclesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circlesAsync = ref.watch(circlesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Circles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'Join Circle',
            onPressed: () => context.go('/circles/join'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/circles/new'),
        icon: const Icon(Icons.add),
        label: const Text('Create Circle'),
      ),
      body: circlesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Something went wrong'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.read(circlesProvider.notifier).refresh(),
                child: const Text('Retry'),
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
              'Create your first Safety Circle',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your circles help ensure the right people are alerted when something happens on the road',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/circles/new'),
              icon: const Icon(Icons.add),
              label: const Text('Create Circle'),
            ),
          ],
        ),
      ),
    );
  }
}
