import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Checks one raw TCP -> serial -> TCP round trip with a physical TX/RX
/// loopback fixture. It does not open or configure a serial device itself.
Future<({int bytes, Duration elapsed})> verifySerialLoopback({
  String host = '127.0.0.1',
  int port = 9268,
  Duration timeout = const Duration(seconds: 20),
}) async {
  if (port < 1 || port > 65535) throw ArgumentError.value(port, 'port');
  final expected = Uint8List.fromList([
    0x00,
    0xff,
    ...List<int>.generate(4094, (index) {
      final position = index + 2;
      return (position * 73 + (position ~/ 256) * 17 + 19) & 0xff;
    }),
  ]);
  final received = BytesBuilder(copy: false);
  final complete = Completer<void>();
  final watch = Stopwatch()..start();
  final socket = await Socket.connect(host, port, timeout: timeout);
  try {
    final subscription = socket.listen(
      (chunk) {
        received.add(chunk);
        if (received.length >= expected.length && !complete.isCompleted) {
          complete.complete();
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!complete.isCompleted) complete.completeError(error, stack);
      },
      onDone: () {
        if (!complete.isCompleted) {
          complete.completeError(
            StateError('TCP connection closed after ${received.length} bytes'),
          );
        }
      },
    );
    try {
      socket.add(expected);
      await socket.flush();
      await complete.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Received ${received.length} of ${expected.length} bytes',
          timeout,
        ),
      );
      final actual = received.takeBytes();
      if (actual.length != expected.length) {
        throw StateError(
          'Expected ${expected.length} bytes, received ${actual.length}',
        );
      }
      for (var index = 0; index < expected.length; index++) {
        if (actual[index] != expected[index]) {
          throw StateError('Binary mismatch at byte $index');
        }
      }
      return (bytes: expected.length, elapsed: watch.elapsed);
    } finally {
      await subscription.cancel();
    }
  } finally {
    socket.destroy();
  }
}

Future<void> main(List<String> args) async {
  if (args.length > 2 || args.contains('--help')) {
    stdout.writeln(
      'Usage: dart run tool/verify_serial_loopback.dart [host] [tcp-port]',
    );
    if (!args.contains('--help')) exitCode = 2;
    return;
  }
  final host = args.isEmpty ? '127.0.0.1' : args[0];
  final port = args.length < 2 ? 9268 : int.tryParse(args[1]);
  if (port == null) {
    stderr.writeln('TCP port must be a number from 1 to 65535.');
    exitCode = 2;
    return;
  }
  try {
    final result = await verifySerialLoopback(host: host, port: port);
    stdout.writeln(
      'PASS: ${result.bytes} binary bytes matched through serial loopback '
      'in ${result.elapsed.inMilliseconds} ms.',
    );
  } on Object catch (error) {
    stderr.writeln('FAIL: $error');
    exitCode = 1;
  }
}
