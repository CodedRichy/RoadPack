import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:convoy_app/screens/convoys_screen.dart';
import 'package:convoy_app/screens/profile_screen.dart';
import 'package:convoy_app/theme/app_colors.dart';
import 'package:convoy_app/widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LatLng _sanFrancisco = const LatLng(37.7749, -122.4194);

  void _onNavigate(NavItem item) {
    if (item == NavItem.convoys) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const ConvoysScreen(),
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
    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            options: MapOptions(
              initialCenter: _sanFrancisco,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                userAgentPackageName: 'com.example.convoy_app',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _sanFrancisco,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: AppColors.primary, size: 40),
                  ),
                ],
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _sanFrancisco,
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderColor: AppColors.primary,
                    borderStrokeWidth: 1,
                    useRadiusInMeter: true,
                    radius: 500, // meters
                  ),
                ],
              ),
            ],
          ),

          // Floating UI Elements
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                   // Top Status Card
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Not in Convoy',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // My Location Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card.withValues(alpha: 0.95),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(LucideIcons.navigation, color: AppColors.white),
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.plus, size: 20),
                              SizedBox(width: 8),
                              Text('Start Convoy'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.card.withValues(alpha: 0.95),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.mapPin, size: 20),
                              SizedBox(width: 8),
                              Text('Join Convoy'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50), // Space for BottomNavBar
                ],
              ),
            ),
          ),

          // Bottom Navigation (Positioned at bottom)
          const Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox.shrink(), // Placeholder, implemented below in separate container or stack logic if needed, but here we can just put it in the Column or separate Align.
            // Wait, the BottomNavBar is inside the Safe Area column in the React Code?
            // No, in React it's absolute at bottom.
          ),
          
          Align(
            alignment: Alignment.bottomCenter,
             child: BottomNavBar(
              currentItem: NavItem.map,
              onNavigate: _onNavigate,
            ),
          ),
        ],
      ),
    );
  }
}
