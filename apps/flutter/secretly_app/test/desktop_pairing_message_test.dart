// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Человеку на экране спаривания не показывают текст исключения Dart.
//
// 🔴 Поле 12.09.2026: «Не генерируется код, я не могу сконектить телефон! Это
// происходит часто, и она работает странно и непонятно». На экране стояло:
//
//     QR недоступен
//     Bad state: publishKeys returned ok=false
//
// Понять из этого нельзя ничего, а сделать тем более: человек видит слово
// «ошибка» и не знает, ждать, перезапускать или звать на помощь. Хуже того,
// рядом печаталось «Keys is offline» — неправда: сервер ОТВЕТИЛ и именно
// отказался принять связку (не-2xx в клиенте бросает с кодом состояния).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/desktop_link_failure.dart';

void main() {
  final screens = <String, String>{
    'экран подключения':
        'lib/ui/desktop/onboarding/desktop_onboarding_screen.dart',
    'настройки': 'lib/ui/desktop/workspace/settings_workspace.dart',
  };

  screens.forEach((name, path) {
    test('🔴 $name не печатает исключение в поле ошибки', () {
      final code = File(path)
          .readAsStringSync()
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      expect(
        code.contains('_errorMessage = e.toString()'),
        isFalse,
        reason: 'вернулся текст исключения Dart на экран: человек снова увидит '
            '«Bad state: ...» вместо того, что ему делать',
      );
    });
  });

  test('у отказа публикации есть свой код, а не общая свалка', () {
    expect(
      DesktopLinkFailureCode.values.contains(
        DesktopLinkFailureCode.keysPublishRejected,
      ),
      isTrue,
    );
  });

  test('его текст говорит, ЧТО делать, и не врёт про офлайн', () {
    final msg = DesktopLinkFailure(
      DesktopLinkFailureCode.keysPublishRejected,
    ).message;

    expect(msg, isNotEmpty);
    expect(
      msg.toLowerCase(),
      contains('clock'),
      reason: 'самая частая причина — уплывшие часы компьютера, и человеку '
          'надо сказать про них прямо',
    );
    expect(
      msg.toLowerCase().contains('offline'),
      isFalse,
      reason: 'сервер ответил — называть это «офлайн» значит уводить человека '
          'проверять интернет вместо часов',
    );
  });
}
