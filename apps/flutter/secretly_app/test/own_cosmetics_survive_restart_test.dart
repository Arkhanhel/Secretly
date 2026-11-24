// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 Новая рамка/обложка пропадала после перезапуска, вместо неё — прежняя
// (жалоба тестировщиков, 23.11.2026).
//
// Путь: выбор → настройки (prefs) → публикация на сервер. После перезапуска
// первый обход забирает СВОИ опубликованные метаданные и принимает их
// (`_adoptMyPublishedProfileMeta`), если «своей неотправленной правки нет».
// Но эта отметка жила только в памяти: не дошла публикация до сервера —
// после перезапуска сервер (и местный кэш) отдавали прежнюю рамку, и она
// записывалась поверх выбранной. Так же — когда запрос при запуске не
// удавался (приём шёл из устаревшего кэша), когда ответ, запрошенный ДО
// публикации, приходил ПОСЛЕ неё, и когда пустоту на сервере создавал наш
// же замок подписки (стиралась сохранённая премиальная рамка).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

const _pid = 'self-profile';
const _did = 'self-device';

/// Сервер ключей в памяти: хранит одну строку своих метаданных.
class _FakeKeys extends KeysClient {
  _FakeKeys({this.frameId, this.coverId})
    : super(baseUrl: Uri.parse('https://example.com'));

  String? frameId;
  String? coverId;
  int updatedAtMs = 1000;

  /// Публикация «не доходит» (приложение закрыли, сеть пропала).
  bool publishFails = false;

  /// Чтение с сервера не удаётся.
  bool fetchFails = false;

  /// Чтение висит, пока тест его не отпустит — отдаёт снимок, сделанный в
  /// момент запроса.
  Completer<void>? holdFetch;

  int publishCalls = 0;

  @override
  Future<ProfileMeta> getProfileMeta(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async {
    if (fetchFails) throw const SocketException('offline');
    final snapshot = ProfileMeta(
      exists: true,
      profileId: profileId,
      nickname: null,
      avatarPngB64: null,
      bio: null,
      privacyAudienceJson: null,
      searchableByNickname: false,
      updatedAtMs: updatedAtMs,
      lastActiveAtMs: 0,
      frameId: frameId,
      coverId: coverId,
    );
    final hold = holdFetch;
    if (hold != null) await hold.future;
    return snapshot;
  }

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
    publishCalls++;
    if (publishFails) return false;
    this.frameId = frameId;
    this.coverId = coverId;
    updatedAtMs += 1000;
    return true;
  }
}

