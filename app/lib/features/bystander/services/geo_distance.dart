import 'dart:math' as math;

const double _earthRadiusMeters = 6371008.8;

/// Great-circle distance in metres.
///
/// Straight line, never road distance. The bystander UI must label it as such
/// -- a 400 m "distance" across a river is a lie a panicking person will act
/// on.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * _earthRadiusMeters * math.asin(math.min(1, math.sqrt(a)));
}

double _rad(double deg) => deg * math.pi / 180;
