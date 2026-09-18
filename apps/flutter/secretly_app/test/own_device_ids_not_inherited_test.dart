// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 СПИСОК «СВОИХ УСТРОЙСТВ» НЕ НАСЛЕДУЕТСЯ ЧУЖИМ АККАУНТОМ.
//
// НАЙДЕНО 16.09.2026 ПО ЖАЛОБЕ ВЛАДЕЛЬЦА: «в пк версии все пузыри справа, и
// вообще нет половины чатов из комнаты "Тест2"».
//
// РАЗБОР НА ЖИВОЙ МАШИНЕ. В настройках окна лежало пять «своих» устройств, а
// журнал линковки помнил ДВА разных профиля: одну заявку к `T4BL-…` со
// статусом applied и одну к `OD3S-…`. То есть окно линковали к одному
// аккаунту, потом к другому.
//
// `known_own_device_ids_v1` — общий на установку, без пометки владельца.
// «Выгрузить аккаунт» чистил набор в памяти и стирал базу, но этот ключ
// оставлял, и следующий запуск приписывал устройства ПРЕЖНЕГО аккаунта новому.
//
// Ценой была не только сторона пузыря. `isOwnDeviceId` — ещё и то, как читают
// автора: `resolveSenderProfileId` для «своего» устройства возвращает `null`,
// и имя с фотографией не подставляются, а уведомление гасится как собственное
// эхо. Чужие сообщения выглядели своими и молча.
//
// Держат теперь двое:
//   1. выгрузка аккаунта стирает ключ с диска;
//   2. старт выбрасывает устройства, про которые ПЕРЕПИСКА знает, что они
//      чужие, — и только их.
//
// 🔴 ВТОРОЕ ПРАВИЛО НАРОЧНО УЗКОЕ. «Нет записи» — это «неизвестно», а не
// «чужое»: на этом держится правка 08.08.2026, ради которой список и завели
// (после восстановления из копии сервер старых устройств уже не помнит, и
// узнать их неоткуда — а без них все свои сообщения уезжают влево).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final controller = File('lib/app/app_controller.dart').readAsStringSync();

  test('🔴 выгрузка аккаунта стирает список своих устройств И С ДИСКА',
      () async {
    final start = controller.indexOf('Future<void> resetProfileAndLocalData()');
    expect(start, greaterThan(0));
    final body = controller.substring(start, start + 12000);
    expect(
      body.contains('await prefs.remove(_prefsKnownOwnDeviceIdsKey);'),
      isTrue,
      reason: 'иначе следующий запуск поднимет устройства прежнего аккаунта',
    );
  });

  test('🔴 старт прогоняет список через проверку на чужих', () {
    final start =
        controller.indexOf('Future<void> _loadKnownOwnDeviceIdsFromDb()');
    expect(start, greaterThan(0));
    final body = controller.substring(start, start + 900);
    expect(body.contains('await _dropForeignOwnDeviceIds(pid);'), isTrue);
  });

  test('🔴 пруна смотрит в ПЕРЕПИСКУ, а не в device_profiles', () {
    // `device_profiles` собирает и прежний профиль самого владельца после
    // смены удостоверения — пруна по нему вернула бы беду 08.08.
    final start =
        controller.indexOf('Future<void> _dropForeignOwnDeviceIds(');
    expect(start, greaterThan(0));
    final body = controller.substring(start, start + 2200);
    expect(body.contains('contactProfilesForDeviceIds'), isTrue);
    expect(
      body.contains('deviceProfileOwners'),
      isFalse,
      reason: 'device_profiles знает и прежний профиль владельца',
    );
    // Своё текущее устройство не проверяют вовсе — его принадлежность не
    // предмет обсуждения.
    expect(body.contains("v != myDeviceId"), isTrue);
  });

  group('владелец устройства по переписке', () {
    test('находит только то, что знает, и молчит об остальном', () async {
      final db = await AppDb.openForTesting();

      await db.contactDeviceUpsert(
        profileId: 'PEER-AAAA',
        deviceId: 'dev-peer',
        identityKeyPubB64: 'ik',
        signedPrekeyPubB64: 'spk',
        signedPrekeySigB64: 'sig',
      );
      await db.contactDeviceUpsert(
        profileId: 'ME-BBBB',
        deviceId: 'dev-my-second',
        identityKeyPubB64: 'ik2',
        signedPrekeyPubB64: 'spk2',
        signedPrekeySigB64: 'sig2',
      );

      final owners = await db.contactProfilesForDeviceIds(
        const ['dev-peer', 'dev-my-second', 'dev-never-seen'],
      );

      expect(owners['dev-peer'], 'PEER-AAAA');
      // Своё второе устройство лежит там же — самораздача пишет его как
      // получателя. Отличает его только профиль, поэтому сравнение с «моим»
      // обязательно.
      expect(owners['dev-my-second'], 'ME-BBBB');
      // 🔴 Неизвестное устройство отсутствует в ответе, а не помечено чужим.
      expect(owners.containsKey('dev-never-seen'), isFalse);

      await db.close();
    });

    test('пустой запрос не ходит в базу', () async {
      final db = await AppDb.openForTesting();
      expect(await db.contactProfilesForDeviceIds(const []), isEmpty);
      expect(await db.contactProfilesForDeviceIds(const ['  ']), isEmpty);
      await db.close();
    });
  });
}
