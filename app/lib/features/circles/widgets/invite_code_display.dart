import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InviteCodeDisplay extends StatelessWidget {
  const InviteCodeDisplay({super.key, required this.code, this.onShare});

  final String code;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Invite Code', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SelectableText(
              code.toUpperCase(),
              style: theme.textTheme.headlineMedium?.copyWith(
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
                if (onShare != null) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
