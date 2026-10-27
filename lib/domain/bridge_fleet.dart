import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:povad_core/povad_core.dart';

import 'bridge_profiles.dart';
import 'bridge_session.dart';
import 'bridge_settings.dart';
import 'bridge_view_state.dart';

final class BridgeConnection {
  BridgeConnection(this.profile, this.session);

  BridgeProfile profile;
  final BridgeSession? session;
  bool allowLan = false;
  bool preparing = false;
  BridgeConfig? reservedConfig;
  String? serialIdentity;
  String? startupError;
  BridgeConflict? conflict;
  DateTime? startedAt;
  int generation = 0;
  Future<void>? pendingStart;
  BridgeViewState previewState = BridgeViewState.stopped;

  String get id => profile.id;
  bool get active => preparing || session?.active == true;
  BridgeViewState get state {
    if (preparing) return BridgeViewState.starting;
    final worker = session;
    if (worker == null) return previewState;
    if (!worker.active &&
        (startupError != null || worker.controlError != null)) {
      return BridgeViewState.error;
    }
    return switch (worker.state) {
      BridgeState.stopped => BridgeViewState.stopped,
      BridgeState.starting => BridgeViewState.starting,
      BridgeState.listening => BridgeViewState.listening,
      BridgeState.connected => BridgeViewState.connected,
      BridgeState.stopping => BridgeViewState.stopping,
      BridgeState.interrupted => BridgeViewState.interrupted,
      BridgeState.fault => BridgeViewState.error,
    };
  }
}

enum BridgeConflictKind { serial, tcp, ble }

final class BridgeConflict implements Exception {
  const BridgeConflict(this.kind, this.ownerId);
  final BridgeConflictKind kind;
  final String ownerId;
}

/// One owner for all profiles and workers. The collection has no two-bridge
/// limit. Reservations precede every asynchronous startup preparation.
final class BridgeFleet extends ChangeNotifier {
  BridgeFleet({
    BridgeSession? firstSession,
    BridgeSession Function()? sessionFactory,
  }) : _sessionFactory =
           sessionFactory ?? (firstSession == null ? null : BridgeSession.new) {
    _attach(
      BridgeProfile(id: 'bridge-1', number: 1),
      firstSession ?? sessionFactory?.call(),
    );
  }

  final BridgeSession Function()? _sessionFactory;
  final List<BridgeConnection> _connections = [];
  final Map<String, VoidCallback> _listeners = {};
  String _selectedId = 'bridge-1';
  bool _shutdown = false;
  bool _closed = false;
  bool _stoppingAll = false;
  Future<void>? _closing;
  Future<void>? _stopping;

  List<BridgeConnection> get connections => List.unmodifiable(_connections);
  BridgeConnection get selected => connection(_selectedId);
  bool get live =>
      _sessionFactory != null || _connections.any((c) => c.session != null);
  bool get shuttingDown => _shutdown || _stoppingAll || _closed;
  bool get active => _connections.any((c) => c.active);
  int get activeCount => _connections.where((c) => c.active).length;
  BridgeViewState get aggregateState {
    for (final state in [
      BridgeViewState.error,
      BridgeViewState.interrupted,
      BridgeViewState.connected,
      BridgeViewState.listening,
      BridgeViewState.starting,
      BridgeViewState.stopping,
    ]) {
      if (_connections.any((c) => c.state == state)) return state;
    }
    return BridgeViewState.stopped;
  }

  BridgeConnection connection(String id) =>
      _connections.firstWhere((c) => c.id == id);

  BridgeProfiles get document => BridgeProfiles(
    profiles: [for (final entry in _connections) entry.profile],
    selectedId: _selectedId,
  );

  void _attach(BridgeProfile profile, BridgeSession? session) {
    final entry = BridgeConnection(profile, session);
    _connections.add(entry);
    void changed() {
      if (!entry.active) {
        entry.reservedConfig = null;
        entry.serialIdentity = null;
      }
      if (entry.state == BridgeViewState.listening ||
          entry.state == BridgeViewState.connected) {
        entry.startedAt ??= DateTime.now();
      } else if (!entry.active) {
        entry.startedAt = null;
      }
      if (!_closed) notifyListeners();
    }

    _listeners[entry.id] = changed;
    session?.addListener(changed);
  }

  /// Only used during startup before profile editing or transport activity.
  void restore(BridgeProfiles saved) {
    if (_closed || _shutdown || active || _connections.length != 1) {
      throw StateError('Cannot restore profiles after bridge activity');
    }
    final first = _connections.single.session;
    first?.removeListener(_listeners[_connections.single.id]!);
    _connections.clear();
    _listeners.clear();
    for (var i = 0; i < saved.profiles.length; i++) {
      _attach(saved.profiles[i], i == 0 ? first : _sessionFactory?.call());
    }
    _selectedId = saved.selectedId;
    notifyListeners();
  }

  void select(String id) {
    connection(id);
    _selectedId = id;
    notifyListeners();
  }

