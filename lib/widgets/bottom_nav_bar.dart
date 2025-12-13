import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:convoy_app/theme/app_colors.dart';

enum NavItem { map, convoys, profile }

class BottomNavBar extends StatelessWidget {
  final NavItem currentItem;
  final Function(NavItem) onNavigate;

  const BottomNavBar({
    super.key,
    required this.currentItem,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context,
            icon: LucideIcons.mapPin,
            item: NavItem.map,
          ),
          _buildNavItem(
            context,
            icon: LucideIcons.users,
            item: NavItem.convoys,
          ),
          _buildNavItem(
            context,
            icon: LucideIcons.user,
            item: NavItem.profile,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, {required IconData icon, required NavItem item}) {
    final isSelected = currentItem == item;
    return GestureDetector(
      onTap: () => onNavigate(item),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            size: 24,
          ),
        ],
      ),
    );
  }
}
