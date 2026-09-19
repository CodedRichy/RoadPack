import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../models/bystander_copy.dart';
import '../models/bystander_lang.dart';
import 'bystander_section.dart';

/// FR-092.
///
/// On a hazard band rather than the emergency tier: this is the one block on
/// the screen that exists to *remove* fear, and the reason many bystanders in
/// India walk past a crash is the belief that helping means police trouble.
class GoodSamaritanNotice extends StatelessWidget {
  const GoodSamaritanNotice({super.key, required this.lang});

  final BystanderLang lang;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    return BystanderSection(
      background: s.hazardBand,
      borderColour: s.onHazard,
      foreground: s.onHazard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            BystanderCopy.samaritanHeading(lang),
            style: AppType.displayStyle(
              AppType.bodyLg,
              weight: FontWeight.w700,
            ).copyWith(color: s.onHazard),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            BystanderCopy.samaritanBody(lang),
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.onHazard),
          ),
        ],
      ),
    );
  }
}
