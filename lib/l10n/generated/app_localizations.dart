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

  /// No description provided for @appCaption.
  ///
  /// In en, this message translates to:
  /// **'Device connectivity'**
  String get appCaption;

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

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @moduleName.
  ///
  /// In en, this message translates to:
  /// **'Serial ↔ TCP Bridge'**
  String get moduleName;

  /// No description provided for @pageTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection overview'**
  String get pageTitle;

  /// No description provided for @previewNotice.
  ///
  /// In en, this message translates to:
  /// **'INTERFACE PREVIEW · No serial or TCP connection'**
  String get previewNotice;

  /// No description provided for @connectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection status'**
  String get connectionStatus;

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
  /// **'The serial port and TCP listener are closed.'**
  String get stoppedDescription;

  /// No description provided for @startingTitle.
  ///
  /// In en, this message translates to:
  /// **'Opening the connection'**
  String get startingTitle;

  /// No description provided for @startingDescription.
  ///
  /// In en, this message translates to:
  /// **'The bridge is opening the serial port and starting the TCP listener.'**
  String get startingDescription;

  /// No description provided for @listeningTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a client'**
  String get listeningTitle;

  /// No description provided for @listeningDescription.
  ///
  /// In en, this message translates to:
  /// **'The serial port and TCP listener are open. No client is connected yet.'**
  String get listeningDescription;

  /// No description provided for @connectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Client connected'**
  String get connectedTitle;

  /// No description provided for @connectedDescription.
  ///
  /// In en, this message translates to:
  /// **'A TCP client is attached. This does not confirm data transfer.'**
  String get connectedDescription;

  /// No description provided for @stoppingTitle.
  ///
  /// In en, this message translates to:
  /// **'Closing the connection'**
  String get stoppingTitle;

  /// No description provided for @stoppingDescription.
  ///
  /// In en, this message translates to:
  /// **'The bridge is waiting for its worker to release the connection safely.'**
  String get stoppingDescription;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection needs attention'**
  String get errorTitle;

  /// No description provided for @errorDescription.
  ///
  /// In en, this message translates to:
  /// **'The worker reported a failure. Check details before trying again.'**
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

  /// No description provided for @serialDevice.
  ///
  /// In en, this message translates to:
  /// **'Serial device'**
  String get serialDevice;

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

  /// No description provided for @bridgeLabel.
  ///
  /// In en, this message translates to:
  /// **'POVAD'**
  String get bridgeLabel;

  /// No description provided for @clientLabel.
  ///
  /// In en, this message translates to:
  /// **'TCP CLIENT'**
  String get clientLabel;

  /// No description provided for @previewStates.
  ///
  /// In en, this message translates to:
  /// **'Preview connection states'**
  String get previewStates;

  /// No description provided for @stateDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'An open port does not confirm that a device is healthy or sending data.'**
  String get stateDisclaimer;

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

  /// No description provided for @appearanceSystem.
  ///
  /// In en, this message translates to:
  /// **'Follows your system setting'**
  String get appearanceSystem;

  /// No description provided for @copperTheme.
  ///
  /// In en, this message translates to:
  /// **'Graphite + copper'**
  String get copperTheme;

  /// No description provided for @classicBlueTheme.
  ///
  /// In en, this message translates to:
  /// **'Classic blue'**
  String get classicBlueTheme;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Povad is in development. Serial ↔ TCP Bridge is its first planned module.'**
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
