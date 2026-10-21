import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:povad/domain/bridge_fleet.dart';
import 'package:povad/domain/bridge_session.dart';
import 'package:povad/domain/bridge_view_state.dart';
import 'package:povad_core/povad_core.dart';

class FakeBridgeSession extends BridgeSession {
  BridgeState current = BridgeState.stopped;
  bool refuseStop = false;
  Completer<void>? stopGate;
  void Function()? onClose;
  int starts = 0, closes = 0;
  @override
  bool get active =>
      current == BridgeState.listening || current == BridgeState.connected;
  @override
  BridgeState get state => current;
  @override
  void start(BridgeConfig config) {
    starts++;
    current = BridgeState.listening;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    await stopGate?.future;
    if (!refuseStop) current = BridgeState.stopped;
    notifyListeners();
  }

  @override
  Future<void> close() async {
    closes++;
    onClose?.call();
  }

  void fault() {
    current = BridgeState.fault;
    notifyListeners();
  }
}

void main() {
  late BridgeFleet fleet;
  late List<FakeBridgeSession> sessions;
  setUp(() {
    sessions = [];
    fleet = BridgeFleet(
      sessionFactory: () {
        final session = FakeBridgeSession();
        sessions.add(session);
        return session;
      },
    );
  });
  tearDown(() async {
    for (final s in sessions) {
      s.refuseStop = false;
    }
    await fleet.close();
  });
  BridgeConfig config(String serial, int port, {String bind = '127.0.0.1'}) =>
      BridgeConfig(serialPort: serial, tcpPort: port, bindAddress: bind);

  test(
    'more than two profiles use distinct identities and suggested TCP ports',
    () {
      for (var i = 0; i < 5; i++) {
        fleet.add();
      }
      expect(fleet.connections.length, 6);
      expect(fleet.connections.map((c) => c.id).toSet().length, 6);
      expect(fleet.connections.map((c) => c.profile.settings.tcpPort), [
        '9268',
        '9269',
        '9270',
        '9271',
        '9272',
        '9273',
      ]);
    },
  );

  test(
    'startup reserves a COM alias before asynchronous preparation',
    () async {
      final first = fleet.selected.id;
      final second = fleet.add().id;
      final prepared = Completer<void>();
      final starting = fleet.start(
        first,
        config('COM03', 9268),
        prepare: () => prepared.future,
      );
      expect(
        () => fleet.start(second, config(r'\\.\com3', 9269)),
        throwsA(
          isA<BridgeConflict>().having(
            (e) => e.kind,
            'kind',
            BridgeConflictKind.serial,
          ),
        ),
      );
      expect(sessions[1].starts, 0);
      prepared.complete();
      await starting;
      expect(fleet.activeCount, 1);
    },
  );

  test(
    'wildcard TCP listeners conflict with loopback, different addresses do not',
    () async {
      final first = fleet.selected.id;
      final second = fleet.add().id;
      await fleet.start(first, config('COM1', 9268, bind: '0.0.0.0'));
      expect(
        () => fleet.start(second, config('COM2', 9268)),
        throwsA(
          isA<BridgeConflict>().having(
            (e) => e.kind,
            'kind',
            BridgeConflictKind.tcp,
          ),
        ),
      );
      await fleet.stop(first);
      await fleet.start(first, config('COM1', 9268, bind: '192.168.1.10'));
      await fleet.start(second, config('COM2', 9268));
      expect(fleet.activeCount, 2);
    },
  );

  test('fault and restart of one bridge leave the other listening', () async {
    final first = fleet.selected.id;
    final second = fleet.add().id;
    await fleet.start(first, config('COM1', 9268));
    await fleet.start(second, config('COM2', 9269));
    sessions[0].fault();
    expect(fleet.connection(second).state, BridgeViewState.listening);
    expect(fleet.activeCount, 1);
    await fleet.start(first, config('COM1', 9268));
    await fleet.stop(second);
    expect(fleet.connection(first).state, BridgeViewState.listening);
  });

  test('stop during preparation prevents a late native start', () async {
    final id = fleet.selected.id;
    final ready = Completer<void>();
    final started = fleet.start(
      id,
      config('COM1', 9268),
      prepare: () => ready.future,
    );
    final stopped = fleet.stop(id);
    ready.complete();
    await started;
    await stopped;
    expect(sessions.single.starts, 0);
    expect(fleet.active, false);
  });

  test(
    'shutdown stops every worker and retains a failed stop as active',
    () async {
      final first = fleet.selected.id;
      final second = fleet.add().id;
      await fleet.start(first, config('COM1', 9268));
      await fleet.start(second, config('COM2', 9269));
      sessions[1].refuseStop = true;
      expect(fleet.lockForShutdown(), true);
      await fleet.stopAll();
      expect(fleet.activeCount, 1);
      expect(sessions[1].closes, 0);
      expect(() => fleet.start(first, config('COM1', 9268)), throwsStateError);
    },
  );

  test('active profiles cannot be edited or removed', () async {
    final first = fleet.selected.id;
    fleet.add();
    await fleet.start(first, config('COM1', 9268));
    expect(() => fleet.updateProfile(first, name: 'Changed'), throwsStateError);
    await expectLater(fleet.remove(first), throwsStateError);
  });

  test(
    'close preserves its start barrier when a previous stop-all finishes',
    () async {
      final id = fleet.selected.id;
      await fleet.start(id, config('COM3', 9268));
      final gate = Completer<void>();
      sessions.single.stopGate = gate;
      final stopping = fleet.stopAll();
      sessions.single.onClose = () {
        expect(fleet.shuttingDown, true);
        expect(() => fleet.start(id, config('COM3', 9268)), throwsStateError);
      };
      final closing = fleet.close();
      gate.complete();
      await stopping;
      await closing;
      expect(sessions.single.closes, 1);
    },
  );

  test('macOS dial-in and callout names share one reservation', () {
    expect(
      BridgeFleet.serialIdentity('/dev/tty.usbserial-123'),
      BridgeFleet.serialIdentity('/dev/cu.usbserial-123'),
    );
  });
}
