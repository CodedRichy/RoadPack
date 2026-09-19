import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/hospital.dart';
import 'geo_distance.dart';
import 'hospital_seed.dart';

/// Where the offline hospital set lives between runs.
abstract class HospitalCacheStore {
  Future<String?> read();
  Future<void> write(String value);
}

class InMemoryHospitalCacheStore implements HospitalCacheStore {
  String? _value;

  void seedJson(String value) => _value = value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async => _value = value;
}

class SharedPreferencesHospitalCacheStore implements HospitalCacheStore {
  static const _key = 'bystander.hospitals.v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(_key, value);
}

/// Pulls the hospital table. Injected so the repository has no Supabase
/// dependency and can be exercised offline in tests.
typedef HospitalFetcher = Future<List<Hospital>> Function();

/// Offline-first hospital lookup (FR-111, FR-114).
///
/// Read path never touches the network: cache, else bundled seed. The refresh
/// path is best-effort and swallows failure -- a stale hospital list is far
/// better than an exception on the one screen that cannot fail.
class HospitalRepository {
  HospitalRepository({required this.store, this.fetcher});

  final HospitalCacheStore store;
  final HospitalFetcher? fetcher;

  List<Hospital>? _memo;

  static String encode(List<Hospital> hospitals) =>
      jsonEncode(hospitals.map((h) => h.toJson()).toList());

  static List<Hospital> decode(String raw) => (jsonDecode(raw) as List)
      .map((e) => Hospital.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<List<Hospital>> hospitals() async {
    if (_memo != null) return _memo!;
    try {
      final raw = await store.read();
      if (raw != null && raw.isNotEmpty) {
        final decoded = decode(raw);
        if (decoded.isNotEmpty) return _memo = decoded;
      }
    } catch (_) {
      // A corrupt cache must not take the screen down.
    }
    return _memo = kBundledHospitalSeed;
  }

  /// Nearest first. Straight-line distance; the caller must label it as such.
  Future<List<RankedHospital>> nearest({
    required double lat,
    required double lng,
    int limit = 3,
    bool emergencyOnly = true,
  }) async {
    final all = await hospitals();
    final ranked =
        all
            .where((h) => !emergencyOnly || h.hasEmergency)
            .map(
              (h) => RankedHospital(h, haversineMeters(lat, lng, h.lat, h.lng)),
            )
            .toList()
          ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return ranked.take(limit).toList();
  }

  /// Best-effort cache warm. Never throws.
  Future<void> refreshCache() async {
    final fetch = fetcher;
    if (fetch == null) return;
    try {
      final rows = await fetch();
      if (rows.isEmpty) return;
      await store.write(encode(rows));
      _memo = rows;
    } catch (_) {
      // Offline, unauthenticated, or the table moved. Keep what we have.
    }
  }
}
