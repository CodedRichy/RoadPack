import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hospital.dart';
import 'hospital_repository.dart';

/// Columns pulled for the offline hospital cache.
///
/// `hospitals.location` is a `GEOGRAPHY(POINT, 4326)` (migration 00008) and
/// PostgREST hands it back as an EWKB hex blob, which this client has no
/// business decoding on a phone at a roadside. The read therefore goes
/// through the `hospitals_flat` view, which projects `ST_Y/ST_X` as plain
/// `lat`/`lng` doubles. Selecting scalars keeps the cached payload small,
/// which matters: it is written to shared preferences and read on a cold,
/// offline start.
const kHospitalColumns =
    'id, name, address, phone, type, trauma_level, has_emergency, '
    'district, verified_at, source, lat, lng';

/// The view the flattened read hits. See the migration noted above.
const kHospitalView = 'hospitals_flat';

/// Builds a [HospitalFetcher] over Supabase.
///
/// This is the *refresh* path only. `HospitalRepository.refreshCache`
/// swallows anything this throws, so an offline phone, an expired token, or
/// a view that has not been deployed yet all degrade to the existing cache
/// and then to the bundled seed. There is no state in which a failure here
/// leaves the bystander with no hospital list.
HospitalFetcher supabaseHospitalFetcher(
  SupabaseClient client, {
  String? district,
  int limit = 500,
}) {
  return () async {
    var query = client.from(kHospitalView).select(kHospitalColumns);
    if (district != null) query = query.eq('district', district);
    final rows = await query.limit(limit);
    return [
      for (final row in rows)
        if (row['lat'] is num && row['lng'] is num)
          Hospital.fromJson(Map<String, dynamic>.from(row)),
    ];
  };
}
