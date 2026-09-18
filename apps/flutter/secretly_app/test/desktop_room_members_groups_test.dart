// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Участники комнаты разложены по присутствию, а не сложены в одну кучу.
//
// 🔴 ЧТО БЫЛО. Раздел без запроса показывал первые ВОСЕМЬ имён подряд и
// строку «ещё N». В комнате на сто человек это восемь случайных имён: тех,
// кто сейчас в сети — а разговор идёт именно с ними, — там могло не быть
// вовсе, и найти их было нечем, кроме поиска по имени, которое ещё надо знать.
//
// Теперь две группы со счётчиками, как в макете. Кто в сети — показывается
// ВЕСЬ: это короткий список и ровно тот, ради которого раздел открывают.
// Обрезка осталась там, где счёт трёхзначный, — у «не в сети».
//
// Группы «В СОЗВОНЕ» здесь нет намеренно: признаки «в созвоне», «говорит»,
// «показывает экран» живут в состоянии LiveKit и существуют только внутри
// идущего созвона. Нарисовать их из данных комнаты нечем.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final view = File(
    'lib/ui/desktop/chat/details/room_details_view.dart',
  ).readAsStringSync();

  test('группы со счётчиками есть', () {
    expect(view.contains("_GroupHeading(label: 'В СЕТИ'"), isTrue);
    expect(view.contains("_GroupHeading(label: 'НЕ В СЕТИ'"), isTrue);
    expect(
      view.contains("'\$label · \$count'"),
      isTrue,
      reason: 'заголовок должен называть и группу, и число в ней',
    );
  });

  test('🔴 кто в сети — показывается весь, без обрезки', () {
    // Обрезка применяется к `offline`, а не к общему списку.
    expect(
      view.contains('offline.take(_kOfflinePreview)'),
      isTrue,
      reason: 'предел должен стоять только у «не в сети»',
    );
    expect(
      view.contains('online.map(') && view.contains('onOpen: onOpenMember'),
      isTrue,
      reason: 'список «в сети» отдаётся целиком',
    );
  });

  test('при поиске группы не рисуются', () {
    // Человек уже назвал, кого ищет, и разбивка на заголовки над двумя
    // строками только мешает.
    expect(view.contains('final grouped =\n        !hasQuery &&'), isTrue);
  });

  test('группы не появляются, когда все в одном состоянии', () {
    expect(view.contains('online.isNotEmpty && offline.isNotEmpty'), isTrue);
  });

  test('строки «не в сети» приглушены', () {
    expect(view.contains('dimmed: true'), isTrue);
    expect(view.contains('opacity: dimmed ? 0.6 : 1'), isTrue);
  });

  // 🔴 «В СОЗВОНЕ» ПОЯВИЛАСЬ 15.09.2026 — см. desktop_members_in_call_test.
  //
  // Прежнее объяснение («признаки живут в состоянии LiveKit») оказалось
  // неверным: `muted`, `deafened` и `screenShareEnabled` лежат в
  // `CachedRoomCall`, который видит ВСЯ комната.
  test('придуманных признаков созвона в разделе по-прежнему нет', () {
    final code = view
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    // «Отошёл» (#F59E0B) в модели отсутствует — рисовать его было бы
    // признаком, которого никто не проверял.
    expect(code.contains("'отошёл'"), isFalse);
    // «Говорит» приходит из LiveKit и существует только внутри идущего
    // созвона: в списке участников за него нечем отвечать.
    expect(code.contains('speaking'), isFalse);
  });
}
