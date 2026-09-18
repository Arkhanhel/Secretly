// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

/// On-device voice-message transcription (premium feature #5, Phase 2).
///
/// Uses the Whisper "base" model (multilingual, ~140 MB) running fully on the
/// device via whisper.cpp — audio never leaves the phone, consistent with the
/// app's E2EE/privacy stance. The model is downloaded once (lazily, on first
/// use) and cached; transcripts are cached on disk per message so re-opening a
/// chat never re-transcribes.
///
/// Everything fails soft (returns null) — transcription is a convenience layer
/// and must never throw into the chat UI.
class VoiceTranscriptionService {
  VoiceTranscriptionService._();
  static final VoiceTranscriptionService instance =
      VoiceTranscriptionService._();

  /// Имя модели — часть имени файла `ggml-<model>.bin`. Раньше это был enum
  /// плагина; теперь плагин (`whisper_cpp_flutter_plus`, MIT, 05.09.2026) о
  /// моделях ничего не знает и получает готовый путь — файл лежит там же, где
  /// и прежде, поэтому уже скачанные и проверенные модели остаются в силе.
  static const String _modelName = 'base';
  /// 🔴 РЕВИЗИЯ ПРИБИТА, А НЕ `main` (02.09.2026, SEC-15).
  ///
  /// Раньше здесь стояло `resolve/main/…`. `main` — ПОДВИЖНАЯ ссылка: что по
  /// ней лежит, решает владелец чужого репозитория, и содержимое может стать
  /// другим в любой момент без нашего участия. Файл при этом весит 141 МБ и
  /// уходит прямиком в нативный разборщик whisper.cpp — то есть подменённая
  /// модель это не «неправильный текст расшифровки», а чужой код, разбираемый
  /// на телефоне человека.
  static const String _modelRevision =
      '5359861c739e955e79d9a303bcbc70fb988958b1';
  static const String _modelUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/$_modelRevision/ggml-base.bin';

  /// Эталон содержимого модели.
  ///
  /// Получен из метаданных хранилища и ПЕРЕПРОВЕРЕН скачиванием: файл с
  /// прибитой ревизии скачан целиком и его сумма посчитана заново. Ошибка в
  /// этой строке ломает расшифровку голосовых у всех сразу, поэтому значение
  /// не переносится «на глаз».
  ///
  /// Оговорка, которую честно держать в уме: сумма взята с того же сервера,
  /// что и файл. Это фиксация известного хорошего состояния, а не независимое
  /// подтверждение, — от подмены В МОМЕНТ фиксации она не защищает, зато
  /// закрывает всё, что случится после.
  static const String _modelSha256Hex =
      '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe';
  static const int _modelSizeBytes = 147951465;

  /// Сколько ждать тишины в потоке скачивания.
  ///
  /// Предела не было вовсе: зависшее соединение держало «загружается» вечно.
  /// Считается пауза МЕЖДУ кусками, а не общее время, — иначе честные 141 МБ
  /// на медленной связи рвались бы на середине, а докачки здесь нет.
  static const Duration _downloadStallTimeout = Duration(seconds: 60);

  /// Файл-отметка: рядом с моделью лежит сумма, которую мы у неё проверили.
  ///
  /// Нужен для моделей, скачанных СТАРЫМ кодом — без всякой проверки. Такой
  /// файл может быть каким угодно, и молча ему доверять нельзя. Отметка
  /// избавляет от пересчёта суммы на каждом запуске: 141 МБ считаются один раз.
  static const String _verifiedStampSuffix = '.verified';

  /// Holds a value in 0..1 while the model is downloading, null otherwise.
  /// The transcription sheet listens to this to show a progress bar.
  final ValueNotifier<double?> downloadProgress = ValueNotifier<double?>(null);

  bool _downloading = false;

  Future<Directory> _supportDir(String sub) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$sub');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<String> _modelDirPath() async => (await _supportDir('whisper')).path;

