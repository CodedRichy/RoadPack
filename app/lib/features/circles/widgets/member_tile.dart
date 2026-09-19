import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../models/circle_member.dart';

class MemberTile extends StatelessWidget {
  const MemberTile({
    super.key,
    required this.member,
    required this.isCurrentUser,
    required this.isAdmin,
    required this.isEc,
    this.onPromote,
    this.onDemote,
    this.onRemove,
    this.onToggleEc,
    this.onLeave,
  });

  final CircleMember member;
  final bool isCurrentUser;
  final bool isAdmin;
  final bool isEc;
  final VoidCallback? onPromote;
  final VoidCallback? onDemote;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleEc;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final initials = (member.userName ?? '?')
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              member.userName ?? l10n.circlesUnknownMember,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 4),
            Text(l10n.circlesYouTag, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          Chip(
            label: Text(
              member.role.displayName(l10n),
              style: theme.textTheme.labelSmall,
            ),
            visualDensity: VisualDensity.compact,
          ),
          if (isEc) ...[
            const SizedBox(width: 4),
            Icon(Icons.shield, size: 16, color: theme.colorScheme.primary),
          ],
        ],
      ),
      trailing: _buildMenu(context),
    );
  }

  Widget? _buildMenu(BuildContext context) {
    final l10n = context.l10n;
    final items = <PopupMenuEntry<String>>[];

    if (isCurrentUser) {
      items.add(
        PopupMenuItem(value: 'leave', child: Text(l10n.circlesMenuLeaveCircle)),
      );
    } else if (isAdmin) {
      if (member.isAdmin) {
        items.add(
          PopupMenuItem(value: 'demote', child: Text(l10n.circlesMenuDemote)),
        );
      } else {
        items.add(
          PopupMenuItem(value: 'promote', child: Text(l10n.circlesMenuPromote)),
        );
      }
      items.add(
        PopupMenuItem(value: 'remove', child: Text(l10n.circlesMenuRemove)),
      );
      if (onToggleEc != null) {
        items.add(
          PopupMenuItem(
            value: 'ec',
            child: Text(
              isEc ? l10n.circlesMenuRemoveEc : l10n.circlesMenuMarkEc,
            ),
          ),
        );
      }
    }

    if (items.isEmpty) return null;

    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'leave':
            onLeave?.call();
          case 'promote':
            onPromote?.call();
          case 'demote':
            onDemote?.call();
          case 'remove':
            onRemove?.call();
          case 'ec':
            onToggleEc?.call();
        }
      },
      itemBuilder: (_) => items,
    );
  }
}
