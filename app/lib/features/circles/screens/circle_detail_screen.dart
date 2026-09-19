import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/l10n.dart';
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
    final currentUserId = ref.watch(clerkAuthProvider).valueOrNull?.userId;
    final l10n = context.l10n;

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
              Text(l10n.circlesLoadError),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(circleDetailProvider(circleId)),
                child: Text(l10n.circlesRetry),
              ),
            ],
          ),
        ),
      ),
      data: (detail) {
        final circle = detail.circle;
        final isAdmin = detail.members.any(
          (m) => m.userId == currentUserId && m.isAdmin,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(circle.name),
            actions: [
              if (isAdmin)
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      _onAdminAction(context, ref, value, circle.id),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'regenerate',
                      child: Text(l10n.circlesRegenerateCode),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.circlesDeleteCircle),
                    ),
                  ],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Chip(label: Text(circle.type.displayName(l10n))),
              const SizedBox(height: 12),
              if (circle.inviteCode != null)
                InviteCodeDisplay(
                  code: circle.inviteCode!,
                  onShare: () {
                    Share.share(
                      l10n.circlesShareInviteMessage(
                        circle.inviteCode!.toUpperCase(),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              Text(
                l10n.circlesMembersHeading(detail.members.length),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...detail.members.map((member) {
                // A member of a FAMILY circle is always synced as an
                // emergency contact. For non-family circles we don't yet
                // have a query that tells us per-member EC status, so we
                // conservatively report false.
                // TODO(circles): add a dedicated fetchMemberEcStatus query
                // so non-family EC status can be reflected here.
                final memberIsEc = circle.isFamily;
                return MemberTile(
                  member: member,
                  isCurrentUser: member.userId == currentUserId,
                  isAdmin: isAdmin,
                  isEc: memberIsEc,
                  onLeave: member.userId == currentUserId
                      ? () => _confirmLeave(
                          context,
                          ref,
                          circle.id,
                          circle.isFamily,
                        )
                      : null,
                  onPromote: isAdmin && !member.isAdmin
                      ? () => _updateRole(
                          context,
                          ref,
                          circle.id,
                          member.userId,
                          CircleRole.admin,
                        )
                      : null,
                  onDemote:
                      isAdmin &&
                          member.isAdmin &&
                          member.userId != currentUserId
                      ? () => _updateRole(
                          context,
                          ref,
                          circle.id,
                          member.userId,
                          CircleRole.member,
                        )
                      : null,
                  onRemove: isAdmin && member.userId != currentUserId
                      ? () => _removeMember(
                          context,
                          ref,
                          circle.id,
                          member.userId,
                          circle.isFamily,
                        )
                      : null,
                  onToggleEc:
                      !circle.isFamily &&
                          isAdmin &&
                          member.userId != currentUserId
                      ? () => _toggleEc(
                          context,
                          ref,
                          circle.id,
                          member.userId,
                          member.userName ?? '',
                          !memberIsEc,
                        )
                      : null,
                );
              }),
              if (detail.observers.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.circlesObserversHeading(detail.observers.length),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...detail.observers.map(
                  (obs) => ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        Icons.phone,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                    title: Text(obs.name),
                    subtitle: Text(_maskPhone(obs.phone)),
                    trailing: isAdmin
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () =>
                                _removeObserver(context, ref, obs.id),
                          )
                        : Chip(label: Text(l10n.circlesObserverSmsTag)),
                  ),
                ),
              ],
              if (isAdmin) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _showAddObserver(context, ref, circle.id),
                  icon: const Icon(Icons.person_add),
                  label: Text(l10n.circlesAddObserverAction),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _maskPhone(String phone) {
    if (phone.length <= 4) return '****';
    return '${'*' * (phone.length - 4)}${phone.substring(phone.length - 4)}';
  }

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    String circleId,
    bool isFamily,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.circlesLeaveDialogTitle),
        content: Text(
          isFamily ? l10n.circlesLeaveFamilyWarning : l10n.circlesLeaveConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.circlesLeaveAction),
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
    final l10n = context.l10n;
    if (action == 'regenerate') {
      final newCode = await ref
          .read(circleActionsProvider)
          .regenerateInviteCode(circleId);
      ref.invalidate(circleDetailProvider(circleId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.circlesNewCodeSnackbar(newCode.toUpperCase())),
          ),
        );
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.circlesDeleteDialogTitle),
          content: Text(l10n.circlesDeleteWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: Text(l10n.circlesDeleteAction),
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

  Future<void> _updateRole(
    BuildContext context,
    WidgetRef ref,
    String circleId,
    String userId,
    CircleRole role,
  ) async {
    try {
      await ref
          .read(circleActionsProvider)
          .updateRole(circleId: circleId, userId: userId, role: role);
      ref.invalidate(circleDetailProvider(circleId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.circlesRoleUpdateError)),
        );
      }
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    String circleId,
    String userId,
    bool isFamily,
  ) async {
    try {
      await ref
          .read(circleActionsProvider)
          .removeMember(circleId: circleId, userId: userId, isFamily: isFamily);
      ref.invalidate(circleDetailProvider(circleId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.circlesRemoveMemberError)),
        );
      }
    }
  }

  Future<void> _removeObserver(
    BuildContext context,
    WidgetRef ref,
    String ecId,
  ) async {
    try {
      await ref.read(circleActionsProvider).removeObserver(ecId: ecId);
      ref.invalidate(circleDetailProvider(circleId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.circlesRemoveObserverError)),
        );
      }
    }
  }

  Future<void> _toggleEc(
    BuildContext context,
    WidgetRef ref,
    String circleId,
    String targetUserId,
    String targetName,
    bool enable,
  ) async {
    try {
      await ref
          .read(circleActionsProvider)
          .toggleEc(
            circleId: circleId,
            targetUserId: targetUserId,
            targetName: targetName,
            enable: enable,
          );
      ref.invalidate(circleDetailProvider(circleId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.circlesEcUpdateError)),
        );
      }
    }
  }

  Future<void> _showAddObserver(
    BuildContext context,
    WidgetRef ref,
    String circleId,
  ) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final l10n = context.l10n;

    await showModalBottomSheet(
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
            Text(
              l10n.circlesAddObserverAction,
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.circlesObserverSmsExplainer,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.commonName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.circlesPhoneNumberLabel,
                prefixText: '+91 ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = '+91${phoneCtrl.text.trim()}';
                if (name.isEmpty || phoneCtrl.text.trim().length < 10) return;
                await ref
                    .read(circleActionsProvider)
                    .addObserver(circleId: circleId, name: name, phone: phone);
                ref.invalidate(circleDetailProvider(circleId));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.circlesAddAction),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
  }
}
