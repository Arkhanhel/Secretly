// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Собственный конверт не лечится и не копится.
//
// Поле 23.08.2026 (диагностика владельца, «Не удалось прочитать: 5»):
//
//   reset_ping_enqueued peer_dev=7089ba66   ← device_id ЭТОГО ЖЕ телефона
//   outbox.sent msg=7e33f26b
//   inbox.delivered msg=7e33f26b
//   decrypt failed: SecretBoxAuthenticationError (MAC)
//   quarantined msg=7e33f26b sender_dev=7089ba66
//
// Устройство слало лечебный пинг САМОМУ СЕБЕ, получало его обратно и не могло
// расшифровать — сессии с собой не существует. Карантин трактует это как
// «сессия с пиром разошлась» и заказывает НОВЫЙ пинг: цикл кормит сам себя,
// каждые ~40 секунд счётчик рос на единицу.
//
// Оба конца цикла закрыты, и тест сторожит именно их.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final controller = File('lib/app/app_controller.dart').readAsStringSync();

  test('пинг сброса не уходит на собственное устройство', () {
    final start = controller.indexOf('void _dispatchSessionResetPing(');
    expect(start, greaterThan(0));
    final body = controller.substring(start, start + 1600);
    expect(body.contains("(_deviceId ?? '')"), isTrue,
        reason: 'лечебный пинг снова может уйти самому себе — это гарантированная '
            'MAC-ошибка и самоподдерживающийся цикл');
    expect(body.contains('isOwnDeviceId'), isFalse,
        reason: 'фильтр по ЛЮБОМУ своему устройству отрежет лечение сессии со '
            'вторым своим устройством — а это полноценный пир');
    // Проверка обязана стоять ДО постановки в очередь, иначе она бесполезна.
    final guard = body.indexOf("(_deviceId ?? '')");
    final enqueue = body.indexOf('outboxUpsert');
    if (enqueue > 0) {
      expect(guard, lessThan(enqueue),
          reason: 'проверка «это я» стоит после постановки в очередь');
    }
  });

  test('конверт со ВТОРОГО своего устройства не выбрасывается', () {
    // Self-fanout: свои сообщения приезжают на другие свои устройства и должны
    // применяться, а не отбрасываться как «своё».
    final start = controller.indexOf('self_envelope_dropped');
    final around = controller.substring(start - 1200, start + 200);
    expect(around.contains('isOwnDeviceId'), isFalse,
        reason: 'отбрасывание по «любому своему устройству» теряет собственную '
            'переписку, приехавшую с телефона на планшет');
  });

  test('собственный конверт отбрасывается, а не карантинится', () {
    expect(controller.contains('self_envelope_dropped'), isTrue,
        reason: 'свой конверт снова попадает в карантин и будет переигрываться '
            'вечно: расшифровать его нельзя ни при каком лечении');
    final start = controller.indexOf('self_envelope_dropped');
    final around = controller.substring(start - 1200, start + 200);
    expect(around.contains('inboxQuarantineDelete'), isTrue,
        reason: 'уже застрявшая копия останется в карантине и счётчик '
            '«не удалось прочитать» не обнулится');
  });

  test('петлевые конверты убираются при запуске, а не ждут переигровки', () {
    // Фильтр на входе ловит только НОВЫЕ попытки. Уже припаркованные записи
    // ждут переигровки, которой для них не наступает (в поле:
    // `quarantine_replay_throttled skipped=6`), поэтому счётчик «не удалось
    // прочитать» висел бы вечно.
    expect(controller.contains('_purgeSelfQuarantine'), isTrue,
        reason: 'разовая уборка карантина пропала — счётчик снова застрянет');
    final start = controller.indexOf('Future<void> _purgeSelfQuarantine');
    final body = controller.substring(start, start + 1400);
    expect(body.contains("sender != selfDid"), isTrue,
        reason: 'уборка обязана сверяться со СВОИМ device_id: конверт со второго '
            'своего устройства — обычная синхронизация, его удалять нельзя');
    expect(controller.contains('unawaited(_purgeSelfQuarantine())'), isTrue,
        reason: 'уборка не вызывается при запуске');
    // Молчание не должно значить одновременно «нечего убирать» и «уборка не
    // отработала» — на этом уже потеряли один заход.
    expect(body.contains("'scanned': rows.length"), isTrue,
        reason: 'уборка снова молчит, когда ничего не удалила');
  });
}
