import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/bridge_fleet.dart';
import '../domain/bridge_view_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../features/overview_page.dart';
import 'bridge_presence.dart';

enum ActiveCloseAction { keepRunning, stopAndQuit, cancel }

/// A visible tray/menu-bar owner for the in-process native worker.
/// Closing an active window hides it; quitting waits for confirmed cleanup.
final class DesktopPresence
    with WindowListener, TrayListener
    implements BridgePresence {
  DesktopPresence._(this.fleet);

  final BridgeFleet fleet;
  String _signature = '';
  Future<void> _menuTail = Future.value();
  BridgeViewState _state = BridgeViewState.stopped;
  Locale _locale = const Locale('en');
  bool _workerActive = false;
  bool _quitting = false;
  bool _trayReady = false;
  bool _closePromptOpen = false;
  Timer? _boundsSaveTimer;
  final SharedPreferencesAsync _windowStore = SharedPreferencesAsync();

  Future<ActiveCloseAction> Function()? chooseCloseAction;

  /// Runs after the worker has confirmed shutdown and before the process
  /// exits, for example to start a staged update.
  Future<void> Function()? beforeExit;

  static Future<DesktopPresence> initialize(BridgeFleet fleet) async {
    await windowManager.ensureInitialized();
    final presence = DesktopPresence._(fleet);
    await windowManager.setPreventClose(true);
    // Below this size the setup form and the mark start to crowd each other.
    await windowManager.setMinimumSize(const Size(400, 560));
    await presence._restoreWindowBounds();
    windowManager.addListener(presence);
    try {
      trayManager.addListener(presence);
      await presence._updateIcon();
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
  Future<void> prepareStart(String serialSelection, Locale locale) async {
    // Keep a close racing with native startup from terminating the session.
    _workerActive = fleet.active;
    _state = fleet.aggregateState;
    _locale = locale;
    await _updateMenuSafely();
  }

  @override
  Future<void> reflect(
    BridgeViewState state,
    Locale locale, {
    required bool workerActive,
  }) async {
    final signature = fleet.connections
        .map((c) => '${c.id}|${c.profile.name}|${c.state}|${c.active}')
        .join(';');
    if (_state == state &&
        _locale == locale &&
        _workerActive == workerActive &&
        _signature == signature) {
      return;
    }
    _signature = signature;
    _state = state;
    _locale = locale;
    _workerActive = workerActive;
    await _updateMenuSafely();
  }

  Future<void> _updateMenuSafely() =>
      _menuTail = _menuTail.then((_) => _applyMenuSafely());

  Future<void> _applyMenuSafely() async {
    try {
      await _updateMenu();
    } catch (error) {
      _trayReady = false;
      trayManager.removeListener(this);
      debugPrint('System tray unavailable: $error');
      // A hidden window must become reachable if its tray icon disappears.
      await windowManager.show();
    }
  }

  Future<void> _updateMenu() async {
    if (!_trayReady) return;
    await _updateIcon();
    final l = lookupAppLocalizations(_locale);
    final status = fleet.connections.length == 1
        ? StateCopy.of(_state, l).title
        : l.bridgesActive(fleet.activeCount);
    await trayManager.setToolTip('Povad · $status');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'status', label: status, disabled: true),
          MenuItem.separator(),
          MenuItem(key: 'open', label: l.openPovad),
          if (fleet.connections.length > 1) ...[
            for (final entry in fleet.connections)
              MenuItem(
                key: 'bridge:${entry.id}',
                label:
                    '${entry.profile.name.isEmpty ? l.bridgeDefaultName(entry.profile.number) : entry.profile.name} · ${StateCopy.of(entry.state, l).badge}',
                disabled: true,
              ),
            MenuItem.separator(),
          ],
          if (_workerActive) MenuItem(key: 'stop', label: l.bridgesStopAll),
          MenuItem(
            key: 'quit',
            label: _workerActive ? l.stopAndQuit : l.quitPovad,
          ),
        ],
      ),
    );
  }

  String get _iconState => switch (_state) {
    BridgeViewState.connected => 'connected',
    BridgeViewState.listening ||
    BridgeViewState.starting ||
    BridgeViewState.stopping => 'listening',
    BridgeViewState.error || BridgeViewState.interrupted => 'error',
    BridgeViewState.stopped => 'stopped',
  };

  Future<void> _updateIcon() => trayManager.setIcon(
    'assets/tray/$_iconState.${Platform.isWindows ? 'ico' : 'png'}',
    isTemplate: Platform.isMacOS,
  );

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  static const _boundsKey = 'desktop.windowBounds.v1';
  static const _defaultSize = Size(520, 720);

  Future<void> _restoreWindowBounds() async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      final areas = [
        for (final display in displays)
          Rect.fromLTWH(
            display.visiblePosition?.dx ?? 0,
            display.visiblePosition?.dy ?? 0,
            (display.visibleSize ?? display.size).width,
            (display.visibleSize ?? display.size).height,
          ),
      ];
      final saved = await _windowStore.getString(_boundsKey);
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        final bounds = Rect.fromLTWH(
          (data['x'] as num).toDouble(),
          (data['y'] as num).toDouble(),
          (data['width'] as num).toDouble(),
          (data['height'] as num).toDouble(),
        );
        if (_usableBounds(bounds, areas)) {
          await windowManager.setBounds(bounds);
          if (data['maximized'] == true) await windowManager.maximize();
          return;
        }
      }
      final primary = await screenRetriever.getPrimaryDisplay();
      final visible = primary.visibleSize ?? primary.size;
      await windowManager.setSize(
        Size(
          _defaultSize.width.clamp(400, visible.width).toDouble(),
          _defaultSize.height.clamp(560, visible.height).toDouble(),
        ),
      );
      await windowManager.center();
    } catch (error) {
      debugPrint('Cannot restore window geometry: $error');
      await windowManager.setSize(_defaultSize);
      await windowManager.center();
    }
  }

  static bool _usableBounds(Rect bounds, List<Rect> areas) {
    if (!bounds.isFinite ||
        bounds.width < 400 ||
        bounds.width > 1600 ||
        bounds.height < 560 ||
        bounds.height > 1400) {
      return false;
    }
    return areas.any((area) {
      final visible = bounds.intersect(area);
      return visible.width >= 240 && visible.height >= 160;
    });
  }

  Future<void> _saveWindowBounds() async {
    try {
      final bounds = await windowManager.getBounds();
      if (!bounds.isFinite || bounds.width < 400 || bounds.height < 560) {
        return;
      }
      final maximized = await windowManager.isMaximized();
      await _windowStore.setString(
        _boundsKey,
        jsonEncode({
          'x': bounds.left,
          'y': bounds.top,
          'width': bounds.width,
          'height': bounds.height,
          'maximized': maximized,
        }),
      );
    } catch (error) {
      debugPrint('Cannot save window geometry: $error');
    }
  }

  void _scheduleBoundsSave() {
    _boundsSaveTimer?.cancel();
    _boundsSaveTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_saveWindowBounds()),
    );
  }

  @override
  void onWindowResized() => _scheduleBoundsSave();

  @override
  void onWindowMoved() => _scheduleBoundsSave();

  @override
  void onWindowMaximize() => _scheduleBoundsSave();

  @override
  void onWindowUnmaximize() => _scheduleBoundsSave();

  @override
  void onWindowClose() {
    unawaited(_handleWindowClose());
  }

  Future<void> _handleWindowClose() async {
    if (_closePromptOpen || _quitting) return;
    _closePromptOpen = true;
    try {
      _boundsSaveTimer?.cancel();
      await _saveWindowBounds();
      if (fleet.active) {
        final choice =
            await chooseCloseAction?.call() ?? ActiveCloseAction.keepRunning;
        if (choice == ActiveCloseAction.cancel) return;
        if (choice == ActiveCloseAction.stopAndQuit) {
          await _quit();
          return;
        }
        // A minimized Linux window remains reachable when the desktop has no
        // AppIndicator extension. Minimize elsewhere if tray setup failed.
        await (Platform.isLinux || !_trayReady
            ? windowManager.minimize()
            : windowManager.hide());
      } else {
        await _quit();
      }
    } finally {
      _closePromptOpen = false;
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
        unawaited(fleet.stopAll());
      case 'quit':
        unawaited(_quit());
    }
  }

  /// Quits through the same confirmed-shutdown path as the tray menu.
  Future<void> quit() => _quit();

  Future<void> _quit() async {
    if (_quitting) return;
    _quitting = true;
    try {
      _boundsSaveTimer?.cancel();
      await _saveWindowBounds();
      fleet.lockForShutdown();
      await fleet.stopAll();
      if (fleet.active) {
        await _showWindow();
        return;
      }
      try {
        await beforeExit?.call();
      } catch (error) {
        debugPrint('Cannot start the staged update: $error');
        await _showWindow();
        return;
      }
      await fleet.close();
      if (_trayReady) await trayManager.destroy();
      exit(0);
    } finally {
      _quitting = false;
      fleet.unlockShutdown();
    }
  }
}
