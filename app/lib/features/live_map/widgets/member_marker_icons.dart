import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'member_marker_spec.dart';

/// Draws member markers as flat discs rather than using Google's pin art.
///
/// Two reasons this is worth the code. First, Google's `defaultMarkerWithHue`
/// can only produce saturated hues, so a stale member could never actually be
/// *grey* — only a washed-out blue, which still reads as "connected". Second,
/// a live member gets a solid disc and a stale one gets a hollow ring, so the
/// distinction survives greyscale and direct sunlight instead of resting on
/// colour alone.
class MemberMarkerIcons {
  const MemberMarkerIcons._();

  static final Map<String, BitmapDescriptor> _cache = {};

  static String _key(MemberMarkerSpec spec, double dpr) =>
      '${spec.presence.state}/${spec.color.toARGB32()}/'
      '${spec.opacity}/${dpr.toStringAsFixed(1)}';

  static Future<BitmapDescriptor> forSpec(
    MemberMarkerSpec spec, {
    double devicePixelRatio = 2,
  }) async {
    final key = _key(spec, devicePixelRatio);
    final cached = _cache[key];
    if (cached != null) return cached;

    final bytes = await _paint(spec, devicePixelRatio);
    final icon = BitmapDescriptor.bytes(
      bytes,
      imagePixelRatio: devicePixelRatio,
    );
    _cache[key] = icon;
    return icon;
  }

  static Future<Uint8List> _paint(
    MemberMarkerSpec spec,
    double devicePixelRatio,
  ) async {
    const logicalSize = 32.0;
    final size = logicalSize * devicePixelRatio;
    final radius = size / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final color = spec.color.withValues(alpha: spec.opacity);

    if (spec.isLive) {
      // Solid disc with a light halo: present and reporting.
      canvas.drawCircle(
        Offset(radius, radius),
        radius * 0.92,
        Paint()..color = color.withValues(alpha: spec.opacity * 0.22),
      );
      canvas.drawCircle(
        Offset(radius, radius),
        radius * 0.55,
        Paint()..color = color,
      );
    } else {
      // Hollow ring: the last place we heard from, not a live position.
      canvas.drawCircle(
        Offset(radius, radius),
        radius * 0.55,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.08,
      );
    }

    final image = await recorder.endRecording().toImage(
      size.round(),
      size.round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}
