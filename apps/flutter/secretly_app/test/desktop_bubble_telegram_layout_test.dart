// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ПУЗЫРЬ ВЫГЛЯДИТ КАК В ТЕЛЕГРАМЕ — ПО СТРОКАМ, А НЕ «ПОХОЖЕ».
//
// Указание владельца 16.09.2026 со скриншотом телеграма: «реакции почему-то
// находятся над датой и они слишком большие… изучи полностью визуальную часть
// телеграм и сделай у нас так же! Каждая линия! Каждая деталь!»
//
// ЧТО БЫЛО НЕ ТАК.
//
//   1. Подвал был СТОЛБИКОМ: сверху фишки реакций, снизу время. В телеграме
//      это одна строка — фишки влево, время с галочками вправо, — и подвал
//      занимает один рост вместо двух.
//
//   2. Время стояло у ЛЕВОГО края, вслед за текстом. У широкого сообщения оно
//      оказывалось посреди пузыря, и взгляд каждый раз искал его заново. В
//      телеграме у времени постоянный угол — правый нижний.
//
//   3. Фишка реакции была крупнее телеграмной: 18-й знак и поля 7×3 против
//      15-го и 6×2. Внутри пузыря это заметно — фишка спорила с самим текстом.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

MessageData _msg({
  required String text,
  bool self = false,
  List<MessageReaction> reactions = const <MessageReaction>[],
}) => MessageData(
  id: 'm1',
  payloadId: 'p1',
  authorName: self ? 'Вы' : 'Игорь',
  text: text,
  time: '20:38',
  isSelf: self,
  reactions: reactions,
);

/// Текст сообщения ищем по вхождению, а не по равенству: в конце абзаца
/// теперь стоит невидимый пролёт под подпись времени, и `toPlainText()`
/// возвращает строку с добавленным знаком-местозаполнителем.
Finder _body(String part) => find.textContaining(part);

/// Подпись времени. В строчном случае их ДВЕ: невидимая копия, которая держит
/// место в конце абзаца, и видимая поверх. Видимая добавлена в `Stack` второй,
/// поэтому берём последнюю.
Finder _time() => find.text('20:38').last;

Widget _host(Widget child) => MaterialApp(
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: SizedBox(width: 760, child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('🔴 у КОРОТКОГО сообщения время в ТОЙ ЖЕ строке', (t) async {
    // «го 21:07 ✓✓» в телеграме занимает одну строку, а не две. Условия «если
    // текст короче N» нет: в конец текста вставлен невидимый пролёт шириной с
    // подпись, и дальше решает обычный перенос строк.
    await t.pumpWidget(
      _host(MessageBubble(showPeerIdentity: false, message: _msg(text: 'го'))),
    );
    await t.pumpAndSettle();
    final text = t.getRect(_body('го'));
    final time = t.getRect(_time());
    expect(
      text.height,
      lessThan(30),
      reason: 'абзац стал выше одной строки — время снова уехало вниз',
    );
    expect(time.center.dy, greaterThan(text.top));
    expect(time.center.dy, lessThan(text.bottom));
  });

  testWidgets('🔴 у ДЛИННОГО — переезжает вниз само', (t) async {
    await t.pumpWidget(
      _host(
        MessageBubble(
          showPeerIdentity: false,
          message: _msg(
            text: 'Достаточно длинное сообщение, чтобы подпись времени уже не '
                'помещалась в конце последней строки и перенеслась вниз сама '
                'вместе с невидимым пролётом, который под неё оставлен',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final text = t.getRect(_body('Достаточно длинное'));
    final time = t.getRect(_time());
    expect(text.height, greaterThan(30), reason: 'иначе проверка пустая');
    expect(
      time.top,
      greaterThan(text.top + 18),
      reason: 'подпись обязана уехать ниже первой строки',
    );
  });

  testWidgets('🔴 время прижато к ПРАВОМУ краю пузыря', (t) async {
    await t.pumpWidget(
      _host(
        MessageBubble(
          showPeerIdentity: false,
          message: _msg(
            text: 'Достаточно длинное сообщение, чтобы пузырь стал широким '
                'и разница между краями была видна',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final text = t.getRect(_body('Достаточно длинное'));
    final time = t.getRect(_time());
    expect(
      (time.right - text.right).abs(),
      lessThan(2),
      reason: 'подпись уехала от правого края — время потеряло свой угол',
    );
  });

  testWidgets('🔴 с реакциями время ОСТАЁТСЯ в их строке', (t) async {
    // Подвал уже занят фишками — вклеивать время в текст там нечего.
    await t.pumpWidget(
      _host(
        MessageBubble(
          showPeerIdentity: false,
          message: _msg(
            text: 'го',
            reactions: const [
              MessageReaction(
                emoji: '❤️',
                count: 1,
                actors: [ReactionActor(profileId: 'P-1', name: 'Игорь')],
              ),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final text = t.getRect(_body('го'));
    final time = t.getRect(_time());
    final heart = t.getRect(find.text('❤️'));
    expect(time.center.dy, greaterThan(text.bottom));
    // И по-прежнему в одной строке с фишкой.
    expect((heart.center.dy - time.center.dy).abs(), lessThan(12));
  });

  testWidgets('🔴 с переводом время НЕ налезает на него', (t) async {
    await t.pumpWidget(
      _host(
        MessageBubble(
          showPeerIdentity: false,
          translatedText: 'Поехали',
          message: _msg(text: 'го'),
        ),
      ),
    );
    await t.pumpAndSettle();
    final translated = t.getRect(_body('Поехали'));
    final time = t.getRect(_time());
    expect(
      time.top,
      greaterThanOrEqualTo(translated.bottom - 2),
      reason: 'подпись, приклеенная к низу абзаца, накрыла бы перевод',
    );
  });

  testWidgets('🔴 короткое сообщение РАСШИРЯЕТСЯ под время', (t) async {
    // В телеграме пузырь «ок» шире слова «ок»: он вмещает время.
    await t.pumpWidget(
      _host(MessageBubble(showPeerIdentity: false, message: _msg(text: 'ок'))),
    );
    await t.pumpAndSettle();
    final text = t.getRect(_body('ок'));
    final time = t.getRect(_time());
    expect(text.width, greaterThan(time.width));
    expect(time.right, lessThanOrEqualTo(text.right + 1));
  });
}
