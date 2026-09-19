/// The three languages the bystander screen ships in for the pilot.
///
/// This screen is read by a stranger, not by the account holder, so it does
/// not follow the app's locale preference blindly -- it offers a visible,
/// one-tap switch. English is the fallback because it is the only one of the
/// three that everyone in the pilot geography can at least partly parse.
enum BystanderLang {
  en('EN', 'English'),
  ml('മല', 'മലയാളം'),
  hi('हि', 'हिन्दी');

  const BystanderLang(this.chip, this.nativeName);

  /// Short label for the language switch.
  final String chip;

  /// The language's name, in itself.
  final String nativeName;

  static BystanderLang fromLocaleCode(String? code) => switch (code) {
    'ml' => BystanderLang.ml,
    'hi' => BystanderLang.hi,
    _ => BystanderLang.en,
  };
}

/// A string in the three pilot languages.
///
/// Bystander copy deliberately does NOT live in the shared ARB files: it is
/// safety-critical wording that must be reviewed as one block, and it must
/// render even if localisation delegates failed to load.
class L3 {
  const L3(this.en, this.ml, this.hi);

  final String en;
  final String ml;
  final String hi;

  String call(BystanderLang lang) => switch (lang) {
    BystanderLang.en => en,
    BystanderLang.ml => ml,
    BystanderLang.hi => hi,
  };
}
