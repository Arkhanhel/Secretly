// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 МОДЕРАЦИЯ СОЗВОНА НА ПК (30.09.2026, ТЗ «ПК как Telegram» §2).
//
// Телефон умел убрать участника из созвона и завершить созвон для всех
// (`removeRelayRoomCallParticipant`, `endRelayRoomCall`, право
// `canModerateCall` = `canRemoveMembers`); на ПК входа не было. Окно созвона
// в тесте не поднять (WebRTC), поэтому сторож — по исходнику, как у соседних
// проверок окна.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File(
    'lib/ui/desktop/calls/room_call_window.dart',
  ).readAsStringSync();

  test('право — то же, что у телефона', () {
    expect(src.contains('_canModerate = policy.canRemoveMembers'), isTrue);
  });

  test('правый щелчок по участнику — «Убрать из созвона», себе — нет', () {
    expect(src.contains('onSecondaryTapDown: menu == null'), isTrue);
    expect(
      src.contains(
        '_canModerate && p.deviceId != widget.controller.deviceId',
      ),
      isTrue,
    );
    expect(src.contains('removeRelayRoomCallParticipant('), isTrue);
    expect(src.contains('desktopCallRemoveFailed'), isTrue,
        reason: 'отказ сервера — словами, а не молчанием');
  });

  test('«Выйти» и ⌘W — через окно с «Завершить для всех»', () {
    expect(src.contains('onTap: () => unawaited(_leavePressed())'), isTrue);
    expect(src.contains('unawaited(_leavePressed());'), isTrue);
    expect(src.contains('endRelayRoomCall('), isTrue);
    // Галочка не отмечена по умолчанию: завершить у всех — осознанный шаг.
    expect(src.contains('var endForAll = false;'), isTrue);
  });
}
