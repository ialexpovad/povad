import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/app/login_startup.dart';
import 'package:povad/design/povad_theme.dart';
import 'package:povad/features/settings_page.dart';
import 'package:povad/l10n/generated/app_localizations.dart';
import 'package:povad/l10n/shadcn_localizations_be.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

class _Backend implements LoginStartupBackend {
  LoginStartupStatus status = LoginStartupStatus.enabled;
  @override
  Future<LoginStartupStatus> read() async => status;
  @override
  Future<void> setEnabled(bool enabled) async => status = enabled
      ? LoginStartupStatus.enabled
      : LoginStartupStatus.disabled;
}

void main() {
  for (final language in ['en', 'be']) {
    for (final dark in [false, true]) {
      testWidgets('startup switch fits narrow $language dark=$dark at 200%', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 700);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final startup = LoginStartup(
          backend: _Backend(),
          readInitialized: () async => true,
          markInitialized: () async {},
        );
        await startup.initialize();
        addTearDown(startup.dispose);
        await tester.pumpWidget(
          shad.ShadcnApp(
            theme: PovadPalette(dark).toShadcn(),
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              PovadShadcnDelegate(),
            ],
            home: ListenableBuilder(
              listenable: startup,
              builder: (_, _) => SettingsPage(
                loginStartup: startup,
                locale: Locale(language),
                onLocaleChanged: (_) {},
                appearance: PovadAppearance.system,
                onAppearanceChanged: (_) {},
                animateConnection: true,
                onAnimateConnectionChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final toggle = find.byKey(const ValueKey('start-at-login'));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        expect(tester.widget<shad.Switch>(toggle).value, isTrue);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.widget<shad.Switch>(toggle).value, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
