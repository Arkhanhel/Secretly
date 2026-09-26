// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ratchet/decrypt_worker.dart';
import 'package:secretly_app/ratchet/double_ratchet_v3.dart';
import 'package:secretly_app/ratchet/ratchet_skip_limits.dart';
import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/ratchet/wire_v3.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';

/// П-3 (ТЗ мультиустройства, 25.09.2026): пропуск ключей ратчета.
///
/// Устройство, долго бывшее без связи, получает провод, опередивший цепочку на
/// сотни номеров. При пределе 200 такой провод не открывался никогда. Здесь
/// проверяется: пределы действуют ровно на своих границах, хранится только
/// нужное, архив остаётся на 200, неудача ничего не пишет, воркер получает оба
/// предела, телефон без флага ведёт себя как раньше.
const String aDev = 'A-device';
const String bDev = 'B-device';

class _Wire {
  _Wire(this.n, this.dhPubB64, this.pn, this.aad, this.ct, this.bytes);
  final int n;
  final String dhPubB64;
  final int pn;
  final Uint8List aad;
  final Uint8List ct;
  final Uint8List bytes;
}

Future<(DoubleRatchetStateV3, DoubleRatchetStateV3)> _pair(
  DoubleRatchetV3 dr, {
  int rkByte = 7,
  int spkBase = 1,
  int ephBase = 200,
}) async {
  final x = X25519();
  final spk = await x.newKeyPairFromSeed(
    Uint8List.fromList(List<int>.generate(32, (i) => (spkBase + i) & 0xff)),
  );
  final spkPub = await spk.extractPublicKey();
  final eph = await x.newKeyPairFromSeed(
    Uint8List.fromList(List<int>.generate(32, (i) => (ephBase + i) & 0xff)),
  );
  final ephPub = await eph.extractPublicKey();
  final rk = Uint8List.fromList(List<int>.filled(32, rkByte));
  final init = await dr.initInitiator(
    peerDeviceId: bDev,
    rootKey: rk,
    handshakeEphKeyPair: eph,
    recipientSignedPrekeyPub: Uint8List.fromList(spkPub.bytes),
  );
  final resp = await dr.initResponder(
    peerDeviceId: aDev,
    rootKey: rk,
    recipientSignedPrekeyKeyPair: spk,
    initiatorDhPub: Uint8List.fromList(ephPub.bytes),
  );
  return (init, resp);
}

Future<void> _seedPrimary(AppDb db, DoubleRatchetStateV3 s) =>
    db.sessionV3Upsert(
      peerDeviceId: s.peerDeviceId,
      rootKeyB64: base64Encode(s.rootKey),
      dhSelfSeedB64: base64Encode(s.dhSelfSeed),
      dhSelfPubB64: base64Encode(s.dhSelfPub),
      dhRemotePubB64: s.dhRemotePub == null
          ? null
          : base64Encode(s.dhRemotePub!),
      sendChainKeyB64: s.sendChainKey == null
          ? null
          : base64Encode(s.sendChainKey!),
      recvChainKeyB64: s.recvChainKey == null
          ? null
          : base64Encode(s.recvChainKey!),
      ns: s.ns,
      nr: s.nr,
      pn: s.pn,
    );

Future<void> _seedArchive(AppDb db, DoubleRatchetStateV3 s) =>
    db.sessionV3ArchivePush(
      peerDeviceId: s.peerDeviceId,
      rootKeyB64: base64Encode(s.rootKey),
      dhSelfSeedB64: base64Encode(s.dhSelfSeed),
      dhSelfPubB64: base64Encode(s.dhSelfPub),
      dhRemotePubB64: s.dhRemotePub == null
          ? null
          : base64Encode(s.dhRemotePub!),
      sendChainKeyB64: s.sendChainKey == null
          ? null
          : base64Encode(s.sendChainKey!),
      recvChainKeyB64: s.recvChainKey == null
          ? null
          : base64Encode(s.recvChainKey!),
      ns: s.ns,
      nr: s.nr,
      pn: s.pn,
    );

RatchetSessionManagerV3 _manager(AppDb db, {int? jump}) =>
    RatchetSessionManagerV3(
      db: db,
      deviceKeys: DeviceKeys.create(),
      keysClient: KeysClient(baseUrl: Uri.parse('http://127.0.0.1:1')),
      liveSkipJump: jump,
    );

Future<String> _open(RatchetSessionManagerV3 mgr, _Wire w) async {
  final pb = await mgr.decryptFromWire(
    selfProfileId: 'B-profile',
    selfDeviceId: bDev,
    wireBytes: w.bytes,
  );
  return utf8.decode(pb);
}

