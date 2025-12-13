import 'package:flutter/material.dart';
import 'package:convoy_app/screens/splash_screen.dart';
import 'package:convoy_app/theme/app_colors.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RoadPack',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
