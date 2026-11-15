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
  String get startupRetry => 'Wiederholen';

  @override
  String get onboardingBackupLater => 'Die Sicherung ist noch nicht aktiv – dein Profil wird noch erstellt. Aktiviere sie später in den Einstellungen.';

  @override
  String get keepMediaTitle => 'Medien auf dem Gerät behalten';

  @override
  String get keepMediaForever => 'Immer';

  @override
  String get keepMediaMonth => '1 Monat';

  @override
  String get keepMediaWeek => '1 Woche';

  @override
  String get keepMediaHint => 'Geladene Fotos, Videos und Dateien, die älter sind, werden vom Telefon entfernt. Nachrichten bleiben; Medien, die nicht mehr auf dem Server sind (älter als 7 Tage), und von dir gesendete werden endgültig entfernt.';

  @override
  String get chatMediaTitle => 'Medien nach Chat';

  @override
  String get chatMediaShow => 'Nach Chat berechnen';

  @override
  String chatMediaFilesCount(int count) {
    return '$count Dateien';
  }

  @override
  String get chatMediaDeleteTitle => 'Medien dieses Chats löschen?';

  @override
  String get chatMediaDeleteBody => 'Geladene Fotos, Videos und Dateien dieses Chats werden vom Telefon entfernt, Nachrichten bleiben. Was noch auf dem Server ist (bis 7 Tage), kann erneut geladen werden; der Rest – von dir Gesendetes und Älteres – wird endgültig entfernt.';

  @override
  String get chatMediaDeleteConfirm => 'Löschen';

  @override
  String get chatMediaEmpty => 'Keine geladenen Medien in Chats';

  @override
  String galleryShowMore(int count) {
    return 'Mehr anzeigen (noch $count)';
  }

  @override
  String get autoDownloadCellularTitle => 'Automatischer Download über mobile Daten';

  @override
  String get autoDownloadEverything => 'Alles';

  @override
  String get autoDownloadUpTo15Mb => 'Fotos, Videos und Dateien bis 15 MB';

  @override
  String get autoDownloadPhotosOnly => 'Nur Fotos';

  @override
  String get autoDownloadNothing => 'Nichts außer Sprachnachrichten';

  @override
  String get autoDownloadHint => 'Über WLAN wird alles geladen. Zurückgestelltes wird im WLAN geladen oder wenn du es öffnest. Dateien werden 7 Tage auf dem Server aufbewahrt.';

  @override
  String get uploadNotSentTapToRetry => 'Nicht gesendet – zum Wiederholen tippen';

  @override
  String get uploadRetry => 'Wiederholen';

  @override
  String get attachmentExpiredOnServer => 'Die Datei ist nicht mehr auf dem Server: Sie wird 7 Tage aufbewahrt.';

  @override
  String get attachmentServerRejectedSize => 'Die Datei ist für den Server zu groß. Sende eine kleinere oder teile sie auf.';

  @override
  String get attachmentServerStorageFull => 'Auf dem Server ist gerade wenig Speicherplatz frei. Versuche es später erneut.';

  @override
  String get attachmentUploadQuotaExceeded => 'Das Speicherlimit für Dateien ist erreicht. Dateien werden 7 Tage aufbewahrt – versuche es später erneut.';

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
  String get onboardingWelcomeSubtitle => 'Ein Messenger der nächsten Generation.\nPrivatsphäre von Anfang an.';

  @override
  String get onboardingCreateAccount => 'Neues Konto erstellen';

  @override
  String get onboardingAlreadyHaveAccount => 'Ich habe bereits ein Konto';

  @override
  String get onboardingFeatureE2eTitle => 'E2E-Verschlüsselung';

  @override
  String get onboardingFeatureE2eBody => 'Nachrichten werden auf deinem Gerät verschlüsselt. Nur du hast die Schlüssel.';

  @override
  String get onboardingFeaturePrivacyTitle => 'Keine persönlichen Daten';

  @override
  String get onboardingFeaturePrivacyBody => 'Keine Telefonnummer. Keine Verknüpfung mit persönlichen Daten.';

  @override
  String get onboardingFeatureRelayTitle => 'Server liest nicht mit';

  @override
  String get onboardingFeatureRelayBody => 'Der Server leitet nur verschlüsselte Nachrichten weiter und löscht sie nach der Zustellung.';

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
  String get desktopRoomLimitTitle => 'Raumlimit erreicht';

  @override
  String desktopRoomLimitCreate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sie können höchstens $count Räume erstellen.',
      one: 'Sie können höchstens $count Raum erstellen.',
    );
    return '$_temp0';
  }

  @override
  String desktopRoomLimitJoin(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sie können höchstens $count Räumen angehören. Um einem neuen beizutreten, verlassen Sie zuerst einen Ihrer Räume.',
      one: 'Sie können höchstens $count Raum angehören. Um einem neuen beizutreten, verlassen Sie zuerst einen Ihrer Räume.',
    );
    return '$_temp0';
  }

  @override
  String get desktopRoomLimitPremium => 'Mit Premium ist das Limit höher – das Abo wird in der Handy-App verwaltet.';

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
  String get desktopViewerPageFailed => 'Diese Seite konnte nicht angezeigt werden';

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
  String desktopPairingHowTo(String settings, String devices, String button) {
    return 'Öffne am Telefon Secretly → $settings → $devices → „$button“ und scanne diesen QR-Code.';
  }

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
  String get desktopCallDiscussion => 'Gespräch';

  @override
  String desktopCallDiscussionOf(Object title) {
    return 'Gespräch · $title';
  }

  @override
  String get desktopCallEncrypted => 'Der Anruf ist Ende-zu-Ende-verschlüsselt';

  @override
  String get desktopRoomCallTransportEncrypted => 'Auf dem Weg zu unserem Medienserver verschlüsselt – noch nicht Ende-zu-Ende';

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
  String get desktopGeneralDoubleClickReply => 'Doppelklick zum Antworten';

  @override
  String get desktopGeneralDoubleClickReplyHint => 'Doppelklick auf eine Nachricht, um zu antworten. Auf Text wird ein Wort markiert';

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
  String get desktopNotifInSystem => 'In Benachrichtigungen und Pop-ups';

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
  String get desktopNotifWhileFocused => 'Bei geöffnetem Fenster';

  @override
  String get desktopNotifWhileFocusedHint => 'Auch über Nachrichten aus anderen Chats benachrichtigen. Nie über den geöffneten Chat';

  @override
  String get desktopNotifOwnWindows => 'Benachrichtigungen wie in Telegram';

  @override
  String get desktopNotifOwnWindowsHint => 'Eigene Fenster in der Bildschirmecke: nehmen keinen Fokus und warten, solange die Maus darüber ist. Aus — Windows-Systembenachrichtigungen.';

  @override
  String get desktopNotifDnd => 'Nicht stören';

  @override
  String get desktopNotifDndHint => 'Alle Benachrichtigungen abschalten';

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
  String get desktopAppearanceHint => 'Das Schema dieses Fensters. Das Telefon hat sein eigenes – diese Einstellung reist nirgendwohin.';

  @override
  String get desktopAppearanceScheme => 'Schema';

  @override
  String get desktopAppearanceDark => 'Dunkel';

  @override
  String get desktopAppearanceLight => 'Hell';

  @override
  String get desktopAppearanceAccent => 'Akzent der Oberfläche';

  @override
  String get desktopAppearanceAccentHint => 'Schaltflächen, eigene Blasen und Markierungen in der ganzen App.';

  @override
  String get desktopAppearanceWallpaper => 'Chat-Hintergrund';

  @override
  String get desktopAppearanceWallPulse => 'Der Hintergrund begleitet die Nachricht';

  @override
  String get desktopAppearanceWallPulseHint => 'Eine Lichtwelle läuft über das Muster: nach oben beim Senden, nach unten beim Empfangen.';

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
  String get desktopAppearanceTabTheme => 'Design & Text';

  @override
  String get desktopAppearanceTabWallpaper => 'Chat-Hintergrund';

  @override
  String get desktopAppearanceTabMessages => 'Nachrichten';

  @override
  String get desktopAppearanceReset => 'Standard';

  @override
  String get desktopAppearanceResetDone => 'Das Aussehen ist zurückgesetzt';

  @override
  String get desktopAppearanceResetUndo => 'Rückgängig';

  @override
  String get desktopAppearanceAutosave => 'Wird automatisch gespeichert';

  @override
  String get desktopAppearancePremiumOnly => 'Das gehört zu Premium – das Abo wird in der Handy-App verwaltet';

  @override
  String get desktopAppearancePresets => 'Fertige Sets';

  @override
  String get desktopAppearancePresetsHint => 'Akzent, Hintergrund, Blasen und Indikatoren mit einem Klick';

  @override
  String get desktopAppearancePresetClassic => 'Klassisch';

  @override
  String get desktopAppearancePresetOcean => 'Ozean';

  @override
  String get desktopAppearancePresetSunset => 'Sonnenuntergang';

  @override
  String get desktopAppearancePresetForest => 'Wald';

  @override
  String get desktopAppearancePresetNight => 'Nacht';

  @override
  String get desktopAppearanceSystem => 'System';

  @override
  String get desktopAppearanceDensity => 'Nachrichtendichte';

  @override
  String get desktopAppearanceDensityCozy => 'Gemütlich';

  @override
  String get desktopAppearanceDensityCompact => 'Kompakt';

  @override
  String get desktopAppearanceWallpaperAllChats => 'Hintergrund für alle Chats. Lebendige schimmern sanft';

  @override
  String get desktopAppearanceStatic => 'Statisch';

  @override
  String get desktopAppearanceLive => 'Lebendig';

  @override
  String get desktopAppearanceLiveBadge => 'LIVE';

  @override
  String get desktopAppearanceDim => 'Abdunkeln';

  @override
  String get desktopAppearanceAnimPattern => 'Muster-Animation';

  @override
  String get desktopAppearanceLiveOnlyBadge => 'nur lebendige Hintergründe';

  @override
  String get desktopWallAnimShortContinuous => 'Immer';

  @override
  String get desktopWallAnimShortOnEnter => 'Beim Öffnen';

  @override
  String get desktopWallAnimShortTap => 'Per Klick';

  @override
  String get desktopWallAnimShortOff => 'Aus';

  @override
  String desktopAppearanceGoLive(Object link) {
    return 'Wählen Sie $link, um die Animation einzustellen.';
  }

  @override
  String get desktopAppearanceGoLiveLink => 'lebendige Hintergründe';

  @override
  String get desktopAppearanceShape => 'Form';

  @override
  String get desktopAppearanceShapeSharp => 'Eckig';

  @override
  String get desktopAppearanceShapeMedium => 'Mittel';

  @override
  String get desktopAppearanceShapeRound => 'Rund';

  @override
  String get desktopAppearanceNamesMulti => 'Bunt';

  @override
  String get desktopAppearanceIndicatorHint => 'Lesehäkchen in der Chatliste, Links und Textauswahl';

  @override
  String get desktopAppearanceSummaryPrefix => 'Aktuell:';

  @override
  String get desktopAppearanceSummaryDark => 'dunkles Schema';

  @override
  String get desktopAppearanceSummaryLight => 'helles Schema';

  @override
  String get desktopAppearanceSummarySystem => 'System-Schema';

  @override
  String desktopAppearanceSummaryBubbles(Object name) {
    return 'Blasen „$name“';
  }

  @override
  String desktopAppearanceSummaryText(Object size) {
    return 'Text $size';
  }

  @override
  String get desktopAppearancePreview => 'Vorschau';

  @override
  String get desktopAppearancePreviewReplay => 'Neu öffnen';

  @override
  String get desktopAppearancePreviewReplayHint => 'Chat neu öffnen, um die Animation zu sehen';

  @override
  String get desktopAppearancePreviewIncoming => 'Eingehend';

  @override
  String get desktopAppearancePreviewIncomingHint => 'Nachricht empfangen';

  @override
  String get desktopAppearancePreviewChat => 'Design-Team';

  @override
  String get desktopAppearancePreviewMembers => '5 Mitglieder, 3 online';

  @override
  String desktopAppearancePreviewTyping(Object name) {
    return '$name schreibt…';
  }

  @override
  String get desktopAppearancePreviewAnna => 'Anna';

  @override
  String get desktopAppearancePreviewMax => 'Max';

  @override
  String get desktopAppearancePreviewLiza => 'Lisa';

  @override
  String get desktopAppearancePreviewMsg1 => 'Ich habe den Hintergrund in unserem Chat erneuert – schaut mal';

  @override
  String get desktopAppearancePreviewMsg2 => 'Die lebendigen sind klasse. Vor allem die Welle beim Schreiben';

  @override
  String get desktopAppearancePreviewMsg3 => 'Ich probiere gleich dieselben aus';

  @override
  String get desktopAppearancePreviewMsg4 => 'Kann man auch die Textgröße ändern?';

  @override
  String get desktopAppearancePreviewMsg5 => 'Ja, unter „Aussehen“. Mehr auf www.secretlyapp.com';

  @override
  String get desktopAppearancePreviewOwnDefault => 'Ich teste, wie die neuen Einstellungen aussehen';

  @override
  String get desktopAppearancePreviewReply1 => 'Sieht super aus!';

  @override
  String get desktopAppearancePreviewReply2 => 'Oh, so ist es viel besser';

  @override
  String get desktopAppearancePreviewReply3 => 'Sag mir später, welchen Hintergrund du gewählt hast';

  @override
  String get desktopAppearancePreviewReply4 => 'Die Blasenfarbe steht dir';

  @override
  String get desktopAppearancePreviewReply5 => 'Ich stelle mir dieselben ein';

  @override
  String get desktopBackupEvery6h => 'Alle 6 Stunden';

  @override
  String get desktopBackupEvery12h => 'Alle 12 Stunden';

  @override
  String get desktopBackupDaily => 'Einmal am Tag';

  @override
  String get desktopBackupWeekly => 'Einmal pro Woche';

  @override
  String get desktopBackupOffWarning => 'Die automatische Sicherung ist aus – es gibt nichts, woraus der Verlauf wiederhergestellt werden könnte';

  @override
  String get desktopBackupNeverRan => 'Eingeschaltet, aber noch nie gelaufen';

  @override
  String desktopBackupLastFailedWith(Object error) {
    return 'Die letzte Sicherung ist fehlgeschlagen: $error';
  }

  @override
  String get desktopBackupLastFailed => 'Die letzte Sicherung ist fehlgeschlagen';

  @override
  String get desktopBackupStale => 'Die Sicherung wurde lange nicht aktualisiert';

  @override
  String get desktopBackupFresh => 'Die Sicherung ist aktuell';

  @override
  String get desktopBackupState => 'Zustand';

  @override
  String get desktopBackupAutomatic => 'Automatische Sicherung';

  @override
  String get desktopBackupAutomaticHint => 'Die Sicherung ist mit deinem Passwort verschlüsselt. Ohne das Passwort kann sie weder von uns noch von sonst jemandem wiederhergestellt werden – man muss es sich also merken.';

  @override
  String get desktopBackupCreateAuto => 'Automatisch erstellen';

  @override
  String get desktopBackupUploadServer => 'Auf den Server hochladen';

  @override
  String get desktopBackupUploadServerHint => 'Von jedem Gerät verfügbar';

  @override
  String get desktopBackupKeepLocal => 'Auf diesem Computer behalten';

  @override
  String get desktopBackupKeepLocalHint => 'Unabhängig vom Netz';

  @override
  String get desktopBackupIncludeMedia => 'Medien einschließen';

  @override
  String get desktopBackupIncludeMediaHint => 'Die Sicherung wird deutlich größer';

  @override
  String get desktopBackupFrequency => 'Häufigkeit';

  @override
  String get desktopBackupNowhereTitle => 'Die Sicherung wird nirgendwo gespeichert';

  @override
  String get desktopBackupNowhereHint => 'Die automatische Sicherung ist an, aber beide Ziele sind aus – es wird also keine Sicherung erstellt. Schalte den Server oder diesen Computer ein.';

  @override
  String get desktopBackupRecoveryKey => 'Wiederherstellungsset';

  @override
  String get desktopBackupCreateRecoveryKey => 'Wiederherstellungsset erstellen';

  @override
  String get desktopBackupRecoveryKeyHint => 'Du brauchst es, wenn kein Gerät mit Secretly mehr da ist. Bewahre es getrennt vom Passwort auf.';

  @override
  String desktopBackupKeyFailed(Object error) {
    return 'Der Schlüssel konnte nicht erstellt werden: $error';
  }

  @override
  String get desktopBackupKeyPassword => 'Passwort für das Wiederherstellungsset';

  @override
  String get desktopBackupPasswordsDiffer => 'Die Passwörter stimmen nicht überein.';

  @override
  String get desktopBackupKeyPasswordHint => 'Dieses Passwort verschlüsselt das Set selbst. Es ersetzt nicht das App-Passwort und wird nirgends gespeichert – es lässt sich nicht wiederherstellen.';

  @override
  String get desktopBackupPasswordAgain => 'Noch einmal';

  @override
  String desktopUnblockTitle(Object name) {
    return '$name entsperren?';
  }

  @override
  String get desktopUnblockBody => 'Diese Person kann dir wieder schreiben und dich anrufen.';

  @override
  String get desktopUnblockAction => 'Entsperren';

  @override
  String get desktopPrivacyLastSeen => 'Zuletzt online';

  @override
  String get desktopPrivacyProfilePhoto => 'Profilfotos';

  @override
  String get desktopPrivacyForwarding => 'Weiterleiten von Nachrichten';

  @override
  String get desktopPrivacyCalls => 'Anrufe';

  @override
  String get desktopPrivacyVoice => 'Sprachnachrichten';

  @override
  String get desktopPrivacyMessages => 'Nachrichten';

  @override
  String get desktopPrivacyNobody => 'Niemand';

  @override
  String get desktopPrivacyEverybody => 'Alle';

  @override
  String get desktopPrivacyContacts => 'Kontakte';

  @override
  String get desktopPrivacyEncryption => 'Verschlüsselung';

  @override
  String get desktopPrivacyEncryptionHint => 'Nachrichten, Dateien und Einzelanrufe sind Ende-zu-Ende-verschlüsselt; die Schlüssel liegen nur auf deinen Geräten. Ende-zu-Ende-Verschlüsselung für Gruppenanrufe wird schrittweise eingeführt: Ein Schloss im Anruf zeigt, dass sie aktiv ist; ohne Schloss ist der Anruf nur auf dem Transportweg verschlüsselt.';

  @override
  String get desktopPrivacyE2eeActive => 'Ende-zu-Ende-Verschlüsselung ist aktiv';

  @override
  String get desktopPrivacyWhoSees => 'Wer sieht was';

  @override
  String get desktopPrivacyWhoSeesHint => 'Dieselben Sichtbarkeitseinstellungen wie auf deinem Telefon. „Kontakte“ setzt die App um; der Server erzwingt nur „Niemand“.';

  @override
  String get desktopPrivacyVisibility => 'Sichtbarkeit';

  @override
  String get desktopPrivacyByNickname => 'Über den Spitznamen auffindbar';

  @override
  String get desktopPrivacyByNicknameHint => 'Lass dich über deinen Spitznamen finden';

  @override
  String get desktopPrivacySuggest => 'Personen in der Suche vorschlagen';

  @override
  String get desktopPrivacyStrangers => 'Neue Chats von Fremden';

  @override
  String get desktopPrivacyStrangersHint => 'Ins Archiv und ohne Benachrichtigungen';

  @override
  String get desktopPrivacyAutoDelete => 'Mein Konto löschen';

  @override
  String get desktopPrivacyAutoDeleteHint => 'Wenn du dich länger als die gewählte Frist nicht anmeldest, werden Konto, Schlüssel, Server-Backup und Nachrichtenwarteschlangen von unseren Servern gelöscht. Der Zähler beginnt bei jeder Anmeldung neu.';

  @override
  String get desktopPrivacyIfAbsent => 'Wenn ich mich nicht anmelde';

  @override
  String get desktopPrivacyIn1Month => 'Nach 1 Monat';

  @override
  String get desktopPrivacyIn3Months => 'Nach 3 Monaten';

  @override
  String get desktopPrivacyIn6Months => 'Nach 6 Monaten';

  @override
  String get desktopPrivacyIn1Year => 'Nach einem Jahr';

  @override
  String get desktopPrivacyIn2Years => 'Nach 2 Jahren';

  @override
  String get desktopLockImmediately => 'Sobald der Fokus verloren geht';

  @override
  String desktopLockSeconds(Object value) {
    return '$value Sek.';
  }

  @override
  String desktopLockMinutes(Object value) {
    return '$value Min.';
  }

  @override
  String desktopLockHours(Object value) {
    return '$value Std.';
  }

  @override
  String get desktopLockNoIdentityService => 'Der Identitätsdienst ist nicht verfügbar – die Sperre wurde nicht aktiviert.';

  @override
  String get desktopLockNotConfirmed => 'Die Sperre wurde nicht aktiviert: Die Bestätigung ist fehlgeschlagen.';

  @override
  String get desktopLockTitle => 'App-Sperre';

  @override
  String get desktopLockTouchIdHint => 'Nach Fokusverlust Touch ID zum Zurückkehren verlangen.';

  @override
  String get desktopLockPasswordHint => 'Nach Fokusverlust das Gerätepasswort zum Zurückkehren verlangen.';

  @override
  String get desktopLockEnableTouchId => 'Touch ID einschalten';

  @override
  String get desktopLockEnableLock => 'Sperre einschalten';

  @override
  String get desktopLockDevicePassword => 'Gerätepasswort';

  @override
  String get desktopLockAfter => 'Sperren nach';

  @override
  String get desktopLockNow => 'Jetzt sperren';

  @override
  String get desktopDevicesEndSessionTitle => 'Sitzung beenden?';

  @override
  String desktopDevicesEndSessionBody(Object id) {
    return 'Gerät $id wird von deinem Profil getrennt. Für den erneuten Zugriff ist ein neuer QR-Scan nötig. Fortfahren?';
  }

  @override
  String get desktopDevicesEnd => 'Beenden';

  @override
  String desktopDevicesEndFailed(Object error) {
    return 'Die Sitzung konnte nicht beendet werden: $error';
  }

  @override
  String get desktopDevicesEnded => 'Die Gerätesitzung wurde beendet.';

  @override
  String get desktopDevicesActiveSessions => 'Aktive Sitzungen';

  @override
  String get desktopDevicesDemoHint => 'Demomodus · echte Geräte erscheinen, sobald ein Profil verbunden ist';

  @override
  String get desktopDevicesThisComputer => 'macOS · Dieser Computer';

  @override
  String get desktopDevicesDemoMac => 'MacBook Pro · Jetzt aktiv';

  @override
  String get desktopDevicesDemoIphone => 'iOS 18.2 · vor 2 Stunden (Demo)';

  @override
  String get desktopDevicesDemoIpad => 'iPadOS 18 · gestern (Demo)';

  @override
  String get desktopDevicesThisDevice => 'Dieses Gerät';

  @override
  String get desktopDevicesRemoteDevice => 'Entferntes Gerät';

  @override
  String get desktopDevicesDisconnect => 'Trennen';

  @override
  String get desktopDevicesTitle => 'Geräte';

  @override
  String desktopDevicesTitleCount(Object count) {
    return 'Geräte · $count';
  }

  @override
  String get desktopDevicesHint => 'Die Geräte, die auf dem Schlüsselserver mit diesem Profil verbunden sind.';

  @override
  String get desktopDevicesLoadFailed => 'Konnte nicht geladen werden';

  @override
  String get desktopDevicesRetry => 'Erneut versuchen';

  @override
  String get desktopDevicesNone => 'Keine Geräte gefunden';

  @override
  String get desktopDevicesNotLinked => 'Das Profil ist noch nicht mit dem Server verbunden.';

  @override
  String get desktopDevicesRefresh => 'Liste aktualisieren';

  @override
  String get desktopAccentCustom => 'Eigene Farbe';

  @override
  String get desktopPairTitle => 'Gerät verbinden';

  @override
  String get desktopPairHint => 'Zeige den QR-Code auf dem neuen Gerät oder scanne ihn vom Telefon';

  @override
  String get desktopPairRequestFailed => 'Die Verbindungsanfrage konnte nicht erstellt werden';

  @override
  String get desktopPairCodeCopied => 'Der QR-Inhalt wurde kopiert';

  @override
  String get desktopPairNewTitle => 'Neues Gerät verbinden';

  @override
  String get desktopPairNewHint => 'Öffne auf dem neuen Gerät Secretly und wähle „Per QR verbinden“. Scanne dann den Code unten.';

  @override
  String get desktopPairClose => 'Schließen';

  @override
  String get desktopPairCopyCode => 'Code kopieren';

  @override
  String get desktopPairRefreshQr => 'QR erneuern';

  @override
  String desktopSyncPulled(Object count) {
    return 'Neue Ereignisse geladen: $count';
  }

  @override
  String get desktopSyncTooOften => 'Zu viele Anfragen – versuche es später';

  @override
  String get desktopSyncNothingNew => 'Fertig · keine neuen Ereignisse';

  @override
  String get desktopSyncDemoUnavailable => 'Im Demomodus nicht verfügbar';

  @override
  String desktopSyncBlobsPulled(Object blobs, Object convos) {
    return 'Anhänge geladen: $blobs (Chats: $convos)';
  }

  @override
  String desktopSyncNoBlobs(Object convos) {
    return 'Fertig · keine neuen Anhänge (Chats: $convos)';
  }

  @override
  String get desktopSyncTitle => 'Verlauf von anderen Geräten';

  @override
  String get desktopSyncHint => 'Den aktuellen Chatverlauf vom Telefon anfordern. Wird genutzt, wenn der Computer länger als 7 Tage offline war oder gerade per QR verbunden wurde.';

  @override
  String get desktopSyncRunning => 'Wird synchronisiert…';

  @override
  String get desktopSyncAskHistory => 'Verlauf anfordern';

  @override
  String get desktopSyncAsk => 'Anfordern';

  @override
  String get desktopSyncBlobsRunning => 'Anhänge werden geladen…';

  @override
  String get desktopSyncBlobsAction => 'Anhänge nachladen';

  @override
  String get desktopSyncBlobsHint => 'Lädt Medien aus den letzten Chats, wenn die Dateien lokal fehlen (nach erneutem Verbinden oder langer Offline-Zeit).';

  @override
  String get desktopSyncBlobsShort => 'Nachladen';

  @override
  String desktopServerBackupOk(Object stamp, Object size, Object profile) {
    return 'Sicherung auf dem Server ✓ · $stamp · $size KB · Profil $profile';
  }

  @override
  String get desktopServerBackupPassword => 'Passwort der Sicherung';

  @override
  String get desktopServerBackupPasswordHint => 'Mit diesem Passwort wird die Sicherung verschlüsselt und auf jedem Gerät wiederhergestellt. Merke es dir – ohne das Passwort ist die Sicherung nutzlos und nicht wiederherstellbar.';

  @override
  String get desktopServerBackupRepeat => 'Passwort wiederholen';

  @override
  String get desktopServerBackupCreate => 'Sicherung erstellen';

  @override
  String get desktopServerBackupTitle => 'Sicherung auf den Server';

  @override
  String get desktopServerBackupHint => 'Eine verschlüsselte Kopie des Kontos auf dem Secretly-Server. Sie wird auf jedem Gerät über „Vom Server wiederherstellen“ mit deiner Secretly-ID und dem Passwort zurückgeholt.';

  @override
  String get desktopServerBackupLoading => 'Wird hochgeladen…';

  @override
  String get desktopServerBackupCreateOnServer => 'Sicherung auf dem Server erstellen';

  @override
  String get desktopServerBackupUpdate => 'Sicherung aktualisieren';

  @override
  String desktopFailedWith(Object error) {
    return 'Fehlgeschlagen: $error';
  }

  @override
  String get desktopStorageDeleteModelTitle => 'Das Erkennungsmodell löschen?';

  @override
  String get desktopStorageDeleteModelBody => 'Das Transkribieren von Sprachnachrichten funktioniert nicht mehr, bis das Modell erneut geladen wird.';

  @override
  String get desktopStorageModelDeleted => 'Das Modell wurde gelöscht';

  @override
  String desktopStorageDeleteFailed(Object error) {
    return 'Konnte nicht gelöscht werden: $error';
  }

  @override
  String desktopStorageKb(Object value) {
    return '$value KB';
  }

  @override
  String desktopStorageMb(Object value) {
    return '$value MB';
  }

  @override
  String desktopStorageGb(Object value) {
    return '$value GB';
  }

  @override
  String get desktopStorageUsage => 'Nutzung';

  @override
  String get desktopStorageUsageHint => 'Cache und Medien auf diesem Gerät';

  @override
  String desktopStorageClearHint(Object size) {
    return '$size werden frei. Nachrichten, von dir gesendete Dateien und die zuletzt genutzten werden nicht gelöscht – sie ließen sich nirgendwo wiederherstellen.';
  }

  @override
  String get desktopStorageClear => 'Cache leeren';

  @override
  String get desktopStorageCounting => 'Wird berechnet…';

  @override
  String get desktopStorageSpeechModel => 'Spracherkennungsmodell';

  @override
  String get desktopStorageSpeechModelHint => 'Wird genutzt, um Sprachnachrichten auf diesem Computer zu transkribieren, ohne den Ton irgendwohin zu senden. Ein normales Leeren des Caches entfernt es NICHT – es ist groß und wird separat geladen.';

  @override
  String get desktopStorageDeleteModel => 'Modell löschen';

  @override
  String desktopStorageMedia(Object size) {
    return 'Medien · $size';
  }

  @override
  String desktopStorageVoice(Object size) {
    return 'Sprache · $size';
  }

  @override
  String desktopStorageOther(Object size) {
    return 'Sonstiges · $size';
  }

  @override
  String get desktopStorageFree => 'Frei';

  @override
  String desktopStorageTotal(Object size) {
    return 'Gesamt · $size';
  }

  @override
  String desktopAboutVersion(Object version, Object build) {
    return 'Version $version · Build $build';
  }

  @override
  String get desktopAboutTagline => 'Ein Ende-zu-Ende-verschlüsselter Messenger. Keine Werbung. Quellcode unter AGPL-3.0.';

  @override
  String get desktopAboutLicences => 'Lizenzen';

  @override
  String get desktopAboutWebsite => 'Website';

  @override
  String get desktopDangerTitle => 'Konto unwiderruflich löschen?';

  @override
  String get desktopDangerBody => 'Profil, Schlüssel, lokale Daten und Nachrichtenverlauf werden auf diesem und anderen Geräten gelöscht. Eine Wiederherstellung ist unmöglich.';

  @override
  String get desktopDangerDeleting => 'Konto wird gelöscht…';

  @override
  String desktopDangerFailed(Object error) {
    return 'Das Konto konnte nicht gelöscht werden: $error';
  }

  @override
  String get desktopDangerSection => 'Konto löschen';

  @override
  String get desktopDangerDemo => 'Demomodus · Löschen ist ohne verbundenes Profil nicht möglich.';

  @override
  String get desktopDangerEnterId => 'Gib zur Bestätigung deine Secretly-ID ein';

  @override
  String desktopDangerEnterIdExact(Object id) {
    return 'Gib zur Bestätigung $id ein';
  }

  @override
  String get desktopDangerAction => 'Konto löschen';

  @override
  String get desktopDangerIrreversible => 'Das lässt sich nicht rückgängig machen. Alle deine Daten, der Nachrichtenverlauf und die Schlüssel werden gelöscht. Eine Wiederherstellung ist unmöglich.';

  @override
  String get desktopSecurityE2ee => 'Ende-zu-Ende-Verschlüsselung';

  @override
  String get desktopSecurityE2eeHint => 'Nachrichten, Dateien und Einzelanrufe werden auf deinem Gerät verschlüsselt, die Schlüssel verlassen deine Geräte nie. Der Server kann keine Inhalte lesen, sieht aber Verbindungsdaten – etwa, wer wem wann schreibt. Ende-zu-Ende-Verschlüsselung für Gruppenanrufe wird schrittweise eingeführt: Ein Schloss im Anruf zeigt, dass sie aktiv ist; ohne Schloss ist der Anruf nur auf dem Transportweg verschlüsselt.';

  @override
  String get desktopSecurityVerifiedDevices => 'Verifizierte Geräte';

  @override
  String get desktopSecurityVerifiedHint => 'Solange dies an ist, gehen Nachrichten nicht an unbestätigte Geräte der anderen Person. Das schützt vor Unterschiebung, aber eine Nachricht kommt womöglich erst an, wenn ein neues Gerät bestätigt wurde. Nur Einzelchats: für Gruppen gilt es nicht.';

  @override
  String get desktopSecurityOnlyVerified => 'Nur verifizierte Geräte';

  @override
  String get desktopSecurityBlocked => 'Nicht verifizierte Geräte werden blockiert';

  @override
  String get desktopSecurityAllDevices => 'Nachrichten gehen an alle Geräte der anderen Person';

  @override
  String get desktopSecurityAppEntry => 'Zugang zur App';

  @override
  String get desktopSecurityAppEntryHint => 'Ein Passwort beim Öffnen von Secretly und nachdem das Fenster länger als eine Minute verborgen war. Gilt für diesen Computer.';

  @override
  String get desktopSecurityPersonalScopeHint => 'Ein eigenes Passwort für die Kategorie „Persönlich“. Ohne es sind persönliche Chats für jeden offen, der Zugang zu einem entsperrten Computer hat.';

  @override
  String get desktopCallsInApp => 'Anrufe in der App';

  @override
  String get desktopCallsInAppHint => 'Ausschalten, um Anrufe vollständig zu deaktivieren';

  @override
  String get desktopCallsAccept => 'Eingehende Anrufe annehmen';

  @override
  String get desktopCallsAcceptHint => 'Man kann dich anrufen';

  @override
  String get desktopCallsDisabledHint => 'Nicht verfügbar, solange Anrufe aus sind';

  @override
  String get desktopCallsScreenShare => 'Bildschirmfreigabe';

  @override
  String get desktopCallsScreenShareHint => 'Den Bildschirm einer anderen Person zu empfangen ist eine eigene Erlaubnis: Dort kann etwas erscheinen, das du nicht erwartet hast.';

  @override
  String get desktopCallsAcceptScreenShare => 'Bildschirmfreigabe annehmen';

  @override
  String get desktopAccountIdCopied => 'Die Secretly-ID wurde kopiert';

  @override
  String get desktopAccountIdHint => 'Diese Kennung teilst du, damit man dich findet. Sie enthält weder Telefonnummer noch E-Mail.';

  @override
  String get desktopAccountCopy => 'Kopieren';

  @override
  String get desktopAccountProfile => 'Profil';

  @override
  String get desktopAccountProfileHint => 'Name, Foto, Status';

  @override
  String get desktopAccountOpenProfile => 'Profilseite öffnen';

  @override
  String desktopScopePasswordFor(Object name) {
    return 'Passwort für „$name“';
  }

  @override
  String get desktopScopeMin4 => 'Mindestens 4 Zeichen';

  @override
  String get desktopScopeOn => 'Schutz ist an';

  @override
  String desktopScopeOnFailed(Object error) {
    return 'Konnte nicht eingeschaltet werden: $error';
  }

  @override
  String get desktopScopeOff => 'Schutz ist aus';

  @override
  String desktopScopeOffFailed(Object error) {
    return 'Konnte nicht ausgeschaltet werden: $error';
  }

  @override
  String get desktopScopePasswordsDiffer => 'Die Passwörter stimmen nicht überein';

  @override
  String get desktopScopeTitle => 'Passwortschutz';

  @override
  String get desktopScopeOnWithPassword => 'An – Passwort';

  @override
  String get desktopScopeEnabled => 'An';

  @override
  String get desktopScopeDisabled => 'Aus';

  @override
  String get desktopScopeChangePassword => 'Passwort ändern';

  @override
  String get desktopScopeLockNow => 'Sperren';

  @override
  String desktopBlockedUnblocked(Object name) {
    return '$name wurde entsperrt';
  }

  @override
  String desktopBlockedUnblockFailed(Object error) {
    return 'Konnte nicht entsperrt werden: $error';
  }

  @override
  String get desktopBlockedTitle => 'Blockiert';

  @override
  String get desktopBlockedEmptyHint => 'Die Liste ist leer. Blockiert wird über das Menü eines Chats.';

  @override
  String get desktopBlockedHint => 'Diese Personen können dir weder schreiben noch dich anrufen.';

  @override
  String get desktopBlockedNone => 'Niemand ist blockiert';

  @override
  String get desktopSupportSent => 'Die Nachricht wurde gesendet';

  @override
  String get desktopSupportSendFailed => 'Senden fehlgeschlagen. Prüfe deine Verbindung.';

  @override
  String get desktopSupportUnavailable => 'Der Support ist nicht verfügbar';

  @override
  String get desktopSupportUnavailableHint => 'Der Support ist gerade abgeschaltet. Versuche es später oder schreibe vom Telefon.';

  @override
  String get desktopSupportThread => 'Die Unterhaltung mit dem Support';

  @override
  String get desktopSupportThreadHint => 'Nachrichten werden auf deinem Gerät verschlüsselt. Der Server speichert nur Chiffretext – lesen kann die Unterhaltung nur der Support.';

  @override
  String get desktopSupportNoReplies => 'Noch keine Antworten. Beschreibe das Problem – die Antwort kommt hierher.';

  @override
  String get desktopSupportWrite => 'An den Support schreiben';

  @override
  String get desktopSupportWriteHint => 'Buildversion und Gerätekennung werden automatisch angehängt – ohne sie lässt sich das Problem kaum nachstellen.';

  @override
  String get desktopSupportDescribe => 'Beschreibe, was passiert ist';

  @override
  String get desktopSupportSending => 'Wird gesendet…';

  @override
  String get desktopSupportSend => 'Senden';

  @override
  String get desktopChatsEmptyHint => 'Beginne ein Gespräch am Telefon – Chats werden automatisch auf den Computer übertragen';

  @override
  String get desktopChatsPickOne => 'Wähle links einen Chat';

  @override
  String desktopChatsSendFailed(Object error) {
    return 'Senden fehlgeschlagen: $error';
  }

  @override
  String desktopChatsSendingTo(Object title) {
    return 'Wird an „$title“ gesendet';
  }

  @override
  String get desktopChatsFilterAll => 'Alle';

  @override
  String get desktopChatsFilterUnread => 'Ungelesen';

  @override
  String get desktopChatsFilterGroups => 'Gruppen';

  @override
  String get desktopChatsFilterArchive => 'Archiv';

  @override
  String get desktopChatsFilterPersonal => 'Persönlich';

  @override
  String get desktopChatsRenameFolder => 'Ordner umbenennen';

  @override
  String get desktopChatsDeleteFolder => 'Ordner löschen';

  @override
  String desktopChatsRenameFailed(Object error) {
    return 'Umbenennen fehlgeschlagen: $error';
  }

  @override
  String desktopChatsDeleteFolderTitle(Object name) {
    return 'Ordner „$name“ löschen?';
  }

  @override
  String get desktopChatsDeleteFolderBody => 'Die Chats bleiben, wo sie sind – nur der Ordner wird gelöscht.';

  @override
  String desktopChatsDeleteFailed(Object error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String desktopChatsAddedToFolder(Object name) {
    return 'Zu „$name“ hinzugefügt';
  }

  @override
  String desktopChatsRemovedFromFolder(Object name) {
    return 'Aus „$name“ entfernt';
  }

  @override
  String desktopChatsFolderChangeFailed(Object error) {
    return 'Der Ordner konnte nicht geändert werden: $error';
  }

  @override
  String desktopChatsFolderCreated(Object name) {
    return 'Der Ordner „$name“ wurde erstellt';
  }

  @override
  String desktopChatsFolderCreateFailed(Object error) {
    return 'Der Ordner konnte nicht erstellt werden: $error';
  }

  @override
  String get desktopChatsNewFolder => 'Neuer Ordner';

  @override
  String get desktopChatsFolderName => 'Name des Ordners';

  @override
  String desktopChatsRemoveFromFolder(Object name) {
    return 'Aus „$name“ entfernen';
  }

  @override
  String desktopChatsAddToFolder(Object name) {
    return 'In den Ordner „$name“';
  }

  @override
  String get desktopChatsNewFolderWithChat => 'Neuer Ordner mit diesem Chat…';

  @override
  String get desktopChatsRemoveFromPersonal => 'Aus „Persönlich“ entfernen';

  @override
  String get desktopChatsAddToPersonal => 'Zu „Persönlich“';

  @override
  String get desktopChatsArchiveEmpty => 'Das Archiv ist leer';

  @override
  String get desktopChatsNoPersonal => 'Es gibt keine persönlichen Chats';

  @override
  String get desktopChatsPersonalLocked => 'Persönliche Chats sind passwortgeschützt';

  @override
  String get desktopChatsAllRead => 'Alles gelesen';

  @override
  String get desktopChatsFolderEmpty => 'Dieser Ordner ist noch leer';

  @override
  String get desktopChatsNewChat => 'Neuer Chat';

  @override
  String get desktopChatsNewRoom => 'Neuer Raum';

  @override
  String get desktopChatsStartFailed => 'Der Chat konnte nicht gestartet werden: das Profil ist nicht verfügbar';

  @override
  String get desktopChatsPhoto => 'Foto';

  @override
  String get desktopChatsVideo => 'Video';

  @override
  String get desktopChatsAudio => 'Audio';

  @override
  String get desktopChatsVoiceMessage => 'Sprachnachricht';

  @override
  String get desktopChatsVoiceShort => 'Sprache';

  @override
  String get desktopChatsLink => 'Link';

  @override
  String get desktopChatsSticker => 'Sticker';

  @override
  String desktopChatsStickerWith(Object label) {
    return 'Sticker $label';
  }

  @override
  String desktopChatsPoll(Object question) {
    return '📊 Umfrage: $question';
  }

  @override
  String get desktopChatsUnknown => 'unbekannt';

  @override
  String get desktopChatsMember => 'Mitglied';

  @override
  String get desktopChatsSoundOn => 'Ton einschalten';

  @override
  String get desktopChatsSoundOff => 'Stumm';

  @override
  String get desktopMuteMenu => 'Stummschalten…';

  @override
  String get desktopMuteFor1h => 'Für 1 Stunde';

  @override
  String get desktopMuteFor8h => 'Für 8 Stunden';

  @override
  String get desktopMuteFor2d => 'Für 2 Tage';

  @override
  String get desktopMuteForever => 'Bis ich es wieder einschalte';

  @override
  String get desktopMuteMentionsOnly => 'Nur Erwähnungen';

  @override
  String get desktopChatsClearHistoryTitle => 'Verlauf löschen?';

  @override
  String desktopChatsClearHistoryBody(Object title) {
    return 'Alle Nachrichten des Chats „$title“ werden auf diesem Gerät gelöscht.';
  }

  @override
  String get desktopChatsClear => 'Löschen';

  @override
  String get desktopChatsHistoryClearedBoth => 'Der Verlauf wurde bei beiden gelöscht';

  @override
  String get desktopChatsHistoryCleared => 'Der Verlauf wurde gelöscht';

  @override
  String get desktopChatsDeleteChatTitle => 'Chat löschen?';

  @override
  String desktopChatsDeleteChatBody(Object title) {
    return 'Der Chat „$title“ wird vollständig von diesem Gerät entfernt.';
  }

  @override
  String get desktopRoomDeleteLeaveMenu => 'Löschen und verlassen';

  @override
  String desktopRoomDeleteLeaveTitle(String title) {
    return '„$title“ löschen und verlassen?';
  }

  @override
  String get desktopRoomDeleteLeaveBody => 'Sie verlassen den Raum und erhalten keine Nachrichten mehr; der Verlauf wird von diesem Computer gelöscht. Zurück geht es nur mit einer neuen Einladung.';

  @override
  String get desktopRoomDeleteLeaveAction => 'Verlassen und löschen';

  @override
  String get desktopChatsRooms => 'Räume';

  @override
  String get desktopChatsGeneralTopic => 'Allgemein';

  @override
  String get desktopChatsNewTopicEllipsis => 'Neues Thema…';

  @override
  String desktopChatsBranch(Object title) {
    return 'Zweig „$title“';
  }

  @override
  String get desktopChatsRename => 'Umbenennen';

  @override
  String get desktopChatsIcon => 'Symbol';

  @override
  String get desktopChatsDeleteBranch => 'Zweig löschen';

  @override
  String get desktopChatsBranchIcon => 'Symbol des Zweigs';

  @override
  String get desktopChatsBranchIconHint => 'Das Symbol ersetzt das Rautenzeichen vor dem Namen. Farbige versprechen, was drin ist: Grün ein Anruf, Rot etwas Dringendes. Die übrigen sind grau, damit sie dem Namen nicht widersprechen.';

  @override
  String get desktopChatsHash => 'Raute';

  @override
  String desktopChatsBranchFailed(Object error) {
    return 'Die Zweige konnten nicht geändert werden: $error';
  }

  @override
  String get desktopChatsNewTopic => 'Neues Thema';

  @override
  String get desktopChatsRenameTopic => 'Thema umbenennen';

  @override
  String get desktopChatsTopicName => 'Name des Themas';

  @override
  String desktopChatsReactionFailed(Object error) {
    return 'Die Reaktion konnte nicht gespeichert werden: $error';
  }

  @override
  String desktopChatsReactionLocal(Object error) {
    return 'Die Reaktion wurde lokal übernommen, aber nicht an die andere Person zugestellt: $error';
  }

  @override
  String get desktopChatsRevealFailed => 'Die Datei konnte nicht im Finder gezeigt werden';

  @override
  String desktopChatsVideoOpenFailed(Object error) {
    return 'Das Video konnte nicht geöffnet werden: $error';
  }

  @override
  String get desktopChatsVideoUnavailable => 'Das Video ist nicht verfügbar';

  @override
  String desktopChatsFileFetchFailed(Object error) {
    return 'Die Datei konnte nicht geholt werden: $error';
  }

  @override
  String get desktopChatsSaveAttachment => 'Anhang speichern';

  @override
  String get desktopChatsFileUnavailable => 'Die Datei ist nicht verfügbar';

  @override
  String desktopChatsSaveFailed(Object error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String desktopChatsOpenFailedWith(Object error) {
    return 'Die Datei konnte nicht geöffnet werden: $error';
  }

  @override
  String get desktopChatsOpenFailed => 'Die Datei konnte nicht geöffnet werden';

  @override
  String desktopChatsOpenFailedShort(Object error) {
    return 'Öffnen fehlgeschlagen: $error';
  }

  @override
  String get desktopFileRiskTitle => 'Diese Datei öffnen?';

  @override
  String desktopFileRiskExtension(Object ext) {
    return 'Diese Datei hat die Endung $ext und kann ein Programm starten, das Ihrem Computer schadet. Öffnen Sie sie nur, wenn Sie dem Absender vertrauen.';
  }

  @override
  String get desktopFileRiskNoExtension => 'Diese Datei hat keine Endung, daher könnte Ihr Computer sie als Programm ausführen. Öffnen Sie sie nur, wenn Sie dem Absender vertrauen.';

  @override
  String desktopFileRiskMismatch(Object ext) {
    return 'Der Absender hat diese Datei als Bild, Audio, Video oder PDF ausgegeben, ihre echte Endung ist aber $ext. So werden gefährliche Dateien getarnt – öffnen Sie sie nur, wenn Sie dem Absender vertrauen.';
  }

  @override
  String get desktopFileRiskShowInFolder => 'Im Ordner zeigen';

  @override
  String get desktopFileRiskOpenAnyway => 'Trotzdem öffnen';

  @override
  String desktopChatsPlayFailed(Object error) {
    return 'Wiedergabe fehlgeschlagen: $error';
  }

  @override
  String get desktopChatsNoCallPeer => 'Es ließ sich nicht ermitteln, wen der Anruf erreichen soll.';

  @override
  String get desktopChatsCallsNotReady => 'Der Anrufdienst ist nicht bereit.';

  @override
  String get desktopChatsCallInProgress => 'Ein Anruf läuft bereits.';

  @override
  String get desktopChatsEditFailed => 'Die Nachricht konnte nicht geändert werden.';

  @override
  String get desktopChatsNoRecipient => 'Der Empfänger ließ sich nicht ermitteln.';

  @override
  String get desktopChatsDeleteMessageTitle => 'Nachricht löschen?';

  @override
  String get desktopChatsDeleteMessagesTitle => 'Ausgewählte Nachrichten löschen?';

  @override
  String get desktopChatsDeleteOthersHint => 'Nachrichten anderer werden nur bei dir gelöscht.';

  @override
  String get desktopChatsDeleteForAll => 'Für alle löschen';

  @override
  String get desktopChatsDeleteForMeOnly => 'Nur bei mir löschen';

  @override
  String get desktopChatsDeleteForMe => 'Bei mir löschen';

  @override
  String get desktopChatsSavePrivacyBlocked => 'Diese Nachricht lässt sich wegen Datenschutzeinschränkungen nicht speichern.';

  @override
  String get desktopChatsNothingToSave => 'Der Anhang wurde nicht geladen – es gibt nichts zu speichern';

  @override
  String get desktopChatsSavedPartly => 'In Favoriten gespeichert, aber nicht alles';

  @override
  String get desktopChatsSaved => 'In Favoriten gespeichert';

  @override
  String get desktopChatsForwardPrivacyBlocked => 'Diese Nachricht lässt sich wegen Datenschutzeinschränkungen nicht weiterleiten.';

  @override
  String desktopChatsForwardFailed(Object error) {
    return 'Weiterleiten fehlgeschlagen: $error';
  }

  @override
  String get desktopChatsNothingToForward => 'Der Anhang wurde nicht geladen – es gibt nichts weiterzuleiten';

  @override
  String desktopChatsForwardedPartly(Object title) {
    return 'An „$title“ weitergeleitet, aber nicht alles';
  }

  @override
  String desktopChatsForwarded(Object title) {
    return 'An „$title“ weitergeleitet';
  }

  @override
  String desktopChatsFileNotSentElsewhere(Object text) {
    return 'Die Datei wurde nicht an die andere Unterhaltung gesendet: $text';
  }

  @override
  String get desktopChatsFileSendFailed => 'Die Datei konnte nicht gesendet werden.';

  @override
  String desktopChatsPremiumFiles(Object text) {
    return '$text Mit Premium kannst du Dateien bis 1 GB senden.';
  }

  @override
  String get desktopChatsTypingEllipsis => 'schreibt…';

  @override
  String get desktopChatsOnline => 'online';

  @override
  String desktopChatsSomeoneTyping(Object name) {
    return '$name schreibt';
  }

  @override
  String get desktopChatsLoadingList => 'Die Liste wird aus dem lokalen Speicher geladen.';

  @override
  String get desktopChatsWillAppear => 'Nachrichten und Anrufe erscheinen hier, sobald du einen Chat öffnest.';

  @override
  String get desktopRoomNoOpenHere => 'Von hier lässt sich kein Chat öffnen';

  @override
  String get desktopRoomIdCopied => 'Die ID wurde kopiert';

  @override
  String get desktopRoomAwaiting => 'Wartet auf Freigabe';

  @override
  String get desktopRoomBlocked => 'Blockiert';

  @override
  String get desktopRoomCopied => 'Kopiert';

  @override
  String get desktopRoomChangeRole => 'Rolle ändern';

  @override
  String get desktopRoomTransfer => 'Besitz übertragen';

  @override
  String get desktopRoomBlockMember => 'Blockieren';

  @override
  String get desktopRoomKick => 'Entfernen';

  @override
  String get desktopRoomKickTitle => 'Mitglied entfernen?';

  @override
  String desktopRoomKickBody(Object name) {
    return '$name verliert den Zugang zum Raum. Eine neue Einladung bringt die Person zurück.';
  }

  @override
  String get desktopRoomBlockTitle => 'Mitglied blockieren?';

  @override
  String desktopRoomBlockBody(Object name) {
    return '$name kann nicht in den Raum zurück, auch nicht mit Einladung, solange die Sperre besteht.';
  }

  @override
  String get desktopRoomTransferTitle => 'Besitz des Raums übertragen?';

  @override
  String desktopRoomTransferBody(Object name) {
    return '$name wird Eigentümer und du wirst Administrator. Nur der neue Eigentümer kann das rückgängig machen.';
  }

  @override
  String get desktopRoomTransferAction => 'Übertragen';

  @override
  String get desktopRoomClearTitle => 'Verlauf löschen?';

  @override
  String get desktopRoomClearBody => 'Alle Nachrichten des Raums werden auf diesem Gerät gelöscht.';

  @override
  String get desktopRoomLeaveTitle => 'Raum verlassen?';

  @override
  String get desktopRoomLeaveBody => 'Du erhältst keine Nachrichten mehr. Für die Rückkehr braucht es eine neue Einladung.';

  @override
  String get desktopRoomLeave => 'Verlassen';

  @override
  String get desktopRoomInvite => 'Einladen';

  @override
  String get desktopRoomCopyId => 'Raum-ID kopieren';

  @override
  String get desktopRoomMuteOff => 'Benachrichtigungen abschalten';

  @override
  String get desktopRoomUnarchive => 'Aus dem Archiv holen';

  @override
  String get desktopRoomLeaveRoom => 'Raum verlassen';

  @override
  String get desktopRoomUntitled => 'Ohne Namen';

  @override
  String get desktopRoomCopyInvite => 'Einladung kopieren';

  @override
  String get desktopRoomInviteCardTitle => 'Raum-Einladung';

  @override
  String get desktopRoomInviteCardHint => 'Öffne die Karte, um den Raum anzusehen und beizutreten.';

  @override
  String get desktopRoomInviteAlreadyMember => 'Du bist bereits im Raum';

  @override
  String get desktopRoomInviteApprovalRequired => 'Genehmigung erforderlich';

  @override
  String get desktopRoomInviteDirectJoin => 'Direkt beitreten';

  @override
  String get desktopRoomInviteWithHistory => 'mit Verlauf';

  @override
  String get desktopRoomInviteWithoutHistory => 'ohne Verlauf';

  @override
  String desktopRoomInviteInvitedBy(String name) {
    return 'Eingeladen von $name';
  }

  @override
  String get desktopRoomInviteHistoryOn => 'Verlauf für neue Mitglieder ist an';

  @override
  String get desktopRoomInviteHistoryOff => 'Verlauf für neue Mitglieder ist aus';

  @override
  String get desktopRoomInviteJoin => 'Beitreten';

  @override
  String get desktopRoomInviteRequestAccess => 'Zugang anfragen';

  @override
  String get desktopRoomInviteOpenRequest => 'Anfrage öffnen';

  @override
  String get desktopRoomInviteOpenRoom => 'Raum öffnen';

  @override
  String desktopRoomInviteReplyQuote(String title) {
    return 'Einladung zu „$title“';
  }

  @override
  String get desktopRoomSound => 'Ton';

  @override
  String get desktopRoomTabInfo => 'Info';

  @override
  String get desktopRoomTabMembers => 'Mitglieder';

  @override
  String get desktopRoomTabMedia => 'Medien';

  @override
  String get desktopRoomTopics => 'THEMEN';

  @override
  String desktopRoomTopicsCount(Object count) {
    return 'THEMEN · $count';
  }

  @override
  String get desktopRoomDescription => 'Beschreibung';

  @override
  String get desktopRoomNotes => 'NOTIZEN';

  @override
  String get desktopRoomInformation => 'Informationen';

  @override
  String get desktopRoomId => 'Raum-ID';

  @override
  String get desktopRoomInviteLink => 'Einladungslink · zum Kopieren klicken';

  @override
  String get desktopRoomFavouriteHint => 'Eine Kachel an der Leiste und ein Platz oben in der Liste';

  @override
  String get desktopRoomArchiveHint => 'Den Raum aus der Hauptliste ausblenden';

  @override
  String get desktopRoomNoMembers => 'Keine Mitglieder';

  @override
  String desktopRoomMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '$count Mitglied',
    );
    return '$_temp0';
  }

  @override
  String get desktopRoomNobodyFound => 'Niemand gefunden';

  @override
  String get desktopRoomMembersUnavailable => 'Die Mitgliederliste ist nicht verfügbar.';

  @override
  String get desktopRoomInCall => 'IM ANRUF';

  @override
  String get desktopRoomOnline => 'ONLINE';

  @override
  String get desktopRoomOffline => 'OFFLINE';

  @override
  String get desktopRoomShowAllMembers => 'Alle anzeigen';

  @override
  String desktopRoomMoreHidden(Object count) {
    return 'Noch $count – nutze die Suche oben';
  }

  @override
  String get desktopRoomSearchMember => 'Mitglied suchen';

  @override
  String get desktopRoomJoinRequests => 'Beitrittsanfragen';

  @override
  String get desktopRoomAccept => 'Annehmen';

  @override
  String get desktopRoomDecline => 'Ablehnen';

  @override
  String get desktopRoomRoleOwner => 'Eigentümer';

  @override
  String get desktopRoomRoleAdmin => 'Administrator';

  @override
  String get desktopRoomRoleModerator => 'Moderator';

  @override
  String get desktopRoomRoleRestricted => 'Eingeschränkt';

  @override
  String get desktopRoomRoleGuest => 'Gast';

  @override
  String get desktopContactBlockTitle => 'Blockieren?';

  @override
  String get desktopContactUnblockTitle => 'Entsperren?';

  @override
  String get desktopContactBlockBody => 'Diese Person kann dir keine Nachrichten mehr senden und dich nicht mehr anrufen.';

  @override
  String get desktopContactUnblockBody => 'Diese Person kann dich wieder erreichen.';

  @override
  String get desktopContactBlock => 'Blockieren';

  @override
  String get desktopContactCallsNotReady => 'Der Anrufdienst ist noch nicht bereit';

  @override
  String get desktopContactCallInProgress => 'Ein Anruf läuft bereits';

  @override
  String desktopContactCallFailed(Object error) {
    return 'Der Anruf konnte nicht gestartet werden: $error';
  }

  @override
  String get desktopContactAutoDelete => 'Automatisches Löschen von Nachrichten';

  @override
  String get desktopContactAutoDeleteUpdated => 'Das automatische Löschen wurde aktualisiert';

  @override
  String get desktopContactClearBody => 'Alle Nachrichten dieses Chats werden auf diesem Gerät gelöscht.';

  @override
  String get desktopContactDeleteBody => 'Der Chat wird vollständig von diesem Gerät entfernt.';

  @override
  String get desktopContactOff => 'Aus';

  @override
  String get desktopContactDisable => 'Ausschalten';

  @override
  String get desktopContactDay1 => '1 Tag';

  @override
  String get desktopContactDays7 => '7 Tage';

  @override
  String get desktopContactDays30 => '30 Tage';

  @override
  String get desktopContactHour1 => '1 Stunde';

  @override
  String desktopContactMinutes(Object value) {
    return '$value Min.';
  }

  @override
  String get desktopContactOffline => 'offline';

  @override
  String desktopContactSeenAt(Object time) {
    return 'zuletzt um $time';
  }

  @override
  String get desktopContactSeenYesterday => 'zuletzt gestern';

  @override
  String desktopContactSeenOn(Object date) {
    return 'zuletzt am $date';
  }

  @override
  String get desktopContactCopyId => 'ID kopieren';

  @override
  String get desktopContactCopyIdShort => 'ID kopieren';

  @override
  String get desktopContactDisappearing => 'Automatisch löschen auf meinen Geräten';

  @override
  String get desktopContactDeleteChat => 'Chat löschen';

  @override
  String get desktopContactCall => 'Anruf';

  @override
  String get desktopContactBlockShort => 'Block';

  @override
  String get desktopContactSecurity => 'Sicherheit';

  @override
  String get desktopContactVerify => 'Kontakt verifizieren';

  @override
  String get desktopContactArchiveHint => 'Den Chat aus der Hauptliste ausblenden';

  @override
  String get desktopThreadMessageHint => 'Nachricht…';

  @override
  String get desktopThreadPasteFailed => 'Das Bild konnte nicht eingefügt werden';

  @override
  String get desktopThreadNoScheduleEdit => 'Eine Änderung lässt sich nicht planen – sie betrifft bereits Gesendetes';

  @override
  String desktopThreadWillLeave(Object when) {
    return 'Geht raus $when';
  }

  @override
  String desktopThreadSeconds(Object value) {
    return '$value Sek.';
  }

  @override
  String desktopThreadMinutes(Object value) {
    return '$value Min.';
  }

  @override
  String desktopThreadHours(Object value) {
    return '$value Std.';
  }

  @override
  String desktopThreadDays(Object value) {
    return '$value Tg.';
  }

  @override
  String desktopThreadWeeks(Object value) {
    return '$value Wo.';
  }

  @override
  String desktopThreadSelected(Object count) {
    return 'Ausgewählt: $count';
  }

  @override
  String get desktopThreadDisappearingOn => 'Automatisches Löschen ist an – nur auf meinen Geräten';

  @override
  String get desktopThreadCallAction => 'Anrufen';

  @override
  String get desktopThreadCallRoom => 'Gruppenanruf';

  @override
  String get desktopThreadVideoCall => 'Videoanruf';

  @override
  String get desktopThreadSearchShortcut => 'Im Chat suchen  Cmd F';

  @override
  String get desktopThreadHideDetails => 'Details ausblenden';

  @override
  String get desktopThreadShowDetails => 'Details anzeigen';

  @override
  String get desktopThreadMore => 'Mehr';

  @override
  String get desktopThreadPinned => 'Angeheftete Nachricht';

  @override
  String get desktopThreadNoMatches => 'keine Treffer';

  @override
  String get desktopThreadSearchHint => 'Im Chat suchen…';

  @override
  String get desktopThreadPrevMatch => 'Vorheriges (Shift F3)';

  @override
  String get desktopThreadNextMatch => 'Nächstes (F3)';

  @override
  String get desktopThreadCloseEsc => 'Schließen (Esc)';

  @override
  String get desktopThreadNewMessages => 'Neue Nachrichten';

  @override
  String desktopThreadUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ungelesen',
      one: '$count ungelesen',
    );
    return '$_temp0';
  }

  @override
  String get desktopThreadToday => 'Heute';

  @override
  String get desktopThreadYesterday => 'Gestern';

  @override
  String get desktopProfileEmojiStatus => 'Emoji-Status';

  @override
  String get desktopProfileClearStatus => 'Status entfernen';

  @override
  String get desktopProfileEmojiStatusPremiumOnly => 'Emoji-Status ist Teil von Premium; das Abo schließt du in der App auf dem Telefon ab';

  @override
  String get desktopProfileCosmeticPremiumOnly => 'Dieser Rahmen oder dieses Titelbild ist Teil von Premium; das Abo schließt du in der App auf dem Telefon ab';

  @override
  String desktopProfileApplyFailed(Object error) {
    return 'Konnte nicht angewendet werden: $error';
  }

  @override
  String get desktopProfileAvatarFrame => 'Avatar-Rahmen';

  @override
  String get desktopProfileCover => 'Profilbanner';

  @override
  String get desktopProfileNoFrame => 'Ohne Rahmen';

  @override
  String get desktopProfileNoCover => 'Ohne Banner';

  @override
  String get desktopProfileReadFailed => 'Die Datei konnte nicht gelesen werden';

  @override
  String get desktopProfilePhotoUpdated => 'Das Profilfoto wurde aktualisiert';

  @override
  String desktopProfilePhotoFailed(Object error) {
    return 'Das Foto konnte nicht aktualisiert werden: $error';
  }

  @override
  String desktopProfilePhotoRemoveFailed(Object error) {
    return 'Das Foto konnte nicht entfernt werden: $error';
  }

  @override
  String get desktopProfileMine => 'Mein Profil';

  @override
  String get desktopProfileEdit => 'Bearbeiten';

  @override
  String get desktopProfileName => 'Name';

  @override
  String get desktopProfileChangePhoto => 'Foto ändern';

  @override
  String get desktopProfileFrameShort => 'Rahmen';

  @override
  String get desktopProfileCoverShort => 'Banner';

  @override
  String get desktopProfileStatus => 'Status';

  @override
  String get desktopProfileAppearanceHint => 'Thema, Akzent und Chat-Hintergrund';

  @override
  String get desktopProfileAbout => 'Über mich';

  @override
  String get desktopProfileEmpty => 'Nicht ausgefüllt';

  @override
  String get desktopProfilePhoto => 'Profilfoto';

  @override
  String get desktopProfileReplacePhoto => 'Foto ersetzen';

  @override
  String get desktopProfilePickPhoto => 'Foto wählen';

  @override
  String get desktopProfilePickedHere => 'Auf diesem Computer gewählt';

  @override
  String get desktopProfileSyncedWithPhone => 'Mit dem Telefon synchronisiert';

  @override
  String get desktopProfileNotPicked => 'Nicht gewählt';

  @override
  String get desktopProfileRemovePhoto => 'Foto entfernen';

  @override
  String get desktopProfileInitialsStay => 'Die Initialen bleiben';

  @override
  String get desktopAvatarOpen => 'Foto öffnen';

  @override
  String get desktopAvatarCropTitle => 'Foto zuschneiden';

  @override
  String get desktopAvatarCropHint => 'Foto ziehen; Mausrad zum Zoomen';

  @override
  String get desktopAvatarRemoveConfirmTitle => 'Foto löschen?';

  @override
  String get desktopAvatarRemoveConfirmBody => 'Statt des Fotos werden die Initialen angezeigt.';

  @override
  String get desktopAvatarRemoveOnPhone => 'Löschen auf dem Telefon';

  @override
  String get desktopRoomPhotoUpdated => 'Gruppenfoto aktualisiert';

  @override
  String get desktopRoomPhotoRemoved => 'Gruppenfoto entfernt';

  @override
  String desktopRoomPhotoFailed(String error) {
    return 'Gruppenfoto konnte nicht geändert werden: $error';
  }

  @override
  String get desktopProfileAccount => 'Konto';

  @override
  String get desktopProfileRecovery => 'Wiederherstellung';

  @override
  String get desktopProfileRecoveryHint => 'Dieser Computer ist mit dem Telefon verbunden und speichert keine eigene Wiederherstellungsphrase: Sicherung und Wiederherstellungsset holen das Konto zurück.';

  @override
  String get desktopProfileDevicesHint => 'Verbundene Computer und Telefone';

  @override
  String get desktopProfileFrameCaps => 'AVATAR-RAHMEN';

  @override
  String get desktopGalleryMedia => 'Medien';

  @override
  String get desktopGalleryFiles => 'Dateien';

  @override
  String get desktopGalleryLinks => 'Links';

  @override
  String get desktopGalleryNoMedia => 'Keine Medien';

  @override
  String get desktopGalleryNoFiles => 'Keine Dateien';

  @override
  String get desktopGalleryNoAudio => 'Kein Audio';

  @override
  String get desktopGalleryLoadFailed => 'Anhänge konnten nicht geladen werden';

  @override
  String get desktopGalleryRetry => 'Erneut versuchen';

  @override
  String get desktopSendMediaDroppedOnSwitch => 'Dateien wurden nicht gesendet – das Sendefenster wurde beim Chatwechsel geschlossen.';

  @override
  String get desktopGalleryNoLinks => 'Keine Links';

  @override
  String get desktopGalleryPathCopied => 'Der Pfad wurde kopiert';

  @override
  String get desktopGalleryOpen => 'Öffnen';

  @override
  String get desktopGalleryView => 'Ansehen';

  @override
  String get desktopGalleryOpenInSystem => 'Im System öffnen';

  @override
  String get desktopGalleryRevealFinder => 'Im Finder zeigen';

  @override
  String get desktopGalleryRevealExplorer => 'Im Explorer zeigen';

  @override
  String get desktopGalleryOpenFolder => 'Ordner öffnen';

  @override
  String get desktopGalleryCopyPath => 'Pfad kopieren';

  @override
  String desktopGalleryBytes(Object value) {
    return '$value B';
  }

  @override
  String get desktopGalleryZeroBytes => '0 B';

  @override
  String desktopOutgoingFolderSingle(Object name) {
    return 'der Ordner „$name“ lässt sich nicht senden';
  }

  @override
  String get desktopOutgoingFoldersMany => 'Ordner lassen sich nicht senden';

  @override
  String desktopOutgoingTooLargeOne(Object name, Object limit) {
    return '„$name“ ist größer als $limit MB';
  }

  @override
  String desktopOutgoingTooLargeMany(int count, Object limit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien sind größer als $limit MB',
      one: '$count Datei ist größer als $limit MB',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingEmptyOne(Object name) {
    return '„$name“ ist leer';
  }

  @override
  String desktopOutgoingEmptyMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien sind leer',
      one: '$count Datei ist leer',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingUnreadableOne(Object name) {
    return '„$name“ konnte nicht gelesen werden';
  }

  @override
  String desktopOutgoingUnreadableMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien konnten nicht gelesen werden',
      one: '$count Datei konnte nicht gelesen werden',
    );
    return '$_temp0';
  }

  @override
  String get desktopOutgoingSending => 'Senden';

  @override
  String desktopOutgoingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos',
      one: '$count Fotos',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Videos',
      one: '$count Videos',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingMedia(Object count) {
    return '$count Medien';
  }

  @override
  String desktopOutgoingAudios(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Audiodateien',
      one: '$count Audiodateien',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '$count Dateien',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallsPickOne => 'Wähle links einen Anruf';

  @override
  String get desktopCallsPickHint => 'Hier erscheinen die Details und eine Rückruf-Schaltfläche';

  @override
  String get desktopCallsNone => 'Noch keine Anrufe';

  @override
  String get desktopCallsNoneHint => 'Der Verlauf erscheint nach dem ersten Anruf';

  @override
  String get desktopCallsOutgoing => 'Ausgehend';

  @override
  String get desktopCallsIncoming => 'Eingehend';

  @override
  String get desktopCallsGroup => 'Gruppe';

  @override
  String get desktopCallsVideoKind => 'Video';

  @override
  String get desktopCallsAudioKind => 'Audio';

  @override
  String get desktopCallsMissed => 'verpasst';

  @override
  String desktopPhotoCopyFailed(Object error) {
    return 'Kopieren fehlgeschlagen: $error';
  }

  @override
  String get desktopPhotoSave => 'Foto speichern';

  @override
  String get desktopPhotoSaved => 'Gespeichert';

  @override
  String desktopPhotoRevealFailed(Object error) {
    return 'Anzeigen im Finder fehlgeschlagen: $error';
  }

  @override
  String get desktopPhotoLoadFailed => 'Konnte nicht geladen werden';

  @override
  String get desktopPhotoZoomOut => 'Verkleinern';

  @override
  String get desktopPhotoZoomReset => 'Zoom zurücksetzen';

  @override
  String get desktopPhotoZoomIn => 'Vergrößern';

  @override
  String get desktopPhotoCopy => 'Kopieren';

  @override
  String desktopBubbleForwardedFrom(Object from) {
    return 'Weitergeleitet von $from';
  }

  @override
  String get desktopBubbleAudioFile => 'Audiodatei';

  @override
  String get desktopBubbleTranslating => 'Wird übersetzt…';

  @override
  String get desktopBubbleTranslation => 'ÜBERSETZUNG';

  @override
  String get desktopBubbleEdited => 'bearbeitet';

  @override
  String get desktopBubbleMoreReactions => 'Mehr Reaktionen';

  @override
  String get desktopBubbleRoleOwner => 'Eigentümer';

  @override
  String get desktopBubbleRoleAdmin => 'Admin';

  @override
  String get desktopBubbleRoleMod => 'Mod';

  @override
  String get desktopBubbleSpeed => 'Wiedergabegeschwindigkeit';

  @override
  String get desktopSpotlightGoChats => 'Zu den Chats';

  @override
  String get desktopSpotlightGoRooms => 'Zu den Räumen';

  @override
  String get desktopSpotlightGoContacts => 'Zu den Kontakten';

  @override
  String get desktopSpotlightGoCalls => 'Zu den Anrufen';

  @override
  String get desktopSpotlightSelect => 'auswählen';

  @override
  String get desktopSpotlightOpen => 'öffnen';

  @override
  String get desktopSpotlightClose => 'schließen';

  @override
  String get desktopSpotlightRoom => 'Raum';

  @override
  String get desktopSpotlightMessage => 'Nachricht';

  @override
  String get desktopSpotlightCommand => 'Befehl';

  @override
  String get desktopComposerCancelRec => 'Aufnahme abbrechen';

  @override
  String desktopComposerRecording(Object time) {
    return 'Aufnahme  $time';
  }

  @override
  String get desktopComposerSendVoice => 'Sprachnachricht senden';

  @override
  String get desktopComposerAttach => 'Anhängen';

  @override
  String get desktopComposerEmoji => 'Emoji und Sticker';

  @override
  String get desktopComposerRecordVoice => 'Sprachnachricht aufnehmen';

  @override
  String get desktopComposerVoiceUnsupported => 'Auf diesem Computer lassen sich keine Sprachnachrichten aufnehmen.';

  @override
  String get desktopComposerEnterSends => 'Enter sendet · Shift+Enter neue Zeile';

  @override
  String get desktopComposerEnterNewline => 'Enter neue Zeile · Shift+Enter sendet';

  @override
  String get desktopComposerEditing => 'Bearbeiten';

  @override
  String desktopComposerReplyTo(Object name) {
    return 'Antwort · $name';
  }

  @override
  String get desktopComposerCancelAction => 'Abbrechen';

  @override
  String get desktopComposerSendHint => 'Senden · Enter\nRechtsklick zum späteren Senden';

  @override
  String get desktopComposerWriteFirst => 'Schreibe erst eine Nachricht';

  @override
  String desktopComposerToTopic(Object title) {
    return 'zum Thema „$title“';
  }

  @override
  String get desktopShortcutsNavigation => 'Navigation';

  @override
  String get desktopShortcutsTabs => 'Chats · Räume · Anrufe · Kontakte';

  @override
  String get desktopShortcutsSearchAll => 'Chats und Nachrichten durchsuchen';

  @override
  String get desktopShortcutsPrevNext => 'Vorheriger / nächster Chat';

  @override
  String get desktopShortcutsInChat => 'In einer Unterhaltung';

  @override
  String get desktopShortcutsFindHere => 'In dieser Unterhaltung suchen';

  @override
  String get desktopShortcutsSend => 'Senden (einstellbar)';

  @override
  String get desktopShortcutsNewline => 'Neue Zeile';

  @override
  String get desktopShortcutsPaste => 'Bild aus der Zwischenablage einfügen';

  @override
  String get desktopShortcutsApp => 'Anwendung';

  @override
  String get desktopShortcutsThisHelp => 'Diese Hilfe';

  @override
  String get desktopShortcutsCloseWindow => 'Fenster oder Suche schließen';

  @override
  String get desktopShortcutsTray => 'In die Ablage minimieren';

  @override
  String get desktopShortcutsTitle => 'Tastenkürzel';

  @override
  String get desktopShortcutsUnread => 'Vorheriger / nächster ungelesener Chat';

  @override
  String get desktopShortcutsFolders => 'Vorheriger / nächster Ordner';

  @override
  String get desktopShortcutsMute => 'Chat stumm / laut schalten';

  @override
  String get desktopShortcutsCloseChat => 'Seitenleiste, dann den Chat schließen';

  @override
  String get desktopChatMutedToast => 'Chat stummgeschaltet';

  @override
  String get desktopChatUnmutedToast => 'Ton für den Chat an';

  @override
  String get desktopChatsFolderReadAll => 'Alle als gelesen markieren';

  @override
  String get desktopMediaCancelSend => 'Senden abbrechen';

  @override
  String get desktopMediaSending => 'Wird gesendet…';

  @override
  String desktopMediaSendingOf(Object total) {
    return 'Wird gesendet… · $total';
  }

  @override
  String get desktopMediaRetryDownload => 'Download wiederholen';

  @override
  String get desktopMediaImage => 'Bild';

  @override
  String desktopMediaDownloading(Object size) {
    return 'Wird geladen… · $size';
  }

  @override
  String get desktopMediaDownload => 'Laden';

  @override
  String get desktopSendAsMedia => 'Als Medien senden';

  @override
  String get desktopSendAsFiles => 'Als Dateien senden';

  @override
  String get desktopSendUngroup => 'Nicht gruppieren';

  @override
  String get desktopSendGroup => 'Gruppieren';

  @override
  String get desktopSendAddFiles => 'Dateien hinzufügen…';

  @override
  String get desktopSendDropHere => 'Loslassen zum Hinzufügen';

  @override
  String get desktopSendCloseEsc => 'Schließen · Esc';

  @override
  String desktopSendToDestination(Object destination) {
    return 'an „$destination“';
  }

  @override
  String get desktopSendCaptionHint => 'Bildunterschrift hinzufügen…';

  @override
  String get desktopSendEmoji => 'Emoji';

  @override
  String get desktopSendRemove => 'Entfernen';

  @override
  String get desktopSendEnter => 'Senden · Enter';

  @override
  String get desktopSendShiftEnter => 'Senden · Shift+Enter';

  @override
  String get desktopCallCtlShareStop => 'Bildschirmfreigabe beenden';

  @override
  String get desktopCallCtlShare => 'Bildschirmfreigabe';

  @override
  String desktopAbsenceDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '$count Tag',
    );
    return '$_temp0';
  }

  @override
  String desktopAbsencePastFanout(Object days) {
    return 'Dieser Computer war $days lang nicht erreichbar. In der Zeit haben Absender aufgehört, Nachrichten für ihn zu verschlüsseln, und ein Teil des Verlaufs kommt hier nicht an. Auf dem Telefon ist er vollständig – öffne dort die nötigen Chats, dann folgt der aktuelle Verlauf.';
  }

  @override
  String desktopAbsenceWithinWindow(Object days) {
    return 'Dieser Computer war $days lang nicht erreichbar. Nachrichten bleiben eine Woche auf dem Server, ein Teil davon ist für ihn womöglich nicht mehr da. Auf dem Telefon sind sie vollständig.';
  }

  @override
  String get desktopAbsenceGotIt => 'Verstanden';

  @override
  String get desktopNavContacts => 'Kontakte';

  @override
  String get desktopChatNotFound => 'Die Unterhaltung wurde nicht gefunden';

  @override
  String desktopUnreadTitle(Object count) {
    return 'Secretly — $count ungelesen';
  }

  @override
  String get desktopRoomsNone => 'Noch keine Räume';

  @override
  String get desktopRoomsNoneHint => 'Erstelle einen Raum am Telefon – er erscheint hier automatisch';

  @override
  String get desktopRoomsPickOne => 'Wähle links einen Raum';

  @override
  String get desktopScheduleTitle => 'Später senden';

  @override
  String get desktopScheduleInHour => 'In einer Stunde';

  @override
  String get desktopScheduleTonight => 'Heute um 19:00';

  @override
  String get desktopScheduleTomorrow => 'Morgen um 9:00';

  @override
  String get desktopScheduleInWeek => 'In einer Woche';

  @override
  String desktopScheduleTodayAt(Object time) {
    return 'heute um $time';
  }

  @override
  String desktopScheduleTomorrowAt(Object time) {
    return 'morgen um $time';
  }

  @override
  String desktopScheduleOnAt(Object date, Object time) {
    return '$date um $time';
  }

  @override
  String get desktopScheduleHint => 'Die Nachricht geht zur gewählten Zeit von selbst raus – auch bei geschlossenem Fenster wird sie beim nächsten Start gesendet.';

  @override
  String get desktopSchedulePickTime => 'Zeit wählen…';

  @override
  String get desktopDevicesSearching => 'Geräte werden gesucht…';

  @override
  String get desktopDevicesNoCameras => 'Keine Kameras gefunden. Vielleicht hat die App in den Systemeinstellungen keinen Zugriff darauf bekommen.';

  @override
  String get desktopDevicesNoMics => 'Keine Mikrofone gefunden. Vielleicht hat die App in den Systemeinstellungen keinen Zugriff darauf bekommen.';

  @override
  String get desktopDevicesOutputHint => 'Wohin der Ton geht, wird im Anruf gewählt – über das Zeichen neben „Mikrofon“. Dort wechselt die App auch von selbst zum Kopfhörer, sobald er eingesteckt wird.';

  @override
  String get desktopDevicesSystemDefault => 'Wie im System gewählt';

  @override
  String get desktopRailSettings => 'Einstellungen   Cmd ,';

  @override
  String get desktopRailConnected => 'Verbunden';

  @override
  String get desktopRailConnecting => 'Verbinden…';

  @override
  String get desktopRailOffline => 'Keine Verbindung';

  @override
  String desktopRailProfile(Object status) {
    return 'Profil   Cmd P   ·   $status';
  }

  @override
  String get desktopEmojiSmileys => 'Smileys und Emotionen';

  @override
  String get desktopEmojiPeople => 'Menschen und Körper';

  @override
  String get desktopEmojiNature => 'Natur';

  @override
  String get desktopEmojiFood => 'Essen und Trinken';

  @override
  String get desktopEmojiTravel => 'Reisen';

  @override
  String get desktopEmojiActivities => 'Aktivitäten';

  @override
  String get desktopEmojiObjects => 'Objekte';

  @override
  String get desktopEmojiSymbols => 'Symbole';

  @override
  String get desktopEmojiFlags => 'Flaggen';

  @override
  String get desktopEmojiOther => 'Sonstiges';

  @override
  String get desktopLockedTitle => 'Secretly ist gesperrt';

  @override
  String get desktopLockedTouchIdPrompt => 'Bestätige deine Identität mit Touch ID, um fortzufahren.';

  @override
  String get desktopLockedPasswordPrompt => 'Bestätige mit dem Gerätepasswort, um fortzufahren.';

  @override
  String get desktopLockedUnlock => 'Entsperren';

  @override
  String get desktopLockedWaiting => 'Warten auf Bestätigung…';

  @override
  String get desktopLockedFailed => 'Identität konnte nicht bestätigt werden.';

  @override
  String get desktopLockedNoService => 'Der Identitätsdienst ist auf diesem Computer nicht verfügbar. Starte Secretly oder den Computer neu. Hilft das nicht, schreibe dem Support vom Telefon aus.';

  @override
  String get desktopEmojiTabEmoji => 'Emojis';

  @override
  String get desktopEmojiTabStickers => 'Sticker';

  @override
  String get desktopEmojiRecents => 'Zuletzt';

  @override
  String get desktopEmojiNothingFound => 'Nichts gefunden';

  @override
  String get desktopEmojiSearchHint => 'Emojis suchen';

  @override
  String get desktopStickersSearchHint => 'Sticker suchen';

  @override
  String get desktopGifSearchHint => 'GIFs suchen';

  @override
  String get desktopGifUnavailable => 'GIFs sind in diesem Fenster nicht verfügbar';

  @override
  String get desktopStickerPacksSoon => 'Sticker-Pakete kommen bald';

  @override
  String get desktopCallFullscreen => 'Vollbild';

  @override
  String get desktopCallPinWindow => 'Immer im Vordergrund';

  @override
  String get desktopCallUnpinWindow => 'Nicht mehr im Vordergrund';

  @override
  String get desktopCallsOwnWindow => 'Anruf in eigenem Fenster';

  @override
  String get desktopCallsOwnWindowHint => 'Der Anruf öffnet sich in einem eigenen Fenster: auf einen anderen Bildschirm ziehen oder über anderen Apps halten.';

  @override
  String get desktopCallExitFullscreen => 'Vollbild beenden';

  @override
  String get desktopCallDialing => 'Anruf…';

  @override
  String get desktopCallEnded => 'Beendet';

  @override
  String desktopCallEncryptedFor(Object duration) {
    return 'Verschlüsselt · $duration';
  }

  @override
  String get desktopCallReturn => 'Zurück zum Anruf';

  @override
  String get desktopCallInProgress => 'Anruf läuft';

  @override
  String desktopCallInProgressWith(Object title) {
    return 'Anruf läuft · $title';
  }

  @override
  String get desktopCallAnswer => 'Annehmen';

  @override
  String get desktopCallAnswerVideo => 'Mit Video annehmen';

  @override
  String get desktopCallAnswerText => 'Per Text';

  @override
  String get desktopTimeYesterday => 'gestern';

  @override
  String get desktopForwardTitle => 'Weiterleiten an…';

  @override
  String get desktopForwardSearchHint => 'Chat oder Raum suchen';

  @override
  String get desktopForwardNoChats => 'Keine Chats verfügbar';

  @override
  String get desktopForwardKindDirect => 'Direktchat';

  @override
  String get desktopContactsSearchHint => 'Kontakte suchen';

  @override
  String get desktopContactsEmpty => 'Noch niemand. Füge einen Kontakt per ID oder Einladungslink hinzu.';

  @override
  String desktopContactsNothingFor(Object query) {
    return 'Nichts gefunden für „$query“.';
  }

  @override
  String get desktopContactsPick => 'Wähle einen Kontakt';

  @override
  String get desktopContactsCardRight => 'Die Karte erscheint rechts.';

  @override
  String get desktopContactsWrite => 'Nachricht schreiben';

  @override
  String get desktopVideoTitle => 'Video';

  @override
  String get desktopViewerCloseEsc => 'Schließen  Esc';

  @override
  String get desktopVideoPlayFailed => 'Video konnte nicht abgespielt werden';

  @override
  String get desktopKeySpace => 'Leertaste';

  @override
  String get desktopWindowMinimize => 'Minimieren';

  @override
  String get desktopWindowMaximize => 'Maximieren';

  @override
  String get desktopWindowClose => 'Schließen';

  @override
  String get desktopWindowBack => 'Zurück';

  @override
  String get desktopWindowForward => 'Vorwärts';

  @override
  String get desktopSearchEverything => 'Chats, Personen, Nachrichten, Dateien';

  @override
  String get desktopUnitB => 'B';

  @override
  String get desktopUnitKb => 'KB';

  @override
  String get desktopUnitMb => 'MB';

  @override
  String get desktopUnitGb => 'GB';

  @override
  String get desktopUnitTb => 'TB';

  @override
  String get desktopSyncDone => 'Synchronisiert';

  @override
  String get desktopSyncSyncing => 'Wird synchronisiert…';

  @override
  String get desktopSyncReconnecting => 'Neu verbinden…';

  @override
  String get desktopDetailsShare => 'Teilen';

  @override
  String get desktopDetailsHide => 'Ausblenden';

  @override
  String get desktopDetailsMore => 'Mehr';

  @override
  String get desktopDetailsChangeCover => 'Titelbild ändern';

  @override
  String desktopDetailsFrame(Object name) {
    return 'Rahmen „$name“';
  }

  @override
  String get desktopApply => 'Übernehmen';

  @override
  String get desktopAccentAppliesTo => 'Schaltflächen, Markierungen und Ringe. Die Sprechblase behält ihren eigenen Stil — den wählst du unten.';

  @override
  String get desktopTranslateUnknownSource => 'Sprache der Nachricht konnte nicht erkannt werden';

  @override
  String get desktopTranslateUnsupported => 'Der Systemübersetzer kennt dieses Sprachpaar nicht';

  @override
  String get desktopTranslateNeedsDownload => 'Die Sprache ist nicht geladen. Systemeinstellungen → Allgemein → Sprache & Region → Übersetzungssprachen';

  @override
  String get desktopTranslateFailed => 'Übersetzung fehlgeschlagen';

  @override
  String get desktopNewChatSearchHint => 'In Kontakten suchen';

  @override
  String get desktopNewChatNoContacts => 'Noch keine Kontakte';

  @override
  String get desktopNewChatNobodyFound => 'Niemanden gefunden';

  @override
  String get desktopMentionEveryone => 'Alle Mitglieder';

  @override
  String get desktopMentionAdmins => 'Admins';

  @override
  String get desktopMentionEveryoneHint => 'Alle im Raum rufen';

  @override
  String get desktopMentionAdminsHint => 'Eigentümer und Admins rufen';

  @override
  String desktopClearForPeer(Object name) {
    return 'Verlauf auch bei $name löschen';
  }

  @override
  String get desktopClearForPeerHint => 'Die Nachrichten verschwinden auf dem Gerät der anderen Person und auf all deinen. Das lässt sich nicht rückgängig machen.';

  @override
  String get desktopRoomClearForAll => 'Auch für alle Mitglieder des Raums';

  @override
  String get desktopRoomClearForAllHint => 'Die Nachrichten verschwinden auch bei allen anderen. Das lässt sich nicht rückgängig machen.';

  @override
  String get desktopGifNoKey => 'GIFs nicht verfügbar: Build ohne GIPHY-Schlüssel';

  @override
  String get desktopGifConnectionLost => 'Die Verbindung wurde unterbrochen. Versuche es erneut';

  @override
  String get desktopNotesHint => 'Was du dir aus diesem Gespräch merken willst…';

  @override
  String get desktopNotesPrivate => 'Nur für dich sichtbar. Wird nicht gesendet, erscheint nicht im Chat und gehört nicht zum Backup — es bleibt auf diesem Computer, in derselben verschlüsselten Datenbank wie die Nachrichten.';

  @override
  String get desktopEmojiSearchShort => 'Emojis suchen…';

  @override
  String get desktopNotifOpen => 'Öffnen';

  @override
  String get desktopLinkPreviewLoading => 'Linkvorschau…';

  @override
  String get desktopLinkPreviewOff => 'Ohne Vorschau';

  @override
  String get desktopDropToSend => 'Loslassen zum Senden';

  @override
  String get desktopDropEncrypted => 'Dateien werden vor dem Senden verschlüsselt';

  @override
  String get desktopDetailsPickChat => 'Wähle einen Chat';

  @override
  String get desktopDetailsEmptyHint => 'Angaben zur Person oder zum Raum\nerscheinen hier.';

  @override
  String get desktopMemberWrite => 'Schreiben';

  @override
  String get desktopShowPanel => 'Leiste einblenden';

  @override
  String get desktopHidePanel => 'Leiste ausblenden';

  @override
  String get desktopNotifOff => 'Mitteilungen sind aus';

  @override
  String get desktopSettingsSearchHint => 'Einstellung finden';

  @override
  String get desktopUnlockPrompt => 'Secretly entsperren';

  @override
  String get desktopEnableLockPrompt => 'Bestätige, um die Secretly-Sperre einzuschalten';

  @override
  String get desktopRoomsNoneHintDot => 'Erstelle einen Raum am Telefon — er erscheint hier von selbst.';

  @override
  String get desktopSplashLoading => 'Profil wird geladen…';

  @override
  String get desktopStartupFailedTitle => 'Secretly konnte nicht starten';

  @override
  String get desktopStartupFailedBody => 'Versuchen Sie es erneut. Tritt der Fehler wieder auf, hilft das Startprotokoll, die Ursache zu finden.';

  @override
  String get desktopStartupSlowTitle => 'Der Start dauert länger als üblich';

  @override
  String get desktopStartupSlowBody => 'Sie können weiter warten oder neu beginnen.';

  @override
  String get desktopStartupRetry => 'Erneut versuchen';

  @override
  String get desktopStartupOpenLogs => 'Protokollordner öffnen';

  @override
  String get desktopOutgoingOnePhoto => 'Foto';

  @override
  String get desktopOutgoingOneVideo => 'Video';

  @override
  String get desktopOutgoingOneAudio => 'Audio';

  @override
  String get desktopOutgoingOneFile => 'Datei';

  @override
  String get desktopMenuSettings => 'Einstellungen …';

  @override
  String get desktopMenuEdit => 'Bearbeiten';

  @override
  String get desktopMenuUndo => 'Widerrufen';

  @override
  String get desktopMenuRedo => 'Wiederholen';

  @override
  String get desktopMenuCut => 'Ausschneiden';

  @override
  String get desktopMenuPaste => 'Einsetzen';

  @override
  String get desktopMenuSelectAll => 'Alles auswählen';

  @override
  String get desktopMenuView => 'Darstellung';

  @override
  String get desktopMenuWindow => 'Fenster';

  @override
  String get desktopMenuHelp => 'Hilfe';

  @override
  String get desktopMenuWebsite => 'Secretly-Website';

  @override
  String get desktopContactsAddHint => 'Secretly-ID oder Einladungslink';

  @override
  String get desktopContactsAdded => 'Kontakt hinzugefügt';

  @override
  String get desktopContactsRenamed => 'Name gesichert';

  @override
  String get desktopMenuCheckUpdates => 'Nach Updates suchen …';

  @override
  String get desktopNotifBlockedTitle => 'Das System zeigt keine Secretly-Mitteilungen an';

  @override
  String get desktopNotifBlockedBody => 'Die Schalter unten funktionieren weiterhin, aber es wird nichts angezeigt: Das System blockiert die Mitteilungen dieser App. Das Fenster ist oft ausgeblendet, und eine Mitteilung ist der einzige Weg, von einer neuen Nachricht zu erfahren.';

  @override
  String get desktopNotifBlockedAction => 'Systemeinstellungen öffnen';

  @override
  String get backupPwRequirements => 'Mindestens 8 ASCII-Zeichen, ein Großbuchstabe und ein Sonderzeichen. Keine Leerzeichen am Anfang oder Ende.';

  @override
  String backupPwTooShort(int count) {
    return 'Das Passwort muss mindestens $count Zeichen lang sein.';
  }

  @override
  String backupPwTooLong(int count) {
    return 'Das Passwort darf höchstens $count Zeichen lang sein.';
  }

  @override
  String get backupPwNonAscii => 'Verwende nur lateinische Buchstaben, Ziffern und ASCII-Zeichen.';

  @override
  String get backupPwOuterSpace => 'Entferne Leerzeichen am Anfang oder Ende des Passworts.';

  @override
  String get backupPwNeedUpper => 'Füge mindestens einen Großbuchstaben A-Z hinzu.';

  @override
  String get backupPwNeedSpecial => 'Füge mindestens ein Sonderzeichen hinzu, etwa !, # oder ?.';

  @override
  String get desktopAuthGateTitle => 'Secretly auf diesem Computer';

  @override
  String get desktopAuthGateSubtitle => 'Wähle, wie du dich anmeldest';

  @override
  String get desktopAuthPhoneTitle => 'Mit dem Telefon anmelden';

  @override
  String get desktopAuthPhoneBody => 'Wenn Secretly schon auf dem Telefon ist. Chats und Kontakte ziehen hierher um.';

  @override
  String get desktopAuthCreateTitle => 'Neues Konto erstellen';

  @override
  String get desktopAuthCreateBody => 'Ein Konto nur auf diesem Computer. Ein Abo lässt sich nur in der Telefon-App kaufen.';

  @override
  String get desktopAuthRestoreTitle => 'Wiederherstellen';

  @override
  String get desktopAuthRestoreBody => 'Aus einem Wiederherstellungs-Set oder aus einer Sicherung auf dem Server.';

  @override
  String get desktopAuthBack => 'Zurück';

  @override
  String get desktopAuthNameTitle => 'Wie heißt du?';

  @override
  String get desktopAuthNameBody => 'Diesen Namen sehen die Leute, denen du schreibst. Du kannst ihn jederzeit ändern.';

  @override
  String get desktopAuthCreating => 'Konto wird erstellt …';

  @override
  String desktopAuthCreateFailed(Object error) {
    return 'Konto konnte nicht erstellt werden: $error';
  }

  @override
  String get desktopAuthCheckClock => 'Prüfe die Uhr des Computers: Bei Abweichung lehnt der Server die Anfrage ab.';

  @override
  String get desktopAuthKitTitle => 'Sichere dein Wiederherstellungs-Set';

  @override
  String get desktopAuthKitBody => 'Das ist der einzige Weg zurück ins Konto, wenn der Computer kaputtgeht oder verloren geht. Secretly hat weder E-Mail noch Telefonnummer: Ohne das Set kann niemand das Konto wiederherstellen, auch wir nicht.';

  @override
  String get desktopAuthKitAction => 'Wiederherstellungs-Set erstellen';

  @override
  String get desktopAuthKitSaved => 'Set gesichert. Das Konto lässt sich jetzt wiederherstellen.';

  @override
  String get desktopAuthContinue => 'Weiter';

  @override
  String get desktopAuthKitOptionTitle => 'Ich habe ein Wiederherstellungs-Set';

  @override
  String get desktopAuthKitOptionBody => 'Der einfachste Weg: Das Set enthält deine Secretly-ID bereits.';

  @override
  String get desktopAuthKitPasteHint => 'Inhalt des Sets einfügen';

  @override
  String get desktopAuthServerOptionTitle => 'Sicherung auf dem Server';

  @override
  String get desktopAuthServerOptionBody => 'Du brauchst deine Secretly-ID und das Sicherungs-Passwort.';

  @override
  String get desktopAuthRestoring => 'Wird wiederhergestellt …';

  @override
  String desktopAuthRestoreFailed(Object error) {
    return 'Wiederherstellung fehlgeschlagen: $error';
  }

  @override
  String get desktopAuthBackupNotFound => 'Für diese Secretly-ID gibt es keine Sicherung auf dem Server.';

  @override
  String get desktopGeneralLaunchAtLogin => 'Beim Anmelden starten';

  @override
  String get desktopGeneralLaunchAtLoginOn => 'Secretly startet von selbst und empfängt weiter Nachrichten';

  @override
  String get desktopGeneralLaunchAtLoginOff => 'Solange Secretly nicht läuft, erreichen Nachrichten diesen Computer nicht';

  @override
  String get desktopGeneralLaunchNeedsApproval => 'Der Start beim Anmelden ist in den Systemeinstellungen unter „Anmeldeobjekte“ deaktiviert';

  @override
  String get desktopA11yStatusSending => 'Wird gesendet';

  @override
  String get desktopA11yStatusScheduled => 'Geplant';

  @override
  String get desktopA11yStatusSent => 'Gesendet';

  @override
  String get desktopA11yStatusDelivered => 'Zugestellt';

  @override
  String get desktopA11yStatusRead => 'Gelesen';

  @override
  String get desktopA11yStatusFailed => 'Nicht gesendet';

  @override
  String get desktopA11yVoiceProgress => 'Wiedergabe der Sprachnachricht';

  @override
  String get desktopViewerPagePrev => 'Vorherige Seite';

  @override
  String get desktopViewerPageNext => 'Nächste Seite';

  @override
  String get desktopReactionsMore => 'Mehr Emojis';

  @override
  String get desktopReactionsCollapse => 'Einklappen';

  @override
  String get desktopThreadScrollToBottom => 'Zu den neuesten Nachrichten';

  @override
  String get desktopViewerPrev => 'Zurück';

  @override
  String get desktopViewerNext => 'Weiter';

  @override
  String get desktopA11yPlay => 'Abspielen';

  @override
  String get desktopA11yPause => 'Pause';

  @override
  String get desktopA11yAudioProgress => 'Wiedergabe';

  @override
  String get desktopPlayerClose => 'Player schließen';

  @override
  String get desktopPlayerOpenSource => 'Zur Nachricht';

  @override
  String desktopPlayerNowPlaying(String title) {
    return 'Wird abgespielt: $title';
  }

  @override
  String get desktopPlayerPrevious => 'Zurück';

  @override
  String get desktopPlayerNext => 'Weiter';

  @override
  String get desktopPlayerMore => 'Mehr in diesem Chat';

  @override
  String get desktopPlayerSpeed => 'Wiedergabegeschwindigkeit';

  @override
  String get desktopPlayerSpeedNormal => 'Normal';

  @override
  String get desktopPlayerVolume => 'Lautstärke';

  @override
  String get desktopUpdateNow => 'Aktualisieren';

  @override
  String desktopUpdateAvailable(String version) {
    return 'Version $version verfügbar';
  }

  @override
  String desktopUpdateDownloading(int percent) {
    return 'Lädt $percent %';
  }

  @override
  String get desktopUpdateVerifying => 'Wird geprüft…';

  @override
  String get desktopUpdateInstalling => 'Wird installiert…';

  @override
  String get desktopUpdateManual => 'Von der Website laden';

  @override
  String get desktopUpdateFailedHint => 'Das Update ließ sich nicht automatisch installieren. Das Installationsprogramm gibt es auf unserer Website.';

  @override
  String get desktopCallExpand => 'Anruf maximieren';

  @override
  String get desktopCallMinimiseHint => 'In ein Mini-Fenster verkleinern';

  @override
  String get desktopCallOpenChat => 'Anruf verkleinern und Chat öffnen';

  @override
  String get desktopCallScreenShareFailed => 'Bildschirm konnte nicht geteilt werden';

  @override
  String get desktopCallScreenShareFailedMac => 'Bildschirm konnte nicht geteilt werden. Erlauben Sie Secretly die Bildschirmaufnahme: Systemeinstellungen → Datenschutz & Sicherheit → Bildschirmaufnahme';

  @override
  String get desktopCallMediaCameraUnavailable => 'Die Kamera ist nicht verfügbar – eine andere App nutzt sie oder die Berechtigung fehlt in den Systemeinstellungen';

  @override
  String get desktopCallMediaMicUnavailable => 'Das Mikrofon ist nicht verfügbar – prüfen Sie die Berechtigung in den Systemeinstellungen';

  @override
  String get desktopCallMediaScreenStopped => 'Bildschirmfreigabe beendet';

  @override
  String desktopCallMediaProblem(String detail) {
    return 'Audio- oder Videoproblem: $detail';
  }

  @override
  String desktopCallEndedAfter(String duration) {
    return 'Anruf beendet · $duration';
  }

  @override
  String desktopCallDirectWith(String name) {
    return 'Laufender Anruf · $name';
  }

  @override
  String get desktopCallLeaveFailed => 'Der Anruf konnte nicht verlassen werden: Der Server hat nicht geantwortet. Versuchen Sie es erneut.';

  @override
  String get desktopCallRemoveParticipant => 'Aus dem Anruf entfernen';

  @override
  String desktopCallRemoveParticipantTitle(String name) {
    return '$name aus dem Anruf entfernen?';
  }

  @override
  String get desktopCallRemoveParticipantBody => 'Die Person verlässt den Anruf. Sie kann durch erneutes Beitreten zurückkommen.';

  @override
  String get desktopCallRemoveFailed => 'Entfernen aus dem Anruf fehlgeschlagen';

  @override
  String get desktopCallLeaveTitle => 'Anruf verlassen?';

  @override
  String get desktopCallEndForAll => 'Anruf für alle beenden';

  @override
  String get desktopCallEndForAllHint => 'Alle anderen verlassen den Anruf ebenfalls.';

  @override
  String get desktopCallEndForAllFailed => 'Der Anruf konnte nicht für alle beendet werden';

  @override
  String get desktopCallToggleFailed => 'Umschalten fehlgeschlagen: Der Server hat nicht geantwortet. Versuchen Sie es erneut.';

  @override
  String get desktopDiagTitle => 'Zustellungsdiagnose';

  @override
  String get desktopDiagHint => 'Worauf zu achten ist, wenn Nachrichten ausbleiben – und was Sie uns senden';

  @override
  String get desktopDiagQueues => 'WARTESCHLANGEN';

  @override
  String get desktopDiagOutbox => 'Warten auf Versand';

  @override
  String get desktopDiagStuck => 'Beim Empfang hängen geblieben';

  @override
  String get desktopDiagReceipts => 'Bestätigungen in der Warteschlange';

  @override
  String get desktopDiagNothingStuck => 'Nichts hängt fest';

  @override
  String get desktopDiagConditions => 'ZUSTELLBEDINGUNGEN';

  @override
  String get desktopDiagClockOk => 'Die Uhr des Computers stimmt mit dem Server überein';

  @override
  String desktopDiagClockSkew(Object delta) {
    return 'Die Uhr des Computers weicht um $delta ab – der Server kann ablehnen';
  }

  @override
  String get desktopDiagCopy => 'Für den Support kopieren';

  @override
  String get desktopAppearanceTextSize => 'Textgröße';

  @override
  String get desktopThreadGoToDate => 'Zu Datum springen';

  @override
  String get desktopHotkeyGlobalShow => 'Secretly von überall einblenden';

  @override
  String get desktopHotkeyGlobalHint => 'Standardmäßig aus: das Kürzel gilt systemweit und würde es einer anderen App wegnehmen';

  @override
  String get desktopHotkeyGlobalTaken => 'Ein anderes Programm belegt dieses Kürzel bereits';

  @override
  String get desktopTrayOpen => 'Secretly öffnen';

  @override
  String desktopTrayUnread(int count) {
    return '$count ungelesen';
  }

  @override
  String get desktopTrayMute => 'Benachrichtigungen stummschalten';

  @override
  String get desktopTrayMuteHour => 'Für 1 Stunde';

  @override
  String get desktopTrayMuteEightHours => 'Für 8 Stunden';

  @override
  String get desktopTrayMuteForever => 'Bis ich sie wieder einschalte';

  @override
  String get desktopTrayUnmute => 'Benachrichtigungen wieder einschalten';

  @override
  String desktopTrayMutedUntil(String time) {
    return 'Stumm bis $time';
  }

  @override
  String get desktopTrayQuit => 'Secretly beenden';

  @override
  String get desktopTrayHintTitle => 'Secretly läuft im Hintergrund weiter';

  @override
  String get desktopTrayHintBody => 'Nachrichten und Anrufe kommen weiter an. Das Symbol ist neben der Uhr – heften Sie es an, damit es sichtbar bleibt.';

  @override
  String get desktopDevicesMicrophone => 'Mikrofon';

  @override
  String get desktopDevicesSpeakers => 'Lautsprecher und Kopfhörer';

  @override
  String get desktopDevicesNoSpeakers => 'Keine Lautsprecher oder Kopfhörer gefunden';

  @override
  String get desktopDevicesCamera => 'Kamera';

  @override
  String get desktopCallsSystemTitle => 'System';

  @override
  String get desktopCallsSystemSound => 'Toneinstellungen des Systems';

  @override
  String get desktopCallsSystemSoundHint => 'Lautstärke, Standardgerät und Mikrofonzugriff';

  @override
  String get desktopCallsOpenSystem => 'Öffnen';

  @override
  String get desktopMicLevel => 'Mikrofonpegel';

  @override
  String get desktopMicLevelHint => 'Sagen Sie etwas – der Balken sollte sich bewegen. Das Mikrofon ist nur an, solange dieser Bereich offen ist, und der Ton geht nirgendwohin.';

  @override
  String get desktopMicNeedsAccess => 'Die App darf das Mikrofon noch nicht verwenden.';

  @override
  String get desktopMicAllow => 'Erlauben';

  @override
  String get desktopMicNoAccess => 'Kein Zugriff auf das Mikrofon. Erlauben Sie ihn in den Systemeinstellungen.';

  @override
  String get desktopMicOpenFailed => 'Das Mikrofon ließ sich nicht öffnen. Vielleicht verwendet es ein anderes Programm, oder der Zugriff ist gesperrt.';

  @override
  String get desktopMicSystemFallback => 'Das gewählte Mikrofon ließ sich für den Test nicht öffnen – angezeigt wird das Systemmikrofon.';

  @override
  String get desktopMediaOpenPrivacy => 'Einstellungen öffnen';

  @override
  String get desktopMicTest => 'Mikrofon testen';

  @override
  String get desktopMicTestHint => 'Nimmt 5 Sekunden auf und spielt sie über die gewählten Lautsprecher ab.';

  @override
  String get desktopMediaCheck => 'Testen';

  @override
  String get desktopMediaCheckStop => 'Stoppen';

  @override
  String desktopMicTestRecording(int seconds) {
    return 'Aufnahme läuft – bitte sprechen… $seconds s';
  }

  @override
  String get desktopMicTestPlaying => 'Aufnahme wird abgespielt…';

  @override
  String get desktopMediaPlaybackFailed => 'Der Ton ließ sich nicht abspielen.';

  @override
  String get desktopMediaPlaybackSystemOnly => 'Der Ton kam aus dem Standardgerät des Systems: Das gewählte Gerät ließ sich für den Test nicht öffnen.';

  @override
  String get desktopMediaBusyInCall => 'Ein Anruf läuft – die Tests sind aus, damit sie ihn nicht stören.';

  @override
  String get desktopSpeakerTest => 'Lautsprecher testen';

  @override
  String get desktopSpeakerTestHint => 'Ein kurzer Klang auf dem gewählten Gerät.';

  @override
  String get desktopSpeakerTestPlaying => 'Wird abgespielt…';

  @override
  String get desktopCameraPreview => 'Kamera testen';

  @override
  String get desktopCameraPreviewHint => 'Die Kamera ist nur an, solange die Vorschau angezeigt wird.';

  @override
  String get desktopCameraPreviewShow => 'Anzeigen';

  @override
  String get desktopCameraPreviewHide => 'Ausblenden';

  @override
  String get desktopCameraPreviewFailed => 'Die Kamera ließ sich nicht einschalten. Vielleicht verwendet sie ein anderes Programm, oder der Zugriff ist gesperrt.';

  @override
  String get desktopCameraMirror => 'Mein Video spiegeln';

  @override
  String get desktopCameraMirrorHint => 'Nur auf Ihrem Bildschirm, wie in einem Spiegel. Andere sehen Sie wie gewohnt.';

  @override
  String get desktopRingtoneTitle => 'Klingelton';

  @override
  String get desktopRingtoneVolume => 'Lautstärke';

  @override
  String get desktopRingtoneVolumeHint => 'Wie laut eingehende Anrufe auf diesem Computer klingeln.';

  @override
  String get desktopRingtoneListen => 'Anhören';

  @override
  String get desktopRingtoneSilent => 'Stumm – nur das Fenster zeigt den Anruf an.';

  @override
  String get desktopRoomEditTitle => 'Gruppe bearbeiten';

  @override
  String get desktopRoomEditName => 'Name';

  @override
  String get desktopRoomEditNameHint => 'Gruppenname';

  @override
  String get desktopRoomEditNameEmpty => 'Namen eingeben';

  @override
  String get desktopRoomEditDescription => 'Beschreibung';

  @override
  String get desktopRoomEditDescriptionHint => 'Worum es in dieser Gruppe geht';

  @override
  String get desktopRoomEditPhotoChoose => 'Foto auswählen…';

  @override
  String get desktopRoomEditPhotoRemove => 'Foto entfernen';

  @override
  String get desktopRoomEditSaved => 'Gruppe aktualisiert';

  @override
  String get desktopRoomPermissionsMenu => 'Berechtigungen';

  @override
  String get desktopRoomPermissionsTitle => 'Mitgliederberechtigungen';

  @override
  String get desktopRoomPermissionsSaved => 'Berechtigungen gespeichert';

  @override
  String get desktopRoomPermMembersSection => 'Was Mitglieder dürfen';

  @override
  String get desktopRoomPermSendText => 'Nachrichten senden';

  @override
  String get desktopRoomPermSendMedia => 'Fotos, Videos und Dateien senden';

  @override
  String get desktopRoomPermPin => 'Nachrichten anheften';

  @override
  String get desktopRoomPermAddMembers => 'Mitglieder hinzufügen';

  @override
  String get desktopRoomAddMembers => 'Mitglieder hinzufügen';

  @override
  String get desktopRoomAddMembersSearch => 'Name oder Secretly-ID';

  @override
  String get desktopRoomAddMembersAlready => 'Bereits im Raum';

  @override
  String get desktopRoomAddMembersNone => 'Niemand gefunden';

  @override
  String get desktopRoomAddMembersNoContacts => 'Noch keine Kontakte. Laden Sie Leute per Link ein.';

  @override
  String desktopRoomAddMembersAction(int count) {
    return '$count hinzufügen';
  }

  @override
  String desktopRoomMembersAdded(int count) {
    return 'Mitglieder hinzugefügt: $count';
  }

  @override
  String get desktopRoomInviteLinksMenu => 'Einladungslinks';

  @override
  String get desktopRoomAuditLog => 'Letzte Aktionen';

  @override
  String get desktopRoomAuditLogEmpty => 'Bisher ist nichts passiert';

  @override
  String get desktopRoomAuditLogHint => 'Beitritte, Austritte, Rollen und Einstellungen – wie dieser Computer sie gesehen hat.';

  @override
  String get desktopRoomPermChangeInfo => 'Name, Foto und Beschreibung ändern';

  @override
  String get desktopRoomPermChangeTag => 'Eigenes Label ändern';

  @override
  String get desktopRoomPermJoinSection => 'Beitritt';

  @override
  String get desktopRoomPermApproval => 'Beitritt nur nach Freigabe';

  @override
  String get desktopRoomPermHistory => 'Verlauf für neue Mitglieder';

  @override
  String get desktopRoomPermHistoryHint => 'Neue Mitglieder sehen Nachrichten von vor ihrem Beitritt';

  @override
  String get desktopRoomPermReactions => 'Reaktionen';

  @override
  String get desktopRoomReactionsAll => 'Alle';

  @override
  String get desktopRoomReactionsSome => 'Ausgewählte';

  @override
  String get desktopRoomReactionsNone => 'Keine';

  @override
  String get desktopRoomPermSlowMode => 'Langsamer Modus';

  @override
  String get desktopRoomPermSlowModeHint => 'Wie oft jedes Mitglied eine Nachricht senden darf';

  @override
  String get desktopRoomSlowOff => 'Aus';

  @override
  String desktopRoomSlowSeconds(int count) {
    return '$count s';
  }

  @override
  String desktopRoomSlowMinutes(int count) {
    return '$count Min.';
  }

  @override
  String desktopRoomSlowHours(int count) {
    return '$count Std.';
  }

  @override
  String get desktopRoomDelete => 'Gruppe löschen';

  @override
  String get desktopRoomDeleteTitle => 'Gruppe für alle löschen?';

  @override
  String desktopRoomDeleteBody(String title) {
    return '„$title“ verschwindet für alle Mitglieder samt Nachrichten. Das lässt sich nicht rückgängig machen.';
  }

  @override
  String get desktopRoomDeleted => 'Gruppe gelöscht';

  @override
  String get desktopRoomOwnerLeaveTitle => 'Sie sind Eigentümer dieser Gruppe';

  @override
  String get desktopRoomOwnerLeaveBody => 'Übergeben Sie die Gruppe vor dem Verlassen an ein anderes Mitglied – oder löschen Sie sie für alle.';

  @override
  String get desktopRoomOwnerLeaveNoMembers => 'Außer Ihnen ist niemand in der Gruppe – sie kann nur gelöscht werden.';

  @override
  String get desktopRoomOwnerLeaveTransfer => 'Übergeben und verlassen';

  @override
  String get desktopComposerSendHintShift => 'Senden · Shift+Enter\nRechtsklick zum späteren Senden';

  @override
  String get desktopWallpaperUseDefault => 'Wie in den Einstellungen';

  @override
  String get desktopWallpaperClassic => 'Klassisch';

  @override
  String get desktopWallpaperStandard => 'Standard';

  @override
  String desktopWallpaperProfilePhoto(int n) {
    return 'Foto $n';
  }

  @override
  String get desktopChatWallpaperTitle => 'Chat-Hintergrund';

  @override
  String get desktopChatWallpaperMenu => 'Chat-Hintergrund…';

  @override
  String get desktopChatWallpaperSaved => 'Hintergrund für diesen Chat gesetzt';

  @override
  String get desktopWallpaperPremiumOnly => 'Dieser Hintergrund gehört zu Premium – das Abo wird in der Handy-App verwaltet';

  @override
  String get desktopGeneralStartMinimized => 'Minimiert starten';

  @override
  String get desktopGeneralStartMinimizedHint => 'Beim Anmelden bleibt das Fenster zu – Secretly wartet im Infobereich';

  @override
  String get desktopGeneralCloseToTray => 'In den Infobereich schließen';

  @override
  String get desktopGeneralCloseToTrayOn => 'Das Schließen-Symbol blendet das Fenster aus – Nachrichten und Anrufe kommen weiter an';

  @override
  String get desktopGeneralCloseToTrayOff => 'Das Schließen-Symbol beendet Secretly – bis zum nächsten Start kommt nichts an';

  @override
  String get desktopGeneralLaunchNeedsApprovalWindows => 'Autostart ist im Task-Manager → Autostart-Apps deaktiviert – aktivieren Sie Secretly dort';

  @override
  String get desktopSupportAttachLog => 'Protokoll anhängen';

  @override
  String get desktopSupportLogEmpty => 'Das Protokoll ist noch leer';

  @override
  String get desktopDevicesAddComputerTitle => 'Weiterer Computer';

  @override
  String get desktopDevicesAddComputerHint => 'Computer werden vom Telefon aus verbunden. Installiere Secretly auf dem anderen Computer und wähle dort „Mit dem Telefon anmelden“, öffne dann am Telefon Einstellungen → Geräte → „Gerät verbinden“ und scanne den QR-Code, den jener Computer zeigt.';

  @override
  String get desktopSettingsSignOutBodyOnlyDevice => 'Dieser Computer ist das einzige Gerät mit diesem Konto. Nach der Abmeldung lässt es sich nur mit dem Wiederherstellungsset zurückholen – ohne das kann es niemand wiederherstellen, auch wir nicht. Stelle zuerst sicher, dass das Set gespeichert ist.';

  @override
  String get desktopSettingsSignOutBodyUnknown => 'Unterhaltungen, Schlüssel und Cache werden von diesem Computer entfernt. Ist das Konto auch auf einem anderen Gerät, bleibt es dort. Ist dieser Computer sein einziges Gerät, lässt es sich nur mit dem Wiederherstellungsset zurückholen.';

  @override
  String desktopPairingRetryIn(Object seconds) {
    return 'Nächster Versuch in $seconds s';
  }

  @override
  String get desktopKitReadyTitle => 'Dein Wiederherstellungsset ist fertig';

  @override
  String get desktopKitReadyBody => 'Bewahre es außerhalb dieses Computers auf – auf einem USB-Stick, in einem Passwort-Manager oder auf Papier. Set und Passwort zusammen öffnen das Konto, also bewahre sie getrennt auf.';

  @override
  String get desktopKitSaveToFile => 'In Datei speichern…';

  @override
  String get desktopKitSaveDialogTitle => 'Wiederherstellungsset speichern';

  @override
  String desktopKitSavedTo(Object path) {
    return 'In Datei gespeichert: $path';
  }

  @override
  String desktopKitSaveFailed(Object error) {
    return 'Die Datei konnte nicht gespeichert werden: $error';
  }

  @override
  String get desktopKitShowQr => 'QR-Code und Text anzeigen';

  @override
  String get desktopKitSavedElsewhere => 'Anders gespeichert';

  @override
  String get desktopKitConfirmTitle => 'Ist das Set wirklich gespeichert?';

  @override
  String get desktopKitConfirmBody => 'Bestätige nur, wenn du den Text des Sets kopiert oder seinen QR-Code fotografiert und an einem sicheren Ort außerhalb dieses Computers abgelegt hast. Ohne das Set lässt sich das Konto nicht wiederherstellen.';

  @override
  String get desktopKitConfirmYes => 'Ja, gespeichert';

  @override
  String get desktopAuthKitConfirmed => 'Du hast bestätigt, dass das Set sicher aufbewahrt ist. Damit lässt sich das Konto wiederherstellen.';

  @override
  String get desktopAboutSourceCode => 'Quellcode';

  @override
  String desktopAboutLicenseLine(Object url) {
    return 'Lizenz: GNU AGPL-3.0. Quellcode: $url';
  }

  @override
  String get desktopProfileLinkTitle => 'Diesen Chat öffnen?';

  @override
  String desktopProfileLinkBody(String name, String id) {
    return 'Der Link führt zu einer Unterhaltung. Gesprächspartner: $name ($id).';
  }

  @override
  String desktopProfileLinkBodyUnknown(String id) {
    return 'Der Link führt zu einer Unterhaltung mit dem Profil $id.';
  }

  @override
  String get desktopProfileLinkOpen => 'Chat öffnen';

  @override
  String desktopUpdateAttemptFailed(String reason) {
    return 'Das Update wurde nicht installiert: $reason';
  }

  @override
  String get desktopUpdateFailureDownload => 'die Datei ließ sich nicht herunterladen';

  @override
  String get desktopUpdateFailureVerification => 'die heruntergeladene Datei hat die Prüfung nicht bestanden und wurde ungestartet gelöscht';

  @override
  String get desktopUpdateFailureLaunch => 'das Installationsprogramm ließ sich nicht starten';

  @override
  String get desktopUpdateFailureNotInstalled => 'nach dem Installationsprogramm läuft weiterhin die bisherige Version';

  @override
  String get desktopUpdateRetry => 'Erneut versuchen';

  @override
  String get desktopRestoreTakeOverTitle => 'Dieser Computer wird zu dem Gerät, das die Sicherung erstellt hat';

  @override
  String get desktopRestoreTakeOverBody => 'Die Sicherung wurde von einem anderen Gerät erstellt – zum Beispiel von Ihrem Telefon. Nach der Wiederherstellung nimmt dieser Computer dessen Platz ein. Ist das andere Gerät noch in Gebrauch, kommen Nachrichten nur bei einem der beiden an, und das andere kann Chats womöglich nicht mehr entschlüsseln oder die Verbindung zum Server verlieren. Stellen Sie so nur wieder her, wenn es das andere Gerät nicht mehr gibt. Um den Computer neben dem Telefon zu nutzen, gehen Sie zurück und verknüpfen Sie ihn per QR-Code.';

  @override
  String get desktopRestoreTakeOverConfirm => 'Trotzdem wiederherstellen';

  @override
  String get desktopServerBackupReplaceTitle => 'Sicherung auf dem Server ersetzen?';

  @override
  String get desktopServerBackupReplaceBody => 'Auf dem Server liegt eine Sicherung pro Konto. Eine Sicherung von diesem Computer ersetzt die, die Ihr Telefon oder ein anderes Gerät erstellt hat, und die bisherige lässt sich nicht zurückholen. Sie enthält nur den Verlauf, der auf diesem Computer vorhanden ist.';

  @override
  String get desktopServerBackupReplaceConfirm => 'Ersetzen';

  @override
  String get desktopBackupAutoPasswordMissing => 'es ist kein Sicherungspasswort festgelegt';

  @override
  String get desktopBackupAutoPasswordWeak => 'das Sicherungspasswort erfüllt die Anforderungen nicht mehr';

  @override
  String get desktopBackupSetPassword => 'Sicherungspasswort festlegen';

  @override
  String get desktopSupportLogConfirmTitle => 'Protokoll anhängen?';

  @override
  String desktopSupportLogConfirmBody(String size) {
    return '$size Dienstaufzeichnungen der App aus der letzten Zeit. Sehen Sie sich den Inhalt an, bevor Sie ihn anhängen: Das Protokoll geht zusammen mit Ihrer Nachricht an den Support.';
  }

  @override
  String get desktopSupportLogView => 'Ansehen';

  @override
  String get desktopSupportLogAttachConfirm => 'Anhängen';

  @override
  String get desktopSupportLogViewTitle => 'Inhalt des Protokolls';

  @override
  String get desktopDevicesEndNotConfirmed => 'Der Server hat es nicht bestätigt. Versuchen Sie es später erneut.';

  @override
  String get desktopPrivacyScreenCaptureTitle => 'Schutz vor Bildschirmaufnahmen';

  @override
  String get desktopPrivacyScreenCaptureSwitch => 'Secretly-Fenster vor Screenshots und Bildschirmaufnahmen verbergen';

  @override
  String get desktopPrivacyScreenCaptureHint => 'Screenshots, Bildschirmaufnahmen und Bildschirmfreigaben – auch Ihre eigene Freigabe in Anrufen – zeigen den Inhalt der Secretly-Fenster nicht. Ein Foto des Bildschirms verhindert das nicht, und manche Aufnahmeprogramme oder Systemversionen halten sich womöglich nicht daran.';

  @override
  String get desktopPrivacyScreenCaptureFailed => 'Das System hat den Schutz vor Bildschirmaufnahmen nicht übernommen.';

  @override
  String get desktopSoundMessagesTitle => 'Nachrichtenton';

  @override
  String get desktopSoundMessagesHint => 'Erklingt mit Benachrichtigungen über Nachrichten auf diesem Computer.';

  @override
  String get desktopSoundMutedNote => 'Der Ton ist oben ausgeschaltet – der gewählte Ton erklingt nicht.';

  @override
  String get desktopSoundInChatTitle => 'Ton im geöffneten Chat';

  @override
  String get desktopSoundInChatSwitch => 'Neue Nachrichten im geöffneten Chat';

  @override
  String get desktopSoundInChatHint => 'Ein leiser Ton statt einer Benachrichtigung, solange der Chat im aktiven Fenster geöffnet ist.';

  @override
  String get desktopSoundNameBubble => 'Blase';

  @override
  String get desktopSoundNameBubbles => 'Blasen';

  @override
  String get desktopSoundNameDrip => 'Tröpfeln';

  @override
  String get desktopSoundNamePing => 'Ping';

  @override
  String get desktopSoundNameSplash => 'Platsch';

  @override
  String get desktopSoundNameDrop => 'Tropfen';

  @override
  String get desktopSoundNameTone => 'Ton';

  @override
  String get desktopSoundNameKey => 'Taste';

  @override
  String get desktopSoundNameClick => 'Klick';

  @override
  String get desktopSoundNameSwitch => 'Schalter';

  @override
  String get desktopSoundNameMelody => 'Melodie';

  @override
  String get desktopSoundNamePulse => 'Puls';

  @override
  String get desktopSoundNameDefault => 'Standard';

  @override
  String get roomCallE2eeOn => 'Ende-zu-Ende-verschlüsselt';

  @override
  String get roomCallE2eeOnHint => 'Nur Teilnehmende können diesen Anruf hören und sehen – unser Server nicht.';

  @override
  String get roomCallE2eeConnecting => 'Verschlüsselung wird eingerichtet…';

  @override
  String get roomCallE2eeFailed => 'Verschlüsselung konnte nicht aktiviert werden. Dieses Gerät kann nicht teilnehmen.';

  @override
  String get roomCallE2eeUnsupported => 'Verschlüsselte Gruppenanrufe sind auf diesem Gerät noch nicht verfügbar.';

  @override
  String get roomCallE2eeWaitingKey => 'Warte auf Schlüssel';

  @override
  String get roomCallE2eeFailing => 'Entschlüsselung nicht möglich – vielleicht eine ältere Version';

  @override
  String roomCallE2eeUnknownParticipants(int count) {
    return 'Unbekannte Teilnehmende nicht hörbar: $count';
  }

  @override
  String get roomCallOpenBanner => 'Nicht Ende-zu-Ende-verschlüsselt – unser Server kann diesen Anruf sehen und hören';

  @override
  String get roomCallJoinOpenTitle => 'Anruf ohne Verschlüsselung beitreten?';

  @override
  String get roomCallJoinOpenBody => 'Dieser Anruf ist nicht Ende-zu-Ende-verschlüsselt: Er wurde in einer älteren Version von Secretly gestartet. Unser Server kann ihn sehen und hören.';

  @override
  String get roomCallJoinOpenAction => 'Trotzdem beitreten';

  @override
  String get roomCallStartChoiceTitle => 'Verschlüsselten Anruf starten?';

  @override
  String roomCallStartChoiceBody(String names) {
    return 'Ältere Version von Secretly – können nicht beitreten: $names.';
  }

  @override
  String get roomCallStartChoiceNotify => 'Im Chat ans Aktualisieren erinnern';

  @override
  String get roomCallStartEncrypted => 'Verschlüsselt starten';

  @override
  String get roomCallStartOpen => 'Ohne Verschlüsselung starten';

  @override
  String get roomCallUpdateNotice => 'Ein verschlüsselter Anruf läuft. Aktualisiere Secretly, um beizutreten.';

  @override
  String get roomCallE2eeScreenShareIos => 'Bildschirmfreigabe vom iPhone ist in verschlüsselten Anrufen noch nicht verfügbar';

  @override
  String get roomCallFull => 'Der verschlüsselte Anruf ist voll';

  @override
  String get roomPrivateTopicNew => 'Neues Thema';

  @override
  String get roomPrivateTopicOpen => 'Offen';

  @override
  String get roomPrivateTopicOpenHint => 'Alle im Raum sehen es';

  @override
  String get roomPrivateTopicClosed => 'Privat';

  @override
  String get roomPrivateTopicClosedHint => 'Nur Eingeladene. Andere erfahren nichts davon';

  @override
  String get roomPrivateTopicTitleHint => 'Name des Themas';

  @override
  String get roomPrivateTopicMembers => 'Wen einladen';

  @override
  String get roomPrivateTopicOnlyYou => 'Vorerst nur du — Personen kannst du später hinzufügen';

  @override
  String get roomPrivateTopicCreate => 'Erstellen';

  @override
  String get roomPrivateTopicFailed => 'Privates Thema konnte nicht erstellt werden';

  @override
  String roomPrivateTopicLimit(int count) {
    return 'Limit privater Themen erreicht: $count';
  }

  @override
  String get roomPrivateTopicLabel => 'Privates Thema';

  @override
  String roomPrivateTopicInRoom(String room) {
    return 'Privates Thema · $room';
  }

  @override
  String get roomPrivateTopicAllowMembers => 'Private Themen erstellen';

  @override
  String get spaceGateEnterCode => 'Code eingeben';

  @override
  String get spaceGateWrongCode => 'Der Code stimmt nicht. Versuchen Sie es erneut.';

  @override
  String spaceGateWaitSeconds(int seconds) {
    return 'Warten Sie $seconds s';
  }

  @override
  String get spaceGateUnlock => 'Entsperren';

  @override
  String get spaceGateUseBiometrics => 'Biometrie verwenden';

  @override
  String get spaceGateBiometricReason => 'Secretly entsperren';

  @override
  String get duressSetupTitle => 'Notfallcode';

  @override
  String get duressSetupDescription => 'Dieser Code öffnet ein separates, leeres Profil statt Ihres eigenen. Er muss sich von Ihrem echten Code unterscheiden. Wer zusieht, wie Sie ihn eingeben, sieht einen frisch installierten Messenger.';

  @override
  String get duressSectionTitle => 'Zwangscode';

  @override
  String get duressSectionSubtitleSet => 'Eingerichtet. Ein zweiter Code öffnet ein separates, leeres Profil.';

  @override
  String get duressSectionSubtitleUnset => 'Ein zweiter Code, der ein separates, leeres Profil anstelle Ihres eigenen öffnet.';

  @override
  String get duressSectionChange => 'Ändern';

  @override
  String get duressSectionSetUp => 'Einrichten';

  @override
  String get duressWipeMainTitle => 'Hauptprofil löschen, wenn der Code eingegeben wird';

  @override
  String get duressWipeMainSubtitle => 'Unwiderruflich. Wiederherstellung nur aus einem Recovery Kit oder einem Backup.';

  @override
  String get duressRemoveCode => 'Zwangscode entfernen';

  @override
  String duressWipeAfterAttemptsTitle(int attempts) {
    return 'Nach $attempts Fehlversuchen alles löschen';
  }

  @override
  String get duressWipeAfterAttemptsSubtitle => 'Beide Profile und die Sperre selbst. Nach 3 Fehlversuchen gilt bereits eine Verzögerung.';

  @override
  String get duressSectionFootnote => 'Schützt bei einer „Zeig mir dein Handy“-Kontrolle, nicht gegen eine forensische Untersuchung des Geräts. Biometrie öffnet immer das Hauptprofil. Um aus dem Täuschprofil dorthin zurückzukehren, schließen Sie die App und geben Sie Ihren echten Code ein.';

  @override
  String get duressSaveFailed => 'Speichern fehlgeschlagen.';

  @override
  String get netSettingsImportNoNewMessages => 'Keine neuen Nachrichten für dieses Gerät.';

  @override
  String netSettingsImportReceived(int count) {
    return 'Empfangene Nachrichten: $count';
  }

  @override
  String get netSettingsImportNotEnvelopeFile => 'Dies ist keine Secretly-Nachrichtendatei oder sie wurde verändert.';

  @override
  String get netSettingsImportCouldNotOpen => 'Die Datei konnte nicht geöffnet werden.';

  @override
  String get netSettingsImportCouldNotRead => 'Die Datei konnte nicht gelesen werden. Öffnen Sie sie in Secretly: Einstellungen → Ohne Internet → „Nachrichtendatei öffnen“.';

  @override
  String get netSettingsPathDirect => 'Direkt';

  @override
  String get netSettingsPathFallback => 'Über Ersatzadresse';

  @override
  String get netSettingsPathMirror => 'Über Spiegelserver';

  @override
  String get netSettingsPathCdn => 'Über CDN';

  @override
  String get netSettingsPathProxy => 'Über Proxy';

  @override
  String get netSettingsPathSocks => 'Über SOCKS';

  @override
  String get netSettingsPathTor => 'Über Tor';

  @override
  String get netSettingsProxyHostError => 'Geben Sie einen Hostnamen ein, zum Beispiel proxy.example.org';

  @override
  String get netSettingsSocksAddressError => 'Geben Sie eine Adresse wie 127.0.0.1:9050 ein';

  @override
  String get netSettingsNoContactsYet => 'Noch keine Kontakte.';

  @override
  String get netSettingsPickRecipientTitle => 'Für wen ist die Datei';

  @override
  String get netSettingsNothingToCarry => 'Für diesen Kontakt gibt es aus der letzten Woche nichts zu übertragen.';

  @override
  String get netSettingsCouldNotCreateFile => 'Die Datei konnte nicht erstellt werden.';

  @override
  String get netSettingsTitle => 'Netzwerk';

  @override
  String get netSettingsPathToServersTitle => 'Weg zu den Servern';

  @override
  String get netSettingsPathDirectOff => 'Direkt. Alternative Wege sind ausgeschaltet oder nicht verfügbar.';

  @override
  String get netSettingsTryAlternativeTitle => 'Alternative Wege suchen';

  @override
  String get netSettingsTryAlternativeSubtitle => 'Wenn der direkte Weg blockiert ist, probiert die App selbst Ersatzadressen, Spiegelserver und Proxys. Die Inhalte bleiben Ende-zu-Ende verschlüsselt.';

  @override
  String get netSettingsVolunteerProxyTitle => 'Freiwilligen-Proxy';

  @override
  String get netSettingsVolunteerProxyDescription => 'Ein Link wie secretly://proxy#host. Der Proxy-Betreiber kann Ihren Verkehr nicht lesen, sieht aber, dass Sie Secretly nutzen.';

  @override
  String get netSettingsSocksTitle => 'SOCKS5 (zum Beispiel Tor über Orbot)';

  @override
  String get netSettingsSendWithoutNetworkTitle => 'Ohne Netzwerk senden';

  @override
  String get netSettingsSendWithoutNetworkSubtitle => 'Eine Datei mit Ihren verschlüsselten Nachrichten an einen Kontakt aus der letzten Woche. Übergeben Sie sie beliebig — per USB-Stick, Bluetooth oder einem anderen Messenger.';

  @override
  String get netSettingsOpenMessageFileTitle => 'Nachrichtendatei öffnen';

  @override
  String get netSettingsOpenMessageFileSubtitle => 'Eine .secretly-Datei von einem Kontakt. Nachrichten für andere Geräte und bereits vorhandene werden übersprungen.';

  @override
  String get netSettingsDeliveryReportsTitle => 'Anonyme Zustellberichte';

  @override
  String get netSettingsDeliveryReportsSubtitle => 'Einmal täglich: Plattform, Netzwerktyp, welcher Weg funktioniert hat und welche nicht, Land anhand der Systemsprache. Keine Kennungen, keine Adressen.';

  @override
  String get netSettingsOrbotTitle => 'Über Orbot (Tor)';

  @override
  String get netSettingsOrbotSubtitle => 'Setzt die SOCKS-Adresse von Orbot ein: 127.0.0.1:9050. Installieren und starten Sie Orbot; Secretly kann nicht prüfen, ob es läuft.';

  @override
  String get netSettingsOrbotDone => 'SOCKS-Adresse auf Orbot gesetzt. Starten Sie Orbot und kommen Sie zurück.';

  @override
  String get netSettingsTorTitle => 'Tor als letzter Ausweg';

  @override
  String get netSettingsTorSubtitle => 'Langsamer und verbraucht mehr Akku; wird nur genutzt, wenn alles andere blockiert ist.';

  @override
  String get socialRecoveryGuardiansTitle => 'Vertrauenspersonen';

  @override
  String get socialRecoveryEntryGuardiansSubtitle => 'Freunde, die gemeinsam Ihr Profil zurückholen können, wenn das Telefon verloren geht. Einzeln kann keiner von ihnen etwas.';

  @override
  String get socialRecoveryHelpSomeoneTitle => 'Jemandem beim Wiederherstellen helfen';

  @override
  String get socialRecoveryHelpSomeoneSubtitle => 'Wenn Sie die Vertrauensperson von jemandem sind.';

  @override
  String get socialRecoveryRecoverMineTitle => 'Mein Profil wiederherstellen';

  @override
  String get socialRecoveryRecoverMineSubtitle => 'Auf einem neuen Telefon, mit Hilfe Ihrer Vertrauenspersonen.';

  @override
  String get socialRecoveryNeedTwoGuardians => 'Wählen Sie mindestens zwei Vertrauenspersonen.';

  @override
  String get socialRecoverySendSharesFailed => 'Die Teile konnten nicht gesendet werden. Prüfen Sie die Verbindung.';

  @override
  String get socialRecoveryOwnerIntro => 'Ihr Profil wird in Teile zwischen den Vertrauenspersonen aufgeteilt. Um es zurückzuholen, brauchen Sie so viele von ihnen, wie Sie festlegen. Wählen Sie Menschen, deren Stimme Sie erkennen und mit denen Sie den Sicherheitscode abgeglichen haben.';

  @override
  String get socialRecoveryIsSetUp => 'Wiederherstellung ist eingerichtet';

  @override
  String get socialRecoveryWaitingConfirmations => 'Warten auf Bestätigungen';

  @override
  String socialRecoveryConfirmedProgress(int accepted, int total, int threshold) {
    return '$accepted von $total bestätigt. $threshold für die Wiederherstellung nötig.';
  }

  @override
  String get socialRecoveryGuardianHoldsPart => 'Hält einen Teil';

  @override
  String get socialRecoveryGuardianNotSent => 'Nicht gesendet';

  @override
  String get socialRecoveryGuardianSentWaiting => 'Gesendet, warten';

  @override
  String socialRecoveryPickContacts(int max) {
    return 'Wählen Sie 2 bis $max Kontakte';
  }

  @override
  String get socialRecoveryNoContactsYet => 'Noch keine Kontakte.';

  @override
  String socialRecoveryThresholdLabel(int threshold, int total) {
    return 'Für die Wiederherstellung nötige Vertrauenspersonen: $threshold von $total';
  }

  @override
  String get socialRecoveryThresholdWarning => 'So viele Vertrauenspersonen könnten Ihr Profil gemeinsam auch ohne Sie wiederherstellen. Wählen Sie keine Menschen, die einander zu nahe stehen.';

  @override
  String get socialRecoverySendParts => 'Teile versenden';

  @override
  String get socialRecoveryUpdateGuardians => 'Vertrauenspersonen aktualisieren';

  @override
  String get socialRecoveryTurnOff => 'Wiederherstellung ausschalten';

  @override
  String get socialRecoveryCodeScanTitle => 'Wiederherstellungscode';

  @override
  String get socialRecoveryNotRecoveryCode => 'Das ist kein Wiederherstellungscode.';

  @override
  String get socialRecoveryNoCodeInClipboard => 'In der Zwischenablage ist kein Wiederherstellungscode.';

  @override
  String get socialRecoverySendFailed => 'Senden fehlgeschlagen. Prüfen Sie die Verbindung.';

  @override
  String get socialRecoveryHelpRecoverTitle => 'Beim Wiederherstellen helfen';

  @override
  String get socialRecoveryNotGuardianYet => 'Sie sind noch nicht die Vertrauensperson von jemandem. Wenn jemand Sie auswählt, erscheint sein Name hier.';

  @override
  String get socialRecoveryWhoAreYouHelping => 'Wem helfen Sie';

  @override
  String socialRecoveryThresholdOfGuardians(int threshold, int guardians) {
    return '$threshold von $guardians Vertrauenspersonen nötig';
  }

  @override
  String get socialRecoveryScanCode => 'Code scannen';

  @override
  String get socialRecoveryPasteCode => 'Code einfügen';

  @override
  String get socialRecoveryCheckWordsByVoice => 'Wörter per Stimme abgleichen';

  @override
  String get socialRecoveryCheckWordsExplanation => 'Rufen Sie die Person an oder treffen Sie sie persönlich. Bitten Sie sie, die Wörter von ihrem Bildschirm vorzulesen. Wenn ein Wort abweicht oder Sie nicht sicher sind, dass es die Person ist, senden Sie nichts. So würde ein Angreifer ein fremdes Profil übernehmen.';

  @override
  String get socialRecoveryHeardWordsConfirm => 'Ich habe diese Wörter von dieser Person gehört';

  @override
  String get socialRecoverySent => 'Gesendet';

  @override
  String get socialRecoverySendMyPart => 'Meinen Teil senden';

  @override
  String get socialRecoveryRecoverProfileTitle => 'Profil wiederherstellen';

  @override
  String get socialRecoveryRecoverIntro => 'Dieses Telefon ersetzt das aktuell geöffnete Profil durch Ihr früheres Profil. Ihre Vertrauenspersonen senden ihre Teile, und sobald genügend da sind, startet die App mit Ihrem Profil neu.';

  @override
  String get socialRecoveryShowCodeToGuardians => 'Code den Vertrauenspersonen zeigen';

  @override
  String get socialRecoveryShowCodeHint => 'Zeigen Sie den Code einer Vertrauensperson oder senden Sie ihn als Text und lesen Sie ihr dann diese Wörter per Stimme vor.';

  @override
  String get socialRecoveryCopyCode => 'Code kopieren';

  @override
  String get socialRecoveryWaitingGuardians => 'Warten auf Vertrauenspersonen';

  @override
  String socialRecoveryReceivedProgress(int received, int threshold) {
    return '$received von $threshold erhalten';
  }

  @override
  String get socialRecoveryPartDidNotFit => 'Ein Teil passte nicht. Fragen Sie eine andere Vertrauensperson.';

  @override
  String socialRecoveryAssembleFailed(String error) {
    return 'Das Profil konnte nicht zusammengesetzt werden ($error).';
  }

  @override
  String get socialRecoveryCancel => 'Abbrechen';

  @override
  String get disappearingTitle => 'Verschwindende Nachrichten';

  @override
  String disappearingSubtitleOn(Object duration) {
    return '$duration · für alle im Chat';
  }

  @override
  String get disappearingDialogHint => 'Nachrichten werden nach Ablauf der Zeit von den Geräten aller Teilnehmenden gelöscht. Das schützt nicht vor Screenshots und nicht vor Geräten mit einer alten App-Version.';

  @override
  String get disappearingCustom => 'Eigene Zeit…';

  @override
  String get disappearingCustomTitle => 'Eigene Zeit';

  @override
  String disappearingCustomHint(Object min, Object max) {
    return 'Von $min bis $max';
  }

  @override
  String get disappearingUnitSeconds => 'Sekunden';

  @override
  String get disappearingUnitMinutes => 'Minuten';

  @override
  String get disappearingUnitHours => 'Stunden';

  @override
  String get disappearingUnitDays => 'Tage';

  @override
  String get disappearingCustomInvalid => 'Gib eine Zahl im erlaubten Bereich ein';

  @override
  String disappearingBannerOn(Object duration) {
    return 'Verschwindende Nachrichten: $duration';
  }

  @override
  String get disappearingPeerOutdated => 'Dein Kontakt nutzt eine alte App-Version – bei ihm verschwinden die Nachrichten nicht.';

  @override
  String get disappearingOwnOutdated => 'Eines deiner Geräte nutzt eine alte App-Version – dort verschwinden die Nachrichten nicht.';

  @override
  String get disappearingSupportUnknown => 'Die App-Version deines Kontakts konnte nicht geprüft werden.';

  @override
  String get disappearingChipTooltip => 'Verschwindende Nachrichten – für alle im Chat';

  @override
  String get disappearingUpdated => 'Timer für verschwindende Nachrichten geändert';

  @override
  String get disappearingSetFailed => 'Timer konnte nicht geändert werden';

  @override
  String get disappearingAdminOnly => 'Nur Besitzer und Administratoren können den Timer ändern';

  @override
  String get disappearingRoomOutdated => 'Einige Mitglieder nutzen eine alte App-Version – bei ihnen verschwinden die Nachrichten nicht.';

  @override
  String get disappearingQuoteGone => 'Nachricht verschwunden';

  @override
  String get serverAuthAlertTitle => 'Serverantwort hat die Prüfung nicht bestanden';

  @override
  String get serverAuthAlertBody => 'Jemand zwischen dir und dem Secretly-Server verändert möglicherweise Daten. Deine bestehenden Chats bleiben geschützt und funktionieren weiter. Neue Kontakte und Geräte werden erst wieder angenommen, wenn das vorbei ist. Versuche ein anderes Netzwerk oder einen Proxy.';

  @override
  String get serverAuthAlertDismiss => 'Verstanden';

  @override
  String get stickerPackAccessTitle => 'Wer dieses Paket hinzufügen kann';

  @override
  String get stickerPackAccessOpen => 'Offen';

  @override
  String get stickerPackAccessOpenHint => 'Wer einen Sticker von dir bekommt, kann das ganze Paket hinzufügen. Es landet nie auf dem Server.';

  @override
  String get stickerPackAccessClosed => 'Geschlossen';

  @override
  String get stickerPackAccessClosedHint => 'Nur du hast das Paket. Andere sehen die Sticker, die du schickst, können das Paket aber nicht hinzufügen. Gesendete Sticker bleiben trotzdem auf ihrem Gerät — Screenshots verhindert das nicht.';

  @override
  String get stickerPackClosedExistingNote => 'Wer das Paket schon hinzugefügt hat, behält es.';

  @override
  String get stickerPackClosedLabel => 'Geschlossenes Paket';

  @override
  String get stickerPackClosedNote => 'Der Autor erlaubt nicht, dieses Paket hinzuzufügen';

  @override
  String get stickerCreateFromPhoto => 'Aus einem Foto';

  @override
  String get stickerCreateTextOnly => 'Text-Sticker';

  @override
  String stickerCreateFailed(String error) {
    return 'Sticker konnte nicht erstellt werden: $error';
  }

  @override
  String stickerPackMissingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weitere Sticker wurden nicht übertragen – der Autor nutzt vielleicht eine alte App-Version',
      one: '$count weiterer Sticker wurde nicht übertragen – der Autor nutzt vielleicht eine alte App-Version',
    );
    return '$_temp0';
  }

  @override
  String get stickerAddedToPack => 'Sticker zum Paket hinzugefügt';

  @override
  String stickerSaveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get stickerFavoritesPackTitle => 'Favoriten';

  @override
  String get stickerAddedToFavorites => 'Sticker zu Favoriten hinzugefügt';

  @override
  String get stickerAnimationUnavailable => 'Animation ist auf diesem Gerät nicht verfügbar';

  @override
  String get stickerMotionPickTitle => 'Bewegungseffekt wählen';

  @override
  String get stickerMotionSlow => 'Langsam';

  @override
  String get stickerMotionNormal => 'Normal';

  @override
  String get stickerMotionFast => 'Schnell';

  @override
  String get stickerMotionPulse => 'Puls';

  @override
  String get stickerMotionBounce => 'Hüpfen';

  @override
  String get stickerMotionWobble => 'Wackeln';

  @override
  String get stickerMotionTada => 'Tada';

  @override
  String get stickerReadyTitle => 'Dein Sticker';

  @override
  String get stickerPickEmojiHint => 'Wähle Emoji, die zum Sticker passen';

  @override
  String get stickerSend => 'Sticker senden';

  @override
  String get stickerAnimating => 'Wird animiert…';

  @override
  String get stickerChangeMotion => 'Bewegung ändern';

  @override
  String get stickerAnimatePremium => 'Animieren · Premium';

  @override
  String get stickerMakeFavorite => 'Zu Favoriten';

  @override
  String get stickerAddToPack => 'Zum Paket hinzufügen';

  @override
  String get stickerBack => 'Zurück';

  @override
  String get stickerNewPack => 'Neues Paket';

  @override
  String get stickerNewPackHint => 'Gib dem Paket einen Namen.';

  @override
  String get stickerCreate => 'Erstellen';

  @override
  String get stickerEditorObjectNotFound => 'Kein Objekt erkannt';

  @override
  String get stickerEditorPickObject => 'Wähle ein Objekt';

  @override
  String get stickerEditorText => 'Text';

  @override
  String get stickerEditorSelectObject => 'Objekt markieren';

  @override
  String get stickerWord => 'Sticker';

  @override
  String get stickerEditorUndo => 'Rückgängig';

  @override
  String get stickerEditorRedo => 'Wiederholen';

  @override
  String get stickerEditorDelete => 'Löschen';

  @override
  String get stickerEditorDone => 'Fertig';

  @override
  String get stickerEditorBgNone => 'Ohne Hintergrund';

  @override
  String get stickerEditorBgSolid => 'Füllung';

  @override
  String get stickerEditorBgPill => 'Etikett';

  @override
  String get stickerEditorOutline => 'Kontur';

  @override
  String get stickerEditorBackground => 'Hintergrund';

  @override
  String get stickerEditorRecut => 'Neu ausschneiden';

  @override
  String get stickerEditorCut => 'Objekt ausschneiden';

  @override
  String get stickerEditorDraw => 'Zeichnen';

  @override
  String get stickerEditorAdjust => 'Anpassen';

  @override
  String get stickerEditorEmoji => 'Emoji';

  @override
  String get stickerEditorExposure => 'Belichtung';

  @override
  String get stickerEditorContrast => 'Kontrast';

  @override
  String get stickerEditorSaturation => 'Sättigung';

  @override
  String get stickerEditorTapObjects => 'Tippe auf die Objekte, die bleiben sollen';

  @override
  String get stickerEditorObjectSelected => 'Objekt ausgewählt';

  @override
  String stickerPackInstallFailed(String error) {
    return 'Stickerpaket konnte nicht installiert werden: $error';
  }

  @override
  String stickerPackRemoveFailed(String error) {
    return 'Stickerpaket konnte nicht entfernt werden: $error';
  }

  @override
  String get stickerPackRemoveTitle => 'Stickerpaket entfernen?';

  @override
  String stickerPackRemoveBody(String title) {
    return 'Das Paket \"$title\" bleibt im Katalog, aber lokale Dateien werden entfernt.';
  }

  @override
  String get stickerPackRemoveAction => 'Entfernen';

  @override
  String stickerPackRemovedSnack(String title) {
    return '\"$title\" von diesem Gerät entfernt.';
  }

  @override
  String get stickerPackEdit => 'bearbeiten';

  @override
  String get stickerPackCoverUpdated => 'Paketcover aktualisiert';

  @override
  String stickerPackFull(int max) {
    return 'Dieses Paket hat bereits $max Sticker – erstelle ein neues';
  }

  @override
  String get settingsGroupProfile => 'Profil';

  @override
  String get settingsGroupRecovery => 'Wiederherstellung';

  @override
  String get settingsCaptionAccountRestore => 'Mit ID und Sicherung holen Sie Ihr Konto auf ein neues Telefon zurück. Schreiben Sie die ID auf und bewahren Sie sie getrennt vom Telefon auf.';

  @override
  String get settingsGroupLeave => 'Abmelden und löschen';

  @override
  String get settingsCaptionLeave => 'Abmelden löscht Daten nur auf diesem Gerät. Löschen entfernt das Profil auch vom Server – das lässt sich nicht rückgängig machen.';

  @override
  String get settingsGroupGeneral => 'Allgemein';

  @override
  String get settingsGroupMessages => 'Nachrichten';

  @override
  String get settingsCaptionMessages => 'Wer Ihr Telefon in der Hand hat, sieht Text und Namen in der Mitteilung.';

  @override
  String get settingsGroupCalls => 'Anrufe';

  @override
  String get settingsGroupInApp => 'In der App';

  @override
  String get settingsCaptionInApp => 'Töne und Vibration, solange Secretly geöffnet ist.';

  @override
  String get settingsGroupNotificationLook => 'Aussehen der Mitteilungen';

  @override
  String get settingsGroupBackground => 'Im Hintergrund';

  @override
  String get settingsGroupQr => 'QR-Code';

  @override
  String get settingsGroupPersonal => 'Persönlich';

  @override
  String get settingsGroupWhoCan => 'Wer Sie sehen und kontaktieren darf';

  @override
  String get settingsGroupNewChats => 'Neue Chats';

  @override
  String get settingsGroupSearchBlocking => 'Suche und Sperren';

  @override
  String get settingsGroupPhoneContacts => 'Telefonkontakte';

  @override
  String get settingsGroupInactive => 'Wenn ich lange nicht da bin';

  @override
  String get settingsCaptionInactive => 'Wenn Sie Secretly so lange nicht öffnen, wird das Konto automatisch gelöscht.';

  @override
  String get settingsGroupAppLanguage => 'App-Sprache';

  @override
  String get settingsGroupTranslation => 'Übersetzung';

  @override
  String get settingsGroupStatus => 'Status';

  @override
  String get settingsGroupBlocked => 'Wenn Secretly blockiert ist';

  @override
  String get settingsCaptionBlocked => 'Meist muss nichts eingestellt werden. Proxy und Orbot sind für den Fall, dass die Ausweichwege nicht helfen.';

  @override
  String get settingsGroupOwnProxy => 'Eigener Proxy';

  @override
  String get settingsGroupOffline => 'Ohne Internet';

  @override
  String get settingsCaptionOffline => 'Das ist eine Datei, keine Live-Verbindung: Ihr Kontakt liest die Nachrichten, sobald er die Datei öffnet.';

  @override
  String get settingsGroupHelpDelivery => 'Zustellung verbessern helfen';

  @override
  String get netHowItWorksTitle => 'So funktioniert es';

  @override
  String get netHowItWorksSubtitle => 'Einfach erklärt: Sperren umgehen und ohne Internet senden';

  @override
  String get netHowStep1Title => 'Wie eine Nachricht ankommt';

  @override
  String get netHowStep1Body => 'Ihr Telefon verschlüsselt die Nachricht vor dem Senden. Der Server bewahrt sie verschlüsselt auf, solange Ihr Kontakt offline ist, und liefert sie aus, sobald er online ist. Lesen kann der Server sie nicht.';

  @override
  String get netHowStep2Title => 'Wenn Secretly blockiert ist';

  @override
  String get netHowStep2Body => '„Alternative Wege suchen“ ist von Anfang an an. Die App probiert selbst eine Ersatzadresse, eine Kopie des Servers („Spiegel“) und große Liefernetze („CDN“), die sich schwer komplett sperren lassen. Die erste Verbindung kann länger dauern.';

  @override
  String get netHowStep3Title => 'Wenn das nicht geholfen hat';

  @override
  String get netHowStep3Body => 'Bitten Sie eine Vertrauensperson um einen Proxy-Link und fügen Sie ihn unter „Freiwilligen-Proxy“ ein. Sie können auch Orbot installieren, die App des Tor-Netzes. Das ist langsamer, und Orbot braucht Akku.';

  @override
  String get netHowStep4Title => 'Gar kein Internet';

  @override
  String get netHowStep4Body => 'Tippen Sie auf „Ohne Netzwerk senden“, wählen Sie den Kontakt und geben Sie die Datei beliebig weiter: USB-Stick, AirDrop, Bluetooth. Er öffnet sie in Secretly. Die Datei enthält nur bereits geschriebene Nachrichten der letzten Woche. Eine Live-Verbindung über Bluetooth oder Telefone in der Nähe gibt es noch nicht.';

  @override
  String get netHowStep5Title => 'Anrufe';

  @override
  String get netHowStep5Body => 'Unter „Datenschutz“ können Sie Ihre Adresse bei Anrufen verbergen: Der Anruf läuft über unseren Server, und Ihr Kontakt sieht Ihre IP-Adresse nicht. Die Verzögerung kann etwas steigen.';

  @override
  String get netHowStep6Title => 'Damit Nachrichten nicht zu spät kommen';

  @override
  String get netHowStep6Body => 'Das System des Telefons kann Secretly „schlafen legen“, dann kommen Nachrichten erst, wenn Sie die App öffnen. Unter „Zuverlässigkeit“ sehen Sie, was die Zustellung stört.';

  @override
  String get settingsHelpGotIt => 'Verstanden';

  @override
  String get settingsHelpTip => 'Tipp';

  @override
  String get settingsHelpButton => 'Erklärung';

  @override
  String get settingsHubAccountGroup => 'Konto & Schutz';

  @override
  String get settingsHubTalkGroup => 'Kommunikation';

  @override
  String get settingsHubConnectionGroup => 'Verbindung';

  @override
  String get settingsHubPhoneGroup => 'Telefon';

  @override
  String get settingsHubMoreGroup => 'Mehr';

  @override
  String get settingsHubAccountSub => 'Name, Secretly ID, QR, Sicherung';

  @override
  String get settingsHubPrivacySub => 'Wer Sie sieht und Ihnen schreiben darf';

  @override
  String get settingsHubSecuritySub => 'App-Sperre, persönliche Chats';

  @override
  String get settingsHubDevicesSub => 'Wo Ihr Konto geöffnet ist';

  @override
  String get settingsHubNotificationsSub => 'Nachrichten, Räume, Anrufe';

  @override
  String get settingsHubChatsSub => 'Design, Hintergründe, Blasen, Symbol';

  @override
  String get settingsHubLanguageSub => 'App-Sprache und Übersetzung';

  @override
  String get settingsHubNetworkSub => 'Wie Secretly seine Server erreicht';

  @override
  String get settingsHubOfflineSub => 'Nachrichten als Datei weitergeben';

  @override
  String get settingsHubReliabilitySub => 'Was die Zustellung verzögern kann';

  @override
  String get settingsHubSystemSub => 'Zurücksetzen und Systemmeldungen';

  @override
  String get settingsHubInviteSub => 'Link teilen';

  @override
  String get settingsHubDonateSub => 'Projekt unterstützen';

  @override
  String get settingsHubSupportSub => 'Schreiben Sie uns';

  @override
  String get settingsHubPolicySub => 'Was wo gespeichert wird';

  @override
  String get settingsHubAboutSub => 'Version und Lizenzen';

  @override
  String get settingsIntroAccount => 'Wie andere Sie sehen und wie Sie den Zugang zu Ihren Chats nicht verlieren.';

  @override
  String get settingsIntroPrivacy => 'Legen Sie fest, wer Ihre Angaben sieht und wer Sie kontaktieren darf.';

  @override
  String get settingsIntroSecurity => 'Schutz, falls Ihr Telefon in fremde Hände gerät.';

  @override
  String get settingsIntroNotifications => 'Was Ihnen wie gemeldet wird. Beginnen Sie mit dem Hauptschalter.';

  @override
  String get settingsIntroLanguage => 'Die Sprache, in der Secretly mit Ihnen spricht.';

  @override
  String get settingsIntroNetwork => 'Wie Secretly sich mit seinen Servern verbindet. Meist muss hier nichts geändert werden.';

  @override
  String get settingsIntroOffline => 'Ganz ohne Internet können Sie Nachrichten als Datei weitergeben – per USB-Stick, Bluetooth oder über einen anderen Messenger.';

  @override
  String get settingsIntroReliability => 'Wir prüfen, ob das System verhindert, dass Nachrichten und Anrufe rechtzeitig ankommen.';

  @override
  String get settingsIntroPower => 'Schalten Sie Effekte aus, wenn das Telefon warm wird oder schnell leer ist.';

  @override
  String get settingsIntroStorage => 'Wie viel Platz Secretly auf Ihrem Telefon belegt.';

  @override
  String get settingsIntroSystem => 'Wartungsaktionen. Nur verwenden, wenn etwas schiefgelaufen ist.';

  @override
  String get settingsGroupShare => 'Teilen';

  @override
  String get settingsGroupMedia => 'Medien';

  @override
  String get settingsGroupData => 'Daten';

  @override
  String get settingsGroupLock => 'Sperre';

  @override
  String get settingsGroupManual => 'Manuelle Einrichtung';

  @override
  String get settingsHelpManual => 'Nur nötig, wenn die alternativen Wege nicht geholfen haben. Wählen Sie einen Weg: einen Proxy von einem bekannten Freiwilligen, SOCKS5 oder Tor über Orbot.';

  @override
  String get settingsGroupConnection => 'Verbindung';

  @override
  String get settingsGroupSend => 'Senden';

  @override
  String get settingsGroupReceive => 'Empfangen';

  @override
  String get settingsOpenPersonalChats => 'Persönliche Chats öffnen';

  @override
  String get settingsOpenPersonalChatsSub => 'Ihre versteckte Chat-Sammlung';

  @override
  String get offlineStep1Title => 'Datei erstellen';

  @override
  String get offlineStep1Body => 'Wählen Sie einen Kontakt – die Datei enthält Ihre verschlüsselten Nachrichten an ihn aus der letzten Woche.';

  @override
  String get offlineStep2Title => 'Beliebig weitergeben';

  @override
  String get offlineStep2Body => 'USB-Stick, Bluetooth, AirDrop, ein anderer Messenger. Nur der Empfänger kann die Nachrichten lesen.';

  @override
  String get offlineStep3Title => 'Ihr Kontakt öffnet die Datei';

  @override
  String get offlineStep3Body => 'In Secretly: „Ohne Internet“ → „Nachrichtendatei öffnen“. Die Nachrichten erscheinen im Chat.';

  @override
  String get translateSameLanguage => 'Die Nachricht ist bereits in dieser Sprache';

  @override
  String get translateUndetected => 'Sprache nicht erkannt. Wählen Sie die Ausgangssprache unter Einstellungen → Sprache.';

  @override
  String get translateUnsupported => 'Der Übersetzer auf dem Telefon kennt diese Sprache noch nicht';

  @override
  String get translateDownloadFailed => 'Sprachpaket konnte nicht geladen werden. Verbindung prüfen und erneut tippen.';

  @override
  String get translateFailed => 'Übersetzung fehlgeschlagen. Erneut tippen.';

  @override
  String get translateNothing => 'Hier gibt es nichts zu übersetzen';

  @override
  String get translateDownloading => 'Sprachpaket wird geladen – nur einmal nötig';

  @override
  String get translateButtonTooltip => 'Übersetzen';

  @override
  String get attachmentMetadataScrubFailed => 'Ort und Telefondaten ließen sich nicht aus dieser Datei entfernen, deshalb wurde sie nicht gesendet. Versuchen Sie ein anderes Foto oder senden Sie es als Datei.';

  @override
  String get backupServerWrongPassword => 'Falsches Passwort oder keine Sicherung für diese Profil-ID. Prüfen Sie ID, Tastaturlayout und Groß-/Kleinschreibung.';

  @override
  String backupServerLocked(String time) {
    return 'Zu viele falsche Passwörter aus diesem Netz. Versuchen Sie es nach $time oder aus einem anderen Netz.';
  }

  @override
  String get backupServerSection => 'Sicherung auf dem Server';

  @override
  String get backupServerDelete => 'Sicherung vom Server löschen';

  @override
  String get backupServerDeleteFooter => 'Die verschlüsselte Sicherung wird vom Server entfernt. Sicherungen auf diesem Gerät und in Dateien bleiben.';

  @override
  String get backupServerDeleteConfirmTitle => 'Sicherung vom Server löschen?';

  @override
  String get backupServerDeleteConfirmBody => 'Chats lassen sich auf einem neuen Telefon nicht mehr vom Server wiederherstellen. Die automatische Sicherung auf den Server wird ausgeschaltet. Das lässt sich nicht rückgängig machen.';

  @override
  String get backupServerDeleteConfirm => 'Löschen';

  @override
  String get backupServerDeleteDone => 'Sicherung vom Server gelöscht';

  @override
  String get backupServerDeleteNone => 'Auf dem Server gab es keine Sicherung';

  @override
  String get backupServerDeleteFailed => 'Sicherung konnte nicht gelöscht werden. Verbindung prüfen und erneut versuchen.';

  @override
  String get backupAutoErrorNoPassword => 'Die automatische Sicherung läuft nicht: Es ist kein Sicherungspasswort festgelegt. Legen Sie es fest – ohne Passwort kann die Sicherung nicht verschlüsselt werden.';

  @override
  String get backupAutoErrorWeakPassword => 'Die automatische Sicherung läuft nicht: Das Passwort erfüllt die Anforderungen nicht mehr. Legen Sie ein neues fest.';

  @override
  String backupKeystoreUnreadable(String slot) {
    return 'Der Schlüssel „$slot“ konnte nicht aus dem geschützten Speicher des Telefons gelesen werden, daher wurde keine Sicherung erstellt. Ihre Chats auf diesem Telefon sind unversehrt. Wenden Sie sich an den Support – das lässt sich ohne Datenverlust beheben.';
  }

  @override
  String get stickerDeleteTitle => 'Sticker löschen?';

  @override
  String stickerDeleteBody(String title) {
    return 'Der Sticker wird aus „$title“ entfernt. Bereits in Chats gesendete Sticker bleiben dort.';
  }

  @override
  String get stickerDeleteLastTitle => 'Ganzes Paket löschen?';

  @override
  String stickerDeleteLastBody(String title) {
    return 'Das ist der letzte Sticker in „$title“. Mit ihm wird das ganze Paket gelöscht.';
  }

  @override
  String get stickerDeleteAction => 'Löschen';

  @override
  String get stickerPackSettings => 'Paket-Einstellungen';

  @override
  String get stickerMore => 'Mehr';

  @override
  String get stickerPackRemoveFromMine => 'Aus meinen Paketen entfernen';

  @override
  String stickerPackRemoveFromMineBody(String title) {
    return '„$title“ verschwindet aus deinem Bereich. Autor und andere behalten es; du kannst es erneut hinzufügen, indem du in einem Chat auf einen Sticker daraus tippst.';
  }

  @override
  String get stickerPackDeleteWhole => 'Paket löschen';

  @override
  String get stickerPackDeleteWholeTitle => 'Paket löschen?';

  @override
  String stickerPackDeleteWholeBody(String title) {
    return 'Das Paket „$title“ wird von diesem Gerät gelöscht. Bereits gesendete Sticker bleiben in den Chats.';
  }

  @override
  String get stickerMakeCover => 'Als Titelbild';

  @override
  String get stickerRemoveFromFavorites => 'Aus Favoriten entfernen';

  @override
  String get stickerRemovedFromFavorites => 'Aus Favoriten entfernt';

  @override
  String stickerAddToThisPack(String title) {
    return 'Zu „$title“ hinzufügen';
  }

  @override
  String get stickerAddSticker => 'Sticker hinzufügen';
}
