import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_be.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('be'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Povad'**
  String get appName;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @bridge.
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get bridge;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @diagnosticsNav.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get diagnosticsNav;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get sendFeedback;

  /// No description provided for @feedbackNav.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedbackNav;

  /// No description provided for @feedbackUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open GitHub Issues. Try github.com/ialexpovad/povad/issues.'**
  String get feedbackUnavailable;

  /// No description provided for @openPovad.
  ///
  /// In en, this message translates to:
  /// **'Open Povad'**
  String get openPovad;

  /// No description provided for @quitPovad.
  ///
  /// In en, this message translates to:
  /// **'Quit Povad'**
  String get quitPovad;

  /// No description provided for @stopAndQuit.
  ///
  /// In en, this message translates to:
  /// **'Stop bridge and quit'**
  String get stopAndQuit;

  /// No description provided for @previewNotice.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW · No live connection'**
  String get previewNotice;

  /// No description provided for @stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stopped;

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get starting;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get listening;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @stopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get stopping;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @stoppedTitle.
  ///
  /// In en, this message translates to:
  /// **'Bridge stopped'**
  String get stoppedTitle;

  /// No description provided for @stoppedDescription.
  ///
  /// In en, this message translates to:
  /// **'Serial and TCP are closed.'**
  String get stoppedDescription;

  /// No description provided for @startingTitle.
  ///
  /// In en, this message translates to:
  /// **'Starting bridge'**
  String get startingTitle;

  /// No description provided for @startingDescription.
  ///
  /// In en, this message translates to:
  /// **'Opening serial and TCP…'**
  String get startingDescription;

  /// No description provided for @listeningTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a client'**
  String get listeningTitle;

  /// No description provided for @listeningDescription.
  ///
  /// In en, this message translates to:
  /// **'Serial ready · TCP listening'**
  String get listeningDescription;

  /// No description provided for @connectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Client connected'**
  String get connectedTitle;

  /// No description provided for @connectedDescription.
  ///
  /// In en, this message translates to:
  /// **'TCP client attached · data transfer unconfirmed'**
  String get connectedDescription;

  /// No description provided for @stoppingTitle.
  ///
  /// In en, this message translates to:
  /// **'Stopping bridge'**
  String get stoppingTitle;

  /// No description provided for @stoppingDescription.
  ///
  /// In en, this message translates to:
  /// **'Closing connections…'**
  String get stoppingDescription;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection needs attention'**
  String get errorTitle;

  /// No description provided for @errorDescription.
  ///
  /// In en, this message translates to:
  /// **'See Details for the cause.'**
  String get errorDescription;

  /// No description provided for @startBridge.
  ///
  /// In en, this message translates to:
  /// **'Start bridge'**
  String get startBridge;

  /// No description provided for @stopBridge.
  ///
  /// In en, this message translates to:
  /// **'Stop bridge'**
  String get stopBridge;

  /// No description provided for @startingAction.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get startingAction;

  /// No description provided for @stoppingAction.
  ///
  /// In en, this message translates to:
  /// **'Stopping…'**
  String get stoppingAction;

  /// No description provided for @reviewDetails.
  ///
  /// In en, this message translates to:
  /// **'Review details'**
  String get reviewDetails;

  /// No description provided for @configureBridge.
  ///
  /// In en, this message translates to:
  /// **'Configure bridge'**
  String get configureBridge;

  /// No description provided for @serialPortPath.
  ///
  /// In en, this message translates to:
  /// **'Serial port'**
  String get serialPortPath;

  /// No description provided for @usbPortsTitle.
  ///
  /// In en, this message translates to:
  /// **'USB serial devices'**
  String get usbPortsTitle;

  /// No description provided for @scanUsbDevices.
  ///
  /// In en, this message translates to:
  /// **'Refresh devices'**
  String get scanUsbDevices;

  /// No description provided for @scanningUsbDevices.
  ///
  /// In en, this message translates to:
  /// **'Scanning for USB serial devices…'**
  String get scanningUsbDevices;

  /// No description provided for @noUsbDevices.
  ///
  /// In en, this message translates to:
  /// **'No supported USB serial device is connected.'**
  String get noUsbDevices;

  /// No description provided for @usbPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'USB access was not granted.'**
  String get usbPermissionDenied;

  /// No description provided for @usbUnavailable.
  ///
  /// In en, this message translates to:
  /// **'USB Host is unavailable on this Android device or build.'**
  String get usbUnavailable;

  /// No description provided for @usbScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not list USB serial devices.'**
  String get usbScanFailed;

  /// No description provided for @baudRate.
  ///
  /// In en, this message translates to:
  /// **'Baud rate'**
  String get baudRate;

  /// No description provided for @customBaudRate.
  ///
  /// In en, this message translates to:
  /// **'Custom rate'**
  String get customBaudRate;

  /// No description provided for @tcpPortNumber.
  ///
  /// In en, this message translates to:
  /// **'TCP port'**
  String get tcpPortNumber;

  /// No description provided for @bridgeSetupIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose a serial device and TCP port.'**
  String get bridgeSetupIntro;

  /// No description provided for @androidBridgeSetupIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose a USB serial device and TCP port.'**
  String get androidBridgeSetupIntro;

  /// No description provided for @loopbackNote.
  ///
  /// In en, this message translates to:
  /// **'Local only (127.0.0.1) by default.'**
  String get loopbackNote;

  /// No description provided for @lanAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow LAN clients'**
  String get lanAccessTitle;

  /// No description provided for @lanAccessRisk.
  ///
  /// In en, this message translates to:
  /// **'LAN clients can send bytes to the serial device. No authentication. Use a trusted network.'**
  String get lanAccessRisk;

  /// No description provided for @lanAddressesTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect from another device'**
  String get lanAddressesTitle;

  /// No description provided for @lanAddressUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No LAN IPv4 address found. Check the network and refresh.'**
  String get lanAddressUnavailable;

  /// No description provided for @refreshAddresses.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshAddresses;

  /// No description provided for @copyEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyEndpoint;

  /// No description provided for @copiedEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copiedEndpoint;

  /// No description provided for @invalidBridgeSettings.
  ///
  /// In en, this message translates to:
  /// **'Enter a serial port, baud rate from 300 to 4,000,000, and TCP port from 1 to 65,535.'**
  String get invalidBridgeSettings;

  /// No description provided for @serialValue.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get serialValue;

  /// No description provided for @tcpListener.
  ///
  /// In en, this message translates to:
  /// **'TCP listener'**
  String get tcpListener;

  /// No description provided for @tcpValue.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get tcpValue;

  /// No description provided for @serialLabel.
  ///
  /// In en, this message translates to:
  /// **'Serial port'**
  String get serialLabel;

  /// No description provided for @previewStates.
  ///
  /// In en, this message translates to:
  /// **'Preview connection states'**
  String get previewStates;

  /// No description provided for @bridgeSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Bridge setup'**
  String get bridgeSetupTitle;

  /// No description provided for @bridgeSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Serial and TCP configuration will appear here when the transport worker is integrated. This preview does not open a port.'**
  String get bridgeSetupBody;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'No active session'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsBody.
  ///
  /// In en, this message translates to:
  /// **'Connection details appear when the bridge runs.'**
  String get diagnosticsBody;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @belarusian.
  ///
  /// In en, this message translates to:
  /// **'Беларуская'**
  String get belarusian;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Povad brings device connections together. Serial ↔ TCP Bridge is its first module.'**
  String get aboutDescription;

  /// No description provided for @updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking GitHub…'**
  String get checkingForUpdates;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check GitHub releases.'**
  String get updateCheckFailed;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get upToDate;

  /// No description provided for @updateNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get updateNotChecked;

  /// No description provided for @viewRelease.
  ///
  /// In en, this message translates to:
  /// **'View release'**
  String get viewRelease;

  /// No description provided for @updateCheckPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Checks GitHub at startup. No serial data or device IDs are sent.'**
  String get updateCheckPrivacy;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionLabel;

  /// No description provided for @versionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get versionUnavailable;

  /// No description provided for @authorLabel.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get authorLabel;

  /// No description provided for @licenseValue.
  ///
  /// In en, this message translates to:
  /// **'MIT License'**
  String get licenseValue;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @licenseDetails.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get licenseDetails;

  /// No description provided for @projectLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link. Visit github.com/ialexpovad/povad.'**
  String get projectLinkFailed;

  /// No description provided for @connectionDiagram.
  ///
  /// In en, this message translates to:
  /// **'Serial device, Povad bridge, and TCP client connection diagram'**
  String get connectionDiagram;

  /// No description provided for @interrupted.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get interrupted;

  /// No description provided for @interruptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Session ended'**
  String get interruptedTitle;

  /// No description provided for @interruptedDescription.
  ///
  /// In en, this message translates to:
  /// **'The client left or the session was interrupted.'**
  String get interruptedDescription;

  /// No description provided for @startAgain.
  ///
  /// In en, this message translates to:
  /// **'Start again'**
  String get startAgain;

  /// No description provided for @editSetup.
  ///
  /// In en, this message translates to:
  /// **'Edit setup'**
  String get editSetup;

  /// No description provided for @copyTcpEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Copy TCP address'**
  String get copyTcpEndpoint;

  /// No description provided for @serialSection.
  ///
  /// In en, this message translates to:
  /// **'Serial device'**
  String get serialSection;

  /// No description provided for @detectedPorts.
  ///
  /// In en, this message translates to:
  /// **'Detected ports'**
  String get detectedPorts;

  /// No description provided for @noDetectedPorts.
  ///
  /// In en, this message translates to:
  /// **'No serial ports found. Connect an adapter or enter its path.'**
  String get noDetectedPorts;

  /// No description provided for @refreshPorts.
  ///
  /// In en, this message translates to:
  /// **'Refresh ports'**
  String get refreshPorts;

  /// No description provided for @settingsLocked.
  ///
  /// In en, this message translates to:
  /// **'Stop the bridge to change these settings.'**
  String get settingsLocked;

  /// No description provided for @serialPortRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a serial port.'**
  String get serialPortRequired;

  /// No description provided for @baudInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a rate from 300 to 4,000,000.'**
  String get baudInvalid;

  /// No description provided for @tcpPortInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a port from 1 to 65,535.'**
  String get tcpPortInvalid;

  /// No description provided for @tcpPortHint.
  ///
  /// In en, this message translates to:
  /// **'TCP clients connect to this port.'**
  String get tcpPortHint;

  /// No description provided for @detailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live state reported by the bridge worker.'**
  String get detailsSubtitle;

  /// No description provided for @sessionSection.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get sessionSection;

  /// No description provided for @trafficSection.
  ///
  /// In en, this message translates to:
  /// **'Traffic'**
  String get trafficSection;

  /// No description provided for @stateLabel.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get stateLabel;

  /// No description provided for @clientLabel.
  ///
  /// In en, this message translates to:
  /// **'TCP client'**
  String get clientLabel;

  /// No description provided for @clientWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get clientWaiting;

  /// No description provided for @clientNone.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get clientNone;

  /// No description provided for @sessionTime.
  ///
  /// In en, this message translates to:
  /// **'Session time'**
  String get sessionTime;

  /// No description provided for @endpointLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get endpointLabel;

  /// No description provided for @fromSerial.
  ///
  /// In en, this message translates to:
  /// **'From serial device'**
  String get fromSerial;

  /// No description provided for @fromTcp.
  ///
  /// In en, this message translates to:
  /// **'From TCP client'**
  String get fromTcp;

  /// No description provided for @trafficNote.
  ///
  /// In en, this message translates to:
  /// **'Bytes received by the bridge. Delivery to the other side is not confirmed.'**
  String get trafficNote;

  /// No description provided for @workerMessage.
  ///
  /// In en, this message translates to:
  /// **'Worker message'**
  String get workerMessage;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Language, appearance, updates, and app information.'**
  String get settingsSubtitle;

  /// No description provided for @interfaceSection.
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get interfaceSection;

  /// No description provided for @updateAvailableVersion.
  ///
  /// In en, this message translates to:
  /// **'Povad {version} is available'**
  String updateAvailableVersion(String version);

  /// No description provided for @updateBadge.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateBadge;

  /// No description provided for @authorProfile.
  ///
  /// In en, this message translates to:
  /// **'Open author profile'**
  String get authorProfile;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @helpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get started and fix common problems.'**
  String get helpSubtitle;

  /// No description provided for @openHelp.
  ///
  /// In en, this message translates to:
  /// **'Open help'**
  String get openHelp;

  /// No description provided for @closeHelp.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeHelp;

  /// No description provided for @quickStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get quickStartTitle;

  /// No description provided for @step1Title.
  ///
  /// In en, this message translates to:
  /// **'Connect the adapter'**
  String get step1Title;

  /// No description provided for @step1Body.
  ///
  /// In en, this message translates to:
  /// **'Plug in the USB–Serial adapter, then pick its port in Bridge setup.'**
  String get step1Body;

  /// No description provided for @step2Title.
  ///
  /// In en, this message translates to:
  /// **'Start the bridge'**
  String get step2Title;

  /// No description provided for @step2Body.
  ///
  /// In en, this message translates to:
  /// **'Povad opens the port and waits for one TCP client.'**
  String get step2Body;

  /// No description provided for @step3Title.
  ///
  /// In en, this message translates to:
  /// **'Connect your client'**
  String get step3Title;

  /// No description provided for @step3Body.
  ///
  /// In en, this message translates to:
  /// **'Point your TCP software at the address shown on Overview. Bytes pass through unchanged.'**
  String get step3Body;

  /// No description provided for @faqTitle.
  ///
  /// In en, this message translates to:
  /// **'Questions and fixes'**
  String get faqTitle;

  /// No description provided for @faqClientQ.
  ///
  /// In en, this message translates to:
  /// **'My TCP client cannot connect'**
  String get faqClientQ;

  /// No description provided for @faqClientA.
  ///
  /// In en, this message translates to:
  /// **'Check that the status reads “Waiting for a client” and use the address from Overview. From another computer, turn on Allow LAN clients and use a LAN address. A firewall can also block the port.'**
  String get faqClientA;

  /// No description provided for @faqPortQ.
  ///
  /// In en, this message translates to:
  /// **'The serial port cannot be opened'**
  String get faqPortQ;

  /// No description provided for @faqPortA.
  ///
  /// In en, this message translates to:
  /// **'Close other apps that use the port, reconnect the adapter, and check the port name. On Linux, add your user to the dialout group. On Windows, find the COM number in Device Manager.'**
  String get faqPortA;

  /// No description provided for @faqEndedQ.
  ///
  /// In en, this message translates to:
  /// **'Why did the session end?'**
  String get faqEndedQ;

  /// No description provided for @faqEndedA.
  ///
  /// In en, this message translates to:
  /// **'Each session serves one TCP client. When it disconnects, the session ends so no bytes reach the wrong client. Select Start again to wait for the next one.'**
  String get faqEndedA;

  /// No description provided for @faqBytesQ.
  ///
  /// In en, this message translates to:
  /// **'Does Povad change my data?'**
  String get faqBytesQ;

  /// No description provided for @faqBytesA.
  ///
  /// In en, this message translates to:
  /// **'No. Povad relays bytes in both directions without parsing a protocol, changing checksums, polling the device, or replying on its behalf.'**
  String get faqBytesA;

  /// No description provided for @faqLanQ.
  ///
  /// In en, this message translates to:
  /// **'Is it safe to allow LAN clients?'**
  String get faqLanQ;

  /// No description provided for @faqLanA.
  ///
  /// In en, this message translates to:
  /// **'LAN clients are not authenticated and can send bytes to your device. Allow them only on a network you trust, and turn LAN access off when you finish.'**
  String get faqLanA;

  /// No description provided for @faqPrivacyQ.
  ///
  /// In en, this message translates to:
  /// **'Does Povad send my data anywhere?'**
  String get faqPrivacyQ;

  /// No description provided for @faqPrivacyA.
  ///
  /// In en, this message translates to:
  /// **'No. Serial data stays between your device and your client. Povad only asks GitHub whether a newer release exists.'**
  String get faqPrivacyA;

  /// No description provided for @shortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get shortcutsTitle;

  /// No description provided for @shortcutToggle.
  ///
  /// In en, this message translates to:
  /// **'Start or stop the bridge'**
  String get shortcutToggle;

  /// No description provided for @shortcutNavigate.
  ///
  /// In en, this message translates to:
  /// **'Switch section'**
  String get shortcutNavigate;

  /// No description provided for @shortcutHelp.
  ///
  /// In en, this message translates to:
  /// **'Open help'**
  String get shortcutHelp;

  /// No description provided for @stillStuck.
  ///
  /// In en, this message translates to:
  /// **'Still stuck?'**
  String get stillStuck;

  /// No description provided for @stillStuckBody.
  ///
  /// In en, this message translates to:
  /// **'Report the problem on GitHub with your OS, adapter, and steps. Do not include device data.'**
  String get stillStuckBody;

  /// No description provided for @reportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportProblem;

  /// No description provided for @howToFix.
  ///
  /// In en, this message translates to:
  /// **'How to fix'**
  String get howToFix;

  /// No description provided for @stoppedUnconfigured.
  ///
  /// In en, this message translates to:
  /// **'Choose a serial port to get started.'**
  String get stoppedUnconfigured;

  /// No description provided for @hintSerialAccess.
  ///
  /// In en, this message translates to:
  /// **'The port is missing, busy, or not permitted. Close apps that use it, reconnect the adapter, and check its name.'**
  String get hintSerialAccess;

  /// No description provided for @hintTcpPort.
  ///
  /// In en, this message translates to:
  /// **'This TCP port is in use or not allowed. Choose another port in Bridge setup.'**
  String get hintTcpPort;

  /// No description provided for @hintDisconnected.
  ///
  /// In en, this message translates to:
  /// **'The adapter stopped responding or was unplugged. Reconnect it and start again.'**
  String get hintDisconnected;

  /// No description provided for @hintSettings.
  ///
  /// In en, this message translates to:
  /// **'The adapter rejected these settings. Try a standard baud rate.'**
  String get hintSettings;

  /// No description provided for @hintDelivery.
  ///
  /// In en, this message translates to:
  /// **'Some bytes may not have reached the other side. Check the device state before you repeat a command.'**
  String get hintDelivery;

  /// No description provided for @hintClientLeft.
  ///
  /// In en, this message translates to:
  /// **'The TCP client disconnected. Start again to wait for the next client.'**
  String get hintClientLeft;

  /// No description provided for @autoUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Download updates automatically'**
  String get autoUpdateTitle;

  /// No description provided for @autoUpdateBody.
  ///
  /// In en, this message translates to:
  /// **'Each download is checked against the release checksum. Installation waits until the bridge is stopped.'**
  String get autoUpdateBody;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading Povad {version}… {percent}%'**
  String updateDownloading(String version, int percent);

  /// No description provided for @updateReady.
  ///
  /// In en, this message translates to:
  /// **'Povad {version} is ready to install'**
  String updateReady(String version);

  /// No description provided for @restartToUpdate.
  ///
  /// In en, this message translates to:
  /// **'Restart to update'**
  String get restartToUpdate;

  /// No description provided for @installUpdate.
  ///
  /// In en, this message translates to:
  /// **'Install update'**
  String get installUpdate;

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get downloadUpdate;

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing the update…'**
  String get updateInstalling;

  /// No description provided for @updateWaitsForBridge.
  ///
  /// In en, this message translates to:
  /// **'Stop the bridge to install the update.'**
  String get updateWaitsForBridge;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The update could not be downloaded or verified. Povad will try again later.'**
  String get updateDownloadFailed;

  /// No description provided for @updateManualOnly.
  ///
  /// In en, this message translates to:
  /// **'This build is updated from the release page.'**
  String get updateManualOnly;

  /// No description provided for @updateNotWritable.
  ///
  /// In en, this message translates to:
  /// **'Povad cannot write to its folder. Download the update from the release page.'**
  String get updateNotWritable;

  /// No description provided for @updatedTo.
  ///
  /// In en, this message translates to:
  /// **'Povad was updated to {version}.'**
  String updatedTo(String version);

  /// No description provided for @updateIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The update to {version} did not complete. Install it from the release page.'**
  String updateIncomplete(String version);

  /// No description provided for @updateInstallsOnQuit.
  ///
  /// In en, this message translates to:
  /// **'Installs when you quit Povad, or restart now.'**
  String get updateInstallsOnQuit;

  /// No description provided for @androidInstallPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow Povad to install apps, then tap Install update again.'**
  String get androidInstallPermission;

  /// No description provided for @updateBannerAction.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateBannerAction;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['be', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'be':
      return AppLocalizationsBe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
