import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:povad_core/povad_core.dart';
import 'package:test/test.dart';

typedef _OpenPtyNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Int32>,
  ffi.Pointer<ffi.Int32>,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Void>,
);
typedef _OpenPty = int Function(
  ffi.Pointer<ffi.Int32>,
  ffi.Pointer<ffi.Int32>,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Void>,
);
typedef _ReadNative = ffi.IntPtr Function(
  ffi.Int32,
  ffi.Pointer<ffi.Void>,
  ffi.IntPtr,
);
typedef _Read = int Function(int, ffi.Pointer<ffi.Void>, int);
typedef _WriteNative = _ReadNative;
typedef _Write = _Read;
typedef _CloseNative = ffi.Int32 Function(ffi.Int32);
typedef _Close = int Function(int);
typedef _FcntlNative = ffi.Int32 Function(ffi.Int32, ffi.Int32, ffi.Int32);
typedef _Fcntl = int Function(int, int, int);

final class _PtyApi {
  _PtyApi()
    : system = ffi.DynamicLibrary.process(),
      pty = Platform.isMacOS
          ? ffi.DynamicLibrary.process()
          : ffi.DynamicLibrary.open('libutil.so.1') {
    openPty = pty.lookupFunction<_OpenPtyNative, _OpenPty>('openpty');
    read = system.lookupFunction<_ReadNative, _Read>('read');
    write = system.lookupFunction<_WriteNative, _Write>('write');
    close = system.lookupFunction<_CloseNative, _Close>('close');
    fcntl = system.lookupFunction<_FcntlNative, _Fcntl>('fcntl');
  }

  final ffi.DynamicLibrary system, pty;
  late final _OpenPty openPty;
  late final _Read read;
  late final _Write write;
  late final _Close close;
  late final _Fcntl fcntl;

  ({int master, int slave, String path}) create() {
    final master = calloc<ffi.Int32>();
    final slave = calloc<ffi.Int32>();
    final name = calloc<ffi.Char>(256);
    try {
      if (openPty(master, slave, name, ffi.nullptr, ffi.nullptr) != 0) {
        throw StateError('Cannot create a pseudo-terminal pair');
      }
      final bytes = <int>[];
      for (var i = 0; i < 256 && name[i] != 0; i++) {
        bytes.add(name[i] & 0xff);
      }
      return (
        master: master.value,
        slave: slave.value,
        path: utf8.decode(bytes),
      );
    } finally {
      calloc.free(master);
      calloc.free(slave);
      calloc.free(name);
    }
  }

  void makeNonblocking(int fd) {
    const getFlags = 3;
    const setFlags = 4;
    final nonblocking = Platform.isMacOS ? 0x0004 : 0x0800;
    final flags = fcntl(fd, getFlags, 0);
    if (flags < 0 || fcntl(fd, setFlags, flags | nonblocking) < 0) {
      throw StateError('Cannot set PTY master to nonblocking mode');
    }
  }

  Future<List<int>> readExactly(int fd, int length) async {
    final buffer = calloc<ffi.Uint8>(length);
    final result = <int>[];
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    try {
      while (result.length < length && DateTime.now().isBefore(deadline)) {
        final count = read(fd, buffer.cast(), length - result.length);
        if (count > 0) {
          result.addAll(buffer.asTypedList(count));
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }
      if (result.length != length) {
        throw StateError('PTY received ${result.length} of $length bytes');
      }
      return result;
    } finally {
      calloc.free(buffer);
    }
  }

  void writeAll(int fd, List<int> bytes) {
    final buffer = calloc<ffi.Uint8>(bytes.length);
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      var offset = 0;
      while (offset < bytes.length) {
        final count = write(
          fd,
          (buffer + offset).cast(),
          bytes.length - offset,
        );
        if (count <= 0) {
          throw StateError('PTY write failed after $offset bytes');
        }
        offset += count;
      }
    } finally {
      calloc.free(buffer);
    }
  }
}

