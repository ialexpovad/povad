import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'bridge_settings.dart';

/// Durable configuration only. LAN consent, USB grants, and worker state
/// belong to the current process and are never restored from this document.
final class BridgeProfile {
  const BridgeProfile({
    required this.id,
    required this.number,
    this.name = '',
    this.settings = const BridgeSettings(),
  });

  final String id, name;
  final int number;
  final BridgeSettings settings;

  BridgeProfile copyWith({String? name, BridgeSettings? settings}) =>
      BridgeProfile(
        id: id,
        number: number,
        name: name ?? this.name,
        settings: settings ?? this.settings,
      );

  Map<String, Object> toJson({bool rememberSerialPort = true}) => {
    'id': id,
    'number': number,
    'name': name,
    'serialPort': rememberSerialPort ? settings.serialPort : '',
    'baud': settings.baud,
    'parity': settings.parity,
    'tcpPort': settings.tcpPort,
    'waitNextClient': settings.waitNextClient,
    'allowedClients': settings.allowedClients,
    'transport': settings.transport.name,
    'stopBits': settings.stopBits,
    'bleName': settings.bleName,
    'bleServiceUuid': settings.bleServiceUuid,
    'bleWriteUuid': settings.bleWriteUuid,
    'bleNotifyUuid': settings.bleNotifyUuid,
    'bleRequirePairing': settings.bleRequirePairing,
  };

  factory BridgeProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final number = json['number'];
    if (id is! String || id.isEmpty || number is! int || number < 1) {
      throw const FormatException('Invalid bridge profile identity');
    }
    return BridgeProfile(
      id: id,
      number: number,
      name: json['name'] as String,
      settings: BridgeSettings(
        serialPort: json['serialPort'] as String,
        baud: json['baud'] as String,
        parity: json['parity'] as String,
        tcpPort: json['tcpPort'] as String,
        waitNextClient: json['waitNextClient'] as bool,
        allowedClients: json['allowedClients'] as String,
        transport: json['transport'] == 'ble'
            ? BridgeTransport.ble
            : BridgeTransport.tcp,
        stopBits: json['stopBits'] == 2 ? 2 : 1,
        bleName: json['bleName'] as String? ?? 'Povad BLE',
        bleServiceUuid: json['bleServiceUuid'] as String? ?? 'FFE0',
        bleWriteUuid: json['bleWriteUuid'] as String? ?? 'FFE2',
        bleNotifyUuid: json['bleNotifyUuid'] as String? ?? 'FFE1',
        bleRequirePairing: json['bleRequirePairing'] as bool? ?? true,
      ),
    );
  }
}

final class BridgeProfiles {
  BridgeProfiles({
    required List<BridgeProfile> profiles,
    required this.selectedId,
  }) : profiles = List.unmodifiable(profiles) {
    if (profiles.isEmpty ||
        profiles.map((p) => p.id).toSet().length != profiles.length ||
        profiles.map((p) => p.number).toSet().length != profiles.length ||
        !profiles.any((p) => p.id == selectedId)) {
      throw const FormatException('Invalid bridge profile collection');
    }
  }

  final List<BridgeProfile> profiles;
  final String selectedId;

  String encode({bool rememberSerialPort = true}) => jsonEncode({
    'version': 2,
    'selectedId': selectedId,
    'profiles': [
      for (final profile in profiles)
        profile.toJson(rememberSerialPort: rememberSerialPort),
    ],
  });

  factory BridgeProfiles.decode(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    if (data['version'] != 1 && data['version'] != 2) {
      throw const FormatException('Unsupported bridge profile version');
    }
    return BridgeProfiles(
      selectedId: data['selectedId'] as String,
      profiles: [
        for (final value in data['profiles'] as List)
          BridgeProfile.fromJson(value as Map<String, dynamic>),
      ],
    );
  }
}

abstract interface class BridgeProfilesStore {
  Future<BridgeProfiles> read();
  Future<void> save(BridgeProfiles profiles);
}

final class DeviceBridgeProfilesStore implements BridgeProfilesStore {
  DeviceBridgeProfilesStore({
    this.rememberSerialPort = true,
    BridgeSettingsStore? legacy,
    Future<String?> Function()? readValue,
    Future<void> Function(String)? writeValue,
    // Keep legacy construction lazy: it may require the platform plugin.
    // ignore: prefer_initializing_formals
  }) : _legacy = legacy,
       _readValue =
           readValue ?? (() => SharedPreferencesAsync().getString(_key)),
       _writeValue =
           writeValue ??
           ((value) => SharedPreferencesAsync().setString(_key, value));

  static const _key = 'bridge.profiles.v1';
  final bool rememberSerialPort;
  final BridgeSettingsStore? _legacy;
  final Future<String?> Function() _readValue;
  final Future<void> Function(String) _writeValue;

  @override
  Future<BridgeProfiles> read() async {
    final encoded = await _readValue();
    if (encoded != null) {
      final saved = BridgeProfiles.decode(encoded);
      if (rememberSerialPort) return saved;
      return BridgeProfiles(
        selectedId: saved.selectedId,
        profiles: [
          for (final p in saved.profiles)
            p.copyWith(settings: p.settings.copyWith(serialPort: '')),
        ],
      );
    }
    final settings =
        await (_legacy ??
                DeviceBridgeSettingsStore(
                  rememberSerialPort: rememberSerialPort,
                ))
            .read() ??
        const BridgeSettings();
    final migrated = BridgeProfiles(
      selectedId: 'bridge-1',
      profiles: [BridgeProfile(id: 'bridge-1', number: 1, settings: settings)],
    );
    // Keep the old keys intact. Only a fully written document completes
    // migration, so a failed write can be retried on the next launch.
    await save(migrated);
    return migrated;
  }

  @override
  Future<void> save(BridgeProfiles profiles) =>
      _writeValue(profiles.encode(rememberSerialPort: rememberSerialPort));
}
