// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ЗАГЛУШКА ПОРТРЕТА РОНЯЛА ОКНО НА ИМЕНИ С ЭМОДЗИ.
//
// ЖАЛОБА ВЛАДЕЛЬЦА 16.09.2026: «моргает экран красным цветом».
//
// Красное — это `ErrorWidget`, подменивший собой упавшее поддерево. Ловушка в
// `main_desktop.dart` записала причину дословно, ещё до того как окно открыли:
//
//     painting_library / while building a TextSpan
//     Invalid argument(s): string is not well-formed UTF-16
//
// ПРИЧИНА. Десктопная заглушка портрета брала буквы по КОДОВЫМ ЕДИНИЦАМ:
// `parts[1][0]` и `substring(0, 2)`. Эмодзи в UTF-16 — это ДВЕ кодовые
// единицы (суррогатная пара). Взять первую — получить половину пары, то есть
// строку, которая правильным UTF-16 не является. `Text` на такой падает.
//
// В списке чатов владельца закреплено «Игорь 🎯» — и заглушка падала на каждой
// перерисовке списка.
//
// СТАЛО: буквы считает общий [AvatarInitials.label] — по видимым знакам
// (`characters`). Он же на телефоне, так что заглушка одного человека теперь
// одинакова буква в букву.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/widgets/avatar_initials.dart';

/// Строка правильна как UTF-16, если её можно перекодировать туда и обратно.
/// Именно это и проверяет движок текста, падая с «not well-formed UTF-16».
bool _isWellFormedUtf16(String s) {
  try {
    // ignore: unnecessary_statements
    s.runes.toList();
    for (final r in s.runes) {
      if (r >= 0xD800 && r <= 0xDFFF) return false; // одинокий суррогат
    }
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  const names = <String>[
    'Игорь 🎯',
    '🎯 Игорь',
    '😀',
    'A😀',
    '❤️',
    'Anasteisha ❤️',
    '👨‍👩‍👧‍👦 семья',
    'Yurii iOS',
    'тест 2',
    '   ',
    '',
  ];

  test('🔴 буквы заглушки — всегда правильный UTF-16', () {
    for (final n in names) {
      final label = AvatarInitials.label(displayName: n);
      expect(
        _isWellFormedUtf16(label),
        isTrue,
        reason: 'имя «$n» дало «$label» — на таком `Text` падает красным',
      );
      expect(label.isNotEmpty, isTrue, reason: 'имя «$n» осталось без букв');
    }
  });

  testWidgets('🔴 и рисуется без исключения', (t) async {
    for (final n in names) {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(AvatarInitials.label(displayName: n)),
            ),
          ),
        ),
      );
      await t.pump();
      expect(t.takeException(), isNull, reason: 'имя «$n»');
    }
  });

  test('🔴 десктоп больше НЕ режет имя по кодовым единицам', () {
    final src = File(
      'lib/ui/desktop/primitives/avatar.dart',
    ).readAsStringSync();
    expect(src.contains('parts[0][0] + parts[1][0]'), isFalse);
    expect(src.contains("substring(0, s.length >= 2 ? 2 : 1)"), isFalse);
    expect(src.contains('AvatarInitials.label(displayName: name)'), isTrue);
  });

  test('эмодзи в имени даёт ЦЕЛЫЙ знак, а не половину', () {
    expect(AvatarInitials.label(displayName: 'Игорь 🎯'), 'И🎯');
    expect(AvatarInitials.label(displayName: '😀'), '😀');
  });
}
