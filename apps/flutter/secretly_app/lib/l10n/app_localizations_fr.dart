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
}
