// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Secretly';

  @override
  String get starting => 'Startet…';

  @override
  String get encrypting => 'Verschlüsseln…';

  @override
  String errorPrefix(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get notificationsSection => 'Benachrichtigungen';

  @override
  String get languageSection => 'Sprache';

  @override
  String get comingSoon => 'Demnächst';

  @override
  String get idsTitle => 'IDs';

  @override
  String get profileIdLabel => 'Profil-ID';

  @override
  String get deviceIdLabel => 'Geräte-ID';

  @override
  String get profileIdShort => 'Profil';

  @override
  String get deviceIdShort => 'Gerät';

  @override
  String get copy => 'Kopieren';

  @override
  String get copied => 'Kopiert';

  @override
  String get copyBoth => 'Beide kopieren';

  @override
  String get openMyId => 'Meine ID öffnen';

  @override
  String get close => 'Schließen';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabGroups => 'Räume';

  @override
  String get tabContacts => 'Kontakte';

  @override
  String get tabProfile => 'Profil';

  @override
  String get accountSection => 'Konto';

  @override
  String get chatsSection => 'Chats';

  @override
  String get privacySection => 'Datenschutz';

  @override
  String get devicesSection => 'Geräte';

  @override
  String get systemSection => 'System';

  @override
  String get languageSystemDefault => 'Systemstandard';

  @override
  String languageSystemCurrent(Object language) {
    return 'System ($language)';
  }

  @override
  String get languageChooseAppLanguage => 'App-Sprache auswählen';

  @override
  String get languageAvailableWave1 => 'Verfügbar: Englisch, Russisch, Ukrainisch, Spanisch, Portugiesisch (Brasilien), Französisch und Deutsch. Du kannst auch der Systemsprache folgen.';

  @override
  String get languageMessageTranslation => 'Nachrichtenübersetzung';

  @override
  String get languageShowTranslateButton => 'Schaltfläche Übersetzen anzeigen';

  @override
  String get languageTranslateWholeChats => 'Ganze Chats übersetzen';

  @override
  String get favoritesTitle => 'Favoriten';

  @override
  String get favoritesSubtitle => 'Deine persönlichen Notizen';

  @override
  String get favoritesEmptyTitle => 'Noch keine Favoriten';

  @override
  String get favoritesEmptySubtitle => 'Sende Nachrichten, Dateien und Notizen hierher, um sie privat auf deinen Geräten zu behalten.';

  @override
  String get favoritesPersonalNotebookLabel => 'Persönliche Notizen';

  @override
  String get more => 'Mehr';

  @override
  String get stickersRecent => 'Neueste Sticker';

  @override
  String get searchStickers => 'Sticker suchen';

  @override
  String get noStickersFound => 'Keine Sticker gefunden';

  @override
  String get noRecentStickers => 'Deine neuesten Sticker erscheinen hier';

  @override
  String get cancelSelection => 'Auswahl abbrechen';

  @override
  String get chatsTitle => 'Chats';

  @override
  String get newChat => 'Neuer Chat';

  @override
  String get openContactsToStartChat => 'Öffne Kontakte, um einen Chat zu starten';

  @override
  String get noChatsYet => 'Noch keine Chats';

  @override
  String get openDemoChat => 'Demo-Chat öffnen';

  @override
  String get archive => 'Archivieren';

  @override
  String get unarchive => 'Aus Archiv holen';

  @override
  String get pin => 'Anheften';

  @override
  String get unpin => 'Lösen';

  @override
  String get clearHistory => 'Verlauf löschen';

  @override
  String archiveHeader(Object count) {
    return 'Archiv ($count)';
  }

  @override
  String deleteChatsConfirmTitle(Object count) {
    return '$count Chat(s) löschen?';
  }

  @override
  String get deleteChatsConfirmBody => 'Dies entfernt Chats nur von diesem Gerät.';

  @override
  String clearHistoryConfirmTitle(Object count) {
    return 'Verlauf für $count Chat(s) löschen?';
  }

  @override
  String get clearHistoryConfirmBody => 'Dies entfernt Nachrichten nur von diesem Gerät.';

  @override
  String get contactsTitle => 'Kontakte';

  @override
  String get contactsTab => 'Kontakte';

  @override
  String get requestsTab => 'Anfragen';

  @override
  String get addContact => 'Kontakt hinzufügen';

  @override
  String get deleteContact => 'Kontakt löschen';

  @override
  String get noContactsYet => 'Noch keine Kontakte';

  @override
  String get noRequests => 'Keine Anfragen';

  @override
  String get secretlyIdLabel => 'Secretly ID';

  @override
  String get secretlyIdHint => 'XXXX-XXXX-...-CHECK';

  @override
  String get nameOptionalLabel => 'Name (optional)';

  @override
  String get scanContactQrTitle => 'Kontakt-QR scannen';

  @override
  String get qrMissingSecretlyId => 'QR enthält keine Secretly ID';

  @override
  String get differentServerTitle => 'Anderer Server';

  @override
  String differentServerBody(Object qrServer, Object appServer) {
    return 'Dieser QR gehört zu einem anderen Server.\n\nQR-Server: $qrServer\nDiese App: $appServer\n\nInstalliere denselben APK/Server auf beiden Telefonen.';
  }

  @override
  String get contactActionProfileNotFound => 'Die Secretly ID wurde auf diesem Server nicht gefunden.';

  @override
  String get contactActionTransportBlocked => 'Diese Aktion ist nicht verfügbar, weil die App an einen anderen Server gebunden ist.';

  @override
  String get contactActionServiceUnavailable => 'Der Server ist gerade nicht verfügbar. Versuche es gleich erneut.';

  @override
  String get contactActionCallsDisabled => 'Anrufe sind in den Datenschutzeinstellungen deaktiviert.';

  @override
  String get contactActionCallsDisabledForContact => 'Anrufe sind für diesen Kontakt deaktiviert.';

  @override
  String get callServiceUnavailable => 'Der Anrufdienst ist gerade nicht verfügbar.';

  @override
  String get callAlreadyInProgress => 'Es läuft bereits ein anderer Anruf.';

  @override
  String get callIceUnavailable => 'Die sichere Anrufeinrichtung ist gerade nicht verfügbar. Versuche es gleich erneut.';

  @override
  String get callPermissionDenied => 'Der Zugriff auf Mikrofon oder Kamera ist blockiert. Erlaube die Berechtigungen und versuche es erneut.';

  @override
  String get callNegotiationFailed => 'Der sichere Anruf konnte nicht aufgebaut werden. Versuche es erneut.';

  @override
  String get callConnectionInterrupted => 'Die Anrufverbindung wurde unterbrochen. Versuche es erneut.';

  @override
  String get callActionGeneric => 'Der Anruf konnte nicht gestartet werden. Versuche es erneut.';

  @override
  String get callEncryptedBadge => 'Ende-zu-Ende-verschlüsselt';

  @override
  String get incomingVideoCall => 'Eingehender Videoanruf';

  @override
  String get incomingVoiceCall => 'Eingehender Sprachanruf';

  @override
  String get callDecline => 'Ablehnen';

  @override
  String get callConnectionUnstable => 'Verbindung instabil';

  @override
  String get callNetworkVeryWeak => 'Sehr schwaches Netzsignal';

  @override
  String get callNetworkWeak => 'Schwaches Netzsignal';

  @override
  String get callEnded => 'Anruf beendet';

  @override
  String get callReplacedByNewerAttempt => 'Anruf wurde durch einen neueren Versuch ersetzt';

  @override
  String get callDeclined => 'Anruf abgelehnt';

  @override
  String get callYouDeclined => 'Du hast abgelehnt';

  @override
  String get callNoAnswer => 'Keine Antwort';

  @override
  String get callConnectionError => 'Verbindungsfehler';

  @override
  String get callVideoUnavailable => 'Video nicht verfügbar';

  @override
  String get callWaitingForRemoteVideo => 'Warten auf Remote-Video...';

  @override
  String get callAttachingRemoteVideo => 'Remote-Video wird verbunden...';

  @override
  String get callStartingRemoteVideo => 'Remote-Video wird gestartet...';

  @override
  String get callRemoteVideoNotArriving => 'Remote-Video kommt nicht an';

  @override
  String get callRemoteVideoBindFailed => 'Remote-Videostream konnte nicht gebunden werden';

  @override
  String get callRemoteVideoNoFrames => 'Remote-Video ist verbunden, aber es werden keine Frames gerendert';

  @override
  String get callMinimize => 'Minimieren';

  @override
  String get callStatusCalling => 'Anrufen...';

  @override
  String get callStatusIncoming => 'Eingehend...';

  @override
  String get callStatusConnecting => 'Verbinden...';

  @override
  String get callStatusReconnecting => 'Erneut verbinden...';

  @override
  String get callStatusEnded => 'Beendet';

  @override
  String get callVideoCall => 'Videoanruf';

  @override
  String get callControlMute => 'Stumm';

  @override
  String get callControlSpeaker => 'Lautsprecher';

  @override
  String get callControlCamera => 'Kamera';

  @override
  String get callControlFlip => 'Wechseln';

  @override
  String get callControlStop => 'Stoppen';

  @override
  String get callControlShare => 'Teilen';

  @override
  String get callControlEnd => 'Beenden';

  @override
  String get contactActionGeneric => 'Die Aktion konnte nicht abgeschlossen werden. Versuche es erneut.';

  @override
  String get notificationTitleRoom => 'Raum';

  @override
  String get notificationTitleRequest => 'Anfrage';

  @override
  String get notificationTitleChat => 'Chat';

  @override
  String get notificationBodyNewMessage => 'Neue Nachricht';

  @override
  String get contactLookupUnavailable => 'Die Suche ist gerade nicht verfügbar. Versuche es gleich erneut.';

  @override
  String addContactFailed(Object error) {
    return 'Kontakt konnte nicht hinzugefügt werden: $error';
  }

  @override
  String deleteContactsConfirmTitle(Object count) {
    return '$count Kontakt(e) löschen?';
  }

  @override
  String get deleteContactsConfirmBody => 'Chats werden nicht gelöscht.';

  @override
  String get privacyTitle => 'Datenschutz';

  @override
  String get blockedUsersSubtitle => 'Blockierte Nutzer können dir keine Nachrichten zustellen (serverseitig erzwungen).';

  @override
  String get noBlockedUsers => 'Keine blockierten Nutzer';

  @override
  String unblockFailed(Object error) {
    return 'Entsperren fehlgeschlagen: $error';
  }

  @override
  String get diagIdentity => 'Identität';

  @override
  String get diagEndpoints => 'Endpoints';

  @override
  String get diagServerBinding => 'Serverbindung';

  @override
  String get diagMismatch => 'Abweichung: Profil gehört zu einem anderen Server. Verwende Einstellungen → Profil zurücksetzen.';

  @override
  String get diagStatus => 'Status';

  @override
  String get diagTimestamps => 'Zeitstempel';

  @override
  String get diagTips => 'Tipps';

  @override
  String get diagTipsBody => 'Wenn Nachrichten mit \"profile not found\" fehlschlagen:\n1) Stelle sicher, dass beide Telefone denselben APK/Server verwenden\n2) Füge den Kontakt erneut hinzu, indem du den QR scannst\n3) Wenn sich Endpoints geändert haben, verwende Profil zurücksetzen\n';

  @override
  String get secretlyUser => 'Secretly-Nutzer';

  @override
  String get onlineStatus => 'online';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get removePhoto => 'Foto entfernen';

  @override
  String get profileSectionTitle => 'Profil';

  @override
  String get myNicknameLabel => 'Mein Spitzname';

  @override
  String get myNicknameHint => 'z. B. Alex';

  @override
  String get includeNicknameInQr => 'Spitznamen in meinen QR aufnehmen';

  @override
  String get includeNicknameInQrSubtitle => 'Aus Datenschutzgründen standardmäßig aus. Wenn aktiviert, können Scanner dich automatisch benennen.';

  @override
  String verifyTitle(Object title) {
    return 'Verifizieren: $title';
  }

  @override
  String get scanVerifyQrTitle => 'Verifizierungs-QR scannen';

  @override
  String qrBelongsAnotherServer(Object server) {
    return 'QR gehört zu einem anderen Server: $server';
  }

  @override
  String get qrSecretlyIdMismatch => 'Die Secretly ID im QR stimmt nicht mit diesem Kontakt überein';

  @override
  String get qrMissingDeviceKeyInfo => 'Im QR fehlen Geräte-/Schlüsselinformationen';

  @override
  String get deviceNotCachedTapRefresh => 'Gerät nicht im Cache. Tippe zuerst auf Aktualisieren.';

  @override
  String get identityKeyMismatch => 'Identity Key stimmt nicht überein. Nicht verifizieren.';

  @override
  String get verifiedSuccess => 'Verifiziert ✅';

  @override
  String get refreshKeys => 'Keys aktualisieren';

  @override
  String get keysOfflineCannotFetch => 'Der Keys-Dienst ist offline. Kontaktschlüssel können gerade nicht abgerufen werden.';

  @override
  String get devicesLabel => 'Geräte';

  @override
  String get noDeviceKeysCachedYet => 'Noch keine Geräteschlüssel im Cache.';

  @override
  String deviceTitle(Object deviceId) {
    return 'Gerät $deviceId';
  }

  @override
  String deviceFpStatus(Object fp, Object status) {
    return 'fp: $fp\n$status';
  }

  @override
  String get verifiedLower => 'verifiziert';

  @override
  String get unverifiedLower => 'nicht verifiziert';

  @override
  String get keysOfflineIdTemporary => 'Der Keys-Dienst ist offline. Die ID kann im Entwicklungsmodus temporär sein.';

  @override
  String get serverKeysLabel => 'Server (Keys)';

  @override
  String get nicknameLabel => 'Spitzname';

  @override
  String get identityFingerprintLabel => 'Identitäts-Fingerabdruck';

  @override
  String get scanToAddVerifyContact => 'Scannen, um diesen Kontakt hinzuzufügen/zu verifizieren';

  @override
  String get mySecretlyId => 'Meine Secretly ID';

  @override
  String get deviceId => 'Geräte-ID';

  @override
  String get recoveryKit => 'Recovery Kit';

  @override
  String get safeBackupTitle => 'Safe Backup';

  @override
  String get safeBackupSubtitle => 'Verschlüsseltes Safe Backup auf dem Server';

  @override
  String get safeBackupIntro => 'Erstelle lokal oder auf dem Server ein verschlüsseltes Backup. Du kannst es später aus einer Datei oder mit einer Secretly ID wiederherstellen.';

  @override
  String get safeBackupUploadNow => 'Backup jetzt hochladen';

  @override
  String get safeBackupRestoreFromServer => 'Vom Server wiederherstellen';

  @override
  String get safeBackupRestoreTitle => 'Aus Server-Backup wiederherstellen';

  @override
  String get safeBackupRestoreConfirmTitle => 'Konto wiederherstellen?';

  @override
  String get safeBackupRestoreConfirmBody => 'Dies entfernt lokale Chats/Kontakte auf diesem Gerät und stellt das Konto aus dem ausgewählten Backup wieder her. Die App wird automatisch neu gestartet.';

  @override
  String get safeBackupUploaded => 'Backup hochgeladen';

  @override
  String get safeBackupUploadFailed => 'Backup-Upload fehlgeschlagen';

  @override
  String safeBackupUploadFailedWithError(Object error) {
    return 'Backup-Upload fehlgeschlagen: $error';
  }

  @override
  String get safeBackupNotFound => 'Für diese Secretly ID wurde kein Server-Backup gefunden';

  @override
  String get exportRecoveryKit => 'Recovery Kit exportieren';

  @override
  String get exportRecoveryKitSubtitle => 'Verschlüsselter QR zur Kontowiederherstellung';

  @override
  String get restoreRecoveryKit => 'Aus Recovery Kit wiederherstellen';

  @override
  String get restoreRecoveryKitSubtitle => 'Löscht lokale Daten und stellt diese Secretly ID wieder her';

  @override
  String get recoveryPasswordTitle => 'Recovery Kit-Passwort';

  @override
  String get password => 'Passwort';

  @override
  String get confirmPassword => 'Passwort bestätigen';

  @override
  String get export => 'Exportieren';

  @override
  String get scanQr => 'QR scannen';

  @override
  String get invalidRecoveryKit => 'Ungültiges Recovery Kit';

  @override
  String get wrongPassword => 'Falsches Passwort';

  @override
  String get restoreConfirmTitle => 'Konto wiederherstellen?';

  @override
  String get restoreConfirmBody => 'Dies entfernt lokale Chats/Kontakte auf diesem Gerät und stellt das Konto aus dem Recovery Kit wieder her.';

  @override
  String get restore => 'Wiederherstellen';

  @override
  String get darkTheme => 'Dunkles Design';

  @override
  String get darkThemeSubtitle => 'Im dunklen Modus denselben Akzentfarbton verwenden.';

  @override
  String get blockUnverified => 'Senden an nicht verifizierte Kontakte blockieren';

  @override
  String get blockUnverifiedSubtitle => 'Strenger Modus: in Einzelchats nur an Kontakte senden, deren Schlüssel du selbst geprüft hast. Gilt nicht für Gruppen.';

  @override
  String get blockedUsers => 'Blockierte Nutzer';

  @override
  String get resetProfile => 'Profil zurücksetzen';

  @override
  String get resetProfileSubtitle => 'Server-/Kontoabweichung durch Erstellen einer neuen Secretly ID beheben';

  @override
  String get resetProfileDialogTitle => 'Profil zurücksetzen?';

  @override
  String get resetProfileDialogBody => 'Dies entfernt lokale Chats/Kontakte/Anfragen auf diesem Gerät und erstellt eine neue Secretly ID.\n\nVerwende dies, wenn du APK/Server geändert hast und Nachrichten nicht mehr funktionieren.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get ok => 'OK';

  @override
  String get add => 'Hinzufügen';

  @override
  String get delete => 'Löschen';

  @override
  String get clear => 'Leeren';

  @override
  String get block => 'Blockieren';

  @override
  String get unblock => 'Entsperren';

  @override
  String get accept => 'Annehmen';

  @override
  String get verify => 'Verifizieren';

  @override
  String get menu => 'Menü';

  @override
  String get search => 'Suchen';

  @override
  String get queryLabel => 'Suchanfrage';

  @override
  String get messageHint => 'Nachricht';

  @override
  String get notificationActionMarkRead => 'Als gelesen markieren';

  @override
  String get addCaption => 'Beschriftung hinzufügen';

  @override
  String get uploadCanceled => 'Upload abgebrochen';

  @override
  String get attachmentFinalizeTimeout => 'Das Netzwerk ist instabil: Der Upload ist abgeschlossen, aber die Sendebestätigung ist abgelaufen. Versuche es erneut.';

  @override
  String get attachmentTransferUnavailable => 'Der Anhang konnte gerade nicht übertragen werden. Prüfe Internet/Server und versuche es erneut.';

  @override
  String get attachmentSendUnavailable => 'Das Senden von Anhängen ist noch nicht bereit. Versuche es erneut.';

  @override
  String get attachmentContactSyncPending => 'Warten auf Identitätssynchronisierung des Kontakts. Bitte den Kontakt, noch eine Nachricht zu senden, und versuche es erneut.';

  @override
  String get attachmentContactBlocked => 'Dieser Kontakt ist blockiert.';

  @override
  String get attachmentRecipientNotFound => 'Das Empfängerprofil wurde auf diesem Server nicht gefunden. Prüfe die Secretly ID und stelle sicher, dass beide Geräte denselben Server verwenden.';

  @override
  String get attachmentRecipientNoDevices => 'Der Empfänger hat noch keine registrierten Geräte. Bitte den Kontakt, Secretly zu öffnen, und versuche es erneut.';

  @override
  String get attachmentNoDeliverableDevices => 'Der Anhang konnte an keines der Empfängergeräte zugestellt werden. Versuche es erneut.';

  @override
  String get attachmentActionGeneric => 'Der Anhang konnte nicht gesendet werden. Versuche es erneut.';

  @override
  String get send => 'Senden';

  @override
  String get attach => 'Anhängen';

  @override
  String get photo => 'Foto';

  @override
  String get video => 'Video';

  @override
  String get file => 'Datei';

  @override
  String get music => 'Musik';

  @override
  String get attachment => 'Anhang';

  @override
  String get downloading => 'Herunterladen…';

  @override
  String downloadFailed(Object error) {
    return 'Download fehlgeschlagen: $error';
  }

  @override
  String savedTo(Object path) {
    return 'Gespeichert unter: $path';
  }

  @override
  String get noMessagesYet => 'Noch keine Nachrichten';

  @override
  String get decrypting => 'Entschlüsseln…';

  @override
  String get uploading => 'Hochladen…';

  @override
  String get uploadTimedOut => 'Der Upload hat das Zeitlimit überschritten. Prüfe Internet/Server und versuche es erneut.';

  @override
  String uploadingBytes(Object sent, Object total) {
    return 'Hochgeladen $sent / $total Bytes';
  }

  @override
  String get requestsInfo => 'Dieser Chat ist unter Anfragen. Nimm an, um zu antworten, oder blockiere, um ihn zu ignorieren.';

  @override
  String get verifyRequired => 'Verifizierung erforderlich';

  @override
  String get verifyContact => 'Kontakt verifizieren';

  @override
  String get muteNotifications => 'Benachrichtigungen stummschalten';

  @override
  String get unmuteNotifications => 'Benachrichtigungen aktivieren';

  @override
  String get setContactPhoto => 'Kontaktfoto festlegen';

  @override
  String get removeContactPhoto => 'Kontaktfoto entfernen';

  @override
  String get blockUser => 'Nutzer blockieren';

  @override
  String get unblockUser => 'Nutzer entsperren';

  @override
  String get deleteChat => 'Chat löschen';

  @override
  String get missingRecipient => 'Empfänger fehlt';

  @override
  String get contactNotVerified => 'Der Sicherheitscode hat sich geändert. Prüfe ihn, um weiter zu schreiben.';

  @override
  String get safetyNumberChangedTitle => 'Sicherheitscode hat sich geändert';

  @override
  String get safetyNumberChangedBody => 'Du hast den Code dieses Kontakts früher geprüft. Jetzt sind die Schlüssel neu — das passiert meist nach einer Neuinstallation oder einem Gerätewechsel. Der Chat bleibt in jedem Fall verschlüsselt. Vergleiche den Code erneut, wenn du sicher sein willst, dass es weiterhin diese Person ist.';

  @override
  String get safetyNumberStrictBody => 'Du hast „Senden an Unverifizierte blockieren“ aktiviert. Vergleiche den Code dieses Kontakts, um ihm Nachrichten zu senden.';

  @override
  String get sendAnyway => 'Trotzdem senden';

  @override
  String get alsoDeleteChat => 'Chat ebenfalls löschen';

  @override
  String get unblockUserConfirmTitle => 'Nutzer entsperren?';

  @override
  String get blockUserConfirmTitle => 'Nutzer blockieren?';

  @override
  String get deleteChatConfirmTitle => 'Chat löschen?';

  @override
  String get deleteChatConfirmBody => 'Dies entfernt den Chat nur von diesem Gerät.';

  @override
  String attachFailed(Object error) {
    return 'Anhängen fehlgeschlagen: $error';
  }

  @override
  String sendFailed(Object error) {
    return 'Senden fehlgeschlagen: $error';
  }

  @override
  String actionFailed(Object error) {
    return 'Aktion fehlgeschlagen: $error';
  }

  @override
  String get roomPolicyNotMember => 'Du bist kein Teilnehmer dieses Raums mehr.';

  @override
  String get roomPolicyAdminsOnly => 'Nur Raumeigentümer und Admins können das in diesem Raum tun.';

  @override
  String get roomPolicyTextMessagesDisabled => 'Deine Rolle kann in diesem Raum keine Textnachrichten senden.';

  @override
  String get roomPolicyMediaDisabled => 'Deine Rolle kann in diesem Raum keine Medien senden.';

  @override
  String get roomPolicyReactionsDisabled => 'Reaktionen sind in diesem Raum deaktiviert.';

  @override
  String get roomPolicyReactionNotAllowed => 'Diese Reaktion ist in diesem Raum nicht erlaubt.';

  @override
  String get roomPolicyPinDenied => 'Nur Admins können Nachrichten in diesem Raum anheften.';

  @override
  String get roomPolicyAddMembersDenied => 'Nur Admins können Teilnehmer zu diesem Raum hinzufügen.';

  @override
  String get roomPolicyChangeInfoDenied => 'Nur Admins können das Gruppenprofil ändern.';

  @override
  String roomPolicySlowMode(Object seconds) {
    return 'Langsamer Modus ist aktiviert. Versuche es in $seconds s erneut.';
  }

  @override
  String get noMatches => 'Keine Treffer';

  @override
  String attachmentTooLarge(Object mb) {
    return 'Der Anhang ist zu groß ($mb MB).';
  }

  @override
  String get attachmentFileMissing => 'Die Datei ist nicht mehr verfügbar.';

  @override
  String foundPrefix(Object hit) {
    return 'Gefunden: $hit';
  }

  @override
  String get contactDetailsChat => 'Chat';

  @override
  String get contactDetailsSound => 'Ton';

  @override
  String get contactDetailsCall => 'Anruf';

  @override
  String get contactDetailsVideo => 'Video';

  @override
  String get contactDetailsUsernameLabel => 'Benutzername';

  @override
  String get contactDetailsAddToContacts => 'Zu Kontakten hinzufügen';

  @override
  String get contactDetailsMediaTab => 'Medien';

  @override
  String get contactDetailsFilesTab => 'Dateien';

  @override
  String get contactDetailsNoMedia => 'Keine Medien';

  @override
  String get contactDetailsNoFiles => 'Keine Dateien';

  @override
  String get contactDetailsStatusRecently => 'zuletzt kürzlich gesehen';

  @override
  String contactDetailsStatusAt(Object time) {
    return 'zuletzt um $time gesehen';
  }

  @override
  String get contactDetailsAutoDelete => 'Automatisch löschen';

  @override
  String get contactDetailsShareContact => 'Kontakt teilen';

  @override
  String get contactDetailsEditContact => 'Kontakt bearbeiten';

  @override
  String get contactDetailsDeleteContact => 'Kontakt löschen';

  @override
  String get contactDetailsSendGift => 'Geschenk senden';

  @override
  String get contactDetailsStartSecretChat => 'Geheimen Chat starten';

  @override
  String get contactDetailsCreateShortcut => 'Verknüpfung erstellen';

  @override
  String get contactDetailsNameLabel => 'Name';

  @override
  String get contactDetailsSave => 'Speichern';

  @override
  String get contactDetailsDeleteConfirmTitle => 'Kontakt löschen?';

  @override
  String get contactAutoDeleteOff => 'Aus';

  @override
  String get contactAutoDelete1Day => '24 Stunden';

  @override
  String get contactAutoDelete7Days => '7 Tage';

  @override
  String get contactAutoDelete30Days => '30 Tage';

  @override
  String get contactEditTitle => 'Kontakt bearbeiten';

  @override
  String get contactEditDone => 'FERTIG';

  @override
  String get contactEditNameLabel => 'Name';

  @override
  String get contactEditAssignEmoji => 'Emoji zuweisen';

  @override
  String get contactEditClearEmoji => 'Emoji entfernen';

  @override
  String get contactEditSetPhoto => 'Foto festlegen';

  @override
  String get chatMenuReply => 'Antworten';

  @override
  String get chatMenuCopy => 'Kopieren';

  @override
  String get chatMenuForward => 'Weiterleiten';

  @override
  String get chatMenuPin => 'Anheften';

  @override
  String get chatMenuDelete => 'Löschen';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get diagnostics => 'Diagnose';

  @override
  String get diagnosticsSubtitle => 'Status, Bindung, Zeitstempel';

  @override
  String get sendLater => 'Später senden';

  @override
  String get sendSilently => 'Ohne Ton senden';

  @override
  String scheduledSendToday(Object time) {
    return 'Heute um $time senden';
  }

  @override
  String scheduledSendOn(Object date, Object time) {
    return 'Am $date um $time senden';
  }

  @override
  String get repeatNever => 'Nie';

  @override
  String get repeat => 'Wiederholen';

  @override
  String get onboardingBackTooltip => 'Zurück';

  @override
  String get onboardingWelcomeTitle => 'Willkommen!';

  @override
  String get onboardingWelcomeSubtitle => 'Ein Messenger der nächsten Generation.\nVolle Privatsphäre. Keine Kompromisse.';

  @override
  String get onboardingCreateAccount => 'Neues Konto erstellen';

  @override
  String get onboardingAlreadyHaveAccount => 'Ich habe bereits ein Konto';

  @override
  String get onboardingFeatureE2eTitle => 'E2E-Verschlüsselung';

  @override
  String get onboardingFeatureE2eBody => 'Nachrichten werden auf deinem Gerät verschlüsselt. Nur du hast die Schlüssel.';

  @override
  String get onboardingFeaturePrivacyTitle => 'Vollständige Anonymität';

  @override
  String get onboardingFeaturePrivacyBody => 'Keine Telefonnummer. Keine Verknüpfung mit persönlichen Daten.';

  @override
  String get onboardingFeatureRelayTitle => 'Keine Vermittler';

  @override
  String get onboardingFeatureRelayBody => 'Der Relay-Server speichert keine Nachrichten. Er leitet sie nur weiter.';

  @override
  String get onboardingProfileTitle => 'Dein Profil';

  @override
  String get onboardingProfileSubtitle => 'So sehen dich andere Nutzer';

  @override
  String get onboardingProfileNameSection => 'Profilname';

  @override
  String get onboardingProfileNameHint => 'Dein Name oder Pseudonym';

  @override
  String get onboardingNotificationsSection => 'Benachrichtigungen';

  @override
  String get onboardingMessageNotificationsTitle => 'Nachrichtenbenachrichtigungen';

  @override
  String get onboardingMessageNotificationsSubtitle => 'Push-Benachrichtigungen von Secretly erhalten';

  @override
  String get onboardingIncomingCallsTitle => 'Eingehende Anrufe';

  @override
  String get onboardingIncomingCallsSubtitle => 'Anrufe von Kontakten annehmen';

  @override
  String get continueAction => 'Weiter';

  @override
  String get onboardingBackupSaveFailed => 'Backup-Einstellungen konnten nicht gespeichert werden';

  @override
  String get backupPasswordRequirements => 'Nutze mindestens 8 ASCII-Zeichen, einen Großbuchstaben und ein Sonderzeichen. Keine Leerzeichen am Anfang oder Ende.';

  @override
  String backupPasswordTooShort(Object minLength) {
    return 'Das Passwort muss mindestens $minLength Zeichen lang sein.';
  }

  @override
  String backupPasswordTooLong(Object maxLength) {
    return 'Das Passwort darf höchstens $maxLength Zeichen lang sein.';
  }

  @override
  String get backupPasswordNonAscii => 'Verwende nur lateinische Buchstaben, Ziffern und ASCII-Symbole.';

  @override
  String get backupPasswordOuterWhitespace => 'Entferne Leerzeichen am Anfang oder Ende des Passworts.';

  @override
  String get backupPasswordMissingUppercase => 'Füge mindestens einen Großbuchstaben A-Z hinzu.';

  @override
  String get backupPasswordMissingSpecial => 'Füge mindestens ein Sonderzeichen hinzu, z. B. !, # oder ?.';

  @override
  String get onboardingBackupPasswordTitle => 'Backup-Passwort';

  @override
  String get onboardingPasswordsDoNotMatch => 'Die Passwörter stimmen nicht überein';

  @override
  String get onboardingBackupTitle => 'Backups';

  @override
  String get onboardingBackupSubtitle => 'Schütze deine Chats vor Datenverlust.\nAuch beim Gerätewechsel.';

  @override
  String get onboardingAutoBackupSection => 'Automatisches Backup';

  @override
  String get onboardingAutoBackupTitle => 'Auto-Backup';

  @override
  String get onboardingAutoBackupSubtitle => 'Automatisch ein Backup speichern';

  @override
  String get onboardingStorageTypeSection => 'Speichertyp';

  @override
  String get onboardingBackupMediaTitle => 'Medien sichern';

  @override
  String get onboardingBackupMediaSubtitle => 'Fotos, Videos, Dateien und Avatare werden nur in lokalen Backups eingeschlossen';

  @override
  String get onboardingFrequencySection => 'Häufigkeit';

  @override
  String get onboardingEnterSecretly => 'Secretly öffnen';

  @override
  String get onboardingSkipBackup => 'Backup-Einrichtung überspringen';

  @override
  String get onboardingSecretlyIdCopied => 'Secretly ID kopiert';

  @override
  String get onboardingRegistrationCompleteTitle => 'Registrierung abgeschlossen';

  @override
  String get onboardingRegistrationCompleteSubtitle => 'Speichere deine Secretly ID jetzt. Du brauchst sie, um Konto und Backup auf einem neuen Gerät wiederherzustellen.';

  @override
  String get onboardingYourSecretlyId => 'Deine Secretly ID';

  @override
  String get onboardingCopyId => 'ID kopieren';

  @override
  String get onboardingRecoveryWarning => 'Ohne Secretly ID und Backup-Passwort kann das Server-Backup nicht wiederhergestellt werden. Speichere die ID an einem sicheren Ort und vergiss das Passwort nicht.';

  @override
  String get onboardingStorageCloud => 'Cloud';

  @override
  String get onboardingStorageCloudSubtitle => 'Auf dem Secretly-Server';

  @override
  String get onboardingStorageLocal => 'Lokal';

  @override
  String get onboardingStorageLocalSubtitle => 'Auf diesem Gerät';

  @override
  String get onboardingInterval6Hours => '6 Stunden';

  @override
  String get onboardingInterval12Hours => '12 Stunden';

  @override
  String get onboardingIntervalEveryDay => 'Jeden Tag';

  @override
  String get onboardingIntervalEvery3Days => 'Alle 3 Tage';

  @override
  String get onboardingIntervalWeekly => 'Einmal pro Woche';

  @override
  String get onboardingBackupLocalCandidate => 'Lokales Secretly-Backup';

  @override
  String get onboardingDownloads => 'Downloads';

  @override
  String get onboardingDeviceFolder => 'Geräteordner';

  @override
  String get onboardingNoBackupsFound => 'Keine Backups auf diesem Gerät gefunden';

  @override
  String get onboardingFoundBackups => 'Gefundene Backups';

  @override
  String get onboardingNoBackupsFoundBody => 'Secretly hat lokale App-Backups und den Downloads-Ordner geprüft. Wenn die Datei woanders liegt, wähle sie manuell aus.';

  @override
  String get chooseManually => 'Manuell auswählen';

  @override
  String get onboardingChooseBackupFileTitle => 'Secretly-Backup-Datei auswählen';

  @override
  String get onboardingReadBackupFailed => 'Backup-Datei konnte nicht gelesen werden';

  @override
  String get onboardingServerBackupNotFound => 'Backup wurde auf dem Server nicht gefunden';

  @override
  String get onboardingRestoreThisBackupTitle => 'Dieses Backup wiederherstellen?';

  @override
  String get onboardingRestoreThisBackupBody => 'Die aktuellen lokalen Daten auf diesem Gerät werden ersetzt.';

  @override
  String onboardingSecretlyIdSummary(Object profileId) {
    return 'Secretly ID: $profileId';
  }

  @override
  String onboardingContactsSummary(Object count) {
    return 'Kontakte: $count';
  }

  @override
  String onboardingMessagesSummary(Object count) {
    return 'Nachrichten: $count';
  }

  @override
  String onboardingChatsSummary(Object count) {
    return 'Chats: $count';
  }

  @override
  String onboardingMediaFilesSummary(Object count) {
    return 'Mediendateien: $count';
  }

  @override
  String get onboardingBrokenBackup => 'Beschädigte oder ungültige Backup-Datei';

  @override
  String get onboardingRestoreFailed => 'Wiederherstellung fehlgeschlagen. Versuche es erneut.';

  @override
  String get onboardingRestoreLoginTitle => 'Bei deinem Konto anmelden';

  @override
  String get onboardingRestoreLoginSubtitle => 'Stelle Chats und Einstellungen\naus einem zuvor erstellten Backup wieder her.';

  @override
  String get onboardingRestoreMediaSubtitle => 'Für künftige lokale Backups: Fotos, Videos, Dateien und Avatare werden nur hinzugefügt, wenn dies aktiviert ist.';

  @override
  String get onboardingRestoreFromCloudTitle => 'Aus der Secretly-Cloud';

  @override
  String get onboardingRestoreFromCloudSubtitle => 'Gib deine Secretly ID und das Backup-Passwort ein; die Daten werden vom Server geladen';

  @override
  String get onboardingRestoreFromDeviceTitle => 'Backup auf diesem Gerät finden';

  @override
  String get onboardingRestoreFromDeviceSubtitle => 'Secretly prüft lokale Backups und Downloads automatisch';

  @override
  String get onboardingRestoring => 'Wiederherstellen...';

  @override
  String get onboardingRestoreFromServerTitle => 'Vom Server wiederherstellen';

  @override
  String get callRecordOutgoingVideoCall => 'Ausgehender Videoanruf';

  @override
  String get callRecordOutgoingCall => 'Ausgehender Anruf';

  @override
  String get callRecordIncomingVideoCall => 'Eingehender Videoanruf';

  @override
  String get callRecordIncomingCall => 'Eingehender Anruf';

  @override
  String get callRecordMissedCall => 'Verpasster Anruf';

  @override
  String get callRecordDeclinedCall => 'Anruf abgelehnt';

  @override
  String get callRecordBusy => 'Besetzt';

  @override
  String get callRecordFailed => 'Anruf fehlgeschlagen';

  @override
  String get callRecordCanceled => 'Anruf abgebrochen';

  @override
  String get callRecordOngoing => 'Laufender Anruf';

  @override
  String get safeBackupInvalidBackup => 'Ungültiges Secretly-Backup';

  @override
  String get recoveryKitPrepareFailed => 'Recovery Kit konnte auf diesem Gerät nicht vorbereitet werden.';

  @override
  String safeBackupPreviewProfileId(String profileId) {
    return 'Secretly-ID: $profileId';
  }

  @override
  String safeBackupPreviewContacts(int count) {
    return 'Kontakte: $count';
  }

  @override
  String safeBackupPreviewServer(String server) {
    return 'Server: $server';
  }

  @override
  String get safeBackupPreviewTitle => 'Backup-Vorschau:';

  @override
  String get safeBackupSavedToFiles => 'Backup in Secretly-Dateien gespeichert';

  @override
  String get safeBackupExportCanceled => 'Backup-Export abgebrochen';

  @override
  String safeBackupExportFailed(Object error) {
    return 'Backup konnte nicht exportiert werden: $error';
  }

  @override
  String get safeBackupCreateDialogTitle => 'Backup erstellen';

  @override
  String get safeBackupServerDestination => 'Server-Backup';

  @override
  String get safeBackupLocalDestination => 'Lokales Backup';

  @override
  String get safeBackupRestoreDialogTitle => 'Backup wiederherstellen';

  @override
  String get safeBackupRestoreFromDevice => 'Vom Gerät wiederherstellen';

  @override
  String get safeBackupDownloadsLocation => 'Downloads';

  @override
  String get safeBackupDeviceFolderLocation => 'Geräteordner';

  @override
  String get safeBackupChooseManualHint => 'Secretly hat lokale App-Backups und den Ordner Downloads automatisch geprüft. Wenn die Datei woanders liegt, kannst du sie manuell auswählen.';

  @override
  String get safeBackupChooseManually => 'Manuell auswählen';

  @override
  String safeBackupReadFileFailed(Object error) {
    return 'Backup-Datei konnte nicht gelesen werden: $error';
  }

  @override
  String get safeBackupFrequencyTitle => 'Speicherhäufigkeit';

  @override
  String get saveAction => 'Speichern';

  @override
  String get safeBackupEnableAutoTitle => 'Auto-Backup aktivieren';

  @override
  String get safeBackupEnableAutoSubtitle => 'Wird in der App ausgeführt, wenn eine Verbindung besteht; mit deinem Passwort verschlüsselt';

  @override
  String get safeBackupUploadToServer => 'Auf Server hochladen';

  @override
  String get safeBackupSaveOnDevice => 'Auf diesem Gerät speichern';

  @override
  String get safeBackupPasswordConfigured => 'Auto-Backup-Passwort: eingerichtet';

  @override
  String get safeBackupPasswordNotSet => 'Auto-Backup-Passwort: nicht festgelegt';

  @override
  String get safeBackupPasswordSaved => 'Auto-Backup-Passwort gespeichert';

  @override
  String genericFailed(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get safeBackupSetPassword => 'Passwort festlegen';

  @override
  String get safeBackupPasswordRemoved => 'Auto-Backup-Passwort entfernt';

  @override
  String get safeBackupClearPassword => 'Passwort löschen';

  @override
  String get safeBackupRunRequested => 'Auto-Backup angefordert';

  @override
  String get safeBackupRunNow => 'Auto-Backup jetzt ausführen';

  @override
  String safeBackupLastAutoBackup(String time) {
    return 'Letztes Auto-Backup: $time';
  }

  @override
  String get safeBackupLastAutoBackupNever => 'Letztes Auto-Backup: nie';

  @override
  String safeBackupLastDeviceBackup(String time) {
    return 'Letztes Geräte-Backup: $time';
  }

  @override
  String safeBackupLastAutoBackupError(Object error) {
    return 'Auto-Backup-Fehler: $error';
  }

  @override
  String get securityScopeAppObject => 'die App';

  @override
  String get securityScopePersonalObject => 'persönliche Chats';

  @override
  String get securityUnlockAppTitle => 'App entsperren';

  @override
  String get securityUnlockPersonalTitle => 'Persönliche Chats entsperren';

  @override
  String get securityUnlockFingerprintAutoSubtitle => 'Die Entsperrung per Fingerabdruck startet automatisch. Falls nötig, kannst du unten dein Passwort verwenden.';

  @override
  String get securityUnlockBiometricPatternAutoSubtitle => 'Die native Biometrie startet zuerst automatisch. Falls nötig, kannst du unten dein Muster verwenden.';

  @override
  String get securityUnlockNativeSubtitle => 'Bestätige den Zugriff mit der nativen Geräteauthentifizierung.';

  @override
  String securityUnlockPasswordSubtitle(String scopeName) {
    return 'Gib dein Passwort ein, um $scopeName zu öffnen.';
  }

  @override
  String securityUnlockPatternSubtitle(String scopeName) {
    return 'Zeichne dein Muster, um auf $scopeName zuzugreifen.';
  }

  @override
  String get securityUnlockBiometricSubtitle => 'Bestätige deine Identität mit der nativen Geräteauthentifizierung.';

  @override
  String get securityUnlockAppBiometricReason => 'Authentifizieren, um die App zu entsperren';

  @override
  String get securityUnlockPersonalBiometricReason => 'Authentifizieren, um persönliche Chats zu öffnen';

  @override
  String get securityUnlockPasswordMismatch => 'Das Passwort stimmt nicht überein. Versuche es erneut.';

  @override
  String get securityUnlockPatternMismatch => 'Das Muster stimmt nicht überein.';

  @override
  String get securityUnlockNativeIncomplete => 'Die native Authentifizierung wurde nicht abgeschlossen.';

  @override
  String get securityPasswordContinueHint => 'Gib dein Passwort ein, um fortzufahren';

  @override
  String get securityUseFingerprint => 'Fingerabdruck verwenden';

  @override
  String get securityUsePassword => 'Passwort verwenden';

  @override
  String get securityClearPattern => 'Muster löschen';

  @override
  String get securityConnectFourDots => 'Verbinde mindestens 4 Punkte.';

  @override
  String get securityPasswordMinFourChars => 'Verwende mindestens 4 Zeichen.';

  @override
  String get securityPasswordsMismatchFull => 'Die Passwörter stimmen nicht überein.';

  @override
  String securityPasswordSetupTitle(String scopeName) {
    return 'Passwort für $scopeName';
  }

  @override
  String get securityPasswordSetupDescription => 'Das Passwort wird nur im sicheren Gerätespeicher abgelegt.';

  @override
  String get securityNewPassword => 'Neues Passwort';

  @override
  String get securityRepeatPassword => 'Passwort wiederholen';

  @override
  String get securitySavePassword => 'Passwort speichern';

  @override
  String get securityPatternSetupInstruction => 'Zeichne ein Muster mit mindestens 4 Punkten.';

  @override
  String get securityPatternSetupRepeat => 'Wiederhole das Muster zur Bestätigung.';

  @override
  String get securityPatternMinFourDots => 'Verwende mindestens 4 Punkte.';

  @override
  String get securityPatternMismatchStartOver => 'Die Muster stimmen nicht überein. Beginne erneut.';

  @override
  String securityPatternSetupTitle(String scopeName) {
    return 'Muster für $scopeName';
  }

  @override
  String get securityStartOver => 'Neu beginnen';

  @override
  String get securityTitle => 'Sicherheit';

  @override
  String get securityNativeAuthentication => 'Native Authentifizierung';

  @override
  String get securityReady => 'Bereit';

  @override
  String get securityUnavailable => 'Nicht verfügbar';

  @override
  String get securityNativeAvailableDescription => 'Wird für Face ID, Fingerabdruck und native Geräteauthentifizierung verwendet.';

  @override
  String get securityNativeUnavailableDescription => 'Biometrie oder native Geräteauthentifizierung ist auf diesem Gerät gerade nicht verfügbar.';

  @override
  String get securityAppLockTitle => 'App-Sperre';

  @override
  String get securityAppLockDescription => 'Schützt den App-Zugriff und kann erneut sperren, wenn die App ausgeblendet wird.';

  @override
  String get securityPersonalChatsTitle => 'Persönliche Chats';

  @override
  String get securityPersonalChatsDescription => 'Schützt den versteckten Bereich Persönlich und den direkten Einstieg in persönliche Chats.';

  @override
  String get securityAuthEnableAppLockReason => 'Authentifizieren, um die App-Sperre zu aktivieren';

  @override
  String get securityAuthChangeSettingsReason => 'Authentifizieren, um Sicherheitseinstellungen zu ändern';

  @override
  String get securityAuthProtectPersonalReason => 'Authentifizieren, um persönliche Chats zu schützen';

  @override
  String get securityAuthChangePersonalReason => 'Authentifizieren, um den Schutz persönlicher Chats zu ändern';

  @override
  String get securityNativeUnavailableError => 'Native Authentifizierung ist auf diesem Gerät nicht verfügbar.';

  @override
  String get securityBiometricCancelled => 'Biometrische Bestätigung wurde abgebrochen.';

  @override
  String get securityProtectionMode => 'Schutzmodus';

  @override
  String get securityProtectionModeSubtitle => 'Wähle, wie der Zugriff geschützt werden soll.';

  @override
  String get securityProtectionModeDescription => 'Passwörter und Muster werden nur als starke Hashes im secure storage gespeichert. Biometrie nutzt die native Systemabfrage.';

  @override
  String get securityProtectionOff => 'Aus';

  @override
  String get securityProtectionOffDescription => 'Zugriff ohne zusätzlichen Schutz.';

  @override
  String get securityPasswordModeDescription => 'Ein eigenes Passwort zum Entsperren des Zugriffs.';

  @override
  String get securityPatternModeTitle => 'Mustersperre';

  @override
  String get securityPatternModeDescription => 'Ein Punktmuster ähnlich der Android-Sperre.';

  @override
  String get securityNativePromptDescription => 'Die native Face ID-, Fingerabdruck- oder Systemauthentifizierungsabfrage des Geräts.';

  @override
  String get securityRelockAfterHidden => 'Erneut sperren, wenn die App ausgeblendet wird';

  @override
  String get securityRelockAfterHiddenDescription => 'Wenn deaktiviert, kehrt der Schutz erst nach einem vollständigen App-Neustart zurück.';

  @override
  String get securityGracePeriod => 'Karenzzeit vor erneuter Sperre';

  @override
  String get securityGraceUnavailable => 'Nicht verfügbar, solange Hintergrundsperre deaktiviert ist.';

  @override
  String securityAllowQuickUnlockWith(String method) {
    return 'Schnelles Entsperren mit $method erlauben';
  }

  @override
  String get securityQuickUnlockSubtitle => 'Behält Passwort oder Muster als primäre Ersatzmethode bei.';

  @override
  String get securityChangePassword => 'Passwort ändern';

  @override
  String get securityChangePattern => 'Muster ändern';

  @override
  String get securityChangeCredentialSubtitle => 'Der aktuelle Schutz wird aktualisiert, sobald das neue Geheimnis bestätigt ist.';

  @override
  String get securityProtectionActivated => 'Schutz wurde sofort aktiviert.';

  @override
  String get securityLockNow => 'Jetzt sperren';

  @override
  String get securitySaveChanges => 'Speichern';

  @override
  String get securityGraceImmediately => 'Sofort';

  @override
  String securityGraceAfterSeconds(int seconds) {
    return 'Nach $seconds s';
  }

  @override
  String securityGraceAfterMinutes(int minutes) {
    return 'Nach $minutes Min.';
  }

  @override
  String get securityStatusLocked => 'Gesperrt';

  @override
  String get securityStatusUnlocked => 'Entsperrt';

  @override
  String get securityAfterHide => 'Nach Ausblenden';

  @override
  String securityGracePill(int seconds) {
    return 'Karenz $seconds s';
  }

  @override
  String get securityNoProtection => 'Kein Schutz';

  @override
  String get securityNativeBiometrics => 'Native Biometrie';

  @override
  String get securityBiometricFaceFingerprint => 'Face ID / Fingerabdruck';

  @override
  String get securityBiometricFingerprint => 'Fingerabdruck';

  @override
  String get securityBiometricNativeDeviceAuthentication => 'Native Geräteauthentifizierung';

  @override
  String get devicesLinkOpenFailed => 'Der Link konnte nicht im Browser geöffnet werden.';

  @override
  String get devicesDesktopDescriptionPrefix => 'Du kannst dich in der ';

  @override
  String get devicesDesktopAppLink => 'Secretly-Desktop-App';

  @override
  String get devicesDesktopDescriptionSuffix => ' mit einem QR-Code anmelden.';

  @override
  String get devicesFailureTransportBlocked => 'Der Transport ist für den aktuellen Server blockiert. Stelle Telefon und Desktop auf denselben Server und versuche es erneut.';

  @override
  String get devicesFailureIdentityNotServerBacked => 'Die Desktop-Identität ist noch nicht auf dem Server registriert. Versuche es in ein paar Sekunden erneut.';

  @override
  String get devicesFailureProfileUnavailable => 'Das Desktop-Profil ist auf dem Server noch nicht sichtbar. Lass die App geöffnet und versuche es erneut.';

  @override
  String get devicesFailureDeviceUnavailable => 'Das Desktop-Gerät ist auf dem Server noch nicht sichtbar. Lass die App geöffnet, aktualisiere den QR und versuche es erneut.';

  @override
  String get devicesFailureCompanionRequired => 'Desktop-Companion-Zugriff ist für dieses Profil nicht aktiviert. Aktiviere ihn auf dem primären Telefon und versuche es erneut.';

  @override
  String get devicesFailureCompanionLimit => 'Das Limit für Desktop-Geräte ist für dieses Profil bereits belegt. Entferne ein altes Desktop-Gerät oder erhöhe die verfügbaren Plätze.';

  @override
  String get devicesFailurePrimaryRequired => 'Erstelle zuerst das Hauptkonto auf einem Telefon und verknüpfe dann den Desktop per QR.';

  @override
  String get devicesFailureInvalidQr => 'Dieser QR ist kein Geräteautorisierungscode.';

  @override
  String get devicesFailureQrExpired => 'Der QR-Code ist abgelaufen. Erzeuge einen neuen auf dem Desktop.';

  @override
  String get devicesFailureServerMismatch => 'Dieser QR gehört zu einem anderen Server. Stelle Telefon und Desktop auf denselben Server und versuche es erneut.';

  @override
  String get devicesFailureProfileMismatch => 'Das Synchronisierungspaket zielt auf ein anderes Profil. Erzeuge einen neuen QR und versuche es erneut.';

  @override
  String get devicesFailureRequestNotFound => 'Die Desktop-Synchronisierungsanfrage wurde nicht gefunden oder ist bereits abgelaufen. Erzeuge einen neuen QR.';

  @override
  String get devicesFailureSessionExpired => 'Die QR-Sitzung ist abgelaufen. Erzeuge einen neuen QR und versuche es erneut.';

  @override
  String get devicesFailureSessionValidation => 'Die QR-Sitzungsprüfung ist fehlgeschlagen. Erzeuge einen neuen QR und versuche es erneut.';

  @override
  String get devicesFailureStateMismatch => 'Der Status der Synchronisierungsanfrage passt nicht mehr. Erzeuge einen neuen QR und versuche es erneut.';

  @override
  String get devicesFailureDeviceMismatch => 'Das Synchronisierungspaket zielt auf ein anderes Gerät. Erzeuge einen neuen QR und versuche es erneut.';

  @override
  String get devicesFailureDeclined => 'Die Anmeldung wurde auf dem primären Telefon abgelehnt. Erzeuge einen neuen QR, um es erneut zu versuchen.';

  @override
  String get devicesFailureInvalidPayload => 'Ungültiges Desktop-Synchronisierungspaket. Erzeuge einen neuen QR und versuche es erneut.';

  @override
  String get devicesFailureInterrupted => 'Die sichere Synchronisierung wurde vor Abschluss unterbrochen. Erzeuge einen neuen QR und versuche es erneut.';

  @override
  String get devicesNewUser => 'Neuer Benutzer';

  @override
  String get devicesNewUserDesktopConfirm => 'Lokale Daten löschen und dieses Desktop-Gerät für QR-Anmeldung vom primären Telefon vorbereiten?';

  @override
  String get devicesNewUserMobileConfirm => 'Aktuelles lokales Profil löschen und einen neuen Benutzer auf diesem Gerät registrieren?';

  @override
  String get devicesCreateAction => 'Erstellen';

  @override
  String get devicesScanDeviceQr => 'Geräte-QR scannen';

  @override
  String get devicesRequestApproved => 'Anfrage genehmigt. Synchronisierungspaket an den Desktop gesendet.';

  @override
  String get devicesRequestDeclined => 'Anfrage abgelehnt. Der Desktop bleibt nicht authentifiziert.';

  @override
  String get devicesApproveSignInTitle => 'Anmeldung auf diesem Gerät genehmigen?';

  @override
  String get devicesConfirmSyncPrimary => 'Bestätige die Synchronisierung vom primären Gerät (Telefon).';

  @override
  String devicesApprovalDeviceOnly(String name) {
    return 'Gerät: $name. Genehmigung ist nur vom primären Telefon erlaubt.';
  }

  @override
  String get devicesSyncChats => 'Chats synchronisieren';

  @override
  String get devicesSyncSettings => 'Einstellungen synchronisieren';

  @override
  String get devicesSyncMedia => 'Medien synchronisieren';

  @override
  String get devicesDeclineSignIn => 'Anmeldung ablehnen';

  @override
  String get devicesApprove => 'Genehmigen';

  @override
  String get devicesTitle => 'Geräte';

  @override
  String get devicesConnectDevice => 'Gerät verbinden';

  @override
  String get devicesPrimaryDeviceTitle => 'Dies ist das primäre Gerät';

  @override
  String get devicesPrimaryDeviceSubtitle => 'Die Berechtigung zum Synchronisieren von Chats, Einstellungen und Medien wird nur hier erteilt.';

  @override
  String get devicesQrSessionExpiredNewCode => 'Die QR-Sitzung ist abgelaufen. Erzeuge einen neuen Code.';

  @override
  String devicesQrExpiresIn(String time) {
    return 'QR läuft ab in $time';
  }

  @override
  String get devicesWaitingQrScan => 'Warte auf QR-Scan auf dem Telefon.';

  @override
  String get devicesQrScannedConfirm => 'QR gescannt. Bestätige die Anmeldung auf dem Telefon.';

  @override
  String get devicesApplyingSecureBundle => 'Sicheres Synchronisierungspaket wird angewendet…';

  @override
  String get devicesAuthorizationFailed => 'Autorisierung fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get devicesUnauthenticatedChooseAction => 'Du bist nicht authentifiziert. Wähle unten eine Aktion.';

  @override
  String get devicesAuthenticated => 'Gerät ist authentifiziert.';

  @override
  String get devicesDesktopWebAuthorization => 'Desktop/Web-Autorisierung';

  @override
  String get devicesDesktopModeDescription => 'Wähle den Modus: neuen Benutzer registrieren oder per QR mit Telefonbestätigung anmelden.';

  @override
  String get devicesCancelQr => 'QR abbrechen';

  @override
  String get devicesRefreshQr => 'QR aktualisieren';

  @override
  String get devicesSignInViaQr => 'Per QR anmelden';

  @override
  String get devicesOpenPrimaryInstruction => 'Öffne Secretly auf dem primären Telefon → Einstellungen → Geräte → Gerät verbinden.';

  @override
  String get storageSection => 'Speicher';

  @override
  String get storageSectionSubtitle => 'Cache und Downloads auf diesem Gerät';

  @override
  String get storageUsageTitle => 'Speichernutzung';

  @override
  String get storageCategoryMedia => 'Medien-Cache';

  @override
  String get storageCategoryVoiceTranscripts => 'Sprachtranskripte';

  @override
  String get storageCategoryVoiceModel => 'Offline-Sprachmodell';

  @override
  String get storageCategoryStickers => 'Sticker';

  @override
  String get storageCategoryEmoji => 'Animierte Emojis';

  @override
  String get storageCategoryProfileMedia => 'Meine Galerie & Avatare';

  @override
  String get storageCategoryRecents => 'Zuletzt verwendete Dateien';

  @override
  String get storageTotal => 'Gesamt';

  @override
  String get storageCalculating => 'Wird berechnet…';

  @override
  String get storageClearCache => 'Cache leeren';

  @override
  String get storageClearCacheHint => 'Entfernt zwischengespeicherte Medien, Avatare von Kontakten und animierte Emojis. Deine eigene Galerie, Sticker und Chats bleiben erhalten; Medien werden beim Ansehen neu geladen.';

  @override
  String get storageClearing => 'Cache wird geleert…';

  @override
  String get storageClearedToast => 'Cache geleert';

  @override
  String get storageRemoveVoiceModel => 'Offline-Sprachmodell entfernen (140 MB)';

  @override
  String get storageRemoveVoiceModelHint => 'Gibt das Spracherkennungsmodell auf dem Gerät frei. Es wird beim nächsten Transkribieren einer Sprachnachricht automatisch neu geladen.';

  @override
  String get storageRemoveVoiceModelConfirmTitle => 'Sprachmodell entfernen?';

  @override
  String get storageRemoveVoiceModelConfirmBody => 'Das 140 MB große Spracherkennungsmodell wird vom Gerät gelöscht. Es wird beim nächsten Transkribieren einer Sprachnachricht automatisch neu geladen.';

  @override
  String get storageRemoveVoiceModelConfirm => 'Entfernen';

  @override
  String get storageVoiceModelNotInstalled => 'Es ist kein Sprachmodell installiert';

  @override
  String get storageVoiceModelRemovedToast => 'Sprachmodell entfernt';

  @override
  String get backupStateProtected => 'Dein Verlauf ist geschützt';

  @override
  String get backupStateUnprotected => 'Dein Verlauf ist nicht geschützt';

  @override
  String get backupStateFailing => 'Backups schlagen fehl';

  @override
  String get backupStateStale => 'Backup ist veraltet';

  @override
  String get backupStateNone => 'Noch kein Backup';

  @override
  String backupLastAt(Object time) {
    return 'Letztes Backup: $time';
  }

  @override
  String get backupIntroHint => 'Mit einem Backup holst du deine Chats auf ein neues Gerät';

  @override
  String get backupAccessUpgradeTitle => 'Sicherung erneut speichern';

  @override
  String get backupAccessUpgradeBody => 'Ihre Sicherung auf dem Server wurde im alten Format erstellt: Sie lässt sich mit Kenntnis der Profil-ID herunterladen. Die Inhalte bleiben mit Ihrem Passwort verschlüsselt, aber eine zweite Hürde schadet nicht. Erneutes Speichern fügt eine Passwortprüfung auf dem Server hinzu.';

  @override
  String get backupAccessUpgradeAction => 'Erneut speichern';

  @override
  String get backupSectionAutomatic => 'Automatisch';

  @override
  String get backupAutoToggle => 'Automatisch sichern';

  @override
  String get backupPassword => 'Passwort';

  @override
  String get backupPasswordSet => 'Gesetzt';

  @override
  String get backupPasswordNotSet => 'Nicht gesetzt';

  @override
  String get backupPasswordSaved => 'Passwort gespeichert';

  @override
  String get backupWhere => 'Wohin';

  @override
  String get backupHowOften => 'Wie oft';

  @override
  String get backupIncludeMedia => 'Medien einschließen';

  @override
  String get backupAutoFooter => 'Das Backup ist mit deinem Passwort verschlüsselt. Ohne das Passwort lässt sich nichts wiederherstellen — bewahre es sicher auf. Medien werden nie auf den Server geladen.';

  @override
  String get backupNow => 'Jetzt sichern';

  @override
  String get backupSectionRestore => 'Wiederherstellen';

  @override
  String get backupRestoreAction => 'Aus einem Backup wiederherstellen';

  @override
  String get backupRestoreFooter => 'Ersetzt die Chats und Einstellungen auf diesem Gerät durch den Inhalt des Backups.';

  @override
  String get backupSectionKey => 'Secretly-ID-Schlüssel';

  @override
  String get backupKeyShow => 'Schlüssel anzeigen';

  @override
  String get backupKeyRestore => 'Mit Schlüssel wiederherstellen';

  @override
  String get backupKeyFooter => 'Stellt nur deine Secretly-ID wieder her — Chats enthält der Schlüssel nicht. Die Wiederherstellung mit einem Schlüssel löscht lokale Daten.';

  @override
  String get backupDestServerDevice => 'Server und Gerät';

  @override
  String get backupDestServer => 'Server';

  @override
  String get backupDestDevice => 'Gerät';

  @override
  String get backupDestNone => 'Nicht gewählt';

  @override
  String get backupDestServerOnly => 'Nur Server';

  @override
  String get backupDestDeviceOnly => 'Nur Gerät';

  @override
  String get backupTileOff => 'Aus — dein Verlauf ist nicht geschützt';

  @override
  String get backupTilePending => 'Ein, aber noch nie ausgeführt';

  @override
  String get backupTileFailing => 'Läuft nicht — bitte prüfen';

  @override
  String get backupTileStale => 'Seit Längerem nicht aktualisiert';

  @override
  String get backupPasswordChange => 'Passwort ändern';

  @override
  String get backupPasswordRemove => 'Passwort entfernen';

  @override
  String get chatUndecryptablePending => 'Eine Nachricht ist angekommen, aber noch nicht lesbar — sichere Sitzung wird wiederhergestellt…';

  @override
  String get liquidGlassTitle => 'Flüssiges Glas';

  @override
  String get liquidGlassSubtitle => 'Lichtbrechende Leisten und Inseln. Ausschalten für das schlichte Material — es braucht weniger Strom und bleibt kühler.';

  @override
  String get billingPendingTitle => 'Warten auf Zahlung';

  @override
  String get billingPendingBody => 'Die Bestellung wurde erstellt, die Zahlung ist aber noch nicht bestätigt. Bezahle mit der gewählten Methode — Premium wird von selbst aktiviert.';

  @override
  String get callsHideAddressTitle => 'Meine Adresse bei Anrufen verbergen';

  @override
  String get callsHideAddressSubtitle => 'Über unseren Server: Die andere Person sieht deine IP-Adresse nicht, aber die Verzögerung kann steigen';

  @override
  String get desktopJoinRoomByLink => 'Über Link beitreten';

  @override
  String get desktopJoinRoomLinkHint => 'Einladungslink einfügen';

  @override
  String get desktopJoinRoomLinkInvalid => 'Das ist kein Einladungslink für einen Raum';

  @override
  String get desktopOfflineLockTitle => 'Passwort nach langer Zeit ohne Verbindung';

  @override
  String get desktopOfflineLockDescription => 'Hat dieser Computer den Server länger als diese Frist nicht erreicht, fragt er beim Start nach dem App-Passwort. Ein verlorener Computer erhält die Fernabmeldung nie — diese Frist erreicht er aber.';

  @override
  String get desktopOfflineLockNever => 'Nie';

  @override
  String get desktopOfflineLockDays7 => '7 Tage';

  @override
  String get desktopOfflineLockDays14 => '14 Tage';

  @override
  String get desktopOfflineLockDays30 => '30 Tage';

  @override
  String get desktopPollTitle => 'Umfrage';

  @override
  String get desktopPollAnonymous => 'Anonyme Umfrage';

  @override
  String get desktopPollClosed => 'Beendet';

  @override
  String desktopPollVoters(Object count) {
    return 'Abgestimmt: $count';
  }

  @override
  String get desktopPollMultipleHint => 'Mehrere Antworten möglich';

  @override
  String get desktopPollCloseAction => 'Umfrage beenden';

  @override
  String get desktopEventTitle => 'Termin';

  @override
  String get desktopEventGoing => 'Ich komme';

  @override
  String get desktopEventMaybe => 'Vielleicht';

  @override
  String get desktopEventNo => 'Ich komme nicht';

  @override
  String get desktopPollNewTitle => 'Neue Umfrage';

  @override
  String get desktopPollQuestionHint => 'Frage';

  @override
  String desktopPollOptionHint(Object index) {
    return 'Option $index';
  }

  @override
  String get desktopPollAddOption => 'Option hinzufügen';

  @override
  String get desktopPollCreateAction => 'Erstellen';

  @override
  String get desktopPollNeedTwo => 'Nötig sind eine Frage und mindestens zwei Optionen';

  @override
  String get desktopPollMultipleLabel => 'Mehrere Antworten';

  @override
  String get desktopPollAnonymousLabel => 'Anonym';

  @override
  String get desktopEventNewTitle => 'Neuer Termin';

  @override
  String get desktopEventTitleHint => 'Titel';

  @override
  String get desktopEventDescriptionHint => 'Beschreibung';

  @override
  String get desktopEventLocationHint => 'Ort';

  @override
  String get desktopEventPickWhen => 'Datum und Uhrzeit wählen';

  @override
  String get desktopEventNeedTitleAndDate => 'Nötig sind ein Titel und ein Datum';

  @override
  String get desktopViewerOpenExternally => 'In anderer App öffnen';

  @override
  String get desktopViewerSaveAs => 'Sichern unter…';

  @override
  String desktopViewerPage(Object page, Object total) {
    return 'Seite $page von $total';
  }

  @override
  String get desktopViewerFailed => 'Datei konnte nicht angezeigt werden';

  @override
  String get desktopViewerTooLarge => 'Diese Datei ist zu groß für die Anzeige hier';

  @override
  String get desktopSupportAttach => 'Datei anhängen';

  @override
  String desktopSupportAttachHint(Object limit) {
    return 'Ein Screenshot oder eine Protokolldatei – bis $limit. Der Anhang wird zusammen mit der Nachricht verschlüsselt.';
  }

  @override
  String desktopSupportTooLarge(Object limit) {
    return 'Die Datei ist größer als $limit und kann nicht gesendet werden';
  }

  @override
  String get desktopSupportUnreadable => 'Die Datei konnte nicht gelesen werden';

  @override
  String get desktopSupportRemoveAttachment => 'Anhang entfernen';

  @override
  String desktopSupportMegabytes(Object value) {
    return '$value MB';
  }

  @override
  String get desktopSupportYou => 'Sie';

  @override
  String get desktopSupportShrunk => 'Das Bild wurde verkleinert, damit es passt';

  @override
  String get desktopStickerPackTitle => 'Sticker-Paket';

  @override
  String get desktopStickerPackAddPlain => 'Paket hinzufügen';

  @override
  String get desktopStickerPackInstalled => 'Installiert';

  @override
  String get desktopStickerPackInstalling => 'Wird installiert…';

  @override
  String get desktopStickerPackOwn => 'Das ist dein eigenes Paket';

  @override
  String get desktopStickerPackNoAuthor => 'Der Urheber des Pakets ist unbekannt – öffne denselben Sticker in einem Einzelchat';

  @override
  String desktopStickerPackInstallingProgress(Object done, Object total) {
    return 'Wird installiert… $done/$total';
  }

  @override
  String desktopStickerPackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sticker',
      one: '$count Sticker',
    );
    return '$_temp0';
  }

  @override
  String desktopStickerPackAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sticker hinzufügen',
      one: '$count Sticker hinzufügen',
    );
    return '$_temp0';
  }

  @override
  String get desktopPairingTitle => 'Verbinde Secretly Desktop';

  @override
  String get desktopPairingHowTo => 'Öffne am Telefon Secretly → Einstellungen → Geräte → „Gerät verbinden“ und scanne diesen QR-Code.';

  @override
  String get desktopPairingPreparingQr => 'QR wird vorbereitet…';

  @override
  String get desktopPairingQrUnavailable => 'QR nicht verfügbar';

  @override
  String get desktopPairingCodeExpired => 'Der Code ist abgelaufen – wird erneuert…';

  @override
  String desktopPairingCodeValidFor(Object time) {
    return 'Der Code gilt noch $time';
  }

  @override
  String get desktopPairingPrepareFailed => 'Der Code konnte nicht vorbereitet werden. Prüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get desktopPairingRevoked => 'Dieses Gerät wurde aus dem Konto entfernt, daher wird kein Code erstellt.\nVerbinde den Computer erneut – er erhält eine neue Geräteidentität, die alte bleibt widerrufen. Zugriff auf die Unterhaltungen gibt nur eine Bestätigung vom Telefon.';

  @override
  String get desktopPairingPreparingNew => 'Neue Verbindung wird vorbereitet…';

  @override
  String get desktopPairingConnectAsNew => 'Als neues Gerät verbinden';

  @override
  String get desktopPairingIdentityResetFailed => 'Die Geräteidentität konnte nicht neu erstellt werden. Starte die App neu und versuche es erneut.';

  @override
  String get desktopPairingWaitingConfirm => 'Warte auf Bestätigung…';

  @override
  String get desktopPairingNewQr => 'Neuen QR erzeugen';

  @override
  String get desktopPairingCreatingRequest => 'Anfrage wird erstellt…';

  @override
  String get desktopPairingReadyToScan => 'Bereit zum Scannen';

  @override
  String get desktopPairingWaitingScan => 'Warte auf den Scan am Telefon…';

  @override
  String get desktopPairingScannedConfirmOnPhone => 'QR gescannt – bestätige am Telefon.';

  @override
  String get desktopPairingFetchingProfile => 'Profil und Schlüssel werden geholt…';

  @override
  String get desktopPairingConnectedLoading => 'Verbunden. Wird geladen…';

  @override
  String get desktopPairingConnectionError => 'Verbindungsfehler. Versuche es erneut.';

  @override
  String get desktopMenuReaction => 'Reaktion';

  @override
  String get desktopMenuContinueInTopic => 'Im Thema fortsetzen';

  @override
  String get desktopMenuCopySelection => 'Auswahl kopieren';

  @override
  String get desktopMenuCopyText => 'Text kopieren';

  @override
  String get desktopMenuCopyLink => 'Link kopieren';

  @override
  String get desktopMenuTranslate => 'Übersetzen';

  @override
  String get desktopMenuHideTranslation => 'Übersetzung ausblenden';

  @override
  String get desktopMenuSelect => 'Auswählen';

  @override
  String get desktopMenuPhotoOrVideo => 'Foto oder Video';

  @override
  String get desktopMenuContact => 'Kontakt';

  @override
  String get desktopMenuLocation => 'Standort';

  @override
  String get desktopListPinned => 'ANGEHEFTET';

  @override
  String get desktopListToday => 'HEUTE';

  @override
  String get desktopListYesterday => 'GESTERN';

  @override
  String get desktopListThisWeek => 'DIESE WOCHE';

  @override
  String get desktopListEarlier => 'FRÜHER';

  @override
  String get desktopListNothingFound => 'Nichts gefunden';

  @override
  String get desktopListAddFavourite => 'Zu Favoriten';

  @override
  String get desktopListRemoveFavourite => 'Aus Favoriten entfernen';

  @override
  String get desktopListMute => 'Stummschalten';

  @override
  String get desktopListMarkRead => 'Als gelesen markieren';

  @override
  String get desktopListArchive => 'Archivieren';

  @override
  String get desktopListFolders => 'Ordner';

  @override
  String get desktopListCreate => 'Erstellen';

  @override
  String get desktopListTyping => 'schreibt';

  @override
  String get desktopListDraftPrefix => 'Entwurf: ';

  @override
  String desktopListDiscussion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gespräch · $count Teilnehmer',
      one: 'Gespräch · $count Teilnehmer',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallServerSilent => 'Der Server hat nicht geantwortet. Versuche es erneut oder verlasse den Anruf.';

  @override
  String get desktopCallRoomMissing => 'Der Raum ist auf dem Server nicht verfügbar – darin lässt sich kein Anruf starten.';

  @override
  String get desktopCallNoServer => 'Keine Verbindung zum Server. Prüfe deine Verbindung.';

  @override
  String get desktopCallJoinFailed => 'Der Anruf konnte nicht betreten werden. Prüfe die Verbindung und versuche es erneut.';

  @override
  String desktopCallSharingScreen(Object name) {
    return '$name teilt den Bildschirm';
  }

  @override
  String get desktopCallRoomEmpty => 'Im Raum wurde noch nichts geschrieben';

  @override
  String get desktopCallMessageHint => 'Nachricht an den Raum…';

  @override
  String get desktopCallSendToRoom => 'An den Raum senden';

  @override
  String desktopCallParticipantsTab(Object count) {
    return 'Teilnehmer · $count';
  }

  @override
  String get desktopCallNotesTab => 'Notizen';

  @override
  String get desktopCallLinkCopied => 'Link kopiert';

  @override
  String get desktopCallFailed => 'Fehlgeschlagen';

  @override
  String desktopCallFailedWith(Object error) {
    return 'Fehlgeschlagen: $error';
  }

  @override
  String get desktopCallMicOn => 'Mikrofon einschalten';

  @override
  String get desktopCallMicOff => 'Mikrofon ausschalten';

  @override
  String get desktopCallCamOn => 'Kamera einschalten';

  @override
  String get desktopCallCamOff => 'Kamera ausschalten';

  @override
  String get desktopCallNoMediaVideo => 'Der Server hat keinen Medienkanal bereitgestellt – Video ist nicht verfügbar';

  @override
  String get desktopCallLayoutSingle => 'Einzeln';

  @override
  String get desktopCallLayoutGrid => 'Raster';

  @override
  String get desktopCallShowOneLarge => 'Eine Person groß zeigen';

  @override
  String get desktopCallShowGrid => 'Alle im Raster zeigen';

  @override
  String get desktopCallScreen => 'Bildschirm';

  @override
  String get desktopCallShareStop => 'Bildschirmfreigabe beenden';

  @override
  String get desktopCallShareStart => 'Bildschirm teilen';

  @override
  String get desktopCallNoMediaScreen => 'Der Server hat keinen Medienkanal bereitgestellt – Bildschirmfreigabe ist nicht verfügbar';

  @override
  String get desktopCallLeave => 'Verlassen';

  @override
  String get desktopCallLeaveCall => 'Anruf verlassen';

  @override
  String get desktopCallNoMediaBoth => 'Der Server hat keinen Medienkanal bereitgestellt: In diesem Anruf gibt es weder Ton noch Video';

  @override
  String get desktopCallMinimise => 'Anruf minimieren';

  @override
  String get desktopCallDiscussion => 'Gespräch';

  @override
  String desktopCallDiscussionOf(Object title) {
    return 'Gespräch · $title';
  }

  @override
  String get desktopCallEncrypted => 'Der Anruf ist Ende-zu-Ende-verschlüsselt';

  @override
  String desktopCallDurationOnAir(Object duration, Object count) {
    return '$duration · $count live';
  }

  @override
  String get desktopCallExitFullScreen => 'Vollbild verlassen';

  @override
  String get desktopCallFullScreen => 'Vollbild';

  @override
  String get desktopCallDemoRoom => 'Demoraum';

  @override
  String get desktopCallNoCallYet => 'Noch kein Anruf';

  @override
  String get desktopCallDemoExplain => 'Er existiert nur auf diesem Computer und nicht auf dem Server – darin lässt sich kein Anruf starten. In einem echten Raum funktioniert die Schaltfläche.';

  @override
  String get desktopCallStartHint => 'Starte – die anderen sehen die Einladung im Raum';

  @override
  String get desktopCallVoiceOnly => 'Nur Ton';

  @override
  String get desktopCallWithCamera => 'Mit Kamera';

  @override
  String get desktopCallConnecting => 'Verbinden…';

  @override
  String get desktopCallOngoing => 'Ein Gespräch läuft';

  @override
  String desktopCallOnAir(Object count) {
    return '$count live';
  }

  @override
  String get desktopCallJoin => 'Beitreten';

  @override
  String get desktopCallFullScreenShort => 'Vollbild';

  @override
  String get desktopCallReconnecting => 'verbindet neu';

  @override
  String get desktopCallCannotHear => 'hört nicht';

  @override
  String get desktopCallSharingShort => 'teilt den Bildschirm';

  @override
  String get desktopCallCameraOn => 'Kamera ist an';

  @override
  String get desktopCallPickDevice => 'Gerät wählen';

  @override
  String get desktopCallPreparingLink => 'Link wird vorbereitet…';

  @override
  String get desktopCallInvite => 'Einladen';

  @override
  String desktopCallFps(Object fps) {
    return '$fps B/s';
  }

  @override
  String get desktopSettingsTitle => 'Einstellungen';

  @override
  String get desktopSettingsGroupApp => 'Anwendung';

  @override
  String get desktopSettingsGroupPrivacy => 'Privatsphäre und Sicherheit';

  @override
  String get desktopSettingsGroupAccount => 'Konto und Daten';

  @override
  String get desktopSettingsGeneralLabel => 'Allgemein';

  @override
  String get desktopSettingsGeneralSubtitle => 'Sprache, Verhalten der App';

  @override
  String get desktopSettingsGeneralKeywords => 'sprache, gebietsschema, enter, senden, eingabe';

  @override
  String get desktopSettingsAppearanceLabel => 'Aussehen';

  @override
  String get desktopSettingsAppearanceSubtitle => 'Thema, Akzent, Chat-Hintergrund';

  @override
  String get desktopSettingsAppearanceKeywords => 'thema, akzent, hintergrund, blasen, farbe, dunkel, haken, animation';

  @override
  String get desktopSettingsShortcutsLabel => 'Tastenkürzel';

  @override
  String get desktopSettingsShortcutsSubtitle => 'Was man drückt, um schneller zu sein';

  @override
  String get desktopSettingsShortcutsKeywords => 'tasten, kürzel, schnell, cmd, ctrl';

  @override
  String get desktopSettingsPowerLabel => 'Energieverbrauch';

  @override
  String get desktopSettingsPowerSubtitle => 'Was den Akku verbraucht';

  @override
  String get desktopSettingsPowerKeywords => 'akku, animation, rahmen, glas, leistung, wärme';

  @override
  String get desktopSettingsNotificationsLabel => 'Benachrichtigungen';

  @override
  String get desktopSettingsNotificationsSubtitle => 'Töne, Vorschau, Ruhe';

  @override
  String get desktopSettingsNotificationsKeywords => 'ton, vorschau, ruhe, nicht stören, banner, text';

  @override
  String get desktopSettingsCallsLabel => 'Anrufe';

  @override
  String get desktopSettingsCallsSubtitle => 'Anrufe annehmen und Bildschirm teilen';

  @override
  String get desktopSettingsCallsKeywords => 'anrufe, eingehend, bildschirm teilen, video, audio';

  @override
  String get desktopSettingsMediaLabel => 'Ton und Video';

  @override
  String get desktopSettingsMediaSubtitle => 'Kamera und Mikrofon für Anrufe';

  @override
  String get desktopSettingsMediaKeywords => 'kamera, mikrofon, gerät, webcam, headset, kopfhörer, ton, video';

  @override
  String get desktopSettingsPrivacyLabel => 'Privatsphäre';

  @override
  String get desktopSettingsPrivacySubtitle => 'Wer was über dich sieht';

  @override
  String get desktopSettingsPrivacyKeywords => 'wer sieht, zuletzt online, foto, anrufe, nachrichten, weiterleiten, spitzname, suche, fremde';

  @override
  String get desktopSettingsSecurityLabel => 'Sicherheit';

  @override
  String get desktopSettingsSecuritySubtitle => 'Verschlüsselung und verifizierte Geräte';

  @override
  String get desktopSettingsSecurityKeywords => 'verschlüsselung, e2ee, verifiziert, sperre, passwort, touch id, überprüfung';

  @override
  String get desktopSettingsBackupLabel => 'Sicherung';

  @override
  String get desktopSettingsBackupSubtitle => 'Was den Gesprächsverlauf rettet';

  @override
  String get desktopSettingsBackupKeywords => 'sicherung, backup, wiederherstellung, safe backup, passwort, medien';

  @override
  String get desktopSettingsBlockedLabel => 'Blockiert';

  @override
  String get desktopSettingsBlockedSubtitle => 'Wer keinen Zugang zu dir hat';

  @override
  String get desktopSettingsBlockedKeywords => 'block, blockiert, entsperren, sperrliste, spam';

  @override
  String get desktopSettingsDevicesLabel => 'Sitzungen und Geräte';

  @override
  String get desktopSettingsDevicesSubtitle => 'Aktive Sitzungen';

  @override
  String get desktopSettingsDevicesKeywords => 'geräte, sitzungen, qr, verbinden, abmelden, sicherung';

  @override
  String get desktopSettingsAccountLabel => 'Konto';

  @override
  String get desktopSettingsAccountSubtitle => 'Profil und Abmelden';

  @override
  String get desktopSettingsAccountKeywords => 'name, über mich, id, abmelden, zurücksetzen';

  @override
  String get desktopSettingsStorageLabel => 'Speicher';

  @override
  String get desktopSettingsStorageSubtitle => 'Cache, Downloads';

  @override
  String get desktopSettingsStorageKeywords => 'cache, speicherplatz, leeren, medien, downloads';

  @override
  String get desktopSettingsSupportLabel => 'Support';

  @override
  String get desktopSettingsSupportSubtitle => 'Eine verschlüsselte Unterhaltung mit uns';

  @override
  String get desktopSettingsSupportKeywords => 'support, hilfe, problem, fehler, schreiben';

  @override
  String get desktopSettingsAboutLabel => 'Über';

  @override
  String get desktopSettingsAboutKeywords => 'version, build, lizenzen, website';

  @override
  String get desktopSettingsDangerLabel => 'Konto löschen';

  @override
  String get desktopSettingsEndCallFirst => 'Beende zuerst den laufenden Anruf.';

  @override
  String get desktopSettingsSignOutTitle => 'Auf diesem Computer vom Konto abmelden?';

  @override
  String get desktopSettingsSignOutBody => 'Unterhaltungen, Schlüssel und Cache werden von diesem Computer entfernt. Konto und Verlauf auf dem Telefon bleiben unberührt – der Computer lässt sich per QR-Code erneut verbinden.';

  @override
  String get desktopSettingsSignOut => 'Abmelden';

  @override
  String desktopSettingsSignOutFailed(Object error) {
    return 'Abmelden fehlgeschlagen: $error';
  }

  @override
  String get desktopSettingsActive => 'aktiv';

  @override
  String get desktopGeneralSystemLanguage => 'System';

  @override
  String get desktopGeneralInterfaceLanguage => 'Sprache der Oberfläche';

  @override
  String get desktopGeneralAppliesAtOnce => 'Gilt sofort';

  @override
  String get desktopGeneralBehaviour => 'Verhalten';

  @override
  String get desktopGeneralEnterSends => 'Enter sendet die Nachricht';

  @override
  String get desktopGeneralShiftEnterNewline => 'Shift+Enter beginnt eine neue Zeile';

  @override
  String get desktopGeneralEnterNewline => 'Enter beginnt eine neue Zeile, Shift+Enter sendet';

  @override
  String get desktopGeneralHoverMenu => 'Menü beim Zeigen auf eine Nachricht';

  @override
  String get desktopGeneralHoverMenuOn => 'Über der Nachricht erscheinen Reaktionen und Aktionen';

  @override
  String get desktopGeneralHoverMenuOff => 'Aktionen liegen auf der rechten Maustaste';

  @override
  String get desktopGeneralLinkPreviews => 'Link-Vorschauen';

  @override
  String get desktopGeneralLinkPreviewsOn => 'Die Link-Karte wird zusammen mit der Nachricht gesendet';

  @override
  String get desktopGeneralLinkPreviewsOff => 'Links werden ohne Karte gesendet, keine Seite wird geöffnet';

  @override
  String get desktopPowerAnimations => 'Animationen';

  @override
  String get desktopPowerAnimationsHint => 'Standardmäßig ist alles an. Schalte von oben nach unten ab, wenn der Laptop heiß wird oder der Akku leerläuft.';

  @override
  String get desktopPowerFramesTitle => 'Animierte Rahmen und Status';

  @override
  String get desktopPowerFramesHint => 'Lebendige Avatar-Rahmen und Emoji-Status bei anderen. Die teuerste der drei – schalte sie zuerst ab.';

  @override
  String get desktopPowerGlassBubbles => 'Glasblasen';

  @override
  String get desktopPowerGlassBubblesHint => 'Unschärfe hinter eingehenden Nachrichten';

  @override
  String get desktopPowerMattePanels => 'Matte Flächen';

  @override
  String get desktopPowerMattePanelsHint => 'Unschärfe bei Flächen und Popups';

  @override
  String get desktopPowerNotAffectedTitle => 'Was davon nicht betroffen ist';

  @override
  String get desktopPowerNotAffectedHint => 'Zustellung, Verschlüsselung und Benachrichtigungen arbeiten bei jeder Einstellung gleich. Diese Optionen betreffen nur die Darstellung.';

  @override
  String get desktopNotifHidden => 'Verborgen';

  @override
  String get desktopNotifSenderOnly => 'Nur Absender';

  @override
  String get desktopNotifSenderAndText => 'Absender und Text';

  @override
  String get desktopNotifUnavailableHere => 'Auf dieser Plattform nicht verfügbar.';

  @override
  String get desktopNotifShowPreview => 'Vorschau der Nachricht zeigen';

  @override
  String get desktopNotifInSystem => 'In Systembenachrichtigungen';

  @override
  String get desktopNotifDirectChats => 'Einzelchats';

  @override
  String get desktopNotifDirectChatsHint => 'Benachrichtigungen über Einzelnachrichten';

  @override
  String get desktopNotifRooms => 'Räume';

  @override
  String get desktopNotifRoomsHint => 'Benachrichtigungen über Nachrichten in Räumen';

  @override
  String get desktopNotifSound => 'Ton';

  @override
  String get desktopNotifDnd => 'Nicht stören';

  @override
  String get desktopNotifDndHint => 'Alle Benachrichtigungen abschalten';

  @override
  String get desktopWallAnimContinuous => 'Dauerhaft';

  @override
  String get desktopWallAnimOnEnter => 'Beim Öffnen eines Chats';

  @override
  String get desktopWallAnimTap => 'Bei Klick auf den Hintergrund';

  @override
  String get desktopWallAnimOff => 'Nicht animieren';

  @override
  String get desktopWallpaperNavy => 'Mitternachtsblau';

  @override
  String get desktopWallpaperGraphite => 'Graphit';

  @override
  String get desktopWallpaperTeal => 'Petrol';

  @override
  String get desktopWallpaperPlum => 'Pflaume';

  @override
  String get desktopWallpaperWine => 'Wein';

  @override
  String get desktopWallpaperMint => 'Minze';

  @override
  String get desktopWallpaperLavender => 'Lavendel';

  @override
  String get desktopWallpaperSunset => 'Sonnenuntergang';

  @override
  String get desktopWallpaperPeach => 'Pfirsich';

  @override
  String get desktopWallpaperSky => 'Himmel';

  @override
  String get desktopWallpaperMidnight => 'Mitternacht';

  @override
  String get desktopAppearanceTitle => 'Erscheinungsbild';

  @override
  String get desktopAppearanceHint => 'Das Schema dieses Fensters. Das Telefon hat sein eigenes – diese Einstellung reist nirgendwohin.';

  @override
  String get desktopAppearanceScheme => 'Schema';

  @override
  String get desktopAppearanceSchemeHint => 'Dunkel, hell oder wie im System';

  @override
  String get desktopAppearanceDark => 'Dunkel';

  @override
  String get desktopAppearanceLight => 'Hell';

  @override
  String get desktopAppearanceAuto => 'Auto';

  @override
  String get desktopAppearanceAccent => 'Akzent der Oberfläche';

  @override
  String get desktopAppearanceAccentHint => 'Schaltflächen, eigene Blasen und Markierungen in der ganzen App.';

  @override
  String get desktopAppearanceWallpaper => 'Chat-Hintergrund';

  @override
  String get desktopAppearanceWallpaperHint => 'Der Chat-Hintergrund für alle Unterhaltungen.';

  @override
  String get desktopAppearanceLiveWallpaper => 'Lebendiger Hintergrund';

  @override
  String get desktopAppearanceLiveWallpaperHint => 'Ein Muster mit sanftem Schimmern. Dieselbe Auswahl wie am Telefon.';

  @override
  String get desktopAppearanceAnimBehaviour => 'Verhalten der Animation';

  @override
  String get desktopAppearanceAnimBehaviourHint => 'Wann das Muster lebendig wird.';

  @override
  String get desktopAppearanceWallPulse => 'Der Hintergrund begleitet die Nachricht';

  @override
  String get desktopAppearanceWallPulseHint => 'Eine Lichtwelle läuft über das Muster: nach oben beim Senden, nach unten beim Empfangen.';

  @override
  String get desktopAppearanceEnable => 'Einschalten';

  @override
  String get desktopAppearanceLiveOnly => 'Funktioniert nur beim lebendigen Hintergrund';

  @override
  String get desktopAppearanceBubbleStyle => 'Stil der Nachrichtenblasen';

  @override
  String get desktopAppearanceBubbleStyleHint => 'Die Farbe deiner ausgehenden Nachrichten in allen Chats.';

  @override
  String get desktopAppearanceSenderColour => 'Farbe des Absendernamens';

  @override
  String get desktopAppearanceSenderColourHint => 'Die Farbe des Spitznamens der anderen Person in Gruppenchats.';

  @override
  String get desktopAppearanceIndicatorColour => 'Farbe der Anzeigen';

  @override
  String get desktopAppearanceIndicatorColourHint => 'Die Zustellhaken und der Punkt für Ungelesenes.';

  @override
  String get desktopAppearanceDemoMode => 'Demomodus';

  @override
  String get desktopAppearanceDemoHint => 'Änderungen am Aussehen werden gespeichert, sobald ein Profil verbunden ist.';

  @override
  String get desktopAppearanceCurrentChoice => 'Aktuelle Auswahl';

  @override
  String desktopAppearanceThemeIs(Object name) {
    return 'Thema: $name';
  }
}
