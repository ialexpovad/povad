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
  String get errorDescription => 'Open Details for the cause.';

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
  String get serialLabel => 'SERIAL';

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
  String get connectionDiagram =>
      'Serial device, Povad bridge, and TCP client connection diagram';
}
