import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/errors/errors.dart';
import 'pack_repository.dart';

/// A route, frozen at ride creation.
///
/// `route_source` records provenance so the answer to "which provider drew
/// this line" can change (TRD §12.1 leaves it open, self-hosted Valhalla
/// leading) without a schema change and without silently reinterpreting rides
/// created under the old one.
@immutable
class PackRouteDraft {
  const PackRouteDraft({
    required this.destinationWkt,
    required this.routeLineWkt,
    required this.source,
  });

  final String destinationWkt;
  final String routeLineWkt;
  final String source;
}

/// Resolves a destination into the polyline chainage is measured along.
///
/// The default is deliberately the weakest possible implementation: a straight
/// line from the rider's current position, tagged `provisional`. It is not a
/// route and does not pretend to be — chainage measured against it is only
/// approximately along-road. Swapping in real routing means replacing this
/// provider, and the tag in the database says which rides were created before
/// that happened.
typedef PackRouteResolver =
    Future<PackRouteDraft> Function({
      required double destLat,
      required double destLng,
    });

final packRouteResolverProvider = Provider<PackRouteResolver>((ref) {
  return ({required double destLat, required double destLng}) async {
    final Position position;
    try {
      position = await Geolocator.getCurrentPosition();
    } catch (_) {
      throw const LocationException(
        'Need your current location to measure the pack',
      );
    }
    return PackRouteDraft(
      destinationWkt: PackRepository.pointWkt(lat: destLat, lng: destLng),
      routeLineWkt: PackRepository.lineWkt([
        (lat: position.latitude, lng: position.longitude),
        (lat: destLat, lng: destLng),
      ]),
      source: 'provisional',
    );
  };
});
