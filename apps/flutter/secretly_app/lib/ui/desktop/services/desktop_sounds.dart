// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// ЗВУКИ ПК: ВЫБОР И «ПОСЛУШАТЬ» (01.10.2026, владелец: «человек должен
/// выбирать звуки и слышать их до выбора»).
///
/// Три списка — как у телефона: звук сообщений, звук в открытом чате и
/// мелодия звонка.
///
/// 🔴 ХРАНИЛИЩЕ — ТЕЛЕФОННОЕ, СВОЕГО НЕТ. Выбор пишется в те же ключи, что
/// пишут «Настройки» телефона и читает контроллер. У звуков сообщений ключа
/// два: `settings_…` пишет экран настроек, а контроллер читает сперва
/// рабочий ключ и лишь при его отсутствии — `settings_…`, один раз копируя
/// значение в рабочий. Пиши ПК только `settings_…`, второй выбор не дошёл бы
/// никуда: рабочий ключ уже держал бы первый. Поэтому пишем оба.
///
/// 🔴 ПОДПИСИ — БЕЗ ЧУЖИХ МАРОК. Имена файлов несут названия производителей
/// и игр (`water_drop_one_plus`, `xiaomi_notification`, `bubbles_samsung`,
/// `pixel_tono`, `cytus_ii_im`, `click_s7`); телефон показывает имя файла как
/// есть. Здесь у каждого звука своё нейтральное название из перевода.
///
/// Играет [DesktopMessageSound] (служба уведомлений ПК) и [DesktopSoundPreview]
/// («Послушать» в настройках). Мелодию звонка играет сам звонок: файл он берёт
/// через точку ПК `DesktopCallDeviceHooks.ringtoneAsset`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../entitlements/cosmetic_catalog.dart'
    show isCallRingtoneAllowed, isRingtoneAllowed;
import '../../../entitlements/entitlement_models.dart' show EntitlementState;
import '../../../l10n/app_localizations.dart';
import '../../app_asset_paths.dart';
import 'desktop_call_prefs.dart';

/// Какой из трёх списков.
enum DesktopSoundKind {
  /// Звук уведомления о сообщении (`sounds/noti/`).
  message,

  /// Звук сообщения в открытой переписке (`sounds/inchat/`).
  inChat,

  /// Мелодия входящего звонка (`Bubble.mp3` и `sounds/call/`).
  call,
}

abstract final class DesktopSounds {
  // Ключи телефона: `settings_…` — экран настроек, остальные — контроллер.
  static const String messageSettingsKey =
      'settings_notif_in_app_sound_asset_v1';
  static const String messageRuntimeKey = 'notif_inapp_sound_asset_v1';
  static const String inChatSettingsKey =
      'settings_notif_in_app_chat_sound_asset_v1';
  static const String inChatRuntimeKey = 'notif_inapp_chat_sound_asset_v1';
  static const String inChatEnabledSettingsKey =
      'settings_notif_in_app_chat_sound_v1';
  static const String inChatEnabledRuntimeKey = 'notif_inapp_chat_sound_v1';

  /// Мелодию звонка звонок читает сам и только отсюда.
  static const String callSettingsKey = 'settings_notif_call_ringtone_v1';

  /// Мелодия по умолчанию — та, что звучала до выбора (`Bubble.mp3`).
  static const String defaultCallId = 'default';

  /// Звуки сообщений — ровно список телефона и его порядок.
  static const List<String> messageIds = <String>[
    'bubble_mail',
    'bubbles_v1',
    'drip_drop',
    'pingo',
    'splash',
    'water_drop_one_plus',
    'xiaomi_notification',
  ];

  /// Звуки открытого чата — папка `inchat`, и только она.
  ///
  /// Телефон предлагает здесь и звуки сообщений, но контроллер ищет выбранный
  /// файл в `inchat/` — там их нет, и выбор оборачивался тишиной.
  static const List<String> inChatIds = <String>[
    'keycap',
    'click_s7',
    'switch_click',
  ];

  /// Мелодии звонка: по умолчанию и папка `call`.
  ///
  /// Без `ringback_ru.wav`: это гудки ИСХОДЯЩЕГО, и входящий, звучащий как
  /// собственный вызов, путал бы.
  static const List<String> callIds = <String>[
    defaultCallId,
    'pixel_tono',
    'bubbles_samsung',
    'cytus_ii_im',
  ];

