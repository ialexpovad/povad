import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:povad/app/lan_discovery.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('macOS advertises Povad through Bonjour', (tester) async {
    await verifyBonjour();
    await verifyMultipleBonjour();
  });
}

Future<void> verifyBonjour() async {
  if (!Platform.isMacOS) return;
  final listener = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
  final requestedName = 'Povad-test-${listener.port}';
  final publisher = LanDiscoveryPublisher();
  try {
    await publisher.update(
      BridgeAdvertisement(
        port: listener.port,
        serial: '/dev/cu.test',
        busy: false,
        name: requestedName,
      ),
    );
    final serviceName = publisher.serviceName!;
    final browser = await Process.start('/usr/bin/dns-sd', [
      '-B',
      povadServiceType,
    ]);
    try {
      final found = Completer<void>();
      browser.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.contains('Add') &&
                line.contains(serviceName) &&
                !found.isCompleted) {
              found.complete();
            }
          });
      await found.future.timeout(const Duration(seconds: 15));
    } finally {
      browser.kill();
      await browser.exitCode.timeout(const Duration(seconds: 3));
    }
    final record = await _resolveRecord(serviceName, 'busy=0');
    expect(record, contains('mode=raw-rtu'));
    expect(record, contains('port=${listener.port}'));
    expect(record, contains('serial=cu.test'));
    expect(record, contains('busy=0'));

    await publisher.update(
      BridgeAdvertisement(
        port: listener.port,
        serial: '/dev/cu.test',
        busy: true,
        name: requestedName,
      ),
    );
    expect(await _resolveRecord(serviceName, 'busy=1'), contains('busy=1'));
  } finally {
    await publisher.update(null);
    await listener.close();
  }
}

Future<String> _resolveRecord(String serviceName, String expectedBusy) async {
  final resolver = await Process.start('/usr/bin/dns-sd', [
    '-L',
    serviceName,
    povadServiceType,
    'local',
  ]);
  try {
    final txt = Completer<String>();
    resolver.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.contains('v=1') &&
              line.contains(expectedBusy) &&
              !txt.isCompleted) {
            txt.complete(line);
          }
        });
    return await txt.future.timeout(const Duration(seconds: 15));
  } finally {
    resolver.kill();
    await resolver.exitCode.timeout(const Duration(seconds: 3));
  }
}

Future<void> verifyMultipleBonjour() async {
  if (!Platform.isMacOS) return;
  final firstSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
  final secondSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
  final first = LanDiscoveryPublisher(id: 'qa-first');
  final second = LanDiscoveryPublisher(id: 'qa-second');
  BridgeAdvertisement advertisement(int port, String serial, bool busy) =>
      BridgeAdvertisement(
        port: port,
        serial: serial,
        busy: busy,
        name: 'Povad-multi-$port',
      );
  try {
    await first.update(advertisement(firstSocket.port, 'COM3', false));
    await second.update(advertisement(secondSocket.port, 'COM7', false));
    final firstName = first.serviceName!;
    final secondName = second.serviceName!;
    expect(firstName, isNot(secondName));
    expect(
      await _resolveRecord(firstName, 'busy=0'),
      contains('port=${firstSocket.port}'),
    );
    expect(await _resolveRecord(secondName, 'busy=0'), contains('serial=COM7'));
    await first.update(advertisement(firstSocket.port, 'COM3', true));
    expect(await _resolveRecord(firstName, 'busy=1'), contains('serial=COM3'));
    expect(
      await _resolveRecord(secondName, 'busy=0'),
      contains('port=${secondSocket.port}'),
    );
    await first.update(null);
    expect(await _resolveRecord(secondName, 'busy=0'), contains('serial=COM7'));
  } finally {
    await first.update(null);
    await second.update(null);
    await firstSocket.close();
    await secondSocket.close();
  }
}
