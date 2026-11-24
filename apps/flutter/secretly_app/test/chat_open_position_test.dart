// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Место открытия чата (23.11.2026): первое непрочитанное и прокрутка
// перевёрнутого списка.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/chat_open_position.dart';

OpenPositionRow _row(String id, {bool me = false, List<String> frames = const []}) =>
    (rowId: id, isMe: me, ids: [id, 'p-$id', ...frames]);

void main() {
  group('firstUnreadRowId', () {
    // Новые первыми, как на экране.
    final rows = [
      _row('e5'),
      _row('e4', me: true),
      _row('e3'),
      _row('e2'),
      _row('e1'),
    ];

    test('самое старое непрочитанное, а не самое новое', () {
      expect(firstUnreadRowId(rows, {'e5', 'e3', 'e2'}), 'e2');
    });

    test('по payload id тоже находит', () {
      expect(firstUnreadRowId(rows, {'p-e3'}), 'e3');
    });

    test('свои сообщения не бывают «первым непрочитанным»', () {
      expect(firstUnreadRowId(rows, {'e4'}), isNull);
    });

    test('альбом — по любому кадру', () {
      final album = [_row('a1', frames: ['f1', 'f2', 'f3']), _row('e0')];
      expect(firstUnreadRowId(album, {'f2'}), 'a1');
    });

    test('нет непрочитанных или их нет в ленте (другая тема) — null', () {
      expect(firstUnreadRowId(rows, {}), isNull);
      expect(firstUnreadRowId(rows, {'other-topic'}), isNull);
      expect(firstUnreadRowId(const [], {'e1'}), isNull);
    });
  });

  group('reversedListOffsetForRowTop', () {
    test('строка ниже нужного — смещение уменьшается', () {
      expect(
        reversedListOffsetForRowTop(
          offset: 1000,
          rowTop: 600,
          desiredTop: 150,
          maxExtent: 5000,
        ),
        550,
      );
    });

    test('строка выше нужного — смещение растёт', () {
      expect(
        reversedListOffsetForRowTop(
          offset: 1000,
          rowTop: 50,
          desiredTop: 150,
          maxExtent: 5000,
        ),
        1100,
      );
    });

    test('у самого низа чата — 0, у самого верха — потолок', () {
      expect(
        reversedListOffsetForRowTop(
          offset: 100,
          rowTop: 700,
          desiredTop: 150,
          maxExtent: 5000,
        ),
        0,
      );
      expect(
        reversedListOffsetForRowTop(
          offset: 4900,
          rowTop: -300,
          desiredTop: 150,
          maxExtent: 5000,
        ),
        5000,
      );
    });
  });

  test('🔴 экран не помечает чат прочитанным, пока выбирает место', () {
    // Раньше через 450 мс после открытия весь чат помечался прочитанным —
    // и первое непрочитанное терялось ещё до прокрутки к нему.
    final src = File('lib/ui/chat_screen.dart').readAsStringSync();
    final schedule = src.indexOf('  void _scheduleMarkRead() {');
    expect(schedule, greaterThan(0));
    final body = src.substring(schedule, schedule + 400);
    expect(body.contains('if (_openPositionPending) return;'), isTrue);
    // И при выходе из чата посреди выбора — тоже.
    expect(
      src.contains('if (!_openPositionPending &&\n        shouldAutoMarkChatRead('),
      isTrue,
    );
    expect(src.contains('const bool kOpenAtFirstUnread = true;'), isTrue);
  });

  test('🔴 открытие: строка держится, пока догружаются высоты; лента ждётся до 10 с', () {
    final src = File('lib/ui/chat_screen.dart').readAsStringSync();
    final i = src.indexOf('Future<void> _resolveOpenPosition()');
    final body = src.substring(i, src.indexOf('/// Ждёт первую собранную ленту', i));
    expect(body, contains('_holdRowAt(rowId'), reason: 'первое непрочитанное уплывало');
    expect(body, contains('_holdRowAt(found.rowId'), reason: 'место «где остановился»');
    expect(body, contains('maxFrames: 90'), reason: 'вторая попытка дальнего прыжка');
    final wait = src.substring(src.indexOf('Future<bool> _waitForFirstTimeline'));
    expect(wait.substring(0, 300), contains('i < 200'), reason: '~10 с, не 3');
  });
}
