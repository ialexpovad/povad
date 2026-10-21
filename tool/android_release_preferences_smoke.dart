import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:povad/domain/bridge_profiles.dart';
import 'package:povad/domain/bridge_settings.dart';

/// Run in an R8-optimized APK: debug builds cannot catch JNI descriptor
/// breakage in shared_preferences_android.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    const usbChannel = MethodChannel('povad/usb_host');
    if (await usbChannel.invokeMethod<bool>('nativeAvailable') != true) {
      throw StateError('native USB worker did not load');
    }
    final preferences = SharedPreferencesAsync();
    const key = 'ci.releasePreferencesSmoke';
    await preferences.setBool(key, true);
    if (await preferences.getBool(key) != true) {
      throw StateError('saved value was not returned');
    }
    await preferences.remove(key);
    if (await preferences.getBool(key) != null) {
      throw StateError('removed value was returned');
    }
    const profilesKey = 'ci.releaseProfilesSmoke';
    final profiles = DeviceBridgeProfilesStore(
      rememberSerialPort: false,
      readValue: () => preferences.getString(profilesKey),
      writeValue: (value) => preferences.setString(profilesKey, value),
    );
    await profiles.save(
      BridgeProfiles(
        profiles: [
          const BridgeProfile(
            id: 'one',
            number: 1,
            settings: BridgeSettings(tcpPort: '9268'),
          ),
          const BridgeProfile(
            id: 'two',
            number: 2,
            name: 'Прылада Б',
            settings: BridgeSettings(tcpPort: '9269', parity: 'E'),
          ),
        ],
        selectedId: 'two',
      ),
    );
    final restored = await profiles.read();
    if (restored.profiles.length != 2 ||
        restored.selectedId != 'two' ||
        restored.profiles.last.settings.parity != 'E' ||
        restored.profiles.last.name != 'Прылада Б') {
      throw StateError(
        'multiple bridge profiles did not survive release storage',
      );
    }
    await preferences.remove(profilesKey);
    debugPrint('POVAD_RELEASE_PREFERENCES_PASS');
    runApp(const _ResultScreen('PASS'));
  } catch (error) {
    debugPrint('POVAD_RELEASE_PREFERENCES_FAIL: $error');
    runApp(const _ResultScreen('FAIL'));
  }
}

class _ResultScreen extends StatelessWidget {
  const _ResultScreen(this.result);

  final String result;

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF18181B),
    builder: (context, child) =>
        Center(child: Text(result, textDirection: TextDirection.ltr)),
  );
}
