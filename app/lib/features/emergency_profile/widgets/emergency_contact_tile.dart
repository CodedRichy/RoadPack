import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/emergency_contact.dart';

/// One row in the emergency-contact list.
///
/// The priority chip is deliberately neutral. Contact order is a *sequence*,
/// not a severity — colouring position 1 red would borrow the emergency tier
/// for something that is not an emergency, and would make positions 2..5 read
/// as "less important people" rather than "later in the cascade".
class EmergencyContactTile extends StatelessWidget {
  const EmergencyContactTile({
    super.key,
    required this.contact,
    required this.index,
    this.onEdit,
    this.onDelete,
    this.showDragHandle = true,
  });

  final EmergencyContact contact;

  /// Position in the reorderable list, used for the drag handle.
  final int index;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      decoration: BoxDecoration(
        color: s.surface1,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: s.hairline,
          width: AppStroke.resolve(AppStroke.hairline, sunlight: s.isSunlight),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      child: Row(
        children: [
          Container(
            width: AppSpace.xxl,
            height: AppSpace.xxl,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.surface2,
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              '${contact.priority}',
              style: AppType.figure(
                AppType.bodyMd,
              ).copyWith(color: s.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contact.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyStyle(
                    AppType.bodyMd,
                    weight: FontWeight.w600,
                  ).copyWith(color: s.textPrimary),
                ),
                Text(
                  [
                    if (contact.relationship != null &&
                        contact.relationship!.isNotEmpty)
                      contact.relationship!,
                    contact.phone,
                  ].join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyStyle(
                    AppType.bodySm,
                  ).copyWith(color: s.textSecondary),
                ),
                _noticeStatus(context, s),
              ],
            ),
          ),
          if (onDelete != null)
            // gloveTarget: this is pressed at a roadside, kitted up.
            SizedBox(
              width: AppSpace.gloveTarget,
              height: AppSpace.gloveTarget,
              child: IconButton(
                icon: const Icon(Icons.delete_outline),
                color: s.textSecondary,
                tooltip: context.l10n.contactsRemoveTooltip(contact.name),
                onPressed: onDelete,
              ),
            ),
          if (showDragHandle)
            ReorderableDragStartListener(
              index: index,
              child: SizedBox(
                width: AppSpace.gloveTarget,
                height: AppSpace.gloveTarget,
                child: Icon(Icons.drag_handle, color: s.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _noticeStatus(BuildContext context, AppSemantics s) {
    final String text;
    if (contact.optedOut) {
      // Honest, not euphemistic: this person will not be texted.
      text = context.l10n.contactsOptedOut;
    } else if (contact.isNotified) {
      text = context.l10n.contactsNoticeSent;
    } else {
      text = context.l10n.contactsNoticePending;
    }
    return Text(
      text,
      style: AppType.bodyStyle(AppType.labelSm).copyWith(
        color: contact.optedOut ? s.attentionAccent : s.textMuted,
      ),
    );
  }
}
