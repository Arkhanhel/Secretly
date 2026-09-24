// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Приватность (24.09.2026): текст сообщения не уходит на сервер открытым
// текстом.
//
// До 1.8.59 приложение клало в служебные данные каждого сообщения
// (`chat_message_v1.message.preview_text`) до 180 символов текста — для
// уведомления. Реле хранило их на диске и отправляло в push через Apple и
// Google, хотя само сообщение было зашифровано сквозным образом. Этот сторож
// не даёт полю вернуться: ни один исходник приложения не должен его писать.
void main() {
  test('no source file writes a plaintext preview_text for the server', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains("'preview_text'") ||
          source.contains('"preview_text"')) {
        offenders.add(entity.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Message text must never be sent to the server in the clear. '
          'The relay discards preview_text since 24.09.2026 and the app '
          'stopped sending it in 1.8.59; do not bring the field back.',
    );
  });
}
