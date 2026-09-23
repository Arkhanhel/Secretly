// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

// Замер, гатящий слой 2 номера безопасности.
//
// 🔴 ЗАЧЕМ ВООБЩЕ ЗАПРОС. Слой 2 отложен 06.08.2026 с условием «неделю считать
// события new_device_seen и identity_rotated_accepted». Условие было
// НЕИЗМЕРИМЫМ: оба живут только в логе устройства, а он кольцевой и чистится.
// Плашка же вставляется в переписку ПОСТОЯННЫМ событием
// `local:safetynum:<пир>:<окно 10 мин>` — история есть, ждать нечего.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now().millisecondsSinceEpoch;
  const week = 7 * 24 * 60 * 60 * 1000;

  Future<void> notice(AppDb db, String peer, int atMs) => db.insertEvent(
        eventId: 'local:safetynum:$peer:${atMs ~/ (10 * 60000)}',
        convoId: peer,
        type: 'sys',
        senderDeviceId: 'me',
        ciphertextB64: 'x',
        createdAtMs: atMs,
        localState: 'received',
      );

  test('считает плашки за окно и различает контакты', () async {
    final db = await AppDb.openForTesting();
    await notice(db, 'peerA', now - 1000);
    await notice(db, 'peerA', now - 2 * 60 * 60 * 1000);
    await notice(db, 'peerB', now - 3 * 60 * 60 * 1000);
    final s = await db.safetyNumberNoticeStats(windowMs: week, nowMs: now);
    expect(s.total, 3);
    expect(s.peers, 2, reason: 'два разных контакта');
    await db.close();
  });

  test('🔴 старше окна не считается — иначе порог решения соврёт', () async {
    // Порог из ТЗ: единицы за НЕДЕЛЮ — откладывать; десятки — делать. Если в
    // окно затечёт история за месяцы, «десятки» появятся сами собой и мы
    // построим крипто-слой по выдуманному поводу.
    final db = await AppDb.openForTesting();
    await notice(db, 'peerA', now - 1000);
    await notice(db, 'peerA', now - 40 * 24 * 60 * 60 * 1000);
    final s = await db.safetyNumberNoticeStats(windowMs: week, nowMs: now);
    expect(s.total, 1);
    await db.close();
  });

  test('обычные события в счёт не идут', () async {
    final db = await AppDb.openForTesting();
    await db.insertEvent(
      eventId: 'ordinary-1',
      convoId: 'peerA',
      type: 'msg',
      senderDeviceId: 'me',
      ciphertextB64: 'x',
      createdAtMs: now - 1000,
      localState: 'sent',
    );
    final s = await db.safetyNumberNoticeStats(windowMs: week, nowMs: now);
    expect(s.total, 0);
    expect(s.peers, 0);
    await db.close();
  });

  test('пусто — ноль, а не исключение', () async {
    final db = await AppDb.openForTesting();
    final s = await db.safetyNumberNoticeStats(windowMs: week, nowMs: now);
    expect(s.total, 0);
    await db.close();
  });
}
