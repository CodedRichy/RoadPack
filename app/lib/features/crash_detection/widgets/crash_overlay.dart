import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../models/crash_state.dart';
import '../providers/crash_detection_provider.dart';
import '../screens/crash_countdown_screen.dart';

class CrashOverlay extends ConsumerWidget {
  const CrashOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(clerkAuthProvider).valueOrNull;
    final crashState = ref.watch(crashDetectionProvider);

    final isAuthenticated = authState?.isAuthenticated ?? false;

    return Stack(
      children: [
        child,
        if (isAuthenticated) ...[
          if (crashState.status == CrashDetectionStatus.countdown ||
              crashState.status == CrashDetectionStatus.dispatching)
            const CrashCountdownScreen(),
          if (crashState.status == CrashDetectionStatus.active ||
              crashState.status == CrashDetectionStatus.resolved)
            const _CrashActiveScreen(),
        ],
      ],
    );
  }
}

class _CrashActiveScreen extends ConsumerWidget {
  const _CrashActiveScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(crashDetectionProvider);
    final isResolved = state.status == CrashDetectionStatus.resolved;

    return Material(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isResolved ? Icons.check_circle : Icons.car_crash,
                color: isResolved ? Colors.green : Colors.orange,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                isResolved ? 'Incident Resolved' : 'CRASH ALERT SENT',
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
                    : 'Your emergency contacts have been notified of a possible crash.',
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
                      ref.read(crashDetectionProvider.notifier).resolve();
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
                      ref.read(crashDetectionProvider.notifier).reset();
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