Future<List<int>> _storedNums(AppDb db) async {
  final raw = await db.rawQueryForTesting(
    'SELECT msg_num FROM skipped_message_keys WHERE peer_device_id = ? '
    'ORDER BY msg_num ASC',
    [aDev],
  );
  return [for (final r in raw) (r['msg_num'] as num).toInt()];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DoubleRatchetStateV3 resp;
  final wires = <int, _Wire>{};
  const wanted = {150, 199, 200, 201, 300, 1999, 2000, 2001, 2500, 3000, 4000,
    4999, 5000, 5001};

  setUpAll(() async {
    final dr = DoubleRatchetV3();
    final (init, r) = await _pair(dr);
    resp = r;
    var s = init;
    for (var i = 0; i <= 5001; i++) {
      final header = <String, Object?>{
        'sender_device_id': aDev,
        'dh_pub_b64': base64Encode(s.dhSelfPub),
        'pn': s.pn,
        'n': s.ns,
      };
      final aad = Uint8List.fromList(utf8.encode(jsonEncode(header)));
      final enc = await dr.encrypt(
        state: s,
        plaintext: Uint8List.fromList(utf8.encode('m$i')),
        aad: aad,
      );
      if (wanted.contains(i)) {
        wires[i] = _Wire(
          i,
          header['dh_pub_b64'] as String,
          header['pn'] as int,
          aad,
          enc.ciphertext,
          RatchetWireV3.encodeSession(
            senderDeviceId: aDev,
            dhPubB64: header['dh_pub_b64'] as String,
            pn: header['pn'] as int,
            n: header['n'] as int,
            ratchetCiphertext: enc.ciphertext,
          ),
        );
      }
      s = enc.updated;
    }
  });

  Future<DoubleRatchetDecryptResultV3> pure(
    DoubleRatchetV3 dr,
    int n, {
    DoubleRatchetStateV3? state,
    Uint8List? preloaded,
  }) {
    final w = wires[n]!;
    return dr.decrypt(
      state: state ?? resp,
      headerDhPubB64: w.dhPubB64,
      pn: w.pn,
      n: w.n,
      ciphertext: w.ct,
      preloadedSkippedKey: preloaded,
      aad: w.aad,
    );
  }

  Matcher tooMany() => throwsA(
    predicate((e) => e.toString().contains('too many skipped messages')),
  );

  group('чистый ратчет: границы', () {
    test('прежние параметры: 199 и 200 открываются, 201 — нет (регресс)', () async {
      final dr = DoubleRatchetV3();
      expect(utf8.decode((await pure(dr, 199)).plaintext), 'm199');
      final at200 = await pure(dr, 200);
      expect(utf8.decode(at200.plaintext), 'm200');
      expect(at200.skippedToStore.length, 200, reason: 'без потолка — все');
      await expectLater(pure(dr, 201), tooMany());
    });

    test('скачок 2 000: 1 999 и 2 000 открываются, 2 001 — нет', () async {
      final dr = DoubleRatchetV3(maxSkip: 2000, maxStoredSkipped: 2000);
      expect(utf8.decode((await pure(dr, 1999)).plaintext), 'm1999');
      expect(utf8.decode((await pure(dr, 2000)).plaintext), 'm2000');
      await expectLater(pure(dr, 2001), tooMany());
    });

    test('скачок 5 000: 4 999 и 5 000 открываются, 5 001 — нет', () async {
      final dr = RatchetSkipLimits.forJump(5000).buildRatchet();
      expect(utf8.decode((await pure(dr, 4999)).plaintext), 'm4999');
      expect(utf8.decode((await pure(dr, 5000)).plaintext), 'm5000');
      await expectLater(pure(dr, 5001), tooMany());
    });

    test('скачок 3 000: хранятся ровно 2 000 самых новых номеров', () async {
      final dr = RatchetSkipLimits.forJump(5000).buildRatchet();
      final r = await pure(dr, 3000);
      final nums = [for (final k in r.skippedToStore) k.msgNum];
      expect(nums.length, 2000);
      expect(nums.first, 1000);
      expect(nums.last, 2999);

      // Опоздавший с хранимым номером открывается, с выброшенным — нет (так и
      // задумано: хранение ограничено, как у Signal).
      final key2500 =
          r.skippedToStore.firstWhere((k) => k.msgNum == 2500).messageKey;
      final late = await pure(dr, 2500, state: r.updated, preloaded: key2500);
      expect(utf8.decode(late.plaintext), 'm2500');
      expect(late.consumedPreloadedKey, isTrue);
      await expectLater(pure(dr, 300, state: r.updated), throwsA(anything));
    });

    test('потолок хранения null — все ключи, как до П-3', () async {
      final r = await pure(DoubleRatchetV3(maxSkip: 200), 150);
      expect(r.skippedToStore.length, 150);
      final capped = await pure(
        DoubleRatchetV3(maxSkip: 200, maxStoredSkipped: 50),
        150,
      );
      expect([for (final k in capped.skippedToStore) k.msgNum].first, 100);
      expect(capped.skippedToStore.length, 50);
    });
  });

  group('воркер', () {
    tearDown(DecryptWorker.instance.disposeForTesting);

    test('🔴 оба предела доезжают до изолята', () async {
      // Потеряй воркер maxSkip — 3 000 упадёт на 200; потеряй хранение —
      // вернутся все 3 000 ключей.
      final w = wires[3000]!;
      final r = await DecryptWorker.instance.decrypt(
        ratchet: RatchetSkipLimits.forJump(5000).buildRatchet(),
        state: resp,
        headerDhPubB64: w.dhPubB64,
        pn: w.pn,
        n: w.n,
        ciphertext: w.ct,
        aad: w.aad,
      );
      expect(DecryptWorker.instance.isRunning, isTrue, reason: 'шёл мимо воркера');
      expect(utf8.decode(r.plaintext), 'm3000');
      expect(r.skippedToStore.length, 2000);
    });
  });

  group('менеджер сессий', () {
    late AppDb db;
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('skip_limits');
      db = await AppDb.openForTesting(path: '${dir.path}/t.db');
    });
    tearDown(() async {
      DecryptWorker.instance.disposeForTesting();
      await db.close();
      await dir.delete(recursive: true);
    });

    test('без флага — прежнее поведение: 200/без потолка, архив 200', () {
      final mgr = _manager(db);
      expect(mgr.liveLimits, RatchetSkipLimits.legacy);
      expect(mgr.dr.maxSkip, 200);
      expect(mgr.dr.maxStoredSkipped, isNull);
      expect(mgr.drArchive.maxSkip, 200);
      expect(mgr.drArchive.maxStoredSkipped, isNull);
      mgr.setLiveSkipJump(5000);
      expect(mgr.dr.maxSkip, 5000);
      expect(mgr.dr.maxStoredSkipped, 2000);
      expect(mgr.drArchive.maxSkip, 200, reason: 'архив не поднимается');
      mgr.setLiveSkipJump(0);
      expect(mgr.liveLimits, RatchetSkipLimits.legacy);
    });

    test('живая сессия со скачком 5 000 открывает 3 000 и хранит 2 000', () async {
      await _seedPrimary(db, resp);
      final mgr = _manager(db, jump: 5000);
      expect(await _open(mgr, wires[3000]!), 'm3000');
      final nums = await _storedNums(db);
      expect(nums.length, 2000);
      expect(nums.first, 1000);
      expect(nums.last, 2999);
      expect(await _open(mgr, wires[2500]!), 'm2500');
      expect((await _storedNums(db)).length, 1999, reason: 'ключ одноразовый');
    });

    test('🔴 архивная сессия остаётся на 200: 300 не открывается, 150 — да', () async {
      // Живая сессия — чужая (другой корень), поэтому дело доходит до архива.
      final (_, other) = await _pair(DoubleRatchetV3(), rkByte: 9, ephBase: 90);
      await _seedPrimary(db, other);
      await _seedArchive(db, resp);
      final mgr = _manager(db, jump: 5000);
      await expectLater(_open(mgr, wires[300]!), throwsA(anything));
      expect(await _storedNums(db), isEmpty);
      expect(await _open(mgr, wires[150]!), 'm150');
    });

    test('🔴 неудачная расшифровка ничего не пишет', () async {
      await _seedPrimary(db, resp);
      final mgr = _manager(db, jump: 5000);
      final w = wires[4000]!;
      final forged = Uint8List.fromList(w.ct)..[w.ct.length - 1] ^= 0x01;
      final bad = _Wire(
        w.n,
        w.dhPubB64,
        w.pn,
        w.aad,
        forged,
        RatchetWireV3.encodeSession(
          senderDeviceId: aDev,
          dhPubB64: w.dhPubB64,
          pn: w.pn,
          n: w.n,
          ratchetCiphertext: forged,
        ),
      );
      await expectLater(_open(mgr, bad), throwsA(anything));
      expect(await _storedNums(db), isEmpty);
      final row = await db.sessionV3Get(aDev);
      expect((row!['nr'] as num).toInt(), 0, reason: 'сессия не сдвинулась');
      // И настоящий провод после этого открывается как ни в чём не бывало.
      expect(await _open(mgr, wires[4000]!), 'm4000');
    });

    test('замер худшего пути ПК: 5 000 выводов + 2 000 строк + обрезка', () async {
      await _seedPrimary(db, resp);
      final mgr = _manager(db, jump: 5000);
      final sw = Stopwatch()..start();
      expect(await _open(mgr, wires[5000]!), 'm5000');
      sw.stop();
      // ignore: avoid_print
      print('П-3 худший путь ПК (скачок 5 000): ${sw.elapsedMilliseconds} мс');
      expect((await _storedNums(db)).length, 2000);
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });

  test('обрезка оставляет 2 000 самых новых и не трогает других', () async {
    final dir = await Directory.systemTemp.createTemp('skip_trim');
    final db = await AppDb.openForTesting(path: '${dir.path}/t.db');
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    const insert =
        'INSERT INTO skipped_message_keys(peer_device_id, dh_pub_b64, msg_num, '
        'mk_b64, created_at_ms) VALUES(?, ?, ?, ?, ?)';
    // Номера и время растут вместе, кроме хвоста: 2 400…2 499 записаны
    // РАНЬШЕ всех — «самые новые» считаются по времени, не по номеру.
    for (var i = 0; i < 2500; i++) {
      final at = i >= 2400 ? i - 2400 : 1000 + i;
      await db.rawInsertForTesting(insert, [aDev, 'dh', i, 'k', at]);
    }
    await db.rawInsertForTesting(insert, ['other', 'dh', 1, 'k', 1]);
    final removed = await db.skippedKeysTrimForPeer(
      peerDeviceId: aDev,
      keep: 2000,
    );
    expect(removed, 500);
    final nums = await _storedNums(db);
    expect(nums.length, 2000);
    expect(nums.first, 400, reason: 'выживают 400…2 399 — самые свежие по времени');
    expect(nums.last, 2399);
    final other = await db.rawQueryForTesting(
      'SELECT 1 FROM skipped_message_keys WHERE peer_device_id = ?',
      ['other'],
    );
    expect(other.length, 1);
  });

  group('правило пределов', () {
    test('не больше 200 — прежнее целиком; выше — потолки и бюджет', () {
      for (final j in [0, 150, 200]) {
        expect(RatchetSkipLimits.forJump(j), RatchetSkipLimits.legacy);
      }
      final raised = RatchetSkipLimits.forJump(201);
      expect(raised.raised, isTrue);
      expect(raised.storedPerWire, 2000);
      expect(raised.storedPerPeer, 2000);
      expect(raised.replayBudget, const Duration(seconds: 2));
      expect(RatchetSkipLimits.forJump(999999).jump, 25000);
      expect(RatchetSkipLimits.legacy.replayBudget, isNull);
    });

    test('🔴 встроенный скачок телефона — прежние 200 (мобильная заморожена)', () {
      expect(RatchetSkipLimits.builtInMobileJump, 200);
      expect(RatchetSkipLimits.builtInDesktopJump, 5000);
    });

    test('скачок для журнала считается как в ратчете', () {
      final remote = Uint8List.fromList(List<int>.filled(32, 1));
      final other = base64Encode(List<int>.filled(32, 2));
      final s = DoubleRatchetStateV3(
        peerDeviceId: aDev,
        rootKey: Uint8List(32),
        dhSelfSeed: Uint8List(32),
        dhSelfPub: Uint8List(32),
        dhRemotePub: remote,
        sendChainKey: null,
        recvChainKey: Uint8List(32),
        ns: 0,
        nr: 10,
        pn: 0,
      );
      int jump(String dh, int pn, int n) => RatchetSessionManagerV3.skipJumpFor(
        state: s,
        headerDhPubB64: dh,
        pn: pn,
        n: n,
      );
      expect(jump(base64Encode(remote), 0, 250), 240);
      expect(jump(base64Encode(remote), 0, 5), 0);
      expect(jump(other, 300, 40), 290 + 40);
      expect(jump('не base64', 0, 1000), 0);
    });
  });

  test('контроллер передаёт скачок во все менеджеры и не забывает бюджет', () {
    final src = File('lib/app/app_controller.dart').readAsStringSync();
    expect(
      RegExp(r'RatchetSessionManagerV3\(').allMatches(src).length,
      RegExp(r'liveSkipJump: _ratchetLiveSkipJump,').allMatches(src).length,
      reason: 'менеджер создан без скачка — ПК останется на 200',
    );
    expect(src.contains('_ratchetV3?.setLiveSkipJump(_ratchetLiveSkipJump);'),
        isTrue);
    expect(
      RegExp(r'spent\.elapsed > budget').allMatches(src).length,
      2,
      reason: 'бюджет переигровки нужен в обоих проходах',
    );
  });
}
