// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// ГОЛОСОВЫЕ С ПК: запись, волна и временные файлы (30.09.2026).
///
/// 🔴 ГОЛОСОВЫЕ НА ПК НЕ ЗАПИСЫВАЛИСЬ ВОВСЕ — И МОЛЧА. Поле ввода писало в
/// Opus, а его не умеет пакет записи ни на macOS (кодек выключен в
/// `isEncoderSupported`), ни на Windows (`E_NOTIMPL`); ошибку глотал пустой
/// `catch`, и кнопка микрофона просто ничего не делала. Теперь — как
/// телефон: AAC-LC в `.m4a`, тип `audio/mp4` и волна громкости. По волне обе
/// стороны и отличают голосовое от песни: по типу `audio/mp4` они неотличимы.
///
/// 🔴 ЗАПИСИ НЕ ОСТАЮТСЯ НА ДИСКЕ. Раньше `voice-….opus` жил во временном
/// каталоге системы вечно: после отправки, после сбоя, после удаления чата и
/// его автоудаления. Теперь запись лежит в своей папке приложения и
/// удаляется, как только отправке больше не нужна; брошенные (падение,
/// выключение посреди записи) убираются при следующем запуске.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../diagnostics/diag_log.dart';
import '../../../l10n/app_localizations.dart';

/// Настройки записи — те же, что у телефона (`chat_screen.dart`).
const RecordConfig kDesktopVoiceRecordConfig = RecordConfig(
  encoder: AudioEncoder.aacLc,
  bitRate: 128000,
  sampleRate: 44100,
);

/// Тип голосового — как у телефона.
const String kDesktopVoiceMime = 'audio/mp4';

/// Сколько столбиков волны уходит с голосовым — как у телефона.
const int kDesktopVoiceWaveformBars = 48;

/// Почему запись не началась.
enum DesktopVoiceFailure {
  noPermission,
  noInputDevice,
  unsupportedEncoder,
  startFailed,
}

/// Что сказать человеку.
String desktopVoiceFailureText(
  DesktopVoiceFailure why,
  AppLocalizations l10n,
) => switch (why) {
  DesktopVoiceFailure.noPermission => l10n.desktopMicNoAccess,
  DesktopVoiceFailure.noInputDevice => l10n.desktopDevicesNoMics,
  DesktopVoiceFailure.unsupportedEncoder =>
    l10n.desktopComposerVoiceUnsupported,
  DesktopVoiceFailure.startFailed => l10n.desktopMicOpenFailed,
};

/// Записать в журнал, почему не вышло. Без пути к файлу: в нём имя
/// пользователя.
void logDesktopVoiceFailure(DesktopVoiceFailure why, [Object? error]) {
  DiagLog.event('voice', 'record_failed', <String, Object?>{
    'reason': why.name,
    if (error != null)
      'error': error is PlatformException
          ? 'platform:${error.code}'
          : error.runtimeType.toString(),
  });
}

/// Микрофон для голосовых. Настоящая половина — [RecordDesktopVoiceRecorder],
/// в тестах — подставная.
abstract class DesktopVoiceRecorder {
  /// Как создать микрофон. Тесты подставляют свой.
  static DesktopVoiceRecorder Function() create =
      RecordDesktopVoiceRecorder.new;

  /// Умеет ли система писать [kDesktopVoiceRecordConfig].
  Future<bool> isEncoderSupported();

  /// Есть ли разрешение; если ещё не решено — спросить систему.
  Future<bool> hasPermission();

  /// Есть ли хоть один микрофон. `null` — система не ответила: тогда не
  /// мешаем записи, а скажет своё уже её начало.
  Future<bool?> hasInputDevice();

  Future<void> start(String path);

  /// Громкость в dBFS: около 0 — громко, около -60 — тишина.
  Stream<double> amplitudeDb(Duration interval);

  /// Остановить; путь к готовой записи.
  Future<String?> stop();

  /// Остановить и выбросить запись.
  Future<void> cancel();

  Future<void> dispose();
}

/// Микрофон через пакет `record` — тот же, что пишет голосовые телефона.
class RecordDesktopVoiceRecorder implements DesktopVoiceRecorder {
  AudioRecorder? _recorder;

  /// Записывающий создаётся в своей зоне ошибок: конструктор пакета сам
  /// заводит запись на платформе и ответа не ждёт (см. `RecordMicCapture`).
  AudioRecorder get _rec => _recorder ??= runZonedGuarded(
    AudioRecorder.new,
    (Object e, StackTrace _) => DiagLog.event('voice', 'recorder_init_failed', {
      'error': e.runtimeType.toString(),
    }),
  )!;

  @override
  Future<bool> isEncoderSupported() =>
      _rec.isEncoderSupported(kDesktopVoiceRecordConfig.encoder);

  @override
  Future<bool> hasPermission() => _rec.hasPermission();

