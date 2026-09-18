// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// · Сетка медиа, сверенная с макетом.
//
// Зазор был 2 — плитки слипались в одно пятно, и сетка читалась как один
// рваный снимок, а не как двадцать разных. Углы прямые — сетка из квадратов
// давала решётку. Под полосой вкладок не было черты, и подпись вкладки
// читалась заголовком того, что под ней, а не переключателем.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File(
    'lib/ui/desktop/chat/details/desktop_media_gallery.dart',
  ).readAsStringSync();

  test('· зазор сетки — 5 из макета', () {
    expect(src.contains('crossAxisSpacing: 5'), isTrue);
    expect(src.contains('mainAxisSpacing: 5'), isTrue);
    expect(src.contains('crossAxisSpacing: 2'), isFalse);
  });

  test('· плитка скруглена', () {
    expect(
      src.contains('ClipRRect(\n            borderRadius: BorderRadius.circular(DRadii.md),'),
      isTrue,
    );
  });

  test('· под полосой вкладок есть черта', () {
    expect(src.contains('dividerColor: Colors.transparent'), isFalse);
    expect(src.contains('dividerColor: c.borderSubtle'), isTrue);
    expect(src.contains('dividerHeight: 1'), isTrue);
  });

  // 🔴 ПРЕВЬЮ ИЗ ШЕСТИ ПЛИТОК С «+41» НЕ ВЗЯТО, И ЭТО РЕШЕНИЕ.
  //
  // В макете панель растёт по содержимому; у нас область вкладок фиксирована
  // по высоте и ОБЩАЯ на все четыре вкладки. Шесть плиток в ней дали бы две
  // строки и примерно двести точек пустоты под ними, а менять высоту по
  // вкладке нельзя — панель прыгала бы при каждом переключении.
  test('🔴 причина отказа от превью записана рядом с кодом', () {
    expect(src.contains('ПРЕВЬЮ ИЗ ШЕСТИ ПЛИТОК'), isTrue);
    final code = src
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');
    // Половинчатой правки нет: сетка по-прежнему показывает всё.
    expect(code.contains('_previewCount'), isFalse);
    expect(code.contains('itemCount: items.length'), isTrue);
  });
}
