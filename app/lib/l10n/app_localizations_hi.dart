// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'RoadPack';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonClose => 'बंद करें';

  @override
  String get commonImOkay => 'मैं ठीक हूँ';

  @override
  String get commonOn => 'चालू';

  @override
  String get commonOff => 'बंद';

  @override
  String get commonSettings => 'सेटिंग्स';

  @override
  String get commonSelect => 'चुनें';

  @override
  String get commonName => 'नाम';

  @override
  String get commonNotSignedIn => 'साइन इन नहीं हैं';

  @override
  String commonError(String message) {
    return 'त्रुटि: $message';
  }

  @override
  String get commonCall112 => '112 पर कॉल करें';

  @override
  String get sosLabel => 'SOS';

  @override
  String get sosAlertTitle => 'SOS अलर्ट';

  @override
  String get sosHoldHint => 'SOS भेजने के लिए 2 सेकंड दबाए रखें';

  @override
  String get sosCountdownBody => 'आपके आपातकालीन संपर्कों को अलर्ट भेजा जाएगा';

  @override
  String get sosSentTitle => 'आपातकालीन अलर्ट भेजे गए';

  @override
  String get sosSentBody => 'आपके आपातकालीन संपर्कों को सूचित किया जा रहा है।';

  @override
  String get incidentResolvedTitle => 'घटना समाप्त';

  @override
  String get incidentResolvedBody =>
      'आपके संपर्कों को बता दिया गया है कि आप सुरक्षित हैं।';

  @override
  String incidentRef(String ref) {
    return 'घटना: $ref';
  }

  @override
  String get crashDetectedTitle => 'दुर्घटना का पता चला';

  @override
  String crashCountdownBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सेकंड में आपके आपातकालीन संपर्कों को अलर्ट भेजा जाएगा',
      one: '1 सेकंड में आपके आपातकालीन संपर्कों को अलर्ट भेजा जाएगा',
    );
    return '$_temp0';
  }

  @override
  String get crashAlertSentTitle => 'दुर्घटना अलर्ट भेजा गया';

  @override
  String get crashAlertSentBody =>
      'संभावित दुर्घटना की सूचना आपके आपातकालीन संपर्कों को दे दी गई है।';

  @override
  String get crashReasonQuestion => 'क्या हुआ?';

  @override
  String get crashReasonPothole => 'गड्ढा / स्पीड ब्रेकर';

  @override
  String get crashReasonPhoneDropped => 'फ़ोन गिर गया';

  @override
  String get crashReasonSuddenBraking => 'अचानक ब्रेक';

  @override
  String get crashReasonOther => 'अन्य';

  @override
  String get crashReasonOtherHint => 'क्या हुआ, बताएँ';

  @override
  String get crashReasonConfirm => 'पुष्टि करें — मैं ठीक हूँ';

  @override
  String get alertTitle => 'अलर्ट';

  @override
  String get alertNotFound => 'अलर्ट नहीं मिला';

  @override
  String get alertDetailTitle => 'आपातकालीन अलर्ट';

  @override
  String alertVictimHeadline(String name) {
    return '$name शायद किसी दुर्घटना में हैं';
  }

  @override
  String alertLocationLine(String lat, String lng) {
    return 'जगह: $lat, $lng';
  }

  @override
  String alertTimeLine(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.yMMMd(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'समय: $timeString';
  }

  @override
  String get alertAcknowledge => 'देख लिया';

  @override
  String get alertAcknowledged => 'देख लिया गया';

  @override
  String alertCallPerson(String name) {
    return '$name को कॉल करें';
  }

  @override
  String get alertOpenInMaps => 'मैप में खोलें';

  @override
  String alertCardTitle(String name) {
    return '$name — आपातकाल';
  }

  @override
  String get alertCardTapToView => 'देखने और पुष्टि के लिए टैप करें';

  @override
  String get homeSwitchToNight => 'रात मोड पर जाएँ';

  @override
  String get homeSwitchToSunlight => 'धूप मोड पर जाएँ';

  @override
  String get protectionEyebrow => 'सुरक्षा';

  @override
  String get checkCrashDetection => 'दुर्घटना\nपहचान';

  @override
  String get checkLocationTracking => 'लोकेशन\nट्रैकिंग';

  @override
  String get checkNonArrival => 'न पहुँचने पर\nअलर्ट';

  @override
  String get checkEmergencyContact => 'आपातकालीन\nसंपर्क';

  @override
  String checkSemantics(String label, String state) {
    return '$label: $state';
  }

  @override
  String get watchersHeading => 'कौन देख रहा है';

  @override
  String get watchersError =>
      'सर्कल लोड नहीं हो सके। दोबारा कोशिश के लिए नीचे खींचें।';

  @override
  String get watchersEmpty =>
      'अभी कोई नहीं। सर्कल वे लोग हैं जिन्हें तब कॉल जाता है जब आप ख़ुद कॉल नहीं कर सकते।';

  @override
  String get watchersCreateCircle => 'सर्कल बनाएँ';

  @override
  String circleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count  सर्कल',
      one: '$count  सर्कल',
    );
    return '$_temp0';
  }

  @override
  String circleCountWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'सर्कल',
      one: 'सर्कल',
    );
    return '$_temp0';
  }

  @override
  String get packEyebrow => 'साथ में सवारी';

  @override
  String get packTagline => 'सिर्फ़ एक बिंदु नहीं — सबको फ़ासला दिखता है';

  @override
  String get packStartRide => 'सवारी शुरू करें';

  @override
  String get packJoinRide => 'सवारी में शामिल हों';

  @override
  String get navLiveMap => 'लाइव मैप';

  @override
  String get navSafetyCircles => 'सुरक्षा सर्कल';

  @override
  String get navCommutes => 'रोज़ का सफ़र और न पहुँचना';

  @override
  String get navKnownRoutes => 'जाने-पहचाने रास्ते';

  @override
  String get navTripHistory => 'यात्रा इतिहास';

  @override
  String get milestoneCapArmed => 'सभी सिस्टम चालू';

  @override
  String get milestoneHeadlineArmed => 'सुरक्षा चालू';

  @override
  String get milestoneDetailArmed =>
      'दुर्घटना पहचान, ट्रैकिंग और न पहुँचने पर अलर्ट — तीनों चालू हैं। अगर आप गिरते हैं, तो आपके सर्कल को पता चल जाएगा।';

  @override
  String get milestoneCapPartial => 'सुरक्षा में कमी';

  @override
  String get milestoneHeadlinePartial => 'आंशिक सुरक्षा';

  @override
  String get milestoneDetailPartial =>
      'कुछ सिस्टम बंद हैं। सवारी से पहले बाक़ी चालू करें, वरना उनसे जुड़ी बात किसी को पता नहीं चलेगी।';

  @override
  String get milestoneCapOff => 'कुछ भी नहीं देख रहा';

  @override
  String get milestoneHeadlineOff => 'सुरक्षा बंद';

  @override
  String get milestoneDetailOff =>
      'न दुर्घटना पहचान, न ट्रैकिंग, न अलर्ट। अगली सवारी से पहले सेटिंग्स में सुरक्षा चालू करें।';

  @override
  String get milestoneCapIncident => 'घटना सक्रिय';

  @override
  String get milestoneHeadlineIncident => 'मदद बुलाई जा रही है';

  @override
  String get milestoneDetailIncident =>
      'आपके सर्कल को अभी अलर्ट भेजा जा रहा है।';

  @override
  String milestoneSemantics(String headline, String detail, int active) {
    return 'सुरक्षा $headline। $detail 3 में से $active सिस्टम चालू।';
  }

  @override
  String get milestoneSemanticsContactSet => 'आपातकालीन संपर्क सेट है।';

  @override
  String get milestoneSemanticsContactMissing => 'कोई आपातकालीन संपर्क नहीं।';

  @override
  String get gapNoContactHeadline => 'कॉल करने को कोई नहीं';

  @override
  String get gapNoContactDetail =>
      'आपका कोई आपातकालीन संपर्क नहीं है। दुर्घटना पहचान चल भी जाए तो अलर्ट किसी तक नहीं पहुँचेगा। एक संपर्क जोड़ें, बाक़ी सब काम करने लगेगा।';

  @override
  String get gapNoContactAction => 'संपर्क जोड़ें';

  @override
  String get gapCrashOffHeadline => 'दुर्घटना पहचान बंद है';

  @override
  String get gapCrashOffDetail =>
      'टक्कर सुनने वाला कुछ भी चालू नहीं है। अगर आप गिरें और फ़ोन तक न पहुँच पाएँ, तो किसी को पता नहीं चलेगा।';

  @override
  String get gapTurnOnAction => 'चालू करें';

  @override
  String get gapTrackingOffHeadline => 'लोकेशन ट्रैकिंग बंद है';

  @override
  String get gapTrackingOffDetail =>
      'आपके सर्कल को अलर्ट तो जाएगा, पर यह नहीं कि आप कहाँ हैं। ढूँढना पड़े तो मदद देर से पहुँचती है।';

  @override
  String get gapNonArrivalOffHeadline => 'न पहुँचने पर अलर्ट बंद है';

  @override
  String get gapNonArrivalOffDetail =>
      'अगर आप मंज़िल तक न पहुँचें, तो कोई इसे नहीं उठाएगा। यह कमी भरने के लिए एक रोज़ का रास्ता सेट करें।';

  @override
  String get gapSetUpCommutesAction => 'रोज़ का सफ़र सेट करें';

  @override
  String get settingsSectionSafety => 'सुरक्षा';

  @override
  String get settingsCrashSensitivity => 'दुर्घटना संवेदनशीलता';

  @override
  String get settingsSensitivityHigh => 'उच्च';

  @override
  String get settingsSensitivityMedium => 'मध्यम';

  @override
  String get settingsSensitivityLow => 'कम';

  @override
  String get settingsSensitivityHighDetail =>
      'उच्च — ज़्यादा संवेदनशील, ग़लत अलर्ट ज़्यादा हो सकते हैं';

  @override
  String get settingsSensitivityMediumDetail => 'मध्यम — संतुलित (सुझाया गया)';

  @override
  String get settingsSensitivityLowDetail => 'कम — कम संवेदनशील, ग़लत अलर्ट कम';

  @override
  String get settingsPhoneMount => 'फ़ोन माउंट';

  @override
  String get settingsMountBar => 'हैंडलबार';

  @override
  String get settingsMountPocket => 'जेब';

  @override
  String get settingsMountBag => 'बैग';

  @override
  String get settingsMountOther => 'अन्य';

  @override
  String get settingsMountBarDetail => 'हैंडलबार माउंट (सबसे संवेदनशील)';

  @override
  String get settingsMountPocketDetail => 'जेब में';

  @override
  String get settingsMountBagDetail => 'बैग में (सबसे कम संवेदनशील)';

  @override
  String get settingsMountUnknownDetail => 'अन्य / अज्ञात';

  @override
  String get settingsSectionTracking => 'ट्रैकिंग';

  @override
  String get settingsNonArrivalAlerts => 'न पहुँचने पर अलर्ट';

  @override
  String get settingsNonArrivalAlertsSub =>
      'अगर आप न पहुँचें तो संपर्कों को अलर्ट भेजें';

  @override
  String get settingsAlertDelay => 'अलर्ट में देरी';

  @override
  String settingsAlertDelaySub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'अनुमानित पहुँचने के $count मिनट बाद',
      one: 'अनुमानित पहुँचने के 1 मिनट बाद',
    );
    return '$_temp0';
  }

  @override
  String minutesShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मिनट',
      one: '1 मिनट',
    );
    return '$_temp0';
  }

  @override
  String get settingsCommuteRoutes => 'रोज़ के रास्ते';

  @override
  String get settingsCommuteRoutesSub =>
      'वे रास्ते जिन पर न पहुँचने पर अलर्ट जाता है';

  @override
  String get settingsSectionEmergency => 'आपातकाल';

  @override
  String get settingsEmergencyContacts => 'आपातकालीन संपर्क';

  @override
  String get settingsEmergencyContactsReady =>
      'जब आप कॉल नहीं कर सकते, तब किसे कॉल जाएगा';

  @override
  String get settingsEmergencyContactsEmpty =>
      'अभी कोई नहीं — अलर्ट किसी तक नहीं पहुँचेगा';

  @override
  String get settingsIceCard => 'ICE कार्ड';

  @override
  String get settingsIceCardSub => 'घटनास्थल पर पहुँचने वाले को क्या दिखेगा';

  @override
  String get settingsBystanderPreview => 'देखें कि राहगीर को क्या दिखता है';

  @override
  String get settingsBystanderPreviewSub =>
      'ज़रूरत पड़ने से पहले अपनी दुर्घटना स्क्रीन जाँच लें';

  @override
  String get settingsIceCommuteToggle => 'रोज़ के सफ़र में ICE कार्ड दिखाएँ';

  @override
  String get settingsIceCommuteToggleSub =>
      'डिफ़ॉल्ट रूप से बंद। चालू करने पर, ट्रैक किए जा रहे सफ़र के दौरान भी — सिर्फ़ दुर्घटना के बाद नहीं — घटनास्थल पर मदद करने वाला आपका ब्लड ग्रुप और संपर्क देख सकता है।';

  @override
  String get settingsSectionMaps => 'मैप';

  @override
  String get settingsOfflineMaps => 'ऑफ़लाइन मैप';

  @override
  String get settingsOfflineMapsSub =>
      'नेटवर्क-रहित इलाक़ों के लिए क्षेत्र डाउनलोड करें';

  @override
  String get settingsSectionEmergencyProfile => 'आपातकालीन प्रोफ़ाइल';

  @override
  String get settingsBloodGroup => 'ब्लड ग्रुप';

  @override
  String get settingsMedicalNotes => 'मेडिकल जानकारी';

  @override
  String get settingsMedicalNotesHint => 'एलर्जी, बीमारियाँ, दवाइयाँ...';

  @override
  String get settingsSectionAccount => 'खाता';

  @override
  String get settingsVehicle => 'वाहन';

  @override
  String get settingsSignOut => 'साइन आउट';

  @override
  String get settingsSectionLanguage => 'भाषा';

  @override
  String get settingsLanguageSub => 'आपातकालीन स्क्रीन भी इसी भाषा में दिखेंगी';

  @override
  String get languageSystemDefault => 'फ़ोन के अनुसार';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get languageMalayalam => 'മലയാളം';

  @override
  String get circlesJoinCircleTitle => 'सर्कल में शामिल हों';

  @override
  String get circlesCreateCircle => 'सर्कल बनाएँ';

  @override
  String get circlesLoadError => 'कुछ गड़बड़ हो गई';

  @override
  String get circlesRetry => 'फिर कोशिश करें';

  @override
  String get circlesEmptyTitle => 'अपना पहला सुरक्षा सर्कल बनाएँ';

  @override
  String get circlesEmptyBody =>
      'आपके सर्कल यह सुनिश्चित करते हैं कि सड़क पर कुछ होने पर सही लोगों को अलर्ट मिले';

  @override
  String get circlesRegenerateCode => 'नया इनवाइट कोड बनाएँ';

  @override
  String get circlesDeleteCircle => 'सर्कल हटाएँ';

  @override
  String circlesMembersHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'सदस्य ($count)',
      one: 'सदस्य (1)',
    );
    return '$_temp0';
  }

  @override
  String circlesObserversHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ऑब्ज़र्वर ($count)',
      one: 'ऑब्ज़र्वर (1)',
    );
    return '$_temp0';
  }

  @override
  String get circlesObserverSmsTag => 'SMS';

  @override
  String get circlesAddObserverAction => 'ऑब्ज़र्वर जोड़ें';

  @override
  String get circlesObserverSmsExplainer =>
      'ऑब्ज़र्वर को SMS अलर्ट मिलते हैं, उन्हें ऐप की ज़रूरत नहीं है।';

  @override
  String get circlesPhoneNumberLabel => 'फ़ोन नंबर';

  @override
  String get circlesAddAction => 'जोड़ें';

  @override
  String get circlesLeaveDialogTitle => 'सर्कल छोड़ें?';

  @override
  String get circlesLeaveFamilyWarning =>
      'छोड़ने पर इस सर्कल से जुड़े सभी आपातकालीन संपर्क हटा दिए जाएँगे।';

  @override
  String get circlesLeaveConfirm => 'क्या आप वाकई छोड़ना चाहते हैं?';

  @override
  String get circlesLeaveAction => 'छोड़ें';

  @override
  String circlesLeaveError(String message) {
    return 'छोड़ा नहीं जा सका: $message';
  }

  @override
  String get circlesDeleteDialogTitle => 'सर्कल हटाएँ?';

  @override
  String get circlesDeleteWarning => 'यह पूर्ववत नहीं किया जा सकता।';

  @override
  String get circlesDeleteAction => 'हटाएँ';

  @override
  String circlesNewCodeSnackbar(String code) {
    return 'नया कोड: $code';
  }

  @override
  String get circlesRoleUpdateError =>
      'भूमिका अपडेट नहीं हो सकी। कृपया फिर कोशिश करें।';

  @override
  String get circlesRemoveMemberError =>
      'सदस्य हटाया नहीं जा सका। कृपया फिर कोशिश करें।';

  @override
  String get circlesRemoveObserverError =>
      'ऑब्ज़र्वर हटाया नहीं जा सका। कृपया फिर कोशिश करें।';

  @override
  String get circlesEcUpdateError =>
      'आपातकालीन संपर्क अपडेट नहीं हो सका। कृपया फिर कोशिश करें।';

  @override
  String circlesShareInviteMessage(String code) {
    return 'RoadPack पर मेरे सुरक्षा सर्कल में शामिल हों! कोड: $code';
  }

  @override
  String get circlesNameLabel => 'सर्कल का नाम';

  @override
  String circlesDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count घंटे',
      one: '1 घंटा',
    );
    return '$_temp0';
  }

  @override
  String get circlesDurationLabel => 'अवधि';

  @override
  String get circlesCreateAction => 'बनाएँ';

  @override
  String get circlesLocationSharingTitle => 'इस सर्कल को लाइव लोकेशन देखने दें';

  @override
  String get circlesLocationSharingOnDetail =>
      'इस सर्कल में सभी को पता चलेगा कि हर सदस्य कहाँ है। आप इसे बाद में बंद कर सकते हैं।';

  @override
  String get circlesLocationSharingOffDetail =>
      'बंद है। दुर्घटना होने पर सदस्यों को अभी भी अलर्ट मिलेगा — बस वे बाक़ी समय एक-दूसरे को नहीं देख सकते।';

  @override
  String get circlesInvalidCodeError => 'अमान्य कोड';

  @override
  String get circlesEnterCodeHeading => 'इनवाइट कोड डालें';

  @override
  String circlesMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सदस्य',
      one: '1 सदस्य',
    );
    return '$_temp0';
  }

  @override
  String get circlesJoinAction => 'शामिल हों';

  @override
  String get circlesWhoCanSeeMeTitle => 'मुझे कौन देख सकता है';

  @override
  String get circlesChangeFailedMessage =>
      'वह बदला नहीं जा सका। कुछ भी नहीं बदला।';

  @override
  String circlesWatcherCountHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लोग आपकी लोकेशन देख सकते हैं',
      one: '1 व्यक्ति आपकी लोकेशन देख सकता है',
      zero: 'कोई भी आपकी लोकेशन नहीं देख सकता',
    );
    return '$_temp0';
  }

  @override
  String get circlesFullListNotice =>
      'यह पूरी सूची है। RoadPack में कोई छुपा हुआ मोड नहीं है — जो भी आपको देख सकता है, वह इस पेज पर है।';

  @override
  String get circlesNoCirclesYet =>
      'आप अभी किसी सर्कल में नहीं हैं, इसलिए आपको देखने वाला कोई नहीं है।';

  @override
  String get circlesLoadWhoCanSeeError =>
      'हम यह लोड नहीं कर सके कि आपको कौन देख सकता है';

  @override
  String get circlesLoadWhoCanSeeErrorDetail =>
      'यह न समझें कि इसका मतलब कोई नहीं देख सकता। सिग्नल मिलने पर फिर कोशिश करें।';

  @override
  String get circlesTryAgainAction => 'फिर कोशिश करें';

  @override
  String circlesCardSubtitle(String type, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$type — $count सदस्य',
      one: '$type — 1 सदस्य',
    );
    return '$_temp0';
  }

  @override
  String get circlesExpiredTag => 'समाप्त';

  @override
  String get circlesTypeFamily => 'परिवार';

  @override
  String get circlesTypeFriends => 'दोस्त';

  @override
  String get circlesTypeCommute => 'रोज़ के सफ़र वाला ग्रुप';

  @override
  String get circlesTypeConvoy => 'काफ़िला';

  @override
  String get circlesTypeFamilyDefaultName => 'मेरा परिवार';

  @override
  String get circlesTypeFriendsDefaultName => 'दोस्त';

  @override
  String get circlesTypeCommuteDefaultName => 'रोज़ के सफ़र वाला ग्रुप';

  @override
  String get circlesTypeConvoyDefaultName => 'काफ़िला';

  @override
  String get circlesTypeFamilyDescription =>
      'आपके सबसे क़रीबी लोग। सदस्य अपने आप आपातकालीन संपर्क बन जाते हैं।';

  @override
  String get circlesTypeFriendsDescription =>
      'साथ सवारी या सफ़र करने वाले दोस्त। ख़ास सदस्यों को आपातकालीन संपर्क के रूप में जोड़ें।';

  @override
  String get circlesTypeCommuteDescription => 'नियमित सफ़र वाला ग्रुप।';

  @override
  String get circlesTypeConvoyDescription =>
      'अस्थायी ग्रुप सवारी। एक अवधि सेट करें।';

  @override
  String get circlesRoleAdmin => 'एडमिन';

  @override
  String get circlesRoleMember => 'सदस्य';

  @override
  String get circlesRoleObserver => 'ऑब्ज़र्वर';

  @override
  String get circlesUnknownMember => 'अज्ञात';

  @override
  String get circlesYouTag => '(आप)';

  @override
  String get circlesMenuLeaveCircle => 'सर्कल छोड़ें';

  @override
  String get circlesMenuDemote => 'सदस्य में डिमोट करें';

  @override
  String get circlesMenuPromote => 'एडमिन में प्रोमोट करें';

  @override
  String get circlesMenuRemove => 'हटाएँ';

  @override
  String get circlesMenuMarkEc => 'आपातकालीन संपर्क के रूप में चिह्नित करें';

  @override
  String get circlesMenuRemoveEc => 'आपातकालीन संपर्क से हटाएँ';

  @override
  String get circlesMonthlyCheckTitle => 'मासिक जाँच: आपको कौन देख सकता है?';

  @override
  String circlesWatcherCountBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'अभी $count लोग आपकी लोकेशन देख सकते हैं।',
      one: 'अभी 1 व्यक्ति आपकी लोकेशन देख सकता है।',
      zero:
          'अभी कोई भी आपकी लोकेशन नहीं देख सकता। फिर भी एक नज़र डाल लें — सर्कल बदलते रहते हैं।',
    );
    return '$_temp0';
  }

  @override
  String get circlesReviewListAction => 'सूची देखें';

  @override
  String get circlesNotNowAction => 'अभी नहीं';

  @override
  String get circlesSharingOnEmptyDetail =>
      'लोकेशन शेयरिंग चालू है, लेकिन इस सर्कल में अभी कोई और नहीं है।';

  @override
  String circlesWatchersHereDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'यहाँ $count लोग देख सकते हैं कि आप कहाँ हैं।',
      one: 'यहाँ 1 व्यक्ति देख सकता है कि आप कहाँ हैं।',
    );
    return '$_temp0';
  }

  @override
  String get circlesSharingOffDetail =>
      'इस सर्कल में कोई भी नहीं देख सकता कि आप कहाँ हैं।';

  @override
  String circlesWatcherRow(String name, String role) {
    return '$name — $role';
  }

  @override
  String get circlesShareMyLocationTitle =>
      'इस सर्कल के साथ अपनी लोकेशन शेयर करें';

  @override
  String get circlesSelfSharingOnDetail =>
      'इसे बंद करने पर आपकी लाइव लोकेशन इस सर्कल से छुप जाएगी। आप फिर भी सदस्य रहेंगे, और दुर्घटना होने पर उन्हें आपकी लोकेशन के साथ अभी भी अलर्ट मिलेगा।';

  @override
  String get circlesSelfSharingOffDetail =>
      'आपकी लाइव लोकेशन इस सर्कल से छुपी है। आप अभी भी सदस्य हैं, आपको अभी भी उनके अलर्ट मिलते हैं, और दुर्घटना होने पर उन्हें अभी भी बताया जाएगा कि आप कहाँ हैं।';

  @override
  String get circlesAdminOnlyOptOutNotice =>
      'सिर्फ़ इस सर्कल का एडमिन पूरे सर्कल की सेटिंग बदल सकता है, लेकिन ऊपर का स्विच आपकी अपनी लोकेशन शेयर होना रोक देता है। आप सर्कल छोड़ भी सकते हैं।';

  @override
  String get circlesAdminOnlyNoOptOutNotice =>
      'सिर्फ़ इस सर्कल का एडमिन इसकी शेयरिंग सेटिंग बदल सकता है। अगर आप सहज नहीं हैं, तो आप सर्कल छोड़ सकते हैं — यह तुरंत असर करता है, और RoadPack आपको कभी नहीं रोकेगा।';

  @override
  String get circlesLeaveThisCircleAction => 'यह सर्कल छोड़ें';

  @override
  String get circlesInviteCodeLabel => 'इनवाइट कोड';

  @override
  String get circlesCodeCopiedSnackbar => 'कोड कॉपी हो गया';

  @override
  String get circlesCopyAction => 'कॉपी करें';

  @override
  String get circlesShareAction => 'शेयर करें';

  @override
  String get commuteTitle => 'रोज़ का सफ़र';

  @override
  String get commuteAddRoute => 'रास्ता जोड़ें';

  @override
  String get commuteEditRoute => 'रास्ता संपादित करें';

  @override
  String get commuteLoadError => 'आपके रास्ते लोड नहीं हो सके';

  @override
  String get commuteYourRoutesHeading => 'आपके रास्ते';

  @override
  String get commuteNonArrivalTitle => 'न पहुँचने पर अलर्ट';

  @override
  String commuteNonArrivalEnabledBody(String late) {
    return 'अगर आप $late तक नहीं पहुँचे, तो RoadPack पहले आपसे पूछेगा। जवाब न देने पर ही आपके सर्कल को बताया जाएगा।';
  }

  @override
  String get commuteNonArrivalDisabledBody =>
      'अगर आप न पहुँचें, तो किसी को नहीं बताया जाएगा।';

  @override
  String get commuteAskMeAfterHeading => 'कितनी देर बाद पूछें';

  @override
  String commuteGraceWindowSemantics(String late) {
    return 'देर से $late';
  }

  @override
  String commuteSpokenMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मिनट',
      one: '1 मिनट',
    );
    return '$_temp0';
  }

  @override
  String commuteSpokenSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सेकंड',
      one: '1 सेकंड',
    );
    return '$_temp0';
  }

  @override
  String get commuteEmptyTitle => 'अभी कोई रास्ता नहीं';

  @override
  String commuteEmptyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'RoadPack $count जैसी यात्राओं के बाद रोज़ का सफ़र सीख लेता है। इंतज़ार नहीं करना है तो ख़ुद जोड़ें — यह तुरंत काम करने लगता है।',
      one:
          'RoadPack 1 जैसी यात्रा के बाद रोज़ का सफ़र सीख लेता है। इंतज़ार नहीं करना है तो ख़ुद जोड़ें — यह तुरंत काम करने लगता है।',
    );
    return '$_temp0';
  }

  @override
  String get commuteDeleteRouteTooltip => 'रास्ता हटाएँ';

  @override
  String get commuteNameHint => 'घर से कॉलेज';

  @override
  String get commuteNameValidation => 'ऐसा नाम दें जिसे आप पहचान सकें';

  @override
  String get commuteSectionWhere => 'कहाँ';

  @override
  String get commuteSectionWhen => 'कब';

  @override
  String get commuteSectionDays => 'दिन';

  @override
  String get commuteStartPoint => 'शुरुआत';

  @override
  String get commuteDestinationPoint => 'मंज़िल';

  @override
  String get commuteLocationPermissionError =>
      'इस जगह को सेट करने के लिए RoadPack को लोकेशन अनुमति चाहिए।';

  @override
  String get commuteLocationFixError =>
      'यहाँ लोकेशन नहीं मिली। बाहर जाकर दोबारा कोशिश करें।';

  @override
  String get commuteIncompleteError =>
      'दोनों जगह, शुरू होने का समय और कम से कम एक दिन सेट करें।';

  @override
  String get commuteDurationLabel => 'सामान्यतः लगते हैं (मिनट)';

  @override
  String get commuteDurationEmptyValidation =>
      'यह सफ़र सामान्यतः कितनी देर का होता है?';

  @override
  String get commuteDurationTooLongValidation =>
      'यह एक दिन की यात्रा से भी ज़्यादा लंबा है';

  @override
  String get commuteSaveChanges => 'बदलाव सेव करें';

  @override
  String get commuteRouteIncompleteHint =>
      'रास्ते को आपके लिए देखना शुरू करने के लिए दोनों जगह, शुरू होने का समय और कम से कम एक दिन ज़रूरी है।';

  @override
  String get commuteUsuallyLeavesAt => 'सामान्यतः निकलने का समय';

  @override
  String get commutePointNotSet => 'सेट नहीं';

  @override
  String get commuteUpdatePoint => 'बदलें';

  @override
  String get commuteUseHerePoint => 'यहाँ इस्तेमाल करें';

  @override
  String get commuteDeleteRouteTitle => 'यह रास्ता हटाएँ?';

  @override
  String get commuteDeleteRouteBody =>
      'RoadPack इस पर न पहुँचने की जाँच बंद कर देगा।';

  @override
  String get commuteKeepAction => 'रखें';

  @override
  String get commuteDeleteAction => 'हटाएँ';

  @override
  String get commuteDayNameMonday => 'सोमवार';

  @override
  String get commuteDayNameTuesday => 'मंगलवार';

  @override
  String get commuteDayNameWednesday => 'बुधवार';

  @override
  String get commuteDayNameThursday => 'गुरुवार';

  @override
  String get commuteDayNameFriday => 'शुक्रवार';

  @override
  String get commuteDayNameSaturday => 'शनिवार';

  @override
  String get commuteDayNameSunday => 'रविवार';

  @override
  String get commuteDayLetterMon => 'सो';

  @override
  String get commuteDayLetterTue => 'मं';

  @override
  String get commuteDayLetterWed => 'बु';

  @override
  String get commuteDayLetterThu => 'गु';

  @override
  String get commuteDayLetterFri => 'शु';

  @override
  String get commuteDayLetterSat => 'श';

  @override
  String get commuteDayLetterSun => 'र';

  @override
  String commuteDaysActiveSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'हफ़्ते में $count दिन चालू',
      one: 'हफ़्ते में 1 दिन चालू',
      zero: 'कोई दिन सेट नहीं',
    );
    return '$_temp0';
  }

  @override
  String get commuteTimeToAnswerHeading => 'जवाब देने का समय';

  @override
  String commuteAnswerSemantics(String spoken) {
    return '$spoken बाद आपके सर्कल को बताया जाएगा।';
  }

  @override
  String get commuteNothingToCheckIn => 'चेक-इन करने के लिए कुछ नहीं है।';

  @override
  String get commuteCheckingInHeading => 'चेक-इन हो रहा है';

  @override
  String get commuteCircleToldHeading => 'आपके सर्कल को बता दिया गया';

  @override
  String get commuteEverythingOkay => 'सब ठीक है?';

  @override
  String get commuteWeLetThemKnow => 'हमने उन्हें बता दिया';

  @override
  String get commuteTravellingBody =>
      'आप अपनी सामान्य मंज़िल तक नहीं पहुँचे हैं। अभी तक किसी को नहीं बताया गया है।';

  @override
  String get commuteEscalatedBody =>
      'आपने जवाब नहीं दिया, इसलिए आपके सर्कल को अलर्ट भेजा गया। जब हो सके, उन्हें बता दें कि आप ठीक हैं।';

  @override
  String get commuteAnswerCaption =>
      'अगर आप जवाब नहीं देते, तो आपके सर्कल को बताया जाएगा।';

  @override
  String commuteSnoozeExtendedMessage(String minutes) {
    return '$minutes के लिए समय बढ़ा दिया गया। किसी को नहीं बताया गया।';
  }

  @override
  String get commuteGladYouMadeIt => 'अच्छा हुआ आप पहुँच गए।';

  @override
  String get commuteFineTellThem => 'मैं ठीक हूँ — उन्हें बताएँ';

  @override
  String get commuteArrivedFine => 'मैं पहुँच गया, ठीक हूँ';

  @override
  String get commuteNeedHelp => 'मुझे मदद चाहिए';

  @override
  String get commuteAddedByYouBadge => 'आपने जोड़ा';

  @override
  String commuteTripsBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count यात्राएँ',
      one: '$count यात्रा',
    );
    return '$_temp0';
  }

  @override
  String get commuteLeavesLabel => 'निकलना';

  @override
  String get commuteTakesLabel => 'लगता है';

  @override
  String get commuteArrivesLabel => 'पहुँचना';

  @override
  String commuteLearningNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'अभी सीख रहा है — इस रास्ते पर नज़र रखने से पहले $count और यात्राएँ चाहिए।',
      one: 'अभी सीख रहा है — इस रास्ते पर नज़र रखने से पहले 1 और यात्रा चाहिए।',
    );
    return '$_temp0';
  }

  @override
  String get commuteNotWatchingTitle => 'यह रास्ता नहीं देखा जा रहा';

  @override
  String get commuteWatchingOnceLearnedTitle => 'सीखने के बाद देखा जाएगा';

  @override
  String commuteNeedsMoreTripsDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count और यात्राएँ चाहिए',
      one: '1 और यात्रा चाहिए',
    );
    return '$_temp0';
  }

  @override
  String get commuteNotWatchingYetTitle => 'अभी नहीं देखा जा रहा';

  @override
  String get commuteMissingScheduleDetail =>
      'शुरू होने का समय, अवधि या दिन सेट नहीं है';

  @override
  String get commuteWatchingTitle => 'न पहुँचने के लिए देखा जा रहा है';

  @override
  String get commuteRunningLateLabel => 'देर हो रही है';

  @override
  String get commuteMuchLaterLabel => 'बहुत देर';

  @override
  String commuteSnoozeTrailing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count मिनट',
      one: '+1 मिनट',
    );
    return '$_temp0';
  }

  @override
  String get commuteNobodyToldCaption =>
      'इसे दबाने पर किसी को नहीं बताया जाता।';

  @override
  String commuteSnoozeSemantics(String label, String trailing) {
    return '$label, $trailing। किसी को सूचित नहीं किया जाता।';
  }

  @override
  String get consentCentreTitle => 'मैंने किन बातों पर हाँ कहा';

  @override
  String get consentPermissionsHeading => 'आपकी अनुमतियाँ';

  @override
  String get consentPermissionsIntro =>
      'इनमें से कोई भी कभी भी बंद कर सकते हैं। लोकेशन शेयरिंग बंद करते ही RoadPack आपको ट्रैक करना तुरंत रोक देता है।';

  @override
  String consentGrantedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'd MMMM yyyy',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return 'आपने $dateString को हाँ कहा था';
  }

  @override
  String get consentParentalSectionBody =>
      'किसी माता-पिता या अभिभावक ने RoadPack को आपको ट्रैक करने की अनुमति दी है। वे, या आप, इसे कभी भी वापस ले सकते हैं — RoadPack तुरंत ट्रैक करना बंद कर देता है।';

  @override
  String get consentWithdrawParentalAction => 'माता-पिता की अनुमति वापस लें';

  @override
  String get consentUnknownLedgerTitle => 'हम आपकी अनुमतियाँ जाँच नहीं सके';

  @override
  String get consentUnknownLedgerBody =>
      'जब तक सर्वर से संपर्क नहीं होता, RoadPack यह मानता है कि आपने किसी बात पर हाँ नहीं कहा और आपको ट्रैक नहीं करेगा।';

  @override
  String get consentChecking => 'जाँच हो रही है...';

  @override
  String get consentTryAgain => 'फिर कोशिश करें';

  @override
  String get consentTypeTrackingTitle => 'सवारी के दौरान मेरी लोकेशन शेयर करें';

  @override
  String get consentTypeTrackingMeaning =>
      'सवारी चालू रहने तक RoadPack यह दर्ज करता है कि आप कहाँ हैं, ताकि दुर्घटना होने पर आपका सर्कल आपको ढूँढ सके।';

  @override
  String get consentTypeDataSharingAnonTitle =>
      'सड़क सुरक्षा मैप बेहतर बनाने में मदद करें';

  @override
  String get consentTypeDataSharingAnonMeaning =>
      'मोटे तौर पर, बिना नाम के लोकेशन बिंदु ख़तरनाक हिस्सों का नक़्शा बनाने में मदद करते हैं। इस तरह भेजी गई किसी भी जानकारी में आपका नाम या नंबर नहीं होता।';

  @override
  String get consentTypeSensorUploadTitle => 'दुर्घटना के बाद सेंसर डेटा भेजें';

  @override
  String get consentTypeSensorUploadMeaning =>
      'दुर्घटना के बाद फ़ोन अपने सेंसर की रीडिंग भेजता है, ताकि पहचान बेहतर हो।';

  @override
  String get consentTypeParentalTitle => 'माता-पिता या अभिभावक की अनुमति';

  @override
  String get consentTypeParentalMeaning =>
      'चूँकि आपकी उम्र 18 से कम है, RoadPack आपको ट्रैक कर सके इससे पहले माता-पिता या अभिभावक का हाँ कहना ज़रूरी है।';

  @override
  String get consentTypeInstitutionalTitle =>
      'अपने कॉलेज या नियोक्ता के साथ शेयर करें';

  @override
  String get consentTypeInstitutionalMeaning =>
      'आपका कॉलेज या नियोक्ता सिर्फ़ समूह के कुल आँकड़े देखता है — कभी आपकी लाइव जगह नहीं और कभी आपके संपर्क नहीं।';

  @override
  String get consentTypeAudioCaptureTitle =>
      'दुर्घटना के बाद ऑडियो रिकॉर्ड करें';

  @override
  String get consentTypeAudioCaptureMeaning =>
      'दुर्घटना के बाद फ़ोन एक छोटी क्लिप रिकॉर्ड कर सकता है, ताकि मदद करने वालों को पता हो कि वे किस हालात में आ रहे हैं।';

  @override
  String get consentGateReadyTitle => 'RoadPack आपका ध्यान रख सकता है';

  @override
  String get consentGateReadyBody =>
      'आपकी प्रोफ़ाइल पूरी है और आपने लोकेशन शेयरिंग के लिए हाँ कहा है। फिर भी RoadPack 112 पर कॉल करने की जगह नहीं लेता।';

  @override
  String get consentGateBlockedTitle => 'RoadPack अभी आपको ट्रैक नहीं कर रहा';

  @override
  String get consentGateBlockedBody => 'इन्हें पूरा करें, फिर यह करेगा:';

  @override
  String get consentGateAskParentAction => 'माता-पिता या अभिभावक से पूछें';

  @override
  String get consentBlockerNameTitle => 'अपना नाम जोड़ें';

  @override
  String get consentBlockerNameBody =>
      'जिसे भी हम कॉल करें, उसे पता होना चाहिए कि कॉल किसके बारे में है।';

  @override
  String get consentBlockerPhoneTitle => 'अपना फ़ोन नंबर जोड़ें';

  @override
  String get consentBlockerPhoneBody =>
      'हमें एक चालू नंबर चाहिए, ताकि मदद आपको वापस कॉल कर सके।';

  @override
  String get consentBlockerContactTitle => 'एक आपातकालीन संपर्क जोड़ें';

  @override
  String get consentBlockerContactBody =>
      'RoadPack के पास अलर्ट भेजने को कोई नहीं है। कम से कम एक संपर्क ज़रूरी है।';

  @override
  String get consentBlockerDobTitle => 'अपनी जन्म तिथि जोड़ें';

  @override
  String get consentBlockerDobBody =>
      'क़ानून 18 से कम उम्र के सवारों के साथ अलग व्यवहार करता है, इसलिए हमें जानना होगा कि आप पर कौन-से नियम लागू होते हैं।';

  @override
  String get consentBlockerParentalTitle =>
      'माता-पिता या अभिभावक की अनुमति चाहिए';

  @override
  String get consentBlockerParentalBody =>
      'आपकी उम्र 18 से कम है। RoadPack आपकी जगह दर्ज करे, इससे पहले माता-पिता या अभिभावक का सहमत होना ज़रूरी है।';

  @override
  String get consentBlockerTrackingTitle => 'लोकेशन शेयरिंग चालू करें';

  @override
  String get consentBlockerTrackingBody =>
      'जब तक आप हाँ नहीं कहते, RoadPack आपकी लोकेशन दर्ज नहीं करता, और जैसे ही आप ना कहते हैं, रुक जाता है।';

  @override
  String get consentBlockerUnknownBody =>
      'आपने किन बातों पर हाँ कहा है, यह जाँचने के लिए हम सर्वर तक नहीं पहुँच सके। जब तक नहीं पहुँचते, RoadPack आपको ट्रैक नहीं करेगा।';

  @override
  String get consentParentalScreenTitle => 'माता-पिता या अभिभावक की अनुमति';

  @override
  String get consentParentalFormIntro =>
      'आपकी उम्र 18 से कम है, इसलिए RoadPack आपकी जगह दर्ज करे इससे पहले माता-पिता या अभिभावक का सहमत होना ज़रूरी है। तब तक कुछ भी ट्रैक नहीं होता।';

  @override
  String get consentParentalNameLabel => 'माता-पिता या अभिभावक का नाम';

  @override
  String get consentParentalPhoneLabel => 'उनका फ़ोन नंबर';

  @override
  String get consentParentalRelationLabel => 'आपसे उनका रिश्ता';

  @override
  String get consentParentalRelationHint => 'माता, पिता, अभिभावक';

  @override
  String consentParentalMethodLine(String method) {
    return 'हम उन्हें कैसे पक्का करते हैं: $method';
  }

  @override
  String get consentParentalSubmitAction => 'उनसे पुष्टि करने को कहें';

  @override
  String get consentVerifierNotAvailable =>
      'अभी उपलब्ध नहीं। जब तक माता-पिता या अभिभावक की ठीक से पुष्टि नहीं हो जाती, RoadPack 18 से कम उम्र के सवारों को ट्रैक नहीं करेगा।';

  @override
  String get consentParentalConfirmed =>
      'माता-पिता या अभिभावक की पुष्टि हो गई।';

  @override
  String get consentParentalNotConfigured =>
      'RoadPack अभी माता-पिता या अभिभावक की पुष्टि नहीं कर सकता, इसलिए यह 18 से कम उम्र के सवारों को ट्रैक नहीं करेगा। बाक़ी सब काम करता रहेगा।';

  @override
  String get consentParentalIncomplete =>
      'कृपया अपने माता-पिता या अभिभावक का नाम, नंबर और आपसे उनका रिश्ता भरें।';

  @override
  String get consentParentalVerificationFailed =>
      'हम उस नंबर की पुष्टि नहीं कर सके। कृपया फिर कोशिश करें।';

  @override
  String get consentParentalUnavailable =>
      'हम सर्वर तक नहीं पहुँच सके। जब तक नहीं पहुँचते, RoadPack 18 से कम उम्र के सवारों को ट्रैक नहीं करेगा।';

  @override
  String get consentTrackingNotPermitted =>
      'RoadPack अभी ट्रैक करना शुरू नहीं कर सकता';

  @override
  String consentWatcherReason(String type, String circleName) {
    return 'आपके $type सर्कल \"$circleName\" में, और उस सर्कल की लोकेशन शेयरिंग चालू है।';
  }

  @override
  String get contactsAddButton => 'संपर्क जोड़ें';

  @override
  String get contactsLoadError => 'आपके संपर्क लोड नहीं हो सके';

  @override
  String get contactsRetry => 'फिर कोशिश करें';

  @override
  String get contactsEmptyHint =>
      'ट्रैकिंग शुरू होने से पहले कम से कम एक संपर्क जोड़ें।';

  @override
  String get contactsOrderHint =>
      'हम उन्हें इस क्रम में कॉल करते हैं। क्रम बदलने के लिए खींचें।';

  @override
  String contactsCountOfMax(int count, int max) {
    return '$max में से $count सूचीबद्ध';
  }

  @override
  String get contactsEmptyBody =>
      'अभी कोई सूचीबद्ध नहीं है।\nजिस अलर्ट को भेजने के लिए कोई न हो, वह सुरक्षा नहीं है।';

  @override
  String contactsRemoveConfirmTitle(String name) {
    return '$name को हटाएँ?';
  }

  @override
  String get contactsRemoveConfirmBody =>
      'अब आपके साथ कुछ होने पर उन्हें अलर्ट नहीं भेजा जाएगा।';

  @override
  String get contactsCancel => 'रद्द करें';

  @override
  String get contactsRemoveButton => 'हटाएँ';

  @override
  String get contactsEditTitle => 'आपातकालीन संपर्क में बदलाव करें';

  @override
  String get contactsAddTitle => 'आपातकालीन संपर्क जोड़ें';

  @override
  String get contactsPhoneLabel => 'मोबाइल नंबर';

  @override
  String get contactsRelationshipLabel => 'रिश्ता (वैकल्पिक)';

  @override
  String get contactsHowWeReachThem => 'हम उनसे कैसे संपर्क करते हैं';

  @override
  String get contactsEditHint =>
      'यहाँ नंबर सुधारने पर, उन्हें पहले भेजी गई सूचना दोबारा नहीं भेजी जाती।';

  @override
  String get contactsAddHint =>
      'उन्हें एक SMS मिलेगा जिसमें बताया जाएगा कि वे सूचीबद्ध हैं, और वे इससे बाहर निकल सकते हैं। कुछ होने तक हम उन्हें फिर से मैसेज नहीं करते।';

  @override
  String get contactsSaveButton => 'बदलाव सहेजें';

  @override
  String contactsRemoveTooltip(String name) {
    return '$name को हटाएँ';
  }

  @override
  String get contactsOptedOut => 'SMS से बाहर';

  @override
  String get contactsNoticeSent => 'उन्हें बताया गया कि वे सूचीबद्ध हैं';

  @override
  String get contactsNoticePending => 'सूचना अभी नहीं भेजी गई';

  @override
  String get iceScreenTitle => 'आपातकालीन कार्ड';

  @override
  String get iceSealedEyebrow => 'आपका कार्ड बंद है';

  @override
  String get iceSealedBody =>
      'आपका ब्लड ग्रुप, मेडिकल जानकारी और संपर्क किसी राहगीर को सिर्फ़ आपातकाल के दौरान दिखते हैं — या, अगर आप इसे चालू करें, तो सवारी के दौरान भी। किसी के स्कैन करने के लिए कोई हमेशा-चालू कोड नहीं है।';

  @override
  String get iceBandHeading => 'इस व्यक्ति को मदद की ज़रूरत हो सकती है';

  @override
  String get iceLabelCallThese => 'इन्हें कॉल करें';

  @override
  String get iceNoContacts => 'कोई संपर्क सूचीबद्ध नहीं';

  @override
  String get iceDisclaimer =>
      'RoadPack इस राइडर के सर्कल को अलर्ट भेजता है। यह एम्बुलेंस को कॉल नहीं करता। आपातकालीन सेवाओं के लिए 112 डायल करें।';

  @override
  String get iceBloodGroupMissing => 'दर्ज नहीं है';

  @override
  String mapCacheReadError(String message) {
    return 'कैश नहीं पढ़ा जा सका: $message';
  }

  @override
  String mapRoutesReadError(String message) {
    return 'आपके रास्ते नहीं पढ़े जा सके: $message';
  }

  @override
  String get mapYourRoutesEyebrow => 'आपके रास्ते';

  @override
  String get mapNoRoutesLearned =>
      'अभी कोई रास्ता नहीं सीखा गया। RoadPack आपकी असली यात्राओं से आपके रोज़ के रास्ते ख़ुद तय करता है।';

  @override
  String get mapStoredOnPhoneEyebrow => 'इस फ़ोन में सेव है';

  @override
  String mapTileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count टाइल',
      one: '1 टाइल',
    );
    return '$_temp0';
  }

  @override
  String get mapCacheInMemoryOnlyNotice =>
      'यह कैश सिर्फ़ मेमोरी में है और ऐप फिर से शुरू होने पर खाली हो जाता है।';

  @override
  String get mapClearCachedDataButton => 'कैश किया गया मैप डेटा हटाएँ';

  @override
  String mapRegionCoverageLine(
    int tiles,
    int zoomLevels,
    String estimatedSize,
    int bufferKm,
  ) {
    return '$zoomLevels ज़ूम स्तरों में $tiles टाइल · लगभग $estimatedSize अनुमानित · $bufferKm किमी बफ़र';
  }

  @override
  String mapRegionCoverageLineCorridor(
    int tiles,
    int zoomLevels,
    String estimatedSize,
    int bufferKm,
  ) {
    return '$zoomLevels ज़ूम स्तरों में $tiles टाइल · लगभग $estimatedSize अनुमानित · $bufferKm किमी बफ़र · कॉरिडोर सिर्फ़ शुरुआत और अंत से अनुमानित';
  }

  @override
  String get mapOfflineNoticeText =>
      'पोज़िशन दोबारा लोड नहीं हो सकी। इस मैप पर कोई भी जानकारी हर सदस्य के पास दिखाई गई उम्र से नई नहीं है।';

  @override
  String get mapEmptyNoticeText =>
      'कोई भी आपके साथ लोकेशन शेयर नहीं कर रहा। लोकेशन शेयरिंग हर सर्कल की अपनी सेटिंग है, और हर सदस्य अपनी ख़ुद तय करता है।';

  @override
  String mapStaleBannerBoth(int unreachableCount, int staleCount) {
    String _temp0 = intl.Intl.pluralLogic(
      unreachableCount,
      locale: localeName,
      other: '$unreachableCount का सिग्नल नहीं',
      one: '1 का सिग्नल नहीं',
    );
    String _temp1 = intl.Intl.pluralLogic(
      staleCount,
      locale: localeName,
      other: '$staleCount अपडेट नहीं हो रहे',
      one: '1 अपडेट नहीं हो रहा',
    );
    return '$_temp0, $_temp1 — ये मार्कर बताते हैं कि वे कहाँ थे, कहाँ हैं यह नहीं।';
  }

  @override
  String mapStaleBannerNoSignalOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count का सिग्नल नहीं',
      one: '1 का सिग्नल नहीं',
    );
    return '$_temp0 — ये मार्कर बताते हैं कि वे कहाँ थे, कहाँ हैं यह नहीं।';
  }

  @override
  String mapStaleBannerNotUpdatingOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अपडेट नहीं हो रहे',
      one: '1 अपडेट नहीं हो रहा',
    );
    return '$_temp0 — ये मार्कर बताते हैं कि वे कहाँ थे, कहाँ हैं यह नहीं।';
  }

  @override
  String get mapLastUpdateLabel => 'आख़िरी अपडेट';

  @override
  String get mapSpeedLabel => 'स्पीड';

  @override
  String get mapBatteryLabel => 'बैटरी';

  @override
  String mapLastUpdateValue(String duration) {
    return '$duration पहले';
  }

  @override
  String mapSpeedValue(int speed) {
    return '$speed km/h';
  }

  @override
  String get mapSpeedNotCurrent => 'अभी की नहीं';

  @override
  String get mapSpeedUnknown => 'अज्ञात';

  @override
  String mapBatteryValue(int battery) {
    return '$battery%';
  }

  @override
  String get mapFootnoteLocating =>
      'इस सदस्य के लिए मैप पर अभी कुछ नहीं दिखाया जा रहा।';

  @override
  String get mapFootnoteLive =>
      'RoadPack घटना और मदद को पता चलने के बीच का समय कम करता है। यह किसी को नहीं भेजता। आपातकाल में 112 पर कॉल करें।';

  @override
  String get mapFootnoteStale =>
      'मार्कर नहीं हिला क्योंकि कोई नई लोकेशन नहीं आई। यह इस बात का अंदाज़ा नहीं है कि वे अभी कहाँ हैं।';

  @override
  String get mapPresenceLocating => 'पता लगाया जा रहा है';

  @override
  String get mapPresenceLive => 'लाइव';

  @override
  String get mapPresenceStopped => 'रुके हुए हैं';

  @override
  String get mapPresenceNoSignal => 'सिग्नल नहीं';

  @override
  String mapPresenceLastSeen(String age) {
    return 'आख़िरी बार $age पहले';
  }

  @override
  String mapAgeLabel(String age) {
    return 'आख़िरी बार $age पहले';
  }

  @override
  String get mapPresenceDetailLocating =>
      'इस डिवाइस से पहली लोकेशन का इंतज़ार है।';

  @override
  String mapPresenceDetailLive(String age) {
    return 'स्थिति $age पहले अपडेट हुई।';
  }

  @override
  String get mapPresenceDetailStopped => 'जानकारी आ रही है, हलचल नहीं।';

  @override
  String get mapPresenceDetailStale =>
      'यह वह जगह है जहाँ वे थे, जहाँ वे अभी हैं वह नहीं।';

  @override
  String mapPresenceDetailUnreachable(String age) {
    return '$age से कुछ नहीं मिला। आख़िरी ज्ञात जगह दिखाई जा रही है।';
  }

  @override
  String get mapRegionStatusNotDownloaded => 'डाउनलोड नहीं हुआ';

  @override
  String get mapRegionStatusDownloading => 'डाउनलोड हो रहा है';

  @override
  String get mapRegionStatusDownloaded => 'डाउनलोड हो गया';

  @override
  String get mapRegionStatusFailed => 'विफल';

  @override
  String get mapOfflineLimitationNotice =>
      'ऑफ़लाइन क्षेत्रों की योजना और माप हो चुकी है, पर बेस मैप के लिए अब भी कनेक्शन चाहिए। Google Maps अपने ही SDK में टाइल बनाता है और ऐप को उन्हें पहले से लोड करने का कोई रास्ता नहीं देता। ऑफ़लाइन मैप असल में तभी काम करेंगे जब हम अपना OSM टाइल स्रोत इस्तेमाल करेंगे।';

  @override
  String get packCreateTitle => 'साथ में सवारी शुरू करें';

  @override
  String get packDestinationInvalid =>
      'मंज़िल को अक्षांश, देशांतर के रूप में डालें';

  @override
  String get packRideNameLabel => 'सवारी का नाम (वैकल्पिक)';

  @override
  String get packRideNameHint => 'मुन्नार राइड';

  @override
  String get packCircleLabel => 'सर्कल (वैकल्पिक)';

  @override
  String get packCircleHelper => 'इस सर्कल के सदस्य इस सवारी को ढूँढ सकते हैं';

  @override
  String get packNoCircleOption => 'कोई सर्कल नहीं';

  @override
  String get packDestinationHeading => 'मंज़िल';

  @override
  String get packLatitudeLabel => 'अक्षांश';

  @override
  String get packLongitudeLabel => 'देशांतर';

  @override
  String get packCreateShareNotice =>
      'जो भी सवारी में शामिल होगा, वह सवारी ख़त्म होने तक — और अधिकतम 12 घंटे तक — अपनी जगह पैक के साथ साझा करेगा। RoadPack मदद के लिए ख़ुद कॉल नहीं करता — आपातकाल में 112 पर कॉल करें।';

  @override
  String get packCreateSubmit => 'सवारी बनाएँ';

  @override
  String get packPasteLinkError =>
      'किसी ने आपको जो लिंक भेजा है उसे पेस्ट करें';

  @override
  String get packShareLinkLabel => 'शेयर लिंक';

  @override
  String get packJoinNotice =>
      'शामिल होने पर, सवारी ख़त्म होने तक पैक को रास्ते पर आपकी जगह दिखती रहेगी। आप कभी भी छोड़ सकते हैं, और छोड़ने पर आप फ़ौरन हटा दिए जाते हैं।';

  @override
  String get packJoinSubmit => 'सवारी में शामिल हों';

  @override
  String get packDefaultRideName => 'पैक';

  @override
  String get packEndRideAction => 'सवारी ख़त्म करें';

  @override
  String get packTellPack => 'पैक को बताएँ';

  @override
  String get packEmptyRoster =>
      'अभी कोई शामिल नहीं हुआ। पैक भरने के लिए लिंक शेयर करें।';

  @override
  String get packEndRideConfirmTitle => 'यह सवारी ख़त्म करें?';

  @override
  String get packEndRideConfirmBody =>
      'सब की शेयरिंग रुक जाएगी और लिंक तुरंत काम करना बंद कर देगा। इसे वापस नहीं किया जा सकता।';

  @override
  String get packKeepRidingAction => 'सवारी जारी रखें';

  @override
  String get packAddNoteAction => 'नोट जोड़ें (वैकल्पिक)';

  @override
  String get packNoteLabel => 'नोट';

  @override
  String get packNoteHint => 'टायर पंक्चर, 20 मिनट';

  @override
  String get packShareHonestyNotice =>
      'RoadPack आपकी जगह साझा करता है। यह मदद के लिए कॉल नहीं करता — आपातकाल में 112 पर कॉल करें।';

  @override
  String get packStatusRiding => 'सवारी में';

  @override
  String get packStatusRefueling => 'ईंधन';

  @override
  String get packStatusTakingBreak => 'विश्राम';

  @override
  String get packStatusWrongTurn => 'गलत मोड़';

  @override
  String get packStatusWaiting => 'प्रतीक्षा';

  @override
  String get packStatusStopped => 'रुका हुआ';

  @override
  String get packStatusDone => 'पूरा हुआ';

  @override
  String get packStatusUnexplainedStop => 'अस्पष्ट रुकावट';

  @override
  String get packStatusUnreachable => 'सिग्नल नहीं';

  @override
  String get packStatusPossibleIncident => 'संभावित घटना';

  @override
  String get packAutoTag => 'स्वतः';

  @override
  String get packRoleLeader => 'अग्रणी';

  @override
  String get packRoleSweep => 'सफ़ाई सवार';

  @override
  String get packRoleRider => 'सवार';

  @override
  String get packGapFront => 'सबसे आगे';

  @override
  String get packOffRouteHeadline => 'रास्ते से बाहर';

  @override
  String get packLastSeenHeadline => 'आख़िरी बार दिखे';

  @override
  String get packLocatingHeadline => 'जगह ढूँढी जा रही है';

  @override
  String get packStraightLineUnknown => 'सीधी दूरी अज्ञात';

  @override
  String packDistanceAway(String distance) {
    return '$distance दूर';
  }

  @override
  String get packNoFixYet => 'अभी लोकेशन नहीं मिली';

  @override
  String get packJustNow => 'अभी अभी';

  @override
  String packAgoCompact(String duration) {
    return '$duration पहले';
  }

  @override
  String get packBehindLabel => 'पीछे';

  @override
  String get packBehindLabelEst => 'अनुमानित पीछे';

  @override
  String packBehindWithDuration(String duration) {
    return '$duration पीछे';
  }

  @override
  String packBehindWithDurationEst(String duration) {
    return '$duration अनुमानित पीछे';
  }

  @override
  String get packYouLabel => 'आप';

  @override
  String packNameYouSuffix(String name) {
    return '$name (आप)';
  }

  @override
  String get packSharingLiveHeadline => 'यह सवारी शेयर की जा रही है';

  @override
  String get packSharingOffHeadline => 'शेयरिंग बंद है';

  @override
  String packLiveNotice(String expiry) {
    return 'लिंक रखने वाला कोई भी $expiry तक देख सकता है कि पैक कहाँ है। सवार देखने वालों की संख्या देख सकते हैं।';
  }

  @override
  String get packLinkExpiredNotice =>
      'लिंक अब काम नहीं करता। इस सवारी को कोई नहीं देख सकता।';

  @override
  String get packExpiresNow => 'अभी';

  @override
  String packExpiresInHours(int hours) {
    return '$hours घंटे में समाप्त';
  }

  @override
  String packExpiresInMinutes(int minutes) {
    return '$minutes मिनट में समाप्त';
  }

  @override
  String get packShareLinkAction => 'लिंक शेयर करें';

  @override
  String get packCopyLinkTooltip => 'लिंक कॉपी करें';

  @override
  String get packStopSharingAction => 'शेयरिंग बंद करें';

  @override
  String get packLinkCopiedSnackbar => 'लिंक कॉपी हो गया';

  @override
  String get packDefaultShareRideName => 'हमारी सवारी';

  @override
  String packShareMessage(String name, String url) {
    return '$name को लाइव फ़ॉलो करें: $url\n\nRoadPack दिखाता है कि पैक कहाँ है। यह एम्बुलेंस के लिए कॉल नहीं करता — आपातकाल में 112 पर कॉल करें।';
  }

  @override
  String packWatchingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count देख रहे हैं',
      one: '1 देख रहा है',
    );
    return '$_temp0';
  }

  @override
  String get packNotShared => 'शेयर नहीं हो रहा';
}
