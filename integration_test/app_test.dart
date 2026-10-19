import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:povad/app/ui_preferences.dart';
import 'package:povad/design/povad_theme.dart';
import 'package:povad/domain/bridge_session.dart';
import 'package:povad/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'macOS app starts its native bridge and switches UI preferences',
    (tester) async {
      await tester.pumpWidget(
        PovadApp(session: BridgeSession(), preferences: _MemoryPreferences()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bridge stopped'), findsOneWidget);
      expect(find.text('Configure bridge'), findsOneWidget);
      expect(find.textContaining('INTERFACE PREVIEW'), findsNothing);

      await tester.tap(find.text('Configure bridge'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(shad.TextField).first,
        '/dev/povad-test-port-does-not-exist',
      );
      await _goHome(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start bridge'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Connection needs attention'), findsOneWidget);
      await tester.tap(find.text('Review details'));
      await tester.pumpAndSettle();
      expect(find.text('Cannot open serial port exclusively'), findsOneWidget);

      await _goSettings(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Беларуская'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Цёмная'));
      await tester.pumpAndSettle();
      await _goHome(tester);
      await tester.pumpAndSettle();

      expect(find.text('Злучэнне патрабуе ўвагі'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _goHome(WidgetTester tester) async {
  final compact = find.byKey(const ValueKey('brand-home-mobile'));
  await tester.tap(
    compact.evaluate().isNotEmpty
        ? compact
        : find.byKey(const ValueKey('brand-home-desktop')),
  );
  await tester.pumpAndSettle();
}

Future<void> _goSettings(WidgetTester tester) async {
  final menu = find.byKey(const ValueKey('mobile-menu'));
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Settings').last);
  } else {
    await tester.tap(find.byKey(const ValueKey('nav-3')));
  }
  await tester.pumpAndSettle();
}

class _MemoryPreferences implements UiPreferences {
  @override
  Future<String?> readLanguage() async => null;

  @override
  Future<PovadAppearance?> readAppearance() async => null;

  @override
  Future<void> saveLanguage(String languageCode) async {}

  @override
  Future<void> saveAppearance(PovadAppearance value) async {}
}
