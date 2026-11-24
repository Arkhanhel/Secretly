// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Закреплённые сообщения (22.11.2026, Д-1…Д-9): чистые правила без
// контроллера и экрана — их проверяют тесты. Формат команды (`v:1`) не
// меняется: всё здесь — решения ПРИНИМАЮЩЕЙ стороны, старые сборки
// продолжают работать в обе стороны.

import '../rooms/room_models.dart';
import 'message_command_utils.dart';

/// Выключатель нового перехода к закреплённому / цитате (Д-1, Д-2, Д-4, Д-8):
/// поиск строки в показанном списке, расширение окна ленты, «Сообщение
/// недоступно» + «Открепить». false — прежний прыжок «76 px на строку».
const bool kPinJumpV2 = true;

/// Выключатель проверок приёма (Д-3, Д-6, Д-7, Д-9, G-3, G-5).
const bool kPinSyncChecksV2 = true;

/// Насколько ревизия списка может быть «из будущего» по своим часам (G-3).
/// Как у таймера исчезающих: спешащие часы отправителя не дают списку
/// вечного первенства.
const int kPinRevisionFutureSkewMs = 5 * 60 * 1000;

/// Свежесть пришедшего списка, которой можно верить (G-3). [fresh] —
/// `command.freshnessMs(atMs)` (по ревизии, без неё — по времени
/// сообщения). Ревизия дальше «сейчас + 5 минут» — часы автора спешат:
/// тогда свежесть — время самого сообщения [messageAtMs] (оно не меняется
/// от перерисовки к перерисовке), а без него — «сейчас + 5 минут».
int trustedPinFreshnessMs(int fresh, int nowMs, {int messageAtMs = 0}) {
  if (!kPinSyncChecksV2 || fresh <= 0) return fresh;
  final limit = nowMs + kPinRevisionFutureSkewMs;
  if (fresh <= limit) return fresh;
  return (messageAtMs > 0 && messageAtMs <= limit) ? messageAtMs : limit;
}

/// Принимать ли список закреплённых комнаты от автора (Д-6): своё
/// устройство — да; чужой — только если по МОЕМУ знанию о составе у него
/// есть право закреплять (та же формула, что у кнопки «Закрепить»).
bool roomPinAuthorAllowed({
  required bool isOwn,
  required RoomMemberRole? authorRole,
  required RoomSettings? settings,
}) {
  if (!kPinSyncChecksV2) return true;
  if (isOwn) return true;
  if (authorRole == null || settings == null) return false;
  return roomRoleCanPinMessages(authorRole, settings);
}

/// Нужно ли объединять (Д-7): первый пришедший список в ЛИЧНОМ чате, когда
/// свой список заведён до обновления (ревизия 0) — тогда пришедший не
/// стирает свои закрепления, а дополняется ими.
bool needsFirstAdoptionMerge({
  required bool isGroup,
  required int localRevision,
  required List<PinnedRef> localPins,
}) => kPinSyncChecksV2 && !isGroup && localRevision <= 0 && localPins.isNotEmpty;

/// Объединение по eventId: пришедшие важнее (их подпись), свои добавляются;
/// новые сверху, до 50.
List<PinnedRef> mergeChatPins({
  required List<PinnedRef> local,
  required List<PinnedRef> inbound,
}) {
  final seen = <String>{};
  final out = <PinnedRef>[];
  for (final p in [...inbound, ...local]) {
    final id = p.eventId.trim();
    if (id.isEmpty || !seen.add(id)) continue;
    out.add(p);
  }
  out.sort((a, b) => b.pinnedAtMs.compareTo(a.pinnedAtMs));
  return out.take(50).toList(growable: false);
}

/// Есть ли в [merged] что-то сверх [inbound] — тогда объединённый список
/// надо разослать.
bool mergeAddsPins(List<PinnedRef> merged, List<PinnedRef> inbound) {
  final ids = inbound.map((p) => p.eventId.trim()).toSet();
  return merged.any((p) => !ids.contains(p.eventId.trim()));
}

/// Закреплённые без удалённых у всех (Д-3) — текст удалённого сообщения не
/// должен оставаться на плашке.
List<T> pinsWithoutDeleted<T>(
  List<T> pins,
  String Function(T pin) idOf,
  Set<String> deletedIds,
) {
  if (deletedIds.isEmpty) return pins;
  if (!pins.any((p) => deletedIds.contains(idOf(p).trim()))) return pins;
  return pins
      .where((p) => !deletedIds.contains(idOf(p).trim()))
      .toList(growable: false);
}

/// Окно ленты для перехода (Д-1): растёт шагом [step], но не выше
/// [ceiling]. null — расти некуда.
int? nextPinJumpWindowLimit({
  required int current,
  required int step,
  required int ceiling,
}) {
  if (current >= ceiling) return null;
  final next = current + step;
  return next > ceiling ? ceiling : next;
}

/// Следующее смещение прокрутки при поиске строки (Д-4). Список
/// перевёрнутый: больший индекс — дальше от низа, больше смещение.
/// [minBuilt]/[maxBuilt] — индексы построенных сейчас строк (−1 — ни одной),
/// [averageRowExtent] — средняя высота построенных строк (0 — неизвестна).
/// Далеко — прыжок на оценку расстояния (с недолётом 10 %), близко — шаг
/// 0,8 экрана.
double nextPinJumpOffset({
  required double pixels,
  required double viewport,
  required double maxExtent,
  required int targetIndex,
  required int minBuilt,
  required int maxBuilt,
  double averageRowExtent = 0,
  double estimatedRowExtent = 76,
}) {
  double clamp(double v) => v < 0 ? 0 : (v > maxExtent ? maxExtent : v);
  final row = averageRowExtent > 0 ? averageRowExtent : estimatedRowExtent;
  if (minBuilt < 0 || maxBuilt < 0) {
    return clamp(targetIndex * row);
  }
  final step = viewport * 0.8;
  double delta(int rows) {
    if (averageRowExtent <= 0) return step;
    final est = rows * averageRowExtent * 0.9;
    return est > step ? est : step;
  }

  if (targetIndex > maxBuilt) return clamp(pixels + delta(targetIndex - maxBuilt));
  if (targetIndex < minBuilt) return clamp(pixels - delta(minBuilt - targetIndex));
  return clamp(pixels);
}

/// Подсветка «только последняя попытка гасит» (Д-8): двойное касание
/// запускает два перехода, и таймер первого гасил подсветку второго.
class LatestAttempt {
  int _value = 0;

  /// Начать новую попытку — номер для [isLatest].
  int begin() => ++_value;

  bool isLatest(int attempt) => attempt == _value;
}
