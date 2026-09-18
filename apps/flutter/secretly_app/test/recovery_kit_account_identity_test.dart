// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/recovery_kit.dart';
import 'package:secretly_app/security/safe_backup.dart';

// Ключ восстановления и сид AIK (08.08.2026, слой 2 «номера безопасности»).
//
// 🔴 ЗАЧЕМ ЭТОТ ФАЙЛ. ТЗ требовало «кит v2», и это было БЫ ошибкой ценой в
// аккаунт: `fromJson` отвергает чужую версию (`if (v != 1) throw`), поэтому
// СТАРАЯ сборка не прочитала бы новый кит вовсе. Человек, снявший кит на новой
// сборке и восстанавливающийся на старой либо после отката, потерял бы профиль —
// тот же шрам, что потеря личности 30.07.
//
// Поэтому версия осталась 1, а сид приезжает НЕОБЯЗАТЕЛЬНЫМ полем. Здесь
// закрепляется совместимость в ОБЕ стороны, потому что сломать её тихо — легко,
// а цена — необратима.

void main() {
  String seedB64(int byte) => base64Encode(List<int>.filled(32, byte));

  String validDeviceMaterialJson() {
    return jsonEncode(<String, Object?>{
      'identity_seed_b64': seedB64(1),
      'signed_prekey_seed_b64': seedB64(2),
      'next_otk_id': 2,
      'otk_seed_by_id': <String, String>{'1': seedB64(3)},
    });
  }

  RecoveryKitPlainV1 kit({String? accountSeed}) {
    return RecoveryKitPlainV1(
      profileId: 'profile-1',
      profileSecretB64: 'c2VjcmV0',
      deviceId: 'device-1',
      deviceKeysMaterialJson: validDeviceMaterialJson(),
      serverBinding:
          'keys=https://keys.example.com;relay=https://relay.example.com',
      accountIdentitySeedB64: accountSeed,
    );
  }

  test('версия кита осталась 1 — иначе старая сборка не прочитает его вовсе', () {
    expect(kit(accountSeed: seedB64(9)).toJson()['v'], 1);
  });

  test('сид переживает круг', () {
    final restored = RecoveryKitPlainV1.fromJson(
      kit(accountSeed: seedB64(9)).toJson(),
    );
    expect(restored.accountIdentitySeedB64, seedB64(9));
  });

  test('🔴 кит БЕЗ сида восстанавливается — это все существующие киты', () {
    final json = kit().toJson();
    expect(json.containsKey('account_identity_seed_b64'), isFalse,
        reason: 'кит без AIK обязан остаться байт в байт прежним');
    final restored = RecoveryKitPlainV1.fromJson(json);
    expect(restored.profileId, 'profile-1');
    expect(restored.accountIdentitySeedB64, isNull);
  });

  test('🔴 кит С сидом читается кодом, который про сид НЕ знает', () {
    // Ровно поведение старой сборки: она берёт знакомые ключи и не спотыкается
    // о незнакомый. Проверяем это, выбрасывая поле из карты после разбора.
    final json = kit(accountSeed: seedB64(9)).toJson();
    final asOldBuildSees = Map<String, Object?>.from(json)
      ..remove('account_identity_seed_b64');
    final restored = RecoveryKitPlainV1.fromJson(asOldBuildSees);
    expect(restored.profileId, 'profile-1');
    expect(restored.deviceId, 'device-1');
    expect(restored.accountIdentitySeedB64, isNull);
  });

  test('🔴 испорченный сид = отсутствие, а НЕ отказ восстановления', () {
    // Обратная защёлка: бросок здесь превратил бы испорченное поле в потерю
    // профиля. Без AIK клиент просто ведёт себя как старая сборка.
    for (final bad in const <Object?>['не base64', 'AAAA', '', 42, <String>[]]) {
      final json = kit().toJson();
      json['account_identity_seed_b64'] = bad;
      final restored = RecoveryKitPlainV1.fromJson(json);
      expect(restored.accountIdentitySeedB64, isNull, reason: '$bad');
      expect(restored.profileId, 'profile-1', reason: '$bad');
    }
  });

  // 🔴 И ТО ЖЕ САМОЕ ДЛЯ РЕЗЕРВНОЙ КОПИИ. Найдено при перепроверке: копия несёт
  // `device_keys_material_json`, то есть личность УСТРОЙСТВА, а AIK терялся бы —
  // на восстановленном устройстве родился бы другой, и у всех собеседников
  // выскочило бы «номер безопасности изменился». То есть путь восстановления сам
  // притаскивал бы ровно ту беду, от которой слой 2 и лечит.
  group('резервная копия', () {
    SafeBackupPlainV1 backup({String? accountSeed}) {
      return SafeBackupPlainV1(
        profileId: 'profile-1',
        profileSecretB64: 'c2VjcmV0',
        deviceId: 'device-1',
        deviceKeysMaterialJson: validDeviceMaterialJson(),
        serverBinding:
            'keys=https://keys.example.com;relay=https://relay.example.com',
        accountIdentitySeedB64: accountSeed,
        contacts: const <SafeBackupContactV1>[],
        blockedProfiles: const <String>[],
        darkMode: false,
        blockUnverified: false,
        shareNicknameInQr: false,
        myNickname: 'User',
        profileGalleryPaths: const <String>[],
        profileBackgroundPaths: const <String>[],
        profileMusicPaths: const <String>[],
        personalConvoIds: const <String>[],
      );
    }

    test('версия копии осталась 1', () {
      expect(backup(accountSeed: seedB64(9)).toJson()['v'], 1);
    });

    test('сид переживает круг', () {
      final restored =
          SafeBackupPlainV1.fromJson(backup(accountSeed: seedB64(9)).toJson());
      expect(restored.accountIdentitySeedB64, seedB64(9));
    });

    test('🔴 копия БЕЗ сида восстанавливается — это все существующие копии', () {
      final json = backup().toJson();
      expect(json.containsKey('account_identity_seed_b64'), isFalse);
      final restored = SafeBackupPlainV1.fromJson(json);
      expect(restored.profileId, 'profile-1');
      expect(restored.accountIdentitySeedB64, isNull);
    });

    test('🔴 испорченный сид = отсутствие, а НЕ отказ восстановления', () {
      for (final bad in const <Object?>['не base64', 'AAAA', '', 42]) {
        final json = backup().toJson();
        json['account_identity_seed_b64'] = bad;
        final restored = SafeBackupPlainV1.fromJson(json);
        expect(restored.accountIdentitySeedB64, isNull, reason: '$bad');
        expect(restored.profileId, 'profile-1', reason: '$bad');
      }
    });
  });

  test('сид едет и через шифрованную обёртку кита', () async {
    final payload = await RecoveryKitV1.encryptToPayload(
      plain: kit(accountSeed: seedB64(9)),
      password: 'Correct-Horse-Battery-9',
    );
    final opened = await RecoveryKitV1.decryptFromPayload(
      payload: payload,
      password: 'Correct-Horse-Battery-9',
    );
    expect(opened.accountIdentitySeedB64, seedB64(9));
  });
}
