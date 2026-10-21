import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:povad/app/ui_preferences.dart';
import 'package:povad/design/povad_theme.dart';
import 'package:povad/domain/bridge_session.dart';
import 'package:povad/domain/bridge_fleet.dart';
import 'package:povad/domain/bridge_settings.dart';
import 'package:povad/domain/bridge_view_state.dart';
import 'package:povad/features/connection_diagram.dart';
import 'package:povad/l10n/generated/app_localizations.dart';
import 'package:povad/l10n/shadcn_localizations_be.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:povad/main.dart';

void main() {
  AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      // Linux/macOS rasterizers differ on circular edges by 34 pixels in the
      // 280x280 mark and 52 in the 360x700 mobile view. Allow at most 0.05%.
      ciGoldensConfig: const CiGoldensConfig(diffThreshold: 0.0005),
      platformGoldensConfig: PlatformGoldensConfig(
        enabled: !Platform.environment.containsKey('CI'),
        platforms: {HostPlatform.macOS},
      ),
    ),
    run: _registerGoldens,
  );
}

void _registerGoldens() {
  goldenTest(
    'connected mark in dark mode',
    fileName: 'connected_mark_dark',
    constraints: const BoxConstraints.tightFor(width: 280, height: 280),
    builder: () => shad.ShadcnApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        PovadShadcnDelegate(),
      ],
      theme: const PovadPalette(true).toShadcn(),
      home: const ColoredBox(
        color: Color(0xFF0B0B0D),
        child: Center(
          child: ConnectionDiagram(state: BridgeViewState.connected),
        ),
      ),
    ),
  );

  goldenTest(
    'desktop overview in light mode',
    fileName: 'overview_desktop_light',
    constraints: const BoxConstraints.tightFor(width: 800, height: 600),
    builder: () =>
        PovadApp(preferences: _GoldenPreferences('en', PovadAppearance.light)),
  );

  goldenTest(
    'desktop live overview',
    fileName: 'overview_desktop_live',
    constraints: const BoxConstraints.tightFor(width: 800, height: 600),
    builder: () => PovadApp(
      session: BridgeSession(),
      preferences: _GoldenPreferences('en', PovadAppearance.light),
    ),
  );

  for (final language in ['en', 'be']) {
    goldenTest(
      'multiple bridges compact $language',
      fileName: 'multiple_bridges_mobile_$language',
      constraints: const BoxConstraints.tightFor(width: 360, height: 700),
      builder: () {
        final fleet = BridgeFleet(sessionFactory: BridgeSession.new)..add();
        fleet.updateProfile(
          fleet.selected.id,
          name: language == 'en' ? 'Bench B' : 'Прылада Б',
          settings: const BridgeSettings(serialPort: 'COM7', tcpPort: '9269'),
        );
        return PovadApp(
          fleet: fleet,
          preferences: _GoldenPreferences(
            language,
            language == 'en' ? PovadAppearance.light : PovadAppearance.dark,
          ),
        );
      },
    );
  }

  goldenTest(
    'desktop overview in dark mode',
    fileName: 'overview_desktop_dark',
    constraints: const BoxConstraints.tightFor(width: 800, height: 600),
    builder: () =>
        PovadApp(preferences: _GoldenPreferences('en', PovadAppearance.dark)),
  );

  goldenTest(
    'small Belarusian overview',
    fileName: 'overview_mobile_be',
    constraints: const BoxConstraints.tightFor(width: 360, height: 700),
    builder: () =>
        PovadApp(preferences: _GoldenPreferences('be', PovadAppearance.light)),
  );
}

class _GoldenPreferences implements UiPreferences {
  _GoldenPreferences(this.language, this.appearance);

  final String language;
  final PovadAppearance appearance;

  @override
  Future<String?> readLanguage() async => language;

  @override
  Future<PovadAppearance?> readAppearance() async => appearance;

  @override
  Future<bool?> readConnectionAnimation() async => null;

  @override
  Future<void> saveLanguage(String languageCode) async {}

  @override
  Future<void> saveAppearance(PovadAppearance value) async {}

  @override
  Future<void> saveConnectionAnimation(bool enabled) async {}
}
