// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/attachments/attachment_naming.dart';

/// 🔴 ИМЯ ФАЙЛА (docs/TZ_ATTACHMENT_NAMING_2026-08-14.md).
///
/// ЖАЛОБА 14.08: «отправил другу app-release.apk — у него скачивается .bin, и
/// при пересылке в другое приложение тоже .bin». Имя у нас БЫЛО — отправитель
/// кладёт его в `filename` — и мы его выбрасывали, собирая имя заново из mime.
void main() {
  group('расширение', () {
    test('🔴 apk остаётся apk — тот самый случай владельца', () {
      expect(
        attachmentExtensionFor(
          filename: 'app-release.apk',
          mime: 'application/octet-stream',
        ),
        '.apk',
      );
    });

    test('имя отправителя сильнее типа', () {
      // Тип может приехать обезличенным или просто неверным; имя — то, что
      // человек видел своими глазами.
      expect(
        attachmentExtensionFor(filename: 'отчёт.docx', mime: 'text/plain'),
        '.docx',
      );
    });

    test('без имени берём тип', () {
      expect(attachmentExtensionFor(mime: 'image/jpeg'), '.jpg');
      expect(
        attachmentExtensionFor(mime: 'application/vnd.android.package-archive'),
        '.apk',
      );
    });

    test('ни имени, ни знакомого типа — пусто, а не выдуманное', () {
      expect(attachmentExtensionFor(mime: 'application/x-nonesuch'), '');
    });

    test('расширением считается последний сегмент — как в системе', () {
      // Спорить с файловой системой бессмысленно: она читает имя так же.
      // Незнакомое расширение не мешает — тип потом честно скажет «не знаю».
      expect(attachmentExtensionFor(filename: 'сборка.от.14.августа'), '.августа');
      expect(
        attachmentMimeFor(filename: 'сборка.от.14.августа'),
        'application/octet-stream',
      );
    });

    test('длинный хвост после точки расширением НЕ считается', () {
      expect(attachmentExtensionFor(filename: 'файл.оченьдлинныйхвост'), '');
    });
  });

  group('тип файла', () {
    test('🔴 обезличенный тип восстанавливается по имени', () {
      // Именно это ломало «Загрузки» на Android: с octet-stream система считает
      // файл двоичным мусором и не предлагает его установить или открыть.
      expect(
        attachmentMimeFor(
          filename: 'app-release.apk',
          mime: 'application/octet-stream',
        ),
        'application/vnd.android.package-archive',
      );
    });

    test('пустой тип восстанавливается по имени', () {
      expect(
        attachmentMimeFor(filename: 'договор.pdf', mime: ''),
        'application/pdf',
      );
    });

    test('осмысленный тип не подменяется', () {
      expect(
        attachmentMimeFor(filename: 'x.bin', mime: 'image/png'),
        'image/png',
      );
    });

    test('тип с параметрами обрезается до сути', () {
      expect(
        attachmentMimeFor(filename: 'a.txt', mime: 'text/plain; charset=utf-8'),
        'text/plain',
      );
    });

    test('ничего не известно — честное «не знаю»', () {
      expect(attachmentMimeFor(filename: 'файл', mime: ''), 'application/octet-stream');
    });
  });

  group('тип по имени с честным «не знаю»', () {
    test('🔴 незнакомое расширение даёт null, а НЕ octet-stream', () {
      // От этого зависит поведение вызывающих: они пишут
      // `_guessMime(p) ?? выбранныйСистемойТип`. Верни здесь «не знаю» — и
      // правка, которая чинит тип, затрёт настоящий тип от системного выбора
      // файлов.
      expect(attachmentMimeForOrNull('нечто.неизвестное'), isNull);
      expect(attachmentMimeForOrNull('файл-без-расширения'), isNull);
    });

    test('🔴 apk теперь распознаётся — раньше уходил как octet-stream', () {
      expect(
        attachmentMimeForOrNull('app-release.apk'),
        'application/vnd.android.package-archive',
      );
    });

    test('офис и архивы распознаются', () {
      expect(
        attachmentMimeForOrNull('смета.xlsx'),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      expect(attachmentMimeForOrNull('архив.rar'), 'application/vnd.rar');
    });

    test('🔴 svg, tiff и avif НЕ становятся изображениями при отправке', () {
      // Пузырь изображения рисует Flutter, а он их не декодирует: файл,
      // уходивший документом, стал бы «сломанной картинкой».
      expect(attachmentMimeForOrNull('рисунок.svg'), isNull);
      expect(attachmentMimeForOrNull('скан.tiff'), isNull);
      expect(attachmentMimeForOrNull('снимок.avif'), isNull);
    });

    test('но расширение по типу для них есть — имя не теряется', () {
      expect(attachmentExtensionFor(mime: 'image/svg+xml'), '.svg');
      expect(attachmentExtensionFor(mime: 'image/tiff'), '.tiff');
    });
  });

  group('имя для выгрузки', () {
    test('🔴 имя отправителя сохраняется целиком', () {
      expect(
        attachmentExportFileName(
          filename: 'app-release.apk',
          mime: 'application/octet-stream',
          createdAtMs: 1_700_000_000_000,
        ),
        'app-release.apk',
      );
    });

    test('имя без расширения дополняется по типу', () {
      expect(
        attachmentExportFileName(
          filename: 'договор',
          mime: 'application/pdf',
          createdAtMs: 1_700_000_000_000,
        ),
        'договор.pdf',
      );
    });

    test('🔴 документ без имени больше НЕ называется «music»', () {
      final name = attachmentExportFileName(
        mime: 'application/pdf',
        createdAtMs: DateTime(2026, 8, 14, 19, 35, 0).millisecondsSinceEpoch,
      );
      expect(name, 'file_20260814_193500.pdf');
      expect(name.contains('music'), isFalse);
    });

    test('снимок без имени зовётся по виду', () {
      expect(
        attachmentExportFileName(
          mime: 'image/jpeg',
          createdAtMs: DateTime(2026, 8, 14, 19, 35, 0).millisecondsSinceEpoch,
          kindStem: 'photo',
        ),
        'photo_20260814_193500.jpg',
      );
    });
  });

  group('безопасность имени', () {
    test('🔴 путь наружу вырезается — имя приходит от собеседника', () {
      // Иначе «имя файла» становится записью мимо папки назначения.
      expect(
        sanitizeAttachmentFileName('../../../etc/passwd'),
        'passwd',
      );
      expect(
        sanitizeAttachmentFileName(r'..\..\windows\system32\evil.dll'),
        'evil.dll',
      );
    });

    test('управляющие символы и разделители убираются', () {
      // Двоеточие и знак вопроса негодны для файловой системы; пробел законен и остаётся.
      expect(sanitizeAttachmentFileName('от чёт:2026?.pdf'), 'от чёт_2026_.pdf');
    });

    test('«.» и «..» именами не являются', () {
      expect(sanitizeAttachmentFileName('.'), '');
      expect(sanitizeAttachmentFileName('..'), '');
    });

    test('слишком длинное имя обрезается, расширение остаётся', () {
      final long = '${'я' * 400}.apk';
      final safe = sanitizeAttachmentFileName(long);
      expect(safe.length <= 180, isTrue);
      expect(safe.endsWith('.apk'), isTrue);
    });

    test('пустое имя остаётся пустым, а не превращается в мусор', () {
      expect(sanitizeAttachmentFileName('   '), '');
    });
  });
}
