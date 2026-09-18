// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Демонстрационная комната не обещает того, чего сервер не даст.
//
// 🔴 Такая комната видна в списке, в неё можно писать — но на сервере её нет:
// запрос по ней возвращает `404 room not found`. Кнопки, которым нужен релей
// (созвон, ссылка-приглашение), там не сработают НИКОГДА.
//
// Проверка вынесена в одно место намеренно: мест, где она нужна, уже два, и
// разъехавшись они дали бы комнату, где созвон честно объяснён, а
// приглашение падает сырой ошибкой.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/demo_rooms.dart';

void main() {
  test('узнаёт демонстрационные идентификаторы', () {
    expect(isDemoRoomId('group:demo:launch'), isTrue);
    expect(isDemoRoomId('demo:design'), isTrue);
    expect(isDemoRoomId('  group:demo:launch  '), isTrue);
  });

  test('не принимает обычную комнату за демонстрационную', () {
    expect(isDemoRoomId('group:T4BL-RGU7'), isFalse);
    expect(isDemoRoomId('demonstration'), isFalse);
    expect(isDemoRoomId(''), isFalse);
    expect(isDemoRoomId(null), isFalse);
  });

  test('оба места спрашивают одну и ту же проверку', () {
    final call = File(
      'lib/ui/desktop/calls/room_call_window.dart',
    ).readAsStringSync();
    final details = File(
      'lib/ui/desktop/chat/details/room_details_view.dart',
    ).readAsStringSync();

    expect(
      call.contains('isDemoRoomId('),
      isTrue,
      reason: 'окно созвона должно звать общую проверку, а не свою копию',
    );
    expect(
      details.contains('isDemoRoomId('),
      isTrue,
      reason: 'подробности комнаты должны звать ту же проверку',
    );
    // Своих копий условия остаться не должно.
    expect(call.contains("startsWith('group:demo:')"), isFalse);
    expect(details.contains("startsWith('group:demo:')"), isFalse);
  });

  test('в демонстрационной комнате нет кнопки приглашения', () {
    final details = File(
      'lib/ui/desktop/chat/details/room_details_view.dart',
    ).readAsStringSync();
    expect(details.contains('isDemoRoomId(_groupId) ? null : _invite'), isTrue);
  });
}