  @override
  Future<bool?> hasInputDevice() async {
    try {
      return (await _rec.listInputDevices()).isNotEmpty;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> start(String path) =>
      _rec.start(kDesktopVoiceRecordConfig, path: path);

  @override
  Stream<double> amplitudeDb(Duration interval) =>
      _rec.onAmplitudeChanged(interval).map((a) => a.current);

  @override
  Future<String?> stop() => _rec.stop();

  @override
  Future<void> cancel() => _rec.cancel();

  @override
  Future<void> dispose() async {
    final rec = _recorder;
    _recorder = null;
    if (rec != null) await rec.dispose();
  }
}

/// Можно ли начинать запись: кодек, разрешение, микрофон — в этом порядке.
/// `null` — можно.
///
/// Кодек — первым: он не спрашивает человека ни о чём, и незачем показывать
/// системный запрос доступа к микрофону, если писать всё равно нечем.
Future<DesktopVoiceFailure?> desktopVoicePreflight(
  DesktopVoiceRecorder rec,
) async {
  if (!await rec.isEncoderSupported()) {
    return DesktopVoiceFailure.unsupportedEncoder;
  }
  if (!await rec.hasPermission()) return DesktopVoiceFailure.noPermission;
  if (await rec.hasInputDevice() == false) {
    return DesktopVoiceFailure.noInputDevice;
  }
  return null;
}

/// Громкость для волны, 0..1: речь занимает [-45, 0] dBFS — как у телефона.
double desktopVoiceLevel(double db) {
  if (!db.isFinite) return 0;
  return ((db + 45.0) / 45.0).clamp(0.0, 1.0);
}

/// Волна голосового: [bars] столбиков 0..100 — тем же способом, что у
/// телефона (`_buildVoiceWaveform` в `chat_screen.dart`): пик в каждом
/// отрезке и растяжка по самому громкому месту.
///
/// 🔴 ВОЛНА НЕ БЫВАЕТ ПУСТОЙ. Голосовое — это `audio/mp4`, как песня, и
/// голосовым его делает только волна. Не пришло ни одного замера громкости —
/// волна всё равно уходит, иначе у получателя голосовое станет «аудиофайлом».
List<int> buildDesktopVoiceWaveform(
  List<double> samples, {
  int bars = kDesktopVoiceWaveformBars,
  math.Random? random,
}) {
  if (bars <= 0) return const <int>[];
  if (samples.isEmpty) {
    final rng = random ?? math.Random();
    return List<int>.generate(bars, (_) {
      final r = rng.nextDouble();
      return (12 + r * r * 88).round().clamp(0, 100);
    }, growable: false);
  }
  final out = List<double>.filled(bars, 0);
  if (samples.length <= bars) {
    for (var i = 0; i < bars; i++) {
      final src = (i * samples.length / bars).floor().clamp(
        0,
        samples.length - 1,
      );
      out[i] = samples[src];
    }
  } else {
    for (var i = 0; i < bars; i++) {
      final start = (i * samples.length / bars).floor();
      final end = ((i + 1) * samples.length / bars).floor().clamp(
        start + 1,
        samples.length,
      );
      var peak = 0.0;
      for (var j = start; j < end; j++) {
        if (samples[j] > peak) peak = samples[j];
      }
      out[i] = peak;
    }
  }
  var maxV = 0.0;
  for (final v in out) {
    if (v > maxV) maxV = v;
  }
  final scale = maxV > 0.05 ? 1.0 / maxV : 1.0;
  return out
      .map((v) => (v * scale * 100).round().clamp(0, 100))
      .toList(growable: false);
}

/// Временные файлы голосовых.
abstract final class DesktopVoiceFiles {
  /// Своя папка приложения во временном каталоге: уборка трогает только
  /// свои записи.
  static const String folderName = 'secretly_voice';

  /// Брошенная запись старше суток — мусор.
  static const Duration staleAfter = Duration(days: 1);

  /// Временный каталог приложения. Подменяют тесты.
  @visibleForTesting
  static Future<Directory> Function() baseDir = getTemporaryDirectory;

  /// Где прежние сборки оставляли `voice-….opus`. Подменяют тесты.
  @visibleForTesting
  static Directory Function() legacyDir = () => Directory.systemTemp;

  static final RegExp _ownName = RegExp(r'^voice-\d+\.m4a$');
  static final RegExp _legacyName = RegExp(r'^voice-\d{13}\.opus$');

  static Future<Directory> _dir() async {
    final dir = Directory(p.join((await baseDir()).path, folderName));
    dir.createSync(recursive: true);
    return dir;
  }

  /// Путь для новой записи.
  static Future<String> newPath() async => p.join(
    (await _dir()).path,
    'voice-${DateTime.now().microsecondsSinceEpoch}.m4a',
  );

  /// Удалить запись. Нет файла — ничего не делает.
  ///
  /// Синхронно: файл уходит сразу, даже если вызывающий не ждёт ответа
  /// (закрытие поля ввода посреди записи).
  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (e) {
      DiagLog.event('voice', 'temp_delete_failed', <String, Object?>{
        'error': e.runtimeType.toString(),
      });
    }
  }

  static bool _swept = false;

  /// Убрать брошенные записи — один раз за запуск.
  static Future<void> sweepOnce() async {
    if (_swept) return;
    _swept = true;
    await sweep();
  }

  /// Убрать записи старше [staleAfter]: свои `voice-*.m4a` и `voice-*.opus`
  /// прежних сборок. Свежие не трогаем — одна из них может писаться прямо
  /// сейчас. Возвращает, сколько убрано.
  static Future<int> sweep({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(staleAfter);
    var removed = 0;
    Future<void> sweepDir(Directory dir, RegExp names) async {
      if (!await dir.exists()) return;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File || !names.hasMatch(p.basename(entity.path))) {
          continue;
        }
        try {
          if ((await entity.lastModified()).isBefore(cutoff)) {
            await entity.delete();
            removed++;
          }
        } catch (_) {}
      }
    }

    try {
      await sweepDir(
        Directory(p.join((await baseDir()).path, folderName)),
        _ownName,
      );
      await sweepDir(legacyDir(), _legacyName);
    } catch (_) {
      // Уборка — забота, а не условие работы: не вышло — попробуем при
      // следующем запуске.
    }
    if (removed > 0) {
      DiagLog.event('voice', 'temp_swept', <String, Object?>{'count': removed});
    }
    return removed;
  }

  @visibleForTesting
  static void debugReset() {
    _swept = false;
    baseDir = getTemporaryDirectory;
    legacyDir = () => Directory.systemTemp;
  }
}
