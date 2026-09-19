import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/app_colors.dart';
import 'package:roadpack/features/live_map/live_map.dart';
import 'package:roadpack/l10n/app_localizations_en.dart';

MapMember _member({
  required String id,
  required DateTime at,
  double lat = 9.9816,
  double lng = 76.2999,
  double? speedKmh,
}) => MapMember(
  userId: id,
  displayName: id.toUpperCase(),
  circleId: 'c1',
  position: MemberPosition(
    userId: id,
    latitude: lat,
    longitude: lng,
    recordedAt: at,
    speedKmh: speedKmh,
  ),
);

void main() {
  final now = DateTime.utc(2026, 9, 8, 12, 0, 0);
  const sem = AppSemantics.night;
  // The marker label is localised copy; these tests assert the English cut.
  final l10n = AppLocalizationsEn();

  test('a live member is drawn in the watch accent, never the emergency tier', () {
    final spec = MemberMarkerSpec.from(
      member: _member(
        id: 'u1',
        at: now.subtract(const Duration(seconds: 5)),
        speedKmh: 40,
      ),
      now: now,
      semantics: sem,
      l10n: l10n,
    );
    expect(spec.color, sem.watchAccent);
    expect(spec.color, isNot(sem.emergency));
    expect(spec.opacity, 1.0);
    expect(spec.isLive, isTrue);
  });

  test('a >60s member is greyed, age-labelled and offers no live affordance', () {
    final spec = MemberMarkerSpec.from(
      member: _member(
        id: 'u1',
        at: now.subtract(const Duration(minutes: 7)),
        speedKmh: 55,
      ),
      now: now,
      semantics: sem,
      l10n: l10n,
    );
    expect(spec.isLive, isFalse);
    expect(spec.color, sem.textMuted, reason: 'stale greys out of the watch tier');
    expect(spec.opacity, lessThan(1.0));
    expect(spec.label, contains('7m'));
    expect(spec.showsHeading, isFalse, reason: 'a heading arrow implies motion');
  });

  test('the marker never moves without a new fix', () {
    final member = _member(
      id: 'u1',
      at: now.subtract(const Duration(seconds: 30)),
      speedKmh: 80,
    );
    final first = MemberMarkerSpec.from(
      member: member,
      now: now,
      semantics: sem,
      l10n: l10n,
    );
    final muchLater = MemberMarkerSpec.from(
      member: member,
      now: now.add(const Duration(minutes: 12)),
      semantics: sem,
      l10n: l10n,
    );
    expect(muchLater.latitude, first.latitude);
    expect(muchLater.longitude, first.longitude);
    expect(first.latitude, member.position?.latitude);
    expect(
      muchLater.isLive,
      isFalse,
      reason: 'time passing degrades trust, not position',
    );
  });

  test('a member with no fix produces no marker at all', () {
    final spec = MemberMarkerSpec.tryFrom(
      member: const MapMember(userId: 'u2', displayName: 'U2', circleId: 'c1'),
      now: now,
      semantics: sem,
      l10n: l10n,
    );
    expect(spec, isNull);
  });

  test('unreachable and stopped members are visually distinct', () {
    final stopped = MemberMarkerSpec.from(
      member: _member(
        id: 'a',
        at: now.subtract(const Duration(seconds: 12)),
        speedKmh: 0,
      ),
      now: now,
      semantics: sem,
      l10n: l10n,
    );
    final unreachable = MemberMarkerSpec.from(
      member: _member(
        id: 'b',
        at: now.subtract(const Duration(minutes: 40)),
        speedKmh: 0,
      ),
      now: now,
      semantics: sem,
      l10n: l10n,
    );
    expect(stopped.color, isNot(unreachable.color));
    expect(stopped.opacity, isNot(unreachable.opacity));
    expect(stopped.label, isNot(unreachable.label));
  });

  test('buildAll skips members without a fix and keeps ids stable', () {
    final specs = MemberMarkerSpec.buildAll(
      members: [
        _member(id: 'u1', at: now.subtract(const Duration(seconds: 3))),
        const MapMember(userId: 'u2', displayName: 'U2', circleId: 'c1'),
      ],
      now: now,
      semantics: sem,
      l10n: l10n,
    );
    expect(specs.map((s) => s.userId), ['u1']);
  });
}
