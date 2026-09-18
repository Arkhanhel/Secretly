// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 СТРОКА СПИСКА ЧАТОВ — ПО ТЕЛЕГРАМУ.
//
// Указание владельца 16.09.2026 со скриншотом левой панели телеграма: «нам
// самое главное это размеры и как выглядит информация и превью последних смс».
//
// ЧТО БЫЛО НЕ ТАК. Галочки доставки стояли справа от ПРЕВЬЮ и показывались
// только тогда, когда непрочитанного нет:
//
//     if (item.unread > 0) _unreadBadge(c)
//     else if (item.delivery != none) _DeliveryTick(...)
//
// То есть о судьбе своего последнего сообщения строка сообщала через раз — а
// стоило собеседнику написать в ответ, галочки пропадали вовсе.
//
// В телеграме это две РАЗНЫЕ сведения в двух разных местах: галочки — про моё
// сообщение, они на строке имени слева от времени; счётчик — про чужие
// сообщения, он на строке превью. Друг друга они не вытесняют.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/chat_list_panel.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/avatar.dart';
import 'package:secretly_app/ui/widgets/avatar_initials.dart';

/// Галочка доставки — своего типа у неё нет (виджет приватный), поэтому ищем
/// по тому, что она рисует: сдвоенная «прочитано» — это `SizedBox` шириной 20
/// с двумя `Icon` внутри, одиночная — один `Icon`.
Finder _ticks() => find.byWidgetPredicate(
      (w) => w is Padding && w.padding == const EdgeInsets.only(left: 2),
    );

Widget _host(List<ChatListItem> items) => MaterialApp(
  home: Scaffold(
    body: DColors(
      colors: kDColorsDark,
      child: SizedBox(
        width: 320,
        height: 600,
        child: ChatListPanel(items: items, selectedId: null, onSelect: (_) {}),
      ),
    ),
  ),
);

