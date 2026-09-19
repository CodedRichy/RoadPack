import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/bystander/services/bystander_actions.dart';

void main() {
  late List<Uri> launched;
  late BystanderActions actions;

  setUp(() {
    launched = [];
    actions = BystanderActions(
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
    );
  });

  test('dials 112 as a platform dial intent', () async {
    await actions.dialEmergencyNumber();
    expect(launched.single, Uri.parse('tel:112'));
  });

  test('dials the emergency contact, stripping formatting', () async {
    await actions.dialContact('+91 98470-12345');
    expect(launched.single, Uri.parse('tel:+919847012345'));
  });

  test('refuses an unusable contact number instead of launching', () async {
    final ok = await actions.dialContact('   ');
    expect(ok, isFalse);
    expect(launched, isEmpty);
  });

  test('opens directions to a destination', () async {
    await actions.openDirections(lat: 9.9816, lng: 76.2999, label: 'GH');
    final uri = launched.single;
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['destination'], '9.9816,76.2999');
  });

  test('reports failure when the platform cannot handle the intent', () async {
    final failing = BystanderActions(launcher: (_) async => false);
    expect(await failing.dialEmergencyNumber(), isFalse);
  });
}