Future<BridgeSnapshot> _waitFor(
  NativeBridge bridge,
  bool Function(BridgeSnapshot) matches,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    final snapshot = bridge.snapshot();
    if (matches(snapshot)) return snapshot;
    if (snapshot.finished && snapshot.state != BridgeState.stopped) {
      throw StateError('Native worker failed: ${snapshot.errorMessage}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Timed out waiting for native bridge state');
}

Future<List<int>> _readTcp(StreamIterator<List<int>> chunks, int length) async {
  final result = <int>[];
  while (result.length < length) {
    if (!await chunks.moveNext().timeout(const Duration(seconds: 5))) {
      throw StateError('TCP closed before the binary vector arrived');
    }
    result.addAll(chunks.current);
  }
  return result;
}

void main() {
  test('Dart FFI relays untouched binary bytes through PTY and TCP in both directions', () async {
    final pty = _PtyApi();
    final pair = pty.create();
    pty.close(pair.slave);
    pty.makeNonblocking(pair.master);
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = reservation.port;
    await reservation.close();
    final bridge = NativeBridge();
    Socket? client;
    StreamIterator<List<int>>? chunks;
    try {
      bridge.start(BridgeConfig(serialPort: pair.path, tcpPort: port));
      await _waitFor(bridge, (value) => value.state == BridgeState.listening);
      client = await Socket.connect(InternetAddress.loopbackIPv4, port);
      await _waitFor(bridge, (value) => value.state == BridgeState.connected);

      const fromTcp = <int>[0x00, 0xff, 0x80, 0x0d, 0x0a, 0x01, 0x04];
      client.add(fromTcp);
      await client.flush();
      expect(await pty.readExactly(pair.master, fromTcp.length), fromTcp);

      const fromSerial = <int>[0xfe, 0x00, 0x7f, 0x03, 0x10, 0xa5];
      chunks = StreamIterator<List<int>>(client);
      pty.writeAll(pair.master, fromSerial);
      expect(await _readTcp(chunks, fromSerial.length), fromSerial);
      final transferred = await _waitFor(
        bridge,
        (value) =>
            value.tcpReceived == fromTcp.length &&
            value.serialAccepted == fromTcp.length &&
            value.serialReceived == fromSerial.length &&
            value.tcpAccepted == fromSerial.length,
      );
      expect(transferred.clientConnected, isTrue);

      bridge.requestStop();
      final stopped = await bridge.waitForStop();
      expect(stopped.state, BridgeState.stopped);
    } finally {
      await chunks?.cancel();
      client?.destroy();
      await bridge.close();
      pty.close(pair.master);
    }
  }, skip: Platform.isWindows || Platform.isAndroid);

  test(
    'Dart FFI sustains repeated bidirectional exchanges without idle traffic',
    () async {
      final pty = _PtyApi();
      final pair = pty.create();
      pty.close(pair.slave);
      pty.makeNonblocking(pair.master);
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();
      final bridge = NativeBridge();
      Socket? client;
      StreamIterator<List<int>>? chunks;
      try {
        bridge.start(BridgeConfig(serialPort: pair.path, tcpPort: port));
        await _waitFor(bridge, (value) => value.state == BridgeState.listening);
        client = await Socket.connect(InternetAddress.loopbackIPv4, port);
        chunks = StreamIterator<List<int>>(client);
        await _waitFor(bridge, (value) => value.state == BridgeState.connected);

        const rounds = 12;
        const tcpLength = 257;
        const serialLength = 263;
        for (var round = 0; round < rounds; round++) {
          final fromTcp = List<int>.generate(
            tcpLength,
            (index) => (index * 37 + round * 29) & 0xff,
          )..setRange(0, 2, [0x00, 0xff]);
          final fromSerial = List<int>.generate(
            serialLength,
            (index) => (index * 53 + round * 17) & 0xff,
          )..setRange(0, 2, [0xff, 0x00]);

          client.add(fromTcp);
          pty.writeAll(pair.master, fromSerial);
          await client.flush();
          final received = await Future.wait([
            pty.readExactly(pair.master, fromTcp.length),
            _readTcp(chunks, fromSerial.length),
          ]);
          expect(received[0], fromTcp, reason: 'TCP to serial, round $round');
          expect(
            received[1],
            fromSerial,
            reason: 'Serial to TCP, round $round',
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }

        final transferred = await _waitFor(
          bridge,
          (value) =>
              value.tcpReceived == rounds * tcpLength &&
              value.serialAccepted == rounds * tcpLength &&
              value.serialReceived == rounds * serialLength &&
              value.tcpAccepted == rounds * serialLength,
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final idle = bridge.snapshot();
        expect(idle.state, BridgeState.connected);
        expect(idle.tcpReceived, transferred.tcpReceived);
        expect(idle.serialReceived, transferred.serialReceived);

        bridge.requestStop();
        expect((await bridge.waitForStop()).state, BridgeState.stopped);
      } finally {
        await chunks?.cancel();
        client?.destroy();
        await bridge.close();
        pty.close(pair.master);
      }
    },
    skip: Platform.isWindows || Platform.isAndroid,
  );
}
