// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ВЛОЖЕНИЕ И НИТЬ СОБСТВЕННЫХ ПИСЕМ В ПОДДЕРЖКУ (компьютерная версия).
//
// Панель поддержки на компьютере умела только текст и показывала только
// ОТВЕТЫ. Здесь проверяется то, что от неё теперь требуется: файл читается,
// предел размера соблюдается ДО отправки, картинка ужимается, а свои письма
// переживают закрытие окна.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/ui/desktop/workspace/support_attachment.dart';
import 'package:secretly_app/ui/desktop/workspace/support_sent.dart';

Uint8List _noisyPng(int w, int h) {
  final im = img.Image(width: w, height: h);
  var seed = 7;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // Шум, а не заливка: залитый прямоугольник сжимается почти в ничто, и
      // проверка «файл больше предела» на нём ничего не проверяет.
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      im.setPixelRgb(x, y, seed & 0xff, (seed >> 8) & 0xff, (seed >> 16) & 0xff);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('secretly_support_test');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('тип файла', () {
    test('по расширению, регистр не важен', () {
      expect(desktopSupportMimeFor('Снимок.PNG'), 'image/png');
      expect(desktopSupportMimeFor('log.txt'), 'text/plain');
      expect(desktopSupportMimeFor('trace.log'), 'text/plain');
      expect(desktopSupportMimeFor('отчёт.pdf'), 'application/pdf');
      expect(desktopSupportMimeFor('photo.heic'), 'image/heic');
    });

    test('незнакомое и безымянное — общий тип, а не догадка', () {
      expect(desktopSupportMimeFor('dump.bin'), 'application/octet-stream');
      expect(desktopSupportMimeFor('README'), 'application/octet-stream');
    });
  });

  group('подготовка вложения', () {
    test('файл в пределах — берём как есть, имя от пути', () async {
      final f = File('${tmp.path}/Снимок экрана.png')
        ..writeAsBytesSync(_noisyPng(8, 8));
      final res = await prepareDesktopSupportAttachment(f.path);
      expect(res.ok, isTrue);
      expect(res.file!.name, 'Снимок экрана.png');
      expect(res.file!.mime, 'image/png');
      expect(res.file!.shrunk, isFalse);
      expect(res.file!.isImage, isTrue);
    });

    test('которого нет — «не прочитать», без исключения наружу', () async {
      final res = await prepareDesktopSupportAttachment('${tmp.path}/нет.txt');
      expect(res.ok, isFalse);
      expect(res.problem, DesktopSupportAttachmentProblem.unreadable);
    });

    test('пустой файл — тоже «не прочитать»: отправлять нечего', () async {
      final f = File('${tmp.path}/пусто.log')..writeAsBytesSync(<int>[]);
      final res = await prepareDesktopSupportAttachment(f.path);
      expect(res.problem, DesktopSupportAttachmentProblem.unreadable);
    });

    test('🔴 большой НЕ рисунок — отказ до отправки, а не после', () async {
      final f = File('${tmp.path}/дамп.bin')
        ..writeAsBytesSync(List<int>.filled(4096, 42));
      final res = await prepareDesktopSupportAttachment(f.path, maxBytes: 1024);
      expect(res.ok, isFalse);
      expect(res.problem, DesktopSupportAttachmentProblem.tooLarge);
    });

    test('🔴 большой снимок экрана ужимается и уходит', () async {
      final png = _noisyPng(900, 700);
      final f = File('${tmp.path}/Снимок.png')..writeAsBytesSync(png);
      final res = await prepareDesktopSupportAttachment(
        f.path,
        maxBytes: 200 * 1024,
        targetBytes: 120 * 1024,
      );
      expect(res.ok, isTrue, reason: 'картинку ужать можно — значит, уходит');
      expect(res.file!.shrunk, isTrue);
      expect(res.file!.bytes.length, lessThanOrEqualTo(200 * 1024));
      expect(res.file!.originalBytes, png.length);
      // Ужатое ушло в JPEG — имя обязано говорить правду о содержимом.
      expect(res.file!.name, 'Снимок.jpg');
      expect(res.file!.mime, 'image/jpeg');
    });
  });

  group('сжатие', () {
    test('не картинку не трогаем — возвращаем null', () {
      final bytes = Uint8List.fromList(utf8.encode('это просто текст'));
      expect(shrinkDesktopSupportImage(bytes), isNull);
    });

    test('картинка становится меньше цели', () {
      final out = shrinkDesktopSupportImage(
        _noisyPng(600, 400),
        targetBytes: 60 * 1024,
      );
      expect(out, isNotNull);
      expect(out!.length, lessThan(_noisyPng(600, 400).length));
    });
  });

  group('свои письма', () {
    late Map<String, String> store;
    late DesktopSupportSentStore sent;

    setUp(() {
      store = <String, String>{};
      sent = DesktopSupportSentStore(
        read: (k) async => store[k],
        write: (k, v) async => store[k] = v,
      );
    });

    test('пусто в начале и после мусора в хранилище', () async {
      expect(await sent.load(), isEmpty);
      store[DesktopSupportSentStore.storageKey] = 'это не json';
      expect(await sent.load(), isEmpty);
    });

    test('письмо переживает закрытие окна вместе с именем вложения', () async {
      await sent.append(
        const DesktopSupportSent(
          text: 'Не приходят уведомления',
          tsMs: 1700000000000,
          attachmentName: 'Снимок.jpg',
        ),
      );
      final again = await DesktopSupportSentStore(
        read: (k) async => store[k],
        write: (k, v) async => store[k] = v,
      ).load();
      expect(again, hasLength(1));
      expect(again.single.text, 'Не приходят уведомления');
      expect(again.single.attachmentName, 'Снимок.jpg');
      expect(again.single.hasAttachment, isTrue);
    });

    test('🔴 сами байты вложения на диск НЕ уходят — только имя', () async {
      await sent.append(
        const DesktopSupportSent(
          text: 'вот файл',
          tsMs: 1,
          attachmentName: 'секрет.png',
        ),
      );
      final raw = store[DesktopSupportSentStore.storageKey]!;
      final decoded = jsonDecode(raw) as List<dynamic>;
      expect((decoded.single as Map)['a'], 'секрет.png');
      expect(raw.contains('b64'), isFalse);
    });

    test('нить не растёт бесконечно: хранится последняя полусотня', () async {
      for (var i = 0; i < DesktopSupportSentStore.keep + 12; i++) {
        await sent.append(DesktopSupportSent(text: 'письмо $i', tsMs: i));
      }
      final all = await sent.load();
      expect(all, hasLength(DesktopSupportSentStore.keep));
      expect(all.first.text, 'письмо 12');
      expect(all.last.text, 'письмо ${DesktopSupportSentStore.keep + 11}');
    });

    test('сбой записи не теряет письмо на экране', () async {
      final failing = DesktopSupportSentStore(
        read: (k) async => store[k],
        write: (k, v) async => throw const FileSystemException('диск занят'),
      );
      final out = await failing.append(
        const DesktopSupportSent(text: 'ушло', tsMs: 5),
      );
      expect(out.single.text, 'ушло');
    });
  });
}
