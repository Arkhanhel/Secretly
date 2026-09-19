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
