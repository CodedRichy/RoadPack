import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/clerk_service.dart';
import 'clerk_auth_provider.dart';

/// Fetches a Supabase-templated JWT for the current Clerk session.
///
/// Resolves to `null` when there is no authenticated Clerk session, or when
/// [ClerkService.getSupabaseToken] could not obtain a token.
final supabaseTokenProvider = FutureProvider<String?>((ref) async {
  final authState = ref.watch(clerkAuthProvider).valueOrNull;
  if (authState == null || !authState.isAuthenticated) return null;

  final service = ref.read(clerkServiceProvider);
  return service.getSupabaseToken();
});
