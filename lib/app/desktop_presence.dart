import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/bridge_session.dart';
import '../domain/bridge_view_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../features/overview_page.dart';
import 'bridge_presence.dart';

/// A visible tray/menu-bar owner for the in-process native worker.
/// Closing an active window hides it; quitting waits for confirmed cleanup.
final class DesktopPresence
    with WindowListener, TrayListener
    implements BridgePresence {
  DesktopPresence._(this.session);

  final BridgeSession session;
  BridgeViewState _state = BridgeViewState.stopped;
  Locale _locale = const Locale('en');
  bool _workerActive = false;
  bool _quitting = false;
  bool _trayReady = false;

  static Future<DesktopPresence> initialize(BridgeSession session) async {
    await windowManager.ensureInitialized();
    final presence = DesktopPresence._(session);
    windowManager.addListener(presence);
    await windowManager.setPreventClose(true);
    try {
      trayManager.addListener(presence);
      await trayManager.setIcon(
        Platform.isWindows
            ? 'assets/brand/icon.ico'
            : 'assets/brand/icon-256.png',
      );
      presence._trayReady = true;
      await presence._updateMenu();
    } catch (error) {
      presence._trayReady = false;
      trayManager.removeListener(presence);
      debugPrint('System tray unavailable: $error');
    }
    return presence;
  }

  @override
  Future<void> prepareStart(String serialSelection, Locale locale) async {}

  @override
  Future<void> reflect(
    BridgeViewState state,
    Locale locale, {
    required bool workerActive,
  }) async {
    if (_state == state && _locale == locale && _workerActive == workerActive) {
      return;
    }
    _state = state;
    _locale = locale;
    _workerActive = workerActive;
    await _updateMenu();
  }

  Future<void> _updateMenu() async {
    if (!_trayReady) return;
    final l = lookupAppLocalizations(_locale);
    final status = StateCopy.of(_state, l).title;
    await trayManager.setToolTip('Povad · $status');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'status', label: status, disabled: true),
          MenuItem.separator(),
          MenuItem(key: 'open', label: l.openPovad),
          if (_workerActive) MenuItem(key: 'stop', label: l.stopBridge),
          MenuItem(
            key: 'quit',
            label: _workerActive ? l.stopAndQuit : l.quitPovad,
          ),
        ],
      ),
    );
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() {
    if (_workerActive) {
      // A minimized Linux window remains reachable when the desktop has no
      // AppIndicator extension. Minimize elsewhere if tray setup failed.
      unawaited(
        Platform.isLinux || !_trayReady
            ? windowManager.minimize()
            : windowManager.hide(),
      );
    } else {
      unawaited(_quit());
    }
  }

  @override
  void onTrayIconMouseDown() => unawaited(_showWindow());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        unawaited(_showWindow());
      case 'stop':
        unawaited(session.stop());
      case 'quit':
        unawaited(_quit());
    }
  }

  Future<void> _quit() async {
    if (_quitting) return;
    _quitting = true;
    try {
      if (_workerActive) {
        await session.stop();
        final snapshot = session.snapshot;
        if (snapshot != null &&
            (!snapshot.finished ||
                snapshot.serialOpen ||
                snapshot.clientConnected)) {
          await _showWindow();
          return;
        }
      }
      await session.close();
      if (_trayReady) await trayManager.destroy();
      exit(0);
    } finally {
      _quitting = false;
    }
  }
}
