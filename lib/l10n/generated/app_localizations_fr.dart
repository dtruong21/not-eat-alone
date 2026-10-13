// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get commonTryAgain => 'Réessayer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonDismiss => 'Fermer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonLoading => 'Chargement';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonSaving => 'Enregistrement…';

  @override
  String get commonSomethingWentWrong => 'Un problème est survenu. Réessaie.';

  @override
  String get errorStateTitle => 'Chargement impossible';

  @override
  String get errorStateMessage => 'Vérifie ta connexion et réessaie.';

  @override
  String get navDiscover => 'Découvrir';

  @override
  String get navChats => 'Discussions';

  @override
  String get navRequests => 'Demandes';

  @override
  String get navProfile => 'Profil';

  @override
  String get authSendingCode => 'Envoi du code…';

  @override
  String get signinTitle => 'Bienvenue sur Convyve';

  @override
  String get signinSubtitle => 'Rencontre quelqu’un autour d’un repas à Paris.';

  @override
  String get signinContinueGoogle => 'Continuer avec Google';

  @override
  String get signinContinueApple => 'Continuer avec Apple';

  @override
  String get signinSigningIn => 'Connexion…';

  @override
  String get signinOr => 'ou';

  @override
  String get signinPhoneLabel => 'Numéro de téléphone';

  @override
  String get signinPhoneError =>
      'Saisis un numéro avec l’indicatif du pays, par ex. +33 6 12 34 56 78';

  @override
  String get signinSendCode => 'Envoyer le code';

  @override
  String get commonUnderageNotice =>
      'Tu dois avoir 18 ans ou plus pour utiliser Convyve.';

  @override
  String get phoneTitle => 'Saisis le code';

  @override
  String phoneSentTo(String phone) {
    return 'Envoyé au $phone';
  }

  @override
  String get phoneChange => 'Modifier';

  @override
  String get phoneChangeSemantics => 'Modifier le numéro de téléphone';

  @override
  String get phoneCodeLabel => 'Code à 6 chiffres';

  @override
  String get phoneWrongCode =>
      'Ce code n’a pas fonctionné. Vérifie-le ou renvoie-le.';

  @override
  String get phoneVerify => 'Valider';

  @override
  String get phoneVerifying => 'Vérification…';

  @override
  String get phoneResend => 'Renvoyer le code';

  @override
  String phoneResendIn(int seconds) {
    return 'Renvoyer le code dans $seconds s';
  }

  @override
  String get phoneResent => 'Code renvoyé';

  @override
  String get agegateTitle => 'Confirme ta date de naissance';

  @override
  String get agegateSelect => 'Choisis ta date de naissance';

  @override
  String get agegateHelp => 'Ta date de naissance';

  @override
  String get agegateFieldLabel => 'Date de naissance';

  @override
  String get setupTitle => 'Configure ton profil';

  @override
  String get setupSubtitle => 'Nom, photo et genre. C’est tout.';

  @override
  String profileStillNeeded(String summary) {
    return 'Il manque encore : $summary.';
  }
}
