import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../domain/bridge_fleet.dart';
import '../domain/bridge_view_state.dart';
import '../features/overview_page.dart';
import '../l10n/generated/app_localizations.dart';
import 'bridge_presence.dart';

/// A single foreground service covers every worker. Channel operations are
/// ordered so stopping one bridge cannot tear down another bridge's service.
final class AndroidPresence implements BridgePresence {
  AndroidPresence(this.fleet) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'serviceStopped') {
        final generation = call.arguments as int?;
        if (generation != null && _expectedStops.remove(generation)) return;
        if (generation != null && generation != _generation) return;
        _active = false;
        if (fleet.active) await fleet.stopAll();
      }
    });
  }

  static const MethodChannel _channel = MethodChannel('povad/background');
  static const MethodChannel _bleChannel = MethodChannel('povad/ble_host');
  final BridgeFleet fleet;
  bool _active = false;
  int _generation = 0;
  final Set<int> _expectedStops = {};
  String? _lastStatus;
  Future<void> _tail = Future.value();

  Future<void> _enqueue(Future<void> Function() task) {
    final next = _tail.then((_) => task());
    _tail = next.catchError((Object _) {});
    return next;
  }

  String _status(Locale locale) {
    final l = lookupAppLocalizations(locale);
    return fleet.connections.length == 1
        ? StateCopy.of(fleet.aggregateState, l).title
        : l.bridgesActive(fleet.activeCount);
  }

  @override
  Future<void> prepareStart(String serialSelection, Locale locale) =>
      _prepareStart(serialSelection, locale, 'tcp');

  Future<void> prepareBle(String serialSelection, Locale locale) async {
    final ready = await _bleChannel.invokeMethod<bool>('prepare');
    if (ready != true) {
      throw StateError('BLE advertising is unavailable or Bluetooth is off');
    }
    await _prepareStart(serialSelection, locale, 'ble');
  }

  Future<void> _prepareStart(
    String serialSelection,
    Locale locale,
    String peerKind,
  ) => _enqueue(() async {
    if (!_active) _generation++;
    final status = _status(locale);
    final started = await _channel.invokeMethod<bool>('start', {
      'selection': serialSelection,
      'peerKind': peerKind,
      'status': status,
      'generation': _generation,
    });
    if (started != true) {
      throw StateError('Android background service did not start');
    }
    _active = true;
    _lastStatus = status;
  });

  @override
  Future<void> reflect(
    BridgeViewState state,
    Locale locale, {
    required bool workerActive,
  }) => _enqueue(() async {
    if (!_active) return;
    // Read the manager at execution time; a queued snapshot may be stale.
    if (!fleet.active) {
      _expectedStops.add(_generation);
      await _channel.invokeMethod<void>('stop');
      _active = false;
      _lastStatus = null;
      return;
    }
    final status = _status(locale);
    if (status == _lastStatus) return;
    await _channel.invokeMethod<void>('update', {'status': status});
    _lastStatus = status;
  });
}
