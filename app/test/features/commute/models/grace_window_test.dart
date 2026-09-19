import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/commute/models/grace_window.dart';
import 'package:roadpack/features/commute/models/non_arrival_config.dart';

void main() {
  group('GraceWindow', () {
    test('defaults to 15 minutes (FR-042)', () {
      expect(GraceWindow.defaultWindow, GraceWindow.fifteen);
      expect(GraceWindow.defaultWindow.minutes, 15);
      expect(GraceWindow.defaultWindow.duration, const Duration(minutes: 15));
    });

    test('offers exactly 10, 15 and 30 minutes', () {
      expect(GraceWindow.values.map((w) => w.minutes).toList(), [10, 15, 30]);
    });

    test('honours 10 and 30 from stored minutes', () {
      expect(GraceWindow.fromMinutes(10), GraceWindow.ten);
      expect(GraceWindow.fromMinutes(30), GraceWindow.thirty);
      expect(GraceWindow.fromMinutes(15), GraceWindow.fifteen);
    });

    test('falls back to the 15 minute default for null or unknown values', () {
      expect(GraceWindow.fromMinutes(null), GraceWindow.fifteen);
      expect(GraceWindow.fromMinutes(0), GraceWindow.fifteen);
      expect(GraceWindow.fromMinutes(45), GraceWindow.fifteen);
      expect(GraceWindow.fromMinutes(-5), GraceWindow.fifteen);
    });
  });

  group('NonArrivalConfig', () {
    test('reads the users row, defaulting a missing delay to 15', () {
      final config = NonArrivalConfig.fromJson(const {
        'non_arrival_enabled': true,
        'non_arrival_delay_min': null,
      });
      expect(config.enabled, isTrue);
      expect(config.window, GraceWindow.fifteen);
    });

    test('round-trips through the wire format', () {
      const config = NonArrivalConfig(
        enabled: false,
        window: GraceWindow.thirty,
      );
      expect(config.toJson(), {
        'non_arrival_enabled': false,
        'non_arrival_delay_min': 30,
      });
      expect(NonArrivalConfig.fromJson(config.toJson()), config);
    });

    test('a disabled config protects nobody and says so', () {
      const config = NonArrivalConfig(enabled: false);
      expect(config.window, GraceWindow.fifteen);
      expect(config.enabled, isFalse);
    });
  });
}
