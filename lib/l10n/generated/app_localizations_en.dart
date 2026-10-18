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
  String get appCaption => 'Device connectivity';

  @override
  String get overview => 'Overview';

  @override
  String get bridge => 'Bridge';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get settings => 'Settings';

  @override
  String get moduleName => 'Serial ↔ TCP Bridge';

  @override
  String get pageTitle => 'Connection overview';

  @override
  String get previewNotice => 'INTERFACE PREVIEW · No serial or TCP connection';

  @override
  String get connectionStatus => 'Connection status';

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
  String get stoppedDescription =>
      'The serial port and TCP listener are closed.';

  @override
  String get startingTitle => 'Opening the connection';

  @override
  String get startingDescription =>
      'The bridge is opening the serial port and starting the TCP listener.';

  @override
  String get listeningTitle => 'Waiting for a client';

  @override
  String get listeningDescription =>
      'The serial port and TCP listener are open. No client is connected yet.';

  @override
  String get connectedTitle => 'Client connected';

  @override
  String get connectedDescription =>
      'A TCP client is attached. This does not confirm data transfer.';

  @override
  String get stoppingTitle => 'Closing the connection';

  @override
  String get stoppingDescription =>
      'The bridge is waiting for its worker to release the connection safely.';

  @override
  String get errorTitle => 'Connection needs attention';

  @override
  String get errorDescription =>
      'The worker reported a failure. Check details before trying again.';

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
  String get tcpPortNumber => 'TCP port';

  @override
  String get bridgeSetupIntro =>
      'Choose a local serial port and a TCP listener. The first session accepts one client; disconnect ends the session.';

  @override
  String get loopbackNote =>
      'By default, the listener is limited to this device (127.0.0.1).';

  @override
  String get lanAccessTitle => 'Listen on all network interfaces';

  @override
  String get lanAccessRisk =>
      'Other devices that can reach this TCP port can send bytes to the serial device. There is no authentication. Enable this only on a trusted network.';

  @override
  String get invalidBridgeSettings =>
      'Enter a serial port, baud rate from 300 to 4,000,000, and TCP port from 1 to 65,535.';

  @override
  String get bridgeUnverified =>
      'Hardware behavior is not verified yet. Use a test adapter and device before relying on this bridge.';

  @override
  String get interruptedTitle => 'Session ended';

  @override
  String get interruptedDescription =>
      'The client disconnected or delivery became uncertain. Review details before restarting.';

  @override
  String get serialDevice => 'Serial device';

  @override
  String get serialValue => 'Not configured';

  @override
  String get tcpListener => 'TCP listener';

  @override
  String get tcpValue => 'Not configured';

  @override
  String get serialLabel => 'SERIAL';

  @override
  String get bridgeLabel => 'POVAD';

  @override
  String get clientLabel => 'TCP CLIENT';

  @override
  String get previewStates => 'Preview connection states';

  @override
  String get stateDisclaimer =>
      'An open port does not confirm that a device is healthy or sending data.';

  @override
  String get bridgeSetupTitle => 'Bridge setup';

  @override
  String get bridgeSetupBody =>
      'Serial and TCP configuration will appear here when the transport worker is integrated. This preview does not open a port.';

  @override
  String get diagnosticsTitle => 'No active session';

  @override
  String get diagnosticsBody =>
      'Connection details and failures will appear here when reported by the transport worker.';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get belarusian => 'Беларуская';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceSystem => 'Follows your system setting';

  @override
  String get copperTheme => 'Graphite + copper';

  @override
  String get classicBlueTheme => 'Classic blue';

  @override
  String get about => 'About';

  @override
  String get aboutDescription =>
      'Povad is in development. Serial ↔ TCP Bridge is its first planned module.';

  @override
  String get connectionDiagram =>
      'Serial device, Povad bridge, and TCP client connection diagram';
}
