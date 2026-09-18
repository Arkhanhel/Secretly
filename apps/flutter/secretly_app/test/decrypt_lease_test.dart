// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/push/background_inbox_fetcher.dart';
import 'package:secretly_app/storage/app_db.dart';

// TZ_BG_DECRYPT_2026-07-23 Б-1: the cross-isolate barrier that keeps exactly
// one writer in the ratchet. If two holders could ever hold it at once, the
// background decrypt path would corrupt sessions — the very failure the whole
// epic exists to avoid. These tests pin that it cannot.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const foreground = 'main';
  const background = 'bg';
  const ttl = 10 * 60 * 1000; // 10 minutes

  test('a fresh lease excludes every other holder', () async {
    final db = await AppDb.openForTesting();
    const now = 1000000;

    expect(await db.acquireDecryptLease(holder: foreground, nowMs: now, ttlMs: ttl), isTrue);
    // The background isolate cannot take it while the foreground lease is fresh.
    expect(await db.acquireDecryptLease(holder: background, nowMs: now + 1000, ttlMs: ttl), isFalse);
    expect(await db.decryptLeaseHolder(now + 1000), foreground);
    await db.close();
  });

  test('the same holder may renew its own lease', () async {
    final db = await AppDb.openForTesting();
    const now = 1000000;
    expect(await db.acquireDecryptLease(holder: foreground, nowMs: now, ttlMs: ttl), isTrue);
    expect(await db.acquireDecryptLease(holder: foreground, nowMs: now + 5000, ttlMs: ttl), isTrue);
    await db.close();
  });

  test('an expired lease may be taken by another holder', () async {
    final db = await AppDb.openForTesting();
    const now = 1000000;
    expect(await db.acquireDecryptLease(holder: foreground, nowMs: now, ttlMs: ttl), isTrue);
    // Past the TTL, the foreground lease is dead and the background may claim it.
    final afterExpiry = now + ttl + 1;
    expect(await db.decryptLeaseHolder(afterExpiry), isNull, reason: 'expired reads as free');
    expect(await db.acquireDecryptLease(holder: background, nowMs: afterExpiry, ttlMs: ttl), isTrue);
    expect(await db.decryptLeaseHolder(afterExpiry), background);
    await db.close();
  });

  test('release frees the lease for the next holder', () async {
    final db = await AppDb.openForTesting();
    const now = 1000000;
    expect(await db.acquireDecryptLease(holder: foreground, nowMs: now, ttlMs: ttl), isTrue);
    await db.releaseDecryptLease(foreground);
    expect(await db.decryptLeaseHolder(now + 1), isNull);
    expect(await db.acquireDecryptLease(holder: background, nowMs: now + 1, ttlMs: ttl), isTrue);
    await db.close();
  });

  test('a stale holder cannot release the new owner\'s lease', () async {
    final db = await AppDb.openForTesting();
    const now = 1000000;
    // foreground takes it, lets it expire, background takes over.
    expect(await db.acquireDecryptLease(holder: foreground, nowMs: now, ttlMs: ttl), isTrue);
    final afterExpiry = now + ttl + 1;
    expect(await db.acquireDecryptLease(holder: background, nowMs: afterExpiry, ttlMs: ttl), isTrue);
    // The late foreground release must NOT free the background's fresh lease.
    await db.releaseDecryptLease(foreground);
    expect(await db.decryptLeaseHolder(afterExpiry + 1), background,
        reason: 'a stale releaser must not steal the lease away');
    await db.close();
  });

  test('a malformed holder is rejected, never stored', () async {
    final db = await AppDb.openForTesting();
    const now = 1000000;
    expect(await db.acquireDecryptLease(holder: 'has|pipe', nowMs: now, ttlMs: ttl), isFalse);
    expect(await db.acquireDecryptLease(holder: '', nowMs: now, ttlMs: ttl), isFalse);
    expect(await db.decryptLeaseHolder(now), isNull);
    await db.close();
  });

  // ── Мёртвая зона между двумя задвижками (11.08.2026) ──────────────────────
  //
  // Задвижек ДВЕ: аренда на расшифровку и отметка «главный изолят жив»
  // (mainIsolateFreshMs, 25 с). Когда система замораживает главный изолят,
  // вторая открывается через 25 секунд — а аренда держала до ДВУХ МИНУТ.
  // Получалось 95 секунд, в которые фоновый проход уже имел право работать, но
  // не мог: сообщения складывались и не применялись, а значит не подтверждались,
  // и реле слало заново, давая новый баннер за баннером.

  test('🔴 окно аренды соизмеримо с окном живости, а не втрое длиннее', () {
    // Ровно тот дефект: 120 с против 25 с.
    const leaseTtlMs = 30 * 1000;
    const aliveFreshMs = BackgroundInboxFetcher.mainIsolateFreshMs;

    expect(
      leaseTtlMs,
      lessThanOrEqualTo(aliveFreshMs * 2),
      reason: 'аренда не должна переживать решение «главного нет» вдвое',
    );
  });

  test('🔴 запас против пропущенного удара пульса сохранён', () {
    // Пульс бьётся раз в 10 секунд. Срок короче трёх ударов означал бы, что одна
    // задержка сборщика мусора отдаёт аренду фону, пока главный жив и работает.
    const leaseTtlMs = 30 * 1000;
    const heartbeatMs = 10 * 1000;
    expect(leaseTtlMs ~/ heartbeatMs, greaterThanOrEqualTo(3));
  });

  test('🔴 уступивший держатель отпускает аренду, а не ждёт протухания', () async {
    // Пульс с выключенным фоновым соединением честно перестаёт штамповать «жив»,
    // но раньше продолжал ДЕРЖАТЬ аренду до истечения срока — уступал одной
    // рукой и не отпускал другой.
    final db = await AppDb.openForTesting();
    const ttl = 30 * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;

    expect(
      await db.acquireDecryptLease(holder: 'main', nowMs: now, ttlMs: ttl),
      isTrue,
    );
    // Фон не может — аренда занята.
    expect(
      await db.acquireDecryptLease(holder: 'bg', nowMs: now + 1, ttlMs: ttl),
      isFalse,
    );

    // Главный уступает окно.
    await db.releaseDecryptLease('main');

    // Фон получает право СРАЗУ, а не через 30 секунд.
    expect(
      await db.acquireDecryptLease(holder: 'bg', nowMs: now + 2, ttlMs: ttl),
      isTrue,
    );
    await db.close();
  });
}
