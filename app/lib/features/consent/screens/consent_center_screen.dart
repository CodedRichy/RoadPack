import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/consent_ledger.dart';
import '../models/consent_type.dart';
import '../providers/consent_provider.dart';
import '../providers/tracking_gate_provider.dart';
import '../widgets/consent_toggle_tile.dart';
import '../widgets/tracking_gate_card.dart';

/// "What I have agreed to" — the revocation path FR-003 requires, because a
/// consent that cannot be withdrawn is not consent.
///
/// Everything here is a switch the user can move in both directions, and the
/// ledger below it shows what was recorded and when.
class ConsentCenterScreen extends ConsumerWidget {
  const ConsentCenterScreen({super.key, this.onOpenParentalConsent});

  /// Navigation is the router's job, not this screen's — the consent
  /// feature does not own `app_router.dart`.
  final VoidCallback? onOpenParentalConsent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.semantics;
    final l10n = context.l10n;
    final gate = ref.watch(trackingGateProvider);
    final ledger = ref.watch(consentLedgerProvider);
    final async = ref.watch(consentRecordsProvider);

    return Scaffold(
      backgroundColor: s.canvas,
      appBar: AppBar(title: Text(l10n.consentCentreTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.gutter,
          vertical: AppSpace.lg,
        ),
        children: [
          TrackingGateCard(
            gate: gate,
            onFixParentalConsent: onOpenParentalConsent,
          ),
          const SizedBox(height: AppSpace.xl),
          if (!ledger.isKnown)
            _UnknownLedgerNotice(
              onRetry: () =>
                  ref.read(consentRecordsProvider.notifier).refresh(),
              isLoading: async.isLoading,
            )
          else ...[
            Text(
              l10n.consentPermissionsHeading,
              style: AppType.displayStyle(
                AppType.titleSm,
                weight: FontWeight.w600,
              ).copyWith(color: s.textPrimary),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              l10n.consentPermissionsIntro,
              style: AppType.bodyStyle(
                AppType.bodySm,
              ).copyWith(color: s.textSecondary),
            ),
            const SizedBox(height: AppSpace.lg),
            for (final type in _userToggleableTypes)
              ConsentToggleTile(
                type: type,
                granted: ledger.isGranted(type),
                grantedAtLabel: _grantedLabel(ledger, type, l10n),
                onChanged: (value) => _toggle(ref, type, value),
              ),
            const SizedBox(height: AppSpace.lg),
            _ParentalSection(
              ledger: ledger,
              onRevoke: () => ref
                  .read(consentRecordsProvider.notifier)
                  .revokeAll(ConsentType.parental),
            ),
          ],
        ],
      ),
    );
  }

  /// [ConsentType.parental] is not in this list: a minor cannot grant their
  /// own parental consent, and it gets its own section with its own copy.
  static const List<ConsentType> _userToggleableTypes = [
    ConsentType.tracking,
    ConsentType.dataSharingAnon,
    ConsentType.sensorUpload,
    ConsentType.audioCapture,
  ];

  /// Formatted through `intl` in the active locale, not a fixed English
  /// month name.
  static String? _grantedLabel(
    ConsentLedger ledger,
    ConsentType type,
    AppLocalizations l10n,
  ) {
    final record = ledger.activeFor(type);
    if (record == null) return null;
    return l10n.consentGrantedOn(record.grantedAt.toLocal());
  }

  static void _toggle(WidgetRef ref, ConsentType type, bool value) {
    final notifier = ref.read(consentRecordsProvider.notifier);
    if (value) {
      notifier.grantSelf(type);
    } else {
      notifier.revokeAll(type);
    }
  }
}

class _ParentalSection extends StatelessWidget {
  const _ParentalSection({required this.ledger, required this.onRevoke});

  final ConsentLedger ledger;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final record = ledger.activeFor(ConsentType.parental);
    if (record == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: s.border,
          width: AppStroke.resolve(AppStroke.hairline, sunlight: s.isSunlight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsentType.parental.title(l10n),
            style: AppType.bodyStyle(
              AppType.bodyMd,
              weight: FontWeight.w600,
            ).copyWith(color: s.textPrimary),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            l10n.consentParentalSectionBody,
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          SizedBox(
            height: AppSpace.gloveTarget,
            child: OutlinedButton(
              onPressed: onRevoke,
              child: Text(l10n.consentWithdrawParentalAction),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnknownLedgerNotice extends StatelessWidget {
  const _UnknownLedgerNotice({required this.onRetry, required this.isLoading});

  final VoidCallback onRetry;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: s.attentionAccent,
          width: AppStroke.resolve(AppStroke.regular, sunlight: s.isSunlight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.consentUnknownLedgerTitle,
            style: AppType.bodyStyle(
              AppType.bodyMd,
              weight: FontWeight.w600,
            ).copyWith(color: s.textPrimary),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            l10n.consentUnknownLedgerBody,
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          SizedBox(
            height: AppSpace.gloveTarget,
            child: FilledButton(
              onPressed: isLoading ? null : onRetry,
              child: Text(
                isLoading ? l10n.consentChecking : l10n.consentTryAgain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
