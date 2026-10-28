import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/app/ui_preferences.dart';
import 'package:povad/app/desktop_presence.dart';
import 'package:povad/app/release_updates.dart';
import 'package:povad/design/povad_mark.dart';
import 'package:povad/design/povad_theme.dart';
import 'package:povad/domain/bridge_session.dart';
import 'package:povad/domain/bridge_settings.dart';
import 'package:povad/domain/serial_port_discovery.dart';
import 'package:povad/domain/bridge_view_state.dart';
import 'package:povad/features/connection_diagram.dart';
import 'package:povad/features/bridge_setup_page.dart';
import 'package:povad/l10n/generated/app_localizations.dart';
import 'package:povad/l10n/shadcn_localizations_be.dart';
import 'package:povad/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:qr_flutter/qr_flutter.dart';

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
      await waitForNativeFault(tester);
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

  testWidgets('parity selection is restored for the next bridge session', (
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
    await tester.tap(find.text('Configure bridge'));
    await tester.pumpAndSettle();

    final selector = find.byKey(const ValueKey('parity-select'));
    expect(tester.widget<shad.Select<String>>(selector).value, 'N');
    await tester.tap(selector);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Even · 8E1').last);
    await tester.pumpAndSettle();
    expect(store.saved?.parity, 'E');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    expect(tester.widget<shad.Select<String>>(selector).value, 'E');
  });

  testWidgets('wait-next and exact LAN allowlist are saved; LAN stays off', (
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
    await tester.tap(find.text('Configure bridge'));
    await tester.pumpAndSettle();
    final waitNext = find.byKey(const ValueKey('wait-next-client'));
    await tester.ensureVisible(waitNext);
    await tester.tap(waitNext);
    await tester.pumpAndSettle();
    expect(store.saved?.waitNextClient, isTrue);

    final lan = find.byKey(const ValueKey('allow-lan'));
    await tester.ensureVisible(lan);
    await tester.tap(lan);
    await tester.pumpAndSettle();
    final allowed = find.descendant(
      of: find.byKey(const ValueKey('allowed-clients-field')),
      matching: find.byType(shad.TextField),
    );
    await tester.ensureVisible(allowed);
    await tester.enterText(allowed, '192.168.1.256');
    await tester.pump();
    expect(find.text('Enter up to 32 exact IPv4 addresses.'), findsOneWidget);
    await tester.enterText(allowed, '192.168.1.20');
    await tester.pump();
    expect(store.saved?.allowedClients, '192.168.1.20');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    expect(tester.widget<shad.Switch>(waitNext).value, isTrue);
    expect(tester.widget<shad.Switch>(lan).value, isFalse);
  });

  testWidgets('LAN address QR encodes the Povad bridge URI', (tester) async {
    await tester.pumpWidget(
      shad.ShadcnApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          PovadShadcnDelegate(),
        ],
        theme: const PovadPalette(false).toShadcn(),
        home: BridgeSetupPage(
          serialPort: '/dev/cu.test',
          baud: '115200',
          parity: 'N',
          tcpPort: '9268',
          onSerialPortChanged: (_) {},
          onBaudChanged: (_) {},
          onParityChanged: (_) {},
          onTcpPortChanged: (_) {},
          allowLan: true,
          waitNextClient: false,
          allowedClients: '',
          onWaitNextChanged: (_) {},
          onAllowedClientsChanged: (_) {},
          onAllowLanChanged: (_) {},
          lanAddresses: const [(name: 'Wi-Fi', address: '192.168.1.20')],
          copiedEndpoint: null,
          onRefreshLan: () {},
          onCopyEndpoint: (_) {},
          showErrors: false,
          running: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('qr-192.168.1.20:9268'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('povad-bridge://192.168.1.20:9268'), findsOneWidget);
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

  testWidgets('connection animation can stop during traffic', (tester) async {
    Widget diagram(int received, {bool animated = true}) => shad.ShadcnApp(
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
          animateConnection: animated,
          serialReceived: received,
        ),
      ),
    );
    PovadMark mark() => tester.widget<PovadMark>(find.byType(PovadMark));

    await tester.pumpWidget(diagram(0));
    await tester.pumpWidget(diagram(1));
    await tester.pump(const Duration(milliseconds: 120));
    expect(mark().serialSignalProgress, isNotNull);

    await tester.pumpWidget(diagram(2, animated: false));
    await tester.pump(const Duration(milliseconds: 120));
    expect(mark().serialSignalProgress, isNull);
    expect(mark().activeProgress, 1);

    await tester.pumpWidget(diagram(3, animated: false));
    await tester.pump(const Duration(milliseconds: 120));
    expect(mark().serialSignalProgress, isNull);
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

  testWidgets('language, appearance, and motion survive an app restart', (
    tester,
  ) async {
    final preferences = MemoryUiPreferences();
    await tester.pumpWidget(PovadApp(preferences: preferences));
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('connection-animation')));
    await tester.pumpAndSettle();
    expect(preferences.connectionAnimation, isFalse);
    await tester.tap(find.text('Беларуская'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(PovadApp(preferences: preferences));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('Мова'), findsOneWidget);
    expect(find.text('Анімацыя злучэння'), findsOneWidget);
    expect(
      tester
          .widget<shad.Switch>(
            find.byKey(const ValueKey('connection-animation')),
          )
          .value,
      isFalse,
    );
    expect(
      paletteOf(tester.element(find.text('Цёмная'))).primary,
      const Color(0xFF60A5FA),
    );
  });

  testWidgets('interface scale resizes the full layout and survives restart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = MemoryUiPreferences();
    await tester.pumpWidget(PovadApp(preferences: preferences));
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();

    final selector = find.byKey(const ValueKey('interface-scale'));
    final navigation = find.byKey(const ValueKey('nav-3'));
    final originalWidth = tester.getRect(navigation).width;
    final original = shad.Theme.of(tester.element(selector)).scaling;
    tester.widget<shad.Select<int>>(selector).onChanged!(80);
    await tester.pumpAndSettle();
    expect(preferences.interfaceScale, 80);
    expect(
      shad.Theme.of(tester.element(selector)).scaling,
      closeTo(original, 0.001),
    );
    expect(tester.getRect(navigation).width, closeTo(originalWidth * 0.8, 0.1));

    tester.widget<shad.Select<int>>(selector).onChanged!(125);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(navigation).width,
      closeTo(originalWidth * 1.25, 0.1),
    );
    expect(tester.takeException(), isNull);

    tester.widget<shad.Select<int>>(selector).onChanged!(80);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(PovadApp(preferences: preferences));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(tester.widget<shad.Select<int>>(selector).value, 80);
    expect(tester.getRect(navigation).width, closeTo(originalWidth * 0.8, 0.1));
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
    await waitForNativeFault(tester);
    expect(find.text('Connection needs attention'), findsOneWidget);
    // The overview turns the worker message into advice instead of a dead end.
    expect(
      find.text(
        'The port is missing, busy, or not permitted. Close apps that use '
        'it, reconnect the adapter, and check its name.',
      ),
      findsOneWidget,
    );
    expect(find.text('Start again'), findsOneWidget);
    expect(find.text('How to fix'), findsOneWidget);

    await tester.tap(find.text('Start again'));
    await waitForNativeFault(tester);
    expect(find.text('Connection needs attention'), findsOneWidget);
    expect(find.text('Start again'), findsOneWidget);

    await tester.tap(find.text('How to fix'));
    await tester.pumpAndSettle();
    // Help opens on the matching answer.
    expect(
      find.textContaining('add your user to the dialout group'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('help-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    // Details keeps the worker's own words next to the advice.
    expect(find.text('Cannot open serial port exclusively'), findsOneWidget);
    expect(
      find.textContaining('missing, busy, or not permitted'),
      findsOneWidget,
    );
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
    final lanSwitch = find.byKey(const ValueKey('allow-lan'));
    await tester.ensureVisible(lanSwitch);
    await tester.pumpAndSettle();
    await tester.tap(lanSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<shad.Switch>(lanSwitch).value, isTrue);
    expect(store.saved?.serialPort, '/dev/ttyUSB7');
    expect(store.saved?.tcpPort, '5020');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('/dev/ttyUSB7'), findsOneWidget);
    expect(find.text('127.0.0.1:5020'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    expect(tester.widget<shad.Switch>(lanSwitch).value, isFalse);
  });

  testWidgets('detected serial ports fill the setup form', (tester) async {
    await tester.pumpWidget(
      PovadApp(
        session: BridgeSession(),
        preferences: MemoryUiPreferences(),
        portDiscovery: SerialPortDiscovery(
          operatingSystem: 'linux',
          list: () async => ['ttyS0', 'ttyUSB3', 'ttyACM1', 'null'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('Detected ports'), findsOneWidget);
    expect(find.text('ttyS0'), findsNothing);
    // The port differs from every platform placeholder, such as Linux's
    // /dev/ttyUSB0, so a match can only come from the selected value.
    await tester.tap(find.text('ttyUSB3'));
    await tester.pumpAndSettle();
    expect(find.text('/dev/ttyUSB3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    expect(find.text('Start bridge'), findsOneWidget);
    expect(find.text('/dev/ttyUSB3'), findsOneWidget);
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

  testWidgets('compact header keeps one menu at the right edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('header-help')), findsNothing);
    expect(find.byKey(const ValueKey('mobile-menu')), findsOneWidget);
    final menu = tester.getSize(find.byKey(const ValueKey('mobile-menu')));
    expect(menu.width, greaterThanOrEqualTo(44));
    expect(menu.width, menu.height);
    final menuRight = tester
        .getTopRight(find.byKey(const ValueKey('mobile-menu')))
        .dx;
    expect(390 - menuRight, inInclusiveRange(0, 10));
    tester.view.physicalSize = const Size(520, 760);
    await tester.pumpAndSettle();
    final wideMenuRight = tester
        .getTopRight(find.byKey(const ValueKey('mobile-menu')))
        .dx;
    expect(520 - wideMenuRight, inInclusiveRange(0, 10));

    await tester.tap(find.byKey(const ValueKey('mobile-menu')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Help').last);
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Connect the adapter'), findsOneWidget);
    // Answers stay collapsed until asked for.
    expect(find.textContaining('dialout'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('faq-port')));
    await tester.pumpAndSettle();
    expect(find.textContaining('dialout'), findsOneWidget);
    expect(find.text('Report a problem'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('help-close')));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsNothing);
    // Help is an overlay: the four destinations are unchanged.
    expect(find.text('Bridge stopped'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-menu')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('brand-home-mobile')));
    await tester.pumpAndSettle();
    expect(find.text('Bridge stopped'), findsOneWidget);
  });

  testWidgets('desktop brand returns to Overview', (tester) async {
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('brand-home-desktop')));
    await tester.pumpAndSettle();
    expect(find.text('Bridge stopped'), findsOneWidget);
  });

  testWidgets('active close choice fits a compact desktop window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(PovadApp)) as dynamic;
    final choice = state.chooseActiveCloseAction() as Future<ActiveCloseAction>;
    await tester.pumpAndSettle();
    expect(find.text('Bridge is running'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Keep running'));
    await tester.pumpAndSettle();
    expect(await choice, ActiveCloseAction.keepRunning);
  });

  testWidgets('desktop sidebar opens help and F1 does too', (tester) async {
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar-help')));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('help-close')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('BLE help follows transport and pairing settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      PovadApp(session: BridgeSession(), preferences: MemoryUiPreferences()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configure bridge'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('BLE'));
    await tester.tap(find.text('BLE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar-help')));
    await tester.pumpAndSettle();

    expect(find.text('My BLE client cannot connect'), findsOneWidget);
    expect(find.text('My TCP client cannot connect'), findsNothing);
    expect(find.text('Is it safe to allow LAN clients?'), findsNothing);
    expect(find.text('Should my BLE client pair?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('help-close')));
    await tester.pumpAndSettle();
    final pairing = find.byKey(const ValueKey('ble-require-pairing'));
    await tester.ensureVisible(pairing);
    await tester.tap(pairing);
    await tester.pumpAndSettle();
    expect(find.textContaining('any nearby Bluetooth device'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sidebar-help')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Should my BLE client pair?'));
    await tester.tap(find.text('Should my BLE client pair?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Require pairing is off'), findsOneWidget);
  });

  testWidgets('Windows BLE explains the system advertising name', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(
      PovadApp(session: BridgeSession(), preferences: MemoryUiPreferences()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configure bridge'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('BLE'));
    await tester.tap(find.text('BLE'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ble-name-field')), findsNothing);
    expect(find.textContaining('Windows advertises under'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sidebar-help')));
    await tester.pumpAndSettle();
    expect(find.textContaining('computer’s Bluetooth name'), findsWidgets);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('modifier shortcuts switch sections', (tester) async {
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.pumpAndSettle();
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final modifier = mac
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
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
  bool? connectionAnimation;
  int? interfaceScale;

  @override
  Future<String?> readLanguage() async => language;

  @override
  Future<PovadAppearance?> readAppearance() async => appearance;

  @override
  Future<bool?> readConnectionAnimation() async => connectionAnimation;

  @override
  Future<int?> readInterfaceScale() async => interfaceScale;

  @override
  Future<void> saveLanguage(String languageCode) async =>
      language = languageCode;

  @override
  Future<void> saveAppearance(PovadAppearance value) async =>
      appearance = value;

  @override
  Future<void> saveConnectionAnimation(bool enabled) async =>
      connectionAnimation = enabled;

  @override
  Future<void> saveInterfaceScale(int percent) async =>
      interfaceScale = percent;
}

// Fake widget time does not schedule the native OS worker. Give it bounded
// real time, then advance the snapshot poller before asserting the UI result.
Future<void> waitForNativeFault(WidgetTester tester) async {
  await tester.pump();
  for (var attempt = 0; attempt < 100; attempt++) {
    final bridge = tester.widget<PovadApp>(find.byType(PovadApp)).session!;
    if (bridge.snapshot?.finished == true &&
        bridge.errorMessage != null &&
        !bridge.active) {
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail(
    'Native worker did not report its missing-port fault within two seconds',
  );
}
