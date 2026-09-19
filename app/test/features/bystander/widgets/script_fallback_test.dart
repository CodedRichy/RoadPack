import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/app_typography.dart';

/// Malayalam is the pilot region's first language and the bystander screen is
/// the last surface in the product where tofu is acceptable. These assertions
/// exist so a font can never be dropped from the bundle silently.
void main() {
  const malayalamFamily = 'NotoSansMalayalam';

  test('the fallback chain carries a Malayalam family', () {
    expect(AppType.fallback, contains(malayalamFamily));
    // Devanagari stays ahead of it: both families are probed in chain order.
    expect(
      AppType.fallback.indexOf('IBMPlexSansDevanagari'),
      lessThan(AppType.fallback.indexOf(malayalamFamily)),
    );
  });

  test('the Malayalam font is bundled, not fetched', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: $malayalamFamily'));
    expect(pubspec.contains('google_fonts'), isFalse);
    expect(
      File('assets/fonts/NotoSansMalayalam-Variable.ttf').existsSync(),
      isTrue,
      reason: 'Malayalam font asset is missing from the bundle',
    );
  });

  test('every bystander text role offers the fallback chain', () {
    final styles = <TextStyle>[
      AppType.bodyStyle(AppType.bodyMd),
      AppType.displayStyle(AppType.titleMd),
      AppType.eyebrow(AppType.labelMd),
      AppType.figure(AppType.bodyMd),
      AppType.readout(48),
    ];
    for (final style in styles) {
      expect(style.fontFamilyFallback, contains(malayalamFamily));
    }
  });
}
