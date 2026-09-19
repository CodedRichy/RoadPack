import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../widgets/parental_consent_form.dart';

/// Standalone route for the FR-003 parental flow, so a minor who skipped it
/// during onboarding can come back to it later.
class ParentalConsentScreen extends ConsumerWidget {
  const ParentalConsentScreen({super.key, this.onGranted});

  final VoidCallback? onGranted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.semantics;
    return Scaffold(
      backgroundColor: s.canvas,
      appBar: AppBar(title: Text(context.l10n.consentParentalScreenTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.gutter,
          vertical: AppSpace.lg,
        ),
        child: ParentalConsentForm(onGranted: onGranted),
      ),
    );
  }
}
