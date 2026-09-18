// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/transport/relay_client.dart';

/// 🔴 ПОДСКАЗКА К ОТКАЗУ АВТОРИЗАЦИИ РЕЛЕ.
///
/// Обращение в поддержку 12.09.2026: человек трижды сбросил профиль, потому
/// что видел только `HTTP 401` и «System errors». Причина была в часах
/// телефона. Путь сервера ключей объясняет это давно, путь реле — молчал.
void main() {
  test('расхождение часов названо прямо, и сказано, что сброс не поможет', () {
    final hint = relayAuthFailureHint(401, 'timestamp out of range');
    expect(hint, contains('clock'));
    expect(hint, contains('automatic date & time'));
    expect(
      hint.toLowerCase(),
      contains('resetting the profile does not help'),
      reason: 'человек сбрасывал профиль трижды — надо сказать, что дело не в нём',
    );
  });

  test('неизвестное устройство и подпись различаются', () {
    expect(relayAuthFailureHint(401, 'unknown device'), contains('does not know'));
    expect(relayAuthFailureHint(401, 'bad signature'), contains('signature'));
  });

  test('успех и прочие коды подсказки не получают', () {
    expect(relayAuthFailureHint(200, 'ok'), isEmpty);
    expect(relayAuthFailureHint(500, 'timestamp out of range'), isEmpty,
        reason: 'подсказка только для 401 — иначе введём в заблуждение');
    expect(relayAuthFailureHint(403, 'timestamp'), isEmpty);
  });

  test('незнакомая причина не выдумывает объяснений', () {
    expect(relayAuthFailureHint(401, 'something else entirely'), isEmpty,
        reason: 'лучше промолчать, чем увести разбор в сторону');
  });

  test('регистр не важен', () {
    expect(relayAuthFailureHint(401, 'TIMESTAMP OUT OF RANGE'), isNotEmpty);
  });
}
