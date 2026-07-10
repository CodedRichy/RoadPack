import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InviteCodeInput extends StatefulWidget {
  const InviteCodeInput({
    super.key,
    required this.onCompleted,
    this.errorText,
  });

  final ValueChanged<String> onCompleted;
  final String? errorText;

  @override
  State<InviteCodeInput> createState() => _InviteCodeInputState();
}

class _InviteCodeInputState extends State<InviteCodeInput> {
  static const _length = 6;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_length, (_) => TextEditingController());
    _focusNodes = List.generate(_length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    final code = _controllers.map((c) => c.text).join();
    if (code.length == _length) {
      widget.onCompleted(code.toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_length, (i) {
            return SizedBox(
              width: 44,
              child: TextField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                textAlign: TextAlign.center,
                maxLength: 1,
                textCapitalization: TextCapitalization.none,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                onChanged: (v) => _onChanged(i, v),
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
            );
          }),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
