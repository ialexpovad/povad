import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/app/ui_preferences.dart';
import 'package:povad/app/release_updates.dart';
import 'package:povad/design/povad_mark.dart';
import 'package:povad/design/povad_theme.dart';
import 'package:povad/domain/bridge_session.dart';
import 'package:povad/domain/bridge_settings.dart';
import 'package:povad/domain/serial_port_discovery.dart';
import 'package:povad/domain/bridge_view_state.dart';
import 'package:povad/features/connection_diagram.dart';
import 'package:povad/l10n/generated/app_localizations.dart';
import 'package:povad/l10n/shadcn_localizations_be.dart';
import 'package:povad/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

void main() {
  testWidgets(
    'live mode configures a bridge and reports a native port failure',
    (tester) async {
      await tester.pumpWidget(
        PovadApp(session: BridgeSession(), preferences: MemoryUiPreferences()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Configure bridge'), findsOneWidget);
      expect(find.textContaining('PREVIEW'), findsNothing);

      await tester.tap(find.text('Configure bridge'));
      await tester.pumpAndSettle();
      expect(find.text('Bridge setup'), findsOneWidget);
      await tester.enterText(
        find.byType(shad.TextField).first,
        '/dev/povad-test-port-does-not-exist',
      );
      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pumpAndSettle();
      expect(find.text('Start bridge'), findsOneWidget);

      await tester.tap(find.text('Start bridge'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Connection needs attention'), findsOneWidget);
      await tester.tap(find.text('Review details'));
      await tester.pumpAndSettle();
      expect(find.text('Cannot open serial port exclusively'), findsOneWidget);
    },
  );

  testWidgets('bridge setup offers standard baud rates and custom entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      PovadApp(session: BridgeSession(), preferences: MemoryUiPreferences()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configure bridge'));
    await tester.pumpAndSettle();

    final selector = find.byKey(const ValueKey('baud-select'));
    expect(tester.widget<shad.Select<String>>(selector).value, '115200');
    await tester.tap(selector);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('9600'));
    await tester.pumpAndSettle();
    expect(tester.widget<shad.Select<String>>(selector).value, '9600');

    await tester.tap(selector);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('Custom rate'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Custom rate').last);
    await tester.pumpAndSettle();
    expect(tester.widget<shad.Select<String>>(selector).value, 'custom');
    expect(find.text('Custom rate'), findsWidgets);
  });

  testWidgets('narrow overview remains usable with large system text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.pumpAndSettle();
    expect(find.text('Bridge stopped'), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-3')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary action label is centered in the button', (tester) async {
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.pumpAndSettle();

    final label = find.text('Start bridge');
    final button = find.ancestor(
      of: label,
      matching: find.byType(shad.PrimaryButton),
    );
    expect(button, findsOneWidget);
    expect(
      (tester.getCenter(label).dx - tester.getCenter(button).dx).abs(),
      lessThan(1),
    );
  });

  testWidgets('core points follow confirmed bridge stages', (tester) async {
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.pumpAndSettle();

    PovadMark core() => tester.widget<PovadMark>(find.byType(PovadMark).last);
    expect(core().firstPoint, const Color(0xFFA1A1AA));
    expect(core().secondPoint, const Color(0xFFA1A1AA));
    expect(core().activeProgress, 0);

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listening'));
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    expect(core().firstPoint, const Color(0xFF2563EB));
    expect(core().secondPoint, const Color(0xFFA1A1AA));
    expect(core().activeProgress, closeTo(0.54, 0.001));

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connected'));
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    expect(core().firstPoint, const Color(0xFF2563EB));
    expect(core().secondPoint, const Color(0xFF2563EB));
    expect(core().activeProgress, closeTo(1, 0.001));
  });

  testWidgets('signal travels only after observed bytes, in source direction', (
    tester,
  ) async {
    Widget diagram({int serial = 0, int tcp = 0}) => shad.ShadcnApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        PovadShadcnDelegate(),
      ],
      theme: const PovadPalette(false).toShadcn(),
      home: Center(
        child: ConnectionDiagram(
          state: BridgeViewState.connected,
          serialReceived: serial,
          tcpReceived: tcp,
        ),
      ),
    );
    PovadMark mark() => tester.widget<PovadMark>(find.byType(PovadMark));

    await tester.pumpWidget(diagram());
    await tester.pumpAndSettle();
    expect(mark().serialSignalProgress, isNull);
    expect(mark().tcpSignalProgress, isNull);

    await tester.pumpWidget(diagram(serial: 1));
    await tester.pump(const Duration(milliseconds: 120));
    expect(mark().serialSignalProgress, isNotNull);
    expect(mark().tcpSignalProgress, isNull);
    await tester.pumpAndSettle();
    expect(mark().serialSignalProgress, isNull);

    await tester.pumpWidget(diagram(serial: 1, tcp: 1));
    await tester.pump(const Duration(milliseconds: 120));
    expect(mark().serialSignalProgress, isNull);
    expect(mark().tcpSignalProgress, isNotNull);
    await tester.pumpAndSettle();

    await tester.pumpWidget(diagram(serial: 2, tcp: 2));
    await tester.pump(const Duration(milliseconds: 120));
    expect(mark().serialSignalProgress, isNotNull);
    expect(mark().tcpSignalProgress, isNotNull);
    await tester.pumpAndSettle();

    await tester.pumpWidget(diagram(serial: 3, tcp: 3));
    await tester.pump(const Duration(milliseconds: 120));
    expect(mark().serialSignalProgress, isNotNull);
    expect(mark().tcpSignalProgress, isNotNull);
  });

  testWidgets('reduced motion suppresses observed-byte signal', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    Widget diagram(int received) => shad.ShadcnApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        PovadShadcnDelegate(),
      ],
      theme: const PovadPalette(false).toShadcn(),
      home: Center(
        child: ConnectionDiagram(
          state: BridgeViewState.connected,
          serialReceived: received,
        ),
      ),
    );
    await tester.pumpWidget(diagram(0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(diagram(1));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester.widget<PovadMark>(find.byType(PovadMark)).serialSignalProgress,
      isNull,
    );
  });

  testWidgets('reduced motion settles during bridge startup', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          disableAnimations: true,
          reduceMotion: true,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start bridge'));
    await tester.pumpAndSettle();
    expect(find.text('Starting bridge'), findsOneWidget);
  });

  testWidgets('preview action never claims a live connection', (tester) async {
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    expect(find.text('PREVIEW · No live connection'), findsOneWidget);
    expect(find.text('Bridge stopped'), findsOneWidget);

    await tester.tap(find.text('Start bridge'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Starting bridge'), findsOneWidget);
    expect(find.text('Starting…'), findsOneWidget);
    expect(find.text('PREVIEW · No live connection'), findsOneWidget);
    final startingCore = tester.widget<PovadMark>(find.byType(PovadMark).last);
    expect(startingCore.firstPoint, const Color(0xFFA1A1AA));
    expect(startingCore.secondPoint, const Color(0xFFA1A1AA));

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connected'));
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    expect(find.text('Client connected'), findsOneWidget);

    await tester.tap(find.text('Stop bridge'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Stopping bridge'), findsOneWidget);
  });

  testWidgets('English and Belarusian are available in settings', (
    tester,
  ) async {
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Беларуская'));
    await tester.pumpAndSettle();
    expect(find.text('Мова'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    expect(find.text('Мост спынены'), findsOneWidget);
    expect(find.textContaining('ПРАГЛЯД'), findsOneWidget);
  });

  testWidgets('About shows author, build and available RC in both languages', (
    tester,
  ) async {
    final updates = ReleaseUpdates(
      assetPlatform: 'android-arm64.apk',
      readBuild: () async => const AppBuild('0.1.0-rc.1', '2'),
      loadReleases: () async => [
        {
          'tag_name': 'v0.1.0-rc.2',
          'prerelease': true,
          'draft': false,
          'assets': [
            {
              'name': 'Povad-v0.1.0-rc.2-android-arm64.apk',
              'state': 'uploaded',
            },
          ],
        },
      ],
    );
    await tester.pumpWidget(
      PovadApp(preferences: MemoryUiPreferences(), updates: updates),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('0.1.0-rc.1 (2)'), findsOneWidget);
    expect(find.text('Version 0.1.0-rc.1 (2)'), findsOneWidget);
    expect(find.text('Created by'), findsOneWidget);
    expect(find.text('Aliaksandr Povad'), findsOneWidget);
    expect(find.text('Povad 0.1.0-rc.2 is available'), findsOneWidget);
    expect(find.text('View release'), findsOneWidget);
    await tester.tap(find.text('Беларуская'));
    await tester.pumpAndSettle();
    expect(find.text('Версія 0.1.0-rc.1 (2)'), findsOneWidget);
    expect(find.text('Распрацаваў'), findsOneWidget);
    expect(find.text('Aliaksandr Povad'), findsOneWidget);
    expect(find.text('Даступная Povad 0.1.0-rc.2'), findsOneWidget);
  });

  testWidgets('small screen keeps Belarusian controls usable', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.tap(find.byKey(const ValueKey('mobile-menu')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Send feedback'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Беларуская'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobile-menu')));
    await tester.pump(const Duration(milliseconds: 300));
    for (final label in [
      'Агляд',
      'Мост',
      'Дэталі',
      'Налады',
      'Адправіць водгук',
    ]) {
      final menuLabel = find.descendant(
        of: find.byType(shad.DropdownMenu),
        matching: find.text(label),
      );
      expect(menuLabel, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(menuLabel).didExceedMaxLines,
        isFalse,
      );
    }
    await tester.tap(find.text('Агляд'));
    await tester.pumpAndSettle();
    expect(find.text('Мост спынены'), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('light and dark appearance update the shadcn theme', (
    tester,
  ) async {
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    final settings = tester.element(find.text('Light'));
    expect(paletteOf(settings).primary, const Color(0xFF2563EB));
    expect(
      shad.Theme.of(settings).colorScheme.primary,
      const Color(0xFF2563EB),
    );
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    final darkSettings = tester.element(find.text('Dark'));
    expect(paletteOf(darkSettings).primary, const Color(0xFF60A5FA));
    expect(find.text('Povad'), findsWidgets);
  });

  testWidgets('language and appearance survive an app restart', (tester) async {
    final preferences = MemoryUiPreferences();
    await tester.pumpWidget(PovadApp(preferences: preferences));
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Беларуская'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(PovadApp(preferences: preferences));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('Мова'), findsOneWidget);
    expect(
      paletteOf(tester.element(find.text('Цёмная'))).primary,
      const Color(0xFF60A5FA),
    );
  });

  testWidgets('an error offers a restart and shows the worker cause', (
    tester,
  ) async {
    await tester.pumpWidget(
      PovadApp(session: BridgeSession(), preferences: MemoryUiPreferences()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configure bridge'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(shad.TextField).first,
      '/dev/povad-test-port-does-not-exist',
    );
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start bridge'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Connection needs attention'), findsOneWidget);
    // The overview explains the failure itself instead of a dead end.
    expect(find.text('Cannot open serial port exclusively'), findsOneWidget);
    expect(find.text('Start again'), findsOneWidget);

    await tester.tap(find.text('Start again'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Connection needs attention'), findsOneWidget);
    expect(find.text('Start again'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('Cannot open serial port exclusively'), findsOneWidget);
    expect(find.text('Edit setup'), findsOneWidget);
    await tester.tap(find.text('Edit setup'));
    await tester.pumpAndSettle();
    expect(find.text('Bridge setup'), findsOneWidget);
  });

  testWidgets('preview ended and error states restart the bridge', (
    tester,
  ) async {
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    for (final (badge, title) in [
      ('Ended', 'Session ended'),
      ('Error', 'Connection needs attention'),
    ]) {
      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(badge).last);
      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text('Start again'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Starting bridge'), findsOneWidget);
    }
  });

  testWidgets('bridge setup validates fields where they are entered', (
    tester,
  ) async {
    await tester.pumpWidget(
      PovadApp(session: BridgeSession(), preferences: MemoryUiPreferences()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configure bridge'));
    await tester.pumpAndSettle();
    // An attempted start flags the empty required field.
    expect(find.text('Enter a serial port.'), findsOneWidget);

    final tcp = find.descendant(
      of: find.byKey(const ValueKey('tcp-field')),
      matching: find.byType(shad.TextField),
    );
    await tester.enterText(tcp, '70000');
    await tester.pump();
    expect(find.text('Enter a port from 1 to 65,535.'), findsOneWidget);
    await tester.enterText(tcp, '80a8');
    await tester.pump();
    expect(find.text('808'), findsOneWidget);
    expect(find.text('Enter a port from 1 to 65,535.'), findsNothing);
  });

  testWidgets('bridge settings are restored, LAN access is not', (
    tester,
  ) async {
    final store = MemoryBridgeSettingsStore();
    Widget app() => PovadApp(
      session: BridgeSession(),
      preferences: MemoryUiPreferences(),
      bridgeSettings: store,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('serial-field')),
        matching: find.byType(shad.TextField),
      ),
      '/dev/ttyUSB7',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('tcp-field')),
        matching: find.byType(shad.TextField),
      ),
      '5020',
    );
    await tester.tap(find.byType(shad.Switch));
    await tester.pumpAndSettle();
    expect(store.saved?.serialPort, '/dev/ttyUSB7');
    expect(store.saved?.tcpPort, '5020');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('/dev/ttyUSB7'), findsOneWidget);
    expect(find.text('127.0.0.1:5020'), findsOneWidget);
    expect(find.text('Start bridge'), findsOneWidget);
  });

  testWidgets('detected serial ports fill the setup form', (tester) async {
    await tester.pumpWidget(
      PovadApp(
        session: BridgeSession(),
        preferences: MemoryUiPreferences(),
        portDiscovery: SerialPortDiscovery(
          operatingSystem: 'linux',
          list: () async => ['ttyS0', 'ttyUSB0', 'ttyACM1', 'null'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('Detected ports'), findsOneWidget);
    expect(find.text('ttyS0'), findsNothing);
    await tester.tap(find.text('ttyUSB0'));
    await tester.pumpAndSettle();
    expect(find.text('/dev/ttyUSB0'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    expect(find.text('Start bridge'), findsOneWidget);
    expect(find.text('/dev/ttyUSB0'), findsOneWidget);
  });

  testWidgets('details report live facts without a running session', (
    tester,
  ) async {
    await tester.pumpWidget(
      PovadApp(session: BridgeSession(), preferences: MemoryUiPreferences()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('Bridge stopped'), findsOneWidget);
    expect(find.text('127.0.0.1:9268'), findsOneWidget);
    expect(find.text('115200'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('0 B'), findsNWidgets(2));
    expect(find.textContaining('PREVIEW'), findsNothing);
  });
}

class MemoryBridgeSettingsStore implements BridgeSettingsStore {
  BridgeSettings? saved;

  @override
  Future<BridgeSettings?> read() async => saved;

  @override
  Future<void> save(BridgeSettings settings) async => saved = settings;
}

class MemoryUiPreferences implements UiPreferences {
  String? language;
  PovadAppearance? appearance;

  @override
  Future<String?> readLanguage() async => language;

  @override
  Future<PovadAppearance?> readAppearance() async => appearance;

  @override
  Future<void> saveLanguage(String languageCode) async =>
      language = languageCode;

  @override
  Future<void> saveAppearance(PovadAppearance value) async =>
      appearance = value;
}
