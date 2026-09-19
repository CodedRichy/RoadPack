import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/theme.dart';
import '../models/ice_profile.dart';

/// The ICE payload as a scannable symbol (FR-094).
///
/// Takes an [IceQrPayload], which can only be built by
/// [IceQrPayload.forSession] on an active incident -- so the gate is in the
/// type system, not in a runtime flag this widget could get wrong.
///
/// Encoded on device. It never fetches: a symbol that needs a network is
/// useless at the moment it is needed.
class IceQrSymbol extends StatelessWidget {
  const IceQrSymbol({super.key, required this.payload});

  final IceQrPayload payload;

  /// Sized against the viewport's short edge rather than a fixed dp value.
  /// This gets photographed off a cracked screen at arm's length, and a
  /// symbol a third of the phone wide scans where a 120dp one does not.
  static double sizeFor(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    return math.min(math.max(shortest * 0.62, 160), 320);
  }

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: payload.data,
      version: QrVersions.auto,
      size: sizeFor(context),
      // Highest level: tolerates roughly 30% of the symbol being lost to a
      // crack, glare, or a smeared screen.
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      // Generous quiet zone. Scanners fail on symbols that run to the edge
      // of a coloured surface.
      padding: const EdgeInsets.all(AppSpace.lg),
      // Deliberately NOT theme-tinted. A scanner needs maximum luminance
      // contrast on both paths, so the plate stays paper and the modules
      // stay ink whichever theme is live.
      backgroundColor: AppColors.paper,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: AppColors.hazardInk,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: AppColors.hazardInk,
      ),
      semanticsLabel: 'Emergency medical information QR code',
    );
  }
}
