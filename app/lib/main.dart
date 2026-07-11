import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/core.dart';
import 'features/auth/services/clerk_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init skipped (config missing): $e');
  }

  if (AppConstants.supabaseUrl.isNotEmpty) {
    await initSupabase();
  }

  final container = ProviderContainer();
  if (AppConstants.clerkPublishableKey.isNotEmpty) {
    await container.read(clerkServiceProvider).initialize();
  }

  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
