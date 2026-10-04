// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the desktop UI strings have actually been localised.
///
/// 🔴 ON since 19.09.2026, when the last desktop label moved into
/// `lib/l10n/app_*.arb` (TZ §5, L-2 and L-3). Two literals remain and always
/// will: «Русский» and «Українська» in the language list itself, because
/// language names are not translated.
///
/// Before that the picker was a placebo: it genuinely switched the locale, but
/// only Material's own widgets followed, so the user got an English "Cancel"
/// inside an entirely Russian app. That is why the row was gated on a flag
/// rather than deleted — and why turning it on is this one line.
///
/// The guard is `test/desktop_l10n_ratchet_test.dart`: it holds the desktop
/// literal count at its floor, so the flag cannot quietly become a lie again.
const bool kDesktopUiLocalized = true;

/// Decides whether the Enter key press currently in hand should SEND.
///
/// With «Enter отправляет» on, plain Enter sends and Shift+Enter breaks the
/// line; with it off the two swap. Kept as a free function so the rule itself
/// is testable — the composer's key handler is otherwise reachable only
/// through a full widget pump.
bool shouldSendOnEnter({
  required bool enterToSend,
  required bool shiftPressed,
}) =>
    enterToSend ? !shiftPressed : shiftPressed;

/// Persisted desktop-only UI preferences.
///
/// These settings existed in the UI but were pure local widget state: flipping
/// a switch updated a `bool` in a `State` object, changed nothing, and reset on
/// restart. Storing them here — and having the composer actually read them —
/// is what makes those rows honest (principle P-5: no dead affordances).
///
/// Desktop-scoped keys on purpose, so the released mobile build is untouched.
/// Exposed as [ValueNotifier]s so a settings change reaches an already-open
/// chat without any plumbing between the two.
class DesktopUiPrefs {
  DesktopUiPrefs._();

  static const String _kEnterToSend = 'desktop_enter_to_send_v1';
  static const String _kThemeMode = 'desktop_theme_mode_v1';
  static const String _kCamera = 'desktop_preferred_camera_v1';
  static const String _kMic = 'desktop_preferred_mic_v1';
  static const String _kSpeaker = 'desktop_preferred_speaker_v1';
  static const String _kCustomAccent = 'desktop_custom_accent_v1';
  static const String _kTextScale = 'desktop_text_scale_v1';
  static const String _kHoverBar = 'desktop_message_hover_bar_v1';
  static const String _kLinkPreviews = 'desktop_link_previews_v1';
  static const String _kDoubleClickReply = 'desktop_double_click_reply_v1';
  static const String _kPlayerVolume = 'desktop_player_volume_v1';
  static const String _kCallMiniCorner = 'desktop_call_mini_corner_v1';
  static const String _kTrayHintShown = 'desktop_tray_hint_shown_v1';
  static const String _kCloseToTray = 'desktop_close_to_tray_v1';
  static const String _kStartMinimized = 'desktop_start_minimized_v1';
  static const String _kCallInOwnWindow = 'desktop_call_in_own_window_v1';
  static const String _kCallWindowPinned = 'desktop_call_window_pinned_v1';
  static const String _kCustomNotifications = 'desktop_custom_notifications_v1';
  static const String _kMessageDensity = 'desktop_message_density_v1';
  static const String _kBubbleShape = 'desktop_bubble_shape_v1';
  static const String _kWallpaperDim = 'desktop_wallpaper_dim_v1';
  static const String _kSenderNameColors = 'desktop_sender_name_colors_v1';

  /// Enter sends the message; Shift+Enter inserts a newline. When false the
  /// roles swap, which is what people coming from IDE-style chats expect.
  static final ValueNotifier<bool> enterToSend = ValueNotifier<bool>(true);

