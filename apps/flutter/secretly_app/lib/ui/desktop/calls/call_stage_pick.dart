// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Кого показывать на сцене созвона — и в каком порядке.
///
/// 🔴 СЦЕНА ГАСЛА, КОГДА НИКТО НЕ ГОВОРИЛ.
///
/// Условие показа камеры было буквально таким: `speaking ||
/// участников ровно один`. То есть втроём, с включёнными у всех камерами, в
/// первую же паузу разговора ни одна камера не проходила проверку, и сцена
/// уходила в сетку неподвижных портретов. Стоило кому-то заговорить —
/// возвращалась. Картинка мигала в такт речи.
///
/// Памяти о том, кто говорил последним, не было вообще, поэтому даже
/// «оставить того, кто только что держал слово» было нечем.
///
/// Порядок выбора здесь ОДИН и вынесен из вёрстки, чтобы его можно было
/// проверить тестом без камер, комнаты и второго человека:
///
///   1. демонстрация экрана — то, ради чего созвон и собрали;
///   2. тот, кто ГОВОРИТ СЕЙЧАС;
///   3. тот, кто говорил ПОСЛЕДНИМ (если камера у него ещё есть);
///   4. любая живая камера — лучше чужое спокойное лицо, чем заставка;
///   5. ничего из перечисленного — сетка портретов.
///
/// Пункт 3 нужен не только ради пауз: без него при двух одновременно
/// говорящих сцена перепрыгивала бы между ними на каждом кадре. Держим того,
/// кто уже на сцене, пока он не замолчал.
library;

/// Что показать на сцене. `null` — показывать нечего, нужна сетка портретов.
typedef StagePick = ({String deviceId, bool screenShare});

/// [screenShares] и [cameras] — только те, чей вид УЖЕ готов к показу.
/// Порядок внутри списков — порядок участников созвона.
StagePick? pickStageVideo({
  required List<String> screenShares,
  required List<String> cameras,
  required Set<String> speaking,
  String? lastSpeaker,
}) {
  if (screenShares.isNotEmpty) {
    return (deviceId: screenShares.first, screenShare: true);
  }
  if (cameras.isEmpty) return null;

  // Тот, кто уже на сцене и всё ещё говорит, остаётся на сцене: иначе при
  // двух говорящих картинка прыгала бы между ними.
  if (lastSpeaker != null &&
      speaking.contains(lastSpeaker) &&
      cameras.contains(lastSpeaker)) {
    return (deviceId: lastSpeaker, screenShare: false);
  }
  for (final id in cameras) {
    if (speaking.contains(id)) return (deviceId: id, screenShare: false);
  }
  // Пауза в разговоре — держим последнего говорившего.
  if (lastSpeaker != null && cameras.contains(lastSpeaker)) {
    return (deviceId: lastSpeaker, screenShare: false);
  }
  // Ещё никто не говорил (или у говорившего выключилась камера) — любая
  // живая картинка лучше сетки неподвижных портретов.
  return (deviceId: cameras.first, screenShare: false);
}

/// Кого запомнить как «говорил последним».
///
/// Возвращает нового кандидата или [previous], если сейчас не говорит никто.
/// Память НЕ сбрасывается тишиной — в этом весь смысл: пауза не должна гасить
/// сцену.
String? nextLastSpeaker({
  required Set<String> speaking,
  required List<String> cameras,
  String? previous,
}) {
  if (previous != null && speaking.contains(previous)) return previous;
  for (final id in cameras) {
    if (speaking.contains(id)) return id;
  }
  return previous;
}
