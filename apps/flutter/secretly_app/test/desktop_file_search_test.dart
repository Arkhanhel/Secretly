// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Поиск по файлам: что считать именем и что считать совпадением.
//
// 🔴 ЧТО БЫЛО. Поле в шапке обещало поиск «по чатам, людям, сообщениям», а
// вложений не находил никто: `searchChatMatches` работает по ТЕКСТУ
// сообщения, и присланный «договор.pdf» был для поиска невидим.
//
// Имени файла нет ни в одном указателе: таблица `attachments` хранит ключ,
// размер и срок жизни, а имя лежит ВНУТРИ зашифрованного груза. Значит поиск
// по файлам — это разбор каждого события, и цена ошибки в разборе выше
// обычного: лишнее совпадение заставит расшифровать и показать не то, а
// пропущенное сделает вид, что файла в переписке нет.

import 'package:flutter/widgets.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ui/desktop/app/desktop_file_match.dart';

AttachmentEventV1 att({
  String? filename,
  String? mime,
  String? caption,
  String? musicTitle,
  String? musicArtist,
  int sizeBytes = 1024,
}) => AttachmentEventV1(
  eventId: 'e1',
  blobId: 'b1',
  fileKeyB64: 'k',
  sizeBytes: sizeBytes,
  mime: mime,
  caption: caption,
  filename: filename,
  musicTitle: musicTitle,
  musicArtist: musicArtist,
);

final _ru = lookupAppLocalizations(const Locale('ru'));

void main() {
  group('имя вложения', () {
    test('имя файла — первое', () {
      expect(
        attachmentDisplayName(att(filename: 'Договор.pdf', caption: 'вот')),
        'Договор.pdf',
      );
    });

    test('у музыки без имени файла берутся теги', () {
      expect(
        attachmentDisplayName(att(musicTitle: 'Kashmir', musicArtist: 'LZ')),
        'LZ — Kashmir',
      );
      expect(attachmentDisplayName(att(musicTitle: 'Kashmir')), 'Kashmir');
    });

    test('иначе подпись, иначе пусто', () {
      expect(attachmentDisplayName(att(caption: 'скрин ошибки')), 'скрин ошибки');
      expect(attachmentDisplayName(att()), '');
    });
  });

  group('совпадение', () {
    test('находит по имени без учёта регистра', () {
      expect(attachmentMatchesQuery(att(filename: 'Договор.pdf'), 'догов'), isTrue);
      expect(attachmentMatchesQuery(att(filename: 'Договор.pdf'), 'ДОГОВ'.toLowerCase()), isTrue);
      expect(attachmentMatchesQuery(att(filename: 'Договор.pdf'), 'pdf'), isTrue);
    });

    test('находит по тегам музыки и по подписи', () {
      expect(attachmentMatchesQuery(att(musicTitle: 'Kashmir'), 'kash'), isTrue);
      expect(attachmentMatchesQuery(att(musicArtist: 'Led Zeppelin'), 'zeppelin'), isTrue);
      expect(attachmentMatchesQuery(att(caption: 'скрин ошибки'), 'ошиб'), isTrue);
    });

    test('🔴 по типу файла НЕ ищет', () {
      // Иначе запрос «image» выдал бы все снимки переписки и вытеснил бы те
      // несколько файлов, которые человек действительно искал.
      expect(
        attachmentMatchesQuery(att(filename: 'a.bin', mime: 'image/png'), 'image'),
        isFalse,
      );
    });

    test('пустой запрос не совпадает ни с чем', () {
      expect(attachmentMatchesQuery(att(filename: 'Договор.pdf'), ''), isFalse);
    });
  });

  group('палитра', () {
    final palette = File(
      'lib/ui/desktop/app/desktop_spotlight.dart',
    ).readAsStringSync();

    test('🔴 пока обходы идут — крутилка, а не «ничего не найдено»', () {
      // Сверка без учёта пробелов: важна развилка, а не отступ, с которым
      // её напечатали (выдача переехала из окна под поле — вложенность
      // сменилась, смысл нет).
      final flat = palette.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flat.contains(
          '? ((_searchingMessages || _searchingFiles) '
          '? _loadingRow(c) : _emptyState(c))',
        ),
        isTrue,
        reason: 'ответ «нет» до конца поиска — неправда',
      );
    });

    test('обход по файлам идёт рядом с текстовым, а не после него', () {
      expect(palette.contains('unawaited(_runMessageSearch(q, seq));'), isTrue);
      expect(palette.contains('unawaited(_runFileSearch(q, seq));'), isTrue);
    });

    test('оба обхода отменяются одним номером запроса', () {
      expect(palette.contains('final seq = ++_searchSeq;'), isTrue);
      expect(palette.contains('if (!mounted || seq != _searchSeq) return;'), isTrue);
    });
  });

  group('подпись под именем', () {
    test('тип берётся из расширения, а без него — из mime', () {
      expect(attachmentMetaLine(att(filename: 'a.pdf', sizeBytes: 2048), _ru), 'PDF · 2.0 КБ');
      expect(attachmentMetaLine(att(mime: 'image/png', sizeBytes: 500), _ru), 'PNG · 500 Б');
      // Тот же формат, что под кадром в ленте: размер считает одна функция.
    });

    test('размер округляется по ступеням', () {
      expect(formatAttachmentSize(0, _ru), '');
      expect(formatAttachmentSize(999, _ru), '999 Б');
      expect(formatAttachmentSize(1024 * 1024 * 3, _ru), '3.0 МБ');
      expect(formatAttachmentSize(1024 * 1024 * 1024 * 2, _ru), '2.0 ГБ');
    });

    test('файл без имени и без типа показывает только размер', () {
      expect(attachmentMetaLine(att(sizeBytes: 100), _ru), '100 Б');
      // Размер неизвестен — строка не врёт нулём, а ставит прочерк.
      expect(attachmentMetaLine(att(sizeBytes: 0), _ru), '—');
    });
  });
}

// ---------------------------------------------------------------------------
// Палитра: «ничего не найдено» только когда обходы закончились.
//
// 🔴 Обходы идут секундами — сообщения и файлы расшифровываются по событию.
// Всё это время палитра писала «Ничего не найдено» над пустотой, а потом
// выкладывала находки. Видел живьём: запрос «привет» сперва дал «Ничего не
// найдено», и только через несколько секунд — шесть сообщений.
