import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/consent/models/age_gate.dart';

void main() {
  group('AgeGate', () {
    final now = DateTime(2026, 9, 8);

    test('counts completed years only', () {
      expect(AgeGate.ageInYears(DateTime(2008, 9, 8), now: now), 18);
      expect(AgeGate.ageInYears(DateTime(2008, 9, 9), now: now), 17);
    });

    test('an 18th birthday today makes the user an adult', () {
      expect(AgeGate.bandFor(DateTime(2008, 9, 8), now: now), AgeBand.adult);
    });

    test('the day before the 18th birthday is still a minor', () {
      expect(AgeGate.bandFor(DateTime(2008, 9, 9), now: now), AgeBand.minor);
    });

    test('a missing date of birth is unknown, and unknown needs consent', () {
      expect(AgeGate.bandFor(null, now: now), AgeBand.unknown);
      expect(AgeBand.unknown.requiresParentalConsent, isTrue);
      expect(AgeGate.requiresParentalConsent(null, now: now), isTrue);
    });

    test('a future date of birth is unknown, never "very old"', () {
      expect(AgeGate.bandFor(DateTime(2030, 1, 1), now: now), AgeBand.unknown);
    });

    test('a leap-day birthday is an adult on 1 March of the 18th year', () {
      final dob = DateTime(2008, 2, 29);
      expect(AgeGate.bandFor(dob, now: DateTime(2026, 2, 28)), AgeBand.minor);
      expect(AgeGate.bandFor(dob, now: DateTime(2026, 3, 1)), AgeBand.adult);
    });

    test('an adult does not require parental consent', () {
      expect(
        AgeGate.requiresParentalConsent(DateTime(1995, 1, 1), now: now),
        isFalse,
      );
    });
  });
}
