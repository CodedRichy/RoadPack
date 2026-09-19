import 'package:url_launcher/url_launcher.dart' as launcher;

/// Injectable so widget tests can assert the intent without a platform.
typedef UriLauncher = Future<bool> Function(Uri uri);

/// The three things a bystander can do, and nothing else.
///
/// Every one is a *user-confirmed* platform intent: the dialer opens with the
/// number filled in and the human presses call. RoadPack never places a call
/// and never pushes data to 112 -- there is no public ERSS API to push to.
class BystanderActions {
  BystanderActions({UriLauncher? launcher}) : _launch = launcher ?? _default;

  final UriLauncher _launch;

  static Future<bool> _default(Uri uri) =>
      launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);

  /// India's single emergency number.
  static const String emergencyNumber = '112';

  static Uri dialUri(String number) => Uri.parse('tel:$number');

  /// Keeps digits and a leading '+'. Anything else is formatting noise that
  /// some dialers choke on.
  static String normalisePhone(String raw) {
    final trimmed = raw.trim();
    final plus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return plus ? '+$digits' : digits;
  }

  /// Turn-by-turn hand-off to whatever maps app the phone already has.
  /// [label] is carried as the query so the destination is recognisable in
  /// the maps app even if the coordinates land beside the gate.
  static Uri directionsUri({
    required double lat,
    required double lng,
    String? label,
  }) => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$lat,$lng',
    if (label != null && label.trim().isNotEmpty) 'destination_name': label,
  });

  Future<bool> dialEmergencyNumber() => _launch(dialUri(emergencyNumber));

  Future<bool> dialContact(String phone) async {
    final number = normalisePhone(phone);
    if (number.isEmpty) return false;
    return _launch(dialUri(number));
  }

  Future<bool> openDirections({
    required double lat,
    required double lng,
    String? label,
  }) => _launch(directionsUri(lat: lat, lng: lng, label: label));
}
