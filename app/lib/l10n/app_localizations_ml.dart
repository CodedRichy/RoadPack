// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malayalam (`ml`).
class AppLocalizationsMl extends AppLocalizations {
  AppLocalizationsMl([String locale = 'ml']) : super(locale);

  @override
  String get appTitle => 'RoadPack';

  @override
  String get commonCancel => 'റദ്ദാക്കുക';

  @override
  String get commonClose => 'അടയ്ക്കുക';

  @override
  String get commonImOkay => 'എനിക്ക് കുഴപ്പമില്ല';

  @override
  String get commonOn => 'ഓൺ';

  @override
  String get commonOff => 'ഓഫ്';

  @override
  String get commonSettings => 'ക്രമീകരണങ്ങൾ';

  @override
  String get commonSelect => 'തിരഞ്ഞെടുക്കുക';

  @override
  String get commonName => 'പേര്';

  @override
  String get commonNotSignedIn => 'സൈൻ ഇൻ ചെയ്തിട്ടില്ല';

  @override
  String commonError(String message) {
    return 'പിശക്: $message';
  }

  @override
  String get commonCall112 => '112 വിളിക്കുക';

  @override
  String get sosLabel => 'SOS';

  @override
  String get sosAlertTitle => 'SOS അലേർട്ട്';

  @override
  String get sosHoldHint => 'SOS അയയ്ക്കാൻ 2 സെക്കൻഡ് അമർത്തിപ്പിടിക്കുക';

  @override
  String get sosCountdownBody =>
      'നിങ്ങളുടെ അടിയന്തര ബന്ധുക്കൾക്ക് അലേർട്ട് അയയ്ക്കും';

  @override
  String get sosSentTitle => 'അടിയന്തര അലേർട്ടുകൾ അയച്ചു';

  @override
  String get sosSentBody => 'നിങ്ങളുടെ അടിയന്തര ബന്ധുക്കളെ അറിയിക്കുന്നു.';

  @override
  String get incidentResolvedTitle => 'സംഭവം അവസാനിച്ചു';

  @override
  String get incidentResolvedBody =>
      'നിങ്ങൾ സുരക്ഷിതരാണെന്ന് നിങ്ങളുടെ ബന്ധുക്കളെ അറിയിച്ചു.';

  @override
  String incidentRef(String ref) {
    return 'സംഭവം: $ref';
  }

  @override
  String get crashDetectedTitle => 'അപകടം കണ്ടെത്തി';

