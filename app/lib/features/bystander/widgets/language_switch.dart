import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../models/bystander_lang.dart';

/// Three chips. The reader is a stranger, so the language choice cannot be
/// buried in settings they will never reach on a phone they cannot unlock.
class BystanderLanguageSwitch extends StatelessWidget {
  const BystanderLanguageSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final BystanderLang value;
  final ValueChanged<BystanderLang> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    return Row(
      children: [
        for (final lang in BystanderLang.values)
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.sm),
            child: Semantics(
              button: true,
              selected: lang == value,
              label: lang.nativeName,
              child: SizedBox(
                height: AppSpace.tapTarget,
                child: Material(
                  color: lang == value ? s.onEmergency : Colors.transparent,
                  borderRadius: AppRadius.pillAll,
                  child: InkWell(
                    borderRadius: AppRadius.pillAll,
                    onTap: () => onChanged(lang),
                    child: Container(
                      alignment: Alignment.center,
                      constraints: const BoxConstraints(minWidth: 56),
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.pillAll,
                        border: Border.all(
                          color: s.onEmergency,
                          width: AppStroke.resolve(
                            AppStroke.regular,
                            sunlight: s.isSunlight,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                      ),
                      child: Text(
                        lang.chip,
                        style: AppType.bodyStyle(
                          AppType.bodyMd,
                          weight: FontWeight.w600,
                        ).copyWith(
                          color: lang == value ? s.emergencyDeep : s.onEmergency,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
