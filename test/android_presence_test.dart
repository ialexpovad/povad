import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/app/android_presence.dart';
import 'package:povad/domain/bridge_fleet.dart';
import 'package:povad_core/povad_core.dart';

import 'bridge_fleet_test.dart' show FakeBridgeSession;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('povad/background');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late BridgeFleet fleet;
  late AndroidPresence presence;
  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    fleet = BridgeFleet(sessionFactory: FakeBridgeSession.new);
    presence = AndroidPresence(fleet);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'start' ? true : null;
    });
  });
  tearDown(() async {
    await fleet.close();
    messenger.setMockMethodCallHandler(channel, null);
    channel.setMethodCallHandler(null);
  });
  Future<void> start(String id, int port) => fleet.start(
    id,
    BridgeConfig(serialPort: 'usb:$id:0', tcpPort: port),
    prepare: () => presence.prepareStart('usb:$id:0', const Locale('en')),
  );
  Future<void> reflect() => presence.reflect(
    fleet.aggregateState,
    const Locale('en'),
    workerActive: fleet.active,
  );
  Future<void> serviceStopped(int generation) async {
    final done = Completer<void>();
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('serviceStopped', generation),
      ),
      (_) => done.complete(),
    );
    await done.future;
  }

  test(
    'one notification counts all workers and stays for the remaining bridge',
    () async {
      final first = fleet.selected.id;
      final second = fleet.add().id;
      await start(first, 9268);
      await start(second, 9269);
      await reflect();
      expect(calls.last.arguments['status'], '2 active bridges');
      await fleet.stop(first);
      await reflect();
      expect(calls.last.method, 'update');
      expect(calls.last.arguments['status'], '1 active bridge');
      expect(calls.where((c) => c.method == 'stop'), isEmpty);
      await fleet.stop(second);
      await reflect();
      expect(calls.where((c) => c.method == 'stop'), hasLength(1));
    },
  );

  test(
    'late acknowledgement of intentional stop cannot stop a new generation',
    () async {
      final id = fleet.selected.id;
      await start(id, 9268);
      final oldGeneration = calls.last.arguments['generation'] as int;
      await fleet.stopAll();
      await reflect();
      await start(id, 9268);
      final newGeneration = calls.last.arguments['generation'] as int;
      expect(newGeneration, greaterThan(oldGeneration));
      await serviceStopped(oldGeneration);
      expect(fleet.activeCount, 1);
      await serviceStopped(newGeneration);
      expect(fleet.active, false);
    },
  );

  test('unexpected loss of foreground service stops every worker', () async {
    final first = fleet.selected.id;
    final second = fleet.add().id;
    await start(first, 9268);
    await start(second, 9269);
    await serviceStopped(calls.last.arguments['generation'] as int);
    expect(fleet.active, false);
  });

  test('a rejected preparation releases only its own reservations', () async {
    final first = fleet.selected.id;
    final second = fleet.add().id;
    await start(first, 9268);
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') {
        throw PlatformException(code: 'USB_PERMISSION');
      }
      return null;
    });
    await expectLater(start(second, 9269), throwsA(isA<PlatformException>()));
    expect(fleet.connection(first).active, true);
    expect(fleet.connection(second).active, false);
    expect(fleet.connection(second).reservedConfig, isNull);
  });
}
