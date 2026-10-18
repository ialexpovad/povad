import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:povad/domain/android_usb_host.dart';
import 'package:povad/domain/bridge_session.dart';
import 'package:povad/main.dart';
import 'package:povad_core/povad_core.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android app loads the USB channel and JNI transport worker', (
    tester,
  ) async {
    await tester.pumpWidget(PovadApp(session: BridgeSession()));
    await tester.pumpAndSettle();
    expect(find.text('Connection overview'), findsOneWidget);
    expect(find.text('Configure bridge'), findsOneWidget);

    const host = AndroidUsbHost();
    expect(await host.available(), isA<bool>());
    expect(await host.listPorts(), isEmpty);
    expect(nativeAbiVersion(), 1);

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
