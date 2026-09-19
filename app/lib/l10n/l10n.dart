import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'app_localizations_en.dart';

export 'app_localizations.dart';
export 'locale_provider.dart';

/// The three pilot languages (FR-005). English first: it is the fallback the
/// resolver lands on for any device locale outside this list.
const kSupportedLocales = <Locale>[Locale('en'), Locale('hi'), Locale('ml')];

extension L10nX on BuildContext {
  /// Localised copy for this subtree.
  ///
  /// Falls back to English rather than throwing when the delegate is missing.
  /// The same reasoning as BystanderCopy: a roadside screen that renders
  /// foreign-but-readable text beats a screen that renders a red error box.
  /// It also keeps widget tests that pump a bare `MaterialApp` working.
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLocalizationsEn();
}