  static List<String> idsOf(DesktopSoundKind kind) => switch (kind) {
    DesktopSoundKind.message => messageIds,
    DesktopSoundKind.inChat => inChatIds,
    DesktopSoundKind.call => callIds,
  };

  static String defaultIdOf(DesktopSoundKind kind) => idsOf(kind).first;

  /// Громкость звука сообщения. Громче сигнала контроллера на телефоне
  /// (0,24): тот звучит, когда человек смотрит в экран, а этот — и когда окно
  /// спрятано в трей.
  static const double messageVolume = 0.7;

  /// Звук открытого чата — тише уведомления: переписка и так перед глазами.
  static const double inChatVolume = 0.35;

  /// Громкость «Послушать» — та же, с которой звук прозвучит на деле.
  static double volumeOf(DesktopSoundKind kind) => switch (kind) {
    DesktopSoundKind.message => messageVolume,
    DesktopSoundKind.inChat => inChatVolume,
    DesktopSoundKind.call => DesktopCallPrefs.ringtoneVolume.value,
  };

  /// Путь к звуку [id] в сборке. Незнакомый [id] — звук по умолчанию.
  static String assetOf(DesktopSoundKind kind, String id) {
    final known = idsOf(kind).contains(id) ? id : defaultIdOf(kind);
    return switch (kind) {
      DesktopSoundKind.message => AppAssetPaths.notificationSong(
        folder: 'noti',
        basename: known,
      ),
      DesktopSoundKind.inChat => AppAssetPaths.notificationSong(
        folder: 'inchat',
        basename: known,
      ),
      DesktopSoundKind.call =>
        known == defaultCallId
            ? AppAssetPaths.incomingRingtoneMp3
            : AppAssetPaths.notificationSong(folder: 'call', basename: known),
    };
  }

  /// Можно ли выбрать [id] при [state]. Правило — телефонное; `null`
  /// (подписка неизвестна) — можно: оплата ошибается в пользу человека.
  /// Звуки открытого чата телефон не делит на платные — и здесь не делим.
  static bool isAllowed(
    DesktopSoundKind kind,
    EntitlementState? state,
    String id,
  ) => switch (kind) {
    DesktopSoundKind.message => isRingtoneAllowed(state, id),
    DesktopSoundKind.inChat => true,
    DesktopSoundKind.call => isCallRingtoneAllowed(state, id),
  };

  /// Название звука для человека.
  static String nameOf(AppLocalizations l10n, String id) => switch (id) {
    'bubble_mail' => l10n.desktopSoundNameBubble,
    'bubbles_v1' || 'bubbles_samsung' => l10n.desktopSoundNameBubbles,
    'drip_drop' => l10n.desktopSoundNameDrip,
    'pingo' => l10n.desktopSoundNamePing,
    'splash' => l10n.desktopSoundNameSplash,
    'water_drop_one_plus' => l10n.desktopSoundNameDrop,
    'xiaomi_notification' => l10n.desktopSoundNameTone,
    'keycap' => l10n.desktopSoundNameKey,
    'click_s7' => l10n.desktopSoundNameClick,
    'switch_click' => l10n.desktopSoundNameSwitch,
    'pixel_tono' => l10n.desktopSoundNameMelody,
    'cytus_ii_im' => l10n.desktopSoundNamePulse,
    _ => l10n.desktopSoundNameDefault,
  };

  static String _clean(String? raw) =>
      (raw ?? '').trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');

  /// Строка по правилу контроллера: рабочий ключ, затем `settings_…`.
  static String? _readCompat(
    SharedPreferences prefs, {
    required String runtimeKey,
    required String settingsKey,
  }) {
    final runtime = prefs.getString(runtimeKey);
    if (runtime != null && runtime.trim().isNotEmpty) return runtime;
    final fromSettings = prefs.getString(settingsKey);
    if (fromSettings != null && fromSettings.trim().isNotEmpty) {
      return fromSettings;
    }
    return null;
  }

