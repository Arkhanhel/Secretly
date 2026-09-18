// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/storage/app_db.dart';

// У-1 (17.09.2026): реле не знает устройство — приложение спрашивает сервер
// ключей и, только если регистрации действительно нет, показывает это.

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppController> controller(OwnDeviceRegistration answer) async {
    final db = await AppDb.openForTesting();
    addTearDown(db.close);
    return AppController()
      ..seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      )
      ..ownDeviceRegistrationProbeForTesting = (() async => answer)
      ..unknownDeviceConfirmDelay = Duration.zero;
  }

  test('регистрации нет — признак поднят, данные не тронуты', () async {
    final c = await controller(OwnDeviceRegistration.gone);
    var resets = 0;
    c.sessionRevokeResetForTesting = () async => resets++;
    c.noteRelayUnknownDeviceForTesting();
    await _settle();
    expect(c.ownDeviceRemoved, isTrue);
    expect(resets, 0);
  });

  test('сервер говорит «на месте» или молчит — ничего не меняется', () async {
    for (final answer in const [
      OwnDeviceRegistration.present,
      OwnDeviceRegistration.unknown,
    ]) {
      final c = await controller(answer);
      c.noteRelayUnknownDeviceForTesting();
      await _settle();
      expect(c.ownDeviceRemoved, isFalse, reason: answer.name);
    }
  });

  test('🔴 после восстановления: сначала «нет», через паузу «на месте» — полосы нет',
      () async {
    // Свежий номер регистрируется в фоне, а реле подключается сразу.
    final c = await controller(OwnDeviceRegistration.gone);
    var calls = 0;
    c.ownDeviceRegistrationProbeForTesting = () async => calls++ == 0
        ? OwnDeviceRegistration.gone
        : OwnDeviceRegistration.present;
    c.noteRelayUnknownDeviceForTesting();
    await _settle();
    expect(calls, 2, reason: '«нет» проверяется повторно');
    expect(c.ownDeviceRemoved, isFalse);
  });

  test('реле снова приняло устройство — полоса снимается', () async {
    final c = await controller(OwnDeviceRegistration.gone);
    c.noteRelayUnknownDeviceForTesting();
    await _settle();
    expect(c.ownDeviceRemoved, isTrue);
    c.noteRelayAcceptedOwnDeviceForTesting();
    expect(c.ownDeviceRemoved, isFalse);
  });

  test('🔴 смена номера: неотправленное помечается «не отправлено»', () async {
    // Провод зашифрован со старым номером в заголовке; реле назовёт новый, и
    // получатель 600+ отбросил бы его молча. Повтор пересоберёт сообщение.
    final db = await AppDb.openForTesting();
    addTearDown(db.close);
    final c = AppController()
      ..seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );
    Future<void> outgoing(String id, String outboxState) async {
      await db.insertEvent(
        eventId: 'ev-$id',
        convoId: 'friend-1',
        type: 'msg',
        senderDeviceId: 'owner-device',
        ciphertextB64: 'AA==',
        createdAtMs: 1000,
        localState: 'pending',
      );
      await db.outboxUpsert(
        msgId: 'msg-$id',
        toDeviceId: 'friend-device',
        ciphertextB64: 'AA==',
        ttlSeconds: 60,
        state: outboxState,
        attemptCount: 0,
        nextRetryAtMs: 0,
        createdAtMs: 1000,
        eventIdRef: 'ev-$id',
      );
    }

    await outgoing('a', 'pending');
    await outgoing('b', 'sent');
    await c.failOutboxAfterDeviceRotationForTesting();
    final rows = await db.rawQueryForTesting(
      'SELECT msg_id, state FROM outbox ORDER BY msg_id',
      const <Object?>[],
    );
    expect(
      {for (final r in rows) r['msg_id']: r['state']},
      {'msg-a': 'failed', 'msg-b': 'sent'},
    );
    final ev = await db.eventGet('ev-a');
    expect(ev?['local_state'], 'failed');
  });
}
