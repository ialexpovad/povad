// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Belarusian (`be`).
class AppLocalizationsBe extends AppLocalizations {
  AppLocalizationsBe([String locale = 'be']) : super(locale);

  @override
  String get appName => 'Povad';

  @override
  String get overview => 'Агляд';

  @override
  String get bridge => 'Мост';

  @override
  String get diagnostics => 'Дыягностыка';

  @override
  String get diagnosticsNav => 'Дэталі';

  @override
  String get settings => 'Налады';

  @override
  String get previewNotice => 'ПРАГЛЯД · Няма сапраўднага злучэння';

  @override
  String get stopped => 'Спынены';

  @override
  String get starting => 'Запуск';

  @override
  String get listening => 'Чаканне';

  @override
  String get connected => 'Падключаны';

  @override
  String get stopping => 'Спыненне';

  @override
  String get error => 'Памылка';

  @override
  String get stoppedTitle => 'Мост спынены';

  @override
  String get stoppedDescription => 'Паслядоўны порт і TCP закрытыя.';

  @override
  String get startingTitle => 'Запуск моста';

  @override
  String get startingDescription => 'Адкрываем порт і TCP…';

  @override
  String get listeningTitle => 'Чакаем кліента';

  @override
  String get listeningDescription => 'Порт гатовы · TCP чакае кліента';

  @override
  String get connectedTitle => 'Кліент падключаны';

  @override
  String get connectedDescription =>
      'TCP-кліент падключаны · перадача даных не пацверджана';

  @override
  String get stoppingTitle => 'Спыненне моста';

  @override
  String get stoppingDescription => 'Закрываем злучэнні…';

  @override
  String get errorTitle => 'Злучэнне патрабуе ўвагі';

  @override
  String get errorDescription => 'Прычына — у раздзеле «Дэталі».';

  @override
  String get startBridge => 'Запусціць мост';

  @override
  String get stopBridge => 'Спыніць мост';

  @override
  String get startingAction => 'Запуск…';

  @override
  String get stoppingAction => 'Спыненне…';

  @override
  String get reviewDetails => 'Паглядзець падрабязнасці';

  @override
  String get configureBridge => 'Наладзіць мост';

  @override
  String get serialPortPath => 'Паслядоўны порт';

  @override
  String get usbPortsTitle => 'Паслядоўныя USB-прылады';

  @override
  String get scanUsbDevices => 'Абнавіць спіс прылад';

  @override
  String get scanningUsbDevices => 'Шукаем паслядоўныя USB-прылады…';

  @override
  String get noUsbDevices =>
      'Падтрымліваемая паслядоўная USB-прылада не падключана.';

  @override
  String get usbPermissionDenied => 'Доступ да USB-прылады не дазволены.';

  @override
  String get usbUnavailable =>
      'USB Host недаступны на гэтай Android-прыладзе або ў гэтай зборцы.';

  @override
  String get usbScanFailed =>
      'Не ўдалося атрымаць спіс паслядоўных USB-прылад.';

  @override
  String get baudRate => 'Хуткасць перадачы';

  @override
  String get tcpPortNumber => 'Порт TCP';

  @override
  String get bridgeSetupIntro => 'Выберыце паслядоўную прыладу і порт TCP.';

  @override
  String get androidBridgeSetupIntro =>
      'Выберыце паслядоўную USB-прыладу і порт TCP.';

  @override
  String get loopbackNote => 'Па змаўчанні толькі гэта прылада (127.0.0.1).';

  @override
  String get lanAccessTitle => 'Дазволіць кліентаў лакальнай сеткі';

  @override
  String get lanAccessRisk =>
      'Кліенты сеткі могуць адпраўляць байты ў паслядоўную прыладу. Праверкі доступу няма. Выкарыстоўвайце давераную сетку.';

  @override
  String get invalidBridgeSettings =>
      'Увядзіце паслядоўны порт, хуткасць ад 300 да 4 000 000 і порт TCP ад 1 да 65 535.';

  @override
  String get serialValue => 'Не настроена';

  @override
  String get tcpListener => 'TCP-сервер';

  @override
  String get tcpValue => 'Не настроена';

  @override
  String get serialLabel => 'ПОРТ';

  @override
  String get previewStates => 'Паказаць станы злучэння';

  @override
  String get bridgeSetupTitle => 'Налады моста';

  @override
  String get bridgeSetupBody =>
      'Налады паслядоўнага порта і TCP з’явяцца тут пасля падключэння працоўнага модуля. Гэты папярэдні прагляд не адкрывае порт.';

  @override
  String get diagnosticsTitle => 'Няма актыўнага сеансу';

  @override
  String get diagnosticsBody =>
      'Звесткі аб злучэнні з’явяцца пасля запуску моста.';

  @override
  String get language => 'Мова';

  @override
  String get english => 'English';

  @override
  String get belarusian => 'Беларуская';

  @override
  String get appearance => 'Выгляд';

  @override
  String get systemTheme => 'Сістэмная';

  @override
  String get lightTheme => 'Светлая';

  @override
  String get darkTheme => 'Цёмная';

  @override
  String get about => 'Аб праграме';

  @override
  String get aboutDescription =>
      'Povad аб’ядноўвае падключэнні прылад. Мост паслядоўны порт ↔ TCP — першы модуль.';

  @override
  String get connectionDiagram =>
      'Схема злучэння паслядоўнай прылады, моста Povad і TCP-кліента';
}