  /// Выбранный звук. Незнакомое значение (например, звук сообщений,
  /// выбранный на телефоне для открытого чата) — звук по умолчанию: его и
  /// будет слышно.
  static String readId(SharedPreferences prefs, DesktopSoundKind kind) {
    final raw = switch (kind) {
      DesktopSoundKind.message => _readCompat(
        prefs,
        runtimeKey: messageRuntimeKey,
        settingsKey: messageSettingsKey,
      ),
      DesktopSoundKind.inChat => _readCompat(
        prefs,
        runtimeKey: inChatRuntimeKey,
        settingsKey: inChatSettingsKey,
      ),
      DesktopSoundKind.call => prefs.getString(callSettingsKey),
    };
    final id = _clean(raw);
    return idsOf(kind).contains(id) ? id : defaultIdOf(kind);
  }

  /// Сохранить выбор. Звуки сообщений — в оба ключа (см. шапку файла).
  static Future<void> save(DesktopSoundKind kind, String id) async {
    if (!idsOf(kind).contains(id)) return;
    final prefs = await SharedPreferences.getInstance();
    switch (kind) {
      case DesktopSoundKind.message:
        await prefs.setString(messageSettingsKey, id);
        await prefs.setString(messageRuntimeKey, id);
      case DesktopSoundKind.inChat:
        await prefs.setString(inChatSettingsKey, id);
        await prefs.setString(inChatRuntimeKey, id);
      case DesktopSoundKind.call:
        await prefs.setString(callSettingsKey, id);
    }
  }

  /// Включён ли звук в открытом чате.
  ///
  /// 🔴 По умолчанию на ПК — НЕТ (01.10.2026). У телефона умолчание «да», но
  /// телефон этот звук не играет вовсе, то есть его люди его не слышали
  /// никогда. На компьютере открытая переписка и так перед глазами, и новый
  /// звук на каждое сообщение в ней после обновления был бы сюрпризом.
  /// Включить — один переключатель в «Уведомлениях»; выбор человека (в
  /// любом из двух ключей) по-прежнему главнее умолчания.
  static bool readInChatEnabled(SharedPreferences prefs) =>
      prefs.getBool(inChatEnabledRuntimeKey) ??
      prefs.getBool(inChatEnabledSettingsKey) ??
      false;

  static Future<void> setInChatEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(inChatEnabledSettingsKey, value);
    await prefs.setBool(inChatEnabledRuntimeKey, value);
  }

  /// Для звонка: по значению настройки — файл мелодии или `null` (мелодия по
  /// умолчанию). «Beacon» и «Chime» телефона — это та же мелодия по
  /// умолчанию, только быстрее или медленнее; их звонок играет по-старому.
  static String? callRingtoneAssetFor(String setting) {
    final id = _clean(setting);
    if (id == defaultCallId || !callIds.contains(id)) return null;
    return assetOf(DesktopSoundKind.call, id);
  }
}

/// Проигрыватель звука. Настоящий — [JustAudioSoundOutput], в тестах —
/// подставной.
abstract class DesktopSoundOutput {
  /// Играть [asset] с начала. Завершается, когда звук ПОШЁЛ; бросает, если
  /// файл не загрузился. [loop] — по кругу, как мелодия настоящего звонка.
  Future<void> start(String asset, {required double volume, bool loop = false});

  /// Завершается, когда текущий звук доиграл или остановлен.
  Future<void> get finished;

  Future<void> setVolume(double volume);
  Future<void> stop();
  Future<void> dispose();
}

/// Тот же проигрыватель, что у звонка и у сигнала контроллера (`just_audio`):
/// звучит в устройстве вывода системы по умолчанию.
class JustAudioSoundOutput implements DesktopSoundOutput {
  AudioPlayer? _player;
  Completer<void>? _finished;

  @override
  Future<void> start(
    String asset, {
    required double volume,
    bool loop = false,
  }) async {
    final player = _player ??= AudioPlayer();
    _finish();
    // 🔴 СПЕРВА ПАУЗА. Доигравший проигрыватель остаётся «играющим», и
    // следующий `play()` завершился бы сразу — «Послушать» гасло бы, не
    // начавшись, а новый файл заиграл бы сам ещё до громкости.
    await player.pause();
    await player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
    await player.setAsset(asset);
    await player.setVolume(volume);
    await player.seek(Duration.zero);
    final done = _finished = Completer<void>();
    // `play()` завершается, когда звук доиграл или остановлен, — это и есть
    // [finished]. Не ждём его здесь: звук — не повод держать вызывающего.
    unawaited(
      player.play().then((_) {}, onError: (Object _) {}).whenComplete(() {
        if (!done.isCompleted) done.complete();
      }),
    );
  }

