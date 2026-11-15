// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/security/account_identity.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/security/recovery_kit.dart';
import 'package:secretly_app/security/secure_secrets.dart';
import 'package:secretly_app/security/social_recovery.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Э3: полный цикл на четырёх «устройствах» — владелец, три хранителя и новое
// устройство владельца. Сеть заменена перехватом служебных сообщений;
// каждое сообщение доставляется адресату вызовом приёма команды.

class _Net {
  final Map<String, AppController> byProfile = <String, AppController>{};
  final List<(String from, String to, String text)> log = [];

  void attach(String pid, AppController c) {
    byProfile[pid] = c;
    c.controlMessageSenderForTesting = (to, text) async {
      log.add((pid, to, text));
    };
  }

  /// Доставляет всё накопленное (и то, что породит доставка).
  Future<void> flush() async {
    while (log.isNotEmpty) {
      final batch = List.of(log);
      log.clear();
      for (final (from, to, text) in batch) {
        final target = byProfile[to];
        if (target == null) continue;
        await target.handleGuardianCommandForTesting(
          text: text,
          senderProfileId: from,
        );
      }
    }
  }
}

/// Каждому «устройству» — своя база: путь `inMemoryDatabasePath` у
/// sqflite общий для всех открытий в процессе.
late Directory _dbRoot;

Future<AppController> _device(String pid, String did) async {
  final db = await AppDb.openForTesting(path: '${_dbRoot.path}/$pid.db');
  return AppController()
    ..seedRoomRuntimeForTesting(
      db: db,
      profileId: pid,
      deviceId: did,
      crypto: DartCryptoProvider(
        Uint8List.fromList(List<int>.generate(32, (i) => i)),
      ),
    );
}

const _owner = 'owner-profile';
const _ownerDevice = 'owner-device';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Net net;
  late AppController owner;
  late String ownerAikSeed;

  setUp(() async {
    _dbRoot = await Directory.systemTemp.createTemp('secretly_social_');
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SecureSecrets.create().setProfileSecretB64(
      profileId: _owner,
      secretB64: base64Encode(List<int>.generate(32, (i) => 50 + i)),
    );
    await DeviceKeys.create().loadIdentityKeyPair(
      profileId: _owner,
      deviceId: _ownerDevice,
    );
    final pair = await Ed25519().newKeyPair();
    ownerAikSeed = base64Encode(await pair.extractPrivateKeyBytes());
    await AccountIdentity.create().importSeedB64(
      profileId: _owner,
      seedB64: ownerAikSeed,
    );
    net = _Net();
    owner = await _device(_owner, _ownerDevice);
    net.attach(_owner, owner);
    for (final g in <String>['g1', 'g2', 'g3']) {
      net.attach(g, await _device(g, '$g-device'));
    }
  });

  tearDown(() async {
    try {
      await _dbRoot.delete(recursive: true);
    } catch (_) {}
  });

  test('🔴 2 из 3 хранителей возвращают ту же личность на новое устройство',
      () async {
    final state = await owner.setupSocialRecovery(
      guardianProfileIds: <String>['g1', 'g2', 'g3'],
      threshold: 2,
    );
    expect(state.version, 1);
    expect(state.guardians.map((g) => g.status), everyElement('sent'));
    await net.flush();

    // Хранители держат доли, владелец видит подтверждения.
    for (final g in <String>['g1', 'g2', 'g3']) {
      final held = await net.byProfile[g]!.heldGuardianShares();
      expect(held.single.ownerProfileId, _owner);
      expect(held.single.threshold, 2);
    }
    final after = await owner.socialRecoveryGuardians();
    expect(after!.accepted, 3);
    expect(after.ready, isTrue);

    // Новое устройство (временный профиль) просит помощи.
    final fresh = await _device('temp-profile', 'temp-device');
    net.attach('temp-profile', fresh);
    RecoveryRequestCode? sameCode;
    RecoveryKitPlainV1? restored;
    fresh.socialRecoveryRestoreForTesting = (kit) async => restored = kit;
    final code = await fresh.startSocialRecoveryRequest();
    sameCode = await fresh.startSocialRecoveryRequest();
    expect(sameCode.nonce, code.nonce, reason: 'код не меняется до конца');

    // Первый хранитель — мало.
    await net.byProfile['g2']!.releaseGuardianShare(
      ownerProfileId: _owner,
      request: code,
    );
    await net.flush();
    expect((await fresh.socialRecoveryProgress()).received, 1);
    expect(restored, isNull);

    // Второй — достаточно.
    await net.byProfile['g3']!.releaseGuardianShare(
      ownerProfileId: _owner,
      request: code,
    );
    await net.flush();
    expect(restored, isNotNull);
    expect(restored!.profileId, _owner);
    expect(restored!.accountIdentitySeedB64, ownerAikSeed,
        reason: 'номер безопасности у собеседников не меняется');
  });

  test('🔴 чужие доли и чужой запрос отвергаются', () async {
    await owner.setupSocialRecovery(
      guardianProfileIds: <String>['g1', 'g2'],
      threshold: 2,
    );
    // Доля «от владельца», присланная кем-то другим, не принимается.
    final forged = net.log.first.$3;
    net.log.clear();
    await net.byProfile['g3']!.handleGuardianCommandForTesting(
      text: forged,
      senderProfileId: 'mallory',
    );
    expect(await net.byProfile['g3']!.heldGuardianShares(), isEmpty);

    // Доля с неверной меткой запроса не засчитывается.
    await owner.setupSocialRecovery(
      guardianProfileIds: <String>['g1', 'g2'],
      threshold: 2,
    );
    await net.flush();
    final fresh = await _device('temp-2', 'temp-2-device');
    net.attach('temp-2', fresh);
    await fresh.startSocialRecoveryRequest();
    final wrong = RecoveryRequestCode(profileId: 'temp-2', nonce: 'stale-nonce-1');
    await net.byProfile['g1']!.releaseGuardianShare(
      ownerProfileId: _owner,
      request: wrong,
    );
    await net.flush();
    expect((await fresh.socialRecoveryProgress()).received, 0);
  });

  test('отзыв: смена состава убирает долю у исключённого хранителя', () async {
    await owner.setupSocialRecovery(
      guardianProfileIds: <String>['g1', 'g2', 'g3'],
      threshold: 2,
    );
    await net.flush();
    await owner.setupSocialRecovery(
      guardianProfileIds: <String>['g1', 'g2'],
      threshold: 2,
    );
    await net.flush();
    expect(await net.byProfile['g3']!.heldGuardianShares(), isEmpty);
    final g1 = await net.byProfile['g1']!.heldGuardianShares();
    expect(g1.single.version, 2);
    await owner.clearSocialRecovery();
    await net.flush();
    expect(await owner.socialRecoveryGuardians(), isNull);
    expect(await net.byProfile['g1']!.heldGuardianShares(), isEmpty);
  });
}
