import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../models/circle_member.dart';
import '../providers/circle_actions_provider.dart';
import '../providers/circle_detail_provider.dart';
import '../widgets/invite_code_display.dart';
import '../widgets/member_tile.dart';

class CircleDetailScreen extends ConsumerWidget {
  const CircleDetailScreen({super.key, required this.circleId});

  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(circleDetailProvider(circleId));
    final currentUserId =
        ref.watch(clerkAuthProvider).valueOrNull?.userId;

    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Something went wrong'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(circleDetailProvider(circleId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (detail) {
        final circle = detail.circle;
        final isAdmin = detail.members
            .any((m) => m.userId == currentUserId && m.isAdmin);

        return Scaffold(
          appBar: AppBar(
            title: Text(circle.name),
            actions: [
              if (isAdmin)
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      _onAdminAction(context, ref, value, circle.id),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'regenerate',
                      child: Text('Regenerate invite code'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete circle'),
                    ),
                  ],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Chip(label: Text(circle.type.displayName)),
              const SizedBox(height: 12),
              if (circle.inviteCode != null)
                InviteCodeDisplay(
                  code: circle.inviteCode!,
                  onShare: () {
                    Share.share(
                      'Join my Safety Circle on RoadPack! '
                      'Code: ${circle.inviteCode!.toUpperCase()}',
                    );
                  },
                ),
              const SizedBox(height: 24),
              Text(
                'Members (${detail.members.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...detail.members.map((member) => MemberTile(
                    member: member,
                    isCurrentUser: member.userId == currentUserId,
                    isAdmin: isAdmin,
                    isEc: false,
                    onLeave: member.userId == currentUserId
                        ? () => _confirmLeave(context, ref, circle.id,
                            circle.isFamily)
                        : null,
                    onPromote: isAdmin && !member.isAdmin
                        ? () => _updateRole(ref, circle.id, member.userId,
                            CircleRole.admin)
                        : null,
                    onDemote: isAdmin && member.isAdmin &&
                            member.userId != currentUserId
                        ? () => _updateRole(ref, circle.id, member.userId,
                            CircleRole.member)
                        : null,
                    onRemove: isAdmin && member.userId != currentUserId
                        ? () => _removeMember(ref, circle.id, member.userId,
                            circle.isFamily)
                        : null,
                    onToggleEc: !circle.isFamily && isAdmin &&
                            member.userId != currentUserId
                        ? () => _toggleEc(ref, circle.id, member.userId,
                            member.userName ?? '', true)
                        : null,
                  )),
              if (detail.observers.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Observers (${detail.observers.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...detail.observers.map((obs) => ListTile(
                      leading: CircleAvatar(
                        child: Icon(Icons.phone,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer),
                      ),
                      title: Text(obs.name),
                      subtitle: Text(_maskPhone(obs.phone)),
                      trailing: isAdmin
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () =>
                                  _removeObserver(ref, obs.id),
                            )
                          : const Chip(label: Text('SMS')),
                    )),
              ],
              if (isAdmin) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _showAddObserver(context, ref, circle.id),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Observer'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 4) return phone;
    return '${phone.substring(0, phone.length - 4)}****${phone.substring(phone.length - 4)}';
  }

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    String circleId,
    bool isFamily,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave circle?'),
        content: Text(isFamily
            ? 'Leaving will remove all emergency contact links from this circle.'
            : 'Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(circleActionsProvider)
          .leaveCircle(circleId: circleId, isFamily: isFamily);
      if (context.mounted) context.go('/circles');
    }
  }

  Future<void> _onAdminAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String circleId,
  ) async {
    if (action == 'regenerate') {
      final newCode = await ref
          .read(circleActionsProvider)
          .regenerateInviteCode(circleId);
      ref.invalidate(circleDetailProvider(circleId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New code: ${newCode.toUpperCase()}')),
        );
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete circle?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await ref.read(circleActionsProvider).deleteCircle(circleId);
        if (context.mounted) context.go('/circles');
      }
    }
  }

  void _updateRole(
    WidgetRef ref,
    String circleId,
    String userId,
    CircleRole role,
  ) {
    ref.read(circleActionsProvider).updateRole(
          circleId: circleId,
          userId: userId,
          role: role,
        );
    ref.invalidate(circleDetailProvider(circleId));
  }

  void _removeMember(
    WidgetRef ref,
    String circleId,
    String userId,
    bool isFamily,
  ) {
    ref.read(circleActionsProvider).removeMember(
          circleId: circleId,
          userId: userId,
          isFamily: isFamily,
        );
    ref.invalidate(circleDetailProvider(circleId));
  }

  void _removeObserver(WidgetRef ref, String ecId) {
    ref.read(circleActionsProvider).removeObserver(ecId: ecId);
    ref.invalidate(circleDetailProvider(circleId));
  }

  void _toggleEc(
    WidgetRef ref,
    String circleId,
    String targetUserId,
    String targetName,
    bool enable,
  ) {
    ref.read(circleActionsProvider).toggleEc(
          circleId: circleId,
          targetUserId: targetUserId,
          targetName: targetName,
          enable: enable,
        );
    ref.invalidate(circleDetailProvider(circleId));
  }

  void _showAddObserver(
    BuildContext context,
    WidgetRef ref,
    String circleId,
  ) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Observer',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Observers receive SMS alerts but don\'t need the app.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixText: '+91 ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = '+91${phoneCtrl.text.trim()}';
                if (name.isEmpty || phoneCtrl.text.trim().length < 10) return;
                await ref.read(circleActionsProvider).addObserver(
                      circleId: circleId,
                      name: name,
                      phone: phone,
                    );
                ref.invalidate(circleDetailProvider(circleId));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
