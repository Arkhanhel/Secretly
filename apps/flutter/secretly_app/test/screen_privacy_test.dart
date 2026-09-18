// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/security/screen_privacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SEC-11 (26.08.2026). Настройка «скрывать содержимое экрана».
//
// 🔴 Главное свойство здесь не «флаг ставится», а «включённым он показывается
// только когда он действительно стоит». Приватность, о которой соврали, хуже
// отсутствующей: человек видит защиту, ведёт себя смелее — и не защищён.

const _channel = MethodChannel('secretly/screen_privacy');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test('🔴 отказ системы НЕ сохраняется как включённая настройка', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    messenger.setMockMethodCallHandler(_channel, (call) async => false);

    final controller = AppController();
    final ok = await controller.setScreenPrivacy(true);

    expect(ok, isFalse, reason: 'вызывающая сторона обязана узнать об отказе');
    expect(
      controller.screenPrivacy,
      isFalse,
      reason: 'переключатель не имеет права показывать защиту, которой нет',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('screen_privacy_v1'),
      isNot(true),
      reason: 'иначе на следующем запуске настройка «включена», а экран открыт',
    );
  });

  test('согласие системы сохраняется и переживает перезапуск', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    messenger.setMockMethodCallHandler(_channel, (call) async => true);

    final controller = AppController();
    expect(await controller.setScreenPrivacy(true), isTrue);
    expect(controller.screenPrivacy, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('screen_privacy_v1'), isTrue);
  });

  test('выключение доходит до системы, а не только до настроек', () async {
    // Обратное направление ломается тише прямого: настройка выключена, а флаг
    // остался — человек считает, что демонстрация экрана снова работает.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final seen = <bool>[];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      seen.add((call.arguments as Map)['enabled'] as bool);
      return true;
    });

    final controller = AppController();
    await controller.setScreenPrivacy(true);
    await controller.setScreenPrivacy(false);

    expect(seen, containsAllInOrder(<bool>[true, false]));
    expect(controller.screenPrivacy, isFalse);
  });

  test('🔴 отсутствие нативной части не роняет запуск', () async {
    // Сборки без нативного канала существуют (инструменты, тесты, настольная
    // версия). Настройка приватности не имеет права уронить приложение.
    messenger.setMockMethodCallHandler(_channel, null);
    await expectLater(ScreenPrivacy.apply(enabled: true), completes);
  });
}
