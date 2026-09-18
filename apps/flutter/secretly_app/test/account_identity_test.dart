// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/account_identity.dart';

// Слой 2 «номера безопасности»: ключ личности АККАУНТА и сертификаты устройств
// (08.08.2026).
//
// Причина работы: номер считался от identity-ключа УСТРОЙСТВА, поэтому
// «номер этого контакта изменился» выскакивал от смены телефона и — что хуже — от
// ротации личности И-1, которая по построению выглядит как новое устройство.
//
// Здесь закрепляется то, что этот файл обязан доказывать: подпись аккаунта
// отличает «то же самое устройство человека» от подмены, и делает это ЗАКРЫТО —
// любая неясность значит «не доказано».

Future<String> seedB64() async {
  final pair = await Ed25519().newKeyPair();
  final bytes = await pair.extractPrivateKeyBytes();
  return base64Encode(bytes);
}

void main() {
  group('сертификат устройства', () {
    test('подпись своим AIK сходится', () async {
      final seed = await seedB64();
      final pub = await AccountIdentity.publicKeyB64FromSeed(seed);
      final identity = AccountIdentity.create();

      // Подписываем напрямую через чистый путь: хранилище в тесте недоступно.
      final keyPair = await Ed25519().newKeyPairFromSeed(base64Decode(seed));
      final sig = await Ed25519().sign(
        AccountIdentity.deviceCertificateMessage(
          profileId: 'profile-A',
          deviceId: 'device-1',
          deviceIdentityPubB64: 'ZGV2LWlkZW50aXR5',
        ),
        keyPair: keyPair,
      );

      expect(
        await AccountIdentity.verifyDeviceCertificate(
          accountPubB64: pub,
          certificateB64: base64Encode(sig.bytes),
          profileId: 'profile-A',
          deviceId: 'device-1',
          deviceIdentityPubB64: 'ZGV2LWlkZW50aXR5',
        ),
        isTrue,
      );
      expect(identity, isNotNull);
    });

    test('🔴 подпись ЧУЖИМ AIK не сходится — иначе проверка ничего не значит',
        () async {
      final mine = await seedB64();
      final other = await seedB64();
      final minePub = await AccountIdentity.publicKeyB64FromSeed(mine);

      final keyPair = await Ed25519().newKeyPairFromSeed(base64Decode(other));
      final sig = await Ed25519().sign(
        AccountIdentity.deviceCertificateMessage(
          profileId: 'profile-A',
          deviceId: 'device-1',
          deviceIdentityPubB64: 'ZGV2LWlkZW50aXR5',
        ),
        keyPair: keyPair,
      );

      expect(
        await AccountIdentity.verifyDeviceCertificate(
          accountPubB64: minePub,
          certificateB64: base64Encode(sig.bytes),
          profileId: 'profile-A',
          deviceId: 'device-1',
          deviceIdentityPubB64: 'ZGV2LWlkZW50aXR5',
        ),
        isFalse,
      );
    });

    test('🔴 сертификат одного устройства НЕ годится другому', () async {
      // Ради этого в подписываемых байтах стоят разделители: без них
      // `profile|device` и `profiledevice|` дали бы одни и те же байты.
      final seed = await seedB64();
      final pub = await AccountIdentity.publicKeyB64FromSeed(seed);
      final keyPair = await Ed25519().newKeyPairFromSeed(base64Decode(seed));
      final sig = await Ed25519().sign(
        AccountIdentity.deviceCertificateMessage(
          profileId: 'profile-A',
          deviceId: 'device-1',
          deviceIdentityPubB64: 'ZGV2LWlkZW50aXR5',
        ),
        keyPair: keyPair,
      );
      final cert = base64Encode(sig.bytes);

      for (final wrong in <Map<String, String>>[
        {'profileId': 'profile-B', 'deviceId': 'device-1', 'pub': 'ZGV2LWlkZW50aXR5'},
        {'profileId': 'profile-A', 'deviceId': 'device-2', 'pub': 'ZGV2LWlkZW50aXR5'},
        {'profileId': 'profile-A', 'deviceId': 'device-1', 'pub': 'b3RoZXI='},
      ]) {
        expect(
          await AccountIdentity.verifyDeviceCertificate(
            accountPubB64: pub,
            certificateB64: cert,
            profileId: wrong['profileId']!,
            deviceId: wrong['deviceId']!,
            deviceIdentityPubB64: wrong['pub']!,
          ),
          isFalse,
          reason: wrong.toString(),
        );
      }
    });

    test('🔴 мусор на входе = НЕ доказано, а не «доказано»', () async {
      final seed = await seedB64();
      final pub = await AccountIdentity.publicKeyB64FromSeed(seed);
      for (final bad in const <String>['', '   ', 'не base64', 'AAAA']) {
        expect(
          await AccountIdentity.verifyDeviceCertificate(
            accountPubB64: pub,
            certificateB64: bad,
            profileId: 'profile-A',
            deviceId: 'device-1',
            deviceIdentityPubB64: 'ZGV2LWlkZW50aXR5',
          ),
          isFalse,
          reason: 'cert=$bad',
        );
        expect(
          await AccountIdentity.verifyDeviceCertificate(
            accountPubB64: bad,
            certificateB64: base64Encode(List<int>.filled(64, 7)),
            profileId: 'profile-A',
            deviceId: 'device-1',
            deviceIdentityPubB64: 'ZGV2LWlkZW50aXR5',
          ),
          isFalse,
          reason: 'aik=$bad',
        );
      }
    });
  });

  group('номер безопасности', () {
    test('🔴 обе стороны видят ОДИН И ТОТ ЖЕ код', () async {
      // Иначе сверять его по телефону бессмысленно — а он ровно для этого и есть.
      final a = await AccountIdentity.publicKeyB64FromSeed(await seedB64());
      final b = await AccountIdentity.publicKeyB64FromSeed(await seedB64());

      final fromA = AccountIdentity.safetyNumberFromAccountKeys(
        selfAccountPubB64: a,
        peerAccountPubB64: b,
      );
      final fromB = AccountIdentity.safetyNumberFromAccountKeys(
        selfAccountPubB64: b,
        peerAccountPubB64: a,
      );
      expect(fromA, fromB);
      expect(fromA, isNotEmpty);
    });

    test('разные люди — разные номера', () async {
      final a = await AccountIdentity.publicKeyB64FromSeed(await seedB64());
      final b = await AccountIdentity.publicKeyB64FromSeed(await seedB64());
      final c = await AccountIdentity.publicKeyB64FromSeed(await seedB64());
      expect(
        AccountIdentity.safetyNumberFromAccountKeys(
          selfAccountPubB64: a,
          peerAccountPubB64: b,
        ),
        isNot(
          AccountIdentity.safetyNumberFromAccountKeys(
            selfAccountPubB64: a,
            peerAccountPubB64: c,
          ),
        ),
      );
    });

    test('🔴 формат ВИЗУАЛЬНО не похож на пер-девайсный', () async {
      // Старый: 24 hex-символа, четыре группы по 6. Совпади формат — люди стали
      // бы сверять старый код с новым и решили, что номер «изменился», ровно
      // тогда, когда мы это и лечим.
      final a = await AccountIdentity.publicKeyB64FromSeed(await seedB64());
      final b = await AccountIdentity.publicKeyB64FromSeed(await seedB64());
      final number = AccountIdentity.safetyNumberFromAccountKeys(
        selfAccountPubB64: a,
        peerAccountPubB64: b,
      );
      final groups = number.split(' ');
      expect(groups, hasLength(12), reason: '12 групп против четырёх у старого');
      for (final group in groups) {
        expect(group, hasLength(5));
        expect(int.tryParse(group), isNotNull, reason: 'только цифры: $group');
      }
      expect(number.replaceAll(' ', ''), hasLength(60));
    });

    test('отпечаток одной стороны — 30 цифр и не зависит от собеседника', () async {
      final a = await AccountIdentity.publicKeyB64FromSeed(await seedB64());
      final first = AccountIdentity.fingerprintDigits(a);
      expect(first, hasLength(30));
      // Проверяем «только цифры» РЕГУЛЯРКОЙ, а не разбором в число: 30 цифр не
      // влезают в 64-битное целое, и `int.tryParse` вернул бы null на верном
      // отпечатке. Ошибка была в этом утверждении, не в выводе отпечатка.
      expect(RegExp(r'^\d{30}$').hasMatch(first), isTrue, reason: first);
      // Дважды одно и то же — иначе номер «менялся» бы сам по себе.
      expect(AccountIdentity.fingerprintDigits(a), first);
    });

    test('🔴 без ключа номера НЕТ — пустая строка, а не выдуманный код', () {
      // Контакт со старой сборкой AIK не публикует. Показать ему любой код
      // значило бы предъявить человеку то, что нечем сверить.
      expect(AccountIdentity.fingerprintDigits(''), isEmpty);
      expect(AccountIdentity.fingerprintDigits('не base64'), isEmpty);
      expect(AccountIdentity.fingerprintDigits('AAAA'), isEmpty);
      expect(
        AccountIdentity.safetyNumberFromAccountKeys(
          selfAccountPubB64: '',
          peerAccountPubB64: '',
        ),
        isEmpty,
      );
    });
  });
}
