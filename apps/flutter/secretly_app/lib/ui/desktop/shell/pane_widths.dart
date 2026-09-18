// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;

/// Арифметика перетаскивания краёв колонок: списка чатов и правой панели.
///
/// Вынесена из оболочки, чтобы её можно было проверить: здесь решается, КТО
/// уступает место, когда край тянут, — и это решение важнее самих чисел.
///
/// 🔴 Как в телеграме (указание владельца 16.09.2026, со скриншотами узкой и
/// растянутой левой панели): список тянется от узкого до почти всего окна, а
/// переписке остаётся только её пол. Потолка «на вкус» у списка (было 720)
/// больше нет — предел ставит окно. У правой панели он поднят с 520 до 720:
/// её содержимое рассчитано на колонку, а не на пол-экрана.

/// Ширина СВЁРНУТОЙ левой панели — один столбик портретов, как в телеграме:
/// портрет 50 и по 13 точек полей с каждой стороны.
const double kCompactListWidth = 76;

/// Итог перетаскивания края списка.
class ListDragResult {
  const ListDragResult({
    required this.listWidth,
    this.detailsWidth,
    this.compact = false,
  });

  final double listWidth;

  /// Новая ширина правой панели; `null` — панель закрыта и не менялась.
  final double? detailsWidth;

  /// Список свёрнут в столбик портретов.
  final bool compact;
}

/// Потолок ширины списка: всё окно, кроме рейки, пола переписки и —
/// если правая панель открыта — её минимума.
double listCeiling({
  required double available,
  required double rail,
  required double threadFloor,
  required double minList,
  double reservedRight = 0,
}) {
  if (!available.isFinite || available <= 0) return double.infinity;
  return math.max(minList, available - rail - threadFloor - reservedRight);
}

/// Край СПИСКА потянули на [dx] (вправо — шире).
///
/// Отсчёт — от ВИДИМОЙ ширины [shownList], а не от сохранённой: когда правая
/// панель сжала список, сохранённая больше видимой, и шаг, прибавленный к
/// ней, не двигал край вовсе. Сворачивания здесь нет — см. [listEdgeAt].
///
/// 🔴 Открытая правая панель УСТУПАЕТ, но не ниже своего минимума. Человек
/// тянет край списка намеренно; если переписка уже на полу, место можно взять
/// только у панели. Иначе `resolveDetailsLayout`, который первым ужимает
/// список, тут же отбирал бы растянутое обратно, и край не двигался бы.
/// Когда список, наоборот, сужают, панель возвращается к желаемой ширине
/// [desiredDetails].
ListDragResult dragListEdge({
  required double dx,
  required double shownList,
  required double available,
  required double rail,
  required double threadFloor,
  required double minList,
  double? desiredDetails,
  double minDetails = 0,
}) => listEdgeAt(
  pointer: shownList + dx,
  available: available,
  rail: rail,
  threadFloor: threadFloor,
  minList: minList,
  desiredDetails: desiredDetails,
  minDetails: minDetails,
);

/// Где встанет край списка, если курсор увёл его туда, где край оказался бы
/// без всяких пределов, — в [pointer].
///
/// Мерить от курсора, а не копить шаги, важно: край, упёршийся в предел,
/// остаётся на месте, пока курсор не вернётся к нему, — так ведут себя все
/// настольные разделители. Накопленные шаги тронули бы край сразу.
///
/// 🔴 СВОРАЧИВАНИЕ, КАК В ТЕЛЕГРАМЕ (указание владельца 16.09.2026). Если
/// [compactWidth] задана и курсор ушёл левее середины между минимумом и
/// свёрнутым видом, список становится столбиком портретов. Обратно — тем же
/// порогом: курсор правее него, и список снова полный, от минимума.
ListDragResult listEdgeAt({
  required double pointer,
  required double available,
  required double rail,
  required double threadFloor,
  required double minList,
  double? desiredDetails,
  double minDetails = 0,
  double? compactWidth,
}) {
  final collapse =
      compactWidth != null && pointer < (minList + compactWidth) / 2;
  final open = desiredDetails != null;
  final double list;
  if (collapse) {
    list = compactWidth;
  } else {
    final ceiling = listCeiling(
      available: available,
      rail: rail,
      threadFloor: threadFloor,
      minList: minList,
      reservedRight: open ? minDetails : 0,
    );
    list = pointer.clamp(minList, ceiling).toDouble();
  }
  if (!open) return ListDragResult(listWidth: list, compact: collapse);
  final room = available - rail - threadFloor - list;
  final details = math.max(minDetails, math.min(desiredDetails, room));
  return ListDragResult(
    listWidth: list,
    detailsWidth: details,
    compact: collapse,
  );
}

/// Край ПРАВОЙ ПАНЕЛИ потянули на [dx] (влево — шире, поэтому шаг вычитается).
///
/// Панель растёт до [maxDetails] и до пола переписки при списке, сжатом до
/// минимума: список уступает первым, как и при открытии панели. Его
/// сохранённая ширина при этом не трогается — она вернётся, когда панель
/// закроют.
double dragDetailsEdge({
  required double dx,
  required double shownDetails,
  required double available,
  required double rail,
  required double threadFloor,
  required double minList,
  required double minDetails,
  required double maxDetails,
}) {
  final byWindow = available.isFinite && available > 0
      ? available - rail - threadFloor - minList
      : maxDetails;
  final ceiling = math.max(minDetails, math.min(maxDetails, byWindow));
  return (shownDetails - dx).clamp(minDetails, ceiling).toDouble();
}
