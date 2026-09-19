import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../bystander/models/bystander_session.dart';
import '../../bystander/providers/bystander_providers.dart';
import '../../bystander/screens/bystander_screen.dart';
import '../../bystander/services/bystander_actions.dart';
import '../../emergency_profile/models/emergency_contact.dart';
import '../../emergency_profile/providers/emergency_contacts_provider.dart';

/// "See what a bystander sees."
///
/// This is the one screen the owner will never meet in normal use — it is
/// reached by a stranger holding their phone after a crash. So the only way
/// they will ever notice that their emergency contact is missing, their blood
/// group is blank, or the first-aid copy is in the wrong language is if they
/// can deliberately look at it.
///
/// Three things this must never do:
///
/// 1. **Fabricate an incident.** The sample session is `incidentActive: false`
///    and lives only in this route's `ProviderScope`. No incident state is
///    written anywhere; nothing outside this widget can observe it.
/// 2. **Weaken the ICE gate.** [IceQrPayload.forSession] keeps returning null
///    for the sample, so the real ICE card simply does not render. Rather than
///    working around that, the preview says the card is sealed and summarises
///    what it would carry — the owner's own data, shown to the owner, inside
///    their own settings.
/// 3. **Do anything.** Every action is wired to an inert launcher, because a
///    preview that can dial 112 is worse than no preview at all.
class BystanderPreviewScreen extends ConsumerWidget {
  const BystanderPreviewScreen({super.key});

  static const bannerKey = ValueKey('bystander-preview.banner');
  static const sealedIceKey = ValueKey('bystander-preview.sealed-ice');

  /// Deliberately not an incident id shape. Nothing consumes it, but if it
  /// ever leaked into a log it should read as what it is.
  static const previewIncidentId = 'preview-not-an-incident';

  /// Swallows every platform intent. Returns false, which is what
  /// [BystanderActions] already reports when a launch does not happen.
  static Future<bool> inertLauncher(Uri uri) async => false;

  /// The bystander's three actions, disarmed.
  static BystanderActions previewActions() =>
      BystanderActions(launcher: inertLauncher);

  /// A sample session built from the rider's *real* profile, so the preview
  /// is a mirror rather than a mock-up.
  ///
  /// - `incidentActive: false` — the ICE gate stays shut on its own terms.
  /// - `ice: null` — the medical payload is not merely gated, it is never
  ///   assembled into the session at all.
  /// - no coordinates — the app does not invent a position it does not have,
  ///   and a preview is no exception.
  static BystanderSession sampleSession({
    required String? name,
    EmergencyContact? contact,
  }) {
    return BystanderSession(
      incidentId: previewIncidentId,
      incidentActive: false,
      victimDisplayName: (name == null || name.trim().isEmpty)
          ? 'You'
          : name.trim(),
      contactName: contact?.name,
      contactPhone: contact?.phone,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.semantics;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final contacts = ref.watch(emergencyContactsProvider).valueOrNull ?? const [];

    final session = sampleSession(
      name: profile?.name,
      contact: contacts.isEmpty ? null : contacts.first,
    );

    return Scaffold(
      backgroundColor: s.canvas,
      appBar: AppBar(title: const Text('What a bystander sees')),
      body: Column(
        children: [
          const _PreviewBanner(),
          Expanded(
            child: ProviderScope(
              overrides: [
                bystanderSessionProvider.overrideWithValue(session),
                bystanderActionsProvider.overrideWithValue(previewActions()),
              ],
              child: Column(
                children: [
                  const Expanded(child: BystanderScreen()),
                  _SealedIceNote(profile: profile, contactCount: contacts.length),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Attention tier, not emergency: this is a gap in the rider's understanding,
/// not an incident. The band is edge to edge and stays put while the screen
/// below it scrolls, so the preview can never be screenshotted or glanced at
/// without it.
class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;

    return Container(
      key: BystanderPreviewScreen.bannerKey,
      width: double.infinity,
      color: s.attentionAccent,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.gutter,
        vertical: AppSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREVIEW',
            style: AppType.eyebrow(
              AppType.labelMd,
            ).copyWith(color: AppColors.paper),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'No emergency is in progress. Nobody has been alerted. This is '
            'what someone holding your phone would see after a crash.',
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: AppColors.paper),
          ),
        ],
      ),
    );
  }
}

/// The ICE card is absent above because the gate returned nothing, which is
/// correct. Saying so — and summarising what it would carry — is the whole
/// point of letting the owner look.
class _SealedIceNote extends StatelessWidget {
  const _SealedIceNote({required this.profile, required this.contactCount});

  final UserProfile? profile;
  final int contactCount;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final blood = profile?.bloodGroup;
    final notes = profile?.medicalNotes;

    final missing = <String>[
      if (blood == null || blood.isEmpty) 'blood group',
      if (contactCount == 0) 'emergency contacts',
    ];

    return Container(
      key: BystanderPreviewScreen.sealedIceKey,
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: s.surface2,
        border: Border(
          top: BorderSide(
            color: s.border,
            width: AppStroke.resolve(
              AppStroke.regular,
              sunlight: s.isSunlight,
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ICE CARD — SEALED',
            style: AppType.eyebrow(AppType.labelMd).copyWith(color: s.textMuted),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Your medical card is not shown above, and that is correct: it '
            'unlocks only during a live incident. In a real crash it would '
            'carry your blood group, medical notes and contacts.',
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textSecondary),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            missing.isEmpty
                ? 'Ready: blood group ${blood!}, $contactCount '
                      '${contactCount == 1 ? 'contact' : 'contacts'}'
                      '${(notes == null || notes.isEmpty) ? '' : ', medical notes'}.'
                : 'Missing: ${missing.join(' and ')}. A responder would see '
                      'nothing under those headings.',
            style: AppType.bodyStyle(
              AppType.bodySm,
              weight: FontWeight.w600,
            ).copyWith(
              color: missing.isEmpty ? s.protectedAccent : s.attentionAccent,
            ),
          ),
        ],
      ),
    );
  }
}
