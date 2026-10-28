// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Povad';

  @override
  String get overview => 'Overview';

  @override
  String get bridge => 'Bridge';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get diagnosticsNav => 'Details';

  @override
  String get settings => 'Settings';

  @override
  String get menu => 'Menu';

  @override
  String get sendFeedback => 'Send feedback';

  @override
  String get feedbackNav => 'Feedback';

  @override
  String get feedbackUnavailable =>
      'Could not open GitHub Issues. Try github.com/ialexpovad/povad/issues.';

  @override
  String get openPovad => 'Open Povad';

  @override
  String get quitPovad => 'Quit Povad';

  @override
  String get stopAndQuit => 'Stop bridge and quit';

  @override
  String get closeActiveTitle => 'Bridge is running';

  @override
  String get closeActiveDescription =>
      'Keep all bridges running in the background, or stop them and quit.';

  @override
  String get keepRunning => 'Keep running';

  @override
  String get cancel => 'Cancel';

  @override
  String get previewNotice => 'PREVIEW · No live connection';

  @override
  String get stopped => 'Stopped';

  @override
  String get starting => 'Starting';

  @override
  String get listening => 'Listening';

  @override
  String get connected => 'Connected';

  @override
  String get stopping => 'Stopping';

  @override
  String get error => 'Error';

  @override
  String get stoppedTitle => 'Bridge stopped';

  @override
  String get stoppedDescription => 'Serial and TCP are closed.';

  @override
  String get startingTitle => 'Starting bridge';

  @override
  String get startingDescription => 'Opening serial and TCP…';

  @override
  String get bleStartingDescription =>
      'Opening serial and starting BLE advertising…';

  @override
  String get listeningTitle => 'Waiting for a client';

  @override
  String get listeningDescription => 'Serial ready · TCP listening';

  @override
  String get connectedTitle => 'Client connected';

  @override
  String get connectedDescription =>
      'TCP client attached · data transfer unconfirmed';

  @override
  String get stoppingTitle => 'Stopping bridge';

  @override
  String get stoppingDescription => 'Closing connections…';

  @override
  String get errorTitle => 'Connection needs attention';

  @override
  String get errorDescription => 'See Details for the cause.';

  @override
  String get startBridge => 'Start bridge';

  @override
  String get stopBridge => 'Stop bridge';

  @override
  String get startingAction => 'Starting…';

  @override
  String get stoppingAction => 'Stopping…';

  @override
  String get reviewDetails => 'Review details';

  @override
  String get configureBridge => 'Configure bridge';

  @override
  String get serialPortPath => 'Serial port';

  @override
  String get builtinSerialPort => 'Built-in expansion port';

  @override
  String get usbPortsTitle => 'USB serial devices';

  @override
  String get scanUsbDevices => 'Refresh devices';

  @override
  String get scanningUsbDevices => 'Scanning for USB serial devices…';

  @override
  String get noUsbDevices => 'No supported USB serial device is connected.';

  @override
  String get usbPermissionDenied => 'USB access was not granted.';

  @override
  String get usbUnavailable =>
      'USB Host is unavailable on this Android device or build.';

  @override
  String get usbScanFailed => 'Could not list USB serial devices.';

  @override
  String get baudRate => 'Baud rate';

  @override
  String get parity => 'Parity';

  @override
  String get parityNone => 'None · 8N1';

  @override
  String get parityEven => 'Even · 8E1';

  @override
  String get parityOdd => 'Odd · 8O1';

  @override
  String get customBaudRate => 'Custom rate';

  @override
  String get tcpPortNumber => 'TCP port';

  @override
  String get bridgeSetupIntro => 'Choose a serial device and TCP port.';

  @override
  String get androidBridgeSetupIntro =>
      'Choose a USB serial device and TCP port.';

  @override
  String get loopbackNote => 'Local only (127.0.0.1) by default.';

  @override
  String get lanAccessTitle => 'Allow LAN clients';

  @override
  String get lanAccessRisk =>
      'LAN clients can send bytes to the serial device. No authentication. Use a trusted network.';

  @override
  String get lanAddressesTitle => 'Connect from another device';

  @override
  String get lanAddressUnavailable =>
      'No LAN IPv4 address found. Check the network and refresh.';

  @override
  String get refreshAddresses => 'Refresh';

  @override
  String get copyEndpoint => 'Copy';

  @override
  String get copiedEndpoint => 'Copied';

  @override
  String get invalidBridgeSettings =>
      'Enter a serial port, baud rate from 300 to 4,000,000, and TCP port from 1 to 65,535.';

  @override
  String get serialValue => 'Not configured';

  @override
  String get tcpListener => 'TCP listener';

  @override
  String get tcpValue => 'Not configured';

  @override
  String get serialLabel => 'Serial port';

  @override
  String get previewStates => 'Preview connection states';

  @override
  String get bridgeSetupTitle => 'Bridge setup';

  @override
  String get bridgeSetupBody =>
      'Configure a Serial ↔ TCP or Serial ↔ BLE bridge in this section. This preview does not open a port.';

  @override
  String get diagnosticsTitle => 'No active session';

  @override
  String get diagnosticsBody =>
      'Connection details appear when the bridge runs.';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get belarusian => 'Беларуская';

  @override
  String get appearance => 'Appearance';

  @override
  String get connectionAnimation => 'Connection animation';

  @override
  String get connectionAnimationDescription =>
      'Animate the bridge and bytes on Overview.';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get about => 'About';

  @override
  String get aboutDescription =>
      'Povad forwards bytes between serial devices and TCP or Bluetooth LE clients.';

  @override
  String get updates => 'Updates';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkingForUpdates => 'Checking GitHub…';

  @override
  String get updateCheckFailed => 'Could not check GitHub releases.';

  @override
  String get upToDate => 'Up to date';

  @override
  String get updateNotChecked => 'Not checked yet';

  @override
  String get viewRelease => 'View release';

  @override
  String get updateCheckPrivacy =>
      'Checks GitHub at startup. No serial data or device IDs are sent.';

  @override
  String get versionLabel => 'Version';

  @override
  String get versionUnavailable => 'Unavailable';

  @override
  String get authorLabel => 'Created by';

  @override
  String get licenseValue => 'MIT License';

  @override
  String get sourceCode => 'Source code';

  @override
  String get licenseDetails => 'License';

  @override
  String get projectLinkFailed =>
      'Could not open the link. Visit github.com/ialexpovad/povad.';

  @override
  String get connectionDiagram =>
      'Serial device, Povad bridge, and TCP client connection diagram';

  @override
  String get bleConnectionDiagram =>
      'Serial device, Povad bridge, and Bluetooth LE client connection diagram';

  @override
  String get interrupted => 'Ended';

  @override
  String get interruptedTitle => 'Session ended';

  @override
  String get interruptedDescription =>
      'The client left or the session was interrupted.';

  @override
  String get startAgain => 'Start again';

  @override
  String get editSetup => 'Edit setup';

  @override
  String get copyTcpEndpoint => 'Copy TCP address';

  @override
  String get serialSection => 'Serial device';

  @override
  String get detectedPorts => 'Detected ports';

  @override
  String get noDetectedPorts =>
      'No serial ports found. Connect an adapter or enter its path.';

  @override
  String get refreshPorts => 'Refresh ports';

  @override
  String get settingsLocked => 'Stop the bridge to change these settings.';

  @override
  String get serialPortRequired => 'Enter a serial port.';

  @override
  String get baudInvalid => 'Enter a rate from 300 to 4,000,000.';

  @override
  String get tcpPortInvalid => 'Enter a port from 1 to 65,535.';

  @override
  String get tcpPortHint => 'TCP clients connect to this port.';

  @override
  String get detailsSubtitle => 'Live state reported by the bridge worker.';

  @override
  String get sessionSection => 'Session';

  @override
  String get trafficSection => 'Traffic';

  @override
  String get stateLabel => 'State';

  @override
  String get clientLabel => 'TCP client';

  @override
  String get clientWaiting => 'Waiting';

  @override
  String get clientNone => 'Not connected';

  @override
  String get sessionTime => 'Session time';

  @override
  String get endpointLabel => 'Address';

  @override
  String get fromSerial => 'From serial device';

  @override
  String get fromTcp => 'From TCP client';

  @override
  String get trafficNote =>
      'Bytes received by the bridge. Delivery to the other side is not confirmed.';

  @override
  String get workerMessage => 'Worker message';

  @override
  String get settingsSubtitle =>
      'Language, appearance, updates, and app information.';

  @override
  String get interfaceSection => 'Interface';

  @override
  String get interfaceScale => 'Interface scale';

  @override
  String get interfaceScaleDescription =>
      'Adjust text, icons, and controls. 100% keeps the current size.';

  @override
  String updateAvailableVersion(String version) {
    return 'Povad $version is available';
  }

  @override
  String get updateBadge => 'Update available';

  @override
  String get authorProfile => 'Open author profile';

  @override
  String get help => 'Help';

  @override
  String get helpSubtitle => 'Get started and fix common problems.';

  @override
  String get openHelp => 'Open help';

  @override
  String get closeHelp => 'Close';

  @override
  String get quickStartTitle => 'Get started';

  @override
  String get step1Title => 'Connect the adapter';

  @override
  String get step1Body =>
      'Plug in the USB–Serial adapter, then pick its port in Bridge setup.';

  @override
  String get step2Title => 'Start the bridge';

  @override
  String get step2Body => 'Povad opens the port and waits for one TCP client.';

  @override
  String get step2BleBody =>
      'Povad opens the serial port and advertises a Bluetooth LE service for one client.';

  @override
  String get step3Title => 'Connect your client';

  @override
  String get step3Body =>
      'Point your TCP software at the address shown on Overview. Bytes pass through unchanged.';

  @override
  String get step3BleBody =>
      'Scan for the advertising name in your BLE client. Use the service and characteristic UUIDs from Bridge setup. Subscribe to notifications and send writes. Bytes pass through unchanged.';

  @override
  String get step3BleWindowsBody =>
      'Scan for this computer’s Bluetooth name, or search for the service UUID from Bridge setup. Subscribe to notifications and send writes. Bytes pass through unchanged.';

  @override
  String get faqTitle => 'Questions and fixes';

  @override
  String get faqClientQ => 'My TCP client cannot connect';

  @override
  String get faqClientA =>
      'Check that the status reads “Waiting for a client” and use the address from Overview. From another computer, turn on Allow LAN clients and use a LAN address. A firewall can also block the port.';

  @override
  String get faqBleClientQ => 'My BLE client cannot connect';

  @override
  String get faqBleClientA =>
      'Check that Povad is waiting for a client, Bluetooth is on, and your client scans for Bluetooth LE devices. Use the advertising name and UUIDs from Bridge setup. If Require pairing is on, pair when your system asks. BT24 clients that never pair need Require pairing off.';

  @override
  String get faqBleWindowsClientA =>
      'Check that Povad is waiting for a client and Bluetooth is on. Windows advertises under this computer’s Bluetooth name; you can also search for the service UUID from Bridge setup. If Require pairing is on, pair when asked. BT24 clients that never pair need Require pairing off.';

  @override
  String get faqPortQ => 'The serial port cannot be opened';

  @override
  String get faqPortA =>
      'Close other apps that use the port, reconnect the adapter, and check the port name. On Linux, add your user to the dialout group. On Windows, find the COM number in Device Manager.';

  @override
  String get faqEndedQ => 'Why did the session end?';

  @override
  String get faqEndedA =>
      'Each session serves one TCP client. When it disconnects, the session ends so no bytes reach the wrong client. Select Start again to wait for the next one.';

  @override
  String get faqEndedBleA =>
      'Each session serves one BLE client. When it disconnects, the session ends. Select Start again to advertise for the next client.';

  @override
  String get faqBytesQ => 'Does Povad change my data?';

  @override
  String get faqBytesA =>
      'No. Povad relays bytes in both directions without parsing a protocol, changing checksums, polling the device, or replying on its behalf.';

  @override
  String get faqLanQ => 'Is it safe to allow LAN clients?';

  @override
  String get faqLanA =>
      'LAN clients are not authenticated and can send bytes to your device. Allow them only on a network you trust, and turn LAN access off when you finish.';

  @override
  String get faqBlePairingQ => 'Should my BLE client pair?';

  @override
  String get faqBlePairingA =>
      'Require pairing is on by default. Pair with Povad when your system asks. The connection is encrypted; another client cannot take over the active bridge.';

  @override
  String get faqBleOpenA =>
      'Require pairing is off. This allows BT24-style clients that do not pair, but any nearby Bluetooth device can connect and send bytes to your serial device. Use this mode only where you trust devices in range.';

  @override
  String get faqPrivacyQ => 'Does Povad send my data anywhere?';

  @override
  String get faqPrivacyA =>
      'No. Serial data stays between your device and your client. Povad only asks GitHub whether a newer release exists.';

  @override
  String get shortcutsTitle => 'Keyboard shortcuts';

  @override
  String get shortcutToggle => 'Start or stop the bridge';

  @override
  String get shortcutNavigate => 'Switch section';

  @override
  String get shortcutHelp => 'Open help';

  @override
  String get stillStuck => 'Still stuck?';

  @override
  String get stillStuckBody =>
      'Report the problem on GitHub with your OS, adapter, and steps. Do not include device data.';

  @override
  String get reportProblem => 'Report a problem';

  @override
  String get howToFix => 'How to fix';

  @override
  String get stoppedUnconfigured => 'Choose a serial port to get started.';

  @override
  String get hintSerialAccess =>
      'The port is missing, busy, or not permitted. Close apps that use it, reconnect the adapter, and check its name.';

  @override
  String get hintTcpPort =>
      'This TCP port is in use or not allowed. Choose another port in Bridge setup.';

  @override
  String get hintDisconnected =>
      'The adapter stopped responding or was unplugged. Reconnect it and start again.';

  @override
  String get hintSettings =>
      'The adapter rejected these settings. Try a standard baud rate.';

  @override
  String get hintDelivery =>
      'Some bytes may not have reached the other side. Check the device state before you repeat a command.';

  @override
  String get hintClientLeft =>
      'The TCP client disconnected. Start again to wait for the next client.';

  @override
  String get autoUpdateTitle => 'Download updates automatically';

  @override
  String get autoUpdateBody =>
      'Each download is checked against the release checksum. Installation waits until the bridge is stopped.';

  @override
  String updateDownloading(String version, int percent) {
    return 'Downloading Povad $version… $percent%';
  }

  @override
  String updateReady(String version) {
    return 'Povad $version is ready to install';
  }

  @override
  String get restartToUpdate => 'Restart to update';

  @override
  String get installUpdate => 'Install update';

  @override
  String get downloadUpdate => 'Download update';

  @override
  String get updateInstalling => 'Installing the update…';

  @override
  String get updateWaitsForBridge => 'Stop all bridges to install the update.';

  @override
  String get updateDownloadFailed =>
      'The update could not be downloaded or verified. Povad will try again later.';

  @override
  String get updateManualOnly => 'This build is updated from the release page.';

  @override
  String get updateNotWritable =>
      'Povad cannot write to its folder. Download the update from the release page.';

  @override
  String updatedTo(String version) {
    return 'Povad was updated to $version.';
  }

  @override
  String updateIncomplete(String version) {
    return 'The update to $version did not complete. Install it from the release page.';
  }

  @override
  String get updateInstallsOnQuit =>
      'Installs when you quit Povad, or restart now.';

  @override
  String get androidInstallPermission =>
      'Allow Povad to install apps, then tap Install update again.';

  @override
  String get updateBannerAction => 'Update';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get waitNextClient => 'Wait for next client';

  @override
  String get waitNextDescription =>
      'Reconnect automatically after a client leaves. A late device response may reach the next client.';

  @override
  String get allowedClients => 'Allowed client IPs';

  @override
  String get allowedClientsHint =>
      'Optional. Leave empty to allow any LAN client; separate exact IPv4 addresses with commas.';

  @override
  String get allowedClientsInvalid => 'Enter up to 32 exact IPv4 addresses.';

  @override
  String get clientRejectedBusy => 'Client rejected: bridge busy';

  @override
  String get clientRejectedIp => 'Client rejected: IP not allowed';

  @override
  String get discoveryUnavailable =>
      'Local discovery is unavailable. Connect using the address below.';

  @override
  String get scanBridgeAddress => 'Scan bridge address';

  @override
  String get close => 'Close';

  @override
  String bridgeDefaultName(int number) {
    return 'Bridge $number';
  }

  @override
  String get bridgeChoose => 'Choose bridge';

  @override
  String get bridgeAdd => 'Add bridge';

  @override
  String get bridgeEdit => 'Edit bridge';

  @override
  String get bridgeRemove => 'Remove';

  @override
  String get bridgeRemoveTitle => 'Remove bridge?';

  @override
  String bridgeRemoveDescription(String name) {
    return 'Remove settings for $name?';
  }

  @override
  String get bridgeSave => 'Save';

  @override
  String get bridgeRetry => 'Retry';

  @override
  String get bridgeStorageError =>
      'Bridge settings could not be loaded or saved. Retry to keep your configuration.';

  @override
  String bridgeSerialConflict(String name) {
    return 'This serial port is already used by $name.';
  }

  @override
  String bridgeTcpConflict(String name) {
    return 'This TCP address and port are already used by $name.';
  }

  @override
  String bridgesActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active bridges',
      one: '1 active bridge',
      zero: 'No active bridges',
    );
    return '$_temp0';
  }

  @override
  String get bridgesStopAll => 'Stop all bridges';

  @override
  String get startupSection => 'Startup';

  @override
  String get startAtLogin => 'Open at login';

  @override
  String get startAtLoginDescription =>
      'Open Povad when you sign in. Start bridges when you need them.';

  @override
  String get startAtLoginFailed =>
      'Could not change startup. Try again or check your system settings.';

  @override
  String get startAtLoginApproval =>
      'Allow Povad in your system’s login or startup settings.';

  @override
  String get startAtLoginUnavailable =>
      'Automatic startup requires macOS 13 or later and an installed app.';

  @override
  String get stopBitsLabel => 'Stop bits';

  @override
  String get transportLabel => 'Transport';

  @override
  String get blePeripheral => 'BLE peripheral';

  @override
  String get bleNameLabel => 'Advertising name';

  @override
  String get bleWindowsNameLabel => 'Bluetooth name';

  @override
  String get bleWindowsComputerName => 'Computer’s Bluetooth name';

  @override
  String get bleWindowsNameNote =>
      'Windows advertises under this computer’s Bluetooth name. Povad cannot change it. If your client supports it, search for the service UUID instead.';

  @override
  String get bleNameInvalid => 'Enter a name up to 29 UTF-8 bytes.';

  @override
  String get bleServiceUuidLabel => 'Service UUID';

  @override
  String get bleWriteUuidLabel => 'Write characteristic UUID';

  @override
  String get bleNotifyUuidLabel => 'Notify characteristic UUID';

  @override
  String get bleUuidInvalid => 'Enter a 16-bit or 128-bit UUID.';

  @override
  String get blePairingNote =>
      'The client must pair for an encrypted connection. One client can exchange data at a time.';

  @override
  String get fromBle => 'From BLE';

  @override
  String get bleListeningDescription =>
      'Advertising and waiting for a paired BLE client.';

  @override
  String get bleConnectedDescription =>
      'A paired BLE client is connected to the serial device.';

  @override
  String bridgeBleConflict(String owner) {
    return 'Bluetooth adapter is already used by $owner.';
  }

  @override
  String get clientRejectedUnpaired =>
      'Client rejected: pair with this device first';

  @override
  String get bleBridgeSetupIntro => 'Choose a serial device and BLE settings.';

  @override
  String get androidBleBridgeSetupIntro =>
      'Choose a USB serial device and BLE settings.';

  @override
  String get bleClientLabel => 'BLE client';

  @override
  String get blePairingTitle => 'Require pairing';

  @override
  String get blePairingDescription =>
      'Clients pair for an encrypted link. Turn off for BLE UART clients that never pair, such as apps made for BT24 or HM-10 modules.';

  @override
  String get bleOpenRisk =>
      'Without pairing, any nearby Bluetooth device can connect to this serial device. Use it only where you trust everyone in range.';

  @override
  String get bleOpenNote => 'One client can exchange data at a time.';

  @override
  String get bleStoppedDescription => 'Serial and BLE are closed.';

  @override
  String get bleOpenListeningDescription =>
      'Advertising and waiting for a BLE client.';

  @override
  String get bleOpenConnectedDescription =>
      'A BLE client is connected to the serial device.';

  @override
  String get hintBleClientLeft =>
      'The BLE client disconnected. Start again to wait for the next client.';
}
