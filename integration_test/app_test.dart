import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:povad/app/ui_preferences.dart';
import 'package:povad/design/povad_theme.dart';
import 'package:povad/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop app opens and switches language and palette', (
    tester,
  ) async {
    await tester.pumpWidget(PovadApp(preferences: _MemoryPreferences()));
    await tester.pumpAndSettle();
    expect(find.text('Connection overview'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Беларуская'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Класічны сіні'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();

    expect(find.text('Агляд злучэння'), findsOneWidget);
    expect(find.text('Мост спынены'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryPreferences implements UiPreferences {
  @override
  Future<String?> readLanguage() async => null;

  @override
  Future<PovadSkin?> readSkin() async => null;

  @override
  Future<void> saveLanguage(String languageCode) async {}

  @override
  Future<void> saveSkin(PovadSkin value) async {}
}
