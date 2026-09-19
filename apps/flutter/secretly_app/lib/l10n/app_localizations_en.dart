// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Secretly';

  @override
  String get starting => 'Starting…';

  @override
  String get encrypting => 'Encrypting…';

  @override
  String errorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get notificationsSection => 'Notifications';

  @override
  String get languageSection => 'Language';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get idsTitle => 'IDs';

  @override
  String get profileIdLabel => 'Profile ID';

  @override
  String get deviceIdLabel => 'Device ID';

  @override
  String get profileIdShort => 'Profile';

  @override
  String get deviceIdShort => 'Device';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get copyBoth => 'Copy both';

  @override
  String get openMyId => 'Open my ID';

  @override
  String get close => 'Close';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabGroups => 'Rooms';

  @override
  String get tabContacts => 'Contacts';

  @override
  String get tabProfile => 'Profile';

  @override
  String get accountSection => 'Account';

  @override
  String get chatsSection => 'Chats';

  @override
  String get privacySection => 'Privacy';

  @override
  String get devicesSection => 'Devices';

  @override
  String get systemSection => 'System';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String languageSystemCurrent(Object language) {
    return 'System ($language)';
  }

  @override
  String get languageChooseAppLanguage => 'Choose app language';

  @override
  String get languageAvailableWave1 => 'Available: English, Russian, Ukrainian, Spanish, Portuguese (Brazil), French, and German. You can also follow system language.';

  @override
  String get languageMessageTranslation => 'Message translation';

  @override
  String get languageShowTranslateButton => 'Show Translate button';

  @override
  String get languageTranslateWholeChats => 'Translate whole chats';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesSubtitle => 'Your personal notes';

  @override
  String get favoritesEmptyTitle => 'No favorites yet';

  @override
  String get favoritesEmptySubtitle => 'Send messages, files, and notes here to keep them private on your devices.';

  @override
  String get favoritesPersonalNotebookLabel => 'Personal notes';

  @override
  String get more => 'More';

  @override
  String get stickersRecent => 'Recent stickers';

  @override
  String get searchStickers => 'Search stickers';

  @override
  String get noStickersFound => 'No stickers found';

  @override
  String get noRecentStickers => 'Your recent stickers will appear here';

  @override
  String get cancelSelection => 'Cancel selection';

  @override
  String get chatsTitle => 'Chats';

  @override
  String get newChat => 'New chat';

  @override
  String get openContactsToStartChat => 'Open Contacts to start a chat';

  @override
  String get noChatsYet => 'No chats yet';

  @override
  String get openDemoChat => 'Open demo chat';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get clearHistory => 'Clear history';

  @override
  String archiveHeader(Object count) {
    return 'Archive ($count)';
  }

  @override
  String deleteChatsConfirmTitle(Object count) {
    return 'Delete $count chat(s)?';
  }

  @override
  String get deleteChatsConfirmBody => 'This removes chats from this device only.';

  @override
  String clearHistoryConfirmTitle(Object count) {
    return 'Clear history for $count chat(s)?';
  }

  @override
  String get clearHistoryConfirmBody => 'This removes messages from this device only.';

  @override
  String get contactsTitle => 'Contacts';

  @override
  String get contactsTab => 'Contacts';

  @override
  String get requestsTab => 'Requests';

  @override
  String get addContact => 'Add contact';

  @override
  String get deleteContact => 'Delete contact';

  @override
  String get noContactsYet => 'No contacts yet';

  @override
  String get noRequests => 'No requests';

  @override
  String get secretlyIdLabel => 'Secretly ID';

  @override
  String get secretlyIdHint => 'XXXX-XXXX-...-CHECK';

  @override
  String get nameOptionalLabel => 'Name (optional)';

  @override
  String get scanContactQrTitle => 'Scan contact QR';

  @override
  String get qrMissingSecretlyId => 'QR does not contain Secretly ID';

  @override
  String get differentServerTitle => 'Different server';

  @override
  String differentServerBody(Object qrServer, Object appServer) {
    return 'This QR belongs to another server.\n\nQR server: $qrServer\nThis app: $appServer\n\nInstall the same APK/server on both phones.';
  }

  @override
  String get contactActionProfileNotFound => 'Secretly ID was not found on this server.';

  @override
  String get contactActionTransportBlocked => 'This action is unavailable because the app is bound to a different server.';

  @override
  String get contactActionServiceUnavailable => 'Server is unavailable right now. Try again in a moment.';

  @override
  String get contactActionCallsDisabled => 'Calls are disabled in Privacy settings.';

  @override
  String get contactActionCallsDisabledForContact => 'Calls are disabled for this contact.';

  @override
  String get callServiceUnavailable => 'Call service is unavailable right now.';

  @override
  String get callAlreadyInProgress => 'Another call is already in progress.';

  @override
  String get callIceUnavailable => 'Secure call setup is unavailable right now. Try again in a moment.';

  @override
  String get callPermissionDenied => 'Microphone or camera access is blocked. Allow permissions and try again.';

  @override
  String get callNegotiationFailed => 'Couldn\'t establish the secure call. Try again.';

  @override
  String get callConnectionInterrupted => 'Call connection was interrupted. Try again.';

  @override
  String get callActionGeneric => 'Couldn\'t start the call. Try again.';

  @override
  String get callEncryptedBadge => 'End-to-end encrypted';

  @override
  String get incomingVideoCall => 'Incoming video call';

  @override
  String get incomingVoiceCall => 'Incoming voice call';

  @override
  String get callDecline => 'Decline';

  @override
  String get callConnectionUnstable => 'Connection unstable';

  @override
  String get callNetworkVeryWeak => 'Very weak network signal';

  @override
  String get callNetworkWeak => 'Weak network signal';

  @override
  String get callEnded => 'Call ended';

  @override
  String get callReplacedByNewerAttempt => 'Call was replaced by a newer attempt';

  @override
  String get callDeclined => 'Call declined';

  @override
  String get callYouDeclined => 'You declined';

  @override
  String get callNoAnswer => 'No answer';

  @override
  String get callConnectionError => 'Connection error';

  @override
  String get callVideoUnavailable => 'Video unavailable';

  @override
  String get callWaitingForRemoteVideo => 'Waiting for remote video...';

  @override
  String get callAttachingRemoteVideo => 'Attaching remote video...';

  @override
  String get callStartingRemoteVideo => 'Starting remote video...';

  @override
  String get callRemoteVideoNotArriving => 'Remote video is not arriving';

  @override
  String get callRemoteVideoBindFailed => 'Could not bind remote video stream';

  @override
  String get callRemoteVideoNoFrames => 'Remote video attached, but no frames are rendering';

  @override
  String get callMinimize => 'Minimize';

  @override
  String get callStatusCalling => 'Calling...';

  @override
  String get callStatusIncoming => 'Incoming...';

  @override
  String get callStatusConnecting => 'Connecting...';

  @override
  String get callStatusReconnecting => 'Reconnecting...';

  @override
  String get callStatusEnded => 'Ended';

  @override
  String get callVideoCall => 'Video call';

  @override
  String get callControlMute => 'Mute';

  @override
  String get callControlSpeaker => 'Speaker';

  @override
  String get callControlCamera => 'Camera';

  @override
  String get callControlFlip => 'Flip';

  @override
  String get callControlStop => 'Stop';

  @override
  String get callControlShare => 'Share';

  @override
  String get callControlEnd => 'End';

  @override
  String get contactActionGeneric => 'Couldn\'t complete the action. Try again.';

  @override
  String get notificationTitleRoom => 'Room';

  @override
  String get notificationTitleRequest => 'Request';

  @override
  String get notificationTitleChat => 'Chat';

  @override
  String get notificationBodyNewMessage => 'New message';

  @override
  String get contactLookupUnavailable => 'Search is unavailable right now. Try again in a moment.';

  @override
  String addContactFailed(Object error) {
    return 'Add contact failed: $error';
  }

  @override
  String deleteContactsConfirmTitle(Object count) {
    return 'Delete $count contact(s)?';
  }

  @override
  String get deleteContactsConfirmBody => 'Chats are not deleted.';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get blockedUsersSubtitle => 'Blocked users cannot deliver messages to you (server-enforced).';

  @override
  String get noBlockedUsers => 'No blocked users';

  @override
  String unblockFailed(Object error) {
    return 'Unblock failed: $error';
  }

  @override
  String get diagIdentity => 'Identity';

  @override
  String get diagEndpoints => 'Endpoints';

  @override
  String get diagServerBinding => 'Server binding';

  @override
  String get diagMismatch => 'Mismatch: profile belongs to another server. Use Settings → Reset profile.';

  @override
  String get diagStatus => 'Status';

  @override
  String get diagTimestamps => 'Timestamps';

  @override
  String get diagTips => 'Tips';

  @override
  String get diagTipsBody => 'If messaging fails with \"profile not found\":\n1) Ensure both phones use the same APK/server\n2) Re-add contact by scanning QR\n3) If endpoints changed, use Reset profile\n';

  @override
  String get secretlyUser => 'Secretly user';

  @override
  String get onlineStatus => 'online';

  @override
  String get edit => 'Edit';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get profileSectionTitle => 'Profile';

  @override
  String get myNicknameLabel => 'My nickname';

  @override
  String get myNicknameHint => 'e.g. Alex';

  @override
  String get includeNicknameInQr => 'Include nickname in my QR';

  @override
  String get includeNicknameInQrSubtitle => 'Off by default for privacy. If enabled, scanners may auto-name you.';

  @override
  String verifyTitle(Object title) {
    return 'Verify: $title';
  }

  @override
  String get scanVerifyQrTitle => 'Scan verify QR';

  @override
  String qrBelongsAnotherServer(Object server) {
    return 'QR belongs to another server: $server';
  }

  @override
  String get qrSecretlyIdMismatch => 'QR Secretly ID does not match this contact';

  @override
  String get qrMissingDeviceKeyInfo => 'QR missing device/key info';

  @override
  String get deviceNotCachedTapRefresh => 'Device not cached. Tap Refresh first.';

  @override
  String get identityKeyMismatch => 'Identity key mismatch. Do not verify.';

  @override
  String get verifiedSuccess => 'Verified ✅';

  @override
  String get refreshKeys => 'Refresh keys';

  @override
  String get keysOfflineCannotFetch => 'Keys service is offline. Cannot fetch contact keys right now.';

  @override
  String get devicesLabel => 'Devices';

  @override
  String get noDeviceKeysCachedYet => 'No device keys cached yet.';

  @override
  String deviceTitle(Object deviceId) {
    return 'Device $deviceId';
  }

  @override
  String deviceFpStatus(Object fp, Object status) {
    return 'fp: $fp\n$status';
  }

  @override
  String get verifiedLower => 'verified';

  @override
  String get unverifiedLower => 'unverified';

  @override
  String get keysOfflineIdTemporary => 'Keys service is offline. ID may be temporary in dev mode.';

  @override
  String get serverKeysLabel => 'Server (Keys)';

  @override
  String get nicknameLabel => 'Nickname';

  @override
  String get identityFingerprintLabel => 'Identity fingerprint';

  @override
  String get scanToAddVerifyContact => 'Scan to add/verify this contact';

  @override
  String get mySecretlyId => 'My Secretly ID';

  @override
  String get deviceId => 'Device ID';

  @override
  String get recoveryKit => 'Recovery Kit';

  @override
  String get safeBackupTitle => 'Backup';

  @override
  String get safeBackupSubtitle => 'Encrypted backup stored on the server';

  @override
  String get safeBackupIntro => 'Create an encrypted backup locally or on the server. You can restore later from a file or Secretly ID.';

  @override
  String get safeBackupUploadNow => 'Upload backup now';

  @override
  String get safeBackupRestoreFromServer => 'Restore from server';

  @override
  String get safeBackupRestoreTitle => 'Restore from server backup';

  @override
  String get safeBackupRestoreConfirmTitle => 'Restore account?';

  @override
  String get safeBackupRestoreConfirmBody => 'This will remove local chats/contacts on this device and restore the account from the selected backup. The app will restart automatically.';

  @override
  String get safeBackupUploaded => 'Backup uploaded';

  @override
  String get safeBackupUploadFailed => 'Backup upload failed';

  @override
  String safeBackupUploadFailedWithError(Object error) {
    return 'Backup upload failed: $error';
  }

  @override
  String get safeBackupNotFound => 'No server backup found for this Secretly ID';

  @override
  String get exportRecoveryKit => 'Export Recovery Kit';

  @override
  String get exportRecoveryKitSubtitle => 'Encrypted QR for account recovery';

  @override
  String get restoreRecoveryKit => 'Restore from Recovery Kit';

  @override
  String get restoreRecoveryKitSubtitle => 'Wipes local data and restores this Secretly ID';

  @override
  String get recoveryPasswordTitle => 'Recovery password';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get export => 'Export';

  @override
  String get scanQr => 'Scan QR';

  @override
  String get invalidRecoveryKit => 'Invalid recovery kit';

  @override
  String get wrongPassword => 'Wrong password';

  @override
  String get restoreConfirmTitle => 'Restore account?';

  @override
  String get restoreConfirmBody => 'This will remove local chats/contacts on this device and restore the account from the recovery kit.';

  @override
  String get restore => 'Restore';

  @override
  String get darkTheme => 'Dark theme';

  @override
  String get darkThemeSubtitle => 'Use the same accent tint in dark mode.';

  @override
  String get blockUnverified => 'Block sending to unverified contacts';

  @override
  String get blockUnverifiedSubtitle => 'Strict mode: in one-to-one chats, only send to contacts whose keys you checked yourself. Does not apply to groups.';

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get resetProfile => 'Reset profile';

  @override
  String get resetProfileSubtitle => 'Fix server/account mismatch by creating a new Secretly ID';

  @override
  String get resetProfileDialogTitle => 'Reset profile?';

  @override
  String get resetProfileDialogBody => 'This will remove local chats/contacts/requests on this device and create a new Secretly ID.\n\nUse this when you changed APK/server and messages started failing.';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get clear => 'Clear';

  @override
  String get block => 'Block';

  @override
  String get unblock => 'Unblock';

  @override
  String get accept => 'Accept';

  @override
  String get verify => 'Verify';

  @override
  String get menu => 'Menu';

  @override
  String get search => 'Search';

  @override
  String get queryLabel => 'Query';

  @override
  String get messageHint => 'Message';

  @override
  String get notificationActionMarkRead => 'Mark Read';

  @override
  String get addCaption => 'Add a caption';

  @override
  String get uploadCanceled => 'Upload canceled';

  @override
  String get attachmentFinalizeTimeout => 'Network is unstable: upload finished, but send confirmation timed out. Try again.';

  @override
  String get attachmentTransferUnavailable => 'Couldn\'t transfer the attachment right now. Check internet/server and try again.';

  @override
  String get attachmentSendUnavailable => 'Attachment sending is not ready yet. Try again.';

  @override
  String get attachmentContactSyncPending => 'Waiting for contact identity sync. Ask the contact to send one more message and try again.';

  @override
  String get attachmentContactBlocked => 'This contact is blocked.';

  @override
  String get attachmentRecipientNotFound => 'Recipient profile was not found on this server. Check Secretly ID and make sure both devices use the same server.';

  @override
  String get attachmentRecipientNoDevices => 'Recipient has no registered devices yet. Ask the contact to open Secretly and try again.';

  @override
  String get attachmentNoDeliverableDevices => 'Couldn\'t deliver the attachment to any recipient device. Try again.';

  @override
  String get attachmentActionGeneric => 'Couldn\'t send the attachment. Try again.';

  @override
  String get send => 'Send';

  @override
  String get attach => 'Attach';

  @override
  String get photo => 'Photo';

  @override
  String get video => 'Video';

  @override
  String get file => 'File';

  @override
  String get music => 'Music';

  @override
  String get attachment => 'Attachment';

  @override
  String get downloading => 'Downloading…';

  @override
  String downloadFailed(Object error) {
    return 'Download failed: $error';
  }

  @override
  String savedTo(Object path) {
    return 'Saved to: $path';
  }

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get decrypting => 'Decrypting…';

  @override
  String get uploading => 'Uploading…';

  @override
  String get uploadTimedOut => 'Upload timed out. Check internet/server and try again.';

  @override
  String uploadingBytes(Object sent, Object total) {
    return 'Uploaded $sent / $total bytes';
  }

  @override
  String get requestsInfo => 'This chat is in Requests. Accept to reply, or block to ignore.';

  @override
  String get verifyRequired => 'Verify required';

  @override
  String get verifyContact => 'Verify contact';

  @override
  String get muteNotifications => 'Mute notifications';

  @override
  String get unmuteNotifications => 'Unmute notifications';

  @override
  String get setContactPhoto => 'Set contact photo';

  @override
  String get removeContactPhoto => 'Remove contact photo';

  @override
  String get blockUser => 'Block user';

  @override
  String get unblockUser => 'Unblock user';

  @override
  String get deleteChat => 'Delete chat';

  @override
  String get missingRecipient => 'Missing recipient';

  @override
  String get contactNotVerified => 'Their security code has changed. Check it to keep sending.';

  @override
  String get safetyNumberChangedTitle => 'Security code has changed';

  @override
  String get safetyNumberChangedBody => 'You checked this contact\'s code before. Their keys are new now — that usually happens after they reinstall the app or switch phones. Your chat stays encrypted either way. Compare the code again if you want to be sure it is still them.';

  @override
  String get safetyNumberStrictBody => 'You turned on “Require verification before sending”. Compare this contact\'s code to send them messages.';

  @override
  String get sendAnyway => 'Send anyway';

  @override
  String get alsoDeleteChat => 'Also delete chat';

  @override
  String get unblockUserConfirmTitle => 'Unblock user?';

  @override
  String get blockUserConfirmTitle => 'Block user?';

  @override
  String get deleteChatConfirmTitle => 'Delete chat?';

  @override
  String get deleteChatConfirmBody => 'This removes the chat from this device only.';

  @override
  String attachFailed(Object error) {
    return 'Attach failed: $error';
  }

  @override
  String sendFailed(Object error) {
    return 'Send failed: $error';
  }

  @override
  String actionFailed(Object error) {
    return 'Action failed: $error';
  }

  @override
  String get roomPolicyNotMember => 'You are no longer a participant in this room.';

  @override
  String get roomPolicyAdminsOnly => 'Only room owners and admins can do that in this room.';

  @override
  String get roomPolicyTextMessagesDisabled => 'Your role cannot send text messages in this room.';

  @override
  String get roomPolicyMediaDisabled => 'Your role cannot send media in this room.';

  @override
  String get roomPolicyReactionsDisabled => 'Reactions are disabled in this room.';

  @override
  String get roomPolicyReactionNotAllowed => 'This reaction is not allowed in this room.';

  @override
  String get roomPolicyPinDenied => 'Only admins can pin messages in this room.';

  @override
  String get roomPolicyAddMembersDenied => 'Only admins can add participants to this room.';

  @override
  String get roomPolicyChangeInfoDenied => 'Only admins can change the group profile.';

  @override
  String roomPolicySlowMode(Object seconds) {
    return 'Slow mode is enabled. Try again in ${seconds}s.';
  }

  @override
  String get noMatches => 'No matches';

  @override
  String attachmentTooLarge(Object mb) {
    return 'Attachment is too large ($mb MB).';
  }

  @override
  String get attachmentFileMissing => 'File is not available anymore.';

  @override
  String foundPrefix(Object hit) {
    return 'Found: $hit';
  }

  @override
  String get contactDetailsChat => 'Chat';

  @override
  String get contactDetailsSound => 'Sound';

  @override
  String get contactDetailsCall => 'Call';

  @override
  String get contactDetailsVideo => 'Video';

  @override
  String get contactDetailsUsernameLabel => 'Username';

  @override
  String get contactDetailsAddToContacts => 'Add to contacts';

  @override
  String get contactDetailsMediaTab => 'Media';

  @override
  String get contactDetailsFilesTab => 'Files';

  @override
  String get contactDetailsNoMedia => 'No media';

  @override
  String get contactDetailsNoFiles => 'No files';

  @override
  String get contactDetailsStatusRecently => 'last seen recently';

  @override
  String contactDetailsStatusAt(Object time) {
    return 'last seen at $time';
  }

  @override
  String get contactDetailsAutoDelete => 'Auto-delete';

  @override
  String get contactDetailsShareContact => 'Share contact';

  @override
  String get contactDetailsEditContact => 'Edit contact';

  @override
  String get contactDetailsDeleteContact => 'Delete contact';

  @override
  String get contactDetailsSendGift => 'Send gift';

  @override
  String get contactDetailsStartSecretChat => 'Start secret chat';

  @override
  String get contactDetailsCreateShortcut => 'Create shortcut';

  @override
  String get contactDetailsNameLabel => 'Name';

  @override
  String get contactDetailsSave => 'Save';

  @override
  String get contactDetailsDeleteConfirmTitle => 'Delete contact?';

  @override
  String get contactAutoDeleteOff => 'Off';

  @override
  String get contactAutoDelete1Day => '24 hours';

  @override
  String get contactAutoDelete7Days => '7 days';

  @override
  String get contactAutoDelete30Days => '30 days';

  @override
  String get contactEditTitle => 'Edit contact';

  @override
  String get contactEditDone => 'DONE';

  @override
  String get contactEditNameLabel => 'Name';

  @override
  String get contactEditAssignEmoji => 'Assign emoji';

  @override
  String get contactEditClearEmoji => 'Clear emoji';

  @override
  String get contactEditSetPhoto => 'Set photo';

  @override
  String get chatMenuReply => 'Reply';

  @override
  String get chatMenuCopy => 'Copy';

  @override
  String get chatMenuForward => 'Forward';

  @override
  String get chatMenuPin => 'Pin';

  @override
  String get chatMenuDelete => 'Delete';

  @override
  String get reset => 'Reset';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get diagnosticsSubtitle => 'Status, binding, timestamps';

  @override
  String get sendLater => 'Send later';

  @override
  String get sendSilently => 'Send without sound';

  @override
  String scheduledSendToday(Object time) {
    return 'Send today at $time';
  }

  @override
  String scheduledSendOn(Object date, Object time) {
    return 'Send $date at $time';
  }

  @override
  String get repeatNever => 'Never';

  @override
  String get repeat => 'Repeat';

  @override
  String get onboardingBackTooltip => 'Back';

  @override
  String get onboardingWelcomeTitle => 'Welcome!';

  @override
  String get onboardingWelcomeSubtitle => 'A next-generation messenger.\nComplete privacy. No compromises.';

  @override
  String get onboardingCreateAccount => 'Create new account';

  @override
  String get onboardingAlreadyHaveAccount => 'Already have an account';

  @override
  String get onboardingFeatureE2eTitle => 'E2E encryption';

  @override
  String get onboardingFeatureE2eBody => 'Messages are encrypted on your device. Only you have the keys.';

  @override
  String get onboardingFeaturePrivacyTitle => 'Full anonymity';

  @override
  String get onboardingFeaturePrivacyBody => 'No phone number. No link to personal data.';

  @override
  String get onboardingFeatureRelayTitle => 'No middlemen';

  @override
  String get onboardingFeatureRelayBody => 'The relay server does not store messages. It only passes them through.';

  @override
  String get onboardingProfileTitle => 'Your profile';

  @override
  String get onboardingProfileSubtitle => 'How other users will see you';

  @override
  String get onboardingProfileNameSection => 'Profile name';

  @override
  String get onboardingProfileNameHint => 'Your name or nickname';

  @override
  String get onboardingNotificationsSection => 'Notifications';

  @override
  String get onboardingMessageNotificationsTitle => 'Message notifications';

  @override
  String get onboardingMessageNotificationsSubtitle => 'Receive push notifications from Secretly';

  @override
  String get onboardingIncomingCallsTitle => 'Incoming calls';

  @override
  String get onboardingIncomingCallsSubtitle => 'Accept calls from contacts';

  @override
  String get continueAction => 'Continue';

  @override
  String get onboardingBackupSaveFailed => 'Could not save backup settings';

  @override
  String get backupPasswordRequirements => 'Use at least 8 ASCII characters, one uppercase letter, and one special character. No leading or trailing spaces.';

  @override
  String backupPasswordTooShort(Object minLength) {
    return 'Password must be at least $minLength characters.';
  }

  @override
  String backupPasswordTooLong(Object maxLength) {
    return 'Password must be no longer than $maxLength characters.';
  }

  @override
  String get backupPasswordNonAscii => 'Use only Latin letters, digits, and ASCII symbols.';

  @override
  String get backupPasswordOuterWhitespace => 'Remove leading or trailing spaces from the password.';

  @override
  String get backupPasswordMissingUppercase => 'Add at least one uppercase A-Z letter.';

  @override
  String get backupPasswordMissingSpecial => 'Add at least one special character, such as !, #, or ?.';

  @override
  String get onboardingBackupPasswordTitle => 'Backup password';

  @override
  String get onboardingPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get onboardingBackupTitle => 'Backups';

  @override
  String get onboardingBackupSubtitle => 'Protect your chats from data loss.\nEven when you change devices.';

  @override
  String get onboardingAutoBackupSection => 'Automatic backup';

  @override
  String get onboardingAutoBackupTitle => 'Auto-backup';

  @override
  String get onboardingAutoBackupSubtitle => 'Automatically save a backup';

  @override
  String get onboardingStorageTypeSection => 'Storage type';

  @override
  String get onboardingBackupMediaTitle => 'Back up media';

  @override
  String get onboardingBackupMediaSubtitle => 'Photos, videos, files, and avatars are included only in local backups';

  @override
  String get onboardingFrequencySection => 'Frequency';

  @override
  String get onboardingEnterSecretly => 'Enter Secretly';

  @override
  String get onboardingSkipBackup => 'Skip backup setup';

  @override
  String get onboardingSecretlyIdCopied => 'Secretly ID copied';

  @override
  String get onboardingRegistrationCompleteTitle => 'Registration complete';

  @override
  String get onboardingRegistrationCompleteSubtitle => 'Save your Secretly ID now. You need it to restore your account and backup on a new device.';

  @override
  String get onboardingYourSecretlyId => 'Your Secretly ID';

  @override
  String get onboardingCopyId => 'Copy ID';

  @override
  String get onboardingRecoveryWarning => 'Without your Secretly ID and backup password, restoring the server backup is impossible. Save the ID in a secure place and do not forget the password.';

  @override
  String get onboardingStorageCloud => 'Cloud';

  @override
  String get onboardingStorageCloudSubtitle => 'On the Secretly server';

  @override
  String get onboardingStorageLocal => 'Local';

  @override
  String get onboardingStorageLocalSubtitle => 'On this device';

  @override
  String get onboardingInterval6Hours => '6 hours';

  @override
  String get onboardingInterval12Hours => '12 hours';

  @override
  String get onboardingIntervalEveryDay => 'Every day';

  @override
  String get onboardingIntervalEvery3Days => 'Every 3 days';

  @override
  String get onboardingIntervalWeekly => 'Once a week';

  @override
  String get onboardingBackupLocalCandidate => 'Secretly local backup';

  @override
  String get onboardingDownloads => 'Downloads';

  @override
  String get onboardingDeviceFolder => 'Device folder';

  @override
  String get onboardingNoBackupsFound => 'No backups found on this device';

  @override
  String get onboardingFoundBackups => 'Found backups';

  @override
  String get onboardingNoBackupsFoundBody => 'Secretly checked local app backups and the Downloads folder. If the file is somewhere else, choose it manually.';

  @override
  String get chooseManually => 'Choose manually';

  @override
  String get onboardingChooseBackupFileTitle => 'Choose a Secretly backup file';

  @override
  String get onboardingReadBackupFailed => 'Could not read the backup file';

  @override
  String get onboardingServerBackupNotFound => 'Backup was not found on the server';

  @override
  String get onboardingRestoreThisBackupTitle => 'Restore this backup?';

  @override
  String get onboardingRestoreThisBackupBody => 'Current local data on this device will be replaced.';

  @override
  String onboardingSecretlyIdSummary(Object profileId) {
    return 'Secretly ID: $profileId';
  }

  @override
  String onboardingContactsSummary(Object count) {
    return 'Contacts: $count';
  }

  @override
  String onboardingMessagesSummary(Object count) {
    return 'Messages: $count';
  }

  @override
  String onboardingChatsSummary(Object count) {
    return 'Chats: $count';
  }

  @override
  String onboardingMediaFilesSummary(Object count) {
    return 'Media files: $count';
  }

  @override
  String get onboardingBrokenBackup => 'Damaged or invalid backup file';

  @override
  String get onboardingRestoreFailed => 'Restore failed. Try again.';

  @override
  String get onboardingRestoreLoginTitle => 'Sign in to your account';

  @override
  String get onboardingRestoreLoginSubtitle => 'Restore chats and settings\nfrom a previously created backup.';

  @override
  String get onboardingRestoreMediaSubtitle => 'For future local backups: photos, videos, files, and avatars will be added only if this is enabled.';

  @override
  String get onboardingRestoreFromCloudTitle => 'From Secretly cloud';

  @override
  String get onboardingRestoreFromCloudSubtitle => 'Enter your Secretly ID and backup password; data will be downloaded from the server';

  @override
  String get onboardingRestoreFromDeviceTitle => 'Find backup on this device';

  @override
  String get onboardingRestoreFromDeviceSubtitle => 'Secretly will check local backups and Downloads automatically';

  @override
  String get onboardingRestoring => 'Restoring...';

  @override
  String get onboardingRestoreFromServerTitle => 'Restore from server';

  @override
  String get callRecordOutgoingVideoCall => 'Outgoing video call';

  @override
  String get callRecordOutgoingCall => 'Outgoing call';

  @override
  String get callRecordIncomingVideoCall => 'Incoming video call';

  @override
  String get callRecordIncomingCall => 'Incoming call';

  @override
  String get callRecordMissedCall => 'Missed call';

  @override
  String get callRecordDeclinedCall => 'Call declined';

  @override
  String get callRecordBusy => 'Busy';

  @override
  String get callRecordFailed => 'Call failed';

  @override
  String get callRecordCanceled => 'Call canceled';

  @override
  String get callRecordOngoing => 'Ongoing call';

  @override
  String get safeBackupInvalidBackup => 'Invalid Secretly backup';

  @override
  String get recoveryKitPrepareFailed => 'Failed to prepare a Recovery Kit on this device.';

  @override
  String safeBackupPreviewProfileId(String profileId) {
    return 'Secretly ID: $profileId';
  }

  @override
  String safeBackupPreviewContacts(int count) {
    return 'Contacts: $count';
  }

  @override
  String safeBackupPreviewServer(String server) {
    return 'Server: $server';
  }

  @override
  String get safeBackupPreviewTitle => 'Backup preview:';

  @override
  String get safeBackupSavedToFiles => 'Backup saved to Secretly Files';

  @override
  String get safeBackupExportCanceled => 'Backup export canceled';

  @override
  String safeBackupExportFailed(Object error) {
    return 'Backup export failed: $error';
  }

  @override
  String get safeBackupCreateDialogTitle => 'Create backup';

  @override
  String get safeBackupServerDestination => 'Server backup';

  @override
  String get safeBackupLocalDestination => 'Local backup';

  @override
  String get safeBackupRestoreDialogTitle => 'Restore backup';

  @override
  String get safeBackupRestoreFromDevice => 'Restore from device';

  @override
  String get safeBackupDownloadsLocation => 'Downloads';

  @override
  String get safeBackupDeviceFolderLocation => 'Device folder';

  @override
  String get safeBackupChooseManualHint => 'Secretly checked local app backups and Downloads. You can still choose a file manually if it is stored elsewhere.';

  @override
  String get safeBackupChooseManually => 'Choose manually';

  @override
  String safeBackupReadFileFailed(Object error) {
    return 'Could not read backup file: $error';
  }

  @override
  String get safeBackupFrequencyTitle => 'Save frequency';

  @override
  String get saveAction => 'Save';

  @override
  String get safeBackupEnableAutoTitle => 'Enable auto-backup';

  @override
  String get safeBackupEnableAutoSubtitle => 'Runs in the app while online; encrypted with your password';

  @override
  String get safeBackupUploadToServer => 'Upload to server';

  @override
  String get safeBackupSaveOnDevice => 'Save on this device';

  @override
  String get safeBackupPasswordConfigured => 'Auto-backup password: configured';

  @override
  String get safeBackupPasswordNotSet => 'Auto-backup password: not set';

  @override
  String get safeBackupPasswordSaved => 'Auto-backup password saved';

  @override
  String genericFailed(Object error) {
    return 'Failed: $error';
  }

  @override
  String get safeBackupSetPassword => 'Set password';

  @override
  String get safeBackupPasswordRemoved => 'Auto-backup password removed';

  @override
  String get safeBackupClearPassword => 'Clear password';

  @override
  String get safeBackupRunRequested => 'Auto-backup run requested';

  @override
  String get safeBackupRunNow => 'Run auto-backup now';

  @override
  String safeBackupLastAutoBackup(String time) {
    return 'Last auto-backup: $time';
  }

  @override
  String get safeBackupLastAutoBackupNever => 'Last auto-backup: never';

  @override
  String safeBackupLastDeviceBackup(String time) {
    return 'Last device backup: $time';
  }

  @override
  String safeBackupLastAutoBackupError(Object error) {
    return 'Last auto-backup error: $error';
  }

  @override
  String get securityScopeAppObject => 'the app';

  @override
  String get securityScopePersonalObject => 'Personal chats';

  @override
  String get securityUnlockAppTitle => 'Unlock the app';

  @override
  String get securityUnlockPersonalTitle => 'Unlock Personal chats';

  @override
  String get securityUnlockFingerprintAutoSubtitle => 'Fingerprint unlock starts automatically. If needed, you can use your password below.';

  @override
  String get securityUnlockBiometricPatternAutoSubtitle => 'Native biometrics start automatically first. If needed, you can use your pattern below.';

  @override
  String get securityUnlockNativeSubtitle => 'Confirm access with native device authentication.';

  @override
  String securityUnlockPasswordSubtitle(String scopeName) {
    return 'Enter your password to open $scopeName.';
  }

  @override
  String securityUnlockPatternSubtitle(String scopeName) {
    return 'Draw your pattern to access $scopeName.';
  }

  @override
  String get securityUnlockBiometricSubtitle => 'Confirm your identity with native device authentication.';

  @override
  String get securityUnlockAppBiometricReason => 'Authenticate to unlock the app';

  @override
  String get securityUnlockPersonalBiometricReason => 'Authenticate to open Personal chats';

  @override
  String get securityUnlockPasswordMismatch => 'That password did not match. Try again.';

  @override
  String get securityUnlockPatternMismatch => 'That pattern did not match.';

  @override
  String get securityUnlockNativeIncomplete => 'Native authentication was not completed.';

  @override
  String get securityPasswordContinueHint => 'Enter your password to continue';

  @override
  String get securityUseFingerprint => 'Use fingerprint';

  @override
  String get securityUsePassword => 'Use password';

  @override
  String get securityClearPattern => 'Clear pattern';

  @override
  String get securityConnectFourDots => 'Connect at least 4 dots.';

  @override
  String get securityPasswordMinFourChars => 'Use at least 4 characters.';

  @override
  String get securityPasswordsMismatchFull => 'The passwords do not match.';

  @override
  String securityPasswordSetupTitle(String scopeName) {
    return 'Password for $scopeName';
  }

  @override
  String get securityPasswordSetupDescription => 'The password is stored only in the secure device store.';

  @override
  String get securityNewPassword => 'New password';

  @override
  String get securityRepeatPassword => 'Repeat password';

  @override
  String get securitySavePassword => 'Save password';

  @override
  String get securityPatternSetupInstruction => 'Draw a pattern with at least 4 dots.';

  @override
  String get securityPatternSetupRepeat => 'Repeat the pattern to confirm it.';

  @override
  String get securityPatternMinFourDots => 'Use at least 4 dots.';

  @override
  String get securityPatternMismatchStartOver => 'The patterns did not match. Start again.';

  @override
  String securityPatternSetupTitle(String scopeName) {
    return 'Pattern lock for $scopeName';
  }

  @override
  String get securityStartOver => 'Start over';

  @override
  String get securityTitle => 'Security';

  @override
  String get securityNativeAuthentication => 'Native authentication';

  @override
  String get securityReady => 'Ready';

  @override
  String get securityUnavailable => 'Unavailable';

  @override
  String get securityNativeAvailableDescription => 'Used for Face ID, fingerprint, and native device authentication.';

  @override
  String get securityNativeUnavailableDescription => 'Biometric or native device authentication is not available on this device right now.';

  @override
  String get securityAppLockTitle => 'App lock';

  @override
  String get securityAppLockDescription => 'Protects app entry and can relock after the app is hidden.';

  @override
  String get securityPersonalChatsTitle => 'Personal chats';

  @override
  String get securityPersonalChatsDescription => 'Protects the hidden Personal section and direct entry into personal chats.';

  @override
  String get securityAuthEnableAppLockReason => 'Authenticate to enable app lock';

  @override
  String get securityAuthChangeSettingsReason => 'Authenticate to change security settings';

  @override
  String get securityAuthProtectPersonalReason => 'Authenticate to protect Personal chats';

  @override
  String get securityAuthChangePersonalReason => 'Authenticate to change Personal chats protection';

  @override
  String get securityNativeUnavailableError => 'Native authentication is unavailable on this device.';

  @override
  String get securityBiometricCancelled => 'Biometric confirmation was cancelled.';

  @override
  String get securityProtectionMode => 'Protection mode';

  @override
  String get securityProtectionModeSubtitle => 'Choose how access should be protected.';

  @override
  String get securityProtectionModeDescription => 'Passwords and patterns are stored only as strong hashes in secure storage. Biometrics use the native system prompt.';

  @override
  String get securityProtectionOff => 'Off';

  @override
  String get securityProtectionOffDescription => 'Access without extra protection.';

  @override
  String get securityPasswordModeDescription => 'A dedicated password to unlock access.';

  @override
  String get securityPatternModeTitle => 'Pattern lock';

  @override
  String get securityPatternModeDescription => 'A dot pattern similar to Android lock patterns.';

  @override
  String get securityNativePromptDescription => 'The native Face ID, fingerprint, or system device authentication prompt.';

  @override
  String get securityRelockAfterHidden => 'Relock after the app is hidden';

  @override
  String get securityRelockAfterHiddenDescription => 'If disabled, protection only returns after a full app restart.';

  @override
  String get securityGracePeriod => 'Grace period before relock';

  @override
  String get securityGraceUnavailable => 'Unavailable while background relock is off.';

  @override
  String securityAllowQuickUnlockWith(String method) {
    return 'Allow quick unlock with $method';
  }

  @override
  String get securityQuickUnlockSubtitle => 'Keeps the password or pattern as the main fallback method.';

  @override
  String get securityChangePassword => 'Change password';

  @override
  String get securityChangePattern => 'Change pattern';

  @override
  String get securityChangeCredentialSubtitle => 'The current protection will be updated as soon as the new secret is confirmed.';

  @override
  String get securityProtectionActivated => 'Protection was activated immediately.';

  @override
  String get securityLockNow => 'Lock now';

  @override
  String get securitySaveChanges => 'Save changes';

  @override
  String get securityGraceImmediately => 'Immediately';

  @override
  String securityGraceAfterSeconds(int seconds) {
    return 'After ${seconds}s';
  }

  @override
  String securityGraceAfterMinutes(int minutes) {
    return 'After ${minutes}m';
  }

  @override
  String get securityStatusLocked => 'Locked';

  @override
  String get securityStatusUnlocked => 'Unlocked';

  @override
  String get securityAfterHide => 'After hide';

  @override
  String securityGracePill(int seconds) {
    return 'Grace ${seconds}s';
  }

  @override
  String get securityNoProtection => 'No protection';

  @override
  String get securityNativeBiometrics => 'Native biometrics';

  @override
  String get securityBiometricFaceFingerprint => 'Face ID / fingerprint';

  @override
  String get securityBiometricFingerprint => 'Fingerprint';

  @override
  String get securityBiometricNativeDeviceAuthentication => 'Native device authentication';

  @override
  String get devicesLinkOpenFailed => 'Could not open the link in a browser.';

  @override
  String get devicesDesktopDescriptionPrefix => 'You can sign in to the ';

  @override
  String get devicesDesktopAppLink => 'Secretly desktop app';

  @override
  String get devicesDesktopDescriptionSuffix => ' using a QR code.';

  @override
  String get devicesFailureTransportBlocked => 'Transport is blocked for the current server. Switch phone and desktop to the same server and retry.';

  @override
  String get devicesFailureIdentityNotServerBacked => 'Desktop identity is not server-backed yet. Retry in a few seconds.';

  @override
  String get devicesFailureProfileUnavailable => 'Desktop profile is not visible on the server yet. Keep the app open and retry.';

  @override
  String get devicesFailureDeviceUnavailable => 'Desktop device is not visible on the server yet. Keep the app open, refresh the QR, and retry.';

  @override
  String get devicesFailureCompanionRequired => 'Desktop companion access is not enabled for this profile. Activate it on the primary phone and retry.';

  @override
  String get devicesFailureCompanionLimit => 'Desktop companion limit is already in use for this profile. Remove an old desktop device or increase available seats.';

  @override
  String get devicesFailurePrimaryRequired => 'Create the main account on a phone first, then link desktop with QR.';

  @override
  String get devicesFailureInvalidQr => 'This QR is not a device authorization code.';

  @override
  String get devicesFailureQrExpired => 'QR code expired. Generate a new one on desktop.';

  @override
  String get devicesFailureServerMismatch => 'This QR belongs to a different server. Switch phone and desktop to the same server and retry.';

  @override
  String get devicesFailureProfileMismatch => 'Sync bundle targets a different profile. Generate a new QR and retry.';

  @override
  String get devicesFailureRequestNotFound => 'Desktop sync request was not found or already expired. Generate a new QR.';

  @override
  String get devicesFailureSessionExpired => 'QR session expired. Generate a new QR and retry.';

  @override
  String get devicesFailureSessionValidation => 'QR session validation failed. Generate a new QR and retry.';

  @override
  String get devicesFailureStateMismatch => 'Sync request state no longer matches. Generate a new QR and retry.';

  @override
  String get devicesFailureDeviceMismatch => 'Sync bundle targets a different device. Generate a new QR and retry.';

  @override
  String get devicesFailureDeclined => 'Sign-in was declined on the primary phone. Generate a new QR to retry.';

  @override
  String get devicesFailureInvalidPayload => 'Invalid desktop sync payload. Generate a new QR and retry.';

  @override
  String get devicesFailureInterrupted => 'Secure sync was interrupted before completion. Generate a new QR and retry.';

  @override
  String get devicesNewUser => 'New user';

  @override
  String get devicesNewUserDesktopConfirm => 'Clear local data and prepare this desktop device for QR sign-in from the primary phone?';

  @override
  String get devicesNewUserMobileConfirm => 'Clear current local profile and register a new user on this device?';

  @override
  String get devicesCreateAction => 'Create';

  @override
  String get devicesScanDeviceQr => 'Scan device QR';

  @override
  String get devicesRequestApproved => 'Request approved. Sync package sent to desktop.';

  @override
  String get devicesRequestDeclined => 'Request declined. Desktop remains unauthenticated.';

  @override
  String get devicesApproveSignInTitle => 'Approve sign-in on this device?';

  @override
  String get devicesConfirmSyncPrimary => 'Confirm sync from the primary device (phone).';

  @override
  String devicesApprovalDeviceOnly(String name) {
    return 'Device: $name. Approval is allowed from primary phone only.';
  }

  @override
  String get devicesSyncChats => 'Sync chats';

  @override
  String get devicesSyncSettings => 'Sync settings';

  @override
  String get devicesSyncMedia => 'Sync media';

  @override
  String get devicesDeclineSignIn => 'Decline sign-in';

  @override
  String get devicesApprove => 'Approve';

  @override
  String get devicesTitle => 'Devices';

  @override
  String get devicesConnectDevice => 'Connect device';

  @override
  String get devicesPrimaryDeviceTitle => 'This is the primary device';

  @override
  String get devicesPrimaryDeviceSubtitle => 'Permission for chat/settings/media sync is granted only here.';

  @override
  String get devicesQrSessionExpiredNewCode => 'QR session expired. Generate a new code.';

  @override
  String devicesQrExpiresIn(String time) {
    return 'QR expires in $time';
  }

  @override
  String get devicesWaitingQrScan => 'Waiting for QR scan on phone.';

  @override
  String get devicesQrScannedConfirm => 'QR scanned. Confirm sign-in on phone.';

  @override
  String get devicesApplyingSecureBundle => 'Applying secure sync bundle…';

  @override
  String get devicesAuthorizationFailed => 'Authorization failed. Please retry.';

  @override
  String get devicesUnauthenticatedChooseAction => 'You are not authenticated. Choose an action below.';

  @override
  String get devicesAuthenticated => 'Device is authenticated.';

  @override
  String get devicesDesktopWebAuthorization => 'Desktop/Web authorization';

  @override
  String get devicesDesktopModeDescription => 'Choose mode: register a new user or sign in via QR with phone approval.';

  @override
  String get devicesCancelQr => 'Cancel QR';

  @override
  String get devicesRefreshQr => 'Refresh QR';

  @override
  String get devicesSignInViaQr => 'Sign in via QR';

  @override
  String get devicesOpenPrimaryInstruction => 'Open Secretly on primary phone → Settings → Devices → Connect device.';

  @override
  String get storageSection => 'Storage';

  @override
  String get storageSectionSubtitle => 'Cache and downloads on this device';

  @override
  String get storageUsageTitle => 'Storage usage';

  @override
  String get storageCategoryMedia => 'Media cache';

  @override
  String get storageCategoryVoiceTranscripts => 'Voice transcripts';

  @override
  String get storageCategoryVoiceModel => 'Offline voice model';

  @override
  String get storageCategoryStickers => 'Stickers';

  @override
  String get storageCategoryEmoji => 'Animated emoji';

  @override
  String get storageCategoryProfileMedia => 'My gallery & avatars';

  @override
  String get storageCategoryRecents => 'Recent files';

  @override
  String get storageTotal => 'Total';

  @override
  String get storageCalculating => 'Calculating…';

  @override
  String get storageClearCache => 'Clear cache';

  @override
  String get storageClearCacheHint => 'Removes cached media, peer avatars and animated emoji. Your own gallery, stickers and chats are kept; media re-downloads when viewed.';

  @override
  String get storageClearing => 'Clearing cache…';

  @override
  String get storageClearedToast => 'Cache cleared';

  @override
  String get storageRemoveVoiceModel => 'Remove offline voice model (140 MB)';

  @override
  String get storageRemoveVoiceModelHint => 'Frees the on-device speech model. It re-downloads automatically the next time you transcribe a voice message.';

  @override
  String get storageRemoveVoiceModelConfirmTitle => 'Remove voice model?';

  @override
  String get storageRemoveVoiceModelConfirmBody => 'The 140 MB on-device speech model will be deleted. It re-downloads automatically the next time you transcribe a voice message.';

  @override
  String get storageRemoveVoiceModelConfirm => 'Remove';

  @override
  String get storageVoiceModelNotInstalled => 'No voice model is installed';

  @override
  String get storageVoiceModelRemovedToast => 'Voice model removed';

  @override
  String get backupStateProtected => 'Your history is protected';

  @override
  String get backupStateUnprotected => 'Your history is not protected';

  @override
  String get backupStateFailing => 'Backups are failing';

  @override
  String get backupStateStale => 'Backup is out of date';

  @override
  String get backupStateNone => 'No backup yet';

  @override
  String backupLastAt(Object time) {
    return 'Last backup: $time';
  }

  @override
  String get backupIntroHint => 'A backup lets you bring your chats to a new device';

  @override
  String get backupAccessUpgradeTitle => 'Save your backup again';

  @override
  String get backupAccessUpgradeBody => 'Your server backup was created in the older format: it can be downloaded by anyone who knows your profile ID. The contents stay encrypted with your password, but a second barrier does no harm. Saving it again adds a password check on the server itself.';

  @override
  String get backupAccessUpgradeAction => 'Save again';

  @override
  String get backupSectionAutomatic => 'Automatic';

  @override
  String get backupAutoToggle => 'Back up automatically';

  @override
  String get backupPassword => 'Password';

  @override
  String get backupPasswordSet => 'Set';

  @override
  String get backupPasswordNotSet => 'Not set';

  @override
  String get backupPasswordSaved => 'Password saved';

  @override
  String get backupWhere => 'Where';

  @override
  String get backupHowOften => 'How often';

  @override
  String get backupIncludeMedia => 'Include media';

  @override
  String get backupAutoFooter => 'The backup is encrypted with your password. Without it nothing can be restored — keep it somewhere safe. Media is never uploaded to the server.';

  @override
  String get backupNow => 'Back up now';

  @override
  String get backupSectionRestore => 'Restore';

  @override
  String get backupRestoreAction => 'Restore from a backup';

  @override
  String get backupRestoreFooter => 'Replaces the chats and settings on this device with the contents of the backup.';

  @override
  String get backupSectionKey => 'Secretly ID key';

  @override
  String get backupKeyShow => 'Show the key';

  @override
  String get backupKeyRestore => 'Restore with a key';

  @override
  String get backupKeyFooter => 'Restores your Secretly ID only — it carries no chats. Restoring with a key erases local data.';

  @override
  String get backupDestServerDevice => 'Server and device';

  @override
  String get backupDestServer => 'Server';

  @override
  String get backupDestDevice => 'Device';

  @override
  String get backupDestNone => 'Not set';

  @override
  String get backupDestServerOnly => 'Server only';

  @override
  String get backupDestDeviceOnly => 'Device only';

  @override
  String get backupTileOff => 'Off — your history is not protected';

  @override
  String get backupTilePending => 'On, but it has not run yet';

  @override
  String get backupTileFailing => 'Not running — needs attention';

  @override
  String get backupTileStale => 'Has not updated in a while';

  @override
  String get backupPasswordChange => 'Change password';

  @override
  String get backupPasswordRemove => 'Remove password';

  @override
  String get chatUndecryptablePending => 'A message arrived but can\'t be read yet — restoring the secure session…';

  @override
  String get liquidGlassTitle => 'Liquid glass';

  @override
  String get liquidGlassSubtitle => 'Refracting bars and islands. Turn off for the plain material — it uses less power and runs cooler.';

  @override
  String get billingPendingTitle => 'Waiting for payment';

  @override
  String get billingPendingBody => 'The order was created but payment is not confirmed yet. Finish paying with your chosen method — Premium will switch on by itself.';

  @override
  String get callsHideAddressTitle => 'Hide my address in calls';

  @override
  String get callsHideAddressSubtitle => 'Through our server: the other person will not see your IP address, but latency may increase';

  @override
  String get desktopJoinRoomByLink => 'Join by link';

  @override
  String get desktopJoinRoomLinkHint => 'Paste the invite link';

  @override
  String get desktopJoinRoomLinkInvalid => 'This is not a room invite link';

  @override
  String get desktopOfflineLockTitle => 'Ask for the password after a long offline spell';

  @override
  String get desktopOfflineLockDescription => 'If this computer has not reached the server for longer than this, it asks for the app password on start. A lost computer never receives a remote sign-out, but it does reach this limit.';

  @override
  String get desktopOfflineLockNever => 'Never';

  @override
  String get desktopOfflineLockDays7 => '7 days';

  @override
  String get desktopOfflineLockDays14 => '14 days';

  @override
  String get desktopOfflineLockDays30 => '30 days';

  @override
  String get desktopPollTitle => 'Poll';

  @override
  String get desktopPollAnonymous => 'Anonymous poll';

  @override
  String get desktopPollClosed => 'Closed';

  @override
  String desktopPollVoters(Object count) {
    return 'Voted: $count';
  }

  @override
  String get desktopPollMultipleHint => 'You can pick several';

  @override
  String get desktopPollCloseAction => 'Close the poll';

  @override
  String get desktopEventTitle => 'Event';

  @override
  String get desktopEventGoing => 'Going';

  @override
  String get desktopEventMaybe => 'Maybe';

  @override
  String get desktopEventNo => 'Not going';

  @override
  String get desktopPollNewTitle => 'New poll';

  @override
  String get desktopPollQuestionHint => 'Question';

  @override
  String desktopPollOptionHint(Object index) {
    return 'Option $index';
  }

  @override
  String get desktopPollAddOption => 'Add an option';

  @override
  String get desktopPollCreateAction => 'Create';

  @override
  String get desktopPollNeedTwo => 'A poll needs a question and at least two options';

  @override
  String get desktopPollMultipleLabel => 'Several answers';

  @override
  String get desktopPollAnonymousLabel => 'Anonymous';

  @override
  String get desktopEventNewTitle => 'New event';

  @override
  String get desktopEventTitleHint => 'Title';

  @override
  String get desktopEventDescriptionHint => 'Description';

  @override
  String get desktopEventLocationHint => 'Place';

  @override
  String get desktopEventPickWhen => 'Pick a date and time';

  @override
  String get desktopEventNeedTitleAndDate => 'An event needs a title and a date';

  @override
  String get desktopViewerOpenExternally => 'Open in another app';

  @override
  String get desktopViewerSaveAs => 'Save as…';

  @override
  String desktopViewerPage(Object page, Object total) {
    return 'Page $page of $total';
  }

  @override
  String get desktopViewerFailed => 'Could not show this file';

  @override
  String get desktopViewerTooLarge => 'This file is too large to show here';

  @override
  String get desktopSupportAttach => 'Attach a file';

  @override
  String desktopSupportAttachHint(Object limit) {
    return 'A screenshot or a log file — up to $limit. The attachment is encrypted together with the message.';
  }

  @override
  String desktopSupportTooLarge(Object limit) {
    return 'The file is larger than $limit — it cannot be sent';
  }

  @override
  String get desktopSupportUnreadable => 'Could not read the file';

  @override
  String get desktopSupportRemoveAttachment => 'Remove the attachment';

  @override
  String desktopSupportMegabytes(Object value) {
    return '$value MB';
  }

  @override
  String get desktopSupportYou => 'You';

  @override
  String get desktopSupportShrunk => 'The image was shrunk to fit';

  @override
  String get desktopStickerPackTitle => 'Sticker pack';

  @override
  String get desktopStickerPackAddPlain => 'Add the pack';

  @override
  String get desktopStickerPackInstalled => 'Installed';

  @override
  String get desktopStickerPackInstalling => 'Installing…';

  @override
  String get desktopStickerPackOwn => 'This is your own pack';

  @override
  String get desktopStickerPackNoAuthor => 'The pack\'s author is unknown — open the same sticker in a one-to-one chat';

  @override
  String desktopStickerPackInstallingProgress(Object done, Object total) {
    return 'Installing… $done/$total';
  }

  @override
  String desktopStickerPackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stickers',
      one: '$count sticker',
    );
    return '$_temp0';
  }

  @override
  String desktopStickerPackAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count stickers',
      one: 'Add $count sticker',
    );
    return '$_temp0';
  }

  @override
  String get desktopPairingTitle => 'Connect Secretly Desktop';

  @override
  String get desktopPairingHowTo => 'On your phone open Secretly → Settings → Devices → “Link a device” and scan this QR code.';

  @override
  String get desktopPairingPreparingQr => 'Preparing the QR…';

  @override
  String get desktopPairingQrUnavailable => 'QR unavailable';

  @override
  String get desktopPairingCodeExpired => 'The code expired — refreshing…';

  @override
  String desktopPairingCodeValidFor(Object time) {
    return 'The code is valid for another $time';
  }

  @override
  String get desktopPairingPrepareFailed => 'Could not prepare the code. Check your internet connection and try again.';

  @override
  String get desktopPairingRevoked => 'This device was removed from the account, so no code is created.\nConnect the desktop again — it will get a new device identity, and the old one stays revoked. Only a confirmation from the phone gives access to the conversations.';

  @override
  String get desktopPairingPreparingNew => 'Preparing a new connection…';

  @override
  String get desktopPairingConnectAsNew => 'Connect as a new device';

  @override
  String get desktopPairingIdentityResetFailed => 'Could not recreate the device identity. Restart the application and try again.';

  @override
  String get desktopPairingWaitingConfirm => 'Waiting for confirmation…';

  @override
  String get desktopPairingNewQr => 'Generate a new QR';

  @override
  String get desktopPairingCreatingRequest => 'Creating the request…';

  @override
  String get desktopPairingReadyToScan => 'Ready to scan';

  @override
  String get desktopPairingWaitingScan => 'Waiting for the scan on the phone…';

  @override
  String get desktopPairingScannedConfirmOnPhone => 'QR scanned — confirm on the phone.';

  @override
  String get desktopPairingFetchingProfile => 'Fetching the profile and keys…';

  @override
  String get desktopPairingConnectedLoading => 'Connected. Loading…';

  @override
  String get desktopPairingConnectionError => 'Connection error. Try again.';

  @override
  String get desktopMenuReaction => 'Reaction';

  @override
  String get desktopMenuContinueInTopic => 'Continue in a topic';

  @override
  String get desktopMenuCopySelection => 'Copy the selection';

  @override
  String get desktopMenuCopyText => 'Copy the text';

  @override
  String get desktopMenuCopyLink => 'Copy the link';

  @override
  String get desktopMenuTranslate => 'Translate';

  @override
  String get desktopMenuHideTranslation => 'Hide the translation';

  @override
  String get desktopMenuSelect => 'Select';

  @override
  String get desktopMenuPhotoOrVideo => 'Photo or video';

  @override
  String get desktopMenuContact => 'Contact';

  @override
  String get desktopMenuLocation => 'Location';

  @override
  String get desktopListPinned => 'PINNED';

  @override
  String get desktopListToday => 'TODAY';

  @override
  String get desktopListYesterday => 'YESTERDAY';

  @override
  String get desktopListThisWeek => 'THIS WEEK';

  @override
  String get desktopListEarlier => 'EARLIER';

  @override
  String get desktopListNothingFound => 'Nothing found';

  @override
  String get desktopListAddFavourite => 'Add to favourites';

  @override
  String get desktopListRemoveFavourite => 'Remove from favourites';

  @override
  String get desktopListMute => 'Mute';

  @override
  String get desktopListMarkRead => 'Mark as read';

  @override
  String get desktopListArchive => 'Archive';

  @override
  String get desktopListFolders => 'Folders';

  @override
  String get desktopListCreate => 'Create';

  @override
  String get desktopListTyping => 'typing';

  @override
  String get desktopListDraftPrefix => 'Draft: ';

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
}
