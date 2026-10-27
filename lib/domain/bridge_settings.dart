import 'package:shared_preferences/shared_preferences.dart';

enum BridgeTransport { tcp, ble }

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
    this.transport = BridgeTransport.tcp,
    this.stopBits = 1,
    this.bleName = 'Povad BLE',
    this.bleServiceUuid = 'FFE0',
    this.bleWriteUuid = 'FFE2',
    this.bleNotifyUuid = 'FFE1',
    this.bleRequirePairing = true,
  });

  BridgeSettings copyWith({
    String? serialPort,
    String? baud,
    String? parity,
    String? tcpPort,
    bool? waitNextClient,
    String? allowedClients,
    BridgeTransport? transport,
    int? stopBits,
    String? bleName,
    String? bleServiceUuid,
    String? bleWriteUuid,
    String? bleNotifyUuid,
    bool? bleRequirePairing,
  }) => BridgeSettings(
    serialPort: serialPort ?? this.serialPort,
    baud: baud ?? this.baud,
    parity: parity ?? this.parity,
    tcpPort: tcpPort ?? this.tcpPort,
    waitNextClient: waitNextClient ?? this.waitNextClient,
    allowedClients: allowedClients ?? this.allowedClients,
    transport: transport ?? this.transport,
    stopBits: stopBits ?? this.stopBits,
    bleName: bleName ?? this.bleName,
    bleServiceUuid: bleServiceUuid ?? this.bleServiceUuid,
    bleWriteUuid: bleWriteUuid ?? this.bleWriteUuid,
    bleNotifyUuid: bleNotifyUuid ?? this.bleNotifyUuid,
    bleRequirePairing: bleRequirePairing ?? this.bleRequirePairing,
  );

  final String serialPort, baud, parity, tcpPort;
  final bool waitNextClient;
  final String allowedClients;
  final BridgeTransport transport;
  final int stopBits;
  final String bleName, bleServiceUuid, bleWriteUuid, bleNotifyUuid;

  /// BLE clients must pair (encrypted, bonded). Off serves clients of BLE
  /// UART modules (BT24, HM-10) that never pair; anyone nearby may connect.
  final bool bleRequirePairing;
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
  static const _transportKey = 'bridge.transport';
  static const _stopBitsKey = 'bridge.stopBits';
  static const _bleNameKey = 'bridge.bleName';
  static const _bleServiceKey = 'bridge.bleServiceUuid';
  static const _bleWriteKey = 'bridge.bleWriteUuid';
  static const _bleNotifyKey = 'bridge.bleNotifyUuid';
  static const _blePairingKey = 'bridge.bleRequirePairing';

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
    final transport = await _store.getString(_transportKey);
    final stopBits = await _store.getInt(_stopBitsKey);
    final bleName = await _store.getString(_bleNameKey);
    final bleService = await _store.getString(_bleServiceKey);
    final bleWrite = await _store.getString(_bleWriteKey);
    final bleNotify = await _store.getString(_bleNotifyKey);
    final blePairing = await _store.getBool(_blePairingKey);
    if (serial == null &&
        baud == null &&
        parity == null &&
        tcp == null &&
        waitNext == null &&
        allowedClients == null &&
        transport == null &&
        stopBits == null &&
        bleName == null &&
        bleService == null &&
        bleWrite == null &&
        bleNotify == null) {
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
      transport: transport == 'ble' ? BridgeTransport.ble : BridgeTransport.tcp,
      stopBits: stopBits == 2 ? 2 : 1,
      bleName: bleName ?? defaults.bleName,
      bleServiceUuid: bleService ?? defaults.bleServiceUuid,
      bleWriteUuid: bleWrite ?? defaults.bleWriteUuid,
      bleNotifyUuid: bleNotify ?? defaults.bleNotifyUuid,
      bleRequirePairing: blePairing ?? defaults.bleRequirePairing,
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
    await _store.setString(_transportKey, settings.transport.name);
    await _store.setInt(_stopBitsKey, settings.stopBits);
    await _store.setString(_bleNameKey, settings.bleName);
    await _store.setString(_bleServiceKey, settings.bleServiceUuid);
    await _store.setString(_bleWriteKey, settings.bleWriteUuid);
    await _store.setString(_bleNotifyKey, settings.bleNotifyUuid);
    await _store.setBool(_blePairingKey, settings.bleRequirePairing);
  }
}
