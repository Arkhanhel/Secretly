// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/stickers/sticker_share_mode.dart';
import 'package:secretly_app/storage/app_db.dart';

// Ш-1 ТЗ по стикерам (08.08.2026): режим доступа к своему набору.
//
// 🔴 ГЛАВНОЕ СВОЙСТВО ЭТОГО ШАГА — он НИЧЕГО НЕ МЕНЯЕТ. Разбор показал, что
// «доступ только тем, кому отправляю» уже работает: свои наборы ездят
// зашифрованными блобами, сервер хранит лишь шифртекст. Значит задача была не
// построить режим, а дать ему имя — и сделать это так, чтобы обновление не
// переключило ни один существующий набор.

Future<void> seedPack(AppDb db, String packId) async {
  await db.upsertStickerPackSummary(
    packId: packId,
    packVersion: 1,
    title: 'Мои стикеры',
    iconStickerId: 's1',
    stickerCount: 3,
    updatedAtMs: 1000,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('разбор значения', () {
    test('каждое известное значение переживает круг', () {
      for (final mode in StickerShareMode.values) {
        expect(StickerShareMode.fromStorage(mode.storageValue), mode);
      }
    });

    test('🔴 неизвестное значение = режим по умолчанию, а НЕ исключение', () {
      // Столбец могла записать более новая сборка, а откат вернуть старый код к
      // новым данным. Падение здесь означало бы набор, который перестал
      // открываться, — потерю вместо непонимания.
      for (final raw in <Object?>[null, '', '   ', 'что-то новое', 42, <int>[]]) {
        expect(
          StickerShareMode.fromStorage(raw),
          StickerShareMode.sentOnly,
          reason: '$raw',
        );
      }
    });

    test('значение по умолчанию — «отправленным», нынешнее поведение', () {
      // 🔴 Не `personal`. Любое другое значение молча поменяло бы поведение
      // существующих наборов при обновлении.
      expect(StickerShareMode.fallback, StickerShareMode.sentOnly);
    });
  });

  group('свойства режимов', () {
    test('только публикация отдаёт содержимое серверу', () {
      expect(StickerShareMode.personal.exposesContentToServer, isFalse);
      expect(StickerShareMode.sentOnly.exposesContentToServer, isFalse);
      expect(StickerShareMode.published.exposesContentToServer, isTrue);
    });

    test('личный набор не уезжает к собеседникам', () {
      expect(StickerShareMode.personal.allowsSendingToPeers, isFalse);
      expect(StickerShareMode.sentOnly.allowsSendingToPeers, isTrue);
    });

    test('🔴 публикация помечена НЕреализованной', () {
      // Значение существует в перечислении только затем, чтобы старые данные и
      // будущие сборки не роняли чтение. Обещать его человеку нельзя: на сервере
      // нет ни приёма загрузки, ни лимитов, ни модерации.
      expect(StickerShareMode.published.isSupported, isFalse);
      expect(StickerShareMode.personal.isSupported, isTrue);
      expect(StickerShareMode.sentOnly.isSupported, isTrue);
    });
  });

  group('база', () {
    test('новый набор получает режим по умолчанию', () async {
      final db = await AppDb.openForTesting();
      try {
        await seedPack(db, 'user:p1:a');
        expect(
          await db.stickerPackShareMode(packId: 'user:p1:a', packVersion: 1),
          StickerShareMode.sentOnly,
        );
      } finally {
        await db.close();
      }
    });

    test('режим записывается и читается', () async {
      final db = await AppDb.openForTesting();
      try {
        await seedPack(db, 'user:p1:a');
        expect(
          await db.stickerPackSetShareMode(
            packId: 'user:p1:a',
            packVersion: 1,
            mode: StickerShareMode.personal,
          ),
          isTrue,
        );
        expect(
          await db.stickerPackShareMode(packId: 'user:p1:a', packVersion: 1),
          StickerShareMode.personal,
        );
      } finally {
        await db.close();
      }
    });

    test('🔴 нереализованный режим записать НЕЛЬЗЯ', () async {
      // Иначе интерфейс мог бы пообещать публикацию, которой нет — и человек
      // считал бы набор выложенным, хотя его никто не видит.
      final db = await AppDb.openForTesting();
      try {
        await seedPack(db, 'user:p1:a');
        expect(
          await db.stickerPackSetShareMode(
            packId: 'user:p1:a',
            packVersion: 1,
            mode: StickerShareMode.published,
          ),
          isFalse,
        );
        expect(
          await db.stickerPackShareMode(packId: 'user:p1:a', packVersion: 1),
          StickerShareMode.sentOnly,
          reason: 'режим обязан остаться прежним',
        );
      } finally {
        await db.close();
      }
    });

    test('🔴 запись режима НЕ затирает остальные поля набора', () async {
      // Обратная защёлка на класс `ConflictAlgorithm.replace`: запись «полным»
      // upsert-ом снесла бы всё, чего не оказалось в вызове.
      final db = await AppDb.openForTesting();
      try {
        await seedPack(db, 'user:p1:a');
        await db.stickerPackSetShareMode(
          packId: 'user:p1:a',
          packVersion: 1,
          mode: StickerShareMode.personal,
        );
        final packs = await db.listStickerCatalogPacks();
        final pack = packs.firstWhere((p) => p.packId == 'user:p1:a');
        expect(pack.title, 'Мои стикеры');
        expect(pack.stickerCount, 3);
        expect(pack.iconStickerId, 's1');
        expect(pack.shareMode, StickerShareMode.personal);
      } finally {
        await db.close();
      }
    });

    test('несуществующий набор не заводится записью режима', () async {
      final db = await AppDb.openForTesting();
      try {
        expect(
          await db.stickerPackSetShareMode(
            packId: 'user:p1:missing',
            packVersion: 1,
            mode: StickerShareMode.personal,
          ),
          isFalse,
        );
      } finally {
        await db.close();
      }
    });
  });
}
