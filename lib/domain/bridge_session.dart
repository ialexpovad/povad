import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:povad_core/povad_core.dart';

/// Coordinates UI snapshots with the single native worker. It never handles
/// serial data or socket traffic; the native core owns those resources.
final class BridgeSession extends ChangeNotifier {
  NativeBridge? _bridge;
  Timer? _poller;
  BridgeSnapshot? _snapshot;
  String? _controlError;
  bool _disposed = false;

  BridgeSnapshot? get snapshot => _snapshot;
  String? get errorMessage => _controlError?.isNotEmpty == true
      ? _controlError
      : _snapshot?.errorMessage.isNotEmpty == true
      ? _snapshot!.errorMessage
      : null;

  BridgeState get state => _snapshot?.state ?? BridgeState.stopped;

  /// A control-call failure that the native snapshot does not describe,
  /// such as a rejected start or a stop that did not finish in time.
  String? get controlError =>
      _controlError?.isNotEmpty == true ? _controlError : null;

  void start(BridgeConfig config) {
    if (_disposed) return;
    try {
      _bridge ??= NativeBridge();
      _controlError = null;
      _bridge!.start(config);
      _refresh();
      _poller ??= Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _refresh(),
      );
    } on NativeBridgeError catch (error) {
      _controlError = error.message;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    final bridge = _bridge;
    if (bridge == null || _disposed) return;
    try {
      bridge.requestStop();
      _refresh();
      await bridge.waitForStop();
      _refresh();
    } on NativeBridgeError catch (error) {
      _controlError = error.message;
      notifyListeners();
      // A timeout does not free the handle. The worker may still own it.
    }
  }

  void _refresh() {
    if (_disposed || _bridge == null) return;
    try {
      final next = _bridge!.snapshot();
      final previous = _snapshot;
      _snapshot = next;
      if (next.finished) {
        _poller?.cancel();
        _poller = null;
      }
      if (previous?.state != next.state ||
          previous?.errorCode != next.errorCode ||
          previous?.tcpReceived != next.tcpReceived ||
          previous?.serialReceived != next.serialReceived ||
          previous?.rejectedBusy != next.rejectedBusy ||
          previous?.rejectedIp != next.rejectedIp) {
        notifyListeners();
      }
    } on NativeBridgeError catch (error) {
      _controlError = error.message;
      _poller?.cancel();
      _poller = null;
      notifyListeners();
    }
  }

  Future<void> close() async {
    _poller?.cancel();
    _poller = null;
    _disposed = true;
    final bridge = _bridge;
    super.dispose();
    if (bridge == null) return;
    // Keep the Dart owner alive until native cleanup is confirmed. The app
    // may be closing, but a timed-out worker must never be freed or forgotten.
    while (true) {
      try {
        await bridge.close();
        _bridge = null;
        return;
      } on NativeBridgeError {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }
}
