import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/design/povad_theme.dart';
import 'package:povad/domain/bridge_view_state.dart';
import 'package:povad/features/connection_diagram.dart';
import 'package:povad/features/overview_page.dart';
import 'package:povad/l10n/generated/app_localizations.dart';
import 'package:povad/l10n/shadcn_localizations_be.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

/// Run manually with:
/// flutter test tool/render_connection_preview_test.dart
/// ffmpeg -y -framerate 25 -i build/connection_preview_frames/%03d.png \
///   -vf palettegen=stats_mode=full build/connection_preview_palette.png
/// ffmpeg -y -framerate 25 -i build/connection_preview_frames/%03d.png \
///   -i build/connection_preview_palette.png -lavfi paletteuse=dither=bayer \
///   assets/preview/connection_activity.gif
void main() {
  setUpAll(_loadPreviewFonts);

  testWidgets('render actual Flutter connection activity frames', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final frameDirectory = Directory('build/connection_preview_frames');
    frameDirectory.createSync(recursive: true);
    const boundaryKey = ValueKey('preview-boundary');
    var frame = 0;

    // Preserve the same widget state while counters increase. These are
    // illustrative inputs; the real app receives counters from the C++ worker.
    Widget trafficPreview(int serial, int tcp) => shad.ShadcnApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        PovadShadcnDelegate(),
      ],
      theme: const PovadPalette(true).toShadcn(),
      home: RepaintBoundary(
        key: boundaryKey,
        child: ColoredBox(
          color: const Color(0xFF0B0B0D),
          child: Center(
            child: ConnectionDiagram(
              state: BridgeViewState.connected,
              serialReceived: serial,
              tcpReceived: tcp,
            ),
          ),
        ),
      ),
    );

    Future<void> capture() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (bytes == null) throw StateError('Cannot render preview frame');
        final path =
            '${frameDirectory.path}/${frame.toString().padLeft(3, '0')}.png';
        File(path).writeAsBytesSync(bytes.buffer.asUint8List());
      });
      frame++;
    }

    await tester.pumpWidget(trafficPreview(0, 0));
    await tester.pumpAndSettle();
    var serial = 0;
    var tcp = 0;
    for (var i = 0; i < 80; i++) {
      // A request arrives from TCP once a second; a serial response follows.
      if (i == 5 || i == 30 || i == 55) {
        tcp++;
        await tester.pumpWidget(trafficPreview(serial, tcp));
      }
      if (i == 12 || i == 37 || i == 62) {
        serial++;
        await tester.pumpWidget(trafficPreview(serial, tcp));
      }
      await tester.pump(const Duration(milliseconds: 40));
      await capture();
    }
  });

  testWidgets('render connected overview content', (tester) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const boundaryKey = ValueKey('connected-overview-boundary');
    await tester.pumpWidget(
      shad.ShadcnApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          PovadShadcnDelegate(),
        ],
        theme: const PovadPalette(false).toShadcn(),
        home: RepaintBoundary(
          key: boundaryKey,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: OverviewPage(
              state: BridgeViewState.connected,
              onAction: () {},
              previewMode: false,
              serialValue: '/dev/tty.usbserial-0001',
              tcpValue: '192.168.1.24:9268',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Client connected'), findsOneWidget);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('Cannot render connected overview');
      File('assets/preview/connected_overview.png')
          .writeAsBytesSync(bytes.buffer.asUint8List());
    });
  });
}

Future<void> _loadPreviewFonts() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final item in manifest) {
    final entry = item as Map<String, dynamic>;
    final family = (entry['family'] as String).replaceFirst(
      'packages/alchemist/',
      '',
    );
    final loader = FontLoader(family);
    for (final item in entry['fonts'] as List<dynamic>) {
      loader.addFont(
        rootBundle.load((item as Map<String, dynamic>)['asset'] as String),
      );
    }
    await loader.load();
  }
}
