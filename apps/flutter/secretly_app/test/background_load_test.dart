// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Фоновая нагрузка (журнал Xiaomi, 23.11.2026): частоты обходов, которые
// тянут сервер и базу, — зафиксированы, чтобы случайно не вернулись.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

void main() {
  final src = File('lib/app/app_controller.dart').readAsStringSync();

  test('чужие профили — раз в 45 с, открытый чат — раз в 15 с', () {
    expect(kMetaRefreshIntervalMs, 45 * 1000);
    expect(kMetaRefreshActiveChatMs, 15 * 1000);
    // «Без фото» больше не значит «раз в 8 с».
    expect(src.contains('(nowMs + 8 * 1000)'), isFalse);
    // Свёрнуто — обход стоит.
    expect(src.contains('maxFetches: _appInForeground ? 3 : 0,'), isTrue);
  });

  test('принудительная выборка входящих: 20 с спокойно, 8 с в риске', () {
    expect(kRelayQuietForcePumpMs, 20 * 1000);
    expect(src.contains('riskyWindow ? 8000 : kRelayQuietForcePumpMs'), isTrue);
  });

  test('перепроверка ключей — попытка не чаще раза в час', () {
    expect(src.contains('_bundleReverifyRetryMs = 60 * 60 * 1000'), isTrue);
    expect(src.contains('_bundleReverifyLastTryAtMs[convoId] = now;'), isTrue);
  });
}
