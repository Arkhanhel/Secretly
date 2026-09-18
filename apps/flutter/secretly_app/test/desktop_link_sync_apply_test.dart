// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/desktop_link_failure.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secretly_app/app/desktop_link_flow.dart';
import 'package:secretly_app/app/desktop_link_sync_apply.dart';

void main() {
  const validProfileSecretB64 = 'c2VjcmV0';
  final validCryptoKeyB64 = base64Encode(List<int>.filled(32, 9));

  const prefsKeys = DesktopLinkSyncApplyPrefsKeys(
    profileIdKey: 'profile_id',
    deviceIdKey: 'device_id',
    serverBindingKey: 'server_binding',
    relayNextSeqKey: 'relay_next_seq',
    pendingSafeImportKey: 'pending_safe_import',
    darkModeKey: 'dark_mode',
    blockUnverifiedKey: 'block_unverified',
    shareNicknameInQrKey: 'share_nickname_in_qr',
    myNicknameKey: 'my_nickname',
    profileGalleryPathsKey: 'profile_gallery_paths',
    profileBackgroundPathsKey: 'profile_background_paths',
    profileMusicPathsKey: 'profile_music_paths',
    keysPublishedKeyPrefix: 'keys_published_',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  DesktopLinkRequest makeRequest({
    String requestId = 'req-1',
    String status = 'pending',
  }) {
    return DesktopLinkRequest(
      requestId: requestId,
      targetProfileId: 'profile-1',
      targetDeviceId: 'desktop-1',
      requestNonce: 'nonce-1',
      deviceLabel: 'Windows Desktop',
      createdAtMs: 1000,
      expiresAtMs: 2000,
      status: status,
    );
  }

  DesktopLinkSyncPayload makePayload({
    Object? settingsRaw,
    Object? pendingImportRaw,
    Object? filesRaw,
    String profileId = 'profile-1',
    String profileSecretB64 = validProfileSecretB64,
    String cryptoKeyB64 = '',
    String serverBinding = 'keys=https://keys;relay=https://relay',
  }) {
    return DesktopLinkSyncPayload(
      requestId: 'req-1',
      requestNonce: 'nonce-1',
      targetProfileId: profileId,
      targetDeviceId: 'desktop-1',
      profileId: profileId,
      profileSecretB64: profileSecretB64,
      cryptoKeyB64: cryptoKeyB64.isEmpty ? validCryptoKeyB64 : cryptoKeyB64,
      serverBinding: serverBinding,
      settingsRaw: settingsRaw,
      pendingImportRaw: pendingImportRaw,
      filesRaw: filesRaw,
    );
  }

  test('DesktopLinkSyncBundleApplier.apply persists settings and applied request', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'keys_published_a': true,
      'keys_published_b': true,
      'untouched_key': 'keep',
    });
    final prefs = await SharedPreferences.getInstance();
    final events = <String>[];
    Map<String, String>? restoredFiles;
    Map<String, dynamic>? importedPending;
    String? savedSecretProfileId;
    String? savedSecretB64;
    String? savedCryptoKey;
    String? deletedProfileSecret;
    String? deletedDeviceRegistration;
    String? deletedDeviceMaterial;

    final applier = DesktopLinkSyncBundleApplier(
      prepareRuntimeForSyncApply: () async {
        events.add('prepare');
      },
      deleteLocalDatabaseFiles: () async {
        events.add('delete-db');
      },
      decodeSafeBackupFiles: (raw) {
        expect(raw, <String, String>{'media/foo.bin': 'QQ=='});
        return <String, String>{'media/foo.bin': 'QQ=='};
      },
      restoreSafeBackupFiles: (files) async {
        restoredFiles = files;
      },
      applyPendingImport: (pendingImport) async {
        importedPending = pendingImport;
        return true;
      },
      setProfileSecret: ({required profileId, required secretB64}) async {
        savedSecretProfileId = profileId;
        savedSecretB64 = secretB64;
      },
      setCryptoKey: (cryptoKeyB64) async {
        savedCryptoKey = cryptoKeyB64;
      },
      deleteProfileSecret: (profileId) async {
        deletedProfileSecret = profileId;
      },
      deleteDeviceRegistration: ({
        required profileId,
        required deviceId,
        String? profileSecretB64,
      }) async {
        deletedDeviceRegistration = '$profileId:$deviceId:${profileSecretB64 ?? ''}';
      },
      deleteDeviceMaterial: ({required profileId, required deviceId}) async {
        deletedDeviceMaterial = '$profileId:$deviceId';
      },
    );

    final result = await applier.apply(
      prefs: prefs,
      prefsKeys: prefsKeys,
      payload: makePayload(
        settingsRaw: <String, Object?>{
          'dark_mode': true,
          'block_unverified': true,
          'share_nickname_in_qr': false,
          'my_nickname': 'Desk User',
          'profile_gallery_paths': <String>[' gallery-a ', ''],
          'profile_background_paths': <String>['bg-a'],
          'profile_music_paths': <String>['music-a'],
        },
        pendingImportRaw: <String, Object?>{
          'contacts': <Object>[],
        },
        filesRaw: <String, String>{'media/foo.bin': 'QQ=='},
      ),
      desktopLinkRequests: <DesktopLinkRequest>[makeRequest()],
      newDesktopDeviceId: 'desktop-new',
      oldProfileId: 'old-profile',
      oldDeviceId: 'old-device',
    );

    expect(events, <String>['prepare', 'delete-db']);
    expect(prefs.getBool('dark_mode'), isTrue);
    expect(prefs.getBool('block_unverified'), isTrue);
    expect(prefs.getBool('share_nickname_in_qr'), isFalse);
    expect(prefs.getString('my_nickname'), 'Desk User');
    expect(prefs.getStringList('profile_gallery_paths'), <String>['gallery-a']);
    expect(prefs.getStringList('profile_background_paths'), <String>['bg-a']);
    expect(prefs.getStringList('profile_music_paths'), <String>['music-a']);
    expect(prefs.getString('profile_id'), 'profile-1');
    expect(prefs.getString('device_id'), 'desktop-new');
    expect(
      prefs.getString('server_binding'),
      'keys=https://keys;relay=https://relay',
    );
    expect(prefs.getInt('relay_next_seq'), 1);
    expect(restoredFiles, <String, String>{'media/foo.bin': 'QQ=='});
    expect(importedPending, <String, dynamic>{'contacts': <Object>[]});
    expect(prefs.getString('pending_safe_import'), isNull);
    expect(savedSecretProfileId, 'profile-1');
    expect(savedSecretB64, validProfileSecretB64);
    expect(savedCryptoKey, validCryptoKeyB64);
    expect(deletedProfileSecret, 'old-profile');
    expect(deletedDeviceRegistration, 'old-profile:old-device:');
    expect(deletedDeviceMaterial, 'old-profile:old-device');
    expect(result.desktopLinkRequests.single.status, 'applied');
    expect(result.newDesktopDeviceId, 'desktop-new');
    expect(prefs.getKeys(), isNot(contains('keys_published_a')));
    expect(prefs.getKeys(), isNot(contains('keys_published_b')));
    expect(prefs.getString('untouched_key'), 'keep');
  });

  test('DesktopLinkSyncBundleApplier.apply queues pending import fallback', () async {
    final prefs = await SharedPreferences.getInstance();

    final applier = DesktopLinkSyncBundleApplier(
      prepareRuntimeForSyncApply: () async {},
      deleteLocalDatabaseFiles: () async {},
      decodeSafeBackupFiles: (_) => const <String, String>{},
      restoreSafeBackupFiles: (_) async {},
      applyPendingImport: (_) async => false,
      setProfileSecret: ({required profileId, required secretB64}) async {},
      setCryptoKey: (_) async {},
      deleteProfileSecret: (_) async {},
      deleteDeviceRegistration: ({
        required profileId,
        required deviceId,
        String? profileSecretB64,
      }) async {},
      deleteDeviceMaterial: ({required profileId, required deviceId}) async {},
    );

    await applier.apply(
      prefs: prefs,
      prefsKeys: prefsKeys,
      payload: makePayload(
        pendingImportRaw: <String, Object?>{
          'contacts': <Object>[<String, Object?>{'profile_id': 'c-1'}],
        },
      ),
      desktopLinkRequests: <DesktopLinkRequest>[makeRequest()],
      newDesktopDeviceId: 'desktop-new',
    );

    expect(
      prefs.getString('pending_safe_import'),
      jsonEncode(<String, Object?>{
        'contacts': <Object>[<String, Object?>{'profile_id': 'c-1'}],
      }),
    );
  });

  test('DesktopLinkSyncBundleApplier.apply cleans stale same-profile device without deleting profile secret', () async {
    final prefs = await SharedPreferences.getInstance();
    var deleteProfileCalls = 0;
    var deleteRegistrationCalls = 0;
    var deleteDeviceCalls = 0;
    var setCryptoCalls = 0;

    final applier = DesktopLinkSyncBundleApplier(
      prepareRuntimeForSyncApply: () async {},
      deleteLocalDatabaseFiles: () async {},
      decodeSafeBackupFiles: (_) => const <String, String>{},
      restoreSafeBackupFiles: (_) async {},
      applyPendingImport: (_) async => true,
      setProfileSecret: ({required profileId, required secretB64}) async {},
      setCryptoKey: (_) async {
        setCryptoCalls += 1;
      },
      deleteProfileSecret: (_) async {
        deleteProfileCalls += 1;
      },
      deleteDeviceRegistration: ({
        required profileId,
        required deviceId,
        String? profileSecretB64,
      }) async {
        deleteRegistrationCalls += 1;
      },
      deleteDeviceMaterial: ({required profileId, required deviceId}) async {
        deleteDeviceCalls += 1;
      },
    );

    await applier.apply(
      prefs: prefs,
      prefsKeys: prefsKeys,
      payload: makePayload(profileId: 'profile-1', cryptoKeyB64: ''),
      desktopLinkRequests: <DesktopLinkRequest>[makeRequest()],
      newDesktopDeviceId: 'desktop-new',
      oldProfileId: 'profile-1',
      oldDeviceId: 'old-device',
    );

    expect(deleteProfileCalls, 0);
    expect(deleteRegistrationCalls, 1);
    expect(deleteDeviceCalls, 1);
    expect(setCryptoCalls, 1);
  });

  test('DesktopLinkSyncBundleApplier.apply fails before destructive work on invalid payload', () async {
    final prefs = await SharedPreferences.getInstance();
    final events = <String>[];

    final applier = DesktopLinkSyncBundleApplier(
      prepareRuntimeForSyncApply: () async {
        events.add('prepare');
      },
      deleteLocalDatabaseFiles: () async {
        events.add('delete-db');
      },
      decodeSafeBackupFiles: (_) => const <String, String>{},
      restoreSafeBackupFiles: (_) async {},
      applyPendingImport: (_) async => true,
      setProfileSecret: ({required profileId, required secretB64}) async {
        events.add('set-secret');
      },
      setCryptoKey: (_) async {
        events.add('set-crypto');
      },
      deleteProfileSecret: (_) async {
        events.add('delete-profile-secret');
      },
      deleteDeviceRegistration: ({
        required profileId,
        required deviceId,
        String? profileSecretB64,
      }) async {
        events.add('delete-device-registration');
      },
      deleteDeviceMaterial: ({required profileId, required deviceId}) async {
        events.add('delete-device-material');
      },
    );

    await expectLater(
      () => applier.apply(
        prefs: prefs,
        prefsKeys: prefsKeys,
        payload: makePayload(
          profileSecretB64: 'not-base64',
          serverBinding: 'broken-binding',
        ),
        desktopLinkRequests: <DesktopLinkRequest>[makeRequest()],
        newDesktopDeviceId: 'desktop-new',
      ),
      throwsA(
        isA<DesktopLinkFailure>().having(
          (failure) => failure.code,
          'code',
          DesktopLinkFailureCode.invalidSyncPayload,
        ),
      ),
    );

    expect(events, isEmpty);
    expect(prefs.getString('profile_id'), isNull);
  });
}