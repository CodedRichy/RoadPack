import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sos_state.dart';
import '../providers/sos_state_provider.dart';

class SosButton extends ConsumerStatefulWidget {
  const SosButton({super.key});

  @override
  ConsumerState<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends ConsumerState<SosButton> {
  Timer? _armTimer;

  void _onLongPressStart(LongPressStartDetails details) {
    HapticFeedback.heavyImpact();
    _armTimer = Timer(const Duration(seconds: 2), () {
      ref.read(sosStateProvider.notifier).arm();
      ref.read(sosStateProvider.notifier).startCountdown();
      HapticFeedback.vibrate();
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _armTimer?.cancel();
    _armTimer = null;
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sosStatus = ref.watch(sosStateProvider.select((s) => s.status));

    if (sosStatus != SosStatus.idle) return const SizedBox.shrink();

    return Positioned(
      bottom: 24,
      right: 24,
      child: GestureDetector(
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        child: FloatingActionButton.large(
          heroTag: 'sos_fab',
          backgroundColor: Colors.red,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Hold for 2 seconds to trigger SOS'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sos, color: Colors.white, size: 32),
              Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
