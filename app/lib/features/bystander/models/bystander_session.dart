import 'ice_profile.dart';

/// Everything the bystander screen is allowed to know.
///
/// Assembled by whoever opens the screen (the incident notification action in
/// Phase 1). It is a value object on purpose: the screen must render from a
/// snapshot, with no live dependency that could fail at the roadside.
class BystanderSession {
  const BystanderSession({
    required this.incidentId,
    required this.incidentActive,
    required this.victimDisplayName,
    this.lat,
    this.lng,
    this.accuracyMeters,
    this.locationAt,
    this.contactName,
    this.contactPhone,
    this.ice,
  });

  final String incidentId;

  /// False once the incident is resolved or cancelled. Gates ICE (FR-094).
  final bool incidentActive;

  final String victimDisplayName;

  final double? lat;
  final double? lng;
  final double? accuracyMeters;

  /// When the fix was taken. Shown verbatim: never presented as "now".
  final DateTime? locationAt;

  final String? contactName;
  final String? contactPhone;

  final IceProfile? ice;

  bool get hasLocation => lat != null && lng != null;

  bool get hasContact =>
      contactPhone != null && contactPhone!.trim().isNotEmpty;

  /// Coordinates in the shape an operator expects to hear: decimal degrees,
  /// five places (~1 m), hemisphere spelled out. Tabular figures in the UI.
  String? get readableCoordinates {
    if (!hasLocation) return null;
    final ns = lat! >= 0 ? 'N' : 'S';
    final ew = lng! >= 0 ? 'E' : 'W';
    return '${lat!.abs().toStringAsFixed(5)} $ns, '
        '${lng!.abs().toStringAsFixed(5)} $ew';
  }

  /// The same numbers, expanded, for someone reading them down a phone line.
  String? get spokenCoordinates {
    if (!hasLocation) return null;
    final ns = lat! >= 0 ? 'North' : 'South';
    final ew = lng! >= 0 ? 'East' : 'West';
    return '${lat!.abs().toStringAsFixed(5)} degrees $ns, '
        '${lng!.abs().toStringAsFixed(5)} degrees $ew';
  }
}
