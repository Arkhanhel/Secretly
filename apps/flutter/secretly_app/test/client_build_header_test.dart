// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/transport/resilient_http_client.dart';

// Замер раскатки показал 0 из 2001 устройства с известной сборкой — а это гейт
// для ТЗ номера безопасности (нельзя менять решения приёмников, не зная доли
// сборок). Первая попытка провалилась: заголовок добавляла общая функция
// подписи, но в relay_client заголовки собираются ВРУЧНУЮ ещё в десяти местах,
// включая путь отправки. Теперь он ставится на уровне клиента — одно горло.
void main() {
  test('клиент создаётся и закрывается без ошибок', () {
    final c = createResilientHttpClient();
    expect(c, isNotNull);
    c.close();
  });
}
