// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🔴 РАЗДЕЛЫ ПЕРЕКЛЮЧАЕТ ШТАТНЫЙ `TabBarView`, А НЕ САМОДЕЛКА.
///
/// Задача «перейти на дальний раздел с анимацией, но не показывая те, что
/// между» решена во Flutter: `TabBarView` временно оставляет в ряду только две
/// вкладки и корректно возвращает полный ряд.
///
/// Три моих попытки сделать это руками на `PageView` провалились, и каждая
/// давала видимый пользователю дефект:
///
///   1. «встать вплотную и шагнуть» — `jumpToPage` к соседу рисует кадр:
///      мелькал соседний раздел;
///   2. временный ряд из двух страниц — подмена контроллера НЕ встаёт на
///      `initialPage` (новая позиция ПОГЛОЩАЕТ смещение старой), и после
///      перехода всплывал раздел с индексом 1;
///   3. появление со сдвигом и прозрачностью — прозрачность и была морганием.
///
/// Тест держит границу: длина `TabController` обязана совпадать с числом
/// страниц (иначе `TabBarView` бросает на первом переходе), и ручных
/// `PageController` в оболочке остаться не должно.
void main() {
  final src = File('lib/ui/app_shell.dart').readAsStringSync();

  test('🔴 число вкладок совпадает с числом страниц', () {
    final pagesBlock = RegExp(r'final pages = \[(.*?)\n    \];', dotAll: true)
        .firstMatch(src);
    expect(pagesBlock, isNotNull, reason: 'список страниц не найден');
    final pageCount =
        'key: const ValueKey'.allMatches(pagesBlock!.group(1)!).length;
    expect(
      src.contains('static const int _tabCount = $pageCount;'),
      isTrue,
      reason: '_tabCount и список страниц разошлись — TabBarView бросит на '
          'первом же переходе между разделами',
    );
  });

  test('🔴 переключение отдано TabBarView, ручной PageView не вернулся', () {
    expect(src.contains('TabBarView('), isTrue);
    expect(
      src.contains('PageController('),
      isFalse,
      reason: 'ручной контроллер ряда — это возврат к трём прежним дефектам',
    );
    expect(
      src.contains('jumpToPage('),
      isFalse,
      reason: 'прыжок по ряду рисует посторонний кадр',
    );
  });

  test('свайп пальцем сохранён', () {
    expect(src.contains('BouncingScrollPhysics()'), isTrue);
  });
}
