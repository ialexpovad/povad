import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:povad_core/povad_core.dart' as core;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../design/povad_mark.dart';
import '../design/povad_theme.dart';
import '../domain/bridge_view_state.dart';
import '../domain/bridge_session.dart';
import '../domain/android_usb_host.dart';
import '../features/overview_page.dart';
import '../features/secondary_pages.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/shadcn_localizations_be.dart';
import 'ui_preferences.dart';

class PovadApp extends StatefulWidget {
  const PovadApp({super.key, this.preferences, this.session});

  final UiPreferences? preferences;

  /// When absent, this widget displays the UI preview for design tests.
  final BridgeSession? session;

  @override
  State<PovadApp> createState() => _PovadAppState();
}

class _PovadAppState extends State<PovadApp> {
  Locale locale = const Locale('en');
  PovadSkin skin = PovadSkin.copper;
  BridgeViewState state = BridgeViewState.stopped;
  int page = 0;
  late final UiPreferences preferences;
  bool settingsChanged = false;
  String serialPort = '';
  String baud = '115200';
  String tcpPort = '9268';
  bool allowLan = false;
  bool invalidBridgeSettings = false;
  final AndroidUsbHost usbHost = const AndroidUsbHost();
  List<AndroidUsbPort> usbPorts = const [];
  String? usbError;
  String? selectedUsbLabel;
  bool usbLoading = false;

  bool get androidHost =>
      !kIsWeb && Platform.isAndroid && widget.session != null;

  bool get configurationReady {
    final speed = int.tryParse(baud);
    final port = int.tryParse(tcpPort);
    return serialPort.trim().isNotEmpty &&
        speed != null &&
        speed >= 300 &&
        speed <= 4000000 &&
        port != null &&
        port >= 1 &&
        port <= 65535;
  }

  bool get running =>
      state == BridgeViewState.starting ||
      state == BridgeViewState.listening ||
      state == BridgeViewState.connected ||
      state == BridgeViewState.stopping;

  @override
  void initState() {
    super.initState();
    preferences = widget.preferences ?? DeviceUiPreferences();
    widget.session?.addListener(onNativeState);
    unawaited(loadPreferences());
    if (androidHost) unawaited(refreshUsbPorts());
  }

