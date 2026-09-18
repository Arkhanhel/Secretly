// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

/// 🔴 БЕЗНАДЁЖНЫЙ КОНВЕРТ ПЕРЕИГРЫВАЕТСЯ РЕДКО, А НЕ КАЖДЫЙ ЗАХОД.
///
/// ЗАМЕР ПОЛЯ 15.08: ОДИН конверт с утерянным ключом ратчета дал 23 лечения
/// сессии за полчаса — каждый заход переигрывал его заново, каждая неудача
/// гнала reset-ping. По всему реле за сутки: 663 конверта лечения на 738
/// сообщений.
///
/// 🔴 ЧЕГО ЭТА ПРАВКА НЕ ДЕЛАЕТ, И ЭТО ГЛАВНОЕ: конверт НЕ выбрасывается и
/// лечение из повтора НЕ отключается. Без них случился инцидент 28.07 — 65
/// неоткрываемых конвертов, 63 жалобы и ноль восстановления за 28 часов.
/// Меняется только частота: раз в час вместо каждого захода.
void main() {
  const nowMs = 1_800_000_000_000;
  const hour = 60 * 60 * 1000;

  Map<String, Object?> row({required int attempts, required int lastMs}) =>
      <String, Object?>{'attempts': attempts, 'last_attempt_at_ms': lastMs};

  test('🔴 свежий конверт пробуется СРАЗУ — он ещё может открыться', () {
    // Первые неудачи объясняются обычной жизнью: конверт мог прийти раньше
    // своей сессии или во время её пересборки.
    for (var attempts = 0; attempts < 3; attempts += 1) {
      expect(
        AppController.quarantineReplayTooSoonForRow(
          row(attempts: attempts, lastMs: nowMs - 1000),
          nowMs: nowMs,
        ),
        isFalse,
        reason: 'попытка $attempts обязана состояться немедленно',
      );
    }
  });

  test('🔴 безнадёжный конверт НЕ пробуется чаще раза в час', () {
    expect(
      AppController.quarantineReplayTooSoonForRow(
        row(attempts: 3, lastMs: nowMs - 5 * 60 * 1000),
        nowMs: nowMs,
      ),
      isTrue,
      reason: 'пять минут назад уже пробовали — это и есть шторм лечения',
    );
  });

  test('🔴 через час пробуется СНОВА — сессия могла починиться', () {
    expect(
      AppController.quarantineReplayTooSoonForRow(
        row(attempts: 42, lastMs: nowMs - hour - 1000),
        nowMs: nowMs,
      ),
      isFalse,
      reason: 'конверт не выброшен: он ждёт починки сессии, а не удаления',
    );
  });

  test('конверт без отметки попытки пробуется — счёта нет, судить не о чем', () {
    expect(
      AppController.quarantineReplayTooSoonForRow(
        row(attempts: 9, lastMs: 0),
        nowMs: nowMs,
      ),
      isFalse,
    );
  });

  test('🔴 прыжок часов назад не превращает паузу в вечное молчание', () {
    // Смена пояса, сон устройства, ручная правка времени: отметка попытки
    // оказывается «в будущем». Молчать из-за этого нельзя.
    expect(
      AppController.quarantineReplayTooSoonForRow(
        row(attempts: 9, lastMs: nowMs + 10 * hour),
        nowMs: nowMs,
      ),
      isFalse,
    );
  });
}