Future<void> _settle() async {
  // Публикация идёт фоном (unawaited) и гоняет изолят — даём ей закончиться.
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<AppController> _device(
  AppDb db,
  _FakeKeys keys,
  SharedPreferences prefs,
) async {
  final c = AppController()
    ..seedRoomRuntimeForTesting(db: db, profileId: _pid, deviceId: _did)
    ..seedKeysRuntimeForTesting(keys: keys, prefs: prefs)
    ..loadOwnCosmeticsFromPrefsForTesting(prefs);
  return c;
}

/// Тестовая база открывается без самолечения столбцов, которое в приложении
/// делает каждое открытие (`_ensureProfileMetaColumns`), — догоняем его.
Future<AppDb> _openDb() async {
  final db = await AppDb.openForTesting();
  final cols = (await db.rawQueryForTesting('PRAGMA table_info(profile_meta);'))
      .map((r) => r['name'] as String)
      .toSet();
  for (final c in const ['cover_path', 'emoji_status', 'premium_badge']) {
    if (!cols.contains(c)) {
      await db.rawQueryForTesting('ALTER TABLE profile_meta ADD COLUMN $c TEXT;');
    }
  }
  return db;
}

Future<void> _seedCache(AppDb db, {String? frame, String? cover}) =>
    db.profileMetaUpsert(
      profileId: _pid,
      nickname: null,
      avatarPath: null,
      bio: null,
      privacyAudienceJson: null,
      frameId: frame ?? '',
      coverId: cover ?? '',
      updatedAtMs: 1000,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStorageState = <String, String>{};
  late Directory tempDocumentsDir;

  setUpAll(() async {
    tempDocumentsDir = await Directory.systemTemp.createTemp(
      'secretly-own-cosmetics-test-',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (call) async => tempDocumentsDir.path,
    );
    messenger.setMockMethodCallHandler(_secureStorageChannel, (call) async {
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
          if (key != null) secureStorageState.remove(key);
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
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathProviderChannel, null);
    messenger.setMockMethodCallHandler(_secureStorageChannel, null);
    if (await tempDocumentsDir.exists()) {
      await tempDocumentsDir.delete(recursive: true);
    }
  });

  setUp(() async {
    // Было выбрано и опубликовано раньше: рамка «neon», обложка «space».
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'secretly_my_frame_id': 'neon',
      'secretly_my_cover_id': 'space',
    });
    secureStorageState.clear();
    await SecureSecrets.create().setProfileSecretB64(
      profileId: _pid,
      secretB64: base64Encode(utf8.encode('secret-profile-key')),
    );
  });

  test(
    'выбор, не успевший уйти на сервер, переживает перезапуск и уходит',
    () async {
      final db = await _openDb();
      try {
        final prefs = await SharedPreferences.getInstance();
        final keys = _FakeKeys(frameId: 'neon', coverId: 'space');
        await _seedCache(db, frame: 'neon', cover: 'space');

        // Сеанс 1: выбрали новую рамку и обложку, публикация не дошла.
        keys.publishFails = true;
        final before = await _device(db, keys, prefs);
        await before.setMyFrame('dragon');
        await before.setMyCover('pattern_fireflies');
        await _settle();
        expect(keys.frameId, 'neon', reason: 'на сервер не дошло');

        // Сеанс 2 («перезапуск»): обход забирает своё лицо с сервера.
        final after = await _device(db, keys, prefs);
        await after.refreshMyProfileMetaNow();
        expect(after.myFrameId, 'dragon');
        expect(after.myCoverId, 'pattern_fireflies');
        expect(prefs.getString('secretly_my_frame_id'), 'dragon');
        expect(prefs.getString('secretly_my_cover_id'), 'pattern_fireflies');

        // Публикация при запуске доносит выбор — отметка снимается.
        keys.publishFails = false;
        expect(await after.publishMyProfileMetaForTesting(), isTrue);
        expect(keys.frameId, 'dragon');
        expect(keys.coverId, 'pattern_fireflies');
        expect(
          prefs.getBool('secretly_my_profile_meta_unpublished_v1'),
          isNull,
        );

        // И синхронизация между устройствами работает как прежде: другое
        // устройство выбрало «ferro» — это принимается.
        keys.frameId = 'ferro';
        keys.updatedAtMs += 1000;
        await after.refreshMyProfileMetaNow();
        expect(after.myFrameId, 'ferro');
        expect(prefs.getString('secretly_my_frame_id'), 'ferro');
      } finally {
        await db.close();
      }
    },
  );

  test('явное «Без обложки» тоже не откатывается при перезапуске', () async {
    final db = await _openDb();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = _FakeKeys(frameId: 'neon', coverId: 'space')
        ..publishFails = true;
      await _seedCache(db, frame: 'neon', cover: 'space');

      final before = await _device(db, keys, prefs);
      await before.setMyCover('none');
      await _settle();

      final after = await _device(db, keys, prefs);
      await after.refreshMyProfileMetaNow();
      expect(after.myCoverId, 'none');
    } finally {
      await db.close();
    }
  });

  test('неудачный запрос при запуске не откатывает к старому кэшу', () async {
    final db = await _openDb();
    try {
      // Прошлый сеанс: «dragon» опубликован, кэш своей строки — ещё старый
      // (публикация кэш не обновляет).
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'secretly_my_frame_id': 'dragon',
      });
      final prefs = await SharedPreferences.getInstance();
      final keys = _FakeKeys(frameId: 'dragon')..fetchFails = true;
      await _seedCache(db, frame: 'neon');

      final c = await _device(db, keys, prefs);
      await c.refreshMyProfileMetaNow();
      expect(c.myFrameId, 'dragon');
      expect(prefs.getString('secretly_my_frame_id'), 'dragon');
    } finally {
      await db.close();
    }
  });

  test('ответ, запрошенный до публикации, не откатывает её', () async {
    final db = await _openDb();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = _FakeKeys(frameId: 'neon', coverId: 'space');
      await _seedCache(db, frame: 'neon', cover: 'space');
      final c = await _device(db, keys, prefs);

      // Обход запросил своё лицо (ответ «neon» уже снят), запрос висит.
      keys.holdFetch = Completer<void>();
      final refresh = c.refreshMyProfileMetaNow();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Тем временем выбрали «dragon», и он успел опубликоваться.
      await c.setMyFrame('dragon');
      await _settle();
      expect(keys.frameId, 'dragon');

      // Старый ответ приходит после публикации.
      keys.holdFetch!.complete();
      await refresh;
      expect(c.myFrameId, 'dragon');
      expect(prefs.getString('secretly_my_frame_id'), 'dragon');
    } finally {
      await db.close();
    }
  });

  test(
    'пустота от собственного замка подписки не стирает сохранённую рамку',
    () async {
      final db = await _openDb();
      try {
        SharedPreferences.setMockInitialValues(const <String, Object>{
          'secretly_my_frame_id': 'dragon',
        });
        final prefs = await SharedPreferences.getInstance();
        // Подписка (по мнению устройства) не активна: премиальная рамка
        // публикуется пустой, и сервер честно хранит пустоту.
        final keys = _FakeKeys(frameId: 'dragon');
        await _seedCache(db, frame: 'dragon');
        final c = await _device(db, keys, prefs)
          ..cosmeticsUnlockedOverrideForTesting = false;
        expect(await c.publishMyProfileMetaForTesting(), isTrue);
        expect(keys.frameId, isNull);

        await c.refreshMyProfileMetaNow();
        expect(c.myFrameId, isNull, reason: 'пока замок — не видна');
        expect(
          prefs.getString('secretly_my_frame_id'),
          'dragon',
          reason: 'но выбор сохранён',
        );

        // Подписка вернулась — рамка на месте сама.
        c.cosmeticsUnlockedOverrideForTesting = true;
        expect(c.myFrameId, 'dragon');
      } finally {
        await db.close();
      }
    },
  );
}
