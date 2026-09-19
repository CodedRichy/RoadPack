import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../models/bystander_copy.dart';
import '../models/bystander_lang.dart';
import '../models/first_aid.dart';
import 'bystander_section.dart';

/// FR-093.
///
/// Prohibitions come first and carry the attention accent, because the
/// commonest bystander harm is moving the casualty, not standing still.
/// Content is DRAFT until a qualified emergency physician signs it off; the
/// review banner stays on screen until then.
class FirstAidCard extends StatelessWidget {
  const FirstAidCard({super.key, required this.lang});

  final BystanderLang lang;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final steps = [
      ...FirstAidGuidance.steps.where((e) => e.isProhibition),
      ...FirstAidGuidance.steps.where((e) => !e.isProhibition),
    ];

    return BystanderSection(
      heading: BystanderCopy.firstAidHeading(lang),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      step.isProhibition
                          ? Icons.block_outlined
                          : Icons.check_circle_outline,
                      size: 20,
                      color: step.isProhibition
                          ? s.attentionAccent
                          : s.protectedAccent,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Text(
                      step.text(lang),
                      style: AppType.bodyStyle(
                        AppType.bodyMd,
                        weight: step.isProhibition
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ).copyWith(color: s.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            BystanderCopy.notMedicalAdvice(lang),
            style: AppType.bodyStyle(
              AppType.labelMd,
            ).copyWith(color: s.textMuted),
          ),
        ],
      ),
    );
  }
}
