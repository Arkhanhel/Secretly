// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ДЕСКТОП ПОКАЗЫВАЛ РАЗМЕТКУ СЫРЬЁМ.
//
// Телефон разбирает `**жирный**`, `__курсив__`, `~~зачёркнутый~~`, `` `код` ``,
// `||спойлер||` и рисует упоминания фишками (`buildChatMessageTextSpans`).
// Десктоп выводил `LinkifiedText` — только ссылки. Сообщение, набранное на
// телефоне жирным, на компьютере читалось «**жирным**» со звёздочками, которых
// человек не писал, а спойлер показывался открытым текстом рядом с палками.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

Widget host(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: SizedBox(width: 760, child: child)),
  ),
);

MessageData msg(String text, {List<MsgMentionV1> mentions = const []}) =>
    MessageData(
      id: 'm1',
      payloadId: 'p1',
      authorName: 'Игорь',
      text: text,
      time: '14:19',
      mentions: mentions,
    );

/// Весь текст, который реально нарисован (склейка всех кусков).
String painted(WidgetTester t) {
  final out = StringBuffer();
  for (final w in t.widgetList<Text>(find.byType(Text))) {
    out.write(w.data ?? w.textSpan?.toPlainText() ?? '');
  }
  return out.toString();
}

void main() {
  testWidgets('🔴 звёздочек жирного на экране нет', (t) async {
    await t.pumpWidget(host(MessageBubble(message: msg('это **важно** очень'))));
    await t.pump();
    final all = painted(t);
    expect(all.contains('важно'), isTrue);
    expect(
      all.contains('**'),
      isFalse,
      reason: 'звёздочки, которых человек не писал',
    );
  });

  testWidgets('курсив, зачёркнутый и код тоже разбираются', (t) async {
    await t.pumpWidget(
      host(MessageBubble(message: msg('__к__ ~~з~~ `код`'))),
    );
    await t.pump();
    final all = painted(t);
    expect(all.contains('__'), isFalse);
    expect(all.contains('~~'), isFalse);
    expect(all.contains('`'), isFalse);
  });

  testWidgets('🔴 спойлер закрыт, а не показан открытым', (t) async {
    await t.pumpWidget(host(MessageBubble(message: msg('тайна: ||секрет||'))));
    await t.pump();
    final all = painted(t);
    expect(all.contains('||'), isFalse);
    // Сам текст спойлера в дереве есть — он прозрачный под точками и держит
    // размер, — но палок вокруг него быть не должно.
  });

  testWidgets('🔴 упоминание рисуется фишкой', (t) async {
    await t.pumpWidget(
      host(
        MessageBubble(
          message: msg(
            '@Игорь, посмотри',
            mentions: const [
              MsgMentionV1(
                type: MsgMentionV1.profileType,
                start: 0,
                end: 6,
                profileId: 'p1',
              ),
            ],
          ),
          selfProfileId: 'me',
        ),
      ),
    );
    await t.pump();
    // Фишка — это WidgetSpan с собственной подложкой внутри текста.
    expect(find.text('@Игорь'), findsOneWidget);
    expect(painted(t).contains('посмотри'), isTrue);
  });

  testWidgets('обычный текст остаётся обычным', (t) async {
    await t.pumpWidget(host(MessageBubble(message: msg('просто привет'))));
    await t.pump();
    expect(painted(t).contains('просто привет'), isTrue);
  });

  group('правила', () {
    final bubble = File(
      'lib/ui/desktop/chat/message_bubble.dart',
    ).readAsStringSync();
    final rich = File(
      'lib/ui/desktop/chat/message_rich_text.dart',
    ).readAsStringSync();

    test('🔴 разбор ОБЩИЙ с телефоном, а не свой', () {
      // Свой разошёлся бы с телефоном на первой же правке, и одно сообщение
      // выглядело бы на двух устройствах по-разному.
      expect(rich.contains('buildChatMessageTextSpans('), isTrue);
      expect(bubble.contains('LinkifiedText('), isFalse);
    });

    test('цвета — десктопные, через ЛОКАЛЬНУЮ тему', () {
      // Общий разборщик берёт их из `colorScheme`, а десктоп живёт на своей
      // палитре. Локальная тема не трогает ни общий код, ни тему окна.
      expect(rich.contains('primary: c.deliveryIndicator'), isTrue);
      expect(rich.contains('onSurface: c.textPrimary'), isTrue);
      expect(rich.contains('base.colorScheme.copyWith('), isTrue);
    });

    test('разметка упоминаний доезжает из payload', () {
      final section = File(
        'lib/ui/desktop/app/desktop_chats_section.dart',
      ).readAsStringSync();
      expect(section.contains('mentions: payload.mentions,'), isTrue);
      expect(bubble.contains('final List<MsgMentionV1> mentions;'), isTrue);
    });

    test('🔴 «@admins» красится обращением только тем, кому оно достаётся', () {
      // У обычного участника такая фишка — чужое обращение, и красить её как
      // «зовут меня» было бы неправдой.
      final section = File(
        'lib/ui/desktop/app/desktop_chats_section.dart',
      ).readAsStringSync();
      expect(
        section.contains(
          '_roomMembersById[widget.controller.profileId]?.isAdmin ?? false',
        ),
        isTrue,
      );
    });
  });
}
