import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The rider's explicit language choice, or `null` to follow the device.
///
/// `null` is not "English" — it hands resolution back to Flutter, which picks
/// the device locale when it is one of the three supported languages and falls
/// through to English (the first entry in `supportedLocales`) otherwise. That
/// is the FR-005 default, and it means a Malayalam handset in Muvattupuzha
/// gets Malayalam without anyone opening settings.
final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale?>(
  AppLocaleNotifier.new,
);

class AppLocaleNotifier extends Notifier<Locale?> {
  static const prefsKey = 'app_locale';

  /// Language codes a stored preference is allowed to name. Anything else —
  /// a stale value from a build that supported more languages, a corrupt
  /// string — is discarded and treated as "follow the device".
  static const allowed = {'en', 'hi', 'ml'};

  @override
  Locale? build() {
    unawaited(_load());
    return null;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(prefsKey);
      if (stored != null && allowed.contains(stored)) {
        state = Locale(stored);
      }
    } catch (e) {
      debugPrint('locale preference read failed, following device: $e');
    }
  }

  /// Sets the language. `null` clears the override and follows the device.
  Future<void> set(Locale? locale) async {
    if (locale != null && !allowed.contains(locale.languageCode)) return;
    final previous = state;
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(prefsKey);
      } else {
        await prefs.setString(prefsKey, locale.languageCode);
      }
    } catch (e) {
      debugPrint('locale preference write failed: $e');
      state = previous;
    }
  }
}