  Future<File> _modelFile() async =>
      File('${await _modelDirPath()}/ggml-$_modelName.bin');

  /// True when the Whisper model is present (so transcription won't need a
  /// 140 MB download). Used to decide whether to show a "download" prompt.
  /// Считает сумму файла потоком, не поднимая 141 МБ в память.
  Future<String?> _fileSha256Hex(File file) async {
    try {
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString();
    } catch (_) {
      return null;
    }
  }

  /// Проверяет содержимое модели и оставляет отметку рядом с ней.
  ///
  /// Возвращает `true`, только если файл в точности тот, что ожидался. Иначе
  /// файл УДАЛЯЕТСЯ: держать на диске непонятный бинарник, который в следующий
  /// раз уйдёт в нативный разборщик, нельзя.
  Future<bool> _verifyModelFile(File file) async {
    try {
      if (!file.existsSync()) return false;
      if (file.lengthSync() != _modelSizeBytes) {
        // Дешёвая отсечка до пересчёта суммы: размер известен точно.
        try {
          file.deleteSync();
        } catch (_) {}
        return false;
      }
      final actual = await _fileSha256Hex(file);
      if (actual != _modelSha256Hex) {
        try {
          file.deleteSync();
        } catch (_) {}
        return false;
      }
      try {
        File('${file.path}$_verifiedStampSuffix')
            .writeAsStringSync(_modelSha256Hex);
      } catch (_) {
        // Отметка — лишь способ не считать сумму заново. Не записалась —
        // проверим в следующий раз, это дороже, но не опаснее.
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Готова ли модель к работе.
  ///
  /// 🔴 РАНЬШЕ ЗДЕСЬ ПРОВЕРЯЛСЯ ТОЛЬКО РАЗМЕР — «больше мегабайта». Любой файл
  /// крупнее мегабайта считался моделью и уходил в нативный разборщик. Теперь
  /// требуется совпадение суммы; для уже скачанных старым кодом файлов она
  /// считается ОДИН раз и запоминается отметкой рядом.
  Future<bool> isModelReady() async {
    final f = await _modelFile();
    if (!f.existsSync()) return false;
    final stamp = File('${f.path}$_verifiedStampSuffix');
    if (stamp.existsSync()) {
      try {
        if (stamp.readAsStringSync().trim() == _modelSha256Hex &&
            f.lengthSync() == _modelSizeBytes) {
          return true;
        }
      } catch (_) {
        // отметку не прочитать — проверим содержимое честно
      }
    }
    return _verifyModelFile(f);
  }

  /// Downloads the Whisper model if needed, reporting progress via
  /// [downloadProgress]. Returns true once the model is present. Concurrent
  /// callers coalesce onto the single in-flight download.
  Future<bool> ensureModel() async {
    if (await isModelReady()) return true;
    if (_downloading) {
      while (_downloading) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      return isModelReady();
    }
    _downloading = true;
    downloadProgress.value = 0;
    final target = await _modelFile();
    final part = File('${target.path}.part');
    HttpClient? client;
    try {
      client = HttpClient();
      final req = await client.getUrl(Uri.parse(_modelUrl));
      // 🔴 ПЕРЕХОДЫ РАЗРЕШЕНЫ ОСОЗНАННО. По всему остальному проекту они
      // запрещены: обычный запрос несёт подпись устройства и тело, а увести
      // его можно на любой домен с исправным сертификатом. Здесь запрос
      // АНОНИМЕН — ни подписи, ни данных, — а хранилище модели всегда уводит
      // на свою раздачу, без перехода скачать нельзя вовсе. Безопасным это
      // делает проверка суммы ниже: куда бы ни увели, чужой файл её не
      // пройдёт и будет удалён.
      req.followRedirects = true;
      req.maxRedirects = 5;
      final resp = await req.close();
      if (resp.statusCode != 200) return false;
      final total = resp.contentLength;
      // Размер известен заранее — не начинаем качать 141 МБ, если обещают иное.
      if (total > 0 && total != _modelSizeBytes) {
        return false;
      }
      final sink = part.openWrite();
      var received = 0;
      // Сторож ТИШИНЫ, а не общий предел: докачки с середины нет, и общий
      // предел рвал бы честную загрузку на медленной связи у самого конца.
      await for (final chunk in resp.timeout(
        _downloadStallTimeout,
        onTimeout: (sink) => sink.addError(
          TimeoutException('whisper model download stalled', _downloadStallTimeout),
        ),
      )) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) downloadProgress.value = received / total;
      }
      await sink.flush();
      await sink.close();
      // 🔴 ПРОВЕРКА ДО ПЕРЕИМЕНОВАНИЯ. Прежде здесь стояло «файл больше
      // мегабайта — значит модель», и этого хватало, чтобы принять что угодно
      // и отдать нативному разборщику. Теперь несовпадение суммы означает, что
      // временный файл удаляется и целевого не появляется вовсе.
      if (!await _verifyModelFile(part)) {
        return false;
      }
      if (target.existsSync()) target.deleteSync();
      part.renameSync(target.path);
      // Отметка переезжает вместе с файлом: она была записана на временное имя.
      try {
        final partStamp = File('${part.path}$_verifiedStampSuffix');
        if (partStamp.existsSync()) {
          partStamp.renameSync('${target.path}$_verifiedStampSuffix');
        }
      } catch (_) {}
      return true;
    } catch (_) {
      try {
        if (part.existsSync()) part.deleteSync();
      } catch (_) {}
      return false;
    } finally {
      client?.close();
      downloadProgress.value = null;
      _downloading = false;
    }
  }

  /// Deletes the cached Whisper model (`<support>/whisper/ggml-<model>.bin`),
  /// reclaiming ~140 MB. The model re-downloads lazily on the next
  /// [transcribe]/[ensureModel] call, so this is always safe to call. Also
  /// removes any leftover `.part` from an interrupted download. Best-effort —
  /// never throws.
  Future<void> deleteModel() async {
    try {
      final target = await _modelFile();
      final part = File('${target.path}.part');
      if (part.existsSync()) part.deleteSync();
      if (target.existsSync()) target.deleteSync();
      // Отметка о проверке без файла бессмысленна и опасна: следующая модель
      // легла бы под чужую отметку и считалась бы проверенной.
      for (final stamp in <File>[
        File('${target.path}$_verifiedStampSuffix'),
        File('${part.path}$_verifiedStampSuffix'),
      ]) {
        if (stamp.existsSync()) stamp.deleteSync();
      }
    } catch (_) {
      // Best-effort — leave the model in place on any failure.
    }
  }

  /// Best-effort background warm-up: ensures the ~140 MB model is downloaded
  /// ahead of first use, so dictation/transcription isn't blocked by the
  /// download when the user taps the mic. Idempotent (a present model is a
  /// no-op; a concurrent download coalesces) and never throws — safe to call on
  /// every chat open. The native model load + inference already run off the main
  /// isolate (the plugin loads the model in a worker isolate and runs inference
  /// natively without blocking Dart), so this only moves the one-time download
  /// off the critical path.
  Future<void> warmUp() async {
    try {
      if (await isModelReady()) return;
      await ensureModel();
    } catch (_) {
      // Best-effort — the first real use will download/retry as before.
    }
  }

  Future<Directory> _transcriptDir() => _supportDir('voice_transcripts');

  String _cacheKey(String eventId) =>
      eventId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Returns a previously-cached transcript for [eventId], or null.
  Future<String?> cachedTranscript(String eventId) async {
    try {
      final f = File(
        '${(await _transcriptDir()).path}/${_cacheKey(eventId)}.txt',
      );
      if (f.existsSync()) {
        final t = await f.readAsString();
        if (t.trim().isNotEmpty) return t.trim();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _cacheTranscript(String eventId, String text) async {
    try {
      final f = File(
        '${(await _transcriptDir()).path}/${_cacheKey(eventId)}.txt',
      );
      await f.writeAsString(text);
    } catch (_) {}
  }

  /// Converts [audioPath] to a 16 kHz mono PCM WAV — the format whisper.cpp
  /// expects. Returns the WAV path or null on failure.
  Future<String?> _toWav(String audioPath) async {
    final out = '$audioPath.stt16k.wav';
    try {
      if (File(out).existsSync()) File(out).deleteSync();
    } catch (_) {}
    final cmd = '-y -i "$audioPath" -ar 16000 -ac 1 -c:a pcm_s16le "$out"';
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc) && File(out).existsSync()) return out;
    return null;
  }

  /// Transcribes the voice file at [audioPath] for message [eventId], using the
  /// on-disk cache when present. Downloads the model on first use. Returns null
  /// on any failure (download/convert/empty result) — never throws.
  ///
  /// [language] forces the recognition language as an ISO-639-1 code
  /// ("ru"/"en"/"uk"/…). When null or blank, Whisper auto-detects the language
  /// ("auto") — the original behavior, so voice-note transcription callers that
  /// omit it are unaffected.
  Future<String?> transcribe({
    required String eventId,
    required String audioPath,
    String? language,
  }) async {
    final cached = await cachedTranscript(eventId);
    if (cached != null) return cached;
    if (!File(audioPath).existsSync()) return null;
    if (!await ensureModel()) return null;
    String? wav;
    WhisperEngine? engine;
    try {
      wav = await _toWav(audioPath);
      if (wav == null) return null;
      // 🔴 ПОСЛЕДНЯЯ ПРОВЕРКА ПЕРЕД ПЕРЕДАЧЕЙ РАЗБОРЩИКУ (SEC-15).
      //
      // Прежний плагин при отсутствии модели качал её сам — по подвижной
      // ссылке и без проверки содержимого, в обход всего нашего контроля.
      // Нынешний (`whisper_cpp_flutter_plus`) ничего не скачивает: получает
      // готовый путь и не берёт файл во владение. Проверка оставлена как
      // страховка от гонки: файл мог исчезнуть между `ensureModel` выше и
      // этой строкой — систему чистки места на телефоне никто не спрашивает.
      // Файла нет — расшифровки не будет; человек повторит, и `ensureModel`
      // скачает модель нашим путём, с проверкой суммы.
      final modelFile = await _modelFile();
      if (!modelFile.existsSync()) {
        return null;
      }
      // WAV уже 16 kHz mono PCM (см. `_toWav`); `readWav` лишь разбирает
      // заголовок и отдаёт Float32-сэмплы, которые ждёт whisper.cpp.
      final samples = await WhisperAudio.readWav(File(wav));
      if (samples.isEmpty) return null;
      engine = await WhisperEngine.load(modelFile.path);
      final result = await engine
          .transcribe(
            samples,
            options: TranscribeOptions(
              language: (language == null || language.trim().isEmpty)
                  ? 'auto'
                  : language.trim(),
              // Нужен текст, не субтитры: без меток времени быстрее и
              // результат — одна строка, как и было с прежним плагином.
              noTimestamps: true,
              tokenTimestamps: false,
            ),
          )
          .result;
      final text = result.text.trim();
      if (text.isEmpty) return null;
      await _cacheTranscript(eventId, text);
      return text;
    } catch (_) {
      return null;
    } finally {
      // Модель ~140 МБ в памяти: освобождаем сразу, как и раньше — прежний
      // плагин тоже загружал её на каждый вызов и не держал между сообщениями.
      try {
        engine?.dispose();
      } catch (_) {}
      try {
        if (wav != null && File(wav).existsSync()) File(wav).deleteSync();
      } catch (_) {}
    }
  }
}
