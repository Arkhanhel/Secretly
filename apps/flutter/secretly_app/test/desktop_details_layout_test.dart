// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Панель подробностей выдвигается справа и НЕ ложится поверх переписки.
//
// 🔴 Накладка выглядит дешёвым решением ровно до того момента, когда человек
// пытается читать переписку и подробности одновременно: она закрывает правый
// край сообщений — тот самый, где стоят время и галочки.
//
// Поэтому панель всегда занимает свою колонку, а недостающее место отдают
// соседи, в порядке от наименее ценного к наиболее: сначала список чатов,
// потом сама панель, и только в последнюю очередь переписка.
//
// Здесь закреплён именно ПОРЯДОК уступок — он и есть решение; ширины это уже
// арифметика.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/shell/details_panel.dart';

void main() {
  const sidebar = 80.0;
  const listWanted = 320.0;
  const listMin = 220.0;
  const detailsWanted = 320.0;
  const detailsMin = 260.0;
  const floor = 460.0;

  DetailsLayout at(double available) => resolveDetailsLayout(
        available: available,
        sidebarWidth: sidebar,
        desiredListWidth: listWanted,
        minListWidth: listMin,
        desiredDetailsWidth: detailsWanted,
        minDetailsWidth: detailsMin,
        threadFloor: floor,
      );

  double threadAt(double available) {
    final l = at(available);
    return available - sidebar - l.listWidth - l.detailsWidth;
  }

  test('места хватает — никто не ужимается', () {
    final l = at(1400);

    expect(l.listWidth, listWanted);
    expect(l.detailsWidth, detailsWanted);
  });

  test('🔴 первым уступает СПИСОК, панель остаётся полной', () {
    // Не хватает 60 точек: их отдаёт список, панель не трогаем — человек
    // открыл её намеренно и читает именно её.
    final l = at(sidebar + listWanted + detailsWanted + floor - 60);

    expect(l.detailsWidth, detailsWanted, reason: 'панель ужимать рано');
    expect(l.listWidth, listWanted - 60);
    expect(l.listWidth, greaterThanOrEqualTo(listMin));
  });

  test('🔴 список выжат до предела — только тогда ужимается панель', () {
    // Списку отдавать больше нечего (320 → 220), остаток берём с панели.
    final l = at(sidebar + listMin + detailsMin + floor + 10);

    expect(l.listWidth, listMin, reason: 'список обязан дойти до минимума');
    expect(l.detailsWidth, lessThan(detailsWanted));
    expect(l.detailsWidth, greaterThanOrEqualTo(detailsMin));
  });

  test('переписке сохраняется пол, пока соседям есть что отдать', () {
    for (final w in <double>[1400, 1200, 1140, sidebar + listMin + detailsMin + floor]) {
      expect(threadAt(w), greaterThanOrEqualTo(floor - 0.001),
          reason: 'при ширине $w переписке осталось ${threadAt(w)}');
    }
  });

  test('🔴 окно меньше всех минимумов — панель НЕ прячется', () {
    // Отдавать больше нечего, и переписка опускается ниже пола. Это честная
    // констатация тесноты. Прятать панель нельзя: человек открыл её намеренно,
    // а исчезновение по неизвестной причине хуже тесноты.
    final tiny = sidebar + listMin + detailsMin + 200;
    final l = at(tiny);

    expect(l.listWidth, listMin);
    expect(l.detailsWidth, detailsMin);
    expect(threadAt(tiny), 200, reason: 'переписка сузилась, но не исчезла');
  });

  test('панель никогда не уже своего минимума', () {
    for (final w in <double>[500, 700, 900, 1100]) {
      expect(at(w).detailsWidth, greaterThanOrEqualTo(detailsMin));
      expect(at(w).listWidth, greaterThanOrEqualTo(listMin));
    }
  });

  test('окно растянули обратно — ширины возвращаются сами', () {
    expect(at(900).listWidth, listMin);
    expect(at(1400).listWidth, listWanted,
        reason: 'решение пересчитывается на каждой перерисовке');
  });

  test('до первого замера окна — прежние ширины, без моргания', () {
    for (final bad in <double>[0, -1, double.nan]) {
      expect(at(bad).listWidth, listWanted);
      expect(at(bad).detailsWidth, detailsWanted);
    }
  });
}
