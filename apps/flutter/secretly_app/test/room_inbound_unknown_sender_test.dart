// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 НЕОПОЗНАННЫЙ ОТПРАВИТЕЛЬ В КОМНАТЕ (13.11.2026).
//
// Если профиль отправителя не удалось узнать (устройства нет в кэше, сервер
// ключей недоступен), проверка «автор — участник» раньше пропускалась, и
// исключённый участник с нового устройства мог писать в комнату. Теперь
// такое сообщение откладывается и применяется только после того, как
// отложенный проход опознает профиль по устройству и найдёт его в составе.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/app/app_controller.dart').readAsStringSync();

  test('сообщение комнаты без профиля отправителя откладывается, а не принимается', () {
    final at = src.indexOf('if (senderProfile.isEmpty &&\n                !fromDeferredReplay &&');
    expect(at, greaterThan(0));
    final block = src.substring(at, src.indexOf('continue;', at));
    expect(block.contains('_storeDeferredRoomInbound('), isTrue);
    expect(block.contains("senderProfile: ''"), isTrue);
  });

  test('отложенный проход опознаёт профиль по устройству и требует членства', () {
    final at = src.indexOf('Future<void> _flushDeferredRoomInbound(');
    expect(at, greaterThan(0));
    final body = src.substring(at, at + 4000);
    expect(body.contains('_resolveProfileIdForDevice(parkedDid)'), isTrue);
    expect(body.contains('!members.contains(senderProfile)'), isTrue);
  });
}
