import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../providers/consent_provider.dart';
import '../services/parental_verification.dart';

/// FR-003 / DPDPA C6: collect the parent or guardian's details, run whatever
/// verification method is plugged in, and only then write the `parental`
/// consent row.
///
/// The form deliberately does not decide whether the verification is good
/// enough — that is [ParentalVerifier]'s job, and in this build the shipped
/// verifier refuses. The honest message that comes back is shown as-is
/// rather than softened.
class ParentalConsentForm extends ConsumerStatefulWidget {
  const ParentalConsentForm({super.key, this.onGranted});

  /// Called only after a consent record actually exists.
  final VoidCallback? onGranted;

  @override
  ConsumerState<ParentalConsentForm> createState() =>
      _ParentalConsentFormState();
}

class _ParentalConsentFormState extends ConsumerState<ParentalConsentForm> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationController = TextEditingController();

  bool _submitting = false;
  String? _message;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _message = null;
    });

    final result = await ref
        .read(consentRecordsProvider.notifier)
        .requestParentalConsent(
          ParentalDeclaration(
            parentName: _nameController.text,
            parentPhone: _phoneController.text,
            relationship: _relationController.text,
          ),
        );

    if (!mounted) return;
    final message = result.plainMessage(context.l10n);
    setState(() {
      _submitting = false;
      _message = message;
    });
    if (result.isVerified) widget.onGranted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final verifier = ref.watch(parentalVerifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.consentParentalFormIntro,
          style: AppType.bodyStyle(
            AppType.bodySm,
          ).copyWith(color: s.textSecondary),
        ),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.consentParentalNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: l10n.consentParentalPhoneLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        TextField(
          controller: _relationController,
          decoration: InputDecoration(
            labelText: l10n.consentParentalRelationLabel,
            hintText: l10n.consentParentalRelationHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          l10n.consentParentalMethodLine(verifier.methodDescription(l10n)),
          style: AppType.bodyStyle(
            AppType.labelMd,
          ).copyWith(color: s.textMuted),
        ),
        const SizedBox(height: AppSpace.lg),
        SizedBox(
          height: AppSpace.gloveTarget,
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              _submitting
                  ? l10n.consentChecking
                  : l10n.consentParentalSubmitAction,
            ),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: AppSpace.md),
          Text(
            _message!,
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.attentionAccent),
          ),
        ],
      ],
    );
  }
}
