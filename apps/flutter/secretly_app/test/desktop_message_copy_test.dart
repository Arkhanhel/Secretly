// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 КОПИЯ СООБЩЕНИЯ НЕСЁТ ВСЕ ПОЛЯ.
//
// Найдено 16.09.2026: `MessageData.copyWith` не знал про `authorRole`,
// `authorProfileId` и `mentions`. А зовётся он на КАЖДОМ втором сообщении
// подряд от одного автора (`m.copyWith(continuation: true)`), при каждой
// поставленной реакции и когда догружается вложение. У всех таких сообщений
// молча пропадали фишки упоминаний, метка роли и оттенок заглушки портрета.
//
// Проверка двойная: поведением (поле пережило копию) и текстом (список полей
// класса совпадает со списком параметров копии) — вторая ловит поле,
// добавленное в класс и забытое в копии, ещё до того, как кто-то заметит.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';

void main() {
  const full = MessageData(
    id: 'm1',
    payloadId: 'p1',
    authorName: 'Игорь',
    authorRole: 'admin',
    authorProfileId: 'PID-1',
    authorSeed: 'DEV-1',
    text: '@Аня привет',
    time: '12:00',
    hasMention: true,
    mentions: <MsgMentionV1>[
      MsgMentionV1(type: MsgMentionV1.profileType, start: 0, end: 4, profileId: 'PID-2'),
    ],
  );

  test('🔴 «продолжение группы» не теряет упоминаний, роли и профиля', () {
    final c = full.copyWith(continuation: true);
    expect(c.continuation, isTrue);
    expect(c.mentions, hasLength(1), reason: '«@Аня» стал бы простым словом');
    expect(c.authorRole, 'admin', reason: 'пропала бы метка «админ»');
    expect(c.authorProfileId, 'PID-1');
    expect(c.authorSeed, 'DEV-1', reason: 'имя перекрасилось бы');
  });

  test('🔴 поставленная реакция их тоже не стирает', () {
    final c = full.copyWith(
      reactions: const [MessageReaction(emoji: '👍', count: 1)],
    );
    expect(c.mentions, hasLength(1));
    expect(c.authorRole, 'admin');
  });

  test('🔴 каждое поле класса есть в копии', () {
    final src = File(
      'lib/ui/desktop/chat/message_bubble.dart',
    ).readAsStringSync();
    final cls = src.indexOf('class MessageData {');
    final copy = src.indexOf('MessageData copyWith({', cls);
    final copyEnd = src.indexOf('\n  }\n', copy);
    expect(cls, greaterThan(0));
    expect(copy, greaterThan(cls));

    final fields = RegExp(r'^  final [\w<>?, ]+ (\w+);', multiLine: true)
        .allMatches(src.substring(cls, copy))
        .map((m) => m.group(1)!)
        .toSet();
    final body = src.substring(copy, copyEnd);
    final missing = <String>[
      for (final f in fields)
        if (!body.contains('$f: $f ?? this.$f')) f,
    ];
    expect(
      missing,
      isEmpty,
      reason: 'поле есть в классе, но копия его молча выбросит',
    );
  });
}
