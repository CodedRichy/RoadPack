/// Which side of the DPDPA age line the user falls on (constraint C6).
enum AgeBand {
  /// No usable date of birth on file. Treated as [minor] by every gate: a
  /// missing DOB is not evidence of adulthood.
  unknown,

  /// Under 18. Cannot be tracked without a live `parental` consent.
  minor,

  /// 18 or over.
  adult;

  bool get requiresParentalConsent => this != AgeBand.adult;
}

/// Age arithmetic for FR-003.
///
/// Kept as pure functions taking an explicit `now` so the boundary cases —
/// the day before an 18th birthday, the birthday itself, a leap-day birth —
/// are testable without waiting a year.
abstract final class AgeGate {
  /// DPDPA 2023 defines a child as a person under 18.
  static const int adultAge = 18;

  /// Completed years between [dateOfBirth] and [now], or `null` when there
  /// is no date of birth or the date is in the future (a corrupt row, which
  /// must not read as "very old").
  static int? ageInYears(DateTime? dateOfBirth, {DateTime? now}) {
    if (dateOfBirth == null) return null;
    final today = now ?? DateTime.now();
    final dob = DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day);
    final ref = DateTime(today.year, today.month, today.day);
    if (dob.isAfter(ref)) return null;

    var age = ref.year - dob.year;
    final hadBirthday =
        ref.month > dob.month || (ref.month == dob.month && ref.day >= dob.day);
    if (!hadBirthday) age -= 1;
    return age < 0 ? null : age;
  }

  /// The band [dateOfBirth] falls in. Unknown or unparseable dates return
  /// [AgeBand.unknown], which every gate treats exactly like [AgeBand.minor].
  static AgeBand bandFor(DateTime? dateOfBirth, {DateTime? now}) {
    final age = ageInYears(dateOfBirth, now: now);
    if (age == null) return AgeBand.unknown;
    return age >= adultAge ? AgeBand.adult : AgeBand.minor;
  }

  /// Convenience for the hard gate. `true` whenever we are not certain the
  /// user is an adult.
  static bool requiresParentalConsent(DateTime? dateOfBirth, {DateTime? now}) =>
      bandFor(dateOfBirth, now: now).requiresParentalConsent;
}
