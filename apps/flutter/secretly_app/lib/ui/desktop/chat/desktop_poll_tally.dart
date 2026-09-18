// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// ПОДСЧЁТ ГОЛОСОВ ОПРОСА ДЛЯ ЛЕНТЫ КОМПЬЮТЕРА.
///
/// Опрос живёт не отдельной таблицей, а самой перепиской: сам опрос, голоса и
/// закрытие — это служебные сообщения. Поэтому итог считается по ленте каждый
/// раз заново, как на телефоне.
///
/// 🔴 ЧЕЙ ГОЛОС — РЕШАЕТ ОТПРАВИТЕЛЬ, А НЕ ТЕКСТ КОМАНДЫ. В команде написано,
/// кто голосует, и без сверки любой участник голосовал бы за другого человека
/// и закрывал бы чужие опросы. Сверяем с автором сообщения; закрыть опрос
/// может только тот, кто его создал.
library;

import '../../../app/message_command_utils.dart';

/// Одна запись ленты, в которой может лежать команда карточки
/// (опрос, голос, закрытие, событие, ответ на событие).
class DesktopCardSource {
  const DesktopCardSource({
    required this.text,
    required this.authorProfileId,
    required this.createdAtMs,
  });

  final String text;

  /// Профиль автора сообщения. Пустой — автор не опознан; такому сообщению
  /// доверяем только его собственные слова о себе.
  final String authorProfileId;
  final int createdAtMs;
}

/// Опрос для показа: вопрос, варианты и посчитанные голоса.
class DesktopPollView {
  const DesktopPollView({
    required this.pollId,
    required this.question,
    required this.options,
    required this.multiple,
    required this.anonymous,
    required this.votesPerOption,
    required this.totalVoters,
    required this.myOptionIndices,
    required this.closed,
    required this.isCreator,
  });

  final String pollId;
  final String question;
  final List<String> options;
  final bool multiple;
  final bool anonymous;

  /// Сколько голосов у каждого варианта, по порядку [options].
  final List<int> votesPerOption;

  /// Сколько человек проголосовало (не сумма голосов: при нескольких ответах
  /// один человек добавляет несколько галочек).
  final int totalVoters;

  /// Мои варианты.
  final List<int> myOptionIndices;

  /// Опрос закрыт создателем — голосовать больше нельзя.
  final bool closed;

  /// Опрос создал я — значит, могу его закрыть.
  final bool isCreator;

  bool get hasVoted => myOptionIndices.isNotEmpty;

  /// Доля варианта от числа проголосовавших, 0..1.
  double share(int index) {
    if (totalVoters <= 0) return 0;
    if (index < 0 || index >= votesPerOption.length) return 0;
    return votesPerOption[index] / totalVoters;
  }
}

/// Считает состояние всех опросов ленты.
Map<String, DesktopPollView> desktopTallyPolls({
  required List<DesktopCardSource> entries,
  required String myProfileId,
}) {
  final specs = <String, PollCommand>{};
  final creatorByPoll = <String, String>{};
  // Последний голос каждого человека по каждому опросу.
  final votes = <String, Map<String, ({List<int> indices, int atMs})>>{};
  final closed = <String>{};
  final closeAttempts = <String, List<({String closer, int atMs})>>{};

  String? voter(DesktopCardSource e, String claimed) {
    final author = e.authorProfileId.trim();
    final says = claimed.trim();
    if (says.isEmpty) return null;
    if (author.isNotEmpty && author != says) return null;
    return says;
  }

  for (final e in entries) {
    final text = e.text;
    final spec = parsePollCommand(text);
    if (spec != null) {
      if (!specs.containsKey(spec.pollId)) {
        specs[spec.pollId] = spec;
        final author = e.authorProfileId.trim();
        if (author.isNotEmpty) creatorByPoll[spec.pollId] = author;
      }
      continue;
    }
    final vote = parsePollVoteCommand(text);
    if (vote != null) {
      final who = voter(e, vote.voterProfileId);
      if (who == null) continue;
      final byVoter = votes.putIfAbsent(
        vote.pollId,
        () => <String, ({List<int> indices, int atMs})>{},
      );
      final existing = byVoter[who];
      if (existing == null || e.createdAtMs >= existing.atMs) {
        byVoter[who] = (indices: vote.optionIndices, atMs: e.createdAtMs);
      }
      continue;
    }
    final close = parsePollCloseCommand(text);
    if (close != null) {
      final who = voter(e, close.closerProfileId);
      if (who == null) continue;
      closeAttempts
          .putIfAbsent(close.pollId, () => <({String closer, int atMs})>[])
          .add((closer: who, atMs: e.createdAtMs));
    }
  }

  for (final entry in closeAttempts.entries) {
    final creator = creatorByPoll[entry.key];
    if (creator == null || creator.isEmpty) continue;
    if (entry.value.any((a) => a.closer == creator)) closed.add(entry.key);
  }

  final me = myProfileId.trim();
  final out = <String, DesktopPollView>{};
  for (final entry in specs.entries) {
    final spec = entry.value;
    final byVoter = votes[entry.key] ?? const {};
    final counts = List<int>.filled(spec.options.length, 0);
    var voters = 0;
    var mine = const <int>[];
    for (final vote in byVoter.entries) {
      final picked = vote.value.indices
          .where((i) => i >= 0 && i < counts.length)
          .toSet();
      if (picked.isEmpty) continue;
      voters++;
      for (final i in picked) {
        counts[i]++;
      }
      if (me.isNotEmpty && vote.key == me) {
        mine = (picked.toList()..sort());
      }
    }
    out[entry.key] = DesktopPollView(
      pollId: entry.key,
      question: spec.question,
      options: spec.options,
      multiple: spec.multiple,
      anonymous: spec.anonymous,
      votesPerOption: counts,
      totalVoters: voters,
      myOptionIndices: mine,
      closed: closed.contains(entry.key),
      isCreator: me.isNotEmpty && creatorByPoll[entry.key] == me,
    );
  }
  return out;
}
