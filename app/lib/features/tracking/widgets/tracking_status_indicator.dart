import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tracking_state.dart';
import '../services/tracking_service.dart';

class TrackingStatusIndicator extends ConsumerWidget {
  const TrackingStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(trackingServiceProvider);
    if (service == null) return const SizedBox.shrink();

    return StreamBuilder<TripState>(
      stream: service.tripStateStream,
      initialData: service.currentTripState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? TripState.idle;
        final (icon, label, color) = _stateDisplay(state, context);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  (IconData, String, Color) _stateDisplay(
    TripState state,
    BuildContext context,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return switch (state) {
      TripState.idle => (Icons.shield_outlined, 'Protected', scheme.primary),
      TripState.recording => (
          Icons.directions_car,
          'Trip Active',
          scheme.tertiary,
        ),
      TripState.completed => (
          Icons.check_circle_outline,
          'Trip Done',
          scheme.primary,
        ),
      TripState.discarded => (Icons.shield_outlined, 'Protected', scheme.primary),
    };
  }
}
