import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/app/ui_preferences.dart';
import 'package:povad/design/povad_mark.dart';
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

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listening'));
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    expect(core().firstPoint, const Color(0xFF2563EB));
    expect(core().secondPoint, const Color(0xFFA1A1AA));

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connected'));
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    expect(core().firstPoint, const Color(0xFF2563EB));
    expect(core().secondPoint, const Color(0xFF2563EB));
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
    expect(find.text('Povad'), findsOneWidget);
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
