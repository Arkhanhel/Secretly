// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/storage/app_db.dart';

// Закрепление ключа личности аккаунта контакта, схема v64 (08.08.2026).
//
// 🔴 ЗАЧЕМ ЭТОТ ФАЙЛ. Новый столбец лёг в таблицу `contact_verification`, у
// которой до сих пор был ОДИН писатель — сама проверка контакта. Из-за этого
// смысл «строка есть = проверен» был верен, и на нём стояли ДВА места. С
// появлением второго писателя оба превратились в мины:
//
//   * `contactWasEverVerified` смотрел на НАЛИЧИЕ строки — объявил бы
//     проверенным человека, которого никто не проверял, и гейт запер бы
//     переписку с ним (ровно болезнь, которую лечил слой 1);
//   * `contactDeviceMarkVerified` вставлял через `ConflictAlgorithm.ignore` — при
//     уже существующей строке НАСТОЯЩАЯ проверка молча не записалась бы: человек
//     сверил код, а отметка не встала.
//
// Здесь закреплено и то, и другое, потому что оба отказа тихие.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('закрепление и чтение ключа аккаунта', () async {
    final db = await AppDb.openForTesting();
    try {
      expect(await db.contactAccountIdentityPinned('peer-1'), isNull);
      expect(
        await db.contactAccountIdentityPinIfAbsent(
          profileId: 'peer-1',
          accountIdentityPubB64: 'QUlL',
        ),
        isTrue,
      );
      expect(await db.contactAccountIdentityPinned('peer-1'), 'QUlL');
    } finally {
      await db.close();
    }
  });

  test('🔴 закреплённый ключ НЕ перезаписывается другим', () async {
    // Ключ аккаунта отдаёт сервер. Молчаливое обновление означало бы, что сервер
    // в любой момент подменяет личность человека вместе с его номером
    // безопасности — то есть уничтожает защиту, ради которой номер и есть.
    final db = await AppDb.openForTesting();
    try {
      await db.contactAccountIdentityPinIfAbsent(
        profileId: 'peer-1',
        accountIdentityPubB64: 'QUlL',
      );
      expect(
        await db.contactAccountIdentityPinIfAbsent(
          profileId: 'peer-1',
          accountIdentityPubB64: 'RFJVR09J',
        ),
        isFalse,
        reason: 'подмену обязан решать человек, а не эта функция',
      );
      expect(await db.contactAccountIdentityPinned('peer-1'), 'QUlL');
    } finally {
      await db.close();
    }
  });

  test('🔴 закрепление НЕ делает контакт «проверенным»', () async {
    // Мина №1. Иначе гейт отправки запрёт переписку с человеком, которого никто
    // не проверял.
    final db = await AppDb.openForTesting();
    try {
      await db.contactAccountIdentityPinIfAbsent(
        profileId: 'peer-1',
        accountIdentityPubB64: 'QUlL',
      );
      expect(await db.contactWasEverVerified('peer-1'), isFalse);
    } finally {
      await db.close();
    }
  });

  test('🔴 настоящая проверка записывается ПОВЕРХ закрепления', () async {
    // Мина №2. `ConflictAlgorithm.ignore` при существующей строке не делал бы
    // ничего, и проверка терялась молча.
    final db = await AppDb.openForTesting();
    try {
      await db.contactAccountIdentityPinIfAbsent(
        profileId: 'peer-1',
        accountIdentityPubB64: 'QUlL',
      );
      await db.contactDeviceMarkVerified(
        profileId: 'peer-1',
        deviceId: 'device-1',
      );
      expect(await db.contactWasEverVerified('peer-1'), isTrue);
      // И закрепление при этом не потерялось.
      expect(await db.contactAccountIdentityPinned('peer-1'), 'QUlL');
    } finally {
      await db.close();
    }
  });

  test('🔴 закрепление НЕ стирает уже сделанную проверку', () async {
    // Обратный порядок: человек проверил контакт ДО того, как приехал ключ
    // аккаунта. Слой 1 не имеет права пострадать от слоя 2.
    final db = await AppDb.openForTesting();
    try {
      await db.contactDeviceMarkVerified(
        profileId: 'peer-1',
        deviceId: 'device-1',
      );
      expect(await db.contactWasEverVerified('peer-1'), isTrue);

      await db.contactAccountIdentityPinIfAbsent(
        profileId: 'peer-1',
        accountIdentityPubB64: 'QUlL',
      );
      expect(
        await db.contactWasEverVerified('peer-1'),
        isTrue,
        reason: 'проверка обязана пережить закрепление ключа',
      );
      expect(await db.contactAccountIdentityPinned('peer-1'), 'QUlL');
    } finally {
      await db.close();
    }
  });

  test('пустые входные данные ничего не закрепляют', () async {
    final db = await AppDb.openForTesting();
    try {
      expect(
        await db.contactAccountIdentityPinIfAbsent(
          profileId: 'peer-1',
          accountIdentityPubB64: '   ',
        ),
        isFalse,
      );
      expect(
        await db.contactAccountIdentityPinIfAbsent(
          profileId: '',
          accountIdentityPubB64: 'QUlL',
        ),
        isFalse,
      );
      expect(await db.contactAccountIdentityPinned('peer-1'), isNull);
    } finally {
      await db.close();
    }
  });
}
