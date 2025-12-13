import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:convoy_app/screens/home_screen.dart';
import 'package:convoy_app/screens/profile_screen.dart';
import 'package:convoy_app/theme/app_colors.dart';
import 'package:convoy_app/widgets/bottom_nav_bar.dart';

class ConvoysScreen extends StatelessWidget {
  const ConvoysScreen({super.key});

  void _onNavigate(BuildContext context, NavItem item) {
    if (item == NavItem.map) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    } else if (item == NavItem.profile) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const ProfileScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final convoys = [
      {'id': 1, 'name': 'Weekend Riders', 'members': 8, 'status': 'Active'},
      {'id': 2, 'name': 'Coast Road Trip', 'members': 5, 'status': 'Active'},
      {'id': 3, 'name': 'Mountain Pass Run', 'members': 12, 'status': 'Ended'},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textSecondary),
          onPressed: () => _onNavigate(context, NavItem.map),
        ),
        title: const Text('Convoys', style: TextStyle(color: AppColors.white)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white.withValues(alpha: 0.05), height: 1),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Create Convoy Button
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.plus, size: 20),
                    SizedBox(width: 8),
                    Text('Create Convoy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Convoys List
              ...convoys.map((convoy) {
                final status = convoy['status'] as String;
                final isActive = status == 'Active';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        convoy['name'] as String,
                        style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(LucideIcons.users, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${convoy['members']} members',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Join by Code
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Have a convoy code?',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Join Convoy', style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100), // Spacing for bottom nav
            ],
          ),

          Align(
            alignment: Alignment.bottomCenter,
             child: BottomNavBar(
              currentItem: NavItem.convoys,
              onNavigate: (item) => _onNavigate(context, item),
            ),
          ),
        ],
      ),
    );
  }
}
