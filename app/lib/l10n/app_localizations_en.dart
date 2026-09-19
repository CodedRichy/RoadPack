// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RoadPack';

  @override
  String get commonCancel => 'CANCEL';

  @override
  String get commonClose => 'CLOSE';

  @override
  String get commonImOkay => 'I\'M OKAY';

  @override
  String get commonOn => 'on';

  @override
  String get commonOff => 'off';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonSelect => 'Select';

  @override
  String get commonName => 'Name';

  @override
  String get commonNotSignedIn => 'Not signed in';

  @override
  String commonError(String message) {
    return 'Error: $message';
  }

  @override
  String get commonCall112 => 'Call 112';

  @override
  String get sosLabel => 'SOS';

  @override
  String get sosAlertTitle => 'SOS ALERT';

  @override
  String get sosHoldHint => 'Hold for 2 seconds to trigger SOS';

  @override
  String get sosCountdownBody =>
      'Emergency alerts will be sent to your contacts';

  @override
  String get sosSentTitle => 'Emergency Alerts Sent';

  @override
  String get sosSentBody => 'Your emergency contacts are being notified.';

  @override
  String get incidentResolvedTitle => 'Incident Resolved';

  @override
  String get incidentResolvedBody =>
      'Your contacts have been notified that you are safe.';

  @override
  String incidentRef(String ref) {
    return 'Incident: $ref';
  }

  @override
  String get crashDetectedTitle => 'CRASH DETECTED';

  @override
  String crashCountdownBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alerting your emergency contacts in $count seconds',
      one: 'Alerting your emergency contacts in 1 second',
    );
    return '$_temp0';
  }

  @override
  String get crashAlertSentTitle => 'CRASH ALERT SENT';

  @override
  String get crashAlertSentBody =>
      'Your emergency contacts have been notified of a possible crash.';

  @override
  String get crashReasonQuestion => 'What happened?';

  @override
  String get crashReasonPothole => 'Pothole / speed bump';

  @override
  String get crashReasonPhoneDropped => 'Phone dropped';

  @override
  String get crashReasonSuddenBraking => 'Sudden braking';

  @override
  String get crashReasonOther => 'Other';

  @override
  String get crashReasonOtherHint => 'Describe what happened';

  @override
  String get crashReasonConfirm => 'Confirm - I\'m Fine';

  @override
  String get alertTitle => 'Alert';

  @override
  String get alertNotFound => 'Alert not found';

  @override
  String get alertDetailTitle => 'Emergency Alert';

  @override
  String alertVictimHeadline(String name) {
    return '$name may have been in an accident';
  }

  @override
  String alertLocationLine(String lat, String lng) {
    return 'Location: $lat, $lng';
  }

  @override
  String alertTimeLine(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.yMMMd(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Time: $timeString';
  }

  @override
  String get alertAcknowledge => 'ACKNOWLEDGE';

  @override
  String get alertAcknowledged => 'Acknowledged';

  @override
  String alertCallPerson(String name) {
    return 'Call $name';
  }

  @override
  String get alertOpenInMaps => 'Open in Maps';

  @override
  String alertCardTitle(String name) {
    return '$name — Emergency';
  }

  @override
  String get alertCardTapToView => 'Tap to view and acknowledge';

  @override
  String get homeSwitchToNight => 'Switch to night';

  @override
  String get homeSwitchToSunlight => 'Switch to sunlight';

  @override
  String get protectionEyebrow => 'PROTECTION';

  @override
  String get checkCrashDetection => 'Crash\ndetection';

  @override
  String get checkLocationTracking => 'Location\ntracking';

  @override
  String get checkNonArrival => 'Non-arrival\nalerts';

  @override
  String get checkEmergencyContact => 'Emergency\ncontact';

  @override
  String checkSemantics(String label, String state) {
    return '$label: $state';
  }

  @override
  String get watchersHeading => 'WHO IS WATCHING';

  @override
  String get watchersError => 'Circles could not load. Pull down to try again.';

  @override
  String get watchersEmpty =>
      'Nobody yet. A circle is who gets called when you cannot call.';

  @override
  String get watchersCreateCircle => 'Create a circle';

  @override
  String circleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count  circles',
      one: '$count  circle',
    );
    return '$_temp0';
  }

  @override
  String circleCountWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'circles',
      one: 'circle',
    );
    return '$_temp0';
  }

  @override
  String get packEyebrow => 'RIDING WITH OTHERS';

  @override
  String get packTagline => 'Everyone sees the gap, not just a dot';

  @override
  String get packStartRide => 'Start a ride';

  @override
  String get packJoinRide => 'Join a ride';

  @override
  String get navLiveMap => 'Live map';

  @override
  String get navSafetyCircles => 'Safety circles';

  @override
  String get navCommutes => 'Commutes and non-arrival';

  @override
  String get navKnownRoutes => 'Known routes';

  @override
  String get navTripHistory => 'Trip history';

  @override
  String get milestoneCapArmed => 'ALL SYSTEMS WATCHING';

  @override
  String get milestoneHeadlineArmed => 'Covered';

  @override
  String get milestoneDetailArmed =>
      'Crash detection, tracking and non-arrival alerts are all live. If you go down, your circles hear about it.';

  @override
  String get milestoneCapPartial => 'GAPS IN COVER';

  @override
  String get milestoneHeadlinePartial => 'Partly covered';

  @override
  String get milestoneDetailPartial =>
      'Some systems are off. Turn the rest on before you ride, or nobody gets told about the part they cover.';

  @override
  String get milestoneCapOff => 'NOTHING IS WATCHING';

  @override
  String get milestoneHeadlineOff => 'Not covered';

  @override
  String get milestoneDetailOff =>
      'No crash detection, no tracking, no alerts. Turn on protection in Settings before your next ride.';

  @override
  String get milestoneCapIncident => 'INCIDENT LIVE';

  @override
  String get milestoneHeadlineIncident => 'Help is being called';

  @override
  String get milestoneDetailIncident =>
      'Your circles are being alerted right now.';

  @override
  String milestoneSemantics(String headline, String detail, int active) {
    return 'Protection $headline. $detail $active of 3 systems active.';
  }

  @override
  String get milestoneSemanticsContactSet => 'Emergency contact set.';

  @override
  String get milestoneSemanticsContactMissing => 'No emergency contact.';

  @override
  String get gapNoContactHeadline => 'Nobody to call';

  @override
  String get gapNoContactDetail =>
      'You have no emergency contact. Crash detection can fire and the alert reaches nobody. Add one contact and the rest starts working.';

  @override
  String get gapNoContactAction => 'Add a contact';

  @override
  String get gapCrashOffHeadline => 'Crash detection is off';

  @override
  String get gapCrashOffDetail =>
      'Nothing is listening for an impact. If you go down and cannot reach your phone, nobody is told.';

  @override
  String get gapTurnOnAction => 'Turn it on';

  @override
  String get gapTrackingOffHeadline => 'Location tracking is off';

  @override
  String get gapTrackingOffDetail =>
      'Your circles can be alerted, but not told where you are. Help arrives slower when it has to search.';

  @override
  String get gapNonArrivalOffHeadline => 'Non-arrival alerts are off';

  @override
  String get gapNonArrivalOffDetail =>
      'If you never reach your destination, nothing raises it. Set up a commute route to close this.';

  @override
  String get gapSetUpCommutesAction => 'Set up commutes';

  @override
  String get settingsSectionSafety => 'Safety';

  @override
  String get settingsCrashSensitivity => 'Crash Sensitivity';

  @override
  String get settingsSensitivityHigh => 'High';

  @override
  String get settingsSensitivityMedium => 'Medium';

  @override
  String get settingsSensitivityLow => 'Low';

  @override
  String get settingsSensitivityHighDetail =>
      'High - More sensitive, may have more false alerts';

  @override
  String get settingsSensitivityMediumDetail =>
      'Medium - Balanced (recommended)';

  @override
  String get settingsSensitivityLowDetail =>
      'Low - Less sensitive, fewer false alerts';

  @override
  String get settingsPhoneMount => 'Phone Mount';

  @override
  String get settingsMountBar => 'Bar';

  @override
  String get settingsMountPocket => 'Pocket';

  @override
  String get settingsMountBag => 'Bag';

  @override
  String get settingsMountOther => 'Other';

  @override
  String get settingsMountBarDetail => 'Handlebar mount (most sensitive)';

  @override
  String get settingsMountPocketDetail => 'In pocket';

  @override
  String get settingsMountBagDetail => 'In bag (least sensitive)';

  @override
  String get settingsMountUnknownDetail => 'Other / Unknown';

  @override
  String get settingsSectionTracking => 'Tracking';

  @override
  String get settingsNonArrivalAlerts => 'Non-Arrival Alerts';

  @override
  String get settingsNonArrivalAlertsSub =>
      'Alert contacts if you don\'t arrive';

  @override
  String get settingsAlertDelay => 'Alert Delay';

  @override
  String settingsAlertDelaySub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes after expected arrival',
      one: '1 minute after expected arrival',
    );
    return '$_temp0';
  }

  @override
  String minutesShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String get settingsCommuteRoutes => 'Commute routes';

  @override
  String get settingsCommuteRoutesSub =>
      'Routes that raise an alert when you do not arrive';

  @override
  String get settingsSectionEmergency => 'Emergency';

  @override
  String get settingsEmergencyContacts => 'Emergency contacts';

  @override
  String get settingsEmergencyContactsReady =>
      'Who gets called when you cannot call';

  @override
  String get settingsEmergencyContactsEmpty =>
      'None yet — alerts have nobody to reach';

  @override
  String get settingsIceCard => 'ICE card';

  @override
  String get settingsIceCardSub => 'What a first responder sees at the scene';

  @override
  String get settingsBystanderPreview => 'See what a bystander sees';

  @override
  String get settingsBystanderPreviewSub =>
      'Check your crash screen before you need it';

  @override
  String get settingsIceCommuteToggle => 'Show ICE card during commutes';

  @override
  String get settingsIceCommuteToggleSub =>
      'Off by default. On, a helper at the scene can see your blood group and contacts during a tracked commute, not only after a crash.';

  @override
  String get settingsSectionMaps => 'Maps';

  @override
  String get settingsOfflineMaps => 'Offline maps';

  @override
  String get settingsOfflineMapsSub => 'Download regions for dead-zone riding';

  @override
  String get settingsSectionEmergencyProfile => 'Emergency Profile';

  @override
  String get settingsBloodGroup => 'Blood Group';

  @override
  String get settingsMedicalNotes => 'Medical Notes';

  @override
  String get settingsMedicalNotesHint =>
      'Allergies, conditions, medications...';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsVehicle => 'Vehicle';

  @override
  String get settingsSignOut => 'Sign Out';

  @override
  String get settingsSectionLanguage => 'Language';

  @override
  String get settingsLanguageSub => 'Emergency screens use this language too';

  @override
  String get languageSystemDefault => 'Match my phone';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get languageMalayalam => 'മലയാളം';

  @override
  String get circlesJoinCircleTitle => 'Join Circle';

  @override
  String get circlesCreateCircle => 'Create Circle';

  @override
  String get circlesLoadError => 'Something went wrong';

  @override
  String get circlesRetry => 'Retry';

  @override
  String get circlesEmptyTitle => 'Create your first Safety Circle';

  @override
  String get circlesEmptyBody =>
      'Your circles help ensure the right people are alerted when something happens on the road';

  @override
  String get circlesRegenerateCode => 'Regenerate invite code';

  @override
  String get circlesDeleteCircle => 'Delete circle';

  @override
  String circlesMembersHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Members ($count)',
      one: 'Member (1)',
    );
    return '$_temp0';
  }

  @override
  String circlesObserversHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Observers ($count)',
      one: 'Observer (1)',
    );
    return '$_temp0';
  }

  @override
  String get circlesObserverSmsTag => 'SMS';

  @override
  String get circlesAddObserverAction => 'Add Observer';

  @override
  String get circlesObserverSmsExplainer =>
      'Observers receive SMS alerts but don\'t need the app.';

  @override
  String get circlesPhoneNumberLabel => 'Phone number';

  @override
  String get circlesAddAction => 'Add';

  @override
  String get circlesLeaveDialogTitle => 'Leave circle?';

  @override
  String get circlesLeaveFamilyWarning =>
      'Leaving will remove all emergency contact links from this circle.';

  @override
  String get circlesLeaveConfirm => 'Are you sure you want to leave?';

  @override
  String get circlesLeaveAction => 'Leave';

  @override
  String circlesLeaveError(String message) {
    return 'Could not leave: $message';
  }

  @override
  String get circlesDeleteDialogTitle => 'Delete circle?';

  @override
  String get circlesDeleteWarning => 'This cannot be undone.';

  @override
  String get circlesDeleteAction => 'Delete';

  @override
  String circlesNewCodeSnackbar(String code) {
    return 'New code: $code';
  }

  @override
  String get circlesRoleUpdateError =>
      'Failed to update role. Please try again.';

  @override
  String get circlesRemoveMemberError =>
      'Failed to remove member. Please try again.';

  @override
  String get circlesRemoveObserverError =>
      'Failed to remove observer. Please try again.';

  @override
  String get circlesEcUpdateError =>
      'Failed to update emergency contact. Please try again.';

  @override
  String circlesShareInviteMessage(String code) {
    return 'Join my Safety Circle on RoadPack! Code: $code';
  }

  @override
  String get circlesNameLabel => 'Circle name';

  @override
  String circlesDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String get circlesDurationLabel => 'Duration';

  @override
  String get circlesCreateAction => 'Create';

  @override
  String get circlesLocationSharingTitle => 'Let this circle see live location';

  @override
  String get circlesLocationSharingOnDetail =>
      'Everyone in this circle will be able to see where each member is. You can turn this off later.';

  @override
  String get circlesLocationSharingOffDetail =>
      'Off. Members still get alerted if someone crashes — they just cannot watch each other the rest of the time.';

  @override
  String get circlesInvalidCodeError => 'Invalid code';

  @override
  String get circlesEnterCodeHeading => 'Enter invite code';

  @override
  String circlesMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get circlesJoinAction => 'Join';

  @override
  String get circlesWhoCanSeeMeTitle => 'Who can see me';

  @override
  String get circlesChangeFailedMessage =>
      'Could not change that. Nothing was changed.';

  @override
  String circlesWatcherCountHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people can see your location',
      one: '1 person can see your location',
      zero: 'Nobody can see your location',
    );
    return '$_temp0';
  }

  @override
  String get circlesFullListNotice =>
      'This is the full list. RoadPack has no hidden mode — if someone can see you, they are on this page.';

  @override
  String get circlesNoCirclesYet =>
      'You are not in any circles yet, so there is nobody to see you.';

  @override
  String get circlesLoadWhoCanSeeError => 'We could not load who can see you';

  @override
  String get circlesLoadWhoCanSeeErrorDetail =>
      'Do not assume this means nobody can. Try again when you have signal.';

  @override
  String get circlesTryAgainAction => 'Try again';

  @override
  String circlesCardSubtitle(String type, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$type -- $count members',
      one: '$type -- 1 member',
    );
    return '$_temp0';
  }

  @override
  String get circlesExpiredTag => 'Expired';

  @override
  String get circlesTypeFamily => 'Family';

  @override
  String get circlesTypeFriends => 'Friends';

  @override
  String get circlesTypeCommute => 'Commute Group';

  @override
  String get circlesTypeConvoy => 'Convoy';

  @override
  String get circlesTypeFamilyDefaultName => 'My Family';

  @override
  String get circlesTypeFriendsDefaultName => 'Friends';

  @override
  String get circlesTypeCommuteDefaultName => 'Commute Group';

  @override
  String get circlesTypeConvoyDefaultName => 'Convoy';

  @override
  String get circlesTypeFamilyDescription =>
      'Your closest people. Members are automatically added as emergency contacts.';

  @override
  String get circlesTypeFriendsDescription =>
      'Friends who ride or commute. Add specific members as emergency contacts.';

  @override
  String get circlesTypeCommuteDescription => 'Regular commute group.';

  @override
  String get circlesTypeConvoyDescription =>
      'Temporary group ride. Set a duration.';

  @override
  String get circlesRoleAdmin => 'Admin';

  @override
  String get circlesRoleMember => 'Member';

  @override
  String get circlesRoleObserver => 'Observer';

  @override
  String get circlesUnknownMember => 'Unknown';

  @override
  String get circlesYouTag => '(you)';

  @override
  String get circlesMenuLeaveCircle => 'Leave circle';

  @override
  String get circlesMenuDemote => 'Demote to member';

  @override
  String get circlesMenuPromote => 'Promote to admin';

  @override
  String get circlesMenuRemove => 'Remove';

  @override
  String get circlesMenuMarkEc => 'Mark as emergency contact';

  @override
  String get circlesMenuRemoveEc => 'Remove as emergency contact';

  @override
  String get circlesMonthlyCheckTitle => 'Monthly check: who can see you?';

  @override
  String circlesWatcherCountBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people can see your location right now.',
      one: '1 person can see your location right now.',
      zero:
          'Nobody can see your location right now. Worth a look anyway — circles change.',
    );
    return '$_temp0';
  }

  @override
  String get circlesReviewListAction => 'Review the list';

  @override
  String get circlesNotNowAction => 'Not now';

  @override
  String get circlesSharingOnEmptyDetail =>
      'Location sharing is on, but there is nobody else in this circle yet.';

  @override
  String circlesWatchersHereDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people here can see where you are.',
      one: '1 person here can see where you are.',
    );
    return '$_temp0';
  }

  @override
  String get circlesSharingOffDetail =>
      'Nobody in this circle can see where you are.';

  @override
  String circlesWatcherRow(String name, String role) {
    return '$name — $role';
  }

  @override
  String get circlesShareMyLocationTitle =>
      'Share my location with this circle';

  @override
  String get circlesSelfSharingOnDetail =>
      'Turning this off hides your live position from this circle. You stay a member, and if you crash they are still alerted with your location.';

  @override
  String get circlesSelfSharingOffDetail =>
      'Your live position is hidden from this circle. You are still a member, you still get their alerts, and if you crash they are still told where you are.';

  @override
  String get circlesAdminOnlyOptOutNotice =>
      'Only this circle\'s admin can change the circle-wide setting, but the switch above stops your own location being shared. You can also leave.';

  @override
  String get circlesAdminOnlyNoOptOutNotice =>
      'Only this circle\'s admin can change its sharing setting. If you are not comfortable, you can leave the circle — it takes effect at once, and RoadPack will never stop you.';

  @override
  String get circlesLeaveThisCircleAction => 'Leave this circle';

  @override
  String get circlesInviteCodeLabel => 'Invite Code';

  @override
  String get circlesCodeCopiedSnackbar => 'Code copied';

  @override
  String get circlesCopyAction => 'Copy';

  @override
  String get circlesShareAction => 'Share';

  @override
  String get commuteTitle => 'Commute';

  @override
  String get commuteAddRoute => 'Add route';

  @override
  String get commuteEditRoute => 'Edit route';

  @override
  String get commuteLoadError => 'Could not load your routes';

  @override
  String get commuteYourRoutesHeading => 'YOUR ROUTES';

  @override
  String get commuteNonArrivalTitle => 'Non-arrival alerts';

  @override
  String commuteNonArrivalEnabledBody(String late) {
    return 'If you have not arrived $late, RoadPack asks you first. Your circle is only told if you do not answer.';
  }

  @override
  String get commuteNonArrivalDisabledBody =>
      'Nobody will be told if you do not arrive.';

  @override
  String get commuteAskMeAfterHeading => 'ASK ME AFTER';

  @override
  String commuteGraceWindowSemantics(String late) {
    return '$late late';
  }

  @override
  String commuteSpokenMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String commuteSpokenSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get commuteEmptyTitle => 'No routes yet';

  @override
  String commuteEmptyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'RoadPack learns a commute after $count similar trips. If you would rather not wait, add one yourself — it works straight away.',
      one:
          'RoadPack learns a commute after 1 similar trip. If you would rather not wait, add one yourself — it works straight away.',
    );
    return '$_temp0';
  }

  @override
  String get commuteDeleteRouteTooltip => 'Delete route';

  @override
  String get commuteNameHint => 'Home to college';

  @override
  String get commuteNameValidation =>
      'Give this route a name you will recognise';

  @override
  String get commuteSectionWhere => 'WHERE';

  @override
  String get commuteSectionWhen => 'WHEN';

  @override
  String get commuteSectionDays => 'DAYS';

  @override
  String get commuteStartPoint => 'Start';

  @override
  String get commuteDestinationPoint => 'Destination';

  @override
  String get commuteLocationPermissionError =>
      'RoadPack needs location permission to pin this point.';

  @override
  String get commuteLocationFixError =>
      'Could not get a fix here. Try again outdoors.';

  @override
  String get commuteIncompleteError =>
      'Set both points, a start time and at least one day.';

  @override
  String get commuteDurationLabel => 'Usually takes (minutes)';

  @override
  String get commuteDurationEmptyValidation =>
      'How long does this ride usually take?';

  @override
  String get commuteDurationTooLongValidation =>
      'That is longer than a day trip';

  @override
  String get commuteSaveChanges => 'Save changes';

  @override
  String get commuteRouteIncompleteHint =>
      'A route needs both points, a start time and at least one day before it can watch for you.';

  @override
  String get commuteUsuallyLeavesAt => 'Usually leaves at';

  @override
  String get commutePointNotSet => 'Not set';

  @override
  String get commuteUpdatePoint => 'Update';

  @override
  String get commuteUseHerePoint => 'Use here';

  @override
  String get commuteDeleteRouteTitle => 'Delete this route?';

  @override
  String get commuteDeleteRouteBody =>
      'RoadPack will stop watching for non-arrival on it.';

  @override
  String get commuteKeepAction => 'Keep';

  @override
  String get commuteDeleteAction => 'Delete';

  @override
  String get commuteDayNameMonday => 'Monday';

  @override
  String get commuteDayNameTuesday => 'Tuesday';

  @override
  String get commuteDayNameWednesday => 'Wednesday';

  @override
  String get commuteDayNameThursday => 'Thursday';

  @override
  String get commuteDayNameFriday => 'Friday';

  @override
  String get commuteDayNameSaturday => 'Saturday';

  @override
  String get commuteDayNameSunday => 'Sunday';

  @override
  String get commuteDayLetterMon => 'M';

  @override
  String get commuteDayLetterTue => 'T';

  @override
  String get commuteDayLetterWed => 'W';

  @override
  String get commuteDayLetterThu => 'T';

  @override
  String get commuteDayLetterFri => 'F';

  @override
  String get commuteDayLetterSat => 'S';

  @override
  String get commuteDayLetterSun => 'S';

  @override
  String commuteDaysActiveSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Active on $count days a week',
      one: 'Active on 1 day a week',
      zero: 'No days set',
    );
    return '$_temp0';
  }

  @override
  String get commuteTimeToAnswerHeading => 'TIME TO ANSWER';

  @override
  String commuteAnswerSemantics(String spoken) {
    return '$spoken before your circle is told.';
  }

  @override
  String get commuteNothingToCheckIn => 'Nothing to check in on.';

  @override
  String get commuteCheckingInHeading => 'CHECKING IN';

  @override
  String get commuteCircleToldHeading => 'YOUR CIRCLE HAS BEEN TOLD';

  @override
  String get commuteEverythingOkay => 'Everything okay?';

  @override
  String get commuteWeLetThemKnow => 'We let them know';

  @override
  String get commuteTravellingBody =>
      'You have not reached your usual destination. Nobody has been told yet.';

  @override
  String get commuteEscalatedBody =>
      'You did not answer, so your circle was sent an alert. Tell them you are fine when you can.';

  @override
  String get commuteAnswerCaption =>
      'If you do not answer, your circle is told.';

  @override
  String commuteSnoozeExtendedMessage(String minutes) {
    return 'Window extended by $minutes. Nobody was told.';
  }

  @override
  String get commuteGladYouMadeIt => 'Glad you made it.';

  @override
  String get commuteFineTellThem => 'I\'m fine — tell them';

  @override
  String get commuteArrivedFine => 'I\'ve arrived, I\'m fine';

  @override
  String get commuteNeedHelp => 'I need help';

  @override
  String get commuteAddedByYouBadge => 'ADDED BY YOU';

  @override
  String commuteTripsBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count TRIPS',
      one: '$count TRIP',
    );
    return '$_temp0';
  }

  @override
  String get commuteLeavesLabel => 'LEAVES';

  @override
  String get commuteTakesLabel => 'TAKES';

  @override
  String get commuteArrivesLabel => 'ARRIVES';

  @override
  String commuteLearningNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Still learning — $count more trips before this route is watched.',
      one: 'Still learning — 1 more trip before this route is watched.',
    );
    return '$_temp0';
  }

  @override
  String get commuteNotWatchingTitle => 'Not watching this route';

  @override
  String get commuteWatchingOnceLearnedTitle => 'Watching once learned';

  @override
  String commuteNeedsMoreTripsDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Needs $count more trips',
      one: 'Needs 1 more trip',
    );
    return '$_temp0';
  }

  @override
  String get commuteNotWatchingYetTitle => 'Not watching yet';

  @override
  String get commuteMissingScheduleDetail =>
      'No start time, duration or days set';

  @override
  String get commuteWatchingTitle => 'Watching for non-arrival';

  @override
  String get commuteRunningLateLabel => 'I\'m running late';

  @override
  String get commuteMuchLaterLabel => 'Much later';

  @override
  String commuteSnoozeTrailing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count min',
      one: '+1 min',
    );
    return '$_temp0';
  }

  @override
  String get commuteNobodyToldCaption => 'Nobody is told when you press this.';

  @override
  String commuteSnoozeSemantics(String label, String trailing) {
    return '$label, $trailing. Nobody is notified.';
  }

  @override
  String get consentCentreTitle => 'What I have agreed to';

  @override
  String get consentPermissionsHeading => 'Your permissions';

  @override
  String get consentPermissionsIntro =>
      'Turn any of these off whenever you want. Turning off location sharing stops RoadPack tracking you straight away.';

  @override
  String consentGrantedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'd MMMM yyyy',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return 'You said yes on $dateString';
  }

  @override
  String get consentParentalSectionBody =>
      'A parent or guardian agreed to RoadPack tracking you. They, or you, can take that back at any time — RoadPack stops tracking immediately.';

  @override
  String get consentWithdrawParentalAction => 'Withdraw parent permission';

  @override
  String get consentUnknownLedgerTitle => 'We could not check your permissions';

  @override
  String get consentUnknownLedgerBody =>
      'Until we can reach the server, RoadPack assumes you have not agreed to anything and will not track you.';

  @override
  String get consentChecking => 'Checking...';

  @override
  String get consentTryAgain => 'Try again';

  @override
  String get consentTypeTrackingTitle => 'Share my location while I ride';

  @override
  String get consentTypeTrackingMeaning =>
      'RoadPack records where you are while a ride is on, so your circle can find you if you crash.';

  @override
  String get consentTypeDataSharingAnonTitle => 'Help improve road safety maps';

  @override
  String get consentTypeDataSharingAnonMeaning =>
      'Rough, un-named location points help map dangerous stretches. Nothing sent this way carries your name or number.';

  @override
  String get consentTypeSensorUploadTitle =>
      'Send crash sensor data after a crash';

  @override
  String get consentTypeSensorUploadMeaning =>
      'After a crash, the phone sends what its sensors felt so the detection gets better.';

  @override
  String get consentTypeParentalTitle => 'Parent or guardian permission';

  @override
  String get consentTypeParentalMeaning =>
      'Because you are under 18, a parent or guardian has to say yes before RoadPack can track you at all.';

  @override
  String get consentTypeInstitutionalTitle =>
      'Share with my college or employer';

  @override
  String get consentTypeInstitutionalMeaning =>
      'Your college or employer sees group totals only — never your live position and never your contacts.';

  @override
  String get consentTypeAudioCaptureTitle => 'Record audio after a crash';

  @override
  String get consentTypeAudioCaptureMeaning =>
      'After a crash, the phone can record a short clip so help knows what it is walking into.';

  @override
  String get consentGateReadyTitle => 'RoadPack can look after you';

  @override
  String get consentGateReadyBody =>
      'Your profile is complete and you have agreed to location sharing. RoadPack still does not replace calling 112.';

  @override
  String get consentGateBlockedTitle => 'RoadPack is not tracking you yet';

  @override
  String get consentGateBlockedBody => 'Finish these and it will:';

  @override
  String get consentGateAskParentAction => 'Ask a parent or guardian';

  @override
  String get consentBlockerNameTitle => 'Add your name';

  @override
  String get consentBlockerNameBody =>
      'Whoever we call needs to know who they are being called about.';

  @override
  String get consentBlockerPhoneTitle => 'Add your phone number';

  @override
  String get consentBlockerPhoneBody =>
      'We need a number that works, so help can call you back.';

  @override
  String get consentBlockerContactTitle => 'Add an emergency contact';

  @override
  String get consentBlockerContactBody =>
      'RoadPack has nobody to alert. One contact is the minimum.';

  @override
  String get consentBlockerDobTitle => 'Add your date of birth';

  @override
  String get consentBlockerDobBody =>
      'The law treats under-18 riders differently, so we have to know which rules apply to you.';

  @override
  String get consentBlockerParentalTitle =>
      'Parent or guardian permission needed';

  @override
  String get consentBlockerParentalBody =>
      'You are under 18. A parent or guardian has to agree before RoadPack can record where you are.';

  @override
  String get consentBlockerTrackingTitle => 'Turn on location sharing';

  @override
  String get consentBlockerTrackingBody =>
      'RoadPack does not record your location until you say yes, and stops the moment you say no.';

  @override
  String get consentBlockerUnknownBody =>
      'We could not reach the server to check what you have agreed to. Until we can, RoadPack will not track you.';

  @override
  String get consentParentalScreenTitle => 'Parent or guardian permission';

  @override
  String get consentParentalFormIntro =>
      'You are under 18, so a parent or guardian has to agree before RoadPack records where you are. Nothing is tracked until they do.';

  @override
  String get consentParentalNameLabel => 'Parent or guardian name';

  @override
  String get consentParentalPhoneLabel => 'Their phone number';

  @override
  String get consentParentalRelationLabel => 'Their relationship to you';

  @override
  String get consentParentalRelationHint => 'Mother, father, guardian';

  @override
  String consentParentalMethodLine(String method) {
    return 'How we confirm them: $method';
  }

  @override
  String get consentParentalSubmitAction => 'Ask them to confirm';

  @override
  String get consentVerifierNotAvailable =>
      'Not available yet. RoadPack will not track riders under 18 until a parent or guardian can be properly confirmed.';

  @override
  String get consentParentalConfirmed => 'Parent or guardian confirmed.';

  @override
  String get consentParentalNotConfigured =>
      'RoadPack cannot confirm a parent or guardian yet, so it will not track riders under 18. Everything else still works.';

  @override
  String get consentParentalIncomplete =>
      'Please fill in your parent or guardian\'s name, number and relationship to you.';

  @override
  String get consentParentalVerificationFailed =>
      'We could not confirm that number. Please try again.';

  @override
  String get consentParentalUnavailable =>
      'We could not reach the server. Until we can, RoadPack will not track riders under 18.';

  @override
  String get consentTrackingNotPermitted =>
      'RoadPack cannot start tracking yet';

  @override
  String consentWatcherReason(String type, String circleName) {
    return 'In your $type circle \"$circleName\", and that circle has location sharing on.';
  }

  @override
  String get contactsAddButton => 'Add contact';

  @override
  String get contactsLoadError => 'Could not load your contacts';

  @override
  String get contactsRetry => 'Retry';

  @override
  String get contactsEmptyHint =>
      'Add at least one contact before tracking can start.';

  @override
  String get contactsOrderHint =>
      'We call them in this order. Drag to change it.';

  @override
  String contactsCountOfMax(int count, int max) {
    return '$count of $max listed';
  }

  @override
  String get contactsEmptyBody =>
      'Nobody is listed yet.\nAn alert with nobody to send it to is not protection.';

  @override
  String contactsRemoveConfirmTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get contactsRemoveConfirmBody =>
      'They will no longer be alerted if something happens to you.';

  @override
  String get contactsCancel => 'Cancel';

  @override
  String get contactsRemoveButton => 'Remove';

  @override
  String get contactsEditTitle => 'Edit emergency contact';

  @override
  String get contactsAddTitle => 'Add emergency contact';

  @override
  String get contactsPhoneLabel => 'Mobile number';

  @override
  String get contactsRelationshipLabel => 'Relationship (optional)';

  @override
  String get contactsHowWeReachThem => 'HOW WE REACH THEM';

  @override
  String get contactsEditHint =>
      'Correcting a number here does not re-send the notice they already received.';

  @override
  String get contactsAddHint =>
      'They get one SMS telling them they are listed, and can opt out of it. We never message them again unless something happens.';

  @override
  String get contactsSaveButton => 'Save changes';

  @override
  String contactsRemoveTooltip(String name) {
    return 'Remove $name';
  }

  @override
  String get contactsOptedOut => 'Opted out of SMS';

  @override
  String get contactsNoticeSent => 'Told they are listed';

  @override
  String get contactsNoticePending => 'Notice not sent yet';

  @override
  String get iceScreenTitle => 'Emergency card';

  @override
  String get iceSealedEyebrow => 'YOUR CARD IS SEALED';

  @override
  String get iceSealedBody =>
      'Your blood group, medical notes and contacts are shown to a bystander only while an emergency is active — or, if you turn it on, while you are riding. There is no always-on code for anyone to scan.';

  @override
  String get iceBandHeading => 'THIS PERSON MAY NEED HELP';

  @override
  String get iceLabelCallThese => 'Call these people';

  @override
  String get iceNoContacts => 'No contacts listed';

  @override
  String get iceDisclaimer =>
      'RoadPack alerts this rider’s circle. It does not call an ambulance. For emergency services, dial 112.';

  @override
  String get iceBloodGroupMissing => 'Not recorded';

  @override
  String mapCacheReadError(String message) {
    return 'Could not read the cache: $message';
  }

  @override
  String mapRoutesReadError(String message) {
    return 'Could not read your routes: $message';
  }

  @override
  String get mapYourRoutesEyebrow => 'YOUR ROUTES';

  @override
  String get mapNoRoutesLearned =>
      'No routes learned yet. RoadPack works out your regular routes from trips you actually take.';

  @override
  String get mapStoredOnPhoneEyebrow => 'STORED ON THIS PHONE';

  @override
  String mapTileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tiles',
      one: '1 tile',
    );
    return '$_temp0';
  }

  @override
  String get mapCacheInMemoryOnlyNotice =>
      'This cache is held in memory only and is emptied when the app restarts.';

  @override
  String get mapClearCachedDataButton => 'Clear cached map data';

  @override
  String mapRegionCoverageLine(
    int tiles,
    int zoomLevels,
    String estimatedSize,
    int bufferKm,
  ) {
    return '$tiles tiles across $zoomLevels zoom levels · ~$estimatedSize estimated · $bufferKm km buffer';
  }

  @override
  String mapRegionCoverageLineCorridor(
    int tiles,
    int zoomLevels,
    String estimatedSize,
    int bufferKm,
  ) {
    return '$tiles tiles across $zoomLevels zoom levels · ~$estimatedSize estimated · $bufferKm km buffer · corridor estimated from start and end only';
  }

  @override
  String get mapOfflineNoticeText =>
      'Positions could not be refreshed. Nothing on this map is newer than the age shown on each member.';

  @override
  String get mapEmptyNoticeText =>
      'No one is sharing location with you. Location sharing is a per-circle setting, and each member controls their own.';

  @override
  String mapStaleBannerBoth(int unreachableCount, int staleCount) {
    String _temp0 = intl.Intl.pluralLogic(
      unreachableCount,
      locale: localeName,
      other: '$unreachableCount with no signal',
      one: '1 with no signal',
    );
    String _temp1 = intl.Intl.pluralLogic(
      staleCount,
      locale: localeName,
      other: '$staleCount not updating',
      one: '1 not updating',
    );
    return '$_temp0, $_temp1 — these markers show where they were, not where they are.';
  }

  @override
  String mapStaleBannerNoSignalOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count with no signal',
      one: '1 with no signal',
    );
    return '$_temp0 — these markers show where they were, not where they are.';
  }

  @override
  String mapStaleBannerNotUpdatingOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count not updating',
      one: '1 not updating',
    );
    return '$_temp0 — these markers show where they were, not where they are.';
  }

  @override
  String get mapLastUpdateLabel => 'Last update';

  @override
  String get mapSpeedLabel => 'Speed';

  @override
  String get mapBatteryLabel => 'Battery';

  @override
  String mapLastUpdateValue(String duration) {
    return '$duration ago';
  }

  @override
  String mapSpeedValue(int speed) {
    return '$speed km/h';
  }

  @override
  String get mapSpeedNotCurrent => 'not current';

  @override
  String get mapSpeedUnknown => 'unknown';

  @override
  String mapBatteryValue(int battery) {
    return '$battery%';
  }

  @override
  String get mapFootnoteLocating =>
      'Nothing is being shown on the map for this member yet.';

  @override
  String get mapFootnoteLive =>
      'RoadPack shortens the gap between an incident and help being aware. It does not dispatch anyone. In an emergency, call 112.';

  @override
  String get mapFootnoteStale =>
      'The marker has not moved because no new fix has arrived. It is not an estimate of where they are now.';

  @override
  String get mapPresenceLocating => 'Locating';

  @override
  String get mapPresenceLive => 'Live';

  @override
  String get mapPresenceStopped => 'Stopped';

  @override
  String get mapPresenceNoSignal => 'No signal';

  @override
  String mapPresenceLastSeen(String age) {
    return 'Last seen $age ago';
  }

  @override
  String mapAgeLabel(String age) {
    return 'last seen $age ago';
  }

  @override
  String get mapPresenceDetailLocating =>
      'Waiting for a first fix from this device.';

  @override
  String mapPresenceDetailLive(String age) {
    return 'Position updated $age ago.';
  }

  @override
  String get mapPresenceDetailStopped => 'Still reporting, not moving.';

  @override
  String get mapPresenceDetailStale =>
      'This is where they were, not where they are.';

  @override
  String mapPresenceDetailUnreachable(String age) {
    return 'Nothing heard for $age. Last known position shown.';
  }

  @override
  String get mapRegionStatusNotDownloaded => 'Not downloaded';

  @override
  String get mapRegionStatusDownloading => 'Downloading';

  @override
  String get mapRegionStatusDownloaded => 'Downloaded';

  @override
  String get mapRegionStatusFailed => 'Failed';

  @override
  String get mapOfflineLimitationNotice =>
      'Offline areas are planned and measured, but the base map still needs a connection. Google Maps draws tiles inside its own SDK and gives the app no way to pre-load them. Switching to a self-hosted OSM tile source is what makes offline maps actually work.';

  @override
  String get packCreateTitle => 'Start a pack ride';

  @override
  String get packDestinationInvalid =>
      'Enter the destination as latitude, longitude';

  @override
  String get packRideNameLabel => 'Ride name (optional)';

  @override
  String get packRideNameHint => 'Munnar run';

  @override
  String get packCircleLabel => 'Circle (optional)';

  @override
  String get packCircleHelper => 'Members of this circle can find the ride';

  @override
  String get packNoCircleOption => 'No circle';

  @override
  String get packDestinationHeading => 'Destination';

  @override
  String get packLatitudeLabel => 'Latitude';

  @override
  String get packLongitudeLabel => 'Longitude';

  @override
  String get packCreateShareNotice =>
      'Everyone who joins shares their position with the pack until the ride ends, and for at most 12 hours. RoadPack does not call for help — in an emergency, dial 112.';

  @override
  String get packCreateSubmit => 'Create ride';

  @override
  String get packPasteLinkError => 'Paste the link somebody sent you';

  @override
  String get packShareLinkLabel => 'Share link';

  @override
  String get packJoinNotice =>
      'When you join, the pack sees where you are along the route until the ride ends. You can leave at any time, and leaving removes you straight away.';

  @override
  String get packJoinSubmit => 'Join ride';

  @override
  String get packDefaultRideName => 'Pack';

  @override
  String get packEndRideAction => 'End ride';

  @override
  String get packTellPack => 'Tell the pack';

  @override
  String get packEmptyRoster =>
      'Nobody has joined yet. Share the link to fill the pack.';

  @override
  String get packEndRideConfirmTitle => 'End this ride?';

  @override
  String get packEndRideConfirmBody =>
      'Everyone stops sharing and the link stops working immediately. This cannot be undone.';

  @override
  String get packKeepRidingAction => 'Keep riding';

  @override
  String get packAddNoteAction => 'Add a note (optional)';

  @override
  String get packNoteLabel => 'Note';

  @override
  String get packNoteHint => 'Tyre puncture, 20 min';

  @override
  String get packShareHonestyNotice =>
      'RoadPack shares where you are. It does not call for help — in an emergency, dial 112.';

  @override
  String get packStatusRiding => 'Riding';

  @override
  String get packStatusRefueling => 'Fuel';

  @override
  String get packStatusTakingBreak => 'Break';

  @override
  String get packStatusWrongTurn => 'Wrong turn';

  @override
  String get packStatusWaiting => 'Waiting';

  @override
  String get packStatusStopped => 'Stopped';

  @override
  String get packStatusDone => 'Done';

  @override
  String get packStatusUnexplainedStop => 'Stopped, unexplained';

  @override
  String get packStatusUnreachable => 'No signal';

  @override
  String get packStatusPossibleIncident => 'Possible incident';

  @override
  String get packAutoTag => 'AUTO';

  @override
  String get packRoleLeader => 'Leader';

  @override
  String get packRoleSweep => 'Sweep';

  @override
  String get packRoleRider => 'Rider';

  @override
  String get packGapFront => 'Front';

  @override
  String get packOffRouteHeadline => 'Off route';

  @override
  String get packLastSeenHeadline => 'Last seen';

  @override
  String get packLocatingHeadline => 'Locating';

  @override
  String get packStraightLineUnknown => 'straight line unknown';

  @override
  String packDistanceAway(String distance) {
    return '$distance away';
  }

  @override
  String get packNoFixYet => 'no fix yet';

  @override
  String get packJustNow => 'just now';

  @override
  String packAgoCompact(String duration) {
    return '$duration ago';
  }

  @override
  String get packBehindLabel => 'BEHIND';

  @override
  String get packBehindLabelEst => 'BEHIND EST';

  @override
  String packBehindWithDuration(String duration) {
    return '$duration BEHIND';
  }

  @override
  String packBehindWithDurationEst(String duration) {
    return '$duration BEHIND EST';
  }

  @override
  String get packYouLabel => 'You';

  @override
  String packNameYouSuffix(String name) {
    return '$name (you)';
  }

  @override
  String get packSharingLiveHeadline => 'This ride is being shared';

  @override
  String get packSharingOffHeadline => 'Sharing is off';

  @override
  String packLiveNotice(String expiry) {
    return 'Anyone with the link can see where the pack is until $expiry. Riders can see the viewer count.';
  }

  @override
  String get packLinkExpiredNotice =>
      'The link no longer resolves. Nobody can see this ride.';

  @override
  String get packExpiresNow => 'now';

  @override
  String packExpiresInHours(int hours) {
    return 'it expires in ${hours}h';
  }

  @override
  String packExpiresInMinutes(int minutes) {
    return 'it expires in ${minutes}m';
  }

  @override
  String get packShareLinkAction => 'Share link';

  @override
  String get packCopyLinkTooltip => 'Copy link';

  @override
  String get packStopSharingAction => 'Stop sharing this ride';

  @override
  String get packLinkCopiedSnackbar => 'Link copied';

  @override
  String get packDefaultShareRideName => 'our ride';

  @override
  String packShareMessage(String name, String url) {
    return 'Follow $name live: $url\n\nRoadPack shows where the pack is. It does not call an ambulance — for an emergency, dial 112.';
  }

  @override
  String packWatchingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count watching',
      one: '1 watching',
    );
    return '$_temp0';
  }

  @override
  String get packNotShared => 'not shared';
}