  /// Показывать ли над сообщением строку действий при наведении мыши.
  ///
  /// 🔴 ВЫКЛЮЧАЕМАЯ (указание владельца 16.09.2026). Кому-то строка мешает
  /// читать: курсор просто лежит на ленте, а над пузырём то и дело всплывают
  /// кнопки. Всё, что есть в строке, доступно и по правой кнопке мыши, так что
  /// без неё ничего не теряется.
  static final ValueNotifier<bool> messageHoverBar = ValueNotifier<bool>(true);

  /// Готовить ли карточку ссылки, которую человек отправляет.
  ///
  /// 🔴 КАРТОЧКУ ГОТОВИТ ОТПРАВИТЕЛЬ (16.09.2026): чтобы её собрать, окно
  /// само открывает страницу — и сайт узнаёт адрес компьютера. Кому это не
  /// подходит, выключает, как в Signal. Выключено — окно не ходит за
  /// страницами вовсе: ни для поля ввода, ни для своих прежних сообщений.
  /// Карточки, которые пришли в сообщениях, видны всегда — за ними в сеть
  /// никто не ходит.
  static final ValueNotifier<bool> linkPreviews = ValueNotifier<bool>(true);

  /// Двойной щелчок по сообщению (мимо текста) — ответ на него, как в
  /// Telegram Desktop. Включено по умолчанию, как там.
  static final ValueNotifier<bool> doubleClickReply = ValueNotifier<bool>(
    true,
  );

  /// Как выбирается светлая или тёмная схема: 'dark', 'light' или 'auto'.
  ///
  /// 🔴 НАСТРОЙКА ДЕСКТОПНАЯ, И ЭТО ВАЖНО.
  ///
  /// Сама схема живёт в общем `AppController.darkMode`, но пишется она ТОЛЬКО
  /// в локальные `SharedPreferences` и с телефоном не синхронизируется —
  /// проверено по `setDarkMode`. Значит «Авто» можно завести целиком на
  /// стороне окна: десктоп смотрит на системную тему и сам ставит нужное
  /// значение, а телефон об этом ничего не узнаёт и продолжает жить со своим.
  ///
  /// Третьего состояния в контроллере нет и заводить его там нельзя: это
  /// изменило бы поведение выпущенного приложения.
  static final ValueNotifier<String> themeMode = ValueNotifier<String>('dark');

  /// Камера и микрофон, которые человек выбрал в настройках. Пусто — «как
  /// решит система».
  ///
  /// 🔴 НАСТРОЙКА ДЕСКТОПНАЯ И ПО ПРИРОДЕ. Камера у стола и камера в кармане —
  /// разные устройства, и синхронизировать их между телефоном и компьютером
  /// было бы прямой ошибкой: на телефоне такого выбора нет вовсе.
  ///
  /// Хранится ИДЕНТИФИКАТОР, а не имя: имена меняются при переподключении, а
  /// пропавшее устройство должно просто откатиться к системному, а не увести
  /// звонок в тишину.
  static final ValueNotifier<String> preferredCameraId =
      ValueNotifier<String>('');
  static final ValueNotifier<String> preferredMicId = ValueNotifier<String>('');

  /// Динамики или наушники для звонков. Пусто — «как в системе»: звук идёт
  /// туда, куда настроена ОС, и следует за ней (см. `call_audio_route.dart`).
  static final ValueNotifier<String> preferredSpeakerId =
      ValueNotifier<String>('');

  /// ◆ «Свой цвет» акцента, ARGB. Ноль — цвет не выбран, акцент берётся из
  /// схемы оформления.
  ///
  /// 🔴 НАСТРОЙКА ДЕСКТОПНАЯ, И ЭТО НЕ ЛЕНЬ.
  ///
  /// Схемы оформления лежат в общем `appThemePresetId`, но там хранится
  /// ИМЯ схемы из списка `kAppThemePresets`, а не цвет. Произвольному цвету
  /// имени в этом списке нет, и проверка `isValidAppThemePresetId` выбросит
  /// его молча: телефон, разворачивая резервную копию, откатился бы на схему
  /// по умолчанию, и человек нашёл бы свой цвет пропавшим без объяснения.
  ///
  /// Второе: окну от схемы нужны ровно ДВА цвета — акцент и его пара, —
  /// а `AppThemePreset` несёт два десятка, включая подложки и градиент
  /// шапки. Выводить их все из одного цвета значило бы придумать телефону
  /// внешний вид, которого никто не выбирал.
  static final ValueNotifier<int> customAccentArgb = ValueNotifier<int>(0);

