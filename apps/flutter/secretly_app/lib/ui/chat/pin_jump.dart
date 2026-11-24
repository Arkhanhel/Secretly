// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Переход к закреплённому сообщению / к цитате ответа (22.11.2026, Д-4).
//
// 🔴 Раньше: один прыжок на «индекс × 76 px», индекс — из списка, который
// НЕ совпадает с показанным (в показанном ещё строки отправки, плашка
// созвона, волна), и одна попытка. В чате с фото и голосовыми строка
// выше 76 px, прыжок промахивался, строка не строилась — и ничего не
// происходило, подсветки не было видно.
//
// Теперь: индекс — в показанном списке, и шаги по 0,8 экрана в сторону
// цели, пока строка не построится (до ~30 кадров).

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../app/chat_pins_logic.dart';

/// Прокручивает [controller], пока у строки [targetIndex] не появится
/// контекст ([targetContext]). [builtRange] — индексы построенных сейчас
/// строк и их средняя высота (`(-1, -1, 0)` — ни одной). [keepGoing] —
/// false, если попытку уже сменила более новая. Возвращает контекст строки
/// или null.
Future<BuildContext?> scrollUntilRowBuilt({
  required ScrollController controller,
  required int targetIndex,
  required BuildContext? Function() targetContext,
  required (int, int, double) Function() builtRange,
  bool Function()? keepGoing,
  int maxFrames = 30,
}) async {
  BuildContext? live() {
    final ctx = targetContext();
    return (ctx != null && ctx.mounted) ? ctx : null;
  }

  var stuck = 0;
  for (var frame = 0; frame < maxFrames; frame++) {
    final ctx = live();
    if (ctx != null) return ctx;
    if (keepGoing != null && !keepGoing()) return null;
    if (!controller.hasClients) return null;
    final pos = controller.position;
    if (!pos.hasContentDimensions) {
      await SchedulerBinding.instance.endOfFrame;
      continue;
    }
    final range = builtRange();
    final next = nextPinJumpOffset(
      pixels: pos.pixels,
      viewport: pos.viewportDimension,
      maxExtent: pos.maxScrollExtent,
      targetIndex: targetIndex,
      minBuilt: range.$1,
      maxBuilt: range.$2,
      averageRowExtent: range.$3,
    );
    if ((next - pos.pixels).abs() < 0.5) {
      // Упёрлись в край, а строки нет — ещё пара кадров на подгрузку.
      if (++stuck > 3) break;
    } else {
      stuck = 0;
      controller.jumpTo(next);
    }
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
  }
  return live();
}

/// Высота построенной строки по её контексту (0 — неизвестна).
double builtRowExtent(BuildContext ctx) {
  final box = ctx.findRenderObject();
  if (box is RenderBox && box.hasSize) return box.size.height;
  return 0;
}

/// Выключатель кнопки «вниз» как у Telegram (23.11.2026): `false` — снова
/// одна анимация 240 мс с любого расстояния.
const bool kTelegramScrollToLatest = true;

/// Куда мгновенно прыгнуть перед доездом вниз (лента перевёрнута: 0 — самое
/// новое). Ближе полутора экранов — `null`, доезжаем целиком.
double? scrollToLatestJumpOffset({
  required double pixels,
  required double viewport,
}) {
  final near = viewport * 1.5;
  return pixels > near ? near : null;
}
