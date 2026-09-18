// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/backup_password_policy.dart';
import 'package:secretly_app/security/recovery_kit.dart';
import 'package:secretly_app/security/safe_backup.dart';
import 'package:secretly_app/storage/safe_backup_snapshot_contract.dart';

void main() {
  String seedB64(int byte) => base64Encode(List<int>.filled(32, byte));

  String rewriteEncryptedRestoreIter({
    required String payload,
    required String prefix,
    required int iter,
  }) {
    final compact = payload.substring(prefix.length);
    final wrapped =
        jsonDecode(utf8.decode(base64Url.decode(compact)))
            as Map<String, dynamic>;
    wrapped['iter'] = iter;
    return '$prefix${base64UrlEncode(utf8.encode(jsonEncode(wrapped)))}';
  }

  String validDeviceMaterialJson() {
    return jsonEncode(<String, Object?>{
      'identity_seed_b64': seedB64(1),
      'signed_prekey_seed_b64': seedB64(2),
      'next_otk_id': 2,
      'otk_seed_by_id': <String, String>{'1': seedB64(3)},
    });
  }

  Map<String, Object?> safeBackupJson({
    String profileId = 'profile-1',
    String profileSecretB64 = 'c2VjcmV0',
    String deviceId = 'device-1',
    String? deviceKeysMaterialJson,
    String serverBinding =
        'keys=https://keys.example.com;relay=https://relay.example.com',
    Map<String, Object?>? dbSnapshot,
    Map<String, String>? filesB64ByRelativePath,
    String? cryptoKeyB64,
  }) {
    return <String, Object?>{
      'v': 1,
      'profile_id': profileId,
      'profile_secret_b64': profileSecretB64,
      'device_id': deviceId,
      'device_keys_material_json':
          deviceKeysMaterialJson ?? validDeviceMaterialJson(),
      if (cryptoKeyB64 != null) 'crypto_key_b64': cryptoKeyB64,
      'server_binding': serverBinding,
      'contacts': <Object?>[
        <String, Object?>{'profile_id': 'peer-1', 'display_name': 'Peer'},
      ],
      'blocked_profiles': <Object?>['blocked-1'],
      'prefs': <String, Object?>{
        'dark_mode': true,
        'block_unverified': false,
        'share_nickname_in_qr': true,
        'my_nickname': 'Desk User',
        'profile_icon_asset_path': 'assets/app_ui/icons/png/001-book.png',
        'profile_avatar_gradient_index': 3,
        'profile_avatar_icon_scale': 0.82,
        'profile_gallery_paths': <String>['gallery/a.png'],
        'profile_background_paths': <String>['backgrounds/a.png'],
        'profile_music_paths': <String>['music/a.mp3'],
        'personal_convo_ids': <String>['convo-personal-1'],
      },
      if (dbSnapshot != null) 'db_snapshot': dbSnapshot,
      if (filesB64ByRelativePath != null) 'files_b64': filesB64ByRelativePath,
    };
  }

  Map<String, Object?> recoveryKitJson({
    String profileId = 'profile-1',
    String profileSecretB64 = 'c2VjcmV0',
    String deviceId = 'device-1',
    String? deviceKeysMaterialJson,
    String serverBinding =
        'keys=https://keys.example.com;relay=https://relay.example.com',
  }) {
    return <String, Object?>{
      'v': 1,
      'profile_id': profileId,
      'profile_secret_b64': profileSecretB64,
      'device_id': deviceId,
      'device_keys_material_json':
          deviceKeysMaterialJson ?? validDeviceMaterialJson(),
      'server_binding': serverBinding,
    };
  }

  test('SafeBackupPlainV1.fromJson accepts valid restore payload', () {
    final plain = SafeBackupPlainV1.fromJson(
      safeBackupJson(
        dbSnapshot: <String, Object?>{
          'group_settings': <Object?>[
            <String, Object?>{
              'group_id': 'group-1',
              'owner_profile_id': 'profile-1',
              'reactions_mode': 'all',
              'allow_text': 1,
              'allow_media': 1,
              'allow_add_members': 1,
              'allow_pin_messages': 1,
              'allow_change_group_info': 1,
              'allow_change_tag': 0,
              'join_approval_required': 0,
              'slow_mode_seconds': 0,
              'chat_history_visible': 0,
              'state_version': 1,
              'membership_version': 1,
              'created_at_ms': 1,
              'updated_at_ms': 1,
            },
          ],
          'room_message_receipts': <Object?>[
            <String, Object?>{
              'payload_event_id': 'evt-1',
              'reader_profile_id': 'profile-1',
              'status': 'read',
              'updated_at_ms': 1,
            },
          ],
          'events': <Object?>[
            <String, Object?>{
              'event_id': 'evt-1',
              'convo_id': 'convo-1',
              'type': 'msg',
              'sender_device_id': 'device-1',
              'ciphertext_b64': 'AA==',
              'created_at_ms': 1,
              'local_state': 'received',
            },
          ],
        },
        filesB64ByRelativePath: <String, String>{
          'avatars/me.png': base64Encode(<int>[1, 2, 3]),
        },
      ),
    );

    expect(plain.profileId, 'profile-1');
    expect(plain.deviceId, 'device-1');
    expect(plain.profileIconAssetPath, 'assets/app_ui/icons/png/001-book.png');
    expect(plain.profileAvatarGradientIndex, 3);
    expect(plain.profileAvatarIconScale, 0.82);
    expect(plain.personalConvoIds, <String>['convo-personal-1']);
    expect(plain.filesB64ByRelativePath, <String, String>{
      'avatars/me.png': base64Encode(<int>[1, 2, 3]),
    });
  });

  test(
    'SafeBackupPlainV1.fromJson tolerates a backup with no cosmetics block',
    () {
      // Backups created before cosmetics existed have no `cosmetics` key. They
      // must still decode, yielding a null cosmetics map (no throw).
      final json = safeBackupJson();
      expect(json.containsKey('cosmetics'), isFalse);
      final plain = SafeBackupPlainV1.fromJson(json);
      expect(plain.cosmetics, isNull);
    },
  );

  test('SafeBackupPlainV1 roundtrips the optional cosmetics block', () {
    final cosmetics = <String, Object?>{
      'frame_id': 'gold',
      'cover_id': 'custom',
      'emoji_status': '🚀',
      'bio': 'hello',
      'default_chat_wallpaper': 'secure3',
      'app_theme_preset_id': 'midnight',
      'chat_bubble_style_preset_id': 'ocean',
      'bubble_color_is_manual': true,
      'nickname_style_preset_id': 'accent',
      'indicator_color_preset_id': 'pink',
      'app_icon_key': 'midnight',
      'cover_image_basename': 'cover_custom_1.png',
      'cover_video_basename': 'cover_video_1.mp4',
      'avatar_video_basename': 'avatar_video_1.mp4',
      'chat_wallpapers': <String, Object?>{'convo-1': 'secure5'},
    };
    final json = safeBackupJson()..['cosmetics'] = cosmetics;
    final plain = SafeBackupPlainV1.fromJson(json);
    expect(plain.cosmetics, isNotNull);
    expect(plain.cosmetics!['frame_id'], 'gold');
    expect(plain.cosmetics!['bubble_color_is_manual'], true);
    expect(plain.cosmetics!['chat_wallpapers'], <String, Object?>{
      'convo-1': 'secure5',
    });

    // toJson re-emits the block; a second fromJson preserves it (roundtrip).
    final reparsed = SafeBackupPlainV1.fromJson(plain.toJson());
    expect(reparsed.cosmetics, plain.cosmetics);
  });

  test('SafeBackupPlainV1.toJson omits cosmetics when null or empty', () {
    final fromNull = SafeBackupPlainV1.fromJson(safeBackupJson());
    expect(fromNull.toJson().containsKey('cosmetics'), isFalse);

    final fromEmpty = SafeBackupPlainV1.fromJson(
      safeBackupJson()..['cosmetics'] = <String, Object?>{},
    );
    expect(fromEmpty.cosmetics, isNull);
    expect(fromEmpty.toJson().containsKey('cosmetics'), isFalse);
  });

  test('SafeBackupPlainV1.fromJson rejects invalid device key material', () {
    expect(
      () => SafeBackupPlainV1.fromJson(
        safeBackupJson(deviceKeysMaterialJson: '{"broken":true}'),
      ),
      throwsStateError,
    );
  });

  test('SafeBackupPlainV1.fromJson rejects invalid crypto key', () {
    expect(
      () => SafeBackupPlainV1.fromJson(
        safeBackupJson(cryptoKeyB64: base64Encode(List<int>.filled(31, 1))),
      ),
      throwsStateError,
    );
  });

  test('SafeBackupPlainV1.fromJson rejects path traversal in files', () {
    expect(
      () => SafeBackupPlainV1.fromJson(
        safeBackupJson(
          filesB64ByRelativePath: <String, String>{
            'avatars/../../outside.txt': base64Encode(<int>[1]),
          },
        ),
      ),
      throwsStateError,
    );
  });

  test('SafeBackupPlainV1.fromJson rejects duplicate normalized files', () {
    expect(
      () => SafeBackupPlainV1.fromJson(
        safeBackupJson(
          filesB64ByRelativePath: <String, String>{
            'gallery/../avatar.png': base64Encode(<int>[1]),
            'avatar.png': base64Encode(<int>[2]),
          },
        ),
      ),
      throwsStateError,
    );
  });

  test('RecoveryKitPlainV1.fromJson accepts valid restore payload', () {
    final plain = RecoveryKitPlainV1.fromJson(recoveryKitJson());

    expect(plain.profileId, 'profile-1');
    expect(plain.deviceId, 'device-1');
  });

  test('RecoveryKitPlainV1.fromJson rejects invalid profile secret', () {
    expect(
      () => RecoveryKitPlainV1.fromJson(
        recoveryKitJson(profileSecretB64: 'not-base64'),
      ),
      throwsStateError,
    );
  });

  test('BackupPasswordPolicy enforces creation requirements', () {
    expect(BackupPasswordPolicy.validate('Password1!').isValid, isTrue);

    final weak = BackupPasswordPolicy.validate('password123');
    expect(weak.isValid, isFalse);
    expect(weak.problems, contains(BackupPasswordProblem.missingUppercase));
    expect(weak.problems, contains(BackupPasswordProblem.missingSpecial));

    final spaced = BackupPasswordPolicy.validate(' Password1!');
    expect(spaced.problems, contains(BackupPasswordProblem.outerWhitespace));

    final nonAscii = BackupPasswordPolicy.validate('Password1!ж');
    expect(nonAscii.problems, contains(BackupPasswordProblem.nonAscii));
  });

  test('SafeBackupPlainV1.fromJson rejects unknown db_snapshot table', () {
    expect(
      () => SafeBackupPlainV1.fromJson(
        safeBackupJson(
          dbSnapshot: <String, Object?>{
            'messages': <Object?>[
              <String, Object?>{'id': 1, 'body': 'hello'},
            ],
          },
        ),
      ),
      throwsStateError,
    );
  });

  test('SafeBackupPlainV1.fromJson rejects unknown db_snapshot column', () {
    expect(
      () => SafeBackupPlainV1.fromJson(
        safeBackupJson(
          dbSnapshot: <String, Object?>{
            'contacts': <Object?>[
              <String, Object?>{
                'contact_profile_id': 'peer-1',
                'display_name': 'Peer',
                'unexpected': 'boom',
                'created_at_ms': 1,
                'updated_at_ms': 1,
              },
            ],
          },
        ),
      ),
      throwsStateError,
    );
  });

  test('SafeBackupV1 encrypt/decrypt roundtrip keeps valid payload', () async {
    final plain = SafeBackupPlainV1(
      profileId: 'profile-1',
      profileSecretB64: 'c2VjcmV0',
      deviceId: 'device-1',
      deviceKeysMaterialJson: validDeviceMaterialJson(),
      cryptoKeyB64: seedB64(8),
      serverBinding:
          'keys=https://keys.example.com;relay=https://relay.example.com',
      contacts: const <SafeBackupContactV1>[
        SafeBackupContactV1(profileId: 'peer-1', displayName: 'Peer'),
      ],
      blockedProfiles: const <String>['blocked-1'],
      darkMode: true,
      blockUnverified: false,
      shareNicknameInQr: true,
      myNickname: 'Desk User',
      profileGalleryPaths: const <String>['gallery/a.png'],
      profileBackgroundPaths: const <String>['backgrounds/a.png'],
      profileMusicPaths: const <String>['music/a.mp3'],
      personalConvoIds: const <String>['convo-personal-1'],
      dbSnapshot: <String, Object?>{
        'events': <Object?>[
          <String, Object?>{
            'event_id': 'evt-1',
            'convo_id': 'convo-1',
            'type': 'msg',
            'sender_device_id': 'device-1',
            'ciphertext_b64': 'AA==',
            'created_at_ms': 1,
            'local_state': 'received',
          },
        ],
      },
      filesB64ByRelativePath: <String, String>{
        'avatars/me.png': base64Encode(<int>[1, 2, 3]),
      },
    );

    final payload = await SafeBackupV1.encryptToPayload(
      plain: plain,
      password: 'Password1!',
    );
    final restored = await SafeBackupV1.decryptFromPayload(
      payload: payload,
      password: 'Password1!',
    );

    expect(restored.profileId, plain.profileId);
    expect(restored.deviceId, plain.deviceId);
    expect(restored.cryptoKeyB64, plain.cryptoKeyB64);
    expect(restored.personalConvoIds, plain.personalConvoIds);
    expect(restored.filesB64ByRelativePath, plain.filesB64ByRelativePath);
    expect(
      restored.dbSnapshot?.keys,
      kSafeBackupSnapshotColumnsByTable.keys.where((key) => key == 'events'),
    );
  });

  test(
    'SafeBackupV1 decrypt rejects payloads below minimum PBKDF2 iterations',
    () async {
      final payload = await SafeBackupV1.encryptToPayload(
        plain: SafeBackupPlainV1(
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
        ),
        password: 'Password1!',
      );
      final downgraded = rewriteEncryptedRestoreIter(
        payload: payload,
        prefix: SafeBackupV1.prefix,
        iter: 1000,
      );

      expect(
        () => SafeBackupV1.decryptFromPayload(
          payload: downgraded,
          password: 'Password1!',
        ),
        throwsStateError,
      );
    },
  );

  test('RecoveryKitV1 encrypt/decrypt roundtrip keeps valid payload', () async {
    final plain = RecoveryKitPlainV1(
      profileId: 'profile-1',
      profileSecretB64: 'c2VjcmV0',
      deviceId: 'device-1',
      deviceKeysMaterialJson: validDeviceMaterialJson(),
      serverBinding:
          'keys=https://keys.example.com;relay=https://relay.example.com',
    );

    final payload = await RecoveryKitV1.encryptToPayload(
      plain: plain,
      password: 'Password1!',
    );
    final restored = await RecoveryKitV1.decryptFromPayload(
      payload: payload,
      password: 'Password1!',
    );

    expect(restored.profileId, plain.profileId);
    expect(restored.deviceId, plain.deviceId);
  });

  test(
    'RecoveryKitV1 decrypt rejects payloads below minimum PBKDF2 iterations',
    () async {
      final payload = await RecoveryKitV1.encryptToPayload(
        plain: RecoveryKitPlainV1(
          profileId: 'profile-1',
          profileSecretB64: 'c2VjcmV0',
          deviceId: 'device-1',
          deviceKeysMaterialJson: validDeviceMaterialJson(),
          serverBinding:
              'keys=https://keys.example.com;relay=https://relay.example.com',
        ),
        password: 'Password1!',
      );
      final downgraded = rewriteEncryptedRestoreIter(
        payload: payload,
        prefix: RecoveryKitV1.prefix,
        iter: 1000,
      );

      expect(
        () => RecoveryKitV1.decryptFromPayload(
          payload: downgraded,
          password: 'Password1!',
        ),
        throwsStateError,
      );
    },
  );
}
