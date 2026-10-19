import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../tool/verify_serial_loopback.dart' as tool;

void main() {
  test('binary comparator accepts an exact TCP echo', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((peer) {
      peer.listen(peer.add, onDone: peer.destroy);
    });
    try {
      final result = await tool.verifySerialLoopback(port: server.port);
      expect(result.bytes, 4096);
    } finally {
      await server.close();
    }
  });

  test('binary comparator rejects corrupted echo bytes', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((peer) {
      var corrupted = false;
      peer.listen((bytes) {
        final reply = Uint8List.fromList(bytes);
        if (!corrupted) {
          reply[0] ^= 0x01;
          corrupted = true;
        }
        peer.add(reply);
      }, onDone: peer.destroy);
    });
    try {
      await expectLater(
        tool.verifySerialLoopback(port: server.port),
        throwsA(isA<StateError>()),
      );
    } finally {
      await server.close();
    }
  });
}
