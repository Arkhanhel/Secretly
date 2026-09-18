// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'desktop_shell.dart' show DesktopShellApi;
import 'resizable_divider.dart';

/// Список чатов и переписка рядом — со швом, который можно тянуть.
///
/// 🔴 КРАЙ СПИСКА НЕ ТЯНУЛСЯ С САМОГО ПОЯВЛЕНИЯ (07.08 → 16.09.2026).
///
/// Ручку перетаскивания тогда поставили не в РЯД между списком и перепиской,
/// а в СТОЛБЕЦ над ними — между полосой уведомлений и самим рядом. В столбце
/// у неё не было высоты: невидимая полоска в ноль точек, схватить которую
/// нельзя. Между списком и перепиской стояла обычная линия. Оболочка при этом
/// честно хранила и сохраняла ширину, которую никто не мог изменить.
/// Владелец заметил это, сравнив с телеграмом, где левая панель тянется от
/// узкой до почти всего окна.
///
/// Раскладка вынесена сюда, чтобы шов и ручка не могли разъехаться снова:
/// ширину списка задаёт ЭТОТ виджет, и ручка стоит ровно на ней.
///
/// Ручка НАЛОЖЕНА поверх шва, а не вставлена в ряд: вставленная, она отняла
/// бы у переписки свои восемь точек и показала бы между колонками полоску
/// чужого фона. Линию шва по-прежнему рисует ряд; ручка лишь подсвечивает её
/// при наведении и перетаскивании.
class ListThreadSplit extends StatelessWidget {
  const ListThreadSplit({
    super.key,
    required this.listWidth,
    required this.list,
    required this.thread,
    required this.onResize,
    this.onReset,
    this.onResizeStart,
    this.onResizeEnd,
  });

  /// Ширина и все ручки края — из оболочки, одним вызовом. Так раздел не
  /// может подключить шаг перетаскивания и забыть начало или конец жеста,
  /// без которых край, меряемый от курсора, продолжил бы прошлый жест.
  ListThreadSplit.fromApi(
    DesktopShellApi api, {
    Key? key,
    required Widget list,
    required Widget thread,
  }) : this(
         key: key,
         listWidth: api.listWidth,
         onResize: api.onListResize,
         onReset: api.onListReset,
         onResizeStart: api.onListResizeStart,
         onResizeEnd: api.onListResizeEnd,
         list: list,
         thread: thread,
       );

  final double listWidth;
  final Widget list;
  final Widget thread;

  /// Шаг перетаскивания края, вправо — положительный.
  final ValueChanged<double> onResize;

  /// Двойной щелчок по краю.
  final VoidCallback? onReset;

  /// Перетаскивание края началось.
  final VoidCallback? onResizeStart;

  /// Перетаскивание края закончилось.
  final VoidCallback? onResizeEnd;

  /// Ширина области, за которую можно взяться. Шире самой линии: в одну точку
  /// мышью не попасть.
  static const double hitWidth = 9;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: listWidth, child: list),
            Container(width: 1, color: c.borderSubtle),
            Expanded(child: thread),
          ],
        ),
        // Ручка заходит на список всего на точку, а остальное — на
        // переписку: у правого края списка появляется полоса прокрутки, и
        // отнимать её у мыши нельзя. У переписки же в первых точках от шва
        // ничего нажимаемого нет — лента начинается с отступа.
        //
        // Подсветка при этом ложится ровно на шов: его середина — в полутора
        // точках от левого края ручки.
        Positioned(
          top: 0,
          bottom: 0,
          left: listWidth - 1,
          width: hitWidth,
          child: ResizableDivider(
            onDelta: onResize,
            onReset: onReset,
            onDragStart: onResizeStart,
            onDragEnd: onResizeEnd,
            hitWidth: hitWidth,
            showIdleLine: false,
            lineCenter: 1.5,
          ),
        ),
      ],
    );
  }
}
