import 'package:flutter/material.dart';

import '../models/circle.dart';
import '../models/circle_member.dart';

class CircleCard extends StatelessWidget {
  const CircleCard({
    super.key,
    required this.circle,
    required this.memberCount,
    required this.userRole,
    required this.onTap,
  });

  final Circle circle;
  final int memberCount;
  final CircleRole userRole;
  final VoidCallback onTap;

  IconData _iconForType(CircleType type) {
    switch (type) {
      case CircleType.family:
        return Icons.favorite;
      case CircleType.friends:
        return Icons.people;
      case CircleType.commute:
        return Icons.route;
      case CircleType.convoy:
        return Icons.two_wheeler;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            _iconForType(circle.type),
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(circle.name),
        subtitle: Text(
          '${circle.type.displayName} -- $memberCount members',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (circle.isExpired)
              Chip(
                label: Text(
                  'Expired',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (circle.isExpired) const SizedBox(width: 4),
            Chip(
              label: Text(
                userRole.displayName,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
