// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart'
    show ValueNotifier, VoidCallback, debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_controller.dart';
import '../../../calls/call_manager.dart';
import '../../../calls/call_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../rooms/room_call_media_state.dart' show RoomCallRuntimeState;
import '../calls/call_peer_label.dart';
import 'desktop_child_windows.dart';
import 'desktop_notification_windows.dart';
import 'desktop_sounds.dart';
import 'desktop_taskbar.dart';

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
/// Screen-share guard: [setScreenShareActive] suppresses all notifications
/// while this desktop shares its screen (per TZ §9.2). The root wires it from
/// both the 1:1 call and the room call — see [desktopScreenShareActive].
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

/// Показывать ли в баннере кнопки «Ответить» и «Прочитано».
///
/// 🔴 ТОЛЬКО КОГДА ОТПРАВИТЕЛЬ НАЗВАН. На нулевом уровне показа баннер
/// сознательно не говорит, кто написал. Поле ответа на таком баннере позволило
/// бы любому, кто проходит мимо чужого компьютера, отправить сообщение в
/// переписку, которую баннер отказывается назвать, — а сам хозяин отвечать
/// вслепую всё равно не станет.
///
/// «Запросы» (`req:`) исключены отдельно: им ещё нечего отвечать, и телефон
/// поступает так же.
bool notificationActionsAllowed({
  required int previewLevel,
  required String convoId,
}) {
  if (previewLevel < 1) return false;
  final id = convoId.trim();
  if (id.isEmpty || id.startsWith('req:')) return false;
  return true;
}

/// Уровень показа уведомления с учётом замков.
///
/// 🔴 ЗАПЕРТОЕ ПРИЛОЖЕНИЕ ГОВОРИТ В УВЕДОМЛЕНИЯХ НЕ БОЛЬШЕ УРОВНЯ 0
/// (30.09.2026). Раньше замки уведомлений не касались: у запертого
/// компьютера баннер называл отправителя и показывал текст, а «Ответить»
/// отправляло сообщение — в том числе с компьютера, запертого как потерянный
/// (долго без связи). Пока заперто, — ни отправителя, ни текста, ни кнопок;
/// нажатие только выводит окно с замком. Так же с личной перепиской, пока
/// заперты «Личные».
@visibleForTesting
int desktopEffectivePreviewLevel({
  required int previewLevel,
  required bool locked,
  bool personalHidden = false,
}) => (locked || personalHidden) ? 0 : previewLevel.clamp(0, 2);

/// Показывает ли этот компьютер свой экран — в звонке один на один или в
/// созвоне комнаты.
///
/// 🔴 Защита «при показе экрана уведомления молчат» была, но включать её было
/// нечему (30.09.2026): имена и текст сообщений попадали в показ, а окошки
/// уведомлений Windows ещё и висят поверх всех окон.
bool desktopScreenShareActive({
  CallState? direct,
  RoomCallRuntimeState? room,
}) {
  if (direct != null && direct.isActive && direct.isScreenSharing) return true;
  if (room == null || !room.hasActiveSession) return false;
  if (room.localMedia.screenShareActive) return true;
  for (final p in room.participants) {
    if (p.isSelf && p.publishScreenShare) return true;
  }
  return false;
}

/// Молчим ли: насовсем или до срока, который ещё не наступил.
bool desktopDoNotDisturbActive({
  required bool forever,
  required int untilMs,
  required int nowMs,
}) =>
    forever || nowMs < untilMs;

/// Нажатие на служебное уведомление приложения выводит окно.
const String kDesktopNotificationShowAppPayload = 'app:show';

/// Настройки уведомлений macOS при запуске службы.
///
/// 🔴 НИ ОДНОГО ЗАПРОСА РАЗРЕШЕНИЯ ЗДЕСЬ (30.09.2026). `initialize` плагина
/// 17.2.4 с запросом отвечает только ПОСЛЕ ответа человека на системное
/// «Разрешить уведомления?», а запуск приложения этого ответа ждал: при первом
/// открытии заставка висела, пока человек не нажмёт кнопку в чужом окне.
/// Разрешение спрашивается отдельно и без ожидания (см.
/// [DesktopNotificationService.init]).
@visibleForTesting
DarwinInitializationSettings desktopMacNotificationInitSettings(
  List<DarwinNotificationCategory> categories,
) => DarwinInitializationSettings(
  requestAlertPermission: false,
  requestBadgePermission: false,
  requestSoundPermission: false,
  notificationCategories: categories,
);

