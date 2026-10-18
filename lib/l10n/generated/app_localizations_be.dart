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
  String get appCaption => 'Сувязь з прыладамі';

  @override
  String get overview => 'Агляд';

  @override
  String get bridge => 'Мост';

  @override
  String get diagnostics => 'Дыягностыка';

  @override
  String get settings => 'Налады';

  @override
  String get moduleName => 'Мост паслядоўны порт ↔ TCP';

  @override
  String get pageTitle => 'Агляд злучэння';

  @override
  String get previewNotice =>
      'ПАПЯРЭДНІ ПРАГЛЯД · Няма злучэння з портам або TCP';

  @override
  String get connectionStatus => 'Стан злучэння';

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
  String get stoppedDescription => 'Паслядоўны порт і TCP-сервер закрытыя.';

  @override
  String get startingTitle => 'Адкрываем злучэнне';

  @override
  String get startingDescription =>
      'Мост адкрывае паслядоўны порт і запускае TCP-сервер.';

  @override
  String get listeningTitle => 'Чакаем кліента';

  @override
  String get listeningDescription =>
      'Паслядоўны порт і TCP-сервер адкрытыя. Кліент яшчэ не падключыўся.';

  @override
  String get connectedTitle => 'Кліент падключаны';

  @override
  String get connectedDescription =>
      'TCP-кліент падключыўся. Гэта не пацвярджае перадачу даных.';

  @override
  String get stoppingTitle => 'Закрываем злучэнне';

  @override
  String get stoppingDescription =>
      'Мост чакае, пакуль працоўны модуль бяспечна закрые злучэнне.';

  @override
  String get errorTitle => 'Злучэнне патрабуе ўвагі';

  @override
  String get errorDescription =>
      'Працоўны модуль паведаміў пра памылку. Праверце падрабязнасці перад паўторнай спробай.';

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
  String get bridgeSetupIntro =>
      'Выберыце лакальны паслядоўны порт і TCP-сервер. Да сеанса далучаецца адзін кліент; яго адключэнне завяршае сеанс.';

  @override
  String get androidBridgeSetupIntro =>
      'Выберыце паслядоўную USB-прыладу і TCP-сервер. Да сеанса далучаецца адзін кліент; яго адключэнне завяршае сеанс.';

  @override
  String get loopbackNote =>
      'Па змаўчанні TCP-сервер даступны толькі на гэтай прыладзе (127.0.0.1).';

  @override
  String get lanAccessTitle => 'Слухаць на ўсіх сеткавых інтэрфейсах';

  @override
  String get lanAccessRisk =>
      'Іншыя прылады, якія маюць доступ да гэтага TCP-порта, могуць адпраўляць байты ў паслядоўную прыладу. Праверкі доступу няма. Уключайце гэта толькі ў даверанай сетцы.';

  @override
  String get invalidBridgeSettings =>
      'Увядзіце паслядоўны порт, хуткасць ад 300 да 4 000 000 і порт TCP ад 1 да 65 535.';

  @override
  String get bridgeUnverified =>
      'Праца з абсталяваннем пакуль не праверана. Перш чым спадзявацца на мост, праверце яго з тэставым адаптарам і прыладай.';

  @override
  String get interruptedTitle => 'Сеанс завершаны';

  @override
  String get interruptedDescription =>
      'Кліент адключыўся або дастаўка даных стала няпэўнай. Праверце падрабязнасці перад новым запускам.';

  @override
  String get serialDevice => 'Паслядоўная прылада';

  @override
  String get serialValue => 'Не настроена';

  @override
  String get tcpListener => 'TCP-сервер';

  @override
  String get tcpValue => 'Не настроена';

  @override
  String get serialLabel => 'ПОРТ';

  @override
  String get bridgeLabel => 'POVAD';

  @override
  String get clientLabel => 'TCP-КЛІЕНТ';

  @override
  String get previewStates => 'Паказаць станы злучэння';

  @override
  String get stateDisclaimer =>
      'Адкрыты порт не пацвярджае спраўнасць прылады або перадачу даных.';

  @override
  String get bridgeSetupTitle => 'Налады моста';

  @override
  String get bridgeSetupBody =>
      'Налады паслядоўнага порта і TCP з’явяцца тут пасля падключэння працоўнага модуля. Гэты папярэдні прагляд не адкрывае порт.';

  @override
  String get diagnosticsTitle => 'Няма актыўнага сеансу';

  @override
  String get diagnosticsBody =>
      'Звесткі аб злучэнні і памылках з’явяцца тут, калі іх паведаміць працоўны модуль.';

  @override
  String get language => 'Мова';

  @override
  String get english => 'English';

  @override
  String get belarusian => 'Беларуская';

  @override
  String get appearance => 'Выгляд';

  @override
  String get appearanceSystem => 'Паводле налад сістэмы';

  @override
  String get copperTheme => 'Графіт і медзь';

  @override
  String get classicBlueTheme => 'Класічны сіні';

  @override
  String get about => 'Аб праграме';

  @override
  String get aboutDescription =>
      'Povad знаходзіцца ў распрацоўцы. Мост паслядоўны порт ↔ TCP — першы запланаваны модуль.';

  @override
  String get connectionDiagram =>
      'Схема злучэння паслядоўнай прылады, моста Povad і TCP-кліента';
}
