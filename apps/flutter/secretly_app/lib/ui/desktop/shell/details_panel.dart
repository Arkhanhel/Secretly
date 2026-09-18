// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// A right-side details panel that animates in from the right
/// and HIDES TO THE LEFT (per request): closes by sliding leftward
/// while its width animates to zero, so the underlying content
/// expands rightward seamlessly.
///
/// Usage:
///
/// ```dart
/// DetailsPanel(
///   open: showDetails,
///   width: 320,
///   child: DetailsContent(...),
/// )
/// ```
class DetailsPanel extends StatefulWidget {
  const DetailsPanel({
    super.key,
    required this.open,
    required this.child,
    this.width = 320,
    this.duration = DMotion.medium,
  });

  final bool open;
  final Widget child;
  final double width;
  final Duration duration;

  @override
  State<DetailsPanel> createState() => _DetailsPanelState();
}

class _DetailsPanelState extends State<DetailsPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.open ? 1.0 : 0.0,
  );

  @override
  void didUpdateWidget(covariant DetailsPanel old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) _c.forward();
    if (!widget.open && old.open) _c.reverse();
    if (widget.duration != old.duration) _c.duration = widget.duration;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = DMotion.easeOutCubic.transform(_c.value.clamp(0.0, 1.0));
        final currentWidth = widget.width * t;
        // Hide-to-LEFT: when closing, content shifts leftward (off-screen behind
        // the chat area). Opens by sliding rightward into place from the left.
        final dx = -widget.width * (1 - t);
        if (currentWidth < 0.5) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          width: currentWidth,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: widget.width,
              maxWidth: widget.width,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Opacity(
                  opacity: t,
                  child: Container(
                    width: widget.width,
                    decoration: BoxDecoration(
                      color: c.detailsPanel,
                      border: Border(
                        left: BorderSide(color: c.borderSubtle),
                      ),
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Ширины колонок, когда панель подробностей открыта.
class DetailsLayout {
  const DetailsLayout({required this.detailsWidth, required this.listWidth});

  final double detailsWidth;
  final double listWidth;
}

/// 🔴 ПАНЕЛЬ НИКОГДА НЕ ЛОЖИТСЯ ПОВЕРХ ПЕРЕПИСКИ. Она выдвигается справа
/// своей колонкой, а место ей уступают соседи.
///
/// Накладка выглядит дешёвым решением ровно до того момента, когда человек
/// пытается читать переписку и панель одновременно: она закрывает правый край
/// сообщений — тот самый, где стоят время и галочки. Поэтому здесь панель
/// всегда занимает свою ширину, а недостающее место отдают соседи, в порядке
/// от наименее ценного к наиболее.
///
/// Очередь уступок:
///
/// 1. **Список чатов.** Он самый сжимаемый: в 220 точках всё ещё помещается
///    имя со временем, а человек, открывший подробности, сейчас читает ОДИН
///    чат — список ему в этот момент нужен меньше всего. Так же ведут себя
///    Telegram и Slack.
/// 2. **Сама панель.** Если сжатого списка не хватило, панель ужимается к
///    своему минимуму — лучше узкая панель, чем задушенная переписка.
/// 3. **Переписка.** Последняя, и только когда отдавать больше нечего: у неё
///    есть пол, и опускаться ниже него — это уже не выбор, а констатация, что
///    окно слишком мало. Прятать панель вместо этого нельзя: человек открыл её
///    намеренно, и исчезновение по неизвестной причине хуже тесноты.
///
/// Решение пересчитывается на каждой перерисовке, поэтому растянутое обратно
/// окно само возвращает соседям их ширину.
DetailsLayout resolveDetailsLayout({
  required double available,
  required double sidebarWidth,
  required double desiredListWidth,
  required double minListWidth,
  required double desiredDetailsWidth,
  required double minDetailsWidth,
  required double threadFloor,
}) {
  // Невменяемая ширина приходит на первом кадре, до первого замера окна.
  if (!available.isFinite || available <= 0) {
    return DetailsLayout(
      detailsWidth: desiredDetailsWidth,
      listWidth: desiredListWidth,
    );
  }

  var list = desiredListWidth;
  var details = desiredDetailsWidth;
  var need = threadFloor - (available - sidebarWidth - list - details);
  if (need <= 0) {
    return DetailsLayout(detailsWidth: details, listWidth: list);
  }

  final fromList = need.clamp(0.0, (list - minListWidth).clamp(0.0, list));
  list -= fromList;
  need -= fromList;

  if (need > 0) {
    final fromDetails =
        need.clamp(0.0, (details - minDetailsWidth).clamp(0.0, details));
    details -= fromDetails;
  }

  return DetailsLayout(detailsWidth: details, listWidth: list);
}
