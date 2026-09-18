// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🔴 ЛЕЧЕНИЕ ОБЯЗАНО БЫТЬ ПОДКЛЮЧЕНО ВО ВСЕХ ПУТЯХ, А НЕ В ОДНОМ ИЗ ДВУХ.
///
/// Этот тест существует потому, что мы наступили на одно и то же трижды за две
/// недели: правило написано верно, покрыто зелёными тестами — и не подключено к
/// половине путей. 15.08: пауза переигровки стояла в заходе по отправителю и
/// отсутствовала в заходе по всей парковке (печать была, пропуска не было).
///
/// Тест проверяет ПРОВОДКУ по исходнику: поведенческий тест этого класса не
/// ловит — правило исправно, не подключён вызов.
void main() {
  final controller = File('lib/app/app_controller.dart').readAsStringSync();
  final db = File('lib/storage/app_db.dart').readAsStringSync();

  test('🔴 пере-NACK стоит в ОБОИХ заходах переигровки карантина', () {
    // Л-2: пауза переигровки (правка 15.08) молча задушила существующую
    // машину восстановления — конверт не переигрывается, значит не
    // проваливается, значит отправителя больше никто не просит пере-шифровать.
    // Инцидент 15–16.08: сутки одной галочки.
    final skips = 'skippedHopeless += 1'.allMatches(controller).toList();
    expect(
      skips.length,
      greaterThanOrEqualTo(2),
      reason: 'заходов переигровки меньше двух — тест устарел, проверить',
    );
    for (final skip in skips) {
      final tail = controller.substring(
        skip.start,
        (skip.start + 900).clamp(0, controller.length),
      );
      expect(
        tail.contains('_nackQuarantinedWireOnce('),
        isTrue,
        reason: 'пропуск переигровки БЕЗ пере-NACK — это и есть тупик: '
            'дорогая расшифровка ждёт час, но «я не могу это прочитать» '
            'обязано звучать; позиция: ${skip.start}',
      );
    }
  });

  test('🔴 пере-NACK ограничен паузой переигровки, а не чаще', () {
    // Иначе возвращается шторм лечения, задушенный 15.08 (52 → 9 в час).
    final calls = '_nackQuarantinedWireOnce('.allMatches(controller).toList();
    // Вызовы из переигровки обязаны нести срок клейма; вызов из СВЕЖЕГО отказа
    // (первая парковка) идёт без него — там уместен обычный клейм.
    final withTtl = calls.where((m) {
      final tail = controller.substring(
        m.start,
        (m.start + 220).clamp(0, controller.length),
      );
      return tail.contains('reNackAfterMs:');
    }).length;
    expect(
      withTtl,
      greaterThanOrEqualTo(2),
      reason: 'оба захода переигровки обязаны передавать срок клейма',
    );
  });

  test('🔴 бюджет переотправки везде считается С ЭПОХОЙ сессии', () {
    // Д-3: ключ без эпохи означал, что пять копий под МЁРТВОЙ сессией запирают
    // сообщение навсегда. Проверяем, что ни один путь не остался на старом.
    for (final call in <String>[
      'resendBudgetHasRoom(',
      'resendBudgetConsume(',
      'resendBudgetGrantBonus(',
      'resendPendingMark(',
    ]) {
      for (final m in call.allMatches(controller)) {
        final tail = controller.substring(
          m.start,
          (m.start + 400).clamp(0, controller.length),
        );
        final body = tail.substring(0, tail.indexOf(');') + 1);
        expect(
          body.contains('epoch:'),
          isTrue,
          reason: '$call без эпохи — капкан бюджета возвращается',
        );
      }
    }
  });

  test('🔴 ключ бюджета в хранилище несёт эпоху', () {
    expect(
      RegExp(r"'rsb:\$deviceId:\$eventId:e\$epoch'").hasMatch(db) ||
          db.contains(r"'rsb:$deviceId:$eventId:e$epoch'"),
      isTrue,
      reason: 'единица учёта бюджета — (устройство, событие, ЭПОХА)',
    );
  });

  test('🔴 «реле пусто» больше не глухой отказ, но и не открытый кран', () {
    final idx = controller.indexOf('if (held == 0) {');
    expect(
      idx,
      greaterThan(0),
      reason: 'вернулся безусловный `if (held == 0) return;` — это Д-1',
    );
    final block = controller.substring(idx, idx + 900);
    expect(
      block.contains('_resendHeldZeroMinAgeMs'),
      isTrue,
      reason: 'свежие события обязаны вести себя по-старому (замысел 6abd3ab8)',
    );
    expect(
      controller.contains('resendHeldZeroClaimOnce('),
      isTrue,
      reason: 'спасение обязано быть разовым на эпоху, иначе это кран',
    );
  });

  test('🔴 исчерпанный бюджет делает недоставку ВИДИМОЙ', () {
    final idx = controller.indexOf("'resend_budget_spent'");
    expect(idx, greaterThan(0));
    final block = controller.substring(idx, idx + 900);
    expect(
      block.contains('eventMarkFailedIfStillSent('),
      isTrue,
      reason: 'вечная одна галочка обязана перестать выглядеть как «отправлено»',
    );
  });
}
