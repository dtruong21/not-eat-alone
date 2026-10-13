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
}
