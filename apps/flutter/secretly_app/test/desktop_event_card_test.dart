// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// КАРТОЧКА СОБЫТИЯ В ЛЕНТЕ КОМПЬЮТЕРА.
//
// 🔴 Событие с телефона приходило строкой «📅 Название»: ни времени, ни места,
// ни ответов «иду / не иду». Ответить было нечем.
//
// Как и опрос, событие живёт самой перепиской: приглашение и ответы — обычные
// сообщения, и чей ответ — решает отправитель, а не текст команды.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_event_tally.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_poll_tally.dart'
    show DesktopCardSource;
import 'package:secretly_app/ui/desktop/chat/event_card.dart';

const _me = 'me-1';
const _igor = 'igor-1';

DesktopCardSource _spec({String author = _me, int at = 1000}) =>
    DesktopCardSource(
      text: buildEventCommand(
        eventId: 'e1',
        title: 'Встреча',
        startMs: DateTime(2026, 9, 18, 19, 5).millisecondsSinceEpoch,
        description: 'Обсудим выпуск',
        location: 'У Игоря',
      ),
      authorProfileId: author,
      createdAtMs: at,
    );

DesktopCardSource _rsvp(
  String author,
  String status, {
  int at = 2000,
  String? claims,
}) => DesktopCardSource(
  text: buildEventRsvpCommand(
    eventId: 'e1',
    status: status,
    voterProfileId: claims ?? author,
  ),
  authorProfileId: author,
  createdAtMs: at,
);

DesktopEventView? tally(List<DesktopCardSource> entries) =>
    desktopTallyEvents(entries: entries, myProfileId: _me)['e1'];

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 420, child: child)),
);

void main() {
  group('подсчёт ответов', () {
    test('событие без ответов', () {
      final ev = tally([_spec()]);
      expect(ev!.title, 'Встреча');
      expect(ev.location, 'У Игоря');
      expect(ev.going, 0);
      expect(ev.myStatus, '');
    });

    test('ответы считаются по людям', () {
      final ev = tally([
        _spec(),
        _rsvp(_me, DesktopEventRsvp.going),
        _rsvp(_igor, DesktopEventRsvp.maybe),
      ]);
      expect(ev!.going, 1);
      expect(ev.maybe, 1);
      expect(ev.myStatus, DesktopEventRsvp.going);
    });

    test('передумал — считается последний ответ', () {
      final ev = tally([
        _spec(),
        _rsvp(_igor, DesktopEventRsvp.going, at: 2000),
        _rsvp(_igor, DesktopEventRsvp.no, at: 2500),
      ]);
      expect(ev!.going, 0);
      expect(ev.declined, 1);
    });

    test('🔴 ответить за другого человека нельзя', () {
      final ev = tally([
        _spec(),
        _rsvp('stranger-1', DesktopEventRsvp.going, claims: _igor),
      ]);
      expect(ev!.going, 0);
    });

    test('неизвестный ответ не считается', () {
      final ev = tally([_spec(), _rsvp(_igor, 'может_быть')]);
      expect(ev!.going + ev.maybe + ev.declined, 0);
    });
  });

  group('карточка', () {
    DesktopEventView view({String myStatus = '', int going = 2}) =>
        DesktopEventView(
          eventId: 'e1',
          title: 'Встреча',
          startMs: DateTime(2026, 9, 18, 19, 5).millisecondsSinceEpoch,
          description: 'Обсудим выпуск',
          location: 'У Игоря',
          going: going,
          maybe: 1,
          declined: 0,
          myStatus: myStatus,
        );

    testWidgets('показывает что, когда и где', (t) async {
      await t.pumpWidget(
        _host(
          DesktopEventCard(
            event: view(),
            foreground: Colors.white,
            foregroundSoft: Colors.white70,
          ),
        ),
      );
      await t.pump();
      expect(find.text('Встреча'), findsOneWidget);
      expect(find.text('18.09 · 19:05'), findsOneWidget);
      expect(find.text('У Игоря'), findsOneWidget);
      expect(find.text('Обсудим выпуск'), findsOneWidget);
      expect(find.text('Иду · 2'), findsOneWidget);
      expect(find.text('Возможно · 1'), findsOneWidget);
      expect(find.text('Не иду'), findsOneWidget, reason: 'ноль не пишем');
    });

    testWidgets('🔴 нажатие — это ответ', (t) async {
      final answers = <String>[];
      await t.pumpWidget(
        _host(
          DesktopEventCard(
            event: view(),
            foreground: Colors.white,
            foregroundSoft: Colors.white70,
            onRsvp: answers.add,
          ),
        ),
      );
      await t.pump();
      await t.tap(find.text('Не иду'));
      expect(answers, [DesktopEventRsvp.no]);
    });

    test('время без даты не показывается', () {
      expect(DesktopEventCard.formatStart(0), '');
    });
  });

  test('проводка: лента считает события и подключает ответы', () {
    final section = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    expect(section.contains('desktopTallyEvents('), isTrue);
    expect(section.contains('rsvpGroupEvent('), isTrue);
    expect(section.contains('onEventRsvp:'), isTrue);
    expect(section.contains('kEventRsvpCommandPrefix'), isTrue);
  });

  test('подписи события есть во всех восьми языках', () {
    for (final code in const [
      'ru', 'en', 'uk', 'es', 'pt', 'pt_BR', 'fr', 'de',
    ]) {
      final arb = File('lib/l10n/app_$code.arb').readAsStringSync();
      for (final key in const [
        'desktopEventTitle',
        'desktopEventGoing',
        'desktopEventMaybe',
        'desktopEventNo',
      ]) {
        expect(arb.contains('"$key"'), isTrue, reason: '$code: $key');
      }
    }
  });
}
