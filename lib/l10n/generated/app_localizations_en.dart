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
}
