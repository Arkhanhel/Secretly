// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secretly_app/storage/app_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Э-4 Ш-1 (docs/TZ_PREKEY_UNTIL_CONFIRMED_2026-08-01.md, редакция 2):
/// the two handshake columns, and the migration onto them.
///
/// This step must change NO behaviour — it only opens the storage. What it must
/// guarantee is that the columns exist on BOTH creation paths (this database has
/// two: a fresh install and the `oldVersion < 11` upgrade path — the Wave-2
/// lesson), that a ratchet advance does not erase them, and that a build with an
/// older database can still open it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppDb> openAt(String path) => AppDb.openForTesting(path: path);

  Future<Set<String>> columnsOf(AppDb db, String table) async {
    final rows = await db.rawQueryForTesting('PRAGMA table_info($table);');
    return rows.map((r) => (r['name'] as String?) ?? '').toSet();
  }

  test('a fresh database has both handshake columns', () async {
    final db = await AppDb.openForTesting();
    final cols = await columnsOf(db, 'sessions_v3');
    expect(cols, contains('handshake_base_pub_b64'));
    expect(cols, contains('pending_prekey_header_json'));
    // Р-4: the base key must travel into the archive too, or a late repeat of
    // an older handshake overwrites a newer session.
    expect(
      await columnsOf(db, 'sessions_v3_archive'),
      contains('handshake_base_pub_b64'),
    );
    await db.close();
  });

  /// 🔴 The real risk of this step: an EXISTING install upgrading. A database
  /// created before Э-4 must gain the columns rather than fail to open.
  test('🔴 an existing pre-Э-4 database migrates instead of breaking', () async {
    final dir = await Directory.systemTemp.createTemp('e4_migrate');
    final path = p.join(dir.path, 'old.db');
    try {
      // Stand in for a shipped database: sessions_v3 as it looked BEFORE Э-4,
      // carrying a real row, at the old user_version.
      ffi.sqfliteFfiInit();
      final raw = await ffi.databaseFactoryFfi.openDatabase(path);
      await raw.execute('''
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
      await raw.insert('sessions_v3', {
        'peer_device_id': 'peer-A',
        'root_key_b64': 'Uk9PVA==',
        'dh_self_seed_b64': 'U0VFRA==',
        'dh_self_pub_b64': 'UFVC',
        'dh_remote_pub_b64': 'UkVN',
        'send_chain_key_b64': 'U0NL',
        'recv_chain_key_b64': 'UkNL',
        'ns': 3,
        'nr': 4,
        'pn': 2,
        'updated_at_ms': 1000,
        'created_at_ms': 900,
        'initiator_pending_at_ms': 0,
        'epoch': 77,
      });
      await raw.setVersion(60);
      await raw.close();

      final db = await openAt(path);
      final cols = await columnsOf(db, 'sessions_v3');
      expect(cols, contains('handshake_base_pub_b64'),
          reason: 'the migration did not add the base-key column');
      expect(cols, contains('pending_prekey_header_json'));

      // The pre-existing session must survive untouched, and read NULL for the
      // new columns — which the receiver treats exactly as it does today (Р-10:
      // this step changes no behaviour for anyone already in the field).
      final row = await db.sessionV3Get('peer-A');
      expect(row, isNotNull);
      expect(row!['ns'], 3);
      expect(row['epoch'], 77);
      expect(row['handshake_base_pub_b64'], isNull);
      expect(row['pending_prekey_header_json'], isNull);
      await db.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });

  /// 🔴 `sessionV3Upsert` runs on EVERY ratchet advance and replaces the whole
  /// row. Anything it does not carry forward is erased on the next message —
  /// and losing the base key means the receiver stops recognising repeats of
  /// the handshake it already adopted, which is the session-destroying path
  /// Д-1 describes.
  test('🔴 a ratchet advance does NOT erase the handshake columns', () async {
    final db = await AppDb.openForTesting();
    await db.sessionV3Upsert(
      peerDeviceId: 'peer-A',
      rootKeyB64: 'Uk9PVA==',
      dhSelfSeedB64: 'U0VFRA==',
      dhSelfPubB64: 'UFVC',
      dhRemotePubB64: 'UkVN',
      sendChainKeyB64: 'U0NL',
      recvChainKeyB64: 'UkNL',
      ns: 0,
      nr: 0,
      pn: 0,
    );
    await db.sessionV3SetHandshake(
      'peer-A',
      baseKeyB64: 'BASEKEY',
      pendingPrekeyHeaderJson: '{"spk_id":1}',
    );

    // Ten advances, as a normal conversation would do.
    for (var i = 1; i <= 10; i++) {
      await db.sessionV3Upsert(
        peerDeviceId: 'peer-A',
        rootKeyB64: 'Uk9PVA==$i',
        dhSelfSeedB64: 'U0VFRA==',
        dhSelfPubB64: 'UFVC',
        dhRemotePubB64: 'UkVN',
        sendChainKeyB64: 'U0NL',
        recvChainKeyB64: 'UkNL',
        ns: i,
        nr: i,
        pn: 0,
      );
    }

    final row = await db.sessionV3Get('peer-A');
    expect(row!['handshake_base_pub_b64'], 'BASEKEY',
        reason: 'the base key was erased by a ratchet advance — repeats would '
            'stop being recognised and would destroy the session (Д-1)');
    expect(row['pending_prekey_header_json'], '{"spk_id":1}');
    expect(row['ns'], 10, reason: 'the advance itself must still work');
    await db.close();
  });

  test('clearing the cached header is explicit and does not touch the base key',
      () async {
    // Confirmation drops the header (next to where initiator_pending_at_ms is
    // zeroed) but the base key belongs to the session for its whole life.
    final db = await AppDb.openForTesting();
    await db.sessionV3Upsert(
      peerDeviceId: 'peer-A',
      rootKeyB64: 'Uk9PVA==',
      dhSelfSeedB64: 'U0VFRA==',
      dhSelfPubB64: 'UFVC',
      dhRemotePubB64: null,
      sendChainKeyB64: null,
      recvChainKeyB64: null,
      ns: 0,
      nr: 0,
      pn: 0,
    );
    await db.sessionV3SetHandshake(
      'peer-A',
      baseKeyB64: 'BASEKEY',
      pendingPrekeyHeaderJson: '{"spk_id":1}',
    );
    await db.sessionV3SetHandshake('peer-A', clearPendingHeader: true);

    final row = await db.sessionV3Get('peer-A');
    expect(row!['pending_prekey_header_json'], isNull,
        reason: 'a header left behind after confirmation repeats forever');
    expect(row['handshake_base_pub_b64'], 'BASEKEY',
        reason: 'the base key outlives confirmation — it identifies the session');
    await db.close();
  });

  test('the archive carries the base key (Р-4)', () async {
    final db = await AppDb.openForTesting();
    await db.sessionV3ArchivePush(
      peerDeviceId: 'peer-A',
      rootKeyB64: 'Uk9PVA==',
      dhSelfSeedB64: 'U0VFRA==',
      dhSelfPubB64: 'UFVC',
      dhRemotePubB64: 'UkVN',
      sendChainKeyB64: 'U0NL',
      recvChainKeyB64: 'UkNL',
      ns: 1,
      nr: 1,
      pn: 0,
      handshakeBasePubB64: 'OLDBASE',
    );
    final archived = await db.sessionV3ArchiveList('peer-A');
    expect(archived, hasLength(1));
    expect(archived.first['handshake_base_pub_b64'], 'OLDBASE',
        reason: 'without this a late repeat of an older handshake falls '
            'through to X3DH and overwrites a NEWER session');
    await db.close();
  });
}
