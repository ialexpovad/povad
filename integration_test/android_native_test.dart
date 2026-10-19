import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:povad/app/ui_preferences.dart';
import 'package:povad/design/povad_theme.dart';
import 'package:povad/domain/android_usb_host.dart';
import 'package:povad/domain/bridge_session.dart';
import 'package:povad/main.dart';
import 'package:povad_core/povad_core.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android app loads the USB channel and JNI transport worker', (
    tester,
  ) async {
    await tester.pumpWidget(
      PovadApp(session: BridgeSession(), preferences: _MemoryPreferences()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bridge stopped'), findsOneWidget);
    expect(find.text('Configure bridge'), findsOneWidget);

    const host = AndroidUsbHost();
    final usbAvailable = await host.available();
    expect(await host.listPorts(), isEmpty);

    await _navigate(tester, 'Bridge');
    expect(find.text('USB serial devices'), findsOneWidget);
    expect(
      find.textContaining('Choose a USB serial device and TCP port.'),
      findsOneWidget,
    );
    expect(
      find.text(
        usbAvailable
            ? 'No supported USB serial device is connected.'
            : 'USB Host is unavailable on this Android device or build.',
      ),
      findsOneWidget,
    );

    await _navigate(tester, 'Settings');
    await tester.tap(find.text('Беларуская'));
    await tester.pumpAndSettle();
    await _navigate(tester, 'Мост');
    expect(find.text('Паслядоўныя USB-прылады'), findsOneWidget);
    expect(
      find.textContaining('Выберыце паслядоўную USB-прыладу і порт TCP.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    expect(nativeAbiVersion(), 2);

    // A missing USB permission must never create a background service.
    const background = MethodChannel('povad/background');
    await expectLater(
      background.invokeMethod<bool>('start', {
        'selection': 'usb:/dev/bus/usb/999/999:0',
        'status': 'Starting bridge',
      }),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'USB_PERMISSION',
        ),
      ),
    );

    final bridge = NativeBridge();
    try {
      bridge.start(
        const BridgeConfig(serialPort: 'usb:/dev/bus/usb/999/999:0'),
      );
      final result = await bridge.waitForStop();
      expect(result.state, BridgeState.fault);
      expect(result.errorCode, 6);
      expect(result.errorMessage, contains('Cannot open USB serial device'));
    } finally {
      await bridge.close();
    }
  });
}

Future<void> _navigate(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('mobile-menu')));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

class _MemoryPreferences implements UiPreferences {
  @override
  Future<String?> readLanguage() async => null;

  @override
  Future<PovadAppearance?> readAppearance() async => null;

  @override
  Future<void> saveLanguage(String languageCode) async {}

  @override
  Future<void> saveAppearance(PovadAppearance value) async {}
}
