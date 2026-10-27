import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/app/ui_preferences.dart';
import 'package:povad/design/povad_theme.dart';
import 'package:povad/domain/bridge_fleet.dart';
import 'package:povad/domain/bridge_session.dart';
import 'package:povad/domain/bridge_settings.dart';
import 'package:povad/main.dart';
import 'package:povad_core/povad_core.dart';

// Reproducible product media: actual widgets, explicitly simulated traffic.
// flutter test tool/render_readme_test.dart
void main() {
  testWidgets('render README light and dark interface preview', (tester) async {
    final manifest = jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    ) as List<dynamic>;
    for (final item in manifest) {
      final entry = item as Map<String, dynamic>;
      final loader = FontLoader(
        (entry['family'] as String).replaceFirst('packages/alchemist/', ''),
      );
      for (final font in entry['fonts'] as List<dynamic>) {
        loader.addFont(
          rootBundle.load((font as Map<String, dynamic>)['asset'] as String),
        );
      }
      await loader.load();
    }
    tester.view.physicalSize = const Size(872, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sessions = [_DemoSession(), _DemoSession()];
    final fleets = [
      for (final session in sessions) BridgeFleet(firstSession: session),
    ];
    for (var i = 0; i < fleets.length; i++) {
      final fleet = fleets[i];
      fleet.updateProfile(
        fleet.selected.id,
        name: 'Lab device',
        settings: BridgeSettings(
          serialPort: '/dev/ttyUSB0',
          baud: '115200',
          tcpPort: '9268',
          transport: i == 0 ? BridgeTransport.tcp : BridgeTransport.ble,
          bleRequirePairing: false,
        ),
      );
    }
    for (var i = 0; i < sessions.length; i++) {
      final session = sessions[i];
      session.ble = i == 1;
      session.connected = true;
    }
    const key = ValueKey('readme-frame');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: const Color(0xFFE4E4E7),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  for (var i = 0; i < 2; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: PovadApp(
                          fleet: fleets[i],
                          preferences: _Preferences(
                            i == 0
                                ? PovadAppearance.light
                                : PovadAppearance.dark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final directory = Directory('build/readme-frames')
      ..createSync(recursive: true);
    Directory('assets/screenshots').createSync(recursive: true);
    Future<void> capture(String path, {double ratio = 1}) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: ratio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File(path).writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    for (var frame = 0; frame < 80; frame++) {
      if (frame % 20 == 0) {
        for (final session in sessions) {
          session.tcp += 8;
          session.notify();
        }
      }
      if (frame % 20 == 7) {
        for (final session in sessions) {
          session.serial += 32;
          session.notify();
        }
      }
      await tester.pump(const Duration(milliseconds: 50));
      await capture(
        '${directory.path}/${frame.toString().padLeft(3, '0')}.png',
      );
      if (frame == 15) {
        await capture('assets/screenshots/overview.png', ratio: 2);
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

class _DemoSession extends BridgeSession {
  int serial = 0, tcp = 0;
  bool connected = false, ble = false;
  void notify() => notifyListeners();
  @override
  bool get active => connected;
  @override
  BridgeState get state =>
      connected ? BridgeState.connected : BridgeState.stopped;
  @override
  BridgeSnapshot get snapshot => BridgeSnapshot(
    state: state,
    serialOpen: true,
    clientConnected: true,
    tcpReceived: tcp,
    bleReceived: ble ? tcp : 0,
    serialReceived: serial,
    serialAccepted: tcp,
    tcpAccepted: serial,
    errorCode: 0,
    errorMessage: '',
    rejectedBusy: 0,
    rejectedIp: 0,
  );
}

class _Preferences implements UiPreferences {
  _Preferences(this.appearance);
  final PovadAppearance appearance;
  @override
  Future<String?> readLanguage() async => 'en';
  @override
  Future<PovadAppearance?> readAppearance() async => appearance;
  @override
  Future<bool?> readConnectionAnimation() async => true;
  @override
  Future<void> saveLanguage(String value) async {}
  @override
  Future<void> saveAppearance(PovadAppearance value) async {}
  @override
  Future<void> saveConnectionAnimation(bool value) async {}
}
