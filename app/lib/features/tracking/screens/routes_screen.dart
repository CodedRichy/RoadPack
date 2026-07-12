import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/tracking_database.dart';
import '../providers/known_routes_provider.dart';

class RoutesScreen extends ConsumerWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(knownRoutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Known Routes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync from server',
            onPressed: () =>
                ref.read(knownRoutesProvider.notifier).syncFromServer(),
          ),
        ],
      ),
      body: routesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 8),
              Text('Failed to load routes: $err'),
            ],
          ),
        ),
        data: (routes) {
          if (routes.isEmpty) return _buildEmptyState(context);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: routes.length,
            itemBuilder: (context, index) =>
                _RouteCard(route: routes[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No routes learned yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'RoadPack automatically learns your commute patterns. '
              'After 3 similar trips, a route is created here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteCard extends ConsumerWidget {
  const _RouteCard({required this.route});
  final KnownRoutesLocalData route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final days = _parseDays(route.daysActive);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    route.name ?? 'Route ${route.id.substring(0, 6)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _ConfidenceBadge(confidence: route.confidence),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (route.typicalStart != null) ...[
                  Icon(Icons.schedule, size: 16, color: scheme.outline),
                  const SizedBox(width: 4),
                  Text(route.typicalStart!,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 16),
                ],
                if (route.typicalDurationMin != null) ...[
                  Icon(Icons.timer_outlined, size: 16, color: scheme.outline),
                  const SizedBox(width: 4),
                  Text('${route.typicalDurationMin} min',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 16),
                ],
                Icon(Icons.repeat, size: 16, color: scheme.outline),
                const SizedBox(width: 4),
                Text('${route.repetitionCount} trips',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (days.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: days.map((d) {
                  return Chip(
                    label: Text(d, style: const TextStyle(fontSize: 10)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  route.nonArrivalEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off_outlined,
                  size: 20,
                  color: route.nonArrivalEnabled
                      ? scheme.primary
                      : scheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Non-arrival alerts',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Switch(
                  value: route.nonArrivalEnabled,
                  onChanged: (value) {
                    ref
                        .read(knownRoutesProvider.notifier)
                        .toggleNonArrival(route.id, value);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _parseDays(String daysJson) {
    try {
      final days = (jsonDecode(daysJson) as List).cast<int>();
      const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days.map((d) => d >= 1 && d <= 7 ? names[d] : '?').toList();
    } catch (_) {
      return [];
    }
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    final color = confidence >= 0.7
        ? Colors.green
        : confidence >= 0.4
            ? Colors.orange
            : Theme.of(context).colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
