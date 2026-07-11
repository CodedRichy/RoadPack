import 'package:flutter/material.dart';

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
              member.userName ?? 'Unknown',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 4),
            Text('(you)', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          Chip(
            label: Text(
              member.role.displayName,
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
    final items = <PopupMenuEntry<String>>[];

    if (isCurrentUser) {
      items.add(
        const PopupMenuItem(value: 'leave', child: Text('Leave circle')),
      );
    } else if (isAdmin) {
      if (member.isAdmin) {
        items.add(
          const PopupMenuItem(value: 'demote', child: Text('Demote to member')),
        );
      } else {
        items.add(
          const PopupMenuItem(
            value: 'promote',
            child: Text('Promote to admin'),
          ),
        );
      }
      items.add(const PopupMenuItem(value: 'remove', child: Text('Remove')));
      if (onToggleEc != null) {
        items.add(
          PopupMenuItem(
            value: 'ec',
            child: Text(
              isEc
                  ? 'Remove as emergency contact'
                  : 'Mark as emergency contact',
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
