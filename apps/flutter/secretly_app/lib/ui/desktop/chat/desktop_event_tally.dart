// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// ПОДСЧЁТ ОТВЕТОВ НА СОБЫТИЕ ДЛЯ ЛЕНТЫ КОМПЬЮТЕРА.
///
/// Как и опрос, событие живёт самой перепиской: приглашение и ответы «иду /
/// возможно / не иду» — обычные сообщения. Итог считается по ленте заново.
///
/// 🔴 ЧЕЙ ОТВЕТ — РЕШАЕТ ОТПРАВИТЕЛЬ, А НЕ ТЕКСТ КОМАНДЫ: иначе участник
/// отвечал бы за другого человека.
library;

import '../../../app/message_command_utils.dart';
import 'desktop_poll_tally.dart' show DesktopCardSource;

/// Ответы на событие.
abstract final class DesktopEventRsvp {
  static const String going = 'going';
  static const String maybe = 'maybe';
  static const String no = 'no';

  static bool isKnown(String status) =>
      status == going || status == maybe || status == no;
}

/// Событие для показа: что, когда, где и кто идёт.
class DesktopEventView {
  const DesktopEventView({
    required this.eventId,
    required this.title,
    required this.startMs,
    required this.description,
    required this.location,
    required this.going,
    required this.maybe,
    required this.declined,
    required this.myStatus,
  });

  final String eventId;
  final String title;
  final int startMs;
  final String description;
  final String location;

  /// Сколько человек ответило «иду», «возможно», «не иду».
  final int going;
  final int maybe;
  final int declined;

  /// Мой ответ или пустая строка.
  final String myStatus;

  int countFor(String status) {
    switch (status) {
      case DesktopEventRsvp.going:
        return going;
      case DesktopEventRsvp.maybe:
        return maybe;
      case DesktopEventRsvp.no:
        return declined;
    }
    return 0;
  }
}

/// Считает состояние всех событий ленты.
Map<String, DesktopEventView> desktopTallyEvents({
  required List<DesktopCardSource> entries,
  required String myProfileId,
}) {
  final specs = <String, EventCommand>{};
  // Последний ответ каждого человека по каждому событию.
  final answers = <String, Map<String, ({String status, int atMs})>>{};

  for (final e in entries) {
    final spec = parseEventCommand(e.text);
    if (spec != null) {
      specs.putIfAbsent(spec.eventId, () => spec);
      continue;
    }
    final rsvp = parseEventRsvpCommand(e.text);
    if (rsvp == null) continue;
    if (!DesktopEventRsvp.isKnown(rsvp.status)) continue;
    final author = e.authorProfileId.trim();
    final says = rsvp.voterProfileId.trim();
    if (says.isEmpty) continue;
    if (author.isNotEmpty && author != says) continue;
    final byVoter = answers.putIfAbsent(
      rsvp.eventId,
      () => <String, ({String status, int atMs})>{},
    );
    final existing = byVoter[says];
    if (existing == null || e.createdAtMs >= existing.atMs) {
      byVoter[says] = (status: rsvp.status, atMs: e.createdAtMs);
    }
  }

  final me = myProfileId.trim();
  final out = <String, DesktopEventView>{};
  for (final entry in specs.entries) {
    final byVoter = answers[entry.key] ?? const {};
    var going = 0;
    var maybe = 0;
    var declined = 0;
    var mine = '';
    for (final answer in byVoter.entries) {
      switch (answer.value.status) {
        case DesktopEventRsvp.going:
          going++;
        case DesktopEventRsvp.maybe:
          maybe++;
        case DesktopEventRsvp.no:
          declined++;
      }
      if (me.isNotEmpty && answer.key == me) mine = answer.value.status;
    }
    final spec = entry.value;
    out[entry.key] = DesktopEventView(
      eventId: entry.key,
      title: spec.title,
      startMs: spec.startMs,
      description: spec.description,
      location: spec.location,
      going: going,
      maybe: maybe,
      declined: declined,
      myStatus: mine,
    );
  }
  return out;
}
