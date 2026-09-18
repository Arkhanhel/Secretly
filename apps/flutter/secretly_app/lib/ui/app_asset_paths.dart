// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
abstract final class AppAssetPaths {
  static const String iconsRoot = 'assets/app_ui/icons';
  static const String reactionsDir = '$iconsRoot/reactions';
  static const String pngIconsDir = '$iconsRoot/png';
  static const String settingsIconsDir = '$iconsRoot/Settings';
  static const String songsRoot = 'assets/app_ui/sounds';

  static const String addUserMaleLottie =
      '$iconsRoot/icons8-add-user-male.json';
  static const String chatBubbleFabPng = 'assets/icon/icons8-chat-transparent.png';
  static const String callLottie = '$iconsRoot/icons8-call.json';
  static const String copyLottie = '$iconsRoot/icons8-copy.json';
  static const String devicesAuthSyncLottie = '$iconsRoot/Messenger sync.json';
  static const String donationBoxLottie = '$iconsRoot/donation box.json';
  static const String favoritesNotebookSvg = '$iconsRoot/notebook.svg';
  static const String favoritesNotePng = '$iconsRoot/note (1).png';
  static const String fingerprintLottie =
      '$iconsRoot/icons8-отпечаток-пальца.json';
  static const String interactiveMoodSelectorLottie =
      '$iconsRoot/Interactive Mood Selector UI.json';
  static const String moonLottie = '$iconsRoot/icons8-moon.json';
  static const String reactionCookieAngry = '$reactionsDir/cookie_angry.json';
  static const String reactionCookieDevil = '$reactionsDir/cookie_devil.json';
  static const String reactionCookieEyes = '$reactionsDir/cookie_eyes.json';
  static const String reactionCookieHearts = '$reactionsDir/cookie_hearts.json';
  static const String reactionCookieScared = '$reactionsDir/cookie_scared.json';
  static const String roomLottie = '$iconsRoot/icons8-room.json';
  static const String securityUnlockLottie = '$iconsRoot/security_unlock.json';
  static const String settingsMicPng = '$settingsIconsDir/icons8-mic.png';
  static const String smileLottie = '$iconsRoot/icons8-smile2.json';
  static const String starLottie = '$iconsRoot/icons8-star.json';
  static const String sunLottie = '$iconsRoot/icons8-san.json';
  static const String appIconPng = '$iconsRoot/app_icon.png';

  static const String profileSmilePng = '$pngIconsDir/137-smile.png';
  static const String profileStarPng = '$pngIconsDir/103-star.png';
  static const String profileFavoritePng = '$pngIconsDir/223-favourite.png';

  static const String incomingRingtoneMp3 = '$songsRoot/Bubble.mp3';
  static const String outgoingRingtoneMp3 = '$songsRoot/call/pixel_tono.mp3';
  // Synthesized ringback ("гудки дозвона") played to the caller on outgoing
  // calls (425 Hz, 1 s on / 4 s off, looped). See tool/gen_ringback.dart.
  static const String ringbackToneWav = '$songsRoot/call/ringback_ru.wav';
  static const String connectingToneMp3 = '$songsRoot/call/cytus_ii_im.mp3';

  static String notificationSong({
    required String folder,
    required String basename,
  }) => '$songsRoot/$folder/$basename.mp3';
}
