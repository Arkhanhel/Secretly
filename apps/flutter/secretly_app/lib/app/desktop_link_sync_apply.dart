// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'desktop_link_flow.dart';

typedef DesktopLinkAsyncCallback = Future<void> Function();
typedef DesktopLinkRestoreFilesCallback =
    Future<void> Function(Map<String, String> filesByRelativePath);
typedef DesktopLinkApplyPendingImportCallback =
    Future<bool> Function(Map<String, dynamic> pendingImport);
typedef DesktopLinkSetProfileSecretCallback = Future<void> Function({
  required String profileId,
  required String secretB64,
});
typedef DesktopLinkSetCryptoKeyCallback = Future<void> Function(
  String cryptoKeyB64,
);
typedef DesktopLinkDeleteProfileSecretCallback = Future<void> Function(
  String profileId,
);
typedef DesktopLinkDeleteDeviceRegistrationCallback = Future<void> Function({
  required String profileId,
  required String deviceId,
  String? profileSecretB64,
});
typedef DesktopLinkDeleteDeviceMaterialCallback = Future<void> Function({
  required String profileId,
  required String deviceId,
});

class DesktopLinkSyncApplyPrefsKeys {
  const DesktopLinkSyncApplyPrefsKeys({
    required this.profileIdKey,
    required this.deviceIdKey,
    required this.serverBindingKey,
    required this.relayNextSeqKey,
    required this.pendingSafeImportKey,
    required this.darkModeKey,
    required this.blockUnverifiedKey,
    required this.shareNicknameInQrKey,
    required this.myNicknameKey,
    required this.profileGalleryPathsKey,
    required this.profileBackgroundPathsKey,
    required this.profileMusicPathsKey,
    required this.keysPublishedKeyPrefix,
  });

  final String profileIdKey;
  final String deviceIdKey;
  final String serverBindingKey;
  final String relayNextSeqKey;
  final String pendingSafeImportKey;
  final String darkModeKey;
  final String blockUnverifiedKey;
  final String shareNicknameInQrKey;
  final String myNicknameKey;
  final String profileGalleryPathsKey;
  final String profileBackgroundPathsKey;
  final String profileMusicPathsKey;
  final String keysPublishedKeyPrefix;
}

class DesktopLinkSyncApplyResult {
  const DesktopLinkSyncApplyResult({
    required this.desktopLinkRequests,
    required this.newDesktopDeviceId,
  });

  final List<DesktopLinkRequest> desktopLinkRequests;
  final String newDesktopDeviceId;
}

class DesktopLinkSyncBundleApplier {
  const DesktopLinkSyncBundleApplier({
    required this.prepareRuntimeForSyncApply,
    required this.deleteLocalDatabaseFiles,
    required this.decodeSafeBackupFiles,
    required this.restoreSafeBackupFiles,
    required this.applyPendingImport,
    required this.setProfileSecret,
    required this.setCryptoKey,
    required this.deleteProfileSecret,
    required this.deleteDeviceRegistration,
    required this.deleteDeviceMaterial,
  });

  final DesktopLinkAsyncCallback prepareRuntimeForSyncApply;
  final DesktopLinkAsyncCallback deleteLocalDatabaseFiles;
  final Map<String, String> Function(Object? raw) decodeSafeBackupFiles;
  final DesktopLinkRestoreFilesCallback restoreSafeBackupFiles;
  final DesktopLinkApplyPendingImportCallback applyPendingImport;
  final DesktopLinkSetProfileSecretCallback setProfileSecret;
  final DesktopLinkSetCryptoKeyCallback setCryptoKey;
  final DesktopLinkDeleteProfileSecretCallback deleteProfileSecret;
  final DesktopLinkDeleteDeviceRegistrationCallback deleteDeviceRegistration;
  final DesktopLinkDeleteDeviceMaterialCallback deleteDeviceMaterial;

