import 'package:shared_preferences/shared_preferences.dart';

import '../design/povad_theme.dart';

abstract interface class UiPreferences {
  Future<String?> readLanguage();
  Future<PovadSkin?> readSkin();
  Future<void> saveLanguage(String languageCode);
  Future<void> saveSkin(PovadSkin skin);
}

final class DeviceUiPreferences implements UiPreferences {
  DeviceUiPreferences() : _store = SharedPreferencesAsync();

  final SharedPreferencesAsync _store;

  static const _languageKey = 'ui.language';
  static const _skinKey = 'ui.skin';

  @override
  Future<String?> readLanguage() => _store.getString(_languageKey);

  @override
  Future<PovadSkin?> readSkin() async {
    final name = await _store.getString(_skinKey);
    for (final skin in PovadSkin.values) {
      if (skin.name == name) return skin;
    }
    return null;
  }

  @override
  Future<void> saveLanguage(String languageCode) =>
      _store.setString(_languageKey, languageCode);

  @override
  Future<void> saveSkin(PovadSkin skin) =>
      _store.setString(_skinKey, skin.name);
}
