import 'package:shared_preferences/shared_preferences.dart';

/// The operator's last bridge configuration. LAN access is deliberately not
/// stored: every launch starts on loopback until the operator opts in again.
final class BridgeSettings {
  const BridgeSettings({
    this.serialPort = '',
    this.baud = '115200',
    this.parity = 'N',
    this.tcpPort = '9268',
    this.waitNextClient = false,
    this.allowedClients = '',
  });

  final String serialPort, baud, parity, tcpPort;
  final bool waitNextClient;
  final String allowedClients;
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
  static const _parityKey = 'bridge.parity';
  static const _tcpKey = 'bridge.tcpPort';
  static const _waitNextKey = 'bridge.waitNextClient';
  static const _allowedClientsKey = 'bridge.allowedClients';

  @override
  Future<BridgeSettings?> read() async {
    final serial = rememberSerialPort
        ? await _store.getString(_serialKey)
        : null;
    final baud = await _store.getString(_baudKey);
    final parity = await _store.getString(_parityKey);
    final tcp = await _store.getString(_tcpKey);
    final waitNext = await _store.getBool(_waitNextKey);
    final allowedClients = await _store.getString(_allowedClientsKey);
    if (serial == null &&
        baud == null &&
        parity == null &&
        tcp == null &&
        waitNext == null &&
        allowedClients == null) {
      return null;
    }
    const defaults = BridgeSettings();
    return BridgeSettings(
      serialPort: serial ?? defaults.serialPort,
      baud: baud ?? defaults.baud,
      parity: {'N', 'E', 'O'}.contains(parity) ? parity! : defaults.parity,
      tcpPort: tcp ?? defaults.tcpPort,
      waitNextClient: waitNext ?? defaults.waitNextClient,
      allowedClients: allowedClients ?? defaults.allowedClients,
    );
  }

  @override
  Future<void> save(BridgeSettings settings) async {
    if (rememberSerialPort) {
      await _store.setString(_serialKey, settings.serialPort);
    }
    await _store.setString(_baudKey, settings.baud);
    await _store.setString(_parityKey, settings.parity);
    await _store.setString(_tcpKey, settings.tcpPort);
    await _store.setBool(_waitNextKey, settings.waitNextClient);
    await _store.setString(_allowedClientsKey, settings.allowedClients);
  }
}