void main() {
  testWidgets('🔴 галочки стоят рядом со ВРЕМЕНЕМ, а не с превью', (t) async {
    await t.pumpWidget(
      _host(const [
        ChatListItem(
          id: 'c1',
          name: 'Максим',
          preview: 'Отака фигня ребятки',
          time: '11:16',
          delivery: ChatDelivery.read,
        ),
      ]),
    );
    await t.pumpAndSettle();

    final time = t.getRect(find.text('11:16'));
    final preview = t.getRect(find.text('Отака фигня ребятки'));
    final tick = t.getRect(_ticks().first);

    expect(
      (tick.center.dy - time.center.dy).abs(),
      lessThan(6),
      reason: 'галочки снова уехали на строку превью',
    );
    expect(tick.right, lessThanOrEqualTo(time.left + 1));
    expect(tick.center.dy, lessThan(preview.top));
  });

  testWidgets('🔴 счётчик НЕ вытесняет галочки', (t) async {
    // Раньше одно исключало другое: приходило чужое сообщение — и о своём
    // отправленном строка переставала что-либо говорить.
    await t.pumpWidget(
      _host(const [
        ChatListItem(
          id: 'c1',
          name: 'Максим',
          preview: 'Отака фигня ребятки',
          time: '11:16',
          delivery: ChatDelivery.read,
          unread: 3,
        ),
      ]),
    );
    await t.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(_ticks(), findsOneWidget);
  });

  testWidgets('без своего сообщения галочек нет вовсе', (t) async {
    await t.pumpWidget(
      _host(const [
        ChatListItem(id: 'c1', name: 'Аня', preview: 'привет', time: '10:00'),
      ]),
    );
    await t.pumpAndSettle();
    expect(_ticks(), findsNothing);
  });

  testWidgets('🔴 у КОМНАТЫ автор — отдельной строкой над текстом', (t) async {
    // Было «Игорь: текст» одной строкой: при длинном имени текст обрезался
    // до пары слов. В телеграме автор — своя строка, сообщение — под ним.
    await t.pumpWidget(
      _host(const [
        ChatListItem(
          id: 'r1',
          name: '6 ГЕЕВ на миду',
          preview: 'Стикер',
          previewAuthor: 'Pavlo Haiduk',
          time: '00:13',
          kind: ChatKind.group,
        ),
      ]),
    );
    await t.pumpAndSettle();
    final author = t.getRect(find.text('Pavlo Haiduk'));
    final body = t.getRect(find.text('Стикер'));
    expect(body.top, greaterThanOrEqualTo(author.bottom - 1));
    expect(find.text('Pavlo Haiduk: Стикер'), findsNothing);
  });

  testWidgets('🔴 у ЛИЧНОГО чата — две строки текста и без «Вы:»', (t) async {
    await t.pumpWidget(
      _host(const [
        ChatListItem(
          id: 'c1',
          name: 'Не повредит',
          preview: 'Ленпосёлок: крайняя, молодёжная, сельская, солнечный '
              'переулок 12:00 Белый бус хундай и белая легковая Ситроен',
          previewIsMine: true,
          time: '12:00',
          delivery: ChatDelivery.read,
        ),
      ]),
    );
    await t.pumpAndSettle();
    final body = t.getRect(find.textContaining('Ленпосёлок'));
    // Две строки: выше одной, но не выше двух.
    expect(body.height, greaterThan(20));
    expect(body.height, lessThan(40));
    // Своё сообщение видно по галочкам — «Вы:» лишнее, как в телеграме.
    expect(find.textContaining('Вы:'), findsNothing);
  });

  testWidgets('🔴 выбранная строка — сплошная заливка, текст белый', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DColors(
            colors: kDColorsDark,
            child: SizedBox(
              width: 320,
              height: 600,
              child: ChatListPanel(
                items: const [
                  ChatListItem(
                    id: 'c1',
                    name: 'Максим',
                    preview: 'привет',
                    time: '11:16',
                  ),
                ],
                selectedId: 'c1',
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final name = t.widget<Text>(find.text('Максим'));
    expect(name.style?.color, Colors.white);
  });

  testWidgets('строки одного роста — и с коротким превью, и с длинным', (t) async {
    await t.pumpWidget(
      _host(const [
        ChatListItem(id: 'a', name: 'Короткий', preview: 'ок', time: '1'),
        ChatListItem(
          id: 'b',
          name: 'Длинный',
          preview: 'очень длинное сообщение, которое займёт две строки превью '
              'целиком и ещё немного сверх того',
          time: '2',
        ),
      ]),
    );
    await t.pumpAndSettle();
    // Имя, а не буква: одна буква совпала бы с заглушкой портрета.
    final a = t.getRect(find.text('Короткий'));
    final b = t.getRect(find.text('Длинный'));
    // Шаг — ровно телеграмные 70, портрет — 50: замеры скриншота владельца.
    expect(b.top - a.top, moreOrLessEquals(70, epsilon: 0.5));
    expect(t.widget<Avatar>(find.byType(Avatar).first).size, 50);
  });

  testWidgets('🔴 между строками — тонкая черта, но не рядом с выбранной', (t) async {
    // На скриншоте телеграма строки разделены чертой от колонки текста до
    // края. У выбранной строки черты нет ни сверху, ни снизу: сплошную
    // заливку она бы резала.
    Finder dividers() =>
        find.byWidgetPredicate((w) => w is Positioned && w.top == -1);
    const items = [
      ChatListItem(id: 'a', name: 'Первый', preview: '1', time: '1'),
      ChatListItem(id: 'b', name: 'Второй', preview: '2', time: '2'),
      ChatListItem(id: 'c', name: 'Третий', preview: '3', time: '3'),
    ];
    Widget host(String? selected) => MaterialApp(
      home: Scaffold(
        body: DColors(
          colors: kDColorsDark,
          child: SizedBox(
            width: 320,
            height: 600,
            child: ChatListPanel(
              items: items,
              selectedId: selected,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );

    await t.pumpWidget(host(null));
    await t.pumpAndSettle();
    // Над первой строкой черты нет — только МЕЖДУ строками.
    expect(dividers(), findsNWidgets(2));
    // Черта начинается от колонки текста, а не от края портрета.
    final line = t.getRect(dividers().first);
    final name = t.getRect(find.text('Второй'));
    expect((line.left - name.left).abs(), lessThan(1.5));

    await t.pumpWidget(host('b'));
    await t.pumpAndSettle();
    expect(dividers(), findsNothing);
  });

  testWidgets('🔴 имени достаётся ВСЁ место до времени, время — у края', (t) async {
    // Было `Flexible` у имени и `Spacer` перед временем в одном ряду: ряд
    // делит свободное место между ними поровну, и имени доставалось не больше
    // половины — «Sophie Benne…» при пустом месте рядом. Время же вставало
    // сразу за этой половиной, у каждой строки на своём месте.
    await t.pumpWidget(
      _host(const [
        ChatListItem(id: 'a', name: 'Аня', preview: 'ок', time: 'вс'),
        ChatListItem(id: 'b', name: 'Sophie Ben', preview: 'ок', time: 'пн'),
      ]),
    );
    await t.pumpAndSettle();

    // Время обеих строк прижато к одному краю.
    final r1 = t.getRect(find.text('вс'));
    final r2 = t.getRect(find.text('пн'));
    expect((r1.right - r2.right).abs(), lessThan(0.5));

    // Имя не усечено: его ширина — естественная ширина той же надписи.
    final name = find.text('Sophie Ben');
    final text = t.widget<Text>(name);
    // Стиль — с тем, что надпись наследует от окружения (у темы Material
    // свой межбуквенный интервал).
    final style = DefaultTextStyle.of(t.element(name)).style.merge(text.style);
    final painter = TextPainter(
      text: TextSpan(text: 'Sophie Ben', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(t.getSize(name).width, moreOrLessEquals(painter.width, epsilon: 0.5));
    painter.dispose();
  });

  group('🔴 заливка выбранной строки читается при любом цвете окна', () {
    // Белый текст на светло-сиреневом пресете (#AF89FB) давал контраст
    // 2,7 : 1 — имя открытого чата едва читалось.
    double contrastWithWhite(Color c) => 1.05 / (c.computeLuminance() + 0.05);

    for (final accent in const [
      Color(0xFF4C8DF6), // синий тёмной темы
      Color(0xFFAF89FB), // светло-сиреневый пресет
      Color(0xFFFCD34D), // жёлтый — самый светлый из мыслимых
    ]) {
      test('акцент ${accent.toARGB32().toRadixString(16)}', () {
        final fill = selectedChatRowFill(accent);
        expect(contrastWithWhite(fill), greaterThanOrEqualTo(4.5));
        // Оттенок сохраняется: цвет только темнеет.
        final a = HSLColor.fromColor(accent);
        final f = HSLColor.fromColor(fill);
        expect((a.hue - f.hue).abs(), lessThan(3));
        expect(f.lightness, lessThanOrEqualTo(a.lightness));
      });
    }

    test('достаточно тёмный цвет не трогается', () {
      const dark = Color(0xFF3050A0);
      expect(selectedChatRowFill(dark), dark);
    });
  });

  testWidgets('🔴 автор превью — цветом этого человека, как на телефоне', (t) async {
    // Телефон пишет автора превью комнаты его цветом по устройству — тем же,
    // что имя в пузыре. Один человек обязан быть одного цвета везде.
    const room = ChatListItem(
      id: 'r1',
      name: 'Комната',
      preview: 'Стикер',
      previewAuthor: 'Pavlo Haiduk',
      previewAuthorSeed: 'dev-pavlo',
      time: '00:13',
      kind: ChatKind.group,
    );
    await t.pumpWidget(_host(const [room]));
    await t.pumpAndSettle();
    final author = t.widget<Text>(find.text('Pavlo Haiduk'));
    expect(
      author.style?.color,
      AvatarInitials.nicknameColor(seed: 'dev-pavlo'),
    );
    expect(author.style?.fontWeight, FontWeight.w600);

    // На выделенной строке — белый: цветное имя на заливке не читается.
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DColors(
            colors: kDColorsDark,
            child: SizedBox(
              width: 320,
              height: 600,
              child: ChatListPanel(
                items: const [room],
                selectedId: 'r1',
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.text('Pavlo Haiduk')).style?.color,
      Colors.white,
    );
  });
}