  @override
  Future<void> get finished => _finished?.future ?? Future<void>.value();

  void _finish() {
    final done = _finished;
    _finished = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  @override
  Future<void> setVolume(double volume) async {
    await _player?.setVolume(volume);
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
    _finish();
  }

  @override
  Future<void> dispose() async {
    _finish();
    final player = _player;
    _player = null;
    await player?.dispose();
  }
}

/// «Послушать» в настройках — ОДИН проигрыватель на все списки: новый звук
/// гасит прежний, где бы тот ни играл.
class DesktopSoundPreview {
  DesktopSoundPreview._();

  static final DesktopSoundPreview instance = DesktopSoundPreview._();

  /// Проигрыватель; в тестах — подставной.
  @visibleForTesting
  static DesktopSoundOutput Function() createOutput = JustAudioSoundOutput.new;

  /// Сколько звучит мелодия звонка. Она идёт по кругу, как у настоящего
  /// звонка (у коротких мелодий круг и есть их звучание), а услышать её
  /// хватает пары тактов.
  static const Duration callPreviewLength = Duration(seconds: 4);

  /// Что звучит сейчас — [keyOf]; `null` — тишина.
  final ValueNotifier<String?> playing = ValueNotifier<String?>(null);

  DesktopSoundOutput? _output;
  Timer? _cap;
  int _seq = 0;

  static String keyOf(DesktopSoundKind kind, String id) => '${kind.name}:$id';

  bool isPlaying(DesktopSoundKind kind, String id) =>
      playing.value == keyOf(kind, id);

  /// Звучит ли сейчас что-то из списка [kind].
  bool isPlayingKind(DesktopSoundKind kind) =>
      playing.value?.startsWith('${kind.name}:') ?? false;

  Future<void> toggle(DesktopSoundKind kind, String id) =>
      isPlaying(kind, id) ? stop() : play(kind, id);

  Future<void> play(DesktopSoundKind kind, String id) async {
    final key = keyOf(kind, id);
    final seq = ++_seq;
    _cap?.cancel();
    _cap = null;
    final output = _output ??= createOutput();
    playing.value = key;
    try {
      await output.start(
        DesktopSounds.assetOf(kind, id),
        volume: DesktopSounds.volumeOf(kind),
        loop: kind == DesktopSoundKind.call,
      );
    } catch (_) {
      if (seq == _seq) playing.value = null;
      return;
    }
    // Пока грузился файл, человек мог нажать другой звук или «Стоп».
    if (seq != _seq) return;
    if (kind == DesktopSoundKind.call) {
      _cap = Timer(callPreviewLength, () {
        if (seq == _seq) unawaited(stop());
      });
    }
    unawaited(
      output.finished.then((_) {
        if (seq == _seq && playing.value == key) playing.value = null;
      }),
    );
  }

  Future<void> stop() async {
    _seq++;
    _cap?.cancel();
    _cap = null;
    playing.value = null;
    try {
      await _output?.stop();
    } catch (_) {}
  }

  /// Громкость мелодии поменяли во время «Послушать» — слышно сразу.
  Future<void> setCallVolume(double volume) async {
    if (!isPlayingKind(DesktopSoundKind.call)) return;
    try {
      await _output?.setVolume(volume);
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _seq++;
    _cap?.cancel();
    _cap = null;
    playing.value = null;
    final output = _output;
    _output = null;
    await output?.dispose();
  }
}

/// Звук сообщения для службы уведомлений ПК: выбранный человеком файл.
class DesktopMessageSound {
  DesktopMessageSound({DesktopSoundOutput Function()? output})
    : _create = output ?? JustAudioSoundOutput.new;

  final DesktopSoundOutput Function() _create;
  DesktopSoundOutput? _output;

  /// Сыграть выбранный звук вида [kind]. `false` — не вышло (файл не
  /// загрузился, проигрывателя нет): вызывающий вернёт системный звук, чтобы
  /// уведомление не осталось беззвучным.
  Future<bool> play(DesktopSoundKind kind) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = DesktopSounds.readId(prefs, kind);
      final output = _output ??= _create();
      await output.start(
        DesktopSounds.assetOf(kind, id),
        volume: DesktopSounds.volumeOf(kind),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    final output = _output;
    _output = null;
    try {
      await output?.dispose();
    } catch (_) {}
  }
}
