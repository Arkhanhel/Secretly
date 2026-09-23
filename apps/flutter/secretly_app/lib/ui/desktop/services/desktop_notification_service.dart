// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart'
    show ValueNotifier, VoidCallback, debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_controller.dart';
import '../../../calls/call_manager.dart';
import '../../../calls/call_state.dart';
import '../../../l10n/app_localizations.dart';
import '../calls/call_peer_label.dart';

/// Desktop-only system-notification bridge.
///
/// Listens to AppController's [AppController.inAppNotifications] stream for
/// new incoming messages and to [CallManager.state] for ringing-incoming
/// calls. When the app window is *not* focused, fires a local notification
/// via flutter_local_notifications. Tapping a notification surfaces the
/// matching conversation through [onTap].
///
/// Strict scope: mobile (iOS / Android) notification flow lives in
/// [AppController] and is untouched. This service is only constructed from
/// the desktop production app and runs only when running on a desktop OS.
///
/// Screen-share guard: callers may set [setScreenShareActive] to true to
/// suppress all notifications while a desktop screen-share is in progress
/// (per TZ §9.2). Desktop screen-share UI is not yet wired, so the flag
/// stays false by default.
/// Текст баннера входящего звонка.
///
/// 🔴 Уровень приватности 0 обещает «ни отправителя, ни текста», и для
/// сообщений это соблюдалось, а звонок называл человека по имени. Теперь на
/// нулевом уровне в баннере только название приложения — как у неизвестного
/// звонящего.
@visibleForTesting
String desktopCallNotificationBody({
  required int previewLevel,
  required String knownName,
  required String appTitle,
}) {
  final name = knownName.trim();
  if (previewLevel < 1 || name.isEmpty) return appTitle;
  return name;
}

class DesktopNotificationService {
  DesktopNotificationService({required this.controller});

  /// Set by the desktop app shell once the service is up, mirroring
  /// [CallManager.instance] — lets the Settings pane reach the live instance
  /// without threading it through the widget tree.
  static DesktopNotificationService? instance;

  static const String _prefsPreviewLevelKey = 'desktop_notif_preview_level_v1';

  /// The SHARED notification-privacy key the controller owns
  /// (`_prefsNotifPrivacyLevelKey` in app_controller.dart). Read directly so a
  /// level set on the phone applies here before the controller is even up.
  static const String _prefsSharedPrivacyLevelKey = 'notif_privacy_level_v1';
  /// Per-scope switches, SHARED with mobile (`notif_private_chats_v1` /
  /// `notif_groups_v1`). Muting rooms while keeping direct messages is the
  /// single most useful notification control on a desktop, where a busy room
  /// can otherwise make the whole feature unusable — and because the keys are
  /// shared, the choice follows the profile to the phone.
  static const String _prefsPrivateChatsKey = 'notif_private_chats_v1';
  static const String _prefsGroupsKey = 'notif_groups_v1';

  static const String _prefsSoundKey = 'desktop_notif_sound_v1';
  static const String _prefsDoNotDisturbKey = 'desktop_notif_dnd_v1';

  final AppController controller;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _tapController =
      StreamController<String>.broadcast();

  StreamSubscription<ChatNotifEvent>? _inAppSub;
  VoidCallback? _callListener;
  CallManager? _callManager;
  SharedPreferences? _prefs;

  bool _ready = false;
  bool _windowFocused = true;

  /// Пропускает ли САМА СИСТЕМА уведомления этого приложения.
  ///
  /// 🔴 ЭТОТ ОТВЕТ ВЫБРАСЫВАЛСЯ, И ЭТО БЫЛА МОЛЧАЛИВАЯ ПОТЕРЯ СООБЩЕНИЙ.
  ///
  /// Разрешение запрашивалось (`requestPermissions`), но результат уходил в
  /// никуда: `unawaited(...catchError((_) => false))`. Приложение не знало
  /// отказа — и вело себя так, будто его нет.
  ///
  /// Чем это кончается на компьютере. Окно живёт в трее и большую часть
  /// времени спрятано; уведомление — ЕДИНСТВЕННЫЙ способ узнать о новом
  /// сообщении. Человек однажды нажал «Не разрешать» (или выключил их в
  /// системных настройках) — и с тех пор не получает ничего, а в разделе
  /// «Уведомления» все переключатели стоят включёнными и выглядят рабочими.
  /// Вывод, который он делает: «Secretly не доставляет сообщения». Это худший
  /// из возможных отказов — тот, который выглядит как исправная работа.
  ///
  /// `null` — ответа ещё нет или спрашивать некого: на Windows `local_notifier`
  /// разрешений не знает вовсе, и показывать там предупреждение значило бы
  /// пугать без причины.
  final ValueNotifier<bool?> systemAllowed = ValueNotifier<bool?>(null);
  bool _screenShareActive = false;
  String _lastNotifiedCallId = '';

