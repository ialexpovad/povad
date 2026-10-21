import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:povad/app/lan_discovery.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android NSD finds a Povad LAN bridge and its TXT record', (
    tester,
  ) async {
    if (!Platform.isAndroid) return;
    final listener = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final publisher = LanDiscoveryPublisher(id: 'qa-first');
    final secondListener = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final secondPublisher = LanDiscoveryPublisher(id: 'qa-second');
    final discovery = BonsoirDiscovery(
      type: povadServiceType,
      printLogs: false,
    );
    StreamSubscription<BonsoirDiscoveryEvent>? subscription;
    try {
      await discovery.initialize();
      final found = Completer<BonsoirService>();
      final secondFound = Completer<BonsoirService>();
      subscription = discovery.eventStream?.listen((event) {
        if (event is BonsoirDiscoveryServiceFoundEvent &&
            event.service.name.startsWith('Povad')) {
          unawaited(event.service.resolve(discovery.serviceResolver));
        }
        if (event is! BonsoirDiscoveryServiceResolvedEvent) return;
        final service = event.service;
        if (service.name.startsWith('Povad') &&
            service.port == listener.port &&
            !found.isCompleted) {
          found.complete(service);
        }
        if (service.name.startsWith('Povad') &&
            service.port == secondListener.port &&
            !secondFound.isCompleted) {
          secondFound.complete(service);
        }
      });
      await discovery.start();
      await publisher.update(
        BridgeAdvertisement(
          port: listener.port,
          serial: 'usb:/dev/bus/usb/test:0',
          busy: false,
        ),
      );
      await secondPublisher.update(
        BridgeAdvertisement(
          port: secondListener.port,
          serial: 'second:0',
          busy: true,
          name: 'Povad-second-${secondListener.port}',
        ),
      );
      final secondService = await secondFound.future.timeout(
        const Duration(seconds: 20),
      );
      expect(secondService.attributes, containsPair('busy', '1'));
      expect(secondService.attributes, containsPair('serial', 'second:0'));
      expect(
        secondService.attributes,
        containsPair('port', '${secondListener.port}'),
      );
      final service = await found.future.timeout(const Duration(seconds: 20));
      expect(service.type, contains(povadServiceType));
      expect(service.attributes, containsPair('v', '1'));
      expect(service.attributes, containsPair('mode', 'raw-rtu'));
      expect(service.attributes, containsPair('port', '${listener.port}'));
      expect(service.attributes, containsPair('serial', 'test:0'));
      expect(service.attributes, containsPair('busy', '0'));
    } finally {
      await subscription?.cancel();
      await discovery.stop();
      await publisher.update(null);
      await secondPublisher.update(null);
      await secondListener.close();
      await listener.close();
    }
  });
}
