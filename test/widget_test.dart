import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/app/ui_preferences.dart';
import 'package:povad/design/povad_theme.dart';
import 'package:povad/domain/bridge_session.dart';
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
      expect(find.textContaining('INTERFACE PREVIEW'), findsNothing);

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
    expect(find.byKey(const ValueKey('nav-3')), findsOneWidget);
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

  testWidgets('preview action never claims a live connection', (tester) async {
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    expect(
      find.text('INTERFACE PREVIEW · No serial or TCP connection'),
      findsOneWidget,
    );
    expect(find.text('Bridge stopped'), findsOneWidget);

    await tester.tap(find.text('Start bridge'));
    await tester.pumpAndSettle();
    expect(find.text('Opening the connection'), findsOneWidget);
    expect(find.text('Starting…'), findsOneWidget);
    expect(
      find.text('INTERFACE PREVIEW · No serial or TCP connection'),
      findsOneWidget,
    );

    final connected = find.text('Connected');
    await tester.ensureVisible(connected);
    await tester.tap(connected);
    await tester.pumpAndSettle();
    expect(find.text('Client connected'), findsOneWidget);

    await tester.tap(find.text('Stop bridge'));
    await tester.pumpAndSettle();
    expect(find.text('Closing the connection'), findsOneWidget);
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
    expect(find.textContaining('ПАПЯРЭДНІ ПРАГЛЯД'), findsOneWidget);
  });

  testWidgets('small screen keeps Belarusian controls usable', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Беларуская'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    expect(find.text('Мост спынены'), findsOneWidget);
    for (final label in ['Агляд', 'Мост', 'Дэталі', 'Налады']) {
      expect(find.text(label), findsOneWidget);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(label))
            .didExceedMaxLines,
        isFalse,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching skins updates the shadcn theme', (tester) async {
    await tester.pumpWidget(PovadApp(preferences: MemoryUiPreferences()));
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Classic blue'));
    await tester.pumpAndSettle();
    final settings = tester.element(find.text('Classic blue'));
    expect(paletteOf(settings).primary, const Color(0xFF2563EB));
    expect(
      shad.Theme.of(settings).colorScheme.primary,
      const Color(0xFF2563EB),
    );
    expect(find.text('ovad'), findsOneWidget);
  });

  testWidgets('language and skin survive an app restart', (tester) async {
    final preferences = MemoryUiPreferences();
    await tester.pumpWidget(PovadApp(preferences: preferences));
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Classic blue'));
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
      paletteOf(tester.element(find.text('Класічны сіні'))).primary,
      const Color(0xFF2563EB),
    );
  });
}

class MemoryUiPreferences implements UiPreferences {
  String? language;
  PovadSkin? skin;

  @override
  Future<String?> readLanguage() async => language;

  @override
  Future<PovadSkin?> readSkin() async => skin;

  @override
  Future<void> saveLanguage(String languageCode) async =>
      language = languageCode;

  @override
  Future<void> saveSkin(PovadSkin value) async => skin = value;
}
