// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secretly_app/storage/app_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// 🔴 THE MIGRATION CHAIN — until now, entirely untested.
///
/// Found during the Э-4 audit (2026-08-02): the upgrade chain was a local
/// closure inside `AppDb.open`, unreachable from any test, and `openForTesting`
/// never ran it (its `onUpgrade` calls `_createSchema`, which is a no-op on a
/// table that already exists). Fifty-nine migration branches had therefore
/// never been executed by a test even once.
///
/// That is the least recoverable failure this codebase can have: a user whose
/// database refuses to open loses their history, and no server-side switch can
/// undo it. Two of this project's worst incidents were database-key and
/// database-open failures.
///
/// These tests run the REAL chain against databases standing in for older
/// installs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ffi.Database> rawDb(String path) {
    ffi.sqfliteFfiInit();
    return ffi.databaseFactoryFfi.openDatabase(path);
  }

  Future<Set<String>> columns(ffi.Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table);');
    return rows.map((r) => (r['name'] as String?) ?? '').toSet();
  }

  /// 🔴 The case a real upgrade actually is: a database that already HOLDS the
  /// user's data. A migration must add to it, never trip over it.
  test('🔴 the real chain upgrades a populated v60 database', () async {
    final dir = await Directory.systemTemp.createTemp('mig_v60');
    final path = p.join(dir.path, 'old.db');
    try {
      final db = await rawDb(path);
      await db.execute('''
CREATE TABLE sessions_v3 (
  peer_device_id TEXT PRIMARY KEY,
  root_key_b64 TEXT NOT NULL,
  dh_self_seed_b64 TEXT NOT NULL,
  dh_self_pub_b64 TEXT NOT NULL,
  dh_remote_pub_b64 TEXT,
  send_chain_key_b64 TEXT,
  recv_chain_key_b64 TEXT,
  ns INTEGER NOT NULL,
  nr INTEGER NOT NULL,
  pn INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  initiator_pending_at_ms INTEGER NOT NULL DEFAULT 0,
  epoch INTEGER NOT NULL DEFAULT 0
);
''');
      await db.execute('''
CREATE TABLE sessions_v3_archive (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  peer_device_id TEXT NOT NULL,
  root_key_b64 TEXT NOT NULL,
  dh_self_seed_b64 TEXT NOT NULL,
  dh_self_pub_b64 TEXT NOT NULL,
  dh_remote_pub_b64 TEXT,
  send_chain_key_b64 TEXT,
  recv_chain_key_b64 TEXT,
  ns INTEGER NOT NULL,
  nr INTEGER NOT NULL,
  pn INTEGER NOT NULL,
  archived_at_ms INTEGER NOT NULL
);
''');
      // v62 (модель Signal для смены номера безопасности) добавляет столбец
      // сюда, поэтому таблица должна быть в фикстуре в её ДОмиграционном виде:
      // иначе ветка молча обходится стороной и остаётся непроверенной.
      await db.execute('''
CREATE TABLE contact_devices (
  contact_profile_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  identity_key_pub_b64 TEXT NOT NULL,
  signed_prekey_pub_b64 TEXT NOT NULL,
  signed_prekey_sig_b64 TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  verified_at_ms INTEGER,
  PRIMARY KEY(contact_profile_id, device_id)
);
''');
      await db.insert('contact_devices', {
        'contact_profile_id': 'peer-profile',
        'device_id': 'peer-A',
        'identity_key_pub_b64': 'SUQ=',
        'signed_prekey_pub_b64': 'U1BL',
        'signed_prekey_sig_b64': 'U0lH',
        'updated_at_ms': 1000,
        'verified_at_ms': 500,
      });

      await db.insert('sessions_v3', {
        'peer_device_id': 'peer-A',
        'root_key_b64': 'Uk9PVA==',
        'dh_self_seed_b64': 'U0VFRA==',
        'dh_self_pub_b64': 'UFVC',
        'dh_remote_pub_b64': 'UkVN',
        'send_chain_key_b64': 'U0NL',
        'recv_chain_key_b64': 'UkNL',
        'ns': 7,
        'nr': 9,
        'pn': 2,
        'updated_at_ms': 1000,
        'created_at_ms': 900,
        'initiator_pending_at_ms': 0,
        'epoch': 77,
      });

      // The REAL chain, exactly as production runs it on upgrade.
      await AppDb.runMigrationsForTest(db, 60, 61);

      expect(await columns(db, 'sessions_v3'),
          containsAll(['handshake_base_pub_b64', 'pending_prekey_header_json']));
      expect(await columns(db, 'sessions_v3_archive'),
          contains('handshake_base_pub_b64'));

      // 🔴 The user's data must survive untouched, and the new columns must
      // read NULL — which every existing code path already handles.
      final row = (await db.query('sessions_v3')).single;
      expect(row['ns'], 7);
      expect(row['nr'], 9);
      expect(row['epoch'], 77);
      expect(row['handshake_base_pub_b64'], isNull);
      expect(row['pending_prekey_header_json'], isNull);

      // v62: столбец добавлен, таблица заведена, а уже проверенное устройство
      // осталось проверенным — миграция ничего не переспрашивает у людей.
      expect(await columns(db, 'contact_devices'), contains('approved_at_ms'));
      final devices = (await db.query('contact_devices')).single;
      expect(devices['verified_at_ms'], 500);
      expect(devices['approved_at_ms'], isNull);
      final verificationTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='contact_verification'",
      );
      expect(verificationTable, isNotEmpty);

      // v64: столбцы под закреплённый ключ личности аккаунта контакта. Проверять
      // обязательно ЗДЕСЬ, в прогоне настоящей цепочки: у таблицы ТРИ пути
      // создания (миграция v62, базовая схема, лечение), и правка одного из них
      // оставила бы часть установок без столбца — шрам Wave-2.
      expect(
        await columns(db, 'contact_verification'),
        containsAll(<String>[
          'account_identity_pub_b64',
          'account_identity_pinned_at_ms',
        ]),
      );

      await db.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });

  /// 🔴 An interrupted upgrade re-runs from the SAME old version on the next
  /// launch. Every branch must therefore be safe to execute twice — an
  /// `ALTER TABLE ADD COLUMN` that runs again throws "duplicate column".
  test('🔴 re-running the chain is safe (an interrupted upgrade retries)',
      () async {
    final dir = await Directory.systemTemp.createTemp('mig_twice');
    final path = p.join(dir.path, 'twice.db');
    try {
      final db = await rawDb(path);
      await db.execute('''
CREATE TABLE sessions_v3 (
  peer_device_id TEXT PRIMARY KEY,
  root_key_b64 TEXT NOT NULL,
  dh_self_seed_b64 TEXT NOT NULL,
  dh_self_pub_b64 TEXT NOT NULL,
  dh_remote_pub_b64 TEXT,
  send_chain_key_b64 TEXT,
  recv_chain_key_b64 TEXT,
  ns INTEGER NOT NULL,
  nr INTEGER NOT NULL,
  pn INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  initiator_pending_at_ms INTEGER NOT NULL DEFAULT 0,
  epoch INTEGER NOT NULL DEFAULT 0
);
''');
      await db.execute('''
CREATE TABLE sessions_v3_archive (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  peer_device_id TEXT NOT NULL,
  root_key_b64 TEXT NOT NULL,
  dh_self_seed_b64 TEXT NOT NULL,
  dh_self_pub_b64 TEXT NOT NULL,
  dh_remote_pub_b64 TEXT,
  send_chain_key_b64 TEXT,
  recv_chain_key_b64 TEXT,
  ns INTEGER NOT NULL,
  nr INTEGER NOT NULL,
  pn INTEGER NOT NULL,
  archived_at_ms INTEGER NOT NULL
);
''');
      await db.execute('''
CREATE TABLE contact_devices (
  contact_profile_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  identity_key_pub_b64 TEXT NOT NULL,
  signed_prekey_pub_b64 TEXT NOT NULL,
  signed_prekey_sig_b64 TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  verified_at_ms INTEGER,
  PRIMARY KEY(contact_profile_id, device_id)
);
''');
      await AppDb.runMigrationsForTest(db, 60, 61);
      // Same starting version again — the crash-then-relaunch case.
      await AppDb.runMigrationsForTest(db, 60, 61);
      expect(await columns(db, 'sessions_v3'),
          contains('handshake_base_pub_b64'));
      // v62: повторный ALTER выбросил бы «duplicate column», а повторный
      // CREATE TABLE без IF NOT EXISTS — «table already exists».
      expect(await columns(db, 'contact_devices'), contains('approved_at_ms'));
      await db.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });

  // 🔴 NOT TESTED HERE, and the reason is worth recording.
  //
  // The Э-4 columns are also healed on every open, and that healer now swallows
  // its own errors: `_ensureColumnExists` is idempotent for a missing COLUMN but
  // NOT for a missing TABLE (PRAGMA returns nothing, so it runs the ALTER and
  // throws), and an every-open healer that throws would turn a merely degraded
  // database into one that cannot be opened at all.
  //
  // Reaching that state through a test means opening a database missing a
  // table, which runs `_createSchema` first — and THAT trips over a
  // pre-existing fragility of its own: `CREATE INDEX IF NOT EXISTS` on a table
  // that does not exist (`sticker_packs`) throws. The same class the schema
  // already documents for `deliver_at_ms`. Fixing the ordering of the base
  // schema is a real change well outside Э-4, so the defensive catch stays and
  // this case is left honestly untested rather than covered by a test that
  // proves something else.

  test('a current database is left alone', () async {
    // Opening an already-current install must not run anything.
    final dir = await Directory.systemTemp.createTemp('mig_noop');
    final path = p.join(dir.path, 'current.db');
    try {
      final db = await rawDb(path);
      await db.execute('CREATE TABLE marker (x INTEGER);');
      // Число обязано ехать вместе с _schemaVersion: пока здесь стоит прошлая
      // версия, тест утверждает не «текущую базу не трогают», а «базу на одну
      // версию старее прогоняют через последнюю миграцию».
      await AppDb.runMigrationsForTest(db, 66, 66);
      final found = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='marker'",
      );
      expect(found, isNotEmpty);
      await db.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });

  // 🔴 ПУТЬ ЛЮДЕЙ С ВЫПУЩЕННОЙ 456 (09.08.2026).
  //
  // У них схема 63 и таблицы стикеров УЖЕ ЕСТЬ — стикеры существовали задолго до
  // 456. Ветки 65 и 66 в этом случае идут не по «таблицы нет», а по ALTER живой
  // таблицы с данными, и именно этот путь не был закрыт ни одним тестом:
  // соседний тест строит базу БЕЗ таблиц стикеров, и обе ветки уходили в
  // холостую сторону.
  //
  // Цена ошибки здесь наибольшая из возможных: база, которая не открылась, — это
  // потерянная история, и никакой серверный переключатель её не вернёт.
  test('🔴 база с ТАБЛИЦАМИ СТИКЕРОВ обновляется с 63 и данные выживают',
      () async {
    final dir = await Directory.systemTemp.createTemp('mig_v63_stickers');
    final path = p.join(dir.path, 'old.db');
    try {
      final db = await rawDb(path);
      // Схема стикеров ровно та, что была в выпущенной 456.
      await db.execute('''
CREATE TABLE sticker_packs (
  pack_id TEXT NOT NULL,
  pack_version INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  icon_sticker_id TEXT NOT NULL,
  icon_emoji_hint TEXT NOT NULL DEFAULT '',
  featured_rank INTEGER,
  tags_json TEXT NOT NULL DEFAULT '[]',
  installed INTEGER NOT NULL DEFAULT 0,
  sticker_count INTEGER NOT NULL DEFAULT 0,
  updated_at_ms INTEGER NOT NULL,
  installed_at_ms INTEGER,
  PRIMARY KEY(pack_id, pack_version)
);
''');
      await db.execute('''
CREATE TABLE sticker_pack_stickers (
  pack_id TEXT NOT NULL,
  pack_version INTEGER NOT NULL,
  sticker_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  local_path TEXT NOT NULL DEFAULT '',
  format TEXT NOT NULL,
  animated INTEGER NOT NULL DEFAULT 0,
  emoji_hint TEXT NOT NULL DEFAULT '',
  label TEXT NOT NULL DEFAULT '',
  keywords_json TEXT NOT NULL DEFAULT '[]',
  sha256_b64 TEXT NOT NULL DEFAULT '',
  size_bytes INTEGER NOT NULL DEFAULT 0,
  downloaded_at_ms INTEGER,
  last_accessed_at_ms INTEGER,
  PRIMARY KEY(pack_id, pack_version, sticker_id)
);
''');
      // Эта таблица у людей на 456 тоже есть — иначе ветка v64 ушла бы в
      // холостую сторону и тест проверял бы не тот путь.
      await db.execute(
        'CREATE TABLE contact_verification (contact_profile_id TEXT PRIMARY '
        'KEY, verified_ever_at_ms INTEGER NOT NULL);',
      );
      await db.insert('contact_verification', <String, Object?>{
        'contact_profile_id': 'peer-1',
        'verified_ever_at_ms': 900,
      });

      await db.insert('sticker_packs', <String, Object?>{
        'pack_id': 'user:P1:abc',
        'pack_version': 2,
        'title': 'Мои стикеры',
        'icon_sticker_id': 's0',
        'installed': 1,
        'sticker_count': 1,
        'updated_at_ms': 1700,
      });
      await db.insert('sticker_pack_stickers', <String, Object?>{
        'pack_id': 'user:P1:abc',
        'pack_version': 2,
        'sticker_id': 's0',
        'file_name': 's0.png',
        'local_path': '/old/place/s0.png',
        'format': 'png',
        'sha256_b64': 'aGFzaA==',
      });

      await AppDb.runMigrationsForTest(db, 63, 66);

      // v65: режим доступа к набору.
      expect(await columns(db, 'sticker_packs'), contains('share_mode'));
      // v66: кэш блоба у стикера.
      final stickerCols = await columns(db, 'sticker_pack_stickers');
      expect(stickerCols, contains('blob_id'));
      expect(stickerCols, contains('blob_file_key_b64'));
      expect(stickerCols, contains('blob_expires_at_ms'));
      // v64: закреплённый ключ личности собеседника.
      expect(
        await columns(db, 'contact_verification'),
        contains('account_identity_pub_b64'),
      );

      // Отметка проверки контакта тоже обязана выжить.
      final verification = await db.rawQuery(
        'SELECT * FROM contact_verification;',
      );
      expect(verification, hasLength(1));
      expect(verification.single['verified_ever_at_ms'], 900);

      // 🔴 Данные обязаны выжить. ALTER их не теряет, но узнать это от теста
      // дешевле, чем от человека.
      final packs = await db.rawQuery('SELECT * FROM sticker_packs;');
      expect(packs, hasLength(1));
      expect(packs.single['title'], 'Мои стикеры');
      final stickers = await db.rawQuery(
        'SELECT * FROM sticker_pack_stickers;',
      );
      expect(stickers, hasLength(1));
      expect(stickers.single['local_path'], '/old/place/s0.png');
      expect(stickers.single['sha256_b64'], 'aGFzaA==');
      // Новый столбец у старой строки пустой, а не мусор.
      expect(stickers.single['blob_id'], anyOf(isNull, ''));

      await db.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('🔴 повторный прогон по базе со стикерами безопасен', () async {
    // Обновление могло прерваться на середине: второй заход обязан пройти, а не
    // упасть на «столбец уже существует».
    final dir = await Directory.systemTemp.createTemp('mig_v63_twice');
    final path = p.join(dir.path, 'old.db');
    try {
      final db = await rawDb(path);
      await db.execute(
        'CREATE TABLE sticker_packs (pack_id TEXT NOT NULL, pack_version '
        'INTEGER NOT NULL, title TEXT NOT NULL, icon_sticker_id TEXT NOT NULL, '
        'updated_at_ms INTEGER NOT NULL, PRIMARY KEY(pack_id, pack_version));',
      );
      await db.execute(
        'CREATE TABLE sticker_pack_stickers (pack_id TEXT NOT NULL, '
        'pack_version INTEGER NOT NULL, sticker_id TEXT NOT NULL, file_name '
        'TEXT NOT NULL, format TEXT NOT NULL, PRIMARY KEY(pack_id, '
        'pack_version, sticker_id));',
      );
      await AppDb.runMigrationsForTest(db, 63, 66);
      await AppDb.runMigrationsForTest(db, 63, 66);
      expect(await columns(db, 'sticker_packs'), contains('share_mode'));
      await db.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
