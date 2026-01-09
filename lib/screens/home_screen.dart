import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:convoy_app/screens/convoys_screen.dart';
import 'package:convoy_app/screens/profile_screen.dart';
import 'package:convoy_app/theme/app_colors.dart';
import 'package:convoy_app/widgets/bottom_nav_bar.dart';
import 'package:flutter/services.dart' show rootBundle;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Constants
  final LatLng _kerala = const LatLng(9.9312, 76.2673);
  
  // State
  bool _isFullScreen = false;
  GoogleMapController? _mapController;
  String? _darkMapStyleJson;
  String? _currentMapStyle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMapStyle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateMapTheme();
    }
  }

  Future<void> _loadMapStyle() async {
    try {
      _darkMapStyleJson = await rootBundle.loadString('assets/map_style.json');
      _updateMapTheme();
    } catch (e) {
      debugPrint("Error loading map style: $e");
    }
  }

  void _updateMapTheme() {
    final hour = DateTime.now().hour;
    final isNight = hour < 6 || hour >= 18;
    
    setState(() {
      _currentMapStyle = isNight ? _darkMapStyleJson : null;
    });
  }

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

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Card Mode properties
    // Height: 60% of screen in normal mode, full screen in expanded
    final double mapHeight = _isFullScreen ? screenHeight : screenHeight * 0.90;
    
    // Margins: 16 horizontal/20 vertical in normal mode (card look), 0 in expanded
    // final double mapMarginHorizontal = _isFullScreen ? 0 : 16; // Unused
    // final double mapMarginVertical = _isFullScreen ? 0 : 16;   // Unused
    // final double mapTopMargin = _isFullScreen ? 0 : 60;        // Unused
    
    final double mapBorderRadius = _isFullScreen ? 0 : 30;

    // Animation Positions
    // Buttons: float above nav in normal (bottom ~100), slide off in full (-200)
    final double buttonsBottomPos = _isFullScreen ? -200 : 100; 
    // Nav: at bottom (0), slide off in full (-100)
    final double navBottomPos = _isFullScreen ? -100 : 0;
    
    // Opacity
    final double uiOpacity = _isFullScreen ? 0.0 : 1.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // LAYER 1: The Map (Animated Container)
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
            height: mapHeight,
            width: screenWidth,
            // User requested Map margin: 20 in card mode.
            // Using explicit margins here instead of unused variables
            margin: _isFullScreen ? EdgeInsets.zero : const EdgeInsets.only(top: 60, left: 16, right: 16, bottom: 20),
            alignment: Alignment.center,
            padding: EdgeInsets.zero, 
            onEnd: () {},
            child: AnimatedContainer(
               duration: const Duration(milliseconds: 500),
               curve: Curves.easeInOutCubic,
               decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(mapBorderRadius),
                boxShadow: _isFullScreen ? [] : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
                ],
              ),
              clipBehavior: Clip.antiAlias,
              // Inner container can just fill the outer one
              // margin: _isFullScreen ? EdgeInsets.zero : const EdgeInsets.only(top: 80, left: 16, right: 16, bottom: 200), // Removed conflicting margin
              
              child: Stack(
                children: [
                   GoogleMap(
                    initialCameraPosition: CameraPosition(target: _kerala, zoom: 13.0),
                    style: _currentMapStyle,
                    padding: EdgeInsets.only(
                      bottom: _isFullScreen ? 20 : 20, // Logo padding
                      top: _isFullScreen ? 50 : 0, 
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    onMapCreated: (GoogleMapController controller) {
                        // _mapController is defined in state class
                        _mapController = controller; 
                    },
                    markers: {Marker(markerId: const MarkerId('loc'), position: _kerala)},
                    circles: {
                         Circle(
                          circleId: const CircleId('radius'),
                          center: _kerala,
                          radius: 500,
                          fillColor: AppColors.primary.withValues(alpha: 0.2), 
                          strokeColor: AppColors.primary,
                          strokeWidth: 1,
                        ),
                    },
                  ),

                  // Touch Detector for Expansion (Only in Normal Mode)
                  if (!_isFullScreen)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _toggleFullScreen,
                        behavior: HitTestBehavior.translucent,
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  
                  // Close Button (Only in FullScreen)
                   if (_isFullScreen)
                    Positioned(
                      top: 50,
                      left: 20,
                      child: SafeArea(
                        child: FloatingActionButton.small(
                          onPressed: _toggleFullScreen,
                          backgroundColor: AppColors.card,
                          child: const Icon(Icons.close_fullscreen, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // LAYER 2: Status Pill (Fade out in FS)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
            top: _isFullScreen ? -100 : 50, // Move it up and out, or just fade? User said fade.
            left: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300), // Faster fade
              opacity: uiOpacity,
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
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Text('Not in Convoy', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),

          // LAYER 3: Action Buttons (Slide down)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
            bottom: buttonsBottomPos,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.plus, size: 20), SizedBox(width: 8), Text('Start Convoy')]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.card,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.mapPin, size: 20), SizedBox(width: 8), Text('Join Convoy')]),
                  ),
                ),
              ],
            ),
          ),

          // LAYER 4: Bottom Nav (Slide down)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
            bottom: navBottomPos,
            left: 0,
            right: 0,
            child: BottomNavBar(currentItem: NavItem.map, onNavigate: _onNavigate),
          ),
        ],
      ),
    );
  }
}
