import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ml.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('en'),
    Locale('hi'),
    Locale('ml'),
  ];

  /// Product name. Not translated.
  ///
  /// In en, this message translates to:
  /// **'RoadPack'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get commonClose;

  /// Cancels a live countdown. The most important button in the app.
  ///
  /// In en, this message translates to:
  /// **'I\'M OKAY'**
  String get commonImOkay;

  /// No description provided for @commonOn.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get commonOff;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get commonSelect;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get commonNotSignedIn;

  /// Generic failure line. {message} is untranslated technical detail.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String commonError(String message);

  /// Reviewed copy, shared with BystanderCopy.dial112.
  ///
  /// In en, this message translates to:
  /// **'Call 112'**
  String get commonCall112;

  /// Latin script in every language: it is the mark on the button.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get sosLabel;

  /// No description provided for @sosAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'SOS ALERT'**
  String get sosAlertTitle;

  /// No description provided for @sosHoldHint.
  ///
  /// In en, this message translates to:
  /// **'Hold for 2 seconds to trigger SOS'**
  String get sosHoldHint;

  /// No description provided for @sosCountdownBody.
  ///
  /// In en, this message translates to:
  /// **'Emergency alerts will be sent to your contacts'**
  String get sosCountdownBody;

  /// No description provided for @sosSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Alerts Sent'**
  String get sosSentTitle;

  /// No description provided for @sosSentBody.
  ///
  /// In en, this message translates to:
  /// **'Your emergency contacts are being notified.'**
  String get sosSentBody;

  /// No description provided for @incidentResolvedTitle.
  ///
  /// In en, this message translates to:
  /// **'Incident Resolved'**
  String get incidentResolvedTitle;

  /// No description provided for @incidentResolvedBody.
  ///
  /// In en, this message translates to:
  /// **'Your contacts have been notified that you are safe.'**
  String get incidentResolvedBody;

  /// Short incident id, shown so a rider can quote it.
  ///
  /// In en, this message translates to:
  /// **'Incident: {ref}'**
  String incidentRef(String ref);

  /// No description provided for @crashDetectedTitle.
  ///
  /// In en, this message translates to:
  /// **'CRASH DETECTED'**
  String get crashDetectedTitle;

  /// Live countdown on the crash screen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Alerting your emergency contacts in 1 second} other{Alerting your emergency contacts in {count} seconds}}'**
  String crashCountdownBody(int count);

  /// No description provided for @crashAlertSentTitle.
  ///
  /// In en, this message translates to:
  /// **'CRASH ALERT SENT'**
  String get crashAlertSentTitle;

  /// No description provided for @crashAlertSentBody.
  ///
  /// In en, this message translates to:
  /// **'Your emergency contacts have been notified of a possible crash.'**
  String get crashAlertSentBody;

  /// No description provided for @crashReasonQuestion.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get crashReasonQuestion;

  /// No description provided for @crashReasonPothole.
  ///
  /// In en, this message translates to:
  /// **'Pothole / speed bump'**
  String get crashReasonPothole;

  /// No description provided for @crashReasonPhoneDropped.
  ///
  /// In en, this message translates to:
  /// **'Phone dropped'**
  String get crashReasonPhoneDropped;

  /// No description provided for @crashReasonSuddenBraking.
  ///
  /// In en, this message translates to:
  /// **'Sudden braking'**
  String get crashReasonSuddenBraking;

  /// No description provided for @crashReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get crashReasonOther;

  /// No description provided for @crashReasonOtherHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened'**
  String get crashReasonOtherHint;

  /// No description provided for @crashReasonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm - I\'m Fine'**
  String get crashReasonConfirm;

  /// No description provided for @alertTitle.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get alertTitle;

  /// No description provided for @alertNotFound.
  ///
  /// In en, this message translates to:
  /// **'Alert not found'**
  String get alertNotFound;

  /// No description provided for @alertDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Alert'**
  String get alertDetailTitle;

  /// Headline of an alert received about somebody else.
  ///
  /// In en, this message translates to:
  /// **'{name} may have been in an accident'**
  String alertVictimHeadline(String name);

  /// No description provided for @alertLocationLine.
  ///
  /// In en, this message translates to:
  /// **'Location: {lat}, {lng}'**
  String alertLocationLine(String lat, String lng);

  /// No description provided for @alertTimeLine.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String alertTimeLine(DateTime time);

  /// Tells the cascade a human has seen this alert.
  ///
  /// In en, this message translates to:
  /// **'ACKNOWLEDGE'**
  String get alertAcknowledge;

  /// No description provided for @alertAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get alertAcknowledged;

  /// No description provided for @alertCallPerson.
  ///
  /// In en, this message translates to:
  /// **'Call {name}'**
  String alertCallPerson(String name);

  /// No description provided for @alertOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get alertOpenInMaps;

  /// No description provided for @alertCardTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} — Emergency'**
  String alertCardTitle(String name);

  /// No description provided for @alertCardTapToView.
  ///
  /// In en, this message translates to:
  /// **'Tap to view and acknowledge'**
  String get alertCardTapToView;

  /// No description provided for @homeSwitchToNight.
  ///
  /// In en, this message translates to:
  /// **'Switch to night'**
  String get homeSwitchToNight;

  /// No description provided for @homeSwitchToSunlight.
  ///
  /// In en, this message translates to:
  /// **'Switch to sunlight'**
  String get homeSwitchToSunlight;

  /// No description provided for @protectionEyebrow.
  ///
  /// In en, this message translates to:
  /// **'PROTECTION'**
  String get protectionEyebrow;

  /// Checklist column. The newline is a deliberate two-line wrap.
  ///
  /// In en, this message translates to:
  /// **'Crash\ndetection'**
  String get checkCrashDetection;

  /// No description provided for @checkLocationTracking.
  ///
  /// In en, this message translates to:
  /// **'Location\ntracking'**
  String get checkLocationTracking;

  /// No description provided for @checkNonArrival.
  ///
  /// In en, this message translates to:
  /// **'Non-arrival\nalerts'**
  String get checkNonArrival;

  /// No description provided for @checkEmergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Emergency\ncontact'**
  String get checkEmergencyContact;

  /// Screen-reader label for a checklist column.
  ///
  /// In en, this message translates to:
  /// **'{label}: {state}'**
  String checkSemantics(String label, String state);

  /// No description provided for @watchersHeading.
  ///
  /// In en, this message translates to:
  /// **'WHO IS WATCHING'**
  String get watchersHeading;

  /// No description provided for @watchersError.
  ///
  /// In en, this message translates to:
  /// **'Circles could not load. Pull down to try again.'**
  String get watchersError;

  /// No description provided for @watchersEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody yet. A circle is who gets called when you cannot call.'**
  String get watchersEmpty;

  /// No description provided for @watchersCreateCircle.
  ///
  /// In en, this message translates to:
  /// **'Create a circle'**
  String get watchersCreateCircle;

  /// Count of circles watching. Number and word are styled separately in the widget; this key is the word only fallback.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count}  circle} other{{count}  circles}}'**
  String circleCount(int count);

  /// The noun after the styled figure on the home screen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{circle} other{circles}}'**
  String circleCountWord(int count);

  /// No description provided for @packEyebrow.
  ///
  /// In en, this message translates to:
  /// **'RIDING WITH OTHERS'**
  String get packEyebrow;

  /// No description provided for @packTagline.
  ///
  /// In en, this message translates to:
  /// **'Everyone sees the gap, not just a dot'**
  String get packTagline;

  /// No description provided for @packStartRide.
  ///
  /// In en, this message translates to:
  /// **'Start a ride'**
  String get packStartRide;

  /// No description provided for @packJoinRide.
  ///
  /// In en, this message translates to:
  /// **'Join a ride'**
  String get packJoinRide;

  /// No description provided for @navLiveMap.
  ///
  /// In en, this message translates to:
  /// **'Live map'**
  String get navLiveMap;

  /// No description provided for @navSafetyCircles.
  ///
  /// In en, this message translates to:
  /// **'Safety circles'**
  String get navSafetyCircles;

  /// No description provided for @navCommutes.
  ///
  /// In en, this message translates to:
  /// **'Commutes and non-arrival'**
  String get navCommutes;

  /// No description provided for @navKnownRoutes.
  ///
  /// In en, this message translates to:
  /// **'Known routes'**
  String get navKnownRoutes;

  /// No description provided for @navTripHistory.
  ///
  /// In en, this message translates to:
  /// **'Trip history'**
  String get navTripHistory;

  /// No description provided for @milestoneCapArmed.
  ///
  /// In en, this message translates to:
  /// **'ALL SYSTEMS WATCHING'**
  String get milestoneCapArmed;

  /// Protection is on. Must not read as a promise that the rider is safe, only that the systems are running.
  ///
  /// In en, this message translates to:
  /// **'Covered'**
  String get milestoneHeadlineArmed;

  /// No description provided for @milestoneDetailArmed.
  ///
  /// In en, this message translates to:
  /// **'Crash detection, tracking and non-arrival alerts are all live. If you go down, your circles hear about it.'**
  String get milestoneDetailArmed;

  /// No description provided for @milestoneCapPartial.
  ///
  /// In en, this message translates to:
  /// **'GAPS IN COVER'**
  String get milestoneCapPartial;

  /// No description provided for @milestoneHeadlinePartial.
  ///
  /// In en, this message translates to:
  /// **'Partly covered'**
  String get milestoneHeadlinePartial;

  /// No description provided for @milestoneDetailPartial.
  ///
  /// In en, this message translates to:
  /// **'Some systems are off. Turn the rest on before you ride, or nobody gets told about the part they cover.'**
  String get milestoneDetailPartial;

  /// No description provided for @milestoneCapOff.
  ///
  /// In en, this message translates to:
  /// **'NOTHING IS WATCHING'**
  String get milestoneCapOff;

  /// No description provided for @milestoneHeadlineOff.
  ///
  /// In en, this message translates to:
  /// **'Not covered'**
  String get milestoneHeadlineOff;

  /// No description provided for @milestoneDetailOff.
  ///
  /// In en, this message translates to:
  /// **'No crash detection, no tracking, no alerts. Turn on protection in Settings before your next ride.'**
  String get milestoneDetailOff;

  /// No description provided for @milestoneCapIncident.
  ///
  /// In en, this message translates to:
  /// **'INCIDENT LIVE'**
  String get milestoneCapIncident;

  /// The app is alerting the rider's own circles. It never dispatches an ambulance and never replaces 112 — no translation may imply that it does.
  ///
  /// In en, this message translates to:
  /// **'Help is being called'**
  String get milestoneHeadlineIncident;

  /// No description provided for @milestoneDetailIncident.
  ///
  /// In en, this message translates to:
  /// **'Your circles are being alerted right now.'**
  String get milestoneDetailIncident;

  /// Screen-reader summary of the milestone.
  ///
  /// In en, this message translates to:
  /// **'Protection {headline}. {detail} {active} of 3 systems active.'**
  String milestoneSemantics(String headline, String detail, int active);

  /// No description provided for @milestoneSemanticsContactSet.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact set.'**
  String get milestoneSemanticsContactSet;

  /// No description provided for @milestoneSemanticsContactMissing.
  ///
  /// In en, this message translates to:
  /// **'No emergency contact.'**
  String get milestoneSemanticsContactMissing;

  /// No description provided for @gapNoContactHeadline.
  ///
  /// In en, this message translates to:
  /// **'Nobody to call'**
  String get gapNoContactHeadline;

  /// No description provided for @gapNoContactDetail.
  ///
  /// In en, this message translates to:
  /// **'You have no emergency contact. Crash detection can fire and the alert reaches nobody. Add one contact and the rest starts working.'**
  String get gapNoContactDetail;

  /// No description provided for @gapNoContactAction.
  ///
  /// In en, this message translates to:
  /// **'Add a contact'**
  String get gapNoContactAction;

  /// No description provided for @gapCrashOffHeadline.
  ///
  /// In en, this message translates to:
  /// **'Crash detection is off'**
  String get gapCrashOffHeadline;

  /// No description provided for @gapCrashOffDetail.
  ///
  /// In en, this message translates to:
  /// **'Nothing is listening for an impact. If you go down and cannot reach your phone, nobody is told.'**
  String get gapCrashOffDetail;

  /// No description provided for @gapTurnOnAction.
  ///
  /// In en, this message translates to:
  /// **'Turn it on'**
  String get gapTurnOnAction;

  /// No description provided for @gapTrackingOffHeadline.
  ///
  /// In en, this message translates to:
  /// **'Location tracking is off'**
  String get gapTrackingOffHeadline;

  /// No description provided for @gapTrackingOffDetail.
  ///
  /// In en, this message translates to:
  /// **'Your circles can be alerted, but not told where you are. Help arrives slower when it has to search.'**
  String get gapTrackingOffDetail;

  /// No description provided for @gapNonArrivalOffHeadline.
  ///
  /// In en, this message translates to:
  /// **'Non-arrival alerts are off'**
  String get gapNonArrivalOffHeadline;

  /// No description provided for @gapNonArrivalOffDetail.
  ///
  /// In en, this message translates to:
  /// **'If you never reach your destination, nothing raises it. Set up a commute route to close this.'**
  String get gapNonArrivalOffDetail;

  /// No description provided for @gapSetUpCommutesAction.
  ///
  /// In en, this message translates to:
  /// **'Set up commutes'**
  String get gapSetUpCommutesAction;

  /// No description provided for @settingsSectionSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get settingsSectionSafety;

  /// No description provided for @settingsCrashSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Crash Sensitivity'**
  String get settingsCrashSensitivity;

  /// No description provided for @settingsSensitivityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get settingsSensitivityHigh;

  /// No description provided for @settingsSensitivityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settingsSensitivityMedium;

  /// No description provided for @settingsSensitivityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get settingsSensitivityLow;

  /// No description provided for @settingsSensitivityHighDetail.
  ///
  /// In en, this message translates to:
  /// **'High - More sensitive, may have more false alerts'**
  String get settingsSensitivityHighDetail;

  /// No description provided for @settingsSensitivityMediumDetail.
  ///
  /// In en, this message translates to:
  /// **'Medium - Balanced (recommended)'**
  String get settingsSensitivityMediumDetail;

  /// No description provided for @settingsSensitivityLowDetail.
  ///
  /// In en, this message translates to:
  /// **'Low - Less sensitive, fewer false alerts'**
  String get settingsSensitivityLowDetail;

  /// No description provided for @settingsPhoneMount.
  ///
  /// In en, this message translates to:
  /// **'Phone Mount'**
  String get settingsPhoneMount;

  /// No description provided for @settingsMountBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get settingsMountBar;

  /// No description provided for @settingsMountPocket.
  ///
  /// In en, this message translates to:
  /// **'Pocket'**
  String get settingsMountPocket;

  /// No description provided for @settingsMountBag.
  ///
  /// In en, this message translates to:
  /// **'Bag'**
  String get settingsMountBag;

  /// No description provided for @settingsMountOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get settingsMountOther;

  /// No description provided for @settingsMountBarDetail.
  ///
  /// In en, this message translates to:
  /// **'Handlebar mount (most sensitive)'**
  String get settingsMountBarDetail;

  /// No description provided for @settingsMountPocketDetail.
  ///
  /// In en, this message translates to:
  /// **'In pocket'**
  String get settingsMountPocketDetail;

  /// No description provided for @settingsMountBagDetail.
  ///
  /// In en, this message translates to:
  /// **'In bag (least sensitive)'**
  String get settingsMountBagDetail;

  /// No description provided for @settingsMountUnknownDetail.
  ///
  /// In en, this message translates to:
  /// **'Other / Unknown'**
  String get settingsMountUnknownDetail;

  /// No description provided for @settingsSectionTracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get settingsSectionTracking;

  /// No description provided for @settingsNonArrivalAlerts.
  ///
  /// In en, this message translates to:
  /// **'Non-Arrival Alerts'**
  String get settingsNonArrivalAlerts;

  /// No description provided for @settingsNonArrivalAlertsSub.
  ///
  /// In en, this message translates to:
  /// **'Alert contacts if you don\'t arrive'**
  String get settingsNonArrivalAlertsSub;

  /// No description provided for @settingsAlertDelay.
  ///
  /// In en, this message translates to:
  /// **'Alert Delay'**
  String get settingsAlertDelay;

  /// No description provided for @settingsAlertDelaySub.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute after expected arrival} other{{count} minutes after expected arrival}}'**
  String settingsAlertDelaySub(int count);

  /// Compact duration used in dropdowns.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min} other{{count} min}}'**
  String minutesShort(int count);

  /// No description provided for @settingsCommuteRoutes.
  ///
  /// In en, this message translates to:
  /// **'Commute routes'**
  String get settingsCommuteRoutes;

  /// No description provided for @settingsCommuteRoutesSub.
  ///
  /// In en, this message translates to:
  /// **'Routes that raise an alert when you do not arrive'**
  String get settingsCommuteRoutesSub;

  /// No description provided for @settingsSectionEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get settingsSectionEmergency;

  /// No description provided for @settingsEmergencyContacts.
  ///
  /// In en, this message translates to:
  /// **'Emergency contacts'**
  String get settingsEmergencyContacts;

  /// No description provided for @settingsEmergencyContactsReady.
  ///
  /// In en, this message translates to:
  /// **'Who gets called when you cannot call'**
  String get settingsEmergencyContactsReady;

  /// No description provided for @settingsEmergencyContactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'None yet — alerts have nobody to reach'**
  String get settingsEmergencyContactsEmpty;

  /// ICE = in case of emergency. Kept as the Latin abbreviation, which is what Indian responders read.
  ///
  /// In en, this message translates to:
  /// **'ICE card'**
  String get settingsIceCard;

  /// No description provided for @settingsIceCardSub.
  ///
  /// In en, this message translates to:
  /// **'What a first responder sees at the scene'**
  String get settingsIceCardSub;

  /// No description provided for @settingsBystanderPreview.
  ///
  /// In en, this message translates to:
  /// **'See what a bystander sees'**
  String get settingsBystanderPreview;

  /// No description provided for @settingsBystanderPreviewSub.
  ///
  /// In en, this message translates to:
  /// **'Check your crash screen before you need it'**
  String get settingsBystanderPreviewSub;

  /// No description provided for @settingsIceCommuteToggle.
  ///
  /// In en, this message translates to:
  /// **'Show ICE card during commutes'**
  String get settingsIceCommuteToggle;

  /// No description provided for @settingsIceCommuteToggleSub.
  ///
  /// In en, this message translates to:
  /// **'Off by default. On, a helper at the scene can see your blood group and contacts during a tracked commute, not only after a crash.'**
  String get settingsIceCommuteToggleSub;

  /// No description provided for @settingsSectionMaps.
  ///
  /// In en, this message translates to:
  /// **'Maps'**
  String get settingsSectionMaps;

  /// No description provided for @settingsOfflineMaps.
  ///
  /// In en, this message translates to:
  /// **'Offline maps'**
  String get settingsOfflineMaps;

  /// No description provided for @settingsOfflineMapsSub.
  ///
  /// In en, this message translates to:
  /// **'Download regions for dead-zone riding'**
  String get settingsOfflineMapsSub;

  /// No description provided for @settingsSectionEmergencyProfile.
  ///
  /// In en, this message translates to:
  /// **'Emergency Profile'**
  String get settingsSectionEmergencyProfile;

  /// No description provided for @settingsBloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Blood Group'**
  String get settingsBloodGroup;

  /// No description provided for @settingsMedicalNotes.
  ///
  /// In en, this message translates to:
  /// **'Medical Notes'**
  String get settingsMedicalNotes;

  /// No description provided for @settingsMedicalNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Allergies, conditions, medications...'**
  String get settingsMedicalNotesHint;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get settingsVehicle;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settingsSignOut;

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsSectionLanguage;

  /// No description provided for @settingsLanguageSub.
  ///
  /// In en, this message translates to:
  /// **'Emergency screens use this language too'**
  String get settingsLanguageSub;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'Match my phone'**
  String get languageSystemDefault;

  /// Endonym. Identical in every locale so a rider can always find their own language in the list.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Endonym.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get languageHindi;

  /// Endonym.
  ///
  /// In en, this message translates to:
  /// **'മലയാളം'**
  String get languageMalayalam;

  /// AppBar title of the join screen, reused as the tooltip on the join icon in the circles list.
  ///
  /// In en, this message translates to:
  /// **'Join Circle'**
  String get circlesJoinCircleTitle;

  /// FAB label on the circles list and AppBar title of the create screen.
  ///
  /// In en, this message translates to:
  /// **'Create Circle'**
  String get circlesCreateCircle;

  /// Generic load failure, reused across circles list/detail/join.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get circlesLoadError;

  /// No description provided for @circlesRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get circlesRetry;

  /// No description provided for @circlesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first Safety Circle'**
  String get circlesEmptyTitle;

  /// No description provided for @circlesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your circles help ensure the right people are alerted when something happens on the road'**
  String get circlesEmptyBody;

  /// No description provided for @circlesRegenerateCode.
  ///
  /// In en, this message translates to:
  /// **'Regenerate invite code'**
  String get circlesRegenerateCode;

  /// No description provided for @circlesDeleteCircle.
  ///
  /// In en, this message translates to:
  /// **'Delete circle'**
  String get circlesDeleteCircle;

  /// Heading above the member list, with the count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Member (1)} other{Members ({count})}}'**
  String circlesMembersHeading(int count);

  /// Heading above the observers list, with the count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Observer (1)} other{Observers ({count})}}'**
  String circlesObserversHeading(int count);

  /// Short tag on an observer row. The protocol name, kept as-is like ICE/SOS elsewhere in the app.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get circlesObserverSmsTag;

  /// Both the outlined button on the detail screen and the title of the add-observer sheet use this exact text.
  ///
  /// In en, this message translates to:
  /// **'Add Observer'**
  String get circlesAddObserverAction;

  /// No description provided for @circlesObserverSmsExplainer.
  ///
  /// In en, this message translates to:
  /// **'Observers receive SMS alerts but don\'t need the app.'**
  String get circlesObserverSmsExplainer;

  /// No description provided for @circlesPhoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get circlesPhoneNumberLabel;

  /// No description provided for @circlesAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get circlesAddAction;

  /// No description provided for @circlesLeaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave circle?'**
  String get circlesLeaveDialogTitle;

  /// Warns that leaving a FAMILY circle also breaks emergency-contact links. Safety-relevant consequence.
  ///
  /// In en, this message translates to:
  /// **'Leaving will remove all emergency contact links from this circle.'**
  String get circlesLeaveFamilyWarning;

  /// No description provided for @circlesLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave?'**
  String get circlesLeaveConfirm;

  /// No description provided for @circlesLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get circlesLeaveAction;

  /// Failure snackbar when leaving a circle throws. {message} is untranslated technical detail (same pattern as commonError).
  ///
  /// In en, this message translates to:
  /// **'Could not leave: {message}'**
  String circlesLeaveError(String message);

  /// No description provided for @circlesDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete circle?'**
  String get circlesDeleteDialogTitle;

  /// No description provided for @circlesDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get circlesDeleteWarning;

  /// No description provided for @circlesDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get circlesDeleteAction;

  /// Snackbar after regenerating the invite code.
  ///
  /// In en, this message translates to:
  /// **'New code: {code}'**
  String circlesNewCodeSnackbar(String code);

  /// No description provided for @circlesRoleUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Failed to update role. Please try again.'**
  String get circlesRoleUpdateError;

  /// No description provided for @circlesRemoveMemberError.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove member. Please try again.'**
  String get circlesRemoveMemberError;

  /// No description provided for @circlesRemoveObserverError.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove observer. Please try again.'**
  String get circlesRemoveObserverError;

  /// No description provided for @circlesEcUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Failed to update emergency contact. Please try again.'**
  String get circlesEcUpdateError;

  /// Text handed to the OS share sheet when sharing an invite code.
  ///
  /// In en, this message translates to:
  /// **'Join my Safety Circle on RoadPack! Code: {code}'**
  String circlesShareInviteMessage(String code);

  /// No description provided for @circlesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Circle name'**
  String get circlesNameLabel;

  /// Convoy duration options in the dropdown.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String circlesDurationHours(int count);

  /// No description provided for @circlesDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get circlesDurationLabel;

  /// No description provided for @circlesCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get circlesCreateAction;

  /// No description provided for @circlesLocationSharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Let this circle see live location'**
  String get circlesLocationSharingTitle;

  /// Consent copy shown when creating a circle with sharing on.
  ///
  /// In en, this message translates to:
  /// **'Everyone in this circle will be able to see where each member is. You can turn this off later.'**
  String get circlesLocationSharingOnDetail;

  /// Honesty clause: the alert cascade still works with sharing off. Must not be softened.
  ///
  /// In en, this message translates to:
  /// **'Off. Members still get alerted if someone crashes — they just cannot watch each other the rest of the time.'**
  String get circlesLocationSharingOffDetail;

  /// No description provided for @circlesInvalidCodeError.
  ///
  /// In en, this message translates to:
  /// **'Invalid code'**
  String get circlesInvalidCodeError;

  /// No description provided for @circlesEnterCodeHeading.
  ///
  /// In en, this message translates to:
  /// **'Enter invite code'**
  String get circlesEnterCodeHeading;

  /// Members in one circle, shown on the join-preview card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String circlesMemberCount(int count);

  /// No description provided for @circlesJoinAction.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get circlesJoinAction;

  /// No description provided for @circlesWhoCanSeeMeTitle.
  ///
  /// In en, this message translates to:
  /// **'Who can see me'**
  String get circlesWhoCanSeeMeTitle;

  /// Failure snackbar for a sharing-setting change. Must clearly say nothing changed, or a failed toggle could be read as succeeded.
  ///
  /// In en, this message translates to:
  /// **'Could not change that. Nothing was changed.'**
  String get circlesChangeFailedMessage;

  /// Headline of the anti-stalking 'who can see me' screen. Accuracy here matters more than almost any other string in the feature.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nobody can see your location} =1{1 person can see your location} other{{count} people can see your location}}'**
  String circlesWatcherCountHeadline(int count);

  /// The core anti-stalking honesty guarantee: no hidden watchers. Must not be softened or hedged in translation.
  ///
  /// In en, this message translates to:
  /// **'This is the full list. RoadPack has no hidden mode — if someone can see you, they are on this page.'**
  String get circlesFullListNotice;

  /// No description provided for @circlesNoCirclesYet.
  ///
  /// In en, this message translates to:
  /// **'You are not in any circles yet, so there is nobody to see you.'**
  String get circlesNoCirclesYet;

  /// No description provided for @circlesLoadWhoCanSeeError.
  ///
  /// In en, this message translates to:
  /// **'We could not load who can see you'**
  String get circlesLoadWhoCanSeeError;

  /// Critical honesty clause on the error state: a load failure must not be read as "you are safe / unwatched".
  ///
  /// In en, this message translates to:
  /// **'Do not assume this means nobody can. Try again when you have signal.'**
  String get circlesLoadWhoCanSeeErrorDetail;

  /// No description provided for @circlesTryAgainAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get circlesTryAgainAction;

  /// Card subtitle: circle type and member count as one message, never string-concatenated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{type} -- 1 member} other{{type} -- {count} members}}'**
  String circlesCardSubtitle(String type, int count);

  /// No description provided for @circlesExpiredTag.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get circlesExpiredTag;

  /// No description provided for @circlesTypeFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get circlesTypeFamily;

  /// No description provided for @circlesTypeFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get circlesTypeFriends;

  /// No description provided for @circlesTypeCommute.
  ///
  /// In en, this message translates to:
  /// **'Commute Group'**
  String get circlesTypeCommute;

  /// No description provided for @circlesTypeConvoy.
  ///
  /// In en, this message translates to:
  /// **'Convoy'**
  String get circlesTypeConvoy;

  /// No description provided for @circlesTypeFamilyDefaultName.
  ///
  /// In en, this message translates to:
  /// **'My Family'**
  String get circlesTypeFamilyDefaultName;

  /// No description provided for @circlesTypeFriendsDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get circlesTypeFriendsDefaultName;

  /// No description provided for @circlesTypeCommuteDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Commute Group'**
  String get circlesTypeCommuteDefaultName;

  /// No description provided for @circlesTypeConvoyDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Convoy'**
  String get circlesTypeConvoyDefaultName;

  /// No description provided for @circlesTypeFamilyDescription.
  ///
  /// In en, this message translates to:
  /// **'Your closest people. Members are automatically added as emergency contacts.'**
  String get circlesTypeFamilyDescription;

  /// No description provided for @circlesTypeFriendsDescription.
  ///
  /// In en, this message translates to:
  /// **'Friends who ride or commute. Add specific members as emergency contacts.'**
  String get circlesTypeFriendsDescription;

  /// No description provided for @circlesTypeCommuteDescription.
  ///
  /// In en, this message translates to:
  /// **'Regular commute group.'**
  String get circlesTypeCommuteDescription;

  /// No description provided for @circlesTypeConvoyDescription.
  ///
  /// In en, this message translates to:
  /// **'Temporary group ride. Set a duration.'**
  String get circlesTypeConvoyDescription;

  /// No description provided for @circlesRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get circlesRoleAdmin;

  /// No description provided for @circlesRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get circlesRoleMember;

  /// No description provided for @circlesRoleObserver.
  ///
  /// In en, this message translates to:
  /// **'Observer'**
  String get circlesRoleObserver;

  /// No description provided for @circlesUnknownMember.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get circlesUnknownMember;

  /// No description provided for @circlesYouTag.
  ///
  /// In en, this message translates to:
  /// **'(you)'**
  String get circlesYouTag;

  /// No description provided for @circlesMenuLeaveCircle.
  ///
  /// In en, this message translates to:
  /// **'Leave circle'**
  String get circlesMenuLeaveCircle;

  /// Admin-only menu item. "Demote" kept as a loanword; unsure it reads naturally in either language.
  ///
  /// In en, this message translates to:
  /// **'Demote to member'**
  String get circlesMenuDemote;

  /// Admin-only menu item. "Promote" kept as a loanword; unsure it reads naturally in either language.
  ///
  /// In en, this message translates to:
  /// **'Promote to admin'**
  String get circlesMenuPromote;

  /// No description provided for @circlesMenuRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get circlesMenuRemove;

  /// No description provided for @circlesMenuMarkEc.
  ///
  /// In en, this message translates to:
  /// **'Mark as emergency contact'**
  String get circlesMenuMarkEc;

  /// No description provided for @circlesMenuRemoveEc.
  ///
  /// In en, this message translates to:
  /// **'Remove as emergency contact'**
  String get circlesMenuRemoveEc;

  /// No description provided for @circlesMonthlyCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly check: who can see you?'**
  String get circlesMonthlyCheckTitle;

  /// Body of the monthly sharing-review nudge banner. Safety headline; accuracy matters.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nobody can see your location right now. Worth a look anyway — circles change.} =1{1 person can see your location right now.} other{{count} people can see your location right now.}}'**
  String circlesWatcherCountBanner(int count);

  /// No description provided for @circlesReviewListAction.
  ///
  /// In en, this message translates to:
  /// **'Review the list'**
  String get circlesReviewListAction;

  /// No description provided for @circlesNotNowAction.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get circlesNotNowAction;

  /// No description provided for @circlesSharingOnEmptyDetail.
  ///
  /// In en, this message translates to:
  /// **'Location sharing is on, but there is nobody else in this circle yet.'**
  String get circlesSharingOnEmptyDetail;

  /// Watcher count for one circle on the who-can-see-me screen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person here can see where you are.} other{{count} people here can see where you are.}}'**
  String circlesWatchersHereDetail(int count);

  /// No description provided for @circlesSharingOffDetail.
  ///
  /// In en, this message translates to:
  /// **'Nobody in this circle can see where you are.'**
  String get circlesSharingOffDetail;

  /// One watcher row: name and role. The role string arriving in {role} is already lower-cased by the caller.
  ///
  /// In en, this message translates to:
  /// **'{name} — {role}'**
  String circlesWatcherRow(String name, String role);

  /// No description provided for @circlesShareMyLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Share my location with this circle'**
  String get circlesShareMyLocationTitle;

  /// Shown while self-sharing is ON, describing what turning it off would do. Must not imply the crash alert stops.
  ///
  /// In en, this message translates to:
  /// **'Turning this off hides your live position from this circle. You stay a member, and if you crash they are still alerted with your location.'**
  String get circlesSelfSharingOnDetail;

  /// Shown while self-sharing is OFF. Critical honesty clause: opting out of the live dot does not opt out of the crash cascade.
  ///
  /// In en, this message translates to:
  /// **'Your live position is hidden from this circle. You are still a member, you still get their alerts, and if you crash they are still told where you are.'**
  String get circlesSelfSharingOffDetail;

  /// Shown to a non-admin member when the member-side opt-out is enforced server-side.
  ///
  /// In en, this message translates to:
  /// **'Only this circle\'s admin can change the circle-wide setting, but the switch above stops your own location being shared. You can also leave.'**
  String get circlesAdminOnlyOptOutNotice;

  /// Consent guarantee shown when the member-side opt-out is NOT enforced server-side. "RoadPack will never stop you" must not be softened.
  ///
  /// In en, this message translates to:
  /// **'Only this circle\'s admin can change its sharing setting. If you are not comfortable, you can leave the circle — it takes effect at once, and RoadPack will never stop you.'**
  String get circlesAdminOnlyNoOptOutNotice;

  /// No description provided for @circlesLeaveThisCircleAction.
  ///
  /// In en, this message translates to:
  /// **'Leave this circle'**
  String get circlesLeaveThisCircleAction;

  /// No description provided for @circlesInviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get circlesInviteCodeLabel;

  /// No description provided for @circlesCodeCopiedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get circlesCodeCopiedSnackbar;

  /// No description provided for @circlesCopyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get circlesCopyAction;

  /// No description provided for @circlesShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get circlesShareAction;

  /// No description provided for @commuteTitle.
  ///
  /// In en, this message translates to:
  /// **'Commute'**
  String get commuteTitle;

  /// No description provided for @commuteAddRoute.
  ///
  /// In en, this message translates to:
  /// **'Add route'**
  String get commuteAddRoute;

  /// No description provided for @commuteEditRoute.
  ///
  /// In en, this message translates to:
  /// **'Edit route'**
  String get commuteEditRoute;

  /// No description provided for @commuteLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your routes'**
  String get commuteLoadError;

  /// No description provided for @commuteYourRoutesHeading.
  ///
  /// In en, this message translates to:
  /// **'YOUR ROUTES'**
  String get commuteYourRoutesHeading;

  /// No description provided for @commuteNonArrivalTitle.
  ///
  /// In en, this message translates to:
  /// **'Non-arrival alerts'**
  String get commuteNonArrivalTitle;

  /// Composed with {late} = commuteGraceWindowSemantics, e.g. "15 minutes late". Honesty-critical: must not imply the app asks before the circle is told is anything other than a courtesy delay.
  ///
  /// In en, this message translates to:
  /// **'If you have not arrived {late}, RoadPack asks you first. Your circle is only told if you do not answer.'**
  String commuteNonArrivalEnabledBody(String late);

  /// No description provided for @commuteNonArrivalDisabledBody.
  ///
  /// In en, this message translates to:
  /// **'Nobody will be told if you do not arrive.'**
  String get commuteNonArrivalDisabledBody;

  /// Eyebrow label above the grace-window picker.
  ///
  /// In en, this message translates to:
  /// **'ASK ME AFTER'**
  String get commuteAskMeAfterHeading;

  /// WARNING: the key name says "late" but the placeholder is the spoken minute count, e.g. commuteSpokenMinutes(15) -> "15 minutes". English renders as "{late} late" -> "15 minutes late". Used standalone (segment semantics) and composed into commuteNonArrivalEnabledBody.
  ///
  /// In en, this message translates to:
  /// **'{late} late'**
  String commuteGraceWindowSemantics(String late);

  /// Spoken duration used inside composed sentences (never shown bare) — accessibility labels and the grace-window explanation.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String commuteSpokenMinutes(int count);

  /// Spoken duration used inside commuteAnswerSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String commuteSpokenSeconds(int count);

  /// No description provided for @commuteEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No routes yet'**
  String get commuteEmptyTitle;

  /// count = CommuteRoute.learningThreshold (currently always 3, plural kept correct regardless).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{RoadPack learns a commute after 1 similar trip. If you would rather not wait, add one yourself — it works straight away.} other{RoadPack learns a commute after {count} similar trips. If you would rather not wait, add one yourself — it works straight away.}}'**
  String commuteEmptyBody(int count);

  /// No description provided for @commuteDeleteRouteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete route'**
  String get commuteDeleteRouteTooltip;

  /// No description provided for @commuteNameHint.
  ///
  /// In en, this message translates to:
  /// **'Home to college'**
  String get commuteNameHint;

  /// No description provided for @commuteNameValidation.
  ///
  /// In en, this message translates to:
  /// **'Give this route a name you will recognise'**
  String get commuteNameValidation;

  /// No description provided for @commuteSectionWhere.
  ///
  /// In en, this message translates to:
  /// **'WHERE'**
  String get commuteSectionWhere;

  /// No description provided for @commuteSectionWhen.
  ///
  /// In en, this message translates to:
  /// **'WHEN'**
  String get commuteSectionWhen;

  /// No description provided for @commuteSectionDays.
  ///
  /// In en, this message translates to:
  /// **'DAYS'**
  String get commuteSectionDays;

  /// No description provided for @commuteStartPoint.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get commuteStartPoint;

  /// No description provided for @commuteDestinationPoint.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get commuteDestinationPoint;

  /// No description provided for @commuteLocationPermissionError.
  ///
  /// In en, this message translates to:
  /// **'RoadPack needs location permission to pin this point.'**
  String get commuteLocationPermissionError;

  /// No description provided for @commuteLocationFixError.
  ///
  /// In en, this message translates to:
  /// **'Could not get a fix here. Try again outdoors.'**
  String get commuteLocationFixError;

  /// No description provided for @commuteIncompleteError.
  ///
  /// In en, this message translates to:
  /// **'Set both points, a start time and at least one day.'**
  String get commuteIncompleteError;

  /// No description provided for @commuteDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Usually takes (minutes)'**
  String get commuteDurationLabel;

  /// No description provided for @commuteDurationEmptyValidation.
  ///
  /// In en, this message translates to:
  /// **'How long does this ride usually take?'**
  String get commuteDurationEmptyValidation;

  /// No description provided for @commuteDurationTooLongValidation.
  ///
  /// In en, this message translates to:
  /// **'That is longer than a day trip'**
  String get commuteDurationTooLongValidation;

  /// No description provided for @commuteSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get commuteSaveChanges;

  /// No description provided for @commuteRouteIncompleteHint.
  ///
  /// In en, this message translates to:
  /// **'A route needs both points, a start time and at least one day before it can watch for you.'**
  String get commuteRouteIncompleteHint;

  /// No description provided for @commuteUsuallyLeavesAt.
  ///
  /// In en, this message translates to:
  /// **'Usually leaves at'**
  String get commuteUsuallyLeavesAt;

  /// No description provided for @commutePointNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get commutePointNotSet;

  /// No description provided for @commuteUpdatePoint.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get commuteUpdatePoint;

  /// No description provided for @commuteUseHerePoint.
  ///
  /// In en, this message translates to:
  /// **'Use here'**
  String get commuteUseHerePoint;

  /// No description provided for @commuteDeleteRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this route?'**
  String get commuteDeleteRouteTitle;

  /// No description provided for @commuteDeleteRouteBody.
  ///
  /// In en, this message translates to:
  /// **'RoadPack will stop watching for non-arrival on it.'**
  String get commuteDeleteRouteBody;

  /// No description provided for @commuteKeepAction.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get commuteKeepAction;

  /// No description provided for @commuteDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commuteDeleteAction;

  /// No description provided for @commuteDayNameMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get commuteDayNameMonday;

  /// No description provided for @commuteDayNameTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get commuteDayNameTuesday;

  /// No description provided for @commuteDayNameWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get commuteDayNameWednesday;

  /// No description provided for @commuteDayNameThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get commuteDayNameThursday;

  /// No description provided for @commuteDayNameFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get commuteDayNameFriday;

  /// No description provided for @commuteDayNameSaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get commuteDayNameSaturday;

  /// No description provided for @commuteDayNameSunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get commuteDayNameSunday;

  /// Fixed-size day chip. Shortened mnemonic, not a translation.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get commuteDayLetterMon;

  /// Fixed-size day chip. Shortened mnemonic, not a translation.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get commuteDayLetterTue;

  /// Fixed-size day chip. Shortened mnemonic, not a translation.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get commuteDayLetterWed;

  /// Fixed-size day chip. Shortened mnemonic, not a translation.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get commuteDayLetterThu;

  /// Fixed-size day chip. Shortened mnemonic, not a translation.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get commuteDayLetterFri;

  /// Fixed-size day chip. Shortened mnemonic, not a translation.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get commuteDayLetterSat;

  /// Fixed-size day chip. Shortened mnemonic, not a translation.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get commuteDayLetterSun;

  /// Accessibility summary for the day strip on a route card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No days set} =1{Active on 1 day a week} other{Active on {count} days a week}}'**
  String commuteDaysActiveSemantics(int count);

  /// No description provided for @commuteTimeToAnswerHeading.
  ///
  /// In en, this message translates to:
  /// **'TIME TO ANSWER'**
  String get commuteTimeToAnswerHeading;

  /// {spoken} is filled with commuteSpokenSeconds or commuteSpokenMinutes depending on time remaining.
  ///
  /// In en, this message translates to:
  /// **'{spoken} before your circle is told.'**
  String commuteAnswerSemantics(String spoken);

  /// No description provided for @commuteNothingToCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Nothing to check in on.'**
  String get commuteNothingToCheckIn;

  /// No description provided for @commuteCheckingInHeading.
  ///
  /// In en, this message translates to:
  /// **'CHECKING IN'**
  String get commuteCheckingInHeading;

  /// No description provided for @commuteCircleToldHeading.
  ///
  /// In en, this message translates to:
  /// **'YOUR CIRCLE HAS BEEN TOLD'**
  String get commuteCircleToldHeading;

  /// No description provided for @commuteEverythingOkay.
  ///
  /// In en, this message translates to:
  /// **'Everything okay?'**
  String get commuteEverythingOkay;

  /// No description provided for @commuteWeLetThemKnow.
  ///
  /// In en, this message translates to:
  /// **'We let them know'**
  String get commuteWeLetThemKnow;

  /// No description provided for @commuteTravellingBody.
  ///
  /// In en, this message translates to:
  /// **'You have not reached your usual destination. Nobody has been told yet.'**
  String get commuteTravellingBody;

  /// Honesty-critical: describes the alert that has actually gone out to the circle. Source text says "your family circle"; simplified to "your circle" to match the app's Circle entity.
  ///
  /// In en, this message translates to:
  /// **'You did not answer, so your circle was sent an alert. Tell them you are fine when you can.'**
  String get commuteEscalatedBody;

  /// No description provided for @commuteAnswerCaption.
  ///
  /// In en, this message translates to:
  /// **'If you do not answer, your circle is told.'**
  String get commuteAnswerCaption;

  /// {minutes} filled with commuteSpokenMinutes(snooze.minutes), e.g. "30 minutes". Snackbar confirming "I'm running late" did not notify anybody.
  ///
  /// In en, this message translates to:
  /// **'Window extended by {minutes}. Nobody was told.'**
  String commuteSnoozeExtendedMessage(String minutes);

  /// No description provided for @commuteGladYouMadeIt.
  ///
  /// In en, this message translates to:
  /// **'Glad you made it.'**
  String get commuteGladYouMadeIt;

  /// No description provided for @commuteFineTellThem.
  ///
  /// In en, this message translates to:
  /// **'I\'m fine — tell them'**
  String get commuteFineTellThem;

  /// No description provided for @commuteArrivedFine.
  ///
  /// In en, this message translates to:
  /// **'I\'ve arrived, I\'m fine'**
  String get commuteArrivedFine;

  /// No description provided for @commuteNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'I need help'**
  String get commuteNeedHelp;

  /// No description provided for @commuteAddedByYouBadge.
  ///
  /// In en, this message translates to:
  /// **'ADDED BY YOU'**
  String get commuteAddedByYouBadge;

  /// No description provided for @commuteTripsBadge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} TRIP} other{{count} TRIPS}}'**
  String commuteTripsBadge(int count);

  /// No description provided for @commuteLeavesLabel.
  ///
  /// In en, this message translates to:
  /// **'LEAVES'**
  String get commuteLeavesLabel;

  /// No description provided for @commuteTakesLabel.
  ///
  /// In en, this message translates to:
  /// **'TAKES'**
  String get commuteTakesLabel;

  /// No description provided for @commuteArrivesLabel.
  ///
  /// In en, this message translates to:
  /// **'ARRIVES'**
  String get commuteArrivesLabel;

  /// No description provided for @commuteLearningNote.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Still learning — 1 more trip before this route is watched.} other{Still learning — {count} more trips before this route is watched.}}'**
  String commuteLearningNote(int count);

  /// No description provided for @commuteNotWatchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Not watching this route'**
  String get commuteNotWatchingTitle;

  /// No description provided for @commuteWatchingOnceLearnedTitle.
  ///
  /// In en, this message translates to:
  /// **'Watching once learned'**
  String get commuteWatchingOnceLearnedTitle;

  /// No description provided for @commuteNeedsMoreTripsDetail.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Needs 1 more trip} other{Needs {count} more trips}}'**
  String commuteNeedsMoreTripsDetail(int count);

  /// No description provided for @commuteNotWatchingYetTitle.
  ///
  /// In en, this message translates to:
  /// **'Not watching yet'**
  String get commuteNotWatchingYetTitle;

  /// No description provided for @commuteMissingScheduleDetail.
  ///
  /// In en, this message translates to:
  /// **'No start time, duration or days set'**
  String get commuteMissingScheduleDetail;

  /// No description provided for @commuteWatchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Watching for non-arrival'**
  String get commuteWatchingTitle;

  /// Fixed-height, most-pressed button on the check-in screen. Shortened from a literal translation to fit the control.
  ///
  /// In en, this message translates to:
  /// **'I\'m running late'**
  String get commuteRunningLateLabel;

  /// Fixed-height control, secondary snooze action. Shortened to fit.
  ///
  /// In en, this message translates to:
  /// **'Much later'**
  String get commuteMuchLaterLabel;

  /// Snooze badge on the running-late buttons, e.g. "+30 min". Deliberately expressed in minutes even for the 60-minute option (never "+1 hour") so the count stays a single ICU plural rather than a unit-switching string.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 min} other{+{count} min}}'**
  String commuteSnoozeTrailing(int count);

  /// Honesty-critical: the snooze action truly notifies nobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody is told when you press this.'**
  String get commuteNobodyToldCaption;

  /// Accessibility label composing the already-localised button label and trailing badge, matching the checkSemantics / milestoneSemantics composition pattern.
  ///
  /// In en, this message translates to:
  /// **'{label}, {trailing}. Nobody is notified.'**
  String commuteSnoozeSemantics(String label, String trailing);

  /// No description provided for @consentCentreTitle.
  ///
  /// In en, this message translates to:
  /// **'What I have agreed to'**
  String get consentCentreTitle;

  /// No description provided for @consentPermissionsHeading.
  ///
  /// In en, this message translates to:
  /// **'Your permissions'**
  String get consentPermissionsHeading;

  /// Revocation promise. Must stay unconditional in every language.
  ///
  /// In en, this message translates to:
  /// **'Turn any of these off whenever you want. Turning off location sharing stops RoadPack tracking you straight away.'**
  String get consentPermissionsIntro;

  /// When a consent was recorded.
  ///
  /// In en, this message translates to:
  /// **'You said yes on {date}'**
  String consentGrantedOn(DateTime date);

  /// No description provided for @consentParentalSectionBody.
  ///
  /// In en, this message translates to:
  /// **'A parent or guardian agreed to RoadPack tracking you. They, or you, can take that back at any time — RoadPack stops tracking immediately.'**
  String get consentParentalSectionBody;

  /// No description provided for @consentWithdrawParentalAction.
  ///
  /// In en, this message translates to:
  /// **'Withdraw parent permission'**
  String get consentWithdrawParentalAction;

  /// No description provided for @consentUnknownLedgerTitle.
  ///
  /// In en, this message translates to:
  /// **'We could not check your permissions'**
  String get consentUnknownLedgerTitle;

  /// Fail-closed statement. Must not be softened into "we will try again later".
  ///
  /// In en, this message translates to:
  /// **'Until we can reach the server, RoadPack assumes you have not agreed to anything and will not track you.'**
  String get consentUnknownLedgerBody;

  /// No description provided for @consentChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get consentChecking;

  /// No description provided for @consentTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get consentTryAgain;

  /// No description provided for @consentTypeTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Share my location while I ride'**
  String get consentTypeTrackingTitle;

  /// No description provided for @consentTypeTrackingMeaning.
  ///
  /// In en, this message translates to:
  /// **'RoadPack records where you are while a ride is on, so your circle can find you if you crash.'**
  String get consentTypeTrackingMeaning;

  /// No description provided for @consentTypeDataSharingAnonTitle.
  ///
  /// In en, this message translates to:
  /// **'Help improve road safety maps'**
  String get consentTypeDataSharingAnonTitle;

  /// No description provided for @consentTypeDataSharingAnonMeaning.
  ///
  /// In en, this message translates to:
  /// **'Rough, un-named location points help map dangerous stretches. Nothing sent this way carries your name or number.'**
  String get consentTypeDataSharingAnonMeaning;

  /// No description provided for @consentTypeSensorUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Send crash sensor data after a crash'**
  String get consentTypeSensorUploadTitle;

  /// No description provided for @consentTypeSensorUploadMeaning.
  ///
  /// In en, this message translates to:
  /// **'After a crash, the phone sends what its sensors felt so the detection gets better.'**
  String get consentTypeSensorUploadMeaning;

  /// No description provided for @consentTypeParentalTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent or guardian permission'**
  String get consentTypeParentalTitle;

  /// No description provided for @consentTypeParentalMeaning.
  ///
  /// In en, this message translates to:
  /// **'Because you are under 18, a parent or guardian has to say yes before RoadPack can track you at all.'**
  String get consentTypeParentalMeaning;

  /// No description provided for @consentTypeInstitutionalTitle.
  ///
  /// In en, this message translates to:
  /// **'Share with my college or employer'**
  String get consentTypeInstitutionalTitle;

  /// A limit on what a third party sees. Must not become vaguer in translation.
  ///
  /// In en, this message translates to:
  /// **'Your college or employer sees group totals only — never your live position and never your contacts.'**
  String get consentTypeInstitutionalMeaning;

  /// No description provided for @consentTypeAudioCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'Record audio after a crash'**
  String get consentTypeAudioCaptureTitle;

  /// No description provided for @consentTypeAudioCaptureMeaning.
  ///
  /// In en, this message translates to:
  /// **'After a crash, the phone can record a short clip so help knows what it is walking into.'**
  String get consentTypeAudioCaptureMeaning;

  /// No description provided for @consentGateReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'RoadPack can look after you'**
  String get consentGateReadyTitle;

  /// Honesty rule 5: never let this imply RoadPack replaces 112.
  ///
  /// In en, this message translates to:
  /// **'Your profile is complete and you have agreed to location sharing. RoadPack still does not replace calling 112.'**
  String get consentGateReadyBody;

  /// No description provided for @consentGateBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'RoadPack is not tracking you yet'**
  String get consentGateBlockedTitle;

  /// No description provided for @consentGateBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Finish these and it will:'**
  String get consentGateBlockedBody;

  /// No description provided for @consentGateAskParentAction.
  ///
  /// In en, this message translates to:
  /// **'Ask a parent or guardian'**
  String get consentGateAskParentAction;

  /// No description provided for @consentBlockerNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your name'**
  String get consentBlockerNameTitle;

  /// No description provided for @consentBlockerNameBody.
  ///
  /// In en, this message translates to:
  /// **'Whoever we call needs to know who they are being called about.'**
  String get consentBlockerNameBody;

  /// No description provided for @consentBlockerPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your phone number'**
  String get consentBlockerPhoneTitle;

  /// No description provided for @consentBlockerPhoneBody.
  ///
  /// In en, this message translates to:
  /// **'We need a number that works, so help can call you back.'**
  String get consentBlockerPhoneBody;

  /// No description provided for @consentBlockerContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Add an emergency contact'**
  String get consentBlockerContactTitle;

  /// No description provided for @consentBlockerContactBody.
  ///
  /// In en, this message translates to:
  /// **'RoadPack has nobody to alert. One contact is the minimum.'**
  String get consentBlockerContactBody;

  /// No description provided for @consentBlockerDobTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your date of birth'**
  String get consentBlockerDobTitle;

  /// No description provided for @consentBlockerDobBody.
  ///
  /// In en, this message translates to:
  /// **'The law treats under-18 riders differently, so we have to know which rules apply to you.'**
  String get consentBlockerDobBody;

  /// No description provided for @consentBlockerParentalTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent or guardian permission needed'**
  String get consentBlockerParentalTitle;

  /// No description provided for @consentBlockerParentalBody.
  ///
  /// In en, this message translates to:
  /// **'You are under 18. A parent or guardian has to agree before RoadPack can record where you are.'**
  String get consentBlockerParentalBody;

  /// No description provided for @consentBlockerTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on location sharing'**
  String get consentBlockerTrackingTitle;

  /// No description provided for @consentBlockerTrackingBody.
  ///
  /// In en, this message translates to:
  /// **'RoadPack does not record your location until you say yes, and stops the moment you say no.'**
  String get consentBlockerTrackingBody;

  /// No description provided for @consentBlockerUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'We could not reach the server to check what you have agreed to. Until we can, RoadPack will not track you.'**
  String get consentBlockerUnknownBody;

  /// No description provided for @consentParentalScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent or guardian permission'**
  String get consentParentalScreenTitle;

  /// No description provided for @consentParentalFormIntro.
  ///
  /// In en, this message translates to:
  /// **'You are under 18, so a parent or guardian has to agree before RoadPack records where you are. Nothing is tracked until they do.'**
  String get consentParentalFormIntro;

  /// No description provided for @consentParentalNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Parent or guardian name'**
  String get consentParentalNameLabel;

  /// No description provided for @consentParentalPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Their phone number'**
  String get consentParentalPhoneLabel;

  /// No description provided for @consentParentalRelationLabel.
  ///
  /// In en, this message translates to:
  /// **'Their relationship to you'**
  String get consentParentalRelationLabel;

  /// No description provided for @consentParentalRelationHint.
  ///
  /// In en, this message translates to:
  /// **'Mother, father, guardian'**
  String get consentParentalRelationHint;

  /// No description provided for @consentParentalMethodLine.
  ///
  /// In en, this message translates to:
  /// **'How we confirm them: {method}'**
  String consentParentalMethodLine(String method);

  /// No description provided for @consentParentalSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Ask them to confirm'**
  String get consentParentalSubmitAction;

  /// The shipped verifier refuses. This admission must stay an admission in every language.
  ///
  /// In en, this message translates to:
  /// **'Not available yet. RoadPack will not track riders under 18 until a parent or guardian can be properly confirmed.'**
  String get consentVerifierNotAvailable;

  /// No description provided for @consentParentalConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Parent or guardian confirmed.'**
  String get consentParentalConfirmed;

  /// No description provided for @consentParentalNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'RoadPack cannot confirm a parent or guardian yet, so it will not track riders under 18. Everything else still works.'**
  String get consentParentalNotConfigured;

  /// No description provided for @consentParentalIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Please fill in your parent or guardian\'s name, number and relationship to you.'**
  String get consentParentalIncomplete;

  /// No description provided for @consentParentalVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not confirm that number. Please try again.'**
  String get consentParentalVerificationFailed;

  /// No description provided for @consentParentalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We could not reach the server. Until we can, RoadPack will not track riders under 18.'**
  String get consentParentalUnavailable;

  /// Shown when a pack action is refused by the FR-003/FR-004 gate and no specific blocker could be named.
  ///
  /// In en, this message translates to:
  /// **'RoadPack cannot start tracking yet'**
  String get consentTrackingNotPermitted;

  /// FR-014 counter-stalking: why this person can see the rider. {type} is a lower-cased circle-type name, {circleName} is the circle's own name and is never translated.
  ///
  /// In en, this message translates to:
  /// **'In your {type} circle \"{circleName}\", and that circle has location sharing on.'**
  String consentWatcherReason(String type, String circleName);

  /// FAB label and the submit button when adding a new contact.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get contactsAddButton;

  /// No description provided for @contactsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your contacts'**
  String get contactsLoadError;

  /// No description provided for @contactsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get contactsRetry;

  /// No description provided for @contactsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add at least one contact before tracking can start.'**
  String get contactsEmptyHint;

  /// No description provided for @contactsOrderHint.
  ///
  /// In en, this message translates to:
  /// **'We call them in this order. Drag to change it.'**
  String get contactsOrderHint;

  /// Below the contact list header. count = contacts saved so far, max = the hard cap (5).
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} listed'**
  String contactsCountOfMax(int count, int max);

  /// No description provided for @contactsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Nobody is listed yet.\nAn alert with nobody to send it to is not protection.'**
  String get contactsEmptyBody;

  /// No description provided for @contactsRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String contactsRemoveConfirmTitle(String name);

  /// No description provided for @contactsRemoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'They will no longer be alerted if something happens to you.'**
  String get contactsRemoveConfirmBody;

  /// Dialog action. Sentence case, distinct from the shouty commonCancel button label used elsewhere.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get contactsCancel;

  /// No description provided for @contactsRemoveButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get contactsRemoveButton;

  /// No description provided for @contactsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit emergency contact'**
  String get contactsEditTitle;

  /// No description provided for @contactsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add emergency contact'**
  String get contactsAddTitle;

  /// No description provided for @contactsPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get contactsPhoneLabel;

  /// No description provided for @contactsRelationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship (optional)'**
  String get contactsRelationshipLabel;

  /// No description provided for @contactsHowWeReachThem.
  ///
  /// In en, this message translates to:
  /// **'HOW WE REACH THEM'**
  String get contactsHowWeReachThem;

  /// No description provided for @contactsEditHint.
  ///
  /// In en, this message translates to:
  /// **'Correcting a number here does not re-send the notice they already received.'**
  String get contactsEditHint;

  /// No description provided for @contactsAddHint.
  ///
  /// In en, this message translates to:
  /// **'They get one SMS telling them they are listed, and can opt out of it. We never message them again unless something happens.'**
  String get contactsAddHint;

  /// No description provided for @contactsSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get contactsSaveButton;

  /// No description provided for @contactsRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String contactsRemoveTooltip(String name);

  /// No description provided for @contactsOptedOut.
  ///
  /// In en, this message translates to:
  /// **'Opted out of SMS'**
  String get contactsOptedOut;

  /// No description provided for @contactsNoticeSent.
  ///
  /// In en, this message translates to:
  /// **'Told they are listed'**
  String get contactsNoticeSent;

  /// No description provided for @contactsNoticePending.
  ///
  /// In en, this message translates to:
  /// **'Notice not sent yet'**
  String get contactsNoticePending;

  /// No description provided for @iceScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency card'**
  String get iceScreenTitle;

  /// No description provided for @iceSealedEyebrow.
  ///
  /// In en, this message translates to:
  /// **'YOUR CARD IS SEALED'**
  String get iceSealedEyebrow;

  /// Explains when the card unseals. Safety/privacy claim: must not be loosened in translation.
  ///
  /// In en, this message translates to:
  /// **'Your blood group, medical notes and contacts are shown to a bystander only while an emergency is active — or, if you turn it on, while you are riding. There is no always-on code for anyone to scan.'**
  String get iceSealedBody;

  /// Same sentence as the already-reviewed BystanderCopy.title, reused verbatim (rendered in an eyebrow/caps style, but Hindi and Malayalam have no case to transform).
  ///
  /// In en, this message translates to:
  /// **'THIS PERSON MAY NEED HELP'**
  String get iceBandHeading;

  /// No description provided for @iceLabelCallThese.
  ///
  /// In en, this message translates to:
  /// **'Call these people'**
  String get iceLabelCallThese;

  /// No description provided for @iceNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts listed'**
  String get iceNoContacts;

  /// Honesty clause read at the roadside. Must never imply the app dispatches an ambulance or contacts 112 on the rider's behalf. Keep "RoadPack" and "112" untranslated.
  ///
  /// In en, this message translates to:
  /// **'RoadPack alerts this rider’s circle. It does not call an ambulance. For emergency services, dial 112.'**
  String get iceDisclaimer;

  /// No description provided for @iceBloodGroupMissing.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get iceBloodGroupMissing;

  /// Error reading tile cache stats. {message} is untranslated technical detail, same pattern as commonError.
  ///
  /// In en, this message translates to:
  /// **'Could not read the cache: {message}'**
  String mapCacheReadError(String message);

  /// Error reading learned-route plans. {message} is untranslated technical detail.
  ///
  /// In en, this message translates to:
  /// **'Could not read your routes: {message}'**
  String mapRoutesReadError(String message);

  /// No description provided for @mapYourRoutesEyebrow.
  ///
  /// In en, this message translates to:
  /// **'YOUR ROUTES'**
  String get mapYourRoutesEyebrow;

  /// No description provided for @mapNoRoutesLearned.
  ///
  /// In en, this message translates to:
  /// **'No routes learned yet. RoadPack works out your regular routes from trips you actually take.'**
  String get mapNoRoutesLearned;

  /// No description provided for @mapStoredOnPhoneEyebrow.
  ///
  /// In en, this message translates to:
  /// **'STORED ON THIS PHONE'**
  String get mapStoredOnPhoneEyebrow;

  /// Number of map tiles held in the offline cache.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tile} other{{count} tiles}}'**
  String mapTileCount(int count);

  /// No description provided for @mapCacheInMemoryOnlyNotice.
  ///
  /// In en, this message translates to:
  /// **'This cache is held in memory only and is emptied when the app restarts.'**
  String get mapCacheInMemoryOnlyNotice;

  /// No description provided for @mapClearCachedDataButton.
  ///
  /// In en, this message translates to:
  /// **'Clear cached map data'**
  String get mapClearCachedDataButton;

  /// One learned route's planned tile coverage. estimatedSize is a pre-formatted byte string (e.g. "12 MB") from TileCacheStats.formatBytes; km is kept as a Latin unit.
  ///
  /// In en, this message translates to:
  /// **'{tiles} tiles across {zoomLevels} zoom levels · ~{estimatedSize} estimated · {bufferKm} km buffer'**
  String mapRegionCoverageLine(
    int tiles,
    int zoomLevels,
    String estimatedSize,
    int bufferKm,
  );

  /// Same as mapRegionCoverageLine, plus the accuracy caveat when the route corridor is only approximated from its two endpoints. Kept as one full string rather than appending a fragment, so no translated pieces are concatenated at the call site.
  ///
  /// In en, this message translates to:
  /// **'{tiles} tiles across {zoomLevels} zoom levels · ~{estimatedSize} estimated · {bufferKm} km buffer · corridor estimated from start and end only'**
  String mapRegionCoverageLineCorridor(
    int tiles,
    int zoomLevels,
    String estimatedSize,
    int bufferKm,
  );

  /// Shown when the live-members fetch failed. Must still read as "this data may be old", never as "still updating normally".
  ///
  /// In en, this message translates to:
  /// **'Positions could not be refreshed. Nothing on this map is newer than the age shown on each member.'**
  String get mapOfflineNoticeText;

  /// No description provided for @mapEmptyNoticeText.
  ///
  /// In en, this message translates to:
  /// **'No one is sharing location with you. Location sharing is a per-circle setting, and each member controls their own.'**
  String get mapEmptyNoticeText;

  /// Both some members unreachable and some stale. Honesty-critical: never soften "not updating / no signal" into anything implying a normal sync.
  ///
  /// In en, this message translates to:
  /// **'{unreachableCount, plural, =1{1 with no signal} other{{unreachableCount} with no signal}}, {staleCount, plural, =1{1 not updating} other{{staleCount} not updating}} — these markers show where they were, not where they are.'**
  String mapStaleBannerBoth(int unreachableCount, int staleCount);

  /// Only unreachable members, no stale ones. See mapStaleBannerBoth.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 with no signal} other{{count} with no signal}} — these markers show where they were, not where they are.'**
  String mapStaleBannerNoSignalOnly(int count);

  /// Only stale members, no unreachable ones. See mapStaleBannerBoth.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 not updating} other{{count} not updating}} — these markers show where they were, not where they are.'**
  String mapStaleBannerNotUpdatingOnly(int count);

  /// No description provided for @mapLastUpdateLabel.
  ///
  /// In en, this message translates to:
  /// **'Last update'**
  String get mapLastUpdateLabel;

  /// No description provided for @mapSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get mapSpeedLabel;

  /// No description provided for @mapBatteryLabel.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get mapBatteryLabel;

  /// duration is a pre-formatted compact age string produced by MemberPresence.formatAge (e.g. "4m", "1h 02m") — the model file that builds it is outside this pass's scope, so the unit letters inside {duration} itself stay in their current form. Flagging so a reviewer confirms "{duration} ago" still reads naturally with that shape dropped in.
  ///
  /// In en, this message translates to:
  /// **'{duration} ago'**
  String mapLastUpdateValue(String duration);

  /// km/h kept as the Latin unit abbreviation in every locale.
  ///
  /// In en, this message translates to:
  /// **'{speed} km/h'**
  String mapSpeedValue(int speed);

  /// Speed value withheld because the fix is stale. Must not read as "loading" or "syncing" — the fix is old, not pending.
  ///
  /// In en, this message translates to:
  /// **'not current'**
  String get mapSpeedNotCurrent;

  /// No description provided for @mapSpeedUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get mapSpeedUnknown;

  /// No description provided for @mapBatteryValue.
  ///
  /// In en, this message translates to:
  /// **'{battery}%'**
  String mapBatteryValue(int battery);

  /// No description provided for @mapFootnoteLocating.
  ///
  /// In en, this message translates to:
  /// **'Nothing is being shown on the map for this member yet.'**
  String get mapFootnoteLocating;

  /// Honesty clause on a live/stationary member's detail sheet. Must never imply RoadPack dispatches help or contacts 112 itself.
  ///
  /// In en, this message translates to:
  /// **'RoadPack shortens the gap between an incident and help being aware. It does not dispatch anyone. In an emergency, call 112.'**
  String get mapFootnoteLive;

  /// Honesty clause on a stale/unreachable member's detail sheet. Must clearly say the position is OLD, never present it as a live or estimated current position.
  ///
  /// In en, this message translates to:
  /// **'The marker has not moved because no new fix has arrived. It is not an estimate of where they are now.'**
  String get mapFootnoteStale;

  /// No description provided for @mapPresenceLocating.
  ///
  /// In en, this message translates to:
  /// **'Locating'**
  String get mapPresenceLocating;

  /// No description provided for @mapPresenceLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get mapPresenceLive;

  /// The rider is reporting and is not moving. Must stay clearly distinct from mapPresenceNoSignal.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get mapPresenceStopped;

  /// Nothing is being heard from the device. Must stay clearly distinct from mapPresenceStopped.
  ///
  /// In en, this message translates to:
  /// **'No signal'**
  String get mapPresenceNoSignal;

  /// {age} is a compact pre-formatted duration such as "4m" or "1h 05m".
  ///
  /// In en, this message translates to:
  /// **'Last seen {age} ago'**
  String mapPresenceLastSeen(String age);

  /// Lower-case inline variant of mapPresenceLastSeen.
  ///
  /// In en, this message translates to:
  /// **'last seen {age} ago'**
  String mapAgeLabel(String age);

  /// No description provided for @mapPresenceDetailLocating.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a first fix from this device.'**
  String get mapPresenceDetailLocating;

  /// No description provided for @mapPresenceDetailLive.
  ///
  /// In en, this message translates to:
  /// **'Position updated {age} ago.'**
  String mapPresenceDetailLive(String age);

  /// No description provided for @mapPresenceDetailStopped.
  ///
  /// In en, this message translates to:
  /// **'Still reporting, not moving.'**
  String get mapPresenceDetailStopped;

  /// Honesty rule 1. A stale position must never read as live. Do not soften this in any language.
  ///
  /// In en, this message translates to:
  /// **'This is where they were, not where they are.'**
  String get mapPresenceDetailStale;

  /// No description provided for @mapPresenceDetailUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Nothing heard for {age}. Last known position shown.'**
  String mapPresenceDetailUnreachable(String age);

  /// No description provided for @mapRegionStatusNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get mapRegionStatusNotDownloaded;

  /// No description provided for @mapRegionStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get mapRegionStatusDownloading;

  /// No description provided for @mapRegionStatusDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get mapRegionStatusDownloaded;

  /// No description provided for @mapRegionStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get mapRegionStatusFailed;

  /// Says plainly that offline maps do not work yet. Must not be softened into a promise.
  ///
  /// In en, this message translates to:
  /// **'Offline areas are planned and measured, but the base map still needs a connection. Google Maps draws tiles inside its own SDK and gives the app no way to pre-load them. Switching to a self-hosted OSM tile source is what makes offline maps actually work.'**
  String get mapOfflineLimitationNotice;

  /// No description provided for @packCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a pack ride'**
  String get packCreateTitle;

  /// No description provided for @packDestinationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the destination as latitude, longitude'**
  String get packDestinationInvalid;

  /// No description provided for @packRideNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Ride name (optional)'**
  String get packRideNameLabel;

  /// Example hint text in the ride-name field. "Munnar" is a place name and is kept; only the accompanying word is translated.
  ///
  /// In en, this message translates to:
  /// **'Munnar run'**
  String get packRideNameHint;

  /// No description provided for @packCircleLabel.
  ///
  /// In en, this message translates to:
  /// **'Circle (optional)'**
  String get packCircleLabel;

  /// No description provided for @packCircleHelper.
  ///
  /// In en, this message translates to:
  /// **'Members of this circle can find the ride'**
  String get packCircleHelper;

  /// No description provided for @packNoCircleOption.
  ///
  /// In en, this message translates to:
  /// **'No circle'**
  String get packNoCircleOption;

  /// No description provided for @packDestinationHeading.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get packDestinationHeading;

  /// No description provided for @packLatitudeLabel.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get packLatitudeLabel;

  /// No description provided for @packLongitudeLabel.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get packLongitudeLabel;

  /// No description provided for @packCreateShareNotice.
  ///
  /// In en, this message translates to:
  /// **'Everyone who joins shares their position with the pack until the ride ends, and for at most 12 hours. RoadPack does not call for help — in an emergency, dial 112.'**
  String get packCreateShareNotice;

  /// No description provided for @packCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create ride'**
  String get packCreateSubmit;

  /// No description provided for @packPasteLinkError.
  ///
  /// In en, this message translates to:
  /// **'Paste the link somebody sent you'**
  String get packPasteLinkError;

  /// No description provided for @packShareLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get packShareLinkLabel;

  /// No description provided for @packJoinNotice.
  ///
  /// In en, this message translates to:
  /// **'When you join, the pack sees where you are along the route until the ride ends. You can leave at any time, and leaving removes you straight away.'**
  String get packJoinNotice;

  /// No description provided for @packJoinSubmit.
  ///
  /// In en, this message translates to:
  /// **'Join ride'**
  String get packJoinSubmit;

  /// Fallback AppBar title when the ride has no name.
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get packDefaultRideName;

  /// No description provided for @packEndRideAction.
  ///
  /// In en, this message translates to:
  /// **'End ride'**
  String get packEndRideAction;

  /// Shared by the FAB label and the status sheet heading — identical text in both places.
  ///
  /// In en, this message translates to:
  /// **'Tell the pack'**
  String get packTellPack;

  /// No description provided for @packEmptyRoster.
  ///
  /// In en, this message translates to:
  /// **'Nobody has joined yet. Share the link to fill the pack.'**
  String get packEmptyRoster;

  /// No description provided for @packEndRideConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'End this ride?'**
  String get packEndRideConfirmTitle;

  /// No description provided for @packEndRideConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Everyone stops sharing and the link stops working immediately. This cannot be undone.'**
  String get packEndRideConfirmBody;

  /// No description provided for @packKeepRidingAction.
  ///
  /// In en, this message translates to:
  /// **'Keep riding'**
  String get packKeepRidingAction;

  /// No description provided for @packAddNoteAction.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get packAddNoteAction;

  /// No description provided for @packNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get packNoteLabel;

  /// No description provided for @packNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Tyre puncture, 20 min'**
  String get packNoteHint;

  /// No description provided for @packShareHonestyNotice.
  ///
  /// In en, this message translates to:
  /// **'RoadPack shares where you are. It does not call for help — in an emergency, dial 112.'**
  String get packShareHonestyNotice;

  /// No description provided for @packStatusRiding.
  ///
  /// In en, this message translates to:
  /// **'Riding'**
  String get packStatusRiding;

  /// No description provided for @packStatusRefueling.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get packStatusRefueling;

  /// No description provided for @packStatusTakingBreak.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get packStatusTakingBreak;

  /// No description provided for @packStatusWrongTurn.
  ///
  /// In en, this message translates to:
  /// **'Wrong turn'**
  String get packStatusWrongTurn;

  /// No description provided for @packStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get packStatusWaiting;

  /// A rider who chose to stop. Must read as clearly different from packStatusUnreachable (a dead zone) in every language.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get packStatusStopped;

  /// No description provided for @packStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get packStatusDone;

  /// Automatic-only: stationary past the threshold with no rider explanation. Not an impact.
  ///
  /// In en, this message translates to:
  /// **'Stopped, unexplained'**
  String get packStatusUnexplainedStop;

  /// Automatic-only: the phone stopped reporting (a dead zone). Must read as clearly different from packStatusStopped in every language.
  ///
  /// In en, this message translates to:
  /// **'No signal'**
  String get packStatusUnreachable;

  /// Automatic-only, emergency tier. Crash detection fired. Must not imply RoadPack has dispatched help.
  ///
  /// In en, this message translates to:
  /// **'Possible incident'**
  String get packStatusPossibleIncident;

  /// Short chip tag marking an automatic (not rider-set) status. Unlike SOS it is a word, not a mark, so it is translated — the native-script forms are short enough for the chip.
  ///
  /// In en, this message translates to:
  /// **'AUTO'**
  String get packAutoTag;

  /// No description provided for @packRoleLeader.
  ///
  /// In en, this message translates to:
  /// **'Leader'**
  String get packRoleLeader;

  /// Convoy term for the rider at the back watching for stragglers. Not confident of an idiomatic one-word equivalent in either language.
  ///
  /// In en, this message translates to:
  /// **'Sweep'**
  String get packRoleSweep;

  /// No description provided for @packRoleRider.
  ///
  /// In en, this message translates to:
  /// **'Rider'**
  String get packRoleRider;

  /// No description provided for @packGapFront.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get packGapFront;

  /// No description provided for @packOffRouteHeadline.
  ///
  /// In en, this message translates to:
  /// **'Off route'**
  String get packOffRouteHeadline;

  /// No description provided for @packLastSeenHeadline.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get packLastSeenHeadline;

  /// No description provided for @packLocatingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Locating'**
  String get packLocatingHeadline;

  /// No description provided for @packStraightLineUnknown.
  ///
  /// In en, this message translates to:
  /// **'straight line unknown'**
  String get packStraightLineUnknown;

  /// distance is a pre-formatted, unit-suffixed string ("620 m") from formatDistance(); the placeholder is substituted whole, never built by concatenating separately-translated words.
  ///
  /// In en, this message translates to:
  /// **'{distance} away'**
  String packDistanceAway(String distance);

  /// No description provided for @packNoFixYet.
  ///
  /// In en, this message translates to:
  /// **'no fix yet'**
  String get packNoFixYet;

  /// No description provided for @packJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get packJustNow;

  /// duration is a pre-formatted compact string ("4m", "1h 30m") from formatDuration(); a single ICU placeholder, never a plural built by string addition. Care point: a stale position must never read as live — this string only ever appears attached to the "Last seen" headline, never substituted for a live gap.
  ///
  /// In en, this message translates to:
  /// **'{duration} ago'**
  String packAgoCompact(String duration);

  /// No description provided for @packBehindLabel.
  ///
  /// In en, this message translates to:
  /// **'BEHIND'**
  String get packBehindLabel;

  /// An estimated gap with no duration figure. Must still read as estimated, not measured.
  ///
  /// In en, this message translates to:
  /// **'BEHIND EST'**
  String get packBehindLabelEst;

  /// No description provided for @packBehindWithDuration.
  ///
  /// In en, this message translates to:
  /// **'{duration} BEHIND'**
  String packBehindWithDuration(String duration);

  /// Care point: an estimated value must still read as estimated after translation — the estimate word must survive here.
  ///
  /// In en, this message translates to:
  /// **'{duration} BEHIND EST'**
  String packBehindWithDurationEst(String duration);

  /// No description provided for @packYouLabel.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get packYouLabel;

  /// No description provided for @packNameYouSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String packNameYouSuffix(String name);

  /// No description provided for @packSharingLiveHeadline.
  ///
  /// In en, this message translates to:
  /// **'This ride is being shared'**
  String get packSharingLiveHeadline;

  /// No description provided for @packSharingOffHeadline.
  ///
  /// In en, this message translates to:
  /// **'Sharing is off'**
  String get packSharingOffHeadline;

  /// expiry is itself a fully localized phrase (packExpiresNow / packExpiresInHours / packExpiresInMinutes) substituted as one opaque placeholder — nested composition, not concatenation of untranslated fragments.
  ///
  /// In en, this message translates to:
  /// **'Anyone with the link can see where the pack is until {expiry}. Riders can see the viewer count.'**
  String packLiveNotice(String expiry);

  /// No description provided for @packLinkExpiredNotice.
  ///
  /// In en, this message translates to:
  /// **'The link no longer resolves. Nobody can see this ride.'**
  String get packLinkExpiredNotice;

  /// No description provided for @packExpiresNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get packExpiresNow;

  /// hours is a plain number; the unit letter "h" is kept, matching the compact-duration convention used elsewhere in this feature.
  ///
  /// In en, this message translates to:
  /// **'it expires in {hours}h'**
  String packExpiresInHours(int hours);

  /// No description provided for @packExpiresInMinutes.
  ///
  /// In en, this message translates to:
  /// **'it expires in {minutes}m'**
  String packExpiresInMinutes(int minutes);

  /// No description provided for @packShareLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get packShareLinkAction;

  /// No description provided for @packCopyLinkTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get packCopyLinkTooltip;

  /// No description provided for @packStopSharingAction.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing this ride'**
  String get packStopSharingAction;

  /// No description provided for @packLinkCopiedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get packLinkCopiedSnackbar;

  /// No description provided for @packDefaultShareRideName.
  ///
  /// In en, this message translates to:
  /// **'our ride'**
  String get packDefaultShareRideName;

  /// No description provided for @packShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Follow {name} live: {url}\n\nRoadPack shows where the pack is. It does not call an ambulance — for an emergency, dial 112.'**
  String packShareMessage(String name, String url);

  /// No description provided for @packWatchingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 watching} other{{count} watching}}'**
  String packWatchingCount(int count);

  /// No description provided for @packNotShared.
  ///
  /// In en, this message translates to:
  /// **'not shared'**
  String get packNotShared;
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
      <String>['en', 'hi', 'ml'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'ml':
      return AppLocalizationsMl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
