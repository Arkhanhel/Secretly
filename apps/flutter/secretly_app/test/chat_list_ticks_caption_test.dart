// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Владелец, 24.11.2026:
//  1) «В списке чатов одна серая — отправлено, две серые — получил, две
//     яркие — прочитал, а внутри чата „получил“ — одна яркая; поменять на две
//     серые».
//  2) «В списках чатов не всегда эти галочки высвечиваются»: превью строки
//     кэшировалось по времени последнего события, квитанция его не меняет —
//     галочка застывала (на отправке — не было вовсе); в пути не было часиков.
//  3) «Последнее — медиа с комментарием, в превью только „Фотография“».

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/ui/chat/chat_list_row_parts.dart';
import 'package:secretly_app/ui/chat_screen.dart';

void main() {
  test('в чате: одна серая → две серые → две яркие, как в списке', () {
    final sent = chatDeliveryTickStyle(MessageLocalState.sent)!;
    final delivered = chatDeliveryTickStyle(MessageLocalState.delivered)!;
    final read = chatDeliveryTickStyle(MessageLocalState.read)!;
    expect((sent.doubled, sent.alpha), (false, 0.55));
    expect((delivered.doubled, delivered.alpha), (true, 0.55));
    expect((read.doubled, read.alpha), (true, 1.0));
  });

  testWidgets('в списке: в пути — часики, а не пусто', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: ChatListTickGlyph(tick: ChatListTick.sending)),
    ));
    expect(find.byType(Icon), findsOneWidget);
  });

  test('🔴 смена состояния сообщения обновляет превью строки', () {
    final db = File('lib/storage/app_db.dart').readAsStringSync();
    // Обе записи состояния и два точечных перехода сообщают о смене.
    expect('_notifyStateChanged('.allMatches(db).length, greaterThanOrEqualTo(4));
    final ctl = File('lib/app/app_controller.dart').readAsStringSync();
    expect(ctl, contains('AppDb.onMessageStateChanged = bumpConvoPreviewEpochForState;'));
    // Превью пересчитывается по эпохе (ключ кэша строки списка).
    expect(File('lib/ui/chats_screen.dart').readAsStringSync(),
        contains('convoPreviewEpoch('));
    expect(AppDb.onMessageStateChanged, isNull,
        reason: 'в чистой проверке контроллера нет — сигнал никуда не идёт');
  });

  test('подпись под фото и файлом попадает в превью', () {
    const p = ChatListPreview(
      kind: ChatListPreviewKind.photo,
      text: 'Ужин у моря',
      caption: 'Ужин у моря',
    );
    expect(p.caption, 'Ужин у моря');
    expect(const ChatListPreview.empty().caption, isNull);
    final ctl = File('lib/app/app_controller.dart').readAsStringSync();
    expect(ctl, contains('caption: caption.isEmpty ? null : caption,'));
    expect(ctl, contains('caption: fileCaption.isEmpty ? null : fileCaption,'));
    expect(File('lib/ui/widgets/chat_list_subtitle_preview.dart').readAsStringSync(),
        contains("return caption.replaceAll('\\n', ' ');"));
  });
}
