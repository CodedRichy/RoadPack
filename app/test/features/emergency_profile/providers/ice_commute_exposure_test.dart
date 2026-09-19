import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/emergency_profile/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('defaults to closed when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final c = container();
    expect(c.read(iceCommuteExposurePrefProvider), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(iceCommuteExposurePrefProvider), isFalse);
    expect(c.read(iceCommuteExposureOptInProvider), isFalse);
  });

  test('is closed on the first frame even when stored true', () {
    SharedPreferences.setMockInitialValues({
      IceCommuteExposureNotifier.prefsKey: true,
    });
    expect(container().read(iceCommuteExposurePrefProvider), isFalse);
  });

  test('opens once the stored opt-in is read back', () async {
    SharedPreferences.setMockInitialValues({
      IceCommuteExposureNotifier.prefsKey: true,
    });
    final c = container();
    c.listen(iceCommuteExposurePrefProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(c.read(iceCommuteExposurePrefProvider), isTrue);
    expect(c.read(iceCommuteExposureOptInProvider), isTrue);
  });

  test('set persists and survives a fresh container', () async {
    SharedPreferences.setMockInitialValues({});
    final first = container();
    await first.read(iceCommuteExposurePrefProvider.notifier).set(true);
    expect(first.read(iceCommuteExposurePrefProvider), isTrue);

    final second = container();
    second.listen(iceCommuteExposurePrefProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(second.read(iceCommuteExposurePrefProvider), isTrue);
  });

  test('a stored opt-out keeps the ICE gate shut during a commute', () async {
    SharedPreferences.setMockInitialValues({
      IceCommuteExposureNotifier.prefsKey: false,
    });
    final c = ProviderContainer(
      overrides: [
        iceIncidentActiveProvider.overrideWithValue(false),
        iceCommuteActiveProvider.overrideWithValue(true),
      ],
    );
    addTearDown(c.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(iceAccessProvider), isNull);
  });
}