  @override
  String crashCountdownBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count സെക്കൻഡിനുള്ളിൽ നിങ്ങളുടെ അടിയന്തര ബന്ധുക്കൾക്ക് അലേർട്ട് അയയ്ക്കും',
      one:
          '1 സെക്കൻഡിനുള്ളിൽ നിങ്ങളുടെ അടിയന്തര ബന്ധുക്കൾക്ക് അലേർട്ട് അയയ്ക്കും',
    );
    return '$_temp0';
  }

  @override
  String get crashAlertSentTitle => 'അപകട അലേർട്ട് അയച്ചു';

  @override
  String get crashAlertSentBody =>
      'സാധ്യമായ ഒരു അപകടത്തെക്കുറിച്ച് നിങ്ങളുടെ അടിയന്തര ബന്ധുക്കളെ അറിയിച്ചു.';

  @override
  String get crashReasonQuestion => 'എന്താണ് സംഭവിച്ചത്?';

  @override
  String get crashReasonPothole => 'കുഴി / സ്പീഡ് ബ്രേക്കർ';

  @override
  String get crashReasonPhoneDropped => 'ഫോൺ വീണു';

  @override
  String get crashReasonSuddenBraking => 'പെട്ടെന്ന് ബ്രേക്ക് ചെയ്തു';

  @override
  String get crashReasonOther => 'മറ്റുള്ളവ';

  @override
  String get crashReasonOtherHint => 'എന്താണ് സംഭവിച്ചതെന്ന് എഴുതുക';

  @override
  String get crashReasonConfirm => 'സ്ഥിരീകരിക്കുക — എനിക്ക് കുഴപ്പമില്ല';

  @override
  String get alertTitle => 'അലേർട്ട്';

  @override
  String get alertNotFound => 'അലേർട്ട് കണ്ടെത്തിയില്ല';

  @override
  String get alertDetailTitle => 'അടിയന്തര അലേർട്ട്';

  @override
  String alertVictimHeadline(String name) {
    return '$name ഒരു അപകടത്തിൽ പെട്ടിരിക്കാം';
  }

  @override
  String alertLocationLine(String lat, String lng) {
    return 'സ്ഥാനം: $lat, $lng';
  }

  @override
  String alertTimeLine(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.yMMMd(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'സമയം: $timeString';
  }

  @override
  String get alertAcknowledge => 'കണ്ടു എന്ന് അറിയിക്കുക';

  @override
  String get alertAcknowledged => 'കണ്ടതായി അറിയിച്ചു';

  @override
  String alertCallPerson(String name) {
    return '$name എന്നയാളെ വിളിക്കുക';
  }

  @override
  String get alertOpenInMaps => 'മാപ്പിൽ തുറക്കുക';

  @override
  String alertCardTitle(String name) {
    return '$name — അടിയന്തരാവസ്ഥ';
  }

  @override
  String get alertCardTapToView => 'കാണാനും സ്ഥിരീകരിക്കാനും ടാപ്പ് ചെയ്യുക';

  @override
  String get homeSwitchToNight => 'നൈറ്റ് മോഡിലേക്ക് മാറുക';

  @override
  String get homeSwitchToSunlight => 'സൺലൈറ്റ് മോഡിലേക്ക് മാറുക';

  @override
  String get protectionEyebrow => 'സംരക്ഷണം';

  @override
  String get checkCrashDetection => 'അപകടം\nകണ്ടെത്തൽ';

  @override
  String get checkLocationTracking => 'ലൊക്കേഷൻ\nട്രാക്കിംഗ്';

  @override
  String get checkNonArrival => 'എത്താതിരിക്കൽ\nഅലേർട്ട്';

  @override
  String get checkEmergencyContact => 'അടിയന്തര\nബന്ധു';

  @override
  String checkSemantics(String label, String state) {
    return '$label: $state';
  }

  @override
  String get watchersHeading => 'ആരാണ് ശ്രദ്ധിക്കുന്നത്';

  @override
  String get watchersError =>
      'സർക്കിളുകൾ ലോഡ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കാൻ താഴേക്ക് വലിക്കുക.';

  @override
  String get watchersEmpty =>
      'ഇതുവരെ ആരുമില്ല. നിങ്ങൾക്ക് വിളിക്കാൻ കഴിയാത്തപ്പോൾ വിളിക്കപ്പെടുന്നവരാണ് ഒരു സർക്കിൾ.';

  @override
  String get watchersCreateCircle => 'സർക്കിൾ ഉണ്ടാക്കുക';

  @override
  String circleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count  സർക്കിളുകൾ',
      one: '$count  സർക്കിൾ',
    );
    return '$_temp0';
  }

  @override
  String circleCountWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'സർക്കിളുകൾ',
      one: 'സർക്കിൾ',
    );
    return '$_temp0';
  }

  @override
  String get packEyebrow => 'മറ്റുള്ളവർക്കൊപ്പം യാത്ര';

  @override
  String get packTagline => 'വെറും ഒരു കുത്തല്ല — എല്ലാവർക്കും അകലം കാണാം';

  @override
  String get packStartRide => 'യാത്ര തുടങ്ങുക';

  @override
  String get packJoinRide => 'യാത്രയിൽ ചേരുക';

  @override
  String get navLiveMap => 'ലൈവ് മാപ്പ്';

  @override
  String get navSafetyCircles => 'സുരക്ഷാ സർക്കിളുകൾ';

  @override
  String get navCommutes => 'യാത്രകളും എത്താതിരിക്കലും';

  @override
  String get navKnownRoutes => 'പരിചിതമായ വഴികൾ';

  @override
  String get navTripHistory => 'യാത്രാ ചരിത്രം';

  @override
  String get milestoneCapArmed => 'എല്ലാ സംവിധാനങ്ങളും ശ്രദ്ധിക്കുന്നു';

  @override
  String get milestoneHeadlineArmed => 'സംരക്ഷണം ഓണാണ്';

  @override
  String get milestoneDetailArmed =>
      'അപകടം കണ്ടെത്തൽ, ട്രാക്കിംഗ്, എത്താതിരിക്കൽ അലേർട്ട് — മൂന്നും ഓണാണ്. നിങ്ങൾ വീണാൽ നിങ്ങളുടെ സർക്കിളുകൾ അറിയും.';

  @override
  String get milestoneCapPartial => 'സംരക്ഷണത്തിൽ വിടവ്';

  @override
  String get milestoneHeadlinePartial => 'ഭാഗിക സംരക്ഷണം';

  @override
  String get milestoneDetailPartial =>
      'ചില സംവിധാനങ്ങൾ ഓഫാണ്. യാത്ര തുടങ്ങും മുൻപ് ബാക്കിയുള്ളവ ഓണാക്കുക, അല്ലെങ്കിൽ അവ ശ്രദ്ധിക്കുന്ന കാര്യം ആരും അറിയില്ല.';

  @override
  String get milestoneCapOff => 'ഒന്നും ശ്രദ്ധിക്കുന്നില്ല';

  @override
  String get milestoneHeadlineOff => 'സംരക്ഷണം ഇല്ല';

  @override
  String get milestoneDetailOff =>
      'അപകടം കണ്ടെത്തലില്ല, ട്രാക്കിംഗില്ല, അലേർട്ടില്ല. അടുത്ത യാത്രയ്ക്ക് മുൻപ് ക്രമീകരണങ്ങളിൽ സംരക്ഷണം ഓണാക്കുക.';

  @override
  String get milestoneCapIncident => 'സംഭവം സജീവം';

  @override
  String get milestoneHeadlineIncident => 'സഹായം വിളിക്കുന്നു';

  @override
  String get milestoneDetailIncident =>
      'നിങ്ങളുടെ സർക്കിളുകൾക്ക് ഇപ്പോൾ അലേർട്ട് പോകുന്നു.';

  @override
  String milestoneSemantics(String headline, String detail, int active) {
    return 'സംരക്ഷണം $headline. $detail 3-ൽ $active സംവിധാനങ്ങൾ സജീവം.';
  }

  @override
  String get milestoneSemanticsContactSet =>
      'അടിയന്തര ബന്ധുവിനെ ചേർത്തിട്ടുണ്ട്.';

  @override
  String get milestoneSemanticsContactMissing => 'അടിയന്തര ബന്ധു ഇല്ല.';

  @override
  String get gapNoContactHeadline => 'വിളിക്കാൻ ആരുമില്ല';

  @override
  String get gapNoContactDetail =>
      'നിങ്ങൾക്ക് അടിയന്തര ബന്ധു ആരുമില്ല. അപകടം കണ്ടെത്തിയാലും അലേർട്ട് ആരുടെയും അടുത്ത് എത്തില്ല. ഒരു ബന്ധുവിനെ ചേർത്താൽ ബാക്കിയെല്ലാം പ്രവർത്തിച്ചു തുടങ്ങും.';

  @override
  String get gapNoContactAction => 'ബന്ധുവിനെ ചേർക്കുക';

  @override
  String get gapCrashOffHeadline => 'അപകടം കണ്ടെത്തൽ ഓഫാണ്';

  @override
  String get gapCrashOffDetail =>
      'ഒരു ഇടിയും ശ്രദ്ധിക്കുന്ന സംവിധാനം പ്രവർത്തിക്കുന്നില്ല. നിങ്ങൾ വീഴുകയും ഫോണിൽ എത്താൻ കഴിയാതിരിക്കുകയും ചെയ്താൽ ആരും അറിയില്ല.';

  @override
  String get gapTurnOnAction => 'ഓണാക്കുക';

  @override
  String get gapTrackingOffHeadline => 'ലൊക്കേഷൻ ട്രാക്കിംഗ് ഓഫാണ്';

  @override
  String get gapTrackingOffDetail =>
      'നിങ്ങളുടെ സർക്കിളുകൾക്ക് അലേർട്ട് പോകും, പക്ഷേ നിങ്ങൾ എവിടെയാണെന്ന് അറിയില്ല. തിരയേണ്ടി വന്നാൽ സഹായം വൈകും.';

  @override
  String get gapNonArrivalOffHeadline => 'എത്താതിരിക്കൽ അലേർട്ട് ഓഫാണ്';

  @override
  String get gapNonArrivalOffDetail =>
      'നിങ്ങൾ ലക്ഷ്യസ്ഥാനത്ത് എത്തിയില്ലെങ്കിൽ ആരും അത് ശ്രദ്ധിക്കില്ല. ഇത് പരിഹരിക്കാൻ ഒരു യാത്രാ വഴി ചേർക്കുക.';

  @override
  String get gapSetUpCommutesAction => 'യാത്രാ വഴികൾ ചേർക്കുക';

  @override
  String get settingsSectionSafety => 'സുരക്ഷ';

  @override
  String get settingsCrashSensitivity => 'അപകട സംവേദനക്ഷമത';

  @override
  String get settingsSensitivityHigh => 'ഉയർന്നത്';

  @override
  String get settingsSensitivityMedium => 'ഇടത്തരം';

  @override
  String get settingsSensitivityLow => 'കുറവ്';

  @override
  String get settingsSensitivityHighDetail =>
      'ഉയർന്നത് — കൂടുതൽ സംവേദനക്ഷമം, തെറ്റായ അലേർട്ടുകൾ കൂടാം';

  @override
  String get settingsSensitivityMediumDetail =>
      'ഇടത്തരം — സന്തുലിതം (ശുപാർശ ചെയ്യുന്നു)';

  @override
  String get settingsSensitivityLowDetail =>
      'കുറവ് — സംവേദനക്ഷമത കുറവ്, തെറ്റായ അലേർട്ടുകൾ കുറവ്';

  @override
  String get settingsPhoneMount => 'ഫോൺ മൗണ്ട്';

  @override
  String get settingsMountBar => 'ഹാൻഡിൽബാർ';

  @override
  String get settingsMountPocket => 'പോക്കറ്റ്';

  @override
  String get settingsMountBag => 'ബാഗ്';

  @override
  String get settingsMountOther => 'മറ്റുള്ളവ';

  @override
  String get settingsMountBarDetail => 'ഹാൻഡിൽബാർ മൗണ്ട് (ഏറ്റവും സംവേദനക്ഷമം)';

  @override
  String get settingsMountPocketDetail => 'പോക്കറ്റിൽ';

  @override
  String get settingsMountBagDetail => 'ബാഗിൽ (ഏറ്റവും കുറഞ്ഞ സംവേദനക്ഷമത)';

  @override
  String get settingsMountUnknownDetail => 'മറ്റുള്ളവ / അറിയില്ല';

  @override
  String get settingsSectionTracking => 'ട്രാക്കിംഗ്';

  @override
  String get settingsNonArrivalAlerts => 'എത്താതിരിക്കൽ അലേർട്ട്';

  @override
  String get settingsNonArrivalAlertsSub =>
      'നിങ്ങൾ എത്തിയില്ലെങ്കിൽ ബന്ധുക്കൾക്ക് അലേർട്ട് അയയ്ക്കുക';

  @override
  String get settingsAlertDelay => 'അലേർട്ട് കാലതാമസം';

  @override
  String settingsAlertDelaySub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'എത്തേണ്ട സമയത്തിന് $count മിനിറ്റ് ശേഷം',
      one: 'എത്തേണ്ട സമയത്തിന് 1 മിനിറ്റ് ശേഷം',
    );
    return '$_temp0';
  }

  @override
  String minutesShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count മിനിറ്റ്',
      one: '1 മിനിറ്റ്',
    );
    return '$_temp0';
  }

  @override
  String get settingsCommuteRoutes => 'യാത്രാ വഴികൾ';

  @override
  String get settingsCommuteRoutesSub =>
      'എത്തിയില്ലെങ്കിൽ അലേർട്ട് അയയ്ക്കുന്ന വഴികൾ';

  @override
  String get settingsSectionEmergency => 'അടിയന്തരാവസ്ഥ';

  @override
  String get settingsEmergencyContacts => 'അടിയന്തര ബന്ധുക്കൾ';

  @override
  String get settingsEmergencyContactsReady =>
      'നിങ്ങൾക്ക് വിളിക്കാൻ കഴിയാത്തപ്പോൾ ആരെ വിളിക്കും';

  @override
  String get settingsEmergencyContactsEmpty =>
      'ഇതുവരെ ആരുമില്ല — അലേർട്ട് ആരുടെയും അടുത്ത് എത്തില്ല';

  @override
  String get settingsIceCard => 'ICE കാർഡ്';

  @override
  String get settingsIceCardSub => 'സ്ഥലത്ത് ആദ്യം എത്തുന്നയാൾ കാണുന്നത്';

  @override
  String get settingsBystanderPreview => 'വഴിയാത്രക്കാരൻ കാണുന്നത് കാണുക';

  @override
  String get settingsBystanderPreviewSub =>
      'ആവശ്യം വരുന്നതിന് മുൻപ് നിങ്ങളുടെ അപകട സ്ക്രീൻ പരിശോധിക്കുക';

  @override
  String get settingsIceCommuteToggle => 'യാത്രകൾക്കിടയിൽ ICE കാർഡ് കാണിക്കുക';

  @override
  String get settingsIceCommuteToggleSub =>
      'സ്ഥിരസ്ഥിതിയായി ഓഫാണ്. ഓണാക്കിയാൽ, അപകടത്തിന് ശേഷം മാത്രമല്ല, ട്രാക്ക് ചെയ്യുന്ന യാത്രയ്ക്കിടയിലും സ്ഥലത്തുള്ള സഹായിക്ക് നിങ്ങളുടെ രക്തഗ്രൂപ്പും ബന്ധുക്കളും കാണാം.';

  @override
  String get settingsSectionMaps => 'മാപ്പുകൾ';

  @override
  String get settingsOfflineMaps => 'ഓഫ്‌ലൈൻ മാപ്പുകൾ';

  @override
  String get settingsOfflineMapsSub =>
      'നെറ്റ്‌വർക്ക് ഇല്ലാത്ത പ്രദേശങ്ങൾക്കായി മാപ്പ് ഡൗൺലോഡ് ചെയ്യുക';

  @override
  String get settingsSectionEmergencyProfile => 'അടിയന്തര പ്രൊഫൈൽ';

  @override
  String get settingsBloodGroup => 'രക്തഗ്രൂപ്പ്';

  @override
  String get settingsMedicalNotes => 'മെഡിക്കൽ വിവരങ്ങൾ';

  @override
  String get settingsMedicalNotesHint => 'അലർജികൾ, രോഗങ്ങൾ, മരുന്നുകൾ...';

  @override
  String get settingsSectionAccount => 'അക്കൗണ്ട്';

  @override
  String get settingsVehicle => 'വാഹനം';

  @override
  String get settingsSignOut => 'സൈൻ ഔട്ട്';

  @override
  String get settingsSectionLanguage => 'ഭാഷ';

  @override
  String get settingsLanguageSub => 'അടിയന്തര സ്ക്രീനുകളും ഈ ഭാഷയിലായിരിക്കും';

  @override
  String get languageSystemDefault => 'ഫോൺ അനുസരിച്ച്';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get languageMalayalam => 'മലയാളം';

  @override
  String get circlesJoinCircleTitle => 'സർക്കിളിൽ ചേരുക';

  @override
  String get circlesCreateCircle => 'സർക്കിൾ ഉണ്ടാക്കുക';

  @override
  String get circlesLoadError => 'എന്തോ കുഴപ്പം സംഭവിച്ചു';

  @override
  String get circlesRetry => 'വീണ്ടും ശ്രമിക്കുക';

  @override
  String get circlesEmptyTitle => 'നിങ്ങളുടെ ആദ്യ സുരക്ഷാ സർക്കിൾ ഉണ്ടാക്കുക';

  @override
  String get circlesEmptyBody =>
      'റോഡിൽ എന്തെങ്കിലും സംഭവിച്ചാൽ ശരിയായ ആളുകൾക്ക് അലേർട്ട് ലഭിക്കുന്നുവെന്ന് നിങ്ങളുടെ സർക്കിളുകൾ ഉറപ്പാക്കുന്നു.';

  @override
  String get circlesRegenerateCode => 'പുതിയ ഇൻവൈറ്റ് കോഡ് ഉണ്ടാക്കുക';

  @override
  String get circlesDeleteCircle => 'സർക്കിൾ ഇല്ലാതാക്കുക';

  @override
  String circlesMembersHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'അംഗങ്ങൾ ($count)',
      one: 'അംഗം (1)',
    );
    return '$_temp0';
  }

  @override
  String circlesObserversHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'നിരീക്ഷകർ ($count)',
      one: 'നിരീക്ഷകൻ (1)',
    );
    return '$_temp0';
  }

  @override
  String get circlesObserverSmsTag => 'SMS';

  @override
  String get circlesAddObserverAction => 'നിരീക്ഷകനെ ചേർക്കുക';

  @override
  String get circlesObserverSmsExplainer =>
      'നിരീക്ഷകർക്ക് SMS അലേർട്ട് ലഭിക്കും, ആപ്പ് ആവശ്യമില്ല.';

  @override
  String get circlesPhoneNumberLabel => 'ഫോൺ നമ്പർ';

  @override
  String get circlesAddAction => 'ചേർക്കുക';

  @override
  String get circlesLeaveDialogTitle => 'സർക്കിൾ വിടണോ?';

  @override
  String get circlesLeaveFamilyWarning =>
      'വിടുന്നത് ഈ സർക്കിളിലെ എല്ലാ അടിയന്തര ബന്ധു ലിങ്കുകളും നീക്കും.';

  @override
  String get circlesLeaveConfirm => 'നിങ്ങൾക്ക് ഉറപ്പാണോ വിടണമെന്ന്?';

  @override
  String get circlesLeaveAction => 'വിടുക';

  @override
  String circlesLeaveError(String message) {
    return 'വിടാൻ കഴിഞ്ഞില്ല: $message';
  }

  @override
  String get circlesDeleteDialogTitle => 'സർക്കിൾ ഇല്ലാതാക്കണോ?';

  @override
  String get circlesDeleteWarning => 'ഇത് തിരികെ എടുക്കാൻ കഴിയില്ല.';

  @override
  String get circlesDeleteAction => 'ഇല്ലാതാക്കുക';

  @override
  String circlesNewCodeSnackbar(String code) {
    return 'പുതിയ കോഡ്: $code';
  }

  @override
  String get circlesRoleUpdateError =>
      'റോൾ അപ്ഡേറ്റ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get circlesRemoveMemberError =>
      'അംഗത്തെ നീക്കം ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get circlesRemoveObserverError =>
      'നിരീക്ഷകനെ നീക്കം ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get circlesEcUpdateError =>
      'അടിയന്തര ബന്ധുവിനെ അപ്ഡേറ്റ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കുക.';

  @override
  String circlesShareInviteMessage(String code) {
    return 'RoadPack-ൽ എന്റെ സുരക്ഷാ സർക്കിളിൽ ചേരൂ! കോഡ്: $code';
  }

  @override
  String get circlesNameLabel => 'സർക്കിളിന്റെ പേര്';

  @override
  String circlesDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count മണിക്കൂർ',
      one: '1 മണിക്കൂർ',
    );
    return '$_temp0';
  }

  @override
  String get circlesDurationLabel => 'ദൈർഘ്യം';

  @override
  String get circlesCreateAction => 'ഉണ്ടാക്കുക';

  @override
  String get circlesLocationSharingTitle =>
      'ഈ സർക്കിളിന് ലൈവ് ലൊക്കേഷൻ കാണാൻ അനുവദിക്കുക';

  @override
  String get circlesLocationSharingOnDetail =>
      'ഈ സർക്കിളിലെ എല്ലാവർക്കും ഓരോ അംഗവും എവിടെയാണെന്ന് കാണാൻ കഴിയും. പിന്നീട് ഇത് ഓഫ് ചെയ്യാം.';

  @override
  String get circlesLocationSharingOffDetail =>
      'ഓഫാണ്. ആരെങ്കിലും അപകടത്തിൽ പെട്ടാൽ അംഗങ്ങൾക്ക് ഇപ്പോഴും അലേർട്ട് ലഭിക്കും — ബാക്കി സമയത്ത് അവർക്ക് പരസ്പരം കാണാൻ കഴിയില്ല എന്ന് മാത്രം.';

  @override
  String get circlesInvalidCodeError => 'തെറ്റായ കോഡ്';

  @override
  String get circlesEnterCodeHeading => 'ഇൻവൈറ്റ് കോഡ് നൽകുക';

  @override
  String circlesMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count അംഗങ്ങൾ',
      one: '1 അംഗം',
    );
    return '$_temp0';
  }

  @override
  String get circlesJoinAction => 'ചേരുക';

  @override
  String get circlesWhoCanSeeMeTitle => 'ആരാണ് എന്നെ കാണാൻ കഴിയുന്നത്';

  @override
  String get circlesChangeFailedMessage =>
      'അത് മാറ്റാൻ കഴിഞ്ഞില്ല. ഒന്നും മാറ്റിയിട്ടില്ല.';

  @override
  String circlesWatcherCountHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ആളുകൾക്ക് നിങ്ങളുടെ ലൊക്കേഷൻ കാണാം',
      one: '1 വ്യക്തിക്ക് നിങ്ങളുടെ ലൊക്കേഷൻ കാണാം',
      zero: 'ആർക്കും നിങ്ങളുടെ ലൊക്കേഷൻ കാണാൻ കഴിയില്ല',
    );
    return '$_temp0';
  }

  @override
  String get circlesFullListNotice =>
      'ഇത് പൂർണ്ണ പട്ടികയാണ്. RoadPack-ന് മറഞ്ഞിരിക്കുന്ന ഒരു മോഡും ഇല്ല — നിങ്ങളെ ആർക്കെങ്കിലും കാണാൻ കഴിയുമെങ്കിൽ, അവർ ഈ പേജിലുണ്ട്.';

  @override
  String get circlesNoCirclesYet =>
      'നിങ്ങൾ ഇതുവരെ ഒരു സർക്കിളിലും അംഗമല്ല, അതിനാൽ നിങ്ങളെ കാണാൻ ആരുമില്ല.';

  @override
  String get circlesLoadWhoCanSeeError =>
      'ആരാണ് നിങ്ങളെ കാണാൻ കഴിയുന്നതെന്ന് ലോഡ് ചെയ്യാനായില്ല';

  @override
  String get circlesLoadWhoCanSeeErrorDetail =>
      'ഇതിനർത്ഥം ആർക്കും കാണാൻ കഴിയില്ല എന്ന് കരുതരുത്. സിഗ്നൽ ലഭിക്കുമ്പോൾ വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get circlesTryAgainAction => 'വീണ്ടും ശ്രമിക്കുക';

  @override
  String circlesCardSubtitle(String type, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$type — $count അംഗങ്ങൾ',
      one: '$type — 1 അംഗം',
    );
    return '$_temp0';
  }

  @override
  String get circlesExpiredTag => 'കാലഹരണപ്പെട്ടു';

  @override
  String get circlesTypeFamily => 'കുടുംബം';

  @override
  String get circlesTypeFriends => 'സുഹൃത്തുക്കൾ';

  @override
  String get circlesTypeCommute => 'യാത്രാ ഗ്രൂപ്പ്';

  @override
  String get circlesTypeConvoy => 'വാഹനസംഘം';

  @override
  String get circlesTypeFamilyDefaultName => 'എന്റെ കുടുംബം';

  @override
  String get circlesTypeFriendsDefaultName => 'സുഹൃത്തുക്കൾ';

  @override
  String get circlesTypeCommuteDefaultName => 'യാത്രാ ഗ്രൂപ്പ്';

  @override
  String get circlesTypeConvoyDefaultName => 'വാഹനസംഘം';

  @override
  String get circlesTypeFamilyDescription =>
      'നിങ്ങളുടെ ഏറ്റവും അടുത്തവർ. അംഗങ്ങൾ സ്വയമേവ അടിയന്തര ബന്ധുക്കളായി ചേർക്കപ്പെടും.';

  @override
  String get circlesTypeFriendsDescription =>
      'യാത്ര ചെയ്യുന്ന അല്ലെങ്കിൽ റൈഡ് ചെയ്യുന്ന സുഹൃത്തുക്കൾ. പ്രത്യേക അംഗങ്ങളെ അടിയന്തര ബന്ധുക്കളായി ചേർക്കുക.';

  @override
  String get circlesTypeCommuteDescription => 'സ്ഥിരം യാത്രാ ഗ്രൂപ്പ്.';

  @override
  String get circlesTypeConvoyDescription =>
      'താൽക്കാലിക ഗ്രൂപ്പ് റൈഡ്. ഒരു ദൈർഘ്യം സെറ്റ് ചെയ്യുക.';

  @override
  String get circlesRoleAdmin => 'അഡ്മിൻ';

  @override
  String get circlesRoleMember => 'അംഗം';

  @override
  String get circlesRoleObserver => 'നിരീക്ഷകൻ';

  @override
  String get circlesUnknownMember => 'അജ്ഞാതം';

  @override
  String get circlesYouTag => '(നിങ്ങൾ)';

  @override
  String get circlesMenuLeaveCircle => 'സർക്കിൾ വിടുക';

  @override
  String get circlesMenuDemote => 'അംഗമായി ഡീമോട്ട് ചെയ്യുക';

  @override
  String get circlesMenuPromote => 'അഡ്മിനായി പ്രോമോട്ട് ചെയ്യുക';

  @override
  String get circlesMenuRemove => 'നീക്കം ചെയ്യുക';

  @override
  String get circlesMenuMarkEc => 'അടിയന്തര ബന്ധുവായി അടയാളപ്പെടുത്തുക';

  @override
  String get circlesMenuRemoveEc => 'അടിയന്തര ബന്ധുവിൽ നിന്ന് നീക്കം ചെയ്യുക';

  @override
  String get circlesMonthlyCheckTitle =>
      'മാസിക പരിശോധന: ആരാണ് നിങ്ങളെ കാണാൻ കഴിയുന്നത്?';

  @override
  String circlesWatcherCountBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ഇപ്പോൾ $count ആളുകൾക്ക് നിങ്ങളുടെ ലൊക്കേഷൻ കാണാം.',
      one: 'ഇപ്പോൾ 1 വ്യക്തിക്ക് നിങ്ങളുടെ ലൊക്കേഷൻ കാണാം.',
      zero:
          'ഇപ്പോൾ ആർക്കും നിങ്ങളുടെ ലൊക്കേഷൻ കാണാൻ കഴിയില്ല. എന്നാലും ഒരു നോട്ടം നല്ലതാണ് — സർക്കിളുകൾ മാറിക്കൊണ്ടിരിക്കും.',
    );
    return '$_temp0';
  }

  @override
  String get circlesReviewListAction => 'പട്ടിക പരിശോധിക്കുക';

  @override
  String get circlesNotNowAction => 'ഇപ്പോൾ വേണ്ട';

  @override
  String get circlesSharingOnEmptyDetail =>
      'ലൊക്കേഷൻ പങ്കിടൽ ഓണാണ്, പക്ഷേ ഈ സർക്കിളിൽ ഇതുവരെ മറ്റാരും ഇല്ല.';

  @override
  String circlesWatchersHereDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ഇവിടെ $count ആളുകൾക്ക് നിങ്ങൾ എവിടെയാണെന്ന് കാണാം.',
      one: 'ഇവിടെ 1 വ്യക്തിക്ക് നിങ്ങൾ എവിടെയാണെന്ന് കാണാം.',
    );
    return '$_temp0';
  }

  @override
  String get circlesSharingOffDetail =>
      'ഈ സർക്കിളിൽ ആർക്കും നിങ്ങൾ എവിടെയാണെന്ന് കാണാൻ കഴിയില്ല.';

  @override
  String circlesWatcherRow(String name, String role) {
    return '$name — $role';
  }

  @override
  String get circlesShareMyLocationTitle =>
      'ഈ സർക്കിളുമായി എന്റെ ലൊക്കേഷൻ പങ്കിടുക';

  @override
  String get circlesSelfSharingOnDetail =>
      'ഇത് ഓഫ് ചെയ്യുന്നത് നിങ്ങളുടെ ലൈവ് സ്ഥാനം ഈ സർക്കിളിൽ നിന്ന് മറയ്ക്കും. നിങ്ങൾ ഇപ്പോഴും ഒരു അംഗമായി തുടരും, അപകടം സംഭവിച്ചാൽ അവർക്ക് ഇപ്പോഴും നിങ്ങളുടെ സ്ഥാനത്തോടെ അലേർട്ട് ലഭിക്കും.';

  @override
  String get circlesSelfSharingOffDetail =>
      'നിങ്ങളുടെ ലൈവ് സ്ഥാനം ഈ സർക്കിളിൽ നിന്ന് മറഞ്ഞിരിക്കുന്നു. നിങ്ങൾ ഇപ്പോഴും ഒരു അംഗമാണ്, അവരുടെ അലേർട്ടുകൾ ഇപ്പോഴും നിങ്ങൾക്ക് ലഭിക്കും, അപകടം സംഭവിച്ചാൽ നിങ്ങൾ എവിടെയാണെന്ന് അവരോട് ഇപ്പോഴും പറയും.';

  @override
  String get circlesAdminOnlyOptOutNotice =>
      'ഈ സർക്കിളിന്റെ അഡ്മിന് മാത്രമേ സർക്കിൾ-വൈഡ് ക്രമീകരണം മാറ്റാൻ കഴിയൂ, പക്ഷേ മുകളിലെ സ്വിച്ച് നിങ്ങളുടെ സ്വന്തം ലൊക്കേഷൻ പങ്കിടുന്നത് നിർത്തും. നിങ്ങൾക്ക് സർക്കിൾ വിടാനും കഴിയും.';

  @override
  String get circlesAdminOnlyNoOptOutNotice =>
      'ഈ സർക്കിളിന്റെ അഡ്മിന് മാത്രമേ അതിന്റെ ഷെയറിംഗ് ക്രമീകരണം മാറ്റാൻ കഴിയൂ. നിങ്ങൾക്ക് സൗകര്യമില്ലെങ്കിൽ, നിങ്ങൾക്ക് സർക്കിൾ വിടാം — ഇത് ഉടനെ പ്രാബല്യത്തിൽ വരും, RoadPack ഒരിക്കലും നിങ്ങളെ തടയില്ല.';

  @override
  String get circlesLeaveThisCircleAction => 'ഈ സർക്കിൾ വിടുക';

  @override
  String get circlesInviteCodeLabel => 'ഇൻവൈറ്റ് കോഡ്';

  @override
  String get circlesCodeCopiedSnackbar => 'കോഡ് കോപ്പി ചെയ്തു';

  @override
  String get circlesCopyAction => 'കോപ്പി ചെയ്യുക';

  @override
  String get circlesShareAction => 'ഷെയർ ചെയ്യുക';

  @override
  String get commuteTitle => 'യാത്ര';

  @override
  String get commuteAddRoute => 'വഴി ചേർക്കുക';

  @override
  String get commuteEditRoute => 'വഴി തിരുത്തുക';

  @override
  String get commuteLoadError => 'നിങ്ങളുടെ വഴികൾ ലോഡ് ചെയ്യാനായില്ല';

  @override
  String get commuteYourRoutesHeading => 'നിങ്ങളുടെ വഴികൾ';

  @override
  String get commuteNonArrivalTitle => 'എത്താതിരിക്കൽ അലേർട്ട്';

  @override
  String commuteNonArrivalEnabledBody(String late) {
    return 'നിങ്ങൾ $late എത്തിയില്ലെങ്കിൽ, RoadPack ആദ്യം നിങ്ങളോട് ചോദിക്കും. നിങ്ങൾ മറുപടി നൽകാത്തപ്പോൾ മാത്രമേ നിങ്ങളുടെ സർക്കിളിനെ അറിയിക്കൂ.';
  }

  @override
  String get commuteNonArrivalDisabledBody =>
      'നിങ്ങൾ എത്തിയില്ലെങ്കിൽ ആരെയും അറിയിക്കില്ല.';

  @override
  String get commuteAskMeAfterHeading => 'എത്ര കഴിഞ്ഞ് ചോദിക്കണം';

  @override
  String commuteGraceWindowSemantics(String late) {
    return '$late വൈകി';
  }

  @override
  String commuteSpokenMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count മിനിറ്റ്',
      one: '1 മിനിറ്റ്',
    );
    return '$_temp0';
  }

  @override
  String commuteSpokenSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count സെക്കൻഡ്',
      one: '1 സെക്കൻഡ്',
    );
    return '$_temp0';
  }

  @override
  String get commuteEmptyTitle => 'ഇതുവരെ വഴികളൊന്നുമില്ല';

  @override
  String commuteEmptyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'സമാനമായ $count യാത്രകൾക്ക് ശേഷം RoadPack ഒരു യാത്രാ വഴി പഠിക്കും. കാത്തിരിക്കേണ്ട എന്നുണ്ടെങ്കിൽ സ്വയം ചേർക്കുക — ഇത് ഉടനെ പ്രവർത്തിക്കും.',
      one:
          'സമാനമായ 1 യാത്രയ്ക്ക് ശേഷം RoadPack ഒരു യാത്രാ വഴി പഠിക്കും. കാത്തിരിക്കേണ്ട എന്നുണ്ടെങ്കിൽ സ്വയം ചേർക്കുക — ഇത് ഉടനെ പ്രവർത്തിക്കും.',
    );
    return '$_temp0';
  }

  @override
  String get commuteDeleteRouteTooltip => 'വഴി നീക്കം ചെയ്യുക';

  @override
  String get commuteNameHint => 'വീട്ടിൽ നിന്ന് കോളേജിലേക്ക്';

  @override
  String get commuteNameValidation =>
      'നിങ്ങൾക്ക് തിരിച്ചറിയാൻ കഴിയുന്ന ഒരു പേര് നൽകുക';

  @override
  String get commuteSectionWhere => 'എവിടെ';

  @override
  String get commuteSectionWhen => 'എപ്പോൾ';

  @override
  String get commuteSectionDays => 'ദിവസങ്ങൾ';

  @override
  String get commuteStartPoint => 'തുടക്കം';

  @override
  String get commuteDestinationPoint => 'ലക്ഷ്യസ്ഥാനം';

  @override
  String get commuteLocationPermissionError =>
      'ഈ സ്ഥലം അടയാളപ്പെടുത്താൻ RoadPack-ന് ലൊക്കേഷൻ അനുമതി ആവശ്യമാണ്.';

  @override
  String get commuteLocationFixError =>
      'ഇവിടെ ലൊക്കേഷൻ ലഭ്യമായില്ല. പുറത്ത് പോയി വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get commuteIncompleteError =>
      'രണ്ട് സ്ഥലങ്ങളും, തുടങ്ങുന്ന സമയവും, കുറഞ്ഞത് ഒരു ദിവസവും സെറ്റ് ചെയ്യുക.';

  @override
  String get commuteDurationLabel => 'സാധാരണ എടുക്കുന്ന സമയം (മിനിറ്റ്)';

  @override
  String get commuteDurationEmptyValidation =>
      'ഈ യാത്ര സാധാരണ എത്ര നേരം എടുക്കും?';

  @override
  String get commuteDurationTooLongValidation =>
      'ഇത് ഒരു ദിവസത്തെ യാത്രയേക്കാൾ കൂടുതലാണ്';

  @override
  String get commuteSaveChanges => 'മാറ്റങ്ങൾ സേവ് ചെയ്യുക';

  @override
  String get commuteRouteIncompleteHint =>
      'ഈ വഴി നിങ്ങൾക്കായി ശ്രദ്ധിക്കാൻ തുടങ്ങുന്നതിന് മുൻപ് രണ്ട് സ്ഥലങ്ങളും, തുടങ്ങുന്ന സമയവും, കുറഞ്ഞത് ഒരു ദിവസവും ആവശ്യമാണ്.';

  @override
  String get commuteUsuallyLeavesAt => 'സാധാരണ പോകുന്ന സമയം';

  @override
  String get commutePointNotSet => 'സെറ്റ് ചെയ്തിട്ടില്ല';

  @override
  String get commuteUpdatePoint => 'പുതുക്കുക';

  @override
  String get commuteUseHerePoint => 'ഇവിടെ ഉപയോഗിക്കുക';

  @override
  String get commuteDeleteRouteTitle => 'ഈ വഴി നീക്കം ചെയ്യണോ?';

  @override
  String get commuteDeleteRouteBody =>
      'ഈ വഴിയിൽ എത്താതിരിക്കൽ ശ്രദ്ധിക്കുന്നത് RoadPack നിർത്തും.';

  @override
  String get commuteKeepAction => 'സൂക്ഷിക്കുക';

  @override
  String get commuteDeleteAction => 'നീക്കം ചെയ്യുക';

  @override
  String get commuteDayNameMonday => 'തിങ്കൾ';

  @override
  String get commuteDayNameTuesday => 'ചൊവ്വ';

  @override
  String get commuteDayNameWednesday => 'ബുധൻ';

  @override
  String get commuteDayNameThursday => 'വ്യാഴം';

  @override
  String get commuteDayNameFriday => 'വെള്ളി';

  @override
  String get commuteDayNameSaturday => 'ശനി';

  @override
  String get commuteDayNameSunday => 'ഞായർ';

  @override
  String get commuteDayLetterMon => 'തി';

  @override
  String get commuteDayLetterTue => 'ചൊ';

  @override
  String get commuteDayLetterWed => 'ബു';

  @override
  String get commuteDayLetterThu => 'വ്യാ';

  @override
  String get commuteDayLetterFri => 'വെ';

  @override
  String get commuteDayLetterSat => 'ശ';

  @override
  String get commuteDayLetterSun => 'ഞാ';

  @override
  String commuteDaysActiveSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ആഴ്ചയിൽ $count ദിവസം ആക്ടീവ്',
      one: 'ആഴ്ചയിൽ 1 ദിവസം ആക്ടീവ്',
      zero: 'ദിവസങ്ങൾ സെറ്റ് ചെയ്തിട്ടില്ല',
    );
    return '$_temp0';
  }

  @override
  String get commuteTimeToAnswerHeading => 'മറുപടി നൽകാനുള്ള സമയം';

  @override
  String commuteAnswerSemantics(String spoken) {
    return '$spoken കഴിഞ്ഞ് നിങ്ങളുടെ സർക്കിളിനെ അറിയിക്കും.';
  }

  @override
  String get commuteNothingToCheckIn => 'ചെക്ക്-ഇൻ ചെയ്യാൻ ഒന്നുമില്ല.';

  @override
  String get commuteCheckingInHeading => 'ചെക്ക്-ഇൻ ചെയ്യുന്നു';

  @override
  String get commuteCircleToldHeading => 'നിങ്ങളുടെ സർക്കിളിനെ അറിയിച്ചു';

  @override
  String get commuteEverythingOkay => 'എല്ലാം ശരിയാണോ?';

  @override
  String get commuteWeLetThemKnow => 'ഞങ്ങൾ അവരെ അറിയിച്ചു';

  @override
  String get commuteTravellingBody =>
      'നിങ്ങൾ സാധാരണ ലക്ഷ്യസ്ഥാനത്ത് എത്തിയിട്ടില്ല. ഇതുവരെ ആരെയും അറിയിച്ചിട്ടില്ല.';

  @override
  String get commuteEscalatedBody =>
      'നിങ്ങൾ മറുപടി നൽകാത്തതിനാൽ, നിങ്ങളുടെ സർക്കിളിന് അലേർട്ട് അയച്ചു. കഴിയുമ്പോൾ നിങ്ങൾ ശരിയാണെന്ന് അവരോട് പറയുക.';

  @override
  String get commuteAnswerCaption =>
      'നിങ്ങൾ മറുപടി നൽകിയില്ലെങ്കിൽ, നിങ്ങളുടെ സർക്കിളിനെ അറിയിക്കും.';

  @override
  String commuteSnoozeExtendedMessage(String minutes) {
    return 'സമയം $minutes കൂട്ടി. ആരെയും അറിയിച്ചിട്ടില്ല.';
  }

  @override
  String get commuteGladYouMadeIt => 'നിങ്ങൾ എത്തിയതിൽ സന്തോഷം.';

  @override
  String get commuteFineTellThem => 'എനിക്ക് കുഴപ്പമില്ല — അവരോട് പറയുക';

  @override
  String get commuteArrivedFine => 'ഞാൻ എത്തി, കുഴപ്പമില്ല';

  @override
  String get commuteNeedHelp => 'എനിക്ക് സഹായം വേണം';

  @override
  String get commuteAddedByYouBadge => 'നിങ്ങൾ ചേർത്തത്';

  @override
  String commuteTripsBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count യാത്രകൾ',
      one: '$count യാത്ര',
    );
    return '$_temp0';
  }

  @override
  String get commuteLeavesLabel => 'പോകുന്നത്';

  @override
  String get commuteTakesLabel => 'എടുക്കുന്നത്';

  @override
  String get commuteArrivesLabel => 'എത്തുന്നത്';

  @override
  String commuteLearningNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'ഇപ്പോഴും പഠിക്കുന്നു — ഈ വഴി ശ്രദ്ധിക്കാൻ തുടങ്ങുന്നതിന് മുൻപ് $count യാത്രകൾ കൂടി വേണം.',
      one:
          'ഇപ്പോഴും പഠിക്കുന്നു — ഈ വഴി ശ്രദ്ധിക്കാൻ തുടങ്ങുന്നതിന് മുൻപ് 1 യാത്ര കൂടി വേണം.',
    );
    return '$_temp0';
  }

  @override
  String get commuteNotWatchingTitle => 'ഈ വഴി ശ്രദ്ധിക്കുന്നില്ല';

  @override
  String get commuteWatchingOnceLearnedTitle => 'പഠിച്ച ശേഷം ശ്രദ്ധിക്കും';

  @override
  String commuteNeedsMoreTripsDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count യാത്രകൾ കൂടി വേണം',
      one: '1 യാത്ര കൂടി വേണം',
    );
    return '$_temp0';
  }

  @override
  String get commuteNotWatchingYetTitle => 'ഇതുവരെ ശ്രദ്ധിക്കുന്നില്ല';

  @override
  String get commuteMissingScheduleDetail =>
      'തുടങ്ങുന്ന സമയം, ദൈർഘ്യം അല്ലെങ്കിൽ ദിവസങ്ങൾ സെറ്റ് ചെയ്തിട്ടില്ല';

  @override
  String get commuteWatchingTitle => 'എത്താതിരിക്കൽ ശ്രദ്ധിക്കുന്നു';

  @override
  String get commuteRunningLateLabel => 'വൈകുന്നു';

  @override
  String get commuteMuchLaterLabel => 'വൈകും';

  @override
  String commuteSnoozeTrailing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count മിനിറ്റ്',
      one: '+1 മിനിറ്റ്',
    );
    return '$_temp0';
  }

  @override
  String get commuteNobodyToldCaption =>
      'ഇത് അമർത്തുമ്പോൾ ആരെയും അറിയിക്കുന്നില്ല.';

  @override
  String commuteSnoozeSemantics(String label, String trailing) {
    return '$label, $trailing. ആരെയും അറിയിക്കുന്നില്ല.';
  }

  @override
  String get consentCentreTitle => 'ഞാൻ സമ്മതിച്ച കാര്യങ്ങൾ';

  @override
  String get consentPermissionsHeading => 'നിങ്ങളുടെ അനുമതികൾ';

  @override
  String get consentPermissionsIntro =>
      'ഇവയിൽ ഏതും എപ്പോൾ വേണമെങ്കിലും ഓഫാക്കാം. ലൊക്കേഷൻ പങ്കിടൽ ഓഫാക്കിയാൽ RoadPack ഉടൻ തന്നെ നിങ്ങളെ ട്രാക്ക് ചെയ്യുന്നത് നിർത്തും.';

  @override
  String consentGrantedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'd MMMM yyyy',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return 'നിങ്ങൾ $dateString-ന് സമ്മതിച്ചു';
  }

  @override
  String get consentParentalSectionBody =>
      'ഒരു രക്ഷിതാവ് RoadPack നിങ്ങളെ ട്രാക്ക് ചെയ്യാൻ സമ്മതിച്ചിട്ടുണ്ട്. അവർക്കോ നിങ്ങൾക്കോ അത് എപ്പോൾ വേണമെങ്കിലും പിൻവലിക്കാം — RoadPack ഉടൻ ട്രാക്കിംഗ് നിർത്തും.';

  @override
  String get consentWithdrawParentalAction =>
      'രക്ഷിതാവിന്റെ അനുമതി പിൻവലിക്കുക';

  @override
  String get consentUnknownLedgerTitle =>
      'നിങ്ങളുടെ അനുമതികൾ പരിശോധിക്കാൻ കഴിഞ്ഞില്ല';

  @override
  String get consentUnknownLedgerBody =>
      'സെർവറുമായി ബന്ധപ്പെടാൻ കഴിയുന്നതുവരെ, നിങ്ങൾ ഒന്നിനും സമ്മതിച്ചിട്ടില്ല എന്ന് RoadPack കണക്കാക്കുകയും നിങ്ങളെ ട്രാക്ക് ചെയ്യാതിരിക്കുകയും ചെയ്യും.';

  @override
  String get consentChecking => 'പരിശോധിക്കുന്നു...';

  @override
  String get consentTryAgain => 'വീണ്ടും ശ്രമിക്കുക';

  @override
  String get consentTypeTrackingTitle =>
      'യാത്ര ചെയ്യുമ്പോൾ എന്റെ ലൊക്കേഷൻ പങ്കിടുക';

  @override
  String get consentTypeTrackingMeaning =>
      'യാത്ര നടക്കുമ്പോൾ നിങ്ങൾ എവിടെയാണെന്ന് RoadPack രേഖപ്പെടുത്തുന്നു, അപകടം സംഭവിച്ചാൽ നിങ്ങളുടെ സർക്കിളിന് നിങ്ങളെ കണ്ടെത്താൻ.';

  @override
  String get consentTypeDataSharingAnonTitle =>
      'റോഡ് സുരക്ഷാ മാപ്പുകൾ മെച്ചപ്പെടുത്താൻ സഹായിക്കുക';

  @override
  String get consentTypeDataSharingAnonMeaning =>
      'ഏകദേശമായ, പേരില്ലാത്ത ലൊക്കേഷൻ പോയിന്റുകൾ അപകടകരമായ ഭാഗങ്ങൾ അടയാളപ്പെടുത്താൻ സഹായിക്കുന്നു. ഇങ്ങനെ അയയ്ക്കുന്ന ഒന്നിലും നിങ്ങളുടെ പേരോ നമ്പറോ ഇല്ല.';

  @override
  String get consentTypeSensorUploadTitle =>
      'അപകടത്തിന് ശേഷം സെൻസർ വിവരങ്ങൾ അയയ്ക്കുക';

  @override
  String get consentTypeSensorUploadMeaning =>
      'അപകടത്തിന് ശേഷം ഫോൺ അതിന്റെ സെൻസറുകൾ അനുഭവിച്ചത് അയയ്ക്കുന്നു, കണ്ടെത്തൽ മെച്ചപ്പെടാൻ.';

  @override
  String get consentTypeParentalTitle => 'രക്ഷിതാവിന്റെ അനുമതി';

  @override
  String get consentTypeParentalMeaning =>
      'നിങ്ങൾക്ക് 18 വയസ്സ് തികഞ്ഞിട്ടില്ലാത്തതിനാൽ, RoadPack നിങ്ങളെ ട്രാക്ക് ചെയ്യുന്നതിന് മുൻപ് ഒരു രക്ഷിതാവ് സമ്മതിക്കണം.';

  @override
  String get consentTypeInstitutionalTitle =>
      'എന്റെ കോളേജുമായോ തൊഴിലുടമയുമായോ പങ്കിടുക';

  @override
  String get consentTypeInstitutionalMeaning =>
      'നിങ്ങളുടെ കോളേജോ തൊഴിലുടമയോ കൂട്ടായ കണക്കുകൾ മാത്രമേ കാണൂ — ഒരിക്കലും നിങ്ങളുടെ തത്സമയ സ്ഥാനമോ ബന്ധുക്കളെയോ അല്ല.';

  @override
  String get consentTypeAudioCaptureTitle =>
      'അപകടത്തിന് ശേഷം ഓഡിയോ റെക്കോർഡ് ചെയ്യുക';

  @override
  String get consentTypeAudioCaptureMeaning =>
      'അപകടത്തിന് ശേഷം ഫോണിന് ഒരു ചെറിയ ക്ലിപ്പ് റെക്കോർഡ് ചെയ്യാം, സഹായിക്കാൻ വരുന്നവർക്ക് സ്ഥിതി അറിയാൻ.';

  @override
  String get consentGateReadyTitle => 'RoadPack നിങ്ങളെ ശ്രദ്ധിക്കാൻ തയ്യാറാണ്';

  @override
  String get consentGateReadyBody =>
      'നിങ്ങളുടെ പ്രൊഫൈൽ പൂർണ്ണമാണ്, ലൊക്കേഷൻ പങ്കിടലിന് നിങ്ങൾ സമ്മതിച്ചിട്ടുമുണ്ട്. എന്നാലും 112 വിളിക്കുന്നതിന് പകരമാവില്ല RoadPack.';

  @override
  String get consentGateBlockedTitle =>
      'RoadPack ഇതുവരെ നിങ്ങളെ ട്രാക്ക് ചെയ്യുന്നില്ല';

  @override
  String get consentGateBlockedBody => 'ഇവ പൂർത്തിയാക്കിയാൽ അത് ചെയ്യും:';

  @override
  String get consentGateAskParentAction => 'ഒരു രക്ഷിതാവിനോട് ചോദിക്കുക';

  @override
  String get consentBlockerNameTitle => 'നിങ്ങളുടെ പേര് ചേർക്കുക';

  @override
  String get consentBlockerNameBody =>
      'ഞങ്ങൾ ആരെ വിളിച്ചാലും, ആരെക്കുറിച്ചാണ് വിളിക്കുന്നതെന്ന് അവർ അറിയണം.';

  @override
  String get consentBlockerPhoneTitle => 'നിങ്ങളുടെ ഫോൺ നമ്പർ ചേർക്കുക';

  @override
  String get consentBlockerPhoneBody =>
      'പ്രവർത്തിക്കുന്ന ഒരു നമ്പർ വേണം, സഹായിക്കുന്നവർക്ക് തിരികെ വിളിക്കാൻ.';

  @override
  String get consentBlockerContactTitle => 'ഒരു അടിയന്തര ബന്ധുവിനെ ചേർക്കുക';

  @override
  String get consentBlockerContactBody =>
      'അലേർട്ട് അയയ്ക്കാൻ RoadPack-ന് ആരുമില്ല. കുറഞ്ഞത് ഒരു ബന്ധുവെങ്കിലും വേണം.';

  @override
  String get consentBlockerDobTitle => 'നിങ്ങളുടെ ജനനത്തീയതി ചേർക്കുക';

  @override
  String get consentBlockerDobBody =>
      'നിയമം 18 വയസ്സിന് താഴെയുള്ളവരെ വ്യത്യസ്തമായാണ് കാണുന്നത്, അതിനാൽ നിങ്ങൾക്ക് ഏത് നിയമമാണ് ബാധകമെന്ന് അറിയണം.';

  @override
  String get consentBlockerParentalTitle => 'രക്ഷിതാവിന്റെ അനുമതി വേണം';

  @override
  String get consentBlockerParentalBody =>
      'നിങ്ങൾക്ക് 18 വയസ്സ് തികഞ്ഞിട്ടില്ല. നിങ്ങൾ എവിടെയാണെന്ന് RoadPack രേഖപ്പെടുത്തുന്നതിന് മുൻപ് ഒരു രക്ഷിതാവ് സമ്മതിക്കണം.';

  @override
  String get consentBlockerTrackingTitle => 'ലൊക്കേഷൻ പങ്കിടൽ ഓണാക്കുക';

  @override
  String get consentBlockerTrackingBody =>
      'നിങ്ങൾ സമ്മതിക്കുന്നതുവരെ RoadPack നിങ്ങളുടെ ലൊക്കേഷൻ രേഖപ്പെടുത്തുന്നില്ല, നിങ്ങൾ വേണ്ടെന്ന് പറയുന്ന നിമിഷം അത് നിർത്തും.';

  @override
  String get consentBlockerUnknownBody =>
      'നിങ്ങൾ എന്തിനൊക്കെ സമ്മതിച്ചു എന്ന് പരിശോധിക്കാൻ സെർവറിൽ എത്താൻ കഴിഞ്ഞില്ല. അതുവരെ RoadPack നിങ്ങളെ ട്രാക്ക് ചെയ്യില്ല.';

  @override
  String get consentParentalScreenTitle => 'രക്ഷിതാവിന്റെ അനുമതി';

  @override
  String get consentParentalFormIntro =>
      'നിങ്ങൾക്ക് 18 വയസ്സ് തികഞ്ഞിട്ടില്ല, അതിനാൽ നിങ്ങൾ എവിടെയാണെന്ന് RoadPack രേഖപ്പെടുത്തുന്നതിന് മുൻപ് ഒരു രക്ഷിതാവ് സമ്മതിക്കണം. അതുവരെ ഒന്നും ട്രാക്ക് ചെയ്യില്ല.';

  @override
  String get consentParentalNameLabel => 'രക്ഷിതാവിന്റെ പേര്';

  @override
  String get consentParentalPhoneLabel => 'അവരുടെ ഫോൺ നമ്പർ';

  @override
  String get consentParentalRelationLabel => 'നിങ്ങളുമായുള്ള അവരുടെ ബന്ധം';

  @override
  String get consentParentalRelationHint => 'അമ്മ, അച്ഛൻ, രക്ഷിതാവ്';

  @override
  String consentParentalMethodLine(String method) {
    return 'അവരെ എങ്ങനെ ഉറപ്പാക്കുന്നു: $method';
  }

  @override
  String get consentParentalSubmitAction =>
      'സ്ഥിരീകരിക്കാൻ അവരോട് ആവശ്യപ്പെടുക';

  @override
  String get consentVerifierNotAvailable =>
      'ഇതുവരെ ലഭ്യമല്ല. ഒരു രക്ഷിതാവിനെ ശരിയായി ഉറപ്പാക്കാൻ കഴിയുന്നതുവരെ RoadPack 18 വയസ്സിന് താഴെയുള്ളവരെ ട്രാക്ക് ചെയ്യില്ല.';

  @override
  String get consentParentalConfirmed => 'രക്ഷിതാവിനെ സ്ഥിരീകരിച്ചു.';

  @override
  String get consentParentalNotConfigured =>
      'RoadPack-ന് ഇതുവരെ ഒരു രക്ഷിതാവിനെ സ്ഥിരീകരിക്കാൻ കഴിയില്ല, അതിനാൽ 18 വയസ്സിന് താഴെയുള്ളവരെ ട്രാക്ക് ചെയ്യില്ല. ബാക്കിയെല്ലാം പ്രവർത്തിക്കുന്നുണ്ട്.';

  @override
  String get consentParentalIncomplete =>
      'ദയവായി നിങ്ങളുടെ രക്ഷിതാവിന്റെ പേര്, നമ്പർ, നിങ്ങളുമായുള്ള ബന്ധം എന്നിവ പൂരിപ്പിക്കുക.';

  @override
  String get consentParentalVerificationFailed =>
      'ആ നമ്പർ സ്ഥിരീകരിക്കാൻ കഴിഞ്ഞില്ല. വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get consentParentalUnavailable =>
      'സെർവറിൽ എത്താൻ കഴിഞ്ഞില്ല. അതുവരെ RoadPack 18 വയസ്സിന് താഴെയുള്ളവരെ ട്രാക്ക് ചെയ്യില്ല.';

  @override
  String get consentTrackingNotPermitted =>
      'RoadPack-ന് ഇതുവരെ ട്രാക്കിംഗ് തുടങ്ങാനാകില്ല';

  @override
  String consentWatcherReason(String type, String circleName) {
    return 'നിങ്ങളുടെ $type സർക്കിളായ \"$circleName\"-ൽ, ആ സർക്കിളിന്റെ ലൊക്കേഷൻ പങ്കിടൽ ഓണാണ്.';
  }

  @override
  String get contactsAddButton => 'ബന്ധുവിനെ ചേർക്കുക';

  @override
  String get contactsLoadError => 'നിങ്ങളുടെ ബന്ധുക്കളെ ലോഡ് ചെയ്യാനായില്ല';

  @override
  String get contactsRetry => 'വീണ്ടും ശ്രമിക്കുക';

  @override
  String get contactsEmptyHint =>
      'ട്രാക്കിംഗ് തുടങ്ങുന്നതിന് മുൻപ് ചുരുങ്ങിയത് ഒരു ബന്ധുവിനെ ചേർക്കുക.';

  @override
  String get contactsOrderHint =>
      'ഈ ക്രമത്തിലാണ് ഞങ്ങൾ അവരെ വിളിക്കുന്നത്. ക്രമം മാറ്റാൻ വലിച്ചിടുക.';

  @override
  String contactsCountOfMax(int count, int max) {
    return '$max-ൽ $count ലിസ്റ്റ് ചെയ്തിട്ടുണ്ട്';
  }

  @override
  String get contactsEmptyBody =>
      'ഇതുവരെ ആരെയും ചേർത്തിട്ടില്ല.\nഅയയ്ക്കാൻ ആരുമില്ലാത്ത അലേർട്ട് സംരക്ഷണമല്ല.';

  @override
  String contactsRemoveConfirmTitle(String name) {
    return '$name-നെ നീക്കം ചെയ്യണോ?';
  }

  @override
  String get contactsRemoveConfirmBody =>
      'നിങ്ങൾക്ക് എന്തെങ്കിലും സംഭവിച്ചാൽ ഇനി അവർക്ക് അലേർട്ട് പോകില്ല.';

  @override
  String get contactsCancel => 'റദ്ദാക്കുക';

  @override
  String get contactsRemoveButton => 'നീക്കം ചെയ്യുക';

  @override
  String get contactsEditTitle => 'അടിയന്തര ബന്ധുവിനെ തിരുത്തുക';

  @override
  String get contactsAddTitle => 'അടിയന്തര ബന്ധുവിനെ ചേർക്കുക';

  @override
  String get contactsPhoneLabel => 'മൊബൈൽ നമ്പർ';

  @override
  String get contactsRelationshipLabel => 'ബന്ധം (ഓപ്ഷണൽ)';

  @override
  String get contactsHowWeReachThem => 'ഞങ്ങൾ അവരെ എങ്ങനെ ബന്ധപ്പെടും';

  @override
  String get contactsEditHint =>
      'ഇവിടെ നമ്പർ ശരിയാക്കുന്നത് അവർക്ക് നേരത്തെ അയച്ച അറിയിപ്പ് വീണ്ടും അയക്കില്ല.';

  @override
  String get contactsAddHint =>
      'അവർ ലിസ്റ്റ് ചെയ്യപ്പെട്ടിരിക്കുന്നു എന്ന് അറിയിക്കുന്ന ഒരു SMS അവർക്ക് ലഭിക്കും, അതിൽ നിന്ന് ഒഴിവാകാനും കഴിയും. എന്തെങ്കിലും സംഭവിക്കാതെ ഞങ്ങൾ വീണ്ടും അവർക്ക് സന്ദേശം അയക്കില്ല.';

  @override
  String get contactsSaveButton => 'മാറ്റങ്ങൾ സേവ് ചെയ്യുക';

  @override
  String contactsRemoveTooltip(String name) {
    return '$name-നെ നീക്കം ചെയ്യുക';
  }

  @override
  String get contactsOptedOut => 'SMS-ൽ നിന്ന് ഒഴിവായി';

  @override
  String get contactsNoticeSent => 'ലിസ്റ്റ് ചെയ്തിട്ടുണ്ടെന്ന് അവരെ അറിയിച്ചു';

  @override
  String get contactsNoticePending => 'അറിയിപ്പ് ഇതുവരെ അയച്ചിട്ടില്ല';

  @override
  String get iceScreenTitle => 'അടിയന്തര കാർഡ്';

  @override
  String get iceSealedEyebrow => 'നിങ്ങളുടെ കാർഡ് അടച്ചിരിക്കുന്നു';

  @override
  String get iceSealedBody =>
      'നിങ്ങളുടെ രക്തഗ്രൂപ്പ്, മെഡിക്കൽ വിവരങ്ങൾ, ബന്ധുക്കൾ എന്നിവ ഒരു വഴിയാത്രക്കാരന് കാണിക്കുന്നത് അടിയന്തരാവസ്ഥ സജീവമായിരിക്കുമ്പോൾ മാത്രമാണ് — അല്ലെങ്കിൽ, നിങ്ങൾ അത് ഓണാക്കിയാൽ, യാത്ര ചെയ്യുമ്പോഴും. ആർക്കും സ്കാൻ ചെയ്യാൻ എപ്പോഴും-ഓണായ കോഡ് ഇല്ല.';

  @override
  String get iceBandHeading => 'ഈ വ്യക്തിക്ക് സഹായം വേണ്ടിവരാം';

  @override
  String get iceLabelCallThese => 'ഇവരെ വിളിക്കുക';

  @override
  String get iceNoContacts => 'ബന്ധുക്കളാരും ലിസ്റ്റ് ചെയ്തിട്ടില്ല';

  @override
  String get iceDisclaimer =>
      'RoadPack ഈ റൈഡറുടെ സർക്കിളിന് അലേർട്ട് അയക്കുന്നു. ഇത് ആംബുലൻസിനെ വിളിക്കുന്നില്ല. അടിയന്തര സേവനങ്ങൾക്ക് 112 ഡയൽ ചെയ്യുക.';

  @override
  String get iceBloodGroupMissing => 'രേഖപ്പെടുത്തിയിട്ടില്ല';

  @override
  String mapCacheReadError(String message) {
    return 'കാഷ് വായിക്കാൻ കഴിഞ്ഞില്ല: $message';
  }

  @override
  String mapRoutesReadError(String message) {
    return 'നിങ്ങളുടെ വഴികൾ വായിക്കാൻ കഴിഞ്ഞില്ല: $message';
  }

  @override
  String get mapYourRoutesEyebrow => 'നിങ്ങളുടെ വഴികൾ';

  @override
  String get mapNoRoutesLearned =>
      'ഇതുവരെ ഒരു വഴിയും പഠിച്ചിട്ടില്ല. നിങ്ങൾ യഥാർത്ഥത്തിൽ പോകുന്ന യാത്രകളിൽ നിന്ന് RoadPack നിങ്ങളുടെ സ്ഥിരം വഴികൾ കണ്ടെത്തും.';

  @override
  String get mapStoredOnPhoneEyebrow => 'ഈ ഫോണിൽ സേവ് ചെയ്തത്';

  @override
  String mapTileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ടൈലുകൾ',
      one: '1 ടൈൽ',
    );
    return '$_temp0';
  }

  @override
  String get mapCacheInMemoryOnlyNotice =>
      'ഈ കാഷ് മെമ്മറിയിൽ മാത്രമാണ്, ആപ്പ് വീണ്ടും തുടങ്ങുമ്പോൾ ഇത് ഒഴിഞ്ഞുപോകും.';

  @override
  String get mapClearCachedDataButton =>
      'കാഷ് ചെയ്ത മാപ്പ് ഡേറ്റ നീക്കം ചെയ്യുക';

  @override
  String mapRegionCoverageLine(
    int tiles,
    int zoomLevels,
    String estimatedSize,
    int bufferKm,
  ) {
    return '$zoomLevels സൂം ലെവലുകളിലായി $tiles ടൈലുകൾ · ഏകദേശം $estimatedSize കണക്കാക്കിയത് · $bufferKm കി.മീ ബഫർ';
  }

  @override
  String mapRegionCoverageLineCorridor(
    int tiles,
    int zoomLevels,
    String estimatedSize,
    int bufferKm,
  ) {
    return '$zoomLevels സൂം ലെവലുകളിലായി $tiles ടൈലുകൾ · ഏകദേശം $estimatedSize കണക്കാക്കിയത് · $bufferKm കി.മീ ബഫർ · കോറിഡോർ തുടക്കവും അവസാനവും മാത്രം വച്ച് കണക്കാക്കിയത്';
  }

  @override
  String get mapOfflineNoticeText =>
      'സ്ഥാനങ്ങൾ പുതുക്കാൻ കഴിഞ്ഞില്ല. ഈ മാപ്പിലുള്ളതൊന്നും ഓരോ അംഗത്തിനും കാണിച്ചിരിക്കുന്ന പഴക്കത്തിലും പുതിയതല്ല.';

  @override
  String get mapEmptyNoticeText =>
      'ആരും നിങ്ങളുമായി ലൊക്കേഷൻ പങ്കിടുന്നില്ല. ലൊക്കേഷൻ പങ്കിടൽ ഓരോ സർക്കിളിന്റെയും സ്വന്തം ക്രമീകരണമാണ്, ഓരോ അംഗവും അവരവരുടേത് നിയന്ത്രിക്കുന്നു.';

  @override
  String mapStaleBannerBoth(int unreachableCount, int staleCount) {
    String _temp0 = intl.Intl.pluralLogic(
      unreachableCount,
      locale: localeName,
      other: '$unreachableCount പേർക്ക് സിഗ്നൽ ഇല്ല',
      one: '1 പേർക്ക് സിഗ്നൽ ഇല്ല',
    );
    String _temp1 = intl.Intl.pluralLogic(
      staleCount,
      locale: localeName,
      other: '$staleCount പുതുക്കുന്നില്ല',
      one: '1 പുതുക്കുന്നില്ല',
    );
    return '$_temp0, $_temp1 — ഈ മാർക്കറുകൾ അവർ എവിടെയായിരുന്നു എന്ന് കാണിക്കുന്നു, ഇപ്പോൾ എവിടെയാണെന്നല്ല.';
  }

  @override
  String mapStaleBannerNoSignalOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count പേർക്ക് സിഗ്നൽ ഇല്ല',
      one: '1 പേർക്ക് സിഗ്നൽ ഇല്ല',
    );
    return '$_temp0 — ഈ മാർക്കറുകൾ അവർ എവിടെയായിരുന്നു എന്ന് കാണിക്കുന്നു, ഇപ്പോൾ എവിടെയാണെന്നല്ല.';
  }

  @override
  String mapStaleBannerNotUpdatingOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count പുതുക്കുന്നില്ല',
      one: '1 പുതുക്കുന്നില്ല',
    );
    return '$_temp0 — ഈ മാർക്കറുകൾ അവർ എവിടെയായിരുന്നു എന്ന് കാണിക്കുന്നു, ഇപ്പോൾ എവിടെയാണെന്നല്ല.';
  }

  @override
  String get mapLastUpdateLabel => 'അവസാന അപ്‌ഡേറ്റ്';

  @override
  String get mapSpeedLabel => 'വേഗത';

  @override
  String get mapBatteryLabel => 'ബാറ്ററി';

  @override
  String mapLastUpdateValue(String duration) {
    return '$duration മുൻപ്';
  }

  @override
  String mapSpeedValue(int speed) {
    return '$speed km/h';
  }

  @override
  String get mapSpeedNotCurrent => 'ഇപ്പോഴത്തേതല്ല';

  @override
  String get mapSpeedUnknown => 'അറിയില്ല';

  @override
  String mapBatteryValue(int battery) {
    return '$battery%';
  }

  @override
  String get mapFootnoteLocating =>
      'ഈ അംഗത്തിനായി മാപ്പിൽ ഇപ്പോൾ ഒന്നും കാണിക്കുന്നില്ല.';

  @override
  String get mapFootnoteLive =>
      'ഒരു സംഭവവും സഹായം അറിയുന്നതും തമ്മിലുള്ള ഇടവേള RoadPack കുറയ്ക്കുന്നു. ഇത് ആരെയും അയക്കുന്നില്ല. അടിയന്തരാവസ്ഥയിൽ 112-ൽ വിളിക്കുക.';

  @override
  String get mapFootnoteStale =>
      'പുതിയ ലൊക്കേഷൻ ഒന്നും ലഭിക്കാത്തതിനാൽ മാർക്കർ നീങ്ങിയിട്ടില്ല. അവർ ഇപ്പോൾ എവിടെയാണെന്നതിന്റെ ഒരു ഊഹമല്ല ഇത്.';

  @override
  String get mapPresenceLocating => 'സ്ഥാനം കണ്ടെത്തുന്നു';

  @override
  String get mapPresenceLive => 'ലൈവ്';

  @override
  String get mapPresenceStopped => 'നിർത്തിയിരിക്കുന്നു';

  @override
  String get mapPresenceNoSignal => 'സിഗ്നൽ ഇല്ല';

  @override
  String mapPresenceLastSeen(String age) {
    return 'അവസാനം കണ്ടത് $age മുൻപ്';
  }

  @override
  String mapAgeLabel(String age) {
    return 'അവസാനം കണ്ടത് $age മുൻപ്';
  }

  @override
  String get mapPresenceDetailLocating =>
      'ഈ ഉപകരണത്തിൽ നിന്ന് ആദ്യ സ്ഥാനവിവരത്തിനായി കാത്തിരിക്കുന്നു.';

  @override
  String mapPresenceDetailLive(String age) {
    return 'സ്ഥാനം $age മുൻപ് പുതുക്കി.';
  }

  @override
  String get mapPresenceDetailStopped => 'വിവരം വരുന്നുണ്ട്, പക്ഷേ ചലനമില്ല.';

  @override
  String get mapPresenceDetailStale =>
      'ഇത് അവർ ഉണ്ടായിരുന്ന സ്ഥലമാണ്, ഇപ്പോൾ ഉള്ള സ്ഥലമല്ല.';

  @override
  String mapPresenceDetailUnreachable(String age) {
    return '$age ആയി ഒന്നും ലഭിച്ചിട്ടില്ല. അവസാനം അറിഞ്ഞ സ്ഥാനമാണ് കാണിക്കുന്നത്.';
  }

  @override
  String get mapRegionStatusNotDownloaded => 'ഡൗൺലോഡ് ചെയ്തിട്ടില്ല';

  @override
  String get mapRegionStatusDownloading => 'ഡൗൺലോഡ് ചെയ്യുന്നു';

  @override
  String get mapRegionStatusDownloaded => 'ഡൗൺലോഡ് ചെയ്തു';

  @override
  String get mapRegionStatusFailed => 'പരാജയപ്പെട്ടു';

  @override
  String get mapOfflineLimitationNotice =>
      'ഓഫ്‌ലൈൻ പ്രദേശങ്ങൾ ആസൂത്രണം ചെയ്ത് അളന്നിട്ടുണ്ട്, പക്ഷേ അടിസ്ഥാന മാപ്പിന് ഇപ്പോഴും കണക്ഷൻ വേണം. Google Maps അതിന്റെ സ്വന്തം SDK-യിലാണ് ടൈലുകൾ വരയ്ക്കുന്നത്, അവ മുൻകൂട്ടി ലോഡ് ചെയ്യാൻ ആപ്പിന് വഴിയില്ല. സ്വന്തം OSM ടൈൽ സ്രോതസ്സിലേക്ക് മാറുമ്പോൾ മാത്രമേ ഓഫ്‌ലൈൻ മാപ്പുകൾ ശരിക്കും പ്രവർത്തിക്കൂ.';

  @override
  String get packCreateTitle => 'ഒരുമിച്ചുള്ള യാത്ര തുടങ്ങുക';

  @override
  String get packDestinationInvalid =>
      'ലക്ഷ്യസ്ഥാനം അക്ഷാംശം, രേഖാംശം ആയി നൽകുക';

  @override
  String get packRideNameLabel => 'യാത്രയുടെ പേര് (ഓപ്ഷണൽ)';

  @override
  String get packRideNameHint => 'മൂന്നാർ റൺ';

  @override
  String get packCircleLabel => 'സർക്കിൾ (ഓപ്ഷണൽ)';

  @override
  String get packCircleHelper => 'ഈ സർക്കിളിലെ അംഗങ്ങൾക്ക് ഈ യാത്ര കണ്ടെത്താം';

  @override
  String get packNoCircleOption => 'സർക്കിൾ ഇല്ല';

  @override
  String get packDestinationHeading => 'ലക്ഷ്യസ്ഥാനം';

  @override
  String get packLatitudeLabel => 'അക്ഷാംശം';

  @override
  String get packLongitudeLabel => 'രേഖാംശം';

  @override
  String get packCreateShareNotice =>
      'ചേരുന്ന എല്ലാവരും യാത്ര അവസാനിക്കുന്നതു വരെ — പരമാവധി 12 മണിക്കൂർ വരെ — തങ്ങളുടെ സ്ഥാനം പായ്ക്കുമായി പങ്കിടും. RoadPack സഹായത്തിനായി സ്വയം വിളിക്കില്ല — അടിയന്തരാവസ്ഥയിൽ 112 വിളിക്കുക.';

  @override
  String get packCreateSubmit => 'യാത്ര ഉണ്ടാക്കുക';

  @override
  String get packPasteLinkError => 'ആരെങ്കിലും അയച്ച ലിങ്ക് പേസ്റ്റ് ചെയ്യുക';

  @override
  String get packShareLinkLabel => 'ഷെയർ ലിങ്ക്';

  @override
  String get packJoinNotice =>
      'നിങ്ങൾ ചേരുമ്പോൾ, യാത്ര അവസാനിക്കുന്നതു വരെ വഴിയിൽ നിങ്ങൾ എവിടെയാണെന്ന് പായ്ക്ക് കാണും. നിങ്ങൾക്ക് എപ്പോൾ വേണമെങ്കിലും വിടാം, വിട്ടാൽ നിങ്ങളെ ഉടൻ നീക്കും.';

  @override
  String get packJoinSubmit => 'യാത്രയിൽ ചേരുക';

  @override
  String get packDefaultRideName => 'പായ്ക്ക്';

  @override
  String get packEndRideAction => 'യാത്ര അവസാനിപ്പിക്കുക';

  @override
  String get packTellPack => 'പായ്ക്കിനെ അറിയിക്കുക';

  @override
  String get packEmptyRoster =>
      'ഇതുവരെ ആരും ചേർന്നിട്ടില്ല. പായ്ക്ക് നിറയ്ക്കാൻ ലിങ്ക് ഷെയർ ചെയ്യുക.';

  @override
  String get packEndRideConfirmTitle => 'ഈ യാത്ര അവസാനിപ്പിക്കണോ?';

  @override
  String get packEndRideConfirmBody =>
      'എല്ലാവരുടെയും ഷെയറിംഗ് നിലയ്ക്കും, ലിങ്ക് ഉടനടി പ്രവർത്തിക്കാതാകും. ഇത് തിരിച്ചെടുക്കാൻ കഴിയില്ല.';

  @override
  String get packKeepRidingAction => 'യാത്ര തുടരുക';

  @override
  String get packAddNoteAction => 'കുറിപ്പ് ചേർക്കുക (ഓപ്ഷണൽ)';

  @override
  String get packNoteLabel => 'കുറിപ്പ്';

  @override
  String get packNoteHint => 'ടയർ പഞ്ചർ, 20 മിനിറ്റ്';

  @override
  String get packShareHonestyNotice =>
      'RoadPack നിങ്ങൾ എവിടെയാണെന്ന് പങ്കിടുന്നു. ഇത് സഹായത്തിനായി വിളിക്കില്ല — അടിയന്തരാവസ്ഥയിൽ 112 വിളിക്കുക.';

  @override
  String get packStatusRiding => 'യാത്രയിൽ';

  @override
  String get packStatusRefueling => 'ഇന്ധനം';

  @override
  String get packStatusTakingBreak => 'വിശ്രമം';

  @override
  String get packStatusWrongTurn => 'വഴി തെറ്റി';

  @override
  String get packStatusWaiting => 'കാത്തിരിപ്പ്';

  @override
  String get packStatusStopped => 'നിർത്തി';

  @override
  String get packStatusDone => 'പൂർത്തിയായി';

  @override
  String get packStatusUnexplainedStop => 'അകാരണമായി നിർത്തി';

  @override
  String get packStatusUnreachable => 'സിഗ്നൽ ഇല്ല';

  @override
  String get packStatusPossibleIncident => 'സാധ്യമായ സംഭവം';

  @override
  String get packAutoTag => 'സ്വയം';

  @override
  String get packRoleLeader => 'നായകൻ';

  @override
  String get packRoleSweep => 'സ്വീപ്പ്';

  @override
  String get packRoleRider => 'യാത്രക്കാരൻ';

  @override
  String get packGapFront => 'മുന്നിൽ';

  @override
  String get packOffRouteHeadline => 'വഴിയിൽ നിന്ന് മാറി';

  @override
  String get packLastSeenHeadline => 'അവസാനം കണ്ടത്';

  @override
  String get packLocatingHeadline => 'സ്ഥാനം കണ്ടെത്തുന്നു';

  @override
  String get packStraightLineUnknown => 'നേർരേഖ ദൂരം അറിയില്ല';

  @override
  String packDistanceAway(String distance) {
    return '$distance അകലെ';
  }

  @override
  String get packNoFixYet => 'ഇതുവരെ സ്ഥാനം ലഭിച്ചിട്ടില്ല';

  @override
  String get packJustNow => 'ഇപ്പോൾ';

  @override
  String packAgoCompact(String duration) {
    return '$duration മുമ്പ്';
  }

  @override
  String get packBehindLabel => 'പിന്നിൽ';

  @override
  String get packBehindLabelEst => 'ഏകദേശം പിന്നിൽ';

  @override
  String packBehindWithDuration(String duration) {
    return '$duration പിന്നിൽ';
  }

  @override
  String packBehindWithDurationEst(String duration) {
    return '$duration ഏകദേശം പിന്നിൽ';
  }

  @override
  String get packYouLabel => 'നിങ്ങൾ';

  @override
  String packNameYouSuffix(String name) {
    return '$name (നിങ്ങൾ)';
  }

  @override
  String get packSharingLiveHeadline => 'ഈ യാത്ര ഷെയർ ചെയ്യുന്നു';

  @override
  String get packSharingOffHeadline => 'ഷെയറിംഗ് ഓഫാണ്';

  @override
  String packLiveNotice(String expiry) {
    return 'ലിങ്ക് ഉള്ള ആർക്കും $expiry വരെ പായ്ക്ക് എവിടെയാണെന്ന് കാണാം. യാത്രക്കാർക്ക് കാണുന്നവരുടെ എണ്ണം കാണാം.';
  }

  @override
  String get packLinkExpiredNotice =>
      'ലിങ്ക് ഇനി പ്രവർത്തിക്കുന്നില്ല. ഈ യാത്ര ആർക്കും കാണാൻ കഴിയില്ല.';

  @override
  String get packExpiresNow => 'ഇപ്പോൾ';

  @override
  String packExpiresInHours(int hours) {
    return '$hours മണിക്കൂറിൽ അവസാനിക്കും';
  }

  @override
  String packExpiresInMinutes(int minutes) {
    return '$minutes മിനിറ്റിൽ അവസാനിക്കും';
  }

  @override
  String get packShareLinkAction => 'ലിങ്ക് ഷെയർ ചെയ്യുക';

  @override
  String get packCopyLinkTooltip => 'ലിങ്ക് കോപ്പി ചെയ്യുക';

  @override
  String get packStopSharingAction => 'ഷെയറിംഗ് നിർത്തുക';

  @override
  String get packLinkCopiedSnackbar => 'ലിങ്ക് കോപ്പി ചെയ്തു';

  @override
  String get packDefaultShareRideName => 'നമ്മുടെ യാത്ര';

  @override
  String packShareMessage(String name, String url) {
    return '$name-നെ ലൈവ് ആയി പിന്തുടരുക: $url\n\nRoadPack പായ്ക്ക് എവിടെയാണെന്ന് കാണിക്കുന്നു. ഇത് ആംബുലൻസിനെ വിളിക്കില്ല — അടിയന്തരാവസ്ഥയിൽ 112 വിളിക്കുക.';
  }

  @override
  String packWatchingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count പേർ കാണുന്നു',
      one: '1 പേർ കാണുന്നു',
    );
    return '$_temp0';
  }

  @override
  String get packNotShared => 'ഷെയർ ചെയ്യുന്നില്ല';
}
