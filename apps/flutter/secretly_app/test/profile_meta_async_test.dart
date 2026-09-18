// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/security/secure_secrets.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);
const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

class _BlockingProfileMetaKeysClient extends KeysClient {
  _BlockingProfileMetaKeysClient()
    : super(baseUrl: Uri.parse('https://example.com'));

  final Completer<void> setProfileMetaCalled = Completer<void>();
  final Completer<bool> setProfileMetaResult = Completer<bool>();

  @override
  Future<bool> setProfileMeta({
    required String profileId,
    required String deviceId,
    required String? nickname,
    required String? avatarPngB64,
    required String? bio,
    required String? privacyAudienceJson,
    required bool searchableByNickname,
    String? frameId,
    String? coverId,
    String? coverPngB64,
    String? emojiStatus,
    String? premiumBadge,
    required String signatureB64,
    required String profileSecretB64,
  }) async {
    if (!setProfileMetaCalled.isCompleted) {
      setProfileMetaCalled.complete();
    }
    return setProfileMetaResult.future;
  }
}

class _ProfileMetaAttempt {
  const _ProfileMetaAttempt({
    required this.nickname,
    required this.avatarPngB64,
  });

  final String? nickname;
  final String? avatarPngB64;
}

class _RejectAvatarProfileMetaKeysClient extends KeysClient {
  _RejectAvatarProfileMetaKeysClient()
    : super(baseUrl: Uri.parse('https://example.com'));

  final attempts = <_ProfileMetaAttempt>[];
  final StreamController<int> _attemptsChanged =
      StreamController<int>.broadcast();

  @override
  Future<bool> setProfileMeta({
    required String profileId,
    required String deviceId,
    required String? nickname,
    required String? avatarPngB64,
    required String? bio,
    required String? privacyAudienceJson,
    required bool searchableByNickname,
    String? frameId,
    String? coverId,
    String? coverPngB64,
    String? emojiStatus,
    String? premiumBadge,
    required String signatureB64,
    required String profileSecretB64,
  }) async {
    attempts.add(
      _ProfileMetaAttempt(nickname: nickname, avatarPngB64: avatarPngB64),
    );
    _attemptsChanged.add(attempts.length);
    return avatarPngB64 == null;
  }

  Future<void> waitForAttempts(int count) async {
    if (attempts.length >= count) return;
    await _attemptsChanged.stream
        .firstWhere((value) => value >= count)
        .timeout(const Duration(milliseconds: 800));
  }

  void resetAttempts() {
    attempts.clear();
  }

  @override
  void close() {
    _attemptsChanged.close();
    super.close();
  }
}

