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
  });
}

Future<void> verifyBonjour() async {
  if (!Platform.isMacOS) return;
  final listener = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
  final publisher = LanDiscoveryPublisher();
  try {
    await publisher.update(
      BridgeAdvertisement(
        port: listener.port,
        serial: '/dev/cu.test',
        busy: false,
      ),
    );
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
                line.contains('Povad') &&
                !found.isCompleted) {
              found.complete();
            }
          });
      await found.future.timeout(const Duration(seconds: 15));
    } finally {
      browser.kill();
    }
    final resolver = await Process.start('/usr/bin/dns-sd', [
      '-L',
      'Povad',
      povadServiceType,
      'local',
    ]);
    try {
      final txt = Completer<String>();
      resolver.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.contains('v=1') && !txt.isCompleted) txt.complete(line);
          });
      final record = await txt.future.timeout(const Duration(seconds: 15));
      expect(record, contains('mode=raw-rtu'));
      expect(record, contains('port=${listener.port}'));
      expect(record, contains('serial=cu.test'));
      expect(record, contains('busy=0'));
    } finally {
      resolver.kill();
    }
  } finally {
    await publisher.update(null);
    await listener.close();
  }
}
