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
  String get commonLoading => 'Chargement';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonSaving => 'Enregistrement…';

  @override
  String get commonSomethingWentWrong =>
      'Oups, un problème est survenu. Réessaie.';

  @override
  String get errorStateTitle => 'Chargement impossible';

  @override
  String get errorStateMessage => 'Vérifie ta connexion et réessaie.';

  @override
  String get navDiscover => 'Découvrir';

  @override
  String get navChats => 'Messages';

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
    return 'Code envoyé au $phone';
  }

  @override
  String get phoneChange => 'Modifier';

  @override
  String get phoneChangeSemantics => 'Modifier le numéro de téléphone';

  @override
  String get phoneCodeLabel => 'Code à 6 chiffres';

  @override
  String get phoneWrongCode =>
      'Ce code n’a pas fonctionné. Vérifie-le ou demande un nouveau code.';

  @override
  String get phoneVerify => 'Valider';

  @override
  String get phoneVerifying => 'Vérification…';

  @override
  String get phoneResend => 'Renvoyer le code';

  @override
  String phoneResendIn(int seconds) {
    return 'Renvoyer le code dans $seconds s';
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

  @override
  String get mealWomenOnly => 'Entre femmes';

  @override
  String get mealHostFallbackName => 'Hôte';

  @override
  String get discoverEmptyTitle => 'Pas encore de repas près de toi';

  @override
  String get discoverEmptyMessage =>
      'Lance-toi : propose un repas et quelqu’un te rejoindra.';

  @override
  String get discoverCreateMeal => 'Créer un repas';

  @override
  String discoverDistanceKm(double distance) {
    final intl.NumberFormat distanceNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String distanceString = distanceNumberFormat.format(distance);

    return '$distanceString km';
  }

  @override
  String get parisNotice =>
      'Convyve n’est qu’à Paris pour l’instant — on démarre tout juste.';

  @override
  String get mealDetailTitle => 'Détails du repas';

  @override
  String get mealDetailHostHeading => 'Hôte';

  @override
  String get mealDetailHostUnavailable => 'Hôte indisponible';

  @override
  String mealDetailHostNameAge(String name, int age) {
    return '$name, $age ans';
  }

  @override
  String get mealDetailReportMeal => 'Signaler ce repas';

  @override
  String get mealDetailReportHost => 'Signaler l’hôte';

  @override
  String get mealDetailBlockHost => 'Bloquer l’hôte';

  @override
  String get mealDetailOpenInMaps => 'Ouvrir dans Maps';

  @override
  String mealDetailOpenInMapsSemantics(String restaurant) {
    return 'Ouvrir $restaurant dans Maps';
  }

  @override
  String get mealDetailMapsFailed => 'Impossible d’ouvrir Maps';

  @override
  String get mealActionRequestToJoin => 'Demander à rejoindre';

  @override
  String get mealActionSendingRequest => 'Envoi de la demande…';

  @override
  String get mealActionRequested => 'Demande envoyée';

  @override
  String get mealActionOpenChat => 'Ouvrir la discussion';

  @override
  String get mealActionNotSelected => 'Pas cette fois';

  @override
  String get mealActionYourMeal => 'C’est ton repas';

  @override
  String get mealActionCancelled => 'Repas annulé';

  @override
  String get mealActionStatusYourMeal => 'Tes demandes : onglet Demandes.';

  @override
  String get mealActionStatusCancelled => 'L’hôte a annulé ce repas.';

  @override
  String get mealActionEnded => 'Repas terminé';

  @override
  String get mealActionStatusEnded => 'Ce repas est terminé.';

  @override
  String get mealActionStatusWomenOnly => 'Réservé aux femmes.';

  @override
  String get mealActionStatusLoadError => 'Impossible de charger ta demande.';

  @override
  String get mealActionStatusPending => 'L’hôte n’a pas encore répondu.';

  @override
  String get mealActionStatusApproved => 'C’est un match ! Dis bonjour !';

  @override
  String get mealActionStatusDenied => 'L’hôte a choisi quelqu’un d’autre.';

  @override
  String get mealActionNoLongerOpen => 'Ce repas n’est plus ouvert.';

  @override
  String get mealActionRequestFailed =>
      'Impossible d’envoyer ta demande. Réessaie.';

  @override
  String get createMealTitle => 'Créer un repas';

  @override
  String get createMealPickDateTime => 'Choisir la date et l’heure';

  @override
  String get createMealNoteLabel => 'Note (facultative)';

  @override
  String get createMealSubmit => 'Publier le repas';

  @override
  String get createMealCreating => 'Publication…';

  @override
  String createMealTooSoon(int minutes) {
    return 'Choisis une heure à au moins $minutes minutes d’ici.';
  }

  @override
  String get createMealPosted =>
      'Repas publié. Tu recevras les demandes dans l’onglet Demandes.';

  @override
  String get restaurantSearchTitle => 'Trouver un restaurant';

  @override
  String get restaurantSearchHint => 'Chercher un restaurant';

  @override
  String get restaurantSearchEmpty =>
      'Aucun restaurant à afficher pour l’instant.';

  @override
  String restaurantSearchNoMatch(String query) {
    return 'Aucun restaurant ne s’appelle « $query ». Essaie un autre nom.';
  }

  @override
  String get inboxTitle => 'Demandes';

  @override
  String get inboxEmptyTitle => 'Aucune demande en attente';

  @override
  String get inboxGuestFallback => 'Convive';

  @override
  String inboxGuestNameAge(String name, int age) {
    return '$name, $age ans';
  }

  @override
  String get inboxPastMeal => 'L’heure du repas est passée';

  @override
  String get inboxApprove => 'Accepter';

  @override
  String get inboxApproving => 'Acceptation…';

  @override
  String get inboxDeny => 'Refuser';

  @override
  String get inboxDenying => 'Refus…';

  @override
  String get inboxActionChat => 'Discuter';

  @override
  String get inboxOutcomeApproved =>
      'Demande acceptée. Tu peux discuter maintenant.';

  @override
  String get inboxOutcomeApproveFailed =>
      'Impossible d’accepter cette demande. Elle a peut-être déjà été traitée.';

  @override
  String get inboxOutcomeDenied => 'Demande refusée.';

  @override
  String get inboxOutcomeDenyFailed =>
      'Impossible de refuser cette demande. Elle a peut-être déjà été traitée.';

  @override
  String get chatListTitle => 'Messages';

  @override
  String get chatListEmptyTitle => 'Pas encore de discussion';

  @override
  String get chatListEmptyMessage =>
      'Fais un match sur un repas pour lancer la discussion.';

  @override
  String get chatListFindMeal => 'Trouver un repas';

  @override
  String get chatSayHi => 'Dis bonjour 👋';

  @override
  String get chatTitleFallback => 'Discussion';

  @override
  String get chatTimeNow => 'à l’instant';

  @override
  String chatTimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String chatTimeHours(int hours) {
    return '$hours h';
  }

  @override
  String chatTimeDays(int days) {
    return '$days j';
  }

  @override
  String get chatUnreadSemantics => 'Non lu';

  @override
  String get chatSeen => 'Vu';

  @override
  String get chatComposerHint => 'Message';

  @override
  String get chatSendTooltip => 'Envoyer le message';

  @override
  String get chatSendFailed => 'Impossible d’envoyer ton message. Réessaie.';

  @override
  String get queuedWriteJoinRequestFailed =>
      'Ta demande n’a pas abouti. Réessaie.';

  @override
  String get queuedWriteMealFailed => 'Ton repas n’a pas été publié. Réessaie.';

  @override
  String get queuedWriteRatingFailed => 'Ta note n’a pas été enregistrée.';

  @override
  String get queuedWriteMessageFailed => 'Un message n’a pas été envoyé.';

  @override
  String get chatUnavailable =>
      'Cette discussion n’est plus disponible — le repas a été annulé.';

  @override
  String get chatBackToChats => 'Retour aux messages';

  @override
  String get leaveMatchTooltip => 'Je ne peux pas venir';

  @override
  String get leaveMatchOtherFallback => 'l’autre personne';

  @override
  String get leaveMatchHostTitle => 'Annuler ce repas ?';

  @override
  String get leaveMatchGuestTitle => 'Te retirer de ce repas ?';

  @override
  String leaveMatchHostBody(String name) {
    return 'On préviendra $name et le repas sera supprimé.';
  }

  @override
  String leaveMatchGuestBody(String name) {
    return 'On préviendra $name et le repas sera de nouveau ouvert aux autres.';
  }

  @override
  String get leaveMatchKeep => 'Garder le repas';

  @override
  String get leaveMatchHostConfirm => 'Annuler le repas';

  @override
  String get leaveMatchGuestConfirm => 'Me retirer';

  @override
  String get leaveMatchHostDone => 'Repas annulé.';

  @override
  String get leaveMatchGuestDone => 'Tu as annulé ta participation.';

  @override
  String get leaveMatchFailed =>
      'Annulation impossible. Vérifie ta connexion et réessaie.';

  @override
  String get safetyTipsBanner => 'Bientôt à table ? Conseils de sécurité';

  @override
  String get safetyTipsBannerDismiss => 'Fermer les conseils de sécurité';

  @override
  String get safetyTipsHeading => 'Bientôt à table ? Reste en sécurité';

  @override
  String get safetyTipPublicPlace => 'Donne rendez-vous dans un lieu public';

  @override
  String get safetyTipTellFriend => 'Préviens un proche de l’endroit où tu vas';

  @override
  String get safetyTipInstincts => 'Fie-toi à ton instinct';

  @override
  String get safetyTipBlockReport =>
      'Tu peux bloquer ou signaler à tout moment';

  @override
  String get safetyTipsGotIt => 'Compris';

  @override
  String get commonSubmit => 'Envoyer';

  @override
  String get commonSubmitting => 'Envoi…';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get safetyReportAction => 'Signaler';

  @override
  String get safetyBlockAction => 'Bloquer';

  @override
  String safetyBlockTitleNamed(String name) {
    return 'Bloquer $name ?';
  }

  @override
  String get safetyBlockTitleGeneric => 'Bloquer cette personne ?';

  @override
  String get safetyBlockBody =>
      'Tu ne verras plus cette personne sur Convyve, et elle ne te verra plus.';

  @override
  String get safetyBlockFailed => 'Impossible de bloquer. Réessaie.';

  @override
  String get safetyBlockDone => 'Tu as bloqué cette personne.';

  @override
  String get safetyTipsTitle => 'Conseils de sécurité';

  @override
  String reportTitleNamed(String name) {
    return 'Signaler $name';
  }

  @override
  String get reportTitleMeal => 'Signaler ce repas';

  @override
  String get reportReasonInappropriate => 'Contenu inapproprié';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonHarassment => 'Harcèlement';

  @override
  String get reportReasonFake => 'Faux profil';

  @override
  String get reportReasonOther => 'Autre';

  @override
  String get reportNoteHint => 'Ajoute un commentaire (facultatif)';

  @override
  String get reportFailed => 'Impossible d’envoyer ton signalement. Réessaie.';

  @override
  String get reportThanks => 'Merci. Nous allons examiner ton signalement.';

  @override
  String get blockedTitle => 'Personnes bloquées';

  @override
  String get blockedEmptyTitle => 'Tu n’as bloqué personne';

  @override
  String get blockedEmptyMessage =>
      'Les personnes que tu bloques sont masquées de tes repas et de tes discussions.';

  @override
  String get blockedUnknownUser => 'Profil inconnu';

  @override
  String get blockedUnblock => 'Débloquer';

  @override
  String blockedUnblockSemantics(String name) {
    return 'Débloquer $name';
  }

  @override
  String get blockedUnblocking => 'Déblocage…';

  @override
  String blockedUnblocked(String name) {
    return 'Tu as débloqué $name.';
  }

  @override
  String get blockedUnblockFailed => 'Impossible de débloquer. Réessaie.';

  @override
  String ratingTitleNamed(String name) {
    return 'Comment s’est passé ton repas avec $name ?';
  }

  @override
  String get ratingTitle => 'Comment s’est passé ton repas ?';

  @override
  String ratingStarTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étoiles',
      one: '$count étoile',
    );
    return '$_temp0';
  }

  @override
  String get ratingShowedUp => 'La personne est-elle venue ?';

  @override
  String get ratingCommentHint => 'Ajoute un commentaire (facultatif)';

  @override
  String get ratingFailed => 'Impossible d’envoyer ta note. Réessaie.';

  @override
  String get ratingThanks => 'Merci pour ton retour !';

  @override
  String get ratingCardSubtitle => 'Ça ne prend qu’un instant.';

  @override
  String ratingCardSubtitleNamed(String name) {
    return 'Avec $name';
  }

  @override
  String get ratingRate => 'Noter';

  @override
  String ratingRateNamed(String name) {
    return 'Noter $name';
  }

  @override
  String get ratingBadgeNew => 'Nouveau';

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
  String get settingsTitle => 'Réglages';

  @override
  String get settingsSectionAccount => 'Compte';

  @override
  String get settingsEditProfile => 'Modifier le profil';

  @override
  String get settingsPhoneNumber => 'Numéro de téléphone';

  @override
  String get settingsSignOut => 'Se déconnecter';

  @override
  String get settingsSignOutTitle => 'Te déconnecter ?';

  @override
  String get settingsSectionSafety => 'Sécurité';

  @override
  String get settingsContactSupport => 'Contacter l’assistance';

  @override
  String settingsMailFailed(String email) {
    return 'Impossible d’ouvrir ta messagerie. Écris à $email';
  }

  @override
  String get settingsSectionNotifications => 'Notifications';

  @override
  String get settingsNotificationSettings => 'Réglages des notifications';

  @override
  String get settingsNotificationSubtitle =>
      'Gère les notifications dans les Réglages iOS';

  @override
  String get settingsSectionLegal => 'Informations légales';

  @override
  String get settingsPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get settingsTermsOfService => 'Conditions d’utilisation';

  @override
  String get settingsLicenses => 'Licences open source';

  @override
  String get settingsSectionAbout => 'À propos';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Langue du système';

  @override
  String get settingsLanguageTitle => 'Langue';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsVersionLoading => 'Chargement…';

  @override
  String get settingsVersionUnavailable => 'Indisponible';

  @override
  String get settingsDeleteAccount => 'Supprimer le compte';

  @override
  String get settingsDeleteTitle => 'Supprimer ton compte ?';

  @override
  String get settingsDeleteBody =>
      'Cela supprime définitivement ton compte et toutes tes données. Cette action est irréversible.';

  @override
  String get settingsDeleteFailed =>
      'Impossible de supprimer le compte. Réessaie.';

  @override
  String get profileSaved => 'Profil enregistré';

  @override
  String get profileYourRating => 'Ta note';

  @override
  String get profileNoRatings => 'Aucune note pour le moment';

  @override
  String get profileFormPhotos => 'Photos';

  @override
  String get profileFormRemovePhoto => 'Supprimer la photo';

  @override
  String get profileFormAddPhoto => 'Ajouter une photo';

  @override
  String get profileFormUploadingPhoto => 'Envoi de la photo en cours';

  @override
  String get profileFormName => 'Nom';

  @override
  String get profileFormGenderHeading => 'Je suis';

  @override
  String get profileFormBio => 'Bio';

  @override
  String get genderWoman => 'Femme';

  @override
  String get genderMan => 'Homme';

  @override
  String get genderNonBinary => 'Non-binaire';

  @override
  String get profileMissingPhoto => 'une photo';

  @override
  String get profileMissingName => 'ton nom';

  @override
  String get profileMissingGender => 'ton genre';

  @override
  String profileMissingTwo(String first, String second) {
    return '$first et $second';
  }

  @override
  String profileMissingThree(String first, String second, String third) {
    return '$first, $second et $third';
  }
}
