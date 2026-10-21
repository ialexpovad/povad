import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/services.dart';

const povadServiceType = '_povad-bridge._tcp';

final class BridgeAdvertisement {
  const BridgeAdvertisement({
    required this.port,
    required this.serial,
    required this.busy,
    this.name = 'Povad',
  });

  final int port;
  final String serial;
  final bool busy;
  final String name;

  // DNS-SD instance names have a 63-byte UTF-8 limit, not 63 characters.
  String get serviceName {
    final result = StringBuffer();
    var bytes = 0;
    for (final rune in name.runes) {
      final character = String.fromCharCode(rune);
      final length = utf8.encode(character).length;
      if (bytes + length > 63) break;
      result.write(character);
      bytes += length;
    }
    return result.isEmpty ? 'Povad' : result.toString();
  }

  String get signature => '$serviceName|$port|$serial|$busy';

  BonsoirService toService() => BonsoirService(
    name: serviceName,
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
  LanDiscoveryPublisher({this.id = 'default'});
  final String id;
  static const _macBonjour = MethodChannel('povad/bonjour');
  BonsoirBroadcast? _broadcast;
  bool _macRegistered = false;
  int? _macPort;
  String? _macSerial;
  String? _macName;
  String? _serviceName;

  String? get serviceName => _serviceName;
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
    if (Platform.isMacOS) {
      final serial = desired?.toService().attributes['serial'];
      if (_macRegistered &&
          desired != null &&
          _macPort == desired.port &&
          _macSerial == serial &&
          _macName == desired.serviceName) {
        await _macBonjour.invokeMethod<bool>('update', {
          'id': id,
          'busy': desired.busy,
        });
        _signature = desired.signature;
        return;
      }
      if (_macRegistered) {
        await _macBonjour.invokeMethod<bool>('stop', {'id': id});
        _macRegistered = false;
        _macPort = null;
        _macSerial = null;
        _macName = null;
        _serviceName = null;
        _signature = null;
      }
      if (desired == null) return;
      _serviceName = await _macBonjour.invokeMethod<String>('start', {
        'id': id,
        'name': desired.serviceName,
        'port': desired.port,
        'serial': serial,
        'busy': desired.busy,
      });
      _macRegistered = true;
      _macPort = desired.port;
      _macSerial = serial;
      _macName = desired.serviceName;
      _signature = desired.signature;
      return;
    }
    final previous = _broadcast;
    if (previous != null) {
      await previous.stop();
      _broadcast = null;
      _signature = null;
    }
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
