import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/home/screens/home_screen.dart';

/// The front door is allowed to be wrong about many things. It is not allowed
/// to overstate protection: a rider who believes an alert will reach somebody
/// rides differently from one who knows it will not.
void main() {
  ProtectionStatus resolve({
    bool crash = true,
    bool tracking = true,
    bool nonArrival = true,
    bool contact = true,
    bool incident = false,
  }) => ProtectionStatus.resolve(
    crashDetection: crash,
    tracking: tracking,
    nonArrival: nonArrival,
    emergencyContact: contact,
    incident: incident,
  );

  group('ProtectionStatus.resolve', () {
    test('is armed only when all three systems and a contact are live', () {
      expect(resolve().level, ProtectionLevel.armed);
      expect(resolve().gap, isNull);
    });

    test('cannot be armed without an emergency contact', () {
      final status = resolve(contact: false);
      expect(status.level, ProtectionLevel.partial);
    });

    test('names the missing contact specifically and where to fix it', () {
      final gap = resolve(contact: false).gap;
      expect(gap, isNotNull);
      expect(gap!.route, '/emergency-contacts');
      expect(gap.kind, ProtectionGapKind.noContact);
    });

    test('the missing contact outranks a missing system', () {
      final gap = resolve(contact: false, tracking: false).gap;
      expect(gap!.route, '/emergency-contacts');
    });

    test('names a missing system when the contact is in place', () {
      expect(resolve(tracking: false).gap!.route, '/settings');
      expect(
        resolve(nonArrival: false).gap!.kind,
        ProtectionGapKind.nonArrivalOff,
      );
      expect(resolve(crash: false).gap!.kind, ProtectionGapKind.crashOff);
    });

    test('is off when nothing is watching', () {
      expect(
        resolve(
          crash: false,
          tracking: false,
          nonArrival: false,
          contact: false,
        ).level,
        ProtectionLevel.off,
      );
    });

    test('a contact alone is not protection', () {
      final status = resolve(crash: false, tracking: false, nonArrival: false);
      expect(status.level, ProtectionLevel.off);
      expect(status.activeCount, 0);
    });

    test('an incident outranks every other state', () {
      expect(
        resolve(incident: true, contact: false).level,
        ProtectionLevel.incident,
      );
    });

    test('activeCount counts only the three watching systems', () {
      expect(resolve(tracking: false).activeCount, 2);
      expect(resolve(contact: false).activeCount, 3);
    });
  });
}