  Future<DesktopLinkSyncApplyResult> apply({
    required SharedPreferences prefs,
    required DesktopLinkSyncApplyPrefsKeys prefsKeys,
    required DesktopLinkSyncPayload payload,
    required List<DesktopLinkRequest> desktopLinkRequests,
    required String newDesktopDeviceId,
    String? oldProfileId,
    String? oldDeviceId,
  }) async {
    payload.validateForSyncApply();

    await prepareRuntimeForSyncApply();
    await deleteLocalDatabaseFiles();

    await _applySettings(
      prefs: prefs,
      prefsKeys: prefsKeys,
      settingsRaw: payload.settingsRaw,
    );

    final pendingImport = _normalizePendingImport(payload.pendingImportRaw);
    await prefs.remove(prefsKeys.pendingSafeImportKey);

    final restoredFiles = decodeSafeBackupFiles(payload.filesRaw);
    if (restoredFiles.isNotEmpty) {
      await restoreSafeBackupFiles(restoredFiles);
    }

    await prefs.setString(prefsKeys.profileIdKey, payload.profileId);
    await prefs.setString(prefsKeys.deviceIdKey, newDesktopDeviceId);
    if (payload.serverBinding.isNotEmpty) {
      await prefs.setString(prefsKeys.serverBindingKey, payload.serverBinding);
    }
    await prefs.setInt(prefsKeys.relayNextSeqKey, 1);

    await setProfileSecret(
      profileId: payload.profileId,
      secretB64: payload.profileSecretB64,
    );
    if (payload.cryptoKeyB64.isNotEmpty) {
      await setCryptoKey(payload.cryptoKeyB64);
    }

    if (pendingImport != null) {
      var imported = false;
      try {
        imported = await applyPendingImport(pendingImport);
      } catch (_) {
        imported = false;
      }
      if (!imported) {
        await prefs.setString(
          prefsKeys.pendingSafeImportKey,
          jsonEncode(pendingImport),
        );
      }
    }

    final keysToRemove = prefs
        .getKeys()
        .where((key) => key.startsWith(prefsKeys.keysPublishedKeyPrefix))
        .toList(growable: false);
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    final requestUpdate = DesktopLinkStateMachine.updateRequestStatus(
      requests: desktopLinkRequests,
      requestId: payload.requestId,
      status: 'applied',
    );

    final normalizedOldProfileId = (oldProfileId ?? '').trim();
    final normalizedOldDeviceId = (oldDeviceId ?? '').trim();
    final shouldCleanupOldDevice =
        normalizedOldProfileId.isNotEmpty &&
        normalizedOldDeviceId.isNotEmpty &&
        normalizedOldDeviceId != newDesktopDeviceId;

    if (shouldCleanupOldDevice) {
      try {
        await deleteDeviceRegistration(
          profileId: normalizedOldProfileId,
          deviceId: normalizedOldDeviceId,
          profileSecretB64: normalizedOldProfileId == payload.profileId
              ? payload.profileSecretB64
              : null,
        );
      } catch (_) {}
    }

    if (shouldCleanupOldDevice && normalizedOldProfileId != payload.profileId) {
      try {
        await deleteProfileSecret(normalizedOldProfileId);
      } catch (_) {}
    }
    if (shouldCleanupOldDevice) {
      try {
        await deleteDeviceMaterial(
          profileId: normalizedOldProfileId,
          deviceId: normalizedOldDeviceId,
        );
      } catch (_) {}
    }

    return DesktopLinkSyncApplyResult(
      desktopLinkRequests: requestUpdate.requests,
      newDesktopDeviceId: newDesktopDeviceId,
    );
  }

  static Map<String, dynamic>? _normalizePendingImport(Object? raw) {
    if (raw is! Map) return null;
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  static Future<void> _applySettings({
    required SharedPreferences prefs,
    required DesktopLinkSyncApplyPrefsKeys prefsKeys,
    required Object? settingsRaw,
  }) async {
    if (settingsRaw is! Map) return;

    final settings = settingsRaw.map((k, v) => MapEntry(k.toString(), v));
    final darkMode = settings['dark_mode'];
    final blockUnverified = settings['block_unverified'];
    final shareNicknameInQr = settings['share_nickname_in_qr'];
    final myNickname = (settings['my_nickname'] as String?)?.trim();
    if (darkMode is bool) {
      await prefs.setBool(prefsKeys.darkModeKey, darkMode);
    }
    if (blockUnverified is bool) {
      await prefs.setBool(prefsKeys.blockUnverifiedKey, blockUnverified);
    }
    if (shareNicknameInQr is bool) {
      await prefs.setBool(
        prefsKeys.shareNicknameInQrKey,
        shareNicknameInQr,
      );
    }
    if (myNickname != null) {
      await prefs.setString(prefsKeys.myNicknameKey, myNickname);
    }

    await prefs.setStringList(
      prefsKeys.profileGalleryPathsKey,
      _normalizeStringList(settings['profile_gallery_paths']),
    );
    await prefs.setStringList(
      prefsKeys.profileBackgroundPathsKey,
      _normalizeStringList(settings['profile_background_paths']),
    );
    await prefs.setStringList(
      prefsKeys.profileMusicPathsKey,
      _normalizeStringList(settings['profile_music_paths']),
    );
  }

  static List<String> _normalizeStringList(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }
}