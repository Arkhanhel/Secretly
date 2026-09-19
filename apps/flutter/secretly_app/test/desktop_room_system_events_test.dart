// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// СЛУЖЕБНЫЕ СООБЩЕНИЯ КОМНАТЫ НА КОМПЬЮТЕРЕ.
//
// «Вошёл», «вышел», «сменили название» телефон показывает плашкой по центру, а
// компьютер выбрасывал их в том же месте, где раньше терялись карточки
// звонков (`_toMessageData` → `return null`). Комната молчала о себе: новый
// участник появлялся в списке без единого слова в ленте.
//
// Плашка — не пузырь: у неё нет автора, времени, стороны и галочек.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DColors(
      colors: kDColorsDark,
      child: SizedBox(width: 700, child: child),
    ),
  ),
);

MessageData _system(String text) => MessageData(
  id: 'sys-1',
  authorName: 'Игорь',
  text: text,
  time: '12:00',
  isSelf: false,
  isSystemEvent: true,
);

void main() {
  testWidgets('плашка показывает текст события', (t) async {
    await t.pumpWidget(_host(MessageBubble(message: _system('Игорь вошёл'))));
    await t.pump();
    expect(find.text('Игорь вошёл'), findsOneWidget);
  });

  testWidgets('🔴 у плашки нет ни автора, ни времени', (t) async {
    // У обычного пузыря в комнате оба есть, и если служебное событие поедет
    // по обычному пути, оно станет чьей-то репликой.
    await t.pumpWidget(
      _host(
        MessageBubble(
          message: _system('Игорь сменил название'),
          showPeerIdentity: true,
        ),
      ),
    );
    await t.pump();
    expect(find.text('Игорь'), findsNothing, reason: 'это не чья-то реплика');
    expect(find.text('12:00'), findsNothing, reason: 'у события нет времени');
  });

  testWidgets('обычный пузырь плашкой не становится', (t) async {
    await t.pumpWidget(
      _host(
        MessageBubble(
          message: MessageData(
            id: 'm1',
            authorName: 'Игорь',
            text: 'Привет',
            time: '12:00',
            isSelf: false,
          ),
          showPeerIdentity: true,
        ),
      ),
    );
    await t.pump();
    // Обычный текст идёт «богатым» виджетом (ссылки, упоминания), поэтому
    // ищем с `findRichText`. Плашка же — простой `Text` по центру.
    expect(
      find.textContaining('Привет', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Игорь'), findsOneWidget, reason: 'автор на месте');
  });

  test('🔴 лента компьютера действительно разбирает служебное событие', () {
    // Ветка стояла в том же `return null`, что и карточки звонков до
    // 20.05: без неё плашке просто неоткуда взяться.
    final section = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    expect(section.contains('payload is SystemEventV1'), isTrue);
    expect(section.contains('formatSystemEventText('), isTrue);
    expect(
      section.contains('isSystemEvent: true'),
      isTrue,
      reason: 'событие должно помечаться плашкой, а не обычным пузырём',
    );
  });
}
