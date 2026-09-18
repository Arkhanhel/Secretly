// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/storage/app_db.dart';

// Модель Signal для смены номера безопасности (2026-08-06).
//
// Раньше проверка была «всё или ничего»: любое неподтверждённое устройство
// запирало отправку, а новое устройство контакта неподтверждено ПО ОПРЕДЕЛЕНИЮ.
// При включённой ротации личности (И-1) новое устройство появляется постоянно —
// и человек упирался в «Контакт не проверен» на ровном месте.
//
// Здесь закрепляются три вещи, каждая из которых уже один раз оказывалась
// ловушкой при чтении кода:
//
//  1. отметка «проверял когда-нибудь» живёт ОТДЕЛЬНО от строк устройств и
//     переживает их удаление;
//  2. отметка «отправить всё равно» переживает обычное обновление связки
//     ключей — иначе её пришлось бы нажимать снова и снова;
//  3. и она же СНИМАЕТСЯ при смене ключа — иначе одно нажатие в прошлом
//     навсегда выключало бы предупреждение о подмене.

const String peer = 'PEER-profile';
const String devA = 'PEER-device-A';

Future<void> publishBundle(
  AppDb db, {
  required String deviceId,
  required String identity,
}) async {
  await db.contactDeviceUpsert(
    profileId: peer,
    deviceId: deviceId,
    identityKeyPubB64: identity,
    signedPrekeyPubB64: 'spk-$identity',
    signedPrekeySigB64: 'sig-$identity',
    allowIdentityRotation: true,
  );
}

Future<Map<String, Object?>> deviceRow(AppDb db, String deviceId) async {
  final rows = await db.contactDevicesList(peer);
  return rows.firstWhere((r) => r['device_id'] == deviceId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('«проверял когда-нибудь» переживает смену ключа и удаление устройства', () async {
    final db = await AppDb.openForTesting();
    try {
      await publishBundle(db, deviceId: devA, identity: 'identity-1');
      expect(await db.contactWasEverVerified(peer), isFalse);

      await db.contactDeviceMarkVerified(profileId: peer, deviceId: devA);
      expect(await db.contactWasEverVerified(peer), isTrue);

      // Контакт переустановил приложение: тот же device_id, новый ключ.
      await publishBundle(db, deviceId: devA, identity: 'identity-2');
      final afterRotation = await deviceRow(db, devA);
      expect(
        afterRotation['verified_at_ms'],
        isNull,
        reason: 'смена ключа обязана снимать подтверждение самого ключа',
      );
      expect(
        await db.contactWasEverVerified(peer),
        isTrue,
        reason: 'а вот факт «этого человека когда-то сверяли» снимать нельзя — '
            'иначе не о чем предупреждать',
      );

      // Устройство ушло из выдачи целиком.
      await db.contactDevicesDeleteMissing(
        profileId: peer,
        keepDeviceIds: const <String>[],
      );
      expect(
        await db.contactWasEverVerified(peer),
        isTrue,
        reason: 'отметка лежит отдельной таблицей именно ради этого',
      );
    } finally {
      await db.close();
    }
  });

  test('«отправить всё равно» переживает обновление связки, но не смену ключа', () async {
    final db = await AppDb.openForTesting();
    try {
      await publishBundle(db, deviceId: devA, identity: 'identity-1');
      await db.contactDeviceMarkApproved(profileId: peer, deviceId: devA);
      expect((await deviceRow(db, devA))['approved_at_ms'], isNotNull);

      // Обычное обновление: ключ личности тот же, prekey новый. Вставка идёт
      // через ConflictAlgorithm.replace — если отметку не перенести руками,
      // она молча исчезнет здесь.
      await db.contactDeviceUpsert(
        profileId: peer,
        deviceId: devA,
        identityKeyPubB64: 'identity-1',
        signedPrekeyPubB64: 'spk-refreshed',
        signedPrekeySigB64: 'sig-refreshed',
        allowIdentityRotation: true,
      );
      expect(
        (await deviceRow(db, devA))['approved_at_ms'],
        isNotNull,
        reason: 'обновление prekey не должно возвращать вопрос заново',
      );

      // А вот смена ключа личности отметку снимает.
      await publishBundle(db, deviceId: devA, identity: 'identity-2');
      expect(
        (await deviceRow(db, devA))['approved_at_ms'],
        isNull,
        reason: 'отметка выдана ключу, а не устройству навсегда',
      );
    } finally {
      await db.close();
    }
  });

  test('смена имени контакта не сбрасывает проверку', () async {
    final db = await AppDb.openForTesting();
    try {
      await publishBundle(db, deviceId: devA, identity: 'identity-1');
      await db.contactDeviceMarkVerified(profileId: peer, deviceId: devA);

      // contactUpsert пишет contacts через ConflictAlgorithm.replace. Если бы
      // отметка жила столбцом в contacts, она бы здесь и потерялась.
      await db.contactUpsert(profileId: peer, displayName: 'Катя');
      await db.contactUpsert(profileId: peer, displayName: 'Катя Иванова');

      expect(await db.contactWasEverVerified(peer), isTrue);
    } finally {
      await db.close();
    }
  });
}
