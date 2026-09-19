// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// «Сохранить» — пересылка самому себе, и ничего больше.
//
// 🔴 В макете четвёртым разделом рейки стоит закладка, и первым ответом на неё
// напрашивается «завести хранилище сохранённых сообщений». Оно не нужно:
// переписка с самим собой в приложении уже есть («Избранное»), она
// синхронизируется с телефоном и умеет всё, что умеет обычный чат — поиск,
// вложения, закрепление. Вторая сущность рядом означала бы два списка, которые
// разойдутся, и объяснение человеку разницы, которой нет.
//
// Пункт меню избавляет от трёх действий: «Переслать» → найти себя в списке →
// нажать. Туда же и попадёт.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final section = File(
    'lib/ui/desktop/app/desktop_chats_section.dart',
  ).readAsStringSync();
  final menu = File(
    'lib/ui/desktop/chat/message_context_menu.dart',
  ).readAsStringSync();
  final panel = File(
    'lib/ui/desktop/chat/chat_thread_panel.dart',
  ).readAsStringSync();

  test('пункт есть и пропадает без обработчика', () {
    // 19.09.2026: подписи меню уехали в переводы.
    expect(menu.contains('label: l10n.saveAction'), isTrue);
    expect(
      menu.contains('if (onSave != null)'),
      isTrue,
      reason: 'правило окна: нет обработчика — нет и пункта',
    );
  });

  test('🔴 получатель — Я, и хранилища рядом не заводится', () {
    final i = section.indexOf('Future<void> _saveMessages(');
    expect(i, greaterThan(0));
    final body = section.substring(i, i + 3600);
    expect(
      body.contains('peerProfileId: myPid'),
      isTrue,
      reason: '«Избранное» — обычная переписка с собой, а не второй склад',
    );
    expect(body.contains('widget.controller.profileId'), isTrue);
  });

  test('🔴 запрет на пересылку действует и на сохранение', () {
    // Проверку делает общий отбор `_forwardableOf` — тот же, что у пересылки.
    final i = section.indexOf('Future<void> _saveMessages(');
    final body = section.substring(i, i + 3600);
    expect(body.contains('_forwardableOf(messages)'), isTrue);
    final j = section.indexOf('_forwardableOf(\n    List<MessageData> messages,');
    expect(j, greaterThan(0));
    expect(
      section.substring(j, j + 900).contains('canForwardFromProfile('),
      isTrue,
      reason:
          'человек, запретивший пересылать свои сообщения, запретил это и '
          '«себе в закладки» — обойти запрет через другой пункт меню нельзя',
    );
  });

  test('🔴 вид сообщения БОЛЬШЕ НЕ ограничен — как и у пересылки', () {
    // До 16.09.2026 «Сохранить» и «Переслать» показывались только у текста:
    // формат пересылки несёт текст с подписью «от кого», а вложение надо
    // заливать в переписку заново. Правило «не показывать то, что откажет»
    // соблюдалось — но на телефоне снимки, голосовые и наклейки сохраняются
    // и пересылаются давно, и одно меню на двух устройствах предлагало разное.
    // Заливку взял на себя хозяин окна (см. `_saveMessage`).
    expect(panel.contains('onSave: widget.onSaveMessage == null'), isTrue);
    expect(
      panel.contains('!m.isTextMessage'),
      isFalse,
      reason: 'ограничение по виду сообщения вернулось',
    );
    final i = section.indexOf('Future<_CopyOutcome> _sendForwardedCopy(');
    expect(i, greaterThan(0));
    final body = section.substring(i, i + 3600);
    expect(body.contains('sendSticker('), isTrue);
    expect(body.contains('sendAttachmentFile('), isTrue);
  });
}
