// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/recovery_kit.dart';
import 'package:secretly_app/security/restore_error_classification.dart';
import 'package:secretly_app/security/safe_backup.dart';

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

  SafeBackupPlainV1 validSafeBackupPlain() {
    return SafeBackupPlainV1(
      profileId: 'profile-1',
      profileSecretB64: 'c2VjcmV0',
      deviceId: 'device-1',
      deviceKeysMaterialJson: validDeviceMaterialJson(),
      serverBinding:
          'keys=https://keys.example.com;relay=https://relay.example.com',
      contacts: const <SafeBackupContactV1>[],
      blockedProfiles: const <String>[],
      darkMode: false,
      blockUnverified: false,
      shareNicknameInQr: false,
      myNickname: 'Desk User',
      profileGalleryPaths: const <String>[],
      profileBackgroundPaths: const <String>[],
      profileMusicPaths: const <String>[],
      personalConvoIds: const <String>[],
    );
  }

  RecoveryKitPlainV1 validRecoveryKitPlain() {
    return RecoveryKitPlainV1(
      profileId: 'profile-1',
      profileSecretB64: 'c2VjcmV0',
      deviceId: 'device-1',
      deviceKeysMaterialJson: validDeviceMaterialJson(),
      serverBinding:
          'keys=https://keys.example.com;relay=https://relay.example.com',
    );
  }

  test(
    'classifyEncryptedRestoreError treats wrong decrypt password as password failure',
    () async {
      final payload = await SafeBackupV1.encryptToPayload(
        plain: validSafeBackupPlain(),
        password: 'Password1!',
      );

      Object error;
      try {
        await SafeBackupV1.decryptFromPayload(
          payload: payload,
          password: 'wrong-password',
        );
        fail('Expected decrypt to fail with wrong password');
      } catch (e) {
        error = e;
      }

      expect(
        classifyEncryptedRestoreError(error),
        EncryptedRestoreFailureKind.wrongPassword,
      );
      expect(
        describeEncryptedRestoreError(error).kind,
        EncryptedRestoreFailureKind.wrongPassword,
      );
    },
  );

  test(
    'classifyEncryptedRestoreError treats wrong recovery password as password failure',
    () async {
      final payload = await RecoveryKitV1.encryptToPayload(
        plain: validRecoveryKitPlain(),
        password: 'Password1!',
      );

      Object error;
      try {
        await RecoveryKitV1.decryptFromPayload(
          payload: payload,
          password: 'wrong-password',
        );
        fail('Expected recovery kit decrypt to fail with wrong password');
      } catch (e) {
        error = e;
      }

      expect(
        classifyEncryptedRestoreError(error),
        EncryptedRestoreFailureKind.wrongPassword,
      );
      expect(
        describeEncryptedRestoreError(error).kind,
        EncryptedRestoreFailureKind.wrongPassword,
      );
    },
  );

  test(
    'classifyEncryptedRestoreError treats structural payload errors as invalid payload',
    () {
      expect(
        classifyEncryptedRestoreError(StateError('Not a safe backup')),
        EncryptedRestoreFailureKind.invalidPayload,
      );
      expect(
        classifyEncryptedRestoreError(FormatException('bad payload')),
        EncryptedRestoreFailureKind.invalidPayload,
      );
      expect(
        describeEncryptedRestoreError(StateError('Not a safe backup')).kind,
        EncryptedRestoreFailureKind.invalidPayload,
      );
    },
  );

  test('describeEncryptedRestoreError preserves typed restore exceptions', () {
    const error = EncryptedRestoreException(
      EncryptedRestoreFailureKind.invalidPayload,
    );

    expect(identical(describeEncryptedRestoreError(error), error), isTrue);
  });
}
