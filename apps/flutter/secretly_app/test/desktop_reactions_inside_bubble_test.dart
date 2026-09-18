// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 РЕАКЦИИ — ВНУТРИ ПУЗЫРЯ, КАК НА ТЕЛЕФОНЕ.
//
// УКАЗАНИЕ ВЛАДЕЛЬЦА 16.09.2026: «сделай чтобы реакции на смс были такие же
// как в мобильной версии внутри пузырей и с анимацией при вставливании
// реакций».
//
// ЧТО БЫЛО. 14.09.2026 фишки вынесли ОТДЕЛЬНОЙ СТРОКОЙ под пузырь — так
// нарисовано в макете, и так у них один набор цветов вместо двух (под своей
// фишкой иначе живой переход от синего к фиолетовому). Указание владельца
// новее — оно и главнее; расхождение с телефоном, из-за которого одно и то же
// сообщение выглядело на двух устройствах по-разному, ушло.
//
// ЦЕНА ВОЗВРАТА ЧЕСТНАЯ: цветов снова два набора. На своём пузыре фишка белая
// на просвет — единственный цвет, читаемый на любом участке перехода, каким бы
// его ни выбрали в темах. На чужом — оттенок выбранного цвета, как на телефоне.
//
// И ЕЩЁ ОДНО, ЧЕГО НЕ БЫЛО ВОВСЕ: полоска портретов. Сводка реакций
// схлопывала список в «эмодзи, число, моя ли» ещё в разделе чатов, и фишка
// физически не могла ответить «кто», хотя на телефоне отвечает.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

const _actors = <ReactionActor>[
  ReactionActor(profileId: 'P-1', name: 'Игорь'),
  ReactionActor(profileId: 'P-2', name: 'Аня'),
];

MessageData _msg({
  bool self = false,
  List<MessageReaction> reactions = const <MessageReaction>[],
}) => MessageData(
  id: 'm1',
  payloadId: 'p1',
  authorName: self ? 'Вы' : 'Игорь',
  text: 'привет',
  time: '14:19',
  isSelf: self,
  reactions: reactions,
);

Widget _host(Widget child) => MaterialApp(
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 120),
        child: SizedBox(width: 760, child: child),
      ),
    ),
  ),
);

