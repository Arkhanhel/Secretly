// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/recovery_kit.dart';
import 'package:secretly_app/security/social_recovery.dart';

// Э3: социальное восстановление без приложения — криптография и форматы.

RecoveryKitPlainV1 _kit() => RecoveryKitPlainV1(
  profileId: 'owner-profile-1',
  profileSecretB64: base64Encode(List<int>.generate(32, (i) => i)),
  deviceId: 'device-1',
  deviceKeysMaterialJson: jsonEncode(<String, Object?>{
    'identity_seed_b64': base64Encode(List<int>.filled(32, 7)),
    'signed_prekey_seed_b64': base64Encode(List<int>.filled(32, 9)),
    'next_otk_id': 1,
    'otk_seed_by_id': <String, String>{},
  }),
  serverBinding: 'keys=https://k;relay=https://r',
  accountIdentitySeedB64: base64Encode(List<int>.generate(32, (i) => 200 - i)),
);

List<GuardianRelease> _releases(SocialRecoverySetup s, List<int> idx) => idx
    .map(
      (i) => GuardianRelease(
        requestNonce: 'nonce-abcdef',
        ownerProfileId: s.ownerProfileId,
        version: s.version,
        threshold: s.threshold,
        shareB64: s.sharesB64[i],
        blobB64: s.blobB64,
      ),
    )
    .toList();

