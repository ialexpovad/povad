import 'package:shared_preferences/shared_preferences.dart';

import '../design/povad_theme.dart';

abstract interface class UiPreferences {
  Future<String?> readLanguage();
  Future<PovadAppearance?> readAppearance();
  Future<bool?> readConnectionAnimation();
  Future<void> saveLanguage(String languageCode);
  Future<void> saveAppearance(PovadAppearance appearance);
  Future<void> saveConnectionAnimation(bool enabled);
}

final class DeviceUiPreferences implements UiPreferences {
  DeviceUiPreferences() : _store = SharedPreferencesAsync();

  final SharedPreferencesAsync _store;

  static const _languageKey = 'ui.language';
  static const _appearanceKey = 'ui.appearance';
  static const _connectionAnimationKey = 'ui.connectionAnimation';

  @override
  Future<String?> readLanguage() => _store.getString(_languageKey);

  @override
  Future<PovadAppearance?> readAppearance() async {
    final name = await _store.getString(_appearanceKey);
    for (final appearance in PovadAppearance.values) {
      if (appearance.name == name) return appearance;
    }
    return null;
  }

  @override
  Future<bool?> readConnectionAnimation() =>
      _store.getBool(_connectionAnimationKey);

  @override
  Future<void> saveLanguage(String languageCode) =>
      _store.setString(_languageKey, languageCode);

  @override
  Future<void> saveAppearance(PovadAppearance appearance) =>
      _store.setString(_appearanceKey, appearance.name);

  @override
  Future<void> saveConnectionAnimation(bool enabled) =>
      _store.setBool(_connectionAnimationKey, enabled);
}
