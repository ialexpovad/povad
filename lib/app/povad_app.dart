import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:povad_core/povad_core.dart' as core;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:url_launcher/url_launcher.dart';

import '../design/app_surface_scale.dart';
import '../design/povad_components.dart';
import '../design/povad_mark.dart';
import '../design/povad_theme.dart';
import '../domain/bridge_settings.dart';
import '../domain/bridge_fleet.dart';
import '../domain/bridge_profiles.dart';
import '../features/bridge_selector.dart';
import '../domain/client_allowlist.dart';
import '../domain/bridge_view_state.dart';
import '../domain/bridge_session.dart';
import '../domain/android_usb_host.dart';
import '../domain/serial_port_discovery.dart';
import '../domain/trouble_hint.dart';
import '../features/help_panel.dart';
import '../features/overview_page.dart';
import '../features/secondary_pages.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/shadcn_localizations_be.dart';
import 'ui_preferences.dart';
import 'login_startup.dart';
import 'bridge_presence.dart';
import 'desktop_presence.dart';
import 'android_presence.dart';
import 'lan_discovery.dart';
import 'release_updates.dart';
import 'update_installer.dart';

const _repository = 'https://github.com/ialexpovad/povad';
const _authorProfile =
    'https://www.linkedin.com/in/aliaksandr-povad-6154341a7/';

class PovadApp extends StatefulWidget {
  const PovadApp({
    super.key,
    this.preferences,
    this.loginStartup,
    this.session,
    this.fleet,
    this.bridgeProfiles,
    this.presence,
    this.updates,
    this.bridgeSettings,
    this.portDiscovery,
    this.installer,
    this.updatePreferences,
    this.exitForUpdate,
  });

  final UiPreferences? preferences;
  final LoginStartup? loginStartup;

  /// When absent, this widget displays the UI preview for design tests.
  final BridgeSession? session;
  final BridgeFleet? fleet;
  final BridgeProfilesStore? bridgeProfiles;
  final BridgePresence? presence;
  final ReleaseUpdates? updates;

  /// Remembers the last bridge form locally. Absent in tests and previews.
  final BridgeSettingsStore? bridgeSettings;

  /// Suggests serial device paths on desktop. Absent in tests and previews.
  final SerialPortDiscovery? portDiscovery;

  /// Downloads, verifies, and installs releases found by [updates].
  final AppUpdater? installer;
  final UpdatePreferences? updatePreferences;

  /// Quits after confirmed worker shutdown so a desktop helper can install.
  final Future<void> Function()? exitForUpdate;

  @override
  State<PovadApp> createState() => _PovadAppState();
}

