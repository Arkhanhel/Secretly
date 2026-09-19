// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Четыре мелочи пузыря, сверенные с макетом.
//
// Каждая по отдельности — «·», но все четыре про одно: пузырь должен читаться
// пузырём, а не набором вложенных карточек.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/radii.dart';

Widget host(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: SizedBox(width: 760, child: child)),
  ),
);

MessageData msg({
  bool edited = false,
  bool continuation = false,
  bool isSelf = false,
  ReplyPreview? reply,
}) => MessageData(
  id: 'm1',
  payloadId: 'p1',
  authorName: 'Игорь',
  text: 'привет',
  time: '14:09',
  edited: edited,
  continuation: continuation,
  isSelf: isSelf,
  reply: reply,
);

void main() {
  // · «ИЗМЕНЕНО» — ПОСЛЕ ВРЕМЕНИ И СЛОВОМ ЦЕЛИКОМ.
  //
  // «изм.» перед временем сдвигало время с места: в столбике подвалов оно
  // оказывалось то у левого края, то правее на ширину сокращения, и взгляд,
  // ищущий время, каждый раз искал заново.
  group('«изменено»', () {
    testWidgets('стоит ПОСЛЕ времени', (t) async {
      await t.pumpWidget(host(MessageBubble(message: msg(edited: true))));
      // Видимая подпись — последняя: первой в дереве идёт невидимая копия,
      // которая держит место в конце абзаца.
      final time = t.getTopLeft(find.text('14:09').last);
      final edited = t.getTopLeft(find.text('изменено').last);
      expect(edited.dx, greaterThan(time.dx));
    });

    testWidgets('сокращения больше нет', (t) async {
      await t.pumpWidget(host(MessageBubble(message: msg(edited: true))));
      expect(find.text('изм.'), findsNothing);
      // Две: невидимая копия под место и видимая поверх.
      expect(find.text('изменено'), findsNWidgets(2));
    });

    testWidgets('не изменяли — подписи нет', (t) async {
      await t.pumpWidget(host(MessageBubble(message: msg())));
      expect(find.text('изменено'), findsNothing);
    });
  });

  // · У ПРОДОЛЖЕНИЯ ГРУППЫ СЖИМАЕТСЯ И ВЕРХНИЙ УГОЛ СО СТОРОНЫ ХВОСТА.
  //
  // Пока он оставался круглым, между пузырями одного автора светилась щель, и
  // группа из трёх сообщений читалась как три отдельных.
  group('угол продолжения', () {
    BorderRadius radiusOf(WidgetTester t) {
      // Текст ищем по вхождению: в конце абзаца теперь стоит невидимый пролёт
      // под подпись времени, и `toPlainText()` возвращает строку со знаком-
      // местозаполнителем — точное равенство больше не совпадает.
      final box = t.widget<Container>(
        find
            .ancestor(
              of: find.textContaining('привет'),
              matching: find.byType(Container),
            )
            .last,
      );
      return (box.decoration! as BoxDecoration).borderRadius! as BorderRadius;
    }

    testWidgets('первый в группе — верхние углы круглые', (t) async {
      await t.pumpWidget(host(MessageBubble(message: msg())));
      final r = radiusOf(t);
      expect(r.topLeft.x, DRadii.r16);
      expect(r.topRight.x, DRadii.r16);
    });

    testWidgets('чужое продолжение — сжат ЛЕВЫЙ верхний', (t) async {
      await t.pumpWidget(
        host(MessageBubble(message: msg(continuation: true))),
      );
      final r = radiusOf(t);
      expect(r.topLeft.x, DRadii.sm);
      expect(r.topRight.x, DRadii.r16);
    });

    testWidgets('своё продолжение — сжат ПРАВЫЙ верхний', (t) async {
      await t.pumpWidget(
        host(MessageBubble(message: msg(continuation: true, isSelf: true))),
      );
      final r = radiusOf(t);
      expect(r.topRight.x, DRadii.sm);
      expect(r.topLeft.x, DRadii.r16);
    });
  });

  // · ЦИТАТА В ПУЗЫРЕ — ТОЛЬКО ПОЛОСКА, БЕЗ ПОДЛОЖКИ.
  //
  // Подложка делала из цитаты вторую карточку внутри пузыря: пузырь в пузыре,
  // и глаз сперва читал её, а потом уже само сообщение.
  testWidgets('· у цитаты нет СВОЕЙ заливки — проверено по дереву', (t) async {
    await t.pumpWidget(
      host(
        MessageBubble(
          message: msg(
            reply: const ReplyPreview(
              authorName: 'Вы',
              text: 'Привет! Проверка связи',
            ),
          ),
        ),
      ),
    );

    // Все контейнеры между текстом цитаты и пузырём: ни один не красится и не
    // скругляется сам по себе.
    final between = find.ancestor(
      of: find.text('Привет! Проверка связи'),
      matching: find.byType(Container),
    );
    for (final w in t.widgetList<Container>(between)) {
      final d = w.decoration;
      if (d == null) continue;
      final box = d as BoxDecoration;
      // Дошли до самого пузыря — дальше не наша забота.
      if (box.borderRadius != null && box.color != null) break;
      expect(box.color, isNull);
    }
  });

  group('правила', () {
    final src = File(
      'lib/ui/desktop/chat/message_bubble.dart',
    ).readAsStringSync();

    // · ЦИТАТА В ПУЗЫРЕ — ТОЛЬКО ПОЛОСКА, БЕЗ ПОДЛОЖКИ.
    //
    // Подложка делала из цитаты вторую карточку внутри пузыря: пузырь в
    // пузыре, и глаз сперва читал её, а потом уже само сообщение.
    test('🔴 цитата — подложка цветом АВТОРА, как на телефоне и в телеграме', () {
      // 14.09 подложку убрали по макету, и цитату держала одна полоска
      // акцентного цвета. 16.09 владелец прислал скриншот телеграма, а у
      // телефона цитата давно такая: подложка оттенка автора, полоска и имя
      // того же цвета. Без цвета автора не понять с первого взгляда, КОГО
      // цитируют. Поведение закреплено в desktop_author_colour_reply_test.
      final i = src.indexOf('Widget _replyQuote(');
      final body = src.substring(i, src.indexOf('// E9 jump-to-reply', i));
      expect(body.contains('AvatarInitials.replyPanelColor('), isTrue);
      expect(body.contains('AvatarInitials.nicknameColor('), isTrue);
      expect(body.contains('Container(width: 2.5, color: stripColor)'), isFalse);
      // Одна строка текста под именем — как у телефона и у телеграма.
      expect(body.contains('maxLines: 1'), isTrue);
      expect(body.contains('maxWidth: 420'), isTrue);
    });

    // · СТРОКА ДЕЙСТВИЙ НАДВИНУТА НА ПУЗЫРЬ, А НЕ ВИСИТ НАД НИМ ПИЛЮЛЕЙ.
    test('· геометрия строки действий из макета', () {
      // 16.09.2026 строка переехала со связи слоёв на `OverlayPortal`
      // (подсказки кнопок роняли раскладку красным экраном — см.
      // `desktop_hover_bar_clickable_test.dart`). Числа макета те же:
      // −14 по вертикали, 8 от своего края.
      // 16.09.2026 (указание владельца): строка ЦЕЛИКОМ над пузырём, а не
      // надвинута на него на 14 точек — нижний край на зазор выше пузыря.
      expect(src.contains('- 14;'), isFalse);
      expect(
        src.contains('final bottom = info.overlaySize.height - (bubbleTop - _barGap);'),
        isTrue,
      );
      expect(src.contains('topLeft.dx + 8'), isTrue);
      expect(src.contains('topRight.dx - 8'), isTrue);
      // Панель, а не ряд отдельных кружков.
      expect(src.contains('borderRadius: BorderRadius.circular(DRadii.md)'), isTrue);
      expect(src.contains('color: c.hoverBar,'), isTrue);
      expect(src.contains('Colors.white.withValues(alpha: 0.09)'), isTrue);
      // Кнопки 26×26 радиусом 8.
      expect(src.contains('width: 26, height: 26,'), isTrue);
      expect(src.contains('BorderRadius.circular(DRadii.r8)'), isTrue);
    });

    test('у строки действий своя поверхность, а не тон всплывашек', () {
      final colors = File(
        'lib/ui/desktop/design/colors.dart',
      ).readAsStringSync();
      expect(colors.contains('hoverBar: Color(0xFF222C3A),'), isTrue);
      expect(kDColorsDark.hoverBar, const Color(0xFF222C3A));
      expect(kDColorsDark.hoverBar == kDColorsDark.elevated, isFalse);
    });
  });
}
