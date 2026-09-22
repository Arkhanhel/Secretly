// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Secretly';

  @override
  String get starting => 'Démarrage…';

  @override
  String get encrypting => 'Chiffrement…';

  @override
  String errorPrefix(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get notificationsSection => 'Notifications';

  @override
  String get languageSection => 'Langue';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get idsTitle => 'IDs';

  @override
  String get profileIdLabel => 'ID de profil';

  @override
  String get deviceIdLabel => 'ID d’appareil';

  @override
  String get profileIdShort => 'Profil';

  @override
  String get deviceIdShort => 'Appareil';

  @override
  String get copy => 'Copier';

  @override
  String get copied => 'Copié';

  @override
  String get copyBoth => 'Copier les deux';

  @override
  String get openMyId => 'Ouvrir mon ID';

  @override
  String get close => 'Fermer';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabGroups => 'Salons';

  @override
  String get tabContacts => 'Contacts';

  @override
  String get tabProfile => 'Profil';

  @override
  String get accountSection => 'Compte';

  @override
  String get chatsSection => 'Chats';

  @override
  String get privacySection => 'Confidentialité';

  @override
  String get devicesSection => 'Appareils';

  @override
  String get systemSection => 'Système';

  @override
  String get languageSystemDefault => 'Langue du système';

  @override
  String languageSystemCurrent(Object language) {
    return 'Système ($language)';
  }

  @override
  String get languageChooseAppLanguage => 'Choisir la langue de l’app';

  @override
  String get languageAvailableWave1 => 'Disponible : anglais, russe, ukrainien, espagnol, portugais (Brésil), français et allemand. Vous pouvez aussi suivre la langue du système.';

  @override
  String get languageMessageTranslation => 'Traduction des messages';

  @override
  String get languageShowTranslateButton => 'Afficher le bouton Traduire';

  @override
  String get languageTranslateWholeChats => 'Traduire les chats entiers';

  @override
  String get favoritesTitle => 'Favoris';

  @override
  String get favoritesSubtitle => 'Vos notes personnelles';

  @override
  String get favoritesEmptyTitle => 'Aucun favori pour le moment';

  @override
  String get favoritesEmptySubtitle => 'Envoyez ici des messages, fichiers et notes pour les garder privés sur vos appareils.';

  @override
  String get favoritesPersonalNotebookLabel => 'Notes personnelles';

  @override
  String get more => 'Plus';

  @override
  String get stickersRecent => 'Stickers récents';

  @override
  String get searchStickers => 'Rechercher des stickers';

  @override
  String get noStickersFound => 'Aucun sticker trouvé';

  @override
  String get noRecentStickers => 'Vos stickers récents apparaîtront ici';

  @override
  String get cancelSelection => 'Annuler la sélection';

  @override
  String get chatsTitle => 'Chats';

  @override
  String get newChat => 'Nouveau chat';

  @override
  String get openContactsToStartChat => 'Ouvrez Contacts pour démarrer un chat';

  @override
  String get noChatsYet => 'Aucun chat pour le moment';

  @override
  String get openDemoChat => 'Ouvrir le chat de démonstration';

  @override
  String get archive => 'Archiver';

  @override
  String get unarchive => 'Désarchiver';

  @override
  String get pin => 'Épingler';

  @override
  String get unpin => 'Désépingler';

  @override
  String get clearHistory => 'Effacer l’historique';

  @override
  String archiveHeader(Object count) {
    return 'Archive ($count)';
  }

  @override
  String deleteChatsConfirmTitle(Object count) {
    return 'Supprimer $count chat(s) ?';
  }

  @override
  String get deleteChatsConfirmBody => 'Cela supprime les chats de cet appareil uniquement.';

  @override
  String clearHistoryConfirmTitle(Object count) {
    return 'Effacer l’historique de $count chat(s) ?';
  }

  @override
  String get clearHistoryConfirmBody => 'Cela supprime les messages de cet appareil uniquement.';

  @override
  String get contactsTitle => 'Contacts';

  @override
  String get contactsTab => 'Contacts';

  @override
  String get requestsTab => 'Demandes';

  @override
  String get addContact => 'Ajouter un contact';

  @override
  String get deleteContact => 'Supprimer le contact';

  @override
  String get noContactsYet => 'Aucun contact pour le moment';

  @override
  String get noRequests => 'Aucune demande';

  @override
  String get secretlyIdLabel => 'Secretly ID';

  @override
  String get secretlyIdHint => 'XXXX-XXXX-...-CHECK';

  @override
  String get nameOptionalLabel => 'Nom (facultatif)';

  @override
  String get scanContactQrTitle => 'Scanner le QR du contact';

  @override
  String get qrMissingSecretlyId => 'Le QR ne contient pas de Secretly ID';

  @override
  String get differentServerTitle => 'Serveur différent';

  @override
  String differentServerBody(Object qrServer, Object appServer) {
    return 'Ce QR appartient à un autre serveur.\n\nServeur du QR : $qrServer\nCette app : $appServer\n\nInstallez le même APK/serveur sur les deux téléphones.';
  }

  @override
  String get contactActionProfileNotFound => 'Ce Secretly ID est introuvable sur ce serveur.';

  @override
  String get contactActionTransportBlocked => 'Cette action est indisponible, car l’app est liée à un autre serveur.';

  @override
  String get contactActionServiceUnavailable => 'Le serveur est indisponible pour le moment. Réessayez dans un instant.';

  @override
  String get contactActionCallsDisabled => 'Les appels sont désactivés dans les paramètres de confidentialité.';

  @override
  String get contactActionCallsDisabledForContact => 'Les appels sont désactivés pour ce contact.';

  @override
  String get callServiceUnavailable => 'Le service d’appels est indisponible pour le moment.';

  @override
  String get callAlreadyInProgress => 'Un autre appel est déjà en cours.';

  @override
  String get callIceUnavailable => 'La configuration sécurisée de l’appel est indisponible pour le moment. Réessayez dans un instant.';

  @override
  String get callPermissionDenied => 'L’accès au micro ou à la caméra est bloqué. Autorisez les permissions et réessayez.';

  @override
  String get callNegotiationFailed => 'Impossible d’établir l’appel sécurisé. Réessayez.';

  @override
  String get callConnectionInterrupted => 'La connexion de l’appel a été interrompue. Réessayez.';

  @override
  String get callActionGeneric => 'Impossible de démarrer l’appel. Réessayez.';

  @override
  String get callEncryptedBadge => 'Chiffré de bout en bout';

  @override
  String get incomingVideoCall => 'Appel vidéo entrant';

  @override
  String get incomingVoiceCall => 'Appel vocal entrant';

  @override
  String get callDecline => 'Refuser';

  @override
  String get callConnectionUnstable => 'Connexion instable';

  @override
  String get callNetworkVeryWeak => 'Signal réseau très faible';

  @override
  String get callNetworkWeak => 'Signal réseau faible';

  @override
  String get callEnded => 'Appel terminé';

  @override
  String get callReplacedByNewerAttempt => 'L’appel a été remplacé par une tentative plus récente';

  @override
  String get callDeclined => 'Appel refusé';

  @override
  String get callYouDeclined => 'Vous avez refusé';

  @override
  String get callNoAnswer => 'Pas de réponse';

  @override
  String get callConnectionError => 'Erreur de connexion';

  @override
  String get callVideoUnavailable => 'Vidéo indisponible';

  @override
  String get callWaitingForRemoteVideo => 'En attente de la vidéo distante...';

  @override
  String get callAttachingRemoteVideo => 'Connexion de la vidéo distante...';

  @override
  String get callStartingRemoteVideo => 'Démarrage de la vidéo distante...';

  @override
  String get callRemoteVideoNotArriving => 'La vidéo distante n’arrive pas';

  @override
  String get callRemoteVideoBindFailed => 'Impossible d’associer le flux vidéo distant';

  @override
  String get callRemoteVideoNoFrames => 'La vidéo distante est connectée, mais aucune image n’est rendue';

  @override
  String get callMinimize => 'Réduire';

  @override
  String get callStatusCalling => 'Appel...';

  @override
  String get callStatusIncoming => 'Entrant...';

  @override
  String get callStatusConnecting => 'Connexion...';

  @override
  String get callStatusReconnecting => 'Reconnexion...';

  @override
  String get callStatusEnded => 'Terminé';

  @override
  String get callVideoCall => 'Appel vidéo';

  @override
  String get callControlMute => 'Muet';

  @override
  String get callControlSpeaker => 'Haut-parleur';

  @override
  String get callControlCamera => 'Caméra';

  @override
  String get callControlFlip => 'Basculer';

  @override
  String get callControlStop => 'Arrêter';

  @override
  String get callControlShare => 'Partager';

  @override
  String get callControlEnd => 'Terminer';

  @override
  String get contactActionGeneric => 'Impossible de terminer l’action. Réessayez.';

  @override
  String get notificationTitleRoom => 'Salon';

  @override
  String get notificationTitleRequest => 'Demande';

  @override
  String get notificationTitleChat => 'Chat';

  @override
  String get notificationBodyNewMessage => 'Nouveau message';

  @override
  String get contactLookupUnavailable => 'La recherche est indisponible pour le moment. Réessayez dans un instant.';

  @override
  String addContactFailed(Object error) {
    return 'Échec de l’ajout du contact : $error';
  }

  @override
  String deleteContactsConfirmTitle(Object count) {
    return 'Supprimer $count contact(s) ?';
  }

  @override
  String get deleteContactsConfirmBody => 'Les chats ne sont pas supprimés.';

  @override
  String get privacyTitle => 'Confidentialité';

  @override
  String get blockedUsersSubtitle => 'Les utilisateurs bloqués ne peuvent pas vous livrer de messages (appliqué par le serveur).';

  @override
  String get noBlockedUsers => 'Aucun utilisateur bloqué';

  @override
  String unblockFailed(Object error) {
    return 'Échec du déblocage : $error';
  }

  @override
  String get diagIdentity => 'Identité';

  @override
  String get diagEndpoints => 'Endpoints';

  @override
  String get diagServerBinding => 'Liaison au serveur';

  @override
  String get diagMismatch => 'Non-correspondance : le profil appartient à un autre serveur. Utilisez Paramètres → Réinitialiser le profil.';

  @override
  String get diagStatus => 'État';

  @override
  String get diagTimestamps => 'Horodatages';

  @override
  String get diagTips => 'Conseils';

  @override
  String get diagTipsBody => 'Si la messagerie échoue avec \"profile not found\" :\n1) Vérifiez que les deux téléphones utilisent le même APK/serveur\n2) Rajoutez le contact en scannant le QR\n3) Si les endpoints ont changé, utilisez Réinitialiser le profil\n';

  @override
  String get secretlyUser => 'Utilisateur Secretly';

  @override
  String get onlineStatus => 'en ligne';

  @override
  String get edit => 'Modifier';

  @override
  String get removePhoto => 'Supprimer la photo';

  @override
  String get profileSectionTitle => 'Profil';

  @override
  String get myNicknameLabel => 'Mon pseudo';

  @override
  String get myNicknameHint => 'ex. Alex';

  @override
  String get includeNicknameInQr => 'Inclure mon pseudo dans mon QR';

  @override
  String get includeNicknameInQrSubtitle => 'Désactivé par défaut pour la confidentialité. Si activé, les personnes qui scannent peuvent vous nommer automatiquement.';

  @override
  String verifyTitle(Object title) {
    return 'Vérifier : $title';
  }

  @override
  String get scanVerifyQrTitle => 'Scanner le QR de vérification';

  @override
  String qrBelongsAnotherServer(Object server) {
    return 'Le QR appartient à un autre serveur : $server';
  }

  @override
  String get qrSecretlyIdMismatch => 'Le Secretly ID du QR ne correspond pas à ce contact';

  @override
  String get qrMissingDeviceKeyInfo => 'Le QR ne contient pas d’infos appareil/clé';

  @override
  String get deviceNotCachedTapRefresh => 'Appareil non mis en cache. Touchez d’abord Actualiser.';

  @override
  String get identityKeyMismatch => 'La identity key ne correspond pas. Ne vérifiez pas.';

  @override
  String get verifiedSuccess => 'Vérifié ✅';

  @override
  String get refreshKeys => 'Actualiser Keys';

  @override
  String get keysOfflineCannotFetch => 'Le service Keys est hors ligne. Impossible de récupérer les clés du contact maintenant.';

  @override
  String get devicesLabel => 'Appareils';

  @override
  String get noDeviceKeysCachedYet => 'Aucune clé d’appareil n’est encore en cache.';

  @override
  String deviceTitle(Object deviceId) {
    return 'Appareil $deviceId';
  }

  @override
  String deviceFpStatus(Object fp, Object status) {
    return 'fp : $fp\n$status';
  }

  @override
  String get verifiedLower => 'vérifié';

  @override
  String get unverifiedLower => 'non vérifié';

  @override
  String get keysOfflineIdTemporary => 'Le service Keys est hors ligne. L’ID peut être temporaire en mode développement.';

  @override
  String get serverKeysLabel => 'Serveur (Keys)';

  @override
  String get nicknameLabel => 'Pseudo';

  @override
  String get identityFingerprintLabel => 'Empreinte d’identité';

  @override
  String get scanToAddVerifyContact => 'Scannez pour ajouter/vérifier ce contact';

  @override
  String get mySecretlyId => 'Mon Secretly ID';

  @override
  String get deviceId => 'ID d’appareil';

  @override
  String get recoveryKit => 'Recovery Kit';

  @override
  String get safeBackupTitle => 'Safe Backup';

  @override
  String get safeBackupSubtitle => 'Safe Backup chiffré stocké sur le serveur';

  @override
  String get safeBackupIntro => 'Créez une sauvegarde chiffrée localement ou sur le serveur. Vous pourrez la restaurer plus tard depuis un fichier ou un Secretly ID.';

  @override
  String get safeBackupUploadNow => 'Téléverser la sauvegarde maintenant';

  @override
  String get safeBackupRestoreFromServer => 'Restaurer depuis le serveur';

  @override
  String get safeBackupRestoreTitle => 'Restaurer depuis la sauvegarde serveur';

  @override
  String get safeBackupRestoreConfirmTitle => 'Restaurer le compte ?';

  @override
  String get safeBackupRestoreConfirmBody => 'Cela supprimera les chats/contacts locaux de cet appareil et restaurera le compte depuis la sauvegarde sélectionnée. L’app redémarrera automatiquement.';

  @override
  String get safeBackupUploaded => 'Sauvegarde téléversée';

  @override
  String get safeBackupUploadFailed => 'Échec du téléversement de la sauvegarde';

  @override
  String safeBackupUploadFailedWithError(Object error) {
    return 'Échec du téléversement de la sauvegarde : $error';
  }

  @override
  String get safeBackupNotFound => 'Aucune sauvegarde serveur trouvée pour ce Secretly ID';

  @override
  String get exportRecoveryKit => 'Exporter le Recovery Kit';

  @override
  String get exportRecoveryKitSubtitle => 'QR chiffré pour la récupération du compte';

  @override
  String get restoreRecoveryKit => 'Restaurer depuis le Recovery Kit';

  @override
  String get restoreRecoveryKitSubtitle => 'Efface les données locales et restaure ce Secretly ID';

  @override
  String get recoveryPasswordTitle => 'Mot de passe du Recovery Kit';

  @override
  String get password => 'Mot de passe';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get export => 'Exporter';

  @override
  String get scanQr => 'Scanner le QR';

  @override
  String get invalidRecoveryKit => 'Recovery Kit non valide';

  @override
  String get wrongPassword => 'Mot de passe incorrect';

  @override
  String get restoreConfirmTitle => 'Restaurer le compte ?';

  @override
  String get restoreConfirmBody => 'Cela supprimera les chats/contacts locaux de cet appareil et restaurera le compte depuis le Recovery Kit.';

  @override
  String get restore => 'Restaurer';

  @override
  String get darkTheme => 'Thème sombre';

  @override
  String get darkThemeSubtitle => 'Utiliser la même teinte d’accent en mode sombre.';

  @override
  String get blockUnverified => 'Bloquer l’envoi aux contacts non vérifiés';

  @override
  String get blockUnverifiedSubtitle => 'Mode strict : dans les conversations individuelles, n\'envoyer qu\'aux contacts dont vous avez vérifié les clés vous-même. Ne s\'applique pas aux groupes.';

  @override
  String get blockedUsers => 'Utilisateurs bloqués';

  @override
  String get resetProfile => 'Réinitialiser le profil';

  @override
  String get resetProfileSubtitle => 'Corriger la non-correspondance serveur/compte en créant un nouveau Secretly ID';

  @override
  String get resetProfileDialogTitle => 'Réinitialiser le profil ?';

  @override
  String get resetProfileDialogBody => 'Cela supprimera les chats/contacts/demandes locaux de cet appareil et créera un nouveau Secretly ID.\n\nUtilisez cette option si vous avez changé d’APK/serveur et que les messages ont commencé à échouer.';

  @override
  String get cancel => 'Annuler';

  @override
  String get ok => 'OK';

  @override
  String get add => 'Ajouter';

  @override
  String get delete => 'Supprimer';

  @override
  String get clear => 'Effacer';

  @override
  String get block => 'Bloquer';

  @override
  String get unblock => 'Débloquer';

  @override
  String get accept => 'Accepter';

  @override
  String get verify => 'Vérifier';

  @override
  String get menu => 'Menu';

  @override
  String get search => 'Rechercher';

  @override
  String get queryLabel => 'Recherche';

  @override
  String get messageHint => 'Message';

  @override
  String get notificationActionMarkRead => 'Marquer comme lu';

  @override
  String get addCaption => 'Ajouter une légende';

  @override
  String get uploadCanceled => 'Téléversement annulé';

  @override
  String get attachmentFinalizeTimeout => 'Le réseau est instable : le téléversement est terminé, mais la confirmation d’envoi a expiré. Réessayez.';

  @override
  String get attachmentTransferUnavailable => 'Impossible de transférer la pièce jointe pour le moment. Vérifiez internet/serveur et réessayez.';

  @override
  String get attachmentSendUnavailable => 'L’envoi de pièces jointes n’est pas encore prêt. Réessayez.';

  @override
  String get attachmentContactSyncPending => 'En attente de la synchronisation d’identité du contact. Demandez au contact d’envoyer un autre message, puis réessayez.';

  @override
  String get attachmentContactBlocked => 'Ce contact est bloqué.';

  @override
  String get attachmentRecipientNotFound => 'Le profil du destinataire est introuvable sur ce serveur. Vérifiez le Secretly ID et assurez-vous que les deux appareils utilisent le même serveur.';

  @override
  String get attachmentRecipientNoDevices => 'Le destinataire n’a encore aucun appareil enregistré. Demandez au contact d’ouvrir Secretly et réessayez.';

  @override
  String get attachmentNoDeliverableDevices => 'Impossible de livrer la pièce jointe à un appareil du destinataire. Réessayez.';

  @override
  String get attachmentActionGeneric => 'Impossible d’envoyer la pièce jointe. Réessayez.';

  @override
  String get send => 'Envoyer';

  @override
  String get attach => 'Joindre';

  @override
  String get photo => 'Photo';

  @override
  String get video => 'Vidéo';

  @override
  String get file => 'Fichier';

  @override
  String get music => 'Musique';

  @override
  String get attachment => 'Pièce jointe';

  @override
  String get downloading => 'Téléchargement…';

  @override
  String downloadFailed(Object error) {
    return 'Échec du téléchargement : $error';
  }

  @override
  String savedTo(Object path) {
    return 'Enregistré dans : $path';
  }

  @override
  String get noMessagesYet => 'Aucun message pour le moment';

  @override
  String get decrypting => 'Déchiffrement…';

  @override
  String get uploading => 'Téléversement…';

  @override
  String get uploadTimedOut => 'Le téléversement a expiré. Vérifiez internet/serveur et réessayez.';

  @override
  String uploadingBytes(Object sent, Object total) {
    return 'Téléversé $sent / $total octets';
  }

  @override
  String get requestsInfo => 'Ce chat est dans Demandes. Acceptez pour répondre, ou bloquez pour l’ignorer.';

  @override
  String get verifyRequired => 'Vérification requise';

  @override
  String get verifyContact => 'Vérifier le contact';

  @override
  String get muteNotifications => 'Couper les notifications';

  @override
  String get unmuteNotifications => 'Réactiver les notifications';

  @override
  String get setContactPhoto => 'Définir la photo du contact';

  @override
  String get removeContactPhoto => 'Supprimer la photo du contact';

  @override
  String get blockUser => 'Bloquer l’utilisateur';

  @override
  String get unblockUser => 'Débloquer l’utilisateur';

  @override
  String get deleteChat => 'Supprimer le chat';

  @override
  String get missingRecipient => 'Destinataire manquant';

  @override
  String get contactNotVerified => 'Le code de sécurité a changé. Vérifiez-le pour continuer.';

  @override
  String get safetyNumberChangedTitle => 'Le code de sécurité a changé';

  @override
  String get safetyNumberChangedBody => 'Vous aviez déjà vérifié le code de ce contact. Ses clés sont nouvelles — cela arrive généralement après une réinstallation ou un changement de téléphone. La conversation reste chiffrée dans tous les cas. Comparez de nouveau le code si vous voulez être sûr que c\'est toujours la même personne.';

  @override
  String get safetyNumberStrictBody => 'Vous avez activé « Bloquer l\'envoi aux non vérifiés ». Comparez le code de ce contact pour lui envoyer des messages.';

  @override
  String get sendAnyway => 'Envoyer quand même';

  @override
  String get alsoDeleteChat => 'Supprimer aussi le chat';

  @override
  String get unblockUserConfirmTitle => 'Débloquer l’utilisateur ?';

  @override
  String get blockUserConfirmTitle => 'Bloquer l’utilisateur ?';

  @override
  String get deleteChatConfirmTitle => 'Supprimer le chat ?';

  @override
  String get deleteChatConfirmBody => 'Cela supprime le chat de cet appareil uniquement.';

  @override
  String attachFailed(Object error) {
    return 'Échec de l’ajout : $error';
  }

  @override
  String sendFailed(Object error) {
    return 'Échec de l’envoi : $error';
  }

  @override
  String actionFailed(Object error) {
    return 'Échec de l’action : $error';
  }

  @override
  String get roomPolicyNotMember => 'Vous ne participez plus à ce salon.';

  @override
  String get roomPolicyAdminsOnly => 'Seuls les propriétaires et administrateurs du salon peuvent faire cela.';

  @override
  String get roomPolicyTextMessagesDisabled => 'Votre rôle ne peut pas envoyer de messages texte dans ce salon.';

  @override
  String get roomPolicyMediaDisabled => 'Votre rôle ne peut pas envoyer de médias dans ce salon.';

  @override
  String get roomPolicyReactionsDisabled => 'Les réactions sont désactivées dans ce salon.';

  @override
  String get roomPolicyReactionNotAllowed => 'Cette réaction n’est pas autorisée dans ce salon.';

  @override
  String get roomPolicyPinDenied => 'Seuls les administrateurs peuvent épingler des messages dans ce salon.';

  @override
  String get roomPolicyAddMembersDenied => 'Seuls les administrateurs peuvent ajouter des participants à ce salon.';

  @override
  String get roomPolicyChangeInfoDenied => 'Seuls les administrateurs peuvent modifier le profil du groupe.';

  @override
  String roomPolicySlowMode(Object seconds) {
    return 'Le mode lent est activé. Réessayez dans $seconds s.';
  }

  @override
  String get noMatches => 'Aucun résultat';

  @override
  String attachmentTooLarge(Object mb) {
    return 'La pièce jointe est trop volumineuse ($mb Mo).';
  }

  @override
  String get attachmentFileMissing => 'Le fichier n’est plus disponible.';

  @override
  String foundPrefix(Object hit) {
    return 'Trouvé : $hit';
  }

  @override
  String get contactDetailsChat => 'Chat';

  @override
  String get contactDetailsSound => 'Son';

  @override
  String get contactDetailsCall => 'Appel';

  @override
  String get contactDetailsVideo => 'Vidéo';

  @override
  String get contactDetailsUsernameLabel => 'Nom d’utilisateur';

  @override
  String get contactDetailsAddToContacts => 'Ajouter aux contacts';

  @override
  String get contactDetailsMediaTab => 'Médias';

  @override
  String get contactDetailsFilesTab => 'Fichiers';

  @override
  String get contactDetailsNoMedia => 'Aucun média';

  @override
  String get contactDetailsNoFiles => 'Aucun fichier';

  @override
  String get contactDetailsStatusRecently => 'vu récemment';

  @override
  String contactDetailsStatusAt(Object time) {
    return 'vu à $time';
  }

  @override
  String get contactDetailsAutoDelete => 'Suppression automatique';

  @override
  String get contactDetailsShareContact => 'Partager le contact';

  @override
  String get contactDetailsEditContact => 'Modifier le contact';

  @override
  String get contactDetailsDeleteContact => 'Supprimer le contact';

  @override
  String get contactDetailsSendGift => 'Envoyer un cadeau';

  @override
  String get contactDetailsStartSecretChat => 'Démarrer un chat secret';

  @override
  String get contactDetailsCreateShortcut => 'Créer un raccourci';

  @override
  String get contactDetailsNameLabel => 'Nom';

  @override
  String get contactDetailsSave => 'Enregistrer';

  @override
  String get contactDetailsDeleteConfirmTitle => 'Supprimer le contact ?';

  @override
  String get contactAutoDeleteOff => 'Désactivé';

  @override
  String get contactAutoDelete1Day => '24 heures';

  @override
  String get contactAutoDelete7Days => '7 jours';

  @override
  String get contactAutoDelete30Days => '30 jours';

  @override
  String get contactEditTitle => 'Modifier le contact';

  @override
  String get contactEditDone => 'TERMINÉ';

  @override
  String get contactEditNameLabel => 'Nom';

  @override
  String get contactEditAssignEmoji => 'Attribuer un emoji';

  @override
  String get contactEditClearEmoji => 'Effacer l’emoji';

  @override
  String get contactEditSetPhoto => 'Définir la photo';

  @override
  String get chatMenuReply => 'Répondre';

  @override
  String get chatMenuCopy => 'Copier';

  @override
  String get chatMenuForward => 'Transférer';

  @override
  String get chatMenuPin => 'Épingler';

  @override
  String get chatMenuDelete => 'Supprimer';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get diagnostics => 'Diagnostic';

  @override
  String get diagnosticsSubtitle => 'État, liaison, horodatages';

  @override
  String get sendLater => 'Envoyer plus tard';

  @override
  String get sendSilently => 'Envoyer sans son';

  @override
  String scheduledSendToday(Object time) {
    return 'Envoyer aujourd’hui à $time';
  }

  @override
  String scheduledSendOn(Object date, Object time) {
    return 'Envoyer le $date à $time';
  }

  @override
  String get repeatNever => 'Jamais';

  @override
  String get repeat => 'Répéter';

  @override
  String get onboardingBackTooltip => 'Retour';

  @override
  String get onboardingWelcomeTitle => 'Bienvenue !';

  @override
  String get onboardingWelcomeSubtitle => 'Une messagerie nouvelle génération.\nConfidentialité totale. Sans compromis.';

  @override
  String get onboardingCreateAccount => 'Créer un nouveau compte';

  @override
  String get onboardingAlreadyHaveAccount => 'J’ai déjà un compte';

  @override
  String get onboardingFeatureE2eTitle => 'Chiffrement E2E';

  @override
  String get onboardingFeatureE2eBody => 'Les messages sont chiffrés sur votre appareil. Vous seul détenez les clés.';

  @override
  String get onboardingFeaturePrivacyTitle => 'Anonymat complet';

  @override
  String get onboardingFeaturePrivacyBody => 'Aucun numéro de téléphone. Aucun lien avec vos données personnelles.';

  @override
  String get onboardingFeatureRelayTitle => 'Sans intermédiaires';

  @override
  String get onboardingFeatureRelayBody => 'Le serveur relay ne stocke pas les messages. Il ne fait que les transmettre.';

  @override
  String get onboardingProfileTitle => 'Votre profil';

  @override
  String get onboardingProfileSubtitle => 'Comment les autres utilisateurs vous verront';

  @override
  String get onboardingProfileNameSection => 'Nom du profil';

  @override
  String get onboardingProfileNameHint => 'Votre nom ou pseudonyme';

  @override
  String get onboardingNotificationsSection => 'Notifications';

  @override
  String get onboardingMessageNotificationsTitle => 'Notifications de messages';

  @override
  String get onboardingMessageNotificationsSubtitle => 'Recevoir les notifications push de Secretly';

  @override
  String get onboardingIncomingCallsTitle => 'Appels entrants';

  @override
  String get onboardingIncomingCallsSubtitle => 'Accepter les appels des contacts';

  @override
  String get continueAction => 'Continuer';

  @override
  String get onboardingBackupSaveFailed => 'Impossible d’enregistrer les réglages de sauvegarde';

  @override
  String get backupPasswordRequirements => 'Utilisez au moins 8 caractères ASCII, une majuscule et un caractère spécial. Aucun espace au début ou à la fin.';

  @override
  String backupPasswordTooShort(Object minLength) {
    return 'Le mot de passe doit contenir au moins $minLength caractères.';
  }

  @override
  String backupPasswordTooLong(Object maxLength) {
    return 'Le mot de passe ne doit pas dépasser $maxLength caractères.';
  }

  @override
  String get backupPasswordNonAscii => 'Utilisez uniquement des lettres latines, des chiffres et des symboles ASCII.';

  @override
  String get backupPasswordOuterWhitespace => 'Supprimez les espaces au début ou à la fin du mot de passe.';

  @override
  String get backupPasswordMissingUppercase => 'Ajoutez au moins une lettre majuscule A-Z.';

  @override
  String get backupPasswordMissingSpecial => 'Ajoutez au moins un caractère spécial, comme !, # ou ?.';

  @override
  String get onboardingBackupPasswordTitle => 'Mot de passe de sauvegarde';

  @override
  String get onboardingPasswordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get onboardingBackupTitle => 'Sauvegardes';

  @override
  String get onboardingBackupSubtitle => 'Protégez vos conversations contre la perte de données.\nMême si vous changez d’appareil.';

  @override
  String get onboardingAutoBackupSection => 'Sauvegarde automatique';

  @override
  String get onboardingAutoBackupTitle => 'Sauvegarde auto';

  @override
  String get onboardingAutoBackupSubtitle => 'Enregistrer automatiquement une sauvegarde';

  @override
  String get onboardingStorageTypeSection => 'Type de stockage';

  @override
  String get onboardingBackupMediaTitle => 'Sauvegarder les médias';

  @override
  String get onboardingBackupMediaSubtitle => 'Les photos, vidéos, fichiers et avatars ne sont inclus que dans les sauvegardes locales';

  @override
  String get onboardingFrequencySection => 'Fréquence';

  @override
  String get onboardingEnterSecretly => 'Entrer dans Secretly';

  @override
  String get onboardingSkipBackup => 'Ignorer la configuration de sauvegarde';

  @override
  String get onboardingSecretlyIdCopied => 'Secretly ID copié';

  @override
  String get onboardingRegistrationCompleteTitle => 'Inscription terminée';

  @override
  String get onboardingRegistrationCompleteSubtitle => 'Enregistrez maintenant votre Secretly ID. Il sera nécessaire pour restaurer votre compte et votre sauvegarde sur un nouvel appareil.';

  @override
  String get onboardingYourSecretlyId => 'Votre Secretly ID';

  @override
  String get onboardingCopyId => 'Copier l’ID';

  @override
  String get onboardingRecoveryWarning => 'Sans votre Secretly ID et le mot de passe de sauvegarde, la restauration de la sauvegarde serveur sera impossible. Enregistrez l’ID dans un endroit sûr et n’oubliez pas le mot de passe.';

  @override
  String get onboardingStorageCloud => 'Cloud';

  @override
  String get onboardingStorageCloudSubtitle => 'Sur le serveur Secretly';

  @override
  String get onboardingStorageLocal => 'Local';

  @override
  String get onboardingStorageLocalSubtitle => 'Sur cet appareil';

  @override
  String get onboardingInterval6Hours => '6 heures';

  @override
  String get onboardingInterval12Hours => '12 heures';

  @override
  String get onboardingIntervalEveryDay => 'Tous les jours';

  @override
  String get onboardingIntervalEvery3Days => 'Tous les 3 jours';

  @override
  String get onboardingIntervalWeekly => 'Une fois par semaine';

  @override
  String get onboardingBackupLocalCandidate => 'Sauvegarde locale Secretly';

  @override
  String get onboardingDownloads => 'Téléchargements';

  @override
  String get onboardingDeviceFolder => 'Dossier de l’appareil';

  @override
  String get onboardingNoBackupsFound => 'Aucune sauvegarde trouvée sur cet appareil';

  @override
  String get onboardingFoundBackups => 'Sauvegardes trouvées';

  @override
  String get onboardingNoBackupsFoundBody => 'Secretly a vérifié les sauvegardes locales de l’application et le dossier Téléchargements. Si le fichier est ailleurs, choisissez-le manuellement.';

  @override
  String get chooseManually => 'Choisir manuellement';

  @override
  String get onboardingChooseBackupFileTitle => 'Choisir un fichier de sauvegarde Secretly';

  @override
  String get onboardingReadBackupFailed => 'Impossible de lire le fichier de sauvegarde';

  @override
  String get onboardingServerBackupNotFound => 'La sauvegarde est introuvable sur le serveur';

  @override
  String get onboardingRestoreThisBackupTitle => 'Restaurer cette sauvegarde ?';

  @override
  String get onboardingRestoreThisBackupBody => 'Les données locales actuelles de cet appareil seront remplacées.';

  @override
  String onboardingSecretlyIdSummary(Object profileId) {
    return 'Secretly ID : $profileId';
  }

  @override
  String onboardingContactsSummary(Object count) {
    return 'Contacts : $count';
  }

  @override
  String onboardingMessagesSummary(Object count) {
    return 'Messages : $count';
  }

  @override
  String onboardingChatsSummary(Object count) {
    return 'Chats : $count';
  }

  @override
  String onboardingMediaFilesSummary(Object count) {
    return 'Fichiers multimédias : $count';
  }

  @override
  String get onboardingBrokenBackup => 'Fichier de sauvegarde endommagé ou non valide';

  @override
  String get onboardingRestoreFailed => 'Échec de la restauration. Réessayez.';

  @override
  String get onboardingRestoreLoginTitle => 'Se connecter au compte';

  @override
  String get onboardingRestoreLoginSubtitle => 'Restaurez les conversations et les réglages\ndepuis une sauvegarde créée auparavant.';

  @override
  String get onboardingRestoreMediaSubtitle => 'Pour les futures sauvegardes locales : les photos, vidéos, fichiers et avatars seront ajoutés uniquement si cette option est activée.';

  @override
  String get onboardingRestoreFromCloudTitle => 'Depuis le cloud Secretly';

  @override
  String get onboardingRestoreFromCloudSubtitle => 'Saisissez votre Secretly ID et le mot de passe de sauvegarde ; les données seront téléchargées depuis le serveur';

  @override
  String get onboardingRestoreFromDeviceTitle => 'Trouver une sauvegarde sur cet appareil';

  @override
  String get onboardingRestoreFromDeviceSubtitle => 'Secretly vérifiera automatiquement les sauvegardes locales et Téléchargements';

  @override
  String get onboardingRestoring => 'Restauration...';

  @override
  String get onboardingRestoreFromServerTitle => 'Restaurer depuis le serveur';

  @override
  String get callRecordOutgoingVideoCall => 'Appel vidéo sortant';

  @override
  String get callRecordOutgoingCall => 'Appel sortant';

  @override
  String get callRecordIncomingVideoCall => 'Appel vidéo entrant';

  @override
  String get callRecordIncomingCall => 'Appel entrant';

  @override
  String get callRecordMissedCall => 'Appel manqué';

  @override
  String get callRecordDeclinedCall => 'Appel refusé';

  @override
  String get callRecordBusy => 'Occupé';

  @override
  String get callRecordFailed => 'Échec de l’appel';

  @override
  String get callRecordCanceled => 'Appel annulé';

  @override
  String get callRecordOngoing => 'Appel en cours';

  @override
  String get safeBackupInvalidBackup => 'Sauvegarde Secretly non valide';

  @override
  String get recoveryKitPrepareFailed => 'Impossible de préparer un Recovery Kit sur cet appareil.';

  @override
  String safeBackupPreviewProfileId(String profileId) {
    return 'ID Secretly : $profileId';
  }

  @override
  String safeBackupPreviewContacts(int count) {
    return 'Contacts : $count';
  }

  @override
  String safeBackupPreviewServer(String server) {
    return 'Serveur : $server';
  }

  @override
  String get safeBackupPreviewTitle => 'Aperçu de la sauvegarde :';

  @override
  String get safeBackupSavedToFiles => 'Sauvegarde enregistrée dans les fichiers Secretly';

  @override
  String get safeBackupExportCanceled => 'Exportation de la sauvegarde annulée';

  @override
  String safeBackupExportFailed(Object error) {
    return 'Échec de l’exportation de la sauvegarde : $error';
  }

  @override
  String get safeBackupCreateDialogTitle => 'Créer une sauvegarde';

  @override
  String get safeBackupServerDestination => 'Sauvegarde serveur';

  @override
  String get safeBackupLocalDestination => 'Sauvegarde locale';

  @override
  String get safeBackupRestoreDialogTitle => 'Restaurer une sauvegarde';

  @override
  String get safeBackupRestoreFromDevice => 'Restaurer depuis l’appareil';

  @override
  String get safeBackupDownloadsLocation => 'Téléchargements';

  @override
  String get safeBackupDeviceFolderLocation => 'Dossier de l’appareil';

  @override
  String get safeBackupChooseManualHint => 'Secretly a vérifié automatiquement les sauvegardes locales de l’application et le dossier Téléchargements. Si le fichier est ailleurs, vous pouvez le choisir manuellement.';

  @override
  String get safeBackupChooseManually => 'Choisir manuellement';

  @override
  String safeBackupReadFileFailed(Object error) {
    return 'Impossible de lire le fichier de sauvegarde : $error';
  }

  @override
  String get safeBackupFrequencyTitle => 'Fréquence d’enregistrement';

  @override
  String get saveAction => 'Enregistrer';

  @override
  String get safeBackupEnableAutoTitle => 'Activer la sauvegarde automatique';

  @override
  String get safeBackupEnableAutoSubtitle => 'S’exécute dans l’application quand vous êtes en ligne ; chiffré avec votre mot de passe';

  @override
  String get safeBackupUploadToServer => 'Envoyer au serveur';

  @override
  String get safeBackupSaveOnDevice => 'Enregistrer sur cet appareil';

  @override
  String get safeBackupPasswordConfigured => 'Mot de passe de sauvegarde automatique : configuré';

  @override
  String get safeBackupPasswordNotSet => 'Mot de passe de sauvegarde automatique : non défini';

  @override
  String get safeBackupPasswordSaved => 'Mot de passe de sauvegarde automatique enregistré';

  @override
  String genericFailed(Object error) {
    return 'Échec : $error';
  }

  @override
  String get safeBackupSetPassword => 'Définir le mot de passe';

  @override
  String get safeBackupPasswordRemoved => 'Mot de passe de sauvegarde automatique supprimé';

  @override
  String get safeBackupClearPassword => 'Effacer le mot de passe';

  @override
  String get safeBackupRunRequested => 'Sauvegarde automatique lancée';

  @override
  String get safeBackupRunNow => 'Lancer la sauvegarde automatique maintenant';

  @override
  String safeBackupLastAutoBackup(String time) {
    return 'Dernière sauvegarde automatique : $time';
  }

  @override
  String get safeBackupLastAutoBackupNever => 'Dernière sauvegarde automatique : jamais';

  @override
  String safeBackupLastDeviceBackup(String time) {
    return 'Dernière sauvegarde de l’appareil : $time';
  }

  @override
  String safeBackupLastAutoBackupError(Object error) {
    return 'Erreur de sauvegarde automatique : $error';
  }

  @override
  String get securityScopeAppObject => 'l’application';

  @override
  String get securityScopePersonalObject => 'les discussions personnelles';

  @override
  String get securityUnlockAppTitle => 'Déverrouiller l’application';

  @override
  String get securityUnlockPersonalTitle => 'Déverrouiller les discussions personnelles';

  @override
  String get securityUnlockFingerprintAutoSubtitle => 'Le déverrouillage par empreinte démarre automatiquement. Si besoin, utilisez votre mot de passe ci-dessous.';

  @override
  String get securityUnlockBiometricPatternAutoSubtitle => 'La biométrie native démarre d’abord automatiquement. Si besoin, utilisez votre schéma ci-dessous.';

  @override
  String get securityUnlockNativeSubtitle => 'Confirmez l’accès avec l’authentification native de l’appareil.';

  @override
  String securityUnlockPasswordSubtitle(String scopeName) {
    return 'Saisissez votre mot de passe pour ouvrir $scopeName.';
  }

  @override
  String securityUnlockPatternSubtitle(String scopeName) {
    return 'Tracez votre schéma pour accéder à $scopeName.';
  }

  @override
  String get securityUnlockBiometricSubtitle => 'Confirmez votre identité avec l’authentification native de l’appareil.';

  @override
  String get securityUnlockAppBiometricReason => 'Authentifiez-vous pour déverrouiller l’application';

  @override
  String get securityUnlockPersonalBiometricReason => 'Authentifiez-vous pour ouvrir les discussions personnelles';

  @override
  String get securityUnlockPasswordMismatch => 'Ce mot de passe ne correspond pas. Réessayez.';

  @override
  String get securityUnlockPatternMismatch => 'Ce schéma ne correspond pas.';

  @override
  String get securityUnlockNativeIncomplete => 'L’authentification native n’a pas été terminée.';

  @override
  String get securityPasswordContinueHint => 'Saisissez votre mot de passe pour continuer';

  @override
  String get securityUseFingerprint => 'Utiliser l’empreinte';

  @override
  String get securityUsePassword => 'Utiliser le mot de passe';

  @override
  String get securityClearPattern => 'Effacer le schéma';

  @override
  String get securityConnectFourDots => 'Reliez au moins 4 points.';

  @override
  String get securityPasswordMinFourChars => 'Utilisez au moins 4 caractères.';

  @override
  String get securityPasswordsMismatchFull => 'Les mots de passe ne correspondent pas.';

  @override
  String securityPasswordSetupTitle(String scopeName) {
    return 'Mot de passe pour $scopeName';
  }

  @override
  String get securityPasswordSetupDescription => 'Le mot de passe est stocké uniquement dans l’espace sécurisé de l’appareil.';

  @override
  String get securityNewPassword => 'Nouveau mot de passe';

  @override
  String get securityRepeatPassword => 'Répéter le mot de passe';

  @override
  String get securitySavePassword => 'Enregistrer le mot de passe';

  @override
  String get securityPatternSetupInstruction => 'Tracez un schéma avec au moins 4 points.';

  @override
  String get securityPatternSetupRepeat => 'Répétez le schéma pour le confirmer.';

  @override
  String get securityPatternMinFourDots => 'Utilisez au moins 4 points.';

  @override
  String get securityPatternMismatchStartOver => 'Les schémas ne correspondent pas. Recommencez.';

  @override
  String securityPatternSetupTitle(String scopeName) {
    return 'Schéma pour $scopeName';
  }

  @override
  String get securityStartOver => 'Recommencer';

  @override
  String get securityTitle => 'Sécurité';

  @override
  String get securityNativeAuthentication => 'Authentification native';

  @override
  String get securityReady => 'Prêt';

  @override
  String get securityUnavailable => 'Indisponible';

  @override
  String get securityNativeAvailableDescription => 'Utilisée pour Face ID, l’empreinte et l’authentification native de l’appareil.';

  @override
  String get securityNativeUnavailableDescription => 'La biométrie ou l’authentification native n’est pas disponible sur cet appareil pour le moment.';

  @override
  String get securityAppLockTitle => 'Verrouillage de l’app';

  @override
  String get securityAppLockDescription => 'Protège l’entrée dans l’app et peut reverrouiller quand l’app est masquée.';

  @override
  String get securityPersonalChatsTitle => 'Discussions personnelles';

  @override
  String get securityPersonalChatsDescription => 'Protège la section Personnelles masquée et l’accès direct aux discussions personnelles.';

  @override
  String get securityAuthEnableAppLockReason => 'Authentifiez-vous pour activer le verrouillage de l’app';

  @override
  String get securityAuthChangeSettingsReason => 'Authentifiez-vous pour modifier les paramètres de sécurité';

  @override
  String get securityAuthProtectPersonalReason => 'Authentifiez-vous pour protéger les discussions personnelles';

  @override
  String get securityAuthChangePersonalReason => 'Authentifiez-vous pour modifier la protection des discussions personnelles';

  @override
  String get securityNativeUnavailableError => 'L’authentification native n’est pas disponible sur cet appareil.';

  @override
  String get securityBiometricCancelled => 'La confirmation biométrique a été annulée.';

  @override
  String get securityProtectionMode => 'Mode de protection';

  @override
  String get securityProtectionModeSubtitle => 'Choisissez comment protéger l’accès.';

  @override
  String get securityProtectionModeDescription => 'Les mots de passe et schémas sont stockés uniquement sous forme de hachages forts dans secure storage. La biométrie utilise l’invite native du système.';

  @override
  String get securityProtectionOff => 'Désactivé';

  @override
  String get securityProtectionOffDescription => 'Accès sans protection supplémentaire.';

  @override
  String get securityPasswordModeDescription => 'Un mot de passe dédié pour déverrouiller l’accès.';

  @override
  String get securityPatternModeTitle => 'Schéma';

  @override
  String get securityPatternModeDescription => 'Un schéma de points similaire au verrouillage Android.';

  @override
  String get securityNativePromptDescription => 'L’invite native Face ID, empreinte ou authentification système de l’appareil.';

  @override
  String get securityRelockAfterHidden => 'Reverrouiller quand l’app est masquée';

  @override
  String get securityRelockAfterHiddenDescription => 'Si désactivé, la protection ne revient qu’après un redémarrage complet de l’app.';

  @override
  String get securityGracePeriod => 'Délai avant reverrouillage';

  @override
  String get securityGraceUnavailable => 'Indisponible quand le verrouillage en arrière-plan est désactivé.';

  @override
  String securityAllowQuickUnlockWith(String method) {
    return 'Autoriser le déverrouillage rapide avec $method';
  }

  @override
  String get securityQuickUnlockSubtitle => 'Conserve le mot de passe ou le schéma comme méthode principale de secours.';

  @override
  String get securityChangePassword => 'Changer le mot de passe';

  @override
  String get securityChangePattern => 'Changer le schéma';

  @override
  String get securityChangeCredentialSubtitle => 'La protection actuelle sera mise à jour dès confirmation du nouveau secret.';

  @override
  String get securityProtectionActivated => 'La protection a été activée immédiatement.';

  @override
  String get securityLockNow => 'Verrouiller maintenant';

  @override
  String get securitySaveChanges => 'Enregistrer';

  @override
  String get securityGraceImmediately => 'Immédiatement';

  @override
  String securityGraceAfterSeconds(int seconds) {
    return 'Après $seconds s';
  }

  @override
  String securityGraceAfterMinutes(int minutes) {
    return 'Après $minutes min';
  }

  @override
  String get securityStatusLocked => 'Verrouillé';

  @override
  String get securityStatusUnlocked => 'Déverrouillé';

  @override
  String get securityAfterHide => 'Après masquage';

  @override
  String securityGracePill(int seconds) {
    return 'Délai $seconds s';
  }

  @override
  String get securityNoProtection => 'Sans protection';

  @override
  String get securityNativeBiometrics => 'Biométrie native';

  @override
  String get securityBiometricFaceFingerprint => 'Face ID / empreinte';

  @override
  String get securityBiometricFingerprint => 'Empreinte';

  @override
  String get securityBiometricNativeDeviceAuthentication => 'Authentification native de l’appareil';

  @override
  String get devicesLinkOpenFailed => 'Impossible d’ouvrir le lien dans un navigateur.';

  @override
  String get devicesDesktopDescriptionPrefix => 'Vous pouvez vous connecter à l’';

  @override
  String get devicesDesktopAppLink => 'application Secretly desktop';

  @override
  String get devicesDesktopDescriptionSuffix => ' avec un code QR.';

  @override
  String get devicesFailureTransportBlocked => 'Le transport est bloqué pour le serveur actuel. Mettez le téléphone et le desktop sur le même serveur, puis réessayez.';

  @override
  String get devicesFailureIdentityNotServerBacked => 'L’identité desktop n’est pas encore enregistrée sur le serveur. Réessayez dans quelques secondes.';

  @override
  String get devicesFailureProfileUnavailable => 'Le profil desktop n’est pas encore visible sur le serveur. Gardez l’app ouverte et réessayez.';

  @override
  String get devicesFailureDeviceUnavailable => 'L’appareil desktop n’est pas encore visible sur le serveur. Gardez l’app ouverte, actualisez le QR et réessayez.';

  @override
  String get devicesFailureCompanionRequired => 'L’accès companion desktop n’est pas activé pour ce profil. Activez-le sur le téléphone principal et réessayez.';

  @override
  String get devicesFailureCompanionLimit => 'La limite d’appareils desktop est déjà utilisée pour ce profil. Supprimez un ancien appareil desktop ou augmentez les places disponibles.';

  @override
  String get devicesFailurePrimaryRequired => 'Créez d’abord le compte principal sur un téléphone, puis liez le desktop avec QR.';

  @override
  String get devicesFailureInvalidQr => 'Ce QR n’est pas un code d’autorisation d’appareil.';

  @override
  String get devicesFailureQrExpired => 'Le code QR a expiré. Générez-en un nouveau sur le desktop.';

  @override
  String get devicesFailureServerMismatch => 'Ce QR appartient à un autre serveur. Mettez le téléphone et le desktop sur le même serveur, puis réessayez.';

  @override
  String get devicesFailureProfileMismatch => 'Le paquet de synchronisation cible un autre profil. Générez un nouveau QR et réessayez.';

  @override
  String get devicesFailureRequestNotFound => 'La demande de synchronisation desktop est introuvable ou a déjà expiré. Générez un nouveau QR.';

  @override
  String get devicesFailureSessionExpired => 'La session QR a expiré. Générez un nouveau QR et réessayez.';

  @override
  String get devicesFailureSessionValidation => 'La validation de la session QR a échoué. Générez un nouveau QR et réessayez.';

  @override
  String get devicesFailureStateMismatch => 'L’état de la demande de synchronisation ne correspond plus. Générez un nouveau QR et réessayez.';

  @override
  String get devicesFailureDeviceMismatch => 'Le paquet de synchronisation cible un autre appareil. Générez un nouveau QR et réessayez.';

  @override
  String get devicesFailureDeclined => 'La connexion a été refusée sur le téléphone principal. Générez un nouveau QR pour réessayer.';

  @override
  String get devicesFailureInvalidPayload => 'Paquet de synchronisation desktop invalide. Générez un nouveau QR et réessayez.';

  @override
  String get devicesFailureInterrupted => 'La synchronisation sécurisée a été interrompue avant la fin. Générez un nouveau QR et réessayez.';

  @override
  String get devicesNewUser => 'Nouvel utilisateur';

  @override
  String get devicesNewUserDesktopConfirm => 'Effacer les données locales et préparer cet appareil desktop pour une connexion QR depuis le téléphone principal ?';

  @override
  String get devicesNewUserMobileConfirm => 'Effacer le profil local actuel et enregistrer un nouvel utilisateur sur cet appareil ?';

  @override
  String get devicesCreateAction => 'Créer';

  @override
  String get devicesScanDeviceQr => 'Scanner le QR de l’appareil';

  @override
  String get devicesRequestApproved => 'Demande approuvée. Paquet de synchronisation envoyé au desktop.';

  @override
  String get devicesRequestDeclined => 'Demande refusée. Le desktop reste non authentifié.';

  @override
  String get devicesApproveSignInTitle => 'Approuver la connexion sur cet appareil ?';

  @override
  String get devicesConfirmSyncPrimary => 'Confirmez la synchronisation depuis l’appareil principal (téléphone).';

  @override
  String devicesApprovalDeviceOnly(String name) {
    return 'Appareil : $name. L’approbation est autorisée uniquement depuis le téléphone principal.';
  }

  @override
  String get devicesSyncChats => 'Synchroniser les discussions';

  @override
  String get devicesSyncSettings => 'Synchroniser les réglages';

  @override
  String get devicesSyncMedia => 'Synchroniser les médias';

  @override
  String get devicesDeclineSignIn => 'Refuser la connexion';

  @override
  String get devicesApprove => 'Approuver';

  @override
  String get devicesTitle => 'Appareils';

  @override
  String get devicesConnectDevice => 'Connecter un appareil';

  @override
  String get devicesPrimaryDeviceTitle => 'Ceci est l’appareil principal';

  @override
  String get devicesPrimaryDeviceSubtitle => 'L’autorisation de synchroniser discussions, réglages et médias est accordée uniquement ici.';

  @override
  String get devicesQrSessionExpiredNewCode => 'La session QR a expiré. Générez un nouveau code.';

  @override
  String devicesQrExpiresIn(String time) {
    return 'Le QR expire dans $time';
  }

  @override
  String get devicesWaitingQrScan => 'En attente du scan QR sur le téléphone.';

  @override
  String get devicesQrScannedConfirm => 'QR scanné. Confirmez la connexion sur le téléphone.';

  @override
  String get devicesApplyingSecureBundle => 'Application du paquet de synchronisation sécurisé…';

  @override
  String get devicesAuthorizationFailed => 'Échec de l’autorisation. Réessayez.';

  @override
  String get devicesUnauthenticatedChooseAction => 'Vous n’êtes pas authentifié. Choisissez une action ci-dessous.';

  @override
  String get devicesAuthenticated => 'Appareil authentifié.';

  @override
  String get devicesDesktopWebAuthorization => 'Autorisation Desktop/Web';

  @override
  String get devicesDesktopModeDescription => 'Choisissez le mode : enregistrer un nouvel utilisateur ou se connecter par QR avec validation sur le téléphone.';

  @override
  String get devicesCancelQr => 'Annuler le QR';

  @override
  String get devicesRefreshQr => 'Actualiser le QR';

  @override
  String get devicesSignInViaQr => 'Connexion par QR';

  @override
  String get devicesOpenPrimaryInstruction => 'Ouvrez Secretly sur le téléphone principal → Réglages → Appareils → Connecter un appareil.';

  @override
  String get storageSection => 'Stockage';

  @override
  String get storageSectionSubtitle => 'Cache et téléchargements sur cet appareil';

  @override
  String get storageUsageTitle => 'Utilisation du stockage';

  @override
  String get storageCategoryMedia => 'Cache des médias';

  @override
  String get storageCategoryVoiceTranscripts => 'Transcriptions vocales';

  @override
  String get storageCategoryVoiceModel => 'Modèle vocal hors ligne';

  @override
  String get storageCategoryStickers => 'Stickers';

  @override
  String get storageCategoryEmoji => 'Émojis animés';

  @override
  String get storageCategoryProfileMedia => 'Ma galerie et mes avatars';

  @override
  String get storageCategoryRecents => 'Fichiers récents';

  @override
  String get storageTotal => 'Total';

  @override
  String get storageCalculating => 'Calcul en cours…';

  @override
  String get storageClearCache => 'Vider le cache';

  @override
  String get storageClearCacheHint => 'Supprime les médias en cache, les avatars des contacts et les émojis animés. Votre galerie, vos stickers et vos discussions sont conservés ; les médias se retéléchargent à l’affichage.';

  @override
  String get storageClearing => 'Vidage du cache…';

  @override
  String get storageClearedToast => 'Cache vidé';

  @override
  String get storageRemoveVoiceModel => 'Supprimer le modèle vocal hors ligne (140 Mo)';

  @override
  String get storageRemoveVoiceModelHint => 'Libère le modèle de reconnaissance vocale sur l’appareil. Il se retélécharge automatiquement la prochaine fois que vous transcrivez un message vocal.';

  @override
  String get storageRemoveVoiceModelConfirmTitle => 'Supprimer le modèle vocal ?';

  @override
  String get storageRemoveVoiceModelConfirmBody => 'Le modèle de reconnaissance vocale de 140 Mo sera supprimé de l’appareil. Il se retélécharge automatiquement la prochaine fois que vous transcrivez un message vocal.';

  @override
  String get storageRemoveVoiceModelConfirm => 'Supprimer';

  @override
  String get storageVoiceModelNotInstalled => 'Aucun modèle vocal n’est installé';

  @override
  String get storageVoiceModelRemovedToast => 'Modèle vocal supprimé';

  @override
  String get backupStateProtected => 'Votre historique est protégé';

  @override
  String get backupStateUnprotected => 'Votre historique n\'est pas protégé';

  @override
  String get backupStateFailing => 'Les sauvegardes échouent';

  @override
  String get backupStateStale => 'La sauvegarde est obsolète';

  @override
  String get backupStateNone => 'Aucune sauvegarde';

  @override
  String backupLastAt(Object time) {
    return 'Dernière sauvegarde : $time';
  }

  @override
  String get backupIntroHint => 'Une sauvegarde vous permet de retrouver vos discussions sur un nouvel appareil';

  @override
  String get backupAccessUpgradeTitle => 'Enregistrez à nouveau la sauvegarde';

  @override
  String get backupAccessUpgradeBody => 'Votre sauvegarde sur le serveur a été créée dans l\'ancien format : elle peut être téléchargée par qui connaît l\'identifiant de profil. Le contenu reste chiffré avec votre mot de passe, mais une seconde barrière ne nuit pas. La réenregistrer ajoute une vérification du mot de passe sur le serveur.';

  @override
  String get backupAccessUpgradeAction => 'Réenregistrer';

  @override
  String get backupSectionAutomatic => 'Automatique';

  @override
  String get backupAutoToggle => 'Sauvegarder automatiquement';

  @override
  String get backupPassword => 'Mot de passe';

  @override
  String get backupPasswordSet => 'Défini';

  @override
  String get backupPasswordNotSet => 'Non défini';

  @override
  String get backupPasswordSaved => 'Mot de passe enregistré';

  @override
  String get backupWhere => 'Où';

  @override
  String get backupHowOften => 'Fréquence';

  @override
  String get backupIncludeMedia => 'Inclure les médias';

  @override
  String get backupAutoFooter => 'La sauvegarde est chiffrée avec votre mot de passe. Sans lui, rien ne peut être restauré — conservez-le en lieu sûr. Les médias ne sont jamais envoyés au serveur.';

  @override
  String get backupNow => 'Sauvegarder maintenant';

  @override
  String get backupSectionRestore => 'Restauration';

  @override
  String get backupRestoreAction => 'Restaurer depuis une sauvegarde';

  @override
  String get backupRestoreFooter => 'Remplace les discussions et les réglages de cet appareil par le contenu de la sauvegarde.';

  @override
  String get backupSectionKey => 'Clé Secretly ID';

  @override
  String get backupKeyShow => 'Afficher la clé';

  @override
  String get backupKeyRestore => 'Restaurer avec une clé';

  @override
  String get backupKeyFooter => 'Restaure uniquement votre Secretly ID — la clé ne contient aucune discussion. La restauration avec une clé efface les données locales.';

  @override
  String get backupDestServerDevice => 'Serveur et appareil';

  @override
  String get backupDestServer => 'Serveur';

  @override
  String get backupDestDevice => 'Appareil';

  @override
  String get backupDestNone => 'Non défini';

  @override
  String get backupDestServerOnly => 'Serveur uniquement';

  @override
  String get backupDestDeviceOnly => 'Appareil uniquement';

  @override
  String get backupTileOff => 'Désactivé — votre historique n\'est pas protégé';

  @override
  String get backupTilePending => 'Activé, mais jamais exécuté';

  @override
  String get backupTileFailing => 'Ne s\'exécute pas — à vérifier';

  @override
  String get backupTileStale => 'Pas mis à jour depuis un moment';

  @override
  String get backupPasswordChange => 'Modifier le mot de passe';

  @override
  String get backupPasswordRemove => 'Supprimer le mot de passe';

  @override
  String get chatUndecryptablePending => 'Un message est arrivé mais n\'est pas encore lisible — restauration de la session sécurisée…';

  @override
  String get liquidGlassTitle => 'Verre liquide';

  @override
  String get liquidGlassSubtitle => 'Barres et îlots réfractants. Désactivez pour le matériau simple : moins d\'énergie, moins de chauffe.';

  @override
  String get billingPendingTitle => 'En attente du paiement';

  @override
  String get billingPendingBody => 'La commande est créée mais le paiement n\'est pas encore confirmé. Terminez le paiement avec le moyen choisi — Premium s\'activera tout seul.';

  @override
  String get callsHideAddressTitle => 'Masquer mon adresse pendant les appels';

  @override
  String get callsHideAddressSubtitle => 'Via notre serveur : votre correspondant ne verra pas votre adresse IP, mais le délai peut augmenter';

  @override
  String get desktopJoinRoomByLink => 'Rejoindre via un lien';

  @override
  String get desktopJoinRoomLinkHint => 'Collez le lien d\'invitation';

  @override
  String get desktopJoinRoomLinkInvalid => 'Ce lien n\'est pas une invitation à un salon';

  @override
  String get desktopOfflineLockTitle => 'Demander le mot de passe après une longue absence de connexion';

  @override
  String get desktopOfflineLockDescription => 'Si cet ordinateur n\'a pas joint le serveur pendant plus longtemps que ce délai, il demande le mot de passe au démarrage. Un ordinateur perdu ne reçoit jamais la déconnexion à distance, mais il atteint ce délai.';

  @override
  String get desktopOfflineLockNever => 'Jamais';

  @override
  String get desktopOfflineLockDays7 => '7 jours';

  @override
  String get desktopOfflineLockDays14 => '14 jours';

  @override
  String get desktopOfflineLockDays30 => '30 jours';

  @override
  String get desktopPollTitle => 'Sondage';

  @override
  String get desktopPollAnonymous => 'Sondage anonyme';

  @override
  String get desktopPollClosed => 'Terminé';

  @override
  String desktopPollVoters(Object count) {
    return 'Ont voté : $count';
  }

  @override
  String get desktopPollMultipleHint => 'Vous pouvez en choisir plusieurs';

  @override
  String get desktopPollCloseAction => 'Terminer le sondage';

  @override
  String get desktopEventTitle => 'Événement';

  @override
  String get desktopEventGoing => 'Je viens';

  @override
  String get desktopEventMaybe => 'Peut-être';

  @override
  String get desktopEventNo => 'Je ne viens pas';

  @override
  String get desktopPollNewTitle => 'Nouveau sondage';

  @override
  String get desktopPollQuestionHint => 'Question';

  @override
  String desktopPollOptionHint(Object index) {
    return 'Choix $index';
  }

  @override
  String get desktopPollAddOption => 'Ajouter un choix';

  @override
  String get desktopPollCreateAction => 'Créer';

  @override
  String get desktopPollNeedTwo => 'Il faut une question et au moins deux choix';

  @override
  String get desktopPollMultipleLabel => 'Plusieurs réponses';

  @override
  String get desktopPollAnonymousLabel => 'Anonyme';

  @override
  String get desktopEventNewTitle => 'Nouvel événement';

  @override
  String get desktopEventTitleHint => 'Titre';

  @override
  String get desktopEventDescriptionHint => 'Description';

  @override
  String get desktopEventLocationHint => 'Lieu';

  @override
  String get desktopEventPickWhen => 'Choisir la date et l’heure';

  @override
  String get desktopEventNeedTitleAndDate => 'Il faut un titre et une date';

  @override
  String get desktopViewerOpenExternally => 'Ouvrir dans une autre app';

  @override
  String get desktopViewerSaveAs => 'Enregistrer sous…';

  @override
  String desktopViewerPage(Object page, Object total) {
    return 'Page $page sur $total';
  }

  @override
  String get desktopViewerFailed => 'Impossible d’afficher ce fichier';

  @override
  String get desktopViewerTooLarge => 'Ce fichier est trop grand pour être affiché ici';

  @override
  String get desktopSupportAttach => 'Joindre un fichier';

  @override
  String desktopSupportAttachHint(Object limit) {
    return 'Une capture d\'écran ou un fichier journal — jusqu\'à $limit. La pièce jointe est chiffrée avec le message.';
  }

  @override
  String desktopSupportTooLarge(Object limit) {
    return 'Le fichier dépasse $limit et ne peut pas être envoyé';
  }

  @override
  String get desktopSupportUnreadable => 'Impossible de lire le fichier';

  @override
  String get desktopSupportRemoveAttachment => 'Retirer la pièce jointe';

  @override
  String desktopSupportMegabytes(Object value) {
    return '$value Mo';
  }

  @override
  String get desktopSupportYou => 'Vous';

  @override
  String get desktopSupportShrunk => 'L\'image a été réduite pour tenir';

  @override
  String get desktopStickerPackTitle => 'Pack d\'autocollants';

  @override
  String get desktopStickerPackAddPlain => 'Ajouter le pack';

  @override
  String get desktopStickerPackInstalled => 'Installé';

  @override
  String get desktopStickerPackInstalling => 'Installation…';

  @override
  String get desktopStickerPackOwn => 'Ceci est votre propre pack';

  @override
  String get desktopStickerPackNoAuthor => 'L\'auteur du pack est inconnu — ouvrez le même autocollant dans une conversation privée';

  @override
  String desktopStickerPackInstallingProgress(Object done, Object total) {
    return 'Installation… $done/$total';
  }

  @override
  String desktopStickerPackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autocollants',
      one: '$count autocollant',
    );
    return '$_temp0';
  }

  @override
  String desktopStickerPackAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter $count autocollants',
      one: 'Ajouter $count autocollant',
    );
    return '$_temp0';
  }

  @override
  String get desktopPairingTitle => 'Connectez Secretly Desktop';

  @override
  String get desktopPairingHowTo => 'Sur votre téléphone, ouvrez Secretly → Réglages → Appareils → « Associer un appareil » et scannez ce code QR.';

  @override
  String get desktopPairingPreparingQr => 'Préparation du QR…';

  @override
  String get desktopPairingQrUnavailable => 'QR indisponible';

  @override
  String get desktopPairingCodeExpired => 'Le code a expiré — actualisation…';

  @override
  String desktopPairingCodeValidFor(Object time) {
    return 'Le code est encore valable $time';
  }

  @override
  String get desktopPairingPrepareFailed => 'Impossible de préparer le code. Vérifiez votre connexion internet et réessayez.';

  @override
  String get desktopPairingRevoked => 'Cet appareil a été retiré du compte, aucun code ne peut donc être créé.\nReconnectez l’ordinateur — il recevra une nouvelle identité d’appareil, et l’ancienne restera révoquée. Seule une confirmation depuis le téléphone donne accès aux conversations.';

  @override
  String get desktopPairingPreparingNew => 'Préparation d’une nouvelle connexion…';

  @override
  String get desktopPairingConnectAsNew => 'Connecter comme nouvel appareil';

  @override
  String get desktopPairingIdentityResetFailed => 'Impossible de recréer l’identité de l’appareil. Redémarrez l’application et réessayez.';

  @override
  String get desktopPairingWaitingConfirm => 'En attente de confirmation…';

  @override
  String get desktopPairingNewQr => 'Générer un nouveau QR';

  @override
  String get desktopPairingCreatingRequest => 'Création de la demande…';

  @override
  String get desktopPairingReadyToScan => 'Prêt à scanner';

  @override
  String get desktopPairingWaitingScan => 'En attente du scan sur le téléphone…';

  @override
  String get desktopPairingScannedConfirmOnPhone => 'QR scanné — confirmez sur le téléphone.';

  @override
  String get desktopPairingFetchingProfile => 'Récupération du profil et des clés…';

  @override
  String get desktopPairingConnectedLoading => 'Connecté. Chargement…';

  @override
  String get desktopPairingConnectionError => 'Erreur de connexion. Réessayez.';

  @override
  String get desktopMenuReaction => 'Réaction';

  @override
  String get desktopMenuContinueInTopic => 'Continuer dans un sujet';

  @override
  String get desktopMenuCopySelection => 'Copier la sélection';

  @override
  String get desktopMenuCopyText => 'Copier le texte';

  @override
  String get desktopMenuCopyLink => 'Copier le lien';

  @override
  String get desktopMenuTranslate => 'Traduire';

  @override
  String get desktopMenuHideTranslation => 'Masquer la traduction';

  @override
  String get desktopMenuSelect => 'Sélectionner';

  @override
  String get desktopMenuPhotoOrVideo => 'Photo ou vidéo';

  @override
  String get desktopMenuContact => 'Contact';

  @override
  String get desktopMenuLocation => 'Position';

  @override
  String get desktopListPinned => 'ÉPINGLÉS';

  @override
  String get desktopListToday => 'AUJOURD\'HUI';

  @override
  String get desktopListYesterday => 'HIER';

  @override
  String get desktopListThisWeek => 'CETTE SEMAINE';

  @override
  String get desktopListEarlier => 'PLUS TÔT';

  @override
  String get desktopListNothingFound => 'Aucun résultat';

  @override
  String get desktopListAddFavourite => 'Ajouter aux favoris';

  @override
  String get desktopListRemoveFavourite => 'Retirer des favoris';

  @override
  String get desktopListMute => 'Mettre en sourdine';

  @override
  String get desktopListMarkRead => 'Marquer comme lu';

  @override
  String get desktopListArchive => 'Archiver';

  @override
  String get desktopListFolders => 'Dossiers';

  @override
  String get desktopListCreate => 'Créer';

  @override
  String get desktopListTyping => 'écrit';

  @override
  String get desktopListDraftPrefix => 'Brouillon : ';

  @override
  String desktopListDiscussion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Discussion · $count participants',
      one: 'Discussion · $count participant',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallServerSilent => 'Le serveur n’a pas répondu. Réessayez ou quittez l’appel.';

  @override
  String get desktopCallRoomMissing => 'Le salon n’est pas disponible sur le serveur — impossible d’y démarrer un appel.';

  @override
  String get desktopCallNoServer => 'Pas de connexion au serveur. Vérifiez votre connexion.';

  @override
  String get desktopCallJoinFailed => 'Impossible de rejoindre l’appel. Vérifiez la connexion et réessayez.';

  @override
  String desktopCallSharingScreen(Object name) {
    return '$name partage son écran';
  }

  @override
  String get desktopCallRoomEmpty => 'Rien n’a encore été écrit dans le salon';

  @override
  String get desktopCallMessageHint => 'Message au salon…';

  @override
  String get desktopCallSendToRoom => 'Envoyer au salon';

  @override
  String desktopCallParticipantsTab(Object count) {
    return 'Participants · $count';
  }

  @override
  String get desktopCallNotesTab => 'Notes';

  @override
  String get desktopCallLinkCopied => 'Lien copié';

  @override
  String get desktopCallFailed => 'Échec';

  @override
  String desktopCallFailedWith(Object error) {
    return 'Échec : $error';
  }

  @override
  String get desktopCallMicOn => 'Activer le micro';

  @override
  String get desktopCallMicOff => 'Couper le micro';

  @override
  String get desktopCallCamOn => 'Activer la caméra';

  @override
  String get desktopCallCamOff => 'Couper la caméra';

  @override
  String get desktopCallNoMediaVideo => 'Le serveur n’a pas fourni de canal média — la vidéo est indisponible';

  @override
  String get desktopCallLayoutSingle => 'Un seul';

  @override
  String get desktopCallLayoutGrid => 'Grille';

  @override
  String get desktopCallShowOneLarge => 'Afficher une personne en grand';

  @override
  String get desktopCallShowGrid => 'Afficher tout le monde en grille';

  @override
  String get desktopCallScreen => 'Écran';

  @override
  String get desktopCallShareStop => 'Arrêter le partage d’écran';

  @override
  String get desktopCallShareStart => 'Partager l’écran';

  @override
  String get desktopCallNoMediaScreen => 'Le serveur n’a pas fourni de canal média — le partage d’écran est indisponible';

  @override
  String get desktopCallLeave => 'Quitter';

  @override
  String get desktopCallLeaveCall => 'Quitter l’appel';

  @override
  String get desktopCallNoMediaBoth => 'Le serveur n’a pas fourni de canal média : cet appel n’aura ni son ni vidéo';

  @override
  String get desktopCallMinimise => 'Réduire l’appel';

  @override
  String get desktopCallDiscussion => 'Discussion';

  @override
  String desktopCallDiscussionOf(Object title) {
    return 'Discussion · $title';
  }

  @override
  String get desktopCallEncrypted => 'L’appel est chiffré de bout en bout';

  @override
  String desktopCallDurationOnAir(Object duration, Object count) {
    return '$duration · $count en direct';
  }

  @override
  String get desktopCallExitFullScreen => 'Quitter le plein écran';

  @override
  String get desktopCallFullScreen => 'Plein écran';

  @override
  String get desktopCallDemoRoom => 'Salon de démonstration';

  @override
  String get desktopCallNoCallYet => 'Pas encore d’appel';

  @override
  String get desktopCallDemoExplain => 'Il n’existe que sur cet ordinateur et pas sur le serveur — impossible d’y démarrer un appel. Dans un vrai salon, le bouton fonctionne.';

  @override
  String get desktopCallStartHint => 'Démarrez — les autres verront l’invitation dans le salon';

  @override
  String get desktopCallVoiceOnly => 'Voix seule';

  @override
  String get desktopCallWithCamera => 'Avec caméra';

  @override
  String get desktopCallConnecting => 'Connexion…';

  @override
  String get desktopCallOngoing => 'Une discussion est en cours';

  @override
  String desktopCallOnAir(Object count) {
    return '$count en direct';
  }

  @override
  String get desktopCallJoin => 'Rejoindre';

  @override
  String get desktopCallFullScreenShort => 'Plein écran';

  @override
  String get desktopCallReconnecting => 'se reconnecte';

  @override
  String get desktopCallCannotHear => 'n’entend pas';

  @override
  String get desktopCallSharingShort => 'partage son écran';

  @override
  String get desktopCallCameraOn => 'caméra activée';

  @override
  String get desktopCallPickDevice => 'Choisir un appareil';

  @override
  String get desktopCallPreparingLink => 'Préparation du lien…';

  @override
  String get desktopCallInvite => 'Inviter';

  @override
  String desktopCallFps(Object fps) {
    return '$fps i/s';
  }

  @override
  String get desktopSettingsTitle => 'Réglages';

  @override
  String get desktopSettingsGroupApp => 'Application';

  @override
  String get desktopSettingsGroupPrivacy => 'Confidentialité et sécurité';

  @override
  String get desktopSettingsGroupAccount => 'Compte et données';

  @override
  String get desktopSettingsGeneralLabel => 'Général';

  @override
  String get desktopSettingsGeneralSubtitle => 'Langue, comportement de l’application';

  @override
  String get desktopSettingsGeneralKeywords => 'langue, locale, entrée, envoi, saisie';

  @override
  String get desktopSettingsAppearanceLabel => 'Apparence';

  @override
  String get desktopSettingsAppearanceSubtitle => 'Thème, accent, fond de conversation';

  @override
  String get desktopSettingsAppearanceKeywords => 'thème, accent, fond, bulles, couleur, sombre, coches, animation';

  @override
  String get desktopSettingsShortcutsLabel => 'Raccourcis clavier';

  @override
  String get desktopSettingsShortcutsSubtitle => 'Ce qu’il faut presser pour aller plus vite';

  @override
  String get desktopSettingsShortcutsKeywords => 'touches, raccourcis, rapide, cmd, ctrl';

  @override
  String get desktopSettingsPowerLabel => 'Consommation';

  @override
  String get desktopSettingsPowerSubtitle => 'Ce qui vide la batterie';

  @override
  String get desktopSettingsPowerKeywords => 'batterie, animation, cadres, verre, performance, chaleur';

  @override
  String get desktopSettingsNotificationsLabel => 'Notifications';

  @override
  String get desktopSettingsNotificationsSubtitle => 'Sons, aperçus, silence';

  @override
  String get desktopSettingsNotificationsKeywords => 'son, aperçu, silence, ne pas déranger, bannière, texte';

  @override
  String get desktopSettingsCallsLabel => 'Appels';

  @override
  String get desktopSettingsCallsSubtitle => 'Réception des appels et partage d’écran';

  @override
  String get desktopSettingsCallsKeywords => 'appels, entrants, partage d’écran, vidéo, audio';

  @override
  String get desktopSettingsMediaLabel => 'Son et vidéo';

  @override
  String get desktopSettingsMediaSubtitle => 'Caméra et micro pour les appels';

  @override
  String get desktopSettingsMediaKeywords => 'caméra, micro, appareil, webcam, casque, écouteurs, son, vidéo';

  @override
  String get desktopSettingsPrivacyLabel => 'Confidentialité';

  @override
  String get desktopSettingsPrivacySubtitle => 'Qui voit quoi de vous';

  @override
  String get desktopSettingsPrivacyKeywords => 'qui voit, dernière connexion, photo, appels, messages, transfert, pseudo, recherche, inconnus';

  @override
  String get desktopSettingsSecurityLabel => 'Sécurité';

  @override
  String get desktopSettingsSecuritySubtitle => 'Chiffrement et appareils vérifiés';

  @override
  String get desktopSettingsSecurityKeywords => 'chiffrement, e2ee, vérifiés, verrouillage, mot de passe, touch id, vérification';

  @override
  String get desktopSettingsBackupLabel => 'Sauvegarde';

  @override
  String get desktopSettingsBackupSubtitle => 'Ce qui sauvera votre historique';

  @override
  String get desktopSettingsBackupKeywords => 'sauvegarde, copie, restauration, safe backup, mot de passe, médias';

  @override
  String get desktopSettingsBlockedLabel => 'Bloqués';

  @override
  String get desktopSettingsBlockedSubtitle => 'Qui n’a pas accès à vous';

  @override
  String get desktopSettingsBlockedKeywords => 'blocage, bloqués, débloquer, liste noire, spam';

  @override
  String get desktopSettingsDevicesLabel => 'Sessions et appareils';

  @override
  String get desktopSettingsDevicesSubtitle => 'Sessions actives';

  @override
  String get desktopSettingsDevicesKeywords => 'appareils, sessions, qr, association, déconnexion, sauvegarde';

  @override
  String get desktopSettingsAccountLabel => 'Compte';

  @override
  String get desktopSettingsAccountSubtitle => 'Profil et déconnexion';

  @override
  String get desktopSettingsAccountKeywords => 'nom, à propos, id, déconnexion, réinitialiser';

  @override
  String get desktopSettingsStorageLabel => 'Stockage';

  @override
  String get desktopSettingsStorageSubtitle => 'Cache, téléchargements';

  @override
  String get desktopSettingsStorageKeywords => 'cache, espace, vider, médias, téléchargements';

  @override
  String get desktopSettingsSupportLabel => 'Assistance';

  @override
  String get desktopSettingsSupportSubtitle => 'Une conversation chiffrée avec nous';

  @override
  String get desktopSettingsSupportKeywords => 'assistance, aide, problème, bogue, écrire';

  @override
  String get desktopSettingsAboutLabel => 'À propos';

  @override
  String get desktopSettingsAboutKeywords => 'version, build, licences, site web';

  @override
  String get desktopSettingsDangerLabel => 'Supprimer le compte';

  @override
  String get desktopSettingsEndCallFirst => 'Terminez d’abord l’appel en cours.';

  @override
  String get desktopSettingsSignOutTitle => 'Se déconnecter du compte sur cet ordinateur ?';

  @override
  String get desktopSettingsSignOutBody => 'Les conversations, les clés et le cache seront supprimés de cet ordinateur. Le compte et l’historique sur le téléphone ne sont pas touchés — l’ordinateur peut être réassocié avec un code QR.';

  @override
  String get desktopSettingsSignOut => 'Se déconnecter';

  @override
  String desktopSettingsSignOutFailed(Object error) {
    return 'Impossible de se déconnecter : $error';
  }

  @override
  String get desktopSettingsActive => 'actif';

  @override
  String get desktopGeneralSystemLanguage => 'Système';

  @override
  String get desktopGeneralInterfaceLanguage => 'Langue de l’interface';

  @override
  String get desktopGeneralAppliesAtOnce => 'S’applique immédiatement';

  @override
  String get desktopGeneralBehaviour => 'Comportement';

  @override
  String get desktopGeneralEnterSends => 'Entrée envoie le message';

  @override
  String get desktopGeneralShiftEnterNewline => 'Maj+Entrée insère un saut de ligne';

  @override
  String get desktopGeneralEnterNewline => 'Entrée insère un saut de ligne, Maj+Entrée envoie';

  @override
  String get desktopGeneralHoverMenu => 'Menu au survol d’un message';

  @override
  String get desktopGeneralHoverMenuOn => 'Les réactions et les actions apparaissent au-dessus du message';

  @override
  String get desktopGeneralHoverMenuOff => 'Les actions sont sur le clic droit';

  @override
  String get desktopGeneralLinkPreviews => 'Aperçus de liens';

  @override
  String get desktopGeneralLinkPreviewsOn => 'La carte du lien part avec le message';

  @override
  String get desktopGeneralLinkPreviewsOff => 'Les liens partent sans carte, aucune page n’est ouverte';

  @override
  String get desktopPowerAnimations => 'Animations';

  @override
  String get desktopPowerAnimationsHint => 'Tout est activé par défaut. Désactivez de haut en bas si le portable chauffe ou si la batterie se vide.';

  @override
  String get desktopPowerFramesTitle => 'Animation des cadres et des statuts';

  @override
  String get desktopPowerFramesHint => 'Cadres d’avatar animés et statuts emoji des autres. La plus coûteuse des trois — désactivez-la en premier.';

  @override
  String get desktopPowerGlassBubbles => 'Bulles en verre';

  @override
  String get desktopPowerGlassBubblesHint => 'Flou derrière les messages reçus';

  @override
  String get desktopPowerMattePanels => 'Panneaux mats';

  @override
  String get desktopPowerMattePanelsHint => 'Flou des panneaux et des fenêtres surgissantes';

  @override
  String get desktopPowerNotAffectedTitle => 'Ce que cela ne touche pas';

  @override
  String get desktopPowerNotAffectedHint => 'La remise des messages, le chiffrement et les notifications fonctionnent de la même façon quelles que soient ces valeurs. Ces réglages ne touchent que l’affichage.';

  @override
  String get desktopNotifHidden => 'Masqué';

  @override
  String get desktopNotifSenderOnly => 'Expéditeur seulement';

  @override
  String get desktopNotifSenderAndText => 'Expéditeur et texte';

  @override
  String get desktopNotifUnavailableHere => 'Non disponible sur cette plateforme.';

  @override
  String get desktopNotifShowPreview => 'Afficher un aperçu du message';

  @override
  String get desktopNotifInSystem => 'Dans les notifications du système';

  @override
  String get desktopNotifDirectChats => 'Conversations privées';

  @override
  String get desktopNotifDirectChatsHint => 'Notifications des messages en tête-à-tête';

  @override
  String get desktopNotifRooms => 'Salons';

  @override
  String get desktopNotifRoomsHint => 'Notifications des messages dans les salons';

  @override
  String get desktopNotifSound => 'Son';

  @override
  String get desktopNotifDnd => 'Ne pas déranger';

  @override
  String get desktopNotifDndHint => 'Désactiver toutes les notifications';

  @override
  String get desktopWallAnimContinuous => 'En continu';

  @override
  String get desktopWallAnimOnEnter => 'À l’ouverture d’une conversation';

  @override
  String get desktopWallAnimTap => 'Au clic sur le fond';

  @override
  String get desktopWallAnimOff => 'Ne pas animer';

  @override
  String get desktopWallpaperNavy => 'Bleu nuit';

  @override
  String get desktopWallpaperGraphite => 'Graphite';

  @override
  String get desktopWallpaperTeal => 'Turquoise';

  @override
  String get desktopWallpaperPlum => 'Prune';

  @override
  String get desktopWallpaperWine => 'Vin';

  @override
  String get desktopWallpaperMint => 'Menthe';

  @override
  String get desktopWallpaperLavender => 'Lavande';

  @override
  String get desktopWallpaperSunset => 'Coucher de soleil';

  @override
  String get desktopWallpaperPeach => 'Pêche';

  @override
  String get desktopWallpaperSky => 'Ciel';

  @override
  String get desktopWallpaperMidnight => 'Minuit';

  @override
  String get desktopAppearanceTitle => 'Apparence';

  @override
  String get desktopAppearanceHint => 'Le schéma de cette fenêtre. Le téléphone a le sien — ce réglage ne voyage nulle part.';

  @override
  String get desktopAppearanceScheme => 'Schéma';

  @override
  String get desktopAppearanceSchemeHint => 'Sombre, clair ou selon le système';

  @override
  String get desktopAppearanceDark => 'Sombre';

  @override
  String get desktopAppearanceLight => 'Clair';

  @override
  String get desktopAppearanceAuto => 'Auto';

  @override
  String get desktopAppearanceAccent => 'Accent de l’interface';

  @override
  String get desktopAppearanceAccentHint => 'Boutons, vos bulles et les sélections dans toute l’application.';

  @override
  String get desktopAppearanceWallpaper => 'Fond de conversation';

  @override
  String get desktopAppearanceWallpaperHint => 'Le fond de conversation pour toutes les discussions.';

  @override
  String get desktopAppearanceLiveWallpaper => 'Fond animé';

  @override
  String get desktopAppearanceLiveWallpaperHint => 'Un motif au chatoiement doux. Le même ensemble que sur le téléphone.';

  @override
  String get desktopAppearanceAnimBehaviour => 'Comportement de l’animation';

  @override
  String get desktopAppearanceAnimBehaviourHint => 'Quand le motif s’anime.';

  @override
  String get desktopAppearanceWallPulse => 'Le fond accompagne le message';

  @override
  String get desktopAppearanceWallPulseHint => 'Une onde de lumière parcourt le motif : vers le haut à l’envoi, vers le bas à la réception.';

  @override
  String get desktopAppearanceEnable => 'Activer';

  @override
  String get desktopAppearanceLiveOnly => 'Ne fonctionne qu’avec le fond animé';

  @override
  String get desktopAppearanceBubbleStyle => 'Style des bulles de message';

  @override
  String get desktopAppearanceBubbleStyleHint => 'La couleur de vos messages envoyés dans toutes les conversations.';

  @override
  String get desktopAppearanceSenderColour => 'Couleur du nom de l’expéditeur';

  @override
  String get desktopAppearanceSenderColourHint => 'La couleur du pseudo de l’autre personne dans les groupes.';

  @override
  String get desktopAppearanceIndicatorColour => 'Couleur des indicateurs';

  @override
  String get desktopAppearanceIndicatorColourHint => 'Les coches de remise et le point de non-lu.';

  @override
  String get desktopAppearanceDemoMode => 'Mode démo';

  @override
  String get desktopAppearanceDemoHint => 'Les changements d’apparence seront conservés une fois un profil associé.';

  @override
  String get desktopAppearanceCurrentChoice => 'Choix actuel';

  @override
  String desktopAppearanceThemeIs(Object name) {
    return 'Thème : $name';
  }

  @override
  String get desktopBackupEvery6h => 'Toutes les 6 heures';

  @override
  String get desktopBackupEvery12h => 'Toutes les 12 heures';

  @override
  String get desktopBackupDaily => 'Une fois par jour';

  @override
  String get desktopBackupWeekly => 'Une fois par semaine';

  @override
  String get desktopBackupOffWarning => 'La sauvegarde automatique est désactivée — il n’y aura rien pour restaurer l’historique';

  @override
  String get desktopBackupNeverRan => 'Activée, mais jamais encore exécutée';

  @override
  String desktopBackupLastFailedWith(Object error) {
    return 'La dernière sauvegarde a échoué : $error';
  }

  @override
  String get desktopBackupLastFailed => 'La dernière sauvegarde a échoué';

  @override
  String get desktopBackupStale => 'La sauvegarde n’a pas été mise à jour depuis longtemps';

  @override
  String get desktopBackupFresh => 'La sauvegarde est à jour';

  @override
  String get desktopBackupState => 'État';

  @override
  String get desktopBackupAutomatic => 'Sauvegarde automatique';

  @override
  String get desktopBackupAutomaticHint => 'La sauvegarde est chiffrée avec votre mot de passe. Sans lui, ni nous ni personne ne peut la restaurer — il faut donc s’en souvenir.';

  @override
  String get desktopBackupCreateAuto => 'Créer automatiquement';

  @override
  String get desktopBackupUploadServer => 'Envoyer au serveur';

  @override
  String get desktopBackupUploadServerHint => 'Disponible depuis n’importe quel appareil';

  @override
  String get desktopBackupKeepLocal => 'Conserver sur cet ordinateur';

  @override
  String get desktopBackupKeepLocalHint => 'Ne dépend pas du réseau';

  @override
  String get desktopBackupIncludeMedia => 'Inclure les médias';

  @override
  String get desktopBackupIncludeMediaHint => 'La sauvegarde deviendra nettement plus grosse';

  @override
  String get desktopBackupFrequency => 'Fréquence';

  @override
  String get desktopBackupNowhereTitle => 'La sauvegarde n’est enregistrée nulle part';

  @override
  String get desktopBackupNowhereHint => 'La sauvegarde automatique est activée mais les deux destinations sont désactivées : aucune sauvegarde n’est donc créée. Activez le serveur ou cet ordinateur.';

  @override
  String get desktopBackupRecoveryKey => 'Clé de récupération';

  @override
  String get desktopBackupCreateRecoveryKey => 'Créer une clé de récupération';

  @override
  String get desktopBackupRecoveryKeyHint => 'Vous en aurez besoin s’il ne reste aucun appareil avec Secretly. Conservez-la séparément du mot de passe.';

  @override
  String desktopBackupKeyFailed(Object error) {
    return 'Impossible de créer la clé : $error';
  }

  @override
  String get desktopBackupKeyPassword => 'Mot de passe de la clé de récupération';

  @override
  String get desktopBackupPasswordsDiffer => 'Les mots de passe ne correspondent pas.';

  @override
  String get desktopBackupKeyPasswordHint => 'Ce mot de passe chiffre la clé elle-même. Il ne remplace pas celui de l’application et n’est stocké nulle part — il est irrécupérable.';

  @override
  String get desktopBackupPasswordAgain => 'Encore une fois';

  @override
  String desktopUnblockTitle(Object name) {
    return 'Débloquer $name ?';
  }

  @override
  String get desktopUnblockBody => 'Cette personne pourra de nouveau vous écrire et vous appeler.';

  @override
  String get desktopUnblockAction => 'Débloquer';

  @override
  String get desktopPrivacyLastSeen => 'Dernière connexion';

  @override
  String get desktopPrivacyProfilePhoto => 'Photos de profil';

  @override
  String get desktopPrivacyForwarding => 'Transfert de messages';

  @override
  String get desktopPrivacyCalls => 'Appels';

  @override
  String get desktopPrivacyVoice => 'Messages vocaux';

  @override
  String get desktopPrivacyMessages => 'Messages';

  @override
  String get desktopPrivacyNobody => 'Personne';

  @override
  String get desktopPrivacyEverybody => 'Tout le monde';

  @override
  String get desktopPrivacyContacts => 'Contacts';

  @override
  String get desktopPrivacyEncryption => 'Chiffrement';

  @override
  String get desktopPrivacyEncryptionHint => 'Tous les messages et appels sont chiffrés de bout en bout. Les clés ne se trouvent que sur vos appareils.';

  @override
  String get desktopPrivacyE2eeActive => 'Le chiffrement de bout en bout est actif';

  @override
  String get desktopPrivacyWhoSees => 'Qui voit';

  @override
  String get desktopPrivacyWhoSeesHint => 'Les mêmes réglages de visibilité que dans l’application mobile.';

  @override
  String get desktopPrivacyVisibility => 'Visibilité';

  @override
  String get desktopPrivacyByNickname => 'Visible par pseudo';

  @override
  String get desktopPrivacyByNicknameHint => 'Permettre qu’on vous trouve par votre pseudo';

  @override
  String get desktopPrivacySuggest => 'Suggérer des personnes dans la recherche';

  @override
  String get desktopPrivacyStrangers => 'Nouvelles conversations d’inconnus';

  @override
  String get desktopPrivacyStrangersHint => 'Dans les archives et sans notifications';

  @override
  String get desktopPrivacyAutoDelete => 'Supprimer mon compte';

  @override
  String get desktopPrivacyAutoDeleteHint => 'Si vous ne vous connectez pas pendant plus longtemps que la durée choisie, le compte et tous les messages sont supprimés automatiquement. Le compte à rebours repart à chaque connexion.';

  @override
  String get desktopPrivacyIfAbsent => 'Si je ne me connecte pas';

  @override
  String get desktopPrivacyIn1Month => 'Au bout d’1 mois';

  @override
  String get desktopPrivacyIn3Months => 'Au bout de 3 mois';

  @override
  String get desktopPrivacyIn6Months => 'Au bout de 6 mois';

  @override
  String get desktopPrivacyIn1Year => 'Au bout d’un an';

  @override
  String get desktopPrivacyIn2Years => 'Au bout de 2 ans';

  @override
  String get desktopLockImmediately => 'Dès la perte du focus';

  @override
  String desktopLockSeconds(Object value) {
    return '$value s';
  }

  @override
  String desktopLockMinutes(Object value) {
    return '$value min';
  }

  @override
  String desktopLockHours(Object value) {
    return '$value h';
  }

  @override
  String get desktopLockNoIdentityService => 'Le service de vérification d’identité est indisponible — le verrouillage n’a pas été activé.';

  @override
  String get desktopLockNotConfirmed => 'Le verrouillage n’a pas été activé : la confirmation a échoué.';

  @override
  String get desktopLockTitle => 'Verrouillage de l’application';

  @override
  String get desktopLockTouchIdHint => 'Demander Touch ID pour revenir après une perte de focus.';

  @override
  String get desktopLockPasswordHint => 'Demander le mot de passe de l’appareil pour revenir après une perte de focus.';

  @override
  String get desktopLockEnableTouchId => 'Activer Touch ID';

  @override
  String get desktopLockEnableLock => 'Activer le verrouillage';

  @override
  String get desktopLockDevicePassword => 'Mot de passe de l’appareil';

  @override
  String get desktopLockAfter => 'Verrouiller après';

  @override
  String get desktopLockNow => 'Verrouiller maintenant';

  @override
  String get desktopDevicesEndSessionTitle => 'Mettre fin à la session ?';

  @override
  String desktopDevicesEndSessionBody(Object id) {
    return 'L’appareil $id sera déconnecté de votre profil. Pour retrouver l’accès, il faudra scanner à nouveau le QR. Continuer ?';
  }

  @override
  String get desktopDevicesEnd => 'Terminer';

  @override
  String desktopDevicesEndFailed(Object error) {
    return 'Impossible de mettre fin à la session : $error';
  }

  @override
  String get desktopDevicesEnded => 'La session de l’appareil a pris fin.';

  @override
  String get desktopDevicesActiveSessions => 'Sessions actives';

  @override
  String get desktopDevicesDemoHint => 'Mode démo · les vrais appareils apparaîtront une fois un profil connecté';

  @override
  String get desktopDevicesThisComputer => 'macOS · Cet ordinateur';

  @override
  String get desktopDevicesDemoMac => 'MacBook Pro · Actif maintenant';

  @override
  String get desktopDevicesDemoIphone => 'iOS 18.2 · il y a 2 heures (démo)';

  @override
  String get desktopDevicesDemoIpad => 'iPadOS 18 · hier (démo)';

  @override
  String get desktopDevicesThisDevice => 'Cet appareil';

  @override
  String get desktopDevicesRemoteDevice => 'Appareil distant';

  @override
  String get desktopDevicesDisconnect => 'Déconnecter';

  @override
  String get desktopDevicesTitle => 'Appareils';

  @override
  String desktopDevicesTitleCount(Object count) {
    return 'Appareils · $count';
  }

  @override
  String get desktopDevicesHint => 'Les appareils associés à ce profil sur le serveur de clés.';

  @override
  String get desktopDevicesLoadFailed => 'Impossible de charger';

  @override
  String get desktopDevicesRetry => 'Réessayer';

  @override
  String get desktopDevicesNone => 'Aucun appareil trouvé';

  @override
  String get desktopDevicesNotLinked => 'Le profil n’est pas encore associé au serveur.';

  @override
  String get desktopDevicesRefresh => 'Actualiser la liste';

  @override
  String get desktopAccentCustom => 'Couleur personnalisée';

  @override
  String get desktopAccentCustomChange => 'Couleur personnalisée — modifier';

  @override
  String get desktopPairTitle => 'Associer un appareil';

  @override
  String get desktopPairHint => 'Affichez le code QR sur le nouvel appareil ou scannez-le depuis le téléphone';

  @override
  String get desktopPairRequestFailed => 'Impossible de créer la demande d’association';

  @override
  String get desktopPairCodeCopied => 'Le contenu du QR a été copié';

  @override
  String get desktopPairNewTitle => 'Associer un nouvel appareil';

  @override
  String get desktopPairNewHint => 'Sur le nouvel appareil, ouvrez Secretly et choisissez « Se connecter par QR ». Puis scannez le code ci-dessous.';

  @override
  String get desktopPairClose => 'Fermer';

  @override
  String get desktopPairCopyCode => 'Copier le code';

  @override
  String get desktopPairRefreshQr => 'Actualiser le QR';

  @override
  String desktopSyncPulled(Object count) {
    return 'Nouveaux événements récupérés : $count';
  }

  @override
  String get desktopSyncTooOften => 'Trop de demandes — réessayez plus tard';

  @override
  String get desktopSyncNothingNew => 'Terminé · aucun nouvel événement';

  @override
  String get desktopSyncDemoUnavailable => 'Indisponible en mode démo';

  @override
  String desktopSyncBlobsPulled(Object blobs, Object convos) {
    return 'Pièces jointes récupérées : $blobs (conversations : $convos)';
  }

  @override
  String desktopSyncNoBlobs(Object convos) {
    return 'Terminé · aucune nouvelle pièce jointe (conversations : $convos)';
  }

  @override
  String get desktopSyncTitle => 'Historique des autres appareils';

  @override
  String get desktopSyncHint => 'Demander au téléphone l’historique récent des conversations. Utile si l’ordinateur est resté hors ligne plus de 7 jours ou vient d’être associé par QR.';

  @override
  String get desktopSyncRunning => 'Synchronisation…';

  @override
  String get desktopSyncAskHistory => 'Demander l’historique';

  @override
  String get desktopSyncAsk => 'Demander';

  @override
  String get desktopSyncBlobsRunning => 'Téléchargement des pièces jointes…';

  @override
  String get desktopSyncBlobsAction => 'Récupérer les pièces jointes';

  @override
  String get desktopSyncBlobsHint => 'Télécharge les médias des conversations récentes quand les fichiers manquent en local (après une réassociation ou une longue absence).';

  @override
  String get desktopSyncBlobsShort => 'Récupérer';

  @override
  String desktopServerBackupOk(Object stamp, Object size, Object profile) {
    return 'Sauvegarde sur le serveur ✓ · $stamp · $size Ko · profil $profile';
  }

  @override
  String get desktopServerBackupPassword => 'Mot de passe de la sauvegarde';

  @override
  String get desktopServerBackupPasswordHint => 'Ce mot de passe chiffre la sauvegarde et permet de la restaurer sur n’importe quel appareil. Retenez-le — sans lui la sauvegarde est inutile et il est irrécupérable.';

  @override
  String get desktopServerBackupRepeat => 'Répétez le mot de passe';

  @override
  String get desktopServerBackupCreate => 'Créer la sauvegarde';

  @override
  String get desktopServerBackupTitle => 'Sauvegarde sur le serveur';

  @override
  String get desktopServerBackupHint => 'Une copie chiffrée du compte sur le serveur Secretly. Elle se restaure sur n’importe quel appareil via « Restaurer depuis le serveur » avec votre identifiant Secretly et le mot de passe.';

  @override
  String get desktopServerBackupLoading => 'Envoi…';

  @override
  String get desktopServerBackupCreateOnServer => 'Créer une sauvegarde sur le serveur';

  @override
  String get desktopServerBackupUpdate => 'Mettre à jour la sauvegarde';

  @override
  String desktopFailedWith(Object error) {
    return 'Échec : $error';
  }

  @override
  String get desktopStorageDeleteModelTitle => 'Supprimer le modèle de reconnaissance ?';

  @override
  String get desktopStorageDeleteModelBody => 'La transcription des messages vocaux cessera de fonctionner jusqu’au nouveau téléchargement du modèle.';

  @override
  String get desktopStorageModelDeleted => 'Le modèle a été supprimé';

  @override
  String desktopStorageDeleteFailed(Object error) {
    return 'Impossible de supprimer : $error';
  }

  @override
  String desktopStorageKb(Object value) {
    return '$value Ko';
  }

  @override
  String desktopStorageMb(Object value) {
    return '$value Mo';
  }

  @override
  String desktopStorageGb(Object value) {
    return '$value Go';
  }

  @override
  String get desktopStorageUsage => 'Utilisation';

  @override
  String get desktopStorageUsageHint => 'Cache et médias sur cet appareil';

  @override
  String desktopStorageClearHint(Object size) {
    return '$size seront libérés. Les messages, les fichiers que vous avez envoyés et les récents ne sont pas supprimés — il n’y aurait nulle part où les récupérer.';
  }

  @override
  String get desktopStorageClear => 'Vider le cache';

  @override
  String get desktopStorageCounting => 'Calcul…';

  @override
  String get desktopStorageSpeechModel => 'Modèle de reconnaissance vocale';

  @override
  String get desktopStorageSpeechModelHint => 'Sert à transcrire les messages vocaux sur cet ordinateur, sans envoyer l’audio où que ce soit. Un vidage normal du cache ne le supprime PAS — il est volumineux et téléchargé à part.';

  @override
  String get desktopStorageDeleteModel => 'Supprimer le modèle';

  @override
  String desktopStorageMedia(Object size) {
    return 'Médias · $size';
  }

  @override
  String desktopStorageVoice(Object size) {
    return 'Voix · $size';
  }

  @override
  String desktopStorageOther(Object size) {
    return 'Autres · $size';
  }

  @override
  String get desktopStorageFree => 'Libre';

  @override
  String desktopStorageTotal(Object size) {
    return 'Total · $size';
  }

  @override
  String desktopAboutVersion(Object version, Object build) {
    return 'Version $version · build $build';
  }

  @override
  String get desktopAboutTagline => 'Une messagerie sécurisée avec chiffrement de bout en bout. Sans cloud. Sans publicité. Code ouvert.';

  @override
  String get desktopAboutLicences => 'Licences';

  @override
  String get desktopAboutWebsite => 'Site web';

  @override
  String get desktopDangerTitle => 'Supprimer le compte de façon irréversible ?';

  @override
  String get desktopDangerBody => 'Le profil, les clés, les données locales et l’historique des messages seront supprimés sur cet appareil et les autres. Aucun retour en arrière.';

  @override
  String get desktopDangerDeleting => 'Suppression du compte…';

  @override
  String desktopDangerFailed(Object error) {
    return 'Impossible de supprimer le compte : $error';
  }

  @override
  String get desktopDangerSection => 'Suppression du compte';

  @override
  String get desktopDangerDemo => 'Mode démo · la suppression est indisponible sans profil connecté.';

  @override
  String get desktopDangerEnterId => 'Saisissez votre identifiant Secretly pour confirmer';

  @override
  String desktopDangerEnterIdExact(Object id) {
    return 'Saisissez $id pour confirmer';
  }

  @override
  String get desktopDangerAction => 'Supprimer le compte';

  @override
  String get desktopDangerIrreversible => 'Cette action est irréversible. Toutes vos données, l’historique des messages et les clés seront supprimés. Aucun retour en arrière.';

  @override
  String get desktopSecurityE2ee => 'Chiffrement de bout en bout';

  @override
  String get desktopSecurityE2eeHint => 'Tous les messages, appels et fichiers sont chiffrés sur votre appareil. Les clés ne quittent jamais vos appareils — le serveur ne voit que du texte chiffré.';

  @override
  String get desktopSecurityVerifiedDevices => 'Appareils vérifiés';

  @override
  String get desktopSecurityVerifiedHint => 'Tant que c’est activé, les messages ne partent pas vers les appareils non confirmés de l’autre personne. Cela protège contre la substitution, mais un message peut ne pas arriver tant qu’elle n’a pas confirmé un nouvel appareil. Conversations privées uniquement : sans effet sur les groupes.';

  @override
  String get desktopSecurityOnlyVerified => 'Appareils vérifiés uniquement';

  @override
  String get desktopSecurityBlocked => 'Les appareils non vérifiés sont bloqués';

  @override
  String get desktopSecurityAllDevices => 'Les messages partent vers tous les appareils de l’autre personne';

  @override
  String get desktopSecurityAppEntry => 'Accès à l’application';

  @override
  String get desktopSecurityAppEntryHint => 'Un mot de passe à l’ouverture de Secretly et après que la fenêtre est restée masquée plus d’une minute. Vaut pour cet ordinateur.';

  @override
  String get desktopSecurityPersonalScopeHint => 'Un mot de passe distinct pour la catégorie « Personnel ». Sans lui, les conversations personnelles sont ouvertes à quiconque accède à un ordinateur déverrouillé.';

  @override
  String get desktopCallsInApp => 'Appels dans l’application';

  @override
  String get desktopCallsInAppHint => 'Désactivez pour couper complètement les appels';

  @override
  String get desktopCallsAccept => 'Accepter les appels entrants';

  @override
  String get desktopCallsAcceptHint => 'On pourra vous appeler';

  @override
  String get desktopCallsDisabledHint => 'Indisponible tant que les appels sont désactivés';

  @override
  String get desktopCallsScreenShare => 'Partage d’écran';

  @override
  String get desktopCallsScreenShareHint => 'Recevoir l’écran d’une autre personne est une autorisation distincte : ce qui s’y affiche peut ne pas être ce que vous attendiez.';

  @override
  String get desktopCallsAcceptScreenShare => 'Accepter le partage d’écran';

  @override
  String get desktopAccountIdCopied => 'L’identifiant Secretly a été copié';

  @override
  String get desktopAccountIdHint => 'Cet identifiant est ce que vous partagez pour qu’on vous trouve. Il ne contient ni numéro de téléphone ni adresse e-mail.';

  @override
  String get desktopAccountCopy => 'Copier';

  @override
  String get desktopAccountProfile => 'Profil';

  @override
  String get desktopAccountProfileHint => 'Nom, photo, statut';

  @override
  String get desktopAccountOpenProfile => 'Ouvrir la page du profil';

  @override
  String desktopScopePasswordFor(Object name) {
    return 'Mot de passe pour « $name »';
  }

  @override
  String get desktopScopeMin4 => 'Au moins 4 caractères';

  @override
  String get desktopScopeOn => 'La protection est activée';

  @override
  String desktopScopeOnFailed(Object error) {
    return 'Impossible d’activer : $error';
  }

  @override
  String get desktopScopeOff => 'La protection est désactivée';

  @override
  String desktopScopeOffFailed(Object error) {
    return 'Impossible de désactiver : $error';
  }

  @override
  String get desktopScopePasswordsDiffer => 'Les mots de passe ne correspondent pas';

  @override
  String get desktopScopeTitle => 'Protection par mot de passe';

  @override
  String get desktopScopeOnWithPassword => 'Activée — mot de passe';

  @override
  String get desktopScopeEnabled => 'Activée';

  @override
  String get desktopScopeDisabled => 'Désactivée';

  @override
  String get desktopScopeChangePassword => 'Changer le mot de passe';

  @override
  String get desktopScopeLockNow => 'Verrouiller';

  @override
  String desktopBlockedUnblocked(Object name) {
    return '$name a été débloqué';
  }

  @override
  String desktopBlockedUnblockFailed(Object error) {
    return 'Impossible de débloquer : $error';
  }

  @override
  String get desktopBlockedTitle => 'Bloqués';

  @override
  String get desktopBlockedEmptyHint => 'La liste est vide. On bloque depuis le menu d’une conversation.';

  @override
  String get desktopBlockedHint => 'Ces personnes ne peuvent ni vous écrire ni vous appeler.';

  @override
  String get desktopBlockedNone => 'Personne n’est bloqué';

  @override
  String get desktopSupportSent => 'Le message a été envoyé';

  @override
  String get desktopSupportSendFailed => 'Envoi impossible. Vérifiez votre connexion.';

  @override
  String get desktopSupportUnavailable => 'L’assistance est indisponible';

  @override
  String get desktopSupportUnavailableHint => 'Le service d’assistance est coupé pour l’instant. Réessayez plus tard ou écrivez depuis le téléphone.';

  @override
  String get desktopSupportThread => 'La conversation avec l’assistance';

  @override
  String get desktopSupportThreadHint => 'Les messages sont chiffrés sur votre appareil. Le serveur ne conserve que du texte chiffré — seule l’assistance peut lire la conversation.';

  @override
  String get desktopSupportNoReplies => 'Pas encore de réponse. Décrivez le problème — la réponse arrivera ici.';

  @override
  String get desktopSupportWrite => 'Écrire à l’assistance';

  @override
  String get desktopSupportWriteHint => 'La version du build et l’identifiant de l’appareil sont joints automatiquement — sans eux, le problème est presque impossible à reproduire.';

  @override
  String get desktopSupportDescribe => 'Décrivez ce qui s’est passé';

  @override
  String get desktopSupportSending => 'Envoi…';

  @override
  String get desktopSupportSend => 'Envoyer';

  @override
  String get desktopChatsEmptyHint => 'Commencez une conversation depuis le téléphone — les discussions se synchronisent toutes seules';

  @override
  String get desktopChatsPickOne => 'Choisissez une conversation à gauche';

  @override
  String desktopChatsSendFailed(Object error) {
    return 'Envoi impossible : $error';
  }

  @override
  String desktopChatsSendingTo(Object title) {
    return 'Envoi vers « $title »';
  }

  @override
  String get desktopChatsFilterAll => 'Tout';

  @override
  String get desktopChatsFilterUnread => 'Non lus';

  @override
  String get desktopChatsFilterGroups => 'Groupes';

  @override
  String get desktopChatsFilterArchive => 'Archives';

  @override
  String get desktopChatsFilterPersonal => 'Personnel';

  @override
  String get desktopChatsRenameFolder => 'Renommer le dossier';

  @override
  String get desktopChatsDeleteFolder => 'Supprimer le dossier';

  @override
  String desktopChatsRenameFailed(Object error) {
    return 'Impossible de renommer : $error';
  }

  @override
  String desktopChatsDeleteFolderTitle(Object name) {
    return 'Supprimer le dossier « $name » ?';
  }

  @override
  String get desktopChatsDeleteFolderBody => 'Les conversations restent en place — seul le dossier est supprimé.';

  @override
  String desktopChatsDeleteFailed(Object error) {
    return 'Impossible de supprimer : $error';
  }

  @override
  String desktopChatsAddedToFolder(Object name) {
    return 'Ajouté à « $name »';
  }

  @override
  String desktopChatsRemovedFromFolder(Object name) {
    return 'Retiré de « $name »';
  }

  @override
  String desktopChatsFolderChangeFailed(Object error) {
    return 'Impossible de changer le dossier : $error';
  }

  @override
  String desktopChatsFolderCreated(Object name) {
    return 'Le dossier « $name » a été créé';
  }

  @override
  String desktopChatsFolderCreateFailed(Object error) {
    return 'Impossible de créer le dossier : $error';
  }

  @override
  String get desktopChatsNewFolder => 'Nouveau dossier';

  @override
  String get desktopChatsFolderName => 'Nom du dossier';

  @override
  String desktopChatsRemoveFromFolder(Object name) {
    return 'Retirer de « $name »';
  }

  @override
  String desktopChatsAddToFolder(Object name) {
    return 'Vers le dossier « $name »';
  }

  @override
  String get desktopChatsNewFolderWithChat => 'Nouveau dossier avec cette conversation…';

  @override
  String get desktopChatsRemoveFromPersonal => 'Retirer de Personnel';

  @override
  String get desktopChatsAddToPersonal => 'Vers Personnel';

  @override
  String get desktopChatsArchiveEmpty => 'Les archives sont vides';

  @override
  String get desktopChatsNoPersonal => 'Il n’y a pas de conversations personnelles';

  @override
  String get desktopChatsPersonalLocked => 'Les conversations personnelles sont protégées par mot de passe';

  @override
  String get desktopChatsAllRead => 'Tout est lu';

  @override
  String get desktopChatsFolderEmpty => 'Ce dossier est vide pour l’instant';

  @override
  String get desktopChatsNewChat => 'Nouvelle conversation';

  @override
  String get desktopChatsNewRoom => 'Nouveau salon';

  @override
  String get desktopChatsStartFailed => 'Impossible de démarrer la conversation : le profil est indisponible';

  @override
  String get desktopChatsPhoto => 'Photo';

  @override
  String get desktopChatsVideo => 'Vidéo';

  @override
  String get desktopChatsAudio => 'Audio';

  @override
  String get desktopChatsVoiceMessage => 'Message vocal';

  @override
  String get desktopChatsVoiceShort => 'Vocal';

  @override
  String get desktopChatsLink => 'Lien';

  @override
  String get desktopChatsSticker => 'Autocollant';

  @override
  String desktopChatsStickerWith(Object label) {
    return 'Autocollant $label';
  }

  @override
  String desktopChatsPoll(Object question) {
    return '📊 Sondage : $question';
  }

  @override
  String get desktopChatsUnknown => 'inconnu';

  @override
  String get desktopChatsMember => 'Membre';

  @override
  String get desktopChatsSoundOn => 'Activer le son';

  @override
  String get desktopChatsSoundOff => 'Sans son';

  @override
  String get desktopChatsClearHistoryTitle => 'Effacer l’historique ?';

  @override
  String desktopChatsClearHistoryBody(Object title) {
    return 'Tous les messages de la conversation « $title » seront supprimés sur cet appareil.';
  }

  @override
  String get desktopChatsClear => 'Effacer';

  @override
  String get desktopChatsHistoryClearedBoth => 'L’historique a été effacé des deux côtés';

  @override
  String get desktopChatsHistoryCleared => 'L’historique a été effacé';

  @override
  String get desktopChatsDeleteChatTitle => 'Supprimer la conversation ?';

  @override
  String desktopChatsDeleteChatBody(Object title) {
    return 'La conversation « $title » sera entièrement supprimée de cet appareil.';
  }

  @override
  String get desktopChatsRooms => 'Salons';

  @override
  String get desktopChatsGeneralTopic => 'Général';

  @override
  String get desktopChatsNewTopicEllipsis => 'Nouveau sujet…';

  @override
  String desktopChatsBranch(Object title) {
    return 'Branche « $title »';
  }

  @override
  String get desktopChatsRename => 'Renommer';

  @override
  String get desktopChatsIcon => 'Icône';

  @override
  String get desktopChatsDeleteBranch => 'Supprimer la branche';

  @override
  String get desktopChatsBranchIcon => 'Icône de la branche';

  @override
  String get desktopChatsBranchIconHint => 'L’icône remplace le dièse devant le nom. Les colorées annoncent ce qu’il y a dedans : vert un appel, rouge quelque chose d’urgent. Les autres sont grises pour ne pas concurrencer le nom.';

  @override
  String get desktopChatsHash => 'Dièse';

  @override
  String desktopChatsBranchFailed(Object error) {
    return 'Impossible de modifier les branches : $error';
  }

  @override
  String get desktopChatsNewTopic => 'Nouveau sujet';

  @override
  String get desktopChatsRenameTopic => 'Renommer le sujet';

  @override
  String get desktopChatsTopicName => 'Nom du sujet';

  @override
  String desktopChatsReactionFailed(Object error) {
    return 'Impossible d’enregistrer la réaction : $error';
  }

  @override
  String desktopChatsReactionLocal(Object error) {
    return 'La réaction a été appliquée localement mais n’a pas été remise à l’autre personne : $error';
  }

  @override
  String get desktopChatsRevealFailed => 'Impossible d’afficher le fichier dans le Finder';

  @override
  String desktopChatsVideoOpenFailed(Object error) {
    return 'Impossible d’ouvrir la vidéo : $error';
  }

  @override
  String get desktopChatsVideoUnavailable => 'La vidéo est indisponible';

  @override
  String desktopChatsFileFetchFailed(Object error) {
    return 'Impossible de récupérer le fichier : $error';
  }

  @override
  String get desktopChatsSaveAttachment => 'Enregistrer la pièce jointe';

  @override
  String get desktopChatsFileUnavailable => 'Le fichier est indisponible';

  @override
  String desktopChatsSaveFailed(Object error) {
    return 'Impossible d’enregistrer : $error';
  }

  @override
  String desktopChatsOpenFailedWith(Object error) {
    return 'Impossible d’ouvrir le fichier : $error';
  }

  @override
  String get desktopChatsOpenFailed => 'Impossible d’ouvrir le fichier';

  @override
  String desktopChatsOpenFailedShort(Object error) {
    return 'Impossible d’ouvrir : $error';
  }

  @override
  String desktopChatsPlayFailed(Object error) {
    return 'Lecture impossible : $error';
  }

  @override
  String get desktopChatsNoCallPeer => 'Impossible de déterminer qui appeler.';

  @override
  String get desktopChatsCallsNotReady => 'Le service d’appel n’est pas prêt.';

  @override
  String get desktopChatsCallInProgress => 'Un appel est déjà en cours.';

  @override
  String get desktopChatsEditFailed => 'Impossible de modifier le message.';

  @override
  String get desktopChatsNoRecipient => 'Impossible de déterminer le destinataire.';

  @override
  String get desktopChatsDeleteMessageTitle => 'Supprimer le message ?';

  @override
  String get desktopChatsDeleteMessagesTitle => 'Supprimer les messages sélectionnés ?';

  @override
  String get desktopChatsDeleteOthersHint => 'Les messages des autres ne seront supprimés que chez vous.';

  @override
  String get desktopChatsDeleteForAll => 'Supprimer pour tout le monde';

  @override
  String get desktopChatsDeleteForMeOnly => 'Supprimer seulement chez moi';

  @override
  String get desktopChatsDeleteForMe => 'Supprimer chez moi';

  @override
  String get desktopChatsSavePrivacyBlocked => 'Ce message ne peut pas être enregistré en raison de restrictions de confidentialité.';

  @override
  String get desktopChatsNothingToSave => 'La pièce jointe n’a pas été téléchargée — il n’y a rien à enregistrer';

  @override
  String get desktopChatsSavedPartly => 'Enregistré dans les favoris, mais pas tout';

  @override
  String get desktopChatsSaved => 'Enregistré dans les favoris';

  @override
  String get desktopChatsForwardPrivacyBlocked => 'Ce message ne peut pas être transféré en raison de restrictions de confidentialité.';

  @override
  String desktopChatsForwardFailed(Object error) {
    return 'Impossible de transférer : $error';
  }

  @override
  String get desktopChatsNothingToForward => 'La pièce jointe n’a pas été téléchargée — il n’y a rien à transférer';

  @override
  String desktopChatsForwardedPartly(Object title) {
    return 'Transféré vers « $title », mais pas tout';
  }

  @override
  String desktopChatsForwarded(Object title) {
    return 'Transféré vers « $title »';
  }

  @override
  String desktopChatsFileNotSentElsewhere(Object text) {
    return 'Le fichier n’a pas été envoyé à l’autre conversation : $text';
  }

  @override
  String get desktopChatsFileSendFailed => 'Impossible d’envoyer le fichier.';

  @override
  String desktopChatsPremiumFiles(Object text) {
    return '$text Avec Premium, vous pouvez envoyer des fichiers jusqu’à 1 Go.';
  }

  @override
  String get desktopChatsTypingEllipsis => 'écrit…';

  @override
  String get desktopChatsOnline => 'en ligne';

  @override
  String desktopChatsSomeoneTyping(Object name) {
    return '$name écrit';
  }

  @override
  String get desktopChatsLoadingList => 'Récupération de la liste depuis le stockage local.';

  @override
  String get desktopChatsWillAppear => 'Les messages et les appels apparaîtront ici dès que vous ouvrirez une conversation.';

  @override
  String get desktopRoomNoOpenHere => 'On ne peut pas ouvrir une conversation d’ici';

  @override
  String get desktopRoomIdCopied => 'L’identifiant a été copié';

  @override
  String get desktopRoomAwaiting => 'En attente d’approbation';

  @override
  String get desktopRoomBlocked => 'Bloqué';

  @override
  String get desktopRoomCopied => 'Copié';

  @override
  String get desktopRoomChangeRole => 'Changer le rôle';

  @override
  String get desktopRoomTransfer => 'Transférer la propriété';

  @override
  String get desktopRoomBlockMember => 'Bloquer';

  @override
  String get desktopRoomKick => 'Exclure';

  @override
  String get desktopRoomKickTitle => 'Exclure le membre ?';

  @override
  String desktopRoomKickBody(Object name) {
    return '$name perdra l’accès au salon. Une nouvelle invitation le fait revenir.';
  }

  @override
  String get desktopRoomBlockTitle => 'Bloquer le membre ?';

  @override
  String desktopRoomBlockBody(Object name) {
    return '$name ne pourra pas revenir dans le salon, même avec une invitation, tant que le blocage dure.';
  }

  @override
  String get desktopRoomTransferTitle => 'Transférer la propriété du salon ?';

  @override
  String desktopRoomTransferBody(Object name) {
    return '$name devient propriétaire et vous devenez administrateur. Seul le nouveau propriétaire peut l’annuler.';
  }

  @override
  String get desktopRoomTransferAction => 'Transférer';

  @override
  String get desktopRoomClearTitle => 'Effacer l’historique ?';

  @override
  String get desktopRoomClearBody => 'Tous les messages du salon seront supprimés sur cet appareil.';

  @override
  String get desktopRoomLeaveTitle => 'Quitter le salon ?';

  @override
  String get desktopRoomLeaveBody => 'Vous cesserez de recevoir les messages. Revenir demande une nouvelle invitation.';

  @override
  String get desktopRoomLeave => 'Quitter';

  @override
  String get desktopRoomInvite => 'Inviter';

  @override
  String get desktopRoomCopyId => 'Copier l’identifiant du salon';

  @override
  String get desktopRoomMuteOff => 'Désactiver les notifications';

  @override
  String get desktopRoomUnarchive => 'Sortir des archives';

  @override
  String get desktopRoomLeaveRoom => 'Quitter le salon';

  @override
  String get desktopRoomUntitled => 'Sans titre';

  @override
  String get desktopRoomCopyInvite => 'Copier l’invitation';

  @override
  String get desktopRoomSound => 'Son';

  @override
  String get desktopRoomTabInfo => 'Infos';

  @override
  String get desktopRoomTabMembers => 'Membres';

  @override
  String get desktopRoomTabMedia => 'Médias';

  @override
  String get desktopRoomTopics => 'SUJETS';

  @override
  String desktopRoomTopicsCount(Object count) {
    return 'SUJETS · $count';
  }

  @override
  String get desktopRoomDescription => 'Description';

  @override
  String get desktopRoomNotes => 'NOTES';

  @override
  String get desktopRoomInformation => 'Informations';

  @override
  String get desktopRoomId => 'Identifiant du salon';

  @override
  String get desktopRoomInviteLink => 'Lien d’invitation · cliquez pour copier';

  @override
  String get desktopRoomFavouriteHint => 'Une tuile sur la barre et une place en haut de la liste';

  @override
  String get desktopRoomArchiveHint => 'Masquer le salon de la liste principale';

  @override
  String get desktopRoomNoMembers => 'Aucun membre';

  @override
  String desktopRoomMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '$count membre',
    );
    return '$_temp0';
  }

  @override
  String get desktopRoomNobodyFound => 'Personne trouvé';

  @override
  String get desktopRoomMembersUnavailable => 'La liste des membres est indisponible.';

  @override
  String get desktopRoomInCall => 'DANS L’APPEL';

  @override
  String get desktopRoomOnline => 'EN LIGNE';

  @override
  String get desktopRoomOffline => 'HORS LIGNE';

  @override
  String desktopRoomMoreHidden(Object count) {
    return '$count de plus — utilisez la recherche ci-dessus';
  }

  @override
  String get desktopRoomSearchMember => 'Rechercher un membre';

  @override
  String get desktopRoomJoinRequests => 'Demandes d’adhésion';

  @override
  String get desktopRoomAccept => 'Accepter';

  @override
  String get desktopRoomDecline => 'Refuser';

  @override
  String get desktopRoomRoleOwner => 'Propriétaire';

  @override
  String get desktopRoomRoleAdmin => 'Administrateur';

  @override
  String get desktopRoomRoleModerator => 'Modérateur';

  @override
  String get desktopRoomRoleRestricted => 'Restreint';

  @override
  String get desktopRoomRoleGuest => 'Invité';

  @override
  String get desktopContactBlockTitle => 'Bloquer ?';

  @override
  String get desktopContactUnblockTitle => 'Débloquer ?';

  @override
  String get desktopContactBlockBody => 'Cette personne ne pourra plus vous envoyer de messages ni vous appeler.';

  @override
  String get desktopContactUnblockBody => 'Cette personne pourra de nouveau vous joindre.';

  @override
  String get desktopContactBlock => 'Bloquer';

  @override
  String get desktopContactCallsNotReady => 'Le service d’appel n’est pas encore prêt';

  @override
  String get desktopContactCallInProgress => 'Un appel est déjà en cours';

  @override
  String desktopContactCallFailed(Object error) {
    return 'Impossible de démarrer l’appel : $error';
  }

  @override
  String get desktopContactAutoDelete => 'Suppression automatique des messages';

  @override
  String get desktopContactAutoDeleteUpdated => 'La suppression automatique a été mise à jour';

  @override
  String get desktopContactClearBody => 'Tous les messages de cette conversation seront supprimés sur cet appareil.';

  @override
  String get desktopContactDeleteBody => 'La conversation sera entièrement supprimée de cet appareil.';

  @override
  String get desktopContactOff => 'Désactivé';

  @override
  String get desktopContactDisable => 'Désactiver';

  @override
  String get desktopContactDay1 => '1 jour';

  @override
  String get desktopContactDays7 => '7 jours';

  @override
  String get desktopContactDays30 => '30 jours';

  @override
  String get desktopContactHour1 => '1 heure';

  @override
  String desktopContactMinutes(Object value) {
    return '$value min';
  }

  @override
  String get desktopContactOffline => 'hors ligne';

  @override
  String desktopContactSeenAt(Object time) {
    return 'vu à $time';
  }

  @override
  String get desktopContactSeenYesterday => 'vu hier';

  @override
  String desktopContactSeenOn(Object date) {
    return 'vu le $date';
  }

  @override
  String get desktopContactCopyId => 'Copier l’identifiant';

  @override
  String get desktopContactCopyIdShort => 'Copier l’ID';

  @override
  String get desktopContactDisappearing => 'Messages éphémères';

  @override
  String get desktopContactDeleteChat => 'Supprimer la conversation';

  @override
  String get desktopContactCall => 'Appel';

  @override
  String get desktopContactBlockShort => 'Bloc';

  @override
  String get desktopContactSecurity => 'Sécurité';

  @override
  String get desktopContactVerify => 'Vérifier le contact';

  @override
  String get desktopContactArchiveHint => 'Masquer la conversation de la liste principale';

  @override
  String get desktopThreadMessageHint => 'Message…';

  @override
  String get desktopThreadPasteFailed => 'Impossible de coller l’image';

  @override
  String get desktopThreadNoScheduleEdit => 'Une modification ne peut pas être planifiée — elle change ce qui est déjà envoyé';

  @override
  String desktopThreadWillLeave(Object when) {
    return 'Partira $when';
  }

  @override
  String desktopThreadSeconds(Object value) {
    return '$value s';
  }

  @override
  String desktopThreadMinutes(Object value) {
    return '$value min';
  }

  @override
  String desktopThreadHours(Object value) {
    return '$value h';
  }

  @override
  String desktopThreadDays(Object value) {
    return '$value j';
  }

  @override
  String desktopThreadWeeks(Object value) {
    return '$value sem';
  }

  @override
  String desktopThreadSelected(Object count) {
    return 'Sélectionnés : $count';
  }

  @override
  String get desktopThreadDisappearingOn => 'Les messages éphémères sont activés';

  @override
  String get desktopThreadCallAction => 'Appeler';

  @override
  String get desktopThreadCallRoom => 'Appel de groupe';

  @override
  String get desktopThreadVideoCall => 'Appel vidéo';

  @override
  String get desktopThreadSearchShortcut => 'Rechercher dans la conversation  Cmd F';

  @override
  String get desktopThreadHideDetails => 'Masquer les détails';

  @override
  String get desktopThreadShowDetails => 'Afficher les détails';

  @override
  String get desktopThreadMore => 'Plus';

  @override
  String get desktopThreadPinned => 'Message épinglé';

  @override
  String get desktopThreadNoMatches => 'aucun résultat';

  @override
  String get desktopThreadSearchHint => 'Rechercher dans la conversation…';

  @override
  String get desktopThreadPrevMatch => 'Précédent (Maj F3)';

  @override
  String get desktopThreadNextMatch => 'Suivant (F3)';

  @override
  String get desktopThreadCloseEsc => 'Fermer (Échap)';

  @override
  String get desktopThreadNewMessages => 'Nouveaux messages';

  @override
  String desktopThreadUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non lus',
      one: '$count non lu',
    );
    return '$_temp0';
  }

  @override
  String get desktopThreadToday => 'Aujourd’hui';

  @override
  String get desktopThreadYesterday => 'Hier';

  @override
  String get desktopProfileEmojiStatus => 'Statut emoji';

  @override
  String get desktopProfileClearStatus => 'Retirer le statut';

  @override
  String desktopProfileApplyFailed(Object error) {
    return 'Impossible d’appliquer : $error';
  }

  @override
  String get desktopProfileAvatarFrame => 'Cadre de l’avatar';

  @override
  String get desktopProfileCover => 'Couverture du profil';

  @override
  String get desktopProfileNoFrame => 'Sans cadre';

  @override
  String get desktopProfileNoCover => 'Sans couverture';

  @override
  String get desktopProfileReadFailed => 'Impossible de lire le fichier';

  @override
  String get desktopProfilePhotoUpdated => 'La photo de profil a été mise à jour';

  @override
  String desktopProfilePhotoFailed(Object error) {
    return 'Impossible de mettre à jour la photo : $error';
  }

  @override
  String desktopProfilePhotoRemoveFailed(Object error) {
    return 'Impossible de retirer la photo : $error';
  }

  @override
  String get desktopProfileMine => 'Mon profil';

  @override
  String get desktopProfileEdit => 'Modifier';

  @override
  String get desktopProfileName => 'Nom';

  @override
  String get desktopProfileChangePhoto => 'Changer la photo';

  @override
  String get desktopProfileFrameShort => 'Cadre';

  @override
  String get desktopProfileCoverShort => 'Couverture';

  @override
  String get desktopProfileStatus => 'Statut';

  @override
  String get desktopProfileAppearanceHint => 'Thème, accent et fond de conversation';

  @override
  String get desktopProfileAbout => 'À propos de moi';

  @override
  String get desktopProfileEmpty => 'Non rempli';

  @override
  String get desktopProfilePhoto => 'Photo de profil';

  @override
  String get desktopProfileReplacePhoto => 'Remplacer la photo';

  @override
  String get desktopProfilePickPhoto => 'Choisir une photo';

  @override
  String get desktopProfilePickedHere => 'Choisie sur cet ordinateur';

  @override
  String get desktopProfileSyncedWithPhone => 'Synchronisée avec le téléphone';

  @override
  String get desktopProfileNotPicked => 'Non choisie';

  @override
  String get desktopProfileRemovePhoto => 'Retirer la photo';

  @override
  String get desktopProfileInitialsStay => 'Les initiales resteront';

  @override
  String get desktopProfileAccount => 'Compte';

  @override
  String get desktopProfileRecovery => 'Récupération';

  @override
  String get desktopProfileRecoveryHint => 'Cet ordinateur est associé au téléphone et ne conserve pas sa propre phrase de récupération : la sauvegarde et la clé de récupération ramènent le compte.';

  @override
  String get desktopProfileDevicesHint => 'Ordinateurs et téléphones connectés';

  @override
  String get desktopProfileFrameCaps => 'CADRE DE L’AVATAR';

  @override
  String get desktopGalleryMedia => 'Médias';

  @override
  String get desktopGalleryFiles => 'Fichiers';

  @override
  String get desktopGalleryLinks => 'Liens';

  @override
  String get desktopGalleryNoMedia => 'Aucun média';

  @override
  String get desktopGalleryNoFiles => 'Aucun fichier';

  @override
  String get desktopGalleryNoAudio => 'Aucun audio';

  @override
  String get desktopGalleryNoLinks => 'Aucun lien';

  @override
  String get desktopGalleryPathCopied => 'Le chemin a été copié';

  @override
  String get desktopGalleryOpen => 'Ouvrir';

  @override
  String get desktopGalleryView => 'Voir';

  @override
  String get desktopGalleryOpenInSystem => 'Ouvrir dans le système';

  @override
  String get desktopGalleryRevealFinder => 'Afficher dans le Finder';

  @override
  String get desktopGalleryRevealExplorer => 'Afficher dans l’Explorateur';

  @override
  String get desktopGalleryOpenFolder => 'Ouvrir le dossier';

  @override
  String get desktopGalleryCopyPath => 'Copier le chemin';

  @override
  String desktopGalleryBytes(Object value) {
    return '$value o';
  }

  @override
  String get desktopGalleryZeroBytes => '0 o';

  @override
  String desktopOutgoingFolderSingle(Object name) {
    return 'le dossier « $name » ne peut pas être envoyé';
  }

  @override
  String get desktopOutgoingFoldersMany => 'les dossiers ne peuvent pas être envoyés';

  @override
  String desktopOutgoingTooLargeOne(Object name, Object limit) {
    return '« $name » dépasse $limit Mo';
  }

  @override
  String desktopOutgoingTooLargeMany(int count, Object limit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers dépassent $limit Mo',
      one: '$count fichier dépasse $limit Mo',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingEmptyOne(Object name) {
    return '« $name » est vide';
  }

  @override
  String desktopOutgoingEmptyMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers sont vides',
      one: '$count fichier est vide',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingUnreadableOne(Object name) {
    return '« $name » n’a pas pu être lu';
  }

  @override
  String desktopOutgoingUnreadableMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers n’ont pas pu être lus',
      one: '$count fichier n’a pas pu être lu',
    );
    return '$_temp0';
  }

  @override
  String get desktopOutgoingSending => 'Envoi';

  @override
  String desktopOutgoingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '$count photos',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vidéos',
      one: '$count vidéos',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingMedia(Object count) {
    return '$count médias';
  }

  @override
  String desktopOutgoingAudios(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audios',
      one: '$count audios',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '$count fichiers',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallsPickOne => 'Choisissez un appel à gauche';

  @override
  String get desktopCallsPickHint => 'Les détails et un bouton pour rappeler apparaîtront ici';

  @override
  String get desktopCallsNone => 'Pas encore d’appels';

  @override
  String get desktopCallsNoneHint => 'L’historique apparaîtra après le premier appel';

  @override
  String get desktopCallsOutgoing => 'Sortant';

  @override
  String get desktopCallsIncoming => 'Entrant';

  @override
  String get desktopCallsGroup => 'groupe';

  @override
  String get desktopCallsVideoKind => 'vidéo';

  @override
  String get desktopCallsAudioKind => 'audio';

  @override
  String get desktopCallsMissed => 'manqué';

  @override
  String desktopPhotoCopyFailed(Object error) {
    return 'Impossible de copier : $error';
  }

  @override
  String get desktopPhotoSave => 'Enregistrer la photo';

  @override
  String get desktopPhotoSaved => 'Enregistré';

  @override
  String desktopPhotoRevealFailed(Object error) {
    return 'Impossible d’afficher dans le Finder : $error';
  }

  @override
  String get desktopPhotoLoadFailed => 'Impossible de charger';

  @override
  String get desktopPhotoZoomOut => 'Dézoomer';

  @override
  String get desktopPhotoZoomReset => 'Réinitialiser le zoom';

  @override
  String get desktopPhotoZoomIn => 'Zoomer';

  @override
  String get desktopPhotoCopy => 'Copier';

  @override
  String desktopBubbleForwardedFrom(Object from) {
    return 'Transféré de $from';
  }

  @override
  String get desktopBubbleAudioFile => 'Fichier audio';

  @override
  String get desktopBubbleTranslating => 'Traduction…';

  @override
  String get desktopBubbleTranslation => 'TRADUCTION';

  @override
  String get desktopBubbleEdited => 'modifié';

  @override
  String get desktopBubbleMoreReactions => 'Plus de réactions';

  @override
  String get desktopBubbleRoleOwner => 'propriétaire';

  @override
  String get desktopBubbleRoleAdmin => 'admin';

  @override
  String get desktopBubbleRoleMod => 'mod';

  @override
  String get desktopBubbleSpeed => 'Vitesse de lecture';

  @override
  String get desktopSpotlightGoChats => 'Aller aux conversations';

  @override
  String get desktopSpotlightGoRooms => 'Aller aux salons';

  @override
  String get desktopSpotlightGoContacts => 'Aller aux contacts';

  @override
  String get desktopSpotlightGoCalls => 'Aller aux appels';

  @override
  String get desktopSpotlightSelect => 'sélectionner';

  @override
  String get desktopSpotlightOpen => 'ouvrir';

  @override
  String get desktopSpotlightClose => 'fermer';

  @override
  String get desktopSpotlightRoom => 'Salon';

  @override
  String get desktopSpotlightMessage => 'Message';

  @override
  String get desktopSpotlightCommand => 'Commande';

  @override
  String get desktopComposerCancelRec => 'Annuler l’enregistrement';

  @override
  String desktopComposerRecording(Object time) {
    return 'Enregistrement  $time';
  }

  @override
  String get desktopComposerSendVoice => 'Envoyer le message vocal';

  @override
  String get desktopComposerAttach => 'Joindre';

  @override
  String get desktopComposerEmoji => 'Emoji et autocollants';

  @override
  String get desktopComposerRecordVoice => 'Enregistrer un message vocal';

  @override
  String get desktopComposerEnterSends => 'Entrée envoie · Maj+Entrée saute une ligne';

  @override
  String get desktopComposerEnterNewline => 'Entrée saute une ligne · Maj+Entrée envoie';

  @override
  String get desktopComposerEditing => 'Modification';

  @override
  String desktopComposerReplyTo(Object name) {
    return 'Réponse · $name';
  }

  @override
  String get desktopComposerCancelAction => 'Annuler';

  @override
  String get desktopComposerSendHint => 'Envoyer · Entrée\nClic droit pour envoyer plus tard';

  @override
  String get desktopComposerWriteFirst => 'Écrivez d’abord un message';

  @override
  String desktopComposerToTopic(Object title) {
    return 'vers le sujet « $title »';
  }

  @override
  String get desktopShortcutsNavigation => 'Navigation';

  @override
  String get desktopShortcutsTabs => 'Conversations · Salons · Appels · Contacts';

  @override
  String get desktopShortcutsSearchAll => 'Rechercher dans les conversations et les messages';

  @override
  String get desktopShortcutsPrevNext => 'Conversation précédente / suivante';

  @override
  String get desktopShortcutsInChat => 'Dans une conversation';

  @override
  String get desktopShortcutsFindHere => 'Rechercher dans cette conversation';

  @override
  String get desktopShortcutsSend => 'Envoyer (configurable)';

  @override
  String get desktopShortcutsNewline => 'Saut de ligne';

  @override
  String get desktopShortcutsPaste => 'Coller une image du presse-papiers';

  @override
  String get desktopShortcutsApp => 'Application';

  @override
  String get desktopShortcutsThisHelp => 'Cette aide';

  @override
  String get desktopShortcutsCloseWindow => 'Fermer la fenêtre ou la recherche';

  @override
  String get desktopShortcutsTray => 'Réduire dans la zone de notification';

  @override
  String get desktopShortcutsTitle => 'Raccourcis clavier';

  @override
  String get desktopMediaCancelSend => 'Annuler l’envoi';

  @override
  String get desktopMediaSending => 'Envoi…';

  @override
  String desktopMediaSendingOf(Object total) {
    return 'Envoi… · $total';
  }

  @override
  String get desktopMediaRetryDownload => 'Réessayer le téléchargement';

  @override
  String get desktopMediaImage => 'Image';

  @override
  String desktopMediaDownloading(Object size) {
    return 'Téléchargement… · $size';
  }

  @override
  String get desktopMediaDownload => 'Télécharger';

  @override
  String get desktopSendAsMedia => 'Envoyer comme médias';

  @override
  String get desktopSendAsFiles => 'Envoyer comme fichiers';

  @override
  String get desktopSendUngroup => 'Ne pas grouper';

  @override
  String get desktopSendGroup => 'Grouper';

  @override
  String get desktopSendAddFiles => 'Ajouter des fichiers…';

  @override
  String get desktopSendDropHere => 'Relâchez pour ajouter';

  @override
  String get desktopSendCloseEsc => 'Fermer · Échap';

  @override
  String desktopSendToDestination(Object destination) {
    return 'vers « $destination »';
  }

  @override
  String get desktopSendCaptionHint => 'Ajouter une légende…';

  @override
  String get desktopSendEmoji => 'Emoji';

  @override
  String get desktopSendRemove => 'Retirer';

  @override
  String get desktopSendEnter => 'Envoyer · Entrée';

  @override
  String get desktopSendShiftEnter => 'Envoyer · Maj+Entrée';

  @override
  String get desktopCallCtlMicOff => 'Couper le micro   ⌘D';

  @override
  String get desktopCallCtlMicOn => 'Activer le micro   ⌘D';

  @override
  String get desktopCallCtlCamOff => 'Couper la caméra   ⌘E';

  @override
  String get desktopCallCtlCamOn => 'Activer la caméra   ⌘E';

  @override
  String get desktopCallCtlShareStop => 'Arrêter le partage';

  @override
  String get desktopCallCtlShare => 'Partage d’écran';

  @override
  String get desktopCallCtlHandDown => 'Baisser la main';

  @override
  String get desktopCallCtlHandUp => 'Lever la main';

  @override
  String get desktopCallCtlHangUp => 'Raccrocher   ⌘W';

  @override
  String desktopAbsenceDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '$count jour',
    );
    return '$_temp0';
  }

  @override
  String desktopAbsencePastFanout(Object days) {
    return 'Cet ordinateur est resté injoignable pendant $days. Pendant ce temps, les expéditeurs ont cessé de chiffrer les messages pour lui, et une partie de l’historique n’arrivera pas ici. Elle est intacte sur le téléphone — ouvrez-y les conversations voulues et l’historique récent suivra.';
  }

  @override
  String desktopAbsenceWithinWindow(Object days) {
    return 'Cet ordinateur est resté injoignable pendant $days. Les messages restent une semaine sur le serveur, une partie n’a donc peut-être pas été conservée pour lui. Sur le téléphone, ils sont intacts.';
  }

  @override
  String get desktopAbsenceGotIt => 'Compris';

  @override
  String get desktopNavContacts => 'Contacts';

  @override
  String get desktopChatNotFound => 'La conversation est introuvable';

  @override
  String desktopUnreadTitle(Object count) {
    return 'Secretly — $count non lus';
  }

  @override
  String get desktopRoomsNone => 'Pas encore de salons';

  @override
  String get desktopRoomsNoneHint => 'Créez un salon depuis le téléphone — il apparaîtra ici automatiquement';

  @override
  String get desktopRoomsPickOne => 'Choisissez un salon à gauche';

  @override
  String get desktopScheduleTitle => 'Envoyer plus tard';

  @override
  String get desktopScheduleInHour => 'Dans une heure';

  @override
  String get desktopScheduleTonight => 'Aujourd’hui à 19h00';

  @override
  String get desktopScheduleTomorrow => 'Demain à 9h00';

  @override
  String get desktopScheduleInWeek => 'Dans une semaine';

  @override
  String desktopScheduleTodayAt(Object time) {
    return 'aujourd’hui à $time';
  }

  @override
  String desktopScheduleTomorrowAt(Object time) {
    return 'demain à $time';
  }

  @override
  String desktopScheduleOnAt(Object date, Object time) {
    return '$date à $time';
  }

  @override
  String get desktopScheduleHint => 'Le message partira tout seul à l’heure choisie — même fenêtre fermée, il sera envoyé au prochain démarrage.';

  @override
  String get desktopSchedulePickTime => 'Choisir l’heure…';

  @override
  String get desktopDevicesSearching => 'Recherche d’appareils…';

  @override
  String get desktopDevicesNoCameras => 'Aucune caméra trouvée. L’application n’a peut-être pas l’accès dans les réglages du système.';

  @override
  String get desktopDevicesNoMics => 'Aucun micro trouvé. L’application n’a peut-être pas l’accès dans les réglages du système.';

  @override
  String get desktopDevicesOutputHint => 'La sortie du son se choisit dans l’appel — par le chevron à côté de « Micro ». C’est là aussi que l’application bascule d’elle-même vers le casque quand on le branche.';

  @override
  String get desktopDevicesSystemDefault => 'Comme dans le système';

  @override
  String get desktopRailSettings => 'Réglages   Cmd ,';

  @override
  String get desktopRailConnected => 'Connecté';

  @override
  String get desktopRailConnecting => 'Connexion…';

  @override
  String get desktopRailOffline => 'Pas de connexion';

  @override
  String desktopRailProfile(Object status) {
    return 'Profil   Cmd P   ·   $status';
  }

  @override
  String get desktopEmojiSmileys => 'Frimousses et émotions';

  @override
  String get desktopEmojiPeople => 'Personnes et corps';

  @override
  String get desktopEmojiNature => 'Nature';

  @override
  String get desktopEmojiFood => 'Nourriture et boissons';

  @override
  String get desktopEmojiTravel => 'Voyages';

  @override
  String get desktopEmojiActivities => 'Activités';

  @override
  String get desktopEmojiObjects => 'Objets';

  @override
  String get desktopEmojiSymbols => 'Symboles';

  @override
  String get desktopEmojiFlags => 'Drapeaux';

  @override
  String get desktopEmojiOther => 'Autres';

  @override
  String get desktopLockedTitle => 'Secretly est verrouillé';

  @override
  String get desktopLockedTouchIdPrompt => 'Confirmez votre identité avec Touch ID pour continuer.';

  @override
  String get desktopLockedPasswordPrompt => 'Confirmez avec le mot de passe de l\'appareil pour continuer.';

  @override
  String get desktopLockedUnlock => 'Déverrouiller';

  @override
  String get desktopLockedWaiting => 'En attente de confirmation…';

  @override
  String get desktopLockedFailed => 'Impossible de confirmer votre identité.';

  @override
  String get desktopLockedNoService => 'Le service d\'identité n\'est pas disponible sur cet ordinateur. Redémarrez Secretly ou l\'ordinateur. Si cela ne suffit pas, écrivez au support depuis votre téléphone.';

  @override
  String get desktopEmojiTabEmoji => 'Émojis';

  @override
  String get desktopEmojiTabStickers => 'Stickers';

  @override
  String get desktopEmojiRecents => 'Récents';

  @override
  String get desktopEmojiNothingFound => 'Aucun résultat';

  @override
  String get desktopEmojiSearchHint => 'Rechercher un émoji';

  @override
  String get desktopStickersSearchHint => 'Rechercher des stickers';

  @override
  String get desktopGifSearchHint => 'Rechercher des GIF';

  @override
  String get desktopGifUnavailable => 'Les GIF ne sont pas disponibles dans cette fenêtre';

  @override
  String get desktopStickerPacksSoon => 'Packs de stickers bientôt';

  @override
  String get desktopCallFullscreen => 'Plein écran';

  @override
  String get desktopCallExitFullscreen => 'Quitter le plein écran';

  @override
  String get desktopCallDialing => 'Appel…';

  @override
  String get desktopCallEnded => 'Terminé';

  @override
  String desktopCallEncryptedFor(Object duration) {
    return 'Chiffré · $duration';
  }

  @override
  String get desktopCallReturn => 'Revenir';

  @override
  String get desktopCallInProgress => 'Appel en cours';

  @override
  String desktopCallInProgressWith(Object title) {
    return 'Appel en cours · $title';
  }

  @override
  String get desktopCallAnswer => 'Répondre';

  @override
  String get desktopCallAnswerVideo => 'Répondre avec la vidéo';

  @override
  String get desktopCallAnswerText => 'Par message';

  @override
  String get desktopTimeYesterday => 'hier';

  @override
  String get desktopForwardTitle => 'Transférer à…';

  @override
  String get desktopForwardSearchHint => 'Rechercher une discussion ou un salon';

  @override
  String get desktopForwardNoChats => 'Aucune discussion disponible';

  @override
  String get desktopForwardKindDirect => 'Discussion privée';

  @override
  String get desktopContactsSearchHint => 'Rechercher des contacts';

  @override
  String get desktopContactsEmpty => 'Personne pour l’instant. Ajoutez un contact par identifiant ou lien d’invitation.';

  @override
  String desktopContactsNothingFor(Object query) {
    return 'Aucun résultat pour « $query ».';
  }

  @override
  String get desktopContactsPick => 'Choisissez un contact';

  @override
  String get desktopContactsCardRight => 'La fiche apparaîtra à droite.';

  @override
  String get desktopContactsWrite => 'Écrire un message';

  @override
  String get desktopVideoTitle => 'Vidéo';

  @override
  String get desktopViewerCloseEsc => 'Fermer  Échap';

  @override
  String get desktopVideoPlayFailed => 'Impossible de lire la vidéo';

  @override
  String get desktopKeySpace => 'Espace';

  @override
  String get desktopWindowMinimize => 'Réduire';

  @override
  String get desktopWindowMaximize => 'Agrandir';

  @override
  String get desktopWindowClose => 'Fermer';

  @override
  String get desktopWindowBack => 'Retour';

  @override
  String get desktopWindowForward => 'Suivant';

  @override
  String get desktopSearchEverything => 'Discussions, personnes, messages, fichiers';

  @override
  String get desktopUnitB => 'o';

  @override
  String get desktopUnitKb => 'ko';

  @override
  String get desktopUnitMb => 'Mo';

  @override
  String get desktopUnitGb => 'Go';

  @override
  String get desktopUnitTb => 'To';

  @override
  String get desktopSyncDone => 'Synchronisé';

  @override
  String get desktopSyncSyncing => 'Synchronisation…';

  @override
  String get desktopSyncReconnecting => 'Reconnexion…';

  @override
  String get desktopDetailsShare => 'Partager';

  @override
  String get desktopDetailsHide => 'Masquer';

  @override
  String get desktopDetailsMore => 'Plus';

  @override
  String get desktopDetailsChangeCover => 'Changer la couverture';

  @override
  String desktopDetailsFrame(Object name) {
    return 'Cadre « $name »';
  }

  @override
  String get desktopApply => 'Appliquer';

  @override
  String get desktopAccentAppliesTo => 'Boutons, sélections et anneaux. La bulle garde son propre style — il se choisit plus bas.';

  @override
  String get desktopTranslateUnknownSource => 'Impossible de détecter la langue du message';

  @override
  String get desktopTranslateUnsupported => 'Le traducteur du système ne connaît pas cette paire de langues';

  @override
  String get desktopTranslateNeedsDownload => 'La langue n\'est pas téléchargée. Réglages Système → Général → Langue et région → Langues de traduction';

  @override
  String get desktopTranslateFailed => 'La traduction a échoué';

  @override
  String get desktopNewChatSearchHint => 'Rechercher dans les contacts';

  @override
  String get desktopNewChatNoContacts => 'Pas encore de contacts';

  @override
  String get desktopNewChatNobodyFound => 'Personne trouvée';

  @override
  String get desktopMentionEveryone => 'Tous les membres';

  @override
  String get desktopMentionAdmins => 'Administrateurs';

  @override
  String get desktopMentionEveryoneHint => 'Appeler tout le monde dans le salon';

  @override
  String get desktopMentionAdminsHint => 'Appeler le propriétaire et les administrateurs';

  @override
  String desktopClearForPeer(Object name) {
    return 'Effacer aussi l\'historique chez $name';
  }

  @override
  String get desktopClearForPeerHint => 'Les messages disparaîtront sur son appareil et sur tous les vôtres. C\'est irréversible.';

  @override
  String get desktopGifNoKey => 'GIF indisponibles : build sans clé GIPHY';

  @override
  String get desktopGifConnectionLost => 'La connexion a été interrompue. Réessayez';

  @override
  String get desktopNotesHint => 'Ce qu’il faut retenir de cette conversation…';

  @override
  String get desktopNotesPrivate => 'Visible par vous seul. Rien n\'est envoyé, rien n\'apparaît dans la conversation et rien n\'entre dans la sauvegarde — tout reste sur cet ordinateur, dans la même base chiffrée que les messages.';

  @override
  String get desktopEmojiSearchShort => 'Rechercher un émoji…';

  @override
  String get desktopNotifOpen => 'Ouvrir';

  @override
  String get desktopLinkPreviewLoading => 'Aperçu du lien…';

  @override
  String get desktopLinkPreviewOff => 'Sans aperçu';

  @override
  String get desktopDropToSend => 'Relâchez pour envoyer';

  @override
  String get desktopDropEncrypted => 'Les fichiers sont chiffrés avant l\'envoi';

  @override
  String get desktopDetailsPickChat => 'Choisissez une discussion';

  @override
  String get desktopDetailsEmptyHint => 'Les informations sur la personne ou le salon\ns’afficheront ici.';

  @override
  String get desktopMemberWrite => 'Écrire';

  @override
  String get desktopShowPanel => 'Afficher le panneau';

  @override
  String get desktopHidePanel => 'Masquer le panneau';

  @override
  String get desktopNotifOff => 'Les notifications sont désactivées';

  @override
  String get desktopSettingsSearchHint => 'Trouver un réglage';

  @override
  String get desktopUnlockPrompt => 'Déverrouiller Secretly';

  @override
  String get desktopEnableLockPrompt => 'Confirmez pour activer le verrouillage de Secretly';

  @override
  String get desktopRoomsNoneHintDot => 'Créez un salon depuis le téléphone — il apparaîtra ici tout seul.';

  @override
  String get desktopSplashLoading => 'Chargement du profil…';

  @override
  String get desktopOutgoingOnePhoto => 'Photo';

  @override
  String get desktopOutgoingOneVideo => 'Vidéo';

  @override
  String get desktopOutgoingOneAudio => 'Audio';

  @override
  String get desktopOutgoingOneFile => 'Fichier';

  @override
  String get desktopMenuSettings => 'Réglages…';

  @override
  String get desktopMenuEdit => 'Édition';

  @override
  String get desktopMenuUndo => 'Annuler';

  @override
  String get desktopMenuRedo => 'Rétablir';

  @override
  String get desktopMenuCut => 'Couper';

  @override
  String get desktopMenuPaste => 'Coller';

  @override
  String get desktopMenuSelectAll => 'Tout sélectionner';

  @override
  String get desktopMenuView => 'Présentation';

  @override
  String get desktopMenuWindow => 'Fenêtre';

  @override
  String get desktopMenuHelp => 'Aide';

  @override
  String get desktopMenuWebsite => 'Site web de Secretly';

  @override
  String get desktopContactsAddHint => 'Identifiant Secretly ou lien d’invitation';

  @override
  String get desktopContactsAdded => 'Contact ajouté';

  @override
  String get desktopContactsRenamed => 'Nom enregistré';

  @override
  String get desktopMenuCheckUpdates => 'Rechercher les mises à jour…';
}
