import 'dart:io';

import 'verify_serial_loopback.dart';

/// Forwards a Mac/PC loopback port to Povad's Android loopback listener.
/// Wireless ADB leaves the phone's USB connector available for an OTG adapter.
Future<({int bytes, Duration elapsed})> verifyAndroidSerialLoopback({
  required String adbSerial,
  int devicePort = 9268,
  String adbExecutable = 'adb',
}) async {
  if (adbSerial.isEmpty) throw ArgumentError.value(adbSerial, 'adbSerial');
  if (devicePort < 1 || devicePort > 65535) {
    throw ArgumentError.value(devicePort, 'devicePort');
  }
  final forward = await Process.run(adbExecutable, [
    '-s',
    adbSerial,
    'forward',
    '--no-rebind',
    'tcp:0',
    'tcp:$devicePort',
  ]);
  if (forward.exitCode != 0) {
    throw StateError('ADB forward failed: ${forward.stderr.toString().trim()}');
  }
  final localPort = int.tryParse(forward.stdout.toString().trim());
  if (localPort == null || localPort < 1 || localPort > 65535) {
    throw StateError('ADB did not return a local TCP port');
  }
  ({int bytes, Duration elapsed})? result;
  Object? verificationError;
  StackTrace? verificationStack;
  try {
    result = await verifySerialLoopback(port: localPort);
  } on Object catch (error, stack) {
    verificationError = error;
    verificationStack = stack;
  }
  final verificationContext = verificationError == null
      ? ''
      : 'Verification failed: $verificationError; ';
  ProcessResult remove;
  try {
    remove = await Process.run(adbExecutable, [
      '-s',
      adbSerial,
      'forward',
      '--remove',
      'tcp:$localPort',
    ]);
  } on Object catch (error) {
    throw StateError('${verificationContext}ADB cleanup failed: $error');
  }
  if (remove.exitCode != 0) {
    throw StateError(
      '${verificationContext}ADB forward cleanup failed: '
      '${remove.stderr.toString().trim()}',
    );
  }
  if (verificationError != null) {
    Error.throwWithStackTrace(verificationError, verificationStack!);
  }
  return result!;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.length > 2 || args.contains('--help')) {
    stdout.writeln(
      'Usage: dart run tool/verify_android_serial_loopback.dart '
      '<adb-serial> [device-tcp-port]\n'
      'Povad must listen on Android 127.0.0.1. Use wireless ADB to keep the '
      'USB serial adapter connected. A PASS only proves '
      'serial hardware when a safe TX/RX loopback fixture is attached.',
    );
    if (!args.contains('--help')) exitCode = 2;
    return;
  }
  final port = args.length == 2 ? int.tryParse(args[1]) : 9268;
  if (port == null || port < 1 || port > 65535) {
    stderr.writeln('Device TCP port must be from 1 to 65535.');
    exitCode = 2;
    return;
  }
  try {
    final result = await verifyAndroidSerialLoopback(
      adbSerial: args[0],
      devicePort: port,
    );
    stdout.writeln(
      'PASS: ${result.bytes} binary bytes echoed by the Android TCP endpoint '
      'in ${result.elapsed.inMilliseconds} ms. Record serial hardware '
      'acceptance only if a physical TX/RX fixture was connected.',
    );
  } on Object catch (error) {
    stderr.writeln('FAIL: $error');
    exitCode = 1;
  }
}
