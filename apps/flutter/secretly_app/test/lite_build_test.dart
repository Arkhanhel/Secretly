// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Облегчённая сборка Android: сторож заслонок.
//
// 🔴 ЧТО ЭТОТ НАБОР МОЖЕТ И ЧЕГО НЕ МОЖЕТ. Флаги из `build_variant.dart` —
// значения ВРЕМЕНИ СБОРКИ (`bool.fromEnvironment`). Подменить их из теста
// нельзя, и притворяться облегчённой сборкой здесь нечестно. Поэтому сторож
// проверяет три настоящие вещи:
//
//   1. в нынешней (полной) сборке флаги стоят ровно так, как ожидает код, —
//      то есть вся сегодняшняя работа идёт прежним путём;
//   2. каждый файл, который тянет одну из трёх вынимаемых библиотек, знает про
//      свой флаг: заслонка в нём есть, а не забыта (ратчет на будущее — новый
//      ввоз библиотеки без заслонки уронит тест);
//   3. запасные пути вызываются и отвечают мягко: ни один из них не бросает
//      исключение в UI и отдаёт именно то, что ждёт вызывающий.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/build_variant.dart';
import 'package:secretly_app/media/h264_encoder.dart';
import 'package:secretly_app/media/video_compressor.dart';
import 'package:secretly_app/media/video_thumbnail_cache.dart';
import 'package:secretly_app/stickers/sticker_animation_service.dart';
import 'package:secretly_app/translation/translation_service.dart';
import 'package:secretly_app/ui/video_trim_editor_screen.dart';

/// Какой флаг обязан упоминать файл, ввозящий данную библиотеку.
const Map<String, String> _pluginToFlag = <String, String>{
  'ffmpeg_kit_flutter_new': 'kVideoToolsAvailable',
  'whisper_cpp_flutter_plus': 'kVoiceTranscriptionAvailable',
  'google_mlkit_translation': 'kTranslationAvailable',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('флаги облегчённой сборки', () {
    test('в нынешней сборке выключены — поведение прежнее', () {
      expect(kLiteBuild, isFalse);
      expect(kVideoToolsAvailable, isTrue);
      expect(kTranslationAvailable, isTrue);
      // «Голос в текст» убран решением владельца 20.11.2026 — отдельно от
      // облегчённой сборки (kVoiceToTextEnabled).
      expect(kVoiceToTextEnabled, isFalse);
      expect(kVoiceTranscriptionAvailable, isFalse);
    });

    test('все три доступности — обратная сторона одного переключателя', () {
      expect(kVideoToolsAvailable, !kLiteBuild);
      expect(kTranslationAvailable, !kLiteBuild);
      expect(kVoiceTranscriptionAvailable, !kLiteBuild && kVoiceToTextEnabled);
    });

    test('порог сжатия видео в полной сборке остался 3 МБ', () {
      // В облегчённой он поднят выше любого файла — это та самая точка, по
      // которой отправщик решает, будет ли фаза сжатия.
      expect(VideoCompressor.skipBelowBytes, 3 * 1024 * 1024);
    });
  });

  group('ратчет: кто ввозит библиотеку — знает про свой флаг', () {
    test('ни одного ввоза без заслонки', () {
      final lib = Directory('lib');
      expect(lib.existsSync(), isTrue, reason: 'тест гоняется из корня пакета');

      final missing = <String>[];
      var checked = 0;
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final src = entity.readAsStringSync();
        for (final entry in _pluginToFlag.entries) {
          if (!src.contains("import 'package:${entry.key}/")) continue;
          checked++;
          if (!src.contains(entry.value)) {
            missing.add('${entity.path} → ${entry.value}');
          }
        }
      }

      // Файлы есть и они найдены — иначе тест был бы зелёным ни о чём.
      expect(checked, greaterThanOrEqualTo(9));
      expect(
        missing,
        isEmpty,
        reason:
            'файл ввозит вынимаемую из облегчённой сборки библиотеку, но про '
            'свой флаг не знает: заслонку надо поставить либо здесь, либо '
            'у входа в возможность (и упомянуть флаг в пояснении)',
      );
    });
  });

  group('запасные пути вызываются и отвечают мягко', () {
    test('сжатие при отправке отдаёт исходный путь, а не бросает', () async {
      const src = '/nonexistent/secretly-lite-probe.mp4';
      expect(await VideoCompressor.compressForSend(src), src);
    });

    test('миниатюры: нет кадра — null, без исключения', () async {
      expect(VideoThumbnailCache.peek('secretly-lite-probe'), isNull);
      expect(
        await VideoThumbnailCache.forVideo(
          key: 'secretly-lite-probe',
          videoPath: '/nonexistent/secretly-lite-probe.mp4',
        ),
        isNull,
      );
    });

    test('обрезка: плёнка кадров пуста, вывоз — null', () async {
      expect(
        await videoTrimFilmstripFrames('/nonexistent/secretly-lite-probe.mp4'),
        isEmpty,
      );
      expect(
        await exportTrimmedVideoFile(
          '/nonexistent/secretly-lite-probe.mp4',
          startMs: 0,
          endMs: 1000,
        ),
        isNull,
      );
    });

    test('анимация стикера: null — вызывающий оставит статичный', () async {
      expect(
        await StickerAnimationService.instance.animate(
          cutoutPng: File('/nonexistent/secretly-lite-probe.png'),
          effect: StickerMotionEffect.pulse,
        ),
        isNull,
      );
    });

    test('перевод: опознание и перевод отдают null, роспуск безопасен', () async {
      final svc = MessageTranslationService.instance;
      expect(await svc.detectLanguage(''), isNull);
      expect(await svc.translate(text: '', targetBcp: 'ru'), isNull);
      expect(await svc.translate(text: 'hello', targetBcp: 'zzz'), isNull);
      expect(await svc.isModelReady('ru'), isFalse);
      await svc.dispose(); // не должно бросить
    });

    test('кодер H.264 остаётся чистой сборкой аргументов', () {
      H264Encoder.debugPlatform = H264Platform.android;
      addTearDown(() => H264Encoder.debugPlatform = null);
      expect(H264Encoder.variants(crf: 23, kbps: 1200), isNotEmpty);
    });
  });
}
