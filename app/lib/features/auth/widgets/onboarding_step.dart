import 'package:flutter/material.dart';

class OnboardingStep extends StatelessWidget {
  const OnboardingStep({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.onNext,
    this.nextLabel = 'Continue',
    this.showSkip = false,
    this.onSkip,
    this.isLoading = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onNext;
  final String nextLabel;
  final bool showSkip;
  final VoidCallback? onSkip;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: 32),
          Expanded(child: child),
          FilledButton(
            onPressed: isLoading ? null : onNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(nextLabel),
          ),
          if (showSkip) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: onSkip,
                child: const Text('Skip for now'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
