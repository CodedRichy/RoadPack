import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_state.dart';
import '../providers/clerk_auth_provider.dart';
import '../widgets/otp_input.dart';

class VerifyScreen extends ConsumerWidget {
  const VerifyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(clerkAuthProvider).valueOrNull ?? const AuthState();
    final isVerifying = authState.status == AuthStatus.verifying;
    final identifier = authState.phone ?? authState.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Verify')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Enter verification code',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Code sent to $identifier',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (isVerifying)
                const Center(child: CircularProgressIndicator())
              else
                OtpInput(
                  onCompleted: (code) =>
                      ref.read(clerkAuthProvider.notifier).verifyCode(code),
                  errorText: authState.errorMessage,
                ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: isVerifying
                      ? null
                      : () {
                          if (authState.phone != null) {
                            ref
                                .read(clerkAuthProvider.notifier)
                                .startPhoneSignIn(authState.phone!);
                          } else if (authState.email != null) {
                            ref
                                .read(clerkAuthProvider.notifier)
                                .startEmailSignIn(authState.email!);
                          }
                        },
                  child: const Text('Resend code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
