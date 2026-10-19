import 'package:flutter_test/flutter_test.dart';
import 'package:povad/design/povad_components.dart';
import 'package:povad/domain/serial_port_discovery.dart';

void main() {
  test(
    'macOS discovery lists callout devices and skips system ports',
    () async {
      final discovery = SerialPortDiscovery(
        operatingSystem: 'macos',
        list: () async => [
          'tty.usbserial-0001',
          'cu.Bluetooth-Incoming-Port',
          'cu.debug-console',
          'cu.usbserial-0001',
          'cu.ZZZ-device',
          'disk0',
        ],
      );
      expect(await discovery.discover(), [
        '/dev/cu.usbserial-0001',
        '/dev/cu.ZZZ-device',
      ]);
    },
  );

  test('Linux discovery keeps adapters and skips built-in UARTs', () async {
    final discovery = SerialPortDiscovery(
      operatingSystem: 'linux',
      list: () async => ['ttyS0', 'ttyACM0', 'ttyUSB1', 'ttyUSB0', 'tty1'],
    );
    expect(await discovery.discover(), [
      '/dev/ttyACM0',
      '/dev/ttyUSB0',
      '/dev/ttyUSB1',
    ]);
  });

  test('discovery is silent when the device directory is unreadable', () async {
    final discovery = SerialPortDiscovery(
      operatingSystem: 'macos',
      list: () async => throw const FileSystemDenied(),
    );
    expect(await discovery.discover(), isEmpty);
    expect(SerialPortDiscovery(operatingSystem: 'windows').supported, isFalse);
  });

  test('byte counts and durations are compact and localized', () {
    expect(formatBytes(0, 'en'), '0 B');
    expect(formatBytes(1536, 'en'), '1.5 KB');
    expect(formatBytes(1536, 'be'), '1,5 KB');
    expect(formatBytes(5 * 1024 * 1024, 'en'), '5.0 MB');
    expect(formatDuration(const Duration(seconds: 65)), '01:05');
    expect(formatDuration(const Duration(hours: 2, seconds: 3)), '2:00:03');
  });
}

class FileSystemDenied implements Exception {
  const FileSystemDenied();
}
