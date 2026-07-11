import 'package:flutter/material.dart';

import '../models/circle.dart';

class CircleTypePicker extends StatelessWidget {
  const CircleTypePicker({super.key, required this.onSelected, this.selected});

  final ValueChanged<CircleType> onSelected;
  final CircleType? selected;

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
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: CircleType.values.map((type) {
        final isSelected = selected == type;
        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          child: InkWell(
            onTap: () => onSelected(type),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _iconForType(type),
                    size: 32,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type.displayName,
                    style: theme.textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type.description,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
