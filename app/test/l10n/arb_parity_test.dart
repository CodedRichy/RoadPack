import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The ARB files are generated from one table, so drift between them should be
/// impossible. This test is the tripwire that says so out loud: a key that
/// exists in English and not in Malayalam is an English string rendered on a
/// Malayalam emergency screen, which is exactly the failure FR-005 exists to
/// prevent.
void main() {
  final locales = ['en', 'hi', 'ml'];

  Map<String, dynamic> read(String locale) {
    final file = File('lib/l10n/app_$locale.arb');
    if (!file.existsSync()) throw StateError('${file.path} is missing');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  /// The `{name}` / `{count, plural, ...}` placeholders a message actually
  /// uses. Order does not matter; presence does.
  Set<String> placeholders(String message) {
    final names = <String>{};
    // Blank out the `one{` / `other{` / `=1{` braces that open an ICU branch
    // body, so `other{circles}` is not mistaken for a `{circles}` placeholder.
    final stripped = message.replaceAll(
      RegExp(r'(?:=\d+|zero|one|two|few|many|other)\s*\{'),
      '<',
    );
    final re = RegExp(r'\{\s*([a-zA-Z][a-zA-Z0-9_]*)\s*[,}]');
    for (final m in re.allMatches(stripped)) {
      names.add(m.group(1)!);
    }
    return names;
  }

  final arbs = {for (final l in locales) l: read(l)};

  test('every locale declares itself', () {
    for (final l in locales) {
      expect(arbs[l]!['@@locale'], l);
    }
  });

  test('no locale is missing a key the template defines', () {
    final template = messageKeys(arbs['en']!);
    expect(template, isNotEmpty);
    for (final l in ['hi', 'ml']) {
      expect(
        template.difference(messageKeys(arbs[l]!)),
        isEmpty,
        reason: '$l is missing keys that English defines',
      );
    }
  });

  test('no locale carries a key the template does not define', () {
    final template = messageKeys(arbs['en']!);
    for (final l in ['hi', 'ml']) {
      expect(
        messageKeys(arbs[l]!).difference(template),
        isEmpty,
        reason: '$l has keys English does not',
      );
    }
  });

  test('placeholders survive translation', () {
    for (final key in messageKeys(arbs['en']!)) {
      final expected = placeholders(arbs['en']![key] as String);
      for (final l in ['hi', 'ml']) {
        expect(
          placeholders(arbs[l]![key] as String),
          expected,
          reason:
              'placeholder drift in "$key" ($l) — a dropped placeholder '
              'silently loses data on screen',
        );
      }
    }
  });

  test('no translation is left as its English source', () {
    // A handful of strings are deliberately identical in every language:
    // product names, endonyms, and marks printed on a button.
    const sameByDesign = {
      'appTitle',
      'sosLabel',
      'languageEnglish',
      'languageHindi',
      'languageMalayalam',
      // Pure structure: the pieces are translated, the message is not.
      'checkSemantics',
      'circlesWatcherRow',
      // Protocol names and unit abbreviations, printed the same everywhere.
      'circlesObserverSmsTag',
      'mapSpeedValue',
      'mapBatteryValue',
    };

    final untranslated = <String>[];
    for (final key in messageKeys(arbs['en']!)) {
      if (sameByDesign.contains(key)) continue;
      final en = arbs['en']![key] as String;
      for (final l in ['hi', 'ml']) {
        if (arbs[l]![key] == en) untranslated.add('$key ($l)');
      }
    }
    expect(untranslated, isEmpty, reason: 'still English: $untranslated');
  });

  test('Hindi is Devanagari and Malayalam is Malayalam script', () {
    // Transliteration ("aapaatkaal") passes every other check in this file and
    // is useless to the reader it is for, so the script itself is asserted.
    final devanagari = RegExp(r'[ऀ-ॿ]');
    final malayalam = RegExp(r'[ഀ-ൿ]');
    // Latin-only entries are legitimate for marks and endonyms; what is not
    // legitimate is a long sentence with no native script in it at all.
    const latinByDesign = {
      'appTitle',
      'sosLabel',
      'languageEnglish',
      'settingsIceCard',
      'circlesObserverSmsTag',
      'mapSpeedValue',
    };

    for (final key in messageKeys(arbs['en']!)) {
      if (latinByDesign.contains(key)) continue;
      final hi = arbs['hi']![key] as String;
      final ml = arbs['ml']![key] as String;
      if (RegExp(r'[A-Za-z]{4,}').hasMatch(hi.replaceAll(RegExp(r'\{[^}]*\}'), ''))) {
        expect(
          devanagari.hasMatch(hi),
          isTrue,
          reason: '"$key" (hi) looks transliterated, not Devanagari',
        );
      }
      if (RegExp(r'[A-Za-z]{4,}').hasMatch(ml.replaceAll(RegExp(r'\{[^}]*\}'), ''))) {
        expect(
          malayalam.hasMatch(ml),
          isTrue,
          reason: '"$key" (ml) looks transliterated, not Malayalam script',
        );
      }
    }
  });

  test('entries awaiting a native speaker are declared, not hidden', () {
    // Not a failure — a count, so the reviewer list in the build output can be
    // trusted and a silently-dropped flag shows up as a diff.
    var flagged = 0;
    for (final l in ['hi', 'ml']) {
      for (final entry in arbs[l]!.entries) {
        if (entry.key.startsWith('@') && entry.value is Map) {
          final meta = entry.value as Map;
          if (meta['x-needsReview'] == true) flagged++;
        }
      }
    }
    expect(flagged, greaterThan(0));
  });
}
