// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// «Создать аккаунт» на компьютере СОЗДАЁТ аккаунт (30.09.2026).
//
// 🔴 ЧТО БЫЛО. Экран создания (23.09) звал
// `createNewServerProfileForCurrentDevice`, а у того ветка для ПК с апреля —
// `resetProfileAndLocalData(); return;`, то есть выход из аккаунта: запрет
// входа взводился, база стиралась, и после перезапуска человек снова стоял на
// выборе входа — без аккаунта и с повисшим признаком «набор не сделан».
//
// Ветку телефона трогать нельзя (мобильная версия выпущена), поэтому у
// компьютера свой путь — [AppController.createDesktopAccountOnThisComputer].

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/transport/keys_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _authRequiredKey = 'desktop_auth_required_after_logout_v1';

/// Сервер ключей в памяти: заводит профиль, принимает устройство и связку.
class _FakeKeys extends KeysClient {
  _FakeKeys({this.failCreate = false})
    : super(baseUrl: Uri.parse('https://keys.example.com'));

  final bool failCreate;
  int createCalls = 0;
  String? registeredDeviceId;
  KeysDeviceClass? registeredClass;
  bool published = false;

  @override
  Future<CreateProfileResult> createProfile() async {
    createCalls += 1;
    if (failCreate) throw StateError('createProfile failed: 503');
    return const CreateProfileResult(
      profileId: 'pid-desktop-new',
      profileSecretB64: 'c2VjcmV0',
    );
  }

  @override
  Future<bool> profileExists(String profileId) async => true;

