import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/auth_state.dart';
import '../providers/clerk_auth_provider.dart';
import '../widgets/phone_input.dart';
import '../widgets/social_sign_in_button.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _useEmail = false;
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(clerkAuthProvider, (prev, next) {
      final status = next.valueOrNull?.status;
      if (status == AuthStatus.codeSent) {
        context.go('/verify');
      }
      // Authenticated users are handled by the router's redirect logic.
    });

    final authState =
        ref.watch(clerkAuthProvider).valueOrNull ?? const AuthState();
    final isLoading = authState.status == AuthStatus.identifierEntered;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 64),
              Text(
                'Welcome to RoadPack',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to stay safe on the road',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),
              if (_useEmail)
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _submitEmail(),
                  decoration: InputDecoration(
                    hintText: 'Email address',
                    errorText: authState.errorMessage,
                    border: const OutlineInputBorder(),
                    suffixIcon: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: _submitEmail,
                          ),
                  ),
                )
              else
                PhoneInput(
                  onSubmit: _submitPhone,
                  errorText: authState.errorMessage,
                ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _useEmail = !_useEmail),
                  child: Text(
                    _useEmail ? 'Use phone instead' : 'Use email instead',
                  ),
                ),
              ),
              const Spacer(),
              const Divider(),
              const SizedBox(height: 16),
              SocialSignInButton(
                onPressed: () =>
                    ref.read(clerkAuthProvider.notifier).signInWithGoogle(),
                isLoading: isLoading,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _submitPhone(String phone) {
    ref.read(clerkAuthProvider.notifier).startPhoneSignIn(phone);
  }

  void _submitEmail() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      ref.read(clerkAuthProvider.notifier).startEmailSignIn(email);
    }
  }
}
