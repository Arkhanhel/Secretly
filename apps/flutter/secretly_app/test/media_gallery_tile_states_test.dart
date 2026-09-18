// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 Плитка галереи должна СКАЗАТЬ, что с ней, — и дать повторить.
//
// НАЙДЕНО ПО ЖАЛОБЕ ВЛАДЕЛЬЦА 15.09.2026: «в галерее комнаты плитки пустые».
// Разбор на живом телефоне показал две разные вещи.
//
// ВНЕШНЯЯ ПРИЧИНА В ТОТ РАЗ: связь на мобильном интернете отваливалась —
// половина запросов к релею падала по таймауту (`pump_inbox_failed`), и
// вложения просто не скачивались. Это не дефект окна.
//
// НО ОКНО ОБ ЭТОМ МОЛЧАЛО, И ВОТ ЭТО — ДЕФЕКТ. У плитки было ОДНО состояние
// «нет картинки», и серый значок фотографии означал сразу три разные вещи:
//
//   • «ещё качаю» — подожди;
//   • «не скачалось» — можно попробовать снова;
//   • «файла нет вовсе» — ждать нечего.
//
// Различить их было нельзя, повторить попытку — тоже: `_resolve()` выполнялся
// один раз при создании плитки, а нажатие вело в просмотрщик, которому нечего
// показать. Связь возвращалась, а сетка оставалась серой до перезахода.
//
// Теперь состояний три, и они говорят разное: кружок ожидания, картинка,
// стрелка «нажмите, чтобы повторить». Одинаково на телефоне и на компьютере.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final mobile = File(
    'lib/ui/widgets/conversation_media_gallery.dart',
  ).readAsStringSync();
  final desktop = File(
    'lib/ui/desktop/chat/details/desktop_media_gallery.dart',
  ).readAsStringSync();

  group('🔴 три состояния вместо одного', () {
    test('на телефоне', () {
      expect(mobile.contains('enum _CellPhase { loading, ready, failed, gone }'), isTrue);
      expect(mobile.contains('_CellPhase.failed'), isTrue);
      expect(mobile.contains('CircularProgressIndicator'), isTrue);
    });

    test('на компьютере', () {
      expect(desktop.contains('enum _TilePhase { loading, ready, failed, gone }'), isTrue);
      expect(desktop.contains('_TilePhase.failed'), isTrue);
      expect(desktop.contains('CircularProgressIndicator'), isTrue);
    });
  });

  group('🔴 нажатие по несостоявшейся плитке ПОВТОРЯЕТ загрузку', () {
    test('на телефоне', () {
      expect(mobile.contains('onTap: failed ? () => unawaited(_resolve())'), isTrue);
    });

    test('на компьютере', () {
      expect(
        desktop.contains('onTap: _phase == _TilePhase.failed'),
        isTrue,
      );
      expect(desktop.contains('unawaited(_resolve())'), isTrue);
    });
  });

  test('🔴 пустое видео — НЕ отказ, а «ещё не открывали»', () {
    // Ролик, который не открывали, намеренно не тянут целиком ради одной
    // картинки. Красить его в «не скачалось» значило бы звать нажимать
    // «повторить» там, где повторять нечего.
    // Смотрим РОВНО ветку видео: дальше начинается ветка картинки, где
    // «не скачалось» — законное состояние.
    final start = mobile.indexOf('if (_isVideo) {');
    final end = mobile.indexOf('final got = await widget.fetchFile(att);');
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final body = mobile.substring(start, end);
    expect(body.contains('_phase = _CellPhase.ready'), isTrue);
    expect(body.contains('_CellPhase.failed'), isFalse);
  });

  test('🔴 компьютер больше не качает заново на каждой перерисовке', () {
    // `future:` собирался прямо в `build`, то есть каждая перерисовка списка
    // начинала скачивание снова: у галереи на сотню вложений — сотня лишних
    // загрузок на каждый тик ленты. Мобильная галерея этот урок уже прошла.
    expect(desktop.contains('FutureBuilder<File?>('), isFalse);
    expect(desktop.contains('class _MediaTileState'), isTrue);
    expect(desktop.contains('void initState()'), isTrue);
  });

  test('обе стороны объясняют причину рядом с кодом', () {
    expect(mobile.contains('СОСТОЯНИЕ БЫЛО ОДНО'), isTrue);
    expect(desktop.contains('СОСТОЯНИЕ БЫЛО ОДНО'), isTrue);
  });

  group('🔴 «файла больше нет» — отдельное состояние, без «повторить»', () {
    // Найдено на живом телефоне: снимки августа в комнате не грузились
    // НИКОГДА и не загрузятся — реле ответило 404, байтов там больше нет, а
    // устройство подняли из резервной копии, в которой их и не было. Звать
    // человека нажимать «повторить» в таком случае — врать ему.
    test('код причины различает 404 от прочих отказов', () {
      expect(mobile.contains("return 'blob_gone'"), isTrue);
      expect(mobile.contains("const String kAttachmentGoneCode = 'blob_gone'"),
          isTrue);
    });

    test('на телефоне', () {
      expect(mobile.contains('_CellPhase.gone'), isTrue);
      expect(mobile.contains('Icons.image_not_supported_outlined'), isTrue);
    });

    test('на компьютере', () {
      expect(desktop.contains('_TilePhase.gone'), isTrue);
      expect(desktop.contains('image_off_24_regular'), isTrue);
    });

    test('🔴 отказ больше не немой: в журнал уходит код причины', () {
      // Здесь стоял `catch (_) { return null; }` над сетевой операцией с
      // расшифровкой — и почему плитки пустые, нельзя было узнать ниоткуда.
      expect(mobile.contains("DiagLog.event('media', 'attachment_fetch_failed'"),
          isTrue);
      // В журнал идут только известные слова, а не текст исключения.
      expect(mobile.contains('String _attachmentFailureCode('), isTrue);
      expect(mobile.contains('e.message.toString()'), isTrue);
    });
  });
}