  Future<void> refreshUsbPorts() async {
    if (!mounted) return;
    setState(() {
      usbLoading = true;
      usbError = null;
    });
    try {
      if (!await usbHost.available()) {
        if (mounted) setState(() => usbError = 'unavailable');
        return;
      }
      final discovered = await usbHost.listPorts();
      if (!mounted) return;
      setState(() {
        usbPorts = discovered;
        if (serialPort.isNotEmpty &&
            !discovered.any((port) => port.nativeSelection == serialPort)) {
          serialPort = '';
          selectedUsbLabel = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => usbError = 'scanFailed');
    } finally {
      if (mounted) setState(() => usbLoading = false);
    }
  }

  Future<void> selectUsbPort(AndroidUsbPort port) async {
    if (!mounted) return;
    setState(() {
      usbLoading = true;
      usbError = null;
    });
    try {
      final allowed = await usbHost.requestPermission(port);
      if (!mounted) return;
      setState(() {
        if (allowed) {
          serialPort = port.nativeSelection;
          selectedUsbLabel = port.label;
          invalidBridgeSettings = false;
        } else {
          usbError = 'denied';
        }
      });
    } catch (_) {
      if (mounted) setState(() => usbError = 'scanFailed');
    } finally {
      if (mounted) setState(() => usbLoading = false);
    }
  }

  @override
  void dispose() {
    widget.session?.removeListener(onNativeState);
    if (widget.session != null) unawaited(widget.session!.close());
    super.dispose();
  }

  void onNativeState() {
    if (!mounted) return;
    setState(() {
      state = switch (widget.session!.state) {
        core.BridgeState.stopped => BridgeViewState.stopped,
        core.BridgeState.starting => BridgeViewState.starting,
        core.BridgeState.listening => BridgeViewState.listening,
        core.BridgeState.connected => BridgeViewState.connected,
        core.BridgeState.stopping => BridgeViewState.stopping,
        core.BridgeState.interrupted ||
        core.BridgeState.fault => BridgeViewState.error,
      };
    });
  }

  Future<void> loadPreferences() async {
    try {
      final savedLanguage = await preferences.readLanguage();
      final savedSkin = await preferences.readSkin();
      if (!mounted || settingsChanged) return;
      setState(() {
        if (savedLanguage == 'en' || savedLanguage == 'be') {
          locale = Locale(savedLanguage!);
        }
        if (savedSkin != null) skin = savedSkin;
      });
    } catch (error) {
      debugPrint('Unable to load UI preferences: $error');
    }
  }

  void changeLocale(Locale value) {
    settingsChanged = true;
    setState(() => locale = value);
    unawaited(saveLanguage(value.languageCode));
  }

  void changeSkin(PovadSkin value) {
    settingsChanged = true;
    setState(() => skin = value);
    unawaited(saveSkin(value));
  }

  Future<void> saveLanguage(String languageCode) async {
    try {
      await preferences.saveLanguage(languageCode);
    } catch (error) {
      debugPrint('Unable to save UI language: $error');
    }
  }

  Future<void> saveSkin(PovadSkin value) async {
    try {
      await preferences.saveSkin(value);
    } catch (error) {
      debugPrint('Unable to save UI theme: $error');
    }
  }

  void act() {
    if (widget.session != null) {
      if (state == BridgeViewState.stopped) {
        if (!configurationReady) {
          setState(() {
            invalidBridgeSettings = true;
            page = 1;
          });
          return;
        }
        widget.session!.start(
          core.BridgeConfig(
            serialPort: serialPort.trim(),
            baud: int.parse(baud),
            tcpPort: int.parse(tcpPort),
            bindAddress: allowLan ? '0.0.0.0' : '127.0.0.1',
            allowLan: allowLan,
          ),
        );
      } else if (state == BridgeViewState.listening ||
          state == BridgeViewState.connected) {
        unawaited(widget.session!.stop());
      } else if (state == BridgeViewState.error) {
        setState(() => page = 2);
      }
      return;
    }
    if (!kDebugMode) return;
    setState(() {
      if (state == BridgeViewState.stopped) {
        state = BridgeViewState.starting;
      } else if (state == BridgeViewState.listening ||
          state == BridgeViewState.connected) {
        state = BridgeViewState.stopping;
      } else if (state == BridgeViewState.error) {
        page = 2;
      }
    });
  }

  @override
  Widget build(BuildContext context) => shad.ShadcnApp(
    title: 'Povad',
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      PovadShadcnDelegate(),
    ],
    theme: PovadPalette(skin, false).toShadcn(),
    darkTheme: PovadPalette(skin, true).toShadcn(),
    home: PovadSkinScope(
      skin: skin,
      child: Builder(
        builder: (context) {
          final l = AppLocalizations.of(context)!;
          final p = paletteOf(context);
          final labels = [l.overview, l.bridge, l.diagnostics, l.settings];
          const icons = [
            shad.LucideIcons.layoutDashboard,
            shad.LucideIcons.cable,
            shad.LucideIcons.activity,
            shad.LucideIcons.settings,
          ];
          final content = switch (page) {
            0 => OverviewPage(
              state: state,
              onAction: act,
              onPreviewState: (value) => setState(() => state = value),
              previewMode: widget.session == null,
              configured: widget.session == null || configurationReady,
              serialValue: serialPort.isEmpty
                  ? l.serialValue
                  : selectedUsbLabel ?? serialPort,
              tcpValue: serialPort.isEmpty
                  ? l.tcpValue
                  : '${allowLan ? '0.0.0.0' : '127.0.0.1'}:$tcpPort',
            ),
            1 =>
              widget.session == null
                  ? EmptyPage(
                      icon: shad.LucideIcons.cable,
                      title: l.bridgeSetupTitle,
                      body: l.bridgeSetupBody,
                    )
                  : BridgeSetupPage(
                      serialPort: serialPort,
                      baud: baud,
                      tcpPort: tcpPort,
                      onSerialPortChanged: (value) => setState(() {
                        serialPort = value;
                        invalidBridgeSettings = false;
                      }),
                      onBaudChanged: (value) => setState(() {
                        baud = value;
                        invalidBridgeSettings = false;
                      }),
                      onTcpPortChanged: (value) => setState(() {
                        tcpPort = value;
                        invalidBridgeSettings = false;
                      }),
                      allowLan: allowLan,
                      onAllowLanChanged: (value) =>
                          setState(() => allowLan = value),
                      error: invalidBridgeSettings
                          ? l.invalidBridgeSettings
                          : null,
                      running: running,
                      usbMode: androidHost,
                      usbPorts: usbPorts,
                      usbLoading: usbLoading,
                      usbMessage: switch (usbError) {
                        'unavailable' => l.usbUnavailable,
                        'denied' => l.usbPermissionDenied,
                        'scanFailed' => l.usbScanFailed,
                        _ => null,
                      },
                      onRefreshUsb: () => unawaited(refreshUsbPorts()),
                      onUsbPortSelected: (port) =>
                          unawaited(selectUsbPort(port)),
                    ),
            2 => EmptyPage(
              icon: shad.LucideIcons.activity,
              title: state == BridgeViewState.error
                  ? l.errorTitle
                  : l.diagnosticsTitle,
              body: state == BridgeViewState.error
                  ? l.errorDescription
                  : l.diagnosticsBody,
              previewMode: widget.session == null,
              detail: widget.session?.errorMessage,
            ),
            _ => SettingsPage(
              locale: locale,
              onLocaleChanged: changeLocale,
              skin: skin,
              onSkinChanged: changeSkin,
            ),
          };
          return ColoredBox(
            color: p.background,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth < 760) {
                    return Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: p.surface,
                            border: Border(bottom: BorderSide(color: p.border)),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [const PovadBrandLockup(compact: true)],
                          ),
                        ),
                        Expanded(child: content),
                        Container(
                          decoration: BoxDecoration(
                            color: p.surface,
                            border: Border(top: BorderSide(color: p.border)),
                          ),
                          padding: const EdgeInsets.fromLTRB(6, 5, 6, 8),
                          child: Row(
                            children: [
                              for (var i = 0; i < 4; i++)
                                Expanded(
                                  child: _NavItem(
                                    key: ValueKey('nav-$i'),
                                    index: i,
                                    selected: page == i,
                                    compact: true,
                                    icon: icons[i],
                                    label: labels[i],
                                    onTap: () => setState(() => page = i),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Container(
                        width: 220,
                        decoration: BoxDecoration(
                          color: p.surface,
                          border: Border(right: BorderSide(color: p.border)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                30,
                                14,
                                36,
                              ),
                              child: PovadBrandLockup(caption: l.appCaption),
                            ),
                            for (var i = 0; i < 4; i++)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  5,
                                ),
                                child: _NavItem(
                                  key: ValueKey('nav-$i'),
                                  index: i,
                                  selected: page == i,
                                  compact: false,
                                  icon: icons[i],
                                  label: labels[i],
                                  onTap: () => setState(() => page = i),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(child: content),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.index,
    required this.selected,
    required this.compact,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final int index;
  final bool selected, compact;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? p.selection : const Color(0x00000000),
          borderRadius: BorderRadius.circular(9),
        ),
        child: shad.GhostButton(
          onPressed: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 3 : 7),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 19,
                        color: selected ? p.primary : p.muted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected ? p.primary : p.muted,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: selected ? p.primary : p.muted,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected ? p.primary : p.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
