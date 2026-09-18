// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Микрофон и отправка больше не исключают друг друга.
//
// 🔴 ЧТО БЫЛО. Одна кнопка на два действия: есть текст — «отправить», нет
// текста — «записать». То есть записать голосовое, не стерев начатый
// черновик, было НЕЛЬЗЯ; а стереть черновик, чтобы добраться до микрофона, —
// значит потерять написанное.
//
// В макете обе кнопки стоят рядом ОДНОВРЕМЕННО, и именно на кадре с уже
// набранным текстом.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final composer = File(
    'lib/ui/desktop/chat/composer.dart',
  ).readAsStringSync();

  test('🔴 переключателя «или-или» больше нет', () {
    expect(composer.contains('_SendOrVoice'), isFalse);
    expect(
      composer.contains('hasText\n          ? _SendButton'),
      isFalse,
      reason: 'кнопки больше не подменяют друг друга',
    );
  });

  test('микрофон и отправка стоят рядом', () {
    expect(composer.contains("tooltip: 'Записать голосовое'"), isTrue);
    expect(composer.contains('_SendButton(\n                              onTap: _hasText ? _trySend : null,'), isTrue);
  });

  test('🔴 без текста отправка ВИДНА, но погашена', () {
    // Исчезающая кнопка сдвигает соседнюю под курсор, а главное действие
    // поля не должно прыгать.
    expect(composer.contains('final enabled = onTap != null;'), isTrue);
    // 16.09.2026 в подсказку добавилась вторая строка — про отложенную
    // отправку правой кнопкой; сама подпись и правило «видна, но погашена» те
    // же.
    expect(composer.contains("'Отправить · Enter"), isTrue);
    expect(composer.contains("'Сначала напишите сообщение'"), isTrue);
    expect(composer.contains(': [c.elevated, c.elevated],'), isTrue);
  });

  test('погашенная кнопка не светится', () {
    // Тень главного действия на неактивной кнопке обещала бы нажатие.
    expect(composer.contains('boxShadow: enabled'), isTrue);
    expect(composer.contains(': const [],'), isTrue);
  });
}
