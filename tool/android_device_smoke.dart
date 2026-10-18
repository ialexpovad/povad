import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:povad/domain/android_usb_host.dart';
import 'package:povad_core/povad_core.dart';

/// Standalone arm64 developer APK for a physical no-adapter Android preflight.
/// It never opens a real USB serial device or starts a TCP listener.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ResultScreen('Checking Android USB/JNI…'));

  try {
    const host = AndroidUsbHost();
    if (!await host.available()) throw StateError('USB Host is unavailable');
    if ((await host.listPorts()).isNotEmpty) {
      throw StateError('Disconnect USB serial devices for this preflight');
    }
    if (nativeAbiVersion() != 1) throw StateError('C ABI mismatch');

    final bridge = NativeBridge();
    try {
      bridge.start(
        const BridgeConfig(serialPort: 'usb:/dev/bus/usb/999/999:0'),
      );
      final result = await bridge.waitForStop().timeout(
        const Duration(seconds: 10),
      );
      if (result.state != BridgeState.fault ||
          result.errorCode != 6 ||
          !result.errorMessage.contains('Cannot open USB serial device')) {
        throw StateError('Unexpected native USB error: ${result.errorCode}');
      }
    } finally {
      await bridge.close();
    }

    debugPrint('POVAD_ANDROID_DEVICE_SMOKE_PASS');
    runApp(const _ResultScreen('PASS\nUSB Host · ABI · JNI worker'));
  } on Object catch (error) {
    debugPrint('POVAD_ANDROID_DEVICE_SMOKE_FAIL: $error');
    runApp(_ResultScreen('FAIL\n$error'));
  }
}

class _ResultScreen extends StatelessWidget {
  const _ResultScreen(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF14181E),
    builder: (context, child) => ColoredBox(
      color: const Color(0xFF14181E),
      child: Center(
        child: Text(
          'Povad Android smoke\n\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 22),
        ),
      ),
    ),
  );
}
