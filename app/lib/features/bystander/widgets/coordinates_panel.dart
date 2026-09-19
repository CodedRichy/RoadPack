import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../models/bystander_copy.dart';
import '../models/bystander_lang.dart';
import '../models/bystander_session.dart';
import 'bystander_section.dart';

/// FR-110: coordinates in a form a human can read down a phone line.
///
/// There is no automatic data push to 112 -- no public ERSS API exists -- and
/// the copy here says so out loud rather than letting the reader assume the
/// app has already told someone.
class CoordinatesPanel extends StatelessWidget {
  const CoordinatesPanel({
    super.key,
    required this.session,
    required this.lang,
  });

  final BystanderSession session;
  final BystanderLang lang;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final coords = session.readableCoordinates;

    return BystanderSection(
      heading: BystanderCopy.locationHeading(lang),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coords == null)
            Text(
              BystanderCopy.noFix(lang),
              style: AppType.bodyStyle(
                AppType.bodyMd,
              ).copyWith(color: s.attentionAccent),
            )
          else ...[
            Text(
              coords,
              style: AppType.figure(
                AppType.titleSm,
                weight: FontWeight.w700,
              ).copyWith(color: s.textPrimary),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              _provenance(),
              style: AppType.bodyStyle(
                AppType.bodySm,
              ).copyWith(color: s.textMuted),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          Text(
            BystanderCopy.readAloud(lang),
            style: AppType.bodyStyle(
              AppType.bodySm,
              weight: FontWeight.w600,
            ).copyWith(color: s.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Fix age and accuracy are stated, never smoothed away. A position the
  /// reader trusts more than it deserves sends help to the wrong kilometre.
  String _provenance() {
    final parts = <String>[];
    final at = session.locationAt;
    if (at != null) {
      final mins = DateTime.now().toUtc().difference(at.toUtc()).inMinutes;
      parts.add(mins <= 1 ? 'fix taken just now' : 'fix taken ${mins}m ago');
    }
    final acc = session.accuracyMeters;
    if (acc != null) parts.add('accurate to about ${acc.round()} m');
    return parts.isEmpty ? 'fix age unknown' : parts.join(' - ');
  }
}
