import 'dart:io';

import 'package:flutter/widgets.dart';

import 'app/android_presence.dart';
import 'app/bridge_presence.dart';
import 'app/desktop_presence.dart';
import 'app/povad_app.dart';
import 'domain/bridge_session.dart';

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
  runApp(PovadApp(session: session, presence: presence));
}
