import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../providers/pack_actions_provider.dart';

/// Join a ride from a share link.
///
/// The field accepts a whole URL as readily as a bare token, because what a
/// rider actually has is a link somebody pasted into a group chat, and asking
/// them to extract the last path segment at a petrol pump is asking them not
/// to join.
///
/// Joining is the moment consent is given, so the screen states plainly what
/// starts happening — before the tap, not after it.
class JoinPackRideScreen extends ConsumerStatefulWidget {
  const JoinPackRideScreen({super.key, this.initialToken, this.onJoined});

  /// Pre-filled when the app was opened from a share link.
  final String? initialToken;

  final void Function(BuildContext context, String rideId)? onJoined;

  @override
  ConsumerState<JoinPackRideScreen> createState() => _JoinPackRideScreenState();
}

class _JoinPackRideScreenState extends ConsumerState<JoinPackRideScreen> {
  late final TextEditingController _token = TextEditingController(
    text: widget.initialToken ?? '',
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final token = extractShareToken(_token.text);
    if (token.isEmpty) {
      setState(() => _error = context.l10n.packPasteLinkError);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final member = await ref.read(packActionsProvider).joinRide(token);
      if (mounted) widget.onJoined?.call(context, member.rideId);
    } catch (e) {
      // The RPC distinguishes ended, revoked, expired and invalid. Which one
      // it was is exactly what the rider needs, so it is shown verbatim.
      if (mounted) {
        setState(
          () => _error = e is TrackingNotPermitted
              ? e.message(context.l10n)
              : e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: s.canvas,
      appBar: AppBar(title: Text(l10n.packJoinRide)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.gutter),
        children: [
          TextField(
            key: const Key('pack-join-token'),
            controller: _token,
            autocorrect: false,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _join(),
            style: AppType.figure(AppType.bodyMd),
            decoration: InputDecoration(
              labelText: l10n.packShareLinkLabel,
              hintText: 'https://roadpack.app/p/...',
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            l10n.packJoinNotice,
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textSecondary),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.lg),
            Text(
              _error!,
              key: const Key('pack-join-error'),
              style: AppType.bodyStyle(
                AppType.bodySm,
              ).copyWith(color: s.attentionAccent),
            ),
          ],
          const SizedBox(height: AppSpace.xl),
          FilledButton(
            key: const Key('pack-join-submit'),
            onPressed: _busy ? null : _join,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, AppSpace.gloveTarget),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.packJoinSubmit),
          ),
        ],
      ),
    );
  }
}

/// Pull the token out of whatever was pasted.
///
/// Share tokens are base64url of 16 random bytes, so they never contain `/`,
/// `?` or `#` — the last path segment is unambiguous.
String extractShareToken(String input) {
  var value = input.trim();
  if (value.isEmpty) return value;
  value = value.split('?').first.split('#').first;
  if (value.endsWith('/')) value = value.substring(0, value.length - 1);
  final segments = value.split('/');
  return segments.isEmpty ? value : segments.last;
}
