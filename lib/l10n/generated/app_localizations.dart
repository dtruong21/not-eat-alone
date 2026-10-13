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

  /// App bar title of the host request inbox.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get inboxTitle;

  /// Empty state of the host request inbox.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get inboxEmptyTitle;

  /// Name shown for a requesting guest whose profile is not loaded.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get inboxGuestFallback;

  /// Guest name and age on a request row.
  ///
  /// In en, this message translates to:
  /// **'{name}, {age}'**
  String inboxGuestNameAge(String name, int age);

  /// Chip, tooltip and hint on a request whose meal time is in the past.
  ///
  /// In en, this message translates to:
  /// **'Meal time has passed'**
  String get inboxPastMeal;

  /// Button that approves a join request.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get inboxApprove;

  /// Approve button label while the action is in flight.
  ///
  /// In en, this message translates to:
  /// **'Approving…'**
  String get inboxApproving;

  /// Button that denies a join request.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get inboxDeny;

  /// Deny button label while the action is in flight.
  ///
  /// In en, this message translates to:
  /// **'Denying…'**
  String get inboxDenying;

  /// Snackbar action that opens the chat after a successful approve.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get inboxActionChat;

  /// Snackbar after a request was approved.
  ///
  /// In en, this message translates to:
  /// **'Approved. You can chat now.'**
  String get inboxOutcomeApproved;

  /// Snackbar when approving failed for any reason other than the meal being closed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t approve this request. It may already have been handled.'**
  String get inboxOutcomeApproveFailed;

  /// Snackbar after a request was denied.
  ///
  /// In en, this message translates to:
  /// **'Request denied.'**
  String get inboxOutcomeDenied;

  /// Snackbar when denying failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t deny this request. It may already have been handled.'**
  String get inboxOutcomeDenyFailed;

  /// App bar title of the chat list.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatListTitle;

  /// Empty state title of the chat list.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get chatListEmptyTitle;

  /// Empty state message of the chat list.
  ///
  /// In en, this message translates to:
  /// **'Match on a meal to start talking.'**
  String get chatListEmptyMessage;

  /// Empty chat list button that opens Discover.
  ///
  /// In en, this message translates to:
  /// **'Find a meal'**
  String get chatListFindMeal;

  /// Preview of a chat with no message yet, and empty thread title.
  ///
  /// In en, this message translates to:
  /// **'Say hi 👋'**
  String get chatSayHi;

  /// Chat title while the other person’s name is not loaded.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitleFallback;

  /// Relative time for under a minute ago, on the chat list.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get chatTimeNow;

  /// Relative time in minutes on the chat list.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String chatTimeMinutes(int minutes);

  /// Relative time in hours on the chat list.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String chatTimeHours(int hours);

  /// Relative time in days on the chat list.
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String chatTimeDays(int days);

  /// Accessibility label of the unread dot on a chat row.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get chatUnreadSemantics;

  /// Marker under the sender’s latest message once the other person read it.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get chatSeen;

  /// Hint of the message field.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatComposerHint;

  /// Tooltip and accessibility label of the send button.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get chatSendTooltip;

  /// Snackbar when sending a message failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your message. Try again.'**
  String get chatSendFailed;

  /// Shown instead of the thread when the match is gone.
  ///
  /// In en, this message translates to:
  /// **'This chat is no longer available — the meal was cancelled.'**
  String get chatUnavailable;

  /// Button on the unavailable-chat state.
  ///
  /// In en, this message translates to:
  /// **'Back to chats'**
  String get chatBackToChats;

  /// Tooltip of the app bar action that cancels or withdraws from a matched meal.
  ///
  /// In en, this message translates to:
  /// **'Can\'t make it'**
  String get leaveMatchTooltip;

  /// Stands in for the other person’s name in the leave dialog when it is not loaded.
  ///
  /// In en, this message translates to:
  /// **'Your match'**
  String get leaveMatchOtherFallback;

  /// Leave dialog title for the host.
  ///
  /// In en, this message translates to:
  /// **'Cancel this meal?'**
  String get leaveMatchHostTitle;

  /// Leave dialog title for the guest.
  ///
  /// In en, this message translates to:
  /// **'Withdraw from this meal?'**
  String get leaveMatchGuestTitle;

  /// Leave dialog body for the host; name is the guest.
  ///
  /// In en, this message translates to:
  /// **'{name} will be told and the meal will be removed.'**
  String leaveMatchHostBody(String name);

  /// Leave dialog body for the guest; name is the host.
  ///
  /// In en, this message translates to:
  /// **'{name} will be told and the meal will open up again for others.'**
  String leaveMatchGuestBody(String name);

  /// Dialog button that keeps the meal.
  ///
  /// In en, this message translates to:
  /// **'Keep meal'**
  String get leaveMatchKeep;

  /// Dialog button that cancels the meal (host).
  ///
  /// In en, this message translates to:
  /// **'Cancel meal'**
  String get leaveMatchHostConfirm;

  /// Dialog button that withdraws the guest.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get leaveMatchGuestConfirm;

  /// Snackbar after the host cancelled the meal.
  ///
  /// In en, this message translates to:
  /// **'Meal cancelled.'**
  String get leaveMatchHostDone;

  /// Snackbar after the guest withdrew.
  ///
  /// In en, this message translates to:
  /// **'You\'ve withdrawn.'**
  String get leaveMatchGuestDone;

  /// Snackbar when cancelling or withdrawing failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t cancel. Check your connection and try again.'**
  String get leaveMatchFailed;

  /// One-line banner above the chat thread.
  ///
  /// In en, this message translates to:
  /// **'Meeting up? Safety tips'**
  String get safetyTipsBanner;

  /// Tooltip of the banner close button.
  ///
  /// In en, this message translates to:
  /// **'Dismiss safety tips'**
  String get safetyTipsBannerDismiss;

  /// Heading of the safety tips sheet and screen.
  ///
  /// In en, this message translates to:
  /// **'Meeting up? Stay safe'**
  String get safetyTipsHeading;

  /// Safety tip 1.
  ///
  /// In en, this message translates to:
  /// **'Meet in a public place'**
  String get safetyTipPublicPlace;

  /// Safety tip 2.
  ///
  /// In en, this message translates to:
  /// **'Tell a friend where you\'re going'**
  String get safetyTipTellFriend;

  /// Safety tip 3.
  ///
  /// In en, this message translates to:
  /// **'Trust your instincts'**
  String get safetyTipInstincts;

  /// Safety tip 4.
  ///
  /// In en, this message translates to:
  /// **'You can block or report anytime'**
  String get safetyTipBlockReport;

  /// Button that closes the safety tips sheet.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get safetyTipsGotIt;

  /// Primary button that sends a short form (report, rating).
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// Label shown on a submit button while it is in flight.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get commonSubmitting;

  /// Primary button that saves edits.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Safety menu item and report sheet title when the target is unnamed.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get safetyReportAction;

  /// Safety menu item and confirm button that blocks a person.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get safetyBlockAction;

  /// Title of the block confirmation dialog when the person is named.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String safetyBlockTitleNamed(String name);

  /// Title of the block confirmation dialog when the name is unknown.
  ///
  /// In en, this message translates to:
  /// **'Block this person?'**
  String get safetyBlockTitleGeneric;

  /// Body of the block confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see each other in Convyve anymore.'**
  String get safetyBlockBody;

  /// Snackbar when blocking failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t block. Try again.'**
  String get safetyBlockFailed;

  /// Snackbar after a successful block.
  ///
  /// In en, this message translates to:
  /// **'Blocked.'**
  String get safetyBlockDone;

  /// App bar title of the Safety tips screen and Settings row label.
  ///
  /// In en, this message translates to:
  /// **'Safety tips'**
  String get safetyTipsTitle;

  /// Report sheet title when the person is named.
  ///
  /// In en, this message translates to:
  /// **'Report {name}'**
  String reportTitleNamed(String name);

  /// Report sheet title when the target is a meal.
  ///
  /// In en, this message translates to:
  /// **'Report this meal'**
  String get reportTitleMeal;

  /// Report reason chip.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get reportReasonInappropriate;

  /// Report reason chip.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get reportReasonSpam;

  /// Report reason chip.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get reportReasonHarassment;

  /// Report reason chip.
  ///
  /// In en, this message translates to:
  /// **'Fake profile'**
  String get reportReasonFake;

  /// Report reason chip.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportReasonOther;

  /// Hint of the optional note field in the report sheet.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get reportNoteHint;

  /// Snackbar when sending a report failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit your report. Try again.'**
  String get reportFailed;

  /// Snackbar after a report was sent.
  ///
  /// In en, this message translates to:
  /// **'Thanks — we\'ll review this.'**
  String get reportThanks;

  /// Title of the blocked people screen and Settings row.
  ///
  /// In en, this message translates to:
  /// **'Blocked people'**
  String get blockedTitle;

  /// Empty-state title of the blocked people screen.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t blocked anyone'**
  String get blockedEmptyTitle;

  /// Empty-state message of the blocked people screen.
  ///
  /// In en, this message translates to:
  /// **'People you block are hidden from your meals and chats.'**
  String get blockedEmptyMessage;

  /// Name shown for a blocked person whose profile cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get blockedUnknownUser;

  /// Button that unblocks a person.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get blockedUnblock;

  /// Screen-reader label of the Unblock button, naming the person.
  ///
  /// In en, this message translates to:
  /// **'Unblock {name}'**
  String blockedUnblockSemantics(String name);

  /// Label of the Unblock button while it is in flight.
  ///
  /// In en, this message translates to:
  /// **'Unblocking…'**
  String get blockedUnblocking;

  /// Snackbar after unblocking a person.
  ///
  /// In en, this message translates to:
  /// **'Unblocked {name}.'**
  String blockedUnblocked(String name);

  /// Snackbar when unblocking failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t unblock. Try again.'**
  String get blockedUnblockFailed;

  /// Rating sheet title when the partner is named.
  ///
  /// In en, this message translates to:
  /// **'How was your meal with {name}?'**
  String ratingTitleNamed(String name);

  /// Rating sheet title and post-meal card headline.
  ///
  /// In en, this message translates to:
  /// **'How was your meal?'**
  String get ratingTitle;

  /// Tooltip and screen-reader label of one star button in the rating sheet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 star} other{{count} stars}}'**
  String ratingStarTooltip(int count);

  /// Label of the show-up switch in the rating sheet.
  ///
  /// In en, this message translates to:
  /// **'Did they show up?'**
  String get ratingShowedUp;

  /// Hint of the optional comment field in the rating sheet.
  ///
  /// In en, this message translates to:
  /// **'Add a comment (optional)'**
  String get ratingCommentHint;

  /// Snackbar when sending a rating failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit your rating. Try again.'**
  String get ratingFailed;

  /// Snackbar after a rating was sent.
  ///
  /// In en, this message translates to:
  /// **'Thanks for the feedback!'**
  String get ratingThanks;

  /// Subtitle of the post-meal card.
  ///
  /// In en, this message translates to:
  /// **'It only takes a moment.'**
  String get ratingCardSubtitle;

  /// Post-meal card button when the partner is unnamed.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get ratingRate;

  /// Post-meal card button naming the partner.
  ///
  /// In en, this message translates to:
  /// **'Rate {name}'**
  String ratingRateNamed(String name);

  /// Badge shown instead of a score when a person has no ratings yet.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get ratingBadgeNew;

  /// Rating badge: average (one decimal) and number of ratings.
  ///
  /// In en, this message translates to:
  /// **'{average} ({count})'**
  String ratingBadgeScore(double average, int count);

  /// Settings screen title and the Profile app bar tooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings section header.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// Settings row that opens the Profile tab.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsEditProfile;

  /// Settings row showing the signed-in phone number.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get settingsPhoneNumber;

  /// Settings row and confirm button that signs the user out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// Title of the sign-out confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get settingsSignOutTitle;

  /// Settings section header.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get settingsSectionSafety;

  /// Settings row that opens a mail to support.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get settingsContactSupport;

  /// Snackbar when the mail app could not be opened; email is the support address.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open your mail app. Write to {email}'**
  String settingsMailFailed(String email);

  /// Settings section header (iOS).
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsSectionNotifications;

  /// Settings row that opens the iOS Settings page of the app.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get settingsNotificationSettings;

  /// Subtitle of the notification settings row.
  ///
  /// In en, this message translates to:
  /// **'Manage notifications in iOS Settings'**
  String get settingsNotificationSubtitle;

  /// Settings section header.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsSectionLegal;

  /// Settings row that opens the privacy policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// Settings row that opens the terms of service.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTermsOfService;

  /// Settings row that opens the open-source licences page.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get settingsLicenses;

  /// Settings section header.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// Settings row that opens the language picker.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Language picker option and row subtitle: follow the device language.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// Title of the language picker dialog.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// Settings row showing the app version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// Subtitle of the version row while it loads.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get settingsVersionLoading;

  /// Subtitle of the version row when it could not be read.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get settingsVersionUnavailable;

  /// Settings row and confirm button that deletes the account.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// Title of the delete-account confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get settingsDeleteTitle;

  /// Body of the delete-account confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and all your data. This can\'t be undone.'**
  String get settingsDeleteBody;

  /// Snackbar when deleting the account failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete account. Try again.'**
  String get settingsDeleteFailed;

  /// Snackbar after saving the profile.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// Label before the rating badge on the Profile tab.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get profileYourRating;

  /// Shown on the Profile tab when the user has no ratings.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet'**
  String get profileNoRatings;

  /// Heading of the photo grid in the profile form.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get profileFormPhotos;

  /// Tooltip and screen-reader label of the remove button on a photo.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get profileFormRemovePhoto;

  /// Label of the add-photo tile.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get profileFormAddPhoto;

  /// Screen-reader label of the add-photo tile while a photo uploads.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo'**
  String get profileFormUploadingPhoto;

  /// Label of the name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileFormName;

  /// Heading above the gender choices; the choice completes the phrase.
  ///
  /// In en, this message translates to:
  /// **'I am a'**
  String get profileFormGenderHeading;

  /// Label of the bio field.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileFormBio;

  /// Gender choice.
  ///
  /// In en, this message translates to:
  /// **'Woman'**
  String get genderWoman;

  /// Gender choice.
  ///
  /// In en, this message translates to:
  /// **'Man'**
  String get genderMan;

  /// Gender choice.
  ///
  /// In en, this message translates to:
  /// **'Non-binary'**
  String get genderNonBinary;

  /// Missing profile field, as part of the still-needed list.
  ///
  /// In en, this message translates to:
  /// **'a photo'**
  String get profileMissingPhoto;

  /// Missing profile field, as part of the still-needed list.
  ///
  /// In en, this message translates to:
  /// **'your name'**
  String get profileMissingName;

  /// Missing profile field, as part of the still-needed list.
  ///
  /// In en, this message translates to:
  /// **'how you identify'**
  String get profileMissingGender;

  /// Joins two missing profile fields.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String profileMissingTwo(String first, String second);

  /// Joins three missing profile fields.
  ///
  /// In en, this message translates to:
  /// **'{first}, {second} and {third}'**
  String profileMissingThree(String first, String second, String third);
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
