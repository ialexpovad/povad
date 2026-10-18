import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:povad/app/ui_preferences.dart';
import 'package:povad/design/povad_theme.dart';
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
    'desktop overview in graphite and copper',
    fileName: 'overview_desktop_copper',
    constraints: const BoxConstraints.tightFor(width: 800, height: 600),
    builder: () =>
        PovadApp(preferences: _GoldenPreferences('en', PovadSkin.copper)),
  );

  goldenTest(
    'desktop overview in classic blue',
    fileName: 'overview_desktop_blue',
    constraints: const BoxConstraints.tightFor(width: 800, height: 600),
    builder: () =>
        PovadApp(preferences: _GoldenPreferences('en', PovadSkin.classicBlue)),
  );

  goldenTest(
    'small Belarusian overview',
    fileName: 'overview_mobile_be',
    constraints: const BoxConstraints.tightFor(width: 360, height: 700),
    builder: () =>
        PovadApp(preferences: _GoldenPreferences('be', PovadSkin.copper)),
  );
}

class _GoldenPreferences implements UiPreferences {
  _GoldenPreferences(this.language, this.skin);

  final String language;
  final PovadSkin skin;

  @override
  Future<String?> readLanguage() async => language;

  @override
  Future<PovadSkin?> readSkin() async => skin;

  @override
  Future<void> saveLanguage(String languageCode) async {}

  @override
  Future<void> saveSkin(PovadSkin value) async {}
}
