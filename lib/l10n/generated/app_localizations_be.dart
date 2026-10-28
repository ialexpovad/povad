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
  String get closeActiveTitle => 'Мост працуе';

  @override
  String get closeActiveDescription =>
      'Пакінуць усе масты працаваць у фоне або спыніць іх і выйсці.';

  @override
  String get keepRunning => 'Пакінуць працаваць';

  @override
  String get cancel => 'Скасаваць';

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
  String get bleStartingDescription =>
      'Адкрываем паслядоўны порт і запускаем аб’яву BLE…';

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
  String get parity => 'Цотнасць';

  @override
  String get parityNone => 'Без цотнасці · 8N1';

  @override
  String get parityEven => 'Цотная · 8E1';

  @override
  String get parityOdd => 'Няцотная · 8O1';

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
      'У гэтым раздзеле наладжваецца мост паміж паслядоўным портам і TCP або BLE. Гэты папярэдні прагляд не адкрывае порт.';

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
  String get connectionAnimation => 'Анімацыя злучэння';

  @override
  String get connectionAnimationDescription =>
      'Рух моста і байтаў на экране агляду.';

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
      'Povad перадае байты паміж паслядоўнымі прыладамі і кліентамі TCP або Bluetooth LE.';

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
  String get bleConnectionDiagram =>
      'Схема злучэння паслядоўнай прылады, моста Povad і BLE-кліента';

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
  String get interfaceScale => 'Маштаб інтэрфейсу';

  @override
  String get interfaceScaleDescription =>
      'Змяняе памер тэксту, значкоў і элементаў кіравання. 100% захоўвае цяперашні памер.';

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
  String get step2BleBody =>
      'Povad адкрывае паслядоўны порт і аб’яўляе сэрвіс Bluetooth LE для аднаго кліента.';

  @override
  String get step3Title => 'Падключыце кліента';

  @override
  String get step3Body =>
      'Укажыце ў TCP-праграме адрас з экрана «Агляд». Байты перадаюцца без змен.';

  @override
  String get step3BleBody =>
      'Знайдзіце імя ў аб’яве праз BLE-кліент. Выкарыстоўвайце UUID сэрвісу і характарыстык з налад моста. Падпішыцеся на апавяшчэнні і адпраўляйце запісы. Байты перадаюцца без змен.';

  @override
  String get step3BleWindowsBody =>
      'Знайдзіце Bluetooth-імя гэтага камп’ютара або пашукайце UUID сэрвісу з налад моста. Падпішыцеся на апавяшчэнні і адпраўляйце запісы. Байты перадаюцца без змен.';

  @override
  String get faqTitle => 'Пытанні і рашэнні';

  @override
  String get faqClientQ => 'TCP-кліент не можа падключыцца';

  @override
  String get faqClientA =>
      'Пераканайцеся, што стан — «Чакаем кліента», і выкарыстоўвайце адрас з экрана «Агляд». З іншага камп’ютара ўключыце «Дазволіць кліентаў лакальнай сеткі» і выкарыстоўвайце адрас лакальнай сеткі. Порт таксама можа блакаваць брандмаўэр.';

  @override
  String get faqBleClientQ => 'BLE-кліент не можа падключыцца';

  @override
  String get faqBleClientA =>
      'Праверце, што Povad чакае кліента, Bluetooth уключаны і кліент шукае прылады Bluetooth LE. Выкарыстоўвайце імя і UUID з налад моста. Калі патрабуецца спалучэнне, пацвердзіце яго ў сістэме. Для кліентаў BT24, якія не спалучаюцца, выключыце патрабаванне спалучэння.';

  @override
  String get faqBleWindowsClientA =>
      'Праверце, што Povad чакае кліента і Bluetooth уключаны. Windows аб’яўляе сэрвіс пад Bluetooth-імем гэтага камп’ютара; таксама можна шукаць UUID сэрвісу з налад моста. Калі патрабуецца спалучэнне, пацвердзіце яго. Для кліентаў BT24, якія не спалучаюцца, выключыце патрабаванне спалучэння.';

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
  String get faqEndedBleA =>
      'Адзін сеанс абслугоўвае аднаго BLE-кліента. Калі ён адключаецца, сеанс завяршаецца. Націсніце «Запусціць зноў», каб аб’явіць мост для наступнага кліента.';

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
  String get faqBlePairingQ => 'Ці трэба спалучаць BLE-кліент?';

  @override
  String get faqBlePairingA =>
      'Патрабаванне спалучэння ўключана па змаўчанні. Пацвердзіце спалучэнне з Povad, калі сістэма папросіць. Злучэнне будзе зашыфраванае; іншы кліент не зможа заняць актыўны мост.';

  @override
  String get faqBleOpenA =>
      'Патрабаванне спалучэння выключана. Гэта дазваляе кліентам накшталт BT24 працаваць без спалучэння, але любая прылада Bluetooth побач можа падключыцца і адпраўляць байты ў паслядоўную прыладу. Выкарыстоўвайце гэты рэжым толькі там, дзе давяраеце прыладам побач.';

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
  String get updateWaitsForBridge =>
      'Спыніце ўсе масты, каб усталяваць абнаўленне.';

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

  @override
  String get waitNextClient => 'Чакаць наступнага кліента';

  @override
  String get waitNextDescription =>
      'Пасля адключэння чакаць зноў. Позні адказ прылады можа трапіць наступнаму кліенту.';

  @override
  String get allowedClients => 'Дазволеныя IP-адрасы кліентаў';

  @override
  String get allowedClientsHint =>
      'Неабавязкова. Пакіньце пустым для ўсіх кліентаў LAN; раздзяляйце IP коскамі.';

  @override
  String get allowedClientsInvalid =>
      'Увядзіце не больш за 32 дакладныя адрасы IPv4.';

  @override
  String get clientRejectedBusy => 'Кліент адхілены: мост заняты';

  @override
  String get clientRejectedIp => 'Кліент адхілены: IP не дазволены';

  @override
  String get discoveryUnavailable =>
      'Пошук у лакальнай сетцы недаступны. Падключыцеся праз адрас ніжэй.';

  @override
  String get scanBridgeAddress => 'Скануйце адрас моста';

  @override
  String get close => 'Закрыць';

  @override
  String bridgeDefaultName(int number) {
    return 'Мост $number';
  }

  @override
  String get bridgeChoose => 'Выбраць мост';

  @override
  String get bridgeAdd => 'Дадаць мост';

  @override
  String get bridgeEdit => 'Налады моста';

  @override
  String get bridgeRemove => 'Выдаліць';

  @override
  String get bridgeRemoveTitle => 'Выдаліць мост?';

  @override
  String bridgeRemoveDescription(String name) {
    return 'Выдаліць налады для $name?';
  }

  @override
  String get bridgeSave => 'Захаваць';

  @override
  String get bridgeRetry => 'Паўтарыць';

  @override
  String get bridgeStorageError =>
      'Не ўдалося загрузіць ці захаваць налады мастоў. Паўтарыце спробу.';

  @override
  String bridgeSerialConflict(String name) {
    return 'Гэты паслядоўны порт ужо выкарыстоўвае $name.';
  }

  @override
  String bridgeTcpConflict(String name) {
    return 'Гэты TCP-адрас і порт ужо выкарыстоўвае $name.';
  }

  @override
  String bridgesActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count актыўнага моста',
      many: '$count актыўных мастоў',
      few: '$count актыўныя масты',
      one: '$count актыўны мост',
      zero: 'Няма актыўных мастоў',
    );
    return '$_temp0';
  }

  @override
  String get bridgesStopAll => 'Спыніць усе масты';

  @override
  String get startupSection => 'Запуск';

  @override
  String get startAtLogin => 'Адкрываць пры ўваходзе';

  @override
  String get startAtLoginDescription =>
      'Адкрываць Povad пры ўваходзе ў сістэму. Запускайце масты, калі яны патрэбныя.';

  @override
  String get startAtLoginFailed =>
      'Не ўдалося змяніць аўтазапуск. Паўтарыце спробу або праверце налады сістэмы.';

  @override
  String get startAtLoginApproval =>
      'Дазвольце Povad у сістэмных наладах уваходу або аўтазапуску.';

  @override
  String get startAtLoginUnavailable =>
      'Аўтазапуск патрабуе macOS 13 або навейшай версіі і ўсталяванай праграмы.';

  @override
  String get stopBitsLabel => 'Стоп-біты';

  @override
  String get transportLabel => 'Транспарт';

  @override
  String get blePeripheral => 'Перыферыйная BLE-прылада';

  @override
  String get bleNameLabel => 'Імя ў аб’яве';

  @override
  String get bleWindowsNameLabel => 'Імя Bluetooth';

  @override
  String get bleWindowsComputerName => 'Bluetooth-імя камп’ютара';

  @override
  String get bleWindowsNameNote =>
      'Windows аб’яўляе сэрвіс пад Bluetooth-імем гэтага камп’ютара. Povad не можа яго змяніць. Калі кліент падтрымлівае такую магчымасць, шукайце UUID сэрвісу.';

  @override
  String get bleNameInvalid => 'Увядзіце імя да 29 байтаў UTF-8.';

  @override
  String get bleServiceUuidLabel => 'UUID сэрвісу';

  @override
  String get bleWriteUuidLabel => 'UUID характарыстыкі запісу';

  @override
  String get bleNotifyUuidLabel => 'UUID характарыстыкі апавяшчэнняў';

  @override
  String get bleUuidInvalid => 'Увядзіце 16-бітны або 128-бітны UUID.';

  @override
  String get blePairingNote =>
      'Кліент павінен спалучыцца для зашыфраванага злучэння. Абменьвацца данымі можа адзін кліент за раз.';

  @override
  String get fromBle => 'З BLE';

  @override
  String get bleListeningDescription =>
      'Аб’ява актыўная, чаканне спалучанага BLE-кліента.';

  @override
  String get bleConnectedDescription =>
      'Спалучаны BLE-кліент падключаны да паслядоўнага порта.';

  @override
  String bridgeBleConflict(String owner) {
    return 'Адаптар Bluetooth ужо выкарыстоўвае $owner.';
  }

  @override
  String get clientRejectedUnpaired =>
      'Кліент адхілены: спачатку спалучыцеся з гэтай прыладай';

  @override
  String get bleBridgeSetupIntro =>
      'Выберыце паслядоўную прыладу і налады BLE.';

  @override
  String get androidBleBridgeSetupIntro =>
      'Выберыце паслядоўную USB-прыладу і налады BLE.';

  @override
  String get bleClientLabel => 'BLE-кліент';

  @override
  String get blePairingTitle => 'Патрабаваць спалучэнне';

  @override
  String get blePairingDescription =>
      'Кліенты спалучаюцца для зашыфраванага злучэння. Выключыце для кліентаў BLE UART, якія не спалучаюцца, напрыклад праграм для модуляў BT24 або HM-10.';

  @override
  String get bleOpenRisk =>
      'Без спалучэння да гэтай паслядоўнай прылады можа падключыцца любая прылада Bluetooth побач. Карыстайцеся гэтым толькі там, дзе давяраеце ўсім у радыусе дзеяння.';

  @override
  String get bleOpenNote => 'Абменьвацца данымі можа адзін кліент за раз.';

  @override
  String get bleStoppedDescription => 'Паслядоўны порт і BLE закрытыя.';

  @override
  String get bleOpenListeningDescription =>
      'Аб’ява актыўная, чаканне BLE-кліента.';

  @override
  String get bleOpenConnectedDescription =>
      'BLE-кліент падключаны да паслядоўнага порта.';

  @override
  String get hintBleClientLeft =>
      'BLE-кліент адключыўся. Запусціце зноў, каб чакаць наступнага кліента.';
}