/// Переводы для уведомлений — на языке приложения.
///
/// 🔴 `lookupAppLocalizations` БРОСАЕТ на языке, которого нет среди восьми
/// (итальянский, польский, японский…), а служба брала язык системы как есть
/// (30.09.2026). На такой системе macOS не поднимала уведомления вовсе — кнопки
/// баннера собираются при запуске, — а Windows молчала о звонках и о сообщениях
/// со скрытым текстом. Язык выбирается теми же правилами, что у окна
/// (`resolveAppUiLocale`: выбор человека, иначе язык системы, иначе
/// английский); не вышло и так — английский.
@visibleForTesting
AppLocalizations desktopNotificationStrings({
  required Locale Function(List<Locale> deviceLocales) resolve,
  required List<Locale> deviceLocales,
}) {
  try {
    return lookupAppLocalizations(resolve(deviceLocales));
  } catch (_) {
    return lookupAppLocalizations(const Locale('en'));
  }
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
  static const String _prefsWhileFocusedKey = 'desktop_notif_while_focused_v1';
  static const String _prefsDoNotDisturbKey = 'desktop_notif_dnd_v1';

  /// До какого момента молчать (мс эпохи), 0 — срока нет. Отдельно от
  /// «насовсем»: «на час» из трея не должно переживать этот час.
  static const String _prefsDoNotDisturbUntilKey =
      'desktop_notif_dnd_until_ms_v1';

  final AppController controller;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _tapController =
      StreamController<String>.broadcast();

  StreamSubscription<ChatNotifEvent>? _inAppSub;
  VoidCallback? _callListener;
  CallManager? _callManager;
  SharedPreferences? _prefs;

  /// 🔴 ЗВУК СООБЩЕНИЯ — ВЫБРАННЫЙ ЧЕЛОВЕКОМ (01.10.2026).
  ///
  /// Раньше звучал системный: на macOS — звук уведомлений системы, на Windows
  /// — «Notification.Default». Выбор из настроек не доходил никуда, а при
  /// окне на экране звучало ДВА звука: выбранный (его играл контроллер) и
  /// системный. Теперь контроллер на ПК молчит, а служба играет выбранный
  /// файл сама — ровно один раз на уведомление. Не заиграл — системный, как
  /// раньше: уведомление не должно остаться беззвучным.
  ///
  /// Подменяется в тестах.
  @visibleForTesting
  static DesktopMessageSound Function() createMessageSound =
      DesktopMessageSound.new;
  DesktopMessageSound? _messageSound;

  /// Разрешила ли система звук уведомлений этого приложения (macOS,
  /// «Уведомления → Secretly → Звук»). Свой звук обязан это уважать: раньше
  /// его выключала сама система.
  bool _systemSoundAllowed = true;

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
  bool _whileFocused = true;
  bool _doNotDisturb = false;
  int _doNotDisturbUntilMs = 0;
  Timer? _doNotDisturbExpiry;

  /// «Не беспокоить» сейчас — для трея и кнопки в шапке: оба обязаны
  /// показывать одно и то же и меняться сразу, в том числе когда срок истёк.
  final ValueNotifier<bool> doNotDisturbListenable = ValueNotifier<bool>(false);

  /// Fires the convoId payload of a tapped notification.
  /// Категория macOS, к которой привязаны кнопки в баннере.
  ///
  /// 🔴 ОТВЕТИТЬ И «ПРОЧИТАНО» ПРЯМО ИЗ УВЕДОМЛЕНИЯ. У телефона это есть с
  /// самого начала (`DarwinNotificationCategory` в `app_controller.dart`), а на
  /// компьютере не было — и разница заметнее, чем кажется: окно живёт в трее, и
  /// короткое «ок» требовало развернуть приложение и найти переписку.
  static const String _macCategoryId = 'secretly_message';
  static const String _macReplyActionId = 'secretly_reply';
  static const String _macMarkReadActionId = 'secretly_mark_read';

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

  /// Уведомлять о сообщениях из ДРУГИХ чатов, пока окно в фокусе.
  bool get notifyWhileFocused => _whileFocused;

  Future<void> setNotifyWhileFocused(bool value) async {
    _whileFocused = value;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_prefsWhileFocusedKey, value);
  }

  /// Переписка, открытая перед глазами, — о ней при окне в фокусе молчим.
  /// Задаёт корень приложения: выбор знает он, а не служба.
  String Function()? openConvoId;

  /// Заперто ли приложение хоть одним замком — см.
  /// [desktopEffectivePreviewLevel]. Задаёт корень: замки знает он.
  bool Function()? lockEngaged;

  /// Личная ли это переписка при запертых «Личных». Задаёт корень.
  bool Function(String convoId)? personalHidden;

  bool get _locked => lockEngaged?.call() ?? false;

  /// Кнопки уведомления (ответ, «прочитано») под замком не работают — даже у
  /// баннера, показанного ДО замка: он остаётся в центре уведомлений.
  bool _actionsBlocked(String convoId) =>
      _locked || (personalHidden?.call(convoId) ?? false);
  /// Молчим ли сейчас: насовсем или до срока, который ещё не наступил.
  bool get doNotDisturb => desktopDoNotDisturbActive(
        forever: _doNotDisturb,
        untilMs: _doNotDisturbUntilMs,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );

  /// До какого момента молчим, если срок задан и не истёк.
  DateTime? get doNotDisturbUntil {
    if (_doNotDisturb) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_doNotDisturbUntilMs <= now) return null;
    return DateTime.fromMillisecondsSinceEpoch(_doNotDisturbUntilMs);
  }

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
    // И включение насовсем, и выключение отменяют срок: «включить звук»
    // после «на час» значит включить его сейчас.
    _doNotDisturbUntilMs = 0;
    _armDoNotDisturbExpiry();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_prefsDoNotDisturbKey, value);
    await prefs.setInt(_prefsDoNotDisturbUntilKey, 0);
  }

  /// «Без звука» на [duration]; `null` — пока не включат (как в трее
  /// Telegram: «на час», «на 8 часов», «пока не включу»).
  Future<void> setDoNotDisturbFor(Duration? duration) async {
    if (duration == null) {
      await setDoNotDisturb(true);
      return;
    }
    _doNotDisturb = false;
    _doNotDisturbUntilMs =
        DateTime.now().add(duration).millisecondsSinceEpoch;
    _armDoNotDisturbExpiry();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_prefsDoNotDisturbKey, false);
    await prefs.setInt(_prefsDoNotDisturbUntilKey, _doNotDisturbUntilMs);
  }

  /// Держит [doNotDisturbListenable] верным: сразу и в момент, когда срок
  /// истекает, — иначе значок трея остался бы «без звука» после часа.
  void _armDoNotDisturbExpiry() {
    _doNotDisturbExpiry?.cancel();
    _doNotDisturbExpiry = null;
    doNotDisturbListenable.value = doNotDisturb;
    final left =
        _doNotDisturbUntilMs - DateTime.now().millisecondsSinceEpoch;
    if (!_doNotDisturb && left > 0) {
      _doNotDisturbExpiry = Timer(
        Duration(milliseconds: left + 50),
        _armDoNotDisturbExpiry,
      );
    }
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
      // Звук играет приложение само (см. [createMessageSound]) — и молчит,
      // если человек выключил звук Secretly в настройках системы.
      _systemSoundAllowed = opts.isSoundEnabled;
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
      _whileFocused = prefs.getBool(_prefsWhileFocusedKey) ?? true;
      _doNotDisturb = prefs.getBool(_prefsDoNotDisturbKey) ?? false;
      _doNotDisturbUntilMs = prefs.getInt(_prefsDoNotDisturbUntilKey) ?? 0;
      _armDoNotDisturbExpiry();
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
      final macSettings = desktopMacNotificationInitSettings(_macCategories());
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
      // The permission prompt comes ONLY from the explicit call below:
      // `initialize` asks nothing (see [desktopMacNotificationInitSettings]).
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

  /// «Звук в открытом чате» (01.10.2026): сообщение пришло в переписку, что
  /// открыта в окне в фокусе. Уведомления нет — её и так видно, — но тихий
  /// звук есть, как у телефона. Со своим выключателем (ключ телефона),
  /// «Звуком» уведомлений и звуком самой переписки; «Без звука» и показ
  /// экрана отсекает вызывающий. Комнаты и личные чаты глушатся так же, как
  /// их уведомления.
  Future<void> _playOpenChatSound(String convoId) async {
    final isRoom = convoId.startsWith('group:');
    if (isRoom ? !_groupsEnabled : !_privateChatsEnabled) return;
    if (!_soundEnabled || !_chatSoundOn(convoId)) return;
    final prefs = _prefs;
    if (prefs != null && !DesktopSounds.readInChatEnabled(prefs)) return;
    await (_messageSound ??= createMessageSound()).play(
      DesktopSoundKind.inChat,
    );
  }

  /// Выключен ли звук у этой переписки (её собственные настройки уведомлений
  /// — тот же ключ, что читает контроллер).
  bool _chatSoundOn(String convoId) =>
      _prefs?.getBool('chat_notif_v1_${convoId.trim()}_sound') ?? true;

  /// Сыграть выбранный звук сообщения. `false` — не вышло или нельзя.
  Future<bool> _playMessageSound() async {
    // macOS: звук Secretly выключен в системе или уведомления запрещены —
    // системный звук молчал бы, и свой молчит.
    if (Platform.isMacOS &&
        (!_systemSoundAllowed || systemAllowed.value == false)) {
      return false;
    }
    return (_messageSound ??= createMessageSound()).play(
      DesktopSoundKind.message,
    );
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

  AppLocalizations get _l10n => desktopNotificationStrings(
    resolve: controller.resolveAppUiLocale,
    deviceLocales: PlatformDispatcher.instance.locales,
  );

  Future<void> _onChatEvent(ChatNotifEvent evt) async {
    if (!_ready || _screenShareActive || doNotDisturb) return;
    final focused = _windowFocused;
    final open = openConvoId?.call() ?? '';
    if (focused &&
        !desktopNotifyWhileFocused(
          enabled: _whileFocused,
          openConvoId: open,
          convoId: evt.convoId,
        )) {
      if (desktopIsOpenConvo(openConvoId: open, convoId: evt.convoId)) {
        await _playOpenChatSound(evt.convoId);
      }
      return;
    }
    // Rooms and direct chats are muted independently. `group:` is the same
    // convo-id prefix the rest of the app uses to tell them apart.
    final isRoom = evt.convoId.startsWith('group:');
    if (isRoom && !_groupsEnabled) return;
    if (!isRoom && !_privateChatsEnabled) return;

    final id = (evt.convoId.hashCode & 0x7fffffff);
    // Same 0/1/2 preview scale as mobile: redact sender/text before it ever
    // reaches the OS notification center when the user asked for privacy —
    // or when the app is locked (see [desktopEffectivePreviewLevel]).
    final level = desktopEffectivePreviewLevel(
      previewLevel: _previewLevel,
      locked: _locked,
      personalHidden: personalHidden?.call(evt.convoId) ?? false,
    );
    final showSender = level >= 1;
    final showText = level >= 2;
    final title = showSender ? evt.title : _l10n.appTitle;
    final body = showText ? evt.body : _l10n.notificationBodyNewMessage;
    final canAct = notificationActionsAllowed(
      previewLevel: level,
      convoId: evt.convoId,
    );
    // Windows: кнопка окна на панели задач мигает, пока окно не выйдет вперёд
    // (как у Telegram); спрятанное в трей окно кнопки не имеет. Окно впереди
    // мигать незачем — оно и так перед глазами.
    if (!focused) unawaited(DesktopTaskbar.flash());
    await _present(
      id: id,
      title: title,
      body: body,
      payload: evt.convoId,
      withActions: canAct,
      // Портрет — только когда имя отправителя можно показывать.
      avatarPath: showSender ? evt.avatarPath : null,
      avatarSeed: showSender ? evt.avatarSeed : null,
      // Звук — выбранный человеком; у переписки, где звук выключен, — никакого.
      sound: _soundEnabled && _chatSoundOn(evt.convoId),
      ownSound: _playMessageSound,
    );
  }

  /// Входящий звонок уже показан своим окном поверх всех (Р1) — системное
  /// уведомление о нём не нужно. Задаёт корень приложения.
  static bool Function(CallState s)? callShownInOwnWindow;

  /// Окно звонка не открылось или закрылось — сверить уведомление о входящем
  /// заново. Пока звонок числился «в своём окне», уведомление пропускали, а
  /// следующего изменения звонка могло и не быть: входящий молчал.
  void recheckIncomingCall() {
    final cm = _callManager;
    if (cm != null) _onCallStateChanged(cm.state.value);
  }

  /// Показывает уведомление тем способом, который умеет эта система.
  ///
  /// Нажатие ведёт в ту же переписку обоими путями: полоса уведомлений
  /// бесполезна, если по ней нельзя попасть в разговор.
  /// Кнопки в баннере. Подписи — те же, что у телефона: одно действие не может
  /// называться на двух устройствах по-разному.
  List<DarwinNotificationCategory> _macCategories() =>
      <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          _macCategoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.text(
              _macReplyActionId,
              _l10n.chatMenuReply,
              buttonTitle: _l10n.send,
              placeholder: _l10n.messageHint,
            ),
            DarwinNotificationAction.plain(
              _macMarkReadActionId,
              _l10n.notificationActionMarkRead,
            ),
          ],
        ),
      ];

  /// Разовое служебное уведомление от самого приложения — например, первое
  /// «Secretly работает в фоне» после того, как окно спрятали в трей.
  ///
  /// Не проверяет «окно в фокусе» и «не беспокоить»: его показывают ровно в
  /// тот момент, когда окно уходит с экрана, и ровно один раз.
  Future<void> showAppNotice({
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    await _present(
      id: 0x5ec7,
      title: title,
      body: body,
      payload: kDesktopNotificationShowAppPayload,
    );
  }

  Future<void> _present({
    required int id,
    required String title,
    required String body,
    required String payload,
    bool timeSensitive = false,

    /// Показывать ли кнопки «Ответить» и «Прочитано». Решение принимает
    /// вызывающий: у звонка их быть не должно, у сообщения — должны, но только
    /// когда отправитель назван.
    bool withActions = false,
    String? avatarPath,
    String? avatarSeed,

    /// Звучать ли; `null` — по «Звуку» уведомлений.
    bool? sound,

    /// Свой звук вместо системного (звук сообщения, выбранный человеком);
    /// `false` — не заиграл, и тогда звучит системный. `null` — системный,
    /// как у звонка и служебных уведомлений.
    Future<bool> Function()? ownSound,
  }) async {
    final withSound = sound ?? _soundEnabled;
    // 🔴 WINDOWS — СВОИ ОКОШКИ, КАК У TELEGRAM (29.09.2026, владелец:
    // «уведомления как будто системные Windows, хочу как в Telegram»).
    // Не вышло — системное уведомление ниже, как раньше.
    if (_usesLocalNotifier && DesktopNotificationWindows.instance.enabled) {
      final shown = await DesktopNotificationWindows.instance.present(
        DesktopNotificationCard(
          title: title,
          body: body,
          payload: payload,
          avatarPath: avatarPath,
          avatarSeed: avatarSeed,
          canAct: withActions,
        ),
        sound: withSound && ownSound == null,
        onTap: () => _tapController.add(payload),
        // «Ответить» и «Прочитано» прямо в окошке — как в Telegram и как
        // кнопки системного уведомления macOS (тот же путь отправки).
        onReply: withActions ? (text) => _sendReply(payload, text) : null,
        onMarkRead: withActions ? () => _markRead(payload) : null,
      );
      // Окошко своё — и звук свой; не заиграл — звук системы, как раньше.
      if (shown && withSound && ownSound != null && !await ownSound()) {
        unawaited(DesktopChildWindows.instance.playNotificationSound());
      }
      if (shown) return;
    }
    if (_usesLocalNotifier) {
      // Системное уведомление Windows (своё окошко выключено или Windows
      // просит не беспокоить) — со звуком системы: когда молчать, решает она.
      try {
        final notification = LocalNotification(
          title: title,
          body: body,
          silent: !withSound,
        );
        notification.onClick = () => _tapController.add(payload);
        await notification.show();
      } catch (_) {
        // Система могла отказать (нет ярлыка, выключены уведомления) — это не
        // повод ронять приём сообщений.
      }
      return;
    }
    // macOS: свой звук — до показа, чтобы знать, нужен ли системный.
    final own = withSound && ownSound != null && await ownSound();
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: withSound && !own,
            // 🔴 Группировка ПО ПЕРЕПИСКЕ. Без неё оживший разговор оставляет
            // столбик отдельных баннеров, в котором не видно, сколько человек
            // писало. Система складывает их в одну стопку — как на телефоне.
            threadIdentifier: payload.isEmpty ? null : payload,
            categoryIdentifier: withActions ? _macCategoryId : null,
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
    if (!_ready || _windowFocused || _screenShareActive || doNotDisturb) {
      return;
    }
    if (s.phase != CallPhase.ringingIncoming) {
      _lastNotifiedCallId = '';
      return;
    }
    if (s.callId.isEmpty || s.callId == _lastNotifiedCallId) return;
    if (callShownInOwnWindow?.call(s) ?? false) return;
    _lastNotifiedCallId = s.callId;
    // Без сырого profile_id: неизвестного подписывает заголовок, а в тексте —
    // название приложения (17.09.2026).
    final caller = desktopCallNotificationBody(
      previewLevel: desktopEffectivePreviewLevel(
        previewLevel: _previewLevel,
        locked: _locked,
      ),
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
    if (response.notificationResponseType ==
        NotificationResponseType.selectedNotificationAction) {
      unawaited(_handleAction(response, payload));
      return;
    }
    _tapController.add(payload);
  }

  /// Нажали кнопку в баннере.
  ///
  /// 🔴 Зовутся ТЕ ЖЕ открытые вызовы контроллера, которыми пользуется телефон
  /// (`sendMessage` / `sendGroupMessage` / `markChatRead`). Своего пути отправки
  /// здесь нет и быть не должно: сообщение, ушедшее мимо общего пути, прошло бы
  /// мимо очереди, повторов и шифрования комнаты.
  Future<void> _handleAction(
    NotificationResponse response,
    String convoId,
  ) async {
    final actionId = (response.actionId ?? '').trim();
    try {
      if (actionId == _macReplyActionId) {
        await _sendReply(convoId, response.input ?? '');
        return;
      }
      if (actionId == _macMarkReadActionId) {
        await _markRead(convoId);
      }
    } catch (_) {
      // Отправка из баннера — удобство, а не единственный путь: провал не
      // должен ронять приём сообщений. Человек увидит, что ответа нет, в самой
      // переписке — там же, где его обычно и проверяет.
    }
  }

  /// Ответ из уведомления — баннера macOS или своего окошка Windows. Один
  /// путь на оба: общий вызов контроллера, с очередью, повторами и
  /// шифрованием комнаты.
  Future<void> _sendReply(String convoId, String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    if (_actionsBlocked(convoId)) return;
    if (convoId.startsWith('group:')) {
      await controller.sendGroupMessage(groupId: convoId, text: text);
    } else {
      await controller.sendMessage(peerProfileId: convoId, text: text);
    }
  }

  Future<void> _markRead(String convoId) async {
    if (_actionsBlocked(convoId)) return;
    await controller.markChatRead(peerProfileId: convoId);
  }

  Future<void> dispose() async {
    await _inAppSub?.cancel();
    _inAppSub = null;
    final sound = _messageSound;
    _messageSound = null;
    await sound?.dispose();
    _detachCallManager();
    if (!_tapController.isClosed) {
      await _tapController.close();
    }
    _ready = false;
  }
}

/// Показывать ли уведомление о сообщении, когда окно Secretly в фокусе.
///
/// 🔴 КАК В TELEGRAM DESKTOP (30.09.2026, ТЗ «ПК как Telegram» §5, этап 1).
/// Раньше окно в фокусе глушило ВСЁ: человек переписывался с одним — и не
/// знал, что пишет другой, пока случайно не заглянет в список. Молчим только
/// об открытой переписке — её и так видно; о других чатах — то же окошко со
/// звуком, что и при свёрнутом окне. Выключается в «Уведомлениях».
@visibleForTesting
bool desktopNotifyWhileFocused({
  required bool enabled,
  required String openConvoId,
  required String convoId,
}) {
  if (!enabled) return false;
  final open = openConvoId.trim();
  return open.isEmpty || open != convoId.trim();
}

/// Это сообщение — в переписку, открытую в окне (01.10.2026)? Тогда вместо
/// уведомления — «звук в открытом чате».
@visibleForTesting
bool desktopIsOpenConvo({required String openConvoId, required String convoId}) {
  final open = openConvoId.trim();
  return open.isNotEmpty && open == convoId.trim();
}
