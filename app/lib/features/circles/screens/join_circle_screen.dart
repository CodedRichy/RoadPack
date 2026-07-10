import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/circle.dart';
import '../providers/circle_actions_provider.dart';
import '../widgets/invite_code_input.dart';

class JoinCircleScreen extends ConsumerStatefulWidget {
  const JoinCircleScreen({super.key});

  @override
  ConsumerState<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends ConsumerState<JoinCircleScreen> {
  Circle? _preview;
  String? _errorText;
  bool _isLoading = false;
  bool _isJoining = false;

  Future<void> _onCodeCompleted(String code) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
      _preview = null;
    });

    try {
      final circle =
          await ref.read(circleActionsProvider).lookupInviteCode(code);
      if (circle == null) {
        setState(() => _errorText = 'Invalid code');
      } else {
        setState(() => _preview = circle);
      }
    } catch (e) {
      setState(() => _errorText = 'Something went wrong');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _join() async {
    final circle = _preview;
    if (circle == null) return;

    setState(() => _isJoining = true);
    try {
      await ref.read(circleActionsProvider).joinCircle(circle: circle);
      if (mounted) context.go('/circles/${circle.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Join Circle')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter invite code',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            InviteCodeInput(
              onCompleted: _onCodeCompleted,
              errorText: _errorText,
            ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_preview != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        _preview!.name,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _preview!.type.displayName,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isJoining ? null : _join,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isJoining
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Join'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
