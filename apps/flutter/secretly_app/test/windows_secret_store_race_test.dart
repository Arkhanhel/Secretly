// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// Подделка платформы хранилища; pubspec общий с выпущенным телефоном, поэтому
// пакет берётся транзитивно (как в desktop_app_lock_test).
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/security/secure_secrets.dart';
import 'package:secretly_app/security/serialized_secure_storage.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/relay_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Как `flutter_secure_storage_windows` 3.1.2: все секреты — один «файл»,
/// каждая операция читает его целиком и записывает целиком, между — await.
class _FileLikeStore extends FlutterSecureStoragePlatform {
  Map<String, String> file = <String, String>{};
  String? failWriteOf;

  Future<Map<String, String>> _load() async {
    await Future<void>.delayed(Duration.zero);
    return Map<String, String>.of(file);
  }

  Future<void> _save(Map<String, String> next) async {
    await Future<void>.delayed(Duration.zero);
    file = next;
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    if (key == failWriteOf) throw StateError('disk full');
    final m = await _load();
    m[key] = value;
    await _save(m);
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => (await _load())[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => (await _load()).containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    final m = await _load();
    m.remove(key);
    await _save(m);
  }

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) =>
      _load();

  @override
  Future<void> deleteAll({required Map<String, String> options}) =>
      _save(<String, String>{});
}

/// Windows-версия теряла секреты: ключ устройства (реле — «неверная подпись»,
/// сообщения копились на сервере) и пароль базы (вход заперт при запуске).
/// Причина — гонка записей в однофайловом хранилище (26.09.2026).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterSecureStoragePlatform original;
  late _FileLikeStore store;
  setUp(() {
    original = FlutterSecureStoragePlatform.instance;
    store = _FileLikeStore();
    FlutterSecureStoragePlatform.instance = store;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
  tearDown(() {
    FlutterSecureStoragePlatform.instance = original;
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> writeTen(FlutterSecureStorage s) => Future.wait([
    for (var i = 0; i < 10; i++) s.write(key: 'k$i', value: 'v$i'),
  ]);

  group('хранилище', () {
    test('подделка честная: без очереди одновременные записи теряются', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await writeTen(const FlutterSecureStorage());
      expect(store.file.length, lessThan(10));
    });

    test('🔴 на Windows очередь сохраняет все записи', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await writeTen(const SerializedSecureStorage());
      expect(store.file.length, 10);
      expect(await const SerializedSecureStorage().read(key: 'k7'), 'v7');
    });

    test('сбой одной записи не останавливает очередь', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      store.failWriteOf = 'bad';
      const s = SerializedSecureStorage();
      final failed = s.write(key: 'bad', value: 'x');
      final after = s.write(key: 'good', value: 'y');
      await expectLater(failed, throwsStateError);
      await after;
      expect(store.file['good'], 'y');
    });

    test('очередь — только на Windows', () {
      for (final p in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = p;
        expect(SerializedSecureStorage.serializes, isFalse, reason: '$p');
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(SerializedSecureStorage.serializes, isTrue);
    });
  });

  group('база', () {
    test('🔴 на Windows и Linux — папка приложения, остальным — как было', () {
      expect(AppDb.databaseLivesInAppSupport(TargetPlatform.windows), isTrue);
      expect(AppDb.databaseLivesInAppSupport(TargetPlatform.linux), isTrue);
      for (final p in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        expect(AppDb.databaseLivesInAppSupport(p), isFalse, reason: '$p');
      }
    });

    test('🔴 база есть, ключа нет: Windows — потеря, телефон — подождать',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await expectLater(
        SecureSecrets.create().requireExistingDbPassphrase(),
        throwsA(isA<DbPassphraseLost>()),
      );
      for (final p in [TargetPlatform.iOS, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = p;
        await expectLater(
          SecureSecrets.create().requireExistingDbPassphrase(),
          throwsA(isA<DbPassphraseUnavailable>()),
          reason: '$p',
        );
      }
    });
  });

  group('реле: неверная подпись', () {
    test('ответ 401 «bad signature» доходит до контроллера', () async {
      final db = await AppDb.openForTesting();
      addTearDown(db.close);
      var calls = 0;
      final relay = RelayClient(
        db: db,
        deviceId: 'device-self',
        selfProfileId: 'self-profile',
        deviceKeys: DeviceKeys.create(),
        wsUrl: Uri.parse('ws://example.test/ws'),
        httpBaseUrl: Uri.parse('https://relay.example.test'),
        httpClient: MockClient(
          (request) async => http.Response('bad signature', 401),
        ),
        identityKeyPairOverride: await Ed25519().newKeyPair(),
        onDelivered: ({required msgId, required ciphertextB64}) async => true,
        loadNextSeq: () async => 1,
        saveNextSeq: (_) async {},
      );
      relay.onBadSignature = () => calls++;
      await relay.pumpInbox(force: true);
      expect(calls, 1);
    });

    test('ПК просит привязать заново примерно после минуты отказов', () {
      expect(AppController.relayBadSignatureShouldRelink(5), isFalse);
      expect(AppController.relayBadSignatureShouldRelink(6), isTrue);
    });

    group('порядок в исходнике', () {
      final src = File('lib/app/app_controller.dart').readAsStringSync();

      String body(String signature, int span) {
        final start = src.indexOf(signature);
        expect(start, greaterThan(0), reason: signature);
        return src.substring(start, start + span);
      }

      test('хук подключён везде, где подключён «неизвестное устройство»', () {
        int n(String s) => RegExp(RegExp.escape(s)).allMatches(src).length;
        expect(n('relay.onBadSignature = _onRelaySaysBadSignature;'),
            n('relay.onUnknownDevice = _onRelaySaysUnknownDevice;'));
      });

      test('🔴 только ПК; удачный ответ реле обнуляет счёт', () {
        final h = body('void _onRelaySaysBadSignature() {', 900);
        final gate = h.indexOf('if (!_isDesktopOrWebPlatform');
        final relink = h.indexOf('await _enterDesktopUnlinkedMode(prefs, null);');
        expect(gate, greaterThan(0));
        expect(relink, greaterThan(gate));
        expect(
          body('void _onRelayAcceptedOwnDevice() {', 200)
              .contains('_relayBadSignatureStreak = 0;'),
          isTrue,
        );
      });
    });
  });
}