  /// Размер текста в окне: множитель 1,0 — как нарисовано.
  ///
  /// 🔴 ЭТО РАЗМЕР ТЕКСТА, А НЕ МАСШТАБ ВСЕГО ОКНА, и названо так нарочно.
  /// Растянуть окно целиком значило бы растянуть отступы, значки и рамки — то
  /// есть пересчитать раскладку, выверенную по макету до точки. Текст же лежит
  /// в строках с ЗАДАННОЙ МИНИМАЛЬНОЙ высотой и растёт, не ломая их.
  ///
  /// Обещать «масштаб интерфейса», а дать размер текста было бы неправдой —
  /// подпись в настройках говорит ровно то, что делает переключатель.
  static final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

  /// Громкость плеера голосовых и песен, 0..1 (24.09.2026).
  ///
  /// Живёт здесь, а не в общем плеере: ползунок громкости есть только у
  /// островка «сейчас играет» на компьютере, а телефон громкость отдаёт
  /// системе. Помнится между запусками — как и в Telegram, выставленная
  /// громкость не должна сбрасываться в полную при каждом открытии окна.
  static final ValueNotifier<double> playerVolume = ValueNotifier<double>(1.0);

  /// Угол, к которому прилипает мини-окно свёрнутого звонка: `topLeft`,
  /// `topRight`, `bottomLeft`, `bottomRight`. Помнится между запусками —
  /// утащенное в свой угол мини-окно не должно в каждом звонке появляться
  /// в чужом.
  static final ValueNotifier<String> callMiniCorner =
      ValueNotifier<String>('topRight');

  /// Показана ли разовая подсказка «Secretly работает в фоне» при первом
  /// скрытии окна в трей. Без неё человек, закрывший окно крестиком, не знает,
  /// что приложение живо и где его искать.
  static final ValueNotifier<bool> trayHintShown = ValueNotifier<bool>(false);

  /// Крестик окна прячет Secretly в трей (как у Telegram), а не закрывает.
  /// Выключено — крестик закрывает приложение, и сообщения не придут, пока
  /// его не откроют снова.
  static final ValueNotifier<bool> closeToTray = ValueNotifier<bool>(true);

  static Future<void> setCloseToTray(bool value) async {
    closeToTray.value = value;
    await _persist(_kCloseToTray, value);
  }

  /// Звонок — в СВОЁМ окне ОС (29.09.2026, Р1). Выключено — как раньше,
  /// поверх главного окна. Работает там, где есть нативный слой окон.
  static final ValueNotifier<bool> callInOwnWindow = ValueNotifier<bool>(true);

  static Future<void> setCallInOwnWindow(bool value) async {
    callInOwnWindow.value = value;
    await _persist(_kCallInOwnWindow, value);
  }

  /// Окно звонка — «поверх всех окон». Запоминается между звонками.
  static final ValueNotifier<bool> callWindowPinned = ValueNotifier<bool>(false);

  static Future<void> setCallWindowPinned(bool value) async {
    callWindowPinned.value = value;
    await _persist(_kCallWindowPinned, value);
  }

  /// Уведомления своими окошками в углу экрана, как у Telegram (Windows).
  /// Выключено — системные уведомления Windows.
  static final ValueNotifier<bool> customNotifications = ValueNotifier<bool>(
    true,
  );

  static Future<void> setCustomNotifications(bool value) async {
    customNotifications.value = value;
    await _persist(_kCustomNotifications, value);
  }