Uint8List _sampleAvatarBytes() {
  final image = img.Image(width: 16, height: 12);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, 0x30 + x * 4, 0x50 + y * 5, 0x90, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// Сторож ЗАВИСАНИЯ, а не мерка скорости.
///
/// 🔴 Здесь стояло 400 мс, и проверка падала на занятой машине: подготовка
/// аватара гоняет отдельный изолят и кодирует PNG, а это под нагрузкой само по
/// себе дольше четырёх десятых секунды. Смысл проверки в ПОРЯДКЕ — вызов
/// обязан вернуться ДО того, как публикация метаданных разблокирована, — а
/// порядок держит сама раскладка теста: результат публикации завершается
/// строкой ниже. Срок нужен лишь чтобы упавший в ожидание тест не висел вечно.
const Duration _kDeadlockGuard = Duration(seconds: 10);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStorageState = <String, String>{};
  late Directory tempDocumentsDir;

  setUpAll(() async {
    tempDocumentsDir = await Directory.systemTemp.createTemp(
      'secretly-profile-meta-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
            case 'getApplicationSupportDirectory':
            case 'getTemporaryDirectory':
              return tempDocumentsDir.path;
          }
          return tempDocumentsDir.path;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
          final arguments = Map<Object?, Object?>.from(
            call.arguments as Map<Object?, Object?>? ?? const {},
          );
          final key = arguments['key'] as String?;
          switch (call.method) {
            case 'read':
              return key == null ? null : secureStorageState[key];
            case 'write':
              if (key != null) {
                secureStorageState[key] = (arguments['value'] as String?) ?? '';
              }
              return null;
            case 'delete':
              if (key != null) {
                secureStorageState.remove(key);
              }
              return null;
            case 'deleteAll':
              secureStorageState.clear();
              return null;
            case 'containsKey':
              return key != null && secureStorageState.containsKey(key);
            case 'readAll':
              return Map<String, String>.from(secureStorageState);
          }
          return null;
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
    if (await tempDocumentsDir.exists()) {
      await tempDocumentsDir.delete(recursive: true);
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    secureStorageState.clear();
  });

  test('setMyNickname returns before profile meta publish completes', () async {
    final db = await AppDb.openForTesting();
    final controller = AppController();
    final keys = _BlockingProfileMetaKeysClient();

    try {
      const profileId = 'self-profile';
      const deviceId = 'self-device';
      final prefs = await SharedPreferences.getInstance();
      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: profileId,
        deviceId: deviceId,
      );
      controller.seedKeysRuntimeForTesting(keys: keys, prefs: prefs);
      await SecureSecrets.create().setProfileSecretB64(
        profileId: profileId,
        secretB64: base64Encode(utf8.encode('secret-profile-key')),
      );

      await controller
          .setMyNickname('  Alice   ')
          .timeout(const Duration(milliseconds: 200));

      expect(controller.myNickname, 'Alice');
      await keys.setProfileMetaCalled.future.timeout(
        _kDeadlockGuard,
      );
      keys.setProfileMetaResult.complete(true);
    } finally {
      if (!keys.setProfileMetaResult.isCompleted) {
        keys.setProfileMetaResult.complete(true);
      }
      await db.close();
    }
  });

  test(
    'setMyAvatarFromImageBytes returns before profile meta publish completes',
    () async {
      final db = await AppDb.openForTesting();
      final controller = AppController();
      final keys = _BlockingProfileMetaKeysClient();

      try {
        const profileId = 'self-profile';
        const deviceId = 'self-device';
        final prefs = await SharedPreferences.getInstance();
        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: profileId,
          deviceId: deviceId,
        );
        controller.seedKeysRuntimeForTesting(keys: keys, prefs: prefs);
        await SecureSecrets.create().setProfileSecretB64(
          profileId: profileId,
          secretB64: base64Encode(utf8.encode('secret-profile-key')),
        );

        await controller
            .setMyAvatarFromImageBytes(_sampleAvatarBytes())
            .timeout(_kDeadlockGuard);

        expect(controller.myAvatarPath, isNotNull);
        await keys.setProfileMetaCalled.future.timeout(
          _kDeadlockGuard,
        );
        keys.setProfileMetaResult.complete(true);
      } finally {
        if (!keys.setProfileMetaResult.isCompleted) {
          keys.setProfileMetaResult.complete(true);
        }
        await db.close();
      }
    },
  );

  test(
    'profile meta publish retries without avatar when avatar is rejected',
    () async {
      final db = await AppDb.openForTesting();
      final controller = AppController();
      final keys = _RejectAvatarProfileMetaKeysClient();

      try {
        const profileId = 'self-profile';
        const deviceId = 'self-device';
        final prefs = await SharedPreferences.getInstance();
        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: profileId,
          deviceId: deviceId,
        );
        controller.seedKeysRuntimeForTesting(keys: keys, prefs: prefs);
        await SecureSecrets.create().setProfileSecretB64(
          profileId: profileId,
          secretB64: base64Encode(utf8.encode('secret-profile-key')),
        );

        await controller.setMyNickname('Alice');
        await keys.waitForAttempts(1);
        keys.resetAttempts();

        await controller
            .setMyAvatarFromImageBytes(_sampleAvatarBytes())
            .timeout(_kDeadlockGuard);
        await keys.waitForAttempts(2);

        expect(keys.attempts.first.nickname, 'Alice');
        expect(keys.attempts.first.avatarPngB64, isNotNull);
        expect(keys.attempts.last.nickname, 'Alice');
        expect(keys.attempts.last.avatarPngB64, isNull);
      } finally {
        keys.close();
        await db.close();
      }
    },
  );
}
