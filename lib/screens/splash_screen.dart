import 'package:flutter/material.dart';
import 'package:convoy_app/screens/login_screen.dart';
import 'package:convoy_app/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'RoadPack',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Stay connected with your convoy',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