  /// Windows: при автозапуске окно не открывается — приложение ждёт в трее.
  static final ValueNotifier<bool> startMinimized = ValueNotifier<bool>(true);

  static Future<void> setStartMinimized(bool value) async {
    startMinimized.value = value;
    await _persist(_kStartMinimized, value);
  }

  // ── Оформление переписки (29.09.2026, страница «Внешний вид» по макету
  // владельца) ─────────────────────────────────────────────────────────────
  //
  // 🔴 ТОЛЬКО ЭТОТ КОМПЬЮТЕР, А НЕ ОБЩИЙ КОНТРОЛЛЕР. Плотность ленты, форма
  // пузырей и затемнение обоев — свойства ОКНА: у телефона другой экран и своя
  // раскладка, и тянуть эти числа туда через общие настройки значило бы менять
  // выпущенную мобильную версию. Поэтому ключи десктопные, как у размера
  // текста.

  /// Плотность ленты: `cozy` — как было, `compact` — теснее строки и поля
  /// пузыря, в окно помещается больше сообщений.
  static const List<String> messageDensityValues = <String>['cozy', 'compact'];
  static final ValueNotifier<String> messageDensity =
      ValueNotifier<String>('cozy');

  static Future<void> setMessageDensity(String value) async {
    final v = _oneOf(value, messageDensityValues, 'cozy');
    messageDensity.value = v;
    await _persistString(_kMessageDensity, v);
  }

  /// Форма пузыря: `sharp`, `medium` (как было до 29.09) и `round`.
  static const List<String> bubbleShapeValues = <String>[
    'sharp',
    'medium',
    'round',
  ];
  static final ValueNotifier<String> bubbleShape =
      ValueNotifier<String>('medium');

  static Future<void> setBubbleShape(String value) async {
    final v = _oneOf(value, bubbleShapeValues, 'medium');
    bubbleShape.value = v;
    await _persistString(_kBubbleShape, v);
  }

  /// Затемнение обоев в процентах: 0…[wallpaperDimMax] шагом 5.
  ///
  /// Потолок 70, а не 100: при полном затемнении обоев не остаётся вовсе, и
  /// для этого есть честный выбор «Без обоев», а не ползунок до чёрного.
  static const int wallpaperDimMax = 70;
  static final ValueNotifier<int> wallpaperDim = ValueNotifier<int>(0);

  static int normalizeWallpaperDim(num? raw) {
    if (raw == null || !raw.isFinite) return 0;
    final stepped = (raw / 5).round() * 5;
    return stepped.clamp(0, wallpaperDimMax).toInt();
  }

