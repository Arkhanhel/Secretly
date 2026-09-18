// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/widgets/support_badge.dart';

/// Значок поддержки (запрос владельца 03.08.2026).
///
/// Правила выбраны так, чтобы значок ГАС САМ, а не висел вечно после любого
/// давнего обращения. Проверяется именно это — «когда его быть НЕ должно»,
/// потому что лишний красный кружок в настройках раздражает сильнее, чем его
/// отсутствие.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );
  }

  /// 🔴 Переписки нет — рисовать нечего.
  testWidgets('🔴 без обращения значка нет', (tester) async {
    await pump(tester, const SupportBadge(count: 0, awaiting: false));
    expect(find.byType(Container), findsNothing);
    expect(find.textContaining(RegExp(r'\d')), findsNothing);
  });

  /// Обращение в работе: ответа ещё нет — точка без числа.
  testWidgets('ждём ответа — точка без числа', (tester) async {
    await pump(tester, const SupportBadge(count: 0, awaiting: true));
    expect(find.byType(Container), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d')), findsNothing,
        reason: 'числа быть не должно — отвечать ещё нечем');
  });

  testWidgets('пришёл ответ — кружок с числом', (tester) async {
    await pump(tester, const SupportBadge(count: 3, awaiting: false));
    expect(find.text('3'), findsOneWidget);
  });

  /// Число важнее точки: если ответы есть, «в работе» уже не показываем —
  /// иначе на одной строке оказались бы два значка.
  testWidgets('число вытесняет точку', (tester) async {
    await pump(tester, const SupportBadge(count: 2, awaiting: true));
    expect(find.text('2'), findsOneWidget);
  });

  /// Кружок не должен разъезжаться по строке на трёхзначном числе.
  testWidgets('больше 99 показывается как 99+', (tester) async {
    await pump(tester, const SupportBadge(count: 137, awaiting: false));
    expect(find.text('99+'), findsOneWidget);
    expect(find.text('137'), findsNothing);
  });

  /// Уменьшенный вариант для иконки нижней панели остаётся читаемым и не
  /// перестаёт быть значком.
  testWidgets('компактный вариант рисует то же самое', (tester) async {
    await pump(
      tester,
      const SupportBadge(count: 5, awaiting: false, compact: true),
    );
    expect(find.text('5'), findsOneWidget);
    final size = tester.getSize(find.byType(SupportBadge));
    expect(size.height, lessThan(19),
        reason: 'компактный обязан быть меньше обычного');
  });
}
