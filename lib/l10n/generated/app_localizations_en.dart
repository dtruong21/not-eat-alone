// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get commonSomethingWentWrong =>
      'Something went wrong — please try again.';

  @override
  String get errorStateTitle => 'Couldn\'t load this';

  @override
  String get errorStateMessage => 'Check your connection and try again.';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navChats => 'Chats';

  @override
  String get navRequests => 'Requests';

  @override
  String get navProfile => 'Profile';

  @override
  String get authSendingCode => 'Sending code…';

  @override
  String get signinTitle => 'Welcome to Convyve';

  @override
  String get signinSubtitle => 'Meet one person over a meal in Paris.';

  @override
  String get signinContinueGoogle => 'Continue with Google';

  @override
  String get signinContinueApple => 'Continue with Apple';

  @override
  String get signinSigningIn => 'Signing in…';

  @override
  String get signinOr => 'or';

  @override
  String get signinPhoneLabel => 'Phone number';

  @override
  String get signinPhoneError =>
      'Enter a phone number with country code, e.g. +33 6 12 34 56 78';

  @override
  String get signinSendCode => 'Send code';

  @override
  String get commonUnderageNotice => 'You must be 18 or older to use Convyve.';

  @override
  String get phoneTitle => 'Enter the code';

  @override
  String phoneSentTo(String phone) {
    return 'Sent to $phone';
  }

  @override
  String get phoneChange => 'Change';

  @override
  String get phoneChangeSemantics => 'Change phone number';

  @override
  String get phoneCodeLabel => '6-digit code';

  @override
  String get phoneWrongCode => 'That code didn\'t work. Check it or resend.';

  @override
  String get phoneVerify => 'Verify';

  @override
  String get phoneVerifying => 'Verifying…';

  @override
  String get phoneResend => 'Resend code';

  @override
  String phoneResendIn(int seconds) {
    return 'Resend code in $seconds s';
  }

  @override
  String get phoneResent => 'Code sent again';

  @override
  String get agegateTitle => 'Confirm your date of birth';

  @override
  String get agegateSelect => 'Select date of birth';

  @override
  String get agegateHelp => 'Your date of birth';

  @override
  String get agegateFieldLabel => 'Date of birth';

  @override
  String get setupTitle => 'Set up your profile';

  @override
  String get setupSubtitle => 'Name, photo and gender. That\'s it.';

  @override
  String profileStillNeeded(String summary) {
    return 'Still needed: $summary.';
  }

  @override
  String get mealWomenOnly => 'Women only';

  @override
  String get mealHostFallbackName => 'Host';

  @override
  String get discoverEmptyTitle => 'No meals nearby yet';

  @override
  String get discoverEmptyMessage =>
      'Be the first: host a meal and someone will join.';

  @override
  String get discoverCreateMeal => 'Create a meal';

  @override
  String discoverDistanceKm(double distance) {
    final intl.NumberFormat distanceNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String distanceString = distanceNumberFormat.format(distance);

    return '$distanceString km';
  }

  @override
  String get parisNotice =>
      'Convyve is Paris-only for now — we\'re just getting started here.';

  @override
  String get mealDetailTitle => 'Meal details';

  @override
  String get mealDetailHostHeading => 'Host';

  @override
  String get mealDetailHostUnavailable => 'Host unavailable';

  @override
  String mealDetailHostNameAge(String name, int age) {
    return '$name, $age';
  }

  @override
  String get mealDetailReportMeal => 'Report this meal';

  @override
  String get mealDetailReportHost => 'Report host';

  @override
  String get mealDetailBlockHost => 'Block host';

  @override
  String get mealDetailOpenInMaps => 'Open in Maps';

  @override
  String mealDetailOpenInMapsSemantics(String restaurant) {
    return 'Open $restaurant in Maps';
  }

  @override
  String get mealDetailMapsFailed => 'Couldn\'t open Maps';

  @override
  String get mealActionRequestToJoin => 'Request to join';

  @override
  String get mealActionSendingRequest => 'Sending request…';

  @override
  String get mealActionRequested => 'Requested';

  @override
  String get mealActionOpenChat => 'Open chat';

  @override
  String get mealActionNotSelected => 'Not selected';

  @override
  String get mealActionYourMeal => 'This is your meal';

  @override
  String get mealActionCancelled => 'Meal cancelled';

  @override
  String get mealActionStatusYourMeal => 'See requests in the Requests tab.';

  @override
  String get mealActionStatusCancelled => 'The host cancelled this meal.';

  @override
  String get mealActionStatusWomenOnly => 'Only women can join this meal.';

  @override
  String get mealActionStatusLoadError => 'Couldn\'t load your request.';

  @override
  String get mealActionStatusPending => 'Waiting for the host to reply.';

  @override
  String get mealActionStatusApproved => 'You\'re matched. Say hi!';

  @override
  String get mealActionStatusDenied => 'The host chose someone else.';

  @override
  String get mealActionNoLongerOpen => 'This meal is no longer open.';

  @override
  String get mealActionRequestFailed =>
      'Couldn\'t send your request. Try again.';

  @override
  String get createMealTitle => 'Create a meal';

  @override
  String get createMealPickDateTime => 'Pick date & time';

  @override
  String get createMealNoteLabel => 'Note (optional)';

  @override
  String get createMealSubmit => 'Create meal';

  @override
  String get createMealCreating => 'Creating…';

  @override
  String createMealTooSoon(int minutes) {
    return 'Pick a time at least $minutes minutes from now.';
  }

  @override
  String get createMealPosted =>
      'Meal posted. You\'ll get requests in the Requests tab.';

  @override
  String get restaurantSearchTitle => 'Find a restaurant';

  @override
  String get restaurantSearchHint => 'Search restaurants';

  @override
  String get restaurantSearchEmpty => 'No restaurants to show yet.';

  @override
  String restaurantSearchNoMatch(String query) {
    return 'No restaurant called “$query”. Try another name.';
  }

  @override
  String get inboxTitle => 'Requests';

  @override
  String get inboxEmptyTitle => 'No pending requests';

  @override
  String get inboxGuestFallback => 'Guest';

  @override
  String inboxGuestNameAge(String name, int age) {
    return '$name, $age';
  }

  @override
  String get inboxPastMeal => 'Meal time has passed';

  @override
  String get inboxApprove => 'Approve';

  @override
  String get inboxApproving => 'Approving…';

  @override
  String get inboxDeny => 'Deny';

  @override
  String get inboxDenying => 'Denying…';

  @override
  String get inboxActionChat => 'Chat';

  @override
  String get inboxOutcomeApproved => 'Approved. You can chat now.';

  @override
  String get inboxOutcomeApproveFailed =>
      'Couldn\'t approve this request. It may already have been handled.';

  @override
  String get inboxOutcomeDenied => 'Request denied.';

  @override
  String get inboxOutcomeDenyFailed =>
      'Couldn\'t deny this request. It may already have been handled.';

  @override
  String get chatListTitle => 'Chats';

  @override
  String get chatListEmptyTitle => 'No chats yet';

  @override
  String get chatListEmptyMessage => 'Match on a meal to start talking.';

  @override
  String get chatListFindMeal => 'Find a meal';

  @override
  String get chatSayHi => 'Say hi 👋';

  @override
  String get chatTitleFallback => 'Chat';

  @override
  String get chatTimeNow => 'now';

  @override
  String chatTimeMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String chatTimeHours(int hours) {
    return '${hours}h';
  }

  @override
  String chatTimeDays(int days) {
    return '${days}d';
  }

  @override
  String get chatUnreadSemantics => 'Unread';

  @override
  String get chatSeen => 'Seen';

  @override
  String get chatComposerHint => 'Message';

  @override
  String get chatSendTooltip => 'Send message';

  @override
  String get chatSendFailed => 'Couldn\'t send your message. Try again.';

  @override
  String get chatUnavailable =>
      'This chat is no longer available — the meal was cancelled.';

  @override
  String get chatBackToChats => 'Back to chats';

  @override
  String get leaveMatchTooltip => 'Can\'t make it';

  @override
  String get leaveMatchOtherFallback => 'Your match';

  @override
  String get leaveMatchHostTitle => 'Cancel this meal?';

  @override
  String get leaveMatchGuestTitle => 'Withdraw from this meal?';

  @override
  String leaveMatchHostBody(String name) {
    return '$name will be told and the meal will be removed.';
  }

  @override
  String leaveMatchGuestBody(String name) {
    return '$name will be told and the meal will open up again for others.';
  }

  @override
  String get leaveMatchKeep => 'Keep meal';

  @override
  String get leaveMatchHostConfirm => 'Cancel meal';

  @override
  String get leaveMatchGuestConfirm => 'Withdraw';

  @override
  String get leaveMatchHostDone => 'Meal cancelled.';

  @override
  String get leaveMatchGuestDone => 'You\'ve withdrawn.';

  @override
  String get leaveMatchFailed =>
      'Couldn\'t cancel. Check your connection and try again.';

  @override
  String get safetyTipsBanner => 'Meeting up? Safety tips';

  @override
  String get safetyTipsBannerDismiss => 'Dismiss safety tips';

  @override
  String get safetyTipsHeading => 'Meeting up? Stay safe';

  @override
  String get safetyTipPublicPlace => 'Meet in a public place';

  @override
  String get safetyTipTellFriend => 'Tell a friend where you\'re going';

  @override
  String get safetyTipInstincts => 'Trust your instincts';

  @override
  String get safetyTipBlockReport => 'You can block or report anytime';

  @override
  String get safetyTipsGotIt => 'Got it';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonSubmitting => 'Submitting…';

  @override
  String get commonSave => 'Save';

  @override
  String get safetyReportAction => 'Report';

  @override
  String get safetyBlockAction => 'Block';

  @override
  String safetyBlockTitleNamed(String name) {
    return 'Block $name?';
  }

  @override
  String get safetyBlockTitleGeneric => 'Block this person?';

  @override
  String get safetyBlockBody => 'You won\'t see each other in Convyve anymore.';

  @override
  String get safetyBlockFailed => 'Couldn\'t block. Try again.';

  @override
  String get safetyBlockDone => 'Blocked.';

  @override
  String get safetyTipsTitle => 'Safety tips';

  @override
  String reportTitleNamed(String name) {
    return 'Report $name';
  }

  @override
  String get reportTitleMeal => 'Report this meal';

  @override
  String get reportReasonInappropriate => 'Inappropriate content';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonHarassment => 'Harassment';

  @override
  String get reportReasonFake => 'Fake profile';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportNoteHint => 'Add a note (optional)';

  @override
  String get reportFailed => 'Couldn\'t submit your report. Try again.';

  @override
  String get reportThanks => 'Thanks — we\'ll review this.';

  @override
  String get blockedTitle => 'Blocked people';

  @override
  String get blockedEmptyTitle => 'You haven\'t blocked anyone';

  @override
  String get blockedEmptyMessage =>
      'People you block are hidden from your meals and chats.';

  @override
  String get blockedUnknownUser => 'Unknown user';

  @override
  String get blockedUnblock => 'Unblock';

  @override
  String blockedUnblockSemantics(String name) {
    return 'Unblock $name';
  }

  @override
  String get blockedUnblocking => 'Unblocking…';

  @override
  String blockedUnblocked(String name) {
    return 'Unblocked $name.';
  }

  @override
  String get blockedUnblockFailed => 'Couldn\'t unblock. Try again.';

  @override
  String ratingTitleNamed(String name) {
    return 'How was your meal with $name?';
  }

  @override
  String get ratingTitle => 'How was your meal?';

  @override
  String ratingStarTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars',
      one: '1 star',
    );
    return '$_temp0';
  }

  @override
  String get ratingShowedUp => 'Did they show up?';

  @override
  String get ratingCommentHint => 'Add a comment (optional)';

  @override
  String get ratingFailed => 'Couldn\'t submit your rating. Try again.';

  @override
  String get ratingThanks => 'Thanks for the feedback!';

  @override
  String get ratingCardSubtitle => 'It only takes a moment.';

  @override
  String get ratingRate => 'Rate';

  @override
  String ratingRateNamed(String name) {
    return 'Rate $name';
  }

  @override
  String get ratingBadgeNew => 'New';

  @override
  String ratingBadgeScore(double average, int count) {
    final intl.NumberFormat averageNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String averageString = averageNumberFormat.format(average);

    return '$averageString ($count)';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsEditProfile => 'Edit profile';

  @override
  String get settingsPhoneNumber => 'Phone number';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutTitle => 'Sign out?';

  @override
  String get settingsSectionSafety => 'Safety';

  @override
  String get settingsContactSupport => 'Contact support';

  @override
  String settingsMailFailed(String email) {
    return 'Couldn\'t open your mail app. Write to $email';
  }

  @override
  String get settingsSectionNotifications => 'Notifications';

  @override
  String get settingsNotificationSettings => 'Notification settings';

  @override
  String get settingsNotificationSubtitle =>
      'Manage notifications in iOS Settings';

  @override
  String get settingsSectionLegal => 'Legal';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsTermsOfService => 'Terms of Service';

  @override
  String get settingsLicenses => 'Open-source licences';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsVersionLoading => 'Loading…';

  @override
  String get settingsVersionUnavailable => 'Unavailable';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteTitle => 'Delete account?';

  @override
  String get settingsDeleteBody =>
      'This permanently deletes your account and all your data. This can\'t be undone.';

  @override
  String get settingsDeleteFailed => 'Couldn\'t delete account. Try again.';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get profileYourRating => 'Your rating';

  @override
  String get profileNoRatings => 'No ratings yet';

  @override
  String get profileFormPhotos => 'Photos';

  @override
  String get profileFormRemovePhoto => 'Remove photo';

  @override
  String get profileFormAddPhoto => 'Add photo';

  @override
  String get profileFormUploadingPhoto => 'Uploading photo';

  @override
  String get profileFormName => 'Name';

  @override
  String get profileFormGenderHeading => 'I am a';

  @override
  String get profileFormBio => 'Bio';

  @override
  String get genderWoman => 'Woman';

  @override
  String get genderMan => 'Man';

  @override
  String get genderNonBinary => 'Non-binary';

  @override
  String get profileMissingPhoto => 'a photo';

  @override
  String get profileMissingName => 'your name';

  @override
  String get profileMissingGender => 'how you identify';

  @override
  String profileMissingTwo(String first, String second) {
    return '$first and $second';
  }

  @override
  String profileMissingThree(String first, String second, String third) {
    return '$first, $second and $third';
  }
}
