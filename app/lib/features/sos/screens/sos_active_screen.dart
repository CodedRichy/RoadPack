import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sos_state.dart';
import '../providers/sos_state_provider.dart';

class SosActiveScreen extends ConsumerWidget {
  const SosActiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sosStateProvider);
    final isResolved = state.status == SosStatus.resolved;

    return Material(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isResolved ? Icons.check_circle : Icons.warning_amber,
                color: isResolved ? Colors.green : Colors.orange,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                isResolved ? 'Incident Resolved' : 'Emergency Alerts Sent',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isResolved
                    ? 'Your contacts have been notified that you are safe.'
                    : 'Your emergency contacts are being notified.',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (state.activeIncident != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Incident: ${state.activeIncident!.id.substring(0, 8)}...',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
              const SizedBox(height: 48),
              if (!isResolved)
                SizedBox(
                  width: 200,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      ref.read(sosStateProvider.notifier).resolve();
                    },
                    child: const Text("I'M OKAY"),
                  ),
                ),
              if (isResolved)
                SizedBox(
                  width: 200,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      ref.read(sosStateProvider.notifier).reset();
                    },
                    child: const Text('CLOSE'),
                  ),
                ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