  static Future<void> setWallpaperDim(int value) async {
    final v = normalizeWallpaperDim(value);
    wallpaperDim.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kWallpaperDim, v);
    } catch (_) {
      // В памяти уже применено; просто не переживёт перезапуск.
    }
  }

  /// Цвет имён в групповых чатах: `person` — у каждого свой, как у Telegram и
  /// телефона (было всегда); `preset` — один цвет для всех, из общей настройки
  /// «Цвет имени» (`nicknameStylePresetId`).
  static const List<String> senderNameColorsValues = <String>[
    'person',
    'preset',
  ];
  static final ValueNotifier<String> senderNameColors =
      ValueNotifier<String>('person');

  static Future<void> setSenderNameColors(String value) async {
    final v = _oneOf(value, senderNameColorsValues, 'person');
    senderNameColors.value = v;
    await _persistString(_kSenderNameColors, v);
  }

  static String _oneOf(String? raw, List<String> allowed, String fallback) {
    final v = (raw ?? '').trim();
    return allowed.contains(v) ? v : fallback;
  }

  static Future<void> markTrayHintShown() async {
    trayHintShown.value = true;
    await _persist(_kTrayHintShown, true);
  }

  /// Разрешённые ступени. Список закрытый: произвольное число из испорченной
  /// настройки не должно превращать окно в нечитаемое.
  static const List<double> textScaleSteps = <double>[0.9, 1.0, 1.15, 1.3, 1.5];

  /// Приводит любое значение к ближайшей ступени.
  static double normalizeTextScale(double? raw) {
    if (raw == null || !raw.isFinite) return 1.0;
    var best = 1.0;
    var bestDiff = double.infinity;
    for (final s in textScaleSteps) {
      final d = (s - raw).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = s;
      }
    }
    return best;
  }

  static bool _loaded = false;

  /// Loads persisted values. Safe to call more than once; later calls are
  /// no-ops so a restart-in-place cannot clobber a live edit.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      enterToSend.value = prefs.getBool(_kEnterToSend) ?? true;
      messageHoverBar.value = prefs.getBool(_kHoverBar) ?? true;
      linkPreviews.value = prefs.getBool(_kLinkPreviews) ?? true;
      doubleClickReply.value = prefs.getBool(_kDoubleClickReply) ?? true;
      themeMode.value = _normalizeThemeMode(prefs.getString(_kThemeMode));
      preferredCameraId.value = prefs.getString(_kCamera) ?? '';
      preferredMicId.value = prefs.getString(_kMic) ?? '';
      preferredSpeakerId.value = prefs.getString(_kSpeaker) ?? '';
      customAccentArgb.value = prefs.getInt(_kCustomAccent) ?? 0;
        textScale.value = normalizeTextScale(prefs.getDouble(_kTextScale));
      playerVolume.value = normalizePlayerVolume(
        prefs.getDouble(_kPlayerVolume),
      );
      callMiniCorner.value = prefs.getString(_kCallMiniCorner) ?? 'topRight';
      trayHintShown.value = prefs.getBool(_kTrayHintShown) ?? false;
      closeToTray.value = prefs.getBool(_kCloseToTray) ?? true;
      startMinimized.value = prefs.getBool(_kStartMinimized) ?? true;
      callInOwnWindow.value = prefs.getBool(_kCallInOwnWindow) ?? true;
      callWindowPinned.value = prefs.getBool(_kCallWindowPinned) ?? false;
      customNotifications.value = prefs.getBool(_kCustomNotifications) ?? true;
      messageDensity.value = _oneOf(
        prefs.getString(_kMessageDensity),
        messageDensityValues,
        'cozy',
      );
      bubbleShape.value = _oneOf(
        prefs.getString(_kBubbleShape),
        bubbleShapeValues,
        'medium',
      );
      wallpaperDim.value = normalizeWallpaperDim(prefs.getInt(_kWallpaperDim));
      senderNameColors.value = _oneOf(
        prefs.getString(_kSenderNameColors),
        senderNameColorsValues,
        'person',
      );
    } catch (_) {
      // Defaults already hold — a preferences failure must not block boot.
    }
    _loaded = true;
  }

  static Future<void> setTextScale(double value) async {
    final v = normalizeTextScale(value);
    textScale.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kTextScale, v);
    } catch (_) {
      // В памяти уже применено; просто не переживёт перезапуск.
    }
  }

  /// Приводит громкость к 0..1; испорченное значение — полная громкость.
  static double normalizePlayerVolume(double? raw) {
    if (raw == null || !raw.isFinite) return 1.0;
    return raw.clamp(0.0, 1.0).toDouble();
  }

  static Future<void> setPlayerVolume(double value) async {
    final v = normalizePlayerVolume(value);
    playerVolume.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kPlayerVolume, v);
    } catch (_) {
      // В памяти уже применено; просто не переживёт перезапуск.
    }
  }

  static Future<void> setCallMiniCorner(String value) async {
    callMiniCorner.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCallMiniCorner, value);
    } catch (_) {
      // В памяти уже применено; просто не переживёт перезапуск.
    }
  }

  static Future<void> setEnterToSend(bool value) async {
    enterToSend.value = value;
    await _persist(_kEnterToSend, value);
  }

  static Future<void> setMessageHoverBar(bool value) async {
    messageHoverBar.value = value;
    await _persist(_kHoverBar, value);
  }

  static Future<void> setLinkPreviews(bool value) async {
    linkPreviews.value = value;
    await _persist(_kLinkPreviews, value);
  }

  static Future<void> setDoubleClickReply(bool value) async {
    doubleClickReply.value = value;
    await _persist(_kDoubleClickReply, value);
  }

  /// Неизвестное значение считаем «тёмной»: так окно выглядело всегда, и
  /// испорченная настройка не должна менять вид без спроса.
  static String _normalizeThemeMode(String? raw) {
    final v = (raw ?? '').trim();
    return (v == 'light' || v == 'auto') ? v : 'dark';
  }

  static Future<void> setThemeMode(String value) async {
    themeMode.value = _normalizeThemeMode(value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeMode, themeMode.value);
    } catch (_) {
      // In-memory already changed; it simply won't survive a restart.
    }
  }

  static Future<void> setPreferredCamera(String deviceId) async {
    preferredCameraId.value = deviceId;
    await _persistString(_kCamera, deviceId);
  }

  static Future<void> setPreferredMic(String deviceId) async {
    preferredMicId.value = deviceId;
    await _persistString(_kMic, deviceId);
  }

  static Future<void> setPreferredSpeaker(String deviceId) async {
    preferredSpeakerId.value = deviceId;
    await _persistString(_kSpeaker, deviceId);
  }

  /// Ноль (и любое значение без непрозрачности) означает «цвета нет»:
  /// прозрачный акцент — это невидимая кнопка, а не оттенок.
  static Future<void> setCustomAccent(int argb) async {
    final v = argb == 0 ? 0 : (argb | 0xFF000000);
    customAccentArgb.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kCustomAccent, v);
    } catch (_) {
      // Уже применено в памяти; не переживёт перезапуск — и только.
    }
  }

  static Future<void> _persistString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {
      // Уже применено в памяти; не переживёт перезапуск — и только.
    }
  }

  static Future<void> _persist(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // The in-memory notifier already changed, so the current session behaves
      // correctly even if the write fails; it simply won't survive a restart.
    }
  }

  /// Test seam — resets to defaults so cases start from a known state.
  @visibleForTesting
  static void resetForTest() {
    enterToSend.value = true;
    messageHoverBar.value = true;
    linkPreviews.value = true;
    doubleClickReply.value = true;
    animatePeerCosmetics.value = true;
    themeMode.value = 'dark';
    preferredCameraId.value = '';
    preferredMicId.value = '';
    preferredSpeakerId.value = '';
    customAccentArgb.value = 0;
    trayHintShown.value = false;
    closeToTray.value = true;
    startMinimized.value = true;
    callInOwnWindow.value = true;
    callWindowPinned.value = false;
    customNotifications.value = true;
    textScale.value = 1.0;
    messageDensity.value = 'cozy';
    bubbleShape.value = 'medium';
    wallpaperDim.value = 0;
    senderNameColors.value = 'person';
    _loaded = false;
  }

  /// D-5: mirror of the controller's «Анимация рамок и статусов» setting.
  ///
  /// The controller owns this preference and its persistence — this is a
  /// read-only mirror so leaf widgets like [Avatar], which have no controller
  /// reference, can honour it without threading one through every call site.
  /// Kept in sync by the desktop app root on each `changed` tick.
  ///
  /// Before this, desktop gated animated frames on [TickerMode] alone, so a
  /// user who turned the setting off on their phone still saw peers' premium
  /// frames animating on desktop — the setting exists precisely to save power
  /// on a machine that is struggling.
  static final ValueNotifier<bool> animatePeerCosmetics =
      ValueNotifier<bool>(true);

  /// Pushes the controller's current value into [animatePeerCosmetics].
  /// Cheap and idempotent — [ValueNotifier] suppresses no-op writes.
  static void syncPeerCosmeticAnim(bool enabled) =>
      animatePeerCosmetics.value = enabled;
}
