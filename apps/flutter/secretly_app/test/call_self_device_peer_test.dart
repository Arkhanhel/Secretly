// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Звонок со СВОЕГО второго устройства обязан показывать имя и фото.
//
// Жалоба 23.08.2026: «при закрытом приложении беру трубку — ни фото, ни имени;
// при открытом всё показывается правильно». Разница в источнике: при закрытом
// экран строится из пуша и звонящий ищется по `contact_devices` — таблице
// устройств КОНТАКТОВ, куда собственный iPhone не попадает по определению.
// При открытом приходит приглашение с готовым profile_id, поэтому там работало.
//
// Тест сторожит исходник: резолв обязан знать про свои устройства, а имя и фото
// для собственного профиля — браться из своих настроек, а не из чужих
// метаданных, где их нет.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final controller = File('lib/app/app_controller.dart').readAsStringSync();

  String bodyOf(String signature) {
    final start = controller.indexOf(signature);
    expect(start, greaterThan(0), reason: 'не найдено: $signature');
    return controller.substring(start, start + 1400);
  }

  test('поиск звонящего учитывает собственные устройства', () {
    final body = bodyOf('Future<String> contactProfileIdForDevice');
    expect(body.contains('isOwnDeviceId'), isTrue,
        reason: 'звонок со своего второго устройства снова останется без имени: '
            'contact_devices содержит только устройства контактов');
  });

  test('имя своего профиля берётся из своих настроек', () {
    final body = bodyOf('Future<String?> cachedProfileDisplayName');
    expect(body.contains('_myNickname'), isTrue,
        reason: 'свой профиль не лежит в контактах — имя взять неоткуда');
  });

  test('фото своего профиля берётся из своих настроек', () {
    // 13.09.2026: разрешение переехало в `resolvedOwnAvatarPath`, но правило
    // осталось прежним — своё фото НЕ ищется в чужих метаданных как у
    // постороннего. Проверяем оба звена: что общий разрешатель уходит в свой,
    // и что свой по-прежнему начинает с локального файла.
    final callSite = bodyOf('Future<String?> cachedProfileAvatarPath');
    expect(callSite.contains('resolvedOwnAvatarPath'), isTrue,
        reason: 'своё фото не лежит в чужих метаданных — кружок будет пустым');

    final resolver = bodyOf('Future<String?> resolvedOwnAvatarPath');
    expect(resolver.contains('_myAvatarPath'), isTrue,
        reason: 'локальный файл — первый источник своего фото');
  });

  test('🔴 компьютер берёт своё фото из собственных метаданных', () {
    // Связка по QR фотографию не везёт: на компьютере `_myAvatarPath` пуст
    // ВСЕГДА, и без этого отката владелец видит инициалы вместо своего лица
    // везде — в рейке, в своих пузырях, в «Избранном», в списке участников.
    final resolver = bodyOf('Future<String?> _pairedDeviceOwnAvatarPath');
    expect(resolver.contains('profileMetaGet'), isTrue,
        reason: 'опубликованная копия своего фото лежит в метаданных профиля');
    expect(resolver.contains('_isDesktopOrWebPlatform'), isTrue,
        reason: 'на телефоне пустой путь значит «фото удалено», а сервер '
            'удаление не принимает — откат вернул бы удалённое фото');
  });
}
