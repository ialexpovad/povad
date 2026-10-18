import 'package:flutter/widgets.dart';

import 'app/povad_app.dart';
import 'domain/bridge_session.dart';

export 'app/povad_app.dart' show PovadApp;

void main() => runApp(PovadApp(session: BridgeSession()));
