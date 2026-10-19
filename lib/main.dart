import 'dart:io';

import 'package:flutter/widgets.dart';

import 'app/android_presence.dart';
import 'app/bridge_presence.dart';
import 'app/desktop_presence.dart';
import 'app/povad_app.dart';
import 'app/release_updates.dart';
import 'domain/bridge_session.dart';
import 'domain/bridge_settings.dart';
import 'domain/serial_port_discovery.dart';

export 'app/povad_app.dart' show PovadApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = BridgeSession();
  final BridgePresence? presence;
  if (Platform.isAndroid) {
    presence = AndroidPresence(session);
  } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    presence = await DesktopPresence.initialize(session);
  } else {
    presence = null;
  }
  runApp(
    PovadApp(
      session: session,
      presence: presence,
      updates: ReleaseUpdates(),
      bridgeSettings: DeviceBridgeSettingsStore(
        rememberSerialPort: !Platform.isAndroid,
      ),
      portDiscovery: SerialPortDiscovery(),
    ),
  );
}
