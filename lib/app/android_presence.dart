import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../domain/bridge_session.dart';
import '../domain/bridge_view_state.dart';
import '../features/overview_page.dart';
import '../l10n/generated/app_localizations.dart';
import 'bridge_presence.dart';

/// Keeps the application-scoped Flutter engine visible to Android while the
/// C++ bridge worker owns an active USB/TCP session.
final class AndroidPresence implements BridgePresence {
  AndroidPresence(this.session) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'serviceStopped') {
        _active = false;
        final snapshot = session.snapshot;
        if (snapshot != null &&
            (!snapshot.finished ||
                snapshot.serialOpen ||
                snapshot.clientConnected)) {
          await session.stop();
        }
      }
    });
  }

  static const MethodChannel _channel = MethodChannel('povad/background');
  final BridgeSession session;
  bool _active = false;

  @override
  Future<void> prepareStart(String serialSelection, Locale locale) async {
    final l = lookupAppLocalizations(locale);
    final started = await _channel.invokeMethod<bool>('start', {
      'selection': serialSelection,
      'status': l.startingTitle,
    });
    if (started != true) {
      throw StateError('Android background service did not start');
    }
    _active = true;
  }

  @override
  Future<void> reflect(
    BridgeViewState state,
    Locale locale, {
    required bool workerActive,
  }) async {
    if (!_active) return;
    if (!workerActive) {
      _active = false;
      await _channel.invokeMethod<void>('stop');
      return;
    }
    final status = StateCopy.of(state, lookupAppLocalizations(locale)).title;
    await _channel.invokeMethod<void>('update', {'status': status});
  }
}
