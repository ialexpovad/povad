import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

const povadServiceType = '_povad-bridge._tcp';

final class BridgeAdvertisement {
  const BridgeAdvertisement({
    required this.port,
    required this.serial,
    required this.busy,
  });

  final int port;
  final String serial;
  final bool busy;

  String get signature => '$port|$serial|$busy';

  BonsoirService toService() => BonsoirService(
    name: 'Povad',
    type: povadServiceType,
    port: port,
    attributes: {
      'v': '1',
      'mode': 'raw-rtu',
      'port': '$port',
      'serial': serial.split(RegExp(r'[/\\]')).last,
      'busy': busy ? '1' : '0',
    },
  );
}

/// Serializes registrations so a rapid connect/disconnect cannot leave a
/// stale TXT record behind. The owner supplies null whenever LAN is off.
final class LanDiscoveryPublisher {
  BonsoirBroadcast? _broadcast;
  String? _signature;
  Future<void> _tail = Future<void>.value();

  Future<void> update(BridgeAdvertisement? desired) {
    final completer = Completer<void>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      try {
        await _apply(desired);
        completer.complete();
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<void> _apply(BridgeAdvertisement? desired) async {
    if (desired?.signature == _signature) return;
    final previous = _broadcast;
    _broadcast = null;
    _signature = null;
    if (previous != null) await previous.stop();
    if (desired == null) return;
    final next = BonsoirBroadcast(
      service: desired.toService(),
      printLogs: false,
    );
    await next.initialize();
    try {
      await next.start();
    } catch (_) {
      await next.stop();
      rethrow;
    }
    _broadcast = next;
    _signature = desired.signature;
  }
}
