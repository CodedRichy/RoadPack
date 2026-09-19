import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/bystander/bystander.dart';

const _ice = IceProfile(
  bloodGroup: 'O+',
  allergies: ['Penicillin'],
  contacts: [IceContact(name: 'Asha', phone: '+919847012345', relation: 'Wife')],
);

BystanderSession _session({required bool active}) => BystanderSession(
  incidentId: 'i1',
  incidentActive: active,
  victimDisplayName: 'Rahul',
  ice: _ice,
);

Future<void> _pump(
  WidgetTester tester,
  IceQrPayload payload, {
  bool sunlight = false,
  Size surface = const Size(400, 900),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: sunlight ? AppTheme.light : AppTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(
          child: IceCard(payload: payload, lang: BystanderLang.en),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the gated payload as a QR symbol', (tester) async {
    final payload = IceQrPayload.forSession(_session(active: true))!;
    await _pump(tester, payload);

    expect(find.byType(QrImageView), findsOneWidget);
    final symbol = tester.widget<IceQrSymbol>(find.byType(IceQrSymbol));
    expect(symbol.payload.data, payload.data);
    expect(symbol.payload.data, contains('O+'));
  });

  testWidgets('uses the highest error correction and a quiet zone', (
    tester,
  ) async {
    await _pump(tester, IceQrPayload.forSession(_session(active: true))!);
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));

    // Photographed off a cracked screen: H tolerates ~30% module loss.
    expect(qr.errorCorrectionLevel, QrErrorCorrectLevel.H);
    expect(qr.padding.horizontal / 2, greaterThanOrEqualTo(AppSpace.lg));
  });

  testWidgets('is high-contrast in both themes, not theme-tinted', (
    tester,
  ) async {
    for (final sunlight in [false, true]) {
      await _pump(
        tester,
        IceQrPayload.forSession(_session(active: true))!,
        sunlight: sunlight,
      );
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr.backgroundColor, AppColors.paper);
      expect(qr.dataModuleStyle.color, AppColors.hazardInk);
      expect(qr.eyeStyle.color, AppColors.hazardInk);
    }
  });

  testWidgets('sizes against the short edge, not a fixed dp value', (
    tester,
  ) async {
    await _pump(
      tester,
      IceQrPayload.forSession(_session(active: true))!,
      surface: const Size(320, 900),
    );
    final small = tester.widget<QrImageView>(find.byType(QrImageView)).size!;

    await _pump(
      tester,
      IceQrPayload.forSession(_session(active: true))!,
      surface: const Size(600, 900),
    );
    final large = tester.widget<QrImageView>(find.byType(QrImageView)).size!;

    expect(large, greaterThan(small));
    expect(small, greaterThanOrEqualTo(160));
  });

  testWidgets('keeps the facts readable as text beside the symbol', (
    tester,
  ) async {
    // A paramedic without a scanner still has to be able to read this.
    await _pump(tester, IceQrPayload.forSession(_session(active: true))!);
    expect(find.textContaining('O+'), findsWidgets);
    expect(find.textContaining('Penicillin'), findsWidgets);
  });
}
