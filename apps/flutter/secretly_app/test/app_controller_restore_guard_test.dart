// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/security/recovery_kit.dart';
import 'package:secretly_app/security/restore_error_classification.dart';
import 'package:secretly_app/security/safe_backup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String seedB64(int byte) => base64Encode(List<int>.filled(32, byte));

  String validDeviceMaterialJson() {
    return jsonEncode(<String, Object?>{
      'identity_seed_b64': seedB64(1),
      'signed_prekey_seed_b64': seedB64(2),
      'next_otk_id': 2,
      'otk_seed_by_id': <String, String>{'1': seedB64(3)},
    });
  }

  DesktopLinkRequest makeLiveRequest() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return DesktopLinkRequest(
      requestId: 'req-1',
      targetProfileId: 'profile-live',
      targetDeviceId: 'device-live',
      requestNonce: 'nonce-1',
      deviceLabel: 'Windows Desktop',
      createdAtMs: nowMs,
      expiresAtMs: nowMs + 60 * 1000,
      status: 'pending',
    );
  }

  Map<String, Object> seededRestorePrefs({
    required DesktopLinkRequest request,
  }) {
    return <String, Object>{
      'profile_id': 'profile-live',
      'device_id': 'device-live',
      'server_binding_v1':
          'keys=https://keys.seed.example.com;relay=https://relay.seed.example.com',
      'relay_next_seq': 7,
      'pending_safe_import_v1': '{"seed":true}',
      'desktop_link_requests_v1': jsonEncode(<Object>[request.toJson()]),
      'my_nickname_v1': 'Seed User',
      'dark_mode_v1': true,
    };
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'restoreFromSafeBackupPayload rejects malformed payload without restart or prefs mutation',
    () async {
      final request = makeLiveRequest();
      SharedPreferences.setMockInitialValues(
        seededRestorePrefs(request: request),
      );
      final prefs = await SharedPreferences.getInstance();
      final controller = AppController()
        ..seedDesktopLinkStateForTesting(
          profileId: 'profile-live',
          deviceId: 'device-live',
          requests: <DesktopLinkRequest>[request],
          authFlowState: AuthFlowState.authenticated,
        );
      final changedStates = <AuthFlowState>[];
      var restartEvents = 0;
      final changedSub = controller.changed.listen((_) {
        changedStates.add(controller.authFlowState);
      });
      final restartSub = controller.restartRequested.listen((_) {
        restartEvents += 1;
      });

      final invalidPlain = SafeBackupPlainV1(
        profileId: 'profile-next',
        profileSecretB64: 'c2VjcmV0',
        deviceId: 'device-next',
        deviceKeysMaterialJson: '{"broken":true}',
        serverBinding:
            'keys=https://keys.example.com;relay=https://relay.example.com',
        contacts: const <SafeBackupContactV1>[],
        blockedProfiles: const <String>[],
        darkMode: false,
        blockUnverified: false,
        shareNicknameInQr: false,
        myNickname: 'Broken Restore',
        profileGalleryPaths: const <String>[],
        profileBackgroundPaths: const <String>[],
        profileMusicPaths: const <String>[],
        personalConvoIds: const <String>[],
      );
      final payload = await SafeBackupV1.encryptToPayload(
        plain: invalidPlain,
        password: 'Password1!',
      );

      await expectLater(
        controller.restoreFromSafeBackupPayload(
          payload: payload,
          password: 'Password1!',
        ),
        throwsA(
          isA<EncryptedRestoreException>().having(
            (error) => error.kind,
            'kind',
            EncryptedRestoreFailureKind.invalidPayload,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await changedSub.cancel();
      await restartSub.cancel();

      expect(changedStates, isEmpty);
      expect(restartEvents, 0);
      expect(controller.authFlowState, AuthFlowState.authenticated);
      expect(controller.authFlowError, isNull);
      expect(controller.desktopLinkRequests.single.requestId, 'req-1');
      expect(controller.activeDesktopLinkRequest, isNotNull);
      expect(prefs.getString('profile_id'), 'profile-live');
      expect(prefs.getString('device_id'), 'device-live');
      expect(
        prefs.getString('server_binding_v1'),
        'keys=https://keys.seed.example.com;relay=https://relay.seed.example.com',
      );
      expect(prefs.getInt('relay_next_seq'), 7);
      expect(prefs.getString('pending_safe_import_v1'), '{"seed":true}');
      expect(
        prefs.getString('desktop_link_requests_v1'),
        jsonEncode(<Object>[request.toJson()]),
      );
    },
  );

  test(
    'restoreFromRecoveryKitPayload rejects malformed kit without restart or prefs mutation',
    () async {
      final request = makeLiveRequest();
      SharedPreferences.setMockInitialValues(
        seededRestorePrefs(request: request),
      );
      final prefs = await SharedPreferences.getInstance();
      final controller = AppController()
        ..seedDesktopLinkStateForTesting(
          profileId: 'profile-live',
          deviceId: 'device-live',
          requests: <DesktopLinkRequest>[request],
          authFlowState: AuthFlowState.authenticated,
        );
      final changedStates = <AuthFlowState>[];
      var restartEvents = 0;
      final changedSub = controller.changed.listen((_) {
        changedStates.add(controller.authFlowState);
      });
      final restartSub = controller.restartRequested.listen((_) {
        restartEvents += 1;
      });

      final invalidKit = RecoveryKitPlainV1(
        profileId: 'profile-next',
        profileSecretB64: 'not-base64',
        deviceId: 'device-next',
        deviceKeysMaterialJson: validDeviceMaterialJson(),
        serverBinding:
            'keys=https://keys.example.com;relay=https://relay.example.com',
      );
      final payload = await RecoveryKitV1.encryptToPayload(
        plain: invalidKit,
        password: 'Password1!',
      );

      await expectLater(
        controller.restoreFromRecoveryKitPayload(
          payload: payload,
          password: 'Password1!',
        ),
        throwsA(
          isA<EncryptedRestoreException>().having(
            (error) => error.kind,
            'kind',
            EncryptedRestoreFailureKind.invalidPayload,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await changedSub.cancel();
      await restartSub.cancel();

      expect(changedStates, isEmpty);
      expect(restartEvents, 0);
      expect(controller.authFlowState, AuthFlowState.authenticated);
      expect(controller.authFlowError, isNull);
      expect(controller.desktopLinkRequests.single.requestId, 'req-1');
      expect(controller.activeDesktopLinkRequest, isNotNull);
      expect(prefs.getString('profile_id'), 'profile-live');
      expect(prefs.getString('device_id'), 'device-live');
      expect(
        prefs.getString('server_binding_v1'),
        'keys=https://keys.seed.example.com;relay=https://relay.seed.example.com',
      );
      expect(prefs.getInt('relay_next_seq'), 7);
      expect(prefs.getString('pending_safe_import_v1'), '{"seed":true}');
      expect(
        prefs.getString('desktop_link_requests_v1'),
        jsonEncode(<Object>[request.toJson()]),
      );
    },
  );

  test(
    'restoreFromSafeBackupPayload rejects invalid db snapshot before restart or prefs mutation',
    () async {
      final request = makeLiveRequest();
      SharedPreferences.setMockInitialValues(
        seededRestorePrefs(request: request),
      );
      final prefs = await SharedPreferences.getInstance();
      final controller = AppController()
        ..seedDesktopLinkStateForTesting(
          profileId: 'profile-live',
          deviceId: 'device-live',
          requests: <DesktopLinkRequest>[request],
          authFlowState: AuthFlowState.authenticated,
        );
      var restartEvents = 0;
      final restartSub = controller.restartRequested.listen((_) {
        restartEvents += 1;
      });

      final invalidPlain = SafeBackupPlainV1(
        profileId: 'profile-next',
        profileSecretB64: 'c2VjcmV0',
        deviceId: 'device-next',
        deviceKeysMaterialJson: validDeviceMaterialJson(),
        serverBinding:
            'keys=https://keys.example.com;relay=https://relay.example.com',
        contacts: const <SafeBackupContactV1>[],
        blockedProfiles: const <String>[],
        darkMode: false,
        blockUnverified: false,
        shareNicknameInQr: false,
        myNickname: 'Broken Snapshot',
        profileGalleryPaths: const <String>[],
        profileBackgroundPaths: const <String>[],
        profileMusicPaths: const <String>[],
        personalConvoIds: const <String>[],
        dbSnapshot: <String, Object?>{
          'messages': <Object?>[
            <String, Object?>{'id': 1, 'body': 'hello'},
          ],
        },
      );
      final payload = await SafeBackupV1.encryptToPayload(
        plain: invalidPlain,
        password: 'Password1!',
      );

      await expectLater(
        controller.restoreFromSafeBackupPayload(
          payload: payload,
          password: 'Password1!',
        ),
        throwsA(
          isA<EncryptedRestoreException>().having(
            (error) => error.kind,
            'kind',
            EncryptedRestoreFailureKind.invalidPayload,
          ),
        ),
      );
      await restartSub.cancel();

      expect(restartEvents, 0);
      expect(controller.authFlowState, AuthFlowState.authenticated);
      expect(prefs.getString('profile_id'), 'profile-live');
      expect(prefs.getString('device_id'), 'device-live');
      expect(prefs.getString('pending_safe_import_v1'), '{"seed":true}');
    },
  );
}
