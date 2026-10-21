import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import 'app/login_startup.dart';

import 'app/android_presence.dart';
import 'app/bridge_presence.dart';
import 'app/desktop_presence.dart';
import 'app/povad_app.dart';
import 'app/release_updates.dart';
import 'app/update_installer.dart';
import 'domain/bridge_session.dart';
import 'domain/bridge_profiles.dart';
import 'domain/bridge_fleet.dart';
import 'domain/serial_port_discovery.dart';

export 'app/povad_app.dart' show PovadApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fleet = BridgeFleet(sessionFactory: BridgeSession.new);
  final BridgePresence? presence;
  if (Platform.isAndroid) {
    presence = AndroidPresence(fleet);
  } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    presence = await DesktopPresence.initialize(fleet);
  } else {
    presence = null;
  }
  runApp(
    PovadApp(
      fleet: fleet,
      loginStartup: kReleaseMode ? LoginStartup.forDesktop() : null,
      presence: presence,
      updates: ReleaseUpdates(),
      bridgeProfiles: DeviceBridgeProfilesStore(
        rememberSerialPort: !Platform.isAndroid,
      ),
      portDiscovery: SerialPortDiscovery(),
      installer: UpdateInstaller(),
      updatePreferences: DeviceUpdatePreferences(),
      exitForUpdate: presence is DesktopPresence ? presence.quit : null,
    ),
  );
}
