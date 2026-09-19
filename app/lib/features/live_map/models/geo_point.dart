import 'dart:math' as math;

/// A plain latitude/longitude pair.
///
/// Deliberately not `LatLng` from google_maps_flutter: the models layer and its
/// tests must not depend on a plugin that needs a platform channel. The map
/// widget converts at the edge.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  static const double earthRadiusMeters = 6371008.8;

  /// Great-circle distance in metres.
  double distanceTo(GeoPoint other) {
    const toRad = math.pi / 180;
    final dLat = (other.latitude - latitude) * toRad;
    final dLng = (other.longitude - longitude) * toRad;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(latitude * toRad) *
            math.cos(other.latitude * toRad) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(a)));
  }

  Map<String, dynamic> toJson() => {'lat': latitude, 'lng': longitude};

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
    (json['lat'] as num).toDouble(),
    (json['lng'] as num).toDouble(),
  );

  /// Parses PostGIS WKT / EWKT `POINT(lng lat)`. Returns null on anything else
  /// rather than guessing — a guessed coordinate is a wrong coordinate.
  static GeoPoint? tryParseWkt(Object? value) {
    if (value is! String) return null;
    final match = RegExp(
      r'POINT\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s*\)',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;
    final lng = double.tryParse(match.group(1)!);
    final lat = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    return GeoPoint(lat, lng);
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}
