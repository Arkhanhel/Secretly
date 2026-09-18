// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/app/desktop_chats_section.dart';

// 🔴 НАКЛЕЙКА В КОМНАТУ НЕ УХОДИЛА (17.09.2026): адрес `group:group:…`.

void main() {
  test('номер комнаты с приставкой не получает вторую', () {
    expect(desktopRoomAddress('group:R1'), 'group:R1');
  });

  test('голый номер получает приставку', () {
    expect(desktopRoomAddress('R1'), 'group:R1');
    expect(desktopRoomAddress('  R1 '), 'group:R1');
  });

  test('ни отправка, ни пересылка не склеивают приставку руками', () {
    final src = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    expect(src.contains("'group:\$_convoId'"), isFalse);
    expect(src.contains("'group:\$groupId'"), isFalse);
    expect(src.contains('target = desktopRoomAddress(_convoId);'), isTrue);
    expect(
      src.contains('toGroup ? desktopRoomAddress(groupId) : peerProfileId!'),
      isTrue,
    );
  });

  group('номер сообщения (правило телефона)', () {
    test('пустой и пробельный номер — не номер', () {
      expect(desktopTimelineRowId('', 'row-1'), 'row-1');
      expect(desktopTimelineRowId('   ', 'row-1'), 'row-1');
      expect(desktopTimelineRowId(null, 'row-1'), 'row-1');
      expect(desktopTimelineRowId(' P-1 ', 'row-1'), 'P-1');
    });

    test('🔴 нигде не осталось `payloadEventId ?? eventId`', () {
      final src = File(
        'lib/ui/desktop/app/desktop_chats_section.dart',
      ).readAsStringSync();
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('payloadEventId ?? event.eventId'), isFalse);
      expect(
        'desktopTimelineRowId('.allMatches(code).length,
        greaterThanOrEqualTo(4),
        reason: 'реакции (два места), темы и команды — одно правило',
      );
    });
  });
}
