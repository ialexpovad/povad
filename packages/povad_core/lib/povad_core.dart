/// Typed control API for Povad's embedded native transport worker.
library;

import 'dart:convert';
import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import 'povad_core_bindings_generated.dart' as native;

int nativeAbiVersion() => native.pv_abi_version();

enum BridgeState {
  stopped,
  starting,
  listening,
  connected,
  stopping,
  interrupted,
  fault,
}

final class BridgeConfig {
  const BridgeConfig({
    required this.serialPort,
    this.baud = 115200,
    this.dataBits = 8,
    this.parity = 'N',
    this.stopBitsX10 = 10,
    this.hardwareFlow = false,
    this.dtr = false,
    this.rts = false,
    this.tcpPort = 9268,
    this.bindAddress = '127.0.0.1',
    this.allowLan = false,
    this.queueLimit = 65536,
    this.queueAgeMs = 2000,
  });

  final String serialPort;
  final int baud;
  final int dataBits;
  final String parity;
  final int stopBitsX10;
  final bool hardwareFlow;
  final bool dtr;
  final bool rts;
  final int tcpPort;
  final String bindAddress;
  final bool allowLan;
  final int queueLimit;
  final int queueAgeMs;
}

final class BridgeSnapshot {
  const BridgeSnapshot({
    required this.state,
    required this.serialOpen,
    required this.clientConnected,
    required this.tcpReceived,
    required this.serialReceived,
    required this.serialAccepted,
    required this.tcpAccepted,
    required this.errorCode,
    required this.errorMessage,
  });

  final BridgeState state;
  final bool serialOpen;
  final bool clientConnected;
  final int tcpReceived;
  final int serialReceived;
  final int serialAccepted;
  final int tcpAccepted;
  final int errorCode;
  final String errorMessage;

  bool get finished =>
      state == BridgeState.stopped ||
      state == BridgeState.interrupted ||
      state == BridgeState.fault;
}

final class NativeBridgeError implements Exception {
  const NativeBridgeError(this.code, this.message);
  final int code;
  final String message;

  @override
  String toString() => 'NativeBridgeError($code): $message';
}

/// Control calls must be serialized on one Dart isolate. Snapshot reads are
/// brief; all serial and socket work stays in the native worker. A timed-out
/// stop retains the handle, so callers can retry after the worker completes.
final class NativeBridge {
  NativeBridge() {
    if (native.pv_abi_version() != native.PV_ABI_VERSION ||
        native.pv_config_size() != ffi.sizeOf<native.pv_config>() ||
        native.pv_error_size() != ffi.sizeOf<native.pv_error>() ||
        native.pv_snapshot_size() != ffi.sizeOf<native.pv_snapshot>()) {
      throw const NativeBridgeError(1, 'Native ABI differs from Dart bindings');
    }
    _handle = native.pv_create();
    if (_handle == ffi.nullptr) {
      throw const NativeBridgeError(6, 'Cannot create native bridge');
    }
  }

  late ffi.Pointer<native.pv_handle> _handle;

  void start(BridgeConfig config) {
    _checkOpen();
    final pointer = calloc<native.pv_config>();
    final error = calloc<native.pv_error>();
    try {
      final value = pointer.ref;
      value.size = ffi.sizeOf<native.pv_config>();
      value.abi = native.PV_ABI_VERSION;
      value.baud = _uint32(config.baud, 'baud');
      value.data_bits = _uint32(config.dataBits, 'dataBits');
      value.parity = config.parity.length == 1
          ? config.parity.codeUnitAt(0)
          : 0;
      value.stop_bits_x10 = _uint32(config.stopBitsX10, 'stopBitsX10');
      value.hardware_flow = config.hardwareFlow ? 1 : 0;
      value.dtr = config.dtr ? 1 : 0;
      value.rts = config.rts ? 1 : 0;
      value.tcp_port = _uint32(config.tcpPort, 'tcpPort');
      value.allow_lan = config.allowLan ? 1 : 0;
      value.queue_limit = _uint32(config.queueLimit, 'queueLimit');
      value.queue_age_ms = _uint32(config.queueAgeMs, 'queueAgeMs');
      _writeText(value.serial_port, 256, config.serialPort);
      _writeText(value.bind_address, 64, config.bindAddress);
      error.ref.size = ffi.sizeOf<native.pv_error>();
      final result = native.pv_start(_handle, pointer, error);
      if (result != 0) {
        throw NativeBridgeError(result, _readText(error.ref.message, 192));
      }
    } finally {
      calloc.free(pointer);
      calloc.free(error);
    }
  }

  BridgeSnapshot snapshot() {
    _checkOpen();
    final pointer = calloc<native.pv_snapshot>();
    try {
      pointer.ref.size = ffi.sizeOf<native.pv_snapshot>();
      final result = native.pv_read_snapshot(_handle, pointer);
      if (result != 0) {
        throw NativeBridgeError(result, 'Cannot read native state');
      }
      final value = pointer.ref;
      return BridgeSnapshot(
        state: BridgeState.values[value.state],
        serialOpen: value.serial_open != 0,
        clientConnected: value.client_connected != 0,
        tcpReceived: value.tcp_received,
        serialReceived: value.serial_received,
        serialAccepted: value.serial_accepted,
        tcpAccepted: value.tcp_accepted,
        errorCode: value.error_code,
        errorMessage: _readText(value.error_message, 192),
      );
    } finally {
      calloc.free(pointer);
    }
  }

  void requestStop() {
    _checkOpen();
    final result = native.pv_request_stop(_handle);
    if (result != 0) throw NativeBridgeError(result, 'Cannot request stop');
  }

  Future<BridgeSnapshot> waitForStop({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final value = snapshot();
      if (value.finished && !value.serialOpen && !value.clientConnected) {
        return value;
      }
      if (DateTime.now().isAfter(deadline)) {
        throw const NativeBridgeError(4, 'Native worker has not stopped');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> close({Duration timeout = const Duration(seconds: 10)}) async {
    if (_handle == ffi.nullptr) return;
    requestStop();
    await waitForStop(timeout: timeout);
    final result = native.pv_destroy(_handle);
    if (result != 0) {
      throw NativeBridgeError(result, 'Native handle remains active');
    }
    _handle = ffi.nullptr;
  }

  void _checkOpen() {
    if (_handle == ffi.nullptr) {
      throw const NativeBridgeError(5, 'Native bridge is closed');
    }
  }
}

int _uint32(int value, String field) {
  if (value < 0 || value > 0xffffffff) {
    throw NativeBridgeError(2, 'Invalid unsigned field: $field');
  }
  return value;
}

void _writeText(ffi.Array<ffi.Char> target, int capacity, String text) {
  final bytes = utf8.encode(text);
  if (bytes.length >= capacity || bytes.contains(0)) {
    throw const NativeBridgeError(2, 'Invalid native string length');
  }
  for (var index = 0; index < capacity; index++) {
    target[index] = index < bytes.length ? bytes[index] : 0;
  }
}

String _readText(ffi.Array<ffi.Char> source, int capacity) {
  final bytes = <int>[];
  for (var index = 0; index < capacity; index++) {
    final value = source[index] & 0xff;
    if (value == 0) break;
    bytes.add(value);
  }
  return utf8.decode(bytes, allowMalformed: true);
}
