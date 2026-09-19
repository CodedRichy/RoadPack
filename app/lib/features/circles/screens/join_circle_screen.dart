import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
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
  int? _memberCount;
  String? _errorText;
  bool _isLoading = false;
  bool _isJoining = false;

  Future<void> _onCodeCompleted(String code) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
      _preview = null;
      _memberCount = null;
    });

    try {
      final actions = ref.read(circleActionsProvider);
      final circle = await actions.lookupInviteCode(code);
      if (circle == null) {
        setState(() => _errorText = context.l10n.circlesInvalidCodeError);
      } else {
        final count = await actions.memberCount(circle.id);
        setState(() {
          _preview = circle;
          _memberCount = count;
        });
      }
    } catch (e) {
      setState(() => _errorText = context.l10n.circlesLoadError);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.circlesJoinCircleTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.circlesEnterCodeHeading,
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
                      Text(_preview!.name, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        _preview!.type.displayName(l10n),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (_memberCount != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.circlesMemberCount(_memberCount!),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
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
                    : Text(l10n.circlesJoinAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
