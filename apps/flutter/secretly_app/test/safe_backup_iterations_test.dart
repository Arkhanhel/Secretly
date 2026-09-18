// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// СТОЙКОСТЬ АРХИВА И СОВМЕСТИМОСТЬ СТАРЫХ КОПИЙ (SEC-04, этап Э-5).
//
// 🔴 Ловушка, ради которой этот файл существует. Защита от понижения сравнивала
// число итераций в архиве с ТОЙ ЖЕ константой, которой шифруются новые архивы:
//
//     if (iter < _iter) throw StateError('Unsupported ... iteration count');
//
// Поднять её «в одну строку» означало объявить каждый существующий архив
// (записанный с 200 000) попыткой понижения и сделать нечитаемым — то есть
// отобрать у людей их собственные резервные копии. Отсюда две константы:
// чем пишем и что принимаем.
//
// Тесты ниже проверяют обе стороны: новые архивы стали стойче, старые
// по-прежнему открываются.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/safe_backup.dart';

Map<String, dynamic> _unwrap(String payload) {
  final b64 = payload.substring(SafeBackupV1.prefix.length);
  return jsonDecode(utf8.decode(base64Url.decode(b64))) as Map<String, dynamic>;
}

void main() {
  const password = 'Correct-Horse-1!';

  String seedB64(int byte) => base64Encode(List<int>.filled(32, byte));
  final deviceMaterial = jsonEncode(<String, Object?>{
    'identity_seed_b64': seedB64(1),
    'signed_prekey_seed_b64': seedB64(2),
    'next_otk_id': 2,
    'otk_seed_by_id': <String, String>{'1': seedB64(3)},
  });
  final plain = SafeBackupPlainV1(
    profileId: 'profile-iter-1',
    profileSecretB64: base64Encode(List<int>.filled(32, 7)),
    deviceId: 'device-iter-1',
    deviceKeysMaterialJson: deviceMaterial,
    serverBinding: 'keys=https://keys.example.com;relay=https://relay.example.com',
    contacts: const <SafeBackupContactV1>[],
    blockedProfiles: const <String>[],
    darkMode: false,
    blockUnverified: false,
    shareNicknameInQr: false,
    myNickname: 'Tester',
    profileGalleryPaths: const <String>[],
    profileBackgroundPaths: const <String>[],
    profileMusicPaths: const <String>[],
    personalConvoIds: const <String>[],
  );

  test('новые архивы пишутся с поднятым числом итераций', () async {
    final payload = await SafeBackupV1.encryptToPayload(
      plain: plain,
      password: password,
    );
    final iter = (_unwrap(payload)['iter'] as num).toInt();
    expect(
      iter,
      greaterThan(200000),
      reason: 'стойкость новых архивов не поднята',
    );
  });

  test('🔴 архив со СТАРЫМ числом итераций по-прежнему открывается', () async {
    // Собираем архив вручную с 200 000 — ровно так записаны все существующие
    // копии. Если планка приёма поднимется вместе с планкой записи, этот тест
    // упадёт, и падение будет означать: люди потеряли доступ к своим архивам.
    final payload = await SafeBackupV1.encryptToPayloadForTest(
      plain: plain,
      password: password,
      iter: 200000,
    );
    expect((_unwrap(payload)['iter'] as num).toInt(), 200000);

    final restored = await SafeBackupV1.decryptFromPayload(
      payload: payload,
      password: password,
    );
    expect(restored.profileSecretB64, plain.profileSecretB64);
  });

  test('архив с ЗАНИЖЕННЫМИ итерациями отвергается', () async {
    // Защита от понижения обязана остаться: подсунутый архив со слабым KDF
    // нельзя принимать, иначе стойкость выбирает атакующий.
    final payload = await SafeBackupV1.encryptToPayloadForTest(
      plain: plain,
      password: password,
      iter: 1000,
    );
    await expectLater(
      SafeBackupV1.decryptFromPayload(payload: payload, password: password),
      throwsA(isA<StateError>()),
    );
  });

  test('новый архив читается своим же паролем', () async {
    final payload = await SafeBackupV1.encryptToPayload(
      plain: plain,
      password: password,
    );
    final restored = await SafeBackupV1.decryptFromPayload(
      payload: payload,
      password: password,
    );
    expect(restored.profileSecretB64, plain.profileSecretB64);
  });
}
