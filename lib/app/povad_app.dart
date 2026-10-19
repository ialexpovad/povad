import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:povad_core/povad_core.dart' as core;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:url_launcher/url_launcher.dart';

import '../design/povad_components.dart';
import '../design/povad_mark.dart';
import '../design/povad_theme.dart';
import '../domain/bridge_settings.dart';
import '../domain/bridge_view_state.dart';
import '../domain/bridge_session.dart';
import '../domain/android_usb_host.dart';
import '../domain/serial_port_discovery.dart';
import '../features/overview_page.dart';
import '../features/secondary_pages.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/shadcn_localizations_be.dart';
import 'ui_preferences.dart';
import 'bridge_presence.dart';
import 'release_updates.dart';

const _repository = 'https://github.com/ialexpovad/povad';
const _authorProfile =
    'https://www.linkedin.com/in/aliaksandr-povad-6154341a7/';

class PovadApp extends StatefulWidget {
  const PovadApp({
    super.key,
    this.preferences,
    this.session,
    this.presence,
    this.updates,
    this.bridgeSettings,
    this.portDiscovery,
  });

  final UiPreferences? preferences;

  /// When absent, this widget displays the UI preview for design tests.
  final BridgeSession? session;
  final BridgePresence? presence;
  final ReleaseUpdates? updates;

  /// Remembers the last bridge form locally. Absent in tests and previews.
  final BridgeSettingsStore? bridgeSettings;

  /// Suggests serial device paths on desktop. Absent in tests and previews.
  final SerialPortDiscovery? portDiscovery;

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
  bool bridgeFormChanged = false;
  String serialPort = '';
  String baud = '115200';
  String tcpPort = '9268';
  bool allowLan = false;
  List<({String name, String address})> lanAddresses = const [];
  List<String> discoveredPorts = const [];
  String? copiedEndpoint;
  bool showFieldErrors = false;
  bool feedbackUnavailable = false;
  AppBuild? installedBuild;
  AvailableRelease? availableRelease;
  bool updateChecking = false;
  bool updateChecked = false;
  bool updateCheckFailed = false;
  bool projectLinkFailed = false;
  String? backgroundError;
  bool presenceFailed = false;
  bool startPending = false;
  DateTime? sessionStartedAt;
  final AndroidUsbHost usbHost = const AndroidUsbHost();
  List<AndroidUsbPort> usbPorts = const [];
  String? usbError;
  String? selectedUsbLabel;
  bool usbLoading = false;

  bool get androidHost =>
      !kIsWeb && Platform.isAndroid && widget.session != null;

