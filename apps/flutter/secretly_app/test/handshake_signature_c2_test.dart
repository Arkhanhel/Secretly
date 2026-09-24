// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ratchet/handshake_signature.dart';
import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/ratchet/wire_v3.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';

// С-2 (24.09.2026): рукопожатие не доказывает, кто его начал.
//
// Сервер (или тот, кто им завладел) знает публичную связку получателя и может
// начать сессию от имени любого устройства. Эти тесты ставят именно этот опыт:
// «сервер» — отдельный менеджер со СВОЕЙ базой и БЕЗ ключа Алисы.

class _FixedBundleKeysClient extends KeysClient {
  _FixedBundleKeysClient(this._devices)
      : super(baseUrl: Uri.parse('https://example.com'));

  final List<Map<String, Object?>> _devices;

  @override
  Future<List<Map<String, Object?>>> fetchBundle(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async =>
      _devices;
}

Map<String, Object?> _deviceMap(
  String deviceId,
  DeviceKeyBundleV1 b, {
  int otkIndex = 0,
}) =>
    <String, Object?>{
      'device_id': deviceId,
      'identity_key_pub_b64': b.identityKeyPubB64,
      'signed_prekey_pub_b64': b.signedPrekeyPubB64,
      'signed_prekey_sig_b64': b.signedPrekeySigB64,
      'one_time_prekey': b.oneTimePrekeys.length > otkIndex
          ? b.oneTimePrekeys[otkIndex]
          : null,
    };

Future<Uint8List> _enc(
  RatchetSessionManagerV3 mgr, {
  required String selfDeviceId,
  required String peerProfileId,
  required String peerDeviceId,
  required String text,
  String? selfProfileId,
}) =>
    mgr.encryptToPeer(
      selfDeviceId: selfDeviceId,
      peerProfileId: peerProfileId,
      peerDeviceId: peerDeviceId,
      plaintext: Uint8List.fromList(utf8.encode(text)),
      selfProfileId: selfProfileId,
    );

Future<String?> _tryDec(
  RatchetSessionManagerV3 mgr, {
  required String selfProfileId,
  required String selfDeviceId,
  required Uint8List wire,
}) async {
  try {
    return await _dec(mgr,
        selfProfileId: selfProfileId, selfDeviceId: selfDeviceId, wire: wire);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _header(Uint8List wire) =>
    RatchetWireV3.tryDecode(wire)!.header;

/// Алиса, Боб и «сервер». У сервера своя база и свежий одноразовый ключ Боба
/// из связки — то, что keys отдаёт любому. Ключа личности Алисы у него нет.
class _World {
  _World(this.a, this.b, this.m, this.aDb, this.bDb, this.mDb, this.aBundle,
      this.bBundle);

  final RatchetSessionManagerV3 a;
  final RatchetSessionManagerV3 b;
  final RatchetSessionManagerV3 m;
  final AppDb aDb;
  final AppDb bDb;
  final AppDb mDb;
  final DeviceKeyBundleV1 aBundle;
  final DeviceKeyBundleV1 bBundle;

  static Future<_World> create({bool pinAlice = true}) async {
    // 🔴 У каждого СВОЙ файл базы. `openForTesting()` без пути открывает ОДНУ
    // И ТУ ЖЕ базу в памяти (sqflite кэширует открытые базы по пути): тогда
    // «сервер» видит сессию Алисы, шлёт обычный провод вместо рукопожатия, и
    // опыт ничего не доказывает. На этом споткнулась первая проба 24.09.
    final dir = Directory.systemTemp.createTempSync('c2hs');
    final aDb = await AppDb.openForTesting(path: '${dir.path}/a.db');
    final bDb = await AppDb.openForTesting(path: '${dir.path}/b.db');
    final mDb = await AppDb.openForTesting(path: '${dir.path}/m.db');
    final keys = DeviceKeys.create();
    final aBundle = await keys.createOrLoadAndAllocateOtk(
      profileId: 'Aprof',
      deviceId: 'Adev',
      allocateOneTimePrekeys: 8,
    );
    final bBundle = await keys.createOrLoadAndAllocateOtk(
      profileId: 'Bprof',
      deviceId: 'Bdev',
      allocateOneTimePrekeys: 8,
    );
    final a = RatchetSessionManagerV3(
      db: aDb,
      deviceKeys: DeviceKeys.create(),
      keysClient: _FixedBundleKeysClient([_deviceMap('Bdev', bBundle)]),
    );
    final b = RatchetSessionManagerV3(
      db: bDb,
      deviceKeys: DeviceKeys.create(),
      keysClient: _FixedBundleKeysClient([_deviceMap('Adev', aBundle)]),
    );
    final m = RatchetSessionManagerV3(
      db: mDb,
      deviceKeys: DeviceKeys.create(),
      keysClient:
          _FixedBundleKeysClient([_deviceMap('Bdev', bBundle, otkIndex: 1)]),
    );
    // Боб знает Алису: её ключ закреплён — так делает приложение, обновляя
    // список устройств контакта.
    if (pinAlice) {
      await bDb.contactDeviceUpsert(
        profileId: 'Aprof',
        deviceId: 'Adev',
        identityKeyPubB64: aBundle.identityKeyPubB64,
        signedPrekeyPubB64: aBundle.signedPrekeyPubB64,
        signedPrekeySigB64: aBundle.signedPrekeySigB64,
      );
    }
    return _World(a, b, m, aDb, bDb, mDb, aBundle, bBundle);
  }

  /// Нормальная переписка в обе стороны. [aSigns] — Алиса на новой сборке.
  Future<void> converse({required bool aSigns}) async {
    final w1 = await _enc(a,
        selfDeviceId: 'Adev',
        peerProfileId: 'Bprof',
        peerDeviceId: 'Bdev',
        text: 'hi-B',
        selfProfileId: aSigns ? 'Aprof' : null);
    expect(await _dec(b, selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: w1),
        'hi-B');
    final w2 = await _enc(b,
        selfDeviceId: 'Bdev',
        peerProfileId: 'Aprof',
        peerDeviceId: 'Adev',
        text: 'hi-A',
        selfProfileId: 'Bprof');
    expect(await _dec(a, selfProfileId: 'Aprof', selfDeviceId: 'Adev', wire: w2),
        'hi-A');
  }

  /// Подделка от имени Алисы. [signWithOwnKey] — сервер подписывает своим
  /// ключом, выдавая его за ключ Алисы.
  Future<Uint8List> forge({bool signWithOwnKey = false}) async {
    if (signWithOwnKey) {
      // Свой материал под «профилем сервера» для номера устройства Алисы.
      await DeviceKeys.create().createOrLoadAndAllocateOtk(
        profileId: 'Mprof',
        deviceId: 'Adev',
        allocateOneTimePrekeys: 1,
      );
    }
    return _enc(m,
        selfDeviceId: 'Adev',
        peerProfileId: 'Bprof',
        peerDeviceId: 'Bdev',
        text: 'forged',
        selfProfileId: signWithOwnKey ? 'Mprof' : null);
  }

  Future<void> close() async {
    await aDb.close();
    await bDb.close();
    await mDb.close();
  }
}

Future<String> _dec(
  RatchetSessionManagerV3 mgr, {
  required String selfProfileId,
  required String selfDeviceId,
  required Uint8List wire,
}) async {
  final plain = await mgr.decryptFromWire(
    selfProfileId: selfProfileId,
    selfDeviceId: selfDeviceId,
    wireBytes: wire,
  );
  return utf8.decode(plain);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorageState = <String, String>{};

  setUp(() {
    secureStorageState.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final args = Map<Object?, Object?>.from(
        call.arguments as Map<Object?, Object?>? ?? const {},
      );
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return key == null ? null : secureStorageState[key];
        case 'write':
          if (key != null) {
            secureStorageState[key] = (args['value'] as String?) ?? '';
          }
          return null;
        case 'delete':
          if (key != null) secureStorageState.remove(key);
          return null;
        case 'readAll':
          return Map<String, String>.from(secureStorageState);
        case 'deleteAll':
          secureStorageState.clear();
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });


  test('Т-1 ⚑ сервер без ключа Алисы не подменяет сессию и не читает ответ',
      () async {
    final w = await _World.create();
    try {
      await w.converse(aSigns: true);
      final forged = await w.forge();
      expect(RatchetWireV3.tryDecode(forged)!.kind, RatchetWireKindV3.prekey);
      expect(_header(forged)[HandshakeSignature.headerField], isNull);

      await expectLater(
        _dec(w.b, selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: forged),
        throwsA(isA<HandshakeAuthRejectedException>()),
      );

      // Сессия Боба с Алисой цела: ответ читает Алиса, а не сервер.
      final reply = await _enc(w.b,
          selfDeviceId: 'Bdev',
          peerProfileId: 'Aprof',
          peerDeviceId: 'Adev',
          text: 'secret reply',
          selfProfileId: 'Bprof');
      expect(
          await _tryDec(w.m,
              selfProfileId: 'Mprof', selfDeviceId: 'Adev', wire: reply),
          isNull);
      expect(
          await _dec(w.a,
              selfProfileId: 'Aprof', selfDeviceId: 'Adev', wire: reply),
          'secret reply');
      expect(await w.bDb.localKvCounterGet('hs_auth.ok'), 1);
      expect(await w.bDb.localKvCounterGet('hs_auth.rejected'), 1);
    } finally {
      await w.close();
    }
  });

  test('Т-2 ⚑ подпись чужим ключом от имени Алисы отвергается', () async {
    final w = await _World.create();
    try {
      await w.converse(aSigns: true);
      final forged = await w.forge(signWithOwnKey: true);
      expect(_header(forged)[HandshakeSignature.headerField], isNotNull);
      await expectLater(
        _dec(w.b, selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: forged),
        throwsA(isA<HandshakeAuthRejectedException>()),
      );
      expect(await w.bDb.localKvCounterGet('hs_auth.bad'), 1);
    } finally {
      await w.close();
    }
  });

  test(
      'Т-3 ⚑ давняя переписка без новых рукопожатий: метка в обычном '
      'сообщении делает Алису доказанной', () async {
    final w = await _World.create();
    try {
      // Сессию открыла ещё старая сборка Алисы — без подписи.
      await w.converse(aSigns: false);
      expect(await w.bDb.handshakeSigCapableKey('Adev'), isNull);

      // Алиса обновилась: обычное сообщение несёт метку `hsv`.
      final w3 = await _enc(w.a,
          selfDeviceId: 'Adev',
          peerProfileId: 'Bprof',
          peerDeviceId: 'Bdev',
          text: 'after update',
          selfProfileId: 'Aprof');
      expect(_header(w3)[HandshakeSignature.capabilityField], 1);
      expect(
          await _dec(w.b, selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: w3),
          'after update');
      expect(await w.bDb.handshakeSigCapableKey('Adev'),
          w.aBundle.identityKeyPubB64);

      final forged = await w.forge();
      await expectLater(
        _dec(w.b, selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: forged),
        throwsA(isA<HandshakeAuthRejectedException>()),
      );
    } finally {
      await w.close();
    }
  });

  test(
      'Т-4 не сломать: собеседник на старой сборке — всё принимается, как '
      'до С-2, и только считается', () async {
    final w = await _World.create();
    try {
      await w.converse(aSigns: false);
      // Остаточный пробел, записанный в ТЗ: пока Алиса не доказала подпись,
      // неподписанное рукопожатие от её имени не отличить от её собственного.
      final forged = await w.forge();
      expect(
          await _dec(w.b,
              selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: forged),
          'forged');
      expect(await w.bDb.localKvCounterGet('hs_auth.missing'), 2);
      expect(await w.bDb.localKvCounterGet('hs_auth.rejected'), 0);
    } finally {
      await w.close();
    }
  });

  test('Т-5 повтор рукопожатия (Ш-4) несёт ту же подпись и принимается',
      () async {
    final w = await _World.create();
    kPrekeyUntilConfirmedSend = true;
    try {
      final first = await _enc(w.a,
          selfDeviceId: 'Adev',
          peerProfileId: 'Bprof',
          peerDeviceId: 'Bdev',
          text: 'lost',
          selfProfileId: 'Aprof');
      // Первое сообщение потерялось; второе уходит повтором рукопожатия.
      final repeat = await _enc(w.a,
          selfDeviceId: 'Adev',
          peerProfileId: 'Bprof',
          peerDeviceId: 'Bdev',
          text: 'second',
          selfProfileId: 'Aprof');
      expect(RatchetWireV3.tryDecode(repeat)!.kind, RatchetWireKindV3.prekey);
      final sig = _header(first)[HandshakeSignature.headerField];
      expect(sig, isNotNull);
      expect(_header(repeat)[HandshakeSignature.headerField], sig);
      expect(
          await _dec(w.b,
              selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: repeat),
          'second');
      expect(await w.bDb.localKvCounterGet('hs_auth.ok'), 1);
    } finally {
      kPrekeyUntilConfirmedSend = false;
      await w.close();
    }
  });

  test('Т-6 выключатель с сервера снимает отказ, но не счёт', () async {
    final w = await _World.create();
    try {
      await w.converse(aSigns: true);
      await w.bDb.localKvSet(AppDb.kvHandshakeAuthEnforceDisabled, '1');
      final forged = await w.forge();
      expect(
          await _dec(w.b,
              selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: forged),
          'forged');
      expect(await w.bDb.localKvCounterGet('hs_auth.missing_switch_off'), 1);
      expect(await w.bDb.localKvCounterGet('hs_auth.rejected'), 0);
    } finally {
      await w.close();
    }
  });

  test(
      'Т-7 не сломать: незнакомое устройство с подписью принимается; '
      'смена ключа снимает признак', () async {
    // Боб не знает Алису вовсе.
    final w = await _World.create(pinAlice: false);
    try {
      final w1 = await _enc(w.a,
          selfDeviceId: 'Adev',
          peerProfileId: 'Bprof',
          peerDeviceId: 'Bdev',
          text: 'first contact',
          selfProfileId: 'Aprof');
      expect(
          await _dec(w.b, selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: w1),
          'first contact');
      expect(await w.bDb.localKvCounterGet('hs_auth.unknown_signed'), 1);
      expect(await w.bDb.handshakeSigCapableKey('Adev'), isNull);

      // Признак привязан к ключу: закреплён другой ключ — признак не действует.
      await w.bDb.handshakeSigCapableSet('Adev', 'b2xkLWtleQ==');
      await w.bDb.contactDeviceUpsert(
        profileId: 'Aprof',
        deviceId: 'Adev',
        identityKeyPubB64: w.aBundle.identityKeyPubB64,
        signedPrekeyPubB64: w.aBundle.signedPrekeyPubB64,
        signedPrekeySigB64: w.aBundle.signedPrekeySigB64,
      );
      final forged = await w.forge();
      expect(
          await _dec(w.b,
              selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: forged),
          'forged');
    } finally {
      await w.close();
    }
  });

  test(
      'Т-9 не сломать: законная смена ключа под прежним номером устройства — '
      'отказ, пока закреплён старый ключ, и приём того же конверта после '
      '«ключ сменился»', () async {
    final w = await _World.create();
    try {
      await w.converse(aSigns: true);
      expect(await w.bDb.handshakeSigCapableKey('Adev'),
          w.aBundle.identityKeyPubB64);

      // Связка ключей ОС Алисы стёрлась, номер устройства уцелел: приложение
      // создало НОВЫЙ ключ личности под тем же номером и потеряло сессии.
      final keys = DeviceKeys.create();
      await keys.deleteMaterial(profileId: 'Aprof', deviceId: 'Adev');
      final rotated = await keys.createOrLoadAndAllocateOtk(
        profileId: 'Aprof',
        deviceId: 'Adev',
        allocateOneTimePrekeys: 4,
      );
      expect(rotated.identityKeyPubB64, isNot(w.aBundle.identityKeyPubB64));
      final dir = Directory.systemTemp.createTempSync('c2rot');
      final a2Db = await AppDb.openForTesting(path: '${dir.path}/a2.db');
      final a2 = RatchetSessionManagerV3(
        db: a2Db,
        deviceKeys: DeviceKeys.create(),
        keysClient: _FixedBundleKeysClient([_deviceMap('Bdev', w.bBundle,
            otkIndex: 2)]),
      );
      try {
        final wire = await _enc(a2,
            selfDeviceId: 'Adev',
            peerProfileId: 'Bprof',
            peerDeviceId: 'Bdev',
            text: 'after rotation',
            selfProfileId: 'Aprof');
        expect(_header(wire)[HandshakeSignature.headerField], isNotNull);

        // У Боба закреплён старый ключ, и Алиса доказанная: отказ.
        await expectLater(
          _dec(w.b, selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: wire),
          throwsA(isA<HandshakeAuthRejectedException>()),
        );

        // Приложение перечитало устройства Алисы с сервера ключей и приняло
        // смену ключа — так делает `_cacheRecipientDeviceStatuses` (с
        // предупреждением «код безопасности изменился»).
        final r = await w.bDb.contactDeviceUpsert(
          profileId: 'Aprof',
          deviceId: 'Adev',
          identityKeyPubB64: rotated.identityKeyPubB64,
          signedPrekeyPubB64: rotated.signedPrekeyPubB64,
          signedPrekeySigB64: rotated.signedPrekeySigB64,
          allowIdentityRotation: true,
        );
        expect(r.identityRotated, isTrue);

        // Тот же конверт из карантина теперь расшифровывается: отказ не
        // тронул ни сессию, ни одноразовый ключ Боба.
        expect(
            await _dec(w.b,
                selfProfileId: 'Bprof', selfDeviceId: 'Bdev', wire: wire),
            'after rotation');
        expect(await w.bDb.handshakeSigCapableKey('Adev'),
            rotated.identityKeyPubB64);
      } finally {
        await a2Db.close();
      }
    } finally {
      await w.close();
    }
  });

  test('Т-8 подписываемые байты: контекст, длины, порча любого поля', () async {
    final kp = await Ed25519().newKeyPair();
    final pub = base64Encode((await kp.extractPublicKey()).bytes);
    Uint8List msg({
      String s = 'Adev',
      String r = 'Bdev',
      int eph = 1,
      int spk = 2,
      int spkId = 1,
      int? otk = 5,
    }) =>
        HandshakeSignature.message(
          senderDeviceId: s,
          recipientDeviceId: r,
          senderEphemeralPub: List<int>.filled(32, eph),
          recipientSignedPrekeyPub: List<int>.filled(32, spk),
          signedPrekeyId: spkId,
          oneTimePrekeyId: otk,
        );
    final base = msg();
    expect(base.length, greaterThan(32));
    expect(utf8.decode(base.sublist(0, HandshakeSignature.context.length)),
        HandshakeSignature.context);
    final sig =
        await HandshakeSignature.sign(identityKeyPair: kp, message: base);
    expect(
        await HandshakeSignature.verify(
            identityKeyPubB64: pub, signatureB64: sig, message: base),
        isTrue);
    for (final tampered in [
      msg(s: 'Xdev'),
      msg(r: 'Xdev'),
      msg(eph: 9),
      msg(spk: 9),
      msg(spkId: 2),
      msg(otk: null),
      msg(otk: 6),
      // Склейка полей не должна давать те же байты.
      msg(s: 'Ad', r: 'evBdev'),
    ]) {
      expect(
          await HandshakeSignature.verify(
              identityKeyPubB64: pub, signatureB64: sig, message: tampered),
          isFalse);
    }
    expect(
        await HandshakeSignature.verify(
            identityKeyPubB64: 'not-base64', signatureB64: sig, message: base),
        isFalse);
  });
}
