import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../models/sos_state.dart';
import '../providers/sos_state_provider.dart';
import '../screens/sos_active_screen.dart';
import '../screens/sos_countdown_screen.dart';
import 'sos_button.dart';

class SosOverlay extends ConsumerWidget {
  const SosOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(clerkAuthProvider).valueOrNull;
    final sosState = ref.watch(sosStateProvider);

    final isAuthenticated = authState?.isAuthenticated ?? false;

    return Stack(
      children: [
        child,
        if (isAuthenticated) ...[
          if (sosState.status == SosStatus.countdown ||
              sosState.status == SosStatus.dispatching)
            const SosCountdownScreen(),
          if (sosState.status == SosStatus.active ||
              sosState.status == SosStatus.resolved)
            const SosActiveScreen(),
          if (sosState.status == SosStatus.idle) const SosButton(),
        ],
      ],
    );
  }
}