  bool get configurationReady =>
      !BridgeFieldErrors.of(serialPort, baud, tcpPort).any;

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
    unawaited(loadBridgeSettings());
    if (androidHost) unawaited(refreshUsbPorts());
    unawaited(refreshSerialPorts());
    if (widget.updates != null) unawaited(checkUpdates());
  }

  Future<void> loadBridgeSettings() async {
    final store = widget.bridgeSettings;
    if (store == null) return;
    try {
      final saved = await store.read();
      if (saved == null || !mounted || bridgeFormChanged) return;
      setState(() {
        serialPort = saved.serialPort;
        baud = saved.baud;
        tcpPort = saved.tcpPort;
      });
    } catch (error) {
      debugPrint('Unable to load bridge settings: $error');
    }
  }

  void updateBridgeForm({String? serial, String? speed, String? port}) {
    bridgeFormChanged = true;
    setState(() {
      serialPort = serial ?? serialPort;
      baud = speed ?? baud;
      tcpPort = port ?? tcpPort;
    });
    final store = widget.bridgeSettings;
    if (store == null) return;
    unawaited(
      store
          .save(
            BridgeSettings(
              serialPort: serialPort,
              baud: baud,
              tcpPort: tcpPort,
            ),
          )
          .catchError(
            (Object error) =>
                debugPrint('Unable to save bridge settings: $error'),
          ),
    );
  }

  Future<void> refreshSerialPorts() async {
    final discovery = widget.portDiscovery;
    if (discovery == null || !discovery.supported) return;
    final ports = await discovery.discover();
    if (mounted) setState(() => discoveredPorts = ports);
  }

  Future<void> refreshLanAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final addresses = [
        for (final interface in interfaces)
          for (final address in interface.addresses)
            if (!address.isLoopback && !address.isLinkLocal)
              (name: interface.name, address: address.address),
      ];
      if (mounted) setState(() => lanAddresses = addresses);
    } catch (_) {
      if (mounted) setState(() => lanAddresses = const []);
    }
  }

  Future<void> copyEndpoint(String endpoint) async {
    await Clipboard.setData(ClipboardData(text: endpoint));
    if (mounted) setState(() => copiedEndpoint = endpoint);
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
      if (allowed) {
        selectedUsbLabel = port.label;
        updateBridgeForm(serial: port.nativeSelection);
      } else {
        setState(() => usbError = 'denied');
      }
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

  BridgeViewState nativeViewState() {
    final session = widget.session!;
    final snapshot = session.snapshot;
    // A rejected control call leaves no native session behind it.
    if (session.controlError != null && (snapshot?.finished ?? true)) {
      return BridgeViewState.error;
    }
    return switch (session.state) {
      core.BridgeState.stopped => BridgeViewState.stopped,
      core.BridgeState.starting => BridgeViewState.starting,
      core.BridgeState.listening => BridgeViewState.listening,
      core.BridgeState.connected => BridgeViewState.connected,
      core.BridgeState.stopping => BridgeViewState.stopping,
      core.BridgeState.interrupted => BridgeViewState.interrupted,
      core.BridgeState.fault => BridgeViewState.error,
    };
  }

  void onNativeState() {
    if (!mounted) return;
    setState(() {
      state = nativeViewState();
      if (state == BridgeViewState.listening ||
          state == BridgeViewState.connected) {
        sessionStartedAt ??= DateTime.now();
      } else if (state != BridgeViewState.stopping) {
        sessionStartedAt = null;
      }
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

  void goTo(int value) {
    setState(() => page = value);
    if (value == 1) unawaited(refreshSerialPorts());
  }

  Future<void> sendFeedback() async {
    const uri = '$_repository/issues/new/choose';
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

  Future<void> checkUpdates() async {
    final updates = widget.updates;
    if (updates == null || updateChecking) return;
    setState(() {
      updateChecking = true;
      updateCheckFailed = false;
    });
    try {
      final build = await updates.installedBuild();
      if (!mounted) return;
      setState(() => installedBuild = build);
      final release = await updates.check(build);
      if (!mounted) return;
      setState(() {
        availableRelease = release;
        updateChecked = true;
      });
    } catch (_) {
      if (mounted) setState(() => updateCheckFailed = true);
    } finally {
      if (mounted) setState(() => updateChecking = false);
    }
  }

  Future<void> openProjectPage(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) setState(() => projectLinkFailed = false);
        return;
      }
    } catch (_) {
      // Keep the URI available as visible text in Settings.
    }
    if (mounted) setState(() => projectLinkFailed = true);
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
    final restartable =
        state == BridgeViewState.stopped ||
        state == BridgeViewState.interrupted ||
        state == BridgeViewState.error;
    if (widget.session != null) {
      if (startPending) return;
      if (restartable) {
        if (!configurationReady) {
          setState(() {
            showFieldErrors = true;
            page = 1;
          });
          return;
        }
        unawaited(startLiveBridge());
      } else if (state == BridgeViewState.listening ||
          state == BridgeViewState.connected) {
        unawaited(widget.session!.stop());
      }
      return;
    }
    if (!kDebugMode) return;
    setState(() {
      if (restartable) {
        state = BridgeViewState.starting;
      } else if (state == BridgeViewState.listening ||
          state == BridgeViewState.connected) {
        state = BridgeViewState.stopping;
      }
    });
  }

  Future<void> startLiveBridge() async {
    if (presenceFailed) {
      setState(() => page = 2);
      return;
    }
    setState(() {
      startPending = true;
      backgroundError = null;
      showFieldErrors = false;
    });
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
          state = BridgeViewState.error;
        });
      }
    } finally {
      if (mounted) setState(() => startPending = false);
    }
  }

  /// The address a client should use, or null if the port is invalid.
  String? primaryEndpoint() {
    final port = int.tryParse(tcpPort);
    if (port == null || port < 1 || port > 65535) return null;
    if (!allowLan) return '127.0.0.1:$port';
    if (lanAddresses.isEmpty) return '0.0.0.0:$port';
    return '${lanAddresses.first.address}:$port';
  }

  String endpointSummary(AppLocalizations l) {
    final endpoint = primaryEndpoint();
    if (endpoint == null) return l.tcpValue;
    final extra = allowLan ? lanAddresses.length - 1 : 0;
    return extra > 0 ? '$endpoint +$extra' : endpoint;
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
    home: Builder(builder: _buildHome),
  );

  Widget _buildHome(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = paletteOf(context);
    final labels = [l.overview, l.bridge, l.diagnosticsNav, l.settings];
    const icons = [
      shad.LucideIcons.layoutDashboard,
      shad.LucideIcons.cable,
      shad.LucideIcons.activity,
      shad.LucideIcons.settings,
    ];
    final live = widget.session != null;
    final snapshot = widget.session?.snapshot;
    final serialDisplay = serialPort.isEmpty
        ? null
        : selectedUsbLabel ?? serialPort;
    final detail = backgroundError ?? widget.session?.errorMessage;
    final endpoint = primaryEndpoint();
    final copyable =
        endpoint != null &&
        (state == BridgeViewState.listening ||
            state == BridgeViewState.connected);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final content = switch (page) {
      0 => OverviewPage(
        state: state,
        onAction: act,
        tcpReceived: snapshot?.tcpReceived ?? 0,
        serialReceived: snapshot?.serialReceived ?? 0,
        previewMode: !live,
        configured: !live || configurationReady,
        serialValue: live ? serialDisplay ?? l.serialValue : null,
        tcpValue: live ? endpointSummary(l) : null,
        detail: live ? detail : null,
        onDetails: () => goTo(2),
        onEditSetup: () => goTo(1),
        onCopyEndpoint: copyable
            ? () => unawaited(copyEndpoint(endpoint))
            : null,
        endpointCopied: copiedEndpoint == endpoint,
      ),
      1 =>
        !live
            ? EmptyPage(
                icon: shad.LucideIcons.cable,
                title: l.bridgeSetupTitle,
                body: l.bridgeSetupBody,
              )
            : BridgeSetupPage(
                serialPort: serialPort,
                baud: baud,
                tcpPort: tcpPort,
                onSerialPortChanged: (value) => updateBridgeForm(serial: value),
                onBaudChanged: (value) => updateBridgeForm(speed: value),
                onTcpPortChanged: (value) => updateBridgeForm(port: value),
                allowLan: allowLan,
                onAllowLanChanged: (value) {
                  setState(() => allowLan = value);
                  if (value) unawaited(refreshLanAddresses());
                },
                lanAddresses: lanAddresses,
                copiedEndpoint: copiedEndpoint,
                onRefreshLan: () => unawaited(refreshLanAddresses()),
                onCopyEndpoint: (value) => unawaited(copyEndpoint(value)),
                showErrors: showFieldErrors,
                running: running,
                discoveredPorts: discoveredPorts,
                discoverySupported:
                    widget.portDiscovery?.supported == true && !androidHost,
                onRefreshPorts: () => unawaited(refreshSerialPorts()),
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
      2 => DetailsPage(
        state: state,
        previewMode: !live,
        detail: live ? detail : null,
        serialValue: live ? serialDisplay : null,
        baud: live && baud.isNotEmpty ? baud : null,
        endpoint: live ? endpoint : null,
        serialReceived: snapshot?.serialReceived ?? 0,
        tcpReceived: snapshot?.tcpReceived ?? 0,
        sessionStartedAt: sessionStartedAt,
        onStartAgain: live ? act : null,
        onEditSetup: live ? () => goTo(1) : null,
        onPreviewState: live ? null : (value) => setState(() => state = value),
      ),
      _ => SettingsPage(
        locale: locale,
        onLocaleChanged: changeLocale,
        appearance: appearance,
        onAppearanceChanged: changeAppearance,
        feedbackError: feedbackUnavailable ? l.feedbackUnavailable : null,
        versionLabel: installedBuild?.label,
        updateChecking: updateChecking,
        updateChecked: updateChecked,
        updateCheckFailed: updateCheckFailed,
        projectLinkFailed: projectLinkFailed,
        availableRelease: availableRelease,
        onCheckUpdates: widget.updates == null
            ? null
            : () => unawaited(checkUpdates()),
        onOpenRelease: availableRelease == null
            ? null
            : () => unawaited(openProjectPage(availableRelease!.page)),
        onOpenSource: () => unawaited(openProjectPage(Uri.parse(_repository))),
        onOpenLicense: () => unawaited(
          openProjectPage(Uri.parse('$_repository/blob/main/LICENSE')),
        ),
        onOpenAuthor: () =>
            unawaited(openProjectPage(Uri.parse(_authorProfile))),
        onSendFeedback: () => unawaited(sendFeedback()),
      ),
    };

    final animated = AnimatedSwitcher(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // Pages fill the content area; a loose Stack would center short ones.
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(page), child: content),
    );
    final statusLabel = StateCopy.of(state, l).badge;
    final updateReady = availableRelease != null;

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
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    child: Row(
                      children: [
                        const PovadBrandLockup(compact: true),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: page == 0
                                ? null
                                : Padding(
                                    padding: const EdgeInsets.only(
                                      left: 8,
                                      right: 4,
                                    ),
                                    child: StatusPill(
                                      state: state,
                                      label: statusLabel,
                                    ),
                                  ),
                          ),
                        ),
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
                                      trailing: i == 3 && updateReady
                                          ? StatusDot(color: p.primary, size: 7)
                                          : null,
                                      onPressed: (_) => goTo(i),
                                      child: Text(labels[i]),
                                    ),
                                  const shad.MenuDivider(),
                                  shad.MenuButton(
                                    leading: const Icon(
                                      shad.LucideIcons.messageSquare,
                                      size: 17,
                                    ),
                                    onPressed: (_) => unawaited(sendFeedback()),
                                    child: Text(l.sendFeedback),
                                  ),
                                ],
                              ),
                            ),
                            child: Semantics(
                              label: l.menu,
                              button: true,
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const Icon(shad.LucideIcons.menu, size: 22),
                                    if (updateReady)
                                      Positioned(
                                        top: 9,
                                        right: 8,
                                        child: StatusDot(
                                          color: p.primary,
                                          size: 7,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: animated),
                ],
              );
            }
            return Row(
              children: [
                Container(
                  width: 212,
                  decoration: BoxDecoration(
                    color: p.sidebar,
                    border: Border(right: BorderSide(color: p.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(18, 22, 14, 26),
                        child: PovadBrandLockup(),
                      ),
                      for (var i = 0; i < 4; i++)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 3),
                          child: _NavItem(
                            key: ValueKey('nav-$i'),
                            index: i,
                            selected: page == i,
                            icon: icons[i],
                            label: labels[i],
                            badge: i == 3 && updateReady ? l.updateBadge : null,
                            onTap: () => goTo(i),
                          ),
                        ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Semantics(
                            liveRegion: false,
                            child: StatusPill(state: state, label: statusLabel),
                          ),
                        ),
                      ),
                      Container(height: 1, color: p.border),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: shad.GhostButton(
                          onPressed: () => unawaited(sendFeedback()),
                          child: Row(
                            children: [
                              Icon(
                                shad.LucideIcons.messageSquare,
                                size: 17,
                                color: p.muted,
                              ),
                              const SizedBox(width: 12),
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
                              if (installedBuild != null)
                                Text(
                                  installedBuild!.version,
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 11.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: animated),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.index,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });
  final int index;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Accessible description of the dot shown beside the label.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Semantics(
      label: badge == null ? label : '$label, $badge',
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
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 18, color: selected ? p.primary : p.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? p.primary : p.foreground,
                    ),
                  ),
                ),
                if (badge != null) StatusDot(color: p.primary, size: 7),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
