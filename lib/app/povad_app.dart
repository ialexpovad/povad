import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:povad_core/povad_core.dart' as core;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:url_launcher/url_launcher.dart';

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
import 'bridge_presence.dart';

class PovadApp extends StatefulWidget {
  const PovadApp({super.key, this.preferences, this.session, this.presence});

  final UiPreferences? preferences;

  /// When absent, this widget displays the UI preview for design tests.
  final BridgeSession? session;
  final BridgePresence? presence;

  @override
  State<PovadApp> createState() => _PovadAppState();
}

class _PovadAppState extends State<PovadApp> {
  Locale locale = const Locale('en');
  PovadAppearance appearance = PovadAppearance.system;
  BridgeViewState state = BridgeViewState.stopped;
  int page = 0;
  late final UiPreferences preferences;
  bool settingsChanged = false;
  String serialPort = '';
  String baud = '115200';
  String tcpPort = '9268';
  bool allowLan = false;
  bool invalidBridgeSettings = false;
  bool feedbackUnavailable = false;
  String? backgroundError;
  bool presenceFailed = false;
  bool startPending = false;
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

  bool get workerActive {
    final snapshot = widget.session?.snapshot;
    return snapshot != null &&
        (!snapshot.finished || snapshot.serialOpen || snapshot.clientConnected);
  }

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
    unawaited(reflectPresence());
  }

  Future<void> reflectPresence() async {
    if (presenceFailed || widget.presence == null) return;
    try {
      await widget.presence!.reflect(state, locale, workerActive: workerActive);
    } catch (error) {
      presenceFailed = true;
      if (workerActive) unawaited(widget.session!.stop());
      if (mounted) {
        setState(() {
          backgroundError = error.toString();
          page = 2;
        });
      }
    }
  }

  Future<void> loadPreferences() async {
    try {
      final savedLanguage = await preferences.readLanguage();
      final savedAppearance = await preferences.readAppearance();
      if (!mounted || settingsChanged) return;
      setState(() {
        if (savedLanguage == 'en' || savedLanguage == 'be') {
          locale = Locale(savedLanguage!);
        }
        if (savedAppearance != null) appearance = savedAppearance;
      });
      unawaited(reflectPresence());
    } catch (error) {
      debugPrint('Unable to load UI preferences: $error');
    }
  }

  void changeLocale(Locale value) {
    settingsChanged = true;
    setState(() => locale = value);
    unawaited(saveLanguage(value.languageCode));
    unawaited(reflectPresence());
  }

  void changeAppearance(PovadAppearance value) {
    settingsChanged = true;
    setState(() => appearance = value);
    unawaited(saveAppearance(value));
  }

  Future<void> sendFeedback() async {
    const uri = 'https://github.com/ialexpovad/povad/issues/new/choose';
    try {
      if (await launchUrl(
        Uri.parse(uri),
        mode: LaunchMode.externalApplication,
      )) {
        if (mounted) setState(() => feedbackUnavailable = false);
        return;
      }
    } catch (_) {
      // The visible settings message below gives the user a direct URL.
    }
    if (mounted) {
      setState(() {
        feedbackUnavailable = true;
        page = 3;
      });
    }
  }

  Future<void> saveLanguage(String languageCode) async {
    try {
      await preferences.saveLanguage(languageCode);
    } catch (error) {
      debugPrint('Unable to save UI language: $error');
    }
  }

  Future<void> saveAppearance(PovadAppearance value) async {
    try {
      await preferences.saveAppearance(value);
    } catch (error) {
      debugPrint('Unable to save UI theme: $error');
    }
  }

  void act() {
    if (widget.session != null) {
      if (startPending) return;
      if (state == BridgeViewState.stopped) {
        if (!configurationReady) {
          setState(() {
            invalidBridgeSettings = true;
            page = 1;
          });
          return;
        }
        unawaited(startLiveBridge());
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

  Future<void> startLiveBridge() async {
    if (presenceFailed) {
      setState(() => page = 2);
      return;
    }
    setState(() => startPending = true);
    try {
      await widget.presence?.prepareStart(serialPort, locale);
      if (!mounted) {
        await widget.presence?.reflect(
          BridgeViewState.stopped,
          locale,
          workerActive: false,
        );
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
    } catch (error) {
      try {
        await widget.presence?.reflect(
          BridgeViewState.stopped,
          locale,
          workerActive: false,
        );
      } catch (_) {
        // Preserve the original startup failure for the details screen.
      }
      if (mounted) {
        setState(() {
          backgroundError = error.toString();
          page = 2;
        });
      }
    } finally {
      if (mounted) setState(() => startPending = false);
    }
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
    theme: const PovadPalette(false).toShadcn(),
    darkTheme: const PovadPalette(true).toShadcn(),
    themeMode: switch (appearance) {
      PovadAppearance.system => shad.ThemeMode.system,
      PovadAppearance.light => shad.ThemeMode.light,
      PovadAppearance.dark => shad.ThemeMode.dark,
    },
    home: Builder(
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
                    onUsbPortSelected: (port) => unawaited(selectUsbPort(port)),
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
            detail: backgroundError ?? widget.session?.errorMessage,
            previewState: widget.session == null ? state : null,
            onPreviewState: widget.session == null
                ? (value) => setState(() => state = value)
                : null,
          ),
          _ => SettingsPage(
            locale: locale,
            onLocaleChanged: changeLocale,
            appearance: appearance,
            onAppearanceChanged: changeAppearance,
            feedbackError: feedbackUnavailable ? l.feedbackUnavailable : null,
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
                          color: p.background,
                          border: Border(bottom: BorderSide(color: p.border)),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const PovadBrandLockup(compact: true),
                            const Spacer(),
                            Builder(
                              builder: (menuContext) => shad.GhostButton(
                                key: const ValueKey('mobile-menu'),
                                onPressed: () => shad.showOverlay<void>(
                                  menuContext,
                                  const shad.PopoverConfiguration(
                                    alignment: Alignment.topRight,
                                    anchorAlignment: Alignment.bottomRight,
                                    offset: Offset(0, 6),
                                  ),
                                  adaptive: false,
                                  builder: (_) => shad.DropdownMenu(
                                    children: [
                                      for (var i = 0; i < 4; i++)
                                        shad.MenuButton(
                                          leading: Icon(icons[i], size: 17),
                                          onPressed: (_) =>
                                              setState(() => page = i),
                                          child: Text(
                                            i == 2
                                                ? l.diagnosticsNav
                                                : labels[i],
                                          ),
                                        ),
                                      shad.MenuButton(
                                        leading: const Icon(
                                          shad.LucideIcons.messageSquare,
                                          size: 17,
                                        ),
                                        onPressed: (_) =>
                                            unawaited(sendFeedback()),
                                        child: Text(l.sendFeedback),
                                      ),
                                    ],
                                  ),
                                ),
                                child: Semantics(
                                  label: l.menu,
                                  button: true,
                                  child: const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(
                                      shad.LucideIcons.menu,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: content),
                    ],
                  );
                }
                return Row(
                  children: [
                    Container(
                      width: 192,
                      decoration: BoxDecoration(
                        color: p.surface,
                        border: Border(right: BorderSide(color: p.border)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 22, 14, 28),
                            child: const PovadBrandLockup(),
                          ),
                          for (var i = 0; i < 4; i++)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
                              child: _NavItem(
                                key: ValueKey('nav-$i'),
                                index: i,
                                selected: page == i,
                                icon: icons[i],
                                label: labels[i],
                                onTap: () => setState(() => page = i),
                              ),
                            ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            child: shad.GhostButton(
                              onPressed: () => unawaited(sendFeedback()),
                              child: Row(
                                children: [
                                  Icon(
                                    shad.LucideIcons.messageSquare,
                                    size: 18,
                                    color: p.muted,
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Text(
                                      l.feedbackNav,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: p.foreground,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.index,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final int index;
  final bool selected;
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
          density: shad.ButtonDensity.normal,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Icon(icon, size: 18, color: selected ? p.primary : p.muted),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
