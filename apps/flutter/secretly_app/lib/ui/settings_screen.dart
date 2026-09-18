// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'package:lottie/lottie.dart';
import 'animations/animations.dart';
import 'icons/app_icons.dart';

import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app/app_controller.dart';
import '../calls/call_manager.dart';
import '../reliability/delivery_reliability_service.dart';
import 'delivery_reliability_screen.dart';
import '../storage/cache_manager.dart';
import 'voice/voice_transcription.dart';
import '../cosmetics/cosmetics_catalog_service.dart';
import '../entitlements/cosmetic_catalog.dart';
import 'widgets/animated_wallpaper_preview.dart';
import 'widgets/wallpaper_picker_sheet.dart';
import '../entitlements/entitlement_models.dart';
import '../security/app_security_manager.dart';
import 'paywall_screen.dart';
import '../billing/show_paywall.dart';
import 'widgets/premium_glass.dart';
import '../version/app_package_info.dart';
import 'support_request_utils.dart';
import 'support_screen.dart';
import 'app_asset_paths.dart';
import 'chat_wallpapers.dart';
import 'liquid_glass_flags.dart';
import '../security/screen_privacy.dart';
import 'l10n.dart';
import 'theme_presets.dart';
import 'premium/app_icon_picker.dart';
import 'theme_transition.dart';
import 'devices_auth_screen.dart';
import 'my_secretly_id_screen.dart';
import 'profile_screen.dart';
import 'privacy_screen.dart';
import 'safe_backup_screen.dart';
import 'personal_chats_screen.dart';
import 'security_settings_screen.dart';
import 'security_lock_flow.dart';
import 'diagnostics_screen.dart';
import 'diagnostics_unlock.dart';
import 'settings_screen_l10n.dart';
import 'share_utils.dart';
import 'wave1_l10n.dart';
import 'widgets/content_edge_fade.dart';
import 'widgets/frosted_header_island.dart';
import 'widgets/frosted_top_bar.dart';
import 'widgets/support_badge.dart';
import 'haptics.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _PreserveWhiteColorMapper extends ColorMapper {
  const _PreserveWhiteColorMapper(this.targetColor);

  final Color targetColor;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color.a <= 0) {
      return color;
    }

    final isWhiteDetail =
        color.r >= 0.995 && color.g >= 0.995 && color.b >= 0.995;
    if (isWhiteDetail) {
      return const Color(0xFFFFFFFF).withValues(alpha: color.a);
    }

    return targetColor.withValues(alpha: color.a);
  }
}

const String _kDonorboxCampaignUrl = 'https://donorbox.org/donate-to-secretly';
const String _kSecretlyWebsiteUrl = 'https://www.secretlyapp.com';
const String _kSecretlyPrivacyPolicyUrl =
    'https://www.secretlyapp.com/privacy-policy';
const String _kSecretlyTermsUrl =
    'https://www.secretlyapp.com/terms-of-service';

String _settingsLabel(
  BuildContext context, {
  required String ru,
  required String en,
}) {
  return settingsScreenLabel(context, ru: ru, en: en);
}

Future<bool> _openDonorboxCampaignInBrowser(BuildContext context) async {
  final uri = Uri.tryParse(_kDonorboxCampaignUrl);
  if (uri == null) {
    return false;
  }
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) {
      return true;
    }
  } catch (_) {
    // Fall through to the snackbar below.
  }
  if (!context.mounted) {
    return false;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SecretlySnackBar(
      content: Text(
        _settingsLabel(
          context,
          ru: 'Не удалось открыть страницу Donorbox в браузере.',
          en: 'Could not open the Donorbox page in a browser.',
        ),
      ),
    ),
  );
  return false;
}

