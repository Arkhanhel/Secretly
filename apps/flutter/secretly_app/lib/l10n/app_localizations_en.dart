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
  String get desktopRoomLimitTitle => 'Room limit reached';

  @override
  String desktopRoomLimitCreate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You can create up to $count rooms.',
      one: 'You can create up to $count room.',
    );
    return '$_temp0';
  }

  @override
  String desktopRoomLimitJoin(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You can be in at most $count rooms. To join a new one, leave one of your rooms first.',
      one: 'You can be in at most $count room. To join a new one, leave one of your rooms first.',
    );
    return '$_temp0';
  }

  @override
  String get desktopRoomLimitPremium => 'Premium raises this limit — the subscription is managed in the phone app.';

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
  String get desktopViewerPageFailed => 'Could not show this page';

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
  String desktopPairingHowTo(String settings, String devices, String button) {
    return 'On your phone open Secretly → $settings → $devices → “$button” and scan this QR code.';
  }

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

  @override
  String get desktopCallServerSilent => 'The server did not answer. Try again or leave the call.';

  @override
  String get desktopCallRoomMissing => 'The room is not available on the server — a call cannot be started in it.';

  @override
  String get desktopCallNoServer => 'No connection to the server. Check your connection.';

  @override
  String get desktopCallJoinFailed => 'Could not join the call. Check the connection and try again.';

  @override
  String desktopCallSharingScreen(Object name) {
    return '$name is sharing the screen';
  }

  @override
  String get desktopCallRoomEmpty => 'Nothing has been written in the room yet';

  @override
  String get desktopCallMessageHint => 'Message to the room…';

  @override
  String get desktopCallSendToRoom => 'Send to the room';

  @override
  String desktopCallParticipantsTab(Object count) {
    return 'Participants · $count';
  }

  @override
  String get desktopCallNotesTab => 'Notes';

  @override
  String get desktopCallLinkCopied => 'The link was copied';

  @override
  String get desktopCallFailed => 'It did not work';

  @override
  String desktopCallFailedWith(Object error) {
    return 'It did not work: $error';
  }

  @override
  String get desktopCallMicOn => 'Turn the microphone on';

  @override
  String get desktopCallMicOff => 'Turn the microphone off';

  @override
  String get desktopCallCamOn => 'Turn the camera on';

  @override
  String get desktopCallCamOff => 'Turn the camera off';

  @override
  String get desktopCallNoMediaVideo => 'The server gave no media channel — video is unavailable';

  @override
  String get desktopCallLayoutSingle => 'One';

  @override
  String get desktopCallLayoutGrid => 'Grid';

  @override
  String get desktopCallShowOneLarge => 'Show one person large';

  @override
  String get desktopCallShowGrid => 'Show everyone in a grid';

  @override
  String get desktopCallScreen => 'Screen';

  @override
  String get desktopCallShareStop => 'Stop sharing the screen';

  @override
  String get desktopCallShareStart => 'Share the screen';

  @override
  String get desktopCallNoMediaScreen => 'The server gave no media channel — screen sharing is unavailable';

  @override
  String get desktopCallLeave => 'Leave';

  @override
  String get desktopCallLeaveCall => 'Leave the call';

  @override
  String get desktopCallNoMediaBoth => 'The server gave no media channel: this call will have neither sound nor video';

  @override
  String get desktopCallDiscussion => 'Discussion';

  @override
  String desktopCallDiscussionOf(Object title) {
    return 'Discussion · $title';
  }

  @override
  String get desktopCallEncrypted => 'The call is end-to-end encrypted';

  @override
  String get desktopRoomCallTransportEncrypted => 'Encrypted in transit to our media server — not end-to-end yet';

  @override
  String desktopCallDurationOnAir(Object duration, Object count) {
    return '$duration · $count on air';
  }

  @override
  String get desktopCallExitFullScreen => 'Leave full screen';

  @override
  String get desktopCallFullScreen => 'Full screen';

  @override
  String get desktopCallDemoRoom => 'Demonstration room';

  @override
  String get desktopCallNoCallYet => 'No call yet';

  @override
  String get desktopCallDemoExplain => 'It lives only on this computer and does not exist on the server, so no call can be started in it. In a real room the button works.';

  @override
  String get desktopCallStartHint => 'Start — everyone else will see the invitation in the room';

  @override
  String get desktopCallVoiceOnly => 'Voice only';

  @override
  String get desktopCallWithCamera => 'With camera';

  @override
  String get desktopCallConnecting => 'Connecting…';

  @override
  String get desktopCallOngoing => 'A discussion is under way';

  @override
  String desktopCallOnAir(Object count) {
    return '$count on air';
  }

  @override
  String get desktopCallJoin => 'Join';

  @override
  String get desktopCallFullScreenShort => 'Full screen';

  @override
  String get desktopCallReconnecting => 'reconnecting';

  @override
  String get desktopCallCannotHear => 'cannot hear';

  @override
  String get desktopCallSharingShort => 'is sharing the screen';

  @override
  String get desktopCallCameraOn => 'camera is on';

  @override
  String get desktopCallPickDevice => 'Choose a device';

  @override
  String get desktopCallPreparingLink => 'Preparing the link…';

  @override
  String get desktopCallInvite => 'Invite';

  @override
  String desktopCallFps(Object fps) {
    return '$fps fps';
  }

  @override
  String get desktopSettingsTitle => 'Settings';

  @override
  String get desktopSettingsGroupApp => 'Application';

  @override
  String get desktopSettingsGroupPrivacy => 'Privacy and security';

  @override
  String get desktopSettingsGroupAccount => 'Account and data';

  @override
  String get desktopSettingsGeneralLabel => 'General';

  @override
  String get desktopSettingsGeneralSubtitle => 'Language, how the app behaves';

  @override
  String get desktopSettingsGeneralKeywords => 'language, locale, enter, sending, input';

  @override
  String get desktopSettingsAppearanceLabel => 'Appearance';

  @override
  String get desktopSettingsAppearanceSubtitle => 'Theme, accent, chat wallpaper';

  @override
  String get desktopSettingsAppearanceKeywords => 'theme, accent, wallpaper, background, bubbles, colour, dark, ticks, animation';

  @override
  String get desktopSettingsShortcutsLabel => 'Keyboard shortcuts';

  @override
  String get desktopSettingsShortcutsSubtitle => 'What to press to go faster';

  @override
  String get desktopSettingsShortcutsKeywords => 'keys, shortcuts, fast, cmd, ctrl';

  @override
  String get desktopSettingsPowerLabel => 'Power use';

  @override
  String get desktopSettingsPowerSubtitle => 'What drains the battery';

  @override
  String get desktopSettingsPowerKeywords => 'battery, animation, frames, glass, panels, performance, heat';

  @override
  String get desktopSettingsNotificationsLabel => 'Notifications';

  @override
  String get desktopSettingsNotificationsSubtitle => 'Sounds, previews, quiet';

  @override
  String get desktopSettingsNotificationsKeywords => 'sound, preview, quiet, do not disturb, banner, text';

  @override
  String get desktopSettingsCallsLabel => 'Calls';

  @override
  String get desktopSettingsCallsSubtitle => 'Receiving calls and screen sharing';

  @override
  String get desktopSettingsCallsKeywords => 'calls, incoming, screen sharing, screen, video, audio';

  @override
  String get desktopSettingsMediaLabel => 'Sound and video';

  @override
  String get desktopSettingsMediaSubtitle => 'Camera and microphone for calls';

  @override
  String get desktopSettingsMediaKeywords => 'camera, microphone, device, webcam, headset, headphones, sound, video';

  @override
  String get desktopSettingsPrivacyLabel => 'Privacy';

  @override
  String get desktopSettingsPrivacySubtitle => 'Who sees what about you';

  @override
  String get desktopSettingsPrivacyKeywords => 'who sees, last seen, photo, calls, messages, forwarding, nickname, search, strangers, delete account';

  @override
  String get desktopSettingsSecurityLabel => 'Security';

  @override
  String get desktopSettingsSecuritySubtitle => 'Encryption and verified devices';

  @override
  String get desktopSettingsSecurityKeywords => 'encryption, e2ee, verified, unverified, lock, password, touch id, verification';

  @override
  String get desktopSettingsBackupLabel => 'Backup';

  @override
  String get desktopSettingsBackupSubtitle => 'What will save your conversation history';

  @override
  String get desktopSettingsBackupKeywords => 'backup, copy, restore, safe backup, backup password, media';

  @override
  String get desktopSettingsBlockedLabel => 'Blocked';

  @override
  String get desktopSettingsBlockedSubtitle => 'Who is shut out from you';

  @override
  String get desktopSettingsBlockedKeywords => 'block, blocked, unblock, blacklist, spam';

  @override
  String get desktopSettingsDevicesLabel => 'Sessions and devices';

  @override
  String get desktopSettingsDevicesSubtitle => 'Active sessions';

  @override
  String get desktopSettingsDevicesKeywords => 'devices, sessions, qr, linking, sign out, backup';

  @override
  String get desktopSettingsAccountLabel => 'Account';

  @override
  String get desktopSettingsAccountSubtitle => 'Profile and signing out';

  @override
  String get desktopSettingsAccountKeywords => 'name, about, id, sign out, reset';

  @override
  String get desktopSettingsStorageLabel => 'Storage';

  @override
  String get desktopSettingsStorageSubtitle => 'Cache, downloads';

  @override
  String get desktopSettingsStorageKeywords => 'cache, space, clear, media, downloads';

  @override
  String get desktopSettingsSupportLabel => 'Support';

  @override
  String get desktopSettingsSupportSubtitle => 'An encrypted conversation with us';

  @override
  String get desktopSettingsSupportKeywords => 'support, help, problem, bug, write';

  @override
  String get desktopSettingsAboutLabel => 'About';

  @override
  String get desktopSettingsAboutKeywords => 'version, build, licences, website';

  @override
  String get desktopSettingsDangerLabel => 'Delete the account';

  @override
  String get desktopSettingsEndCallFirst => 'End the active call first.';

  @override
  String get desktopSettingsSignOutTitle => 'Sign out of the account on this computer?';

  @override
  String get desktopSettingsSignOutBody => 'The conversations, keys and cache will be removed from this computer. The account and the history on the phone are untouched — the desktop can be linked again with a QR code.';

  @override
  String get desktopSettingsSignOut => 'Sign out';

  @override
  String desktopSettingsSignOutFailed(Object error) {
    return 'Could not sign out: $error';
  }

  @override
  String get desktopSettingsActive => 'active';

  @override
  String get desktopGeneralSystemLanguage => 'System';

  @override
  String get desktopGeneralInterfaceLanguage => 'Interface language';

  @override
  String get desktopGeneralAppliesAtOnce => 'Applies straight away';

  @override
  String get desktopGeneralBehaviour => 'Behaviour';

  @override
  String get desktopGeneralEnterSends => 'Enter sends the message';

  @override
  String get desktopGeneralShiftEnterNewline => 'Shift+Enter starts a new line';

  @override
  String get desktopGeneralEnterNewline => 'Enter starts a new line, Shift+Enter sends';

  @override
  String get desktopGeneralHoverMenu => 'Menu when hovering over a message';

  @override
  String get desktopGeneralHoverMenuOn => 'Reactions and actions appear above the message';

  @override
  String get desktopGeneralHoverMenuOff => 'Actions are on the right mouse button';

  @override
  String get desktopGeneralLinkPreviews => 'Link previews';

  @override
  String get desktopGeneralLinkPreviewsOn => 'The link card is sent together with the message';

  @override
  String get desktopGeneralLinkPreviewsOff => 'Links are sent without a card and no page is opened';

  @override
  String get desktopGeneralDoubleClickReply => 'Double-click to reply';

  @override
  String get desktopGeneralDoubleClickReplyHint => 'Double-click a message to reply to it. On text, it selects a word';

  @override
  String get desktopPowerAnimations => 'Animations';

  @override
  String get desktopPowerAnimationsHint => 'Everything is on by default. Switch off from the top down if the laptop gets hot or the battery drains.';

  @override
  String get desktopPowerFramesTitle => 'Animated frames and statuses';

  @override
  String get desktopPowerFramesHint => 'Live avatar frames and emoji statuses on other people. The most expensive of the three — switch this off first.';

  @override
  String get desktopPowerGlassBubbles => 'Glass bubbles';

  @override
  String get desktopPowerGlassBubblesHint => 'Blur behind incoming messages';

  @override
  String get desktopPowerMattePanels => 'Matte panels';

  @override
  String get desktopPowerMattePanelsHint => 'Blur on panels and popups';

  @override
  String get desktopPowerNotAffectedTitle => 'What this does not affect';

  @override
  String get desktopPowerNotAffectedHint => 'Message delivery, encryption and notifications work the same whatever you choose. These settings only affect drawing.';

  @override
  String get desktopNotifHidden => 'Hidden';

  @override
  String get desktopNotifSenderOnly => 'Sender only';

  @override
  String get desktopNotifSenderAndText => 'Sender and text';

  @override
  String get desktopNotifUnavailableHere => 'Not available on this platform.';

  @override
  String get desktopNotifShowPreview => 'Show a preview of the message';

  @override
  String get desktopNotifInSystem => 'In notifications and pop-ups';

  @override
  String get desktopNotifDirectChats => 'One-to-one chats';

  @override
  String get desktopNotifDirectChatsHint => 'Notifications about one-to-one messages';

  @override
  String get desktopNotifRooms => 'Rooms';

  @override
  String get desktopNotifRoomsHint => 'Notifications about messages in rooms';

  @override
  String get desktopNotifSound => 'Sound';

  @override
  String get desktopNotifWhileFocused => 'While the window is open';

  @override
  String get desktopNotifWhileFocusedHint => 'Notify about messages in other chats too. Never about the open chat';

  @override
  String get desktopNotifOwnWindows => 'Notifications like in Telegram';

  @override
  String get desktopNotifOwnWindowsHint => 'Own pop-ups in the corner of the screen: they don\'t take focus and wait while the mouse is over them. Off — Windows system notifications.';

  @override
  String get desktopNotifDnd => 'Do not disturb';

  @override
  String get desktopNotifDndHint => 'Switch off every notification';

  @override
  String get desktopWallpaperNavy => 'Midnight blue';

  @override
  String get desktopWallpaperGraphite => 'Graphite';

  @override
  String get desktopWallpaperTeal => 'Teal';

  @override
  String get desktopWallpaperPlum => 'Plum';

  @override
  String get desktopWallpaperWine => 'Wine';

  @override
  String get desktopWallpaperMint => 'Mint';

  @override
  String get desktopWallpaperLavender => 'Lavender';

  @override
  String get desktopWallpaperSunset => 'Sunset';

  @override
  String get desktopWallpaperPeach => 'Peach';

  @override
  String get desktopWallpaperSky => 'Sky';

  @override
  String get desktopWallpaperMidnight => 'Midnight';

  @override
  String get desktopAppearanceHint => 'The scheme of this window. The phone has its own — this setting does not travel anywhere.';

  @override
  String get desktopAppearanceScheme => 'Scheme';

  @override
  String get desktopAppearanceDark => 'Dark';

  @override
  String get desktopAppearanceLight => 'Light';

  @override
  String get desktopAppearanceAccent => 'Interface accent';

  @override
  String get desktopAppearanceAccentHint => 'Buttons, your own bubbles and selections across the application.';

  @override
  String get desktopAppearanceWallpaper => 'Chat wallpaper';

  @override
  String get desktopAppearanceWallPulse => 'The wallpaper carries the message';

  @override
  String get desktopAppearanceWallPulseHint => 'A wave of light runs along the pattern: upwards when you send, downwards when you receive.';

  @override
  String get desktopAppearanceBubbleStyle => 'Message bubble style';

  @override
  String get desktopAppearanceBubbleStyleHint => 'The colour of your outgoing messages in every chat.';

  @override
  String get desktopAppearanceSenderColour => 'Sender name colour';

  @override
  String get desktopAppearanceSenderColourHint => 'The colour of the other person’s nickname in group chats.';

  @override
  String get desktopAppearanceIndicatorColour => 'Indicator colour';

  @override
  String get desktopAppearanceTabTheme => 'Theme & text';

  @override
  String get desktopAppearanceTabWallpaper => 'Chat background';

  @override
  String get desktopAppearanceTabMessages => 'Messages';

  @override
  String get desktopAppearanceReset => 'Defaults';

  @override
  String get desktopAppearanceResetDone => 'Appearance is back to defaults';

  @override
  String get desktopAppearanceResetUndo => 'Undo';

  @override
  String get desktopAppearanceAutosave => 'Saved automatically';

  @override
  String get desktopAppearancePremiumOnly => 'This is part of Premium — the subscription is managed in the phone app';

  @override
  String get desktopAppearancePresets => 'Ready-made sets';

  @override
  String get desktopAppearancePresetsHint => 'Accent, wallpaper, bubbles and indicators in one click';

  @override
  String get desktopAppearancePresetClassic => 'Classic';

  @override
  String get desktopAppearancePresetOcean => 'Ocean';

  @override
  String get desktopAppearancePresetSunset => 'Sunset';

  @override
  String get desktopAppearancePresetForest => 'Forest';

  @override
  String get desktopAppearancePresetNight => 'Night';

  @override
  String get desktopAppearanceSystem => 'System';

  @override
  String get desktopAppearanceDensity => 'Message density';

  @override
  String get desktopAppearanceDensityCozy => 'Cozy';

  @override
  String get desktopAppearanceDensityCompact => 'Compact';

  @override
  String get desktopAppearanceWallpaperAllChats => 'Background for all chats. Live ones shimmer softly';

  @override
  String get desktopAppearanceStatic => 'Static';

  @override
  String get desktopAppearanceLive => 'Live';

  @override
  String get desktopAppearanceLiveBadge => 'LIVE';

  @override
  String get desktopAppearanceDim => 'Dimming';

  @override
  String get desktopAppearanceAnimPattern => 'Pattern animation';

  @override
  String get desktopAppearanceLiveOnlyBadge => 'live wallpaper only';

  @override
  String get desktopWallAnimShortContinuous => 'Always';

  @override
  String get desktopWallAnimShortOnEnter => 'On open';

  @override
  String get desktopWallAnimShortTap => 'On click';

  @override
  String get desktopWallAnimShortOff => 'Off';

  @override
  String desktopAppearanceGoLive(Object link) {
    return 'Choose $link to set up the animation.';
  }

  @override
  String get desktopAppearanceGoLiveLink => 'live wallpaper';

  @override
  String get desktopAppearanceShape => 'Shape';

  @override
  String get desktopAppearanceShapeSharp => 'Sharp';

  @override
  String get desktopAppearanceShapeMedium => 'Medium';

  @override
  String get desktopAppearanceShapeRound => 'Round';

  @override
  String get desktopAppearanceNamesMulti => 'Multicolor';

  @override
  String get desktopAppearanceIndicatorHint => 'Read ticks in the chat list, links and text selection';

  @override
  String get desktopAppearanceSummaryPrefix => 'Now:';

  @override
  String get desktopAppearanceSummaryDark => 'dark scheme';

  @override
  String get desktopAppearanceSummaryLight => 'light scheme';

  @override
  String get desktopAppearanceSummarySystem => 'system scheme';

  @override
  String desktopAppearanceSummaryBubbles(Object name) {
    return 'bubbles “$name”';
  }

  @override
  String desktopAppearanceSummaryText(Object size) {
    return 'text $size';
  }

  @override
  String get desktopAppearancePreview => 'Preview';

  @override
  String get desktopAppearancePreviewReplay => 'Reopen';

  @override
  String get desktopAppearancePreviewReplayHint => 'Reopen the chat to see the animation';

  @override
  String get desktopAppearancePreviewIncoming => 'Incoming';

  @override
  String get desktopAppearancePreviewIncomingHint => 'Receive a message';

  @override
  String get desktopAppearancePreviewChat => 'Design team';

  @override
  String get desktopAppearancePreviewMembers => '5 members, 3 online';

  @override
  String desktopAppearancePreviewTyping(Object name) {
    return '$name is typing…';
  }

  @override
  String get desktopAppearancePreviewAnna => 'Anna';

  @override
  String get desktopAppearancePreviewMax => 'Max';

  @override
  String get desktopAppearancePreviewLiza => 'Lisa';

  @override
  String get desktopAppearancePreviewMsg1 => 'Updated the wallpaper in our chat — take a look';

  @override
  String get desktopAppearancePreviewMsg2 => 'The live ones are great. Especially the wave when you write';

  @override
  String get desktopAppearancePreviewMsg3 => 'I’ll try setting the same ones';

  @override
  String get desktopAppearancePreviewMsg4 => 'Can the text size be changed too?';

  @override
  String get desktopAppearancePreviewMsg5 => 'Yes, in Appearance. More at www.secretlyapp.com';

  @override
  String get desktopAppearancePreviewOwnDefault => 'Checking how the new settings look';

  @override
  String get desktopAppearancePreviewReply1 => 'Looks great!';

  @override
  String get desktopAppearancePreviewReply2 => 'Oh, that’s much better';

  @override
  String get desktopAppearancePreviewReply3 => 'Tell me later which wallpaper you picked';

  @override
  String get desktopAppearancePreviewReply4 => 'That bubble color suits you';

  @override
  String get desktopAppearancePreviewReply5 => 'I’m setting the same ones';

  @override
  String get desktopBackupEvery6h => 'Every 6 hours';

  @override
  String get desktopBackupEvery12h => 'Every 12 hours';

  @override
  String get desktopBackupDaily => 'Once a day';

  @override
  String get desktopBackupWeekly => 'Once a week';

  @override
  String get desktopBackupOffWarning => 'Automatic backup is off — there will be nothing to restore the history from';

  @override
  String get desktopBackupNeverRan => 'On, but it has never run yet';

  @override
  String desktopBackupLastFailedWith(Object error) {
    return 'The last backup failed: $error';
  }

  @override
  String get desktopBackupLastFailed => 'The last backup failed';

  @override
  String get desktopBackupStale => 'The backup has not been updated for a while';

  @override
  String get desktopBackupFresh => 'The backup is up to date';

  @override
  String get desktopBackupState => 'State';

  @override
  String get desktopBackupAutomatic => 'Automatic backup';

  @override
  String get desktopBackupAutomaticHint => 'The backup is encrypted with your password. Without it neither we nor anyone else can restore it — so the password has to be remembered.';

  @override
  String get desktopBackupCreateAuto => 'Create automatically';

  @override
  String get desktopBackupUploadServer => 'Upload to the server';

  @override
  String get desktopBackupUploadServerHint => 'Available from any device';

  @override
  String get desktopBackupKeepLocal => 'Keep on this computer';

  @override
  String get desktopBackupKeepLocalHint => 'Does not depend on the network';

  @override
  String get desktopBackupIncludeMedia => 'Include media';

  @override
  String get desktopBackupIncludeMediaHint => 'The backup will get noticeably bigger';

  @override
  String get desktopBackupFrequency => 'Frequency';

  @override
  String get desktopBackupNowhereTitle => 'The backup is saved nowhere';

  @override
  String get desktopBackupNowhereHint => 'Automatic backup is on but both destinations are off, which means no backup is made. Switch on the server or this computer.';

  @override
  String get desktopBackupRecoveryKey => 'Recovery kit';

  @override
  String get desktopBackupCreateRecoveryKey => 'Create a recovery kit';

  @override
  String get desktopBackupRecoveryKeyHint => 'You will need it if no device with Secretly is left. Keep it separately from the password.';

  @override
  String desktopBackupKeyFailed(Object error) {
    return 'Could not create the key: $error';
  }

  @override
  String get desktopBackupKeyPassword => 'Password for the recovery kit';

  @override
  String get desktopBackupPasswordsDiffer => 'The passwords do not match.';

  @override
  String get desktopBackupKeyPasswordHint => 'This password encrypts the kit itself. It does not replace the application password and is stored nowhere — it cannot be recovered.';

  @override
  String get desktopBackupPasswordAgain => 'Again';

  @override
  String desktopUnblockTitle(Object name) {
    return 'Unblock $name?';
  }

  @override
  String get desktopUnblockBody => 'This person will be able to write to you and call you again.';

  @override
  String get desktopUnblockAction => 'Unblock';

  @override
  String get desktopPrivacyLastSeen => 'Last seen';

  @override
  String get desktopPrivacyProfilePhoto => 'Profile photos';

  @override
  String get desktopPrivacyForwarding => 'Message forwarding';

  @override
  String get desktopPrivacyCalls => 'Calls';

  @override
  String get desktopPrivacyVoice => 'Voice messages';

  @override
  String get desktopPrivacyMessages => 'Messages';

  @override
  String get desktopPrivacyNobody => 'Nobody';

  @override
  String get desktopPrivacyEverybody => 'Everybody';

  @override
  String get desktopPrivacyContacts => 'Contacts';

  @override
  String get desktopPrivacyEncryption => 'Encryption';

  @override
  String get desktopPrivacyEncryptionHint => 'Messages, files and one-to-one calls are end-to-end encrypted; the keys live only on your devices. Group calls are encrypted only in transit for now.';

  @override
  String get desktopPrivacyE2eeActive => 'End-to-end encryption is active';

  @override
  String get desktopPrivacyWhoSees => 'Who sees';

  @override
  String get desktopPrivacyWhoSeesHint => 'The same visibility settings as on your phone. “Contacts” is applied by the app; the server enforces only “Nobody”.';

  @override
  String get desktopPrivacyVisibility => 'Visibility';

  @override
  String get desktopPrivacyByNickname => 'Findable by nickname';

  @override
  String get desktopPrivacyByNicknameHint => 'Let people find you by your nickname';

  @override
  String get desktopPrivacySuggest => 'Suggest people in search';

  @override
  String get desktopPrivacyStrangers => 'New chats from strangers';

  @override
  String get desktopPrivacyStrangersHint => 'To the archive and without notifications';

  @override
  String get desktopPrivacyAutoDelete => 'Delete my account';

  @override
  String get desktopPrivacyAutoDeleteHint => 'If you don\'t sign in for longer than the chosen period, your account, keys, server backup and message queues are deleted from our servers. The countdown resets on each sign-in.';

  @override
  String get desktopPrivacyIfAbsent => 'If I do not sign in';

  @override
  String get desktopPrivacyIn1Month => 'After 1 month';

  @override
  String get desktopPrivacyIn3Months => 'After 3 months';

  @override
  String get desktopPrivacyIn6Months => 'After 6 months';

  @override
  String get desktopPrivacyIn1Year => 'After a year';

  @override
  String get desktopPrivacyIn2Years => 'After 2 years';

  @override
  String get desktopLockImmediately => 'As soon as focus is lost';

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
  String get desktopLockNoIdentityService => 'The identity-check service is unavailable — the lock was not switched on.';

  @override
  String get desktopLockNotConfirmed => 'The lock was not switched on: the confirmation did not pass.';

  @override
  String get desktopLockTitle => 'Application lock';

  @override
  String get desktopLockTouchIdHint => 'Ask for Touch ID to get back in after focus is lost.';

  @override
  String get desktopLockPasswordHint => 'Ask for the device password to get back in after focus is lost.';

  @override
  String get desktopLockEnableTouchId => 'Switch on Touch ID';

  @override
  String get desktopLockEnableLock => 'Switch on the lock';

  @override
  String get desktopLockDevicePassword => 'Device password';

  @override
  String get desktopLockAfter => 'Lock after';

  @override
  String get desktopLockNow => 'Lock now';

  @override
  String get desktopDevicesEndSessionTitle => 'End the session?';

  @override
  String desktopDevicesEndSessionBody(Object id) {
    return 'Device $id will be disconnected from your profile. Getting access back needs a new QR scan. Continue?';
  }

  @override
  String get desktopDevicesEnd => 'End';

  @override
  String desktopDevicesEndFailed(Object error) {
    return 'Could not end the session: $error';
  }

  @override
  String get desktopDevicesEnded => 'The device session has ended.';

  @override
  String get desktopDevicesActiveSessions => 'Active sessions';

  @override
  String get desktopDevicesDemoHint => 'Demo mode · real devices will appear once a profile is connected';

  @override
  String get desktopDevicesThisComputer => 'macOS · This computer';

  @override
  String get desktopDevicesDemoMac => 'MacBook Pro · Active now';

  @override
  String get desktopDevicesDemoIphone => 'iOS 18.2 · 2 hours ago (demo)';

  @override
  String get desktopDevicesDemoIpad => 'iPadOS 18 · yesterday (demo)';

  @override
  String get desktopDevicesThisDevice => 'This device';

  @override
  String get desktopDevicesRemoteDevice => 'Remote device';

  @override
  String get desktopDevicesDisconnect => 'Disconnect';

  @override
  String get desktopDevicesTitle => 'Devices';

  @override
  String desktopDevicesTitleCount(Object count) {
    return 'Devices · $count';
  }

  @override
  String get desktopDevicesHint => 'The devices linked to this profile on the key server.';

  @override
  String get desktopDevicesLoadFailed => 'Could not load';

  @override
  String get desktopDevicesRetry => 'Try again';

  @override
  String get desktopDevicesNone => 'No devices found';

  @override
  String get desktopDevicesNotLinked => 'The profile is not linked to the server yet.';

  @override
  String get desktopDevicesRefresh => 'Refresh the list';

  @override
  String get desktopAccentCustom => 'Custom colour';

  @override
  String get desktopPairTitle => 'Link a device';

  @override
  String get desktopPairHint => 'Show the QR code on the new device or scan it from the phone';

  @override
  String get desktopPairRequestFailed => 'Could not create the link request';

  @override
  String get desktopPairCodeCopied => 'The QR contents were copied';

  @override
  String get desktopPairNewTitle => 'Link a new device';

  @override
  String get desktopPairNewHint => 'On the new device open Secretly and choose “Connect by QR”. Then scan the code below.';

  @override
  String get desktopPairClose => 'Close';

  @override
  String get desktopPairCopyCode => 'Copy the code';

  @override
  String get desktopPairRefreshQr => 'Refresh the QR';

  @override
  String desktopSyncPulled(Object count) {
    return 'New events pulled: $count';
  }

  @override
  String get desktopSyncTooOften => 'Too many requests — try again later';

  @override
  String get desktopSyncNothingNew => 'Done · no new events';

  @override
  String get desktopSyncDemoUnavailable => 'Not available in demo mode';

  @override
  String desktopSyncBlobsPulled(Object blobs, Object convos) {
    return 'Attachments pulled: $blobs (chats: $convos)';
  }

  @override
  String desktopSyncNoBlobs(Object convos) {
    return 'Done · no new attachments (chats: $convos)';
  }

  @override
  String get desktopSyncTitle => 'History from other devices';

  @override
  String get desktopSyncHint => 'Ask the mobile device for the recent chat history. Used when the desktop has been offline for more than 7 days or has just been linked by QR.';

  @override
  String get desktopSyncRunning => 'Syncing…';

  @override
  String get desktopSyncAskHistory => 'Ask for the history';

  @override
  String get desktopSyncAsk => 'Ask';

  @override
  String get desktopSyncBlobsRunning => 'Downloading attachments…';

  @override
  String get desktopSyncBlobsAction => 'Fetch the attachments';

  @override
  String get desktopSyncBlobsHint => 'Downloads media from recent chats when the files are missing locally (after re-linking or a long time offline).';

  @override
  String get desktopSyncBlobsShort => 'Fetch';

  @override
  String desktopServerBackupOk(Object stamp, Object size, Object profile) {
    return 'Backup on the server ✓ · $stamp · $size KB · profile $profile';
  }

  @override
  String get desktopServerBackupPassword => 'Backup password';

  @override
  String get desktopServerBackupPasswordHint => 'This password encrypts the backup and restores it on any device. Remember it — without it the backup is useless, and it cannot be recovered.';

  @override
  String get desktopServerBackupRepeat => 'Repeat the password';

  @override
  String get desktopServerBackupCreate => 'Create the backup';

  @override
  String get desktopServerBackupTitle => 'Backup to the server';

  @override
  String get desktopServerBackupHint => 'An encrypted copy of the account on the Secretly server. It is restored on any device through “Restore from the server” with your Secretly ID and password.';

  @override
  String get desktopServerBackupLoading => 'Uploading…';

  @override
  String get desktopServerBackupCreateOnServer => 'Create a backup on the server';

  @override
  String get desktopServerBackupUpdate => 'Update the backup';

  @override
  String desktopFailedWith(Object error) {
    return 'It did not work: $error';
  }

  @override
  String get desktopStorageDeleteModelTitle => 'Delete the recognition model?';

  @override
  String get desktopStorageDeleteModelBody => 'Transcribing voice messages will stop working until the model is downloaded again.';

  @override
  String get desktopStorageModelDeleted => 'The model was deleted';

  @override
  String desktopStorageDeleteFailed(Object error) {
    return 'Could not delete: $error';
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
  String get desktopStorageUsage => 'Usage';

  @override
  String get desktopStorageUsageHint => 'Cache and media on this device';

  @override
  String desktopStorageClearHint(Object size) {
    return '$size will be freed. Messages, files you sent and the recent ones are not deleted — there would be nowhere to restore them from.';
  }

  @override
  String get desktopStorageClear => 'Clear the cache';

  @override
  String get desktopStorageCounting => 'Counting…';

  @override
  String get desktopStorageSpeechModel => 'Speech-recognition model';

  @override
  String get desktopStorageSpeechModelHint => 'Used to transcribe voice messages on this computer, without sending the audio anywhere. A normal cache clear does NOT remove it — it is large and downloaded separately.';

  @override
  String get desktopStorageDeleteModel => 'Delete the model';

  @override
  String desktopStorageMedia(Object size) {
    return 'Media · $size';
  }

  @override
  String desktopStorageVoice(Object size) {
    return 'Voice · $size';
  }

  @override
  String desktopStorageOther(Object size) {
    return 'Other · $size';
  }

  @override
  String get desktopStorageFree => 'Free';

  @override
  String desktopStorageTotal(Object size) {
    return 'Total · $size';
  }

  @override
  String desktopAboutVersion(Object version, Object build) {
    return 'Version $version · build $build';
  }

  @override
  String get desktopAboutTagline => 'An end-to-end encrypted messenger. No ads. Source code under AGPL-3.0.';

  @override
  String get desktopAboutLicences => 'Licences';

  @override
  String get desktopAboutWebsite => 'Website';

  @override
  String get desktopDangerTitle => 'Delete the account irreversibly?';

  @override
  String get desktopDangerBody => 'The profile, the keys, the local data and the message history will be deleted on this and other devices. There is no way back.';

  @override
  String get desktopDangerDeleting => 'Deleting the account…';

  @override
  String desktopDangerFailed(Object error) {
    return 'Could not delete the account: $error';
  }

  @override
  String get desktopDangerSection => 'Deleting the account';

  @override
  String get desktopDangerDemo => 'Demo mode · deleting is unavailable without a connected profile.';

  @override
  String get desktopDangerEnterId => 'Type your Secretly ID to confirm';

  @override
  String desktopDangerEnterIdExact(Object id) {
    return 'Type $id to confirm';
  }

  @override
  String get desktopDangerAction => 'Delete the account';

  @override
  String get desktopDangerIrreversible => 'This is irreversible. All your data, the message history and the keys will be deleted. There is no way back.';

  @override
  String get desktopSecurityE2ee => 'End-to-end encryption';

  @override
  String get desktopSecurityE2eeHint => 'Messages, files and one-to-one calls are encrypted on your device, and the keys never leave your devices. The server can\'t read the content but does see service data, such as who writes to whom and when. Group calls are encrypted only in transit for now.';

  @override
  String get desktopSecurityVerifiedDevices => 'Verified devices';

  @override
  String get desktopSecurityVerifiedHint => 'While this is on, messages are not sent to the other person’s unconfirmed devices. It guards against substitution, but a message may not arrive until they confirm a new device. One-to-one chats only: it does not apply to groups.';

  @override
  String get desktopSecurityOnlyVerified => 'Verified devices only';

  @override
  String get desktopSecurityBlocked => 'Unverified devices are blocked';

  @override
  String get desktopSecurityAllDevices => 'Messages go to all of the other person’s devices';

  @override
  String get desktopSecurityAppEntry => 'Entry to the application';

  @override
  String get desktopSecurityAppEntryHint => 'A password when Secretly opens and after the window has been hidden for more than a minute. It applies to this computer.';

  @override
  String get desktopSecurityPersonalScopeHint => 'A separate password for the “Personal” category. Without it, personal chats are open to anyone with access to an unlocked computer.';

  @override
  String get desktopCallsInApp => 'Calls in the application';

  @override
  String get desktopCallsInAppHint => 'Switch off to disable calls entirely';

  @override
  String get desktopCallsAccept => 'Accept incoming calls';

  @override
  String get desktopCallsAcceptHint => 'People will be able to call you';

  @override
  String get desktopCallsDisabledHint => 'Unavailable while calls are off';

  @override
  String get desktopCallsScreenShare => 'Screen sharing';

  @override
  String get desktopCallsScreenShareHint => 'Receiving someone else’s screen is a separate permission: what appears there may not be what you expected to see.';

  @override
  String get desktopCallsAcceptScreenShare => 'Accept screen sharing';

  @override
  String get desktopAccountIdCopied => 'The Secretly ID was copied';

  @override
  String get desktopAccountIdHint => 'This identifier is what you share so people can find you. It carries neither a phone number nor an email address.';

  @override
  String get desktopAccountCopy => 'Copy';

  @override
  String get desktopAccountProfile => 'Profile';

  @override
  String get desktopAccountProfileHint => 'Name, photo, status';

  @override
  String get desktopAccountOpenProfile => 'Open the profile page';

  @override
  String desktopScopePasswordFor(Object name) {
    return 'Password for “$name”';
  }

  @override
  String get desktopScopeMin4 => 'At least 4 characters';

  @override
  String get desktopScopeOn => 'Protection is on';

  @override
  String desktopScopeOnFailed(Object error) {
    return 'Could not switch on: $error';
  }

  @override
  String get desktopScopeOff => 'Protection is off';

  @override
  String desktopScopeOffFailed(Object error) {
    return 'Could not switch off: $error';
  }

  @override
  String get desktopScopePasswordsDiffer => 'The passwords do not match';

  @override
  String get desktopScopeTitle => 'Password protection';

  @override
  String get desktopScopeOnWithPassword => 'On — password';

  @override
  String get desktopScopeEnabled => 'On';

  @override
  String get desktopScopeDisabled => 'Off';

  @override
  String get desktopScopeChangePassword => 'Change the password';

  @override
  String get desktopScopeLockNow => 'Lock';

  @override
  String desktopBlockedUnblocked(Object name) {
    return '$name was unblocked';
  }

  @override
  String desktopBlockedUnblockFailed(Object error) {
    return 'Could not unblock: $error';
  }

  @override
  String get desktopBlockedTitle => 'Blocked';

  @override
  String get desktopBlockedEmptyHint => 'The list is empty. Blocking is done from a chat’s menu.';

  @override
  String get desktopBlockedHint => 'These people cannot write to you or call you.';

  @override
  String get desktopBlockedNone => 'Nobody is blocked';

  @override
  String get desktopSupportSent => 'The message was sent';

  @override
  String get desktopSupportSendFailed => 'Could not send. Check your connection.';

  @override
  String get desktopSupportUnavailable => 'Support is unavailable';

  @override
  String get desktopSupportUnavailableHint => 'The support service is switched off right now. Try later or write from the phone.';

  @override
  String get desktopSupportThread => 'The conversation with support';

  @override
  String get desktopSupportThreadHint => 'Messages are encrypted on your device. The server keeps only ciphertext — only support can read the conversation.';

  @override
  String get desktopSupportNoReplies => 'No replies yet. Describe the problem — the answer will arrive here.';

  @override
  String get desktopSupportWrite => 'Write to support';

  @override
  String get desktopSupportWriteHint => 'The build version and the device identifier are attached automatically — without them the problem is nearly impossible to reproduce.';

  @override
  String get desktopSupportDescribe => 'Describe what happened';

  @override
  String get desktopSupportSending => 'Sending…';

  @override
  String get desktopSupportSend => 'Send';

  @override
  String get desktopChatsEmptyHint => 'Start a conversation from the phone — chats sync to the desktop automatically';

  @override
  String get desktopChatsPickOne => 'Pick a chat on the left';

  @override
  String desktopChatsSendFailed(Object error) {
    return 'Could not send: $error';
  }

  @override
  String desktopChatsSendingTo(Object title) {
    return 'Sending to “$title”';
  }

  @override
  String get desktopChatsFilterAll => 'All';

  @override
  String get desktopChatsFilterUnread => 'Unread';

  @override
  String get desktopChatsFilterGroups => 'Groups';

  @override
  String get desktopChatsFilterArchive => 'Archive';

  @override
  String get desktopChatsFilterPersonal => 'Personal';

  @override
  String get desktopChatsRenameFolder => 'Rename the folder';

  @override
  String get desktopChatsDeleteFolder => 'Delete the folder';

  @override
  String desktopChatsRenameFailed(Object error) {
    return 'Could not rename: $error';
  }

  @override
  String desktopChatsDeleteFolderTitle(Object name) {
    return 'Delete the folder “$name”?';
  }

  @override
  String get desktopChatsDeleteFolderBody => 'The chats stay where they are — only the folder is deleted.';

  @override
  String desktopChatsDeleteFailed(Object error) {
    return 'Could not delete: $error';
  }

  @override
  String desktopChatsAddedToFolder(Object name) {
    return 'Added to “$name”';
  }

  @override
  String desktopChatsRemovedFromFolder(Object name) {
    return 'Removed from “$name”';
  }

  @override
  String desktopChatsFolderChangeFailed(Object error) {
    return 'Could not change the folder: $error';
  }

  @override
  String desktopChatsFolderCreated(Object name) {
    return 'The folder “$name” was created';
  }

  @override
  String desktopChatsFolderCreateFailed(Object error) {
    return 'Could not create the folder: $error';
  }

  @override
  String get desktopChatsNewFolder => 'New folder';

  @override
  String get desktopChatsFolderName => 'Folder name';

  @override
  String desktopChatsRemoveFromFolder(Object name) {
    return 'Remove from “$name”';
  }

  @override
  String desktopChatsAddToFolder(Object name) {
    return 'To the folder “$name”';
  }

  @override
  String get desktopChatsNewFolderWithChat => 'New folder with this chat…';

  @override
  String get desktopChatsRemoveFromPersonal => 'Remove from personal';

  @override
  String get desktopChatsAddToPersonal => 'To personal';

  @override
  String get desktopChatsArchiveEmpty => 'The archive is empty';

  @override
  String get desktopChatsNoPersonal => 'There are no personal chats';

  @override
  String get desktopChatsPersonalLocked => 'Personal chats are password-protected';

  @override
  String get desktopChatsAllRead => 'Everything is read';

  @override
  String get desktopChatsFolderEmpty => 'This folder is empty for now';

  @override
  String get desktopChatsNewChat => 'New chat';

  @override
  String get desktopChatsNewRoom => 'New room';

  @override
  String get desktopChatsStartFailed => 'Could not start the chat: the profile is unavailable';

  @override
  String get desktopChatsPhoto => 'Photo';

  @override
  String get desktopChatsVideo => 'Video';

  @override
  String get desktopChatsAudio => 'Audio';

  @override
  String get desktopChatsVoiceMessage => 'Voice message';

  @override
  String get desktopChatsVoiceShort => 'Voice';

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
    return '📊 Poll: $question';
  }

  @override
  String get desktopChatsUnknown => 'unknown';

  @override
  String get desktopChatsMember => 'Member';

  @override
  String get desktopChatsSoundOn => 'Switch the sound on';

  @override
  String get desktopChatsSoundOff => 'Muted';

  @override
  String get desktopMuteMenu => 'Mute…';

  @override
  String get desktopMuteFor1h => 'For 1 hour';

  @override
  String get desktopMuteFor8h => 'For 8 hours';

  @override
  String get desktopMuteFor2d => 'For 2 days';

  @override
  String get desktopMuteForever => 'Until I turn it back on';

  @override
  String get desktopMuteMentionsOnly => 'Mentions only';

  @override
  String get desktopChatsClearHistoryTitle => 'Clear the history?';

  @override
  String desktopChatsClearHistoryBody(Object title) {
    return 'Every message of the chat “$title” will be deleted on this device.';
  }

  @override
  String get desktopChatsClear => 'Clear';

  @override
  String get desktopChatsHistoryClearedBoth => 'The history was cleared for both';

  @override
  String get desktopChatsHistoryCleared => 'The history was cleared';

  @override
  String get desktopChatsDeleteChatTitle => 'Delete the chat?';

  @override
  String desktopChatsDeleteChatBody(Object title) {
    return 'The chat “$title” will be removed from this device entirely.';
  }

  @override
  String get desktopRoomDeleteLeaveMenu => 'Delete and leave';

  @override
  String desktopRoomDeleteLeaveTitle(String title) {
    return 'Delete and leave “$title”?';
  }

  @override
  String get desktopRoomDeleteLeaveBody => 'You will leave the room and stop receiving its messages, and the chat will be deleted from this computer. You can only come back with a new invite.';

  @override
  String get desktopRoomDeleteLeaveAction => 'Leave and delete';

  @override
  String get desktopChatsRooms => 'Rooms';

  @override
  String get desktopChatsGeneralTopic => 'General';

  @override
  String get desktopChatsNewTopicEllipsis => 'New topic…';

  @override
  String desktopChatsBranch(Object title) {
    return 'Branch “$title”';
  }

  @override
  String get desktopChatsRename => 'Rename';

  @override
  String get desktopChatsIcon => 'Icon';

  @override
  String get desktopChatsDeleteBranch => 'Delete the branch';

  @override
  String get desktopChatsBranchIcon => 'Branch icon';

  @override
  String get desktopChatsBranchIconHint => 'The icon replaces the hash before the name. Coloured ones promise what is inside: green a call, red something urgent. The rest are grey so they do not argue with the name.';

  @override
  String get desktopChatsHash => 'Hash';

  @override
  String desktopChatsBranchFailed(Object error) {
    return 'Could not change the branches: $error';
  }

  @override
  String get desktopChatsNewTopic => 'New topic';

  @override
  String get desktopChatsRenameTopic => 'Rename the topic';

  @override
  String get desktopChatsTopicName => 'Topic name';

  @override
  String desktopChatsReactionFailed(Object error) {
    return 'Could not save the reaction: $error';
  }

  @override
  String desktopChatsReactionLocal(Object error) {
    return 'The reaction was applied locally but not delivered to the other person: $error';
  }

  @override
  String get desktopChatsRevealFailed => 'Could not show the file in Finder';

  @override
  String desktopChatsVideoOpenFailed(Object error) {
    return 'Could not open the video: $error';
  }

  @override
  String get desktopChatsVideoUnavailable => 'The video is unavailable';

  @override
  String desktopChatsFileFetchFailed(Object error) {
    return 'Could not fetch the file: $error';
  }

  @override
  String get desktopChatsSaveAttachment => 'Save the attachment';

  @override
  String get desktopChatsFileUnavailable => 'The file is unavailable';

  @override
  String desktopChatsSaveFailed(Object error) {
    return 'Could not save: $error';
  }

  @override
  String desktopChatsOpenFailedWith(Object error) {
    return 'Could not open the file: $error';
  }

  @override
  String get desktopChatsOpenFailed => 'Could not open the file';

  @override
  String desktopChatsOpenFailedShort(Object error) {
    return 'Could not open: $error';
  }

  @override
  String get desktopFileRiskTitle => 'Open this file?';

  @override
  String desktopFileRiskExtension(Object ext) {
    return 'This file has the $ext extension and may run a program that harms your computer. Open it only if you trust the sender.';
  }

  @override
  String get desktopFileRiskNoExtension => 'This file has no extension, so your computer may run it as a program. Open it only if you trust the sender.';

  @override
  String desktopFileRiskMismatch(Object ext) {
    return 'The sender labeled this file as a picture, sound, video or PDF, but its real extension is $ext. Dangerous files are often disguised this way — open it only if you trust the sender.';
  }

  @override
  String get desktopFileRiskShowInFolder => 'Show in folder';

  @override
  String get desktopFileRiskOpenAnyway => 'Open anyway';

  @override
  String desktopChatsPlayFailed(Object error) {
    return 'Could not play: $error';
  }

  @override
  String get desktopChatsNoCallPeer => 'Could not work out who to call.';

  @override
  String get desktopChatsCallsNotReady => 'The call service is not ready.';

  @override
  String get desktopChatsCallInProgress => 'A call is already under way.';

  @override
  String get desktopChatsEditFailed => 'Could not edit the message.';

  @override
  String get desktopChatsNoRecipient => 'Could not work out the recipient.';

  @override
  String get desktopChatsDeleteMessageTitle => 'Delete the message?';

  @override
  String get desktopChatsDeleteMessagesTitle => 'Delete the selected messages?';

  @override
  String get desktopChatsDeleteOthersHint => 'Other people’s messages will be deleted only for you.';

  @override
  String get desktopChatsDeleteForAll => 'Delete for everyone';

  @override
  String get desktopChatsDeleteForMeOnly => 'Delete only for me';

  @override
  String get desktopChatsDeleteForMe => 'Delete for me';

  @override
  String get desktopChatsSavePrivacyBlocked => 'This message cannot be saved because of privacy restrictions.';

  @override
  String get desktopChatsNothingToSave => 'The attachment was not downloaded — there is nothing to save';

  @override
  String get desktopChatsSavedPartly => 'Saved to Favourites, but not all of it';

  @override
  String get desktopChatsSaved => 'Saved to Favourites';

  @override
  String get desktopChatsForwardPrivacyBlocked => 'This message cannot be forwarded because of privacy restrictions.';

  @override
  String desktopChatsForwardFailed(Object error) {
    return 'Could not forward: $error';
  }

  @override
  String get desktopChatsNothingToForward => 'The attachment was not downloaded — there is nothing to forward';

  @override
  String desktopChatsForwardedPartly(Object title) {
    return 'Forwarded to “$title”, but not all of it';
  }

  @override
  String desktopChatsForwarded(Object title) {
    return 'Forwarded to “$title”';
  }

  @override
  String desktopChatsFileNotSentElsewhere(Object text) {
    return 'The file was not sent to the other conversation: $text';
  }

  @override
  String get desktopChatsFileSendFailed => 'Could not send the file.';

  @override
  String desktopChatsPremiumFiles(Object text) {
    return '$text With Premium you can send files of up to 1 GB.';
  }

  @override
  String get desktopChatsTypingEllipsis => 'typing…';

  @override
  String get desktopChatsOnline => 'online';

  @override
  String desktopChatsSomeoneTyping(Object name) {
    return '$name is typing';
  }

  @override
  String get desktopChatsLoadingList => 'Pulling the list from local storage.';

  @override
  String get desktopChatsWillAppear => 'Messages and calls will appear here as soon as you open a chat.';

  @override
  String get desktopRoomNoOpenHere => 'A chat cannot be opened from here';

  @override
  String get desktopRoomIdCopied => 'The ID was copied';

  @override
  String get desktopRoomAwaiting => 'Awaiting approval';

  @override
  String get desktopRoomBlocked => 'Blocked';

  @override
  String get desktopRoomCopied => 'Copied';

  @override
  String get desktopRoomChangeRole => 'Change the role';

  @override
  String get desktopRoomTransfer => 'Transfer ownership';

  @override
  String get desktopRoomBlockMember => 'Block';

  @override
  String get desktopRoomKick => 'Remove';

  @override
  String get desktopRoomKickTitle => 'Remove the member?';

  @override
  String desktopRoomKickBody(Object name) {
    return '$name will lose access to the room. A new invitation brings them back.';
  }

  @override
  String get desktopRoomBlockTitle => 'Block the member?';

  @override
  String desktopRoomBlockBody(Object name) {
    return '$name will not be able to come back to the room even with an invitation until the block is lifted.';
  }

  @override
  String get desktopRoomTransferTitle => 'Transfer ownership of the room?';

  @override
  String desktopRoomTransferBody(Object name) {
    return '$name becomes the owner and you become an administrator. Only the new owner can undo it.';
  }

  @override
  String get desktopRoomTransferAction => 'Transfer';

  @override
  String get desktopRoomClearTitle => 'Clear the history?';

  @override
  String get desktopRoomClearBody => 'Every message of the room will be deleted on this device.';

  @override
  String get desktopRoomLeaveTitle => 'Leave the room?';

  @override
  String get desktopRoomLeaveBody => 'You will stop receiving messages. Coming back needs a new invitation.';

  @override
  String get desktopRoomLeave => 'Leave';

  @override
  String get desktopRoomInvite => 'Invite';

  @override
  String get desktopRoomCopyId => 'Copy the room ID';

  @override
  String get desktopRoomMuteOff => 'Switch notifications off';

  @override
  String get desktopRoomUnarchive => 'Bring back from the archive';

  @override
  String get desktopRoomLeaveRoom => 'Leave the room';

  @override
  String get desktopRoomUntitled => 'Untitled';

  @override
  String get desktopRoomCopyInvite => 'Copy the invitation';

  @override
  String get desktopRoomInviteCardTitle => 'Room invite';

  @override
  String get desktopRoomInviteCardHint => 'Open the card to review the room and join.';

  @override
  String get desktopRoomInviteAlreadyMember => 'You are already in the room';

  @override
  String get desktopRoomInviteApprovalRequired => 'Approval required';

  @override
  String get desktopRoomInviteDirectJoin => 'Direct join';

  @override
  String get desktopRoomInviteWithHistory => 'with history';

  @override
  String get desktopRoomInviteWithoutHistory => 'without history';

  @override
  String desktopRoomInviteInvitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String get desktopRoomInviteHistoryOn => 'History for new members is enabled';

  @override
  String get desktopRoomInviteHistoryOff => 'History for new members is disabled';

  @override
  String get desktopRoomInviteJoin => 'Join room';

  @override
  String get desktopRoomInviteRequestAccess => 'Request access';

  @override
  String get desktopRoomInviteOpenRequest => 'Open request';

  @override
  String get desktopRoomInviteOpenRoom => 'Open room';

  @override
  String desktopRoomInviteReplyQuote(String title) {
    return 'Invite to «$title»';
  }

  @override
  String get desktopRoomSound => 'Sound';

  @override
  String get desktopRoomTabInfo => 'Info';

  @override
  String get desktopRoomTabMembers => 'Members';

  @override
  String get desktopRoomTabMedia => 'Media';

  @override
  String get desktopRoomTopics => 'TOPICS';

  @override
  String desktopRoomTopicsCount(Object count) {
    return 'TOPICS · $count';
  }

  @override
  String get desktopRoomDescription => 'Description';

  @override
  String get desktopRoomNotes => 'NOTES';

  @override
  String get desktopRoomInformation => 'Information';

  @override
  String get desktopRoomId => 'Room ID';

  @override
  String get desktopRoomInviteLink => 'Invitation link · click to copy';

  @override
  String get desktopRoomFavouriteHint => 'A tile on the rail and a place at the top of the list';

  @override
  String get desktopRoomArchiveHint => 'Hide the room from the main list';

  @override
  String get desktopRoomNoMembers => 'No members';

  @override
  String desktopRoomMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String get desktopRoomNobodyFound => 'Nobody found';

  @override
  String get desktopRoomMembersUnavailable => 'The member list is unavailable.';

  @override
  String get desktopRoomInCall => 'IN THE CALL';

  @override
  String get desktopRoomOnline => 'ONLINE';

  @override
  String get desktopRoomOffline => 'OFFLINE';

  @override
  String get desktopRoomShowAllMembers => 'Show all';

  @override
  String desktopRoomMoreHidden(Object count) {
    return '$count more — use the search above';
  }

  @override
  String get desktopRoomSearchMember => 'Search for a member';

  @override
  String get desktopRoomJoinRequests => 'Join requests';

  @override
  String get desktopRoomAccept => 'Accept';

  @override
  String get desktopRoomDecline => 'Decline';

  @override
  String get desktopRoomRoleOwner => 'Owner';

  @override
  String get desktopRoomRoleAdmin => 'Administrator';

  @override
  String get desktopRoomRoleModerator => 'Moderator';

  @override
  String get desktopRoomRoleRestricted => 'Restricted';

  @override
  String get desktopRoomRoleGuest => 'Guest';

  @override
  String get desktopContactBlockTitle => 'Block?';

  @override
  String get desktopContactUnblockTitle => 'Unblock?';

  @override
  String get desktopContactBlockBody => 'This person will no longer be able to send you messages or call you.';

  @override
  String get desktopContactUnblockBody => 'This person will be able to reach you again.';

  @override
  String get desktopContactBlock => 'Block';

  @override
  String get desktopContactCallsNotReady => 'The call service is not ready yet';

  @override
  String get desktopContactCallInProgress => 'A call is already under way';

  @override
  String desktopContactCallFailed(Object error) {
    return 'Could not start the call: $error';
  }

  @override
  String get desktopContactAutoDelete => 'Automatic message deletion';

  @override
  String get desktopContactAutoDeleteUpdated => 'Automatic deletion was updated';

  @override
  String get desktopContactClearBody => 'Every message of this chat will be deleted on this device.';

  @override
  String get desktopContactDeleteBody => 'The chat will be removed from this device entirely.';

  @override
  String get desktopContactOff => 'Off';

  @override
  String get desktopContactDisable => 'Switch off';

  @override
  String get desktopContactDay1 => '1 day';

  @override
  String get desktopContactDays7 => '7 days';

  @override
  String get desktopContactDays30 => '30 days';

  @override
  String get desktopContactHour1 => '1 hour';

  @override
  String desktopContactMinutes(Object value) {
    return '$value min';
  }

  @override
  String get desktopContactOffline => 'offline';

  @override
  String desktopContactSeenAt(Object time) {
    return 'last seen at $time';
  }

  @override
  String get desktopContactSeenYesterday => 'last seen yesterday';

  @override
  String desktopContactSeenOn(Object date) {
    return 'last seen on $date';
  }

  @override
  String get desktopContactCopyId => 'Copy the ID';

  @override
  String get desktopContactCopyIdShort => 'Copy ID';

  @override
  String get desktopContactDisappearing => 'Auto-delete on my devices';

  @override
  String get desktopContactDeleteChat => 'Delete the chat';

  @override
  String get desktopContactCall => 'Call';

  @override
  String get desktopContactBlockShort => 'Block';

  @override
  String get desktopContactSecurity => 'Security';

  @override
  String get desktopContactVerify => 'Verify the contact';

  @override
  String get desktopContactArchiveHint => 'Hide the chat from the main list';

  @override
  String get desktopThreadMessageHint => 'Message…';

  @override
  String get desktopThreadPasteFailed => 'Could not paste the picture';

  @override
  String get desktopThreadNoScheduleEdit => 'An edit cannot be scheduled — it changes something already sent';

  @override
  String desktopThreadWillLeave(Object when) {
    return 'Will go out $when';
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
    return '$value d';
  }

  @override
  String desktopThreadWeeks(Object value) {
    return '$value w';
  }

  @override
  String desktopThreadSelected(Object count) {
    return 'Selected: $count';
  }

  @override
  String get desktopThreadDisappearingOn => 'Auto-delete is on — on my devices only';

  @override
  String get desktopThreadCallAction => 'Call';

  @override
  String get desktopThreadCallRoom => 'Group call';

  @override
  String get desktopThreadVideoCall => 'Video call';

  @override
  String get desktopThreadSearchShortcut => 'Search in the chat  Cmd F';

  @override
  String get desktopThreadHideDetails => 'Hide the details';

  @override
  String get desktopThreadShowDetails => 'Show the details';

  @override
  String get desktopThreadMore => 'More';

  @override
  String get desktopThreadPinned => 'Pinned message';

  @override
  String get desktopThreadNoMatches => 'no matches';

  @override
  String get desktopThreadSearchHint => 'Search in the chat…';

  @override
  String get desktopThreadPrevMatch => 'Previous (Shift F3)';

  @override
  String get desktopThreadNextMatch => 'Next (F3)';

  @override
  String get desktopThreadCloseEsc => 'Close (Esc)';

  @override
  String get desktopThreadNewMessages => 'New messages';

  @override
  String desktopThreadUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '$count unread',
    );
    return '$_temp0';
  }

  @override
  String get desktopThreadToday => 'Today';

  @override
  String get desktopThreadYesterday => 'Yesterday';

  @override
  String get desktopProfileEmojiStatus => 'Emoji status';

  @override
  String get desktopProfileClearStatus => 'Clear the status';

  @override
  String get desktopProfileEmojiStatusPremiumOnly => 'Emoji status is part of Premium; you can subscribe in the app on your phone';

  @override
  String desktopProfileApplyFailed(Object error) {
    return 'Could not apply: $error';
  }

  @override
  String get desktopProfileAvatarFrame => 'Avatar frame';

  @override
  String get desktopProfileCover => 'Profile cover';

  @override
  String get desktopProfileNoFrame => 'No frame';

  @override
  String get desktopProfileNoCover => 'No cover';

  @override
  String get desktopProfileReadFailed => 'Could not read the file';

  @override
  String get desktopProfilePhotoUpdated => 'The profile photo was updated';

  @override
  String desktopProfilePhotoFailed(Object error) {
    return 'Could not update the photo: $error';
  }

  @override
  String desktopProfilePhotoRemoveFailed(Object error) {
    return 'Could not remove the photo: $error';
  }

  @override
  String get desktopProfileMine => 'My profile';

  @override
  String get desktopProfileEdit => 'Edit';

  @override
  String get desktopProfileName => 'Name';

  @override
  String get desktopProfileChangePhoto => 'Change the photo';

  @override
  String get desktopProfileFrameShort => 'Frame';

  @override
  String get desktopProfileCoverShort => 'Cover';

  @override
  String get desktopProfileStatus => 'Status';

  @override
  String get desktopProfileAppearanceHint => 'Theme, accent and chat wallpaper';

  @override
  String get desktopProfileAbout => 'About me';

  @override
  String get desktopProfileEmpty => 'Not filled in';

  @override
  String get desktopProfilePhoto => 'Profile photo';

  @override
  String get desktopProfileReplacePhoto => 'Replace the photo';

  @override
  String get desktopProfilePickPhoto => 'Choose a photo';

  @override
  String get desktopProfilePickedHere => 'Chosen on this computer';

  @override
  String get desktopProfileSyncedWithPhone => 'Synced with the phone';

  @override
  String get desktopProfileNotPicked => 'Not chosen';

  @override
  String get desktopProfileRemovePhoto => 'Remove the photo';

  @override
  String get desktopProfileInitialsStay => 'The initials remain';

  @override
  String get desktopAvatarOpen => 'Open photo';

  @override
  String get desktopAvatarCropTitle => 'Crop photo';

  @override
  String get desktopAvatarCropHint => 'Drag the photo; use the mouse wheel to zoom';

  @override
  String get desktopAvatarRemoveConfirmTitle => 'Delete photo?';

  @override
  String get desktopAvatarRemoveConfirmBody => 'The initials will be shown instead of the photo.';

  @override
  String get desktopAvatarRemoveOnPhone => 'Delete on your phone';

  @override
  String get desktopRoomPhotoUpdated => 'Group photo updated';

  @override
  String get desktopRoomPhotoRemoved => 'Group photo removed';

  @override
  String desktopRoomPhotoFailed(String error) {
    return 'Could not change the group photo: $error';
  }

  @override
  String get desktopProfileAccount => 'Account';

  @override
  String get desktopProfileRecovery => 'Recovery';

  @override
  String get desktopProfileRecoveryHint => 'This computer is linked to the phone and keeps no recovery phrase of its own: the backup and the recovery kit bring the account back.';

  @override
  String get desktopProfileDevicesHint => 'Connected computers and phones';

  @override
  String get desktopProfileFrameCaps => 'AVATAR FRAME';

  @override
  String get desktopGalleryMedia => 'Media';

  @override
  String get desktopGalleryFiles => 'Files';

  @override
  String get desktopGalleryLinks => 'Links';

  @override
  String get desktopGalleryNoMedia => 'No media';

  @override
  String get desktopGalleryNoFiles => 'No files';

  @override
  String get desktopGalleryNoAudio => 'No audio';

  @override
  String get desktopGalleryLoadFailed => 'Couldn\'t load attachments';

  @override
  String get desktopGalleryRetry => 'Try again';

  @override
  String get desktopSendMediaDroppedOnSwitch => 'Files weren\'t sent — the send window closed when the chat changed.';

  @override
  String get desktopGalleryNoLinks => 'No links';

  @override
  String get desktopGalleryPathCopied => 'The path was copied';

  @override
  String get desktopGalleryOpen => 'Open';

  @override
  String get desktopGalleryView => 'View';

  @override
  String get desktopGalleryOpenInSystem => 'Open in the system';

  @override
  String get desktopGalleryRevealFinder => 'Show in Finder';

  @override
  String get desktopGalleryRevealExplorer => 'Show in Explorer';

  @override
  String get desktopGalleryOpenFolder => 'Open the folder';

  @override
  String get desktopGalleryCopyPath => 'Copy the path';

  @override
  String desktopGalleryBytes(Object value) {
    return '$value B';
  }

  @override
  String get desktopGalleryZeroBytes => '0 B';

  @override
  String desktopOutgoingFolderSingle(Object name) {
    return 'the folder “$name” cannot be sent';
  }

  @override
  String get desktopOutgoingFoldersMany => 'folders cannot be sent';

  @override
  String desktopOutgoingTooLargeOne(Object name, Object limit) {
    return '“$name” is larger than $limit MB';
  }

  @override
  String desktopOutgoingTooLargeMany(int count, Object limit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files are larger than $limit MB',
      one: '$count file is larger than $limit MB',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingEmptyOne(Object name) {
    return '“$name” is empty';
  }

  @override
  String desktopOutgoingEmptyMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files are empty',
      one: '$count file is empty',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingUnreadableOne(Object name) {
    return '“$name” could not be read';
  }

  @override
  String desktopOutgoingUnreadableMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files could not be read',
      one: '$count file could not be read',
    );
    return '$_temp0';
  }

  @override
  String get desktopOutgoingSending => 'Sending';

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
      other: '$count videos',
      one: '$count videos',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingMedia(Object count) {
    return '$count media items';
  }

  @override
  String desktopOutgoingAudios(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audio files',
      one: '$count audio files',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '$count files',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallsPickOne => 'Pick a call on the left';

  @override
  String get desktopCallsPickHint => 'The details and a call-back button will appear here';

  @override
  String get desktopCallsNone => 'No calls yet';

  @override
  String get desktopCallsNoneHint => 'The history appears after the first call';

  @override
  String get desktopCallsOutgoing => 'Outgoing';

  @override
  String get desktopCallsIncoming => 'Incoming';

  @override
  String get desktopCallsGroup => 'group';

  @override
  String get desktopCallsVideoKind => 'video';

  @override
  String get desktopCallsAudioKind => 'audio';

  @override
  String get desktopCallsMissed => 'missed';

  @override
  String desktopPhotoCopyFailed(Object error) {
    return 'Could not copy: $error';
  }

  @override
  String get desktopPhotoSave => 'Save the photo';

  @override
  String get desktopPhotoSaved => 'Saved';

  @override
  String desktopPhotoRevealFailed(Object error) {
    return 'Could not show in Finder: $error';
  }

  @override
  String get desktopPhotoLoadFailed => 'Could not load';

  @override
  String get desktopPhotoZoomOut => 'Zoom out';

  @override
  String get desktopPhotoZoomReset => 'Reset the zoom';

  @override
  String get desktopPhotoZoomIn => 'Zoom in';

  @override
  String get desktopPhotoCopy => 'Copy';

  @override
  String desktopBubbleForwardedFrom(Object from) {
    return 'Forwarded from $from';
  }

  @override
  String get desktopBubbleAudioFile => 'Audio file';

  @override
  String get desktopBubbleTranslating => 'Translating…';

  @override
  String get desktopBubbleTranslation => 'TRANSLATION';

  @override
  String get desktopBubbleEdited => 'edited';

  @override
  String get desktopBubbleMoreReactions => 'More reactions';

  @override
  String get desktopBubbleRoleOwner => 'owner';

  @override
  String get desktopBubbleRoleAdmin => 'admin';

  @override
  String get desktopBubbleRoleMod => 'mod';

  @override
  String get desktopBubbleSpeed => 'Playback speed';

  @override
  String get desktopSpotlightGoChats => 'Go to chats';

  @override
  String get desktopSpotlightGoRooms => 'Go to rooms';

  @override
  String get desktopSpotlightGoContacts => 'Go to contacts';

  @override
  String get desktopSpotlightGoCalls => 'Go to calls';

  @override
  String get desktopSpotlightSelect => 'select';

  @override
  String get desktopSpotlightOpen => 'open';

  @override
  String get desktopSpotlightClose => 'close';

  @override
  String get desktopSpotlightRoom => 'Room';

  @override
  String get desktopSpotlightMessage => 'Message';

  @override
  String get desktopSpotlightCommand => 'Command';

  @override
  String get desktopComposerCancelRec => 'Cancel the recording';

  @override
  String desktopComposerRecording(Object time) {
    return 'Recording  $time';
  }

  @override
  String get desktopComposerSendVoice => 'Send the voice message';

  @override
  String get desktopComposerAttach => 'Attach';

  @override
  String get desktopComposerEmoji => 'Emoji and stickers';

  @override
  String get desktopComposerRecordVoice => 'Record a voice message';

  @override
  String get desktopComposerVoiceUnsupported => 'Voice messages can’t be recorded on this computer.';

  @override
  String get desktopComposerEnterSends => 'Enter sends · Shift+Enter makes a new line';

  @override
  String get desktopComposerEnterNewline => 'Enter makes a new line · Shift+Enter sends';

  @override
  String get desktopComposerEditing => 'Editing';

  @override
  String desktopComposerReplyTo(Object name) {
    return 'Reply · $name';
  }

  @override
  String get desktopComposerCancelAction => 'Cancel';

  @override
  String get desktopComposerSendHint => 'Send · Enter\nRight click to send later';

  @override
  String get desktopComposerWriteFirst => 'Write a message first';

  @override
  String desktopComposerToTopic(Object title) {
    return 'to the topic “$title”';
  }

  @override
  String get desktopShortcutsNavigation => 'Navigation';

  @override
  String get desktopShortcutsTabs => 'Chats · Rooms · Calls · Contacts';

  @override
  String get desktopShortcutsSearchAll => 'Search chats and messages';

  @override
  String get desktopShortcutsPrevNext => 'Previous / next chat';

  @override
  String get desktopShortcutsInChat => 'In a conversation';

  @override
  String get desktopShortcutsFindHere => 'Find in this conversation';

  @override
  String get desktopShortcutsSend => 'Send (configurable)';

  @override
  String get desktopShortcutsNewline => 'New line';

  @override
  String get desktopShortcutsPaste => 'Paste an image from the clipboard';

  @override
  String get desktopShortcutsApp => 'Application';

  @override
  String get desktopShortcutsThisHelp => 'This help';

  @override
  String get desktopShortcutsCloseWindow => 'Close the window or the search';

  @override
  String get desktopShortcutsTray => 'Minimise to the tray';

  @override
  String get desktopShortcutsTitle => 'Keyboard shortcuts';

  @override
  String get desktopShortcutsUnread => 'Previous / next unread chat';

  @override
  String get desktopShortcutsFolders => 'Previous / next folder';

  @override
  String get desktopShortcutsMute => 'Mute / unmute the chat';

  @override
  String get desktopShortcutsCloseChat => 'Close the panel, then the chat';

  @override
  String get desktopChatMutedToast => 'Chat muted';

  @override
  String get desktopChatUnmutedToast => 'Chat unmuted';

  @override
  String get desktopChatsFolderReadAll => 'Mark all as read';

  @override
  String get desktopMediaCancelSend => 'Cancel the send';

  @override
  String get desktopMediaSending => 'Sending…';

  @override
  String desktopMediaSendingOf(Object total) {
    return 'Sending… · $total';
  }

  @override
  String get desktopMediaRetryDownload => 'Retry the download';

  @override
  String get desktopMediaImage => 'Image';

  @override
  String desktopMediaDownloading(Object size) {
    return 'Downloading… · $size';
  }

  @override
  String get desktopMediaDownload => 'Download';

  @override
  String get desktopSendAsMedia => 'Send as media';

  @override
  String get desktopSendAsFiles => 'Send as files';

  @override
  String get desktopSendUngroup => 'Do not group';

  @override
  String get desktopSendGroup => 'Group';

  @override
  String get desktopSendAddFiles => 'Add files…';

  @override
  String get desktopSendDropHere => 'Release to add';

  @override
  String get desktopSendCloseEsc => 'Close · Esc';

  @override
  String desktopSendToDestination(Object destination) {
    return 'to “$destination”';
  }

  @override
  String get desktopSendCaptionHint => 'Add a caption…';

  @override
  String get desktopSendEmoji => 'Emoji';

  @override
  String get desktopSendRemove => 'Remove';

  @override
  String get desktopSendEnter => 'Send · Enter';

  @override
  String get desktopSendShiftEnter => 'Send · Shift+Enter';

  @override
  String get desktopCallCtlShareStop => 'Stop the screen share';

  @override
  String get desktopCallCtlShare => 'Screen sharing';

  @override
  String desktopAbsenceDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String desktopAbsencePastFanout(Object days) {
    return 'This computer has been out of touch for $days. In that time senders stopped encrypting messages for it, and part of the history will not arrive here. It is intact on the phone — open the chats you need there and the recent history will follow.';
  }

  @override
  String desktopAbsenceWithinWindow(Object days) {
    return 'This computer has been out of touch for $days. Messages are kept on the server for a week, so some of them may not have survived for it. On the phone they are intact.';
  }

  @override
  String get desktopAbsenceGotIt => 'Got it';

  @override
  String get desktopNavContacts => 'Contacts';

  @override
  String get desktopChatNotFound => 'The conversation was not found';

  @override
  String desktopUnreadTitle(Object count) {
    return 'Secretly — $count unread';
  }

  @override
  String get desktopRoomsNone => 'No rooms yet';

  @override
  String get desktopRoomsNoneHint => 'Create a room on the phone — it will appear here automatically';

  @override
  String get desktopRoomsPickOne => 'Pick a room on the left';

  @override
  String get desktopScheduleTitle => 'Send later';

  @override
  String get desktopScheduleInHour => 'In an hour';

  @override
  String get desktopScheduleTonight => 'Today at 19:00';

  @override
  String get desktopScheduleTomorrow => 'Tomorrow at 9:00';

  @override
  String get desktopScheduleInWeek => 'In a week';

  @override
  String desktopScheduleTodayAt(Object time) {
    return 'today at $time';
  }

  @override
  String desktopScheduleTomorrowAt(Object time) {
    return 'tomorrow at $time';
  }

  @override
  String desktopScheduleOnAt(Object date, Object time) {
    return '$date at $time';
  }

  @override
  String get desktopScheduleHint => 'The message goes out on its own at the chosen time — even with the window closed it will be sent at the next start.';

  @override
  String get desktopSchedulePickTime => 'Pick a time…';

  @override
  String get desktopDevicesSearching => 'Looking for devices…';

  @override
  String get desktopDevicesNoCameras => 'No cameras found. The application may not have been given access to them in the system settings.';

  @override
  String get desktopDevicesNoMics => 'No microphones found. The application may not have been given access to them in the system settings.';

  @override
  String get desktopDevicesOutputHint => 'Where the sound goes is chosen inside the call — by the chevron next to “Microphone”. That is also where the application switches to headphones on its own when they are plugged in.';

  @override
  String get desktopDevicesSystemDefault => 'As chosen in the system';

  @override
  String get desktopRailSettings => 'Settings   Cmd ,';

  @override
  String get desktopRailConnected => 'Connected';

  @override
  String get desktopRailConnecting => 'Connecting…';

  @override
  String get desktopRailOffline => 'No connection';

  @override
  String desktopRailProfile(Object status) {
    return 'Profile   Cmd P   ·   $status';
  }

  @override
  String get desktopEmojiSmileys => 'Smileys and emotion';

  @override
  String get desktopEmojiPeople => 'People and body';

  @override
  String get desktopEmojiNature => 'Nature';

  @override
  String get desktopEmojiFood => 'Food and drink';

  @override
  String get desktopEmojiTravel => 'Travel';

  @override
  String get desktopEmojiActivities => 'Activities';

  @override
  String get desktopEmojiObjects => 'Objects';

  @override
  String get desktopEmojiSymbols => 'Symbols';

  @override
  String get desktopEmojiFlags => 'Flags';

  @override
  String get desktopEmojiOther => 'Other';

  @override
  String get desktopLockedTitle => 'Secretly is locked';

  @override
  String get desktopLockedTouchIdPrompt => 'Confirm your identity with Touch ID to continue.';

  @override
  String get desktopLockedPasswordPrompt => 'Confirm with your device password to continue.';

  @override
  String get desktopLockedUnlock => 'Unlock';

  @override
  String get desktopLockedWaiting => 'Waiting for confirmation…';

  @override
  String get desktopLockedFailed => 'Could not confirm your identity.';

  @override
  String get desktopLockedNoService => 'The identity service is unavailable on this computer. Restart Secretly or the computer. If that doesn\'t help, write to support from your phone.';

  @override
  String get desktopEmojiTabEmoji => 'Emoji';

  @override
  String get desktopEmojiTabStickers => 'Stickers';

  @override
  String get desktopEmojiRecents => 'Recent';

  @override
  String get desktopEmojiNothingFound => 'Nothing found';

  @override
  String get desktopEmojiSearchHint => 'Search emoji';

  @override
  String get desktopStickersSearchHint => 'Search stickers';

  @override
  String get desktopGifSearchHint => 'Search GIFs';

  @override
  String get desktopGifUnavailable => 'GIFs aren\'t available in this window';

  @override
  String get desktopStickerPacksSoon => 'Sticker packs coming soon';

  @override
  String get desktopCallFullscreen => 'Full screen';

  @override
  String get desktopCallPinWindow => 'Keep on top of other windows';

  @override
  String get desktopCallUnpinWindow => 'Stop keeping on top';

  @override
  String get desktopCallsOwnWindow => 'Call in a separate window';

  @override
  String get desktopCallsOwnWindowHint => 'The call opens in its own window: move it to another screen or keep it on top of other apps.';

  @override
  String get desktopCallExitFullscreen => 'Exit full screen';

  @override
  String get desktopCallDialing => 'Calling…';

  @override
  String get desktopCallEnded => 'Ended';

  @override
  String desktopCallEncryptedFor(Object duration) {
    return 'Encrypted · $duration';
  }

  @override
  String get desktopCallReturn => 'Return';

  @override
  String get desktopCallInProgress => 'Call in progress';

  @override
  String desktopCallInProgressWith(Object title) {
    return 'Call in progress · $title';
  }

  @override
  String get desktopCallAnswer => 'Answer';

  @override
  String get desktopCallAnswerVideo => 'Answer with video';

  @override
  String get desktopCallAnswerText => 'By text';

  @override
  String get desktopTimeYesterday => 'yesterday';

  @override
  String get desktopForwardTitle => 'Forward to…';

  @override
  String get desktopForwardSearchHint => 'Search chats and rooms';

  @override
  String get desktopForwardNoChats => 'No chats available';

  @override
  String get desktopForwardKindDirect => 'Direct chat';

  @override
  String get desktopContactsSearchHint => 'Search contacts';

  @override
  String get desktopContactsEmpty => 'No one yet. Add a contact by ID or invite link.';

  @override
  String desktopContactsNothingFor(Object query) {
    return 'Nothing found for “$query”.';
  }

  @override
  String get desktopContactsPick => 'Pick a contact';

  @override
  String get desktopContactsCardRight => 'The card will open on the right.';

  @override
  String get desktopContactsWrite => 'Send a message';

  @override
  String get desktopVideoTitle => 'Video';

  @override
  String get desktopViewerCloseEsc => 'Close  Esc';

  @override
  String get desktopVideoPlayFailed => 'Could not play the video';

  @override
  String get desktopKeySpace => 'Space';

  @override
  String get desktopWindowMinimize => 'Minimise';

  @override
  String get desktopWindowMaximize => 'Maximise';

  @override
  String get desktopWindowClose => 'Close';

  @override
  String get desktopWindowBack => 'Back';

  @override
  String get desktopWindowForward => 'Forward';

  @override
  String get desktopSearchEverything => 'Chats, people, messages, files';

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
  String get desktopSyncDone => 'Synced';

  @override
  String get desktopSyncSyncing => 'Syncing…';

  @override
  String get desktopSyncReconnecting => 'Reconnecting…';

  @override
  String get desktopDetailsShare => 'Share';

  @override
  String get desktopDetailsHide => 'Hide';

  @override
  String get desktopDetailsMore => 'More';

  @override
  String get desktopDetailsChangeCover => 'Change cover';

  @override
  String desktopDetailsFrame(Object name) {
    return '“$name” frame';
  }

  @override
  String get desktopApply => 'Apply';

  @override
  String get desktopAccentAppliesTo => 'Buttons, selections and rings. The bubble keeps its own style — you pick that below.';

  @override
  String get desktopTranslateUnknownSource => 'Couldn\'t detect the message language';

  @override
  String get desktopTranslateUnsupported => 'The system translator doesn\'t know this language pair';

  @override
  String get desktopTranslateNeedsDownload => 'The language isn’t downloaded. System Settings → General → Language & Region → Translation Languages';

  @override
  String get desktopTranslateFailed => 'Couldn\'t translate';

  @override
  String get desktopNewChatSearchHint => 'Search contacts';

  @override
  String get desktopNewChatNoContacts => 'No contacts yet';

  @override
  String get desktopNewChatNobodyFound => 'Nobody found';

  @override
  String get desktopMentionEveryone => 'Everyone';

  @override
  String get desktopMentionAdmins => 'Admins';

  @override
  String get desktopMentionEveryoneHint => 'Call everyone in the room';

  @override
  String get desktopMentionAdminsHint => 'Call the owner and admins';

  @override
  String desktopClearForPeer(Object name) {
    return 'Clear the history on $name’s side too';
  }

  @override
  String get desktopClearForPeerHint => 'Messages will vanish on their device and on all of yours. This cannot be undone.';

  @override
  String get desktopRoomClearForAll => 'For all room members too';

  @override
  String get desktopRoomClearForAllHint => 'Messages will disappear for everyone else too. This can’t be undone.';

  @override
  String get desktopGifNoKey => 'GIFs unavailable: this build has no GIPHY key';

  @override
  String get desktopGifConnectionLost => 'The connection dropped. Try again';

  @override
  String get desktopNotesHint => 'What to remember from this conversation…';

  @override
  String get desktopNotesPrivate => 'Visible only to you. It is never sent, never appears in the conversation and is not part of the backup — it lives on this computer, in the same encrypted database as the messages.';

  @override
  String get desktopEmojiSearchShort => 'Search emoji…';

  @override
  String get desktopNotifOpen => 'Open';

  @override
  String get desktopLinkPreviewLoading => 'Link preview…';

  @override
  String get desktopLinkPreviewOff => 'No preview';

  @override
  String get desktopDropToSend => 'Drop to send';

  @override
  String get desktopDropEncrypted => 'Files are encrypted before they are sent';

  @override
  String get desktopDetailsPickChat => 'Pick a chat';

  @override
  String get desktopDetailsEmptyHint => 'Details about the person or room\nwill appear here.';

  @override
  String get desktopMemberWrite => 'Message';

  @override
  String get desktopShowPanel => 'Show the panel';

  @override
  String get desktopHidePanel => 'Hide the panel';

  @override
  String get desktopNotifOff => 'Notifications are off';

  @override
  String get desktopSettingsSearchHint => 'Find a setting';

  @override
  String get desktopUnlockPrompt => 'Unlock Secretly';

  @override
  String get desktopEnableLockPrompt => 'Confirm to turn on the Secretly lock';

  @override
  String get desktopRoomsNoneHintDot => 'Create a room on your phone — it will show up here by itself.';

  @override
  String get desktopSplashLoading => 'Loading your profile…';

  @override
  String get desktopStartupFailedTitle => 'Secretly couldn\'t start';

  @override
  String get desktopStartupFailedBody => 'Try again. If it happens again, the startup log will help find the cause.';

  @override
  String get desktopStartupSlowTitle => 'Startup is taking longer than usual';

  @override
  String get desktopStartupSlowBody => 'You can keep waiting or start over.';

  @override
  String get desktopStartupRetry => 'Try again';

  @override
  String get desktopStartupOpenLogs => 'Open log folder';

  @override
  String get desktopOutgoingOnePhoto => 'Photo';

  @override
  String get desktopOutgoingOneVideo => 'Video';

  @override
  String get desktopOutgoingOneAudio => 'Audio';

  @override
  String get desktopOutgoingOneFile => 'File';

  @override
  String get desktopMenuSettings => 'Settings…';

  @override
  String get desktopMenuEdit => 'Edit';

  @override
  String get desktopMenuUndo => 'Undo';

  @override
  String get desktopMenuRedo => 'Redo';

  @override
  String get desktopMenuCut => 'Cut';

  @override
  String get desktopMenuPaste => 'Paste';

  @override
  String get desktopMenuSelectAll => 'Select All';

  @override
  String get desktopMenuView => 'View';

  @override
  String get desktopMenuWindow => 'Window';

  @override
  String get desktopMenuHelp => 'Help';

  @override
  String get desktopMenuWebsite => 'Secretly Website';

  @override
  String get desktopContactsAddHint => 'Secretly ID or invite link';

  @override
  String get desktopContactsAdded => 'Contact added';

  @override
  String get desktopContactsRenamed => 'Name saved';

  @override
  String get desktopMenuCheckUpdates => 'Check for Updates…';

  @override
  String get desktopNotifBlockedTitle => 'The system is not showing Secretly notifications';

  @override
  String get desktopNotifBlockedBody => 'The switches below still work, but nothing will be shown: the system is blocking this app’s notifications. The window is often hidden, and a notification is the only way to learn about a new message.';

  @override
  String get desktopNotifBlockedAction => 'Open System Settings';

  @override
  String get backupPwRequirements => 'Use at least 8 ASCII characters, one uppercase letter, and one special character. No leading or trailing spaces.';

  @override
  String backupPwTooShort(int count) {
    return 'Password must be at least $count characters.';
  }

  @override
  String backupPwTooLong(int count) {
    return 'Password must be no longer than $count characters.';
  }

  @override
  String get backupPwNonAscii => 'Use only Latin letters, digits, and ASCII symbols.';

  @override
  String get backupPwOuterSpace => 'Remove leading or trailing spaces from the password.';

  @override
  String get backupPwNeedUpper => 'Add at least one uppercase A-Z letter.';

  @override
  String get backupPwNeedSpecial => 'Add at least one special character, such as !, #, or ?.';

  @override
  String get desktopAuthGateTitle => 'Secretly on this computer';

  @override
  String get desktopAuthGateSubtitle => 'Choose how to sign in';

  @override
  String get desktopAuthPhoneTitle => 'Sign in with your phone';

  @override
  String get desktopAuthPhoneBody => 'If Secretly is already on your phone. Chats and contacts will move here.';

  @override
  String get desktopAuthCreateTitle => 'Create a new account';

  @override
  String get desktopAuthCreateBody => 'An account on this computer only. A subscription can be bought only in the phone app.';

  @override
  String get desktopAuthRestoreTitle => 'Restore';

  @override
  String get desktopAuthRestoreBody => 'From a recovery kit or from a backup on the server.';

  @override
  String get desktopAuthBack => 'Back';

  @override
  String get desktopAuthNameTitle => 'What should we call you?';

  @override
  String get desktopAuthNameBody => 'People you write to will see this name. You can change it at any time.';

  @override
  String get desktopAuthCreating => 'Creating the account…';

  @override
  String desktopAuthCreateFailed(Object error) {
    return 'Could not create the account: $error';
  }

  @override
  String get desktopAuthCheckClock => 'Check the computer’s clock: the server rejects requests when it is off.';

  @override
  String get desktopAuthKitTitle => 'Save your recovery kit';

  @override
  String get desktopAuthKitBody => 'This is the only way back into the account if the computer breaks or is lost. Secretly has no email and no phone number: without the kit nobody can restore the account, including us.';

  @override
  String get desktopAuthKitAction => 'Create the recovery kit';

  @override
  String get desktopAuthKitSaved => 'Kit saved. The account can be restored now.';

  @override
  String get desktopAuthContinue => 'Continue';

  @override
  String get desktopAuthKitOptionTitle => 'I have a recovery kit';

  @override
  String get desktopAuthKitOptionBody => 'The simplest way: the kit already carries your Secretly ID.';

  @override
  String get desktopAuthKitPasteHint => 'Paste the contents of the kit';

  @override
  String get desktopAuthServerOptionTitle => 'Backup on the server';

  @override
  String get desktopAuthServerOptionBody => 'You will need your Secretly ID and the backup password.';

  @override
  String get desktopAuthRestoring => 'Restoring…';

  @override
  String desktopAuthRestoreFailed(Object error) {
    return 'Could not restore: $error';
  }

  @override
  String get desktopAuthBackupNotFound => 'There is no backup on the server for this Secretly ID.';

  @override
  String get desktopGeneralLaunchAtLogin => 'Launch at login';

  @override
  String get desktopGeneralLaunchAtLoginOn => 'Secretly starts on its own and keeps receiving messages';

  @override
  String get desktopGeneralLaunchAtLoginOff => 'While Secretly is not running, messages do not reach this computer';

  @override
  String get desktopGeneralLaunchNeedsApproval => 'Launch at login is switched off in System Settings, under Login Items';

  @override
  String get desktopA11yStatusSending => 'Sending';

  @override
  String get desktopA11yStatusScheduled => 'Scheduled';

  @override
  String get desktopA11yStatusSent => 'Sent';

  @override
  String get desktopA11yStatusDelivered => 'Delivered';

  @override
  String get desktopA11yStatusRead => 'Read';

  @override
  String get desktopA11yStatusFailed => 'Not sent';

  @override
  String get desktopA11yVoiceProgress => 'Voice message playback';

  @override
  String get desktopViewerPagePrev => 'Previous page';

  @override
  String get desktopViewerPageNext => 'Next page';

  @override
  String get desktopReactionsMore => 'More emoji';

  @override
  String get desktopReactionsCollapse => 'Collapse';

  @override
  String get desktopThreadScrollToBottom => 'To the latest messages';

  @override
  String get desktopViewerPrev => 'Previous';

  @override
  String get desktopViewerNext => 'Next';

  @override
  String get desktopA11yPlay => 'Play';

  @override
  String get desktopA11yPause => 'Pause';

  @override
  String get desktopA11yAudioProgress => 'Playback';

  @override
  String get desktopPlayerClose => 'Close player';

  @override
  String get desktopPlayerOpenSource => 'Go to message';

  @override
  String desktopPlayerNowPlaying(String title) {
    return 'Now playing: $title';
  }

  @override
  String get desktopPlayerPrevious => 'Previous';

  @override
  String get desktopPlayerNext => 'Next';

  @override
  String get desktopPlayerMore => 'More in this chat';

  @override
  String get desktopPlayerSpeed => 'Playback speed';

  @override
  String get desktopPlayerSpeedNormal => 'Normal';

  @override
  String get desktopPlayerVolume => 'Volume';

  @override
  String get desktopUpdateNow => 'Update';

  @override
  String desktopUpdateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String desktopUpdateDownloading(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get desktopUpdateVerifying => 'Verifying…';

  @override
  String get desktopUpdateInstalling => 'Installing…';

  @override
  String get desktopUpdateManual => 'Download from the site';

  @override
  String get desktopUpdateFailedHint => 'The update could not be installed automatically. The installer is on our website.';

  @override
  String get desktopCallExpand => 'Expand the call';

  @override
  String get desktopCallMinimiseHint => 'Minimise to a mini window';

  @override
  String get desktopCallOpenChat => 'Minimise the call and open the chat';

  @override
  String get desktopCallScreenShareFailed => 'Couldn\'t share the screen';

  @override
  String get desktopCallScreenShareFailedMac => 'Couldn\'t share the screen. Allow Secretly to record the screen: System Settings → Privacy & Security → Screen Recording';

  @override
  String get desktopCallMediaCameraUnavailable => 'The camera is unavailable — another app is using it or permission is missing in system settings';

  @override
  String get desktopCallMediaMicUnavailable => 'The microphone is unavailable — check the permission in system settings';

  @override
  String get desktopCallMediaScreenStopped => 'Screen sharing stopped';

  @override
  String desktopCallMediaProblem(String detail) {
    return 'Audio or video problem: $detail';
  }

  @override
  String desktopCallEndedAfter(String duration) {
    return 'Call ended · $duration';
  }

  @override
  String desktopCallDirectWith(String name) {
    return 'On a call · $name';
  }

  @override
  String get desktopCallLeaveFailed => 'Couldn\'t leave the call: the server didn\'t answer. Try again.';

  @override
  String get desktopCallRemoveParticipant => 'Remove from call';

  @override
  String desktopCallRemoveParticipantTitle(String name) {
    return 'Remove $name from the call?';
  }

  @override
  String get desktopCallRemoveParticipantBody => 'They will be taken out of the call. They can come back by joining again.';

  @override
  String get desktopCallRemoveFailed => 'Couldn’t remove from the call';

  @override
  String get desktopCallLeaveTitle => 'Leave the call?';

  @override
  String get desktopCallEndForAll => 'End the call for everyone';

  @override
  String get desktopCallEndForAllHint => 'Everyone else will be taken out of the call too.';

  @override
  String get desktopCallEndForAllFailed => 'Couldn’t end the call for everyone';

  @override
  String get desktopCallToggleFailed => 'Couldn\'t switch it: the server didn\'t answer. Try again.';

  @override
  String get desktopDiagTitle => 'Delivery diagnostics';

  @override
  String get desktopDiagHint => 'What to look at when messages are not arriving, and what to send us';

  @override
  String get desktopDiagQueues => 'QUEUES';

  @override
  String get desktopDiagOutbox => 'Waiting to be sent';

  @override
  String get desktopDiagStuck => 'Stuck on arrival';

  @override
  String get desktopDiagReceipts => 'Receipts queued';

  @override
  String get desktopDiagNothingStuck => 'Nothing is stuck';

  @override
  String get desktopDiagConditions => 'DELIVERY CONDITIONS';

  @override
  String get desktopDiagClockOk => 'Computer clock agrees with the server';

  @override
  String desktopDiagClockSkew(Object delta) {
    return 'Computer clock is off by $delta — the server may refuse messages';
  }

  @override
  String get desktopDiagCopy => 'Copy for support';

  @override
  String get desktopAppearanceTextSize => 'Text size';

  @override
  String get desktopThreadGoToDate => 'Go to date';

  @override
  String get desktopHotkeyGlobalShow => 'Show Secretly from anywhere';

  @override
  String get desktopHotkeyGlobalHint => 'Off by default: the shortcut is system-wide and would be taken away from another app';

  @override
  String get desktopHotkeyGlobalTaken => 'Another app already holds this shortcut';

  @override
  String get desktopTrayOpen => 'Open Secretly';

  @override
  String desktopTrayUnread(int count) {
    return '$count unread';
  }

  @override
  String get desktopTrayMute => 'Mute notifications';

  @override
  String get desktopTrayMuteHour => 'For 1 hour';

  @override
  String get desktopTrayMuteEightHours => 'For 8 hours';

  @override
  String get desktopTrayMuteForever => 'Until I turn them back on';

  @override
  String get desktopTrayUnmute => 'Turn notifications back on';

  @override
  String desktopTrayMutedUntil(String time) {
    return 'Muted until $time';
  }

  @override
  String get desktopTrayQuit => 'Quit Secretly';

  @override
  String get desktopTrayHintTitle => 'Secretly keeps running in the background';

  @override
  String get desktopTrayHintBody => 'Messages and calls will keep arriving. The icon is next to the clock — pin it to keep it in sight.';

  @override
  String get desktopDevicesMicrophone => 'Microphone';

  @override
  String get desktopDevicesSpeakers => 'Speakers and headphones';

  @override
  String get desktopDevicesNoSpeakers => 'No speakers or headphones found';

  @override
  String get desktopDevicesCamera => 'Camera';

  @override
  String get desktopCallsSystemTitle => 'System';

  @override
  String get desktopCallsSystemSound => 'System sound settings';

  @override
  String get desktopCallsSystemSoundHint => 'Volume, the default device and microphone access';

  @override
  String get desktopCallsOpenSystem => 'Open';

  @override
  String get desktopMicLevel => 'Microphone level';

  @override
  String get desktopMicLevelHint => 'Say something — the bar should move. The microphone is on only while this section is open, and the sound goes nowhere.';

  @override
  String get desktopMicNeedsAccess => 'The app hasn’t been allowed to use the microphone yet.';

  @override
  String get desktopMicAllow => 'Allow';

  @override
  String get desktopMicNoAccess => 'No access to the microphone. Allow it in the system settings.';

  @override
  String get desktopMicOpenFailed => 'Couldn’t open the microphone. Another app may be using it, or access to it is blocked.';

  @override
  String get desktopMicSystemFallback => 'The selected microphone couldn’t be opened for the check — showing the system microphone.';

  @override
  String get desktopMediaOpenPrivacy => 'Open settings';

  @override
  String get desktopMicTest => 'Test microphone';

  @override
  String get desktopMicTestHint => 'Records 5 seconds and plays them back through the selected speakers.';

  @override
  String get desktopMediaCheck => 'Test';

  @override
  String get desktopMediaCheckStop => 'Stop';

  @override
  String desktopMicTestRecording(int seconds) {
    return 'Recording — speak… $seconds s';
  }

  @override
  String get desktopMicTestPlaying => 'Playing the recording…';

  @override
  String get desktopMediaPlaybackFailed => 'Couldn’t play the sound.';

  @override
  String get desktopMediaPlaybackSystemOnly => 'The sound played on the system default device: the selected one couldn’t be opened for the check.';

  @override
  String get desktopMediaBusyInCall => 'A call is in progress — checks are off so they don’t disturb it.';

  @override
  String get desktopSpeakerTest => 'Test speakers';

  @override
  String get desktopSpeakerTestHint => 'A short chime on the selected device.';

  @override
  String get desktopSpeakerTestPlaying => 'Playing…';

  @override
  String get desktopCameraPreview => 'Check the camera';

  @override
  String get desktopCameraPreviewHint => 'The camera turns on only while the preview is shown.';

  @override
  String get desktopCameraPreviewShow => 'Show';

  @override
  String get desktopCameraPreviewHide => 'Hide';

  @override
  String get desktopCameraPreviewFailed => 'Couldn’t turn on the camera. Another app may be using it, or access to it is blocked.';

  @override
  String get desktopCameraMirror => 'Mirror my video';

  @override
  String get desktopCameraMirrorHint => 'Only on your screen, like in a mirror. Others see you as usual.';

  @override
  String get desktopRingtoneTitle => 'Ringtone';

  @override
  String get desktopRingtoneVolume => 'Volume';

  @override
  String get desktopRingtoneVolumeHint => 'How loud incoming calls ring on this computer.';

  @override
  String get desktopRingtoneListen => 'Listen';

  @override
  String get desktopRingtoneSilent => 'Silent — only the window will show the call.';

  @override
  String get desktopRoomEditTitle => 'Edit group';

  @override
  String get desktopRoomEditName => 'Name';

  @override
  String get desktopRoomEditNameHint => 'Group name';

  @override
  String get desktopRoomEditNameEmpty => 'Enter a name';

  @override
  String get desktopRoomEditDescription => 'Description';

  @override
  String get desktopRoomEditDescriptionHint => 'What this group is about';

  @override
  String get desktopRoomEditPhotoChoose => 'Choose photo…';

  @override
  String get desktopRoomEditPhotoRemove => 'Remove photo';

  @override
  String get desktopRoomEditSaved => 'Group updated';

  @override
  String get desktopRoomPermissionsMenu => 'Permissions';

  @override
  String get desktopRoomPermissionsTitle => 'Member permissions';

  @override
  String get desktopRoomPermissionsSaved => 'Permissions saved';

  @override
  String get desktopRoomPermMembersSection => 'What members can do';

  @override
  String get desktopRoomPermSendText => 'Send messages';

  @override
  String get desktopRoomPermSendMedia => 'Send photos, videos and files';

  @override
  String get desktopRoomPermPin => 'Pin messages';

  @override
  String get desktopRoomPermAddMembers => 'Add members';

  @override
  String get desktopRoomAddMembers => 'Add members';

  @override
  String get desktopRoomAddMembersSearch => 'Name or Secretly ID';

  @override
  String get desktopRoomAddMembersAlready => 'Already in the room';

  @override
  String get desktopRoomAddMembersNone => 'Nobody found';

  @override
  String get desktopRoomAddMembersNoContacts => 'No contacts yet. Invite people with a link.';

  @override
  String desktopRoomAddMembersAction(int count) {
    return 'Add $count';
  }

  @override
  String desktopRoomMembersAdded(int count) {
    return 'Members added: $count';
  }

  @override
  String get desktopRoomInviteLinksMenu => 'Invite links';

  @override
  String get desktopRoomAuditLog => 'Recent actions';

  @override
  String get desktopRoomAuditLogEmpty => 'Nothing has happened yet';

  @override
  String get desktopRoomAuditLogHint => 'Joins, leaves, roles and settings — as this computer has seen them.';

  @override
  String get desktopRoomPermChangeInfo => 'Change name, photo and description';

  @override
  String get desktopRoomPermChangeTag => 'Change their own tag';

  @override
  String get desktopRoomPermJoinSection => 'Joining';

  @override
  String get desktopRoomPermApproval => 'Join only after approval';

  @override
  String get desktopRoomPermHistory => 'Chat history for new members';

  @override
  String get desktopRoomPermHistoryHint => 'New members see messages sent before they joined';

  @override
  String get desktopRoomPermReactions => 'Reactions';

  @override
  String get desktopRoomReactionsAll => 'All';

  @override
  String get desktopRoomReactionsSome => 'Selected';

  @override
  String get desktopRoomReactionsNone => 'None';

  @override
  String get desktopRoomPermSlowMode => 'Slow mode';

  @override
  String get desktopRoomPermSlowModeHint => 'How often each member can send a message';

  @override
  String get desktopRoomSlowOff => 'Off';

  @override
  String desktopRoomSlowSeconds(int count) {
    return '$count s';
  }

  @override
  String desktopRoomSlowMinutes(int count) {
    return '$count min';
  }

  @override
  String desktopRoomSlowHours(int count) {
    return '$count h';
  }

  @override
  String get desktopRoomDelete => 'Delete group';

  @override
  String get desktopRoomDeleteTitle => 'Delete the group for everyone?';

  @override
  String desktopRoomDeleteBody(String title) {
    return '“$title” will disappear for all members together with its messages. This can\'t be undone.';
  }

  @override
  String get desktopRoomDeleted => 'Group deleted';

  @override
  String get desktopRoomOwnerLeaveTitle => 'You own this group';

  @override
  String get desktopRoomOwnerLeaveBody => 'Before leaving, hand the group over to another member — or delete it for everyone.';

  @override
  String get desktopRoomOwnerLeaveNoMembers => 'There is nobody else in the group — it can only be deleted.';

  @override
  String get desktopRoomOwnerLeaveTransfer => 'Hand over and leave';

  @override
  String get desktopComposerSendHintShift => 'Send · Shift+Enter\nRight click to send later';

  @override
  String get desktopWallpaperUseDefault => 'As in settings';

  @override
  String get desktopWallpaperClassic => 'Classic';

  @override
  String get desktopWallpaperStandard => 'Standard';

  @override
  String desktopWallpaperProfilePhoto(int n) {
    return 'Photo $n';
  }

  @override
  String get desktopChatWallpaperTitle => 'Chat wallpaper';

  @override
  String get desktopChatWallpaperMenu => 'Chat wallpaper…';

  @override
  String get desktopChatWallpaperSaved => 'Wallpaper set for this chat';

  @override
  String get desktopWallpaperPremiumOnly => 'This wallpaper is part of Premium — the subscription is managed in the phone app';

  @override
  String get desktopGeneralStartMinimized => 'Start minimized';

  @override
  String get desktopGeneralStartMinimizedHint => 'At sign-in the window stays closed — Secretly waits in the tray';

  @override
  String get desktopGeneralCloseToTray => 'Close to tray';

  @override
  String get desktopGeneralCloseToTrayOn => 'The close button hides the window — messages and calls keep arriving';

  @override
  String get desktopGeneralCloseToTrayOff => 'The close button quits Secretly — nothing arrives until you open it again';

  @override
  String get desktopGeneralLaunchNeedsApprovalWindows => 'Startup is turned off in Task Manager → Startup apps — turn Secretly on there';

  @override
  String get desktopSupportAttachLog => 'Attach log';

  @override
  String get desktopSupportLogEmpty => 'The log is empty for now';

  @override
  String get desktopDevicesAddComputerTitle => 'Another computer';

  @override
  String get desktopDevicesAddComputerHint => 'Computers are linked from the phone. Install Secretly on the other computer and choose “Sign in with your phone” there, then on your phone open Settings → Devices → “Connect device” and scan the QR code that computer shows.';

  @override
  String get desktopSettingsSignOutBodyOnlyDevice => 'This computer is the only device with this account. After signing out, the account can be brought back only with the recovery kit — without it nobody can restore it, including us. Make sure the kit is saved first.';

  @override
  String get desktopSettingsSignOutBodyUnknown => 'The conversations, keys and cache will be removed from this computer. If the account is also on another device, it stays there. If this computer is its only device, the account can be brought back only with the recovery kit.';

  @override
  String desktopPairingRetryIn(Object seconds) {
    return 'Next attempt in $seconds s';
  }

  @override
  String get desktopKitReadyTitle => 'Your recovery kit is ready';

  @override
  String get desktopKitReadyBody => 'Keep it outside this computer — on a flash drive, in a password manager or on paper. The kit together with its password opens the account, so store them separately.';

  @override
  String get desktopKitSaveToFile => 'Save to file…';

  @override
  String get desktopKitSaveDialogTitle => 'Save the recovery kit';

  @override
  String desktopKitSavedTo(Object path) {
    return 'Saved to file: $path';
  }

  @override
  String desktopKitSaveFailed(Object error) {
    return 'Could not save the file: $error';
  }

  @override
  String get desktopKitShowQr => 'Show the QR code and text';

  @override
  String get desktopKitSavedElsewhere => 'Saved another way';

  @override
  String get desktopKitConfirmTitle => 'Is the kit really saved?';

  @override
  String get desktopKitConfirmBody => 'Confirm only if you copied the kit’s text or photographed its QR code and put it somewhere safe outside this computer. Without the kit the account cannot be restored.';

  @override
  String get desktopKitConfirmYes => 'Yes, it’s saved';

  @override
  String get desktopAuthKitConfirmed => 'You confirmed that the kit is kept in a safe place. The account can be restored with it.';

  @override
  String get desktopAboutSourceCode => 'Source code';

  @override
  String desktopAboutLicenseLine(Object url) {
    return 'Licence: GNU AGPL-3.0. Source code: $url';
  }

  @override
  String get desktopProfileLinkTitle => 'Open this chat?';

  @override
  String desktopProfileLinkBody(String name, String id) {
    return 'The link leads to a chat with $name ($id).';
  }

  @override
  String desktopProfileLinkBodyUnknown(String id) {
    return 'The link leads to a chat with the profile $id.';
  }

  @override
  String get desktopProfileLinkOpen => 'Open chat';

  @override
  String desktopUpdateAttemptFailed(String reason) {
    return 'The update wasn\'t installed: $reason';
  }

  @override
  String get desktopUpdateFailureDownload => 'the file couldn\'t be downloaded';

  @override
  String get desktopUpdateFailureVerification => 'the downloaded file failed the check and was deleted without being run';

  @override
  String get desktopUpdateFailureLaunch => 'the installer didn\'t start';

  @override
  String get desktopUpdateFailureNotInstalled => 'the previous version is still running after the installer';

  @override
  String get desktopUpdateRetry => 'Try again';

  @override
  String get desktopRestoreTakeOverTitle => 'This computer will become the device that made the backup';

  @override
  String get desktopRestoreTakeOverBody => 'The backup was made by another device — for example, your phone. After restoring, this computer takes that device\'s place. If that device is still in use, messages will reach only one of the two, and the other may stop decrypting chats or lose its connection to the server. Restore this way only if that device is gone. To use the computer alongside your phone, go back and link it with a QR code instead.';

  @override
  String get desktopRestoreTakeOverConfirm => 'Restore anyway';

  @override
  String get desktopServerBackupReplaceTitle => 'Replace the backup on the server?';

  @override
  String get desktopServerBackupReplaceBody => 'The server keeps one backup per account. A backup from this computer replaces the one made by your phone or another device, and the previous one can\'t be brought back. It will contain only the history that is on this computer.';

  @override
  String get desktopServerBackupReplaceConfirm => 'Replace';

  @override
  String get desktopBackupAutoPasswordMissing => 'no backup password is set';

  @override
  String get desktopBackupAutoPasswordWeak => 'the backup password no longer meets the requirements';

  @override
  String get desktopBackupSetPassword => 'Set the backup password';

  @override
  String get desktopSupportLogConfirmTitle => 'Attach the log?';

  @override
  String desktopSupportLogConfirmBody(String size) {
    return '$size of the app\'s service records from recent days. Look at what is in it before attaching: the log goes to support together with your message.';
  }

  @override
  String get desktopSupportLogView => 'View';

  @override
  String get desktopSupportLogAttachConfirm => 'Attach';

  @override
  String get desktopSupportLogViewTitle => 'What the log contains';

  @override
  String get desktopDevicesEndNotConfirmed => 'the server did not confirm it. Try again later.';

  @override
  String get desktopPrivacyScreenCaptureTitle => 'Screen capture protection';

  @override
  String get desktopPrivacyScreenCaptureSwitch => 'Hide Secretly windows from screenshots and screen recording';

  @override
  String get desktopPrivacyScreenCaptureHint => 'Screenshots, screen recording and screen sharing — including your own screen sharing in calls — won\'t show what is in Secretly windows. It doesn\'t stop anyone from photographing the screen, and some capture tools or system versions may not honour it.';

  @override
  String get desktopPrivacyScreenCaptureFailed => 'The system didn\'t accept screen capture protection.';

  @override
  String get desktopSoundMessagesTitle => 'Message sound';

  @override
  String get desktopSoundMessagesHint => 'Plays with message notifications on this computer.';

  @override
  String get desktopSoundMutedNote => 'Sound is turned off above — the chosen sound won’t play.';

  @override
  String get desktopSoundInChatTitle => 'Sound in the open chat';

  @override
  String get desktopSoundInChatSwitch => 'New messages in the open chat';

  @override
  String get desktopSoundInChatHint => 'A quiet sound instead of a notification while the chat is open in the active window.';

  @override
  String get desktopSoundNameBubble => 'Bubble';

  @override
  String get desktopSoundNameBubbles => 'Bubbles';

  @override
  String get desktopSoundNameDrip => 'Drip';

  @override
  String get desktopSoundNamePing => 'Ping';

  @override
  String get desktopSoundNameSplash => 'Splash';

  @override
  String get desktopSoundNameDrop => 'Drop';

  @override
  String get desktopSoundNameTone => 'Tone';

  @override
  String get desktopSoundNameKey => 'Key';

  @override
  String get desktopSoundNameClick => 'Click';

  @override
  String get desktopSoundNameSwitch => 'Switch';

  @override
  String get desktopSoundNameMelody => 'Melody';

  @override
  String get desktopSoundNamePulse => 'Pulse';

  @override
  String get desktopSoundNameDefault => 'Default';
}