  @override
  Future<List<String>> listDevices(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async => [?registeredDeviceId];

  @override
  Future<List<KeysDeviceStatus>> listDeviceStatuses(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async => [
    if (registeredDeviceId != null)
      KeysDeviceStatus(deviceId: registeredDeviceId!, hasBundle: published),
  ];

  @override
  Future<DeviceChallenge> deviceChallenge({
    required String profileId,
    required String deviceId,
    required String profileSecretB64,
  }) async => DeviceChallenge(
    nonceB64: 'nonce',
    expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
  );

  @override
  Future<bool> registerDeviceProof({
    required String profileId,
    required String deviceId,
    required String identityKeyPubB64,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
    required String profileSecretB64,
    KeysDeviceClass deviceClass = KeysDeviceClass.mobile,
    String? deviceLabel,
    String? replacesDeviceId,
  }) async {
    registeredDeviceId = deviceId;
    registeredClass = deviceClass;
    return true;
  }

  @override
  Future<bool> publishKeys({
    required String profileId,
    required String deviceId,
    required String identityKeyPubB64,
    required String signedPrekeyPubB64,
    required String signedPrekeySigB64,
    required List<Map<String, Object?>> oneTimePrekeys,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
    required String profileSecretB64,
    String? accountIdentityPubB64,
    String? deviceCertB64,
  }) async {
    published = true;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorage = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  final secrets = <String, String>{};
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('desktop_create_account');
    // Экран входа на компьютере: запрет входа взведён, профиля нет.
    SharedPreferences.setMockInitialValues(<String, Object>{
      _authRequiredKey: true,
      'device_id': 'device-gate',
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathProvider, (_) async => tmp.path);
    messenger.setMockMethodCallHandler(secureStorage, (call) async {
      final args = Map<Object?, Object?>.from(
        call.arguments as Map<Object?, Object?>? ?? const {},
      );
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return key == null ? null : secrets[key];
        case 'write':
          if (key != null) secrets[key] = (args['value'] as String?) ?? '';
          return null;
        case 'delete':
          if (key != null) secrets.remove(key);
          return null;
        case 'containsKey':
          return key != null && secrets.containsKey(key);
        case 'readAll':
          return Map<String, String>.from(secrets);
        case 'deleteAll':
          secrets.clear();
          return null;
      }
      return null;
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    secrets.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathProvider, null);
    messenger.setMockMethodCallHandler(secureStorage, null);
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('🔴 аккаунт заводится, запрет входа снят, имя переживает перезапуск',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final keys = _FakeKeys();
    final controller = AppController()
      ..seedKeysRuntimeForTesting(keys: keys, prefs: prefs);
    var restarts = 0;
    final sub = controller.restartRequested.listen((_) => restarts += 1);
    addTearDown(sub.cancel);

    await controller.createDesktopAccountOnThisComputerForTesting(
      nickname: '  Анна \n  Ли ',
      keys: keys,
    );
    await Future<void>.delayed(Duration.zero);

    expect(keys.createCalls, 1);
    expect(keys.registeredClass, KeysDeviceClass.desktop);
    expect(keys.published, isTrue);
    expect(prefs.getString('profile_id'), 'pid-desktop-new');
    expect(prefs.getString('device_id'), keys.registeredDeviceId);
    expect(prefs.getBool(_authRequiredKey), isFalse);
    expect(controller.authFlowState, AuthFlowState.authenticated);
    // Имя лежит в настройках ДО перезапуска: новый контроллер прочтёт его.
    expect(prefs.getString('my_nickname_v1'), 'Анна Ли');
    expect(restarts, 1);
    // И после перезапуска компьютер НЕ просит войти снова.
    expect(
      AppController.shouldBootstrapRuntimeForStartup(
        isDesktopOrWebPlatform: true,
        desktopAuthRequired: prefs.getBool(_authRequiredKey)!,
        profileId: prefs.getString('profile_id'),
      ),
      isTrue,
    );
  });

  test('🔴 сорвалось — остаёмся на экране входа, без перезапуска', () async {
    final prefs = await SharedPreferences.getInstance();
    final keys = _FakeKeys(failCreate: true);
    final controller = AppController()
      ..seedKeysRuntimeForTesting(keys: keys, prefs: prefs);
    var restarts = 0;
    final sub = controller.restartRequested.listen((_) => restarts += 1);
    addTearDown(sub.cancel);

    await expectLater(
      controller.createDesktopAccountOnThisComputerForTesting(
        nickname: 'Анна',
        keys: keys,
      ),
      throwsA(anything),
    );
    await Future<void>.delayed(Duration.zero);

    expect(prefs.getBool(_authRequiredKey), isTrue);
    expect(prefs.getString('profile_id'), isNull);
    expect(restarts, 0);
    expect(controller.requiresDesktopProfileSelection, isTrue);
  });

  test('путь только для компьютера: телефон его не зовёт', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final prefs = await SharedPreferences.getInstance();
    final keys = _FakeKeys();
    final controller = AppController()
      ..seedKeysRuntimeForTesting(keys: keys, prefs: prefs);
    await expectLater(
      controller.createDesktopAccountOnThisComputerForTesting(
        nickname: 'Анна',
        keys: keys,
      ),
      throwsStateError,
    );
    expect(keys.createCalls, 0);
    // И телефонные экраны нового пути не знают.
    for (final path in const [
      'lib/ui/devices_auth_screen.dart',
      'lib/ui/settings_screen.dart',
    ]) {
      expect(
        File(path).readAsStringSync().contains('createDesktopAccount'),
        isFalse,
        reason: path,
      );
    }
  });

  test('экран создания зовёт путь компьютера, а не выход из аккаунта', () {
    final code = File(
      'lib/ui/desktop/onboarding/desktop_create_account_flow.dart',
    ).readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');
    expect(code.contains('createDesktopAccountOnThisComputer('), isTrue);
    expect(code.contains('createNewServerProfileForCurrentDevice('), isFalse);
    // Имя уходит вместе с созданием, а не вдогонку уходящему контроллеру.
    expect(code.contains('setMyNickname('), isFalse);
    // Экран выбора по-прежнему ничего не создаёт сам.
    final gate = File('lib/ui/desktop/onboarding/desktop_auth_gate.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(gate.contains('createDesktopAccountOnThisComputer'), isFalse);
  });
}