Future<bool> _openSecretlyExternalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) {
      return true;
    }
  } catch (_) {
    // Fall through to the snackbar below.
  }
  if (!context.mounted) {
    return false;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SecretlySnackBar(
      content: Text(
        _settingsLabel(
          context,
          ru: 'Не удалось открыть ссылку на сайт Secretly.',
          en: 'Could not open the Secretly website link.',
        ),
      ),
    ),
  );
  return false;
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _nativeCallUiChannel = MethodChannel(
    'secretly/call_ui',
  );
  static const String _settingsIconsDir = AppAssetPaths.settingsIconsDir;
  static const String _iconAccount = '$_settingsIconsDir/w11-account.png';
  static const String _iconChats = '$_settingsIconsDir/w11-chats.png';
  static const String _iconPrivacy = '$_settingsIconsDir/w11-privacy.png';
  static const String _iconNotifications =
      '$_settingsIconsDir/w11-notifications.png';
  static const String _iconLanguage = '$_settingsIconsDir/w11-language.png';
  static const String _iconDevices = '$_settingsIconsDir/w11-devices.png';
  static const String _iconSystem = '$_settingsIconsDir/w11-system.png';
  static const String _iconSupport = '$_settingsIconsDir/w11-support.png';
  static const String _iconPolicy = '$_settingsIconsDir/w11-policy.png';
  static const String _iconInfo = '$_settingsIconsDir/w11-info.png';
  static const String _iconInvite = '$_settingsIconsDir/w11-invite.png';
  static const String _iconDonate = '$_settingsIconsDir/w11-donate.png';

  static const String _iconChatsWallpaper =
      '$_settingsIconsDir/Chats/w11-wallpaper.png';
  static const String _iconChatsTheme =
      '$_settingsIconsDir/Chats/w11-theme.png';
  static const String _iconChatsBubbleStyle =
      '$_settingsIconsDir/Chats/w11-bubble.png';
  static const String _iconChatsApproved =
      '$_settingsIconsDir/Chats/w11-verified.png';

  static const String _iconPrivacyVisibility =
      '$_settingsIconsDir/privat/w11-eye.png';
  static const String _iconPrivacyList =
      '$_settingsIconsDir/privat/w11-list.png';
  static const String _iconPrivacyStop =
      '$_settingsIconsDir/privat/w11-block.png';

  static const Color _iconBlue = Color(0xFF2AABEE);
  static const Color _iconOrange = Color(0xFFF39A2B);
  static const Color _iconGreen = Color(0xFF35B86B);
  static const Color _iconRed = Color(0xFFE25563);
  static const Color _iconPurple = Color(0xFF7C67F2);
  static const Color _iconCyan = Color(0xFF1FAFC4);
  static const Color _iconAmber = Color(0xFFE0A43A);

  List<String> _bundledWallpaperPaths = const <String>[];
  // Server-hosted premium wallpapers (id + title) for the wallpaper pickers.
  List<({String id, String title})> _serverWallpapers =
      const <({String id, String title})>[];

  static const String _prefsLanguageShowTranslateButtonKey =
      'settings_language_show_translate_btn_v1';
  static const String _prefsLanguageTranslateWholeChatKey =
      'settings_language_translate_whole_chat_v1';
  // Translator direction. Source 'auto' = auto-detect the message language;
  // target '' = the app/device language. Otherwise BCP-47 codes (e.g. 'en').
  static const String _prefsLanguageTranslateSourceKey =
      'settings_language_translate_source_v1';
  static const String _prefsLanguageTranslateTargetKey =
      'settings_language_translate_target_v1';
  static const String _prefsPrivacySuggestContactsKey =
      'settings_privacy_suggest_contacts_v1';

  static const String _prefsNotifAllAccountsKey =
      'settings_notif_all_accounts_v1';
  static const String _prefsNotifPrivateChatsKey =
      'settings_notif_private_chats_v1';
  static const String _prefsNotifGroupsKey = 'settings_notif_groups_v1';
  static const String _prefsNotifInAppSoundKey =
      'settings_notif_in_app_sound_v1';
  static const String _prefsNotifInAppVibrateKey =
      'settings_notif_in_app_vibrate_v1';
  static const String _prefsNotifInAppPreviewKey =
      'settings_notif_in_app_preview_v1';
  static const String _prefsNotifPrivacyLevelKey =
      'settings_notif_privacy_level_v1';
  static const String _prefsNotifInAppChatSoundKey =
      'settings_notif_in_app_chat_sound_v1';
  static const String _prefsNotifInAppSoundAssetKey =
      'settings_notif_in_app_sound_asset_v1';
  static const String _prefsNotifInAppChatSoundAssetKey =
      'settings_notif_in_app_chat_sound_asset_v1';
  static const String _prefsNotifBackgroundCardKey =
      'settings_notif_background_card_v1';
  static const String _prefsNotifBackgroundConnectionKey =
      'settings_notif_background_connection_v1';
  static const String _prefsNotifCallVibrationKey =
      'settings_notif_call_vibration_v1';
  static const String _prefsNotifCallRingtoneKey =
      'settings_notif_call_ringtone_v1';
  static const String _prefsNotifPrivateMessagesKey =
      'settings_notif_private_messages_v1';
  static const String _prefsNotifPrivateShowTextKey =
      'settings_notif_private_show_text_v1';
  static const String _prefsNotifPrivateShowSenderKey =
      'settings_notif_private_show_sender_v1';
  static const String _prefsNotifGroupsMessagesKey =
      'settings_notif_groups_messages_v1';
  static const String _prefsNotifGroupsShowTextKey =
      'settings_notif_groups_show_text_v1';
  static const String _prefsNotifGroupsShowSenderKey =
      'settings_notif_groups_show_sender_v1';
  static const String _prefsAppHapticsKey = 'settings_app_haptics_v1';

  bool _languageShowTranslateButton = false;
  bool _languageTranslateWholeChat = false;
  String _translateSourceLang = 'auto';
  String _translateTargetLang = '';

  bool _notifAllAccounts = true;
  bool _notifPrivateChats = true;
  bool _notifGroups = true;
  bool _notifPrivateMessages = true;
  bool _notifPrivateShowText = false;
  bool _notifPrivateShowSender = true;
  bool _notifGroupsMessages = true;
  bool _notifGroupsShowText = false;
  bool _notifGroupsShowSender = true;
  bool _notifInAppSound = true;
  bool _notifInAppVibrate = true;
  bool _notifInAppPreview = true;
  int _notifPrivacyLevel = 1;
  bool _notifInAppChatSound = true;
  String _notifInAppSoundAsset = 'bubble_mail';
  String _notifInAppChatSoundAsset = 'keycap';
  bool _notifBackgroundCard = true;
  bool _notifBackgroundConnection = true;
  String _notifCallVibration = 'off';
  String _notifCallRingtone = 'default';
  bool _appHaptics = true;
  bool _androidFullScreenIntentGranted = true;
  bool _androidFullScreenIntentChecked = false;
  bool _loggingOut = false;
  bool _resettingProfile = false;
  late final Future<AppPackageInfo> _appPackageInfoFuture;

  // Жест «пять нажатий по версии», открывающий раздел «Диагностика».
  // См. [DiagnosticsUnlock]: раздел показывает идентификаторы и состояние
  // очередей — он для владельца и поддержки, а не для витрины.
  int _versionTaps = 0;
  int _versionLastTapAtMs = 0;
  bool _diagnosticsUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appPackageInfoFuture = AppPackageInfo.load();
    unawaited(_loadDiagnosticsUnlocked());
    _loadBundledWallpaperPaths();
    _loadExtraSettings();
    _refreshAndroidFullScreenIntentPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAndroidFullScreenIntentPermission());
    }
  }

  Future<void> _refreshAndroidFullScreenIntentPermission() async {
    if (!Platform.isAndroid) return;
    try {
      final granted = await _nativeCallUiChannel.invokeMethod<bool>(
        'canUseFullScreenIntent',
      );
      if (!mounted) return;
      setState(() {
        _androidFullScreenIntentGranted = granted ?? true;
        _androidFullScreenIntentChecked = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _androidFullScreenIntentChecked = true;
      });
    }
  }

  Future<void> _openAndroidFullScreenIntentPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _nativeCallUiChannel.invokeMethod<void>(
        'requestFullScreenIntentPermission',
      );
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _refreshAndroidFullScreenIntentPermission();
  }

  Future<void> _loadDiagnosticsUnlocked() async {
    final unlocked = await DiagnosticsUnlock.isUnlocked();
    if (!mounted || unlocked == _diagnosticsUnlocked) return;
    setState(() => _diagnosticsUnlocked = unlocked);
  }

  /// Нажатие по строке версии. Пять подряд — раздел открыт.
  void _onVersionTap(BuildContext context) {
    if (_diagnosticsUnlocked) return; // уже открыт — жест ничего не меняет
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final taps = DiagnosticsUnlock.nextTapCount(
      previousTaps: _versionTaps,
      lastTapAtMs: _versionLastTapAtMs,
      nowMs: nowMs,
    );
    _versionTaps = taps;
    _versionLastTapAtMs = nowMs;

    if (DiagnosticsUnlock.unlocksAt(taps)) {
      _versionTaps = 0;
      _versionLastTapAtMs = 0;
      unawaited(DiagnosticsUnlock.setUnlocked(true));
      if (!mounted) return;
      setState(() => _diagnosticsUnlocked = true);
      _showVersionTapSnack(
        context,
        _label(
          context,
          ru: 'Диагностика включена — она в конце списка настроек',
          en: 'Diagnostics enabled — it is at the end of Settings',
        ),
      );
      return;
    }

    final left = DiagnosticsUnlock.remainingHint(taps);
    if (left == null) return;
    _showVersionTapSnack(
      context,
      _label(
        context,
        ru: 'Ещё $left до включения диагностики',
        en: '$left more taps to enable diagnostics',
      ),
    );
  }

  void _showVersionTapSnack(BuildContext context, String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
  }

  String _label(
    BuildContext context, {
    required String ru,
    required String en,
  }) {
    return settingsScreenLabel(context, ru: ru, en: en);
  }

  /// Subtitle for the Backup row: the default description while everything is
  /// fine, otherwise what is actually wrong. Kept to one short line so the row
  /// looks the same as its neighbours.
  String _safeBackupStatusLine(
    BuildContext context,
    AppController c,
    String healthySubtitle,
  ) {
    switch (c.safeBackupHealth) {
      case SafeBackupHealth.ok:
        return healthySubtitle;
      case SafeBackupHealth.off:
        return context.l10n.backupTileOff;
      case SafeBackupHealth.pending:
        return context.l10n.backupTilePending;
      case SafeBackupHealth.failing:
        return context.l10n.backupTileFailing;
      case SafeBackupHealth.stale:
        return context.l10n.backupTileStale;
    }
  }

  String _audienceLabel(BuildContext context, String value) {
    switch (value) {
      case 'nobody':
        return _label(context, ru: 'Никто', en: 'Nobody');
      case 'contacts':
        return _label(context, ru: 'Контакты', en: 'My contacts');
      default:
        return _label(context, ru: 'Все', en: 'Everybody');
    }
  }

  String _callVibrationLabel(BuildContext context, String value) {
    switch (value) {
      case 'short':
        return _label(context, ru: 'Короткий', en: 'Short');
      case 'long':
        return _label(context, ru: 'Длинный', en: 'Long');
      case 'system':
        return _label(context, ru: 'Системный', en: 'System default');
      default:
        return _label(context, ru: 'Откл.', en: 'Off');
    }
  }

  String _callRingtoneLabel(BuildContext context, String value) {
    switch (value) {
      case 'beacon':
        return _label(context, ru: 'Beacon', en: 'Beacon');
      case 'chime':
        return _label(context, ru: 'Chime', en: 'Chime');
      default:
        return _label(context, ru: 'По умолчанию', en: 'Default');
    }
  }

  String _sanitizeNotifAssetName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
  }

  String _notifSoundLabel(BuildContext context, String value) {
    final pretty = value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
    return pretty.isEmpty
        ? _label(context, ru: 'По умолчанию', en: 'Default')
        : pretty;
  }

  String _notifPrivacyLevelLabel(BuildContext context, int level) {
    switch (level.clamp(0, 2)) {
      case 0:
        return _label(context, ru: 'Скрыто', en: 'Hidden');
      case 1:
        return _label(context, ru: 'Только отправитель', en: 'Sender only');
      default:
        return _label(
          context,
          ru: 'Отправитель и текст',
          en: 'Sender + message',
        );
    }
  }

  Future<void> _loadExtraSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _languageShowTranslateButton =
          prefs.getBool(_prefsLanguageShowTranslateButtonKey) ?? false;
      _languageTranslateWholeChat =
          prefs.getBool(_prefsLanguageTranslateWholeChatKey) ?? false;
      _translateSourceLang =
          prefs.getString(_prefsLanguageTranslateSourceKey) ?? 'auto';
      _translateTargetLang =
          prefs.getString(_prefsLanguageTranslateTargetKey) ?? '';

      _notifAllAccounts = prefs.getBool(_prefsNotifAllAccountsKey) ?? true;
      _notifPrivateChats = prefs.getBool(_prefsNotifPrivateChatsKey) ?? true;
      _notifGroups = prefs.getBool(_prefsNotifGroupsKey) ?? true;
      _notifInAppSound = prefs.getBool(_prefsNotifInAppSoundKey) ?? true;
      _notifInAppVibrate = prefs.getBool(_prefsNotifInAppVibrateKey) ?? true;
      _notifInAppPreview = prefs.getBool(_prefsNotifInAppPreviewKey) ?? true;
      final savedPrivacyLevel = prefs.getInt(_prefsNotifPrivacyLevelKey);
      _notifPrivacyLevel = (savedPrivacyLevel ?? (_notifInAppPreview ? 2 : 1))
          .clamp(0, 2)
          .toInt();
      final defaultShowSender = _notifPrivacyLevel >= 1;
      final defaultShowText = _notifPrivacyLevel >= 2;
      // NOTE: the effective privacy level the notification code uses prefers the
      // runtime key over this `settings_*` mirror; it is reconciled just below
      // via the controller so Settings shows what notifications actually apply.
      _notifPrivateMessages =
          prefs.getBool(_prefsNotifPrivateMessagesKey) ?? true;
      _notifPrivateShowText =
          prefs.getBool(_prefsNotifPrivateShowTextKey) ?? defaultShowText;
      _notifPrivateShowSender =
          prefs.getBool(_prefsNotifPrivateShowSenderKey) ?? defaultShowSender;
      _notifGroupsMessages =
          prefs.getBool(_prefsNotifGroupsMessagesKey) ?? true;
      _notifGroupsShowText =
          prefs.getBool(_prefsNotifGroupsShowTextKey) ?? defaultShowText;
      _notifGroupsShowSender =
          prefs.getBool(_prefsNotifGroupsShowSenderKey) ?? defaultShowSender;
      _notifInAppChatSound =
          prefs.getBool(_prefsNotifInAppChatSoundKey) ?? true;
      _notifInAppSoundAsset = _sanitizeNotifAssetName(
        prefs.getString(_prefsNotifInAppSoundAssetKey) ?? 'bubble_mail',
      );
      if (_notifInAppSoundAsset.isEmpty) {
        _notifInAppSoundAsset = 'bubble_mail';
      }
      _notifInAppChatSoundAsset = _sanitizeNotifAssetName(
        prefs.getString(_prefsNotifInAppChatSoundAssetKey) ?? 'keycap',
      );
      if (_notifInAppChatSoundAsset.isEmpty) {
        _notifInAppChatSoundAsset = 'keycap';
      }
      _notifBackgroundCard =
          prefs.getBool(_prefsNotifBackgroundCardKey) ?? true;
      _notifBackgroundConnection =
          prefs.getBool(_prefsNotifBackgroundConnectionKey) ?? true;
      _notifCallVibration =
          prefs.getString(_prefsNotifCallVibrationKey) ?? 'off';
      _notifCallRingtone =
          prefs.getString(_prefsNotifCallRingtoneKey) ?? 'default';
      _appHaptics = prefs.getBool(_prefsAppHapticsKey) ?? true;
    });

    // Reconcile the displayed privacy level with the effective value the
    // notification code actually uses (runtime key first, then `settings_*`
    // mirror). Keeps the global Settings page in agreement with the in-chat and
    // contact-profile notification entry points.
    final effectivePrivacyLevel = await widget.controller
        .getGlobalNotificationPrivacyLevel();
    if (!mounted) return;
    if (effectivePrivacyLevel != _notifPrivacyLevel) {
      setState(() {
        _notifPrivacyLevel = effectivePrivacyLevel;
        _notifInAppPreview = effectivePrivacyLevel >= 2;
        _notifPrivateShowSender = effectivePrivacyLevel >= 1;
        _notifPrivateShowText = effectivePrivacyLevel >= 2;
        _notifGroupsShowSender = effectivePrivacyLevel >= 1;
        _notifGroupsShowText = effectivePrivacyLevel >= 2;
      });
    }
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (key.startsWith('settings_notif_')) {
      widget.controller.refreshPushNotificationPolicy();
    }
  }

  Future<void> _saveIntSetting(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
    if (key.startsWith('settings_notif_')) {
      widget.controller.refreshPushNotificationPolicy();
    }
  }

  Future<void> _saveStringSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    if (key.startsWith('settings_notif_')) {
      widget.controller.refreshPushNotificationPolicy();
    }
  }

  Future<void> _loadBundledWallpaperPaths() async {
    final paths = await loadBundledChatWallpaperAssets();
    CosmeticsCatalogService.instance.configure(
      widget.controller.relayHttpBaseUrl,
    );
    final serverItems = await CosmeticsCatalogService.instance.wallpapers();
    if (!mounted) return;
    setState(() {
      _bundledWallpaperPaths = paths;
      _serverWallpapers = serverItems
          .map((it) => (id: it.id, title: it.title))
          .toList(growable: false);
    });
  }

  Future<void> _showDefaultWallpaperPicker(
    BuildContext context,
    AppController c,
  ) async {
    final latestPaths = await loadBundledChatWallpaperAssets();
    CosmeticsCatalogService.instance.configure(c.relayHttpBaseUrl);
    final serverItems = await CosmeticsCatalogService.instance.wallpapers();
    if (!context.mounted) return;
    if (mounted) {
      setState(() {
        _bundledWallpaperPaths = latestPaths;
        _serverWallpapers = serverItems
            .map((it) => (id: it.id, title: it.title))
            .toList(growable: false);
      });
    }
    final options = buildChatWallpaperOptions(
      context,
      assetPaths: latestPaths,
      filePaths: c.profileBackgroundPaths,
      serverWallpapers: _serverWallpapers,
      includeGlobalOption: false,
    );

    final selected = await showWallpaperPickerSheet(
      context,
      title: _label(
        context,
        ru: 'Обои чатов по умолчанию',
        en: 'Default chat wallpapers',
      ),
      options: options,
      selectedId: normalizeChatWallpaperId(c.defaultChatWallpaperId),
      isLocked: (id) => _cosmeticLocked(c, CosmeticKind.wallpaper, id),
      isAnimated: isAnimatedChatWallpaperId,
      onAnimatedUnlockedTap: (ctx, id) async {
        final style = decodeAnimatedChatWallpaperStyle(id);
        if (style == null) return null;
        final choice = await showAnimatedWallpaperPreview(
          ctx,
          style: style,
          initialMode: c.chatWallpaperAnimMode,
          initialConduct: c.chatWallpaperConduct,
        );
        if (choice == null) return null;
        await c.setChatWallpaperAnimMode(choice.mode);
        await c.setChatWallpaperConduct(choice.conduct);
        return id;
      },
    );

    if (selected == null ||
        !isValidChatWallpaperId(selected) ||
        selected == kGlobalChatWallpaperSelectionId) {
      return;
    }
    if (!context.mounted) return;
    await _onCosmeticTap(
      context,
      c,
      kind: CosmeticKind.wallpaper,
      id: selected,
      apply: () => c.setDefaultChatWallpaperId(selected),
    );
  }

  Future<void> _showAppThemePicker(
    BuildContext context,
    AppController c,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Material(
            color: cs.surface.withValues(alpha: 0.98),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                      child: Text(
                        _label(
                          context,
                          ru: 'Цветовая тема приложения',
                          en: 'Application color theme',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: kAppThemePresets.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                      itemBuilder: (context, index) {
                        final preset = kAppThemePresets[index];
                        final selected = preset.id == c.appThemePresetId;
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).pop(preset.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        preset.darkBgBottom,
                                        preset.darkBgTop,
                                      ],
                                    ),
                                    border: Border.all(
                                      color: selected
                                          ? cs.primary
                                          : cs.outlineVariant.withValues(
                                              alpha: 0.55,
                                            ),
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: preset.darkPrimary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: preset.darkSecondary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      settingsScreenPresetName(
                                        context,
                                        id: preset.id,
                                        ru: preset.nameRu,
                                        en: preset.nameEn,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      AppIcons.checkCircleSolid,
                                      size: 16,
                                      color: cs.primary,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (selected == null || !isValidAppThemePresetId(selected)) return;
    if (!context.mounted) return;
    await _onCosmeticTap(
      context,
      c,
      kind: CosmeticKind.theme,
      id: selected,
      apply: () => c.setAppThemePresetId(selected),
    );
  }

  Future<void> _showBubbleStylePicker(
    BuildContext context,
    AppController c,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Material(
            color: cs.surface.withValues(alpha: 0.98),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                      child: Text(
                        _label(
                          context,
                          ru: 'Стиль пузырей сообщений',
                          en: 'Message bubble style',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: kChatBubbleStylePresets.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                      itemBuilder: (context, index) {
                        final preset = kChatBubbleStylePresets[index];
                        final selected =
                            preset.id ==
                            normalizeChatBubbleStylePresetId(
                              c.chatBubbleStylePresetId,
                            );
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).pop(preset.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: cs.surfaceContainer,
                                    border: Border.all(
                                      color: selected
                                          ? cs.primary
                                          : cs.outlineVariant.withValues(
                                              alpha: 0.55,
                                            ),
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        width: 78,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: preset.darkMid != null
                                                ? [
                                                    preset.darkBottom,
                                                    preset.darkMid!,
                                                    preset.darkTop,
                                                  ]
                                                : [
                                                    preset.darkBottom,
                                                    preset.darkTop,
                                                  ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      settingsScreenPresetName(
                                        context,
                                        id: preset.id,
                                        ru: preset.nameRu,
                                        en: preset.nameEn,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      AppIcons.checkCircleSolid,
                                      size: 16,
                                      color: cs.primary,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (selected == null || !isValidChatBubbleStylePresetId(selected)) return;
    if (!context.mounted) return;
    await _onCosmeticTap(
      context,
      c,
      kind: CosmeticKind.bubbleStyle,
      id: selected,
      apply: () => c.setChatBubbleStylePresetId(selected),
    );
  }

  Future<void> _showNicknameStylePicker(
    BuildContext context,
    AppController c,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Material(
            color: cs.surface.withValues(alpha: 0.98),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                      child: Text(
                        _label(
                          context,
                          ru: 'Цвет имён в ответах и цитатах',
                          en: 'Names color in replies and quotes',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: kNicknameStylePresets.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                      itemBuilder: (context, index) {
                        final preset = kNicknameStylePresets[index];
                        final selected = preset.id == c.nicknameStylePresetId;
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).pop(preset.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: cs.surfaceContainer,
                                    border: Border.all(
                                      color: selected
                                          ? cs.primary
                                          : cs.outlineVariant.withValues(
                                              alpha: 0.55,
                                            ),
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _label(context, ru: 'Вы', en: 'You'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: preset.outgoing,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _label(
                                            context,
                                            ru: 'Контакт',
                                            en: 'Contact',
                                          ),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: preset.incoming,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      settingsScreenPresetName(
                                        context,
                                        id: preset.id,
                                        ru: preset.nameRu,
                                        en: preset.nameEn,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      AppIcons.checkCircleSolid,
                                      size: 16,
                                      color: cs.primary,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (selected == null || !isValidNicknameStylePresetId(selected)) return;
    await c.setNicknameStylePresetId(selected);
  }

  void _openProfile(BuildContext context, AppController controller) {
    Navigator.of(context).push(
      SecretlyPageRoute(builder: (_) => ProfileScreen(controller: controller)),
    );
  }

  Future<void> _openSupportSection(
    BuildContext context,
    AppController c,
  ) async {
    // In-app E2EE support (TZ 2026-07-24) when the signed config carries a
    // support key; otherwise fall back to the e-mail contact screen. Fail-OFF:
    // an unverified/absent block keeps the old behaviour.
    final Widget page = c.supportConfig.isUsable
        ? SupportScreen(controller: c)
        : _SupportContactScreen(controller: c);
    await Navigator.of(context).push(
      SecretlyPageRoute(builder: (_) => page),
    );
  }

  Future<void> _openMyId(
    BuildContext context,
    AppController c, {
    MySecretlyIdTab initialTab = MySecretlyIdTab.myQr,
  }) async {
    await Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) =>
            MySecretlyIdScreen(controller: c, initialTab: initialTab),
      ),
    );
  }

  Future<void> _editProfileName(BuildContext context, AppController c) async {
    final l10n = this.context.l10n;
    final controller = TextEditingController(text: c.myNickname.trim());
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_label(context, ru: 'Имя профиля', en: 'Profile name')),
        content: TextField(
          controller: controller,
          maxLength: 32,
          textInputAction: TextInputAction.done,
          autofocus: true,
          decoration: InputDecoration(
            labelText: _label(context, ru: 'Введите имя', en: 'Enter name'),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(_label(context, ru: 'Сохранить', en: 'Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await c.setMyNickname(name.trim());
  }

  Future<void> _shareProfile(BuildContext context, AppController c) async {
    final profileId = c.profileId.trim();
    if (profileId.isEmpty || profileId == 'unknown') return;
    final text = buildProfileShareText(
      profileId: profileId,
      isRu: settingsScreenUsesRussianShareText(context),
      displayName: c.myNickname,
    );
    await shareTextExternally(text: text);
  }

  Future<void> _showProfileMoreMenu(
    BuildContext context,
    AppController c,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.16),
      builder: (context) {
        final safeTop = MediaQuery.of(context).padding.top;
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: safeTop + kToolbarHeight - 10,
                    right: 10,
                  ),
                  child: FrostedPopupContainer(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 210,
                        maxWidth: 250,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => Navigator.of(context).pop('edit-name'),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    AppIcons.badge,
                                    size: 22,
                                    color: cs.onSurface.withValues(alpha: 0.92),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      _label(
                                        context,
                                        ru: 'Изменить имя',
                                        en: 'Change name',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () =>
                                Navigator.of(context).pop('share-profile'),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.share_outlined,
                                    size: 22,
                                    color: cs.onSurface.withValues(alpha: 0.92),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      _label(
                                        context,
                                        ru: 'Поделиться профилем',
                                        en: 'Share profile',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted || selected == null) return;
    switch (selected) {
      case 'edit-name':
        await _editProfileName(context, c);
        return;
      case 'share-profile':
        await _shareProfile(context, c);
        return;
    }
  }

  Future<void> _shareInvite(BuildContext context, AppController c) async {
    final text = buildInviteFriendShareText(
      controller: c,
      isRu: settingsScreenUsesRussianShareText(context),
    );
    await shareTextExternally(text: text);
  }

  Future<void> _openDonateSection(BuildContext context) async {
    await Navigator.of(context).push(
      SecretlyPageRoute(builder: (_) => const _DonateSupportLandingScreen()),
    );
  }

  Future<void> _openPrivacyPolicySection(BuildContext context) async {
    await Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => _SettingsInfoScreen(
          title: _label(
            context,
            ru: 'Политика конфиденциальности',
            en: 'Privacy policy',
          ),
          sections: [
            (
              title: _label(
                context,
                ru: 'Что хранится локально',
                en: 'What is stored locally',
              ),
              body: _label(
                context,
                ru: 'История чатов и вложения хранятся на вашем устройстве в зашифрованной базе.',
                en: 'Chat history and attachments are stored on your device in an encrypted database.',
              ),
            ),
            (
              title: _label(
                context,
                ru: 'Что проходит через сервер',
                en: 'What goes through the server',
              ),
              body: _label(
                context,
                ru: 'Серверы обрабатывают доставку зашифрованных пакетов, очереди TTL и сервис ключей. Контент сообщений не хранится в открытом виде.',
                en: 'Servers process encrypted message delivery, TTL queues, and key-service operations. Message content is not stored in plaintext.',
              ),
            ),
            (
              title: _label(
                context,
                ru: 'Официальная версия',
                en: 'Official version',
              ),
              body: _label(
                context,
                ru: 'Полная политика конфиденциальности и условия использования опубликованы на официальном сайте Secretly.',
                en: 'The full Privacy Policy and Terms of Service are published on the official Secretly website.',
              ),
            ),
          ],
          links: [
            _SettingsInfoLink(
              title: _label(
                context,
                ru: 'Открыть Privacy Policy',
                en: 'Open Privacy Policy',
              ),
              subtitle: _kSecretlyPrivacyPolicyUrl,
              url: _kSecretlyPrivacyPolicyUrl,
            ),
            _SettingsInfoLink(
              title: _label(
                context,
                ru: 'Открыть Terms of Service',
                en: 'Open Terms of Service',
              ),
              subtitle: _kSecretlyTermsUrl,
              url: _kSecretlyTermsUrl,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAboutSection(BuildContext context, AppController c) async {
    await Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => _SettingsInfoScreen(
          title: _label(context, ru: 'О Secretly', en: 'About Secretly'),
          sections: [
            (
              title: 'Secretly',
              body: _label(
                context,
                ru: 'Мессенджер с фокусом на E2EE, приватность и надежную доставку сообщений.',
                en: 'A messenger focused on E2EE, privacy, and reliable message delivery.',
              ),
            ),
            (
              title: _label(context, ru: 'Сборка', en: 'Build'),
              body: 'Build marker: ${c.buildMarker}',
            ),
          ],
          links: [
            _SettingsInfoLink(
              title: _label(
                context,
                ru: 'Официальный сайт',
                en: 'Official website',
              ),
              subtitle: _kSecretlyWebsiteUrl,
              url: _kSecretlyWebsiteUrl,
            ),
            _SettingsInfoLink(
              title: _label(
                context,
                ru: 'Privacy Policy',
                en: 'Privacy Policy',
              ),
              subtitle: _kSecretlyPrivacyPolicyUrl,
              url: _kSecretlyPrivacyPolicyUrl,
            ),
            _SettingsInfoLink(
              title: _label(
                context,
                ru: 'Terms of Service',
                en: 'Terms of Service',
              ),
              subtitle: _kSecretlyTermsUrl,
              url: _kSecretlyTermsUrl,
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Widget _buildAppInfoFooter({
    required BuildContext context,
    required ColorScheme cs,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: FutureBuilder<AppPackageInfo>(
        future: _appPackageInfoFuture,
        builder: (context, snapshot) {
          final info = snapshot.data ?? AppPackageInfo.fallback;
          final appName = info.appName;
          final version = info.version;
          final build = info.buildNumber;

          return Column(
            children: [
              Text(
                '$appName LLC',
                textAlign: TextAlign.center,
                style: textTheme.titleSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              // Пять нажатий подряд открывают раздел «Диагностика»
              // (см. [DiagnosticsUnlock]). `behavior: opaque` — чтобы
              // засчитывались нажатия по всей строке, а не только по буквам.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onVersionTap(context),
                child: Text(
                  _label(context,
                      ru: 'Версия $version ($build)',
                      en: 'Version $version ($build)'),
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Created by Arkhangel corp.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.86),
                ),
              ),
              // О-6 (26.08.2026). Экран лицензий был только в настольной
              // версии. На телефоне приложение везёт девятнадцать файлов
              // шрифтов под OFL и Apache 2.0 — а показать их лицензии человеку
              // было негде. Записи заявляются в
              // `lib/legal/third_party_licenses.dart`; без них этот экран
              // покажет только пакеты из `pub`, и шрифтов в нём не будет.
              TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: appName,
                  applicationVersion: _label(
                    context,
                    ru: 'Версия $version ($build)',
                    en: 'Version $version ($build)',
                  ),
                ),
                child: Text(
                  _label(context, ru: 'Лицензии', en: 'Licenses'),
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile({
    required BuildContext context,
    IconData? icon,
    IconData? fallbackIcon,
    String? iconAsset,
    Widget? leading,
    Color? iconTint,
    required Color iconBg,
    required Color iconFg,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Builder(
      builder: (ctx) {
        final flatIcon = _FlatIconMode.of(ctx);
        final scheme = Theme.of(ctx).colorScheme;
        final bgTint = iconTint ?? Colors.grey;
        // SOLID (opaque) island-style plate — the old faint translucent tint
        // blended onto the surface so the card never shows through.
        final effectiveBg = iconBg == Colors.transparent
            ? Color.alphaBlend(bgTint.withValues(alpha: 0.20), scheme.surface)
            : iconBg;
        // Squircle: a strongly-rounded square (not a circle), lifted by a thin
        // shadow like the app's glass islands.
        Widget squircle(Widget child) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(child: child),
        );
        final Widget iconLeading;
        if (leading != null) {
          iconLeading = leading;
        } else if (flatIcon) {
          iconLeading = SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Icon(
                fallbackIcon ?? icon ?? AppIcons.settings,
                size: 26,
                color: iconTint ?? iconFg,
              ),
            ),
          );
        } else {
          iconLeading = iconAsset != null
              ? squircle(
                  iconAsset.endsWith('.png')
                      ? Image.asset(
                          iconAsset,
                          width: 22,
                          height: 22,
                          color: iconTint ?? iconFg,
                          colorBlendMode: BlendMode.srcIn,
                        )
                      : SvgPicture.asset(
                          iconAsset,
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                          colorMapper: iconTint == null
                              ? null
                              : _PreserveWhiteColorMapper(iconTint),
                          placeholderBuilder: (context) => Center(
                            child: Icon(
                              fallbackIcon ?? icon ?? AppIcons.settings,
                              size: 18,
                              color: iconTint ?? iconFg,
                            ),
                          ),
                        ),
                )
              : squircle(Icon(icon, color: iconFg));
        }
        return ListTile(
          leading: iconLeading,
          minLeadingWidth: 44,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 1,
          ),
          title: Text(
            title,
            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
          trailing: trailing,
          // Отклик на нажатие для ВСЕХ строк настроек сразу: этот построитель
          // используется 66 раз. Расставлять руками значило бы забыть половину.
          onTap: onTap == null
              ? null
              : () {
                  Haptics.tap();
                  onTap();
                },
        );
      },
    );
  }

  Widget _svgLeading(
    String assetPath,
    Color tint, {
    IconData fallbackIcon = AppIcons.settings,
  }) {
    return CircleAvatar(
      backgroundColor: tint.withValues(alpha: 0.14),
      radius: 20,
      child: assetPath.endsWith('.png')
          ? Image.asset(
              assetPath,
              width: 22,
              height: 22,
              color: tint,
              colorBlendMode: BlendMode.srcIn,
            )
          : SvgPicture.asset(
              assetPath,
              width: 22,
              height: 22,
              fit: BoxFit.contain,
              colorMapper: _PreserveWhiteColorMapper(tint),
              placeholderBuilder: (context) =>
                  Center(child: Icon(fallbackIcon, size: 18, color: tint)),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    final noDividerTheme = Theme.of(context).copyWith(
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        space: 0,
        thickness: 0,
      ),
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        automaticallyImplyLeading: false,
        // Two floating matte islands (like the in-chat header): the profile
        // (avatar + name) on the left, QR + overflow on the right. The old
        // centered profile placeholder in the body is removed in favour of this.
        flexibleSpace: Stack(
          children: [
            // Top shade + blur behind the floating islands (the body extends
            // behind the app bar), matching the chat / list screens.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SystemTopFadeLayer(height: topInset, blurSigma: 20),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<void>(
                        stream: widget.controller.changed,
                        builder: (context, _) {
                          final c = widget.controller;
                          final raw = c.myAvatarPath;
                          final avatarPath = (raw != null && raw.isNotEmpty)
                              ? raw
                              : null;
                          final name = c.myNickname.isNotEmpty
                              ? c.myNickname
                              : l10n.mySecretlyId;
                          return FrostedHeaderIsland(
                            radius: 24,
                            height: 48,
                            // Symmetric avatar inset: left gap == top/bottom
                            // gap ((48 - 40) / 2 = 4), same rule as the
                            // in-chat header island.
                            padding: const EdgeInsets.fromLTRB(4, 0, 6, 0),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => _openProfile(context, c),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: cs.primaryContainer,
                                      foregroundColor: cs.onPrimaryContainer,
                                      child: ClipOval(
                                        child: SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: avatarPath == null
                                              ? const Icon(
                                                  AppIcons.personSolid,
                                                  size: 22,
                                                )
                                              : Image.file(
                                                  File(avatarPath),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                        AppIcons.personSolid,
                                                        size: 22,
                                                      ),
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FrostedHeaderIsland(
                      radius: 24,
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: _label(
                              context,
                              ru: 'QR профиля',
                              en: 'Profile QR',
                            ),
                            icon: const Icon(AppIcons.qrCode),
                            onPressed: () =>
                                _openMyId(context, widget.controller),
                          ),
                          IconButton(
                            tooltip: l10n.more,
                            icon: const Icon(AppIcons.moreVert, size: 23),
                            onPressed: () => _showProfileMoreMenu(
                              context,
                              widget.controller,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Theme(
        data: noDividerTheme,
        child: StreamBuilder<void>(
          stream: widget.controller.changed,
          builder: (context, _) {
            final c = widget.controller;
            final bottomInset = MediaQuery.of(context).padding.bottom;

            // Telegram-style content edge fade: the list's CONTENT dissolves to
            // transparent at the top (under the floating profile/QR islands) and
            // bottom (over the nav-pill gesture area). Paints no shading itself —
            // it only masks the list's alpha, so the appBar's SystemTopFadeLayer
            // and the shell's SystemBottomFadeLayer compose on top of it.
            return ContentEdgeFade(
              topFadeEndPx: topInset,
              bottomFadeFraction: 0.07,
              child: ListView(
                padding: EdgeInsets.only(
                  top: topInset,
                  bottom: 32 + bottomInset,
                ),
                children: [
                  // Profile (avatar + name) moved to a top-bar island — see the
                  // frostedAppBar flexibleSpace above.
                  // §C-4: proactive "Secretly Premium" entry (Telegram-style).
                  // Shown only when monetization is live AND the user is not paid,
                  // so it stays hidden in the current free-for-all and for premium
                  // users. Security is never gated; this is purely an upgrade entry.
                  if (c.entitlementStateNow.monetizationEnabled &&
                      !c.entitlementStateNow.tier.isPaid)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: PremiumGlassCard(
                        highlighted: false,
                        radius: 18,
                        onTap: () =>
                            showPaywall(context, PaywallTrigger.general),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFF6CE7A),
                                      Color(0xFFE0922C),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ShimmerGoldText(
                                      'Secretly Premium',
                                      colors: premiumShimmerColors(context),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      Localizations.localeOf(
                                                context,
                                              ).languageCode ==
                                              'ru'
                                          ? 'Больше лимитов, темы, рамки и многое другое'
                                          : 'More limits, themes, frames and more',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  _card([
                    _tile(
                      context: context,
                      iconAsset: _iconAccount,
                      fallbackIcon: AppIcons.personSolid,
                      iconTint: _iconBlue,
                      iconBg: Colors.transparent,
                      iconFg: cs.onSurface,
                      title: l10n.accountSection,
                      onTap: () {
                        Navigator.of(context).push(
                          SecretlyPageRoute(
                            builder: (_) => _SettingsCategoryScreen(
                              title: l10n.accountSection,
                              child: _buildAccount(
                                context: context,
                                c: c,
                                cs: cs,
                                l10n: l10n,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _tile(
                      context: context,
                      iconAsset: _iconChats,
                      fallbackIcon: AppIcons.chats,
                      iconTint: _iconOrange,
                      iconBg: Colors.transparent,
                      iconFg: cs.onSurface,
                      title: l10n.chatsSection,
                      onTap: () {
                        Navigator.of(context).push(
                          SecretlyPageRoute(
                            builder: (_) => _SettingsCategoryScreen(
                              title: l10n.chatsSection,
                              child: _StreamRebuild(
                                stream: c.changed,
                                builder: (ctx) => _buildChats(
                                  context: ctx,
                                  c: c,
                                  cs: Theme.of(ctx).colorScheme,
                                  l10n: l10n,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _tile(
                      context: context,
                      iconAsset: _iconPolicy,
                      fallbackIcon: AppIcons.photo,
                      iconTint: _iconBlue,
                      iconBg: Colors.transparent,
                      iconFg: cs.onSurface,
                      title: _label(
                        context,
                        ru: 'Медиа и профиль',
                        en: 'Media & profile',
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          SecretlyPageRoute(
                            builder: (_) => _SettingsCategoryScreen(
                              title: _label(
                                context,
                                ru: 'Медиа и профиль',
                                en: 'Media & profile',
                              ),
                              child: _buildMedia(
                                context: context,
                                c: c,
                                cs: cs,
                                l10n: l10n,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _tile(
                      context: context,
                      iconAsset: _iconPrivacy,
                      fallbackIcon: AppIcons.privacyTip,
                      iconTint: _iconGreen,
                      iconBg: Colors.transparent,
                      iconFg: cs.onSurface,
                      title: l10n.privacySection,
                      onTap: () {
                        Navigator.of(context).push(
                          SecretlyPageRoute(
                            builder: (_) => _SettingsCategoryScreen(
                              title: l10n.privacySection,
                              child: _buildPrivacy(
                                context: context,
                                c: c,
                                cs: cs,
                                l10n: l10n,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _tile(
                      context: context,
                      iconAsset: _iconPrivacyStop,
                      fallbackIcon: Icons.lock_rounded,
                      iconTint: _iconAmber,
                      iconBg: Colors.transparent,
                      iconFg: cs.onSurface,
                      title: _label(
                        context,
                        ru: 'Безопасность',
                        en: 'Security',
                      ),
                      onTap: () =>
                          openSecuritySettings(context: context, controller: c),
                    ),
                    const Divider(height: 1),
                    _tile(
                      context: context,
                      iconAsset: _iconNotifications,
                      fallbackIcon: AppIcons.bell,
                      iconTint: _iconRed,
                      iconBg: Colors.transparent,
                      iconFg: cs.onSurface,
                      title: l10n.notificationsSection,
                      onTap: () {
                        Navigator.of(context).push(
                          SecretlyPageRoute(
                            builder: (_) => _SettingsCategoryScreen(
                              title: l10n.notificationsSection,
                              child: _buildNotifications(
                                context: context,
                                c: c,
                                cs: cs,
                                l10n: l10n,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // DELIVERY RELIABILITY (2026-07-16, delivery-wake audit):
                    // диагностика системных переключателей, глушащих доставку
                    // (батарея/Data Saver/автозапуск/уведомления). Оранжевый
                    // индикатор — когда что-то реально мешает.
                    if (Platform.isAndroid || Platform.isIOS) ...[
                      const Divider(height: 1),
                      _tile(
                        context: context,
                        icon: Icons.network_check_rounded,
                        fallbackIcon: Icons.network_check_rounded,
                        iconTint: _iconGreen,
                        iconBg: Colors.transparent,
                        // Light-green glyph (raw IconData paints with iconFg,
                        // and onSurface read as white-on-green) — one shade
                        // lighter than the plate tint, matching the colored
                        // icons8 glyphs around it.
                        iconFg: const Color(0xFF7CDCA4),
                        title: wave1Text(
                          context,
                          ru: 'Надёжность',
                          en: 'Reliability',
                          uk: 'Надійність',
                          es: 'Fiabilidad',
                          pt: 'Fiabilidade',
                          ptBr: 'Confiabilidade',
                          fr: 'Fiabilite',
                          de: 'Zuverlaessigkeit',
                        ),
                        trailing: FutureBuilder<DeliveryReliabilityStatus?>(
                          future: DeliveryReliabilityService().getStatus(),
                          builder: (context, snap) {
                            if (snap.data?.hasIssues ?? false) {
                              return const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.orange,
                                size: 20,
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            SecretlyPageRoute(
                              builder: (_) => DeliveryReliabilityScreen(
                                healthLoader:
                                    widget.controller.deliveryHealthCounters,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const Divider(height: 1),
                    _tile(
                      context: context,
                      iconAsset: _iconLanguage,
                      fallbackIcon: AppIcons.language,
                      iconTint: _iconPurple,
                      iconBg: Colors.transparent,
                      iconFg: cs.onSurface,
                      title: l10n.languageSection,
                      onTap: () {
                        Navigator.of(context).push(
                          SecretlyPageRoute(
                            builder: (_) => _SettingsCategoryScreen(
                              title: l10n.languageSection,
                              child: _buildLanguage(
                                context: context,
                                cs: cs,
                                l10n: l10n,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _tile(
                      context: context,
                      iconAsset: _iconDevices,
                      fallbackIcon: AppIcons.devices,
                      iconTint: _iconCyan,
                      iconBg: Colors.transparent,
                      iconFg: cs.onSurface,
                      title: l10n.devicesSection,
                      onTap: () {
                        Navigator.of(context).push(
                          SecretlyPageRoute(
                            builder: (_) => DevicesAuthScreen(controller: c),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _tile(
                      context: context,
                      icon: Icons.bolt_rounded,
                      fallbackIcon: Icons.bolt_rounded,
                      iconTint: _iconAmber,
                      iconBg: Colors.transparent,
                      iconFg: _iconAmber,
                      title: _label(
                        context,
                        ru: 'Энергопотребление',
                        en: 'Power',
                      ),
                      subtitle: _label(
                        context,
                        ru: 'Меньше нагрева и расхода батареи',
                        en: 'Less heat and battery drain',
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          SecretlyPageRoute(
                            builder: (_) => _PowerSettingsScreen(
                              controller: widget.controller,
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _tile(
                      context: context,
                      icon: AppIcons.archive,
                      fallbackIcon: AppIcons.archive,
                      iconTint: _iconBlue,
                      iconBg: Colors.transparent,
                      iconFg: _iconBlue,
                      title: l10n.storageSection,
                      subtitle: l10n.storageSectionSubtitle,
                      onTap: () {
                        Navigator.of(context).push(
                          SecretlyPageRoute(
                            builder: (_) => _StorageSettingsScreen(
                              controller: widget.controller,
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _tile(
                      context: context,
                      iconAsset: _iconSystem,
                      fallbackIcon: AppIcons.settings,
                      iconTint: _iconAmber,
                      iconBg: Colors.transparent,
                      iconFg: cs.onSurface,
                      title: l10n.systemSection,
                      subtitle: (c.startupWarning != null || c.transportBlocked)
                          ? _label(
                              context,
                              ru: 'Есть системное сообщение',
                              en: 'System message available',
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context).push(
                          SecretlyPageRoute(
                            builder: (_) => _SettingsCategoryScreen(
                              title: l10n.systemSection,
                              child: _StreamRebuild(
                                stream: c.changed,
                                builder: (ctx) => _buildSystem(
                                  context: ctx,
                                  c: c,
                                  cs: Theme.of(ctx).colorScheme,
                                  l10n: l10n,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ]),

                  const SizedBox(height: 12),
                  _card([
                    _tile(
                      context: context,
                      iconAsset: _iconInvite,
                      fallbackIcon: AppIcons.send,
                      iconTint: _iconBlue,
                      iconBg: Colors.transparent,
                      iconFg: _iconBlue,
                      title: _label(
                        context,
                        ru: 'Пригласить друзей',
                        en: 'Invite friends',
                      ),
                      onTap: () => _shareInvite(context, c),
                    ),
                    // Apple App Review guideline 3.1.1 (rejection f3cc3e8a-ef24
                    // submission 2026-06-01): in-app donations that grant access
                    // to «digital content or services» must use In-App Purchase
                    // on iOS. Until we ship the IAP rewrite we hide the donor
                    // entry point on iOS entirely; Android keeps Donorbox.
                    if (!Platform.isIOS) ...[
                      const Divider(height: 1),
                      _tile(
                        context: context,
                        iconAsset: _iconDonate,
                        fallbackIcon: AppIcons.favorites,
                        iconTint: _iconRed,
                        iconBg: Colors.transparent,
                        iconFg: _iconRed,
                        title: _label(
                          context,
                          ru: 'Поддержать Secretly',
                          en: 'Donate Secretly',
                        ),
                        onTap: () => _openDonateSection(context),
                      ),
                    ],
                    const Divider(height: 1),
                    _tile(
                      context: context,
                      iconAsset: _iconSupport,
                      fallbackIcon: AppIcons.chatBubble,
                      iconTint: _iconAmber,
                      iconBg: Colors.transparent,
                      iconFg: cs.onSurface,
                      title: _label(context, ru: 'Поддержка', en: 'Support'),
                      // Точка «обращение в работе» либо кружок с числом
                      // непрочитанных ответов — см. SupportBadge.
                      trailing: SupportBadgeListener(controller: c),
                      onTap: () => _openSupportSection(context, c),
                    ),
                    const Divider(height: 1),
                    // 🔴 ДИАГНОСТИКА БЫЛА НЕДОСТУПНА (12.08.2026).
                    //
                    // Экран существует и переводы к нему лежат на девяти языках
                    // (`diagnostics`, `diagnosticsSubtitle`), но открыть его
                    // можно было ТОЛЬКО из истории звонков, нажав на запись
                    // ПРОВАЛИВШЕГОСЯ звонка. То есть чтобы посмотреть состояние
                    // доставки смс, надо было сперва не дозвониться. Владелец
                    // так и сказал: «в приложении диагностики нет».
                    //
                    // `diagnosticsSubtitle` не использовался нигде — строку
                    // задумали и не подключили.
                    // 🔴 СКРЫТ ПО УМОЛЧАНИЮ (16.08.2026). Раздел показывает
                    // profile_id, device_id, адреса серверов, состояние
                    // очередей и флаги раскатки. Человеку это ничего не
                    // говорит, но переслать он это может — и отдаст свои
                    // идентификаторы, не понимая, что отдал.
                    //
                    // Открывается пятью нажатиями по строке версии внизу
                    // экрана, закрывается кнопкой внутри самого раздела.
                    // Путь «плохой звонок → открыть диагностику звонков» из
                    // истории звонков НЕ трогаем: он появляется по месту, по
                    // конкретной неудаче, и служит поддержке.
                    if (_diagnosticsUnlocked) ...[
                      _tile(
                        context: context,
                        iconAsset: _iconInfo,
                        fallbackIcon: Icons.bug_report_outlined,
                        iconTint: _iconBlue,
                        iconBg: Colors.transparent,
                        iconFg: cs.onSurface,
                        title: l10n.diagnostics,
                        subtitle: l10n.diagnosticsSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            SecretlyPageRoute(
                              builder: (_) => DiagnosticsScreen(controller: c),
                            ),
                          );
                          // Внутри могли нажать «Скрыть диагностику».
                          await _loadDiagnosticsUnlocked();
                        },
                      ),
                      const Divider(height: 1),
                    ],
                    _tile(
                      context: context,
                      iconAsset: _iconPolicy,
                      fallbackIcon: AppIcons.shield,
                      iconTint: _iconGreen,
                      iconBg: Colors.transparent,
                      iconFg: cs.onSurface,
                      title: _label(
                        context,
                        ru: 'Политика конфиденциальности',
                        en: 'Privacy policy',
                      ),
                      onTap: () => _openPrivacyPolicySection(context),
                    ),
                    const Divider(height: 1),
                    _tile(
                      context: context,
                      iconAsset: _iconInfo,
                      fallbackIcon: Icons.info_outline,
                      iconTint: _iconPurple,
                      iconBg: Colors.transparent,
                      iconFg: cs.onSurface,
                      title: _label(
                        context,
                        ru: 'о Secretly',
                        en: 'About Secretly',
                      ),
                      onTap: () => _openAboutSection(context, c),
                    ),
                  ]),
                  _buildAppInfoFooter(context: context, cs: cs),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAccount({
    required BuildContext context,
    required AppController c,
    required ColorScheme cs,
    required dynamic l10n,
  }) {
    return Column(
      children: [
        _card([
          _tile(
            context: context,
            iconAsset: _iconAccount,
            iconTint: _iconBlue,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.person_rounded,
            title: _label(context, ru: 'Имя профиля', en: 'Profile name'),
            subtitle: c.myNickname.trim().isEmpty
                ? _label(context, ru: 'Не указано', en: 'Not set')
                : c.myNickname.trim(),
            onTap: () => _editProfileName(context, c),
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconInfo,
            iconTint: _iconCyan,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.notes_rounded,
            title: _label(context, ru: 'О себе', en: 'About'),
            subtitle: c.myBio.trim().isEmpty
                ? _label(context, ru: 'Не добавлено', en: 'Not added')
                : c.myBio.trim(),
            onTap: () async {
              final controller = TextEditingController(text: c.myBio);
              final bio = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(_label(context, ru: 'О себе', en: 'About')),
                  content: TextField(
                    controller: controller,
                    maxLength: 140,
                    maxLines: 3,
                    minLines: 2,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: _label(
                        context,
                        ru: 'Текст о себе',
                        en: 'About text',
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(''),
                      child: Text(_label(context, ru: 'Очистить', en: 'Clear')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(controller.text.trim()),
                      child: Text(_label(context, ru: 'Сохранить', en: 'Save')),
                    ),
                  ],
                ),
              );
              controller.dispose();
              if (bio == null) return;
              await c.setMyBio(bio.trim());
            },
          ),
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconPrivacyVisibility,
            iconTint: _iconBlue,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.qr_code_2_rounded,
            title: l10n.mySecretlyId,
            subtitle:
                '${c.profileId}\n${_label(context, ru: 'Сохраните этот ID: он нужен для восстановления аккаунта и серверной резервной копии.', en: 'Save this ID: it is required to restore your account and server backup.')}',
            onTap: () {
              Navigator.of(context).push(
                SecretlyPageRoute(
                  builder: (_) => MySecretlyIdScreen(controller: c),
                ),
              );
            },
          ),
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconChatsTheme,
            iconTint: _iconCyan,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.cloud_upload_rounded,
            title: l10n.safeBackupTitle,
            // Backup health reads right here, in the row the user already
            // scrolls past — a backup that quietly stopped working is the one
            // that costs a history (2026-07-20).
            subtitle: _safeBackupStatusLine(context, c, l10n.safeBackupSubtitle),
            trailing: c.safeBackupHealth == SafeBackupHealth.ok
                ? null
                : Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: c.safeBackupHealth == SafeBackupHealth.failing
                        ? cs.error
                        : cs.onSurface.withValues(alpha: 0.45),
                  ),
            onTap: () {
              Navigator.of(context).push(
                SecretlyPageRoute(
                  builder: (_) => SafeBackupScreen(controller: c),
                ),
              );
            },
          ),
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconPrivacyStop,
            iconTint: _iconRed,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.logout_rounded,
            leading: _loggingOut
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  )
                : null,
            title: _label(context, ru: 'Выйти из аккаунта', en: 'Log out'),
            subtitle: _label(
              context,
              ru: 'Завершить сессию на этом устройстве',
              en: 'End session on this device',
            ),
            onTap: () async {
              if (_loggingOut) return;
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text(
                      _label(context, ru: 'Выход из аккаунта', en: 'Log out'),
                    ),
                    content: Text(
                      _label(
                        context,
                        ru: 'Выполнить выход с очисткой локального профиля на этом устройстве?',
                        en: 'Log out and clear local profile data on this device?',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          _label(context, ru: 'Выйти', en: 'Log out'),
                        ),
                      ),
                    ],
                  );
                },
              );
              if (ok != true || !context.mounted) return;
              setState(() => _loggingOut = true);
              try {
                await c.resetProfileAndLocalData();
                // `resetProfileAndLocalData()` fires `restartRequested`,
                // which main.dart's `_restart()` handles by rebuilding the
                // root tree — but Settings may be pushed one or more levels
                // deep, so pop back to root now or the rebuilt welcome
                // screen stays hidden underneath the leftover route stack.
                CallManager.navigatorKey.currentState?.popUntil(
                  (route) => route.isFirst,
                );
              } finally {
                if (mounted) setState(() => _loggingOut = false);
              }
            },
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconPrivacyStop,
            iconTint: _iconRed,
            iconBg: Colors.transparent,
            iconFg: cs.error,
            fallbackIcon: Icons.delete_forever_rounded,
            title: _label(context, ru: 'Удалить аккаунт', en: 'Delete account'),
            subtitle: _label(
              context,
              ru: 'Удалить профиль на сервере и данные на устройстве',
              en: 'Delete server profile and local data',
            ),
            onTap: () => _confirmAndDeleteAccount(context, c, l10n),
          ),
        ]),
      ],
    );
  }

  Future<void> _confirmAndDeleteAccount(
    BuildContext context,
    AppController c,
    dynamic l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _label(
              dialogContext,
              ru: 'Удалить аккаунт?',
              en: 'Delete account?',
            ),
          ),
          content: Text(
            _label(
              dialogContext,
              ru: 'Профиль, ключи, резервные копии, очереди сообщений и локальные данные будут удалены. Это действие нельзя отменить.',
              en: 'Your profile, keys, backups, message queues, and local data will be deleted. This cannot be undone.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_label(dialogContext, ru: 'Удалить', en: 'Delete')),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final unlocked = await ensureSecurityScopeUnlocked(
      context: context,
      controller: c,
      scope: SecurityLockScope.app,
      forcePrompt: true,
    );
    if (!unlocked || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _label(
                    dialogContext,
                    ru: 'Удаление аккаунта...',
                    en: 'Deleting account...',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await c.deleteAccountEverywhere();
      // `deleteAccountEverywhere()` fires `restartRequested`, which main.dart's
      // `_restart()` handles by rebuilding the root tree — but Settings may be
      // pushed one or more levels deep, so pop back to root now (dismissing the
      // progress dialog along with it) or the rebuilt welcome screen stays
      // hidden underneath the leftover route stack.
      CallManager.navigatorKey.currentState?.popUntil(
        (route) => route.isFirst,
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            _label(
              context,
              ru: 'Не удалось удалить аккаунт: $error',
              en: 'Could not delete account: $error',
            ),
          ),
        ),
      );
    }
  }

  Widget _buildNotifications({
    required BuildContext context,
    required AppController c,
    required ColorScheme cs,
    required dynamic l10n,
  }) {
    Future<void> setLocalBool(
      String key,
      bool value,
      void Function(bool value) assign,
    ) async {
      setState(() {
        assign(value);
      });
      await _saveBoolSetting(key, value);
    }

    Future<void> setLocalString(
      String key,
      String value,
      void Function(String value) assign,
    ) async {
      setState(() {
        assign(value);
      });
      await _saveStringSetting(key, value);
    }

    Future<void> pickCallVibration() async {
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          final options = <String>['off', 'short', 'long', 'system'];
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in options)
                  ListTile(
                    title: Text(_callVibrationLabel(context, option)),
                    trailing: _notifCallVibration == option
                        ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
              ],
            ),
          );
        },
      );
      if (selected == null) return;
      await setLocalString(
        _prefsNotifCallVibrationKey,
        selected,
        (v) => _notifCallVibration = v,
      );
    }

    Future<void> pickCallRingtone() async {
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          final options = <String>['default', 'beacon', 'chime'];
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in options)
                  ListTile(
                    title: Text(_callRingtoneLabel(context, option)),
                    trailing: _notifCallRingtone == option
                        ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                        : (isCallRingtoneAllowed(
                                _entitlement(widget.controller),
                                option,
                              )
                              ? null
                              : const Icon(
                                  Icons.lock_outline,
                                  size: 18,
                                  color: Color(0xFFD4A11E),
                                )),
                    onTap: () => Navigator.of(context).pop(option),
                  ),
              ],
            ),
          );
        },
      );
      if (selected == null) return;
      // Premium call ringtone while locked → paywall (default tone stays free).
      if (!isCallRingtoneAllowed(_entitlement(widget.controller), selected)) {
        if (!context.mounted) return;
        await showPaywall(context, PaywallTrigger.cosmetic);
        return;
      }
      await setLocalString(
        _prefsNotifCallRingtoneKey,
        selected,
        (v) => _notifCallRingtone = v,
      );
    }

    Future<void> pickIncomingNotifSound() async {
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          final options = <String>[
            'bubble_mail',
            'bubbles_v1',
            'drip_drop',
            'pingo',
            'splash',
            'water_drop_one_plus',
            'xiaomi_notification',
          ];
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in options)
                  ListTile(
                    title: Text(_notifSoundLabel(context, option)),
                    trailing: _notifInAppSoundAsset == option
                        ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                        : (isRingtoneAllowed(
                                _entitlement(widget.controller),
                                option,
                              )
                              ? null
                              : const Icon(
                                  Icons.lock_outline,
                                  size: 18,
                                  color: Color(0xFFD4A11E),
                                )),
                    onTap: () => Navigator.of(context).pop(option),
                  ),
              ],
            ),
          );
        },
      );
      if (selected == null) return;
      // Premium ringtone while locked → paywall instead of applying (free tones
      // stay selectable). Fail-open: isRingtoneAllowed is true when the gate is
      // off / kill-switch disabled.
      if (!isRingtoneAllowed(_entitlement(widget.controller), selected)) {
        if (!context.mounted) return;
        await showPaywall(context, PaywallTrigger.cosmetic);
        return;
      }
      await setLocalString(
        _prefsNotifInAppSoundAssetKey,
        selected,
        (v) => _notifInAppSoundAsset = v,
      );
    }

    Future<void> pickInChatSound() async {
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          final options = <String>[
            'keycap',
            'bubble_mail',
            'bubbles_v1',
            'drip_drop',
            'pingo',
            'splash',
            'water_drop_one_plus',
            'xiaomi_notification',
          ];
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in options)
                  ListTile(
                    title: Text(_notifSoundLabel(context, option)),
                    trailing: _notifInAppChatSoundAsset == option
                        ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
              ],
            ),
          );
        },
      );
      if (selected == null) return;
      await setLocalString(
        _prefsNotifInAppChatSoundAssetKey,
        selected,
        (v) => _notifInAppChatSoundAsset = v,
      );
    }

    Future<void> pickNotifPrivacyLevel() async {
      final selected = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          const options = <int>[0, 1, 2];
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in options)
                  ListTile(
                    title: Text(_notifPrivacyLevelLabel(context, option)),
                    trailing: _notifPrivacyLevel == option
                        ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
              ],
            ),
          );
        },
      );
      if (selected == null) return;
      final showSender = selected >= 1;
      final showText = selected >= 2;
      // Single source of truth: the controller writes BOTH the runtime
      // (`notif_*`) and legacy (`settings_notif_*`) keys for the privacy level
      // and the derived show-sender/show-text booleans, so the notification
      // code (which reads the runtime key first) reflects this change and stays
      // in sync with the in-chat and contact-profile entry points. Writing only
      // the `settings_*` key here used to be silently shadowed by a stale
      // runtime value after the first compat-read migration.
      setState(() {
        _notifPrivacyLevel = selected;
        _notifInAppPreview = showText;
        _notifPrivateShowSender = showSender;
        _notifPrivateShowText = showText;
        _notifGroupsShowSender = showSender;
        _notifGroupsShowText = showText;
      });
      await c.setGlobalNotificationPrivacyLevel(selected);
    }

    Future<void> setAppHaptics(bool value) async {
      setState(() {
        _appHaptics = value;
      });
      await c.setAppHapticsEnabled(value);
    }

    String toggleStateLabel(bool enabled) {
      return _label(
        context,
        ru: enabled ? 'Включены' : 'Отключены',
        en: enabled ? 'Enabled' : 'Disabled',
      );
    }

    Widget buildNotificationDetailTile({
      required String title,
      required String subtitle,
      required bool value,
      required Future<void> Function(bool value) onChanged,
      required bool enabled,
      required IconData fallbackIcon,
      required Color iconTint,
    }) {
      return _tile(
        context: context,
        iconAsset: _iconNotifications,
        iconTint: iconTint,
        iconBg: Colors.transparent,
        iconFg: cs.onSurface,
        fallbackIcon: fallbackIcon,
        title: title,
        subtitle: subtitle,
        trailing: Switch(
          value: value,
          onChanged: enabled ? (v) => onChanged(v) : null,
        ),
        onTap: enabled ? () => onChanged(!value) : null,
      );
    }

    return Column(
      children: [
        _card([
          _tile(
            context: context,
            iconAsset: _iconChatsApproved,
            iconTint: _iconBlue,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.notifications_rounded,
            title: _label(
              context,
              ru: 'Показывать уведомления',
              en: 'Show notifications',
            ),
            subtitle: _label(context, ru: 'Всех аккаунтов', en: 'All accounts'),
            trailing: Switch(
              value: _notifAllAccounts,
              onChanged: (v) => setLocalBool(
                _prefsNotifAllAccountsKey,
                v,
                (x) => _notifAllAccounts = x,
              ),
            ),
            onTap: () => setLocalBool(
              _prefsNotifAllAccountsKey,
              !_notifAllAccounts,
              (x) => _notifAllAccounts = x,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconPrivacyVisibility,
            iconTint: _iconBlue,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.chat_bubble_rounded,
            title: _label(context, ru: 'Личные чаты', en: 'Private chats'),
            subtitle: toggleStateLabel(_notifPrivateChats),
            trailing: Switch(
              value: _notifPrivateChats,
              onChanged: (v) => setLocalBool(
                _prefsNotifPrivateChatsKey,
                v,
                (x) => _notifPrivateChats = x,
              ),
            ),
            onTap: () => setLocalBool(
              _prefsNotifPrivateChatsKey,
              !_notifPrivateChats,
              (x) => _notifPrivateChats = x,
            ),
          ),
          const Divider(height: 1),
          buildNotificationDetailTile(
            title: _label(context, ru: 'Новые сообщения', en: 'New messages'),
            subtitle: _label(
              context,
              ru: 'Оповещать о новых сообщениях в личных чатах.',
              en: 'Notify about new messages in private chats.',
            ),
            value: _notifPrivateMessages,
            onChanged: (v) => setLocalBool(
              _prefsNotifPrivateMessagesKey,
              v,
              (x) => _notifPrivateMessages = x,
            ),
            enabled: _notifPrivateChats,
            fallbackIcon: Icons.mark_chat_unread_rounded,
            iconTint: _iconBlue,
          ),
          const Divider(height: 1),
          buildNotificationDetailTile(
            title: _label(context, ru: 'Текст сообщения', en: 'Message text'),
            subtitle: _label(
              context,
              ru: 'Показывать текст сообщения в уведомлениях личных чатов.',
              en: 'Show message text in private chat notifications.',
            ),
            value: _notifPrivateShowText,
            onChanged: (v) => setLocalBool(
              _prefsNotifPrivateShowTextKey,
              v,
              (x) => _notifPrivateShowText = x,
            ),
            enabled: _notifPrivateChats,
            fallbackIcon: Icons.short_text_rounded,
            iconTint: _iconGreen,
          ),
          const Divider(height: 1),
          buildNotificationDetailTile(
            title: _label(context, ru: 'Имя и фото', en: 'Name and photo'),
            subtitle: _label(
              context,
              ru: 'Показывать имя и фото собеседника в уведомлениях личных чатов.',
              en: 'Show the contact name and photo in private chat notifications.',
            ),
            value: _notifPrivateShowSender,
            onChanged: (v) => setLocalBool(
              _prefsNotifPrivateShowSenderKey,
              v,
              (x) => _notifPrivateShowSender = x,
            ),
            enabled: _notifPrivateChats,
            fallbackIcon: Icons.account_circle_rounded,
            iconTint: _iconAmber,
          ),
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconPrivacyList,
            iconTint: _iconCyan,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.group_rounded,
            title: _label(context, ru: 'Комнаты', en: 'Rooms'),
            subtitle: toggleStateLabel(_notifGroups),
            trailing: Switch(
              value: _notifGroups,
              onChanged: (v) => setLocalBool(
                _prefsNotifGroupsKey,
                v,
                (x) => _notifGroups = x,
              ),
            ),
            onTap: () => setLocalBool(
              _prefsNotifGroupsKey,
              !_notifGroups,
              (x) => _notifGroups = x,
            ),
          ),
          const Divider(height: 1),
          buildNotificationDetailTile(
            title: _label(context, ru: 'Новые сообщения', en: 'New messages'),
            subtitle: _label(
              context,
              ru: 'Оповещать о новых сообщениях в комнатах.',
              en: 'Notify about new messages in rooms.',
            ),
            value: _notifGroupsMessages,
            onChanged: (v) => setLocalBool(
              _prefsNotifGroupsMessagesKey,
              v,
              (x) => _notifGroupsMessages = x,
            ),
            enabled: _notifGroups,
            fallbackIcon: Icons.mark_chat_unread_rounded,
            iconTint: _iconCyan,
          ),
          const Divider(height: 1),
          buildNotificationDetailTile(
            title: _label(context, ru: 'Текст сообщения', en: 'Message text'),
            subtitle: _label(
              context,
              ru: 'Показывать текст сообщения в уведомлениях комнат.',
              en: 'Show message text in room notifications.',
            ),
            value: _notifGroupsShowText,
            onChanged: (v) => setLocalBool(
              _prefsNotifGroupsShowTextKey,
              v,
              (x) => _notifGroupsShowText = x,
            ),
            enabled: _notifGroups,
            fallbackIcon: Icons.short_text_rounded,
            iconTint: _iconGreen,
          ),
          const Divider(height: 1),
          buildNotificationDetailTile(
            title: _label(context, ru: 'Имя и фото', en: 'Name and photo'),
            subtitle: _label(
              context,
              ru: 'Показывать имя и фото отправителя в уведомлениях комнат.',
              en: 'Show the sender name and photo in room notifications.',
            ),
            value: _notifGroupsShowSender,
            onChanged: (v) => setLocalBool(
              _prefsNotifGroupsShowSenderKey,
              v,
              (x) => _notifGroupsShowSender = x,
            ),
            enabled: _notifGroups,
            fallbackIcon: Icons.account_circle_rounded,
            iconTint: _iconAmber,
          ),
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconChatsApproved,
            iconTint: _iconBlue,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.phone_rounded,
            title: _label(
              context,
              ru: 'Звонки в приложении',
              en: 'In-app calls',
            ),
            subtitle: _label(
              context,
              ru: 'Разрешить звонки в приложении',
              en: 'Allow calls in the app',
            ),
            trailing: Switch(
              value: c.callsEnabled,
              onChanged: (v) => c.setCallsEnabled(v),
            ),
            onTap: () => c.setCallsEnabled(!c.callsEnabled),
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconPrivacyVisibility,
            iconTint: _iconCyan,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.call_received_rounded,
            title: _label(context, ru: 'Входящие звонки', en: 'Incoming calls'),
            subtitle: _label(
              context,
              ru: 'Разрешить входящие вызовы',
              en: 'Allow incoming calls',
            ),
            trailing: Switch(
              value: c.incomingCallsEnabled,
              onChanged: c.callsEnabled
                  ? (v) => c.setIncomingCallsEnabled(v)
                  : null,
            ),
            onTap: c.callsEnabled
                ? () => c.setIncomingCallsEnabled(!c.incomingCallsEnabled)
                : null,
          ),
          if (Platform.isAndroid) ...[
            const Divider(height: 1),
            _tile(
              context: context,
              iconAsset: _iconNotifications,
              iconTint: _androidFullScreenIntentGranted
                  ? _iconGreen
                  : _iconAmber,
              iconBg: Colors.transparent,
              iconFg: cs.onSurface,
              fallbackIcon: _androidFullScreenIntentGranted
                  ? Icons.call_rounded
                  : Icons.phone_locked_rounded,
              title: _label(
                context,
                ru: 'Экран звонка при блокировке',
                en: 'Lock-screen call screen',
              ),
              subtitle: _androidFullScreenIntentChecked
                  ? (_androidFullScreenIntentGranted
                        ? _label(
                            context,
                            ru: 'Системное разрешение включено',
                            en: 'System permission enabled',
                          )
                        : _label(
                            context,
                            ru: 'Включите, чтобы звонок открывался поверх заблокированного экрана',
                            en: 'Enable this so calls can open over the lock screen',
                          ))
                  : _label(
                      context,
                      ru: 'Проверяем разрешение...',
                      en: 'Checking permission...',
                    ),
              trailing: Icon(
                _androidFullScreenIntentGranted
                    ? AppIcons.checkCircleSolid
                    : Icons.open_in_new_rounded,
                color: _androidFullScreenIntentGranted
                    ? _iconGreen
                    : _iconAmber,
              ),
              onTap: _openAndroidFullScreenIntentPermission,
            ),
          ],
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconPrivacyList,
            iconTint: _iconPurple,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.screen_share_rounded,
            title: _label(
              context,
              ru: 'Демонстрация экрана',
              en: 'Screen sharing',
            ),
            subtitle: _label(
              context,
              ru: 'Разрешить входящие звонки с шарингом экрана',
              en: 'Allow incoming screen-sharing calls',
            ),
            trailing: Switch(
              value: c.incomingScreenShareEnabled,
              onChanged: c.callsEnabled
                  ? (v) => c.setIncomingScreenShareEnabled(v)
                  : null,
            ),
            onTap: c.callsEnabled
                ? () => c.setIncomingScreenShareEnabled(
                    !c.incomingScreenShareEnabled,
                  )
                : null,
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconNotifications,
            iconTint: _iconAmber,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.vibration_rounded,
            title: _label(context, ru: 'Вибросигнал', en: 'Vibration'),
            subtitle: _callVibrationLabel(context, _notifCallVibration),
            onTap: pickCallVibration,
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconNotifications,
            iconTint: _iconGreen,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.music_note_rounded,
            title: _label(context, ru: 'Рингтон', en: 'Ringtone'),
            subtitle: _callRingtoneLabel(context, _notifCallRingtone),
            onTap: pickCallRingtone,
          ),
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconChatsApproved,
            iconTint: _iconGreen,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.volume_up_rounded,
            title: _label(context, ru: 'Звук', en: 'Sound'),
            trailing: Switch(
              value: _notifInAppSound,
              onChanged: (v) => setLocalBool(
                _prefsNotifInAppSoundKey,
                v,
                (x) => _notifInAppSound = x,
              ),
            ),
            onTap: () => setLocalBool(
              _prefsNotifInAppSoundKey,
              !_notifInAppSound,
              (x) => _notifInAppSound = x,
            ),
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconNotifications,
            iconTint: _iconBlue,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.queue_music_rounded,
            title: _label(context, ru: 'Звук входящих', en: 'Incoming sound'),
            subtitle: _notifSoundLabel(context, _notifInAppSoundAsset),
            onTap: pickIncomingNotifSound,
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconNotifications,
            iconTint: _iconGreen,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.chat_bubble_outline_rounded,
            title: _label(context, ru: 'Звук в чате', en: 'In-chat sound'),
            trailing: Switch(
              value: _notifInAppChatSound,
              onChanged: (v) => setLocalBool(
                _prefsNotifInAppChatSoundKey,
                v,
                (x) => _notifInAppChatSound = x,
              ),
            ),
            onTap: () => setLocalBool(
              _prefsNotifInAppChatSoundKey,
              !_notifInAppChatSound,
              (x) => _notifInAppChatSound = x,
            ),
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconNotifications,
            iconTint: _iconCyan,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.queue_music_rounded,
            title: _label(
              context,
              ru: 'Звук в чате (тип)',
              en: 'In-chat sound style',
            ),
            subtitle: _notifSoundLabel(context, _notifInAppChatSoundAsset),
            onTap: _notifInAppChatSound ? pickInChatSound : null,
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconNotifications,
            iconTint: _iconAmber,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.vibration_rounded,
            title: _label(context, ru: 'Вибросигнал', en: 'Vibration'),
            trailing: Switch(
              value: _notifInAppVibrate,
              onChanged: (v) => setLocalBool(
                _prefsNotifInAppVibrateKey,
                v,
                (x) => _notifInAppVibrate = x,
              ),
            ),
            onTap: () => setLocalBool(
              _prefsNotifInAppVibrateKey,
              !_notifInAppVibrate,
              (x) => _notifInAppVibrate = x,
            ),
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconNotifications,
            iconTint: _iconPurple,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.touch_app_rounded,
            title: _label(context, ru: 'Тактильный отклик', en: 'Haptics'),
            subtitle: _label(
              context,
              ru: 'Вибрация при раскрытии категорий, фото и других действиях в приложении.',
              en: 'Vibration for expanding categories, photos, and other in-app actions.',
            ),
            trailing: Switch(
              value: _appHaptics,
              onChanged: (v) => setAppHaptics(v),
            ),
            onTap: () => setAppHaptics(!_appHaptics),
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconChatsTheme,
            iconTint: _iconBlue,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.security_rounded,
            title: _label(
              context,
              ru: 'Приватность уведомлений',
              en: 'Notification privacy',
            ),
            subtitle: _notifPrivacyLevelLabel(context, _notifPrivacyLevel),
            onTap: pickNotifPrivacyLevel,
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconPrivacyVisibility,
            iconTint: _iconCyan,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.notification_important_rounded,
            title: _label(
              context,
              ru: 'Карточка уведомления',
              en: 'Notification card',
            ),
            subtitle: _label(
              context,
              ru: 'Показывать системную карточку, когда приложение в фоне.',
              en: 'Show the system notification card while the app is in background.',
            ),
            trailing: Switch(
              value: _notifBackgroundCard,
              onChanged: (v) => setLocalBool(
                _prefsNotifBackgroundCardKey,
                v,
                (x) => _notifBackgroundCard = x,
              ),
            ),
            onTap: () => setLocalBool(
              _prefsNotifBackgroundCardKey,
              !_notifBackgroundCard,
              (x) => _notifBackgroundCard = x,
            ),
          ),
        ]),
        _card([
          _tile(
            context: context,
            iconAsset: _iconDevices,
            iconTint: _iconBlue,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.sync_rounded,
            title: _label(
              context,
              ru: 'Фоновое соединение',
              en: 'Background connection',
            ),
            subtitle: _label(
              context,
              ru: 'Поддерживать минимальное соединение, пока приложение остаётся в памяти. При полном закрытии работают только push-уведомления.',
              en: 'Keep a minimal connection while the app stays in memory. When the app is fully closed, delivery relies on push notifications.',
            ),
            trailing: Switch(
              value: _notifBackgroundConnection,
              onChanged: (v) => setLocalBool(
                _prefsNotifBackgroundConnectionKey,
                v,
                (x) => _notifBackgroundConnection = x,
              ),
            ),
            onTap: () => setLocalBool(
              _prefsNotifBackgroundConnectionKey,
              !_notifBackgroundConnection,
              (x) => _notifBackgroundConnection = x,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconPrivacyStop,
            iconTint: _iconRed,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.restore_rounded,
            title: _label(
              context,
              ru: 'Сбросить настройки уведомлений',
              en: 'Reset notification settings',
            ),
            subtitle: _label(
              context,
              ru: 'Сбросить особые настройки уведомлений.',
              en: 'Reset custom notification preferences.',
            ),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    _label(context, ru: 'Сброс настроек', en: 'Reset settings'),
                  ),
                  content: Text(
                    _label(
                      context,
                      ru: 'Сбросить настройки уведомлений к значениям по умолчанию?',
                      en: 'Reset notification settings to defaults?',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(_label(context, ru: 'Сбросить', en: 'Reset')),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              setState(() {
                _notifAllAccounts = true;
                _notifPrivateChats = true;
                _notifGroups = true;
                _notifPrivateMessages = true;
                _notifPrivateShowText = false;
                _notifPrivateShowSender = true;
                _notifGroupsMessages = true;
                _notifGroupsShowText = false;
                _notifGroupsShowSender = true;
                _notifInAppSound = true;
                _notifInAppVibrate = true;
                _notifInAppPreview = true;
                _notifPrivacyLevel = 1;
                _notifInAppChatSound = true;
                _notifInAppSoundAsset = 'bubble_mail';
                _notifInAppChatSoundAsset = 'keycap';
                _notifBackgroundCard = true;
                _notifBackgroundConnection = true;
                _notifCallVibration = 'off';
                _notifCallRingtone = 'default';
                _appHaptics = true;
              });
              await Future.wait(<Future<void>>[
                _saveBoolSetting(_prefsNotifAllAccountsKey, _notifAllAccounts),
                _saveBoolSetting(
                  _prefsNotifPrivateChatsKey,
                  _notifPrivateChats,
                ),
                _saveBoolSetting(_prefsNotifGroupsKey, _notifGroups),
                _saveBoolSetting(
                  _prefsNotifPrivateMessagesKey,
                  _notifPrivateMessages,
                ),
                _saveBoolSetting(
                  _prefsNotifPrivateShowTextKey,
                  _notifPrivateShowText,
                ),
                _saveBoolSetting(
                  _prefsNotifPrivateShowSenderKey,
                  _notifPrivateShowSender,
                ),
                _saveBoolSetting(
                  _prefsNotifGroupsMessagesKey,
                  _notifGroupsMessages,
                ),
                _saveBoolSetting(
                  _prefsNotifGroupsShowTextKey,
                  _notifGroupsShowText,
                ),
                _saveBoolSetting(
                  _prefsNotifGroupsShowSenderKey,
                  _notifGroupsShowSender,
                ),
                _saveBoolSetting(_prefsNotifInAppSoundKey, _notifInAppSound),
                _saveBoolSetting(
                  _prefsNotifInAppVibrateKey,
                  _notifInAppVibrate,
                ),
                _saveBoolSetting(
                  _prefsNotifInAppPreviewKey,
                  _notifInAppPreview,
                ),
                _saveIntSetting(_prefsNotifPrivacyLevelKey, _notifPrivacyLevel),
                _saveBoolSetting(
                  _prefsNotifInAppChatSoundKey,
                  _notifInAppChatSound,
                ),
                _saveStringSetting(
                  _prefsNotifInAppSoundAssetKey,
                  _notifInAppSoundAsset,
                ),
                _saveStringSetting(
                  _prefsNotifInAppChatSoundAssetKey,
                  _notifInAppChatSoundAsset,
                ),
                _saveBoolSetting(
                  _prefsNotifBackgroundCardKey,
                  _notifBackgroundCard,
                ),
                _saveBoolSetting(
                  _prefsNotifBackgroundConnectionKey,
                  _notifBackgroundConnection,
                ),
                _saveStringSetting(
                  _prefsNotifCallVibrationKey,
                  _notifCallVibration,
                ),
                _saveStringSetting(
                  _prefsNotifCallRingtoneKey,
                  _notifCallRingtone,
                ),
                // Reset the privacy level through the single writer so the
                // runtime key is cleared too (not just the `settings_*` mirror),
                // otherwise a stale runtime value would shadow the reset.
                c.setGlobalNotificationPrivacyLevel(_notifPrivacyLevel),
                c.setAppHapticsEnabled(_appHaptics),
              ]);
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildLanguage({
    required BuildContext context,
    required ColorScheme cs,
    required dynamic l10n,
  }) {
    final selectedLocale = widget.controller.appLocalePreference;
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;

    String localePreference(Locale locale) {
      final languageCode = locale.languageCode.toLowerCase();
      final countryCode = locale.countryCode?.toUpperCase();
      if (languageCode == 'pt' && countryCode == 'BR') {
        return 'pt_BR';
      }
      return languageCode;
    }

    String normalizeLanguagePreference(String code) {
      final normalized = code.trim().replaceAll('-', '_').toLowerCase();
      if (normalized == 'pt_br') return 'pt_BR';
      return normalized.split('_').first;
    }

    String languageName(String code) {
      switch (normalizeLanguagePreference(code)) {
        case 'de':
          return 'Deutsch';
        case 'es':
          return 'Español';
        case 'fr':
          return 'Français';
        case 'pt':
          return 'Português';
        case 'pt_BR':
          return 'Português (Brasil)';
        case 'ru':
          return 'Русский';
        case 'uk':
          return 'Українська';
        case 'en':
        default:
          return 'English';
      }
    }

    Color languageTint(String preference) {
      switch (normalizeLanguagePreference(preference)) {
        case 'ru':
          return _iconCyan;
        case 'uk':
          return _iconBlue;
        case 'es':
          return _iconOrange;
        case 'pt':
        case 'pt_BR':
          return _iconGreen;
        case 'fr':
          return _iconPurple;
        case 'de':
          return _iconAmber;
        case 'en':
        default:
          return _iconBlue;
      }
    }

    String languageFlag(String preference) {
      switch (normalizeLanguagePreference(preference)) {
        case 'ru':
          return '🇷🇺';
        case 'uk':
          return '🇺🇦';
        case 'es':
          return '🇪🇸';
        case 'pt':
          return '🇵🇹';
        case 'pt_BR':
          return '🇧🇷';
        case 'fr':
          return '🇫🇷';
        case 'de':
          return '🇩🇪';
        case 'en':
        default:
          return '🇬🇧';
      }
    }

    Widget languageFlagLeading(String preference) {
      final tint = languageTint(preference);
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.withValues(alpha: 0.12),
              border: Border.all(color: tint.withValues(alpha: 0.24)),
            ),
            child: Text(
              languageFlag(preference),
              style: const TextStyle(fontSize: 22, height: 1),
            ),
          ),
        ),
      );
    }

    Future<void> selectLocale(String preference) async {
      await widget.controller.setAppLocalePreference(preference);
      if (!mounted) return;
      setState(() {});
    }

    final systemPreference = localePreference(systemLocale);
    final current = selectedLocale.isEmpty
        ? l10n.languageSystemCurrent(languageName(systemPreference))
        : languageName(selectedLocale);
    const localeOptions = <String>['en', 'ru', 'uk', 'es', 'pt_BR', 'fr', 'de'];

    // ── Translator direction (ML Kit on-device). BCP-47 codes. Broader than the
    // UI languages so foreign messages can be translated. [code, name, flag].
    const translateLangs = <List<String>>[
      ['en', 'English', '🇬🇧'],
      ['ru', 'Русский', '🇷🇺'],
      ['uk', 'Українська', '🇺🇦'],
      ['es', 'Español', '🇪🇸'],
      ['pt', 'Português', '🇵🇹'],
      ['fr', 'Français', '🇫🇷'],
      ['de', 'Deutsch', '🇩🇪'],
      ['it', 'Italiano', '🇮🇹'],
      ['pl', 'Polski', '🇵🇱'],
      ['tr', 'Türkçe', '🇹🇷'],
      ['nl', 'Nederlands', '🇳🇱'],
      ['zh', '中文', '🇨🇳'],
      ['ja', '日本語', '🇯🇵'],
      ['ko', '한국어', '🇰🇷'],
      ['ar', 'العربية', '🇸🇦'],
      ['hi', 'हिन्दी', '🇮🇳'],
    ];
    String translateLangLabel(String code) {
      for (final l in translateLangs) {
        if (l[0] == code) return '${l[2]}  ${l[1]}';
      }
      return code;
    }

    final autoLabel = wave1Text(
      context,
      ru: 'Определять автоматически',
      en: 'Detect automatically',
      uk: 'Визначати автоматично',
      es: 'Detectar automáticamente',
      pt: 'Detetar automaticamente',
      ptBr: 'Detectar automaticamente',
      fr: 'Détecter automatiquement',
      de: 'Automatisch erkennen',
    );
    final appLangTargetLabel = wave1Text(
      context,
      ru: 'Язык приложения',
      en: 'App language',
      uk: 'Мова застосунку',
      es: 'Idioma de la aplicación',
      pt: 'Idioma da aplicação',
      ptBr: 'Idioma do aplicativo',
      fr: "Langue de l'application",
      de: 'App-Sprache',
    );

    Future<void> pickTranslateLang({required bool isSource}) async {
      final current = isSource ? _translateSourceLang : _translateTargetLang;
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetCtx) {
          // Source: 'auto' default; Target: '' default (app language).
          final defaultValue = isSource ? 'auto' : '';
          final defaultLabel = isSource ? autoLabel : appLangTargetLabel;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Text(
                        isSource ? '🌐' : '📱',
                        style: const TextStyle(fontSize: 22),
                      ),
                      title: Text(defaultLabel),
                      trailing: current == defaultValue
                          ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                          : null,
                      onTap: () => Navigator.of(sheetCtx).pop(defaultValue),
                    ),
                    const Divider(height: 1),
                    for (final l in translateLangs)
                      ListTile(
                        leading: Text(
                          l[2],
                          style: const TextStyle(fontSize: 22),
                        ),
                        title: Text(l[1]),
                        trailing: current == l[0]
                            ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                            : null,
                        onTap: () => Navigator.of(sheetCtx).pop(l[0]),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (selected == null) return;
      setState(() {
        if (isSource) {
          _translateSourceLang = selected;
        } else {
          _translateTargetLang = selected;
        }
      });
      await _saveStringSetting(
        isSource
            ? _prefsLanguageTranslateSourceKey
            : _prefsLanguageTranslateTargetKey,
        selected,
      );
    }

    return Column(
      children: [
        _card([
          _tile(
            context: context,
            iconAsset: _iconChatsTheme,
            iconTint: _iconBlue,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.translate_rounded,
            title: l10n.languageMessageTranslation,
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconPrivacyVisibility,
            iconTint: _iconCyan,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.touch_app_rounded,
            title: l10n.languageShowTranslateButton,
            trailing: Switch(
              value: _languageShowTranslateButton,
              onChanged: (v) async {
                setState(() {
                  _languageShowTranslateButton = v;
                });
                await _saveBoolSetting(_prefsLanguageShowTranslateButtonKey, v);
              },
            ),
            onTap: () async {
              final next = !_languageShowTranslateButton;
              setState(() {
                _languageShowTranslateButton = next;
              });
              await _saveBoolSetting(
                _prefsLanguageShowTranslateButtonKey,
                next,
              );
            },
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconPrivacyList,
            iconTint: _iconPurple,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.g_translate,
            title: l10n.languageTranslateWholeChats,
            trailing: Switch(
              value: _languageTranslateWholeChat,
              onChanged: _languageShowTranslateButton
                  ? (v) async {
                      setState(() {
                        _languageTranslateWholeChat = v;
                      });
                      await _saveBoolSetting(
                        _prefsLanguageTranslateWholeChatKey,
                        v,
                      );
                    }
                  : null,
            ),
            onTap: _languageShowTranslateButton
                ? () async {
                    final next = !_languageTranslateWholeChat;
                    setState(() {
                      _languageTranslateWholeChat = next;
                    });
                    await _saveBoolSetting(
                      _prefsLanguageTranslateWholeChatKey,
                      next,
                    );
                  }
                : null,
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconLanguage,
            iconTint: _iconAmber,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.translate_rounded,
            title: wave1Text(
              context,
              ru: 'Переводить с языка',
              en: 'Translate from',
              uk: 'Перекладати з мови',
              es: 'Traducir desde',
              pt: 'Traduzir de',
              ptBr: 'Traduzir de',
              fr: 'Traduire depuis',
              de: 'Übersetzen aus',
            ),
            subtitle: _translateSourceLang == 'auto'
                ? autoLabel
                : translateLangLabel(_translateSourceLang),
            onTap: () => pickTranslateLang(isSource: true),
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconLanguage,
            iconTint: _iconGreen,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.g_translate,
            title: wave1Text(
              context,
              ru: 'Переводить на язык',
              en: 'Translate to',
              uk: 'Перекладати на мову',
              es: 'Traducir a',
              pt: 'Traduzir para',
              ptBr: 'Traduzir para',
              fr: 'Traduire vers',
              de: 'Übersetzen nach',
            ),
            subtitle: _translateTargetLang.isEmpty
                ? appLangTargetLabel
                : translateLangLabel(_translateTargetLang),
            onTap: () => pickTranslateLang(isSource: false),
          ),
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconLanguage,
            iconTint: _iconBlue,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.language_rounded,
            title: l10n.languageSection,
            subtitle: current,
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            leading: languageFlagLeading(systemPreference),
            iconAsset: _iconChatsApproved,
            iconTint: _iconGreen,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.flag_rounded,
            title: l10n.languageSystemDefault,
            subtitle: languageName(systemPreference),
            trailing: Icon(
              selectedLocale.isEmpty
                  ? AppIcons.radioChecked
                  : AppIcons.radioUnchecked,
              color: cs.primary,
            ),
            onTap: () => selectLocale('system'),
          ),
          for (final preference in localeOptions) ...[
            const Divider(height: 1),
            _tile(
              context: context,
              leading: languageFlagLeading(preference),
              iconAsset: _iconChatsApproved,
              iconTint: languageTint(preference),
              iconBg: Colors.transparent,
              iconFg: cs.onSurface,
              fallbackIcon: Icons.public_rounded,
              title: languageName(preference),
              trailing: Icon(
                selectedLocale == preference
                    ? AppIcons.radioChecked
                    : AppIcons.radioUnchecked,
                color: cs.primary,
              ),
              onTap: () => selectLocale(preference),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconPrivacyVisibility,
            iconTint: _iconPurple,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.info_rounded,
            title: l10n.languageChooseAppLanguage,
            subtitle: l10n.languageAvailableWave1,
          ),
        ]),
      ],
    );
  }

  Widget _buildChatsLivePreview({
    required BuildContext context,
    required AppController c,
  }) {
    final cs = Theme.of(context).colorScheme;
    final bubblePreset = resolveChatBubbleStylePreset(
      c.chatBubbleStylePresetId,
    );
    final nicknamePreset = resolveNicknameStylePreset(c.nicknameStylePresetId);
    final themePreset = resolveAppThemePreset(c.appThemePresetId);
    final darkMode = c.darkMode;
    final topBarTop = resolveThemeTopBarTop(
      darkMode: darkMode,
      themePreset: themePreset,
      colorScheme: cs,
    );
    final topBarBottom = resolveThemeTopBarBottom(
      darkMode: darkMode,
      themePreset: themePreset,
      colorScheme: cs,
    );
    final topBarBorder = resolveThemeTopBarBorder(
      darkMode: darkMode,
      themePreset: themePreset,
      colorScheme: cs,
    );
    final effectiveWallpaperId = resolveEffectiveChatWallpaperId(
      selectionId: c.defaultChatWallpaperId,
      defaultId: 'default',
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 308,
        child: Stack(
          children: [
            Positioned.fill(
              child: buildChatWallpaperBackground(
                context,
                effectiveWallpaperId,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: darkMode ? 0.18 : 0.04),
                      Colors.transparent,
                      Colors.black.withValues(alpha: darkMode ? 0.16 : 0.06),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      topBarTop.withValues(alpha: 0.92),
                      topBarBottom.withValues(alpha: 0.88),
                    ],
                  ),
                  border: topBarBorder.a <= 0
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: topBarBorder.withValues(alpha: 0.52),
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: cs.primaryContainer,
                      child: Icon(
                        AppIcons.personSolid,
                        size: 12,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _label(
                          context,
                          ru: 'Рабочая группа • онлайн',
                          en: 'Work group • online',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      AppIcons.more,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.82),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              top: 48,
              bottom: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPreviewBubble(
                        context,
                        outgoing: false,
                        nickname: _label(context, ru: 'Мира', en: 'Mira'),
                        text: _label(
                          context,
                          ru: 'Переслано от\nSMS: Курьер\nДоставка на 19:30, код 4821.',
                          en: 'Forwarded from\nSMS: Courier\nDelivery at 7:30 PM, code 4821.',
                        ),
                        bubblePreset: bubblePreset,
                        nicknamePreset: nicknamePreset,
                        darkMode: darkMode,
                      ),
                      const SizedBox(height: 8),
                      _buildPreviewBubble(
                        context,
                        outgoing: true,
                        nickname: _label(context, ru: 'Вы', en: 'You'),
                        text: _label(
                          context,
                          ru: 'Принято. Ответил команде.',
                          en: 'Done. Updated the team.',
                        ),
                        replyAuthor: _label(context, ru: 'Мира', en: 'Mira'),
                        replyPreview: _label(
                          context,
                          ru: 'Переслано от • SMS: Курьер',
                          en: 'Forwarded from • SMS: Courier',
                        ),
                        bubblePreset: bubblePreset,
                        nicknamePreset: nicknamePreset,
                        darkMode: darkMode,
                      ),
                      const SizedBox(height: 8),
                      _buildPreviewBubble(
                        context,
                        outgoing: false,
                        nickname: _label(context, ru: 'Служба', en: 'Service'),
                        text: _label(
                          context,
                          ru: 'Ок. Добавлю напоминание при необходимости.',
                          en: 'Okay. I can add a reminder if needed.',
                        ),
                        bubblePreset: bubblePreset,
                        nicknamePreset: nicknamePreset,
                        darkMode: darkMode,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewBubble(
    BuildContext context, {
    required bool outgoing,
    required String nickname,
    required String text,
    String? replyAuthor,
    String? replyPreview,
    required ChatBubbleStylePreset bubblePreset,
    required NicknameStylePreset nicknamePreset,
    required bool darkMode,
  }) {
    final cs = Theme.of(context).colorScheme;
    final bubbleGradient = outgoing
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: darkMode
                ? (bubblePreset.darkMid != null
                      ? [
                          bubblePreset.darkTop,
                          bubblePreset.darkMid!,
                          bubblePreset.darkBottom,
                        ]
                      : [bubblePreset.darkTop, bubblePreset.darkBottom])
                : (bubblePreset.lightMid != null
                      ? [
                          bubblePreset.lightTop,
                          bubblePreset.lightMid!,
                          bubblePreset.lightBottom,
                        ]
                      : [bubblePreset.lightTop, bubblePreset.lightBottom]),
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surface.withValues(alpha: 0.82),
              cs.surfaceContainerHighest.withValues(alpha: 0.72),
            ],
          );

    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: bubbleGradient,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(outgoing ? 14 : 6),
              bottomRight: Radius.circular(outgoing ? 6 : 14),
            ),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.34),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: outgoing
                        ? nicknamePreset.outgoing
                        : nicknamePreset.incoming,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (replyAuthor != null && replyPreview != null) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: outgoing
                          ? Colors.white.withValues(alpha: 0.12)
                          : cs.primaryContainer.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 28,
                          decoration: BoxDecoration(
                            color: outgoing
                                ? nicknamePreset.incoming
                                : nicknamePreset.outgoing,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                replyAuthor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: outgoing
                                          ? nicknamePreset.incoming
                                          : nicknamePreset.outgoing,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              Text(
                                replyPreview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color:
                                          (outgoing
                                                  ? Colors.white
                                                  : cs.onSurface)
                                              .withValues(alpha: 0.9),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.3,
                    color: outgoing ? Colors.white : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Current resolved entitlement (fail-open default until the R1 bootstrap
  /// has populated it).
  EntitlementState _entitlement(AppController c) =>
      c.entitlements?.value ?? EntitlementState.open;

  /// True when [id] of [kind] is premium and the current state can't use it.
  bool _cosmeticLocked(AppController c, CosmeticKind kind, String id) =>
      !isCosmeticAllowed(_entitlement(c), kind, id);

  /// Apply a cosmetic selection, or open the paywall if it is premium-locked.
  Future<void> _onCosmeticTap(
    BuildContext context,
    AppController c, {
    required CosmeticKind kind,
    required String id,
    required Future<void> Function() apply,
  }) async {
    if (_cosmeticLocked(c, kind, id)) {
      await showPaywall(context, PaywallTrigger.cosmetic);
      return;
    }
    await apply();
  }

  Widget _buildCarouselCard({
    required BuildContext context,
    required bool selected,
    required String title,
    required Widget preview,
    required VoidCallback onTap,
    double width = 74,
    bool showTitle = true,
    bool locked = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? cs.primary
                        : cs.outlineVariant.withValues(alpha: 0.55),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Premium items render slightly dimmed behind a lock badge
                      // (showcase rule: visible to all, tap opens paywall).
                      locked ? Opacity(opacity: 0.45, child: preview) : preview,
                      if (locked)
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (!showTitle && selected && !locked)
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Icon(
                            AppIcons.checkCircleSolid,
                            size: 16,
                            color: cs.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (showTitle) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (selected)
                    Icon(
                      AppIcons.checkCircleSolid,
                      size: 15,
                      color: cs.primary,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChats({
    required BuildContext context,
    required AppController c,
    required ColorScheme cs,
    required dynamic l10n,
  }) {
    final effectiveDefaultWallpaperId = resolveEffectiveChatWallpaperId(
      selectionId: c.defaultChatWallpaperId,
      defaultId: 'default',
    );
    final wallpaperOptions = buildChatWallpaperOptions(
      context,
      assetPaths: _bundledWallpaperPaths,
      filePaths: c.profileBackgroundPaths,
      serverWallpapers: _serverWallpapers,
      includeGlobalOption: false,
    );
    final appThemePreset = resolveAppThemePreset(c.appThemePresetId);
    final appThemePresetName = settingsScreenPresetName(
      context,
      id: appThemePreset.id,
      ru: appThemePreset.nameRu,
      en: appThemePreset.nameEn,
    );
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    Widget placeholderCard(Widget child) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: isLightTheme ? 0 : 1,
          color: isLightTheme
              ? cs.surfaceContainerLow.withValues(alpha: 0.92)
              : cs.surfaceContainerHigh.withValues(alpha: 0.76),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isLightTheme
                  ? cs.outlineVariant.withValues(alpha: 0.55)
                  : cs.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: child,
        ),
      );
    }

    return Column(
      children: [
        placeholderCard(
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: _buildChatsLivePreview(context: context, c: c),
          ),
        ),
        // Liquid glass is iOS-only, so the row simply does not exist elsewhere
        // rather than sitting there disabled. Listens to the notifier so the
        // switch reflects the live value even when something else changed it.
        if (kLiquidGlassNavBar && Platform.isIOS) ...[
          const SizedBox(height: 10),
          placeholderCard(
            ValueListenableBuilder<bool>(
              valueListenable: GlassPrefs.enabled,
              builder: (context, glassOn, _) => SwitchListTile.adaptive(
                value: glassOn,
                onChanged: (v) {
                  Haptics.tap();
                  GlassPrefs.setEnabled(v);
                },
                title: Text(l10n.liquidGlassTitle),
                subtitle: Text(
                  l10n.liquidGlassSubtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        placeholderCard(
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _svgLeading(
                      _iconChatsWallpaper,
                      _iconOrange,
                      fallbackIcon: AppIcons.wallpaper,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _label(
                          context,
                          ru: 'Фоны чатов',
                          en: 'Chat wallpapers',
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _label(
                        context,
                        ru: 'Открыть расширенный выбор',
                        en: 'Open extended picker',
                      ),
                      onPressed: () => _showDefaultWallpaperPicker(context, c),
                      icon: const Icon(AppIcons.more),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 126,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: wallpaperOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final option = wallpaperOptions[index];
                      return _buildCarouselCard(
                        context: context,
                        selected: option.id == effectiveDefaultWallpaperId,
                        title: option.title,
                        showTitle: false,
                        locked: _cosmeticLocked(
                          c,
                          CosmeticKind.wallpaper,
                          option.id,
                        ),
                        onTap: () async {
                          if (!isValidChatWallpaperId(option.id) ||
                              option.id == kGlobalChatWallpaperSelectionId) {
                            return;
                          }
                          // Dynamic (`anim:`) wallpaper → open the animation
                          // settings sheet FIRST, exactly like the expanded
                          // picker's onAnimatedUnlockedTap, instead of applying it
                          // silently. Only when unlocked; a locked one falls
                          // through to `_onCosmeticTap`'s paywall unchanged.
                          if (isAnimatedChatWallpaperId(option.id) &&
                              !_cosmeticLocked(
                                c,
                                CosmeticKind.wallpaper,
                                option.id,
                              )) {
                            final style = decodeAnimatedChatWallpaperStyle(
                              option.id,
                            );
                            if (style != null) {
                              final choice =
                                  await showAnimatedWallpaperPreview(
                                context,
                                style: style,
                                initialMode: c.chatWallpaperAnimMode,
                                initialConduct: c.chatWallpaperConduct,
                              );
                              if (choice == null) return;
                              await c.setChatWallpaperAnimMode(choice.mode);
                              await c.setChatWallpaperConduct(choice.conduct);
                            }
                          }
                          if (!context.mounted) return;
                          await _onCosmeticTap(
                            context,
                            c,
                            kind: CosmeticKind.wallpaper,
                            id: option.id,
                            apply: () => c.setDefaultChatWallpaperId(option.id),
                          );
                        },
                        preview: Stack(
                          fit: StackFit.expand,
                          children: [
                            buildChatWallpaperBackground(context, option.id, preview: true),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.08),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.14),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        width: 69,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _svgLeading(
                      _iconChatsTheme,
                      _iconBlue,
                      fallbackIcon: AppIcons.themeLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _label(
                          context,
                          ru: 'Темы приложения',
                          en: 'Application themes',
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _label(
                        context,
                        ru: 'Открыть расширенный выбор',
                        en: 'Open extended picker',
                      ),
                      onPressed: () => _showAppThemePicker(context, c),
                      icon: const Icon(AppIcons.more),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 126,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kAppThemePresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final preset = kAppThemePresets[index];
                      return _buildCarouselCard(
                        context: context,
                        selected: preset.id == c.appThemePresetId,
                        locked: _cosmeticLocked(
                          c,
                          CosmeticKind.theme,
                          preset.id,
                        ),
                        title: settingsScreenPresetName(
                          context,
                          id: preset.id,
                          ru: preset.nameRu,
                          en: preset.nameEn,
                        ),
                        onTap: () => _onCosmeticTap(
                          context,
                          c,
                          kind: CosmeticKind.theme,
                          id: preset.id,
                          apply: () => c.setAppThemePresetId(preset.id),
                        ),
                        preview: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [preset.darkBgTop, preset.darkBgBottom],
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 11,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: preset.darkPrimary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Container(
                                    width: 11,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: preset.darkSecondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _iconPurple.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.apps_rounded,
                        size: 18,
                        color: _iconPurple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _label(
                          context,
                          ru: 'Иконка приложения',
                          en: 'App icon',
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _label(
                        context,
                        ru: 'Открыть выбор',
                        en: 'Open picker',
                      ),
                      onPressed: () => showAppIconPicker(context, c),
                      icon: const Icon(AppIcons.more),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppIconCarousel(controller: c),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _svgLeading(
                      _iconChatsBubbleStyle,
                      _iconPurple,
                      fallbackIcon: AppIcons.chatBubble,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _label(
                          context,
                          ru: 'Цвета пузырей',
                          en: 'Bubble colors',
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _label(
                        context,
                        ru: 'Открыть расширенный выбор',
                        en: 'Open extended picker',
                      ),
                      onPressed: () => _showBubbleStylePicker(context, c),
                      icon: const Icon(AppIcons.more),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 126,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kChatBubbleStylePresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final preset = kChatBubbleStylePresets[index];
                      return _buildCarouselCard(
                        context: context,
                        selected:
                            preset.id ==
                            normalizeChatBubbleStylePresetId(
                              c.chatBubbleStylePresetId,
                            ),
                        locked: _cosmeticLocked(
                          c,
                          CosmeticKind.bubbleStyle,
                          preset.id,
                        ),
                        title: settingsScreenPresetName(
                          context,
                          id: preset.id,
                          ru: preset.nameRu,
                          en: preset.nameEn,
                        ),
                        onTap: () => _onCosmeticTap(
                          context,
                          c,
                          kind: CosmeticKind.bubbleStyle,
                          id: preset.id,
                          apply: () => c.setChatBubbleStylePresetId(preset.id),
                        ),
                        preview: Container(
                          padding: const EdgeInsets.all(8),
                          color: cs.surfaceContainer.withValues(alpha: 0.82),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 88,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: c.darkMode
                                      ? (preset.darkMid != null
                                            ? [
                                                preset.darkTop,
                                                preset.darkMid!,
                                                preset.darkBottom,
                                              ]
                                            : [
                                                preset.darkTop,
                                                preset.darkBottom,
                                              ])
                                      : (preset.lightMid != null
                                            ? [
                                                preset.lightTop,
                                                preset.lightMid!,
                                                preset.lightBottom,
                                              ]
                                            : [
                                                preset.lightTop,
                                                preset.lightBottom,
                                              ]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _svgLeading(
                      _iconChatsApproved,
                      _iconGreen,
                      fallbackIcon: AppIcons.badge,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _label(
                          context,
                          ru: 'Цвета ников',
                          en: 'Nickname colors',
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _label(
                        context,
                        ru: 'Открыть расширенный выбор',
                        en: 'Open extended picker',
                      ),
                      onPressed: () => _showNicknameStylePicker(context, c),
                      icon: const Icon(AppIcons.more),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 126,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kNicknameStylePresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final preset = kNicknameStylePresets[index];
                      return _buildCarouselCard(
                        context: context,
                        selected: preset.id == c.nicknameStylePresetId,
                        title: settingsScreenPresetName(
                          context,
                          id: preset.id,
                          ru: preset.nameRu,
                          en: preset.nameEn,
                        ),
                        onTap: () async {
                          await c.setNicknameStylePresetId(preset.id);
                        },
                        preview: Container(
                          color: cs.surfaceContainer.withValues(alpha: 0.8),
                          padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _label(
                                  context,
                                  ru: 'Вы: принял',
                                  en: 'You: got it',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: preset.outgoing,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _label(
                                  context,
                                  ru: 'Мира: переслала SMS',
                                  en: 'Mira: forwarded SMS',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: preset.incoming,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // PR-J — "Цвета индикаторов" section ----------------------
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.primary.withValues(alpha: 0.14),
                      radius: 20,
                      child: Icon(AppIcons.tag, size: 18, color: cs.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _label(
                          context,
                          ru: 'Цвета индикаторов',
                          en: 'Indicator colors',
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kIndicatorColorPresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final preset = kIndicatorColorPresets[index];
                      final isDarkMode =
                          Theme.of(context).brightness == Brightness.dark;
                      // For the swatch preview we always show the dark-mode
                      // hue (it's vivid and reads well against the card
                      // background regardless of the active theme). The
                      // "theme" preset displays a soft rainbow swatch so it
                      // visually stands apart from the fixed accent options.
                      final swatchColor = preset.followsTheme
                          ? cs.primary
                          : (isDarkMode
                                ? preset.darkPrimary
                                : preset.lightPrimary);
                      return _buildCarouselCard(
                        context: context,
                        selected: preset.id == c.indicatorColorPresetId,
                        locked: _cosmeticLocked(
                          c,
                          CosmeticKind.indicatorColor,
                          preset.id,
                        ),
                        title: settingsScreenPresetName(
                          context,
                          id: 'indicator_${preset.id}',
                          ru: preset.nameRu,
                          en: preset.nameEn,
                        ),
                        onTap: () => _onCosmeticTap(
                          context,
                          c,
                          kind: CosmeticKind.indicatorColor,
                          id: preset.id,
                          apply: () => c.setIndicatorColorPresetId(preset.id),
                        ),
                        preview: Container(
                          color: cs.surfaceContainer.withValues(alpha: 0.8),
                          alignment: Alignment.center,
                          child: preset.followsTheme
                              ? Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: <Color>[
                                        Color(0xFF6366F1),
                                        Color(0xFFEC4899),
                                        Color(0xFFF59E0B),
                                        Color(0xFF10B981),
                                        Color(0xFF3B82F6),
                                        Color(0xFF6366F1),
                                      ],
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: swatchColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: swatchColor.withValues(
                                          alpha: 0.45,
                                        ),
                                        blurRadius: 10,
                                        spreadRadius: -2,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _svgLeading(
                      _iconChats,
                      _iconCyan,
                      fallbackIcon: AppIcons.settings,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _label(
                          context,
                          ru: 'Поведение чатов',
                          en: 'Chat behavior',
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    children: [
                      Builder(
                        builder: (tileCtx) => SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          value: c.darkMode,
                          title: Text(l10n.darkTheme),
                          subtitle: Text(l10n.darkThemeSubtitle),
                          onChanged: (v) {
                            Haptics.tap();
                            final box =
                                tileCtx.findRenderObject() as RenderBox?;
                            final center = box != null
                                ? box.localToGlobal(
                                    box.size.center(Offset.zero),
                                  )
                                : Offset(
                                    MediaQuery.sizeOf(tileCtx).width / 2,
                                    MediaQuery.sizeOf(tileCtx).height / 3,
                                  );
                            ThemeTransitionScope.of(
                              tileCtx,
                            )?.triggerTransition(center, v);
                          },
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.25),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        value: c.blockUnverified,
                        title: Text(l10n.blockUnverified),
                        subtitle: Text(l10n.blockUnverifiedSubtitle),
                        onChanged: (v) {
                          Haptics.tap();
                          c.setBlockUnverified(v);
                        },
                      ),
                      // SEC-11: скрытие содержимого экрана. Выключено по
                      // умолчанию, как в Signal: на Android флаг ломает
                      // демонстрацию экрана и часть средств доступности.
                      //
                      // 🔴 Подпись РАЗНАЯ на двух системах, и это не
                      // придирка. iOS не даёт приложению запретить снимок
                      // экрана — закрывается только карточка в переключателе.
                      // Одинаковый текст пообещал бы там защиту, которой нет,
                      // а человек стал бы вести себя смелее, чем можно.
                      if (ScreenPrivacy.isSupported) ...[
                        Divider(
                          height: 1,
                          color: cs.outlineVariant.withValues(alpha: 0.25),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          value: c.screenPrivacy,
                          title: Text(
                            _label(
                              context,
                              ru: 'Скрывать содержимое экрана',
                              en: 'Hide screen contents',
                            ),
                          ),
                          subtitle: Text(
                            ScreenPrivacy.blocksScreenshots
                                ? _label(
                                    context,
                                    ru: 'Снимок и запись экрана недоступны, в списке приложений пусто. Демонстрация экрана и часть средств доступности перестанут работать.',
                                    en: 'Screenshots and screen recording are blocked, and the app preview is blank. Screen sharing and some accessibility tools will stop working.',
                                  )
                                : _label(
                                    context,
                                    ru: 'Содержимое скрыто в списке приложений. Запретить снимки экрана iOS приложениям не позволяет.',
                                    en: 'Contents are hidden in the app switcher. iOS does not let apps block screenshots.',
                                  ),
                          ),
                          onChanged: (v) async {
                            Haptics.tap();
                            final ok = await c.setScreenPrivacy(v);
                            if (ok || !context.mounted) return;
                            // Система отказала — переключатель остался
                            // выключенным намеренно. Молчаливый «включено» при
                            // незащищённом экране опаснее отказа.
                            ScaffoldMessenger.of(context).showSnackBar(
                              SecretlySnackBar(
                                content: Text(
                                  _label(
                                    context,
                                    ru: 'Система не приняла настройку — содержимое экрана не скрыто.',
                                    en: 'The system refused the setting — screen contents are not hidden.',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _label(
                    context,
                    ru: 'Текущая тема: $appThemePresetName.',
                    en: 'Current theme: $appThemePresetName.',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedia({
    required BuildContext context,
    required AppController c,
    required ColorScheme cs,
    required dynamic l10n,
  }) {
    return _card([
      _tile(
        context: context,
        iconAsset: _iconPrivacyVisibility,
        iconTint: _iconBlue,
        iconBg: Colors.transparent,
        iconFg: cs.onSurface,
        fallbackIcon: Icons.qr_code_2_rounded,
        title: _label(context, ru: 'QR-профиль', en: 'Profile QR'),
        subtitle: _label(
          context,
          ru: 'Показать ваш QR-код профиля',
          en: 'Show your profile QR code',
        ),
        onTap: () {
          Navigator.of(context).push(
            SecretlyPageRoute(
              builder: (_) => MySecretlyIdScreen(controller: c),
            ),
          );
        },
      ),
      const Divider(height: 1),
      _tile(
        context: context,
        iconAsset: _iconPrivacyList,
        iconTint: _iconPurple,
        iconBg: Colors.transparent,
        iconFg: cs.onSurface,
        fallbackIcon: Icons.qr_code_scanner_rounded,
        title: _label(context, ru: 'Сканер QR', en: 'QR scanner'),
        subtitle: _label(
          context,
          ru: 'Сканировать QR-код контакта',
          en: 'Scan a contact QR code',
        ),
        onTap: () async {
          await _openMyId(context, c, initialTab: MySecretlyIdTab.scanQr);
        },
      ),
      const Divider(height: 1),
      _tile(
        context: context,
        iconAsset: _iconChatsBubbleStyle,
        iconTint: _iconOrange,
        iconBg: Colors.transparent,
        iconFg: cs.onSurface,
        fallbackIcon: Icons.folder_special_rounded,
        title: _label(context, ru: 'Личные чаты', en: 'Personal chats'),
        subtitle: _label(
          context,
          ru: 'Открыть личную подборку чатов',
          en: 'Open your personal chat collection',
        ),
        onTap: () async {
          final unlocked = await ensureSecurityScopeUnlocked(
            context: context,
            controller: c,
            scope: SecurityLockScope.personal,
          );
          if (!context.mounted || !unlocked) {
            return;
          }
          Navigator.of(context).push(
            SecretlyPageRoute(
              builder: (_) => PersonalChatsScreen(controller: c),
            ),
          );
        },
      ),
      const Divider(height: 1),
      _tile(
        context: context,
        iconAsset: _iconPrivacyStop,
        iconTint: _iconGreen,
        iconBg: Colors.transparent,
        iconFg: cs.onSurface,
        fallbackIcon: Icons.lock_rounded,
        title: _label(context, ru: 'Приватность медиа', en: 'Media privacy'),
        subtitle: _label(
          context,
          ru: 'Медиа из профиля видите только вы',
          en: 'Profile media is visible only to you',
        ),
      ),
      // Peer cosmetics motion MOVED to Settings → Power (2026-07-31):
      // it is a motion/battery choice, not a media one, and it belongs next
      // to the other things that cost frames.
    ]);
  }

  Widget _buildPrivacy({
    required BuildContext context,
    required AppController c,
    required ColorScheme cs,
    required dynamic l10n,
  }) {
    Future<void> setArchiveUnknown(bool value) async {
      setState(() {});
      await c.setPrivacyArchiveUnknownChats(value);
    }

    Future<void> setUserLookup(bool value) async {
      setState(() {});
      await _saveBoolSetting(_prefsPrivacySuggestContactsKey, value);
      await c.setAllowNicknameLookup(value);
    }

    String syncContactsSubtitle() {
      if (c.contactSyncInFlight) {
        return _label(
          context,
          ru: 'Синхронизация контактов устройства выполняется',
          en: 'Syncing with your device address book',
        );
      }
      if (!c.contactSyncSupported) {
        return _label(
          context,
          ru: 'Доступно в приложении для Android и iPhone',
          en: 'Available in the Android and iPhone app',
        );
      }
      if (c.contactSyncEnabled) {
        return _label(
          context,
          ru: 'Контакты Secretly сохраняются в адресную книгу устройства',
          en: 'Keep Secretly contacts in your device address book',
        );
      }
      return _label(
        context,
        ru: 'Контакты Secretly не сохраняются в адресную книгу устройства',
        en: 'Do not save Secretly contacts to your device address book',
      );
    }

    String deleteImportedContactsSubtitle() {
      if (!c.contactSyncSupported) {
        return _label(
          context,
          ru: 'Удаление доступно только в мобильном приложении',
          en: 'Removal is available only in the mobile app',
        );
      }
      return _label(
        context,
        ru: 'Удалить контакты Secretly из адресной книги и выключить синхронизацию',
        en: 'Remove Secretly contacts from your address book and turn sync off',
      );
    }

    String contactSyncMessage(DeviceContactSyncActionResult result) {
      switch (result.status) {
        case DeviceContactSyncActionStatus.synced:
          if (result.createdCount == 0 &&
              result.updatedCount == 0 &&
              result.deletedCount == 0) {
            return _label(
              context,
              ru: 'Контакты устройства уже актуальны.',
              en: 'Device contacts are already up to date.',
            );
          }
          return _label(
            context,
            ru: 'Синхронизация завершена: создано ${result.createdCount}, обновлено ${result.updatedCount}, удалено ${result.deletedCount}.',
            en: 'Sync complete: created ${result.createdCount}, updated ${result.updatedCount}, removed ${result.deletedCount}.',
          );
        case DeviceContactSyncActionStatus.disabled:
          return _label(
            context,
            ru: 'Синхронизация контактов отключена на этом устройстве.',
            en: 'Contact sync is turned off on this device.',
          );
        case DeviceContactSyncActionStatus.cleared:
          if (result.deletedCount == 0) {
            return _label(
              context,
              ru: 'Импортированные контакты не найдены. Синхронизация выключена.',
              en: 'No imported contacts were found. Sync is off.',
            );
          }
          return _label(
            context,
            ru: 'Удалено контактов: ${result.deletedCount}. Синхронизация выключена.',
            en: 'Removed ${result.deletedCount} imported contact(s). Sync is off.',
          );
        case DeviceContactSyncActionStatus.permissionDenied:
          return _label(
            context,
            ru: 'Разрешите доступ к контактам, чтобы управлять адресной книгой устройства.',
            en: 'Allow contact access to manage your device address book.',
          );
        case DeviceContactSyncActionStatus.unsupported:
          return _label(
            context,
            ru: 'Управление контактами устройства доступно в приложении для Android и iPhone.',
            en: 'Manage device contacts from the Android or iPhone app.',
          );
        case DeviceContactSyncActionStatus.failed:
          return _label(
            context,
            ru: 'Не удалось обновить контакты устройства прямо сейчас.',
            en: 'Could not update device contacts right now.',
          );
      }
    }

    void showContactSyncSnackBar(DeviceContactSyncActionResult result) {
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(content: Text(contactSyncMessage(result))),
      );
    }

    Future<void> toggleContactSync(bool value) async {
      final result = await c.setContactSyncEnabled(value);
      if (!mounted) return;
      setState(() {});
      showContactSyncSnackBar(result);
    }

    Future<void> deleteImportedContacts() async {
      if (!c.contactSyncSupported) {
        showContactSyncSnackBar(
          const DeviceContactSyncActionResult(
            status: DeviceContactSyncActionStatus.unsupported,
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              _label(
                context,
                ru: 'Удалить импортированные контакты?',
                en: 'Delete imported contacts?',
              ),
            ),
            content: Text(
              _label(
                context,
                ru: 'Secretly удалит свои контакты из адресной книги этого устройства и выключит синхронизацию.',
                en: 'Secretly will remove its contacts from this device address book and turn sync off.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(_label(context, ru: 'Отмена', en: 'Cancel')),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(_label(context, ru: 'Удалить', en: 'Delete')),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;

      final result = await c.clearSyncedDeviceContactsAndDisableSync();
      if (!mounted) return;
      setState(() {});
      showContactSyncSnackBar(result);
    }

    Future<void> pickAudience(String key, String title) async {
      final current = c.privacyAudience[key] ?? 'contacts';
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          const options = <String>['nobody', 'contacts', 'everyone'];
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final option in options)
                  ListTile(
                    title: Text(_audienceLabel(context, option)),
                    trailing: option == current
                        ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
              ],
            ),
          );
        },
      );
      if (selected == null) return;
      await c.setPrivacyAudience(key, selected);
      setState(() {});
    }

    Future<void> pickDeleteAccountAfter() async {
      final selected = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          final options = <int>[1, 3, 6, 12, 24];
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final months in options)
                  ListTile(
                    title: Text(
                      _label(
                        context,
                        ru: '$months ${months == 1 ? 'месяц' : 'месяца'}',
                        en: '$months month${months == 1 ? '' : 's'}',
                      ),
                    ),
                    trailing: months == c.privacyDeleteAccountMonths
                        ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(months),
                  ),
              ],
            ),
          );
        },
      );
      if (selected == null) return;
      await c.setPrivacyDeleteAccountMonths(selected);
    }

    Widget audienceTile({
      required String key,
      required String titleRu,
      required String titleEn,
      IconData iconData = Icons.privacy_tip_rounded,
      Color? tint,
    }) {
      return _tile(
        context: context,
        iconAsset: _iconPrivacyVisibility,
        iconTint: tint ?? _iconBlue,
        iconBg: Colors.transparent,
        iconFg: cs.onSurface,
        fallbackIcon: iconData,
        title: _label(context, ru: titleRu, en: titleEn),
        subtitle: _audienceLabel(context, c.privacyAudience[key] ?? 'contacts'),
        onTap: () =>
            pickAudience(key, _label(context, ru: titleRu, en: titleEn)),
      );
    }

    return Column(
      children: [
        _card([
          audienceTile(
            key: 'last_seen',
            titleRu: 'Время захода',
            titleEn: 'Last seen',
            iconData: Icons.history_rounded,
            tint: _iconCyan,
          ),
          const Divider(height: 1),
          audienceTile(
            key: 'photo',
            titleRu: 'Фотографии профиля',
            titleEn: 'Profile photos',
            iconData: Icons.account_circle_rounded,
            tint: _iconPurple,
          ),
          const Divider(height: 1),
          audienceTile(
            key: 'forwards',
            titleRu: 'Пересылка сообщений',
            titleEn: 'Message forwards',
            iconData: Icons.forward_rounded,
            tint: _iconOrange,
          ),
          const Divider(height: 1),
          audienceTile(
            key: 'calls',
            titleRu: 'Звонки',
            titleEn: 'Calls',
            iconData: Icons.phone_in_talk_rounded,
            tint: _iconGreen,
          ),
          const Divider(height: 1),
          audienceTile(
            key: 'voice_messages',
            titleRu: 'Голосовые сообщения',
            titleEn: 'Voice messages',
            iconData: Icons.keyboard_voice_rounded,
            tint: _iconAmber,
          ),
          const Divider(height: 1),
          audienceTile(
            key: 'messages',
            titleRu: 'Сообщения',
            titleEn: 'Messages',
            iconData: Icons.message_rounded,
            tint: _iconCyan,
          ),
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconPrivacyList,
            iconTint: _iconPurple,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.archive_rounded,
            title: _label(
              context,
              ru: 'Новые чаты с незнакомцами',
              en: 'New chats from strangers',
            ),
            subtitle: _label(
              context,
              ru: 'В архив и без уведомлений',
              en: 'Archive and mute',
            ),
            trailing: Switch(
              value: c.privacyArchiveUnknownChats,
              onChanged: setArchiveUnknown,
            ),
            onTap: () => setArchiveUnknown(!c.privacyArchiveUnknownChats),
          ),
        ]),
        const SizedBox(height: 10),
        // SEC-10③: механизм «только через сервер» существовал давно, но
        // человеку был недоступен — политику назначал сервер. По умолчанию
        // соединение прямое, а значит собеседник видит IP-адрес.
        //
        // 🔴 Цена названа в самой подписи. Молча ухудшить связь ради
        // приватности — тот же обман, что молча раскрыть адрес: человек
        // должен выбирать, зная размен.
        _card([
          _tile(
            context: context,
            icon: Icons.vpn_lock_rounded,
            fallbackIcon: Icons.vpn_lock_rounded,
            iconTint: _iconGreen,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            title: _label(
              context,
              ru: 'Скрывать мой адрес в звонках',
              en: 'Hide my address in calls',
            ),
            subtitle: _label(
              context,
              ru: 'Через наш сервер: собеседник не увидит IP-адрес, но задержка может вырасти',
              en: 'Through our server: the other person will not see your IP address, but latency may increase',
            ),
            trailing: Switch(
              value: c.hideAddressInCalls,
              onChanged: (v) => unawaited(c.setHideAddressInCalls(v)),
            ),
            onTap: () =>
                unawaited(c.setHideAddressInCalls(!c.hideAddressInCalls)),
          ),
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconSystem,
            iconTint: _iconAmber,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.person_remove_rounded,
            title: _label(
              context,
              ru: 'Удалить мой аккаунт',
              en: 'Delete my account',
            ),
            subtitle: _label(
              context,
              ru: 'Если я не захожу: ${c.privacyDeleteAccountMonths} ${c.privacyDeleteAccountMonths == 1 ? 'месяц' : 'месяца'}',
              en: 'If away for: ${c.privacyDeleteAccountMonths} month${c.privacyDeleteAccountMonths == 1 ? '' : 's'}',
            ),
            onTap: pickDeleteAccountAfter,
          ),
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconPrivacyStop,
            iconTint: _iconRed,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.contacts_rounded,
            title: _label(
              context,
              ru: 'Удалить импортированные контакты',
              en: 'Delete imported contacts',
            ),
            subtitle: deleteImportedContactsSubtitle(),
            onTap: c.contactSyncInFlight ? null : deleteImportedContacts,
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconChatsApproved,
            iconTint: _iconGreen,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.sync_alt_rounded,
            title: _label(
              context,
              ru: 'Синхронизировать контакты',
              en: 'Sync contacts',
            ),
            subtitle: syncContactsSubtitle(),
            trailing: Switch(
              value: c.contactSyncEnabled,
              onChanged: c.contactSyncInFlight ? null : toggleContactSync,
            ),
            onTap: c.contactSyncInFlight
                ? null
                : () => toggleContactSync(!c.contactSyncEnabled),
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            iconAsset: _iconPrivacyVisibility,
            iconTint: _iconBlue,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.manage_search_rounded,
            title: _label(
              context,
              ru: 'Подсказка людей при поиске',
              en: 'People suggestions in search',
            ),
            trailing: Switch(
              value: c.allowNicknameLookup,
              onChanged: setUserLookup,
            ),
            onTap: () => setUserLookup(!c.allowNicknameLookup),
          ),
        ]),
        const SizedBox(height: 10),
        _card([
          _tile(
            context: context,
            iconAsset: _iconPrivacyVisibility,
            iconTint: _iconBlue,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.visibility_rounded,
            title: _label(
              context,
              ru: 'Видимость по никнейму',
              en: 'Discoverable by nickname',
            ),
            subtitle: _label(
              context,
              ru: 'Позволить находить вас по никнейму',
              en: 'Allow others to find you by nickname',
            ),
            trailing: Switch(
              value: c.discoverableByNickname,
              onChanged: (v) => c.setDiscoverableByNickname(v),
            ),
            onTap: () => c.setDiscoverableByNickname(!c.discoverableByNickname),
          ),
          const Divider(height: 1),
          _tile(
            context: context,
            fallbackIcon: Icons.block_rounded,
            iconAsset: _iconPrivacyStop,
            iconTint: _iconRed,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            title: _label(
              context,
              ru: 'Конфиденциальность',
              en: 'Privacy controls',
            ),
            subtitle: _label(
              context,
              ru: 'Управление заблокированными пользователями',
              en: 'Manage blocked users',
            ),
            onTap: () {
              Navigator.of(context).push(
                SecretlyPageRoute(builder: (_) => PrivacyScreen(controller: c)),
              );
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildSystem({
    required BuildContext context,
    required AppController c,
    required ColorScheme cs,
    required dynamic l10n,
  }) {
    final warn = c.startupWarning;
    final blocked = c.transportBlocked;
    final blockedReason = c.transportBlockedReason;
    final localProfile = c.isUnregisteredLocalProfile;

    String lbl(String ru, String en) => _label(context, ru: ru, en: en);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status card
        if (warn != null || blocked || localProfile) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: cs.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lbl('Системные ошибки', 'System errors'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: cs.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (warn != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      warn,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ],
                  if (blocked && blockedReason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${lbl("Транспорт заблокирован", "Transport blocked")}: $blockedReason',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ],
                  if (localProfile) ...[
                    const SizedBox(height: 8),
                    Text(
                      lbl(
                        'Профиль не зарегистрирован на сервере (локальный ID). '
                            'Сообщения НЕ будут доставляться. Нажмите «Сбросить '
                            'профиль», чтобы создать настоящий ID.',
                        'Profile is not registered on the server (local-only ID). '
                            'Messages will NOT be delivered. Tap "Reset profile" '
                            'to create a real ID.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (warn == null && !blocked && !localProfile)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: cs.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  lbl(
                    'Система работает нормально',
                    'System is operating normally',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.primary),
                ),
              ],
            ),
          ),
        // Reset profile
        _card([
          _tile(
            context: context,
            iconAsset: _iconPrivacyStop,
            iconTint: _iconRed,
            iconBg: Colors.transparent,
            iconFg: cs.onSurface,
            fallbackIcon: Icons.delete_sweep_rounded,
            leading: _resettingProfile
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  )
                : null,
            title: l10n.resetProfile,
            subtitle: l10n.resetProfileSubtitle,
            onTap: () async {
              if (_resettingProfile) return;
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text(l10n.resetProfileDialogTitle),
                    content: Text(l10n.resetProfileDialogBody),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l10n.reset),
                      ),
                    ],
                  );
                },
              );
              if (ok != true || !context.mounted) return;
              setState(() => _resettingProfile = true);
              try {
                await c.resetProfileAndLocalData();
                // Same pattern as Log out / Delete account: Settings may be
                // pushed one or more levels deep, so pop back to root now or
                // the rebuilt Welcome screen stays hidden underneath the
                // leftover route stack.
                CallManager.navigatorKey.currentState?.popUntil(
                  (route) => route.isFirst,
                );
              } finally {
                if (mounted) setState(() => _resettingProfile = false);
              }
            },
          ),
        ]),
      ],
    );
  }
}

class _SupportContactScreen extends StatefulWidget {
  const _SupportContactScreen({required this.controller});

  final AppController controller;

  @override
  State<_SupportContactScreen> createState() => _SupportContactScreenState();
}

class _SupportContactScreenState extends State<_SupportContactScreen> {
  late final TextEditingController _nameController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  late final TextEditingController _techInfoController;

  String _label({required String ru, required String en}) =>
      settingsScreenLabel(context, ru: ru, en: en);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.controller.myNickname.trim(),
    );
    _techInfoController = TextEditingController(text: _techInfo());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    _techInfoController.dispose();
    super.dispose();
  }

  String _techInfo() {
    return buildSupportTechnicalInfo(
      buildMarker: widget.controller.buildMarker,
      deviceId: widget.controller.deviceId,
      profileId: widget.controller.profileId,
      additionalLines: widget.controller.pushRegistrationTechnicalLines,
    );
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            _label(
              ru: 'Сначала опишите проблему.',
              en: 'Describe the issue first.',
            ),
          ),
        ),
      );
      return;
    }
    final payload = buildSupportRequestPayload(
      message: message,
      technicalInfo: _techInfoController.text,
      name: _nameController.text,
      email: _emailController.text,
    );
    const supportEmail = 'technical.support@secretlyapp.com';
    final subject = Uri.encodeComponent('Secretly Support');
    final body = Uri.encodeComponent(payload);
    final mailUri = Uri.parse(
      'mailto:$supportEmail?subject=$subject&body=$body',
    );
    bool opened = false;
    try {
      opened = await launchUrl(mailUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!mounted) return;
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: payload));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            _label(
              ru: 'Не удалось открыть почту. Текст запроса скопирован в буфер обмена.',
              en: 'Could not open mail app. Request text copied to clipboard.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: Text(_label(ru: 'Поддержка', en: 'Support')),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: topInset,
          bottom: 32 + bottomInset,
          left: 16,
          right: 16,
        ),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(
                      ru: 'Форма связи с поддержкой',
                      en: 'Support contact form',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _label(
                      ru: 'Опишите проблему, при необходимости добавьте контактные данные. Техническая информация ниже приложится автоматически.',
                      en: 'Describe the issue and add contact details if needed. The technical information below is attached automatically.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'technical.support@secretlyapp.com',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: _label(ru: 'Имя', en: 'Name'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: _label(
                        ru: 'Email / Контакт для связи',
                        en: 'Email / Contact',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageController,
                    minLines: 6,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: _label(
                        ru: 'Опишите проблему',
                        en: 'Describe the issue',
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _techInfoController,
                    readOnly: true,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: _label(
                        ru: 'Техническая информация',
                        en: 'Technical information',
                      ),
                      alignLabelWithHint: true,
                      helperText: _label(
                        ru: 'Этот блок уже будет приложен к запросу автоматически.',
                        en: 'This block is already attached to the request automatically.',
                      ),
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(AppIcons.send),
            label: Text(_label(ru: 'Отправить запрос', en: 'Send request')),
          ),
        ],
      ),
    );
  }
}

/// Rebuilds [builder] every time [stream] emits, passing a fresh [BuildContext].
/// Used to keep settings sub-pages reactive to controller/theme changes.
class _StreamRebuild extends StatelessWidget {
  const _StreamRebuild({required this.stream, required this.builder});

  final Stream<void> stream;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: stream,
      builder: (ctx, _) => builder(ctx),
    );
  }
}

/// Storage / cache management screen (audit §D). Shows per-category on-disk
/// usage and offers two reclaim actions: «Clear cache» (re-fetchable caches
/// only — see [CacheManager.clearMediaCache]) and «Remove offline voice model».
/// Nothing here can delete the DB, keys, chats, or the user's own gallery.
/// Power / heat settings.
///
/// Exists because the look had a real, continuous cost the user could not opt
/// out of: the glass bubbles were a compile-time `!Platform.isAndroid`, so a
/// phone that ran hot had no lever at all. Everything here defaults to ON —
/// this page only ever takes things away, and only when asked.
///
/// Ordered by how much each one actually saves, most first, so somebody who
/// just wants a cooler phone can stop reading after the first switch.
class _PowerSettingsScreen extends StatefulWidget {
  const _PowerSettingsScreen({required this.controller});

  final AppController controller;

  @override
  State<_PowerSettingsScreen> createState() => _PowerSettingsScreenState();
}

class _PowerSettingsScreenState extends State<_PowerSettingsScreen> {
  // 🔴 This screen used to carry a PRIVATE ru/en helper of its own:
  //
  //     final code = Localizations.localeOf(context).languageCode;
  //     return code == 'ru' ? ru : en;
  //
  // It never consulted `_settingsTranslations`, so every language except
  // Russian read English — including the six this app ships translations for.
  // The strings were translated on 2026-08-01 and STILL showed English,
  // because nothing routed them through the lookup (field report, same day).
  //
  // `_settingsLabel` is the shared helper the rest of Settings uses: Russian
  // and English come back directly, everything else is looked up by the exact
  // English string. Never reintroduce a local shortcut here —
  // `power_settings_l10n_test.dart` fails if one appears.
  static String _t(BuildContext context, {required String ru, required String en}) =>
      _settingsLabel(context, ru: ru, en: en);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.controller;
    // Android never builds the blurred wallpaper texture, so offering to turn
    // it off there would be a switch that does nothing.
    final showBubbleGlass = !Platform.isAndroid;

    Widget toggle({
      required bool value,
      required String title,
      required String subtitle,
      required ValueChanged<bool> onChanged,
    }) => SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      value: value,
      title: Text(title),
      subtitle: Text(subtitle),
      onChanged: (v) {
        Haptics.tap();
        onChanged(v);
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_t(context, ru: 'Энергопотребление', en: 'Power')),
      ),
      body: StreamBuilder<void>(
        stream: c.changed,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
              child: Text(
                _t(
                  context,
                  ru: 'Всё включено по умолчанию. Выключайте по одному сверху '
                      'вниз — первый пункт экономит больше всего.',
                  en: 'Everything is on by default. Turn them off from the top '
                      'down — the first one saves the most.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  if (showBubbleGlass) ...[
                    toggle(
                      value: c.bubbleGlassEnabled,
                      title: _t(
                        context,
                        ru: 'Стеклянные пузыри',
                        en: 'Glass bubbles',
                      ),
                      subtitle: _t(
                        context,
                        ru: 'Входящие сообщения показывают размытые обои '
                            'сквозь себя. Красиво, но держит размытую копию '
                            'обоев всё время, пока открыт чат. Выключите '
                            'первым, если телефон греется.',
                        en: 'Incoming messages show the blurred wallpaper '
                            'through them. It looks good, but keeps a blurred '
                            'copy of the wallpaper alive the whole time a chat '
                            'is open. Turn this off first if the phone gets hot.',
                      ),
                      onChanged: (v) => c.setBubbleGlassEnabled(v),
                    ),
                    const Divider(height: 1),
                  ],
                  toggle(
                    value: c.frostedPanelsEnabled,
                    title: _t(
                      context,
                      ru: 'Матовые панели',
                      en: 'Frosted panels',
                    ),
                    subtitle: _t(
                      context,
                      ru: 'Размытие под шапкой чата и полем ввода. Панели '
                          'остаются на месте — фон за ними просто перестаёт '
                          'размываться.',
                      en: 'The blur under the chat header and the composer. '
                          'The panels stay exactly where they are — the '
                          'background behind them simply stops being blurred.',
                    ),
                    onChanged: (v) => c.setFrostedPanelsEnabled(v),
                  ),
                  const Divider(height: 1),
                  // Moved here from Media & profile: it is a motion/battery
                  // choice, not a media one, and it belongs next to its peers.
                  toggle(
                    value: c.peerCosmeticAnimEnabled,
                    title: _t(
                      context,
                      ru: 'Анимация рамок и статусов',
                      en: 'Frame & status animations',
                    ),
                    subtitle: _t(
                      context,
                      ru: 'Анимировать премиум-рамки и эмодзи-статусы '
                          'собеседников в чатах и списках. В профилях '
                          'анимация есть всегда.',
                      en: "Animate peers' premium frames and status emoji in "
                          'chats and lists. Profiles always animate.',
                    ),
                    onChanged: (v) => c.setPeerCosmeticAnimEnabled(v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
              child: Text(
                _t(
                  context,
                  ru: 'Ничего из этого не влияет на доставку сообщений, '
                      'шифрование и уведомления — только на то, как приложение '
                      'выглядит.',
                  en: 'None of these affect message delivery, encryption or '
                      'notifications — only how the app looks.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageSettingsScreen extends StatefulWidget {
  const _StorageSettingsScreen({required this.controller});

  final AppController controller;

  @override
  State<_StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<_StorageSettingsScreen> {
  CacheUsage? _usage;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    // TZ E0: which cached chat-media files are the ONLY copy (no re-download
    // path). Clearing must skip them, and the "clearable" figure must not
    // count them. null = unknown → CacheManager fail-safes to protect all.
    final irreplaceable = await widget.controller
        .irreplaceableAttachmentBlobIds();
    final usage = await CacheManager.instance.computeUsage(
      irreplaceableAttachmentBlobIds: irreplaceable,
    );
    if (!mounted) return;
    setState(() => _usage = usage);
  }

  static String _fmtBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // Self-contained card/tile helpers (the screen lives outside
  // `_SettingsScreenState`, so it can't reuse that state's private `_card`/
  // `_tile`/icon-color members). Styling mirrors the rest of Settings.
  static const Color _storageBlue = Color(0xFF2AABEE);
  static const Color _storageRed = Color(0xFFE25563);

  Widget _storageCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color tint,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tint.withValues(alpha: 0.14),
        foregroundColor: tint,
        child: Icon(icon),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: trailing,
      onTap: onTap == null
          ? null
          : () {
              Haptics.tap();
              onTap();
            },
    );
  }

  Future<void> _clearCache() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // TZ E0: fetch the protected set at CLEAR time (not a stale snapshot) so
      // media received while this screen was open is honored too.
      final irreplaceable = await widget.controller
          .irreplaceableAttachmentBlobIds();
      await CacheManager.instance.clearMediaCache(
        irreplaceableAttachmentBlobIds: irreplaceable,
      );
      await _refresh();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.storageClearedToast)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeVoiceModel() async {
    if (_busy) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ready = await VoiceTranscriptionService.instance.isModelReady();
    if (!mounted) return;
    if (!ready) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.storageVoiceModelNotInstalled)),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.storageRemoveVoiceModelConfirmTitle),
        content: Text(l10n.storageRemoveVoiceModelConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.storageRemoveVoiceModelConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await VoiceTranscriptionService.instance.deleteModel();
      await _refresh();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.storageVoiceModelRemovedToast)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    final usage = _usage;
    final calculating = l10n.storageCalculating;

    String sizeFor(int? bytes) =>
        bytes == null ? calculating : _fmtBytes(bytes);

    Widget usageRow(String label, int? bytes) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            Text(
              sizeFor(bytes),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(title: Text(l10n.storageSection)),
      body: ListView(
        padding: EdgeInsets.only(top: topInset, bottom: 32 + bottomInset),
        children: [
          // ---- usage breakdown ------------------------------------------
          _storageCard([
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                l10n.storageUsageTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            usageRow(l10n.storageCategoryMedia, usage?.mediaBytes),
            const Divider(height: 1),
            usageRow(
              l10n.storageCategoryVoiceTranscripts,
              usage?.voiceTranscriptsBytes,
            ),
            const Divider(height: 1),
            usageRow(l10n.storageCategoryEmoji, usage?.notoEmojiBytes),
            const Divider(height: 1),
            usageRow(l10n.storageCategoryVoiceModel, usage?.whisperModelBytes),
            const Divider(height: 1),
            usageRow(l10n.storageCategoryStickers, usage?.stickersBytes),
            const Divider(height: 1),
            usageRow(
              l10n.storageCategoryProfileMedia,
              usage?.profileMediaBytes,
            ),
            const Divider(height: 1),
            usageRow(
              l10n.storageCategoryRecents,
              usage?.recentAttachmentsBytes,
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.storageTotal,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    sizeFor(usage?.total),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // ---- actions --------------------------------------------------
          _storageCard([
            _actionTile(
              icon: AppIcons.delete,
              tint: _storageBlue,
              title: l10n.storageClearCache,
              subtitle: usage == null
                  ? l10n.storageClearCacheHint
                  : _fmtBytes(usage.clearableBytes),
              trailing: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : null,
              onTap: _busy ? null : _clearCache,
            ),
            const Divider(height: 1),
            _actionTile(
              icon: AppIcons.archive,
              tint: _storageRed,
              title: l10n.storageRemoveVoiceModel,
              subtitle: l10n.storageRemoveVoiceModelHint,
              onTap: _busy ? null : _removeVoiceModel,
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
            child: Text(
              l10n.storageClearCacheHint,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Signals to [_tile] builders in its subtree that icons should be flat
/// (no CircleAvatar background) — used inside [_SettingsCategoryScreen].
class _FlatIconMode extends InheritedWidget {
  const _FlatIconMode({required super.child});

  @override
  bool updateShouldNotify(_FlatIconMode old) => false;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FlatIconMode>() != null;
}

class _SettingsCategoryScreen extends StatelessWidget {
  const _SettingsCategoryScreen({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    final noDividerTheme = Theme.of(context).copyWith(
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        space: 0,
        thickness: 0,
      ),
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(title: Text(title)),
      body: Theme(
        data: noDividerTheme,
        child: _FlatIconMode(
          child: ListView(
            padding: EdgeInsets.only(bottom: 32 + bottomInset, top: topInset),
            children: [child],
          ),
        ),
      ),
    );
  }
}

class _DonateSupportLandingScreen extends StatelessWidget {
  const _DonateSupportLandingScreen();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: Text(
          _settingsLabel(
            context,
            ru: 'Поддержать Secretly',
            en: 'Donate Secretly',
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: topInset,
          bottom: 32 + bottomInset,
          left: 16,
          right: 16,
        ),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    height: 220,
                    child: Lottie.asset(
                      AppAssetPaths.donationBoxLottie,
                      repeat: true,
                    ),
                  ),
                  Text(
                    _settingsLabel(
                      context,
                      ru: 'Поддержка проекта',
                      en: 'Support the project',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _settingsLabel(
                      context,
                      ru: 'Secretly развивается как приватный мессенджер с акцентом на безопасность, UX и независимую инфраструктуру. На Android и iPhone страница Donorbox открывается в браузере, чтобы Apple Pay и Google Pay не скрывались внутри встроенного WebView.',
                      en: 'Secretly is evolving as a private messenger focused on security, UX, and independent infrastructure. On Android and iPhone, the Donorbox page opens in a browser so Apple Pay and Google Pay stay available instead of disappearing inside an embedded WebView.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        if (Platform.isAndroid || Platform.isIOS) {
                          await _openDonorboxCampaignInBrowser(context);
                          return;
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          SecretlyPageRoute(
                            builder: (_) => const _DonorboxSupportScreen(),
                          ),
                        );
                      },
                      icon: const Icon(AppIcons.favorites),
                      label: Text(
                        _settingsLabel(
                          context,
                          ru: 'Поддержать',
                          en: 'Support',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonorboxSupportScreen extends StatefulWidget {
  const _DonorboxSupportScreen();

  @override
  State<_DonorboxSupportScreen> createState() => _DonorboxSupportScreenState();
}

class _DonorboxSupportScreenState extends State<_DonorboxSupportScreen> {
  static const String _embedBaseUrl = 'https://donorbox.org';
  static const String _donorboxHtml = '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1, maximum-scale=1, viewport-fit=cover"
    >
    <style>
      html, body {
        margin: 0;
        padding: 0;
        background: #f6f1eb;
      }

      body {
        min-height: 100vh;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      }

      .container {
        box-sizing: border-box;
        min-height: 100vh;
        padding: 12px;
      }

      dbox-widget {
        display: block;
        width: 100%;
      }
    </style>
    <script type="module" src="https://donorbox.org/widgets.js" async></script>
  </head>
  <body>
    <div class="container">
      <dbox-widget
        campaign="donate-to-secretly"
        type="donation_form"
        enable-auto-scroll="true"
      ></dbox-widget>
    </div>
  </body>
</html>
''';

  late final WebViewController _controller;
  bool _loading = true;
  String? _loadError;

  bool get _supportsEmbeddedDonorbox => Platform.isMacOS;

  bool get _usesExternalBrowserForWalletPayments =>
      Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (!_supportsEmbeddedDonorbox) {
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _loadError = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
            });
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _loadError = error.description.isEmpty
                  ? _settingsLabel(
                      context,
                      ru: 'Не удалось загрузить Donorbox.',
                      en: 'Failed to load Donorbox.',
                    )
                  : error.description;
            });
          },
        ),
      )
      ..loadHtmlString(_donorboxHtml, baseUrl: _embedBaseUrl);
  }

  Future<void> _copyCampaignUrl() async {
    await Clipboard.setData(const ClipboardData(text: _kDonorboxCampaignUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(
        content: Text(
          _settingsLabel(
            context,
            ru: 'Ссылка Donorbox скопирована',
            en: 'Donorbox link copied',
          ),
        ),
      ),
    );
  }

  Future<void> _reload() async {
    if (!_supportsEmbeddedDonorbox) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    await _controller.loadHtmlString(_donorboxHtml, baseUrl: _embedBaseUrl);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: Text(
          _settingsLabel(
            context,
            ru: 'Поддержать Secretly',
            en: 'Donate Secretly',
          ),
        ),
        actions: [
          IconButton(
            tooltip: _settingsLabel(
              context,
              ru: 'Скопировать ссылку',
              en: 'Copy link',
            ),
            onPressed: _copyCampaignUrl,
            icon: const Icon(AppIcons.copyOutline),
          ),
          if (_usesExternalBrowserForWalletPayments)
            IconButton(
              tooltip: _settingsLabel(
                context,
                ru: 'Открыть в браузере',
                en: 'Open in browser',
              ),
              onPressed: () => _openDonorboxCampaignInBrowser(context),
              icon: const Icon(Icons.open_in_new_rounded),
            )
          else
            IconButton(
              tooltip: _settingsLabel(context, ru: 'Обновить', en: 'Refresh'),
              onPressed: _supportsEmbeddedDonorbox ? _reload : null,
              icon: const Icon(AppIcons.restart),
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(
          top: topInset,
          bottom: 16 + bottomInset,
          left: 16,
          right: 16,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ColoredBox(
            color: cs.surface,
            child: _supportsEmbeddedDonorbox
                ? Stack(
                    children: [
                      Positioned.fill(
                        child: WebViewWidget(controller: _controller),
                      ),
                      if (_loading)
                        Positioned.fill(
                          child: ColoredBox(
                            color: cs.surface,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                      if (_loadError != null)
                        Positioned.fill(
                          child: ColoredBox(
                            color: cs.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    AppIcons.errorOutline,
                                    color: cs.error,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _settingsLabel(
                                      context,
                                      ru: 'Donorbox сейчас не загрузился',
                                      en: 'Donorbox did not load right now',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _loadError!,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: _reload,
                                    icon: const Icon(AppIcons.restart),
                                    label: Text(
                                      _settingsLabel(
                                        context,
                                        ru: 'Попробовать снова',
                                        en: 'Try again',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SelectableText(
                                    _kDonorboxCampaignUrl,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : _usesExternalBrowserForWalletPayments
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.privacyTip, color: cs.primary, size: 28),
                        const SizedBox(height: 12),
                        Text(
                          _settingsLabel(
                            context,
                            ru: 'Apple Pay и Google Pay открываются через браузер',
                            en: 'Apple Pay and Google Pay open in a browser',
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _settingsLabel(
                            context,
                            ru: 'Donorbox сначала показывает web-wallet кнопки, а затем скрывает их внутри встроенного WebView после проверки среды. Во внешнем браузере страница оплаты остаётся совместимой с Apple Pay и Google Pay.',
                            en: 'Donorbox briefly renders the web-wallet buttons and then hides them inside the embedded WebView after environment checks. Opening the page in your browser keeps Apple Pay and Google Pay available.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () =>
                                _openDonorboxCampaignInBrowser(context),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: Text(
                              _settingsLabel(
                                context,
                                ru: 'Открыть страницу оплаты',
                                en: 'Open payment page',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          _kDonorboxCampaignUrl,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.privacyTip, color: cs.primary, size: 28),
                        const SizedBox(height: 12),
                        Text(
                          _settingsLabel(
                            context,
                            ru: 'Встроенный Donorbox доступен на Android, iPhone и macOS',
                            en: 'Embedded Donorbox is available on Android, iPhone, and macOS',
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _settingsLabel(
                            context,
                            ru: 'На этой платформе пока оставлен безопасный fallback. Сама кампания уже настроена и её ссылка доступна ниже.',
                            en: 'This platform currently uses a safe fallback. The campaign itself is already configured and the link is available below.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          _kDonorboxCampaignUrl,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SettingsInfoLink {
  const _SettingsInfoLink({
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final String title;
  final String subtitle;
  final String url;
}

class _SettingsInfoScreen extends StatelessWidget {
  const _SettingsInfoScreen({
    required this.title,
    required this.sections,
    this.links = const <_SettingsInfoLink>[],
  });

  final String title;
  final List<({String title, String body})> sections;
  final List<_SettingsInfoLink> links;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(title: Text(title)),
      body: ListView(
        padding: EdgeInsets.only(
          top: topInset,
          bottom: 32 + bottomInset,
          left: 16,
          right: 16,
        ),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  ListTile(
                    title: Text(
                      sections[i].title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(sections[i].body),
                    ),
                  ),
                  if (i != sections.length - 1 || links.isNotEmpty)
                    const Divider(height: 1),
                ],
                for (var i = 0; i < links.length; i++) ...[
                  ListTile(
                    leading: const Icon(Icons.open_in_new_rounded),
                    title: Text(
                      links[i].title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(links[i].subtitle),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        _openSecretlyExternalUrl(context, links[i].url),
                  ),
                  if (i != links.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
