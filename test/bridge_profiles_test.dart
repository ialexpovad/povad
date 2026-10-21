import 'package:flutter_test/flutter_test.dart';
import 'package:povad/domain/bridge_profiles.dart';
import 'package:povad/domain/bridge_settings.dart';

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
