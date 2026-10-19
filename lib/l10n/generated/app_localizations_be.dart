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
  String get menu => 'Меню';

  @override
  String get sendFeedback => 'Адправіць водгук';

  @override
  String get feedbackNav => 'Водгук';

  @override
  String get feedbackUnavailable =>
      'Не ўдалося адкрыць GitHub Issues. Адкрыйце github.com/ialexpovad/povad/issues.';

  @override
  String get openPovad => 'Адкрыць Povad';

  @override
  String get quitPovad => 'Выйсці з Povad';

  @override
  String get stopAndQuit => 'Спыніць мост і выйсці';

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
  String get customBaudRate => 'Іншая хуткасць';

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
  String get lanAddressesTitle => 'Падключэнне з іншай прылады';

  @override
  String get lanAddressUnavailable =>
      'Адрас IPv4 лакальнай сеткі не знойдзены. Праверце сетку і абнавіце.';

  @override
  String get refreshAddresses => 'Абнавіць';

  @override
  String get copyEndpoint => 'Скапіяваць';

  @override
  String get copiedEndpoint => 'Скапіявана';

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
  String get serialLabel => 'Паслядоўны порт';

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
  String get updates => 'Абнаўленні';

  @override
  String get checkForUpdates => 'Праверыць абнаўленні';

  @override
  String get checkingForUpdates => 'Правяраем GitHub…';

  @override
  String get updateCheckFailed => 'Не ўдалося праверыць выпускі GitHub.';

  @override
  String get upToDate => 'Актуальная версія';

  @override
  String get updateNotChecked => 'Яшчэ не правяралася';

  @override
  String get viewRelease => 'Адкрыць выпуск';

  @override
  String get updateCheckPrivacy =>
      'Правярае GitHub пры запуску. Даныя порта і ID прылады не перадаюцца.';

  @override
  String get versionLabel => 'Версія';

  @override
  String get versionUnavailable => 'Недаступна';

  @override
  String get authorLabel => 'Распрацаваў';

  @override
  String get licenseValue => 'Ліцэнзія MIT';

  @override
  String get sourceCode => 'Зыходны код';

  @override
  String get licenseDetails => 'Ліцэнзія';

  @override
  String get projectLinkFailed =>
      'Не ўдалося адкрыць спасылку. Адкрыйце github.com/ialexpovad/povad.';

  @override
  String get connectionDiagram =>
      'Схема злучэння паслядоўнай прылады, моста Povad і TCP-кліента';

  @override
  String get interrupted => 'Завершаны';

  @override
  String get interruptedTitle => 'Сеанс завершаны';

  @override
  String get interruptedDescription =>
      'Кліент адключыўся або сеанс перапыніўся.';

  @override
  String get startAgain => 'Запусціць зноў';

  @override
  String get editSetup => 'Змяніць налады';

  @override
  String get copyTcpEndpoint => 'Скапіяваць адрас TCP';

  @override
  String get serialSection => 'Паслядоўная прылада';

  @override
  String get detectedPorts => 'Знойдзеныя порты';

  @override
  String get noDetectedPorts =>
      'Паслядоўныя порты не знойдзены. Падключыце адаптар або ўвядзіце шлях.';

  @override
  String get refreshPorts => 'Абнавіць порты';

  @override
  String get settingsLocked => 'Каб змяніць налады, спыніце мост.';

  @override
  String get serialPortRequired => 'Увядзіце паслядоўны порт.';

  @override
  String get baudInvalid => 'Увядзіце хуткасць ад 300 да 4 000 000.';

  @override
  String get tcpPortInvalid => 'Увядзіце порт ад 1 да 65 535.';

  @override
  String get tcpPortHint => 'TCP-кліенты падключаюцца да гэтага порта.';

  @override
  String get detailsSubtitle =>
      'Бягучы стан, які паведамляе працоўны модуль моста.';

  @override
  String get sessionSection => 'Сеанс';

  @override
  String get trafficSection => 'Трафік';

  @override
  String get stateLabel => 'Стан';

  @override
  String get clientLabel => 'TCP-кліент';

  @override
  String get clientWaiting => 'Чакаем';

  @override
  String get clientNone => 'Не падключаны';

  @override
  String get sessionTime => 'Час сеансу';

  @override
  String get endpointLabel => 'Адрас';

  @override
  String get fromSerial => 'Ад паслядоўнай прылады';

  @override
  String get fromTcp => 'Ад TCP-кліента';

  @override
  String get trafficNote =>
      'Байты, прынятыя мостам. Дастаўка на другі бок не пацверджана.';

  @override
  String get workerMessage => 'Паведамленне модуля';

  @override
  String get settingsSubtitle =>
      'Мова, выгляд, абнаўленні і звесткі пра праграму.';

  @override
  String get interfaceSection => 'Інтэрфейс';

  @override
  String updateAvailableVersion(String version) {
    return 'Даступная Povad $version';
  }

  @override
  String get updateBadge => 'Даступна абнаўленне';

  @override
  String get authorProfile => 'Адкрыць профіль аўтара';

  @override
  String get help => 'Даведка';

  @override
  String get helpSubtitle => 'Як пачаць і як выправіць частыя праблемы.';

  @override
  String get openHelp => 'Адкрыць даведку';

  @override
  String get closeHelp => 'Закрыць';

  @override
  String get quickStartTitle => 'Як пачаць';

  @override
  String get step1Title => 'Падключыце адаптар';

  @override
  String get step1Body =>
      'Падключыце адаптар USB–Serial і выберыце яго порт у наладах моста.';

  @override
  String get step2Title => 'Запусціце мост';

  @override
  String get step2Body => 'Povad адкрывае порт і чакае аднаго TCP-кліента.';

  @override
  String get step3Title => 'Падключыце кліента';

  @override
  String get step3Body =>
      'Укажыце ў TCP-праграме адрас з экрана «Агляд». Байты перадаюцца без змен.';

  @override
  String get faqTitle => 'Пытанні і рашэнні';

  @override
  String get faqClientQ => 'TCP-кліент не можа падключыцца';

  @override
  String get faqClientA =>
      'Пераканайцеся, што стан — «Чакаем кліента», і выкарыстоўвайце адрас з экрана «Агляд». З іншага камп’ютара ўключыце «Дазволіць кліентаў лакальнай сеткі» і выкарыстоўвайце адрас лакальнай сеткі. Порт таксама можа блакаваць брандмаўэр.';

  @override
  String get faqPortQ => 'Не ўдаецца адкрыць паслядоўны порт';

  @override
  String get faqPortA =>
      'Закрыйце іншыя праграмы, якія карыстаюцца портам, перападключыце адаптар і праверце назву порта. У Linux дадайце карыстальніка ў групу dialout. У Windows нумар COM-порта паказаны ў Дыспетчары прылад.';

  @override
  String get faqEndedQ => 'Чаму сеанс завяршыўся?';

  @override
  String get faqEndedA =>
      'Адзін сеанс абслугоўвае аднаго TCP-кліента. Калі ён адключаецца, сеанс завяршаецца, каб байты не трапілі іншаму кліенту. Націсніце «Запусціць зноў», каб чакаць наступнага.';

  @override
  String get faqBytesQ => 'Ці змяняе Povad мае даныя?';

  @override
  String get faqBytesA =>
      'Не. Povad перадае байты ў абодва бакі, не разбіраючы пратакол, не мяняючы кантрольныя сумы, не апытваючы прыладу і не адказваючы за яе.';

  @override
  String get faqLanQ => 'Ці бяспечна дазваляць кліентаў лакальнай сеткі?';

  @override
  String get faqLanA =>
      'Кліенты лакальнай сеткі не правяраюцца і могуць адпраўляць байты ў вашу прыладу. Дазваляйце іх толькі ў даверанай сетцы і выключайце доступ пасля працы.';

  @override
  String get faqPrivacyQ => 'Ці адпраўляе Povad мае даныя кудысьці?';

  @override
  String get faqPrivacyA =>
      'Не. Паслядоўныя даныя застаюцца паміж вашай прыладай і кліентам. Povad толькі пытаецца ў GitHub, ці ёсць новы выпуск.';

  @override
  String get shortcutsTitle => 'Спалучэнні клавіш';

  @override
  String get shortcutToggle => 'Запусціць або спыніць мост';

  @override
  String get shortcutNavigate => 'Пераключыць раздзел';

  @override
  String get shortcutHelp => 'Адкрыць даведку';

  @override
  String get stillStuck => 'Не атрымліваецца?';

  @override
  String get stillStuckBody =>
      'Апішыце праблему на GitHub: АС, адаптар і крокі. Не дадавайце даныя прылады.';

  @override
  String get reportProblem => 'Паведаміць пра праблему';

  @override
  String get howToFix => 'Як выправіць';

  @override
  String get stoppedUnconfigured => 'Каб пачаць, выберыце паслядоўны порт.';

  @override
  String get hintSerialAccess =>
      'Порт адсутнічае, заняты або недаступны. Закрыйце праграмы, якія ім карыстаюцца, перападключыце адаптар і праверце назву.';

  @override
  String get hintTcpPort =>
      'Гэты порт TCP заняты або недаступны. Выберыце іншы порт у наладах моста.';

  @override
  String get hintDisconnected =>
      'Адаптар перастаў адказваць або быў адключаны. Падключыце яго і запусціце зноў.';

  @override
  String get hintSettings =>
      'Адаптар не прыняў гэтыя налады. Паспрабуйце стандартную хуткасць.';

  @override
  String get hintDelivery =>
      'Частка байтаў магла не дайсці. Праверце стан прылады, перш чым паўтараць каманду.';

  @override
  String get hintClientLeft =>
      'TCP-кліент адключыўся. Запусціце зноў, каб чакаць наступнага кліента.';

  @override
  String get autoUpdateTitle => 'Аўтаматычна спампоўваць абнаўленні';

  @override
  String get autoUpdateBody =>
      'Кожнае спампоўванне правяраецца па кантрольнай суме выпуску. Усталяванне чакае, пакуль мост не спынены.';

  @override
  String updateDownloading(String version, int percent) {
    return 'Спампоўваем Povad $version… $percent%';
  }

  @override
  String updateReady(String version) {
    return 'Povad $version гатовая да ўсталявання';
  }

  @override
  String get restartToUpdate => 'Перазапусціць і абнавіць';

  @override
  String get installUpdate => 'Усталяваць абнаўленне';

  @override
  String get downloadUpdate => 'Спампаваць абнаўленне';

  @override
  String get updateInstalling => 'Усталёўваем абнаўленне…';

  @override
  String get updateWaitsForBridge => 'Каб усталяваць абнаўленне, спыніце мост.';

  @override
  String get updateDownloadFailed =>
      'Не ўдалося спампаваць або праверыць абнаўленне. Povad паспрабуе пазней.';

  @override
  String get updateManualOnly =>
      'Гэтая зборка абнаўляецца праз старонку выпуску.';

  @override
  String get updateNotWritable =>
      'Povad не можа запісваць у сваю папку. Спампуйце абнаўленне са старонкі выпуску.';

  @override
  String updatedTo(String version) {
    return 'Povad абноўлена да $version.';
  }

  @override
  String updateIncomplete(String version) {
    return 'Абнаўленне да $version не завяршылася. Усталюйце яго са старонкі выпуску.';
  }

  @override
  String get updateInstallsOnQuit =>
      'Усталюецца, калі вы выйдзеце з Povad, або перазапусціце зараз.';

  @override
  String get androidInstallPermission =>
      'Дазвольце Povad усталёўваць праграмы і зноў націсніце «Усталяваць абнаўленне».';

  @override
  String get updateBannerAction => 'Абнавіць';

  @override
  String get dismiss => 'Схаваць';
}
