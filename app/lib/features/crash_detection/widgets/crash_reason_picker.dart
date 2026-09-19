import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class CrashReasonPicker extends StatefulWidget {
  const CrashReasonPicker({super.key});

  @override
  State<CrashReasonPicker> createState() => _CrashReasonPickerState();
}

/// The cancel reasons, as values rather than strings.
///
/// The reason travels to the incident record, so it must not change meaning
/// when the rider changes language: the enum name is what is stored, the
/// label is only what is shown.
enum CrashCancelReason { pothole, phoneDropped, suddenBraking, other }

extension CrashCancelReasonLabel on CrashCancelReason {
  String label(AppLocalizations l10n) => switch (this) {
    CrashCancelReason.pothole => l10n.crashReasonPothole,
    CrashCancelReason.phoneDropped => l10n.crashReasonPhoneDropped,
    CrashCancelReason.suddenBraking => l10n.crashReasonSuddenBraking,
    CrashCancelReason.other => l10n.crashReasonOther,
  };
}

class _CrashReasonPickerState extends State<CrashReasonPicker> {
  CrashCancelReason? _selectedReason;
  final _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.crashReasonQuestion,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          RadioGroup<CrashCancelReason?>(
            groupValue: _selectedReason,
            onChanged: (v) => setState(() => _selectedReason = v),
            child: Column(
              children: CrashCancelReason.values
                  .map(
                    (reason) => RadioListTile<CrashCancelReason?>(
                      title: Text(reason.label(l10n)),
                      value: reason,
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_selectedReason == CrashCancelReason.other)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _otherController,
                decoration: InputDecoration(
                  hintText: l10n.crashReasonOtherHint,
                ),
                maxLines: 2,
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _selectedReason != null
                  ? () {
                      // What is stored is the stable enum name, or the
                      // rider's own words. Never a localised label: a reason
                      // read back in another language would be unusable.
                      final reason =
                          _selectedReason == CrashCancelReason.other &&
                              _otherController.text.isNotEmpty
                          ? _otherController.text
                          : _selectedReason!.name;
                      Navigator.of(context).pop(reason);
                    }
                  : null,
              child: Text(l10n.crashReasonConfirm),
            ),
          ),
        ],
      ),
    );
  }
}