class _PovadAppState extends State<PovadApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final BridgeFleet fleet;
  final Map<String, _ConnectionUi> _connectionUi = {};
  final Map<String, _DiscoveryRuntime> _discoveries = {};
  bool profilesReady = false;
  bool profileStorageError = false;
  Future<void> _profileSaveTail = Future.value();
  BridgeConnection get connection => fleet.selected;
  BridgeSession? get session => connection.session;
  _ConnectionUi get ui => _uiFor(connection.id);
  _ConnectionUi _uiFor(String id) =>
      _connectionUi.putIfAbsent(id, _ConnectionUi.new);
  BridgeViewState get state => connection.state;
  set state(BridgeViewState value) => connection.previewState = value;
  BridgeSettings get form => connection.profile.settings;
  void _setForm(BridgeSettings value) =>
      connection.profile = connection.profile.copyWith(settings: value);
  String get serialPort => form.serialPort;
  set serialPort(String value) => _setForm(form.copyWith(serialPort: value));
  String get baud => form.baud;
  set baud(String value) => _setForm(form.copyWith(baud: value));
  String get serialParity => form.parity;
  set serialParity(String value) => _setForm(form.copyWith(parity: value));
  BridgeTransport get transport => form.transport;
  int get stopBits => form.stopBits;
  String get tcpPort => form.tcpPort;
  set tcpPort(String value) => _setForm(form.copyWith(tcpPort: value));
  bool get allowLan => connection.allowLan;
  set allowLan(bool value) => connection.allowLan = value;
  bool get waitNextClient => form.waitNextClient;
  set waitNextClient(bool value) =>
      _setForm(form.copyWith(waitNextClient: value));
  String get allowedClients => form.allowedClients;
  set allowedClients(String value) =>
      _setForm(form.copyWith(allowedClients: value));
  String? get discoveryError => _discoveries[connection.id]?.error;
  String? get backgroundError => ui.backgroundError ?? connection.startupError;
  set backgroundError(String? value) => ui.backgroundError = value;
  String? get selectedUsbLabel => ui.selectedUsbLabel;
  set selectedUsbLabel(String? value) => ui.selectedUsbLabel = value;
  String? get copiedEndpoint => ui.copiedEndpoint;
  set copiedEndpoint(String? value) => ui.copiedEndpoint = value;
  bool get showFieldErrors => ui.showFieldErrors;
  set showFieldErrors(bool value) => ui.showFieldErrors = value;
  int get rejectionNotice => ui.rejectionNotice;
  bool get startPending => connection.preparing;
  DateTime? get sessionStartedAt => connection.startedAt;
  bool get anyBridgeActive => fleet.active || (!fleet.live && running);

  Locale locale = const Locale('en');
  PovadAppearance appearance = PovadAppearance.system;
  bool animateConnection = true;
  int interfaceScale = 100;
  int page = 0;
  late final UiPreferences preferences;
  bool settingsChanged = false;
  bool bridgeFormChanged = false;
  List<({String name, String address})> lanAddresses = const [];
  List<String> discoveredPorts = const [];
  bool feedbackUnavailable = false;
  AppBuild? installedBuild;
  AvailableRelease? availableRelease;
  bool updateChecking = false;
  bool updateChecked = false;
  bool updateCheckFailed = false;
  bool projectLinkFailed = false;
  UpdateStage updateStage = UpdateStage.none;
  double updateProgress = 0;
  StagedUpdate? stagedUpdate;
  bool autoDownload = true;
  bool updateBlocked = false;
  String? updateNotice;
  bool updateNoticeError = false;
  bool updateNoticeDismissed = false;
  Timer? updateTimer;
  bool presenceFailed = false;
  final AndroidUsbHost usbHost = const AndroidUsbHost();
  List<AndroidUsbPort> usbPorts = const [];
  String? usbError;
  bool usbLoading = false;

  bool get androidHost => !kIsWeb && Platform.isAndroid && session != null;

  bool get configurationReady =>
      !BridgeFieldErrors.of(
        serialPort,
        baud,
        transport == BridgeTransport.tcp ? tcpPort : '9268',
      ).any &&
      (transport == BridgeTransport.ble
          ? bleSettingsValid(
              form,
              requireName: defaultTargetPlatform != TargetPlatform.windows,
            )
          : (!allowLan || parseClientAllowlist(allowedClients) != null));

  bool get running =>
      state == BridgeViewState.starting ||
      state == BridgeViewState.listening ||
      state == BridgeViewState.connected ||
      state == BridgeViewState.stopping;

  bool get workerActive => connection.active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.loginStartup?.addListener(onLoginStartupChanged);
    unawaited(widget.loginStartup?.initialize());
    fleet = widget.fleet ?? BridgeFleet(firstSession: widget.session);
    profilesReady = widget.bridgeProfiles == null;
    preferences = widget.preferences ?? DeviceUiPreferences();
    fleet.addListener(onNativeState);
    unawaited(loadPreferences());
    unawaited(loadBridgeSettings());
    if (androidHost) unawaited(refreshUsbPorts());
    unawaited(refreshSerialPorts());
    if (widget.updates != null) {
      unawaited(checkUpdates());
      // Long-running sessions still learn about new releases.
      updateTimer = Timer.periodic(
        const Duration(hours: 6),
        (_) => unawaited(checkUpdates()),
      );
    }
    final presence = widget.presence;
    if (presence is DesktopPresence) {
      presence.beforeExit = installOnQuit;
      presence.chooseCloseAction = chooseActiveCloseAction;
    }
  }

  Future<void> loadBridgeSettings() async {
    try {
      final profilesStore = widget.bridgeProfiles;
      if (profilesStore != null) {
        final saved = await profilesStore.read();
        if (!mounted || bridgeFormChanged) return;
        fleet.restore(saved);
      } else {
        final saved = await widget.bridgeSettings?.read();
        if (!mounted || bridgeFormChanged) return;
        if (saved != null) _setForm(saved);
      }
      if (mounted) {
        setState(() {
          profilesReady = true;
          profileStorageError = false;
        });
      }
    } catch (error) {
      debugPrint('Unable to load bridge profiles: $error');
      if (mounted) setState(() => profileStorageError = true);
    }
  }

  void persistProfiles() {
    if (!profilesReady) return;
    final document = fleet.document;
    final legacy = form;
    _profileSaveTail = _profileSaveTail.then((_) async {
      try {
        if (widget.bridgeProfiles != null) {
          await widget.bridgeProfiles!.save(document);
        } else {
          await widget.bridgeSettings?.save(legacy);
        }
        if (mounted && profileStorageError) {
          setState(() => profileStorageError = false);
        }
      } catch (error) {
        debugPrint('Unable to save bridge profiles: $error');
        if (mounted) setState(() => profileStorageError = true);
      }
    });
  }

  void updateBridgeForm({
    String? serial,
    String? speed,
    String? parity,
    String? port,
    bool? waitNext,
    String? allowedIps,
    BridgeTransport? peerTransport,
    int? serialStopBits,
    String? bleName,
    String? bleServiceUuid,
    String? bleWriteUuid,
    String? bleNotifyUuid,
    bool? bleRequirePairing,
  }) {
    if (!profilesReady || connection.active || fleet.shuttingDown) return;
    bridgeFormChanged = true;
    fleet.updateProfile(
      connection.id,
      settings: form.copyWith(
        serialPort: serial,
        baud: speed,
        parity: parity,
        tcpPort: port,
        waitNextClient: waitNext,
        allowedClients: allowedIps,
        transport: peerTransport,
        stopBits: serialStopBits,
        bleName: bleName,
        bleServiceUuid: bleServiceUuid,
        bleWriteUuid: bleWriteUuid,
        bleNotifyUuid: bleNotifyUuid,
        bleRequirePairing: bleRequirePairing,
      ),
    );
    persistProfiles();
  }

  void selectBridge(String id) {
    fleet.select(id);
    persistProfiles();
  }

  void addBridge() {
    if (!profilesReady || fleet.shuttingDown) return;
    fleet.add();
    page = 1;
    persistProfiles();
  }

  Future<void> editBridge(BuildContext context) async {
    final entry = connection;
    final edit = await showBridgeEditor(
      context,
      profile: entry.profile,
      canRemove: fleet.connections.length > 1,
      enabled: !entry.active,
    );
    if (!mounted || edit == null || entry.active || fleet.shuttingDown) return;
    if (edit.remove) {
      await fleet.remove(entry.id);
      final discovery = _discoveries.remove(entry.id);
      discovery?.retry?.cancel();
      await discovery?.publisher.update(null);
      _connectionUi.remove(entry.id);
    } else {
      fleet.updateProfile(entry.id, name: edit.name);
    }
    persistProfiles();
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
    final target = ui;
    await Clipboard.setData(ClipboardData(text: endpoint));
    if (mounted) setState(() => target.copiedEndpoint = endpoint);
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
        for (final entry in fleet.connections) {
          final serial = entry.profile.settings.serialPort;
          for (final port in discovered) {
            if (port.nativeSelection == serial) {
              _uiFor(entry.id).selectedUsbLabel = port.labelIn(
                discovered,
                builtinName: lookupAppLocalizations(locale).builtinSerialPort,
              );
              break;
            }
          }
          if (!entry.active &&
              serial.isNotEmpty &&
              !discovered.any((port) => port.nativeSelection == serial)) {
            entry.profile = entry.profile.copyWith(
              settings: entry.profile.settings.copyWith(serialPort: ''),
            );
            _uiFor(entry.id).selectedUsbLabel = null;
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => usbError = 'scanFailed');
    } finally {
      if (mounted) setState(() => usbLoading = false);
    }
  }

  Future<void> selectUsbPort(AndroidUsbPort port) async {
    if (!mounted || usbLoading || !profilesReady) return;
    final target = connection;
    setState(() {
      usbLoading = true;
      usbError = null;
    });
    try {
      final allowed = await usbHost.requestPermission(port);
      if (!mounted) return;
      if (allowed &&
          fleet.connections.contains(target) &&
          !target.active &&
          !fleet.shuttingDown) {
        _uiFor(target.id).selectedUsbLabel = port.labelIn(
          usbPorts,
          builtinName: lookupAppLocalizations(locale).builtinSerialPort,
        );
        fleet.updateProfile(
          target.id,
          settings: target.profile.settings.copyWith(
            serialPort: port.nativeSelection,
          ),
        );
        persistProfiles();
      } else {
        setState(() => usbError = 'denied');
      }
    } catch (_) {
      if (mounted) setState(() => usbError = 'scanFailed');
    } finally {
      if (mounted) setState(() => usbLoading = false);
    }
  }

  void onLoginStartupChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.loginStartup?.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.loginStartup?.removeListener(onLoginStartupChanged);
    widget.loginStartup?.dispose();
    updateTimer?.cancel();
    for (final discovery in _discoveries.values) {
      discovery.retry?.cancel();
      unawaited(discovery.publisher.update(null));
    }
    final presence = widget.presence;
    if (presence is DesktopPresence) {
      presence.beforeExit = null;
      presence.chooseCloseAction = null;
    }
    fleet.removeListener(onNativeState);
    unawaited(fleet.close());
    super.dispose();
  }

  void onNativeState() {
    if (!mounted) return;
    for (final entry in fleet.connections) {
      final snapshot = entry.session?.snapshot;
      final ui = _uiFor(entry.id);
      if (snapshot != null) {
        if (snapshot.rejectedBusy > ui.rejectedBusySeen) {
          ui.rejectionNotice = 1;
          ui.rejectedBusySeen = snapshot.rejectedBusy;
        }
        if (snapshot.rejectedIp > ui.rejectedIpSeen) {
          ui.rejectionNotice = 2;
          ui.rejectedIpSeen = snapshot.rejectedIp;
        }
        if (snapshot.rejectedUnpaired > ui.rejectedUnpairedSeen) {
          ui.rejectionNotice = 3;
          ui.rejectedUnpairedSeen = snapshot.rejectedUnpaired;
        }
      }
    }
    setState(() {});
    unawaited(reflectPresence());
    unawaited(syncDiscovery());
  }

  Future<void> syncDiscovery() async {
    await Future.wait([
      for (final entry in fleet.connections) _syncBridgeDiscovery(entry),
    ]);
  }

  Future<void> _syncBridgeDiscovery(BridgeConnection entry) async {
    final runtime = _discoveries.putIfAbsent(
      entry.id,
      () => _DiscoveryRuntime(LanDiscoveryPublisher(id: entry.id)),
    );
    final config = entry.reservedConfig;
    final advertised =
        config != null &&
        config.peer == core.BridgePeer.tcp &&
        config.allowLan &&
        (entry.state == BridgeViewState.listening ||
            entry.state == BridgeViewState.connected);
    final desired = advertised
        ? BridgeAdvertisement(
            port: config.tcpPort,
            serial: config.serialPort,
            busy: entry.state == BridgeViewState.connected,
            name: entry.profile.name.isEmpty
                ? 'Povad ${entry.profile.number}'
                : 'Povad ${entry.profile.name}',
          )
        : null;
    final signature = desired?.signature;
    if (desired == null) {
      runtime.retry?.cancel();
      runtime.retry = null;
    }
    if (signature == runtime.target) return;
    runtime.target = signature;
    try {
      await runtime.publisher.update(desired);
      if (runtime.target != signature) return;
      runtime.retry?.cancel();
      runtime.retry = null;
      if (mounted) setState(() => runtime.error = null);
    } catch (error) {
      if (runtime.target != signature) return;
      runtime.target = null;
      if (mounted) setState(() => runtime.error = error.toString());
      if (mounted && desired != null) {
        runtime.retry?.cancel();
        runtime.retry = Timer(const Duration(seconds: 5), () {
          if (mounted && fleet.connections.contains(entry)) {
            unawaited(_syncBridgeDiscovery(entry));
          }
        });
      }
    }
  }

  Future<void> reflectPresence() async {
    if (presenceFailed || widget.presence == null) return;
    try {
      await widget.presence!.reflect(
        fleet.aggregateState,
        locale,
        workerActive: fleet.active,
      );
    } catch (error) {
      presenceFailed = true;
      if (fleet.active) unawaited(fleet.stopAll());
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
      final savedConnectionAnimation = await preferences
          .readConnectionAnimation();
      final savedInterfaceScale = await preferences.readInterfaceScale();
      if (!mounted || settingsChanged) return;
      setState(() {
        if (savedLanguage == 'en' || savedLanguage == 'be') {
          locale = Locale(savedLanguage!);
        }
        if (savedAppearance != null) appearance = savedAppearance;
        if (savedConnectionAnimation != null) {
          animateConnection = savedConnectionAnimation;
        }
        if (savedInterfaceScale != null &&
            savedInterfaceScale >= 75 &&
            savedInterfaceScale <= 125 &&
            savedInterfaceScale % 5 == 0) {
          interfaceScale = savedInterfaceScale;
        }
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

  void changeConnectionAnimation(bool value) {
    settingsChanged = true;
    setState(() => animateConnection = value);
    unawaited(saveConnectionAnimation(value));
  }

  void changeInterfaceScale(int value) {
    settingsChanged = true;
    setState(() => interfaceScale = value);
    unawaited(saveInterfaceScale(value));
  }

  Future<ActiveCloseAction> chooseActiveCloseAction() async {
    if (!mounted) return ActiveCloseAction.keepRunning;
    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null) return ActiveCloseAction.keepRunning;
    final l = lookupAppLocalizations(locale);
    return await showGeneralDialog<ActiveCloseAction>(
          context: dialogContext,
          barrierDismissible: true,
          barrierLabel: l.cancel,
          barrierColor: const Color(0x59000000),
          pageBuilder: (dialogContext, _, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: shad.AlertDialog(
                  leading: const Icon(shad.LucideIcons.cable),
                  title: Text(l.closeActiveTitle),
                  content: Text(l.closeActiveDescription),
                  actions: [
                    SizedBox(
                      width: 290,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          shad.PrimaryButton(
                            onPressed: () => Navigator.pop(
                              dialogContext,
                              ActiveCloseAction.keepRunning,
                            ),
                            child: Center(child: Text(l.keepRunning)),
                          ),
                          const SizedBox(height: 8),
                          shad.OutlineButton(
                            onPressed: () => Navigator.pop(
                              dialogContext,
                              ActiveCloseAction.stopAndQuit,
                            ),
                            child: Center(child: Text(l.stopAndQuit)),
                          ),
                          const SizedBox(height: 8),
                          shad.GhostButton(
                            onPressed: () => Navigator.pop(
                              dialogContext,
                              ActiveCloseAction.cancel,
                            ),
                            child: Center(child: Text(l.cancel)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        ActiveCloseAction.cancel;
  }

  void openHelp(BuildContext context, {HelpTopic? topic}) {
    unawaited(
      showHelpPanel(
        context,
        topic: topic,
        bleMode: transport == BridgeTransport.ble,
        blePaired: form.bleRequirePairing,
        onReportProblem: () => unawaited(sendFeedback()),
      ),
    );
  }

  /// Desktop shortcuts. Text fields do not consume these combinations.
  Map<ShortcutActivator, VoidCallback> shortcuts(BuildContext context) {
    final mac =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    SingleActivator withModifier(LogicalKeyboardKey key) =>
        SingleActivator(key, meta: mac, control: !mac);
    return {
      withModifier(LogicalKeyboardKey.enter): act,
      withModifier(LogicalKeyboardKey.digit1): () => goTo(0),
      withModifier(LogicalKeyboardKey.digit2): () => goTo(1),
      withModifier(LogicalKeyboardKey.digit3): () => goTo(2),
      withModifier(LogicalKeyboardKey.digit4): () => goTo(3),
      const SingleActivator(LogicalKeyboardKey.f1): () => openHelp(context),
    };
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
      final firstCheck = installedBuild == null;
      setState(() => installedBuild = build);
      if (firstCheck) await reportPendingUpdate(build);
      final release = await updates.check(build);
      if (!mounted) return;
      setState(() {
        availableRelease = release;
        updateChecked = true;
      });
      if (release != null) unawaited(prepareUpdate(release));
    } catch (_) {
      if (mounted) setState(() => updateCheckFailed = true);
    } finally {
      if (mounted) setState(() => updateChecking = false);
    }
  }

  /// Tells the operator whether the update started before the last exit
  /// actually replaced the installed version.
  Future<void> reportPendingUpdate(AppBuild build) async {
    final store = widget.updatePreferences;
    if (store == null) return;
    try {
      autoDownload = await store.readAutoDownload();
      final pending = await store.readPending();
      if (pending == null) return;
      await store.clearPending();
      if (!mounted) return;
      final l = lookupAppLocalizations(locale);
      setState(() {
        updateNoticeDismissed = false;
        if (build.version == pending.to) {
          updateNotice = l.updatedTo(pending.to);
          updateNoticeError = false;
        } else {
          updateNotice = l.updateIncomplete(pending.to);
          updateNoticeError = true;
        }
      });
    } catch (error) {
      debugPrint('Unable to read update state: $error');
    }
  }

  /// Decides how a found release can be installed and, when allowed,
  /// downloads and verifies it in the background.
  Future<void> prepareUpdate(
    AvailableRelease release, {
    bool force = false,
  }) async {
    final installer = widget.installer;
    if (installer == null || _preparingUpdate) return;
    if (stagedUpdate?.version == release.version ||
        updateStage == UpdateStage.downloading ||
        updateStage == UpdateStage.installing) {
      return;
    }
    _preparingUpdate = true;
    try {
      await _prepareUpdate(installer, release, force: force);
    } finally {
      _preparingUpdate = false;
    }
  }

  /// Startup and a button press must not start two downloads at once.
  bool _preparingUpdate = false;

  Future<void> _prepareUpdate(
    AppUpdater installer,
    AvailableRelease release, {
    required bool force,
  }) async {
    if (!release.installable || installer.method == InstallMethod.manual) {
      if (mounted) setState(() => updateStage = UpdateStage.manual);
      return;
    }
    if (!await installer.canInstall()) {
      if (mounted) setState(() => updateStage = UpdateStage.notWritable);
      return;
    }
    if (!autoDownload && !force) {
      if (mounted) setState(() => updateStage = UpdateStage.available);
      return;
    }
    if (!mounted) return;
    setState(() {
      updateStage = UpdateStage.downloading;
      updateProgress = 0;
    });
    try {
      final staged = await installer.download(
        release,
        onProgress: (value) {
          if (mounted) setState(() => updateProgress = value);
        },
      );
      if (!mounted) return;
      setState(() {
        stagedUpdate = staged;
        updateStage = UpdateStage.ready;
      });
    } catch (error) {
      debugPrint('Update download failed: $error');
      if (mounted) setState(() => updateStage = UpdateStage.failed);
    }
  }

  /// Installs a staged update now. Never while the worker owns a port: the
  /// operator stops the bridge first, so shutdown is confirmed beforehand.
  Future<void> installStagedUpdate() async {
    final staged = stagedUpdate, installer = widget.installer;
    if (staged == null || installer == null) return;
    if (anyBridgeActive || !fleet.lockForShutdown()) {
      setState(() => updateBlocked = true);
      return;
    }
    setState(() {
      updateBlocked = false;
      updateStage = UpdateStage.installing;
    });
    try {
      await _profileSaveTail;
      if (profileStorageError) {
        throw StateError('Bridge settings have not been saved');
      }
      final from = installedBuild?.version;
      if (from != null) {
        try {
          await widget.updatePreferences?.savePending(from, staged.version);
        } catch (error) {
          // A preferences failure must not prevent the verified installer
          // from opening. The next launch can still check the current build.
          debugPrint('Unable to remember pending update: $error');
        }
      }
      final started = await installer.launch(staged, relaunch: true);
      if (!started) {
        await _clearPendingUpdate();
        if (mounted) setState(() => updateStage = UpdateStage.needsPermission);
        return;
      }
      if (installer.method == InstallMethod.androidApk) {
        // Android shows its own confirmation; the app is replaced from there.
        if (mounted) setState(() => updateStage = UpdateStage.ready);
        return;
      }
      stagedUpdate = null;
      await widget.exitForUpdate?.call();
    } catch (error) {
      debugPrint('Update install failed: $error');
      await _clearPendingUpdate();
      if (mounted) setState(() => updateStage = UpdateStage.failed);
    } finally {
      fleet.unlockShutdown();
    }
  }

  Future<void> _clearPendingUpdate() async {
    try {
      await widget.updatePreferences?.clearPending();
    } catch (error) {
      debugPrint('Unable to clear pending update: $error');
    }
  }

  /// A staged desktop update installs when Povad quits, so updates do not
  /// depend on the operator remembering to restart.
  Future<void> installOnQuit() async {
    await _profileSaveTail;
    final staged = stagedUpdate, installer = widget.installer;
    if (staged == null || installer == null) return;
    if (profileStorageError) {
      throw StateError('Bridge settings have not been saved');
    }
    if (installer.method != InstallMethod.windowsZip &&
        installer.method != InstallMethod.linuxTarXz) {
      return;
    }
    if (fleet.active) throw StateError('Bridge shutdown is incomplete');
    final from = installedBuild?.version;
    if (from != null) {
      await widget.updatePreferences?.savePending(from, staged.version);
    }
    try {
      if (!await installer.launch(staged, relaunch: false)) {
        throw StateError('Update installer did not start');
      }
      stagedUpdate = null;
    } catch (_) {
      await _clearPendingUpdate();
      rethrow;
    }
  }

  void changeAutoDownload(bool value) {
    setState(() => autoDownload = value);
    unawaited(
      widget.updatePreferences
          ?.saveAutoDownload(value)
          .catchError(
            (Object error) =>
                debugPrint('Unable to save update choice: $error'),
          ),
    );
    final release = availableRelease;
    if (value && release != null) unawaited(prepareUpdate(release));
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

  Future<void> saveConnectionAnimation(bool value) async {
    try {
      await preferences.saveConnectionAnimation(value);
    } catch (error) {
      debugPrint('Unable to save connection animation setting: $error');
    }
  }

  Future<void> saveInterfaceScale(int value) async {
    try {
      await preferences.saveInterfaceScale(value);
    } catch (error) {
      debugPrint('Unable to save interface scale: $error');
    }
  }

  void act() {
    final restartable =
        state == BridgeViewState.stopped ||
        state == BridgeViewState.interrupted ||
        state == BridgeViewState.error;
    if (session != null) {
      if (startPending || !profilesReady || fleet.shuttingDown) return;
      if (workerActive && restartable) {
        unawaited(fleet.stop(connection.id));
        return;
      }
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
        unawaited(fleet.stop(connection.id));
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
    if (presenceFailed || !profilesReady) {
      setState(() => page = 2);
      return;
    }
    final entry = connection;
    final target = ui;
    final settings = entry.profile.settings;
    target.backgroundError = null;
    target.showFieldErrors = false;
    target.rejectedBusySeen = 0;
    target.rejectedIpSeen = 0;
    target.rejectedUnpairedSeen = 0;
    target.rejectionNotice = 0;
    try {
      await fleet.start(
        entry.id,
        core.BridgeConfig(
          serialPort: settings.serialPort.trim(),
          baud: int.parse(settings.baud),
          parity: settings.parity,
          stopBitsX10: settings.stopBits * 10,
          peer: settings.transport == BridgeTransport.ble
              ? core.BridgePeer.ble
              : core.BridgePeer.tcp,
          bleName: defaultTargetPlatform == TargetPlatform.windows
              ? 'Povad BLE'
              : settings.bleName,
          bleServiceUuid: settings.bleServiceUuid,
          bleWriteUuid: settings.bleWriteUuid,
          bleNotifyUuid: settings.bleNotifyUuid,
          bleRequirePairing: settings.bleRequirePairing,
          tcpPort: int.parse(settings.tcpPort),
          bindAddress: entry.allowLan ? '0.0.0.0' : '127.0.0.1',
          allowLan: entry.allowLan,
          waitNextClient: settings.waitNextClient,
          allowedClients: entry.allowLan
              ? parseClientAllowlist(settings.allowedClients) ?? const []
              : const [],
        ),
        prepare: () async {
          final presence = widget.presence;
          if (settings.transport == BridgeTransport.ble &&
              presence is AndroidPresence) {
            await presence.prepareBle(settings.serialPort, locale);
          } else {
            await presence?.prepareStart(settings.serialPort, locale);
          }
        },
      );
    } on BridgeConflict {
      // The overview identifies the other profile using localized copy.
    } catch (error) {
      target.backgroundError = error.toString();
    } finally {
      if (mounted) {
        setState(() {});
        await reflectPresence();
      }
    }
  }

  /// The address a client should use, or null if the port is invalid.
  String? primaryEndpoint() {
    if (transport == BridgeTransport.ble) return null;
    final port = int.tryParse(tcpPort);
    if (port == null || port < 1 || port > 65535) return null;
    if (!allowLan) return '127.0.0.1:$port';
    if (lanAddresses.isEmpty) return '0.0.0.0:$port';
    return '${lanAddresses.first.address}:$port';
  }

  String endpointSummary(AppLocalizations l) {
    if (transport == BridgeTransport.ble) {
      return defaultTargetPlatform == TargetPlatform.windows
          ? l.bleWindowsComputerName
          : form.bleName;
    }
    final endpoint = primaryEndpoint();
    if (endpoint == null) return l.tcpValue;
    final extra = allowLan ? lanAddresses.length - 1 : 0;
    return extra > 0 ? '$endpoint +$extra' : endpoint;
  }

  /// One short line above the mark: a ready update while the bridge is idle,
  /// or the outcome of the last update. Never shown during a session.
  Widget? _overviewNotice(AppLocalizations l) {
    if (running || workerActive) {
      if (rejectionNotice == 0) return null;
      return UpdateNotice(
        key: const ValueKey('client-rejection-notice'),
        icon: shad.LucideIcons.circleAlert,
        text: switch (rejectionNotice) {
          1 => l.clientRejectedBusy,
          2 => l.clientRejectedIp,
          _ => l.clientRejectedUnpaired,
        },
        actionLabel: l.dismiss,
        onAction: () => setState(() => ui.rejectionNotice = 0),
      );
    }
    final release = availableRelease;
    if (updateStage == UpdateStage.ready && release != null) {
      return UpdateNotice(
        key: const ValueKey('update-notice'),
        icon: shad.LucideIcons.circleArrowUp,
        text: l.updateReady(release.version),
        actionLabel: l.updateBannerAction,
        onAction: () => unawaited(installStagedUpdate()),
      );
    }
    if (updateNotice != null && !updateNoticeDismissed) {
      return UpdateNotice(
        key: const ValueKey('update-result'),
        icon: updateNoticeError
            ? shad.LucideIcons.circleAlert
            : shad.LucideIcons.partyPopper,
        text: updateNotice!,
        error: updateNoticeError,
        actionLabel: updateNoticeError && release != null
            ? l.viewRelease
            : l.dismiss,
        onAction: updateNoticeError && release != null
            ? () => unawaited(openProjectPage(release.page))
            : () => setState(() => updateNoticeDismissed = true),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => shad.ShadcnApp(
    title: 'Povad',
    scaling: shad.AdaptiveScaling(
      defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS
          ? 1.25
          : 1.0,
    ),
    surfaceBuilder: (context, child) =>
        AppSurfaceScale(scale: interfaceScale / 100, child: child),
    navigatorKey: _navigatorKey,
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
    final live = session != null;
    final snapshot = session?.snapshot;
    final serialDisplay = serialPort.isEmpty
        ? null
        : selectedUsbLabel ?? serialPort;
    final conflict = connection.conflict;
    final owner = conflict == null ? null : fleet.connection(conflict.ownerId);
    final ownerName = owner == null ? '' : bridgeLabel(owner.profile, l);
    final detail = conflict == null
        ? backgroundError ?? session?.errorMessage
        : switch (conflict.kind) {
            BridgeConflictKind.serial => l.bridgeSerialConflict(ownerName),
            BridgeConflictKind.tcp => l.bridgeTcpConflict(ownerName),
            BridgeConflictKind.ble => l.bridgeBleConflict(ownerName),
          };
    final ended =
        state == BridgeViewState.error || state == BridgeViewState.interrupted;
    final hint = ended ? troubleHintFor(detail) : null;
    final hintText = troubleHintText(
      hint,
      l,
      bleMode: transport == BridgeTransport.ble,
    );
    final endpoint = primaryEndpoint();
    final copyable =
        transport == BridgeTransport.tcp &&
        endpoint != null &&
        (state == BridgeViewState.listening ||
            state == BridgeViewState.connected);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final content = switch (page) {
      0 => OverviewPage(
        notice: _overviewNotice(l),
        state: state,
        animateConnection: animateConnection,
        onAction: act,
        tcpReceived: transport == BridgeTransport.ble
            ? snapshot?.bleReceived ?? 0
            : snapshot?.tcpReceived ?? 0,
        serialReceived: snapshot?.serialReceived ?? 0,
        previewMode: !live,
        configured: !live || configurationReady,
        serialValue: live ? serialDisplay ?? l.serialValue : null,
        tcpValue: live ? endpointSummary(l) : null,
        bleMode: transport == BridgeTransport.ble,
        blePaired: form.bleRequirePairing,
        detail: live ? hintText ?? detail : null,
        onDetails: () => goTo(2),
        onHelp: () => openHelp(context, topic: helpTopicFor(hint)),
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
                parity: serialParity,
                transport: transport,
                stopBits: stopBits,
                bleName: form.bleName,
                bleServiceUuid: form.bleServiceUuid,
                bleWriteUuid: form.bleWriteUuid,
                bleNotifyUuid: form.bleNotifyUuid,
                bleRequirePairing: form.bleRequirePairing,
                onBleRequirePairingChanged: (value) =>
                    updateBridgeForm(bleRequirePairing: value),
                tcpPort: tcpPort,
                onSerialPortChanged: (value) => updateBridgeForm(serial: value),
                onBaudChanged: (value) => updateBridgeForm(speed: value),
                onParityChanged: (value) => updateBridgeForm(parity: value),
                onTransportChanged: (value) =>
                    updateBridgeForm(peerTransport: value),
                onStopBitsChanged: (value) =>
                    updateBridgeForm(serialStopBits: value),
                onBleNameChanged: (value) => updateBridgeForm(bleName: value),
                onBleServiceChanged: (value) =>
                    updateBridgeForm(bleServiceUuid: value),
                onBleWriteChanged: (value) =>
                    updateBridgeForm(bleWriteUuid: value),
                onBleNotifyChanged: (value) =>
                    updateBridgeForm(bleNotifyUuid: value),
                onTcpPortChanged: (value) => updateBridgeForm(port: value),
                allowLan: allowLan,
                waitNextClient: waitNextClient,
                allowedClients: allowedClients,
                discoveryUnavailable: discoveryError != null,
                onWaitNextChanged: (value) => updateBridgeForm(waitNext: value),
                onAllowedClientsChanged: (value) =>
                    updateBridgeForm(allowedIps: value),
                onAllowLanChanged: (value) {
                  setState(() => allowLan = value);
                  if (value) unawaited(refreshLanAddresses());
                },
                lanAddresses: lanAddresses,
                copiedEndpoint: copiedEndpoint,
                onRefreshLan: () => unawaited(refreshLanAddresses()),
                onCopyEndpoint: (value) => unawaited(copyEndpoint(value)),
                showErrors: showFieldErrors,
                running:
                    workerActive ||
                    running ||
                    !profilesReady ||
                    fleet.shuttingDown,
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
        hint: live ? hintText : null,
        serialValue: live ? serialDisplay : null,
        baud: live && baud.isNotEmpty ? baud : null,
        parity: live ? serialParity : null,
        stopBits: live ? stopBits : null,
        endpoint: live
            ? transport == BridgeTransport.ble
                  ? endpointSummary(l)
                  : endpoint
            : null,
        bleMode: transport == BridgeTransport.ble,
        blePaired: form.bleRequirePairing,
        serialReceived: snapshot?.serialReceived ?? 0,
        tcpReceived: transport == BridgeTransport.ble
            ? snapshot?.bleReceived ?? 0
            : snapshot?.tcpReceived ?? 0,
        sessionStartedAt: sessionStartedAt,
        onStartAgain: live ? act : null,
        onEditSetup: live ? () => goTo(1) : null,
        onPreviewState: live ? null : (value) => setState(() => state = value),
      ),
      _ => SettingsPage(
        loginStartup: widget.loginStartup,
        locale: locale,
        onLocaleChanged: changeLocale,
        appearance: appearance,
        onAppearanceChanged: changeAppearance,
        animateConnection: animateConnection,
        onAnimateConnectionChanged: changeConnectionAnimation,
        interfaceScale: interfaceScale,
        onInterfaceScaleChanged: changeInterfaceScale,
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
        updateStage: updateStage,
        updateProgress: updateProgress,
        updateBlocked: updateBlocked && anyBridgeActive,
        autoDownload: widget.installer == null ? null : autoDownload,
        onAutoDownloadChanged: changeAutoDownload,
        onDownloadUpdate: availableRelease == null
            ? null
            : () => unawaited(prepareUpdate(availableRelease!, force: true)),
        onInstallUpdate: () => unawaited(installStagedUpdate()),
        installLabel: widget.installer?.method == InstallMethod.androidApk
            ? l.installUpdate
            : l.restartToUpdate,
        installsOnQuit:
            widget.installer?.method == InstallMethod.windowsZip ||
            widget.installer?.method == InstallMethod.linuxTarXz,
        updateNotice: updateNotice,
        updateNoticeError: updateNoticeError,
      ),
    };

    final animated = AnimatedSwitcher(
      // Switching devices must replace controls immediately. A fading previous
      // bridge could otherwise display Stop while the new bridge offers Start.
      key: ValueKey(connection.id),
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
      child: KeyedSubtree(
        key: ValueKey('${connection.id}:$page'),
        child: content,
      ),
    );
    final bridgeContent = Column(
      children: [
        if (live && page != 3)
          BridgeSelector(
            connections: fleet.connections,
            selectedId: connection.id,
            enabled: profilesReady && !fleet.shuttingDown,
            onSelected: selectBridge,
            onAdd: addBridge,
            onEdit: () => unawaited(editBridge(context)),
          ),
        if (live && profileStorageError)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(l.bridgeStorageError),
                shad.GhostButton(
                  onPressed: () {
                    if (profilesReady) {
                      persistProfiles();
                    } else {
                      unawaited(loadBridgeSettings());
                    }
                  },
                  child: Text(l.bridgeRetry),
                ),
              ],
            ),
          ),
        Expanded(child: animated),
      ],
    );
    final statusLabel = StateCopy.of(state, l).badge;
    final updateReady = availableRelease != null;

    return CallbackShortcuts(
      bindings: shortcuts(context),
      child: Focus(
        autofocus: true,
        child: ColoredBox(
          color: p.background,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                if (box.maxWidth < 760) {
                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: p.background,
                          border: Border(bottom: BorderSide(color: p.border)),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                        child: Row(
                          children: [
                            // Large system text shrinks the wordmark
                            // before it can push the toolbar off screen.
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: _BrandHomeButton(
                                  key: const ValueKey('brand-home-mobile'),
                                  compact: true,
                                  label: l.overview,
                                  onPressed: () => goTo(0),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: page == 0
                                    ? null
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8,
                                          right: 8,
                                        ),
                                        child: StatusPill(
                                          state: state,
                                          label: statusLabel,
                                        ),
                                      ),
                              ),
                            ),
                            Builder(
                              builder: (menuContext) => ToolbarIconButton(
                                key: const ValueKey('mobile-menu'),
                                icon: shad.LucideIcons.menu,
                                label: l.menu,
                                badge: updateReady,
                                quiet: true,
                                onPressed: () => shad.showOverlay<void>(
                                  menuContext,
                                  const shad.PopoverConfiguration(
                                    alignment: Alignment.topRight,
                                    anchorAlignment: Alignment.bottomRight,
                                    offset: Offset(0, 8),
                                  ),
                                  adaptive: false,
                                  builder: (_) => shad.DropdownMenu(
                                    children: [
                                      for (var i = 0; i < 4; i++)
                                        shad.MenuButton(
                                          leading: Icon(icons[i], size: 17),
                                          trailing: i == 3 && updateReady
                                              ? StatusDot(
                                                  color: p.primary,
                                                  size: 7,
                                                )
                                              : null,
                                          onPressed: (_) => goTo(i),
                                          child: Text(labels[i]),
                                        ),
                                      const shad.MenuDivider(),
                                      shad.MenuButton(
                                        leading: const Icon(
                                          shad.LucideIcons.lifeBuoy,
                                          size: 17,
                                        ),
                                        onPressed: (_) => openHelp(context),
                                        child: Text(l.help),
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
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: bridgeContent),
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 22, 14, 26),
                            child: _BrandHomeButton(
                              key: const ValueKey('brand-home-desktop'),
                              label: l.overview,
                              onPressed: () => goTo(0),
                            ),
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
                                badge: i == 3 && updateReady
                                    ? l.updateBadge
                                    : null,
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
                                child: StatusPill(
                                  state: state,
                                  label: statusLabel,
                                ),
                              ),
                            ),
                          ),
                          Container(height: 1, color: p.border),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                            child: _FooterAction(
                              key: const ValueKey('sidebar-help'),
                              icon: shad.LucideIcons.lifeBuoy,
                              label: l.help,
                              onPressed: () => openHelp(context),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                            child: _FooterAction(
                              icon: shad.LucideIcons.messageSquare,
                              label: l.feedbackNav,
                              trailing: installedBuild?.version,
                              onPressed: () => unawaited(sendFeedback()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: bridgeContent),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHomeButton extends StatelessWidget {
  const _BrandHomeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return Semantics(
      button: true,
      label: 'Povad, $label',
      excludeSemantics: true,
      child: shad.Clickable(
        onPressed: onPressed,
        mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        decoration: WidgetStateProperty.resolveWith(
          (states) => BoxDecoration(
            color:
                states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)
                ? colors.subtle
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 6 : 0),
          child: PovadBrandLockup(compact: compact),
        ),
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return shad.GhostButton(
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 17, color: p.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.foreground, fontSize: 14),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: TextStyle(color: p.muted, fontSize: 11.5)),
        ],
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

class _ConnectionUi {
  String? selectedUsbLabel, copiedEndpoint, backgroundError;
  bool showFieldErrors = false;
  int rejectedBusySeen = 0, rejectedIpSeen = 0;
  int rejectedUnpairedSeen = 0, rejectionNotice = 0;
}

class _DiscoveryRuntime {
  _DiscoveryRuntime(this.publisher);
  final LanDiscoveryPublisher publisher;
  String? target, error;
  Timer? retry;
}
