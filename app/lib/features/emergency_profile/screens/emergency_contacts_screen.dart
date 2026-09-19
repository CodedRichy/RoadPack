import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../models/emergency_contact.dart';
import '../providers/emergency_contact_actions_provider.dart';
import '../providers/emergency_contacts_provider.dart';
import '../services/emergency_contact_validator.dart';
import '../widgets/emergency_contact_tile.dart';

/// FR-020: manage the 1..5 priority-ordered emergency contacts.
class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.semantics;
    final contactsAsync = ref.watch(emergencyContactsProvider);
    final slotsLeft = ref.watch(emergencyContactSlotsLeftProvider);

    return Scaffold(
      backgroundColor: s.canvas,
      appBar: AppBar(title: Text(context.l10n.settingsEmergencyContacts)),
      floatingActionButton: slotsLeft > 0
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(context, ref),
              icon: const Icon(Icons.person_add_alt),
              label: Text(context.l10n.contactsAddButton),
            )
          : null,
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: AppSpace.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.contactsLoadError,
                  style: AppType.bodyStyle(
                    AppType.bodyMd,
                  ).copyWith(color: s.textPrimary),
                ),
                const SizedBox(height: AppSpace.md),
                FilledButton(
                  onPressed: () =>
                      ref.read(emergencyContactsProvider.notifier).refresh(),
                  child: Text(context.l10n.contactsRetry),
                ),
              ],
            ),
          ),
        ),
        data: (contacts) => _list(context, ref, contacts, slotsLeft),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<EmergencyContact> contacts,
    int slotsLeft,
  ) {
    final s = context.semantics;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.lg,
            AppSpace.gutter,
            AppSpace.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contacts.isEmpty
                    ? context.l10n.contactsEmptyHint
                    : context.l10n.contactsOrderHint,
                style: AppType.bodyStyle(
                  AppType.bodyMd,
                ).copyWith(color: s.textSecondary),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                context.l10n.contactsCountOfMax(
                  contacts.length,
                  EmergencyContactValidator.maxContacts,
                ),
                style: AppType.bodyStyle(
                  AppType.labelMd,
                ).copyWith(color: s.textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: contacts.isEmpty
              ? _empty(context)
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.sm,
                    AppSpace.gutter,
                    AppSpace.huge * 1.5,
                  ),
                  buildDefaultDragHandles: false,
                  itemCount: contacts.length,
                  onReorder: (oldIndex, newIndex) => _guard(
                    context,
                    () => ref
                        .read(emergencyContactActionsProvider)
                        .reorder(oldIndex: oldIndex, newIndex: newIndex),
                  ),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return EmergencyContactTile(
                      key: ValueKey(contact.id),
                      contact: contact,
                      index: index,
                      onEdit: () => _openEditor(context, ref, existing: contact),
                      onDelete: () => _confirmDelete(context, ref, contact),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final s = context.semantics;
    return Center(
      child: Padding(
        padding: AppSpace.screen,
        child: Text(
          context.l10n.contactsEmptyBody,
          textAlign: TextAlign.center,
          style: AppType.bodyStyle(
            AppType.bodyMd,
          ).copyWith(color: s.textMuted),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact contact,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.contactsRemoveConfirmTitle(contact.name)),
        content: Text(context.l10n.contactsRemoveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.contactsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.contactsRemoveButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _guard(
      context,
      () => ref
          .read(emergencyContactActionsProvider)
          .removeContact(contact.id),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    EmergencyContact? existing,
  }) async {
    final result = await showModalBottomSheet<_ContactDraft>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ContactEditorSheet(existing: existing),
    );
    if (result == null || !context.mounted) return;

    final ownerName =
        ref.read(userProfileProvider).valueOrNull?.name ?? 'A RoadPack rider';

    await _guard(context, () async {
      if (existing != null) {
        await ref
            .read(emergencyContactActionsProvider)
            .editContact(
              contactId: existing.id,
              name: result.name,
              phone: result.phone,
              relationship: result.relationship ?? '',
              alertMethods: result.alertMethods,
            );
        return;
      }

      await ref
          .read(emergencyContactActionsProvider)
          .addContact(
            name: result.name,
            phone: result.phone,
            relationship: result.relationship,
            alertMethods: result.alertMethods,
          );
      // FR-024: tell them once that they were listed. Fire-and-forget —
      // a failed SMS must not block the user finishing their profile.
      unawaited(
        ref
            .read(emergencyContactActionsProvider)
            .sendPendingListedNotices(listedByName: ownerName)
            .catchError((Object _) => 0),
      );
    });
  }

  Future<void> _guard(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await action();
    } on EmergencyContactException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not save. Try again.')),
      );
    }
  }
}

class _ContactDraft {
  const _ContactDraft({
    required this.name,
    required this.phone,
    this.relationship,
    required this.alertMethods,
  });

  final String name;
  final String phone;
  final String? relationship;
  final Set<AlertMethod> alertMethods;
}

class _ContactEditorSheet extends StatefulWidget {
  const _ContactEditorSheet({this.existing});

  /// Null for "add", set for "edit". The validation path is identical either
  /// way — an edit is just an add that already has an id.
  final EmergencyContact? existing;

  @override
  State<_ContactEditorSheet> createState() => _ContactEditorSheetState();
}

class _ContactEditorSheetState extends State<_ContactEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _relationship = TextEditingController();
  late final Set<AlertMethod> _methods;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _methods = {...existing?.alertMethods ?? AlertMethod.defaults};
    if (existing != null) {
      _name.text = existing.name;
      // Shown without the +91 the field already prefixes.
      _phone.text = existing.phone.startsWith('+91')
          ? existing.phone.substring(3)
          : existing.phone;
      _relationship.text = existing.relationship ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.gutter,
        right: AppSpace.gutter,
        top: AppSpace.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit
                  ? context.l10n.contactsEditTitle
                  : context.l10n.contactsAddTitle,
              style: AppType.displayStyle(
                AppType.titleSm,
              ).copyWith(color: s.textPrimary),
            ),
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.l10n.commonName),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? EmergencyContactError.missingName.message
                  : null,
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: context.l10n.contactsPhoneLabel,
                prefixText: '+91 ',
              ),
              validator: (v) =>
                  EmergencyContactValidator.normalisePhone(v ?? '') == null
                  ? EmergencyContactError.invalidPhone.message
                  : null,
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _relationship,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.l10n.contactsRelationshipLabel,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              context.l10n.contactsHowWeReachThem,
              style: AppType.eyebrow(
                AppType.labelSm,
              ).copyWith(color: s.textSecondary),
            ),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              children: [
                for (final m in AlertMethod.values)
                  FilterChip(
                    label: Text(m.displayName),
                    selected: _methods.contains(m),
                    onSelected: (on) => setState(() {
                      on ? _methods.add(m) : _methods.remove(m);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              _isEdit
                  ? context.l10n.contactsEditHint
                  : context.l10n.contactsAddHint,
              style: AppType.bodyStyle(
                AppType.bodySm,
              ).copyWith(color: s.textSecondary),
            ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              height: AppSpace.gloveTarget,
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(
                  _isEdit
                      ? context.l10n.contactsSaveButton
                      : context.l10n.contactsAddButton,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _ContactDraft(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        relationship: _relationship.text.trim().isEmpty
            ? null
            : _relationship.text.trim(),
        alertMethods: _methods.isEmpty
            ? {...AlertMethod.defaults}
            : {..._methods},
      ),
    );
  }
}
