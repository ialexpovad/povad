import 'package:flutter/widgets.dart';

import '../domain/bridge_view_state.dart';

/// Platform visibility for a bridge that outlives its window or Activity.
/// Transport resources remain owned by the native worker through BridgeSession.
abstract interface class BridgePresence {
  /// Called from the visible UI before opening the serial port.
  Future<void> prepareStart(String serialSelection, Locale locale);

  /// Reflects confirmed worker state. [workerActive] includes shutdown.
  Future<void> reflect(
    BridgeViewState state,
    Locale locale, {
    required bool workerActive,
  });
}
