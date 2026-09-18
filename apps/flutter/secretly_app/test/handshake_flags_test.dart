// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/messages/handshake_flags.dart';

/// Серверный переключатель отправки повторного prekey (Э-4).
///
/// Тут проверяется главным образом ОТКАЗ В ЗАКРЫТУЮ: этот флаг — единственный
/// ключ от поведения, которое на стороне получателя может сбросить сессию,
/// поэтому любая неясность обязана оставлять отправку спящей.
void main() {
  Map<String, dynamic> config({
    bool enabled = true,
    int percent = 100,
    int issuedAtMs = 1_700_000_000_000,
  }) => <String, dynamic>{
    'handshake': <String, dynamic>{
      'prekey_until_confirmed_send_enabled': enabled,
      'prekey_until_confirmed_send_percent': percent,
      'issued_at_ms': issuedAtMs,
    },
  };

  group('отказ в закрытую', () {
    /// 🔴 Непроверенная подпись — это НЕТ. Не «оставить как было», а именно
    /// нет: конфиг, переставший верифицироваться, обязан вернуть отправку в
    /// спящее состояние.
    test('🔴 без проверенной подписи отправка спит', () {
      final f = HandshakeFlags.fromConfigResponse(config(), verified: false);
      expect(f, HandshakeFlags.defaults);
      expect(f.allowsSendFor('dev-1'), isFalse);
    });

    test('🔴 старый сервер без блока — отправка спит', () {
      final f = HandshakeFlags.fromConfigResponse(
        <String, dynamic>{},
        verified: true,
      );
      expect(f.allowsSendFor('dev-1'), isFalse);
    });

    test('🔴 срезанное поле читается как ноль, а не как «включено»', () {
      final f = HandshakeFlags.fromConfigResponse(<String, dynamic>{
        'handshake': <String, dynamic>{'issued_at_ms': 1},
      }, verified: true);
      expect(f.prekeyUntilConfirmedSendEnabled, isFalse);
      expect(f.prekeyUntilConfirmedSendPercent, 0);
    });

    test('🔴 пустой device_id не попадает в долю', () {
      final f = HandshakeFlags.fromConfigResponse(
        config(percent: 100),
        verified: true,
      );
      expect(f.allowsSendFor(''), isFalse,
          reason: '«неизвестно» нельзя считать за «включено»');
    });

    test('включено, но доля ноль — никому', () {
      final f = HandshakeFlags.fromConfigResponse(
        config(percent: 0),
        verified: true,
      );
      expect(f.prekeyUntilConfirmedSendEnabled, isTrue);
      expect(f.allowsSendFor('dev-1'), isFalse);
    });

    test('доля есть, но выключатель выключен — никому', () {
      final f = HandshakeFlags.fromConfigResponse(
        config(enabled: false, percent: 100),
        verified: true,
      );
      expect(f.allowsSendFor('dev-1'), isFalse);
    });
  });

  group('доля раскатки', () {
    /// 🔴 Главное свойство: одно устройство при одной доле всегда получает
    /// один и тот же ответ. Иначе поведение мигало бы от опроса к опросу, и
    /// разобраться в поломке было бы нечем.
    test('🔴 решение для устройства не меняется между вызовами', () {
      final f = HandshakeFlags.fromConfigResponse(
        config(percent: 37),
        verified: true,
      );
      final first = f.allowsSendFor('device-abc');
      for (var i = 0; i < 50; i++) {
        expect(f.allowsSendFor('device-abc'), first);
      }
    });

    test('100 процентов — всем, включая любой device_id', () {
      final f = HandshakeFlags.fromConfigResponse(
        config(percent: 100),
        verified: true,
      );
      for (final id in ['a', 'b', 'zzz', 'cfd47563-ac76-40a7']) {
        expect(f.allowsSendFor(id), isTrue);
      }
    });

    /// Доля должна быть примерно долей, иначе «включить 10%» не значит ничего.
    test('доля попадает примерно в заданный процент', () {
      final f = HandshakeFlags.fromConfigResponse(
        config(percent: 25),
        verified: true,
      );
      var hits = 0;
      const n = 4000;
      for (var i = 0; i < n; i++) {
        if (f.allowsSendFor('device-$i')) hits++;
      }
      final share = hits / n * 100;
      expect(share, greaterThan(20), reason: 'доля вышла $share%');
      expect(share, lessThan(30), reason: 'доля вышла $share%');
    });

    /// Расширение доли не должно ВЫКЛЮЧАТЬ тех, кто уже был включён: иначе
    /// расширение раскатки стало бы одновременно и откатом для части людей.
    test('🔴 расширение доли не выключает уже включённых', () {
      final small = HandshakeFlags.fromConfigResponse(
        config(percent: 10),
        verified: true,
      );
      final big = HandshakeFlags.fromConfigResponse(
        config(percent: 60),
        verified: true,
      );
      for (var i = 0; i < 500; i++) {
        final id = 'device-$i';
        if (small.allowsSendFor(id)) {
          expect(big.allowsSendFor(id), isTrue,
              reason: '$id выпал при расширении доли');
        }
      }
    });

    test('сервер прислал больше ста — зажимается', () {
      final f = HandshakeFlags.fromConfigResponse(
        config(percent: 999),
        verified: true,
      );
      expect(f.prekeyUntilConfirmedSendPercent, 100);
    });
  });

  /// 🔴 Подписываемая строка обязана совпадать с Rust побайтово. Разойдись
  /// они — подпись перестанет сходиться, и флаг молча замрёт навсегда.
  test('🔴 подписываемая строка совпадает с серверной формой', () {
    expect(
      handshakeSigningMessage(
        prekeyUntilConfirmedSendEnabled: true,
        prekeyUntilConfirmedSendPercent: 25,
        issuedAtMs: 1_700_000_000_000,
      ),
      'secretly-handshake-v1|true|25|1700000000000',
    );
    expect(
      handshakeSigningMessage(
        prekeyUntilConfirmedSendEnabled: false,
        prekeyUntilConfirmedSendPercent: 0,
        issuedAtMs: 1,
      ),
      'secretly-handshake-v1|false|0|1',
    );
  });
}
