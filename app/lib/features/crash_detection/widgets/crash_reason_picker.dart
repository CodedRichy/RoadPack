import 'package:flutter/material.dart';

class CrashReasonPicker extends StatefulWidget {
  const CrashReasonPicker({super.key});

  @override
  State<CrashReasonPicker> createState() => _CrashReasonPickerState();
}

class _CrashReasonPickerState extends State<CrashReasonPicker> {
  String? _selectedReason;
  final _otherController = TextEditingController();

  static const _reasons = [
    'Pothole / speed bump',
    'Phone dropped',
    'Sudden braking',
    'Other',
  ];

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'What happened?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          RadioGroup<String>(
            groupValue: _selectedReason ?? '',
            onChanged: (v) => setState(() => _selectedReason = v),
            child: Column(
              children: _reasons
                  .map(
                    (reason) => RadioListTile<String>(
                      title: Text(reason),
                      value: reason,
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_selectedReason == 'Other')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _otherController,
                decoration: const InputDecoration(
                  hintText: 'Describe what happened',
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
                      final reason = _selectedReason == 'Other'
                          ? _otherController.text.isNotEmpty
                              ? _otherController.text
                              : 'Other'
                          : _selectedReason!;
                      Navigator.of(context).pop(reason);
                    }
                  : null,
              child: const Text("Confirm - I'm Fine"),
            ),
          ),
        ],
      ),
    );
  }
}
