import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneInput extends StatefulWidget {
  const PhoneInput({super.key, required this.onSubmit, this.errorText});

  final ValueChanged<String> onSubmit;
  final String? errorText;

  @override
  State<PhoneInput> createState() => _PhoneInputState();
}

class _PhoneInputState extends State<PhoneInput> {
  final _controller = TextEditingController();
  static const _prefix = '+91';

  void _submit() {
    final digits = _controller.text.trim();
    if (digits.length == 10) {
      widget.onSubmit('$_prefix$digits');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('+91', style: TextStyle(fontSize: 16)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: 'Phone number',
        counterText: '',
        errorText: widget.errorText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