void main() {
  test('🔴 два хранителя из трёх возвращают личность целиком, с ключом AIK',
      () async {
    final setup = await SocialRecovery.createSetup(
      kit: _kit(),
      threshold: 2,
      guardians: 3,
      version: 1,
      safeBackupAutoPassword: 'auto-pass',
      random: Random(1),
    );
    expect(setup.guardians, 3);
    for (final pair in <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[0, 2],
    ]) {
      final result = await SocialRecovery.recover(_releases(setup, pair));
      expect(result.kit.profileId, 'owner-profile-1');
      expect(result.kit.profileSecretB64, _kit().profileSecretB64);
      expect(result.kit.accountIdentitySeedB64, _kit().accountIdentitySeedB64);
      expect(result.safeBackupAutoPassword, 'auto-pass');
    }
  });

  test('🔴 одного хранителя мало', () async {
    final setup = await SocialRecovery.createSetup(
      kit: _kit(),
      threshold: 2,
      guardians: 3,
      version: 1,
    );
    expect(
      () => SocialRecovery.recover(_releases(setup, <int>[2])),
      throwsA(isA<SocialRecoveryException>().having((e) => e.code, 'code', 'not_enough_shares')),
    );
    // Одна и та же доля дважды — тоже одна доля.
    expect(
      () => SocialRecovery.recover(_releases(setup, <int>[1, 1])),
      throwsA(isA<SocialRecoveryException>()),
    );
  });

  test('🔴 подмена доли или блока обнаруживается', () async {
    final setup = await SocialRecovery.createSetup(
      kit: _kit(),
      threshold: 2,
      guardians: 3,
      version: 1,
    );
    final good = _releases(setup, <int>[0, 1]);
    final share = base64Decode(good[1].shareB64);
    share[5] ^= 0x01;
    final forged = <GuardianRelease>[
      good[0],
      GuardianRelease(
        requestNonce: 'nonce-abcdef',
        ownerProfileId: setup.ownerProfileId,
        version: 1,
        threshold: 2,
        shareB64: base64Encode(share),
        blobB64: setup.blobB64,
      ),
    ];
    expect(
      () => SocialRecovery.recover(forged),
      throwsA(isA<SocialRecoveryException>().having((e) => e.code, 'code', 'auth_failed')),
    );
    // Чужая версия — доли не смешиваются.
    final other = await SocialRecovery.createSetup(
      kit: _kit(),
      threshold: 2,
      guardians: 3,
      version: 2,
    );
    expect(
      () => SocialRecovery.recover(<GuardianRelease>[
        good[0],
        _releases(other, <int>[1]).single,
      ]),
      throwsA(isA<SocialRecoveryException>().having((e) => e.code, 'code', 'mixed_sets')),
    );
  });

  test('блок привязан к владельцу и версии (AAD)', () async {
    final setup = await SocialRecovery.createSetup(
      kit: _kit(),
      threshold: 2,
      guardians: 2,
      version: 1,
    );
    final swapped = _releases(setup, <int>[0, 1])
        .map(
          (r) => GuardianRelease(
            requestNonce: r.requestNonce,
            ownerProfileId: r.ownerProfileId,
            version: 7,
            threshold: r.threshold,
            shareB64: r.shareB64,
            blobB64: r.blobB64,
          ),
        )
        .toList();
    expect(
      () => SocialRecovery.recover(swapped),
      throwsA(isA<SocialRecoveryException>().having((e) => e.code, 'code', 'auth_failed')),
    );
  });

  test('параметры: от 2 до 5 хранителей, порог не меньше 2', () async {
    for (final (t, n) in <(int, int)>[(1, 3), (2, 1), (3, 2), (2, 6)]) {
      expect(
        () => SocialRecovery.createSetup(kit: _kit(), threshold: t, guardians: n, version: 1),
        throwsArgumentError,
        reason: 't=$t n=$n',
      );
    }
  });

  test('код запроса: кодирование, разбор, мусор отвергается', () {
    final code = RecoveryRequestCode.generate('temp-profile-9', random: Random(3));
    final parsed = RecoveryRequestCode.tryParse(code.encode());
    expect(parsed?.profileId, 'temp-profile-9');
    expect(parsed?.nonce, code.nonce);
    for (final bad in <String>[
      'secretly://recover#',
      'secretly://recover#onlypid',
      'secretly://proxy#a.bbbbbbbbbb',
      'https://recover#a.bbbbbbbbbb',
      'secretly://recover#bad pid.bbbbbbbbbb',
      'secretly://recover#pid.short',
    ]) {
      expect(RecoveryRequestCode.tryParse(bad), isNull, reason: bad);
    }
  });

  test('проверочные слова: одинаковы для одного кода и разные для разных', () async {
    final a = await SocialRecovery.checkWords('secretly://recover#p.aaaaaaaaaaaa');
    final a2 = await SocialRecovery.checkWords('secretly://recover#p.aaaaaaaaaaaa');
    final b = await SocialRecovery.checkWords('secretly://recover#p.aaaaaaaaaaab');
    expect(a, a2);
    expect(a.length, 4);
    expect(a, isNot(b));
  });

  test('разбор доли хранителя отвергает мусор и пределы', () {
    final ok = GuardianShare.tryParse(<String, Object?>{
      'owner_profile_id': 'o',
      'version': 1,
      't': 2,
      'n': 3,
      'share_b64': 'AA==',
      'blob_b64': 'AA==',
    });
    expect(ok, isNotNull);
    for (final bad in <Map<String, Object?>>[
      <String, Object?>{'owner_profile_id': '', 'version': 1, 't': 2, 'n': 3, 'share_b64': 'A', 'blob_b64': 'A'},
      <String, Object?>{'owner_profile_id': 'o', 'version': 0, 't': 2, 'n': 3, 'share_b64': 'A', 'blob_b64': 'A'},
      <String, Object?>{'owner_profile_id': 'o', 'version': 1, 't': 1, 'n': 3, 'share_b64': 'A', 'blob_b64': 'A'},
      <String, Object?>{'owner_profile_id': 'o', 'version': 1, 't': 2, 'n': 9, 'share_b64': 'A', 'blob_b64': 'A'},
    ]) {
      expect(GuardianShare.tryParse(bad), isNull, reason: '$bad');
    }
    expect(
      GuardianRelease.tryParse(<String, Object?>{
        ...ok!.toJson(),
        'nonce': '',
      }),
      isNull,
    );
  });
}
