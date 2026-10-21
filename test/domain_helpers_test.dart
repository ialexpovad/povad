import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:povad/design/povad_components.dart';
import 'package:povad/app/lan_discovery.dart';
import 'package:povad/domain/client_allowlist.dart';
import 'package:povad/domain/serial_port_discovery.dart';
import 'package:povad/domain/trouble_hint.dart';

void main() {
  test('LAN service uses neutral Povad identity and exact TXT fields', () {
    const advertisement = BridgeAdvertisement(
      port: 9268,
      serial: '/dev/cu.usbserial-01',
      busy: true,
    );
    final service = advertisement.toService();
    expect(service.type, '_povad-bridge._tcp');
    expect(service.port, 9268);
    expect(service.attributes, {
      'v': '1',
      'mode': 'raw-rtu',
      'port': '9268',
      'serial': 'cu.usbserial-01',
      'busy': '1',
    });
  });

  test(
    'Bonjour instance names fit the UTF-8 byte limit without broken characters',
    () {
      final advertisement = BridgeAdvertisement(
        port: 9268,
        serial: 'COM3',
        busy: false,
        name: 'Povad ${'Прылада' * 10}',
      );
      final encoded = utf8.encode(advertisement.toService().name);
      expect(encoded.length, lessThanOrEqualTo(63));
      expect(utf8.decode(encoded), advertisement.serviceName);
      expect(advertisement.serviceName, startsWith('Povad Прылада'));
    },
  );

  test('LAN allowlist accepts exact IPv4 peers only', () {
    expect(parseClientAllowlist(''), isEmpty);
    expect(parseClientAllowlist('192.168.1.20, 10.0.0.7'), [
      '192.168.1.20',
      '10.0.0.7',
    ]);
    expect(parseClientAllowlist('192.168.1.020'), isNull);
    expect(parseClientAllowlist('192.168.1.256'), isNull);
    expect(parseClientAllowlist('192.168.1.20,'), isNull);
    expect(parseClientAllowlist('example.org'), isNull);
  });
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
    expect(SerialPortDiscovery(operatingSystem: 'windows').supported, isTrue);
  });

  test(
    'Windows discovery suggests current COM names in numeric order',
    () async {
      final discovery = SerialPortDiscovery(
        operatingSystem: 'windows',
        list: () async => ['COM11', 'LPT1', 'com2', 'COM1', 'COM0', 'COM3:'],
      );
      expect(await discovery.discover(), ['COM1', 'COM2', 'COM11']);
    },
  );

  test('worker messages map to actionable hints', () {
    expect(
      troubleHintFor('Cannot open serial port exclusively'),
      TroubleHint.serialAccess,
    );
    expect(
      troubleHintFor(
        'Cannot open USB serial device; check permission, adapter, and settings',
      ),
      TroubleHint.serialAccess,
    );
    expect(troubleHintFor('Cannot bind TCP listener'), TroubleHint.tcpPort);
    expect(troubleHintFor('Cannot listen on TCP port'), TroubleHint.tcpPort);
    expect(
      troubleHintFor('Serial device disconnected'),
      TroubleHint.disconnected,
    );
    expect(
      troubleHintFor('Unsupported serial baud rate'),
      TroubleHint.settings,
    );
    expect(
      troubleHintFor('Client disconnected; restart for another session'),
      TroubleHint.clientLeft,
    );
    // Uncertain delivery outranks the client leaving.
    expect(
      troubleHintFor(
        'Client closed with output pending; delivery is uncertain',
      ),
      TroubleHint.delivery,
    );
    expect(troubleHintFor('Transport worker failed'), isNull);
    expect(troubleHintFor(null), isNull);
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
