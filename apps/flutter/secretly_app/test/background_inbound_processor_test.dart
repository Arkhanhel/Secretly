// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/push/background_inbound_processor.dart';
import 'package:secretly_app/storage/app_db.dart';

// TZ_BG_DECRYPT_2026-07-23: the background pass must apply what it can and PARK
// what it cannot — never drop, never double-process. These pin that orchestration
// with an injected decrypt, so it holds without standing up a ratchet session.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BackgroundInboundWire wire(String id) =>
      BackgroundInboundWire(msgId: id, ciphertextB64: 'ct-$id');

  test('a wire that decrypts is applied and marked seen', () async {
    final db = await AppDb.openForTesting();
    final res = await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [wire('m1'), wire('m2')],
      decrypt: ({required msgId, required ciphertextB64}) async => true,
      nowMs: 1000,
    );
    expect(res.applied, 2);
    expect(res.staged, 0);
    expect(await db.inboxHasSeen('m1'), isTrue);
    expect(await db.inboxHasSeen('m2'), isTrue);
    await db.close();
  });

  test('a wire that will not decrypt is parked, not dropped', () async {
    final db = await AppDb.openForTesting();
    final res = await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [wire('bad')],
      decrypt: ({required msgId, required ciphertextB64}) async => false,
      nowMs: 1000,
    );
    expect(res.applied, 0);
    expect(res.staged, 1);
    // Not marked seen — the foreground must still get its chance.
    expect(await db.inboxHasSeen('bad'), isFalse);
    // Parked in quarantine for the foreground's recovery sweep.
    expect(await db.inboxQuarantineCountAll(), 1);
    await db.close();
  });

  test('a decrypt that throws parks rather than dropping', () async {
    final db = await AppDb.openForTesting();
    final res = await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [wire('boom')],
      decrypt: ({required msgId, required ciphertextB64}) async =>
          throw StateError('crypto not ready'),
      nowMs: 1000,
    );
    expect(res.applied, 0);
    expect(res.staged, 1);
    expect(await db.inboxHasSeen('boom'), isFalse);
    await db.close();
  });

  test('an already-seen wire is skipped, never decrypted again', () async {
    final db = await AppDb.openForTesting();
    await db.inboxMarkSeen('dup');
    var called = false;
    final res = await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [wire('dup')],
      decrypt: ({required msgId, required ciphertextB64}) async {
        called = true;
        return true;
      },
      nowMs: 1000,
    );
    expect(res.skipped, 1);
    expect(res.applied, 0);
    expect(called, isFalse, reason: 'seen wires must not be re-decrypted');
    await db.close();
  });

  test('a mixed batch applies the good and parks the bad independently',
      () async {
    final db = await AppDb.openForTesting();
    final res = await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [wire('ok1'), wire('bad'), wire('ok2')],
      decrypt: ({required msgId, required ciphertextB64}) async =>
          msgId != 'bad',
      nowMs: 1000,
    );
    expect(res.applied, 2);
    expect(res.staged, 1);
    expect(await db.inboxHasSeen('ok1'), isTrue);
    expect(await db.inboxHasSeen('ok2'), isTrue);
    expect(await db.inboxHasSeen('bad'), isFalse);
    await db.close();
  });

  // ── Подтверждение приёма из фона (12.08.2026) ────────────────────────────
  //
  // Фоновый проход применял сообщение и не говорил об этом реле: в коде стояло
  // допущение «подтвердит следующий насос переднего плана». Верно — но только
  // когда человек ОТКРОЕТ приложение. Замер 11.08: остаток в ящике 6 → 7 → 7 → 7,
  // ноль подтверждений за 25 минут, и отправитель шлёт заново каждые 4,5 минуты.

  BackgroundInboundWire seqWire(String id, int seq) =>
      BackgroundInboundWire(msgId: id, ciphertextB64: 'ct-$id', seq: seq);

  test('применённое подтверждается', () async {
    final db = await AppDb.openForTesting();
    final acked = <int>[];
    final res = await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [seqWire('m1', 10), seqWire('m2', 11)],
      decrypt: ({required msgId, required ciphertextB64}) async => true,
      nowMs: 1000,
      ack: ({required seq, required msgId}) async {
        acked.add(seq);
        return true;
      },
    );
    expect(res.applied, 2);
    expect(acked, <int>[10, 11]);
    await db.close();
  });

  test('🔴 СЛОЖЕННОЕ НЕ ПОДТВЕРЖДАЕТСЯ НИКОГДА', () async {
    // Самый важный тест файла. Подтверждение — это разрешение реле ЗАБЫТЬ
    // сообщение. Сложенное в карантин ещё не разобрано; сказать «забудь» о нём
    // значит потерять его навсегда — реле больше не пришлёт, человек не увидит.
    final db = await AppDb.openForTesting();
    final acked = <int>[];
    final res = await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [seqWire('m1', 10)],
      decrypt: ({required msgId, required ciphertextB64}) async => false,
      nowMs: 1000,
      ack: ({required seq, required msgId}) async {
        acked.add(seq);
        return true;
      },
    );
    expect(res.staged, 1);
    expect(acked, isEmpty, reason: 'сложенное подтверждать нельзя');
    await db.close();
  });

  test('🔴 пропущенное подтверждается — иначе висит вечно', () async {
    // Замер 11.08 показал `applied=0 skipped=7`: семь сообщений давно применены
    // и всё ещё в ящике реле. Без подтверждения пропущенного они не уйдут
    // оттуда никогда.
    final db = await AppDb.openForTesting();
    await db.inboxMarkSeen('m1');
    final acked = <int>[];
    final res = await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [seqWire('m1', 10)],
      decrypt: ({required msgId, required ciphertextB64}) async {
        fail('уже виденное не должно расшифровываться заново');
      },
      nowMs: 1000,
      ack: ({required seq, required msgId}) async {
        acked.add(seq);
        return true;
      },
    );
    expect(res.skipped, 1);
    expect(acked, <int>[10]);
    await db.close();
  });

  test('🔴 неудача подтверждения паркует его в очередь, а не теряет', () async {
    // Иначе разовый сбой сети превращается в вечный повтор.
    final db = await AppDb.openForTesting();
    await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [seqWire('m1', 10)],
      decrypt: ({required msgId, required ciphertextB64}) async => true,
      nowMs: 1000,
      ack: ({required seq, required msgId}) async => false,
    );
    final parked = await db.pendingAckList(limit: 10);
    expect(parked, hasLength(1));
    expect((parked.single['seq'] as num).toInt(), 10);
    await db.close();
  });

  test('🔴 отказ подписи не роняет проход и не подтверждает', () async {
    // На заблокированном телефоне связка ключей сообщает об отсутствии
    // совершенно исправного элемента. Применение уже состоялось — обрывать его
    // из-за подписи нельзя.
    final db = await AppDb.openForTesting();
    final res = await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [seqWire('m1', 10)],
      decrypt: ({required msgId, required ciphertextB64}) async => true,
      nowMs: 1000,
      ack: ({required seq, required msgId}) async => throw StateError('keychain'),
    );
    expect(res.applied, 1, reason: 'применение обязано уцелеть');
    expect(await db.inboxHasSeen('m1'), isTrue);
    final parked = await db.pendingAckList(limit: 10);
    expect(parked, hasLength(1), reason: 'и уйти в очередь');
    await db.close();
  });

  test('🔴 потолок подтверждений за проход соблюдается', () async {
    // Бюджет прохода 12 секунд, и в поле он уже не всегда выдерживается.
    final db = await AppDb.openForTesting();
    final wires = <BackgroundInboundWire>[
      for (var i = 0; i < BackgroundInboundProcessor.maxAcksPerPass + 5; i++)
        seqWire('m$i', 100 + i),
    ];
    var sent = 0;
    await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: wires,
      decrypt: ({required msgId, required ciphertextB64}) async => true,
      nowMs: 1000,
      ack: ({required seq, required msgId}) async {
        sent++;
        return true;
      },
    );
    expect(sent, BackgroundInboundProcessor.maxAcksPerPass);
    await db.close();
  });

  test('конверт без номера просто не подтверждается', () async {
    // Старый вызов без seq обязан работать как раньше, а не падать.
    final db = await AppDb.openForTesting();
    var sent = 0;
    final res = await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [wire('m1')],
      decrypt: ({required msgId, required ciphertextB64}) async => true,
      nowMs: 1000,
      ack: ({required seq, required msgId}) async {
        sent++;
        return true;
      },
    );
    expect(res.applied, 1);
    expect(sent, 0);
    await db.close();
  });

  // ── Замер обязан уметь провалиться (12.08.2026) ─────────────────────────
  //
  // Прошлая правка была объявлена проверенной по полю на основании «acked=10».
  // Счётчик рос ДО отправки, а HTTP-клиент к тому моменту закрывался сразу
  // после выборки — ни одно подтверждение не уходило. Реле не приняло ни
  // одного, ящик рос с seq 271 до 285, и телефон будили по кругу.

  test('🔴 недошедшее подтверждение НЕ считается дошедшим', () async {
    final db = await AppDb.openForTesting();
    final res = await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [seqWire('m1', 10), seqWire('m2', 11)],
      decrypt: ({required msgId, required ciphertextB64}) async => true,
      nowMs: 1000,
      ack: ({required seq, required msgId}) async => false,
    );
    expect(res.applied, 2);
    expect(res.acked, 0, reason: 'реле ничего не приняло');
    expect(res.ackFailed, 2);
    await db.close();
  });

  test('🔴 упавшее подтверждение — тоже не дошедшее', () async {
    // Ровно случай закрытого клиента: POST бросает мгновенно.
    final db = await AppDb.openForTesting();
    final res = await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [seqWire('m1', 10)],
      decrypt: ({required msgId, required ciphertextB64}) async => true,
      nowMs: 1000,
      ack: ({required seq, required msgId}) async =>
          throw StateError('Client is already closed'),
    );
    expect(res.applied, 1);
    expect(res.acked, 0);
    expect(res.ackFailed, 1);
    // И оно припарковано, чтобы передний план досказал реле.
    expect(await db.pendingAckCount(), 1);
    await db.close();
  });

  test('дошедшее считается дошедшим', () async {
    final db = await AppDb.openForTesting();
    final res = await BackgroundInboundProcessor.applyWires(
      db: db,
      wires: [seqWire('m1', 10), seqWire('m2', 11)],
      decrypt: ({required msgId, required ciphertextB64}) async => true,
      nowMs: 1000,
      ack: ({required seq, required msgId}) async => true,
    );
    expect(res.acked, 2);
    expect(res.ackFailed, 0);
    await db.close();
  });
}
