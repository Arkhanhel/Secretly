// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// КАРТОЧКА ОПРОСА В ЛЕНТЕ КОМПЬЮТЕРА.
//
// 🔴 Опрос с телефона приходил строкой «📊 Опрос: …»: вариантов не видно,
// проголосовать нечем, итога нет. Голосование — это разговор, и ему место в
// переписке.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_poll_tally.dart';
import 'package:secretly_app/ui/desktop/chat/poll_card.dart';

DesktopPollView _poll({
  List<int> votes = const [2, 1, 0],
  int voters = 3,
  List<int> mine = const [],
  bool closed = false,
  bool creator = false,
  bool multiple = false,
  bool anonymous = false,
}) => DesktopPollView(
  pollId: 'p1',
  question: 'Когда встречаемся?',
  options: const ['В пятницу', 'В субботу', 'В воскресенье'],
  multiple: multiple,
  anonymous: anonymous,
  votesPerOption: votes,
  totalVoters: voters,
  myOptionIndices: mine,
  closed: closed,
  isCreator: creator,
);

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 420, child: child)),
);

void main() {
  testWidgets('показывает вопрос, варианты и счёт', (t) async {
    await t.pumpWidget(
      _host(
        DesktopPollCard(
          poll: _poll(),
          foreground: Colors.white,
          foregroundSoft: Colors.white70,
        ),
      ),
    );
    await t.pump();
    expect(find.text('Когда встречаемся?'), findsOneWidget);
    expect(find.text('В пятницу'), findsOneWidget);
    expect(find.text('В воскресенье'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'счёт голосов варианта');
    expect(find.text('Проголосовали: 3'), findsOneWidget);
    expect(find.text('Опрос'), findsOneWidget);
  });

  testWidgets('анонимный опрос подписан иначе', (t) async {
    await t.pumpWidget(
      _host(
        DesktopPollCard(
          poll: _poll(anonymous: true),
          foreground: Colors.white,
          foregroundSoft: Colors.white70,
        ),
      ),
    );
    await t.pump();
    expect(find.text('Анонимный опрос'), findsOneWidget);
  });

  testWidgets('🔴 нажатие на вариант — это голос', (t) async {
    final votes = <int>[];
    await t.pumpWidget(
      _host(
        DesktopPollCard(
          poll: _poll(),
          foreground: Colors.white,
          foregroundSoft: Colors.white70,
          onVote: votes.add,
        ),
      ),
    );
    await t.pump();
    await t.tap(find.text('В субботу'));
    expect(votes, [1]);
  });

  testWidgets('🔴 в завершённом опросе голосовать нельзя', (t) async {
    final votes = <int>[];
    await t.pumpWidget(
      _host(
        DesktopPollCard(
          poll: _poll(closed: true),
          foreground: Colors.white,
          foregroundSoft: Colors.white70,
          onVote: votes.add,
        ),
      ),
    );
    await t.pump();
    expect(find.text('Завершён'), findsOneWidget);
    await t.tap(find.text('В субботу'));
    expect(votes, isEmpty);
  });

  testWidgets('завершить опрос предлагается только его создателю', (t) async {
    await t.pumpWidget(
      _host(
        DesktopPollCard(
          poll: _poll(),
          foreground: Colors.white,
          foregroundSoft: Colors.white70,
          onClose: () {},
        ),
      ),
    );
    await t.pump();
    expect(find.text('Завершить опрос'), findsNothing);

    await t.pumpWidget(
      _host(
        DesktopPollCard(
          poll: _poll(creator: true),
          foreground: Colors.white,
          foregroundSoft: Colors.white70,
          onClose: () {},
        ),
      ),
    );
    await t.pump();
    expect(find.text('Завершить опрос'), findsOneWidget);
  });

  testWidgets('подсказка про несколько ответов — пока не проголосовал', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        DesktopPollCard(
          poll: _poll(multiple: true),
          foreground: Colors.white,
          foregroundSoft: Colors.white70,
        ),
      ),
    );
    await t.pump();
    expect(find.text('Можно выбрать несколько'), findsOneWidget);
  });

  group('проводка (по исходникам)', () {
    String read(String path) => File(path).readAsStringSync();

    test('🔴 лента собирает голоса до отбрасывания служебных', () {
      final section = read('lib/ui/desktop/app/desktop_chats_section.dart');
      final collect = section.indexOf('_pollSourceByEventId[event.eventId]');
      final hidden = section.indexOf('if (_isHiddenControlText(raw)) return null;');
      expect(collect, greaterThan(0));
      expect(hidden, greaterThan(0));
      expect(
        collect < hidden,
        isTrue,
        reason: 'голоса отбрасываются как служебные — собрать их надо раньше',
      );
    });

    test('лента считает и подключает голосование', () {
      final section = read('lib/ui/desktop/app/desktop_chats_section.dart');
      expect(section.contains('desktopTallyPolls('), isTrue);
      expect(section.contains('voteGroupPoll('), isTrue);
      expect(section.contains('closeGroupPoll('), isTrue);
      expect(section.contains('onPollVote:'), isTrue);
    });

    test('подписи опроса есть во всех восьми языках', () {
      for (final code in const [
        'ru', 'en', 'uk', 'es', 'pt', 'pt_BR', 'fr', 'de',
      ]) {
        final arb = read('lib/l10n/app_$code.arb');
        for (final key in const [
          'desktopPollTitle',
          'desktopPollAnonymous',
          'desktopPollClosed',
          'desktopPollVoters',
          'desktopPollMultipleHint',
          'desktopPollCloseAction',
        ]) {
          expect(arb.contains('"$key"'), isTrue, reason: '$code: $key');
        }
      }
    });
  });
}
