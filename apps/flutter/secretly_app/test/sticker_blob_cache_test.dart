// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/storage/app_db.dart';

// Кэш выгруженного блоба стикера, схема v66 (08.08.2026, С-11 ТЗ по стикерам).
//
// 🔴 ЗАЧЕМ. Ссылка на шифртекст и ключ к нему создавались в момент ОТПРАВКИ и
// нигде не запоминались: человек платил полное шифрование и выгрузку за стикер,
// который отправлял уже десятый раз. А собрать приглашение в набор из 50 стикеров
// означало 50 выгрузок подряд.
//
// 🔴 ГЛАВНОЕ, ЧТО ЗДЕСЬ ЗАКРЕПЛЕНО — ИНВАЛИДАЦИЯ. У блоба на сервере есть срок,
// и кэш без срока однажды начал бы отдавать МЁРТВУЮ ссылку: собеседник увидел бы
// стикер, который не скачивается, и списал бы это на поломку приложения, а не на
// срок хранения. Кэш без инвалидации хуже отсутствия кэша.

Future<void> seedSticker(AppDb db) async {
  await db.upsertStickerPackSummary(
    packId: 'user:P1:a',
    packVersion: 1,
    title: 'Набор',
    iconStickerId: 's1',
    stickerCount: 1,
    updatedAtMs: 1000,
  );
  await db.upsertStickerPackSticker(
    sticker: (
      packId: 'user:P1:a',
      packVersion: 1,
      stickerId: 's1',
      fileName: 's1.png',
      localPath: '',
      format: 'png',
      animated: false,
      emojiHint: '',
      label: '',
      keywords: const <String>[],
      sha256B64: '',
      sizeBytes: 0,
      downloadedAtMs: null,
      lastAccessedAtMs: null,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const hour = 60 * 60 * 1000;

  test('свежего стикера в кэше нет', () async {
    final db = await AppDb.openForTesting();
    try {
      await seedSticker(db);
      expect(
        await db.stickerCachedBlob(
          packId: 'user:P1:a',
          packVersion: 1,
          stickerId: 's1',
        ),
        isNull,
      );
    } finally {
      await db.close();
    }
  });

  test('блоб запоминается и отдаётся', () async {
    final db = await AppDb.openForTesting();
    try {
      await seedSticker(db);
      final now = DateTime.now().millisecondsSinceEpoch;
      expect(
        await db.stickerRememberBlob(
          packId: 'user:P1:a',
          packVersion: 1,
          stickerId: 's1',
          blobId: 'blob-1',
          fileKeyB64: 'a2V5',
          accessTokenB64: 'dG9rZW4=',
          expiresAtMs: now + 24 * hour,
        ),
        isTrue,
      );
      final cached = await db.stickerCachedBlob(
        packId: 'user:P1:a',
        packVersion: 1,
        stickerId: 's1',
      );
      expect(cached, isNotNull);
      expect(cached!.blobId, 'blob-1');
      expect(cached.fileKeyB64, 'a2V5');
      expect(cached.accessTokenB64, 'dG9rZW4=');
    } finally {
      await db.close();
    }
  });

  test('🔴 просроченный блоб считается ОТСУТСТВУЮЩИМ', () async {
    final db = await AppDb.openForTesting();
    try {
      await seedSticker(db);
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.stickerRememberBlob(
        packId: 'user:P1:a',
        packVersion: 1,
        stickerId: 's1',
        blobId: 'blob-1',
        fileKeyB64: 'a2V5',
        expiresAtMs: now - hour,
      );
      expect(
        await db.stickerCachedBlob(
          packId: 'user:P1:a',
          packVersion: 1,
          stickerId: 's1',
        ),
        isNull,
        reason: 'иначе собеседнику уедет мёртвая ссылка',
      );
    } finally {
      await db.close();
    }
  });

  test('🔴 блоб, истекающий вот-вот, тоже не годится', () async {
    // Запас на дорогу: формально живой блоб к моменту, когда получатель за ним
    // придёт, уже мёртв.
    final db = await AppDb.openForTesting();
    try {
      await seedSticker(db);
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.stickerRememberBlob(
        packId: 'user:P1:a',
        packVersion: 1,
        stickerId: 's1',
        blobId: 'blob-1',
        fileKeyB64: 'a2V5',
        expiresAtMs: now + 60 * 1000, // минута
      );
      expect(
        await db.stickerCachedBlob(
          packId: 'user:P1:a',
          packVersion: 1,
          stickerId: 's1',
        ),
        isNull,
      );
    } finally {
      await db.close();
    }
  });

  test('🔴 запись БЕЗ срока отвергается', () async {
    // Иначе в кэше появилась бы строка, которую нечем инвалидировать, и она
    // жила бы вечно, отдавая мёртвую ссылку.
    final db = await AppDb.openForTesting();
    try {
      await seedSticker(db);
      expect(
        await db.stickerRememberBlob(
          packId: 'user:P1:a',
          packVersion: 1,
          stickerId: 's1',
          blobId: 'blob-1',
          fileKeyB64: 'a2V5',
          expiresAtMs: null,
        ),
        isFalse,
      );
      expect(
        await db.stickerRememberBlob(
          packId: 'user:P1:a',
          packVersion: 1,
          stickerId: 's1',
          blobId: 'blob-1',
          fileKeyB64: 'a2V5',
          expiresAtMs: 0,
        ),
        isFalse,
      );
    } finally {
      await db.close();
    }
  });

  test('🔴 блоб без ключа бесполезен и не отдаётся', () async {
    final db = await AppDb.openForTesting();
    try {
      await seedSticker(db);
      expect(
        await db.stickerRememberBlob(
          packId: 'user:P1:a',
          packVersion: 1,
          stickerId: 's1',
          blobId: 'blob-1',
          fileKeyB64: '   ',
          expiresAtMs: DateTime.now().millisecondsSinceEpoch + 24 * hour,
        ),
        isFalse,
        reason: 'расшифровать такой блоб нечем',
      );
    } finally {
      await db.close();
    }
  });

  test('🔴 запись блоба НЕ затирает остальные поля стикера', () async {
    // Обратная защёлка на класс `ConflictAlgorithm.replace`.
    final db = await AppDb.openForTesting();
    try {
      await seedSticker(db);
      await db.stickerRememberBlob(
        packId: 'user:P1:a',
        packVersion: 1,
        stickerId: 's1',
        blobId: 'blob-1',
        fileKeyB64: 'a2V5',
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + 24 * hour,
      );
      final rows = await db.stickerLocalPathRowsForRebase();
      final row = rows.firstWhere((r) => r['sticker_id'] == 's1');
      expect(row['file_name'], 's1.png');
    } finally {
      await db.close();
    }
  });

  test('несуществующий стикер не заводится записью блоба', () async {
    final db = await AppDb.openForTesting();
    try {
      expect(
        await db.stickerRememberBlob(
          packId: 'user:P1:a',
          packVersion: 1,
          stickerId: 'missing',
          blobId: 'blob-1',
          fileKeyB64: 'a2V5',
          expiresAtMs: DateTime.now().millisecondsSinceEpoch + 24 * hour,
        ),
        isFalse,
      );
    } finally {
      await db.close();
    }
  });
}
