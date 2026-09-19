import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/pack_status.dart';
import '../widgets/pack_status_chip.dart' show packStatusLabel;

/// What the picker hands back.
@immutable
class PackStatusChoice {
  const PackStatusChoice(this.status, [this.note]);

  final PackStatus status;
  final String? note;
}

/// The status picker (PM-32).
///
/// Design constraints are all ergonomic, and they are the reason the status
/// set is a fixed enum rather than free text. A rider using this is stopped at
/// the roadside in gloves, possibly in rain, possibly with the engine running
/// and a pack waiting. So: one tap from the ride screen to here, one tap to
/// commit — never more — and every target is [AppSpace.gloveTarget], not the
/// 48dp Material assumes for a bare fingertip.
///
/// The automatic-only statuses are absent by construction: the grid is built
/// from [PackStatus.settable]. A rider cannot declare a possible incident, and
/// the app cannot be made to lie about one by a stray tap.
class PackStatusSheet extends StatefulWidget {
  const PackStatusSheet({super.key, this.current, this.currentNote});

  final PackStatus? current;
  final String? currentNote;

  static Future<PackStatusChoice?> show(
    BuildContext context, {
    PackStatus? current,
    String? currentNote,
  }) {
    return showModalBottomSheet<PackStatusChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.semantics.surface1,
      builder: (_) =>
          PackStatusSheet(current: current, currentNote: currentNote),
    );
  }

  @override
  State<PackStatusSheet> createState() => _PackStatusSheetState();
}

class _PackStatusSheetState extends State<PackStatusSheet> {
  late final TextEditingController _note = TextEditingController(
    text: widget.currentNote ?? '',
  );
  bool _noteOpen = false;

  @override
  void initState() {
    super.initState();
    _noteOpen = (widget.currentNote ?? '').isNotEmpty;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _commit(PackStatus status) {
    final note = _note.text.trim();
    Navigator.of(
      context,
    ).pop(PackStatusChoice(status, note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final statuses = PackStatus.settable;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.gutter,
          right: AppSpace.gutter,
          top: AppSpace.lg,
          bottom: AppSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.packTellPack,
                style: AppType.displayStyle(
                  AppType.titleSm,
                ).copyWith(color: s.textPrimary),
              ),
              const SizedBox(height: AppSpace.lg),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: AppSpace.sm,
                crossAxisSpacing: AppSpace.sm,
                // A fixed row height rather than an aspect ratio: on a wide
                // screen a ratio inflates the cells until the grid no longer
                // fits, and this control has to survive every viewport the
                // sheet can be opened on. 92 clears AppSpace.gloveTarget.
                mainAxisExtent: 92,
                children: [
                  for (final status in statuses)
                    _StatusButton(
                      status: status,
                      selected: status == widget.current,
                      onPressed: () => _commit(status),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              if (!_noteOpen)
                TextButton.icon(
                  onPressed: () => setState(() => _noteOpen = true),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, AppSpace.tapTarget),
                    foregroundColor: s.textSecondary,
                  ),
                  icon: const Icon(Icons.notes, size: 18),
                  label: Text(l10n.packAddNoteAction),
                )
              else
                TextField(
                  controller: _note,
                  maxLength: 140,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(140)],
                  style: AppType.bodyStyle(AppType.bodyMd),
                  decoration: InputDecoration(
                    labelText: l10n.packNoteLabel,
                    hintText: l10n.packNoteHint,
                  ),
                ),
              const SizedBox(height: AppSpace.sm),
              Text(
                l10n.packShareHonestyNotice,
                style: AppType.bodyStyle(
                  AppType.labelMd,
                ).copyWith(color: s.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.status,
    required this.selected,
    required this.onPressed,
  });

  final PackStatus status;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final icon = _iconFor(status);
    final label = packStatusLabel(status, l10n);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: Key('pack-status-pick-${status.wire}'),
        onTap: onPressed,
        borderRadius: AppRadius.mdAll,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: AppSpace.gloveTarget,
            minHeight: AppSpace.gloveTarget,
          ),
          decoration: BoxDecoration(
            color: selected ? s.surface3 : s.surface2,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: selected ? s.protectedAccent : s.hairline,
              width: AppStroke.resolve(
                selected ? AppStroke.heavy : AppStroke.hairline,
                sunlight: s.isSunlight,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? s.protectedAccent : s.textSecondary,
              ),
              const SizedBox(height: AppSpace.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyStyle(
                    AppType.labelMd,
                    weight: FontWeight.w600,
                  ).copyWith(color: s.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(PackStatus status) => switch (status) {
    PackStatus.riding => Icons.two_wheeler,
    PackStatus.refueling => Icons.local_gas_station,
    PackStatus.takingBreak => Icons.local_cafe,
    PackStatus.wrongTurn => Icons.u_turn_left,
    PackStatus.waiting => Icons.hourglass_bottom,
    PackStatus.stopped => Icons.pause_rounded,
    PackStatus.done => Icons.flag,
    _ => Icons.help_outline,
  };
}
