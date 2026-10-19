import 'package:shared_preferences/shared_preferences.dart';

/// The operator's last bridge configuration. LAN access is deliberately not
/// stored: every launch starts on loopback until the operator opts in again.
final class BridgeSettings {
  const BridgeSettings({
    this.serialPort = '',
    this.baud = '115200',
    this.tcpPort = '9268',
  });

  final String serialPort, baud, tcpPort;
}

abstract interface class BridgeSettingsStore {
  Future<BridgeSettings?> read();
  Future<void> save(BridgeSettings settings);
}

/// Local-only storage. Nothing here is uploaded or included in reports.
final class DeviceBridgeSettingsStore implements BridgeSettingsStore {
  DeviceBridgeSettingsStore({this.rememberSerialPort = true})
    : _store = SharedPreferencesAsync();

  /// Android USB selections need a fresh permission grant, so they are not
  /// restored across launches.
  final bool rememberSerialPort;
  final SharedPreferencesAsync _store;

  static const _serialKey = 'bridge.serialPort';
  static const _baudKey = 'bridge.baud';
  static const _tcpKey = 'bridge.tcpPort';

  @override
  Future<BridgeSettings?> read() async {
    final serial = rememberSerialPort
        ? await _store.getString(_serialKey)
        : null;
    final baud = await _store.getString(_baudKey);
    final tcp = await _store.getString(_tcpKey);
    if (serial == null && baud == null && tcp == null) return null;
    const defaults = BridgeSettings();
    return BridgeSettings(
      serialPort: serial ?? defaults.serialPort,
      baud: baud ?? defaults.baud,
      tcpPort: tcp ?? defaults.tcpPort,
    );
  }

  @override
  Future<void> save(BridgeSettings settings) async {
    if (rememberSerialPort) {
      await _store.setString(_serialKey, settings.serialPort);
    }
    await _store.setString(_baudKey, settings.baud);
    await _store.setString(_tcpKey, settings.tcpPort);
  }
}
