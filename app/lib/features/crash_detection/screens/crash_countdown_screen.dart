import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/crash_detection_provider.dart';
import '../widgets/crash_reason_picker.dart';

class CrashCountdownScreen extends ConsumerWidget {
  const CrashCountdownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(crashDetectionProvider);

    return Material(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'CRASH DETECTED',
              style: TextStyle(
                color: Colors.red,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Alerting your emergency contacts in '
              '${state.countdownRemaining} seconds',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Text(
              '${state.countdownRemaining}',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 120,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 240,
              height: 64,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  showModalBottomSheet<String>(
                    context: context,
                    isDismissible: false,
                    builder: (_) => const CrashReasonPicker(),
                  ).then((reason) {
                    if (reason != null) {
                      ref.read(crashDetectionProvider.notifier).cancel(reason);
                    }
                  });
                },
                child: const Text("I'M OKAY"),
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
    );
  }
}
