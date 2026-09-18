// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/security/safe_backup.dart';

// Резервная копия: лицо профиля и возраст копии (07.08.2026).
//
// Две полевые жалобы одного дня:
//
//  1. «После восстановления не вернулось фото профиля, хотя у собеседников оно
//     осталось». Причина: аватар лежал под тем же флагом, что и медиа
//     переписки, а серверная копия собирается без медиа. В копии оставался
//     ПУТЬ к аватару, но не байты.
//  2. «Восстанавливаются чаты, которые я давно удалил». Причина: восстановление
//     это полная замена, значит вернулось ровно то, что было в копии — то есть
//     копия старше удаления. Узнать это было неоткуда: в диалоге не было даты.
//
// Здесь закрепляется формат: отметка времени пишется и читается, а копии СТАРОГО
// формата (без неё) обязаны продолжать читаться.

String _seedB64(int byte) => base64Encode(List<int>.filled(32, byte));

/// Материал ключей обязан быть НАСТОЯЩИМ: `fromJson` проверяет его на входе,
/// и заглушка вида `{}` роняет разбор ещё до полей, которые здесь проверяются.
String _validDeviceMaterialJson() => jsonEncode(<String, Object?>{
  'identity_seed_b64': _seedB64(1),
  'signed_prekey_seed_b64': _seedB64(2),
  'next_otk_id': 2,
  'otk_seed_by_id': <String, String>{'1': _seedB64(3)},
});

SafeBackupPlainV1 samplePlain({
  int? createdAtMs,
  Map<String, String>? files,
}) {
  return SafeBackupPlainV1(
    profileId: 'PROFILE',
    profileSecretB64: _seedB64(9),
    deviceId: 'DEVICE',
    deviceKeysMaterialJson: _validDeviceMaterialJson(),
    serverBinding:
        'keys=https://keys.example.com;relay=https://relay.example.com',
    contacts: const <SafeBackupContactV1>[],
    blockedProfiles: const <String>[],
    darkMode: true,
    blockUnverified: false,
    shareNicknameInQr: true,
    myNickname: 'Я',
    profileGalleryPaths: const <String>[],
    profileBackgroundPaths: const <String>[],
    profileMusicPaths: const <String>[],
    personalConvoIds: const <String>[],
    filesB64ByRelativePath: files,
    createdAtMs: createdAtMs,
  );
}

void main() {
  test('отметка времени переживает запись и чтение', () {
    const stamp = 1786000000000;
    final restored = SafeBackupPlainV1.fromJson(
      samplePlain(createdAtMs: stamp).toJson(),
    );
    expect(restored.createdAtMs, stamp);
  });

  test('копия СТАРОГО формата читается, возраст просто неизвестен', () {
    // Защёлка обратной совместимости: копии, снятые до 07.08.2026, поля не
    // несут. Они обязаны восстанавливаться — иначе правка ради подсказки о
    // возрасте отняла бы у людей их единственную копию.
    final json = samplePlain().toJson();
    expect(
      json.containsKey('created_at_ms'),
      isFalse,
      reason: 'без отметки поле не должно появляться в payload',
    );

    final restored = SafeBackupPlainV1.fromJson(json);
    expect(restored.createdAtMs, isNull);
    expect(restored.profileId, 'PROFILE');
  });

  test('файлы лица профиля переживают путь через payload', () {
    // Серверная копия идёт БЕЗ медиа переписки, но аватар в ней быть обязан:
    // именно его отсутствие оставляло профиль без фото после восстановления.
    final files = <String, String>{'my_avatar.png': 'AAAA'};
    final restored = SafeBackupPlainV1.fromJson(
      samplePlain(files: files).toJson(),
    );
    expect(restored.filesB64ByRelativePath, files);
  });

  test('пустой набор файлов не ломает разбор', () {
    // Сбор лица профиля возвращает пустую карту, когда файлов на диске нет, —
    // раньше на этом месте был null, и оба состояния должны вести себя одинаково.
    final restored = SafeBackupPlainV1.fromJson(
      samplePlain(files: const <String, String>{}).toJson(),
    );
    expect(restored.filesB64ByRelativePath ?? const {}, isEmpty);
    expect(restored.profileId, 'PROFILE');
  });
}