  BridgeConnection add() {
    if (shuttingDown) throw StateError('Bridges are shutting down');
    final usedPorts = _connections
        .map((c) => int.tryParse(c.profile.settings.tcpPort))
        .toSet();
    var port = 9268;
    while (port <= 65535 && usedPorts.contains(port)) {
      port++;
    }
    if (port > 65535) throw StateError('No unused TCP port');
    final number = _connections.map((c) => c.profile.number).reduce(max) + 1;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _attach(
      BridgeProfile(
        id: id,
        number: number,
        settings: BridgeSettings(tcpPort: '$port'),
      ),
      _sessionFactory?.call(),
    );
    _selectedId = id;
    notifyListeners();
    return selected;
  }

  void updateProfile(String id, {String? name, BridgeSettings? settings}) {
    final entry = connection(id);
    if (shuttingDown || entry.active) {
      throw StateError('Stop this bridge before editing it');
    }
    entry.profile = entry.profile.copyWith(name: name, settings: settings);
    entry.startupError = null;
    entry.conflict = null;
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final entry = connection(id);
    if (shuttingDown || entry.active || _connections.length == 1) {
      throw StateError('Cannot remove this bridge');
    }
    // Detach before awaiting cleanup so a concurrent start cannot target it.
    entry.session?.removeListener(_listeners.remove(id)!);
    _connections.remove(entry);
    for (final other in _connections) {
      if (other.conflict?.ownerId == id) {
        other.conflict = null;
        other.startupError = null;
      }
    }
    if (_selectedId == id) _selectedId = _connections.first.id;
    notifyListeners();
    await entry.session?.close();
  }

  Future<void> start(
    String id,
    BridgeConfig config, {
    Future<void> Function()? prepare,
  }) {
    final entry = connection(id);
    if (shuttingDown || entry.active) {
      throw StateError('Bridge cannot start now');
    }
    final identity = serialIdentity(config.serialPort);
    for (final other in _connections) {
      final held = other.reservedConfig;
      if (other == entry || !other.active || held == null) continue;
      BridgeConflictKind? kind;
      if (other.serialIdentity == identity) {
        kind = BridgeConflictKind.serial;
      } else if (held.peer == BridgePeer.ble && config.peer == BridgePeer.ble) {
        kind = BridgeConflictKind.ble;
      } else if (held.peer == BridgePeer.tcp &&
          config.peer == BridgePeer.tcp &&
          held.tcpPort == config.tcpPort &&
          (held.bindAddress == config.bindAddress ||
              held.bindAddress == '0.0.0.0' ||
              config.bindAddress == '0.0.0.0')) {
        kind = BridgeConflictKind.tcp;
      }
      if (kind != null) {
        entry.conflict = BridgeConflict(kind, other.id);
        entry.startupError = 'Endpoint is used by another bridge';
        notifyListeners();
        throw entry.conflict!;
      }
    }
    entry.conflict = null;
    entry.startupError = null;
    entry.preparing = true;
    entry.reservedConfig = config;
    entry.serialIdentity = identity;
    final generation = ++entry.generation;
    notifyListeners();
    return entry.pendingStart = _start(entry, generation, config, prepare);
  }

  Future<void> _start(
    BridgeConnection entry,
    int generation,
    BridgeConfig config,
    Future<void> Function()? prepare,
  ) async {
    try {
      await prepare?.call();
      if (shuttingDown || entry.generation != generation) return;
      entry.session?.start(config);
    } catch (error) {
      entry.startupError = error.toString();
      rethrow;
    } finally {
      entry.preparing = false;
      if (!entry.active) {
        entry.reservedConfig = null;
        entry.serialIdentity = null;
      }
      if (!_closed) notifyListeners();
    }
  }

  Future<void> stop(String id) async {
    final entry = connection(id);
    entry.generation++;
    try {
      await entry.pendingStart;
    } catch (_) {
      /* Startup already reported. */
    }
    await entry.session?.stop();
    if (!_closed) notifyListeners();
  }

  Future<void> stopAll() =>
      _stopping ??= _stopAll().whenComplete(() => _stopping = null);

  Future<void> _stopAll() async {
    _stoppingAll = true;
    notifyListeners();
    try {
      await Future.wait([
        for (final entry in [..._connections]) stop(entry.id),
      ]);
    } finally {
      _stoppingAll = false;
      if (!_closed) notifyListeners();
    }
  }

  /// Acquires a synchronous start barrier before an installer or exit awaits.
  bool lockForShutdown() {
    if (shuttingDown) return false;
    _shutdown = true;
    notifyListeners();
    return true;
  }

  void unlockShutdown() {
    if (_closed) return;
    _shutdown = false;
    notifyListeners();
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _shutdown = true;
    await stopAll();
    // BridgeSession.close retains native handles until cleanup is confirmed.
    await Future.wait([
      for (final entry in _connections)
        entry.session?.close() ?? Future.value(),
    ]);
    _closed = true;
    super.dispose();
  }

  static String serialIdentity(String value) {
    var path = value.trim();
    final com = RegExp(
      r'^(?:\\\\\.\\)?COM0*([1-9][0-9]*):?$',
      caseSensitive: false,
    ).firstMatch(path);
    if (com != null) return 'COM${com.group(1)}';
    if (path.startsWith('/')) {
      try {
        path = File(path).resolveSymbolicLinksSync();
      } on FileSystemException {
        /* Native open reports absent paths. */
      }
      if (path.startsWith('/dev/tty.')) {
        path = path.replaceFirst('/dev/tty.', '/dev/cu.');
      }
    }
    return path;
  }
}
