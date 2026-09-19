import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bystander_lang.dart';
import '../models/bystander_session.dart';
import '../../auth/providers/authenticated_supabase_provider.dart';
import '../models/hospital.dart';
import '../services/bystander_actions.dart';
import '../services/hospital_gateway.dart';
import '../services/hospital_repository.dart';

/// The incident snapshot the screen renders.
///
/// Unimplemented by default and overridden at the route: there is no safe
/// default bystander session, and silently rendering an empty one would put a
/// screen that says "this person may need help" in front of a stranger with
/// no incident behind it.
final bystanderSessionProvider = Provider<BystanderSession>((ref) {
  throw UnimplementedError(
    'bystanderSessionProvider must be overridden with the active incident',
  );
});

/// Providers that read the session must declare it here.
///
/// The session is supplied by a nested `ProviderScope` at the route, so any
/// provider deriving from it is scoped too. Riverpod requires that
/// relationship to be declared: without it, reading a derived provider from
/// inside the override throws at build time rather than resolving against the
/// overridden session.
final _scopedToSession = <ProviderOrFamily>[bystanderSessionProvider];

final bystanderActionsProvider = Provider<BystanderActions>(
  (ref) => BystanderActions(),
);

/// Offline-first, with the Supabase refresh wired in when — and only when —
/// there is an authenticated client. The read path does not consult it: the
/// fetcher is used by `refreshCache`, which swallows failure, so an
/// unauthenticated or offline device still resolves from cache and seed.
final hospitalRepositoryProvider = Provider<HospitalRepository>((ref) {
  final client = ref.watch(authenticatedSupabaseProvider);
  return HospitalRepository(
    store: SharedPreferencesHospitalCacheStore(),
    fetcher: client == null ? null : supabaseHospitalFetcher(client),
  );
});

/// Fire-and-forget cache warm. Nothing awaits it and nothing renders behind
/// it; it exists so a device that does have a network arrives at the next
/// crash with a fresher list than the bundled seed.
final hospitalCacheWarmProvider = Provider<void>((ref) {
  unawaited(ref.watch(hospitalRepositoryProvider).refreshCache());
});

/// Which language the bystander picked. Defaults to English; the switch is on
/// screen because the reader is not the account holder.
final bystanderLangProvider =
    NotifierProvider<BystanderLangNotifier, BystanderLang>(
      BystanderLangNotifier.new,
    );

class BystanderLangNotifier extends Notifier<BystanderLang> {
  @override
  BystanderLang build() => BystanderLang.en;

  void set(BystanderLang lang) => state = lang;
}

/// Nearest cached trauma-capable facility. Resolves offline.
final nearestHospitalsProvider = FutureProvider<List<RankedHospital>>((
  ref,
) async {
  final session = ref.watch(bystanderSessionProvider);
  if (!session.hasLocation) return const [];
  final repo = ref.watch(hospitalRepositoryProvider);
  return repo.nearest(lat: session.lat!, lng: session.lng!, limit: 3);
}, dependencies: _scopedToSession);
