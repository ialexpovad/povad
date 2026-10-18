import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/app/ui_preferences.dart';
import 'package:povad/design/povad_theme.dart';
import 'package:povad/main.dart';

void main() {
  testWidgets('overview controls are labeled and readable', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(PovadApp(preferences: _MemoryPreferences()));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

  testWidgets('narrow layout has usable touch targets', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(PovadApp(preferences: _MemoryPreferences()));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('dark overview retains readable contrast', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(PovadApp(preferences: _MemoryPreferences()));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
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
