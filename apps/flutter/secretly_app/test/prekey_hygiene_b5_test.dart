// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/messages/prekey_flags.dart';
import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/ratchet/wire_v3.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';

// Б5 Э1 (24.10.2026): приём нескольких подписанных предключей.
// Ротации в Э1 нет — её здесь изображает правка записи ключей так, как её
// сделает Э3: новый ключ становится текущим, прежний уходит в `previous_spks`.

class _FixedBundleKeysClient extends KeysClient {
  _FixedBundleKeysClient(this.devices)
      : super(baseUrl: Uri.parse('https://example.com'));

  List<Map<String, Object?>> devices;

  @override
  Future<List<Map<String, Object?>>> fetchBundle(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async =>
      devices;
}

Map<String, Object?> _deviceMap(String deviceId, DeviceKeyBundleV1 b,
        {int otkIndex = 0}) =>
    <String, Object?>{
      'device_id': deviceId,
      'identity_key_pub_b64': b.identityKeyPubB64,
      'signed_prekey_pub_b64': b.signedPrekeyPubB64,
      'signed_prekey_sig_b64': b.signedPrekeySigB64,
      if (b.signedPrekeyId != 1) 'signed_prekey_id': b.signedPrekeyId,
      'one_time_prekey': b.oneTimePrekeys.length > otkIndex
          ? b.oneTimePrekeys[otkIndex]
          : null,
    };

String _materialKey(String pid, String did) => 'secretly/device_keys_v1/$pid/$did';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final store = <String, String>{};

