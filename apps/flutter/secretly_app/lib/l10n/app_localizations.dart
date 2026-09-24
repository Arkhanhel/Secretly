import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
    Locale('pt', 'BR'),
    Locale('ru'),
    Locale('uk')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Secretly'**
  String get appTitle;

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get starting;

  /// No description provided for @encrypting.
  ///
  /// In en, this message translates to:
  /// **'Encrypting…'**
  String get encrypting;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorPrefix(Object error);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @notificationsSection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsSection;

  /// No description provided for @languageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSection;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @idsTitle.
  ///
  /// In en, this message translates to:
  /// **'IDs'**
  String get idsTitle;

  /// No description provided for @profileIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile ID'**
  String get profileIdLabel;

  /// No description provided for @deviceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get deviceIdLabel;

  /// No description provided for @profileIdShort.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileIdShort;

  /// No description provided for @deviceIdShort.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get deviceIdShort;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @copyBoth.
  ///
  /// In en, this message translates to:
  /// **'Copy both'**
  String get copyBoth;

  /// No description provided for @openMyId.
  ///
  /// In en, this message translates to:
  /// **'Open my ID'**
  String get openMyId;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @tabChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get tabChats;

  /// No description provided for @tabGroups.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get tabGroups;

  /// No description provided for @tabContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get tabContacts;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// No description provided for @chatsSection.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsSection;

  /// No description provided for @privacySection.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacySection;

  /// No description provided for @devicesSection.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesSection;

  /// No description provided for @systemSection.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemSection;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @languageSystemCurrent.
  ///
  /// In en, this message translates to:
  /// **'System ({language})'**
  String languageSystemCurrent(Object language);

  /// No description provided for @languageChooseAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose app language'**
  String get languageChooseAppLanguage;

  /// No description provided for @languageAvailableWave1.
  ///
  /// In en, this message translates to:
  /// **'Available: English, Russian, Ukrainian, Spanish, Portuguese (Brazil), French, and German. You can also follow system language.'**
  String get languageAvailableWave1;

  /// No description provided for @languageMessageTranslation.
  ///
  /// In en, this message translates to:
  /// **'Message translation'**
  String get languageMessageTranslation;

  /// No description provided for @languageShowTranslateButton.
  ///
  /// In en, this message translates to:
  /// **'Show Translate button'**
  String get languageShowTranslateButton;

  /// No description provided for @languageTranslateWholeChats.
  ///
  /// In en, this message translates to:
  /// **'Translate whole chats'**
  String get languageTranslateWholeChats;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// No description provided for @favoritesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal notes'**
  String get favoritesSubtitle;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send messages, files, and notes here to keep them private on your devices.'**
  String get favoritesEmptySubtitle;

  /// No description provided for @favoritesPersonalNotebookLabel.
  ///
  /// In en, this message translates to:
  /// **'Personal notes'**
  String get favoritesPersonalNotebookLabel;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @stickersRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent stickers'**
  String get stickersRecent;

  /// No description provided for @searchStickers.
  ///
  /// In en, this message translates to:
  /// **'Search stickers'**
  String get searchStickers;

  /// No description provided for @noStickersFound.
  ///
  /// In en, this message translates to:
  /// **'No stickers found'**
  String get noStickersFound;

  /// No description provided for @noRecentStickers.
  ///
  /// In en, this message translates to:
  /// **'Your recent stickers will appear here'**
  String get noRecentStickers;

  /// No description provided for @cancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get cancelSelection;

  /// No description provided for @chatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTitle;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @openContactsToStartChat.
  ///
  /// In en, this message translates to:
  /// **'Open Contacts to start a chat'**
  String get openContactsToStartChat;

  /// No description provided for @noChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChatsYet;

  /// No description provided for @openDemoChat.
  ///
  /// In en, this message translates to:
  /// **'Open demo chat'**
  String get openDemoChat;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchive;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @archiveHeader.
  ///
  /// In en, this message translates to:
  /// **'Archive ({count})'**
  String archiveHeader(Object count);

  /// No description provided for @deleteChatsConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} chat(s)?'**
  String deleteChatsConfirmTitle(Object count);

  /// No description provided for @deleteChatsConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes chats from this device only.'**
  String get deleteChatsConfirmBody;

  /// No description provided for @clearHistoryConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear history for {count} chat(s)?'**
  String clearHistoryConfirmTitle(Object count);

  /// No description provided for @clearHistoryConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes messages from this device only.'**
  String get clearHistoryConfirmBody;

  /// No description provided for @contactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contactsTitle;

  /// No description provided for @contactsTab.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contactsTab;

  /// No description provided for @requestsTab.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requestsTab;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get addContact;

  /// No description provided for @deleteContact.
  ///
  /// In en, this message translates to:
  /// **'Delete contact'**
  String get deleteContact;

  /// No description provided for @noContactsYet.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get noContactsYet;

  /// No description provided for @noRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests'**
  String get noRequests;

  /// No description provided for @secretlyIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Secretly ID'**
  String get secretlyIdLabel;

  /// No description provided for @secretlyIdHint.
  ///
  /// In en, this message translates to:
  /// **'XXXX-XXXX-...-CHECK'**
  String get secretlyIdHint;

  /// No description provided for @nameOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get nameOptionalLabel;

  /// No description provided for @scanContactQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan contact QR'**
  String get scanContactQrTitle;

  /// No description provided for @qrMissingSecretlyId.
  ///
  /// In en, this message translates to:
  /// **'QR does not contain Secretly ID'**
  String get qrMissingSecretlyId;

  /// No description provided for @differentServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Different server'**
  String get differentServerTitle;

  /// No description provided for @differentServerBody.
  ///
  /// In en, this message translates to:
  /// **'This QR belongs to another server.\n\nQR server: {qrServer}\nThis app: {appServer}\n\nInstall the same APK/server on both phones.'**
  String differentServerBody(Object qrServer, Object appServer);

  /// No description provided for @contactActionProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Secretly ID was not found on this server.'**
  String get contactActionProfileNotFound;

  /// No description provided for @contactActionTransportBlocked.
  ///
  /// In en, this message translates to:
  /// **'This action is unavailable because the app is bound to a different server.'**
  String get contactActionTransportBlocked;

  /// No description provided for @contactActionServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server is unavailable right now. Try again in a moment.'**
  String get contactActionServiceUnavailable;

  /// No description provided for @contactActionCallsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Calls are disabled in Privacy settings.'**
  String get contactActionCallsDisabled;

  /// No description provided for @contactActionCallsDisabledForContact.
  ///
  /// In en, this message translates to:
  /// **'Calls are disabled for this contact.'**
  String get contactActionCallsDisabledForContact;

  /// No description provided for @callServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Call service is unavailable right now.'**
  String get callServiceUnavailable;

  /// No description provided for @callAlreadyInProgress.
  ///
  /// In en, this message translates to:
  /// **'Another call is already in progress.'**
  String get callAlreadyInProgress;

  /// No description provided for @callIceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Secure call setup is unavailable right now. Try again in a moment.'**
  String get callIceUnavailable;

  /// No description provided for @callPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone or camera access is blocked. Allow permissions and try again.'**
  String get callPermissionDenied;

  /// No description provided for @callNegotiationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t establish the secure call. Try again.'**
  String get callNegotiationFailed;

  /// No description provided for @callConnectionInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Call connection was interrupted. Try again.'**
  String get callConnectionInterrupted;

  /// No description provided for @callActionGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the call. Try again.'**
  String get callActionGeneric;

  /// No description provided for @callEncryptedBadge.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted'**
  String get callEncryptedBadge;

  /// No description provided for @incomingVideoCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming video call'**
  String get incomingVideoCall;

  /// No description provided for @incomingVoiceCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming voice call'**
  String get incomingVoiceCall;

  /// No description provided for @callDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get callDecline;

  /// No description provided for @callConnectionUnstable.
  ///
  /// In en, this message translates to:
  /// **'Connection unstable'**
  String get callConnectionUnstable;

  /// No description provided for @callNetworkVeryWeak.
  ///
  /// In en, this message translates to:
  /// **'Very weak network signal'**
  String get callNetworkVeryWeak;

  /// No description provided for @callNetworkWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak network signal'**
  String get callNetworkWeak;

  /// No description provided for @callEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get callEnded;

  /// No description provided for @callReplacedByNewerAttempt.
  ///
  /// In en, this message translates to:
  /// **'Call was replaced by a newer attempt'**
  String get callReplacedByNewerAttempt;

  /// No description provided for @callDeclined.
  ///
  /// In en, this message translates to:
  /// **'Call declined'**
  String get callDeclined;

  /// No description provided for @callYouDeclined.
  ///
  /// In en, this message translates to:
  /// **'You declined'**
  String get callYouDeclined;

  /// No description provided for @callNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get callNoAnswer;

  /// No description provided for @callConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get callConnectionError;

  /// No description provided for @callVideoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video unavailable'**
  String get callVideoUnavailable;

  /// No description provided for @callWaitingForRemoteVideo.
  ///
  /// In en, this message translates to:
  /// **'Waiting for remote video...'**
  String get callWaitingForRemoteVideo;

  /// No description provided for @callAttachingRemoteVideo.
  ///
  /// In en, this message translates to:
  /// **'Attaching remote video...'**
  String get callAttachingRemoteVideo;

  /// No description provided for @callStartingRemoteVideo.
  ///
  /// In en, this message translates to:
  /// **'Starting remote video...'**
  String get callStartingRemoteVideo;

  /// No description provided for @callRemoteVideoNotArriving.
  ///
  /// In en, this message translates to:
  /// **'Remote video is not arriving'**
  String get callRemoteVideoNotArriving;

  /// No description provided for @callRemoteVideoBindFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not bind remote video stream'**
  String get callRemoteVideoBindFailed;

  /// No description provided for @callRemoteVideoNoFrames.
  ///
  /// In en, this message translates to:
  /// **'Remote video attached, but no frames are rendering'**
  String get callRemoteVideoNoFrames;

  /// No description provided for @callMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get callMinimize;

  /// No description provided for @callStatusCalling.
  ///
  /// In en, this message translates to:
  /// **'Calling...'**
  String get callStatusCalling;

  /// No description provided for @callStatusIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming...'**
  String get callStatusIncoming;

  /// No description provided for @callStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get callStatusConnecting;

  /// No description provided for @callStatusReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get callStatusReconnecting;

  /// No description provided for @callStatusEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get callStatusEnded;

  /// No description provided for @callVideoCall.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get callVideoCall;

  /// No description provided for @callControlMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get callControlMute;

  /// No description provided for @callControlSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get callControlSpeaker;

  /// No description provided for @callControlCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get callControlCamera;

  /// No description provided for @callControlFlip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get callControlFlip;

  /// No description provided for @callControlStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get callControlStop;

  /// No description provided for @callControlShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get callControlShare;

  /// No description provided for @callControlEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get callControlEnd;

  /// No description provided for @contactActionGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete the action. Try again.'**
  String get contactActionGeneric;

  /// No description provided for @notificationTitleRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get notificationTitleRoom;

  /// No description provided for @notificationTitleRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get notificationTitleRequest;

  /// No description provided for @notificationTitleChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get notificationTitleChat;

  /// No description provided for @notificationBodyNewMessage.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get notificationBodyNewMessage;

  /// No description provided for @contactLookupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Search is unavailable right now. Try again in a moment.'**
  String get contactLookupUnavailable;

  /// No description provided for @addContactFailed.
  ///
  /// In en, this message translates to:
  /// **'Add contact failed: {error}'**
  String addContactFailed(Object error);

  /// No description provided for @deleteContactsConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} contact(s)?'**
  String deleteContactsConfirmTitle(Object count);

  /// No description provided for @deleteContactsConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Chats are not deleted.'**
  String get deleteContactsConfirmBody;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTitle;

  /// No description provided for @blockedUsersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked users cannot deliver messages to you (server-enforced).'**
  String get blockedUsersSubtitle;

  /// No description provided for @noBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get noBlockedUsers;

  /// No description provided for @unblockFailed.
  ///
  /// In en, this message translates to:
  /// **'Unblock failed: {error}'**
  String unblockFailed(Object error);

  /// No description provided for @diagIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get diagIdentity;

  /// No description provided for @diagEndpoints.
  ///
  /// In en, this message translates to:
  /// **'Endpoints'**
  String get diagEndpoints;

  /// No description provided for @diagServerBinding.
  ///
  /// In en, this message translates to:
  /// **'Server binding'**
  String get diagServerBinding;

  /// No description provided for @diagMismatch.
  ///
  /// In en, this message translates to:
  /// **'Mismatch: profile belongs to another server. Use Settings → Reset profile.'**
  String get diagMismatch;

  /// No description provided for @diagStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get diagStatus;

  /// No description provided for @diagTimestamps.
  ///
  /// In en, this message translates to:
  /// **'Timestamps'**
  String get diagTimestamps;

  /// No description provided for @diagTips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get diagTips;

  /// No description provided for @diagTipsBody.
  ///
  /// In en, this message translates to:
  /// **'If messaging fails with \"profile not found\":\n1) Ensure both phones use the same APK/server\n2) Re-add contact by scanning QR\n3) If endpoints changed, use Reset profile\n'**
  String get diagTipsBody;

  /// No description provided for @secretlyUser.
  ///
  /// In en, this message translates to:
  /// **'Secretly user'**
  String get secretlyUser;

  /// No description provided for @onlineStatus.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get onlineStatus;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @profileSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileSectionTitle;

  /// No description provided for @myNicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'My nickname'**
  String get myNicknameLabel;

  /// No description provided for @myNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Alex'**
  String get myNicknameHint;

  /// No description provided for @includeNicknameInQr.
  ///
  /// In en, this message translates to:
  /// **'Include nickname in my QR'**
  String get includeNicknameInQr;

  /// No description provided for @includeNicknameInQrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off by default for privacy. If enabled, scanners may auto-name you.'**
  String get includeNicknameInQrSubtitle;

  /// No description provided for @verifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify: {title}'**
  String verifyTitle(Object title);

  /// No description provided for @scanVerifyQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan verify QR'**
  String get scanVerifyQrTitle;

  /// No description provided for @qrBelongsAnotherServer.
  ///
  /// In en, this message translates to:
  /// **'QR belongs to another server: {server}'**
  String qrBelongsAnotherServer(Object server);

  /// No description provided for @qrSecretlyIdMismatch.
  ///
  /// In en, this message translates to:
  /// **'QR Secretly ID does not match this contact'**
  String get qrSecretlyIdMismatch;

  /// No description provided for @qrMissingDeviceKeyInfo.
  ///
  /// In en, this message translates to:
  /// **'QR missing device/key info'**
  String get qrMissingDeviceKeyInfo;

  /// No description provided for @deviceNotCachedTapRefresh.
  ///
  /// In en, this message translates to:
  /// **'Device not cached. Tap Refresh first.'**
  String get deviceNotCachedTapRefresh;

  /// No description provided for @identityKeyMismatch.
  ///
  /// In en, this message translates to:
  /// **'Identity key mismatch. Do not verify.'**
  String get identityKeyMismatch;

  /// No description provided for @verifiedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Verified ✅'**
  String get verifiedSuccess;

  /// No description provided for @refreshKeys.
  ///
  /// In en, this message translates to:
  /// **'Refresh keys'**
  String get refreshKeys;

  /// No description provided for @keysOfflineCannotFetch.
  ///
  /// In en, this message translates to:
  /// **'Keys service is offline. Cannot fetch contact keys right now.'**
  String get keysOfflineCannotFetch;

  /// No description provided for @devicesLabel.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesLabel;

  /// No description provided for @noDeviceKeysCachedYet.
  ///
  /// In en, this message translates to:
  /// **'No device keys cached yet.'**
  String get noDeviceKeysCachedYet;

  /// No description provided for @deviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Device {deviceId}'**
  String deviceTitle(Object deviceId);

  /// No description provided for @deviceFpStatus.
  ///
  /// In en, this message translates to:
  /// **'fp: {fp}\n{status}'**
  String deviceFpStatus(Object fp, Object status);

  /// No description provided for @verifiedLower.
  ///
  /// In en, this message translates to:
  /// **'verified'**
  String get verifiedLower;

  /// No description provided for @unverifiedLower.
  ///
  /// In en, this message translates to:
  /// **'unverified'**
  String get unverifiedLower;

  /// No description provided for @keysOfflineIdTemporary.
  ///
  /// In en, this message translates to:
  /// **'Keys service is offline. ID may be temporary in dev mode.'**
  String get keysOfflineIdTemporary;

  /// No description provided for @serverKeysLabel.
  ///
  /// In en, this message translates to:
  /// **'Server (Keys)'**
  String get serverKeysLabel;

  /// No description provided for @nicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nicknameLabel;

  /// No description provided for @identityFingerprintLabel.
  ///
  /// In en, this message translates to:
  /// **'Identity fingerprint'**
  String get identityFingerprintLabel;

  /// No description provided for @scanToAddVerifyContact.
  ///
  /// In en, this message translates to:
  /// **'Scan to add/verify this contact'**
  String get scanToAddVerifyContact;

  /// No description provided for @mySecretlyId.
  ///
  /// In en, this message translates to:
  /// **'My Secretly ID'**
  String get mySecretlyId;

  /// No description provided for @deviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get deviceId;

  /// No description provided for @recoveryKit.
  ///
  /// In en, this message translates to:
  /// **'Recovery Kit'**
  String get recoveryKit;

  /// No description provided for @safeBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get safeBackupTitle;

  /// No description provided for @safeBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup stored on the server'**
  String get safeBackupSubtitle;

  /// No description provided for @safeBackupIntro.
  ///
  /// In en, this message translates to:
  /// **'Create an encrypted backup locally or on the server. You can restore later from a file or Secretly ID.'**
  String get safeBackupIntro;

  /// No description provided for @safeBackupUploadNow.
  ///
  /// In en, this message translates to:
  /// **'Upload backup now'**
  String get safeBackupUploadNow;

  /// No description provided for @safeBackupRestoreFromServer.
  ///
  /// In en, this message translates to:
  /// **'Restore from server'**
  String get safeBackupRestoreFromServer;

  /// No description provided for @safeBackupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from server backup'**
  String get safeBackupRestoreTitle;

  /// No description provided for @safeBackupRestoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore account?'**
  String get safeBackupRestoreConfirmTitle;

  /// No description provided for @safeBackupRestoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove local chats/contacts on this device and restore the account from the selected backup. The app will restart automatically.'**
  String get safeBackupRestoreConfirmBody;

  /// No description provided for @safeBackupUploaded.
  ///
  /// In en, this message translates to:
  /// **'Backup uploaded'**
  String get safeBackupUploaded;

  /// No description provided for @safeBackupUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup upload failed'**
  String get safeBackupUploadFailed;

  /// No description provided for @safeBackupUploadFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Backup upload failed: {error}'**
  String safeBackupUploadFailedWithError(Object error);

  /// No description provided for @safeBackupNotFound.
  ///
  /// In en, this message translates to:
  /// **'No server backup found for this Secretly ID'**
  String get safeBackupNotFound;

  /// No description provided for @exportRecoveryKit.
  ///
  /// In en, this message translates to:
  /// **'Export Recovery Kit'**
  String get exportRecoveryKit;

  /// No description provided for @exportRecoveryKitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted QR for account recovery'**
  String get exportRecoveryKitSubtitle;

  /// No description provided for @restoreRecoveryKit.
  ///
  /// In en, this message translates to:
  /// **'Restore from Recovery Kit'**
  String get restoreRecoveryKit;

  /// No description provided for @restoreRecoveryKitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wipes local data and restores this Secretly ID'**
  String get restoreRecoveryKitSubtitle;

  /// No description provided for @recoveryPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery password'**
  String get recoveryPasswordTitle;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanQr;

  /// No description provided for @invalidRecoveryKit.
  ///
  /// In en, this message translates to:
  /// **'Invalid recovery kit'**
  String get invalidRecoveryKit;

  /// No description provided for @wrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get wrongPassword;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore account?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove local chats/contacts on this device and restore the account from the recovery kit.'**
  String get restoreConfirmBody;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get darkTheme;

  /// No description provided for @darkThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the same accent tint in dark mode.'**
  String get darkThemeSubtitle;

  /// No description provided for @blockUnverified.
  ///
  /// In en, this message translates to:
  /// **'Block sending to unverified contacts'**
  String get blockUnverified;

  /// No description provided for @blockUnverifiedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Strict mode: in one-to-one chats, only send to contacts whose keys you checked yourself. Does not apply to groups.'**
  String get blockUnverifiedSubtitle;

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsers;

  /// No description provided for @resetProfile.
  ///
  /// In en, this message translates to:
  /// **'Reset profile'**
  String get resetProfile;

  /// No description provided for @resetProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fix server/account mismatch by creating a new Secretly ID'**
  String get resetProfileSubtitle;

  /// No description provided for @resetProfileDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset profile?'**
  String get resetProfileDialogTitle;

  /// No description provided for @resetProfileDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove local chats/contacts/requests on this device and create a new Secretly ID.\n\nUse this when you changed APK/server and messages started failing.'**
  String get resetProfileDialogBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @queryLabel.
  ///
  /// In en, this message translates to:
  /// **'Query'**
  String get queryLabel;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// No description provided for @notificationActionMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark Read'**
  String get notificationActionMarkRead;

  /// No description provided for @addCaption.
  ///
  /// In en, this message translates to:
  /// **'Add a caption'**
  String get addCaption;

  /// No description provided for @uploadCanceled.
  ///
  /// In en, this message translates to:
  /// **'Upload canceled'**
  String get uploadCanceled;

  /// No description provided for @attachmentFinalizeTimeout.
  ///
  /// In en, this message translates to:
  /// **'Network is unstable: upload finished, but send confirmation timed out. Try again.'**
  String get attachmentFinalizeTimeout;

  /// No description provided for @attachmentTransferUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t transfer the attachment right now. Check internet/server and try again.'**
  String get attachmentTransferUnavailable;

  /// No description provided for @attachmentSendUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Attachment sending is not ready yet. Try again.'**
  String get attachmentSendUnavailable;

  /// No description provided for @attachmentContactSyncPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for contact identity sync. Ask the contact to send one more message and try again.'**
  String get attachmentContactSyncPending;

  /// No description provided for @attachmentContactBlocked.
  ///
  /// In en, this message translates to:
  /// **'This contact is blocked.'**
  String get attachmentContactBlocked;

  /// No description provided for @attachmentRecipientNotFound.
  ///
  /// In en, this message translates to:
  /// **'Recipient profile was not found on this server. Check Secretly ID and make sure both devices use the same server.'**
  String get attachmentRecipientNotFound;

  /// No description provided for @attachmentRecipientNoDevices.
  ///
  /// In en, this message translates to:
  /// **'Recipient has no registered devices yet. Ask the contact to open Secretly and try again.'**
  String get attachmentRecipientNoDevices;

  /// No description provided for @attachmentNoDeliverableDevices.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t deliver the attachment to any recipient device. Try again.'**
  String get attachmentNoDeliverableDevices;

  /// No description provided for @attachmentActionGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the attachment. Try again.'**
  String get attachmentActionGeneric;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @attach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attach;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @attachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get attachment;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get downloading;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(Object error);

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to: {path}'**
  String savedTo(Object path);

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @decrypting.
  ///
  /// In en, this message translates to:
  /// **'Decrypting…'**
  String get decrypting;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploading;

  /// No description provided for @uploadTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Upload timed out. Check internet/server and try again.'**
  String get uploadTimedOut;

  /// No description provided for @uploadingBytes.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {sent} / {total} bytes'**
  String uploadingBytes(Object sent, Object total);

  /// No description provided for @requestsInfo.
  ///
  /// In en, this message translates to:
  /// **'This chat is in Requests. Accept to reply, or block to ignore.'**
  String get requestsInfo;

  /// No description provided for @verifyRequired.
  ///
  /// In en, this message translates to:
  /// **'Verify required'**
  String get verifyRequired;

  /// No description provided for @verifyContact.
  ///
  /// In en, this message translates to:
  /// **'Verify contact'**
  String get verifyContact;

  /// No description provided for @muteNotifications.
  ///
  /// In en, this message translates to:
  /// **'Mute notifications'**
  String get muteNotifications;

  /// No description provided for @unmuteNotifications.
  ///
  /// In en, this message translates to:
  /// **'Unmute notifications'**
  String get unmuteNotifications;

  /// No description provided for @setContactPhoto.
  ///
  /// In en, this message translates to:
  /// **'Set contact photo'**
  String get setContactPhoto;

  /// No description provided for @removeContactPhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove contact photo'**
  String get removeContactPhoto;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get blockUser;

  /// No description provided for @unblockUser.
  ///
  /// In en, this message translates to:
  /// **'Unblock user'**
  String get unblockUser;

  /// No description provided for @deleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get deleteChat;

  /// No description provided for @missingRecipient.
  ///
  /// In en, this message translates to:
  /// **'Missing recipient'**
  String get missingRecipient;

  /// No description provided for @contactNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Their security code has changed. Check it to keep sending.'**
  String get contactNotVerified;

  /// No description provided for @safetyNumberChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Security code has changed'**
  String get safetyNumberChangedTitle;

  /// No description provided for @safetyNumberChangedBody.
  ///
  /// In en, this message translates to:
  /// **'You checked this contact\'s code before. Their keys are new now — that usually happens after they reinstall the app or switch phones. Your chat stays encrypted either way. Compare the code again if you want to be sure it is still them.'**
  String get safetyNumberChangedBody;

  /// No description provided for @safetyNumberStrictBody.
  ///
  /// In en, this message translates to:
  /// **'You turned on “Require verification before sending”. Compare this contact\'s code to send them messages.'**
  String get safetyNumberStrictBody;

  /// No description provided for @sendAnyway.
  ///
  /// In en, this message translates to:
  /// **'Send anyway'**
  String get sendAnyway;

  /// No description provided for @alsoDeleteChat.
  ///
  /// In en, this message translates to:
  /// **'Also delete chat'**
  String get alsoDeleteChat;

  /// No description provided for @unblockUserConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Unblock user?'**
  String get unblockUserConfirmTitle;

  /// No description provided for @blockUserConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block user?'**
  String get blockUserConfirmTitle;

  /// No description provided for @deleteChatConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete chat?'**
  String get deleteChatConfirmTitle;

  /// No description provided for @deleteChatConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the chat from this device only.'**
  String get deleteChatConfirmBody;

  /// No description provided for @attachFailed.
  ///
  /// In en, this message translates to:
  /// **'Attach failed: {error}'**
  String attachFailed(Object error);

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed: {error}'**
  String sendFailed(Object error);

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String actionFailed(Object error);

  /// No description provided for @roomPolicyNotMember.
  ///
  /// In en, this message translates to:
  /// **'You are no longer a participant in this room.'**
  String get roomPolicyNotMember;

  /// No description provided for @roomPolicyAdminsOnly.
  ///
  /// In en, this message translates to:
  /// **'Only room owners and admins can do that in this room.'**
  String get roomPolicyAdminsOnly;

  /// No description provided for @roomPolicyTextMessagesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Your role cannot send text messages in this room.'**
  String get roomPolicyTextMessagesDisabled;

  /// No description provided for @roomPolicyMediaDisabled.
  ///
  /// In en, this message translates to:
  /// **'Your role cannot send media in this room.'**
  String get roomPolicyMediaDisabled;

  /// No description provided for @roomPolicyReactionsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Reactions are disabled in this room.'**
  String get roomPolicyReactionsDisabled;

  /// No description provided for @roomPolicyReactionNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This reaction is not allowed in this room.'**
  String get roomPolicyReactionNotAllowed;

  /// No description provided for @roomPolicyPinDenied.
  ///
  /// In en, this message translates to:
  /// **'Only admins can pin messages in this room.'**
  String get roomPolicyPinDenied;

  /// No description provided for @roomPolicyAddMembersDenied.
  ///
  /// In en, this message translates to:
  /// **'Only admins can add participants to this room.'**
  String get roomPolicyAddMembersDenied;

  /// No description provided for @roomPolicyChangeInfoDenied.
  ///
  /// In en, this message translates to:
  /// **'Only admins can change the group profile.'**
  String get roomPolicyChangeInfoDenied;

  /// No description provided for @roomPolicySlowMode.
  ///
  /// In en, this message translates to:
  /// **'Slow mode is enabled. Try again in {seconds}s.'**
  String roomPolicySlowMode(Object seconds);

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @attachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Attachment is too large ({mb} MB).'**
  String attachmentTooLarge(Object mb);

  /// No description provided for @attachmentFileMissing.
  ///
  /// In en, this message translates to:
  /// **'File is not available anymore.'**
  String get attachmentFileMissing;

  /// No description provided for @foundPrefix.
  ///
  /// In en, this message translates to:
  /// **'Found: {hit}'**
  String foundPrefix(Object hit);

  /// No description provided for @contactDetailsChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get contactDetailsChat;

  /// No description provided for @contactDetailsSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get contactDetailsSound;

  /// No description provided for @contactDetailsCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get contactDetailsCall;

  /// No description provided for @contactDetailsVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get contactDetailsVideo;

  /// No description provided for @contactDetailsUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get contactDetailsUsernameLabel;

  /// No description provided for @contactDetailsAddToContacts.
  ///
  /// In en, this message translates to:
  /// **'Add to contacts'**
  String get contactDetailsAddToContacts;

  /// No description provided for @contactDetailsMediaTab.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get contactDetailsMediaTab;

  /// No description provided for @contactDetailsFilesTab.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get contactDetailsFilesTab;

  /// No description provided for @contactDetailsNoMedia.
  ///
  /// In en, this message translates to:
  /// **'No media'**
  String get contactDetailsNoMedia;

  /// No description provided for @contactDetailsNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get contactDetailsNoFiles;

  /// No description provided for @contactDetailsStatusRecently.
  ///
  /// In en, this message translates to:
  /// **'last seen recently'**
  String get contactDetailsStatusRecently;

  /// No description provided for @contactDetailsStatusAt.
  ///
  /// In en, this message translates to:
  /// **'last seen at {time}'**
  String contactDetailsStatusAt(Object time);

  /// No description provided for @contactDetailsAutoDelete.
  ///
  /// In en, this message translates to:
  /// **'Auto-delete'**
  String get contactDetailsAutoDelete;

  /// No description provided for @contactDetailsShareContact.
  ///
  /// In en, this message translates to:
  /// **'Share contact'**
  String get contactDetailsShareContact;

  /// No description provided for @contactDetailsEditContact.
  ///
  /// In en, this message translates to:
  /// **'Edit contact'**
  String get contactDetailsEditContact;

  /// No description provided for @contactDetailsDeleteContact.
  ///
  /// In en, this message translates to:
  /// **'Delete contact'**
  String get contactDetailsDeleteContact;

  /// No description provided for @contactDetailsSendGift.
  ///
  /// In en, this message translates to:
  /// **'Send gift'**
  String get contactDetailsSendGift;

  /// No description provided for @contactDetailsStartSecretChat.
  ///
  /// In en, this message translates to:
  /// **'Start secret chat'**
  String get contactDetailsStartSecretChat;

  /// No description provided for @contactDetailsCreateShortcut.
  ///
  /// In en, this message translates to:
  /// **'Create shortcut'**
  String get contactDetailsCreateShortcut;

  /// No description provided for @contactDetailsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactDetailsNameLabel;

  /// No description provided for @contactDetailsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get contactDetailsSave;

  /// No description provided for @contactDetailsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete contact?'**
  String get contactDetailsDeleteConfirmTitle;

  /// No description provided for @contactAutoDeleteOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get contactAutoDeleteOff;

  /// No description provided for @contactAutoDelete1Day.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get contactAutoDelete1Day;

  /// No description provided for @contactAutoDelete7Days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get contactAutoDelete7Days;

  /// No description provided for @contactAutoDelete30Days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get contactAutoDelete30Days;

  /// No description provided for @contactEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit contact'**
  String get contactEditTitle;

  /// No description provided for @contactEditDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get contactEditDone;

  /// No description provided for @contactEditNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactEditNameLabel;

  /// No description provided for @contactEditAssignEmoji.
  ///
  /// In en, this message translates to:
  /// **'Assign emoji'**
  String get contactEditAssignEmoji;

  /// No description provided for @contactEditClearEmoji.
  ///
  /// In en, this message translates to:
  /// **'Clear emoji'**
  String get contactEditClearEmoji;

  /// No description provided for @contactEditSetPhoto.
  ///
  /// In en, this message translates to:
  /// **'Set photo'**
  String get contactEditSetPhoto;

  /// No description provided for @chatMenuReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatMenuReply;

  /// No description provided for @chatMenuCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatMenuCopy;

  /// No description provided for @chatMenuForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get chatMenuForward;

  /// No description provided for @chatMenuPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get chatMenuPin;

  /// No description provided for @chatMenuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatMenuDelete;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @diagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Status, binding, timestamps'**
  String get diagnosticsSubtitle;

  /// No description provided for @sendLater.
  ///
  /// In en, this message translates to:
  /// **'Send later'**
  String get sendLater;

  /// No description provided for @sendSilently.
  ///
  /// In en, this message translates to:
  /// **'Send without sound'**
  String get sendSilently;

  /// No description provided for @scheduledSendToday.
  ///
  /// In en, this message translates to:
  /// **'Send today at {time}'**
  String scheduledSendToday(Object time);

  /// No description provided for @scheduledSendOn.
  ///
  /// In en, this message translates to:
  /// **'Send {date} at {time}'**
  String scheduledSendOn(Object date, Object time);

  /// No description provided for @repeatNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get repeatNever;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @onboardingBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBackTooltip;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A next-generation messenger.\nComplete privacy. No compromises.'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create new account'**
  String get onboardingCreateAccount;

  /// No description provided for @onboardingAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account'**
  String get onboardingAlreadyHaveAccount;

  /// No description provided for @onboardingFeatureE2eTitle.
  ///
  /// In en, this message translates to:
  /// **'E2E encryption'**
  String get onboardingFeatureE2eTitle;

  /// No description provided for @onboardingFeatureE2eBody.
  ///
  /// In en, this message translates to:
  /// **'Messages are encrypted on your device. Only you have the keys.'**
  String get onboardingFeatureE2eBody;

  /// No description provided for @onboardingFeaturePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Full anonymity'**
  String get onboardingFeaturePrivacyTitle;

  /// No description provided for @onboardingFeaturePrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'No phone number. No link to personal data.'**
  String get onboardingFeaturePrivacyBody;

  /// No description provided for @onboardingFeatureRelayTitle.
  ///
  /// In en, this message translates to:
  /// **'No middlemen'**
  String get onboardingFeatureRelayTitle;

  /// No description provided for @onboardingFeatureRelayBody.
  ///
  /// In en, this message translates to:
  /// **'The relay server does not store messages. It only passes them through.'**
  String get onboardingFeatureRelayBody;

  /// No description provided for @onboardingProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get onboardingProfileTitle;

  /// No description provided for @onboardingProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How other users will see you'**
  String get onboardingProfileSubtitle;

  /// No description provided for @onboardingProfileNameSection.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get onboardingProfileNameSection;

  /// No description provided for @onboardingProfileNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name or nickname'**
  String get onboardingProfileNameHint;

  /// No description provided for @onboardingNotificationsSection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get onboardingNotificationsSection;

  /// No description provided for @onboardingMessageNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Message notifications'**
  String get onboardingMessageNotificationsTitle;

  /// No description provided for @onboardingMessageNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive push notifications from Secretly'**
  String get onboardingMessageNotificationsSubtitle;

  /// No description provided for @onboardingIncomingCallsTitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming calls'**
  String get onboardingIncomingCallsTitle;

  /// No description provided for @onboardingIncomingCallsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Accept calls from contacts'**
  String get onboardingIncomingCallsSubtitle;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @onboardingBackupSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save backup settings'**
  String get onboardingBackupSaveFailed;

  /// No description provided for @backupPasswordRequirements.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 ASCII characters, one uppercase letter, and one special character. No leading or trailing spaces.'**
  String get backupPasswordRequirements;

  /// No description provided for @backupPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least {minLength} characters.'**
  String backupPasswordTooShort(Object minLength);

  /// No description provided for @backupPasswordTooLong.
  ///
  /// In en, this message translates to:
  /// **'Password must be no longer than {maxLength} characters.'**
  String backupPasswordTooLong(Object maxLength);

  /// No description provided for @backupPasswordNonAscii.
  ///
  /// In en, this message translates to:
  /// **'Use only Latin letters, digits, and ASCII symbols.'**
  String get backupPasswordNonAscii;

  /// No description provided for @backupPasswordOuterWhitespace.
  ///
  /// In en, this message translates to:
  /// **'Remove leading or trailing spaces from the password.'**
  String get backupPasswordOuterWhitespace;

  /// No description provided for @backupPasswordMissingUppercase.
  ///
  /// In en, this message translates to:
  /// **'Add at least one uppercase A-Z letter.'**
  String get backupPasswordMissingUppercase;

  /// No description provided for @backupPasswordMissingSpecial.
  ///
  /// In en, this message translates to:
  /// **'Add at least one special character, such as !, #, or ?.'**
  String get backupPasswordMissingSpecial;

  /// No description provided for @onboardingBackupPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get onboardingBackupPasswordTitle;

  /// No description provided for @onboardingPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get onboardingPasswordsDoNotMatch;

  /// No description provided for @onboardingBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get onboardingBackupTitle;

  /// No description provided for @onboardingBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Protect your chats from data loss.\nEven when you change devices.'**
  String get onboardingBackupSubtitle;

  /// No description provided for @onboardingAutoBackupSection.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get onboardingAutoBackupSection;

  /// No description provided for @onboardingAutoBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup'**
  String get onboardingAutoBackupTitle;

  /// No description provided for @onboardingAutoBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically save a backup'**
  String get onboardingAutoBackupSubtitle;

  /// No description provided for @onboardingStorageTypeSection.
  ///
  /// In en, this message translates to:
  /// **'Storage type'**
  String get onboardingStorageTypeSection;

  /// No description provided for @onboardingBackupMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up media'**
  String get onboardingBackupMediaTitle;

  /// No description provided for @onboardingBackupMediaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Photos, videos, files, and avatars are included only in local backups'**
  String get onboardingBackupMediaSubtitle;

  /// No description provided for @onboardingFrequencySection.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get onboardingFrequencySection;

  /// No description provided for @onboardingEnterSecretly.
  ///
  /// In en, this message translates to:
  /// **'Enter Secretly'**
  String get onboardingEnterSecretly;

  /// No description provided for @onboardingSkipBackup.
  ///
  /// In en, this message translates to:
  /// **'Skip backup setup'**
  String get onboardingSkipBackup;

  /// No description provided for @onboardingSecretlyIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Secretly ID copied'**
  String get onboardingSecretlyIdCopied;

  /// No description provided for @onboardingRegistrationCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration complete'**
  String get onboardingRegistrationCompleteTitle;

  /// No description provided for @onboardingRegistrationCompleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save your Secretly ID now. You need it to restore your account and backup on a new device.'**
  String get onboardingRegistrationCompleteSubtitle;

  /// No description provided for @onboardingYourSecretlyId.
  ///
  /// In en, this message translates to:
  /// **'Your Secretly ID'**
  String get onboardingYourSecretlyId;

  /// No description provided for @onboardingCopyId.
  ///
  /// In en, this message translates to:
  /// **'Copy ID'**
  String get onboardingCopyId;

  /// No description provided for @onboardingRecoveryWarning.
  ///
  /// In en, this message translates to:
  /// **'Without your Secretly ID and backup password, restoring the server backup is impossible. Save the ID in a secure place and do not forget the password.'**
  String get onboardingRecoveryWarning;

  /// No description provided for @onboardingStorageCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get onboardingStorageCloud;

  /// No description provided for @onboardingStorageCloudSubtitle.
  ///
  /// In en, this message translates to:
  /// **'On the Secretly server'**
  String get onboardingStorageCloudSubtitle;

  /// No description provided for @onboardingStorageLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get onboardingStorageLocal;

  /// No description provided for @onboardingStorageLocalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get onboardingStorageLocalSubtitle;

  /// No description provided for @onboardingInterval6Hours.
  ///
  /// In en, this message translates to:
  /// **'6 hours'**
  String get onboardingInterval6Hours;

  /// No description provided for @onboardingInterval12Hours.
  ///
  /// In en, this message translates to:
  /// **'12 hours'**
  String get onboardingInterval12Hours;

  /// No description provided for @onboardingIntervalEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get onboardingIntervalEveryDay;

  /// No description provided for @onboardingIntervalEvery3Days.
  ///
  /// In en, this message translates to:
  /// **'Every 3 days'**
  String get onboardingIntervalEvery3Days;

  /// No description provided for @onboardingIntervalWeekly.
  ///
  /// In en, this message translates to:
  /// **'Once a week'**
  String get onboardingIntervalWeekly;

  /// No description provided for @onboardingBackupLocalCandidate.
  ///
  /// In en, this message translates to:
  /// **'Secretly local backup'**
  String get onboardingBackupLocalCandidate;

  /// No description provided for @onboardingDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get onboardingDownloads;

  /// No description provided for @onboardingDeviceFolder.
  ///
  /// In en, this message translates to:
  /// **'Device folder'**
  String get onboardingDeviceFolder;

  /// No description provided for @onboardingNoBackupsFound.
  ///
  /// In en, this message translates to:
  /// **'No backups found on this device'**
  String get onboardingNoBackupsFound;

  /// No description provided for @onboardingFoundBackups.
  ///
  /// In en, this message translates to:
  /// **'Found backups'**
  String get onboardingFoundBackups;

  /// No description provided for @onboardingNoBackupsFoundBody.
  ///
  /// In en, this message translates to:
  /// **'Secretly checked local app backups and the Downloads folder. If the file is somewhere else, choose it manually.'**
  String get onboardingNoBackupsFoundBody;

  /// No description provided for @chooseManually.
  ///
  /// In en, this message translates to:
  /// **'Choose manually'**
  String get chooseManually;

  /// No description provided for @onboardingChooseBackupFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a Secretly backup file'**
  String get onboardingChooseBackupFileTitle;

  /// No description provided for @onboardingReadBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the backup file'**
  String get onboardingReadBackupFailed;

  /// No description provided for @onboardingServerBackupNotFound.
  ///
  /// In en, this message translates to:
  /// **'Backup was not found on the server'**
  String get onboardingServerBackupNotFound;

  /// No description provided for @onboardingRestoreThisBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get onboardingRestoreThisBackupTitle;

  /// No description provided for @onboardingRestoreThisBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Current local data on this device will be replaced.'**
  String get onboardingRestoreThisBackupBody;

  /// No description provided for @onboardingSecretlyIdSummary.
  ///
  /// In en, this message translates to:
  /// **'Secretly ID: {profileId}'**
  String onboardingSecretlyIdSummary(Object profileId);

  /// No description provided for @onboardingContactsSummary.
  ///
  /// In en, this message translates to:
  /// **'Contacts: {count}'**
  String onboardingContactsSummary(Object count);

  /// No description provided for @onboardingMessagesSummary.
  ///
  /// In en, this message translates to:
  /// **'Messages: {count}'**
  String onboardingMessagesSummary(Object count);

  /// No description provided for @onboardingChatsSummary.
  ///
  /// In en, this message translates to:
  /// **'Chats: {count}'**
  String onboardingChatsSummary(Object count);

  /// No description provided for @onboardingMediaFilesSummary.
  ///
  /// In en, this message translates to:
  /// **'Media files: {count}'**
  String onboardingMediaFilesSummary(Object count);

  /// No description provided for @onboardingBrokenBackup.
  ///
  /// In en, this message translates to:
  /// **'Damaged or invalid backup file'**
  String get onboardingBrokenBackup;

  /// No description provided for @onboardingRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed. Try again.'**
  String get onboardingRestoreFailed;

  /// No description provided for @onboardingRestoreLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get onboardingRestoreLoginTitle;

  /// No description provided for @onboardingRestoreLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore chats and settings\nfrom a previously created backup.'**
  String get onboardingRestoreLoginSubtitle;

  /// No description provided for @onboardingRestoreMediaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For future local backups: photos, videos, files, and avatars will be added only if this is enabled.'**
  String get onboardingRestoreMediaSubtitle;

  /// No description provided for @onboardingRestoreFromCloudTitle.
  ///
  /// In en, this message translates to:
  /// **'From Secretly cloud'**
  String get onboardingRestoreFromCloudTitle;

  /// No description provided for @onboardingRestoreFromCloudSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your Secretly ID and backup password; data will be downloaded from the server'**
  String get onboardingRestoreFromCloudSubtitle;

  /// No description provided for @onboardingRestoreFromDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Find backup on this device'**
  String get onboardingRestoreFromDeviceTitle;

  /// No description provided for @onboardingRestoreFromDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secretly will check local backups and Downloads automatically'**
  String get onboardingRestoreFromDeviceSubtitle;

  /// No description provided for @onboardingRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring...'**
  String get onboardingRestoring;

  /// No description provided for @onboardingRestoreFromServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from server'**
  String get onboardingRestoreFromServerTitle;

  /// No description provided for @callRecordOutgoingVideoCall.
  ///
  /// In en, this message translates to:
  /// **'Outgoing video call'**
  String get callRecordOutgoingVideoCall;

  /// No description provided for @callRecordOutgoingCall.
  ///
  /// In en, this message translates to:
  /// **'Outgoing call'**
  String get callRecordOutgoingCall;

  /// No description provided for @callRecordIncomingVideoCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming video call'**
  String get callRecordIncomingVideoCall;

  /// No description provided for @callRecordIncomingCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get callRecordIncomingCall;

  /// No description provided for @callRecordMissedCall.
  ///
  /// In en, this message translates to:
  /// **'Missed call'**
  String get callRecordMissedCall;

  /// No description provided for @callRecordDeclinedCall.
  ///
  /// In en, this message translates to:
  /// **'Call declined'**
  String get callRecordDeclinedCall;

  /// No description provided for @callRecordBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get callRecordBusy;

  /// No description provided for @callRecordFailed.
  ///
  /// In en, this message translates to:
  /// **'Call failed'**
  String get callRecordFailed;

  /// No description provided for @callRecordCanceled.
  ///
  /// In en, this message translates to:
  /// **'Call canceled'**
  String get callRecordCanceled;

  /// No description provided for @callRecordOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing call'**
  String get callRecordOngoing;

  /// No description provided for @safeBackupInvalidBackup.
  ///
  /// In en, this message translates to:
  /// **'Invalid Secretly backup'**
  String get safeBackupInvalidBackup;

  /// No description provided for @recoveryKitPrepareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to prepare a Recovery Kit on this device.'**
  String get recoveryKitPrepareFailed;

  /// No description provided for @safeBackupPreviewProfileId.
  ///
  /// In en, this message translates to:
  /// **'Secretly ID: {profileId}'**
  String safeBackupPreviewProfileId(String profileId);

  /// No description provided for @safeBackupPreviewContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts: {count}'**
  String safeBackupPreviewContacts(int count);

  /// No description provided for @safeBackupPreviewServer.
  ///
  /// In en, this message translates to:
  /// **'Server: {server}'**
  String safeBackupPreviewServer(String server);

  /// No description provided for @safeBackupPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup preview:'**
  String get safeBackupPreviewTitle;

  /// No description provided for @safeBackupSavedToFiles.
  ///
  /// In en, this message translates to:
  /// **'Backup saved to Secretly Files'**
  String get safeBackupSavedToFiles;

  /// No description provided for @safeBackupExportCanceled.
  ///
  /// In en, this message translates to:
  /// **'Backup export canceled'**
  String get safeBackupExportCanceled;

  /// No description provided for @safeBackupExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup export failed: {error}'**
  String safeBackupExportFailed(Object error);

  /// No description provided for @safeBackupCreateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get safeBackupCreateDialogTitle;

  /// No description provided for @safeBackupServerDestination.
  ///
  /// In en, this message translates to:
  /// **'Server backup'**
  String get safeBackupServerDestination;

  /// No description provided for @safeBackupLocalDestination.
  ///
  /// In en, this message translates to:
  /// **'Local backup'**
  String get safeBackupLocalDestination;

  /// No description provided for @safeBackupRestoreDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get safeBackupRestoreDialogTitle;

  /// No description provided for @safeBackupRestoreFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Restore from device'**
  String get safeBackupRestoreFromDevice;

  /// No description provided for @safeBackupDownloadsLocation.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get safeBackupDownloadsLocation;

  /// No description provided for @safeBackupDeviceFolderLocation.
  ///
  /// In en, this message translates to:
  /// **'Device folder'**
  String get safeBackupDeviceFolderLocation;

  /// No description provided for @safeBackupChooseManualHint.
  ///
  /// In en, this message translates to:
  /// **'Secretly checked local app backups and Downloads. You can still choose a file manually if it is stored elsewhere.'**
  String get safeBackupChooseManualHint;

  /// No description provided for @safeBackupChooseManually.
  ///
  /// In en, this message translates to:
  /// **'Choose manually'**
  String get safeBackupChooseManually;

  /// No description provided for @safeBackupReadFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read backup file: {error}'**
  String safeBackupReadFileFailed(Object error);

  /// No description provided for @safeBackupFrequencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Save frequency'**
  String get safeBackupFrequencyTitle;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @safeBackupEnableAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable auto-backup'**
  String get safeBackupEnableAutoTitle;

  /// No description provided for @safeBackupEnableAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Runs in the app while online; encrypted with your password'**
  String get safeBackupEnableAutoSubtitle;

  /// No description provided for @safeBackupUploadToServer.
  ///
  /// In en, this message translates to:
  /// **'Upload to server'**
  String get safeBackupUploadToServer;

  /// No description provided for @safeBackupSaveOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Save on this device'**
  String get safeBackupSaveOnDevice;

  /// No description provided for @safeBackupPasswordConfigured.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup password: configured'**
  String get safeBackupPasswordConfigured;

  /// No description provided for @safeBackupPasswordNotSet.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup password: not set'**
  String get safeBackupPasswordNotSet;

  /// No description provided for @safeBackupPasswordSaved.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup password saved'**
  String get safeBackupPasswordSaved;

  /// No description provided for @genericFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String genericFailed(Object error);

  /// No description provided for @safeBackupSetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get safeBackupSetPassword;

  /// No description provided for @safeBackupPasswordRemoved.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup password removed'**
  String get safeBackupPasswordRemoved;

  /// No description provided for @safeBackupClearPassword.
  ///
  /// In en, this message translates to:
  /// **'Clear password'**
  String get safeBackupClearPassword;

  /// No description provided for @safeBackupRunRequested.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup run requested'**
  String get safeBackupRunRequested;

  /// No description provided for @safeBackupRunNow.
  ///
  /// In en, this message translates to:
  /// **'Run auto-backup now'**
  String get safeBackupRunNow;

  /// No description provided for @safeBackupLastAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Last auto-backup: {time}'**
  String safeBackupLastAutoBackup(String time);

  /// No description provided for @safeBackupLastAutoBackupNever.
  ///
  /// In en, this message translates to:
  /// **'Last auto-backup: never'**
  String get safeBackupLastAutoBackupNever;

  /// No description provided for @safeBackupLastDeviceBackup.
  ///
  /// In en, this message translates to:
  /// **'Last device backup: {time}'**
  String safeBackupLastDeviceBackup(String time);

  /// No description provided for @safeBackupLastAutoBackupError.
  ///
  /// In en, this message translates to:
  /// **'Last auto-backup error: {error}'**
  String safeBackupLastAutoBackupError(Object error);

  /// No description provided for @securityScopeAppObject.
  ///
  /// In en, this message translates to:
  /// **'the app'**
  String get securityScopeAppObject;

  /// No description provided for @securityScopePersonalObject.
  ///
  /// In en, this message translates to:
  /// **'Personal chats'**
  String get securityScopePersonalObject;

  /// No description provided for @securityUnlockAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock the app'**
  String get securityUnlockAppTitle;

  /// No description provided for @securityUnlockPersonalTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Personal chats'**
  String get securityUnlockPersonalTitle;

  /// No description provided for @securityUnlockFingerprintAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint unlock starts automatically. If needed, you can use your password below.'**
  String get securityUnlockFingerprintAutoSubtitle;

  /// No description provided for @securityUnlockBiometricPatternAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Native biometrics start automatically first. If needed, you can use your pattern below.'**
  String get securityUnlockBiometricPatternAutoSubtitle;

  /// No description provided for @securityUnlockNativeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm access with native device authentication.'**
  String get securityUnlockNativeSubtitle;

  /// No description provided for @securityUnlockPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to open {scopeName}.'**
  String securityUnlockPasswordSubtitle(String scopeName);

  /// No description provided for @securityUnlockPatternSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Draw your pattern to access {scopeName}.'**
  String securityUnlockPatternSubtitle(String scopeName);

  /// No description provided for @securityUnlockBiometricSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your identity with native device authentication.'**
  String get securityUnlockBiometricSubtitle;

  /// No description provided for @securityUnlockAppBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to unlock the app'**
  String get securityUnlockAppBiometricReason;

  /// No description provided for @securityUnlockPersonalBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to open Personal chats'**
  String get securityUnlockPersonalBiometricReason;

  /// No description provided for @securityUnlockPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'That password did not match. Try again.'**
  String get securityUnlockPasswordMismatch;

  /// No description provided for @securityUnlockPatternMismatch.
  ///
  /// In en, this message translates to:
  /// **'That pattern did not match.'**
  String get securityUnlockPatternMismatch;

  /// No description provided for @securityUnlockNativeIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Native authentication was not completed.'**
  String get securityUnlockNativeIncomplete;

  /// No description provided for @securityPasswordContinueHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to continue'**
  String get securityPasswordContinueHint;

  /// No description provided for @securityUseFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint'**
  String get securityUseFingerprint;

  /// No description provided for @securityUsePassword.
  ///
  /// In en, this message translates to:
  /// **'Use password'**
  String get securityUsePassword;

  /// No description provided for @securityClearPattern.
  ///
  /// In en, this message translates to:
  /// **'Clear pattern'**
  String get securityClearPattern;

  /// No description provided for @securityConnectFourDots.
  ///
  /// In en, this message translates to:
  /// **'Connect at least 4 dots.'**
  String get securityConnectFourDots;

  /// No description provided for @securityPasswordMinFourChars.
  ///
  /// In en, this message translates to:
  /// **'Use at least 4 characters.'**
  String get securityPasswordMinFourChars;

  /// No description provided for @securityPasswordsMismatchFull.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get securityPasswordsMismatchFull;

  /// No description provided for @securityPasswordSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Password for {scopeName}'**
  String securityPasswordSetupTitle(String scopeName);

  /// No description provided for @securityPasswordSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'The password is stored only in the secure device store.'**
  String get securityPasswordSetupDescription;

  /// No description provided for @securityNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get securityNewPassword;

  /// No description provided for @securityRepeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get securityRepeatPassword;

  /// No description provided for @securitySavePassword.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get securitySavePassword;

  /// No description provided for @securityPatternSetupInstruction.
  ///
  /// In en, this message translates to:
  /// **'Draw a pattern with at least 4 dots.'**
  String get securityPatternSetupInstruction;

  /// No description provided for @securityPatternSetupRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat the pattern to confirm it.'**
  String get securityPatternSetupRepeat;

  /// No description provided for @securityPatternMinFourDots.
  ///
  /// In en, this message translates to:
  /// **'Use at least 4 dots.'**
  String get securityPatternMinFourDots;

  /// No description provided for @securityPatternMismatchStartOver.
  ///
  /// In en, this message translates to:
  /// **'The patterns did not match. Start again.'**
  String get securityPatternMismatchStartOver;

  /// No description provided for @securityPatternSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Pattern lock for {scopeName}'**
  String securityPatternSetupTitle(String scopeName);

  /// No description provided for @securityStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get securityStartOver;

  /// No description provided for @securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityTitle;

  /// No description provided for @securityNativeAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Native authentication'**
  String get securityNativeAuthentication;

  /// No description provided for @securityReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get securityReady;

  /// No description provided for @securityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get securityUnavailable;

  /// No description provided for @securityNativeAvailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Used for Face ID, fingerprint, and native device authentication.'**
  String get securityNativeAvailableDescription;

  /// No description provided for @securityNativeUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Biometric or native device authentication is not available on this device right now.'**
  String get securityNativeUnavailableDescription;

  /// No description provided for @securityAppLockTitle.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get securityAppLockTitle;

  /// No description provided for @securityAppLockDescription.
  ///
  /// In en, this message translates to:
  /// **'Protects app entry and can relock after the app is hidden.'**
  String get securityAppLockDescription;

  /// No description provided for @securityPersonalChatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal chats'**
  String get securityPersonalChatsTitle;

  /// No description provided for @securityPersonalChatsDescription.
  ///
  /// In en, this message translates to:
  /// **'Protects the hidden Personal section and direct entry into personal chats.'**
  String get securityPersonalChatsDescription;

  /// No description provided for @securityAuthEnableAppLockReason.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to enable app lock'**
  String get securityAuthEnableAppLockReason;

  /// No description provided for @securityAuthChangeSettingsReason.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to change security settings'**
  String get securityAuthChangeSettingsReason;

  /// No description provided for @securityAuthProtectPersonalReason.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to protect Personal chats'**
  String get securityAuthProtectPersonalReason;

  /// No description provided for @securityAuthChangePersonalReason.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to change Personal chats protection'**
  String get securityAuthChangePersonalReason;

  /// No description provided for @securityNativeUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'Native authentication is unavailable on this device.'**
  String get securityNativeUnavailableError;

  /// No description provided for @securityBiometricCancelled.
  ///
  /// In en, this message translates to:
  /// **'Biometric confirmation was cancelled.'**
  String get securityBiometricCancelled;

  /// No description provided for @securityProtectionMode.
  ///
  /// In en, this message translates to:
  /// **'Protection mode'**
  String get securityProtectionMode;

  /// No description provided for @securityProtectionModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how access should be protected.'**
  String get securityProtectionModeSubtitle;

  /// No description provided for @securityProtectionModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Passwords and patterns are stored only as strong hashes in secure storage. Biometrics use the native system prompt.'**
  String get securityProtectionModeDescription;

  /// No description provided for @securityProtectionOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get securityProtectionOff;

  /// No description provided for @securityProtectionOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Access without extra protection.'**
  String get securityProtectionOffDescription;

  /// No description provided for @securityPasswordModeDescription.
  ///
  /// In en, this message translates to:
  /// **'A dedicated password to unlock access.'**
  String get securityPasswordModeDescription;

  /// No description provided for @securityPatternModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Pattern lock'**
  String get securityPatternModeTitle;

  /// No description provided for @securityPatternModeDescription.
  ///
  /// In en, this message translates to:
  /// **'A dot pattern similar to Android lock patterns.'**
  String get securityPatternModeDescription;

  /// No description provided for @securityNativePromptDescription.
  ///
  /// In en, this message translates to:
  /// **'The native Face ID, fingerprint, or system device authentication prompt.'**
  String get securityNativePromptDescription;

  /// No description provided for @securityRelockAfterHidden.
  ///
  /// In en, this message translates to:
  /// **'Relock after the app is hidden'**
  String get securityRelockAfterHidden;

  /// No description provided for @securityRelockAfterHiddenDescription.
  ///
  /// In en, this message translates to:
  /// **'If disabled, protection only returns after a full app restart.'**
  String get securityRelockAfterHiddenDescription;

  /// No description provided for @securityGracePeriod.
  ///
  /// In en, this message translates to:
  /// **'Grace period before relock'**
  String get securityGracePeriod;

  /// No description provided for @securityGraceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable while background relock is off.'**
  String get securityGraceUnavailable;

  /// No description provided for @securityAllowQuickUnlockWith.
  ///
  /// In en, this message translates to:
  /// **'Allow quick unlock with {method}'**
  String securityAllowQuickUnlockWith(String method);

  /// No description provided for @securityQuickUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keeps the password or pattern as the main fallback method.'**
  String get securityQuickUnlockSubtitle;

  /// No description provided for @securityChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get securityChangePassword;

  /// No description provided for @securityChangePattern.
  ///
  /// In en, this message translates to:
  /// **'Change pattern'**
  String get securityChangePattern;

  /// No description provided for @securityChangeCredentialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The current protection will be updated as soon as the new secret is confirmed.'**
  String get securityChangeCredentialSubtitle;

  /// No description provided for @securityProtectionActivated.
  ///
  /// In en, this message translates to:
  /// **'Protection was activated immediately.'**
  String get securityProtectionActivated;

  /// No description provided for @securityLockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get securityLockNow;

  /// No description provided for @securitySaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get securitySaveChanges;

  /// No description provided for @securityGraceImmediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get securityGraceImmediately;

  /// No description provided for @securityGraceAfterSeconds.
  ///
  /// In en, this message translates to:
  /// **'After {seconds}s'**
  String securityGraceAfterSeconds(int seconds);

  /// No description provided for @securityGraceAfterMinutes.
  ///
  /// In en, this message translates to:
  /// **'After {minutes}m'**
  String securityGraceAfterMinutes(int minutes);

  /// No description provided for @securityStatusLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get securityStatusLocked;

  /// No description provided for @securityStatusUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get securityStatusUnlocked;

  /// No description provided for @securityAfterHide.
  ///
  /// In en, this message translates to:
  /// **'After hide'**
  String get securityAfterHide;

  /// No description provided for @securityGracePill.
  ///
  /// In en, this message translates to:
  /// **'Grace {seconds}s'**
  String securityGracePill(int seconds);

  /// No description provided for @securityNoProtection.
  ///
  /// In en, this message translates to:
  /// **'No protection'**
  String get securityNoProtection;

  /// No description provided for @securityNativeBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Native biometrics'**
  String get securityNativeBiometrics;

  /// No description provided for @securityBiometricFaceFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Face ID / fingerprint'**
  String get securityBiometricFaceFingerprint;

  /// No description provided for @securityBiometricFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get securityBiometricFingerprint;

  /// No description provided for @securityBiometricNativeDeviceAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Native device authentication'**
  String get securityBiometricNativeDeviceAuthentication;

  /// No description provided for @devicesLinkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link in a browser.'**
  String get devicesLinkOpenFailed;

  /// No description provided for @devicesDesktopDescriptionPrefix.
  ///
  /// In en, this message translates to:
  /// **'You can sign in to the '**
  String get devicesDesktopDescriptionPrefix;

  /// No description provided for @devicesDesktopAppLink.
  ///
  /// In en, this message translates to:
  /// **'Secretly desktop app'**
  String get devicesDesktopAppLink;

  /// No description provided for @devicesDesktopDescriptionSuffix.
  ///
  /// In en, this message translates to:
  /// **' using a QR code.'**
  String get devicesDesktopDescriptionSuffix;

  /// No description provided for @devicesFailureTransportBlocked.
  ///
  /// In en, this message translates to:
  /// **'Transport is blocked for the current server. Switch phone and desktop to the same server and retry.'**
  String get devicesFailureTransportBlocked;

  /// No description provided for @devicesFailureIdentityNotServerBacked.
  ///
  /// In en, this message translates to:
  /// **'Desktop identity is not server-backed yet. Retry in a few seconds.'**
  String get devicesFailureIdentityNotServerBacked;

  /// No description provided for @devicesFailureProfileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Desktop profile is not visible on the server yet. Keep the app open and retry.'**
  String get devicesFailureProfileUnavailable;

  /// No description provided for @devicesFailureDeviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Desktop device is not visible on the server yet. Keep the app open, refresh the QR, and retry.'**
  String get devicesFailureDeviceUnavailable;

  /// No description provided for @devicesFailureCompanionRequired.
  ///
  /// In en, this message translates to:
  /// **'Desktop companion access is not enabled for this profile. Activate it on the primary phone and retry.'**
  String get devicesFailureCompanionRequired;

  /// No description provided for @devicesFailureCompanionLimit.
  ///
  /// In en, this message translates to:
  /// **'Desktop companion limit is already in use for this profile. Remove an old desktop device or increase available seats.'**
  String get devicesFailureCompanionLimit;

  /// No description provided for @devicesFailurePrimaryRequired.
  ///
  /// In en, this message translates to:
  /// **'Create the main account on a phone first, then link desktop with QR.'**
  String get devicesFailurePrimaryRequired;

  /// No description provided for @devicesFailureInvalidQr.
  ///
  /// In en, this message translates to:
  /// **'This QR is not a device authorization code.'**
  String get devicesFailureInvalidQr;

  /// No description provided for @devicesFailureQrExpired.
  ///
  /// In en, this message translates to:
  /// **'QR code expired. Generate a new one on desktop.'**
  String get devicesFailureQrExpired;

  /// No description provided for @devicesFailureServerMismatch.
  ///
  /// In en, this message translates to:
  /// **'This QR belongs to a different server. Switch phone and desktop to the same server and retry.'**
  String get devicesFailureServerMismatch;

  /// No description provided for @devicesFailureProfileMismatch.
  ///
  /// In en, this message translates to:
  /// **'Sync bundle targets a different profile. Generate a new QR and retry.'**
  String get devicesFailureProfileMismatch;

  /// No description provided for @devicesFailureRequestNotFound.
  ///
  /// In en, this message translates to:
  /// **'Desktop sync request was not found or already expired. Generate a new QR.'**
  String get devicesFailureRequestNotFound;

  /// No description provided for @devicesFailureSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'QR session expired. Generate a new QR and retry.'**
  String get devicesFailureSessionExpired;

  /// No description provided for @devicesFailureSessionValidation.
  ///
  /// In en, this message translates to:
  /// **'QR session validation failed. Generate a new QR and retry.'**
  String get devicesFailureSessionValidation;

  /// No description provided for @devicesFailureStateMismatch.
  ///
  /// In en, this message translates to:
  /// **'Sync request state no longer matches. Generate a new QR and retry.'**
  String get devicesFailureStateMismatch;

  /// No description provided for @devicesFailureDeviceMismatch.
  ///
  /// In en, this message translates to:
  /// **'Sync bundle targets a different device. Generate a new QR and retry.'**
  String get devicesFailureDeviceMismatch;

  /// No description provided for @devicesFailureDeclined.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was declined on the primary phone. Generate a new QR to retry.'**
  String get devicesFailureDeclined;

  /// No description provided for @devicesFailureInvalidPayload.
  ///
  /// In en, this message translates to:
  /// **'Invalid desktop sync payload. Generate a new QR and retry.'**
  String get devicesFailureInvalidPayload;

  /// No description provided for @devicesFailureInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Secure sync was interrupted before completion. Generate a new QR and retry.'**
  String get devicesFailureInterrupted;

  /// No description provided for @devicesNewUser.
  ///
  /// In en, this message translates to:
  /// **'New user'**
  String get devicesNewUser;

  /// No description provided for @devicesNewUserDesktopConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear local data and prepare this desktop device for QR sign-in from the primary phone?'**
  String get devicesNewUserDesktopConfirm;

  /// No description provided for @devicesNewUserMobileConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear current local profile and register a new user on this device?'**
  String get devicesNewUserMobileConfirm;

  /// No description provided for @devicesCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get devicesCreateAction;

  /// No description provided for @devicesScanDeviceQr.
  ///
  /// In en, this message translates to:
  /// **'Scan device QR'**
  String get devicesScanDeviceQr;

  /// No description provided for @devicesRequestApproved.
  ///
  /// In en, this message translates to:
  /// **'Request approved. Sync package sent to desktop.'**
  String get devicesRequestApproved;

  /// No description provided for @devicesRequestDeclined.
  ///
  /// In en, this message translates to:
  /// **'Request declined. Desktop remains unauthenticated.'**
  String get devicesRequestDeclined;

  /// No description provided for @devicesApproveSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve sign-in on this device?'**
  String get devicesApproveSignInTitle;

  /// No description provided for @devicesConfirmSyncPrimary.
  ///
  /// In en, this message translates to:
  /// **'Confirm sync from the primary device (phone).'**
  String get devicesConfirmSyncPrimary;

  /// No description provided for @devicesApprovalDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'Device: {name}. Approval is allowed from primary phone only.'**
  String devicesApprovalDeviceOnly(String name);

  /// No description provided for @devicesSyncChats.
  ///
  /// In en, this message translates to:
  /// **'Sync chats'**
  String get devicesSyncChats;

  /// No description provided for @devicesSyncSettings.
  ///
  /// In en, this message translates to:
  /// **'Sync settings'**
  String get devicesSyncSettings;

  /// No description provided for @devicesSyncMedia.
  ///
  /// In en, this message translates to:
  /// **'Sync media'**
  String get devicesSyncMedia;

  /// No description provided for @devicesDeclineSignIn.
  ///
  /// In en, this message translates to:
  /// **'Decline sign-in'**
  String get devicesDeclineSignIn;

  /// No description provided for @devicesApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get devicesApprove;

  /// No description provided for @devicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesTitle;

  /// No description provided for @devicesConnectDevice.
  ///
  /// In en, this message translates to:
  /// **'Connect device'**
  String get devicesConnectDevice;

  /// No description provided for @devicesPrimaryDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'This is the primary device'**
  String get devicesPrimaryDeviceTitle;

  /// No description provided for @devicesPrimaryDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permission for chat/settings/media sync is granted only here.'**
  String get devicesPrimaryDeviceSubtitle;

  /// No description provided for @devicesQrSessionExpiredNewCode.
  ///
  /// In en, this message translates to:
  /// **'QR session expired. Generate a new code.'**
  String get devicesQrSessionExpiredNewCode;

  /// No description provided for @devicesQrExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'QR expires in {time}'**
  String devicesQrExpiresIn(String time);

  /// No description provided for @devicesWaitingQrScan.
  ///
  /// In en, this message translates to:
  /// **'Waiting for QR scan on phone.'**
  String get devicesWaitingQrScan;

  /// No description provided for @devicesQrScannedConfirm.
  ///
  /// In en, this message translates to:
  /// **'QR scanned. Confirm sign-in on phone.'**
  String get devicesQrScannedConfirm;

  /// No description provided for @devicesApplyingSecureBundle.
  ///
  /// In en, this message translates to:
  /// **'Applying secure sync bundle…'**
  String get devicesApplyingSecureBundle;

  /// No description provided for @devicesAuthorizationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authorization failed. Please retry.'**
  String get devicesAuthorizationFailed;

  /// No description provided for @devicesUnauthenticatedChooseAction.
  ///
  /// In en, this message translates to:
  /// **'You are not authenticated. Choose an action below.'**
  String get devicesUnauthenticatedChooseAction;

  /// No description provided for @devicesAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Device is authenticated.'**
  String get devicesAuthenticated;

  /// No description provided for @devicesDesktopWebAuthorization.
  ///
  /// In en, this message translates to:
  /// **'Desktop/Web authorization'**
  String get devicesDesktopWebAuthorization;

  /// No description provided for @devicesDesktopModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose mode: register a new user or sign in via QR with phone approval.'**
  String get devicesDesktopModeDescription;

  /// No description provided for @devicesCancelQr.
  ///
  /// In en, this message translates to:
  /// **'Cancel QR'**
  String get devicesCancelQr;

  /// No description provided for @devicesRefreshQr.
  ///
  /// In en, this message translates to:
  /// **'Refresh QR'**
  String get devicesRefreshQr;

  /// No description provided for @devicesSignInViaQr.
  ///
  /// In en, this message translates to:
  /// **'Sign in via QR'**
  String get devicesSignInViaQr;

  /// No description provided for @devicesOpenPrimaryInstruction.
  ///
  /// In en, this message translates to:
  /// **'Open Secretly on primary phone → Settings → Devices → Connect device.'**
  String get devicesOpenPrimaryInstruction;

  /// No description provided for @storageSection.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storageSection;

  /// No description provided for @storageSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cache and downloads on this device'**
  String get storageSectionSubtitle;

  /// No description provided for @storageUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage usage'**
  String get storageUsageTitle;

  /// No description provided for @storageCategoryMedia.
  ///
  /// In en, this message translates to:
  /// **'Media cache'**
  String get storageCategoryMedia;

  /// No description provided for @storageCategoryVoiceTranscripts.
  ///
  /// In en, this message translates to:
  /// **'Voice transcripts'**
  String get storageCategoryVoiceTranscripts;

  /// No description provided for @storageCategoryVoiceModel.
  ///
  /// In en, this message translates to:
  /// **'Offline voice model'**
  String get storageCategoryVoiceModel;

  /// No description provided for @storageCategoryStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get storageCategoryStickers;

  /// No description provided for @storageCategoryEmoji.
  ///
  /// In en, this message translates to:
  /// **'Animated emoji'**
  String get storageCategoryEmoji;

  /// No description provided for @storageCategoryProfileMedia.
  ///
  /// In en, this message translates to:
  /// **'My gallery & avatars'**
  String get storageCategoryProfileMedia;

  /// No description provided for @storageCategoryRecents.
  ///
  /// In en, this message translates to:
  /// **'Recent files'**
  String get storageCategoryRecents;

  /// No description provided for @storageTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get storageTotal;

  /// No description provided for @storageCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get storageCalculating;

  /// No description provided for @storageClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get storageClearCache;

  /// No description provided for @storageClearCacheHint.
  ///
  /// In en, this message translates to:
  /// **'Removes cached media, peer avatars and animated emoji. Your own gallery, stickers and chats are kept; media re-downloads when viewed.'**
  String get storageClearCacheHint;

  /// No description provided for @storageClearing.
  ///
  /// In en, this message translates to:
  /// **'Clearing cache…'**
  String get storageClearing;

  /// No description provided for @storageClearedToast.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get storageClearedToast;

  /// No description provided for @storageRemoveVoiceModel.
  ///
  /// In en, this message translates to:
  /// **'Remove offline voice model (140 MB)'**
  String get storageRemoveVoiceModel;

  /// No description provided for @storageRemoveVoiceModelHint.
  ///
  /// In en, this message translates to:
  /// **'Frees the on-device speech model. It re-downloads automatically the next time you transcribe a voice message.'**
  String get storageRemoveVoiceModelHint;

  /// No description provided for @storageRemoveVoiceModelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove voice model?'**
  String get storageRemoveVoiceModelConfirmTitle;

  /// No description provided for @storageRemoveVoiceModelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The 140 MB on-device speech model will be deleted. It re-downloads automatically the next time you transcribe a voice message.'**
  String get storageRemoveVoiceModelConfirmBody;

  /// No description provided for @storageRemoveVoiceModelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get storageRemoveVoiceModelConfirm;

  /// No description provided for @storageVoiceModelNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'No voice model is installed'**
  String get storageVoiceModelNotInstalled;

  /// No description provided for @storageVoiceModelRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'Voice model removed'**
  String get storageVoiceModelRemovedToast;

  /// No description provided for @backupStateProtected.
  ///
  /// In en, this message translates to:
  /// **'Your history is protected'**
  String get backupStateProtected;

  /// No description provided for @backupStateUnprotected.
  ///
  /// In en, this message translates to:
  /// **'Your history is not protected'**
  String get backupStateUnprotected;

  /// No description provided for @backupStateFailing.
  ///
  /// In en, this message translates to:
  /// **'Backups are failing'**
  String get backupStateFailing;

  /// No description provided for @backupStateStale.
  ///
  /// In en, this message translates to:
  /// **'Backup is out of date'**
  String get backupStateStale;

  /// No description provided for @backupStateNone.
  ///
  /// In en, this message translates to:
  /// **'No backup yet'**
  String get backupStateNone;

  /// No description provided for @backupLastAt.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {time}'**
  String backupLastAt(Object time);

  /// No description provided for @backupIntroHint.
  ///
  /// In en, this message translates to:
  /// **'A backup lets you bring your chats to a new device'**
  String get backupIntroHint;

  /// No description provided for @backupAccessUpgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Save your backup again'**
  String get backupAccessUpgradeTitle;

  /// No description provided for @backupAccessUpgradeBody.
  ///
  /// In en, this message translates to:
  /// **'Your server backup was created in the older format: it can be downloaded by anyone who knows your profile ID. The contents stay encrypted with your password, but a second barrier does no harm. Saving it again adds a password check on the server itself.'**
  String get backupAccessUpgradeBody;

  /// No description provided for @backupAccessUpgradeAction.
  ///
  /// In en, this message translates to:
  /// **'Save again'**
  String get backupAccessUpgradeAction;

  /// No description provided for @backupSectionAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get backupSectionAutomatic;

  /// No description provided for @backupAutoToggle.
  ///
  /// In en, this message translates to:
  /// **'Back up automatically'**
  String get backupAutoToggle;

  /// No description provided for @backupPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get backupPassword;

  /// No description provided for @backupPasswordSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get backupPasswordSet;

  /// No description provided for @backupPasswordNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get backupPasswordNotSet;

  /// No description provided for @backupPasswordSaved.
  ///
  /// In en, this message translates to:
  /// **'Password saved'**
  String get backupPasswordSaved;

  /// No description provided for @backupWhere.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get backupWhere;

  /// No description provided for @backupHowOften.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get backupHowOften;

  /// No description provided for @backupIncludeMedia.
  ///
  /// In en, this message translates to:
  /// **'Include media'**
  String get backupIncludeMedia;

  /// No description provided for @backupAutoFooter.
  ///
  /// In en, this message translates to:
  /// **'The backup is encrypted with your password. Without it nothing can be restored — keep it somewhere safe. Media is never uploaded to the server.'**
  String get backupAutoFooter;

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupNow;

  /// No description provided for @backupSectionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupSectionRestore;

  /// No description provided for @backupRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get backupRestoreAction;

  /// No description provided for @backupRestoreFooter.
  ///
  /// In en, this message translates to:
  /// **'Replaces the chats and settings on this device with the contents of the backup.'**
  String get backupRestoreFooter;

  /// No description provided for @backupSectionKey.
  ///
  /// In en, this message translates to:
  /// **'Secretly ID key'**
  String get backupSectionKey;

  /// No description provided for @backupKeyShow.
  ///
  /// In en, this message translates to:
  /// **'Show the key'**
  String get backupKeyShow;

  /// No description provided for @backupKeyRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore with a key'**
  String get backupKeyRestore;

  /// No description provided for @backupKeyFooter.
  ///
  /// In en, this message translates to:
  /// **'Restores your Secretly ID only — it carries no chats. Restoring with a key erases local data.'**
  String get backupKeyFooter;

  /// No description provided for @backupDestServerDevice.
  ///
  /// In en, this message translates to:
  /// **'Server and device'**
  String get backupDestServerDevice;

  /// No description provided for @backupDestServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get backupDestServer;

  /// No description provided for @backupDestDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get backupDestDevice;

  /// No description provided for @backupDestNone.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get backupDestNone;

  /// No description provided for @backupDestServerOnly.
  ///
  /// In en, this message translates to:
  /// **'Server only'**
  String get backupDestServerOnly;

  /// No description provided for @backupDestDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'Device only'**
  String get backupDestDeviceOnly;

  /// No description provided for @backupTileOff.
  ///
  /// In en, this message translates to:
  /// **'Off — your history is not protected'**
  String get backupTileOff;

  /// No description provided for @backupTilePending.
  ///
  /// In en, this message translates to:
  /// **'On, but it has not run yet'**
  String get backupTilePending;

  /// No description provided for @backupTileFailing.
  ///
  /// In en, this message translates to:
  /// **'Not running — needs attention'**
  String get backupTileFailing;

  /// No description provided for @backupTileStale.
  ///
  /// In en, this message translates to:
  /// **'Has not updated in a while'**
  String get backupTileStale;

  /// No description provided for @backupPasswordChange.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get backupPasswordChange;

  /// No description provided for @backupPasswordRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove password'**
  String get backupPasswordRemove;

  /// No description provided for @chatUndecryptablePending.
  ///
  /// In en, this message translates to:
  /// **'A message arrived but can\'t be read yet — restoring the secure session…'**
  String get chatUndecryptablePending;

  /// No description provided for @liquidGlassTitle.
  ///
  /// In en, this message translates to:
  /// **'Liquid glass'**
  String get liquidGlassTitle;

  /// No description provided for @liquidGlassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Refracting bars and islands. Turn off for the plain material — it uses less power and runs cooler.'**
  String get liquidGlassSubtitle;

  /// No description provided for @billingPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment'**
  String get billingPendingTitle;

  /// No description provided for @billingPendingBody.
  ///
  /// In en, this message translates to:
  /// **'The order was created but payment is not confirmed yet. Finish paying with your chosen method — Premium will switch on by itself.'**
  String get billingPendingBody;

  /// No description provided for @callsHideAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide my address in calls'**
  String get callsHideAddressTitle;

  /// No description provided for @callsHideAddressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Through our server: the other person will not see your IP address, but latency may increase'**
  String get callsHideAddressSubtitle;

  /// No description provided for @desktopJoinRoomByLink.
  ///
  /// In en, this message translates to:
  /// **'Join by link'**
  String get desktopJoinRoomByLink;

  /// No description provided for @desktopJoinRoomLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the invite link'**
  String get desktopJoinRoomLinkHint;

  /// No description provided for @desktopJoinRoomLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not a room invite link'**
  String get desktopJoinRoomLinkInvalid;

  /// No description provided for @desktopOfflineLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask for the password after a long offline spell'**
  String get desktopOfflineLockTitle;

  /// No description provided for @desktopOfflineLockDescription.
  ///
  /// In en, this message translates to:
  /// **'If this computer has not reached the server for longer than this, it asks for the app password on start. A lost computer never receives a remote sign-out, but it does reach this limit.'**
  String get desktopOfflineLockDescription;

  /// No description provided for @desktopOfflineLockNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get desktopOfflineLockNever;

  /// No description provided for @desktopOfflineLockDays7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get desktopOfflineLockDays7;

  /// No description provided for @desktopOfflineLockDays14.
  ///
  /// In en, this message translates to:
  /// **'14 days'**
  String get desktopOfflineLockDays14;

  /// No description provided for @desktopOfflineLockDays30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get desktopOfflineLockDays30;

  /// No description provided for @desktopPollTitle.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get desktopPollTitle;

  /// No description provided for @desktopPollAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous poll'**
  String get desktopPollAnonymous;

  /// No description provided for @desktopPollClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get desktopPollClosed;

  /// No description provided for @desktopPollVoters.
  ///
  /// In en, this message translates to:
  /// **'Voted: {count}'**
  String desktopPollVoters(Object count);

  /// No description provided for @desktopPollMultipleHint.
  ///
  /// In en, this message translates to:
  /// **'You can pick several'**
  String get desktopPollMultipleHint;

  /// No description provided for @desktopPollCloseAction.
  ///
  /// In en, this message translates to:
  /// **'Close the poll'**
  String get desktopPollCloseAction;

  /// No description provided for @desktopEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get desktopEventTitle;

  /// No description provided for @desktopEventGoing.
  ///
  /// In en, this message translates to:
  /// **'Going'**
  String get desktopEventGoing;

  /// No description provided for @desktopEventMaybe.
  ///
  /// In en, this message translates to:
  /// **'Maybe'**
  String get desktopEventMaybe;

  /// No description provided for @desktopEventNo.
  ///
  /// In en, this message translates to:
  /// **'Not going'**
  String get desktopEventNo;

  /// No description provided for @desktopPollNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New poll'**
  String get desktopPollNewTitle;

  /// No description provided for @desktopPollQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get desktopPollQuestionHint;

  /// No description provided for @desktopPollOptionHint.
  ///
  /// In en, this message translates to:
  /// **'Option {index}'**
  String desktopPollOptionHint(Object index);

  /// No description provided for @desktopPollAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add an option'**
  String get desktopPollAddOption;

  /// No description provided for @desktopPollCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get desktopPollCreateAction;

  /// No description provided for @desktopPollNeedTwo.
  ///
  /// In en, this message translates to:
  /// **'A poll needs a question and at least two options'**
  String get desktopPollNeedTwo;

  /// No description provided for @desktopPollMultipleLabel.
  ///
  /// In en, this message translates to:
  /// **'Several answers'**
  String get desktopPollMultipleLabel;

  /// No description provided for @desktopPollAnonymousLabel.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get desktopPollAnonymousLabel;

  /// No description provided for @desktopEventNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get desktopEventNewTitle;

  /// No description provided for @desktopEventTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get desktopEventTitleHint;

  /// No description provided for @desktopEventDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get desktopEventDescriptionHint;

  /// No description provided for @desktopEventLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get desktopEventLocationHint;

  /// No description provided for @desktopEventPickWhen.
  ///
  /// In en, this message translates to:
  /// **'Pick a date and time'**
  String get desktopEventPickWhen;

  /// No description provided for @desktopEventNeedTitleAndDate.
  ///
  /// In en, this message translates to:
  /// **'An event needs a title and a date'**
  String get desktopEventNeedTitleAndDate;

  /// No description provided for @desktopViewerOpenExternally.
  ///
  /// In en, this message translates to:
  /// **'Open in another app'**
  String get desktopViewerOpenExternally;

  /// No description provided for @desktopViewerSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get desktopViewerSaveAs;

  /// No description provided for @desktopViewerPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String desktopViewerPage(Object page, Object total);

  /// No description provided for @desktopViewerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not show this file'**
  String get desktopViewerFailed;

  /// No description provided for @desktopViewerTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too large to show here'**
  String get desktopViewerTooLarge;

  /// No description provided for @desktopSupportAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach a file'**
  String get desktopSupportAttach;

  /// No description provided for @desktopSupportAttachHint.
  ///
  /// In en, this message translates to:
  /// **'A screenshot or a log file — up to {limit}. The attachment is encrypted together with the message.'**
  String desktopSupportAttachHint(Object limit);

  /// No description provided for @desktopSupportTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is larger than {limit} — it cannot be sent'**
  String desktopSupportTooLarge(Object limit);

  /// No description provided for @desktopSupportUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Could not read the file'**
  String get desktopSupportUnreadable;

  /// No description provided for @desktopSupportRemoveAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove the attachment'**
  String get desktopSupportRemoveAttachment;

  /// No description provided for @desktopSupportMegabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String desktopSupportMegabytes(Object value);

  /// No description provided for @desktopSupportYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get desktopSupportYou;

  /// No description provided for @desktopSupportShrunk.
  ///
  /// In en, this message translates to:
  /// **'The image was shrunk to fit'**
  String get desktopSupportShrunk;

  /// No description provided for @desktopStickerPackTitle.
  ///
  /// In en, this message translates to:
  /// **'Sticker pack'**
  String get desktopStickerPackTitle;

  /// No description provided for @desktopStickerPackAddPlain.
  ///
  /// In en, this message translates to:
  /// **'Add the pack'**
  String get desktopStickerPackAddPlain;

  /// No description provided for @desktopStickerPackInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get desktopStickerPackInstalled;

  /// No description provided for @desktopStickerPackInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing…'**
  String get desktopStickerPackInstalling;

  /// No description provided for @desktopStickerPackOwn.
  ///
  /// In en, this message translates to:
  /// **'This is your own pack'**
  String get desktopStickerPackOwn;

  /// No description provided for @desktopStickerPackNoAuthor.
  ///
  /// In en, this message translates to:
  /// **'The pack\'s author is unknown — open the same sticker in a one-to-one chat'**
  String get desktopStickerPackNoAuthor;

  /// No description provided for @desktopStickerPackInstallingProgress.
  ///
  /// In en, this message translates to:
  /// **'Installing… {done}/{total}'**
  String desktopStickerPackInstallingProgress(Object done, Object total);

  /// No description provided for @desktopStickerPackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} sticker} other{{count} stickers}}'**
  String desktopStickerPackCount(int count);

  /// No description provided for @desktopStickerPackAdd.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Add {count} sticker} other{Add {count} stickers}}'**
  String desktopStickerPackAdd(int count);

  /// No description provided for @desktopPairingTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect Secretly Desktop'**
  String get desktopPairingTitle;

  /// No description provided for @desktopPairingHowTo.
  ///
  /// In en, this message translates to:
  /// **'On your phone open Secretly → Settings → Devices → “Link a device” and scan this QR code.'**
  String get desktopPairingHowTo;

  /// No description provided for @desktopPairingPreparingQr.
  ///
  /// In en, this message translates to:
  /// **'Preparing the QR…'**
  String get desktopPairingPreparingQr;

  /// No description provided for @desktopPairingQrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'QR unavailable'**
  String get desktopPairingQrUnavailable;

  /// No description provided for @desktopPairingCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'The code expired — refreshing…'**
  String get desktopPairingCodeExpired;

  /// No description provided for @desktopPairingCodeValidFor.
  ///
  /// In en, this message translates to:
  /// **'The code is valid for another {time}'**
  String desktopPairingCodeValidFor(Object time);

  /// No description provided for @desktopPairingPrepareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the code. Check your internet connection and try again.'**
  String get desktopPairingPrepareFailed;

  /// No description provided for @desktopPairingRevoked.
  ///
  /// In en, this message translates to:
  /// **'This device was removed from the account, so no code is created.\nConnect the desktop again — it will get a new device identity, and the old one stays revoked. Only a confirmation from the phone gives access to the conversations.'**
  String get desktopPairingRevoked;

  /// No description provided for @desktopPairingPreparingNew.
  ///
  /// In en, this message translates to:
  /// **'Preparing a new connection…'**
  String get desktopPairingPreparingNew;

  /// No description provided for @desktopPairingConnectAsNew.
  ///
  /// In en, this message translates to:
  /// **'Connect as a new device'**
  String get desktopPairingConnectAsNew;

  /// No description provided for @desktopPairingIdentityResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not recreate the device identity. Restart the application and try again.'**
  String get desktopPairingIdentityResetFailed;

  /// No description provided for @desktopPairingWaitingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation…'**
  String get desktopPairingWaitingConfirm;

  /// No description provided for @desktopPairingNewQr.
  ///
  /// In en, this message translates to:
  /// **'Generate a new QR'**
  String get desktopPairingNewQr;

  /// No description provided for @desktopPairingCreatingRequest.
  ///
  /// In en, this message translates to:
  /// **'Creating the request…'**
  String get desktopPairingCreatingRequest;

  /// No description provided for @desktopPairingReadyToScan.
  ///
  /// In en, this message translates to:
  /// **'Ready to scan'**
  String get desktopPairingReadyToScan;

  /// No description provided for @desktopPairingWaitingScan.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the scan on the phone…'**
  String get desktopPairingWaitingScan;

  /// No description provided for @desktopPairingScannedConfirmOnPhone.
  ///
  /// In en, this message translates to:
  /// **'QR scanned — confirm on the phone.'**
  String get desktopPairingScannedConfirmOnPhone;

  /// No description provided for @desktopPairingFetchingProfile.
  ///
  /// In en, this message translates to:
  /// **'Fetching the profile and keys…'**
  String get desktopPairingFetchingProfile;

  /// No description provided for @desktopPairingConnectedLoading.
  ///
  /// In en, this message translates to:
  /// **'Connected. Loading…'**
  String get desktopPairingConnectedLoading;

  /// No description provided for @desktopPairingConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Try again.'**
  String get desktopPairingConnectionError;

  /// No description provided for @desktopMenuReaction.
  ///
  /// In en, this message translates to:
  /// **'Reaction'**
  String get desktopMenuReaction;

  /// No description provided for @desktopMenuContinueInTopic.
  ///
  /// In en, this message translates to:
  /// **'Continue in a topic'**
  String get desktopMenuContinueInTopic;

  /// No description provided for @desktopMenuCopySelection.
  ///
  /// In en, this message translates to:
  /// **'Copy the selection'**
  String get desktopMenuCopySelection;

  /// No description provided for @desktopMenuCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy the text'**
  String get desktopMenuCopyText;

  /// No description provided for @desktopMenuCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy the link'**
  String get desktopMenuCopyLink;

  /// No description provided for @desktopMenuTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get desktopMenuTranslate;

  /// No description provided for @desktopMenuHideTranslation.
  ///
  /// In en, this message translates to:
  /// **'Hide the translation'**
  String get desktopMenuHideTranslation;

  /// No description provided for @desktopMenuSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get desktopMenuSelect;

  /// No description provided for @desktopMenuPhotoOrVideo.
  ///
  /// In en, this message translates to:
  /// **'Photo or video'**
  String get desktopMenuPhotoOrVideo;

  /// No description provided for @desktopMenuContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get desktopMenuContact;

  /// No description provided for @desktopMenuLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get desktopMenuLocation;

  /// No description provided for @desktopListPinned.
  ///
  /// In en, this message translates to:
  /// **'PINNED'**
  String get desktopListPinned;

  /// No description provided for @desktopListToday.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get desktopListToday;

  /// No description provided for @desktopListYesterday.
  ///
  /// In en, this message translates to:
  /// **'YESTERDAY'**
  String get desktopListYesterday;

  /// No description provided for @desktopListThisWeek.
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get desktopListThisWeek;

  /// No description provided for @desktopListEarlier.
  ///
  /// In en, this message translates to:
  /// **'EARLIER'**
  String get desktopListEarlier;

  /// No description provided for @desktopListNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get desktopListNothingFound;

  /// No description provided for @desktopListAddFavourite.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get desktopListAddFavourite;

  /// No description provided for @desktopListRemoveFavourite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get desktopListRemoveFavourite;

  /// No description provided for @desktopListMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get desktopListMute;

  /// No description provided for @desktopListMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get desktopListMarkRead;

  /// No description provided for @desktopListArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get desktopListArchive;

  /// No description provided for @desktopListFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get desktopListFolders;

  /// No description provided for @desktopListCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get desktopListCreate;

  /// No description provided for @desktopListTyping.
  ///
  /// In en, this message translates to:
  /// **'typing'**
  String get desktopListTyping;

  /// No description provided for @desktopListDraftPrefix.
  ///
  /// In en, this message translates to:
  /// **'Draft: '**
  String get desktopListDraftPrefix;

  /// No description provided for @desktopListDiscussion.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Discussion · {count} participant} other{Discussion · {count} participants}}'**
  String desktopListDiscussion(int count);

  /// No description provided for @desktopCallServerSilent.
  ///
  /// In en, this message translates to:
  /// **'The server did not answer. Try again or leave the call.'**
  String get desktopCallServerSilent;

  /// No description provided for @desktopCallRoomMissing.
  ///
  /// In en, this message translates to:
  /// **'The room is not available on the server — a call cannot be started in it.'**
  String get desktopCallRoomMissing;

  /// No description provided for @desktopCallNoServer.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server. Check your connection.'**
  String get desktopCallNoServer;

  /// No description provided for @desktopCallJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not join the call. Check the connection and try again.'**
  String get desktopCallJoinFailed;

  /// No description provided for @desktopCallSharingScreen.
  ///
  /// In en, this message translates to:
  /// **'{name} is sharing the screen'**
  String desktopCallSharingScreen(Object name);

  /// No description provided for @desktopCallRoomEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been written in the room yet'**
  String get desktopCallRoomEmpty;

  /// No description provided for @desktopCallMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message to the room…'**
  String get desktopCallMessageHint;

  /// No description provided for @desktopCallSendToRoom.
  ///
  /// In en, this message translates to:
  /// **'Send to the room'**
  String get desktopCallSendToRoom;

  /// No description provided for @desktopCallParticipantsTab.
  ///
  /// In en, this message translates to:
  /// **'Participants · {count}'**
  String desktopCallParticipantsTab(Object count);

  /// No description provided for @desktopCallNotesTab.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get desktopCallNotesTab;

  /// No description provided for @desktopCallLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'The link was copied'**
  String get desktopCallLinkCopied;

  /// No description provided for @desktopCallFailed.
  ///
  /// In en, this message translates to:
  /// **'It did not work'**
  String get desktopCallFailed;

  /// No description provided for @desktopCallFailedWith.
  ///
  /// In en, this message translates to:
  /// **'It did not work: {error}'**
  String desktopCallFailedWith(Object error);

  /// No description provided for @desktopCallMicOn.
  ///
  /// In en, this message translates to:
  /// **'Turn the microphone on'**
  String get desktopCallMicOn;

  /// No description provided for @desktopCallMicOff.
  ///
  /// In en, this message translates to:
  /// **'Turn the microphone off'**
  String get desktopCallMicOff;

  /// No description provided for @desktopCallCamOn.
  ///
  /// In en, this message translates to:
  /// **'Turn the camera on'**
  String get desktopCallCamOn;

  /// No description provided for @desktopCallCamOff.
  ///
  /// In en, this message translates to:
  /// **'Turn the camera off'**
  String get desktopCallCamOff;

  /// No description provided for @desktopCallNoMediaVideo.
  ///
  /// In en, this message translates to:
  /// **'The server gave no media channel — video is unavailable'**
  String get desktopCallNoMediaVideo;

  /// No description provided for @desktopCallLayoutSingle.
  ///
  /// In en, this message translates to:
  /// **'One'**
  String get desktopCallLayoutSingle;

  /// No description provided for @desktopCallLayoutGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get desktopCallLayoutGrid;

  /// No description provided for @desktopCallShowOneLarge.
  ///
  /// In en, this message translates to:
  /// **'Show one person large'**
  String get desktopCallShowOneLarge;

  /// No description provided for @desktopCallShowGrid.
  ///
  /// In en, this message translates to:
  /// **'Show everyone in a grid'**
  String get desktopCallShowGrid;

  /// No description provided for @desktopCallScreen.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get desktopCallScreen;

  /// No description provided for @desktopCallShareStop.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing the screen'**
  String get desktopCallShareStop;

  /// No description provided for @desktopCallShareStart.
  ///
  /// In en, this message translates to:
  /// **'Share the screen'**
  String get desktopCallShareStart;

  /// No description provided for @desktopCallNoMediaScreen.
  ///
  /// In en, this message translates to:
  /// **'The server gave no media channel — screen sharing is unavailable'**
  String get desktopCallNoMediaScreen;

  /// No description provided for @desktopCallLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get desktopCallLeave;

  /// No description provided for @desktopCallLeaveCall.
  ///
  /// In en, this message translates to:
  /// **'Leave the call'**
  String get desktopCallLeaveCall;

  /// No description provided for @desktopCallNoMediaBoth.
  ///
  /// In en, this message translates to:
  /// **'The server gave no media channel: this call will have neither sound nor video'**
  String get desktopCallNoMediaBoth;

  /// No description provided for @desktopCallMinimise.
  ///
  /// In en, this message translates to:
  /// **'Minimise the call'**
  String get desktopCallMinimise;

  /// No description provided for @desktopCallDiscussion.
  ///
  /// In en, this message translates to:
  /// **'Discussion'**
  String get desktopCallDiscussion;

  /// No description provided for @desktopCallDiscussionOf.
  ///
  /// In en, this message translates to:
  /// **'Discussion · {title}'**
  String desktopCallDiscussionOf(Object title);

  /// No description provided for @desktopCallEncrypted.
  ///
  /// In en, this message translates to:
  /// **'The call is end-to-end encrypted'**
  String get desktopCallEncrypted;

  /// No description provided for @desktopCallDurationOnAir.
  ///
  /// In en, this message translates to:
  /// **'{duration} · {count} on air'**
  String desktopCallDurationOnAir(Object duration, Object count);

  /// No description provided for @desktopCallExitFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Leave full screen'**
  String get desktopCallExitFullScreen;

  /// No description provided for @desktopCallFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get desktopCallFullScreen;

  /// No description provided for @desktopCallDemoRoom.
  ///
  /// In en, this message translates to:
  /// **'Demonstration room'**
  String get desktopCallDemoRoom;

  /// No description provided for @desktopCallNoCallYet.
  ///
  /// In en, this message translates to:
  /// **'No call yet'**
  String get desktopCallNoCallYet;

  /// No description provided for @desktopCallDemoExplain.
  ///
  /// In en, this message translates to:
  /// **'It lives only on this computer and does not exist on the server, so no call can be started in it. In a real room the button works.'**
  String get desktopCallDemoExplain;

  /// No description provided for @desktopCallStartHint.
  ///
  /// In en, this message translates to:
  /// **'Start — everyone else will see the invitation in the room'**
  String get desktopCallStartHint;

  /// No description provided for @desktopCallVoiceOnly.
  ///
  /// In en, this message translates to:
  /// **'Voice only'**
  String get desktopCallVoiceOnly;

  /// No description provided for @desktopCallWithCamera.
  ///
  /// In en, this message translates to:
  /// **'With camera'**
  String get desktopCallWithCamera;

  /// No description provided for @desktopCallConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get desktopCallConnecting;

  /// No description provided for @desktopCallOngoing.
  ///
  /// In en, this message translates to:
  /// **'A discussion is under way'**
  String get desktopCallOngoing;

  /// No description provided for @desktopCallOnAir.
  ///
  /// In en, this message translates to:
  /// **'{count} on air'**
  String desktopCallOnAir(Object count);

  /// No description provided for @desktopCallJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get desktopCallJoin;

  /// No description provided for @desktopCallFullScreenShort.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get desktopCallFullScreenShort;

  /// No description provided for @desktopCallReconnecting.
  ///
  /// In en, this message translates to:
  /// **'reconnecting'**
  String get desktopCallReconnecting;

  /// No description provided for @desktopCallCannotHear.
  ///
  /// In en, this message translates to:
  /// **'cannot hear'**
  String get desktopCallCannotHear;

  /// No description provided for @desktopCallSharingShort.
  ///
  /// In en, this message translates to:
  /// **'is sharing the screen'**
  String get desktopCallSharingShort;

  /// No description provided for @desktopCallCameraOn.
  ///
  /// In en, this message translates to:
  /// **'camera is on'**
  String get desktopCallCameraOn;

  /// No description provided for @desktopCallPickDevice.
  ///
  /// In en, this message translates to:
  /// **'Choose a device'**
  String get desktopCallPickDevice;

  /// No description provided for @desktopCallPreparingLink.
  ///
  /// In en, this message translates to:
  /// **'Preparing the link…'**
  String get desktopCallPreparingLink;

  /// No description provided for @desktopCallInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get desktopCallInvite;

  /// No description provided for @desktopCallFps.
  ///
  /// In en, this message translates to:
  /// **'{fps} fps'**
  String desktopCallFps(Object fps);

  /// No description provided for @desktopSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get desktopSettingsTitle;

  /// No description provided for @desktopSettingsGroupApp.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get desktopSettingsGroupApp;

  /// No description provided for @desktopSettingsGroupPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy and security'**
  String get desktopSettingsGroupPrivacy;

  /// No description provided for @desktopSettingsGroupAccount.
  ///
  /// In en, this message translates to:
  /// **'Account and data'**
  String get desktopSettingsGroupAccount;

  /// No description provided for @desktopSettingsGeneralLabel.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get desktopSettingsGeneralLabel;

  /// No description provided for @desktopSettingsGeneralSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Language, how the app behaves'**
  String get desktopSettingsGeneralSubtitle;

  /// No description provided for @desktopSettingsGeneralKeywords.
  ///
  /// In en, this message translates to:
  /// **'language, locale, enter, sending, input'**
  String get desktopSettingsGeneralKeywords;

  /// No description provided for @desktopSettingsAppearanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get desktopSettingsAppearanceLabel;

  /// No description provided for @desktopSettingsAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, accent, chat wallpaper'**
  String get desktopSettingsAppearanceSubtitle;

  /// No description provided for @desktopSettingsAppearanceKeywords.
  ///
  /// In en, this message translates to:
  /// **'theme, accent, wallpaper, background, bubbles, colour, dark, ticks, animation'**
  String get desktopSettingsAppearanceKeywords;

  /// No description provided for @desktopSettingsShortcutsLabel.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get desktopSettingsShortcutsLabel;

  /// No description provided for @desktopSettingsShortcutsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What to press to go faster'**
  String get desktopSettingsShortcutsSubtitle;

  /// No description provided for @desktopSettingsShortcutsKeywords.
  ///
  /// In en, this message translates to:
  /// **'keys, shortcuts, fast, cmd, ctrl'**
  String get desktopSettingsShortcutsKeywords;

  /// No description provided for @desktopSettingsPowerLabel.
  ///
  /// In en, this message translates to:
  /// **'Power use'**
  String get desktopSettingsPowerLabel;

  /// No description provided for @desktopSettingsPowerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What drains the battery'**
  String get desktopSettingsPowerSubtitle;

  /// No description provided for @desktopSettingsPowerKeywords.
  ///
  /// In en, this message translates to:
  /// **'battery, animation, frames, glass, panels, performance, heat'**
  String get desktopSettingsPowerKeywords;

  /// No description provided for @desktopSettingsNotificationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get desktopSettingsNotificationsLabel;

  /// No description provided for @desktopSettingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sounds, previews, quiet'**
  String get desktopSettingsNotificationsSubtitle;

  /// No description provided for @desktopSettingsNotificationsKeywords.
  ///
  /// In en, this message translates to:
  /// **'sound, preview, quiet, do not disturb, banner, text'**
  String get desktopSettingsNotificationsKeywords;

  /// No description provided for @desktopSettingsCallsLabel.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get desktopSettingsCallsLabel;

  /// No description provided for @desktopSettingsCallsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receiving calls and screen sharing'**
  String get desktopSettingsCallsSubtitle;

  /// No description provided for @desktopSettingsCallsKeywords.
  ///
  /// In en, this message translates to:
  /// **'calls, incoming, screen sharing, screen, video, audio'**
  String get desktopSettingsCallsKeywords;

  /// No description provided for @desktopSettingsMediaLabel.
  ///
  /// In en, this message translates to:
  /// **'Sound and video'**
  String get desktopSettingsMediaLabel;

  /// No description provided for @desktopSettingsMediaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Camera and microphone for calls'**
  String get desktopSettingsMediaSubtitle;

  /// No description provided for @desktopSettingsMediaKeywords.
  ///
  /// In en, this message translates to:
  /// **'camera, microphone, device, webcam, headset, headphones, sound, video'**
  String get desktopSettingsMediaKeywords;

  /// No description provided for @desktopSettingsPrivacyLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get desktopSettingsPrivacyLabel;

  /// No description provided for @desktopSettingsPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Who sees what about you'**
  String get desktopSettingsPrivacySubtitle;

  /// No description provided for @desktopSettingsPrivacyKeywords.
  ///
  /// In en, this message translates to:
  /// **'who sees, last seen, photo, calls, messages, forwarding, nickname, search, strangers, delete account'**
  String get desktopSettingsPrivacyKeywords;

  /// No description provided for @desktopSettingsSecurityLabel.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get desktopSettingsSecurityLabel;

  /// No description provided for @desktopSettingsSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Encryption and verified devices'**
  String get desktopSettingsSecuritySubtitle;

  /// No description provided for @desktopSettingsSecurityKeywords.
  ///
  /// In en, this message translates to:
  /// **'encryption, e2ee, verified, unverified, lock, password, touch id, verification'**
  String get desktopSettingsSecurityKeywords;

  /// No description provided for @desktopSettingsBackupLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get desktopSettingsBackupLabel;

  /// No description provided for @desktopSettingsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What will save your conversation history'**
  String get desktopSettingsBackupSubtitle;

  /// No description provided for @desktopSettingsBackupKeywords.
  ///
  /// In en, this message translates to:
  /// **'backup, copy, restore, safe backup, backup password, media'**
  String get desktopSettingsBackupKeywords;

  /// No description provided for @desktopSettingsBlockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get desktopSettingsBlockedLabel;

  /// No description provided for @desktopSettingsBlockedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Who is shut out from you'**
  String get desktopSettingsBlockedSubtitle;

  /// No description provided for @desktopSettingsBlockedKeywords.
  ///
  /// In en, this message translates to:
  /// **'block, blocked, unblock, blacklist, spam'**
  String get desktopSettingsBlockedKeywords;

  /// No description provided for @desktopSettingsDevicesLabel.
  ///
  /// In en, this message translates to:
  /// **'Sessions and devices'**
  String get desktopSettingsDevicesLabel;

  /// No description provided for @desktopSettingsDevicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get desktopSettingsDevicesSubtitle;

  /// No description provided for @desktopSettingsDevicesKeywords.
  ///
  /// In en, this message translates to:
  /// **'devices, sessions, qr, linking, sign out, backup'**
  String get desktopSettingsDevicesKeywords;

  /// No description provided for @desktopSettingsAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get desktopSettingsAccountLabel;

  /// No description provided for @desktopSettingsAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Profile and signing out'**
  String get desktopSettingsAccountSubtitle;

  /// No description provided for @desktopSettingsAccountKeywords.
  ///
  /// In en, this message translates to:
  /// **'name, about, id, sign out, reset'**
  String get desktopSettingsAccountKeywords;

  /// No description provided for @desktopSettingsStorageLabel.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get desktopSettingsStorageLabel;

  /// No description provided for @desktopSettingsStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cache, downloads'**
  String get desktopSettingsStorageSubtitle;

  /// No description provided for @desktopSettingsStorageKeywords.
  ///
  /// In en, this message translates to:
  /// **'cache, space, clear, media, downloads'**
  String get desktopSettingsStorageKeywords;

  /// No description provided for @desktopSettingsSupportLabel.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get desktopSettingsSupportLabel;

  /// No description provided for @desktopSettingsSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'An encrypted conversation with us'**
  String get desktopSettingsSupportSubtitle;

  /// No description provided for @desktopSettingsSupportKeywords.
  ///
  /// In en, this message translates to:
  /// **'support, help, problem, bug, write'**
  String get desktopSettingsSupportKeywords;

  /// No description provided for @desktopSettingsAboutLabel.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get desktopSettingsAboutLabel;

  /// No description provided for @desktopSettingsAboutKeywords.
  ///
  /// In en, this message translates to:
  /// **'version, build, licences, website'**
  String get desktopSettingsAboutKeywords;

  /// No description provided for @desktopSettingsDangerLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete the account'**
  String get desktopSettingsDangerLabel;

  /// No description provided for @desktopSettingsEndCallFirst.
  ///
  /// In en, this message translates to:
  /// **'End the active call first.'**
  String get desktopSettingsEndCallFirst;

  /// No description provided for @desktopSettingsSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of the account on this computer?'**
  String get desktopSettingsSignOutTitle;

  /// No description provided for @desktopSettingsSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'The conversations, keys and cache will be removed from this computer. The account and the history on the phone are untouched — the desktop can be linked again with a QR code.'**
  String get desktopSettingsSignOutBody;

  /// No description provided for @desktopSettingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get desktopSettingsSignOut;

  /// No description provided for @desktopSettingsSignOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign out: {error}'**
  String desktopSettingsSignOutFailed(Object error);

  /// No description provided for @desktopSettingsActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get desktopSettingsActive;

  /// No description provided for @desktopGeneralSystemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get desktopGeneralSystemLanguage;

  /// No description provided for @desktopGeneralInterfaceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get desktopGeneralInterfaceLanguage;

  /// No description provided for @desktopGeneralAppliesAtOnce.
  ///
  /// In en, this message translates to:
  /// **'Applies straight away'**
  String get desktopGeneralAppliesAtOnce;

  /// No description provided for @desktopGeneralBehaviour.
  ///
  /// In en, this message translates to:
  /// **'Behaviour'**
  String get desktopGeneralBehaviour;

  /// No description provided for @desktopGeneralEnterSends.
  ///
  /// In en, this message translates to:
  /// **'Enter sends the message'**
  String get desktopGeneralEnterSends;

  /// No description provided for @desktopGeneralShiftEnterNewline.
  ///
  /// In en, this message translates to:
  /// **'Shift+Enter starts a new line'**
  String get desktopGeneralShiftEnterNewline;

  /// No description provided for @desktopGeneralEnterNewline.
  ///
  /// In en, this message translates to:
  /// **'Enter starts a new line, Shift+Enter sends'**
  String get desktopGeneralEnterNewline;

  /// No description provided for @desktopGeneralHoverMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu when hovering over a message'**
  String get desktopGeneralHoverMenu;

  /// No description provided for @desktopGeneralHoverMenuOn.
  ///
  /// In en, this message translates to:
  /// **'Reactions and actions appear above the message'**
  String get desktopGeneralHoverMenuOn;

  /// No description provided for @desktopGeneralHoverMenuOff.
  ///
  /// In en, this message translates to:
  /// **'Actions are on the right mouse button'**
  String get desktopGeneralHoverMenuOff;

  /// No description provided for @desktopGeneralLinkPreviews.
  ///
  /// In en, this message translates to:
  /// **'Link previews'**
  String get desktopGeneralLinkPreviews;

  /// No description provided for @desktopGeneralLinkPreviewsOn.
  ///
  /// In en, this message translates to:
  /// **'The link card is sent together with the message'**
  String get desktopGeneralLinkPreviewsOn;

  /// No description provided for @desktopGeneralLinkPreviewsOff.
  ///
  /// In en, this message translates to:
  /// **'Links are sent without a card and no page is opened'**
  String get desktopGeneralLinkPreviewsOff;

  /// No description provided for @desktopPowerAnimations.
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get desktopPowerAnimations;

  /// No description provided for @desktopPowerAnimationsHint.
  ///
  /// In en, this message translates to:
  /// **'Everything is on by default. Switch off from the top down if the laptop gets hot or the battery drains.'**
  String get desktopPowerAnimationsHint;

  /// No description provided for @desktopPowerFramesTitle.
  ///
  /// In en, this message translates to:
  /// **'Animated frames and statuses'**
  String get desktopPowerFramesTitle;

  /// No description provided for @desktopPowerFramesHint.
  ///
  /// In en, this message translates to:
  /// **'Live avatar frames and emoji statuses on other people. The most expensive of the three — switch this off first.'**
  String get desktopPowerFramesHint;

  /// No description provided for @desktopPowerGlassBubbles.
  ///
  /// In en, this message translates to:
  /// **'Glass bubbles'**
  String get desktopPowerGlassBubbles;

  /// No description provided for @desktopPowerGlassBubblesHint.
  ///
  /// In en, this message translates to:
  /// **'Blur behind incoming messages'**
  String get desktopPowerGlassBubblesHint;

  /// No description provided for @desktopPowerMattePanels.
  ///
  /// In en, this message translates to:
  /// **'Matte panels'**
  String get desktopPowerMattePanels;

  /// No description provided for @desktopPowerMattePanelsHint.
  ///
  /// In en, this message translates to:
  /// **'Blur on panels and popups'**
  String get desktopPowerMattePanelsHint;

  /// No description provided for @desktopPowerNotAffectedTitle.
  ///
  /// In en, this message translates to:
  /// **'What this does not affect'**
  String get desktopPowerNotAffectedTitle;

  /// No description provided for @desktopPowerNotAffectedHint.
  ///
  /// In en, this message translates to:
  /// **'Message delivery, encryption and notifications work the same whatever you choose. These settings only affect drawing.'**
  String get desktopPowerNotAffectedHint;

  /// No description provided for @desktopNotifHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get desktopNotifHidden;

  /// No description provided for @desktopNotifSenderOnly.
  ///
  /// In en, this message translates to:
  /// **'Sender only'**
  String get desktopNotifSenderOnly;

  /// No description provided for @desktopNotifSenderAndText.
  ///
  /// In en, this message translates to:
  /// **'Sender and text'**
  String get desktopNotifSenderAndText;

  /// No description provided for @desktopNotifUnavailableHere.
  ///
  /// In en, this message translates to:
  /// **'Not available on this platform.'**
  String get desktopNotifUnavailableHere;

  /// No description provided for @desktopNotifShowPreview.
  ///
  /// In en, this message translates to:
  /// **'Show a preview of the message'**
  String get desktopNotifShowPreview;

  /// No description provided for @desktopNotifInSystem.
  ///
  /// In en, this message translates to:
  /// **'In system notifications'**
  String get desktopNotifInSystem;

  /// No description provided for @desktopNotifDirectChats.
  ///
  /// In en, this message translates to:
  /// **'One-to-one chats'**
  String get desktopNotifDirectChats;

  /// No description provided for @desktopNotifDirectChatsHint.
  ///
  /// In en, this message translates to:
  /// **'Notifications about one-to-one messages'**
  String get desktopNotifDirectChatsHint;

  /// No description provided for @desktopNotifRooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get desktopNotifRooms;

  /// No description provided for @desktopNotifRoomsHint.
  ///
  /// In en, this message translates to:
  /// **'Notifications about messages in rooms'**
  String get desktopNotifRoomsHint;

  /// No description provided for @desktopNotifSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get desktopNotifSound;

  /// No description provided for @desktopNotifDnd.
  ///
  /// In en, this message translates to:
  /// **'Do not disturb'**
  String get desktopNotifDnd;

  /// No description provided for @desktopNotifDndHint.
  ///
  /// In en, this message translates to:
  /// **'Switch off every notification'**
  String get desktopNotifDndHint;

  /// No description provided for @desktopWallAnimContinuous.
  ///
  /// In en, this message translates to:
  /// **'Continuously'**
  String get desktopWallAnimContinuous;

  /// No description provided for @desktopWallAnimOnEnter.
  ///
  /// In en, this message translates to:
  /// **'When a chat opens'**
  String get desktopWallAnimOnEnter;

  /// No description provided for @desktopWallAnimTap.
  ///
  /// In en, this message translates to:
  /// **'On a click on the background'**
  String get desktopWallAnimTap;

  /// No description provided for @desktopWallAnimOff.
  ///
  /// In en, this message translates to:
  /// **'Do not animate'**
  String get desktopWallAnimOff;

  /// No description provided for @desktopWallpaperNavy.
  ///
  /// In en, this message translates to:
  /// **'Midnight blue'**
  String get desktopWallpaperNavy;

  /// No description provided for @desktopWallpaperGraphite.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get desktopWallpaperGraphite;

  /// No description provided for @desktopWallpaperTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get desktopWallpaperTeal;

  /// No description provided for @desktopWallpaperPlum.
  ///
  /// In en, this message translates to:
  /// **'Plum'**
  String get desktopWallpaperPlum;

  /// No description provided for @desktopWallpaperWine.
  ///
  /// In en, this message translates to:
  /// **'Wine'**
  String get desktopWallpaperWine;

  /// No description provided for @desktopWallpaperMint.
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get desktopWallpaperMint;

  /// No description provided for @desktopWallpaperLavender.
  ///
  /// In en, this message translates to:
  /// **'Lavender'**
  String get desktopWallpaperLavender;

  /// No description provided for @desktopWallpaperSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get desktopWallpaperSunset;

  /// No description provided for @desktopWallpaperPeach.
  ///
  /// In en, this message translates to:
  /// **'Peach'**
  String get desktopWallpaperPeach;

  /// No description provided for @desktopWallpaperSky.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get desktopWallpaperSky;

  /// No description provided for @desktopWallpaperMidnight.
  ///
  /// In en, this message translates to:
  /// **'Midnight'**
  String get desktopWallpaperMidnight;

  /// No description provided for @desktopAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get desktopAppearanceTitle;

  /// No description provided for @desktopAppearanceHint.
  ///
  /// In en, this message translates to:
  /// **'The scheme of this window. The phone has its own — this setting does not travel anywhere.'**
  String get desktopAppearanceHint;

  /// No description provided for @desktopAppearanceScheme.
  ///
  /// In en, this message translates to:
  /// **'Scheme'**
  String get desktopAppearanceScheme;

  /// No description provided for @desktopAppearanceSchemeHint.
  ///
  /// In en, this message translates to:
  /// **'Dark, light or follow the system'**
  String get desktopAppearanceSchemeHint;

  /// No description provided for @desktopAppearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get desktopAppearanceDark;

  /// No description provided for @desktopAppearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get desktopAppearanceLight;

  /// No description provided for @desktopAppearanceAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get desktopAppearanceAuto;

  /// No description provided for @desktopAppearanceAccent.
  ///
  /// In en, this message translates to:
  /// **'Interface accent'**
  String get desktopAppearanceAccent;

  /// No description provided for @desktopAppearanceAccentHint.
  ///
  /// In en, this message translates to:
  /// **'Buttons, your own bubbles and selections across the application.'**
  String get desktopAppearanceAccentHint;

  /// No description provided for @desktopAppearanceWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Chat wallpaper'**
  String get desktopAppearanceWallpaper;

  /// No description provided for @desktopAppearanceWallpaperHint.
  ///
  /// In en, this message translates to:
  /// **'The chat background for every conversation.'**
  String get desktopAppearanceWallpaperHint;

  /// No description provided for @desktopAppearanceLiveWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Live wallpaper'**
  String get desktopAppearanceLiveWallpaper;

  /// No description provided for @desktopAppearanceLiveWallpaperHint.
  ///
  /// In en, this message translates to:
  /// **'A pattern with a soft shimmer. The same set as on the phone.'**
  String get desktopAppearanceLiveWallpaperHint;

  /// No description provided for @desktopAppearanceAnimBehaviour.
  ///
  /// In en, this message translates to:
  /// **'Animation behaviour'**
  String get desktopAppearanceAnimBehaviour;

  /// No description provided for @desktopAppearanceAnimBehaviourHint.
  ///
  /// In en, this message translates to:
  /// **'When the pattern comes alive.'**
  String get desktopAppearanceAnimBehaviourHint;

  /// No description provided for @desktopAppearanceWallPulse.
  ///
  /// In en, this message translates to:
  /// **'The wallpaper carries the message'**
  String get desktopAppearanceWallPulse;

  /// No description provided for @desktopAppearanceWallPulseHint.
  ///
  /// In en, this message translates to:
  /// **'A wave of light runs along the pattern: upwards when you send, downwards when you receive.'**
  String get desktopAppearanceWallPulseHint;

  /// No description provided for @desktopAppearanceEnable.
  ///
  /// In en, this message translates to:
  /// **'Switch on'**
  String get desktopAppearanceEnable;

  /// No description provided for @desktopAppearanceLiveOnly.
  ///
  /// In en, this message translates to:
  /// **'Works only on live wallpaper'**
  String get desktopAppearanceLiveOnly;

  /// No description provided for @desktopAppearanceBubbleStyle.
  ///
  /// In en, this message translates to:
  /// **'Message bubble style'**
  String get desktopAppearanceBubbleStyle;

  /// No description provided for @desktopAppearanceBubbleStyleHint.
  ///
  /// In en, this message translates to:
  /// **'The colour of your outgoing messages in every chat.'**
  String get desktopAppearanceBubbleStyleHint;

  /// No description provided for @desktopAppearanceSenderColour.
  ///
  /// In en, this message translates to:
  /// **'Sender name colour'**
  String get desktopAppearanceSenderColour;

  /// No description provided for @desktopAppearanceSenderColourHint.
  ///
  /// In en, this message translates to:
  /// **'The colour of the other person’s nickname in group chats.'**
  String get desktopAppearanceSenderColourHint;

  /// No description provided for @desktopAppearanceIndicatorColour.
  ///
  /// In en, this message translates to:
  /// **'Indicator colour'**
  String get desktopAppearanceIndicatorColour;

  /// No description provided for @desktopAppearanceIndicatorColourHint.
  ///
  /// In en, this message translates to:
  /// **'The delivery ticks and the unread dot.'**
  String get desktopAppearanceIndicatorColourHint;

  /// No description provided for @desktopAppearanceDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode'**
  String get desktopAppearanceDemoMode;

  /// No description provided for @desktopAppearanceDemoHint.
  ///
  /// In en, this message translates to:
  /// **'Appearance changes will be kept once a profile is linked.'**
  String get desktopAppearanceDemoHint;

  /// No description provided for @desktopAppearanceCurrentChoice.
  ///
  /// In en, this message translates to:
  /// **'Current choice'**
  String get desktopAppearanceCurrentChoice;

  /// No description provided for @desktopAppearanceThemeIs.
  ///
  /// In en, this message translates to:
  /// **'Theme: {name}'**
  String desktopAppearanceThemeIs(Object name);

  /// No description provided for @desktopBackupEvery6h.
  ///
  /// In en, this message translates to:
  /// **'Every 6 hours'**
  String get desktopBackupEvery6h;

  /// No description provided for @desktopBackupEvery12h.
  ///
  /// In en, this message translates to:
  /// **'Every 12 hours'**
  String get desktopBackupEvery12h;

  /// No description provided for @desktopBackupDaily.
  ///
  /// In en, this message translates to:
  /// **'Once a day'**
  String get desktopBackupDaily;

  /// No description provided for @desktopBackupWeekly.
  ///
  /// In en, this message translates to:
  /// **'Once a week'**
  String get desktopBackupWeekly;

  /// No description provided for @desktopBackupOffWarning.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup is off — there will be nothing to restore the history from'**
  String get desktopBackupOffWarning;

  /// No description provided for @desktopBackupNeverRan.
  ///
  /// In en, this message translates to:
  /// **'On, but it has never run yet'**
  String get desktopBackupNeverRan;

  /// No description provided for @desktopBackupLastFailedWith.
  ///
  /// In en, this message translates to:
  /// **'The last backup failed: {error}'**
  String desktopBackupLastFailedWith(Object error);

  /// No description provided for @desktopBackupLastFailed.
  ///
  /// In en, this message translates to:
  /// **'The last backup failed'**
  String get desktopBackupLastFailed;

  /// No description provided for @desktopBackupStale.
  ///
  /// In en, this message translates to:
  /// **'The backup has not been updated for a while'**
  String get desktopBackupStale;

  /// No description provided for @desktopBackupFresh.
  ///
  /// In en, this message translates to:
  /// **'The backup is up to date'**
  String get desktopBackupFresh;

  /// No description provided for @desktopBackupState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get desktopBackupState;

  /// No description provided for @desktopBackupAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get desktopBackupAutomatic;

  /// No description provided for @desktopBackupAutomaticHint.
  ///
  /// In en, this message translates to:
  /// **'The backup is encrypted with your password. Without it neither we nor anyone else can restore it — so the password has to be remembered.'**
  String get desktopBackupAutomaticHint;

  /// No description provided for @desktopBackupCreateAuto.
  ///
  /// In en, this message translates to:
  /// **'Create automatically'**
  String get desktopBackupCreateAuto;

  /// No description provided for @desktopBackupUploadServer.
  ///
  /// In en, this message translates to:
  /// **'Upload to the server'**
  String get desktopBackupUploadServer;

  /// No description provided for @desktopBackupUploadServerHint.
  ///
  /// In en, this message translates to:
  /// **'Available from any device'**
  String get desktopBackupUploadServerHint;

  /// No description provided for @desktopBackupKeepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep on this computer'**
  String get desktopBackupKeepLocal;

  /// No description provided for @desktopBackupKeepLocalHint.
  ///
  /// In en, this message translates to:
  /// **'Does not depend on the network'**
  String get desktopBackupKeepLocalHint;

  /// No description provided for @desktopBackupIncludeMedia.
  ///
  /// In en, this message translates to:
  /// **'Include media'**
  String get desktopBackupIncludeMedia;

  /// No description provided for @desktopBackupIncludeMediaHint.
  ///
  /// In en, this message translates to:
  /// **'The backup will get noticeably bigger'**
  String get desktopBackupIncludeMediaHint;

  /// No description provided for @desktopBackupFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get desktopBackupFrequency;

  /// No description provided for @desktopBackupNowhereTitle.
  ///
  /// In en, this message translates to:
  /// **'The backup is saved nowhere'**
  String get desktopBackupNowhereTitle;

  /// No description provided for @desktopBackupNowhereHint.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup is on but both destinations are off, which means no backup is made. Switch on the server or this computer.'**
  String get desktopBackupNowhereHint;

  /// No description provided for @desktopBackupRecoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Recovery kit'**
  String get desktopBackupRecoveryKey;

  /// No description provided for @desktopBackupCreateRecoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Create a recovery kit'**
  String get desktopBackupCreateRecoveryKey;

  /// No description provided for @desktopBackupRecoveryKeyHint.
  ///
  /// In en, this message translates to:
  /// **'You will need it if no device with Secretly is left. Keep it separately from the password.'**
  String get desktopBackupRecoveryKeyHint;

  /// No description provided for @desktopBackupKeyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the key: {error}'**
  String desktopBackupKeyFailed(Object error);

  /// No description provided for @desktopBackupKeyPassword.
  ///
  /// In en, this message translates to:
  /// **'Password for the recovery kit'**
  String get desktopBackupKeyPassword;

  /// No description provided for @desktopBackupPasswordsDiffer.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get desktopBackupPasswordsDiffer;

  /// No description provided for @desktopBackupKeyPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'This password encrypts the kit itself. It does not replace the application password and is stored nowhere — it cannot be recovered.'**
  String get desktopBackupKeyPasswordHint;

  /// No description provided for @desktopBackupPasswordAgain.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get desktopBackupPasswordAgain;

  /// No description provided for @desktopUnblockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unblock {name}?'**
  String desktopUnblockTitle(Object name);

  /// No description provided for @desktopUnblockBody.
  ///
  /// In en, this message translates to:
  /// **'This person will be able to write to you and call you again.'**
  String get desktopUnblockBody;

  /// No description provided for @desktopUnblockAction.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get desktopUnblockAction;

  /// No description provided for @desktopPrivacyLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get desktopPrivacyLastSeen;

  /// No description provided for @desktopPrivacyProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photos'**
  String get desktopPrivacyProfilePhoto;

  /// No description provided for @desktopPrivacyForwarding.
  ///
  /// In en, this message translates to:
  /// **'Message forwarding'**
  String get desktopPrivacyForwarding;

  /// No description provided for @desktopPrivacyCalls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get desktopPrivacyCalls;

  /// No description provided for @desktopPrivacyVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice messages'**
  String get desktopPrivacyVoice;

  /// No description provided for @desktopPrivacyMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get desktopPrivacyMessages;

  /// No description provided for @desktopPrivacyNobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody'**
  String get desktopPrivacyNobody;

  /// No description provided for @desktopPrivacyEverybody.
  ///
  /// In en, this message translates to:
  /// **'Everybody'**
  String get desktopPrivacyEverybody;

  /// No description provided for @desktopPrivacyContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get desktopPrivacyContacts;

  /// No description provided for @desktopPrivacyEncryption.
  ///
  /// In en, this message translates to:
  /// **'Encryption'**
  String get desktopPrivacyEncryption;

  /// No description provided for @desktopPrivacyEncryptionHint.
  ///
  /// In en, this message translates to:
  /// **'Every message and call is end-to-end encrypted. The keys live only on your devices.'**
  String get desktopPrivacyEncryptionHint;

  /// No description provided for @desktopPrivacyE2eeActive.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encryption is active'**
  String get desktopPrivacyE2eeActive;

  /// No description provided for @desktopPrivacyWhoSees.
  ///
  /// In en, this message translates to:
  /// **'Who sees'**
  String get desktopPrivacyWhoSees;

  /// No description provided for @desktopPrivacyWhoSeesHint.
  ///
  /// In en, this message translates to:
  /// **'The same visibility settings as in the mobile application.'**
  String get desktopPrivacyWhoSeesHint;

  /// No description provided for @desktopPrivacyVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get desktopPrivacyVisibility;

  /// No description provided for @desktopPrivacyByNickname.
  ///
  /// In en, this message translates to:
  /// **'Findable by nickname'**
  String get desktopPrivacyByNickname;

  /// No description provided for @desktopPrivacyByNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Let people find you by your nickname'**
  String get desktopPrivacyByNicknameHint;

  /// No description provided for @desktopPrivacySuggest.
  ///
  /// In en, this message translates to:
  /// **'Suggest people in search'**
  String get desktopPrivacySuggest;

  /// No description provided for @desktopPrivacyStrangers.
  ///
  /// In en, this message translates to:
  /// **'New chats from strangers'**
  String get desktopPrivacyStrangers;

  /// No description provided for @desktopPrivacyStrangersHint.
  ///
  /// In en, this message translates to:
  /// **'To the archive and without notifications'**
  String get desktopPrivacyStrangersHint;

  /// No description provided for @desktopPrivacyAutoDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get desktopPrivacyAutoDelete;

  /// No description provided for @desktopPrivacyAutoDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'If you do not sign in for longer than the chosen period, the account and every message are deleted automatically. The countdown resets on each sign-in.'**
  String get desktopPrivacyAutoDeleteHint;

  /// No description provided for @desktopPrivacyIfAbsent.
  ///
  /// In en, this message translates to:
  /// **'If I do not sign in'**
  String get desktopPrivacyIfAbsent;

  /// No description provided for @desktopPrivacyIn1Month.
  ///
  /// In en, this message translates to:
  /// **'After 1 month'**
  String get desktopPrivacyIn1Month;

  /// No description provided for @desktopPrivacyIn3Months.
  ///
  /// In en, this message translates to:
  /// **'After 3 months'**
  String get desktopPrivacyIn3Months;

  /// No description provided for @desktopPrivacyIn6Months.
  ///
  /// In en, this message translates to:
  /// **'After 6 months'**
  String get desktopPrivacyIn6Months;

  /// No description provided for @desktopPrivacyIn1Year.
  ///
  /// In en, this message translates to:
  /// **'After a year'**
  String get desktopPrivacyIn1Year;

  /// No description provided for @desktopPrivacyIn2Years.
  ///
  /// In en, this message translates to:
  /// **'After 2 years'**
  String get desktopPrivacyIn2Years;

  /// No description provided for @desktopLockImmediately.
  ///
  /// In en, this message translates to:
  /// **'As soon as focus is lost'**
  String get desktopLockImmediately;

  /// No description provided for @desktopLockSeconds.
  ///
  /// In en, this message translates to:
  /// **'{value} s'**
  String desktopLockSeconds(Object value);

  /// No description provided for @desktopLockMinutes.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String desktopLockMinutes(Object value);

  /// No description provided for @desktopLockHours.
  ///
  /// In en, this message translates to:
  /// **'{value} h'**
  String desktopLockHours(Object value);

  /// No description provided for @desktopLockNoIdentityService.
  ///
  /// In en, this message translates to:
  /// **'The identity-check service is unavailable — the lock was not switched on.'**
  String get desktopLockNoIdentityService;

  /// No description provided for @desktopLockNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'The lock was not switched on: the confirmation did not pass.'**
  String get desktopLockNotConfirmed;

  /// No description provided for @desktopLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Application lock'**
  String get desktopLockTitle;

  /// No description provided for @desktopLockTouchIdHint.
  ///
  /// In en, this message translates to:
  /// **'Ask for Touch ID to get back in after focus is lost.'**
  String get desktopLockTouchIdHint;

  /// No description provided for @desktopLockPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Ask for the device password to get back in after focus is lost.'**
  String get desktopLockPasswordHint;

  /// No description provided for @desktopLockEnableTouchId.
  ///
  /// In en, this message translates to:
  /// **'Switch on Touch ID'**
  String get desktopLockEnableTouchId;

  /// No description provided for @desktopLockEnableLock.
  ///
  /// In en, this message translates to:
  /// **'Switch on the lock'**
  String get desktopLockEnableLock;

  /// No description provided for @desktopLockDevicePassword.
  ///
  /// In en, this message translates to:
  /// **'Device password'**
  String get desktopLockDevicePassword;

  /// No description provided for @desktopLockAfter.
  ///
  /// In en, this message translates to:
  /// **'Lock after'**
  String get desktopLockAfter;

  /// No description provided for @desktopLockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get desktopLockNow;

  /// No description provided for @desktopDevicesEndSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'End the session?'**
  String get desktopDevicesEndSessionTitle;

  /// No description provided for @desktopDevicesEndSessionBody.
  ///
  /// In en, this message translates to:
  /// **'Device {id} will be disconnected from your profile. Getting access back needs a new QR scan. Continue?'**
  String desktopDevicesEndSessionBody(Object id);

  /// No description provided for @desktopDevicesEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get desktopDevicesEnd;

  /// No description provided for @desktopDevicesEndFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not end the session: {error}'**
  String desktopDevicesEndFailed(Object error);

  /// No description provided for @desktopDevicesEnded.
  ///
  /// In en, this message translates to:
  /// **'The device session has ended.'**
  String get desktopDevicesEnded;

  /// No description provided for @desktopDevicesActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get desktopDevicesActiveSessions;

  /// No description provided for @desktopDevicesDemoHint.
  ///
  /// In en, this message translates to:
  /// **'Demo mode · real devices will appear once a profile is connected'**
  String get desktopDevicesDemoHint;

  /// No description provided for @desktopDevicesThisComputer.
  ///
  /// In en, this message translates to:
  /// **'macOS · This computer'**
  String get desktopDevicesThisComputer;

  /// No description provided for @desktopDevicesDemoMac.
  ///
  /// In en, this message translates to:
  /// **'MacBook Pro · Active now'**
  String get desktopDevicesDemoMac;

  /// No description provided for @desktopDevicesDemoIphone.
  ///
  /// In en, this message translates to:
  /// **'iOS 18.2 · 2 hours ago (demo)'**
  String get desktopDevicesDemoIphone;

  /// No description provided for @desktopDevicesDemoIpad.
  ///
  /// In en, this message translates to:
  /// **'iPadOS 18 · yesterday (demo)'**
  String get desktopDevicesDemoIpad;

  /// No description provided for @desktopDevicesThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get desktopDevicesThisDevice;

  /// No description provided for @desktopDevicesRemoteDevice.
  ///
  /// In en, this message translates to:
  /// **'Remote device'**
  String get desktopDevicesRemoteDevice;

  /// No description provided for @desktopDevicesDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get desktopDevicesDisconnect;

  /// No description provided for @desktopDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get desktopDevicesTitle;

  /// No description provided for @desktopDevicesTitleCount.
  ///
  /// In en, this message translates to:
  /// **'Devices · {count}'**
  String desktopDevicesTitleCount(Object count);

  /// No description provided for @desktopDevicesHint.
  ///
  /// In en, this message translates to:
  /// **'The devices linked to this profile on the key server.'**
  String get desktopDevicesHint;

  /// No description provided for @desktopDevicesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load'**
  String get desktopDevicesLoadFailed;

  /// No description provided for @desktopDevicesRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get desktopDevicesRetry;

  /// No description provided for @desktopDevicesNone.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get desktopDevicesNone;

  /// No description provided for @desktopDevicesNotLinked.
  ///
  /// In en, this message translates to:
  /// **'The profile is not linked to the server yet.'**
  String get desktopDevicesNotLinked;

  /// No description provided for @desktopDevicesRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh the list'**
  String get desktopDevicesRefresh;

  /// No description provided for @desktopAccentCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom colour'**
  String get desktopAccentCustom;

  /// No description provided for @desktopAccentCustomChange.
  ///
  /// In en, this message translates to:
  /// **'Custom colour — change'**
  String get desktopAccentCustomChange;

  /// No description provided for @desktopPairTitle.
  ///
  /// In en, this message translates to:
  /// **'Link a device'**
  String get desktopPairTitle;

  /// No description provided for @desktopPairHint.
  ///
  /// In en, this message translates to:
  /// **'Show the QR code on the new device or scan it from the phone'**
  String get desktopPairHint;

  /// No description provided for @desktopPairRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the link request'**
  String get desktopPairRequestFailed;

  /// No description provided for @desktopPairCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'The QR contents were copied'**
  String get desktopPairCodeCopied;

  /// No description provided for @desktopPairNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Link a new device'**
  String get desktopPairNewTitle;

  /// No description provided for @desktopPairNewHint.
  ///
  /// In en, this message translates to:
  /// **'On the new device open Secretly and choose “Connect by QR”. Then scan the code below.'**
  String get desktopPairNewHint;

  /// No description provided for @desktopPairClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get desktopPairClose;

  /// No description provided for @desktopPairCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy the code'**
  String get desktopPairCopyCode;

  /// No description provided for @desktopPairRefreshQr.
  ///
  /// In en, this message translates to:
  /// **'Refresh the QR'**
  String get desktopPairRefreshQr;

  /// No description provided for @desktopSyncPulled.
  ///
  /// In en, this message translates to:
  /// **'New events pulled: {count}'**
  String desktopSyncPulled(Object count);

  /// No description provided for @desktopSyncTooOften.
  ///
  /// In en, this message translates to:
  /// **'Too many requests — try again later'**
  String get desktopSyncTooOften;

  /// No description provided for @desktopSyncNothingNew.
  ///
  /// In en, this message translates to:
  /// **'Done · no new events'**
  String get desktopSyncNothingNew;

  /// No description provided for @desktopSyncDemoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available in demo mode'**
  String get desktopSyncDemoUnavailable;

  /// No description provided for @desktopSyncBlobsPulled.
  ///
  /// In en, this message translates to:
  /// **'Attachments pulled: {blobs} (chats: {convos})'**
  String desktopSyncBlobsPulled(Object blobs, Object convos);

  /// No description provided for @desktopSyncNoBlobs.
  ///
  /// In en, this message translates to:
  /// **'Done · no new attachments (chats: {convos})'**
  String desktopSyncNoBlobs(Object convos);

  /// No description provided for @desktopSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'History from other devices'**
  String get desktopSyncTitle;

  /// No description provided for @desktopSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the mobile device for the recent chat history. Used when the desktop has been offline for more than 7 days or has just been linked by QR.'**
  String get desktopSyncHint;

  /// No description provided for @desktopSyncRunning.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get desktopSyncRunning;

  /// No description provided for @desktopSyncAskHistory.
  ///
  /// In en, this message translates to:
  /// **'Ask for the history'**
  String get desktopSyncAskHistory;

  /// No description provided for @desktopSyncAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get desktopSyncAsk;

  /// No description provided for @desktopSyncBlobsRunning.
  ///
  /// In en, this message translates to:
  /// **'Downloading attachments…'**
  String get desktopSyncBlobsRunning;

  /// No description provided for @desktopSyncBlobsAction.
  ///
  /// In en, this message translates to:
  /// **'Fetch the attachments'**
  String get desktopSyncBlobsAction;

  /// No description provided for @desktopSyncBlobsHint.
  ///
  /// In en, this message translates to:
  /// **'Downloads media from recent chats when the files are missing locally (after re-linking or a long time offline).'**
  String get desktopSyncBlobsHint;

  /// No description provided for @desktopSyncBlobsShort.
  ///
  /// In en, this message translates to:
  /// **'Fetch'**
  String get desktopSyncBlobsShort;

  /// No description provided for @desktopServerBackupOk.
  ///
  /// In en, this message translates to:
  /// **'Backup on the server ✓ · {stamp} · {size} KB · profile {profile}'**
  String desktopServerBackupOk(Object stamp, Object size, Object profile);

  /// No description provided for @desktopServerBackupPassword.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get desktopServerBackupPassword;

  /// No description provided for @desktopServerBackupPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'This password encrypts the backup and restores it on any device. Remember it — without it the backup is useless, and it cannot be recovered.'**
  String get desktopServerBackupPasswordHint;

  /// No description provided for @desktopServerBackupRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat the password'**
  String get desktopServerBackupRepeat;

  /// No description provided for @desktopServerBackupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create the backup'**
  String get desktopServerBackupCreate;

  /// No description provided for @desktopServerBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup to the server'**
  String get desktopServerBackupTitle;

  /// No description provided for @desktopServerBackupHint.
  ///
  /// In en, this message translates to:
  /// **'An encrypted copy of the account on the Secretly server. It is restored on any device through “Restore from the server” with your Secretly ID and password.'**
  String get desktopServerBackupHint;

  /// No description provided for @desktopServerBackupLoading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get desktopServerBackupLoading;

  /// No description provided for @desktopServerBackupCreateOnServer.
  ///
  /// In en, this message translates to:
  /// **'Create a backup on the server'**
  String get desktopServerBackupCreateOnServer;

  /// No description provided for @desktopServerBackupUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update the backup'**
  String get desktopServerBackupUpdate;

  /// No description provided for @desktopFailedWith.
  ///
  /// In en, this message translates to:
  /// **'It did not work: {error}'**
  String desktopFailedWith(Object error);

  /// No description provided for @desktopStorageDeleteModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the recognition model?'**
  String get desktopStorageDeleteModelTitle;

  /// No description provided for @desktopStorageDeleteModelBody.
  ///
  /// In en, this message translates to:
  /// **'Transcribing voice messages will stop working until the model is downloaded again.'**
  String get desktopStorageDeleteModelBody;

  /// No description provided for @desktopStorageModelDeleted.
  ///
  /// In en, this message translates to:
  /// **'The model was deleted'**
  String get desktopStorageModelDeleted;

  /// No description provided for @desktopStorageDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete: {error}'**
  String desktopStorageDeleteFailed(Object error);

  /// No description provided for @desktopStorageKb.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String desktopStorageKb(Object value);

  /// No description provided for @desktopStorageMb.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String desktopStorageMb(Object value);

  /// No description provided for @desktopStorageGb.
  ///
  /// In en, this message translates to:
  /// **'{value} GB'**
  String desktopStorageGb(Object value);

  /// No description provided for @desktopStorageUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get desktopStorageUsage;

  /// No description provided for @desktopStorageUsageHint.
  ///
  /// In en, this message translates to:
  /// **'Cache and media on this device'**
  String get desktopStorageUsageHint;

  /// No description provided for @desktopStorageClearHint.
  ///
  /// In en, this message translates to:
  /// **'{size} will be freed. Messages, files you sent and the recent ones are not deleted — there would be nowhere to restore them from.'**
  String desktopStorageClearHint(Object size);

  /// No description provided for @desktopStorageClear.
  ///
  /// In en, this message translates to:
  /// **'Clear the cache'**
  String get desktopStorageClear;

  /// No description provided for @desktopStorageCounting.
  ///
  /// In en, this message translates to:
  /// **'Counting…'**
  String get desktopStorageCounting;

  /// No description provided for @desktopStorageSpeechModel.
  ///
  /// In en, this message translates to:
  /// **'Speech-recognition model'**
  String get desktopStorageSpeechModel;

  /// No description provided for @desktopStorageSpeechModelHint.
  ///
  /// In en, this message translates to:
  /// **'Used to transcribe voice messages on this computer, without sending the audio anywhere. A normal cache clear does NOT remove it — it is large and downloaded separately.'**
  String get desktopStorageSpeechModelHint;

  /// No description provided for @desktopStorageDeleteModel.
  ///
  /// In en, this message translates to:
  /// **'Delete the model'**
  String get desktopStorageDeleteModel;

  /// No description provided for @desktopStorageMedia.
  ///
  /// In en, this message translates to:
  /// **'Media · {size}'**
  String desktopStorageMedia(Object size);

  /// No description provided for @desktopStorageVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice · {size}'**
  String desktopStorageVoice(Object size);

  /// No description provided for @desktopStorageOther.
  ///
  /// In en, this message translates to:
  /// **'Other · {size}'**
  String desktopStorageOther(Object size);

  /// No description provided for @desktopStorageFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get desktopStorageFree;

  /// No description provided for @desktopStorageTotal.
  ///
  /// In en, this message translates to:
  /// **'Total · {size}'**
  String desktopStorageTotal(Object size);

  /// No description provided for @desktopAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · build {build}'**
  String desktopAboutVersion(Object version, Object build);

  /// No description provided for @desktopAboutTagline.
  ///
  /// In en, this message translates to:
  /// **'A secure messenger with end-to-end encryption. No cloud. No advertising. Open source.'**
  String get desktopAboutTagline;

  /// No description provided for @desktopAboutLicences.
  ///
  /// In en, this message translates to:
  /// **'Licences'**
  String get desktopAboutLicences;

  /// No description provided for @desktopAboutWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get desktopAboutWebsite;

  /// No description provided for @desktopDangerTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the account irreversibly?'**
  String get desktopDangerTitle;

  /// No description provided for @desktopDangerBody.
  ///
  /// In en, this message translates to:
  /// **'The profile, the keys, the local data and the message history will be deleted on this and other devices. There is no way back.'**
  String get desktopDangerBody;

  /// No description provided for @desktopDangerDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting the account…'**
  String get desktopDangerDeleting;

  /// No description provided for @desktopDangerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the account: {error}'**
  String desktopDangerFailed(Object error);

  /// No description provided for @desktopDangerSection.
  ///
  /// In en, this message translates to:
  /// **'Deleting the account'**
  String get desktopDangerSection;

  /// No description provided for @desktopDangerDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo mode · deleting is unavailable without a connected profile.'**
  String get desktopDangerDemo;

  /// No description provided for @desktopDangerEnterId.
  ///
  /// In en, this message translates to:
  /// **'Type your Secretly ID to confirm'**
  String get desktopDangerEnterId;

  /// No description provided for @desktopDangerEnterIdExact.
  ///
  /// In en, this message translates to:
  /// **'Type {id} to confirm'**
  String desktopDangerEnterIdExact(Object id);

  /// No description provided for @desktopDangerAction.
  ///
  /// In en, this message translates to:
  /// **'Delete the account'**
  String get desktopDangerAction;

  /// No description provided for @desktopDangerIrreversible.
  ///
  /// In en, this message translates to:
  /// **'This is irreversible. All your data, the message history and the keys will be deleted. There is no way back.'**
  String get desktopDangerIrreversible;

  /// No description provided for @desktopSecurityE2ee.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encryption'**
  String get desktopSecurityE2ee;

  /// No description provided for @desktopSecurityE2eeHint.
  ///
  /// In en, this message translates to:
  /// **'Every message, call and file is encrypted on your device. The keys never leave your devices — the server sees only ciphertext.'**
  String get desktopSecurityE2eeHint;

  /// No description provided for @desktopSecurityVerifiedDevices.
  ///
  /// In en, this message translates to:
  /// **'Verified devices'**
  String get desktopSecurityVerifiedDevices;

  /// No description provided for @desktopSecurityVerifiedHint.
  ///
  /// In en, this message translates to:
  /// **'While this is on, messages are not sent to the other person’s unconfirmed devices. It guards against substitution, but a message may not arrive until they confirm a new device. One-to-one chats only: it does not apply to groups.'**
  String get desktopSecurityVerifiedHint;

  /// No description provided for @desktopSecurityOnlyVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified devices only'**
  String get desktopSecurityOnlyVerified;

  /// No description provided for @desktopSecurityBlocked.
  ///
  /// In en, this message translates to:
  /// **'Unverified devices are blocked'**
  String get desktopSecurityBlocked;

  /// No description provided for @desktopSecurityAllDevices.
  ///
  /// In en, this message translates to:
  /// **'Messages go to all of the other person’s devices'**
  String get desktopSecurityAllDevices;

  /// No description provided for @desktopSecurityAppEntry.
  ///
  /// In en, this message translates to:
  /// **'Entry to the application'**
  String get desktopSecurityAppEntry;

  /// No description provided for @desktopSecurityAppEntryHint.
  ///
  /// In en, this message translates to:
  /// **'A password when Secretly opens and after the window has been hidden for more than a minute. It applies to this computer.'**
  String get desktopSecurityAppEntryHint;

  /// No description provided for @desktopSecurityPersonalScopeHint.
  ///
  /// In en, this message translates to:
  /// **'A separate password for the “Personal” category. Without it, personal chats are open to anyone with access to an unlocked computer.'**
  String get desktopSecurityPersonalScopeHint;

  /// No description provided for @desktopCallsInApp.
  ///
  /// In en, this message translates to:
  /// **'Calls in the application'**
  String get desktopCallsInApp;

  /// No description provided for @desktopCallsInAppHint.
  ///
  /// In en, this message translates to:
  /// **'Switch off to disable calls entirely'**
  String get desktopCallsInAppHint;

  /// No description provided for @desktopCallsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept incoming calls'**
  String get desktopCallsAccept;

  /// No description provided for @desktopCallsAcceptHint.
  ///
  /// In en, this message translates to:
  /// **'People will be able to call you'**
  String get desktopCallsAcceptHint;

  /// No description provided for @desktopCallsDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Unavailable while calls are off'**
  String get desktopCallsDisabledHint;

  /// No description provided for @desktopCallsScreenShare.
  ///
  /// In en, this message translates to:
  /// **'Screen sharing'**
  String get desktopCallsScreenShare;

  /// No description provided for @desktopCallsScreenShareHint.
  ///
  /// In en, this message translates to:
  /// **'Receiving someone else’s screen is a separate permission: what appears there may not be what you expected to see.'**
  String get desktopCallsScreenShareHint;

  /// No description provided for @desktopCallsAcceptScreenShare.
  ///
  /// In en, this message translates to:
  /// **'Accept screen sharing'**
  String get desktopCallsAcceptScreenShare;

  /// No description provided for @desktopAccountIdCopied.
  ///
  /// In en, this message translates to:
  /// **'The Secretly ID was copied'**
  String get desktopAccountIdCopied;

  /// No description provided for @desktopAccountIdHint.
  ///
  /// In en, this message translates to:
  /// **'This identifier is what you share so people can find you. It carries neither a phone number nor an email address.'**
  String get desktopAccountIdHint;

  /// No description provided for @desktopAccountCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get desktopAccountCopy;

  /// No description provided for @desktopAccountProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get desktopAccountProfile;

  /// No description provided for @desktopAccountProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Name, photo, status'**
  String get desktopAccountProfileHint;

  /// No description provided for @desktopAccountOpenProfile.
  ///
  /// In en, this message translates to:
  /// **'Open the profile page'**
  String get desktopAccountOpenProfile;

  /// No description provided for @desktopScopePasswordFor.
  ///
  /// In en, this message translates to:
  /// **'Password for “{name}”'**
  String desktopScopePasswordFor(Object name);

  /// No description provided for @desktopScopeMin4.
  ///
  /// In en, this message translates to:
  /// **'At least 4 characters'**
  String get desktopScopeMin4;

  /// No description provided for @desktopScopeOn.
  ///
  /// In en, this message translates to:
  /// **'Protection is on'**
  String get desktopScopeOn;

  /// No description provided for @desktopScopeOnFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch on: {error}'**
  String desktopScopeOnFailed(Object error);

  /// No description provided for @desktopScopeOff.
  ///
  /// In en, this message translates to:
  /// **'Protection is off'**
  String get desktopScopeOff;

  /// No description provided for @desktopScopeOffFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch off: {error}'**
  String desktopScopeOffFailed(Object error);

  /// No description provided for @desktopScopePasswordsDiffer.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match'**
  String get desktopScopePasswordsDiffer;

  /// No description provided for @desktopScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Password protection'**
  String get desktopScopeTitle;

  /// No description provided for @desktopScopeOnWithPassword.
  ///
  /// In en, this message translates to:
  /// **'On — password'**
  String get desktopScopeOnWithPassword;

  /// No description provided for @desktopScopeEnabled.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get desktopScopeEnabled;

  /// No description provided for @desktopScopeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get desktopScopeDisabled;

  /// No description provided for @desktopScopeChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change the password'**
  String get desktopScopeChangePassword;

  /// No description provided for @desktopScopeLockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get desktopScopeLockNow;

  /// No description provided for @desktopBlockedUnblocked.
  ///
  /// In en, this message translates to:
  /// **'{name} was unblocked'**
  String desktopBlockedUnblocked(Object name);

  /// No description provided for @desktopBlockedUnblockFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not unblock: {error}'**
  String desktopBlockedUnblockFailed(Object error);

  /// No description provided for @desktopBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get desktopBlockedTitle;

  /// No description provided for @desktopBlockedEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'The list is empty. Blocking is done from a chat’s menu.'**
  String get desktopBlockedEmptyHint;

  /// No description provided for @desktopBlockedHint.
  ///
  /// In en, this message translates to:
  /// **'These people cannot write to you or call you.'**
  String get desktopBlockedHint;

  /// No description provided for @desktopBlockedNone.
  ///
  /// In en, this message translates to:
  /// **'Nobody is blocked'**
  String get desktopBlockedNone;

  /// No description provided for @desktopSupportSent.
  ///
  /// In en, this message translates to:
  /// **'The message was sent'**
  String get desktopSupportSent;

  /// No description provided for @desktopSupportSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send. Check your connection.'**
  String get desktopSupportSendFailed;

  /// No description provided for @desktopSupportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Support is unavailable'**
  String get desktopSupportUnavailable;

  /// No description provided for @desktopSupportUnavailableHint.
  ///
  /// In en, this message translates to:
  /// **'The support service is switched off right now. Try later or write from the phone.'**
  String get desktopSupportUnavailableHint;

  /// No description provided for @desktopSupportThread.
  ///
  /// In en, this message translates to:
  /// **'The conversation with support'**
  String get desktopSupportThread;

  /// No description provided for @desktopSupportThreadHint.
  ///
  /// In en, this message translates to:
  /// **'Messages are encrypted on your device. The server keeps only ciphertext — only support can read the conversation.'**
  String get desktopSupportThreadHint;

  /// No description provided for @desktopSupportNoReplies.
  ///
  /// In en, this message translates to:
  /// **'No replies yet. Describe the problem — the answer will arrive here.'**
  String get desktopSupportNoReplies;

  /// No description provided for @desktopSupportWrite.
  ///
  /// In en, this message translates to:
  /// **'Write to support'**
  String get desktopSupportWrite;

  /// No description provided for @desktopSupportWriteHint.
  ///
  /// In en, this message translates to:
  /// **'The build version and the device identifier are attached automatically — without them the problem is nearly impossible to reproduce.'**
  String get desktopSupportWriteHint;

  /// No description provided for @desktopSupportDescribe.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened'**
  String get desktopSupportDescribe;

  /// No description provided for @desktopSupportSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get desktopSupportSending;

  /// No description provided for @desktopSupportSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get desktopSupportSend;

  /// No description provided for @desktopChatsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation from the phone — chats sync to the desktop automatically'**
  String get desktopChatsEmptyHint;

  /// No description provided for @desktopChatsPickOne.
  ///
  /// In en, this message translates to:
  /// **'Pick a chat on the left'**
  String get desktopChatsPickOne;

  /// No description provided for @desktopChatsSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send: {error}'**
  String desktopChatsSendFailed(Object error);

  /// No description provided for @desktopChatsSendingTo.
  ///
  /// In en, this message translates to:
  /// **'Sending to “{title}”'**
  String desktopChatsSendingTo(Object title);

  /// No description provided for @desktopChatsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get desktopChatsFilterAll;

  /// No description provided for @desktopChatsFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get desktopChatsFilterUnread;

  /// No description provided for @desktopChatsFilterGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get desktopChatsFilterGroups;

  /// No description provided for @desktopChatsFilterArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get desktopChatsFilterArchive;

  /// No description provided for @desktopChatsFilterPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get desktopChatsFilterPersonal;

  /// No description provided for @desktopChatsRenameFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename the folder'**
  String get desktopChatsRenameFolder;

  /// No description provided for @desktopChatsDeleteFolder.
  ///
  /// In en, this message translates to:
  /// **'Delete the folder'**
  String get desktopChatsDeleteFolder;

  /// No description provided for @desktopChatsRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not rename: {error}'**
  String desktopChatsRenameFailed(Object error);

  /// No description provided for @desktopChatsDeleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the folder “{name}”?'**
  String desktopChatsDeleteFolderTitle(Object name);

  /// No description provided for @desktopChatsDeleteFolderBody.
  ///
  /// In en, this message translates to:
  /// **'The chats stay where they are — only the folder is deleted.'**
  String get desktopChatsDeleteFolderBody;

  /// No description provided for @desktopChatsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete: {error}'**
  String desktopChatsDeleteFailed(Object error);

  /// No description provided for @desktopChatsAddedToFolder.
  ///
  /// In en, this message translates to:
  /// **'Added to “{name}”'**
  String desktopChatsAddedToFolder(Object name);

  /// No description provided for @desktopChatsRemovedFromFolder.
  ///
  /// In en, this message translates to:
  /// **'Removed from “{name}”'**
  String desktopChatsRemovedFromFolder(Object name);

  /// No description provided for @desktopChatsFolderChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the folder: {error}'**
  String desktopChatsFolderChangeFailed(Object error);

  /// No description provided for @desktopChatsFolderCreated.
  ///
  /// In en, this message translates to:
  /// **'The folder “{name}” was created'**
  String desktopChatsFolderCreated(Object name);

  /// No description provided for @desktopChatsFolderCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the folder: {error}'**
  String desktopChatsFolderCreateFailed(Object error);

  /// No description provided for @desktopChatsNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get desktopChatsNewFolder;

  /// No description provided for @desktopChatsFolderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get desktopChatsFolderName;

  /// No description provided for @desktopChatsRemoveFromFolder.
  ///
  /// In en, this message translates to:
  /// **'Remove from “{name}”'**
  String desktopChatsRemoveFromFolder(Object name);

  /// No description provided for @desktopChatsAddToFolder.
  ///
  /// In en, this message translates to:
  /// **'To the folder “{name}”'**
  String desktopChatsAddToFolder(Object name);

  /// No description provided for @desktopChatsNewFolderWithChat.
  ///
  /// In en, this message translates to:
  /// **'New folder with this chat…'**
  String get desktopChatsNewFolderWithChat;

  /// No description provided for @desktopChatsRemoveFromPersonal.
  ///
  /// In en, this message translates to:
  /// **'Remove from personal'**
  String get desktopChatsRemoveFromPersonal;

  /// No description provided for @desktopChatsAddToPersonal.
  ///
  /// In en, this message translates to:
  /// **'To personal'**
  String get desktopChatsAddToPersonal;

  /// No description provided for @desktopChatsArchiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'The archive is empty'**
  String get desktopChatsArchiveEmpty;

  /// No description provided for @desktopChatsNoPersonal.
  ///
  /// In en, this message translates to:
  /// **'There are no personal chats'**
  String get desktopChatsNoPersonal;

  /// No description provided for @desktopChatsPersonalLocked.
  ///
  /// In en, this message translates to:
  /// **'Personal chats are password-protected'**
  String get desktopChatsPersonalLocked;

  /// No description provided for @desktopChatsAllRead.
  ///
  /// In en, this message translates to:
  /// **'Everything is read'**
  String get desktopChatsAllRead;

  /// No description provided for @desktopChatsFolderEmpty.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty for now'**
  String get desktopChatsFolderEmpty;

  /// No description provided for @desktopChatsNewChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get desktopChatsNewChat;

  /// No description provided for @desktopChatsNewRoom.
  ///
  /// In en, this message translates to:
  /// **'New room'**
  String get desktopChatsNewRoom;

  /// No description provided for @desktopChatsStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the chat: the profile is unavailable'**
  String get desktopChatsStartFailed;

  /// No description provided for @desktopChatsPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get desktopChatsPhoto;

  /// No description provided for @desktopChatsVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get desktopChatsVideo;

  /// No description provided for @desktopChatsAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get desktopChatsAudio;

  /// No description provided for @desktopChatsVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get desktopChatsVoiceMessage;

  /// No description provided for @desktopChatsVoiceShort.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get desktopChatsVoiceShort;

  /// No description provided for @desktopChatsLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get desktopChatsLink;

  /// No description provided for @desktopChatsSticker.
  ///
  /// In en, this message translates to:
  /// **'Sticker'**
  String get desktopChatsSticker;

  /// No description provided for @desktopChatsStickerWith.
  ///
  /// In en, this message translates to:
  /// **'Sticker {label}'**
  String desktopChatsStickerWith(Object label);

  /// No description provided for @desktopChatsPoll.
  ///
  /// In en, this message translates to:
  /// **'📊 Poll: {question}'**
  String desktopChatsPoll(Object question);

  /// No description provided for @desktopChatsUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get desktopChatsUnknown;

  /// No description provided for @desktopChatsMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get desktopChatsMember;

  /// No description provided for @desktopChatsSoundOn.
  ///
  /// In en, this message translates to:
  /// **'Switch the sound on'**
  String get desktopChatsSoundOn;

  /// No description provided for @desktopChatsSoundOff.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get desktopChatsSoundOff;

  /// No description provided for @desktopChatsClearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the history?'**
  String get desktopChatsClearHistoryTitle;

  /// No description provided for @desktopChatsClearHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'Every message of the chat “{title}” will be deleted on this device.'**
  String desktopChatsClearHistoryBody(Object title);

  /// No description provided for @desktopChatsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get desktopChatsClear;

  /// No description provided for @desktopChatsHistoryClearedBoth.
  ///
  /// In en, this message translates to:
  /// **'The history was cleared for both'**
  String get desktopChatsHistoryClearedBoth;

  /// No description provided for @desktopChatsHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'The history was cleared'**
  String get desktopChatsHistoryCleared;

  /// No description provided for @desktopChatsDeleteChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the chat?'**
  String get desktopChatsDeleteChatTitle;

  /// No description provided for @desktopChatsDeleteChatBody.
  ///
  /// In en, this message translates to:
  /// **'The chat “{title}” will be removed from this device entirely.'**
  String desktopChatsDeleteChatBody(Object title);

  /// No description provided for @desktopChatsRooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get desktopChatsRooms;

  /// No description provided for @desktopChatsGeneralTopic.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get desktopChatsGeneralTopic;

  /// No description provided for @desktopChatsNewTopicEllipsis.
  ///
  /// In en, this message translates to:
  /// **'New topic…'**
  String get desktopChatsNewTopicEllipsis;

  /// No description provided for @desktopChatsBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch “{title}”'**
  String desktopChatsBranch(Object title);

  /// No description provided for @desktopChatsRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get desktopChatsRename;

  /// No description provided for @desktopChatsIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get desktopChatsIcon;

  /// No description provided for @desktopChatsDeleteBranch.
  ///
  /// In en, this message translates to:
  /// **'Delete the branch'**
  String get desktopChatsDeleteBranch;

  /// No description provided for @desktopChatsBranchIcon.
  ///
  /// In en, this message translates to:
  /// **'Branch icon'**
  String get desktopChatsBranchIcon;

  /// No description provided for @desktopChatsBranchIconHint.
  ///
  /// In en, this message translates to:
  /// **'The icon replaces the hash before the name. Coloured ones promise what is inside: green a call, red something urgent. The rest are grey so they do not argue with the name.'**
  String get desktopChatsBranchIconHint;

  /// No description provided for @desktopChatsHash.
  ///
  /// In en, this message translates to:
  /// **'Hash'**
  String get desktopChatsHash;

  /// No description provided for @desktopChatsBranchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the branches: {error}'**
  String desktopChatsBranchFailed(Object error);

  /// No description provided for @desktopChatsNewTopic.
  ///
  /// In en, this message translates to:
  /// **'New topic'**
  String get desktopChatsNewTopic;

  /// No description provided for @desktopChatsRenameTopic.
  ///
  /// In en, this message translates to:
  /// **'Rename the topic'**
  String get desktopChatsRenameTopic;

  /// No description provided for @desktopChatsTopicName.
  ///
  /// In en, this message translates to:
  /// **'Topic name'**
  String get desktopChatsTopicName;

  /// No description provided for @desktopChatsReactionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the reaction: {error}'**
  String desktopChatsReactionFailed(Object error);

  /// No description provided for @desktopChatsReactionLocal.
  ///
  /// In en, this message translates to:
  /// **'The reaction was applied locally but not delivered to the other person: {error}'**
  String desktopChatsReactionLocal(Object error);

  /// No description provided for @desktopChatsRevealFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not show the file in Finder'**
  String get desktopChatsRevealFailed;

  /// No description provided for @desktopChatsVideoOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the video: {error}'**
  String desktopChatsVideoOpenFailed(Object error);

  /// No description provided for @desktopChatsVideoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The video is unavailable'**
  String get desktopChatsVideoUnavailable;

  /// No description provided for @desktopChatsFileFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch the file: {error}'**
  String desktopChatsFileFetchFailed(Object error);

  /// No description provided for @desktopChatsSaveAttachment.
  ///
  /// In en, this message translates to:
  /// **'Save the attachment'**
  String get desktopChatsSaveAttachment;

  /// No description provided for @desktopChatsFileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The file is unavailable'**
  String get desktopChatsFileUnavailable;

  /// No description provided for @desktopChatsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String desktopChatsSaveFailed(Object error);

  /// No description provided for @desktopChatsOpenFailedWith.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file: {error}'**
  String desktopChatsOpenFailedWith(Object error);

  /// No description provided for @desktopChatsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file'**
  String get desktopChatsOpenFailed;

  /// No description provided for @desktopChatsOpenFailedShort.
  ///
  /// In en, this message translates to:
  /// **'Could not open: {error}'**
  String desktopChatsOpenFailedShort(Object error);

  /// No description provided for @desktopChatsPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play: {error}'**
  String desktopChatsPlayFailed(Object error);

  /// No description provided for @desktopChatsNoCallPeer.
  ///
  /// In en, this message translates to:
  /// **'Could not work out who to call.'**
  String get desktopChatsNoCallPeer;

  /// No description provided for @desktopChatsCallsNotReady.
  ///
  /// In en, this message translates to:
  /// **'The call service is not ready.'**
  String get desktopChatsCallsNotReady;

  /// No description provided for @desktopChatsCallInProgress.
  ///
  /// In en, this message translates to:
  /// **'A call is already under way.'**
  String get desktopChatsCallInProgress;

  /// No description provided for @desktopChatsEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not edit the message.'**
  String get desktopChatsEditFailed;

  /// No description provided for @desktopChatsNoRecipient.
  ///
  /// In en, this message translates to:
  /// **'Could not work out the recipient.'**
  String get desktopChatsNoRecipient;

  /// No description provided for @desktopChatsDeleteMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the message?'**
  String get desktopChatsDeleteMessageTitle;

  /// No description provided for @desktopChatsDeleteMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the selected messages?'**
  String get desktopChatsDeleteMessagesTitle;

  /// No description provided for @desktopChatsDeleteOthersHint.
  ///
  /// In en, this message translates to:
  /// **'Other people’s messages will be deleted only for you.'**
  String get desktopChatsDeleteOthersHint;

  /// No description provided for @desktopChatsDeleteForAll.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get desktopChatsDeleteForAll;

  /// No description provided for @desktopChatsDeleteForMeOnly.
  ///
  /// In en, this message translates to:
  /// **'Delete only for me'**
  String get desktopChatsDeleteForMeOnly;

  /// No description provided for @desktopChatsDeleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get desktopChatsDeleteForMe;

  /// No description provided for @desktopChatsSavePrivacyBlocked.
  ///
  /// In en, this message translates to:
  /// **'This message cannot be saved because of privacy restrictions.'**
  String get desktopChatsSavePrivacyBlocked;

  /// No description provided for @desktopChatsNothingToSave.
  ///
  /// In en, this message translates to:
  /// **'The attachment was not downloaded — there is nothing to save'**
  String get desktopChatsNothingToSave;

  /// No description provided for @desktopChatsSavedPartly.
  ///
  /// In en, this message translates to:
  /// **'Saved to Favourites, but not all of it'**
  String get desktopChatsSavedPartly;

  /// No description provided for @desktopChatsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to Favourites'**
  String get desktopChatsSaved;

  /// No description provided for @desktopChatsForwardPrivacyBlocked.
  ///
  /// In en, this message translates to:
  /// **'This message cannot be forwarded because of privacy restrictions.'**
  String get desktopChatsForwardPrivacyBlocked;

  /// No description provided for @desktopChatsForwardFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not forward: {error}'**
  String desktopChatsForwardFailed(Object error);

  /// No description provided for @desktopChatsNothingToForward.
  ///
  /// In en, this message translates to:
  /// **'The attachment was not downloaded — there is nothing to forward'**
  String get desktopChatsNothingToForward;

  /// No description provided for @desktopChatsForwardedPartly.
  ///
  /// In en, this message translates to:
  /// **'Forwarded to “{title}”, but not all of it'**
  String desktopChatsForwardedPartly(Object title);

  /// No description provided for @desktopChatsForwarded.
  ///
  /// In en, this message translates to:
  /// **'Forwarded to “{title}”'**
  String desktopChatsForwarded(Object title);

  /// No description provided for @desktopChatsFileNotSentElsewhere.
  ///
  /// In en, this message translates to:
  /// **'The file was not sent to the other conversation: {text}'**
  String desktopChatsFileNotSentElsewhere(Object text);

  /// No description provided for @desktopChatsFileSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the file.'**
  String get desktopChatsFileSendFailed;

  /// No description provided for @desktopChatsPremiumFiles.
  ///
  /// In en, this message translates to:
  /// **'{text} With Premium you can send files of up to 1 GB.'**
  String desktopChatsPremiumFiles(Object text);

  /// No description provided for @desktopChatsTypingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get desktopChatsTypingEllipsis;

  /// No description provided for @desktopChatsOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get desktopChatsOnline;

  /// No description provided for @desktopChatsSomeoneTyping.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing'**
  String desktopChatsSomeoneTyping(Object name);

  /// No description provided for @desktopChatsLoadingList.
  ///
  /// In en, this message translates to:
  /// **'Pulling the list from local storage.'**
  String get desktopChatsLoadingList;

  /// No description provided for @desktopChatsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Messages and calls will appear here as soon as you open a chat.'**
  String get desktopChatsWillAppear;

  /// No description provided for @desktopRoomNoOpenHere.
  ///
  /// In en, this message translates to:
  /// **'A chat cannot be opened from here'**
  String get desktopRoomNoOpenHere;

  /// No description provided for @desktopRoomIdCopied.
  ///
  /// In en, this message translates to:
  /// **'The ID was copied'**
  String get desktopRoomIdCopied;

  /// No description provided for @desktopRoomAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Awaiting approval'**
  String get desktopRoomAwaiting;

  /// No description provided for @desktopRoomBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get desktopRoomBlocked;

  /// No description provided for @desktopRoomCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get desktopRoomCopied;

  /// No description provided for @desktopRoomChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Change the role'**
  String get desktopRoomChangeRole;

  /// No description provided for @desktopRoomTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get desktopRoomTransfer;

  /// No description provided for @desktopRoomBlockMember.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get desktopRoomBlockMember;

  /// No description provided for @desktopRoomKick.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get desktopRoomKick;

  /// No description provided for @desktopRoomKickTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove the member?'**
  String get desktopRoomKickTitle;

  /// No description provided for @desktopRoomKickBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will lose access to the room. A new invitation brings them back.'**
  String desktopRoomKickBody(Object name);

  /// No description provided for @desktopRoomBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block the member?'**
  String get desktopRoomBlockTitle;

  /// No description provided for @desktopRoomBlockBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will not be able to come back to the room even with an invitation until the block is lifted.'**
  String desktopRoomBlockBody(Object name);

  /// No description provided for @desktopRoomTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership of the room?'**
  String get desktopRoomTransferTitle;

  /// No description provided for @desktopRoomTransferBody.
  ///
  /// In en, this message translates to:
  /// **'{name} becomes the owner and you become an administrator. Only the new owner can undo it.'**
  String desktopRoomTransferBody(Object name);

  /// No description provided for @desktopRoomTransferAction.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get desktopRoomTransferAction;

  /// No description provided for @desktopRoomClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the history?'**
  String get desktopRoomClearTitle;

  /// No description provided for @desktopRoomClearBody.
  ///
  /// In en, this message translates to:
  /// **'Every message of the room will be deleted on this device.'**
  String get desktopRoomClearBody;

  /// No description provided for @desktopRoomLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave the room?'**
  String get desktopRoomLeaveTitle;

  /// No description provided for @desktopRoomLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'You will stop receiving messages. Coming back needs a new invitation.'**
  String get desktopRoomLeaveBody;

  /// No description provided for @desktopRoomLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get desktopRoomLeave;

  /// No description provided for @desktopRoomInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get desktopRoomInvite;

  /// No description provided for @desktopRoomCopyId.
  ///
  /// In en, this message translates to:
  /// **'Copy the room ID'**
  String get desktopRoomCopyId;

  /// No description provided for @desktopRoomMuteOff.
  ///
  /// In en, this message translates to:
  /// **'Switch notifications off'**
  String get desktopRoomMuteOff;

  /// No description provided for @desktopRoomUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Bring back from the archive'**
  String get desktopRoomUnarchive;

  /// No description provided for @desktopRoomLeaveRoom.
  ///
  /// In en, this message translates to:
  /// **'Leave the room'**
  String get desktopRoomLeaveRoom;

  /// No description provided for @desktopRoomUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get desktopRoomUntitled;

  /// No description provided for @desktopRoomCopyInvite.
  ///
  /// In en, this message translates to:
  /// **'Copy the invitation'**
  String get desktopRoomCopyInvite;

  /// No description provided for @desktopRoomSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get desktopRoomSound;

  /// No description provided for @desktopRoomTabInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get desktopRoomTabInfo;

  /// No description provided for @desktopRoomTabMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get desktopRoomTabMembers;

  /// No description provided for @desktopRoomTabMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get desktopRoomTabMedia;

  /// No description provided for @desktopRoomTopics.
  ///
  /// In en, this message translates to:
  /// **'TOPICS'**
  String get desktopRoomTopics;

  /// No description provided for @desktopRoomTopicsCount.
  ///
  /// In en, this message translates to:
  /// **'TOPICS · {count}'**
  String desktopRoomTopicsCount(Object count);

  /// No description provided for @desktopRoomDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get desktopRoomDescription;

  /// No description provided for @desktopRoomNotes.
  ///
  /// In en, this message translates to:
  /// **'NOTES'**
  String get desktopRoomNotes;

  /// No description provided for @desktopRoomInformation.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get desktopRoomInformation;

  /// No description provided for @desktopRoomId.
  ///
  /// In en, this message translates to:
  /// **'Room ID'**
  String get desktopRoomId;

  /// No description provided for @desktopRoomInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invitation link · click to copy'**
  String get desktopRoomInviteLink;

  /// No description provided for @desktopRoomFavouriteHint.
  ///
  /// In en, this message translates to:
  /// **'A tile on the rail and a place at the top of the list'**
  String get desktopRoomFavouriteHint;

  /// No description provided for @desktopRoomArchiveHint.
  ///
  /// In en, this message translates to:
  /// **'Hide the room from the main list'**
  String get desktopRoomArchiveHint;

  /// No description provided for @desktopRoomNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No members'**
  String get desktopRoomNoMembers;

  /// No description provided for @desktopRoomMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} member} other{{count} members}}'**
  String desktopRoomMembersCount(int count);

  /// No description provided for @desktopRoomNobodyFound.
  ///
  /// In en, this message translates to:
  /// **'Nobody found'**
  String get desktopRoomNobodyFound;

  /// No description provided for @desktopRoomMembersUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The member list is unavailable.'**
  String get desktopRoomMembersUnavailable;

  /// No description provided for @desktopRoomInCall.
  ///
  /// In en, this message translates to:
  /// **'IN THE CALL'**
  String get desktopRoomInCall;

  /// No description provided for @desktopRoomOnline.
  ///
  /// In en, this message translates to:
  /// **'ONLINE'**
  String get desktopRoomOnline;

  /// No description provided for @desktopRoomOffline.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get desktopRoomOffline;

  /// No description provided for @desktopRoomMoreHidden.
  ///
  /// In en, this message translates to:
  /// **'{count} more — use the search above'**
  String desktopRoomMoreHidden(Object count);

  /// No description provided for @desktopRoomSearchMember.
  ///
  /// In en, this message translates to:
  /// **'Search for a member'**
  String get desktopRoomSearchMember;

  /// No description provided for @desktopRoomJoinRequests.
  ///
  /// In en, this message translates to:
  /// **'Join requests'**
  String get desktopRoomJoinRequests;

  /// No description provided for @desktopRoomAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get desktopRoomAccept;

  /// No description provided for @desktopRoomDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get desktopRoomDecline;

  /// No description provided for @desktopRoomRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get desktopRoomRoleOwner;

  /// No description provided for @desktopRoomRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get desktopRoomRoleAdmin;

  /// No description provided for @desktopRoomRoleModerator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get desktopRoomRoleModerator;

  /// No description provided for @desktopRoomRoleRestricted.
  ///
  /// In en, this message translates to:
  /// **'Restricted'**
  String get desktopRoomRoleRestricted;

  /// No description provided for @desktopRoomRoleGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get desktopRoomRoleGuest;

  /// No description provided for @desktopContactBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block?'**
  String get desktopContactBlockTitle;

  /// No description provided for @desktopContactUnblockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unblock?'**
  String get desktopContactUnblockTitle;

  /// No description provided for @desktopContactBlockBody.
  ///
  /// In en, this message translates to:
  /// **'This person will no longer be able to send you messages or call you.'**
  String get desktopContactBlockBody;

  /// No description provided for @desktopContactUnblockBody.
  ///
  /// In en, this message translates to:
  /// **'This person will be able to reach you again.'**
  String get desktopContactUnblockBody;

  /// No description provided for @desktopContactBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get desktopContactBlock;

  /// No description provided for @desktopContactCallsNotReady.
  ///
  /// In en, this message translates to:
  /// **'The call service is not ready yet'**
  String get desktopContactCallsNotReady;

  /// No description provided for @desktopContactCallInProgress.
  ///
  /// In en, this message translates to:
  /// **'A call is already under way'**
  String get desktopContactCallInProgress;

  /// No description provided for @desktopContactCallFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the call: {error}'**
  String desktopContactCallFailed(Object error);

  /// No description provided for @desktopContactAutoDelete.
  ///
  /// In en, this message translates to:
  /// **'Automatic message deletion'**
  String get desktopContactAutoDelete;

  /// No description provided for @desktopContactAutoDeleteUpdated.
  ///
  /// In en, this message translates to:
  /// **'Automatic deletion was updated'**
  String get desktopContactAutoDeleteUpdated;

  /// No description provided for @desktopContactClearBody.
  ///
  /// In en, this message translates to:
  /// **'Every message of this chat will be deleted on this device.'**
  String get desktopContactClearBody;

  /// No description provided for @desktopContactDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The chat will be removed from this device entirely.'**
  String get desktopContactDeleteBody;

  /// No description provided for @desktopContactOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get desktopContactOff;

  /// No description provided for @desktopContactDisable.
  ///
  /// In en, this message translates to:
  /// **'Switch off'**
  String get desktopContactDisable;

  /// No description provided for @desktopContactDay1.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get desktopContactDay1;

  /// No description provided for @desktopContactDays7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get desktopContactDays7;

  /// No description provided for @desktopContactDays30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get desktopContactDays30;

  /// No description provided for @desktopContactHour1.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get desktopContactHour1;

  /// No description provided for @desktopContactMinutes.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String desktopContactMinutes(Object value);

  /// No description provided for @desktopContactOffline.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get desktopContactOffline;

  /// No description provided for @desktopContactSeenAt.
  ///
  /// In en, this message translates to:
  /// **'last seen at {time}'**
  String desktopContactSeenAt(Object time);

  /// No description provided for @desktopContactSeenYesterday.
  ///
  /// In en, this message translates to:
  /// **'last seen yesterday'**
  String get desktopContactSeenYesterday;

  /// No description provided for @desktopContactSeenOn.
  ///
  /// In en, this message translates to:
  /// **'last seen on {date}'**
  String desktopContactSeenOn(Object date);

  /// No description provided for @desktopContactCopyId.
  ///
  /// In en, this message translates to:
  /// **'Copy the ID'**
  String get desktopContactCopyId;

  /// No description provided for @desktopContactCopyIdShort.
  ///
  /// In en, this message translates to:
  /// **'Copy ID'**
  String get desktopContactCopyIdShort;

  /// No description provided for @desktopContactDisappearing.
  ///
  /// In en, this message translates to:
  /// **'Disappearing messages'**
  String get desktopContactDisappearing;

  /// No description provided for @desktopContactDeleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete the chat'**
  String get desktopContactDeleteChat;

  /// No description provided for @desktopContactCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get desktopContactCall;

  /// No description provided for @desktopContactBlockShort.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get desktopContactBlockShort;

  /// No description provided for @desktopContactSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get desktopContactSecurity;

  /// No description provided for @desktopContactVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify the contact'**
  String get desktopContactVerify;

  /// No description provided for @desktopContactArchiveHint.
  ///
  /// In en, this message translates to:
  /// **'Hide the chat from the main list'**
  String get desktopContactArchiveHint;

  /// No description provided for @desktopThreadMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get desktopThreadMessageHint;

  /// No description provided for @desktopThreadPasteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not paste the picture'**
  String get desktopThreadPasteFailed;

  /// No description provided for @desktopThreadNoScheduleEdit.
  ///
  /// In en, this message translates to:
  /// **'An edit cannot be scheduled — it changes something already sent'**
  String get desktopThreadNoScheduleEdit;

  /// No description provided for @desktopThreadWillLeave.
  ///
  /// In en, this message translates to:
  /// **'Will go out {when}'**
  String desktopThreadWillLeave(Object when);

  /// No description provided for @desktopThreadSeconds.
  ///
  /// In en, this message translates to:
  /// **'{value} s'**
  String desktopThreadSeconds(Object value);

  /// No description provided for @desktopThreadMinutes.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String desktopThreadMinutes(Object value);

  /// No description provided for @desktopThreadHours.
  ///
  /// In en, this message translates to:
  /// **'{value} h'**
  String desktopThreadHours(Object value);

  /// No description provided for @desktopThreadDays.
  ///
  /// In en, this message translates to:
  /// **'{value} d'**
  String desktopThreadDays(Object value);

  /// No description provided for @desktopThreadWeeks.
  ///
  /// In en, this message translates to:
  /// **'{value} w'**
  String desktopThreadWeeks(Object value);

  /// No description provided for @desktopThreadSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count}'**
  String desktopThreadSelected(Object count);

  /// No description provided for @desktopThreadDisappearingOn.
  ///
  /// In en, this message translates to:
  /// **'Disappearing messages are on'**
  String get desktopThreadDisappearingOn;

  /// No description provided for @desktopThreadCallAction.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get desktopThreadCallAction;

  /// No description provided for @desktopThreadCallRoom.
  ///
  /// In en, this message translates to:
  /// **'Group call'**
  String get desktopThreadCallRoom;

  /// No description provided for @desktopThreadVideoCall.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get desktopThreadVideoCall;

  /// No description provided for @desktopThreadSearchShortcut.
  ///
  /// In en, this message translates to:
  /// **'Search in the chat  Cmd F'**
  String get desktopThreadSearchShortcut;

  /// No description provided for @desktopThreadHideDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide the details'**
  String get desktopThreadHideDetails;

  /// No description provided for @desktopThreadShowDetails.
  ///
  /// In en, this message translates to:
  /// **'Show the details'**
  String get desktopThreadShowDetails;

  /// No description provided for @desktopThreadMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get desktopThreadMore;

  /// No description provided for @desktopThreadPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned message'**
  String get desktopThreadPinned;

  /// No description provided for @desktopThreadNoMatches.
  ///
  /// In en, this message translates to:
  /// **'no matches'**
  String get desktopThreadNoMatches;

  /// No description provided for @desktopThreadSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search in the chat…'**
  String get desktopThreadSearchHint;

  /// No description provided for @desktopThreadPrevMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous (Shift F3)'**
  String get desktopThreadPrevMatch;

  /// No description provided for @desktopThreadNextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next (F3)'**
  String get desktopThreadNextMatch;

  /// No description provided for @desktopThreadCloseEsc.
  ///
  /// In en, this message translates to:
  /// **'Close (Esc)'**
  String get desktopThreadCloseEsc;

  /// No description provided for @desktopThreadNewMessages.
  ///
  /// In en, this message translates to:
  /// **'New messages'**
  String get desktopThreadNewMessages;

  /// No description provided for @desktopThreadUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} unread} other{{count} unread}}'**
  String desktopThreadUnreadCount(int count);

  /// No description provided for @desktopThreadToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get desktopThreadToday;

  /// No description provided for @desktopThreadYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get desktopThreadYesterday;

  /// No description provided for @desktopProfileEmojiStatus.
  ///
  /// In en, this message translates to:
  /// **'Emoji status'**
  String get desktopProfileEmojiStatus;

  /// No description provided for @desktopProfileClearStatus.
  ///
  /// In en, this message translates to:
  /// **'Clear the status'**
  String get desktopProfileClearStatus;

  /// No description provided for @desktopProfileApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not apply: {error}'**
  String desktopProfileApplyFailed(Object error);

  /// No description provided for @desktopProfileAvatarFrame.
  ///
  /// In en, this message translates to:
  /// **'Avatar frame'**
  String get desktopProfileAvatarFrame;

  /// No description provided for @desktopProfileCover.
  ///
  /// In en, this message translates to:
  /// **'Profile cover'**
  String get desktopProfileCover;

  /// No description provided for @desktopProfileNoFrame.
  ///
  /// In en, this message translates to:
  /// **'No frame'**
  String get desktopProfileNoFrame;

  /// No description provided for @desktopProfileNoCover.
  ///
  /// In en, this message translates to:
  /// **'No cover'**
  String get desktopProfileNoCover;

  /// No description provided for @desktopProfileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the file'**
  String get desktopProfileReadFailed;

  /// No description provided for @desktopProfilePhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'The profile photo was updated'**
  String get desktopProfilePhotoUpdated;

  /// No description provided for @desktopProfilePhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the photo: {error}'**
  String desktopProfilePhotoFailed(Object error);

  /// No description provided for @desktopProfilePhotoRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the photo: {error}'**
  String desktopProfilePhotoRemoveFailed(Object error);

  /// No description provided for @desktopProfileMine.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get desktopProfileMine;

  /// No description provided for @desktopProfileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get desktopProfileEdit;

  /// No description provided for @desktopProfileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get desktopProfileName;

  /// No description provided for @desktopProfileChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change the photo'**
  String get desktopProfileChangePhoto;

  /// No description provided for @desktopProfileFrameShort.
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get desktopProfileFrameShort;

  /// No description provided for @desktopProfileCoverShort.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get desktopProfileCoverShort;

  /// No description provided for @desktopProfileStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get desktopProfileStatus;

  /// No description provided for @desktopProfileAppearanceHint.
  ///
  /// In en, this message translates to:
  /// **'Theme, accent and chat wallpaper'**
  String get desktopProfileAppearanceHint;

  /// No description provided for @desktopProfileAbout.
  ///
  /// In en, this message translates to:
  /// **'About me'**
  String get desktopProfileAbout;

  /// No description provided for @desktopProfileEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not filled in'**
  String get desktopProfileEmpty;

  /// No description provided for @desktopProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get desktopProfilePhoto;

  /// No description provided for @desktopProfileReplacePhoto.
  ///
  /// In en, this message translates to:
  /// **'Replace the photo'**
  String get desktopProfileReplacePhoto;

  /// No description provided for @desktopProfilePickPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get desktopProfilePickPhoto;

  /// No description provided for @desktopProfilePickedHere.
  ///
  /// In en, this message translates to:
  /// **'Chosen on this computer'**
  String get desktopProfilePickedHere;

  /// No description provided for @desktopProfileSyncedWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Synced with the phone'**
  String get desktopProfileSyncedWithPhone;

  /// No description provided for @desktopProfileNotPicked.
  ///
  /// In en, this message translates to:
  /// **'Not chosen'**
  String get desktopProfileNotPicked;

  /// No description provided for @desktopProfileRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove the photo'**
  String get desktopProfileRemovePhoto;

  /// No description provided for @desktopProfileInitialsStay.
  ///
  /// In en, this message translates to:
  /// **'The initials remain'**
  String get desktopProfileInitialsStay;

  /// No description provided for @desktopProfileAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get desktopProfileAccount;

  /// No description provided for @desktopProfileRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get desktopProfileRecovery;

  /// No description provided for @desktopProfileRecoveryHint.
  ///
  /// In en, this message translates to:
  /// **'This computer is linked to the phone and keeps no recovery phrase of its own: the backup and the recovery kit bring the account back.'**
  String get desktopProfileRecoveryHint;

  /// No description provided for @desktopProfileDevicesHint.
  ///
  /// In en, this message translates to:
  /// **'Connected computers and phones'**
  String get desktopProfileDevicesHint;

  /// No description provided for @desktopProfileFrameCaps.
  ///
  /// In en, this message translates to:
  /// **'AVATAR FRAME'**
  String get desktopProfileFrameCaps;

  /// No description provided for @desktopGalleryMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get desktopGalleryMedia;

  /// No description provided for @desktopGalleryFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get desktopGalleryFiles;

  /// No description provided for @desktopGalleryLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get desktopGalleryLinks;

  /// No description provided for @desktopGalleryNoMedia.
  ///
  /// In en, this message translates to:
  /// **'No media'**
  String get desktopGalleryNoMedia;

  /// No description provided for @desktopGalleryNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get desktopGalleryNoFiles;

  /// No description provided for @desktopGalleryNoAudio.
  ///
  /// In en, this message translates to:
  /// **'No audio'**
  String get desktopGalleryNoAudio;

  /// No description provided for @desktopGalleryNoLinks.
  ///
  /// In en, this message translates to:
  /// **'No links'**
  String get desktopGalleryNoLinks;

  /// No description provided for @desktopGalleryPathCopied.
  ///
  /// In en, this message translates to:
  /// **'The path was copied'**
  String get desktopGalleryPathCopied;

  /// No description provided for @desktopGalleryOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get desktopGalleryOpen;

  /// No description provided for @desktopGalleryView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get desktopGalleryView;

  /// No description provided for @desktopGalleryOpenInSystem.
  ///
  /// In en, this message translates to:
  /// **'Open in the system'**
  String get desktopGalleryOpenInSystem;

  /// No description provided for @desktopGalleryRevealFinder.
  ///
  /// In en, this message translates to:
  /// **'Show in Finder'**
  String get desktopGalleryRevealFinder;

  /// No description provided for @desktopGalleryRevealExplorer.
  ///
  /// In en, this message translates to:
  /// **'Show in Explorer'**
  String get desktopGalleryRevealExplorer;

  /// No description provided for @desktopGalleryOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open the folder'**
  String get desktopGalleryOpenFolder;

  /// No description provided for @desktopGalleryCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy the path'**
  String get desktopGalleryCopyPath;

  /// No description provided for @desktopGalleryBytes.
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String desktopGalleryBytes(Object value);

  /// No description provided for @desktopGalleryZeroBytes.
  ///
  /// In en, this message translates to:
  /// **'0 B'**
  String get desktopGalleryZeroBytes;

  /// No description provided for @desktopOutgoingFolderSingle.
  ///
  /// In en, this message translates to:
  /// **'the folder “{name}” cannot be sent'**
  String desktopOutgoingFolderSingle(Object name);

  /// No description provided for @desktopOutgoingFoldersMany.
  ///
  /// In en, this message translates to:
  /// **'folders cannot be sent'**
  String get desktopOutgoingFoldersMany;

  /// No description provided for @desktopOutgoingTooLargeOne.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is larger than {limit} MB'**
  String desktopOutgoingTooLargeOne(Object name, Object limit);

  /// No description provided for @desktopOutgoingTooLargeMany.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file is larger than {limit} MB} other{{count} files are larger than {limit} MB}}'**
  String desktopOutgoingTooLargeMany(int count, Object limit);

  /// No description provided for @desktopOutgoingEmptyOne.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is empty'**
  String desktopOutgoingEmptyOne(Object name);

  /// No description provided for @desktopOutgoingEmptyMany.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file is empty} other{{count} files are empty}}'**
  String desktopOutgoingEmptyMany(int count);

  /// No description provided for @desktopOutgoingUnreadableOne.
  ///
  /// In en, this message translates to:
  /// **'“{name}” could not be read'**
  String desktopOutgoingUnreadableOne(Object name);

  /// No description provided for @desktopOutgoingUnreadableMany.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file could not be read} other{{count} files could not be read}}'**
  String desktopOutgoingUnreadableMany(int count);

  /// No description provided for @desktopOutgoingSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get desktopOutgoingSending;

  /// No description provided for @desktopOutgoingPhotos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} photos} other{{count} photos}}'**
  String desktopOutgoingPhotos(int count);

  /// No description provided for @desktopOutgoingVideos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} videos} other{{count} videos}}'**
  String desktopOutgoingVideos(int count);

  /// No description provided for @desktopOutgoingMedia.
  ///
  /// In en, this message translates to:
  /// **'{count} media items'**
  String desktopOutgoingMedia(Object count);

  /// No description provided for @desktopOutgoingAudios.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} audio files} other{{count} audio files}}'**
  String desktopOutgoingAudios(int count);

  /// No description provided for @desktopOutgoingFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} files} other{{count} files}}'**
  String desktopOutgoingFiles(int count);

  /// No description provided for @desktopCallsPickOne.
  ///
  /// In en, this message translates to:
  /// **'Pick a call on the left'**
  String get desktopCallsPickOne;

  /// No description provided for @desktopCallsPickHint.
  ///
  /// In en, this message translates to:
  /// **'The details and a call-back button will appear here'**
  String get desktopCallsPickHint;

  /// No description provided for @desktopCallsNone.
  ///
  /// In en, this message translates to:
  /// **'No calls yet'**
  String get desktopCallsNone;

  /// No description provided for @desktopCallsNoneHint.
  ///
  /// In en, this message translates to:
  /// **'The history appears after the first call'**
  String get desktopCallsNoneHint;

  /// No description provided for @desktopCallsOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get desktopCallsOutgoing;

  /// No description provided for @desktopCallsIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get desktopCallsIncoming;

  /// No description provided for @desktopCallsGroup.
  ///
  /// In en, this message translates to:
  /// **'group'**
  String get desktopCallsGroup;

  /// No description provided for @desktopCallsVideoKind.
  ///
  /// In en, this message translates to:
  /// **'video'**
  String get desktopCallsVideoKind;

  /// No description provided for @desktopCallsAudioKind.
  ///
  /// In en, this message translates to:
  /// **'audio'**
  String get desktopCallsAudioKind;

  /// No description provided for @desktopCallsMissed.
  ///
  /// In en, this message translates to:
  /// **'missed'**
  String get desktopCallsMissed;

  /// No description provided for @desktopPhotoCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy: {error}'**
  String desktopPhotoCopyFailed(Object error);

  /// No description provided for @desktopPhotoSave.
  ///
  /// In en, this message translates to:
  /// **'Save the photo'**
  String get desktopPhotoSave;

  /// No description provided for @desktopPhotoSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get desktopPhotoSaved;

  /// No description provided for @desktopPhotoRevealFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not show in Finder: {error}'**
  String desktopPhotoRevealFailed(Object error);

  /// No description provided for @desktopPhotoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load'**
  String get desktopPhotoLoadFailed;

  /// No description provided for @desktopPhotoZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get desktopPhotoZoomOut;

  /// No description provided for @desktopPhotoZoomReset.
  ///
  /// In en, this message translates to:
  /// **'Reset the zoom'**
  String get desktopPhotoZoomReset;

  /// No description provided for @desktopPhotoZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get desktopPhotoZoomIn;

  /// No description provided for @desktopPhotoCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get desktopPhotoCopy;

  /// No description provided for @desktopBubbleForwardedFrom.
  ///
  /// In en, this message translates to:
  /// **'Forwarded from {from}'**
  String desktopBubbleForwardedFrom(Object from);

  /// No description provided for @desktopBubbleAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Audio file'**
  String get desktopBubbleAudioFile;

  /// No description provided for @desktopBubbleTranslating.
  ///
  /// In en, this message translates to:
  /// **'Translating…'**
  String get desktopBubbleTranslating;

  /// No description provided for @desktopBubbleTranslation.
  ///
  /// In en, this message translates to:
  /// **'TRANSLATION'**
  String get desktopBubbleTranslation;

  /// No description provided for @desktopBubbleEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get desktopBubbleEdited;

  /// No description provided for @desktopBubbleMoreReactions.
  ///
  /// In en, this message translates to:
  /// **'More reactions'**
  String get desktopBubbleMoreReactions;

  /// No description provided for @desktopBubbleRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'owner'**
  String get desktopBubbleRoleOwner;

  /// No description provided for @desktopBubbleRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'admin'**
  String get desktopBubbleRoleAdmin;

  /// No description provided for @desktopBubbleRoleMod.
  ///
  /// In en, this message translates to:
  /// **'mod'**
  String get desktopBubbleRoleMod;

  /// No description provided for @desktopBubbleSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get desktopBubbleSpeed;

  /// No description provided for @desktopSpotlightGoChats.
  ///
  /// In en, this message translates to:
  /// **'Go to chats'**
  String get desktopSpotlightGoChats;

  /// No description provided for @desktopSpotlightGoRooms.
  ///
  /// In en, this message translates to:
  /// **'Go to rooms'**
  String get desktopSpotlightGoRooms;

  /// No description provided for @desktopSpotlightGoContacts.
  ///
  /// In en, this message translates to:
  /// **'Go to contacts'**
  String get desktopSpotlightGoContacts;

  /// No description provided for @desktopSpotlightGoCalls.
  ///
  /// In en, this message translates to:
  /// **'Go to calls'**
  String get desktopSpotlightGoCalls;

  /// No description provided for @desktopSpotlightSelect.
  ///
  /// In en, this message translates to:
  /// **'select'**
  String get desktopSpotlightSelect;

  /// No description provided for @desktopSpotlightOpen.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get desktopSpotlightOpen;

  /// No description provided for @desktopSpotlightClose.
  ///
  /// In en, this message translates to:
  /// **'close'**
  String get desktopSpotlightClose;

  /// No description provided for @desktopSpotlightRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get desktopSpotlightRoom;

  /// No description provided for @desktopSpotlightMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get desktopSpotlightMessage;

  /// No description provided for @desktopSpotlightCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get desktopSpotlightCommand;

  /// No description provided for @desktopComposerCancelRec.
  ///
  /// In en, this message translates to:
  /// **'Cancel the recording'**
  String get desktopComposerCancelRec;

  /// No description provided for @desktopComposerRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording  {time}'**
  String desktopComposerRecording(Object time);

  /// No description provided for @desktopComposerSendVoice.
  ///
  /// In en, this message translates to:
  /// **'Send the voice message'**
  String get desktopComposerSendVoice;

  /// No description provided for @desktopComposerAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get desktopComposerAttach;

  /// No description provided for @desktopComposerEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji and stickers'**
  String get desktopComposerEmoji;

  /// No description provided for @desktopComposerRecordVoice.
  ///
  /// In en, this message translates to:
  /// **'Record a voice message'**
  String get desktopComposerRecordVoice;

  /// No description provided for @desktopComposerEnterSends.
  ///
  /// In en, this message translates to:
  /// **'Enter sends · Shift+Enter makes a new line'**
  String get desktopComposerEnterSends;

  /// No description provided for @desktopComposerEnterNewline.
  ///
  /// In en, this message translates to:
  /// **'Enter makes a new line · Shift+Enter sends'**
  String get desktopComposerEnterNewline;

  /// No description provided for @desktopComposerEditing.
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get desktopComposerEditing;

  /// No description provided for @desktopComposerReplyTo.
  ///
  /// In en, this message translates to:
  /// **'Reply · {name}'**
  String desktopComposerReplyTo(Object name);

  /// No description provided for @desktopComposerCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get desktopComposerCancelAction;

  /// No description provided for @desktopComposerSendHint.
  ///
  /// In en, this message translates to:
  /// **'Send · Enter\nRight click to send later'**
  String get desktopComposerSendHint;

  /// No description provided for @desktopComposerWriteFirst.
  ///
  /// In en, this message translates to:
  /// **'Write a message first'**
  String get desktopComposerWriteFirst;

  /// No description provided for @desktopComposerToTopic.
  ///
  /// In en, this message translates to:
  /// **'to the topic “{title}”'**
  String desktopComposerToTopic(Object title);

  /// No description provided for @desktopShortcutsNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get desktopShortcutsNavigation;

  /// No description provided for @desktopShortcutsTabs.
  ///
  /// In en, this message translates to:
  /// **'Chats · Rooms · Calls · Contacts'**
  String get desktopShortcutsTabs;

  /// No description provided for @desktopShortcutsSearchAll.
  ///
  /// In en, this message translates to:
  /// **'Search chats and messages'**
  String get desktopShortcutsSearchAll;

  /// No description provided for @desktopShortcutsPrevNext.
  ///
  /// In en, this message translates to:
  /// **'Previous / next chat'**
  String get desktopShortcutsPrevNext;

  /// No description provided for @desktopShortcutsInChat.
  ///
  /// In en, this message translates to:
  /// **'In a conversation'**
  String get desktopShortcutsInChat;

  /// No description provided for @desktopShortcutsFindHere.
  ///
  /// In en, this message translates to:
  /// **'Find in this conversation'**
  String get desktopShortcutsFindHere;

  /// No description provided for @desktopShortcutsSend.
  ///
  /// In en, this message translates to:
  /// **'Send (configurable)'**
  String get desktopShortcutsSend;

  /// No description provided for @desktopShortcutsNewline.
  ///
  /// In en, this message translates to:
  /// **'New line'**
  String get desktopShortcutsNewline;

  /// No description provided for @desktopShortcutsPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste an image from the clipboard'**
  String get desktopShortcutsPaste;

  /// No description provided for @desktopShortcutsApp.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get desktopShortcutsApp;

  /// No description provided for @desktopShortcutsThisHelp.
  ///
  /// In en, this message translates to:
  /// **'This help'**
  String get desktopShortcutsThisHelp;

  /// No description provided for @desktopShortcutsCloseWindow.
  ///
  /// In en, this message translates to:
  /// **'Close the window or the search'**
  String get desktopShortcutsCloseWindow;

  /// No description provided for @desktopShortcutsTray.
  ///
  /// In en, this message translates to:
  /// **'Minimise to the tray'**
  String get desktopShortcutsTray;

  /// No description provided for @desktopShortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get desktopShortcutsTitle;

  /// No description provided for @desktopMediaCancelSend.
  ///
  /// In en, this message translates to:
  /// **'Cancel the send'**
  String get desktopMediaCancelSend;

  /// No description provided for @desktopMediaSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get desktopMediaSending;

  /// No description provided for @desktopMediaSendingOf.
  ///
  /// In en, this message translates to:
  /// **'Sending… · {total}'**
  String desktopMediaSendingOf(Object total);

  /// No description provided for @desktopMediaRetryDownload.
  ///
  /// In en, this message translates to:
  /// **'Retry the download'**
  String get desktopMediaRetryDownload;

  /// No description provided for @desktopMediaImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get desktopMediaImage;

  /// No description provided for @desktopMediaDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… · {size}'**
  String desktopMediaDownloading(Object size);

  /// No description provided for @desktopMediaDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get desktopMediaDownload;

  /// No description provided for @desktopSendAsMedia.
  ///
  /// In en, this message translates to:
  /// **'Send as media'**
  String get desktopSendAsMedia;

  /// No description provided for @desktopSendAsFiles.
  ///
  /// In en, this message translates to:
  /// **'Send as files'**
  String get desktopSendAsFiles;

  /// No description provided for @desktopSendUngroup.
  ///
  /// In en, this message translates to:
  /// **'Do not group'**
  String get desktopSendUngroup;

  /// No description provided for @desktopSendGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get desktopSendGroup;

  /// No description provided for @desktopSendAddFiles.
  ///
  /// In en, this message translates to:
  /// **'Add files…'**
  String get desktopSendAddFiles;

  /// No description provided for @desktopSendDropHere.
  ///
  /// In en, this message translates to:
  /// **'Release to add'**
  String get desktopSendDropHere;

  /// No description provided for @desktopSendCloseEsc.
  ///
  /// In en, this message translates to:
  /// **'Close · Esc'**
  String get desktopSendCloseEsc;

  /// No description provided for @desktopSendToDestination.
  ///
  /// In en, this message translates to:
  /// **'to “{destination}”'**
  String desktopSendToDestination(Object destination);

  /// No description provided for @desktopSendCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a caption…'**
  String get desktopSendCaptionHint;

  /// No description provided for @desktopSendEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get desktopSendEmoji;

  /// No description provided for @desktopSendRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get desktopSendRemove;

  /// No description provided for @desktopSendEnter.
  ///
  /// In en, this message translates to:
  /// **'Send · Enter'**
  String get desktopSendEnter;

  /// No description provided for @desktopSendShiftEnter.
  ///
  /// In en, this message translates to:
  /// **'Send · Shift+Enter'**
  String get desktopSendShiftEnter;

  /// No description provided for @desktopCallCtlMicOff.
  ///
  /// In en, this message translates to:
  /// **'Turn the microphone off   ⌘D'**
  String get desktopCallCtlMicOff;

  /// No description provided for @desktopCallCtlMicOn.
  ///
  /// In en, this message translates to:
  /// **'Turn the microphone on   ⌘D'**
  String get desktopCallCtlMicOn;

  /// No description provided for @desktopCallCtlCamOff.
  ///
  /// In en, this message translates to:
  /// **'Turn the camera off   ⌘E'**
  String get desktopCallCtlCamOff;

  /// No description provided for @desktopCallCtlCamOn.
  ///
  /// In en, this message translates to:
  /// **'Turn the camera on   ⌘E'**
  String get desktopCallCtlCamOn;

  /// No description provided for @desktopCallCtlShareStop.
  ///
  /// In en, this message translates to:
  /// **'Stop the screen share'**
  String get desktopCallCtlShareStop;

  /// No description provided for @desktopCallCtlShare.
  ///
  /// In en, this message translates to:
  /// **'Screen sharing'**
  String get desktopCallCtlShare;

  /// No description provided for @desktopCallCtlHandDown.
  ///
  /// In en, this message translates to:
  /// **'Lower the hand'**
  String get desktopCallCtlHandDown;

  /// No description provided for @desktopCallCtlHandUp.
  ///
  /// In en, this message translates to:
  /// **'Raise the hand'**
  String get desktopCallCtlHandUp;

  /// No description provided for @desktopCallCtlHangUp.
  ///
  /// In en, this message translates to:
  /// **'Hang up   ⌘W'**
  String get desktopCallCtlHangUp;

  /// No description provided for @desktopAbsenceDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}}'**
  String desktopAbsenceDays(int count);

  /// No description provided for @desktopAbsencePastFanout.
  ///
  /// In en, this message translates to:
  /// **'This computer has been out of touch for {days}. In that time senders stopped encrypting messages for it, and part of the history will not arrive here. It is intact on the phone — open the chats you need there and the recent history will follow.'**
  String desktopAbsencePastFanout(Object days);

  /// No description provided for @desktopAbsenceWithinWindow.
  ///
  /// In en, this message translates to:
  /// **'This computer has been out of touch for {days}. Messages are kept on the server for a week, so some of them may not have survived for it. On the phone they are intact.'**
  String desktopAbsenceWithinWindow(Object days);

  /// No description provided for @desktopAbsenceGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get desktopAbsenceGotIt;

  /// No description provided for @desktopNavContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get desktopNavContacts;

  /// No description provided for @desktopChatNotFound.
  ///
  /// In en, this message translates to:
  /// **'The conversation was not found'**
  String get desktopChatNotFound;

  /// No description provided for @desktopUnreadTitle.
  ///
  /// In en, this message translates to:
  /// **'Secretly — {count} unread'**
  String desktopUnreadTitle(Object count);

  /// No description provided for @desktopRoomsNone.
  ///
  /// In en, this message translates to:
  /// **'No rooms yet'**
  String get desktopRoomsNone;

  /// No description provided for @desktopRoomsNoneHint.
  ///
  /// In en, this message translates to:
  /// **'Create a room on the phone — it will appear here automatically'**
  String get desktopRoomsNoneHint;

  /// No description provided for @desktopRoomsPickOne.
  ///
  /// In en, this message translates to:
  /// **'Pick a room on the left'**
  String get desktopRoomsPickOne;

  /// No description provided for @desktopScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Send later'**
  String get desktopScheduleTitle;

  /// No description provided for @desktopScheduleInHour.
  ///
  /// In en, this message translates to:
  /// **'In an hour'**
  String get desktopScheduleInHour;

  /// No description provided for @desktopScheduleTonight.
  ///
  /// In en, this message translates to:
  /// **'Today at 19:00'**
  String get desktopScheduleTonight;

  /// No description provided for @desktopScheduleTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow at 9:00'**
  String get desktopScheduleTomorrow;

  /// No description provided for @desktopScheduleInWeek.
  ///
  /// In en, this message translates to:
  /// **'In a week'**
  String get desktopScheduleInWeek;

  /// No description provided for @desktopScheduleTodayAt.
  ///
  /// In en, this message translates to:
  /// **'today at {time}'**
  String desktopScheduleTodayAt(Object time);

  /// No description provided for @desktopScheduleTomorrowAt.
  ///
  /// In en, this message translates to:
  /// **'tomorrow at {time}'**
  String desktopScheduleTomorrowAt(Object time);

  /// No description provided for @desktopScheduleOnAt.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String desktopScheduleOnAt(Object date, Object time);

  /// No description provided for @desktopScheduleHint.
  ///
  /// In en, this message translates to:
  /// **'The message goes out on its own at the chosen time — even with the window closed it will be sent at the next start.'**
  String get desktopScheduleHint;

  /// No description provided for @desktopSchedulePickTime.
  ///
  /// In en, this message translates to:
  /// **'Pick a time…'**
  String get desktopSchedulePickTime;

  /// No description provided for @desktopDevicesSearching.
  ///
  /// In en, this message translates to:
  /// **'Looking for devices…'**
  String get desktopDevicesSearching;

  /// No description provided for @desktopDevicesNoCameras.
  ///
  /// In en, this message translates to:
  /// **'No cameras found. The application may not have been given access to them in the system settings.'**
  String get desktopDevicesNoCameras;

  /// No description provided for @desktopDevicesNoMics.
  ///
  /// In en, this message translates to:
  /// **'No microphones found. The application may not have been given access to them in the system settings.'**
  String get desktopDevicesNoMics;

  /// No description provided for @desktopDevicesOutputHint.
  ///
  /// In en, this message translates to:
  /// **'Where the sound goes is chosen inside the call — by the chevron next to “Microphone”. That is also where the application switches to headphones on its own when they are plugged in.'**
  String get desktopDevicesOutputHint;

  /// No description provided for @desktopDevicesSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'As chosen in the system'**
  String get desktopDevicesSystemDefault;

  /// No description provided for @desktopRailSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings   Cmd ,'**
  String get desktopRailSettings;

  /// No description provided for @desktopRailConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get desktopRailConnected;

  /// No description provided for @desktopRailConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get desktopRailConnecting;

  /// No description provided for @desktopRailOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get desktopRailOffline;

  /// No description provided for @desktopRailProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile   Cmd P   ·   {status}'**
  String desktopRailProfile(Object status);

  /// No description provided for @desktopEmojiSmileys.
  ///
  /// In en, this message translates to:
  /// **'Smileys and emotion'**
  String get desktopEmojiSmileys;

  /// No description provided for @desktopEmojiPeople.
  ///
  /// In en, this message translates to:
  /// **'People and body'**
  String get desktopEmojiPeople;

  /// No description provided for @desktopEmojiNature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get desktopEmojiNature;

  /// No description provided for @desktopEmojiFood.
  ///
  /// In en, this message translates to:
  /// **'Food and drink'**
  String get desktopEmojiFood;

  /// No description provided for @desktopEmojiTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get desktopEmojiTravel;

  /// No description provided for @desktopEmojiActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get desktopEmojiActivities;

  /// No description provided for @desktopEmojiObjects.
  ///
  /// In en, this message translates to:
  /// **'Objects'**
  String get desktopEmojiObjects;

  /// No description provided for @desktopEmojiSymbols.
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get desktopEmojiSymbols;

  /// No description provided for @desktopEmojiFlags.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get desktopEmojiFlags;

  /// No description provided for @desktopEmojiOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get desktopEmojiOther;

  /// No description provided for @desktopLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Secretly is locked'**
  String get desktopLockedTitle;

  /// No description provided for @desktopLockedTouchIdPrompt.
  ///
  /// In en, this message translates to:
  /// **'Confirm your identity with Touch ID to continue.'**
  String get desktopLockedTouchIdPrompt;

  /// No description provided for @desktopLockedPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Confirm with your device password to continue.'**
  String get desktopLockedPasswordPrompt;

  /// No description provided for @desktopLockedUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get desktopLockedUnlock;

  /// No description provided for @desktopLockedWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation…'**
  String get desktopLockedWaiting;

  /// No description provided for @desktopLockedFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm your identity.'**
  String get desktopLockedFailed;

  /// No description provided for @desktopLockedNoService.
  ///
  /// In en, this message translates to:
  /// **'The identity service is unavailable on this computer. Restart Secretly or the computer. If that doesn\'t help, write to support from your phone.'**
  String get desktopLockedNoService;

  /// No description provided for @desktopEmojiTabEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get desktopEmojiTabEmoji;

  /// No description provided for @desktopEmojiTabStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get desktopEmojiTabStickers;

  /// No description provided for @desktopEmojiRecents.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get desktopEmojiRecents;

  /// No description provided for @desktopEmojiNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get desktopEmojiNothingFound;

  /// No description provided for @desktopEmojiSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search emoji'**
  String get desktopEmojiSearchHint;

  /// No description provided for @desktopStickersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search stickers'**
  String get desktopStickersSearchHint;

  /// No description provided for @desktopGifSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search GIFs'**
  String get desktopGifSearchHint;

  /// No description provided for @desktopGifUnavailable.
  ///
  /// In en, this message translates to:
  /// **'GIFs aren\'t available in this window'**
  String get desktopGifUnavailable;

  /// No description provided for @desktopStickerPacksSoon.
  ///
  /// In en, this message translates to:
  /// **'Sticker packs coming soon'**
  String get desktopStickerPacksSoon;

  /// No description provided for @desktopCallFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get desktopCallFullscreen;

  /// No description provided for @desktopCallExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get desktopCallExitFullscreen;

  /// No description provided for @desktopCallDialing.
  ///
  /// In en, this message translates to:
  /// **'Calling…'**
  String get desktopCallDialing;

  /// No description provided for @desktopCallEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get desktopCallEnded;

  /// No description provided for @desktopCallEncryptedFor.
  ///
  /// In en, this message translates to:
  /// **'Encrypted · {duration}'**
  String desktopCallEncryptedFor(Object duration);

  /// No description provided for @desktopCallReturn.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get desktopCallReturn;

  /// No description provided for @desktopCallInProgress.
  ///
  /// In en, this message translates to:
  /// **'Call in progress'**
  String get desktopCallInProgress;

  /// No description provided for @desktopCallInProgressWith.
  ///
  /// In en, this message translates to:
  /// **'Call in progress · {title}'**
  String desktopCallInProgressWith(Object title);

  /// No description provided for @desktopCallAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get desktopCallAnswer;

  /// No description provided for @desktopCallAnswerVideo.
  ///
  /// In en, this message translates to:
  /// **'Answer with video'**
  String get desktopCallAnswerVideo;

  /// No description provided for @desktopCallAnswerText.
  ///
  /// In en, this message translates to:
  /// **'By text'**
  String get desktopCallAnswerText;

  /// No description provided for @desktopTimeYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get desktopTimeYesterday;

  /// No description provided for @desktopForwardTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward to…'**
  String get desktopForwardTitle;

  /// No description provided for @desktopForwardSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search chats and rooms'**
  String get desktopForwardSearchHint;

  /// No description provided for @desktopForwardNoChats.
  ///
  /// In en, this message translates to:
  /// **'No chats available'**
  String get desktopForwardNoChats;

  /// No description provided for @desktopForwardKindDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct chat'**
  String get desktopForwardKindDirect;

  /// No description provided for @desktopContactsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get desktopContactsSearchHint;

  /// No description provided for @desktopContactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one yet. Add a contact by ID or invite link.'**
  String get desktopContactsEmpty;

  /// No description provided for @desktopContactsNothingFor.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for “{query}”.'**
  String desktopContactsNothingFor(Object query);

  /// No description provided for @desktopContactsPick.
  ///
  /// In en, this message translates to:
  /// **'Pick a contact'**
  String get desktopContactsPick;

  /// No description provided for @desktopContactsCardRight.
  ///
  /// In en, this message translates to:
  /// **'The card will open on the right.'**
  String get desktopContactsCardRight;

  /// No description provided for @desktopContactsWrite.
  ///
  /// In en, this message translates to:
  /// **'Send a message'**
  String get desktopContactsWrite;

  /// No description provided for @desktopVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get desktopVideoTitle;

  /// No description provided for @desktopViewerCloseEsc.
  ///
  /// In en, this message translates to:
  /// **'Close  Esc'**
  String get desktopViewerCloseEsc;

  /// No description provided for @desktopVideoPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play the video'**
  String get desktopVideoPlayFailed;

  /// No description provided for @desktopKeySpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get desktopKeySpace;

  /// No description provided for @desktopWindowMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimise'**
  String get desktopWindowMinimize;

  /// No description provided for @desktopWindowMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximise'**
  String get desktopWindowMaximize;

  /// No description provided for @desktopWindowClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get desktopWindowClose;

  /// No description provided for @desktopWindowBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get desktopWindowBack;

  /// No description provided for @desktopWindowForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get desktopWindowForward;

  /// No description provided for @desktopSearchEverything.
  ///
  /// In en, this message translates to:
  /// **'Chats, people, messages, files'**
  String get desktopSearchEverything;

  /// No description provided for @desktopUnitB.
  ///
  /// In en, this message translates to:
  /// **'B'**
  String get desktopUnitB;

  /// No description provided for @desktopUnitKb.
  ///
  /// In en, this message translates to:
  /// **'KB'**
  String get desktopUnitKb;

  /// No description provided for @desktopUnitMb.
  ///
  /// In en, this message translates to:
  /// **'MB'**
  String get desktopUnitMb;

  /// No description provided for @desktopUnitGb.
  ///
  /// In en, this message translates to:
  /// **'GB'**
  String get desktopUnitGb;

  /// No description provided for @desktopUnitTb.
  ///
  /// In en, this message translates to:
  /// **'TB'**
  String get desktopUnitTb;

  /// No description provided for @desktopSyncDone.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get desktopSyncDone;

  /// No description provided for @desktopSyncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get desktopSyncSyncing;

  /// No description provided for @desktopSyncReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get desktopSyncReconnecting;

  /// No description provided for @desktopDetailsShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get desktopDetailsShare;

  /// No description provided for @desktopDetailsHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get desktopDetailsHide;

  /// No description provided for @desktopDetailsMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get desktopDetailsMore;

  /// No description provided for @desktopDetailsChangeCover.
  ///
  /// In en, this message translates to:
  /// **'Change cover'**
  String get desktopDetailsChangeCover;

  /// No description provided for @desktopDetailsFrame.
  ///
  /// In en, this message translates to:
  /// **'“{name}” frame'**
  String desktopDetailsFrame(Object name);

  /// No description provided for @desktopApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get desktopApply;

  /// No description provided for @desktopAccentAppliesTo.
  ///
  /// In en, this message translates to:
  /// **'Buttons, selections and rings. The bubble keeps its own style — you pick that below.'**
  String get desktopAccentAppliesTo;

  /// No description provided for @desktopTranslateUnknownSource.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t detect the message language'**
  String get desktopTranslateUnknownSource;

  /// No description provided for @desktopTranslateUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The system translator doesn\'t know this language pair'**
  String get desktopTranslateUnsupported;

  /// No description provided for @desktopTranslateNeedsDownload.
  ///
  /// In en, this message translates to:
  /// **'The language isn’t downloaded. System Settings → General → Language & Region → Translation Languages'**
  String get desktopTranslateNeedsDownload;

  /// No description provided for @desktopTranslateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t translate'**
  String get desktopTranslateFailed;

  /// No description provided for @desktopNewChatSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get desktopNewChatSearchHint;

  /// No description provided for @desktopNewChatNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get desktopNewChatNoContacts;

  /// No description provided for @desktopNewChatNobodyFound.
  ///
  /// In en, this message translates to:
  /// **'Nobody found'**
  String get desktopNewChatNobodyFound;

  /// No description provided for @desktopMentionEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get desktopMentionEveryone;

  /// No description provided for @desktopMentionAdmins.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get desktopMentionAdmins;

  /// No description provided for @desktopMentionEveryoneHint.
  ///
  /// In en, this message translates to:
  /// **'Call everyone in the room'**
  String get desktopMentionEveryoneHint;

  /// No description provided for @desktopMentionAdminsHint.
  ///
  /// In en, this message translates to:
  /// **'Call the owner and admins'**
  String get desktopMentionAdminsHint;

  /// No description provided for @desktopClearForPeer.
  ///
  /// In en, this message translates to:
  /// **'Clear the history on {name}’s side too'**
  String desktopClearForPeer(Object name);

  /// No description provided for @desktopClearForPeerHint.
  ///
  /// In en, this message translates to:
  /// **'Messages will vanish on their device and on all of yours. This cannot be undone.'**
  String get desktopClearForPeerHint;

  /// No description provided for @desktopGifNoKey.
  ///
  /// In en, this message translates to:
  /// **'GIFs unavailable: this build has no GIPHY key'**
  String get desktopGifNoKey;

  /// No description provided for @desktopGifConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'The connection dropped. Try again'**
  String get desktopGifConnectionLost;

  /// No description provided for @desktopNotesHint.
  ///
  /// In en, this message translates to:
  /// **'What to remember from this conversation…'**
  String get desktopNotesHint;

  /// No description provided for @desktopNotesPrivate.
  ///
  /// In en, this message translates to:
  /// **'Visible only to you. It is never sent, never appears in the conversation and is not part of the backup — it lives on this computer, in the same encrypted database as the messages.'**
  String get desktopNotesPrivate;

  /// No description provided for @desktopEmojiSearchShort.
  ///
  /// In en, this message translates to:
  /// **'Search emoji…'**
  String get desktopEmojiSearchShort;

  /// No description provided for @desktopNotifOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get desktopNotifOpen;

  /// No description provided for @desktopLinkPreviewLoading.
  ///
  /// In en, this message translates to:
  /// **'Link preview…'**
  String get desktopLinkPreviewLoading;

  /// No description provided for @desktopLinkPreviewOff.
  ///
  /// In en, this message translates to:
  /// **'No preview'**
  String get desktopLinkPreviewOff;

  /// No description provided for @desktopDropToSend.
  ///
  /// In en, this message translates to:
  /// **'Drop to send'**
  String get desktopDropToSend;

  /// No description provided for @desktopDropEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Files are encrypted before they are sent'**
  String get desktopDropEncrypted;

  /// No description provided for @desktopDetailsPickChat.
  ///
  /// In en, this message translates to:
  /// **'Pick a chat'**
  String get desktopDetailsPickChat;

  /// No description provided for @desktopDetailsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Details about the person or room\nwill appear here.'**
  String get desktopDetailsEmptyHint;

  /// No description provided for @desktopMemberWrite.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get desktopMemberWrite;

  /// No description provided for @desktopShowPanel.
  ///
  /// In en, this message translates to:
  /// **'Show the panel'**
  String get desktopShowPanel;

  /// No description provided for @desktopHidePanel.
  ///
  /// In en, this message translates to:
  /// **'Hide the panel'**
  String get desktopHidePanel;

  /// No description provided for @desktopNotifOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off'**
  String get desktopNotifOff;

  /// No description provided for @desktopSettingsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Find a setting'**
  String get desktopSettingsSearchHint;

  /// No description provided for @desktopUnlockPrompt.
  ///
  /// In en, this message translates to:
  /// **'Unlock Secretly'**
  String get desktopUnlockPrompt;

  /// No description provided for @desktopEnableLockPrompt.
  ///
  /// In en, this message translates to:
  /// **'Confirm to turn on the Secretly lock'**
  String get desktopEnableLockPrompt;

  /// No description provided for @desktopRoomsNoneHintDot.
  ///
  /// In en, this message translates to:
  /// **'Create a room on your phone — it will show up here by itself.'**
  String get desktopRoomsNoneHintDot;

  /// No description provided for @desktopSplashLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your profile…'**
  String get desktopSplashLoading;

  /// No description provided for @desktopOutgoingOnePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get desktopOutgoingOnePhoto;

  /// No description provided for @desktopOutgoingOneVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get desktopOutgoingOneVideo;

  /// No description provided for @desktopOutgoingOneAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get desktopOutgoingOneAudio;

  /// No description provided for @desktopOutgoingOneFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get desktopOutgoingOneFile;

  /// No description provided for @desktopMenuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings…'**
  String get desktopMenuSettings;

  /// No description provided for @desktopMenuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get desktopMenuEdit;

  /// No description provided for @desktopMenuUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get desktopMenuUndo;

  /// No description provided for @desktopMenuRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get desktopMenuRedo;

  /// No description provided for @desktopMenuCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get desktopMenuCut;

  /// No description provided for @desktopMenuPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get desktopMenuPaste;

  /// No description provided for @desktopMenuSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get desktopMenuSelectAll;

  /// No description provided for @desktopMenuView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get desktopMenuView;

  /// No description provided for @desktopMenuWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get desktopMenuWindow;

  /// No description provided for @desktopMenuHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get desktopMenuHelp;

  /// No description provided for @desktopMenuWebsite.
  ///
  /// In en, this message translates to:
  /// **'Secretly Website'**
  String get desktopMenuWebsite;

  /// No description provided for @desktopContactsAddHint.
  ///
  /// In en, this message translates to:
  /// **'Secretly ID or invite link'**
  String get desktopContactsAddHint;

  /// No description provided for @desktopContactsAdded.
  ///
  /// In en, this message translates to:
  /// **'Contact added'**
  String get desktopContactsAdded;

  /// No description provided for @desktopContactsRenamed.
  ///
  /// In en, this message translates to:
  /// **'Name saved'**
  String get desktopContactsRenamed;

  /// No description provided for @desktopMenuCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates…'**
  String get desktopMenuCheckUpdates;

  /// No description provided for @desktopNotifBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'The system is not showing Secretly notifications'**
  String get desktopNotifBlockedTitle;

  /// No description provided for @desktopNotifBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'The switches below still work, but nothing will be shown: the system is blocking this app’s notifications. The window is often hidden, and a notification is the only way to learn about a new message.'**
  String get desktopNotifBlockedBody;

  /// No description provided for @desktopNotifBlockedAction.
  ///
  /// In en, this message translates to:
  /// **'Open System Settings'**
  String get desktopNotifBlockedAction;

  /// No description provided for @backupPwRequirements.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 ASCII characters, one uppercase letter, and one special character. No leading or trailing spaces.'**
  String get backupPwRequirements;

  /// No description provided for @backupPwTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least {count} characters.'**
  String backupPwTooShort(int count);

  /// No description provided for @backupPwTooLong.
  ///
  /// In en, this message translates to:
  /// **'Password must be no longer than {count} characters.'**
  String backupPwTooLong(int count);

  /// No description provided for @backupPwNonAscii.
  ///
  /// In en, this message translates to:
  /// **'Use only Latin letters, digits, and ASCII symbols.'**
  String get backupPwNonAscii;

  /// No description provided for @backupPwOuterSpace.
  ///
  /// In en, this message translates to:
  /// **'Remove leading or trailing spaces from the password.'**
  String get backupPwOuterSpace;

  /// No description provided for @backupPwNeedUpper.
  ///
  /// In en, this message translates to:
  /// **'Add at least one uppercase A-Z letter.'**
  String get backupPwNeedUpper;

  /// No description provided for @backupPwNeedSpecial.
  ///
  /// In en, this message translates to:
  /// **'Add at least one special character, such as !, #, or ?.'**
  String get backupPwNeedSpecial;

  /// No description provided for @desktopAuthGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Secretly on this computer'**
  String get desktopAuthGateTitle;

  /// No description provided for @desktopAuthGateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how to sign in'**
  String get desktopAuthGateSubtitle;

  /// No description provided for @desktopAuthPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your phone'**
  String get desktopAuthPhoneTitle;

  /// No description provided for @desktopAuthPhoneBody.
  ///
  /// In en, this message translates to:
  /// **'If Secretly is already on your phone. Chats and contacts will move here.'**
  String get desktopAuthPhoneBody;

  /// No description provided for @desktopAuthCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new account'**
  String get desktopAuthCreateTitle;

  /// No description provided for @desktopAuthCreateBody.
  ///
  /// In en, this message translates to:
  /// **'An account on this computer only. A subscription can be bought only in the phone app.'**
  String get desktopAuthCreateBody;

  /// No description provided for @desktopAuthRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get desktopAuthRestoreTitle;

  /// No description provided for @desktopAuthRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'From a recovery kit or from a backup on the server.'**
  String get desktopAuthRestoreBody;

  /// No description provided for @desktopAuthBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get desktopAuthBack;

  /// No description provided for @desktopAuthNameTitle.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get desktopAuthNameTitle;

  /// No description provided for @desktopAuthNameBody.
  ///
  /// In en, this message translates to:
  /// **'People you write to will see this name. You can change it at any time.'**
  String get desktopAuthNameBody;

  /// No description provided for @desktopAuthCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating the account…'**
  String get desktopAuthCreating;

  /// No description provided for @desktopAuthCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the account: {error}'**
  String desktopAuthCreateFailed(Object error);

  /// No description provided for @desktopAuthCheckClock.
  ///
  /// In en, this message translates to:
  /// **'Check the computer’s clock: the server rejects requests when it is off.'**
  String get desktopAuthCheckClock;

  /// No description provided for @desktopAuthKitTitle.
  ///
  /// In en, this message translates to:
  /// **'Save your recovery kit'**
  String get desktopAuthKitTitle;

  /// No description provided for @desktopAuthKitBody.
  ///
  /// In en, this message translates to:
  /// **'This is the only way back into the account if the computer breaks or is lost. Secretly has no email and no phone number: without the kit nobody can restore the account, including us.'**
  String get desktopAuthKitBody;

  /// No description provided for @desktopAuthKitAction.
  ///
  /// In en, this message translates to:
  /// **'Create the recovery kit'**
  String get desktopAuthKitAction;

  /// No description provided for @desktopAuthKitSaved.
  ///
  /// In en, this message translates to:
  /// **'Kit saved. The account can be restored now.'**
  String get desktopAuthKitSaved;

  /// No description provided for @desktopAuthContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get desktopAuthContinue;

  /// No description provided for @desktopAuthKitOptionTitle.
  ///
  /// In en, this message translates to:
  /// **'I have a recovery kit'**
  String get desktopAuthKitOptionTitle;

  /// No description provided for @desktopAuthKitOptionBody.
  ///
  /// In en, this message translates to:
  /// **'The simplest way: the kit already carries your Secretly ID.'**
  String get desktopAuthKitOptionBody;

  /// No description provided for @desktopAuthKitPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the contents of the kit'**
  String get desktopAuthKitPasteHint;

  /// No description provided for @desktopAuthServerOptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup on the server'**
  String get desktopAuthServerOptionTitle;

  /// No description provided for @desktopAuthServerOptionBody.
  ///
  /// In en, this message translates to:
  /// **'You will need your Secretly ID and the backup password.'**
  String get desktopAuthServerOptionBody;

  /// No description provided for @desktopAuthRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring…'**
  String get desktopAuthRestoring;

  /// No description provided for @desktopAuthRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore: {error}'**
  String desktopAuthRestoreFailed(Object error);

  /// No description provided for @desktopAuthBackupNotFound.
  ///
  /// In en, this message translates to:
  /// **'There is no backup on the server for this Secretly ID.'**
  String get desktopAuthBackupNotFound;

  /// No description provided for @desktopGeneralLaunchAtLogin.
  ///
  /// In en, this message translates to:
  /// **'Launch at login'**
  String get desktopGeneralLaunchAtLogin;

  /// No description provided for @desktopGeneralLaunchAtLoginOn.
  ///
  /// In en, this message translates to:
  /// **'Secretly starts on its own and keeps receiving messages'**
  String get desktopGeneralLaunchAtLoginOn;

  /// No description provided for @desktopGeneralLaunchAtLoginOff.
  ///
  /// In en, this message translates to:
  /// **'While Secretly is not running, messages do not reach this computer'**
  String get desktopGeneralLaunchAtLoginOff;

  /// No description provided for @desktopGeneralLaunchNeedsApproval.
  ///
  /// In en, this message translates to:
  /// **'Launch at login is switched off in System Settings, under Login Items'**
  String get desktopGeneralLaunchNeedsApproval;

  /// No description provided for @desktopA11yStatusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get desktopA11yStatusSending;

  /// No description provided for @desktopA11yStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get desktopA11yStatusScheduled;

  /// No description provided for @desktopA11yStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get desktopA11yStatusSent;

  /// No description provided for @desktopA11yStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get desktopA11yStatusDelivered;

  /// No description provided for @desktopA11yStatusRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get desktopA11yStatusRead;

  /// No description provided for @desktopA11yStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get desktopA11yStatusFailed;

  /// No description provided for @desktopA11yVoiceProgress.
  ///
  /// In en, this message translates to:
  /// **'Voice message playback'**
  String get desktopA11yVoiceProgress;

  /// No description provided for @desktopViewerPagePrev.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get desktopViewerPagePrev;

  /// No description provided for @desktopViewerPageNext.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get desktopViewerPageNext;

  /// No description provided for @desktopReactionsMore.
  ///
  /// In en, this message translates to:
  /// **'More emoji'**
  String get desktopReactionsMore;

  /// No description provided for @desktopReactionsCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get desktopReactionsCollapse;

  /// No description provided for @desktopThreadScrollToBottom.
  ///
  /// In en, this message translates to:
  /// **'To the latest messages'**
  String get desktopThreadScrollToBottom;

  /// No description provided for @desktopViewerPrev.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get desktopViewerPrev;

  /// No description provided for @desktopViewerNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get desktopViewerNext;

  /// No description provided for @desktopA11yPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get desktopA11yPlay;

  /// No description provided for @desktopA11yPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get desktopA11yPause;

  /// No description provided for @desktopA11yAudioProgress.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get desktopA11yAudioProgress;

  /// No description provided for @desktopPlayerClose.
  ///
  /// In en, this message translates to:
  /// **'Close player'**
  String get desktopPlayerClose;

  /// No description provided for @desktopPlayerOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Go to message'**
  String get desktopPlayerOpenSource;

  /// No description provided for @desktopPlayerNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing: {title}'**
  String desktopPlayerNowPlaying(String title);

  /// No description provided for @desktopPlayerPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get desktopPlayerPrevious;

  /// No description provided for @desktopPlayerNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get desktopPlayerNext;

  /// No description provided for @desktopPlayerMore.
  ///
  /// In en, this message translates to:
  /// **'More in this chat'**
  String get desktopPlayerMore;

  /// No description provided for @desktopPlayerSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get desktopPlayerSpeed;

  /// No description provided for @desktopPlayerSpeedNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get desktopPlayerSpeedNormal;

  /// No description provided for @desktopPlayerVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get desktopPlayerVolume;

  /// No description provided for @desktopUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get desktopUpdateNow;

  /// No description provided for @desktopUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String desktopUpdateAvailable(String version);

  /// No description provided for @desktopDiagTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery diagnostics'**
  String get desktopDiagTitle;

  /// No description provided for @desktopDiagHint.
  ///
  /// In en, this message translates to:
  /// **'What to look at when messages are not arriving, and what to send us'**
  String get desktopDiagHint;

  /// No description provided for @desktopDiagQueues.
  ///
  /// In en, this message translates to:
  /// **'QUEUES'**
  String get desktopDiagQueues;

  /// No description provided for @desktopDiagOutbox.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be sent'**
  String get desktopDiagOutbox;

  /// No description provided for @desktopDiagStuck.
  ///
  /// In en, this message translates to:
  /// **'Stuck on arrival'**
  String get desktopDiagStuck;

  /// No description provided for @desktopDiagReceipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts queued'**
  String get desktopDiagReceipts;

  /// No description provided for @desktopDiagNothingStuck.
  ///
  /// In en, this message translates to:
  /// **'Nothing is stuck'**
  String get desktopDiagNothingStuck;

  /// No description provided for @desktopDiagConditions.
  ///
  /// In en, this message translates to:
  /// **'DELIVERY CONDITIONS'**
  String get desktopDiagConditions;

  /// No description provided for @desktopDiagClockOk.
  ///
  /// In en, this message translates to:
  /// **'Computer clock agrees with the server'**
  String get desktopDiagClockOk;

  /// No description provided for @desktopDiagClockSkew.
  ///
  /// In en, this message translates to:
  /// **'Computer clock is off by {delta} — the server may refuse messages'**
  String desktopDiagClockSkew(Object delta);

  /// No description provided for @desktopDiagCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy for support'**
  String get desktopDiagCopy;

  /// No description provided for @desktopAppearanceTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get desktopAppearanceTextSize;

  /// No description provided for @desktopAppearanceTextSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Applies to the whole window. Spacing and icons stay as designed'**
  String get desktopAppearanceTextSizeHint;

  /// No description provided for @desktopThreadGoToDate.
  ///
  /// In en, this message translates to:
  /// **'Go to date'**
  String get desktopThreadGoToDate;

  /// No description provided for @desktopHotkeyGlobalShow.
  ///
  /// In en, this message translates to:
  /// **'Show Secretly from anywhere'**
  String get desktopHotkeyGlobalShow;

  /// No description provided for @desktopHotkeyGlobalHint.
  ///
  /// In en, this message translates to:
  /// **'Off by default: the shortcut is system-wide and would be taken away from another app'**
  String get desktopHotkeyGlobalHint;

  /// No description provided for @desktopHotkeyGlobalTaken.
  ///
  /// In en, this message translates to:
  /// **'Another app already holds this shortcut'**
  String get desktopHotkeyGlobalTaken;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en', 'es', 'fr', 'pt', 'ru', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt': {
  switch (locale.countryCode) {
    case 'BR': return AppLocalizationsPtBr();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de': return AppLocalizationsDe();
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'fr': return AppLocalizationsFr();
    case 'pt': return AppLocalizationsPt();
    case 'ru': return AppLocalizationsRu();
    case 'uk': return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
