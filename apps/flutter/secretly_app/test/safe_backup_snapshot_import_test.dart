// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/storage/safe_backup_snapshot_contract.dart';

void main() {
  _excludedColumnsContract();
  _stickerSnapshotContract();
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Safe backup snapshot import', () {
    test('fails closed on unknown table without partial import', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.contactUpsert(profileId: 'peer-old', displayName: 'Old Peer');

        await expectLater(
          db.importTables(
            <String, List<Map<String, Object?>>>{
              'contacts': <Map<String, Object?>>[
                <String, Object?>{
                  'contact_profile_id': 'peer-new',
                  'display_name': 'New Peer',
                  'created_at_ms': 1,
                  'updated_at_ms': 1,
                },
              ],
              'messages': <Map<String, Object?>>[
                <String, Object?>{'id': 1},
              ],
            },
            allowedColumnsByTable: kSafeBackupSnapshotColumnsByTable,
          ),
          throwsStateError,
        );

        final contacts = await db.contactsList();
        expect(contacts, hasLength(1));
        expect(contacts.single['contact_profile_id'], 'peer-old');
      } finally {
        await db.close();
      }
    });

    test('fails closed on unknown column without partial import', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.contactUpsert(profileId: 'peer-old', displayName: 'Old Peer');

        await expectLater(
          db.importTables(
            <String, List<Map<String, Object?>>>{
              'contacts': <Map<String, Object?>>[
                <String, Object?>{
                  'contact_profile_id': 'peer-new',
                  'display_name': 'New Peer',
                  'created_at_ms': 1,
                  'updated_at_ms': 1,
                  'broken': 'x',
                },
              ],
            },
            allowedColumnsByTable: kSafeBackupSnapshotColumnsByTable,
          ),
          throwsStateError,
        );

        final contacts = await db.contactsList();
        expect(contacts, hasLength(1));
        expect(contacts.single['contact_profile_id'], 'peer-old');
      } finally {
        await db.close();
      }
    });

    // Regression: the snapshot allowlist drifted behind the DB schema after the
    // premium/monetization work added cosmetic columns. On production the DB
    // self-heal (_ensureProfileMetaColumns / _ensureGroupSettingsCosmeticColumns,
    // run on every open) guarantees these columns exist, and exportTables does
    // SELECT *, so any populated row tripped _validateSnapshotRow with
    // "Unsupported snapshot column ..." — making EVERY backup save (local file,
    // server upload, auto-backup) throw. The allowlist must list every column
    // the live schema can hold for these tables, or both the export (SAVE) and
    // import/validate (RESTORE) paths reject the row.
    test('snapshot contract lists premium/cosmetic columns', () {
      final profileMeta = kSafeBackupSnapshotColumnsByTable['profile_meta'];
      expect(profileMeta, isNotNull);
      expect(
        profileMeta,
        containsAll(<String>[
          'frame_id',
          'cover_id',
          'cover_path',
          'emoji_status',
          'premium_badge',
          'last_seen_at_ms',
        ]),
      );

      final groupSettings = kSafeBackupSnapshotColumnsByTable['group_settings'];
      expect(groupSettings, isNotNull);
      expect(
        groupSettings,
        containsAll(<String>['cover_id', 'frame_id', 'name_emoji']),
      );

      final conversations = kSafeBackupSnapshotColumnsByTable['conversations'];
      expect(conversations, isNotNull);
      expect(
        conversations,
        containsAll(<String>['muted_until_ms', 'muted_mentions_only']),
      );
    });

    test(
      'import accepts a conversations row carrying the new muted columns',
      () async {
        final db = await AppDb.openForTesting();
        try {
          await db.importTables(
            <String, List<Map<String, Object?>>>{
              'conversations': <Map<String, Object?>>[
                <String, Object?>{
                  'convo_id': 'convo-1',
                  'kind': 'direct',
                  'peer_profile_id': 'peer-1',
                  'muted': 1,
                  'muted_until_ms': 999,
                  'muted_mentions_only': 1,
                  'last_event_at_ms': 1,
                  'created_at_ms': 1,
                  'updated_at_ms': 1,
                },
              ],
            },
            allowedColumnsByTable: kSafeBackupSnapshotColumnsByTable,
          );

          final convo = await db.convoGet('convo-1');
          expect(convo?['muted_until_ms'], 999);
          expect(convo?['muted_mentions_only'], 1);
        } finally {
          await db.close();
        }
      },
    );
  });
}
// 🔴 Стикеры в копии (08.08.2026, поле: «после восстановления папка стикеров
// пустая»).
//
// Своих наборов не было НИ в таблицах снимка, НИ в файлах копии — а сервер их
// не хранит вовсе (каталог односторонний, выгрузки нет). То есть копия теряла
// их безвозвратно, и восстановить набор было нечем: картинки рисовал человек.
void _stickerSnapshotContract() {
  group('стикеры едут в копии', () {
    test('🔴 обе таблицы в списке снимка', () {
      expect(kSafeBackupSnapshotTables, contains('sticker_packs'));
      expect(kSafeBackupSnapshotTables, contains('sticker_pack_stickers'));
    });

    test('🔴 local_path переносится — иначе нечего перепривязывать', () {
      // Путь абсолютный и на новом устройстве недействителен, но выбросить его
      // нельзя: перепривязка ищет файл по имени и переписывает ЭТОТ столбец.
      // Без него наборы легли бы пустыми.
      final columns =
          kSafeBackupSnapshotColumnsByTable['sticker_pack_stickers']!;
      expect(columns, contains('local_path'));
      expect(columns, contains('file_name'));
      expect(columns, contains('sticker_id'));
    });

    test('набор описан достаточно, чтобы отрисоваться', () {
      final packs = kSafeBackupSnapshotColumnsByTable['sticker_packs']!;
      expect(packs, containsAll(<String>['pack_id', 'pack_version', 'title']));
      expect(packs, contains('icon_sticker_id'));
      expect(packs, contains('installed'));
    });

    test('каждая таблица снимка имеет список столбцов', () {
      // Обратная защёлка: таблица без списка столбцов проедет мимо фильтра, и в
      // копию попадёт то, чего мы не собирались отдавать.
      for (final table in kSafeBackupSnapshotTables) {
        expect(
          kSafeBackupSnapshotColumnsByTable.containsKey(table),
          isTrue,
          reason: table,
        );
      }
    });
  });
}

