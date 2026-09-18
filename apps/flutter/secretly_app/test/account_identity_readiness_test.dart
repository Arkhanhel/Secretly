// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

// Гейт Ш-3 ТЗ номера безопасности: доля контактов, чья сборка умеет слой 2.
//
// 🔴 ЗАЧЕМ ЗАПРОС, А НЕ СЧЁТЧИК СОБЫТИЙ. Ш-3 (сертификат отменяет «номер
// изменился») нельзя включать, не зная доли. Измерять её событиями журнала
// нельзя — он кольцевой. 12.08.2026 это был ТРЕТИЙ неизмеримый гейт за день:
// сначала «неделю считать события» для этого же ТЗ, потом доля сборок (0 из
// 2001), потом вот этот. Закрепление же уже лежит на диске — считать не надо.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('доля считается от числа контактов', () async {
    final db = await AppDb.openForTesting();
    for (final pid in ['a', 'b', 'c', 'd']) {
      await db.contactUpsert(profileId: pid, displayName: pid);
    }
    await db.contactAccountIdentityPinIfAbsent(
      profileId: 'a',
      accountIdentityPubB64: 'AAA',
    );
    await db.contactAccountIdentityPinIfAbsent(
      profileId: 'b',
      accountIdentityPubB64: 'BBB',
    );
    final r = await db.accountIdentityReadinessStats();
    expect(r.contacts, 4);
    expect(r.pinned, 2);
    await db.close();
  });

  test('🔴 пустое закрепление за готовность не считается', () async {
    // Иначе доля вырастет сама собой и Ш-3 включат по выдуманной цифре.
    final db = await AppDb.openForTesting();
    await db.contactUpsert(profileId: 'a', displayName: 'a');
    final r = await db.accountIdentityReadinessStats();
    expect(r.contacts, 1);
    expect(r.pinned, 0);
    await db.close();
  });

  test('счётчики наблюдения переживают перечитывание', () async {
    final db = await AppDb.openForTesting();
    await db.localKvCounterInc(AppDb.kvAcctCertOk);
    await db.localKvCounterInc(AppDb.kvAcctCertOk);
    await db.localKvCounterInc(AppDb.kvAcctCertBad);
    expect(await db.localKvCounterGet(AppDb.kvAcctCertOk), 2);
    expect(await db.localKvCounterGet(AppDb.kvAcctCertBad), 1);
    expect(await db.localKvCounterGet(AppDb.kvAcctKeyChanged), 0);
    await db.close();
  });
}
