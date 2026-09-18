// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/restore_error_classification.dart';

// Два дефекта восстановления, найденные в поле 08.08.2026.
//
// 1. «После восстановления из копии все пузыри — и мои, и собеседника — стали
//    слева». Сторона пузыря решается через `isOwnDeviceId`: текущее устройство
//    ИЛИ одно из прошлых своих. Список прошлых нигде не хранился и чистился на
//    каждом запуске, а пополнялся только из перечня устройств на СЕРВЕРЕ — а
//    восстановление заводит устройство заново, и старое с сервера вытесняется.
//    Узнать старый id было неоткуда, и свои сообщения навсегда выглядели чужими.
//
// 2. «При плохом интернете восстановление выдаёт ошибку». Категорий ошибки было
//    ДВЕ, и `invalidPayload` работал сборником всего непонятого — то есть на
//    обрыв связи человеку сообщали, что его резервная копия НЕДЕЙСТВИТЕЛЬНА.
//    Про единственный носитель его переписки.

void main() {
  group('классификация ошибок восстановления', () {
    test('🔴 обрыв связи — это НЕ «копия недействительна»', () {
      // Главный смысл правки: человек, поверивший, что копия испорчена, удалит
      // её и начнёт с пустого места.
      for (final error in <Object>[
        const SocketException('No route to host'),
        TimeoutException('too slow'),
        const HttpException('connection closed'),
        Exception('ClientException with SocketException: Failed host lookup'),
        Exception('Connection reset by peer'),
      ]) {
        expect(
          classifyEncryptedRestoreError(error),
          EncryptedRestoreFailureKind.networkUnavailable,
          reason: '$error',
        );
      }
    });

    test('неверный пароль остался неверным паролем', () {
      // Обратная защёлка: самая частая настоящая причина не должна была
      // потеряться среди новых веток.
      for (final error in <Object>[
        Exception('SecretBoxAuthenticationError'),
        Exception('mac check failed'),
        Exception('bad tag'),
      ]) {
        expect(
          classifyEncryptedRestoreError(error),
          EncryptedRestoreFailureKind.wrongPassword,
          reason: '$error',
        );
      }
    });

    test('испорченная копия остаётся испорченной', () {
      // Вторая обратная защёлка: сетевая ветка не имеет права поглотить
      // настоящую порчу данных, иначе мы просто перевернём ложь.
      expect(
        classifyEncryptedRestoreError(StateError('Safe backup missing device_id')),
        EncryptedRestoreFailureKind.invalidPayload,
      );
      expect(
        classifyEncryptedRestoreError(
          FormatException('Unsupported safe backup version: 9'),
        ),
        EncryptedRestoreFailureKind.invalidPayload,
      );
    });

    test('🔴 текст сетевой ошибки НЕ похож на приговор копии', () {
      // Проверяем не строку интерфейса, а сам факт: сетевой сбой и порча копии
      // теперь РАЗНЫЕ категории. До правки они были одной.
      expect(
        classifyEncryptedRestoreError(const SocketException('down')),
        isNot(classifyEncryptedRestoreError(StateError('broken payload'))),
      );
    });
  });
}
