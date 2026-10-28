import 'package:flutter_test/flutter_test.dart';
import 'package:povad/domain/bridge_profiles.dart';
import 'package:povad/domain/bridge_settings.dart';
import 'package:povad/features/bridge_setup_page.dart';

class LegacyStore implements BridgeSettingsStore {
  int reads = 0;
  @override
  Future<BridgeSettings?> read() async {
    reads++;
    return const BridgeSettings(
      serialPort: 'COM7',
      baud: '9600',
      parity: 'E',
      tcpPort: '9370',
      waitNextClient: true,
      allowedClients: '192.168.1.2',
    );
  }

  @override
  Future<void> save(BridgeSettings settings) async {}
}

void main() {
  test('migration preserves the old settings and runs only once', () async {
    String? value;
    final legacy = LegacyStore();
    final store = DeviceBridgeProfilesStore(
      legacy: legacy,
      readValue: () async => value,
      writeValue: (next) async {
        value = next;
      },
    );
    final saved = await store.read();
    expect(saved.profiles.single.settings.serialPort, 'COM7');
    expect(saved.profiles.single.settings.parity, 'E');
    expect(saved.profiles.single.settings.waitNextClient, true);
    expect(saved.profiles.single.settings.allowedClients, '192.168.1.2');
    expect(saved.profiles.single.settings.transport, BridgeTransport.tcp);
    expect(saved.profiles.single.settings.stopBits, 1);
    await store.read();
    expect(legacy.reads, 1);
    expect(value, isNot(contains('allowLan')));
  });
  test(
    'multiple profiles and selection survive storage, Android drops USB paths',
    () async {
      String? value;
      final store = DeviceBridgeProfilesStore(
        rememberSerialPort: false,
        readValue: () async => value,
        writeValue: (next) async {
          value = next;
        },
      );
      final profiles = [
        for (var i = 1; i <= 4; i++)
          BridgeProfile(
            id: 'id-$i',
            number: i,
            name: 'Device $i',
            settings: BridgeSettings(
              serialPort: 'usb:/dev/bus/usb/001/001:$i',
              tcpPort: '${9267 + i}',
            ),
          ),
      ];
      await store.save(BridgeProfiles(profiles: profiles, selectedId: 'id-3'));
      final saved = await store.read();
      expect(saved.selectedId, 'id-3');
      expect(saved.profiles.length, 4);
      expect(
        saved.profiles.map((p) => p.settings.serialPort),
        everyElement(isEmpty),
      );
      expect(saved.profiles.last.settings.tcpPort, '9271');
    },
  );
  test(
    'Android keeps a built-in port selection, whose name is stable',
    () async {
      String? value;
      final store = DeviceBridgeProfilesStore(
        rememberSerialPort: false,
        readValue: () async => value,
        writeValue: (next) async {
          value = next;
        },
      );
      await store.save(
        BridgeProfiles(
          selectedId: 'a',
          profiles: [
            BridgeProfile(
              id: 'a',
              number: 1,
              name: 'Built-in',
              settings: const BridgeSettings(
                serialPort: 'usb:builtin:expansion:0',
              ),
            ),
            BridgeProfile(
              id: 'b',
              number: 2,
              name: 'Adapter',
              settings: const BridgeSettings(
                serialPort: 'usb:/dev/bus/usb/001/002:0',
              ),
            ),
          ],
        ),
      );
      final saved = await store.read();
      expect(
        saved.profiles.first.settings.serialPort,
        'usb:builtin:expansion:0',
      );
      expect(saved.profiles.last.settings.serialPort, isEmpty);
    },
  );
  test('v1 profiles migrate as TCP and BLE settings round-trip', () {
    const legacy =
        '{"version":1,"selectedId":"old","profiles":[{"id":"old","number":1,"name":"",'
        '"serialPort":"COM7","baud":"115200","parity":"N","tcpPort":"9268",'
        '"waitNextClient":false,"allowedClients":""}]}';
    final old = BridgeProfiles.decode(legacy).profiles.single.settings;
    expect(old.transport, BridgeTransport.tcp);
    expect(old.stopBits, 1);
    final ble = BridgeProfiles(
      selectedId: 'old',
      profiles: [
        BridgeProfile(
          id: 'old',
          number: 1,
          settings: old.copyWith(
            transport: BridgeTransport.ble,
            stopBits: 2,
            bleName: 'Povad BLE',
            bleServiceUuid: 'FFE0',
            bleWriteUuid: 'FFE2',
            bleNotifyUuid: 'FFE1',
          ),
        ),
      ],
    );
    final restored = BridgeProfiles.decode(ble.encode())
        .profiles
        .single
        .settings;
    expect(restored.transport, BridgeTransport.ble);
    expect(restored.stopBits, 2);
    expect(bleSettingsValid(restored), true);
    expect(canonicalBleUuid('FFE1'), '0000ffe1-0000-1000-8000-00805f9b34fb');
    expect(bleSettingsValid(restored.copyWith(bleNotifyUuid: 'FFE2')), false);
  });
  test(
    'corrupt or newer documents are not overwritten with an empty profile',
    () async {
      var writes = 0;
      final store = DeviceBridgeProfilesStore(
        readValue: () async => '{}',
        writeValue: (next) async {
          writes++;
        },
      );
      await expectLater(store.read(), throwsFormatException);
      expect(writes, 0);
    },
  );
}