// 🔴 Регрессия 09.08.2026: копия перестала СОЗДАВАТЬСЯ.
//
// Экспорт делает `SELECT *` и падает на столбце, которого нет в контракте — это
// правильная защита, она заставляет решить про каждый новый столбец. Но у решения
// «не переносить» не было способа выразиться: столбец, про который решили «не
// надо», выглядел точно как забытый и валил создание копии ЦЕЛИКОМ.
//
// Так и сломалось после добавления кэша блоба стикеров (схема v66): столбцы
// добавили, в контракт осознанно не внесли — и человек не смог сделать копию.
void _excludedColumnsContract() {
  group('осознанно исключённые столбцы', () {
    test('🔴 кэш блоба стикера НЕ едет в копию', () {
      // Это состояние сервера со сроком жизни и токеном доступа: перенос на
      // другую установку дал бы указатели на, возможно, истёкшие объекты.
      final excluded =
          kSafeBackupSnapshotExcludedColumnsByTable['sticker_pack_stickers']!;
      expect(
        excluded,
        containsAll(<String>[
          'blob_id',
          'blob_file_key_b64',
          'blob_access_token_b64',
          'blob_expires_at_ms',
        ]),
      );
    });

    test('🔴 исключённое и разрешённое НЕ пересекаются', () {
      // Столбец в обоих списках означал бы, что мы сами не знаем, едет он или
      // нет, — и поведение зависело бы от порядка проверок.
      for (final entry in kSafeBackupSnapshotExcludedColumnsByTable.entries) {
        final allowed = kSafeBackupSnapshotColumnsByTable[entry.key];
        if (allowed == null) continue;
        expect(
          allowed.intersection(entry.value),
          isEmpty,
          reason: entry.key,
        );
      }
    });

    test('исключения объявлены только для таблиц снимка', () {
      // Исключение для таблицы, которой нет в снимке, — мёртвая запись: она
      // никогда не применится и будет вводить в заблуждение.
      for (final table in kSafeBackupSnapshotExcludedColumnsByTable.keys) {
        expect(kSafeBackupSnapshotTables, contains(table), reason: table);
      }
    });
  });
}
