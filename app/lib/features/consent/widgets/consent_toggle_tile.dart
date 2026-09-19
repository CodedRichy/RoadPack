import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/consent_type.dart';

/// One consent, in the user's language, with the switch that changes it.
///
/// Attention tier at most. Consent is not an emergency, and borrowing the
/// SOS colour here would spend the one signal the app has for a crash.
class ConsentToggleTile extends StatelessWidget {
  const ConsentToggleTile({
    super.key,
    required this.type,
    required this.granted,
    required this.onChanged,
    this.grantedAtLabel,
    this.enabled = true,
    this.lockedReason,
  });

  final ConsentType type;
  final bool granted;
  final ValueChanged<bool> onChanged;

  /// e.g. "You said yes on 4 March 2026". Shown only when granted.
  final String? grantedAtLabel;

  final bool enabled;

  /// Why the control is unavailable, in plain words. A disabled switch with
  /// no explanation reads as a bug.
  final String? lockedReason;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: granted ? s.protectedAccent : s.border,
          width: AppStroke.resolve(AppStroke.hairline, sunlight: s.isSunlight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  type.title(context.l10n),
                  style: AppType.bodyStyle(
                    AppType.bodyMd,
                    weight: FontWeight.w600,
                  ).copyWith(color: s.textPrimary),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              SizedBox(
                height: AppSpace.gloveTarget,
                child: Center(
                  child: Switch(
                    value: granted,
                    onChanged: enabled ? onChanged : null,
                  ),
                ),
              ),
            ],
          ),
          Text(
            type.plainMeaning(context.l10n),
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textSecondary),
          ),
          if (granted && grantedAtLabel != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              grantedAtLabel!,
              style: AppType.bodyStyle(
                AppType.labelMd,
              ).copyWith(color: s.textMuted),
            ),
          ],
          if (!enabled && lockedReason != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              lockedReason!,
              style: AppType.bodyStyle(
                AppType.labelMd,
              ).copyWith(color: s.attentionAccent),
            ),
          ],
        ],
      ),
    );
  }
}
