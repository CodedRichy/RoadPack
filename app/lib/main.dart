import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConstants.supabaseUrl.isNotEmpty) {
    await initSupabase();
  }

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