void main() {
  final src = File(
    'lib/ui/desktop/chat/message_bubble.dart',
  ).readAsStringSync();
  final section = File(
    'lib/ui/desktop/app/desktop_chats_section.dart',
  ).readAsStringSync();

  testWidgets('🔴 фишка стоит ВНУТРИ пузыря, а не под ним', (t) async {
    await t.pumpWidget(
      _host(
        MessageBubble(
          message: _msg(
            reactions: const [
              MessageReaction(emoji: '👍', count: 2, actors: _actors),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    final text = t.getRect(find.textContaining('привет'));
    final time = t.getRect(find.text('14:19'));
    final chip = t.getRect(find.text('2'));

    // Реакция живёт между текстом и временем — то есть в подвале пузыря.
    expect(
      chip.top,
      greaterThan(text.top),
      reason: 'фишка обязана быть ниже текста сообщения',
    );
    expect(
      chip.bottom,
      lessThanOrEqualTo(time.bottom + 1),
      reason: 'фишка ушла ниже времени — значит она снова под пузырём',
    );
  });

  testWidgets('🔴 портреты поставивших — в самой фишке', (t) async {
    await t.pumpWidget(
      _host(
        MessageBubble(
          // Без большого портрета автора рядом: он даёт те же буквы, и в
          // проверке они мешали бы отличить одно от другого.
          showPeerIdentity: false,
          message: _msg(
            reactions: const [
              MessageReaction(emoji: '👍', count: 2, actors: _actors),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    // Заглушки портретов — буквы имён, тем же счётчиком, что на телефоне:
    // одно слово даёт два знака.
    expect(find.text('ИГ'), findsOneWidget);
    expect(find.text('АН'), findsOneWidget);
  });

  testWidgets('одинокая реакция показывает только знак, без числа', (t) async {
    await t.pumpWidget(
      _host(
        MessageBubble(
          showPeerIdentity: false,
          message: _msg(
            reactions: const [
              MessageReaction(
                emoji: '🔥',
                count: 1,
                actors: [ReactionActor(profileId: 'P-1', name: 'Игорь')],
              ),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('1'), findsNothing);
    expect(find.text('ИГ'), findsOneWidget);
  });

  testWidgets('🔴 без реакций пузырь выглядит ровно как раньше', (t) async {
    await t.pumpWidget(_host(MessageBubble(message: _msg())));
    await t.pumpAndSettle();
    // По вхождению: в конце абзаца стоит невидимый пролёт под подпись времени.
    final before = t.getRect(find.textContaining('привет'));

    await t.pumpWidget(
      _host(
        MessageBubble(
          message: _msg(
            reactions: const [
              MessageReaction(emoji: '👍', count: 1, actors: _actors),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final after = t.getRect(find.textContaining('привет'));
    // Пустой слот не занимает ничего: текст стоит там же, пока реакций нет.
    expect(before.top, after.top);
  });

  testWidgets('нажатие по фишке отдаётся наружу', (t) async {
    final tapped = <String>[];
    await t.pumpWidget(
      _host(
        MessageBubble(
          message: _msg(
            reactions: const [
              MessageReaction(emoji: '👍', count: 2, actors: _actors),
            ],
          ),
          onReactionTap: tapped.add,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('2'), warnIfMissed: true);
    await t.pump();
    expect(tapped, ['👍']);
  });

  group('правила', () {
    test('🔴 слот реакций один на все виды пузыря — в подвале', () {
      final i = src.indexOf('Widget _metaRow(');
      final body = src.substring(i, i + 2600);
      expect(body.contains('Flexible(child: _reactionsSlot(c, isSelf)),'), isTrue);
    });

    test('🔴 реакции и время — ОДНА строка, а не столбик', () {
      // Жалоба владельца 16.09.2026: «реакции почему-то находятся НАД датой».
      // В телеграме это одна строка: фишки влево, время с галочками вправо.
      final i = src.indexOf('Widget _metaRow(');
      final body = src.substring(i, i + 2600);
      expect(
        body.contains('children: [_reactionsSlot(c, isSelf), meta],'),
        isFalse,
        reason: 'столбик вернулся — подвал снова в два роста',
      );
      expect(body.contains('alignment: Alignment.centerRight'), isTrue);
      expect(body.contains('crossAxisAlignment: CrossAxisAlignment.end'), isTrue);
    });

    test('🔴 кадр без подписи получает слот отдельно — у него нет подвала', () {
      // Снимок и ролик без подписи носят время пилюлей поверх кадра (с
      // 16.09.2026 — одна отрисовка на снимок, ролик и альбом,
      // `_visualMessage`): на ленте слот стоит под кадром, в пузыре с шапкой —
      // внутри пузыря.
      final i = src.indexOf('Widget _visualMessage(');
      expect(i, greaterThan(0));
      final body = src.substring(i, src.indexOf('\n  }\n', i));
      expect(body.contains('child: _reactionsSlot(c, isSelf)),'), isTrue);
      expect(
        body.contains('else\n            _reactionsSlot(c, isSelf, inset: true),'),
        isTrue,
      );
    });

    test('🔴 снимок ТОЖЕ дорастает до первой реакции, а не прыгает', () {
      // Слот у кадра стоит всегда; поля живут ВНУТРИ него, иначе под каждым
      // снимком без подписи оставалась бы пустая полоса, а условие «показывать
      // слот, только когда реакции есть» убило бы сам смысл слота.
      expect(
        src.contains('if (!hasCaption && m.reactions.isNotEmpty)'),
        isFalse,
        reason: 'условие вернулось — пузырь снова прыгает',
      );
      final i = src.indexOf('Widget _reactionsSlot(');
      final body = src.substring(i, i + 1400);
      expect(body.contains('EdgeInsets.fromLTRB(13, 5, 13, 7)'), isTrue);
    });

    test('🔴 большое эмодзи тоже носит реакции', () {
      final i = src.indexOf('Widget _buildSoloEmoji(');
      expect(i, greaterThan(0));
      expect(
        src.substring(i, i + 1600).contains('_reactionsSlot(c, isSelf)'),
        isTrue,
      );
    });

    test('🔴 пузырь ДОРАСТАЕТ до первой реакции, а не прыгает', () {
      final i = src.indexOf('Widget _reactionsSlot(');
      final body = src.substring(i, i + 900);
      expect(body.contains('AnimatedSize('), isTrue);
      expect(body.contains('milliseconds: 260'), isTrue);
      expect(body.contains('Curves.easeOutCubic'), isTrue);
      // Без этого фишку резало пополам, пока слот раскрывается.
      expect(body.contains('clipBehavior: Clip.none'), isTrue);
    });

    test('🔴 фишка оживает на появление — ключ включает токен', () {
      expect(
        src.contains(r"ValueKey('${m.id}|${r.emoji}|$token')"),
        isTrue,
      );
      expect(src.contains('NotoLottieMode.once'), isTrue);
      expect(src.contains('NotoLottieMode.looping'), isFalse);
    });

    test('🔴 имена и портреты доходят до пузыря, а не теряются в сводке', () {
      expect(section.contains('bubble.ReactionActor('), isTrue);
      expect(section.contains('avatarPath: r.actorAvatarPath'), isTrue);
      // Порядок фишек телефонный: сначала те, кого больше.
      expect(section.contains('byEmoji[b]!.length.compareTo(byEmoji[a]!.length)'), isTrue);
    });

    test('цвета — два набора: на своей заливке и на чужом тоне', () {
      final i = src.indexOf('if (widget.mine) {', src.indexOf('class _ReactionChipState'));
      final body = src.substring(i, i + 600);
      expect(body.contains('Colors.white.withValues'), isTrue);
      expect(body.contains('c.accentPrimary.withValues'), isTrue);
    });
  });
}
