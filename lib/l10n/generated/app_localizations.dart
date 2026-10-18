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
  /// **'Open Details for the cause.'**
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
  /// **'SERIAL'**
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
  /// **'Connection details and failures will appear here when reported by the transport worker.'**
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

  /// No description provided for @connectionDiagram.
  ///
  /// In en, this message translates to:
  /// **'Serial device, Povad bridge, and TCP client connection diagram'**
  String get connectionDiagram;
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
