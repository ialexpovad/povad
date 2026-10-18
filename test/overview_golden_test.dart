import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:povad/app/ui_preferences.dart';
import 'package:povad/design/povad_theme.dart';
import 'package:povad/domain/bridge_session.dart';
import 'package:povad/main.dart';

void main() {
  AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      // Flutter's Linux and macOS rasterizers differed by at most 28 pixels
      // in the first CI run; keep the allowance below 0.02% of the image.
      ciGoldensConfig: const CiGoldensConfig(diffThreshold: 0.0002),
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
  Future<void> saveLanguage(String languageCode) async {}

  @override
  Future<void> saveAppearance(PovadAppearance value) async {}
}