  setUp(() {
    store.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = Map<Object?, Object?>.from(
        call.arguments as Map<Object?, Object?>? ?? const {},
      );
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return key == null ? null : store[key];
        case 'write':
          if (key != null) store[key] = (args['value'] as String?) ?? '';
          return null;
        case 'delete':
          if (key != null) store.remove(key);
          return null;
        case 'readAll':
          return Map<String, String>.from(store);
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Как сделает Э3: новый текущий ключ, прежний — в начало `previous_spks`.
  void rotate(String pid, String did, int newId) {
    final key = _materialKey(pid, did);
    final m = jsonDecode(store[key]!) as Map<String, dynamic>;
    final oldId = (m['signed_prekey_id'] as num?)?.toInt() ?? 1;
    m['previous_spks'] = <Object?>[
      {
        'id': oldId,
        'seed_b64': m['signed_prekey_seed_b64'],
        'created_ms': 0,
        'retired_ms': 1,
      },
      ...(m['previous_spks'] as List<dynamic>? ?? const <dynamic>[]),
    ];
    m['signed_prekey_seed_b64'] =
        base64Encode(List<int>.generate(32, (i) => (i * 7 + newId) & 0xff));
    m['signed_prekey_id'] = newId;
    store[key] = jsonEncode(m);
  }

  Future<String> dec(RatchetSessionManagerV3 mgr, String pid, String did,
      Uint8List wire) async {
    final plain = await mgr.decryptFromWire(
      selfProfileId: pid,
      selfDeviceId: did,
      wireBytes: wire,
    );
    return utf8.decode(plain);
  }

  Future<Uint8List> enc(RatchetSessionManagerV3 mgr, String text) =>
      mgr.encryptToPeer(
        selfDeviceId: 'Adev',
        peerProfileId: 'Bprof',
        peerDeviceId: 'Bdev',
        plaintext: Uint8List.fromList(utf8.encode(text)),
        selfProfileId: 'Aprof',
      );

  Future<(RatchetSessionManagerV3, RatchetSessionManagerV3, _FixedBundleKeysClient, List<AppDb>)>
      world() async {
    final dir = Directory.systemTemp.createTempSync('b5hs');
    final aDb = await AppDb.openForTesting(path: '${dir.path}/a.db');
    final bDb = await AppDb.openForTesting(path: '${dir.path}/b.db');
    final keys = DeviceKeys.create();
    final aBundle = await keys.createOrLoadAndAllocateOtk(
        profileId: 'Aprof', deviceId: 'Adev', allocateOneTimePrekeys: 4);
    final bBundle = await keys.createOrLoadAndAllocateOtk(
        profileId: 'Bprof', deviceId: 'Bdev', allocateOneTimePrekeys: 4);
    final toB = _FixedBundleKeysClient([_deviceMap('Bdev', bBundle)]);
    final a = RatchetSessionManagerV3(
        db: aDb, deviceKeys: DeviceKeys.create(), keysClient: toB);
    final b = RatchetSessionManagerV3(
        db: bDb,
        deviceKeys: DeviceKeys.create(),
        keysClient: _FixedBundleKeysClient([_deviceMap('Adev', aBundle)]));
    await bDb.contactDeviceUpsert(
      profileId: 'Aprof',
      deviceId: 'Adev',
      identityKeyPubB64: aBundle.identityKeyPubB64,
      signedPrekeyPubB64: aBundle.signedPrekeyPubB64,
      signedPrekeySigB64: aBundle.signedPrekeySigB64,
    );
    return (a, b, toB, [aDb, bDb]);
  }

  test('запись без ротации остаётся формы v1', () async {
    final keys = DeviceKeys.create();
    final bundle = await keys.createOrLoadAndAllocateOtk(
        profileId: 'P', deviceId: 'D', allocateOneTimePrekeys: 0);
    expect(bundle.signedPrekeyId, 1);
    final m = jsonDecode(store[_materialKey('P', 'D')]!) as Map<String, dynamic>;
    expect(m.keys.toSet(), {
      'identity_seed_b64',
      'signed_prekey_seed_b64',
      'next_otk_id',
      'otk_seed_by_id',
    });

    await keys.createOrLoadAndAllocateOtk(
        profileId: 'P', deviceId: 'D', allocateOneTimePrekeys: 3);
    final m2 = jsonDecode(store[_materialKey('P', 'D')]!) as Map<String, dynamic>;
    expect((m2['otk_alloc_marks'] as List).single[0], 1);
    expect(m2.containsKey('signed_prekey_id'), isFalse);
  });

  test('испорченные новые поля не лишают устройство ключей', () async {
    final keys = DeviceKeys.create();
    await keys.createOrLoadAndAllocateOtk(
        profileId: 'P', deviceId: 'D', allocateOneTimePrekeys: 1);
    final m = jsonDecode(store[_materialKey('P', 'D')]!) as Map<String, dynamic>;
    m['signed_prekey_id'] = -5;
    m['previous_spks'] = 'garbage';
    m['otk_alloc_marks'] = [
      [1],
      'x'
    ];
    m['otk_used_ms_by_id'] = [1, 2];
    await keys.importMaterialJson(
        profileId: 'P', deviceId: 'D', rawJson: jsonEncode(m));

    final candidates =
        await keys.loadSignedPrekeyCandidates(profileId: 'P', deviceId: 'D');
    expect(candidates.map((c) => c.id), [1]);
    final again = await keys.createOrLoadAndAllocateOtk(
        profileId: 'P', deviceId: 'D', allocateOneTimePrekeys: 0);
    expect(again.signedPrekeyId, 1);
  });

  test('кандидаты: названный номер — только он; 1 — текущий, затем прежние',
      () async {
    final keys = DeviceKeys.create();
    await keys.createOrLoadAndAllocateOtk(
        profileId: 'P', deviceId: 'D', allocateOneTimePrekeys: 0);
    rotate('P', 'D', 2);
    rotate('P', 'D', 3);
    Future<List<int>> ids(int? named) async => (await keys
            .loadSignedPrekeyCandidates(
                profileId: 'P', deviceId: 'D', signedPrekeyId: named))
        .map((c) => c.id)
        .toList();
    expect(await ids(1), [3, 2, 1]);
    expect(await ids(null), [3, 2, 1]);
    expect(await ids(2), [2]);
    expect(await ids(99), [3, 2, 1], reason: 'неизвестный номер — перебор');
  });

  test('старый отправитель (spk_id = 1) после ротации получателя доходит',
      () async {
    final (a, b, _, dbs) = await world();
    try {
      // Пакет Боба Алиса взяла ДО ротации; конверт идёт после неё.
      rotate('Bprof', 'Bdev', 2);
      final wire = await enc(a, 'после ротации');
      expect(RatchetWireV3.tryDecode(wire)!.header['spk_id'], 1);
      expect(await dec(b, 'Bprof', 'Bdev', wire), 'после ротации');
    } finally {
      for (final d in dbs) {
        await d.close();
      }
    }
  });

  test('новый отправитель называет номер, получатель берёт ключ по нему',
      () async {
    final (a, b, toB, dbs) = await world();
    try {
      rotate('Bprof', 'Bdev', 2);
      final fresh = await DeviceKeys.create().createOrLoadAndAllocateOtk(
          profileId: 'Bprof', deviceId: 'Bdev', allocateOneTimePrekeys: 2);
      expect(fresh.signedPrekeyId, 2);
      toB.devices = [_deviceMap('Bdev', fresh)];
      final wire = await enc(a, 'по номеру');
      final header = RatchetWireV3.tryDecode(wire)!.header;
      expect(header['spk_id'], 2);
      expect(await dec(b, 'Bprof', 'Bdev', wire), 'по номеру');

      // Принятый одноразовый ключ отмечен (запись — вне транзакции).
      final otkId = header['otk_id'] as int;
      Map<String, dynamic> used = const {};
      for (var i = 0; i < 50 && !used.containsKey('$otkId'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final m = jsonDecode(store[_materialKey('Bprof', 'Bdev')]!)
            as Map<String, dynamic>;
        used = (m['otk_used_ms_by_id'] as Map<String, dynamic>?) ?? const {};
      }
      expect(used.containsKey('$otkId'), isTrue);
    } finally {
      for (final d in dbs) {
        await d.close();
      }
    }
  });

  test('одновременные записи не теряют сиды OTK', () async {
    final keys = DeviceKeys.create();
    await keys.createOrLoadAndAllocateOtk(
        profileId: 'P', deviceId: 'D', allocateOneTimePrekeys: 2);
    await Future.wait([
      DeviceKeys.create().createOrLoadAndAllocateOtk(
          profileId: 'P', deviceId: 'D', allocateOneTimePrekeys: 5),
      DeviceKeys.create().markOneTimePrekeyUsed(
          profileId: 'P', deviceId: 'D', prekeyId: 1, nowMs: 42),
      DeviceKeys.create().createOrLoadAndAllocateOtk(
          profileId: 'P', deviceId: 'D', allocateOneTimePrekeys: 5),
    ]);
    final m = jsonDecode(store[_materialKey('P', 'D')]!) as Map<String, dynamic>;
    expect((m['otk_seed_by_id'] as Map).length, 12);
    expect(m['next_otk_id'], 13);
    expect((m['otk_used_ms_by_id'] as Map)['1'], 42);
  });

  // ── Э2 (24.10.2026): флаг, пополнение по остатку, чистка сидов ─────────────

  test('блок prekeys: подпись побайтово как у сервера, отказ — всё выключено',
      () {
    expect(
      prekeysSigningMessage(
        otkHygieneShare: 10,
        spkRotateShare: 0,
        spkRotateDays: 7,
        legacyWireRejectShare: 0,
        issuedAtMs: 1760000000123,
      ),
      'secretly-prekeys-v1|10|0|7|0|1760000000123',
    );
    final config = <String, dynamic>{
      'prekeys': {
        'otk_hygiene_share': 150,
        'spk_rotate_share': 3,
        'spk_rotate_days': 0,
        'legacy_wire_reject_share': -1,
      },
    };
    expect(PrekeyFlags.fromConfigResponse(config, verified: false),
        PrekeyFlags.defaults);
    final f = PrekeyFlags.fromConfigResponse(config, verified: true);
    expect(f.otkHygieneShare, 100);
    expect(f.spkRotateDays, 1);
    expect(f.legacyWireRejectShare, 0);
    expect(f.otkHygieneFor('dev'), isTrue);
    expect(f.otkHygieneFor(' '), isFalse);
    expect(PrekeyFlags.defaults.otkHygieneFor('dev'), isFalse);
    // Доля детерминирована по устройству и примерно соблюдается.
    const half = PrekeyFlags(otkHygieneShare: 50);
    final inShare =
        List.generate(1000, (i) => half.otkHygieneFor('d$i')).where((x) => x);
    expect(inShare.length, inInclusiveRange(400, 600));
    expect(half.otkHygieneFor('d7'), half.otkHygieneFor('d7'));
  });

  test('пополнение: неизвестно — 20, меньше 20 — до 100, иначе 0', () {
    expect(otkTopUpCount(null), 20);
    expect(otkTopUpCount(0), 100);
    expect(otkTopUpCount(19), 81);
    expect(otkTopUpCount(20), 0);
    expect(otkTopUpCount(500), 0);
  });

  group('чистка сидов OTK', () {
    const day = 24 * 60 * 60 * 1000;
    const now = 1760000000000;

    Future<Map<String, dynamic>> seed({
      required int count,
      List<List<int>>? marks,
      Map<String, int>? used,
    }) async {
      await DeviceKeys.create().createOrLoadAndAllocateOtk(
          profileId: 'P', deviceId: 'D', allocateOneTimePrekeys: count);
      final m =
          jsonDecode(store[_materialKey('P', 'D')]!) as Map<String, dynamic>;
      if (marks == null) {
        m.remove('otk_alloc_marks');
      } else {
        m['otk_alloc_marks'] = marks;
      }
      if (used != null) m['otk_used_ms_by_id'] = used;
      store[_materialKey('P', 'D')] = jsonEncode(m);
      return m;
    }

    Future<(int, Set<String>)> prune(
        {required int? remaining, required int? minId}) async {
      final removed = await DeviceKeys.create().pruneOneTimePrekeySeeds(
        profileId: 'P',
        deviceId: 'D',
        nowMs: now,
        otkRemaining: remaining,
        minRemainingId: minId,
      );
      final m =
          jsonDecode(store[_materialKey('P', 'D')]!) as Map<String, dynamic>;
      return (removed, (m['otk_seed_by_id'] as Map).keys.cast<String>().toSet());
    }

    test('принятый — через 48 ч, не раньше', () async {
      await seed(count: 3, marks: [
        [1, now]
      ], used: {
        '1': now - 49 * 60 * 60 * 1000,
        '2': now - 47 * 60 * 60 * 1000,
      });
      final (removed, left) = await prune(remaining: null, minId: null);
      expect(removed, 1);
      expect(left, {'2', '3'});
    });

    test('выданный — старше 60 дней; невыданный не трогается', () async {
      await seed(count: 6, marks: [
        [1, now - 70 * day],
        [4, now - 10 * day],
      ]);
      // На keys остались 3 и выше: 1–2 выданы 70 дней назад, 3 — нет.
      final (removed, left) = await prune(remaining: 4, minId: 3);
      expect(removed, 2);
      expect(left, {'3', '4', '5', '6'});
    });

    test('keys не сказал остаток — второе правило не работает', () async {
      await seed(count: 3, marks: [
        [1, now - 90 * day]
      ]);
      final (removed, _) = await prune(remaining: null, minId: null);
      expect(removed, 0);
    });

    test('пул на keys пуст — выданы все до следующего номера', () async {
      await seed(count: 3, marks: [
        [1, now - 90 * day]
      ]);
      final (removed, left) = await prune(remaining: 0, minId: null);
      expect(removed, 3);
      expect(left, isEmpty);
    });

    test('ключи до Б5 без меток не стираются, пока нет первой метки', () async {
      await seed(count: 3);
      final (removed, _) = await prune(remaining: 0, minId: null);
      expect(removed, 0);
    });

    test('без чего стирать — запись не переписывается', () async {
      await seed(count: 2, marks: [
        [1, now]
      ]);
      final before = store[_materialKey('P', 'D')];
      final (removed, _) = await prune(remaining: 2, minId: 1);
      expect(removed, 0);
      expect(identical(before, store[_materialKey('P', 'D')]), isTrue);
    });
  });

  // ── Э3 (24.10.2026): ротация SPK ───────────────────────────────────────────

  group('ротация SPK', () {
    const day = 24 * 60 * 60 * 1000;
    const t0 = 1760000000000;

    Map<String, dynamic> material() =>
        jsonDecode(store[_materialKey('P', 'D')]!) as Map<String, dynamic>;

    Future<bool> maintain(int now) => DeviceKeys.create().maintainSignedPrekey(
        profileId: 'P', deviceId: 'D', nowMs: now, rotateEveryMs: 7 * day);

    List<int> previousIds() => [
          for (final p in (material()['previous_spks'] as List? ?? const []))
            (p as Map)['id'] as int
        ];

    test('ключ до Б5 сменяется сразу, дальше — раз в период', () async {
      await DeviceKeys.create().createOrLoadAndAllocateOtk(
          profileId: 'P', deviceId: 'D', allocateOneTimePrekeys: 0);
      final oldSeed = material()['signed_prekey_seed_b64'];

      expect(await maintain(t0), isTrue);
      expect(material()['signed_prekey_id'], 2);
      expect(material()['signed_prekey_created_ms'], t0);
      expect(material()['signed_prekey_seed_b64'], isNot(oldSeed));
      expect(previousIds(), [1]);

      expect(await maintain(t0 + 6 * day), isFalse);
      expect(material()['signed_prekey_id'], 2);

      expect(await maintain(t0 + 7 * day), isTrue);
      expect(material()['signed_prekey_id'], 3);
      expect(previousIds(), [2, 1]);

      final bundle = await DeviceKeys.create().createOrLoadAndAllocateOtk(
          profileId: 'P', deviceId: 'D', allocateOneTimePrekeys: 0);
      expect(bundle.signedPrekeyId, 3);
    });

    test('прежний уходит, когда есть два новее И прошло 30 дней; не больше 5',
        () async {
      await DeviceKeys.create().createOrLoadAndAllocateOtk(
          profileId: 'P', deviceId: 'D', allocateOneTimePrekeys: 0);
      for (var w = 0; w < 4; w++) {
        expect(await maintain(t0 + w * 7 * day), isTrue);
      }
      // Ротации в t0, +7, +14, +21 дней: текущий 5, прежние 4,3,2,1 отставлены
      // в t0+21, +14, +7 и t0.
      expect(previousIds(), [4, 3, 2, 1]);
      // t0+27: ротации нет, и никто не отставлен 30 дней назад.
      expect(await maintain(t0 + 27 * day), isFalse);
      expect(previousIds(), [4, 3, 2, 1]);
      // t0+28: текущий 6, прежних пять (предел).
      expect(await maintain(t0 + 28 * day), isTrue);
      expect(previousIds(), [5, 4, 3, 2, 1]);
      // t0+31: 1 отставлен 31 день назад и новее него ≥ 2 ключей — уходит.
      expect(await maintain(t0 + 31 * day), isFalse);
      expect(previousIds(), [5, 4, 3, 2], reason: '1 отставлен ≥ 30 дней назад');
      // Последний прежний держится, даже если старый: новее него только текущий.
      expect(await maintain(t0 + 400 * day), isTrue); // текущий 7
      expect(previousIds(), [6],
          reason: 'новее 6 только текущий 7; остальные старые и с двумя новее');
    });

    test('старый отправитель с пакетом двухнедельной давности доходит',
        () async {
      final (a, b, _, dbs) = await world();
      try {
        // Пакет Боба Алиса взяла раньше; Боб сменил ключ дважды.
        expect(
            await DeviceKeys.create().maintainSignedPrekey(
                profileId: 'Bprof',
                deviceId: 'Bdev',
                nowMs: t0,
                rotateEveryMs: 7 * day),
            isTrue);
        expect(
            await DeviceKeys.create().maintainSignedPrekey(
                profileId: 'Bprof',
                deviceId: 'Bdev',
                nowMs: t0 + 7 * day,
                rotateEveryMs: 7 * day),
            isTrue);
        final wire = await enc(a, 'две ротации спустя');
        expect(RatchetWireV3.tryDecode(wire)!.header['spk_id'], 1);
        expect(await dec(b, 'Bprof', 'Bdev', wire), 'две ротации спустя');
      } finally {
        for (final d in dbs) {
          await d.close();
        }
      }
    });

    test('новый SPK у контакта при том же ключе личности не рвёт сессию',
        () async {
      final (a, b, _, dbs) = await world();
      try {
        expect(await dec(b, 'Bprof', 'Bdev', await enc(a, 'раз')), 'раз');
        final aDb = dbs[0];
        expect(await aDb.sessionV3Get('Bdev'), isNotNull);
        final bBundle = await DeviceKeys.create().createOrLoadAndAllocateOtk(
            profileId: 'Bprof', deviceId: 'Bdev', allocateOneTimePrekeys: 0);
        // Алиса освежает устройства Боба и видит новый SPK.
        await aDb.contactDeviceUpsert(
          profileId: 'Bprof',
          deviceId: 'Bdev',
          identityKeyPubB64: bBundle.identityKeyPubB64,
          signedPrekeyPubB64: bBundle.signedPrekeyPubB64,
          signedPrekeySigB64: bBundle.signedPrekeySigB64,
        );
        await DeviceKeys.create().maintainSignedPrekey(
            profileId: 'Bprof',
            deviceId: 'Bdev',
            nowMs: t0,
            rotateEveryMs: 7 * day);
        final rotated = await DeviceKeys.create().createOrLoadAndAllocateOtk(
            profileId: 'Bprof', deviceId: 'Bdev', allocateOneTimePrekeys: 0);
        await aDb.contactDeviceUpsert(
          profileId: 'Bprof',
          deviceId: 'Bdev',
          identityKeyPubB64: rotated.identityKeyPubB64,
          signedPrekeyPubB64: rotated.signedPrekeyPubB64,
          signedPrekeySigB64: rotated.signedPrekeySigB64,
        );
        expect(await aDb.sessionV3Get('Bdev'), isNotNull,
            reason: 'сессия жива');
        final wire = await enc(a, 'два');
        expect(RatchetWireV3.tryDecode(wire)!.kind, isNot(RatchetWireKindV3.prekey),
            reason: 'продолжение сессии, а не новое рукопожатие');
        expect(await dec(b, 'Bprof', 'Bdev', wire), 'два');
      } finally {
        for (final d in dbs) {
          await d.close();
        }
      }
    });
  });
}