  // Same 0/1/2 scale as mobile's globalNotificationPrivacyLevel: 0 = hidden
  // (neither sender nor text), 1 = sender only, 2 = sender + message text.
  int _previewLevel = 1;
  bool _privateChatsEnabled = true;
  bool _groupsEnabled = true;
  bool _soundEnabled = true;
  bool _doNotDisturb = false;

  /// Fires the convoId payload of a tapped notification.
  Stream<String> get onTap => _tapController.stream;

  int get previewLevel => _previewLevel;
  bool get privateChatsEnabled => _privateChatsEnabled;
  bool get groupsEnabled => _groupsEnabled;

  Future<void> setPrivateChatsEnabled(bool value) async {
    _privateChatsEnabled = value;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_prefsPrivateChatsKey, value);
  }

  Future<void> setGroupsEnabled(bool value) async {
    _groupsEnabled = value;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_prefsGroupsKey, value);
  }
  bool get soundEnabled => _soundEnabled;
  bool get doNotDisturb => _doNotDisturb;

  /// Sets the notification privacy level.
  ///
  /// Routed through the CONTROLLER, not written straight to preferences. The
  /// shared setter derives eleven other flags from this one number — show
  /// sender and show text, for private chats and for rooms, in both the
  /// current and legacy key namespaces — and then refreshes the push policy.
  /// Writing only the desktop key left the phone's notifications on the old
  /// level, so the same profile behaved differently depending on which device
  /// the change was made from.
  ///
  /// The desktop key is still written, so a desktop that boots before the
  /// controller is ready starts on the user's real choice rather than the
  /// default.
  Future<void> setPreviewLevel(int level) async {
    _previewLevel = level.clamp(0, 2);
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setInt(_prefsPreviewLevelKey, _previewLevel);
    try {
      await controller.setGlobalNotificationPrivacyLevel(_previewLevel);
    } catch (_) {
      // Local behaviour already changed; a failed shared write must not undo
      // what the user just asked for on this device.
    }
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_prefsSoundKey, value);
  }

  Future<void> setDoNotDisturb(bool value) async {
    _doNotDisturb = value;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_prefsDoNotDisturbKey, value);
  }

  /// Спросить систему заново, пропускает ли она наши уведомления.
  ///
  /// Вызывается после запроса разрешения и каждый раз, когда окно снова
  /// снова становится активным: человек уходит выключать или включать их в
  /// системных настройках и возвращается — и предупреждение должно исчезнуть
  /// само, без перезапуска.
  /// Чем спросить систему. Подменяется в тестах.
  ///
  /// Настоящий путь идёт в платформенный канал, которого в тесте нет, а на
  /// сборщике CI нет и самой macOS. Без этого шва проверка свелась бы к
  /// «на маке что-то произошло» — и молчала бы ровно там, где нужна.
  @visibleForTesting
  static Future<bool?> Function()? debugPermissionProbe;

  Future<void> refreshSystemPermission() async {
    final probe = debugPermissionProbe;
    if (probe != null) {
      final value = await probe();
      if (value != null) systemAllowed.value = value;
      return;
    }
    if (kIsWeb || !Platform.isMacOS) return;
    try {
      final macImpl = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macImpl == null) return;
      final opts = await macImpl.checkPermissions();
      // `null` — система не ответила. Это НЕ отказ: показать предупреждение
      // по молчанию значило бы обвинить систему без основания.
      if (opts == null) return;
      // Достаточно `isEnabled`: без него не покажется ничего. Отдельно
      // выключенные звук или плашка — это выбор человека, а не потеря.
      final allowed = opts.isEnabled;
      // В журнал — потому что это причина жалобы «сообщения не приходят», а
      // причина, которой нет в журнале, стоит поддержке часа расспросов.
      if (systemAllowed.value != allowed) {
        debugPrint('Sly/Diag: event=notif.system_permission allowed=$allowed');
      }
      systemAllowed.value = allowed;
    } catch (_) {
      // Канал недоступен — молчим. Прежнее значение остаётся: ложная тревога
      // хуже отсутствия тревоги.
    }
  }

  bool get _isDesktopOs =>
      !kIsWeb &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// 🔴 НА WINDOWS УВЕДОМЛЕНИЯ ПОКАЗЫВАЕТ ДРУГОЙ ПАКЕТ (19.09.2026).
  ///
  /// `flutter_local_notifications` 17-й версии Windows не поддерживает вовсе:
  /// его `initialize` там падает «нет реализации», и дальше служба считала себя
  /// неготовой — то есть на Windows не было НИ ОДНОГО уведомления. Поднимать
  /// версию нельзя: пакет общий с выпущенной мобильной сборкой. Поэтому на
  /// Windows показываем через `local_notifier`, на macOS — как раньше.
  bool get _usesLocalNotifier => !kIsWeb && Platform.isWindows;

  Future<void> init({CallManager? callManager}) async {
    if (!_isDesktopOs) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      // Prefer the SHARED key: a level chosen on the phone must govern here
      // too. The desktop key is only the fallback for a profile that has
      // never set one.
      final shared = prefs.getInt(_prefsSharedPrivacyLevelKey);
      _previewLevel =
          (shared ?? prefs.getInt(_prefsPreviewLevelKey) ?? 1).clamp(0, 2);
      _privateChatsEnabled = prefs.getBool(_prefsPrivateChatsKey) ?? true;
      _groupsEnabled = prefs.getBool(_prefsGroupsKey) ?? true;
      _soundEnabled = prefs.getBool(_prefsSoundKey) ?? true;
      _doNotDisturb = prefs.getBool(_prefsDoNotDisturbKey) ?? false;
    } catch (_) {
      // fall back to in-memory defaults
    }
    if (_usesLocalNotifier) {
      try {
        // Имя нужно самой системе Windows: уведомления показываются от имени
        // ярлыка приложения.
        await localNotifier.setup(appName: 'Secretly');
        _ready = true;
      } catch (_) {
        _ready = false;
        return;
      }
      _inAppSub?.cancel();
      _inAppSub = controller.inAppNotifications.listen(_onChatEvent);
      _attachCallManager(callManager);
      return;
    }
    try {
      const macSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      final linuxSettings = LinuxInitializationSettings(
        defaultActionName: _l10n.desktopNotifOpen,
      );
      final initSettings = InitializationSettings(
        macOS: macSettings,
        linux: linuxSettings,
      );
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onResponse,
      );
      // Permission prompt is implicit via DarwinInitializationSettings on
      // macOS; explicit call below makes the prompt deterministic if the
      // bundle entitlement hasn't been granted yet.
      //
      // CRITICAL: the system "Allow notifications?" dialog can block boot
      // indefinitely if the user doesn't dismiss it (observed on first run
      // under sandbox). The permission outcome is non-essential for app
      // startup — we fire-and-forget so the splash can dismiss and the
      // shell renders even when the prompt is still on-screen.
      final macImpl = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macImpl != null) {
        // Ответ на запрос больше НЕ выбрасывается: за ним сразу идёт сверка с
        // системой. Ожидание по-прежнему не блокирует запуск (см. выше про
        // окно, способное висеть бесконечно) — поэтому `unawaited`, а не
        // `await`, и проверка навешена продолжением.
        unawaited(
          macImpl
              .requestPermissions(alert: true, badge: true, sound: true)
              .catchError((_) => false)
              .whenComplete(refreshSystemPermission),
        );
      }
      _ready = true;
    } catch (_) {
      _ready = false;
      return;
    }

    _inAppSub?.cancel();
    _inAppSub = controller.inAppNotifications.listen(_onChatEvent);

    _attachCallManager(callManager);
  }

  /// Re-bind to a fresh [CallManager] after a controller restart.
  void attachCallManager(CallManager? cm) {
    if (!_isDesktopOs) return;
    _attachCallManager(cm);
  }

  void _attachCallManager(CallManager? cm) {
    _detachCallManager();
    if (cm == null) return;
    _callManager = cm;
    _callListener = () => _onCallStateChanged(cm.state.value);
    cm.state.addListener(_callListener!);
  }

  void _detachCallManager() {
    final cm = _callManager;
    final listener = _callListener;
    if (cm != null && listener != null) {
      try {
        cm.state.removeListener(listener);
      } catch (_) {}
    }
    _callListener = null;
    _callManager = null;
  }

  void setWindowFocused(bool focused) {
    // Вернулись в окно — самый вероятный момент, когда разрешение только что
    // поменяли в системных настройках.
    if (focused && !_windowFocused) unawaited(refreshSystemPermission());
    _windowFocused = focused;
  }

  void setScreenShareActive(bool active) {
    _screenShareActive = active;
  }

  AppLocalizations get _l10n =>
      lookupAppLocalizations(PlatformDispatcher.instance.locale);

  Future<void> _onChatEvent(ChatNotifEvent evt) async {
    if (!_ready ||
        _windowFocused ||
        _screenShareActive ||
        _doNotDisturb) {
      return;
    }
    // Rooms and direct chats are muted independently. `group:` is the same
    // convo-id prefix the rest of the app uses to tell them apart.
    final isRoom = evt.convoId.startsWith('group:');
    if (isRoom && !_groupsEnabled) return;
    if (!isRoom && !_privateChatsEnabled) return;

    final id = (evt.convoId.hashCode & 0x7fffffff);
    // Same 0/1/2 preview scale as mobile: redact sender/text before it ever
    // reaches the OS notification center when the user asked for privacy.
    final showSender = _previewLevel >= 1;
    final showText = _previewLevel >= 2;
    final title = showSender ? evt.title : _l10n.appTitle;
    final body = showText ? evt.body : _l10n.notificationBodyNewMessage;
    await _present(id: id, title: title, body: body, payload: evt.convoId);
  }

  /// Показывает уведомление тем способом, который умеет эта система.
  ///
  /// Нажатие ведёт в ту же переписку обоими путями: полоса уведомлений
  /// бесполезна, если по ней нельзя попасть в разговор.
  Future<void> _present({
    required int id,
    required String title,
    required String body,
    required String payload,
    bool timeSensitive = false,
  }) async {
    if (_usesLocalNotifier) {
      try {
        final notification = LocalNotification(
          title: title,
          body: body,
          silent: !_soundEnabled,
        );
        notification.onClick = () => _tapController.add(payload);
        await notification.show();
      } catch (_) {
        // Система могла отказать (нет ярлыка, выключены уведомления) — это не
        // повод ронять приём сообщений.
      }
      return;
    }
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: _soundEnabled,
            interruptionLevel: timeSensitive
                ? InterruptionLevel.timeSensitive
                : null,
          ),
          linux: const LinuxNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (_) {}
  }

  void _onCallStateChanged(CallState s) {
    if (!_ready || _windowFocused || _screenShareActive || _doNotDisturb) {
      return;
    }
    if (s.phase != CallPhase.ringingIncoming) {
      _lastNotifiedCallId = '';
      return;
    }
    if (s.callId.isEmpty || s.callId == _lastNotifiedCallId) return;
    _lastNotifiedCallId = s.callId;
    // Без сырого profile_id: неизвестного подписывает заголовок, а в тексте —
    // название приложения (17.09.2026).
    final caller = desktopCallNotificationBody(
      previewLevel: _previewLevel,
      knownName: desktopCallPeerKnownName(s),
      appTitle: _l10n.appTitle,
    );
    final title = s.isVideo
        ? _l10n.callVideoCall
        : _l10n.callRecordIncomingCall;
    final id = (('call:${s.callId}').hashCode & 0x7fffffff);
    unawaited(
      _present(
        id: id,
        title: title,
        body: caller,
        payload: 'call:${s.callId}',
        timeSensitive: true,
      ),
    );
  }

  void _onResponse(NotificationResponse response) {
    final payload = response.payload?.trim() ?? '';
    if (payload.isEmpty) return;
    _tapController.add(payload);
  }

  Future<void> dispose() async {
    await _inAppSub?.cancel();
    _inAppSub = null;
    _detachCallManager();
    if (!_tapController.isClosed) {
      await _tapController.close();
    }
    _ready = false;
  }
}
