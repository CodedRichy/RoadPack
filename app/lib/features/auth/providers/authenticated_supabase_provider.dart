import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../services/clerk_service.dart';
import 'clerk_auth_provider.dart';

/// A [SupabaseClient] authenticated with the current Clerk session's
/// Supabase-templated JWT, via `supabase`'s third-party `accessToken` hook
/// (see `SupabaseClient`'s `accessToken` constructor parameter in
/// package:supabase ^2.14.0, re-exported by supabase_flutter ^2.9.0+).
///
/// Resolves to `null` when there is no authenticated Clerk session. Note
/// that a client constructed with a custom `accessToken` callback cannot use
/// its own `auth` namespace — Supabase auth state is driven entirely by
/// Clerk here.
final authenticatedSupabaseProvider = Provider<SupabaseClient?>((ref) {
  final authState = ref.watch(clerkAuthProvider).valueOrNull;
  if (authState == null || !authState.isAuthenticated) return null;

  final service = ref.read(clerkServiceProvider);

  return SupabaseClient(
    AppConstants.supabaseUrl,
    AppConstants.supabaseAnonKey,
    accessToken: () async {
      final token = await service.getSupabaseToken();
      if (token == null) throw Exception('No Supabase token available');
      return token;
    },
  );
});
