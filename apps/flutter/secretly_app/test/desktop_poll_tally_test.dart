// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ПОДСЧЁТ ГОЛОСОВ ОПРОСА В ЛЕНТЕ КОМПЬЮТЕРА.
//
// Опрос живёт самой перепиской: и сам опрос, и голоса, и закрытие — это
// служебные сообщения. Итог считается по ленте заново, как на телефоне.
//
// 🔴 Главное правило: чей голос — решает ОТПРАВИТЕЛЬ сообщения, а не текст
// команды. Иначе участник голосует за другого человека и закрывает чужие
// опросы.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_poll_tally.dart';

const _me = 'me-1';
const _igor = 'igor-1';

DesktopCardSource _spec({
  String author = _me,
  int at = 1000,
  bool multiple = false,
  bool anonymous = false,
}) => DesktopCardSource(
  text: buildPollCommand(
    pollId: 'p1',
    question: 'Когда встречаемся?',
    options: const ['В пятницу', 'В субботу', 'В воскресенье'],
    multiple: multiple,
    anonymous: anonymous,
  ),
  authorProfileId: author,
  createdAtMs: at,
);

DesktopCardSource _vote(
  String author,
  List<int> indices, {
  int at = 2000,
  String? claims,
}) => DesktopCardSource(
  text: buildPollVoteCommand(
    pollId: 'p1',
    optionIndices: indices,
    voterProfileId: claims ?? author,
  ),
  authorProfileId: author,
  createdAtMs: at,
);

DesktopCardSource _close(String author, {int at = 3000, String? claims}) =>
    DesktopCardSource(
      text: buildPollCloseCommand(
        pollId: 'p1',
        closerProfileId: claims ?? author,
        closedAtMs: at,
      ),
      authorProfileId: author,
      createdAtMs: at,
    );

DesktopPollView? tally(List<DesktopCardSource> entries, {String me = _me}) =>
    desktopTallyPolls(entries: entries, myProfileId: me)['p1'];

void main() {
  test('опрос без голосов', () {
    final poll = tally([_spec()]);
    expect(poll, isNotNull);
    expect(poll!.question, 'Когда встречаемся?');
    expect(poll.options.length, 3);
    expect(poll.totalVoters, 0);
    expect(poll.votesPerOption, [0, 0, 0]);
    expect(poll.hasVoted, isFalse);
    expect(poll.isCreator, isTrue);
    expect(poll.closed, isFalse);
  });

  test('голоса считаются по людям, а не по галочкам', () {
    final poll = tally([
      _spec(multiple: true),
      _vote(_me, [0, 1]),
      _vote(_igor, [1]),
    ]);
    expect(poll!.votesPerOption, [1, 2, 0]);
    expect(poll.totalVoters, 2, reason: 'проголосовали двое');
    expect(poll.myOptionIndices, [0, 1]);
    expect(poll.share(1), closeTo(1.0, 0.001));
  });

  test('человек передумал — считается последний голос', () {
    final poll = tally([
      _spec(),
      _vote(_igor, [0], at: 2000),
      _vote(_igor, [2], at: 2500),
    ]);
    expect(poll!.votesPerOption, [0, 0, 1]);
    expect(poll.totalVoters, 1);
  });

  test('🔴 за другого человека проголосовать нельзя', () {
    // Команда говорит «голосует Игорь», а прислал её кто-то другой.
    final poll = tally([
      _spec(),
      _vote('stranger-1', [0], claims: _igor),
    ]);
    expect(poll!.totalVoters, 0, reason: 'чужой голос принят');
    expect(poll.votesPerOption, [0, 0, 0]);
  });

  test('🔴 закрыть опрос может только его создатель', () {
    final mine = tally([_spec(author: _me), _close(_igor)]);
    expect(mine!.closed, isFalse, reason: 'чужой закрыл опрос');

    final byCreator = tally([_spec(author: _me), _close(_me)]);
    expect(byCreator!.closed, isTrue);
  });

  test('🔴 подложное закрытие от имени создателя не проходит', () {
    final poll = tally([
      _spec(author: _me),
      _close('stranger-1', claims: _me),
    ]);
    expect(poll!.closed, isFalse);
  });

  test('чужой опрос закрывать нельзя мне тоже', () {
    final poll = tally([_spec(author: _igor)]);
    expect(poll!.isCreator, isFalse);
  });

  test('несуществующий вариант не ломает подсчёт', () {
    final poll = tally([
      _spec(),
      _vote(_igor, [7]),
      _vote(_me, [1]),
    ]);
    expect(poll!.votesPerOption, [0, 1, 0]);
    expect(poll.totalVoters, 1, reason: 'пустой голос не считается');
  });

  test('неопознанный автор: верим только словам о себе', () {
    final poll = tally([
      _spec(),
      DesktopCardSource(
        text: buildPollVoteCommand(
          pollId: 'p1',
          optionIndices: const [2],
          voterProfileId: _igor,
        ),
        authorProfileId: '',
        createdAtMs: 2000,
      ),
    ]);
    expect(poll!.votesPerOption, [0, 0, 1]);
  });

  test('голос без опроса ничего не создаёт', () {
    expect(tally([_vote(_igor, [0])]), isNull);
  });
}
