import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/core.dart';
import 'features/auth/services/clerk_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConstants.supabaseUrl.isNotEmpty) {
    await initSupabase();
  }

  final container = ProviderContainer();
  if (AppConstants.clerkPublishableKey.isNotEmpty) {
    await container.read(clerkServiceProvider).initialize();
  }

  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
