// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ПЕРЕСЫЛАЛСЯ ТОЛЬКО ТЕКСТ.
//
// Указание владельца 16.09.2026: «убедись что каждая функция в чате работает
// безукоризненно».
//
// Пункт «Переслать» в меню сообщения показывался ТОЛЬКО у текста, и то же
// самое у «Сохранить». Правило «не показывать то, что всё равно откажет»
// соблюдалось честно — но на телефоне снимки, голосовые, файлы и наклейки
// пересылаются давно (`ForwardDraftItem.attachment` / `.sticker`). То есть
// одно и то же меню на двух устройствах предлагало разное, и человек,
// привыкший пересылать фотографии с телефона, на компьютере молча не находил
// пункта — худший вид отказа: без отказа.
//
// Теперь три случая, и каждый уходит своим путём: текст — командой пересылки с
// подписью «от кого», наклейка — тем же вызовом, что и отправка новой,
// вложение — файлом, тем же путём, что перетаскивание.
//
// 🔴 ВЛОЖЕНИЕ ПЕРЕЗАЛИВАЕТСЯ, А НЕ ОТДАЁТСЯ ССЫЛКОЙ НА ТОТ ЖЕ БЛОБ. Отдать
// чужому получателю тот же blob значило бы показать серверу один файл в двух
// переписках — то есть сам факт пересылки.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _methodBody(String src, String signature) {
  final start = src.indexOf(signature);
  if (start < 0) throw StateError('не нашли $signature');
  // Конец ищем после скобки ТЕЛА: у метода с параметрами на нескольких
  // строках первая «\n  }» — это закрытие списка параметров.
  final open = src.indexOf(' {\n', start);
  if (open < 0) throw StateError('не нашли тело $signature');
  final end = src.indexOf('\n  }\n', open);
  if (end <= start) throw StateError('не нашли конец $signature');
  return src.substring(start, end);
}

void main() {
  final section = File(
    'lib/ui/desktop/app/desktop_chats_section.dart',
  ).readAsStringSync();
  final panel = File(
    'lib/ui/desktop/chat/chat_thread_panel.dart',
  ).readAsStringSync();

  test('🔴 пункт «Переслать» больше не заперт за текстом', () {
    expect(
      panel.contains('!m.isTextMessage)\n                                      ? null'),
      isFalse,
      reason: 'ограничение по виду сообщения вернулось',
    );
    expect(
      panel.contains('onForward: widget.onForwardMessage == null'),
      isTrue,
    );
    expect(panel.contains('onSave: widget.onSaveMessage == null'), isTrue);
  });

  // 16.09.2026 пересылка и «Сохранить» переехали на общий помощник
  // `_sendForwardedCopy`: одно сообщение и выделенная пачка уходят одним и тем
  // же путём, и разойтись им не на чем.
  test('одно сообщение пересылается тем же путём, что и пачка', () {
    expect(
      section.contains(
        'Future<void> _forwardMessage(MessageData m) => _forwardMessages([m]);',
      ),
      isTrue,
    );
    expect(
      section.contains(
        'Future<void> _saveMessage(MessageData m) => _saveMessages([m]);',
      ),
      isTrue,
    );
  });

  group('🔴 пересылка разбирает три случая', () {
    final body = _methodBody(section, 'Future<_CopyOutcome> _sendForwardedCopy(');
    final flow = _methodBody(
      section,
      'Future<void> _forwardMessages(List<MessageData> messages) async {',
    );

    test('наклейка уходит как наклейка', () {
      expect(body.contains('sendSticker('), isTrue);
    });

    test('вложение уходит файлом — в комнату и в личный чат по-разному', () {
      expect(body.contains('sendGroupAttachmentFile('), isTrue);
      expect(body.contains('sendAttachmentFile('), isTrue);
    });

    test('текст по-прежнему уходит с подписью «от кого»', () {
      expect(body.contains('buildForwardCommand('), isTrue);
      expect(body.contains('authorName: originAuthor'), isTrue);
    });

    test('🔴 подпись под снимком не теряется — едет вместе с ним', () {
      // С 16.09.2026 окно показывает подписи вложений, поэтому подпись
      // пересылается в самом вложении, а не отдельным сообщением.
      expect(body.contains('final caption = text.isEmpty ? null : text;'), isTrue);
      expect('caption: caption,'.allMatches(body).length, 2);
      expect(body.contains('if (text.isNotEmpty) await sendText(text);'), isFalse);
    });

    test('🔴 пересланный снимок остаётся снимком, а не файлом', () {
      // Снимок уходит без имени; документ — с именем ОТПРАВИТЕЛЯ, но не с
      // именем файла из кэша (17.09.2026).
      expect(
        body.contains('filename: (asMedia || givenName.isEmpty) ? null : givenName,'),
        isTrue,
      );
    });

    test('🔴 нечего слать — говорим вслух, а не молчим', () {
      expect(body.contains('_CopyOutcome.noFile'), isTrue);
      expect(flow.contains('Вложение не скачано — переслать нечего'), isTrue);
    });

    test('получатель выбирается один раз на всю пачку', () {
      final ask = flow.indexOf('ForwardTargetDialog.show(');
      final loop = flow.indexOf('for (final m in r.allowed)');
      expect(ask, greaterThan(0));
      expect(loop, greaterThan(ask));
    });
  });

  group('🔴 «Сохранить» делает ровно то же, только себе', () {
    final body = _methodBody(
      section,
      'Future<void> _saveMessages(List<MessageData> messages) async {',
    );

    test('те же три случая — тем же помощником', () {
      expect(body.contains('_sendForwardedCopy('), isTrue);
    });

    test('получатель — всегда я', () {
      expect(body.contains('peerProfileId: myPid'), isTrue);
    });

    test('нечего сохранять — говорим вслух', () {
      expect(body.contains('Вложение не скачано — сохранять нечего'), isTrue);
    });
  });

  test('🔴 файл берётся из ленты, а payload не разбирается второй раз', () {
    final body = _methodBody(
      section,
      'Future<String?> _forwardableAttachmentPath(',
    );
    // Поиск конверта вынесен в `_attachmentPayloadOf` (им же пользуется
    // пересылка себе), но смысл прежний: берём разобранное лентой, а не
    // разбираем payload второй раз.
    expect(body.contains('_attachmentPayloadOf('), isTrue);
    expect(
      _methodBody(section, 'AttachmentEventV1? _attachmentPayloadOf(')
          .contains('_attachmentsByMessageId.values'),
      isTrue,
    );
    expect(body.contains('ensureCachedAttachmentFile('), isTrue);
    // Готовый путь из пузыря — первым: скачивать заново то, что уже лежит,
    // значит ждать там, где ждать нечего.
    expect(body.indexOf('attachment.filePath'), lessThan(body.indexOf('ensureCachedAttachmentFile(')));
  });

  test('проверка приватности осталась на обоих путях', () {
    expect(
      section.contains('Это сообщение нельзя переслать из-за ограничений приватности.'),
      isTrue,
    );
    expect(
      section.contains('Это сообщение нельзя сохранить из-за ограничений приватности.'),
      isTrue,
    );
  });
}
