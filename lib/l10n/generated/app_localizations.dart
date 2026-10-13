import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('fr'),
  ];

  /// Button label that retries a failed load or action.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// Button label that dismisses a dialog or sheet without acting.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Tooltip / accessibility label of a close button on a dismissible notice.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// Short button label that retries a failed action.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Screen-reader label of a loading placeholder.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get commonLoading;

  /// Primary button that moves to the next step.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// Label shown on a button while a save is in flight.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get commonSaving;

  /// Generic inline error shown when a step fails for an unknown reason.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong — please try again.'**
  String get commonSomethingWentWrong;

  /// Default headline of the error block shown when a screen fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this'**
  String get errorStateTitle;

  /// Default supporting text of the error block.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get errorStateMessage;

  /// Bottom navigation tab: browse meals.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// Bottom navigation tab: conversations.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get navChats;

  /// Bottom navigation tab: join requests inbox.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get navRequests;

  /// Bottom navigation tab: the user's own profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Button label while an SMS code is being sent.
  ///
  /// In en, this message translates to:
  /// **'Sending code…'**
  String get authSendingCode;

  /// Headline of the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Convyve'**
  String get signinTitle;

  /// Sub-headline of the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Meet one person over a meal in Paris.'**
  String get signinSubtitle;

  /// Button that signs in with a Google account.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signinContinueGoogle;

  /// Label of the Sign in with Apple button.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get signinContinueApple;

  /// Button / screen-reader label while a sign-in is in flight.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signinSigningIn;

  /// Divider word between social sign-in and phone sign-in.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get signinOr;

  /// Label of the phone number field.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get signinPhoneLabel;

  /// Error under the phone field when the number is not valid.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number with country code, e.g. +33 6 12 34 56 78'**
  String get signinPhoneError;

  /// Button that sends the SMS code.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get signinSendCode;

  /// Notice shown on sign-in (and on the blocked age-gate screen) after an under-18 attempt.
  ///
  /// In en, this message translates to:
  /// **'You must be 18 or older to use Convyve.'**
  String get commonUnderageNotice;

  /// Headline of the SMS code screen.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get phoneTitle;

  /// Line under the headline naming the number the code was sent to.
  ///
  /// In en, this message translates to:
  /// **'Sent to {phone}'**
  String phoneSentTo(String phone);

  /// Button that goes back to change the phone number.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get phoneChange;

  /// Screen-reader label of the Change button.
  ///
  /// In en, this message translates to:
  /// **'Change phone number'**
  String get phoneChangeSemantics;

  /// Label of the SMS code field.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get phoneCodeLabel;

  /// Error under the code field when the code was rejected.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t work. Check it or resend.'**
  String get phoneWrongCode;

  /// Button that submits the SMS code.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get phoneVerify;

  /// Button label while the code is being checked.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get phoneVerifying;

  /// Button that requests a new SMS code.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get phoneResend;

  /// Disabled resend button showing the cooldown; "s" is the seconds symbol.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds} s'**
  String phoneResendIn(int seconds);

  /// Confirmation shown after a new SMS code was sent.
  ///
  /// In en, this message translates to:
  /// **'Code sent again'**
  String get phoneResent;

  /// Headline of the age-gate screen.
  ///
  /// In en, this message translates to:
  /// **'Confirm your date of birth'**
  String get agegateTitle;

  /// Button that opens the date picker before a date is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select date of birth'**
  String get agegateSelect;

  /// Help text at the top of the date picker.
  ///
  /// In en, this message translates to:
  /// **'Your date of birth'**
  String get agegateHelp;

  /// Field label of the date picker text-entry mode.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get agegateFieldLabel;

  /// Headline of the profile setup screen.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile'**
  String get setupTitle;

  /// Sub-headline of the profile setup screen.
  ///
  /// In en, this message translates to:
  /// **'Name, photo and gender. That\'s it.'**
  String get setupSubtitle;

  /// Hint under the Continue button listing the required fields still empty; summary is a pre-built list such as "name and photo".
  ///
  /// In en, this message translates to:
  /// **'Still needed: {summary}.'**
  String profileStillNeeded(String summary);

  /// Badge / disabled-button label for a meal only women can join.
  ///
  /// In en, this message translates to:
  /// **'Women only'**
  String get mealWomenOnly;

  /// Name shown for a host whose profile has no display name.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get mealHostFallbackName;

  /// Headline of the Discover empty state.
  ///
  /// In en, this message translates to:
  /// **'No meals nearby yet'**
  String get discoverEmptyTitle;

  /// Supporting text of the Discover empty state.
  ///
  /// In en, this message translates to:
  /// **'Be the first: host a meal and someone will join.'**
  String get discoverEmptyMessage;

  /// Discover button / floating button that starts meal creation.
  ///
  /// In en, this message translates to:
  /// **'Create a meal'**
  String get discoverCreateMeal;

  /// Distance from the viewer to a meal, in kilometres with one decimal.
  ///
  /// In en, this message translates to:
  /// **'{distance} km'**
  String discoverDistanceKm(double distance);

  /// Dismissible banner on Discover explaining the Paris-only launch.
  ///
  /// In en, this message translates to:
  /// **'Convyve is Paris-only for now — we\'re just getting started here.'**
  String get parisNotice;

  /// App bar title of the meal detail screen.
  ///
  /// In en, this message translates to:
  /// **'Meal details'**
  String get mealDetailTitle;

  /// Section heading above the host's profile block.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get mealDetailHostHeading;

  /// Shown instead of the host block when the host profile no longer exists.
  ///
  /// In en, this message translates to:
  /// **'Host unavailable'**
  String get mealDetailHostUnavailable;

  /// Host name followed by age.
  ///
  /// In en, this message translates to:
  /// **'{name}, {age}'**
  String mealDetailHostNameAge(String name, int age);

  /// Safety menu item that reports the meal.
  ///
  /// In en, this message translates to:
  /// **'Report this meal'**
  String get mealDetailReportMeal;

  /// Safety menu item that reports the host.
  ///
  /// In en, this message translates to:
  /// **'Report host'**
  String get mealDetailReportHost;

  /// Safety menu item that blocks the host.
  ///
  /// In en, this message translates to:
  /// **'Block host'**
  String get mealDetailBlockHost;

  /// Button that opens the restaurant in the maps app.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get mealDetailOpenInMaps;

  /// Screen-reader label of the Open in Maps button.
  ///
  /// In en, this message translates to:
  /// **'Open {restaurant} in Maps'**
  String mealDetailOpenInMapsSemantics(String restaurant);

  /// Snackbar shown when the maps app could not be launched.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open Maps'**
  String get mealDetailMapsFailed;

  /// Meal action bar: button that sends a join request.
  ///
  /// In en, this message translates to:
  /// **'Request to join'**
  String get mealActionRequestToJoin;

  /// Meal action bar: button label while the join request is being sent.
  ///
  /// In en, this message translates to:
  /// **'Sending request…'**
  String get mealActionSendingRequest;

  /// Meal action bar: disabled button once the request is pending.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get mealActionRequested;

  /// Meal action bar: button that opens the chat after a match.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get mealActionOpenChat;

  /// Meal action bar: disabled button when the host chose someone else.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get mealActionNotSelected;

  /// Meal action bar: disabled button on the viewer's own meal.
  ///
  /// In en, this message translates to:
  /// **'This is your meal'**
  String get mealActionYourMeal;

  /// Meal action bar: disabled button on a cancelled meal.
  ///
  /// In en, this message translates to:
  /// **'Meal cancelled'**
  String get mealActionCancelled;

  /// Meal action bar status line (one line only) on the viewer's own meal.
  ///
  /// In en, this message translates to:
  /// **'See requests in the Requests tab.'**
  String get mealActionStatusYourMeal;

  /// Meal action bar status line on a cancelled meal.
  ///
  /// In en, this message translates to:
  /// **'The host cancelled this meal.'**
  String get mealActionStatusCancelled;

  /// Meal action bar status line for a women-only meal the viewer cannot join.
  ///
  /// In en, this message translates to:
  /// **'Only women can join this meal.'**
  String get mealActionStatusWomenOnly;

  /// Meal action bar status line when the viewer's request failed to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your request.'**
  String get mealActionStatusLoadError;

  /// Meal action bar status line while the request is pending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host to reply.'**
  String get mealActionStatusPending;

  /// Meal action bar status line after the host approved the request.
  ///
  /// In en, this message translates to:
  /// **'You\'re matched. Say hi!'**
  String get mealActionStatusApproved;

  /// Meal action bar status line after the host declined the request.
  ///
  /// In en, this message translates to:
  /// **'The host chose someone else.'**
  String get mealActionStatusDenied;

  /// Snackbar when the server rejects a request because the meal closed.
  ///
  /// In en, this message translates to:
  /// **'This meal is no longer open.'**
  String get mealActionNoLongerOpen;

  /// Snackbar when sending a join request failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your request. Try again.'**
  String get mealActionRequestFailed;

  /// App bar title of the create-meal screen.
  ///
  /// In en, this message translates to:
  /// **'Create a meal'**
  String get createMealTitle;

  /// Button that opens the date and time pickers.
  ///
  /// In en, this message translates to:
  /// **'Pick date & time'**
  String get createMealPickDateTime;

  /// Label of the optional note field.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get createMealNoteLabel;

  /// Button that posts the meal.
  ///
  /// In en, this message translates to:
  /// **'Create meal'**
  String get createMealSubmit;

  /// Button label while the meal is being posted.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get createMealCreating;

  /// Snackbar when the picked time is too close to now.
  ///
  /// In en, this message translates to:
  /// **'Pick a time at least {minutes} minutes from now.'**
  String createMealTooSoon(int minutes);

  /// Snackbar after a meal was posted.
  ///
  /// In en, this message translates to:
  /// **'Meal posted. You\'ll get requests in the Requests tab.'**
  String get createMealPosted;

  /// App bar title of the restaurant search screen.
  ///
  /// In en, this message translates to:
  /// **'Find a restaurant'**
  String get restaurantSearchTitle;

  /// Hint of the restaurant search field.
  ///
  /// In en, this message translates to:
  /// **'Search restaurants'**
  String get restaurantSearchHint;

  /// Shown when the search has no query and no results.
  ///
  /// In en, this message translates to:
  /// **'No restaurants to show yet.'**
  String get restaurantSearchEmpty;

  /// Shown when a typed search has no results; query is what the user typed.
  ///
  /// In en, this message translates to:
  /// **'No restaurant called “{query}”. Try another name.'**
  String restaurantSearchNoMatch(String query);
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
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
