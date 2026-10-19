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
      'Serial and TCP configuration will appear here when the transport worker is integrated. This preview does not open a port.';

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
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get about => 'About';

  @override
  String get aboutDescription =>
      'Povad brings device connections together. Serial ↔ TCP Bridge is its first module.';

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
  String updateAvailableVersion(String version) {
    return 'Povad $version is available';
  }

  @override
  String get updateBadge => 'Update available';

  @override
  String get authorProfile => 'Open author profile';
}
