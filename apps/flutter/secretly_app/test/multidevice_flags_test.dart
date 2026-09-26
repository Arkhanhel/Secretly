// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/messages/multidevice_flags.dart';

/// Блок `multidevice` подписанного `/v1/config` (ТЗ 25.09.2026, §2).
///
/// Главное здесь — отказ к нулям: 0 везде означает «как без блока», и любая
/// неясность (нет блока, подпись не сошлась, поле срезано) обязана приводить
/// именно туда.
void main() {
  Map<String, dynamic> config(Map<String, Object> fields) => <String, dynamic>{
    'multidevice': <String, dynamic>{
      'ratchet_jump_mobile': 0,
      'ratchet_jump_desktop': 0,
      'ephemeral_online_only_percent': 0,
      'companion_warn_days': 0,
      'companion_unlink_days': 0,
      'nack_v2_percent': 0,
      'send_journal_percent': 0,
      'device_check_percent': 0,
      'issued_at_ms': 1_700_000_000_000,
      ...fields,
    },
  };

  final everythingOn = config({
    'ratchet_jump_mobile': 2000,
    'ratchet_jump_desktop': 5000,
    'ephemeral_online_only_percent': 100,
    'companion_warn_days': 30,
    'companion_unlink_days': 45,
    'nack_v2_percent': 100,
    'send_journal_percent': 100,
    'device_check_percent': 100,
  });

  void expectDark(MultideviceFlags f) {
    expect(f, MultideviceFlags.defaults);
    expect(f.ratchetJumpFor(desktop: false, builtIn: 2000), 2000);
    expect(f.ratchetJumpFor(desktop: true, builtIn: 5000), 5000);
    expect(f.ephemeralOnlineOnlyFor('dev-1'), isFalse);
    expect(f.nackV2For('dev-1'), isFalse);
    expect(f.sendJournalFor('dev-1'), isFalse);
    expect(f.deviceCheckFor('dev-1'), isFalse);
    expect(f.companionWarnDays, 0);
    expect(f.companionUnlinkDays, 0);
  }

  group('отказ к нулям', () {
    test('🔴 без проверенной подписи — как без блока', () {
      expectDark(
        MultideviceFlags.fromConfigResponse(everythingOn, verified: false),
      );
    });

    test('🔴 старый сервер без блока — как без блока', () {
      expectDark(
        MultideviceFlags.fromConfigResponse(
          <String, dynamic>{},
          verified: true,
        ),
      );
    });

    test('🔴 срезанные поля читаются как ноль, а не как «включено»', () {
      expectDark(
        MultideviceFlags.fromConfigResponse(<String, dynamic>{
          'multidevice': <String, dynamic>{'issued_at_ms': 1},
        }, verified: true),
      );
    });

    test('🔴 в сборке без ключа подпись не считается проверенной', () async {
      // Тесты собираются без SECRETLY_CONFIG_PUBLIC_KEY_B64 — как и отладка.
      expect(kConfigPublicKeyB64, isEmpty);
      expect(
        await verifyMultideviceSignature(<String, dynamic>{
          ...everythingOn,
          'multidevice_signature': 'AAAA',
        }),
        isFalse,
      );
    });

    test('🔴 пустой device_id не в доле даже при ста процентах', () {
      final f = MultideviceFlags.fromConfigResponse(
        everythingOn,
        verified: true,
      );
      expect(f.nackV2For(''), isFalse);
      expect(f.deviceCheckFor('  '), isFalse);
      expect(f.ephemeralOnlineOnlyFor(''), isFalse);
      expect(f.sendJournalFor(''), isFalse);
    });
  });

  group('значения', () {
    test('включённый блок читается целиком', () {
      final f = MultideviceFlags.fromConfigResponse(
        everythingOn,
        verified: true,
      );
      expect(f.ratchetJumpFor(desktop: false, builtIn: 200), 2000);
      expect(f.ratchetJumpFor(desktop: true, builtIn: 200), 5000);
      expect(f.companionWarnDays, 30);
      expect(f.companionUnlinkDays, 45);
      expect(f.nackV2For('dev-1'), isTrue);
      expect(f.deviceCheckFor('dev-1'), isTrue);
      expect(f.ephemeralOnlineOnlyFor('dev-1'), isTrue);
      expect(f.sendJournalFor('dev-1'), isTrue);
    });

    test('скачок ратчета зажат в 200..25 000, 0 — встроенный', () {
      MultideviceFlags jump(int mobile, int desktop) =>
          MultideviceFlags.fromConfigResponse(
            config({
              'ratchet_jump_mobile': mobile,
              'ratchet_jump_desktop': desktop,
            }),
            verified: true,
          );
      expect(jump(50, 0).ratchetJumpFor(desktop: false, builtIn: 2000), 200);
      expect(jump(50, 0).ratchetJumpFor(desktop: true, builtIn: 5000), 5000);
      expect(
        jump(0, 999999).ratchetJumpFor(desktop: true, builtIn: 5000),
        25000,
      );
      expect(jump(-7, 3000).ratchetJumpFor(desktop: false, builtIn: 2000), 2000);
      expect(jump(-7, 3000).ratchetJumpFor(desktop: true, builtIn: 5000), 3000);
    });

    test('доли и дни зажимаются', () {
      final f = MultideviceFlags.fromConfigResponse(
        config({
          'nack_v2_percent': 999,
          'device_check_percent': -5,
          'companion_warn_days': -1,
          'companion_unlink_days': 100000,
        }),
        verified: true,
      );
      expect(f.nackV2Percent, 100);
      expect(f.deviceCheckPercent, 0);
      expect(f.companionWarnDays, 0);
      expect(f.companionUnlinkDays, 365);
    });
  });

  group('доля раскатки', () {
    test('🔴 соль закреплена: корзины не меняются от сборки к сборке', () {
      // Сменится формула — устройства перетасуются между группами посреди
      // раскатки. Числа посчитаны независимо (sha256 в Python).
      expect(MultideviceFlags.rolloutBucket('nack_v2_percent', 'device-1'), 52);
      expect(
        MultideviceFlags.rolloutBucket('device_check_percent', 'device-1'),
        84,
      );
      expect(
        MultideviceFlags.rolloutBucket(
          'ephemeral_online_only_percent',
          'device-1',
        ),
        3,
      );
      expect(
        MultideviceFlags.rolloutBucket(
          'send_journal_percent',
          'cfd47563-ac76-40a7',
        ),
        99,
      );
    });

    test('решение для устройства устойчиво', () {
      final f = MultideviceFlags.fromConfigResponse(
        config({'nack_v2_percent': 37}),
        verified: true,
      );
      final first = f.nackV2For('device-abc');
      for (var i = 0; i < 50; i++) {
        expect(f.nackV2For('device-abc'), first);
      }
    });

    test('доля примерно равна заданному проценту', () {
      final f = MultideviceFlags.fromConfigResponse(
        config({'device_check_percent': 25}),
        verified: true,
      );
      var hits = 0;
      const n = 4000;
      for (var i = 0; i < n; i++) {
        if (f.deviceCheckFor('device-$i')) hits++;
      }
      final share = hits / n * 100;
      expect(share, greaterThan(20), reason: 'доля вышла $share%');
      expect(share, lessThan(30), reason: 'доля вышла $share%');
    });

    test('🔴 расширение доли не выключает уже включённых', () {
      final small = MultideviceFlags.fromConfigResponse(
        config({'nack_v2_percent': 10}),
        verified: true,
      );
      final big = MultideviceFlags.fromConfigResponse(
        config({'nack_v2_percent': 60}),
        verified: true,
      );
      for (var i = 0; i < 500; i++) {
        final id = 'device-$i';
        if (small.nackV2For(id)) {
          expect(big.nackV2For(id), isTrue, reason: '$id выпал');
        }
      }
    });

    test('у каждого поля своя соль — не одни и те же устройства', () {
      final f = MultideviceFlags.fromConfigResponse(
        config({'nack_v2_percent': 10, 'device_check_percent': 10}),
        verified: true,
      );
      final nack = <String>{};
      final check = <String>{};
      for (var i = 0; i < 2000; i++) {
        final id = 'device-$i';
        if (f.nackV2For(id)) nack.add(id);
        if (f.deviceCheckFor(id)) check.add(id);
      }
      expect(nack, isNotEmpty);
      expect(nack.intersection(check).length, lessThan(nack.length ~/ 2));
    });
  });

  test('🔴 подписываемая строка совпадает с серверной формой', () {
    // Та же строка закреплена в Rust: multidevice_signing_message_is_byte_stable.
    expect(
      multideviceSigningMessage(
        ratchetJumpMobile: 2000,
        ratchetJumpDesktop: 5000,
        ephemeralOnlineOnlyPercent: 10,
        companionWarnDays: 30,
        companionUnlinkDays: 45,
        nackV2Percent: 50,
        sendJournalPercent: 0,
        deviceCheckPercent: 100,
        issuedAtMs: 42,
      ),
      'secretly-multidevice-v1|2000|5000|10|30|45|50|0|100|42',
    );
  });

  test('контроллер применяет блок на обоих путях обновления конфига', () {
    final src = File('lib/app/app_controller.dart').readAsStringSync();
    final pattern = RegExp(
      r'_applyHandshakeAuthSwitch\(repo\);\s*_applyMultideviceFlags\(repo\);',
    );
    expect(pattern.allMatches(src).length, 2);
  });
}
