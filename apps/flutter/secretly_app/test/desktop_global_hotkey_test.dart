// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// C-5: ОБЩЕСИСТЕМНОЕ «ПОКАЗАТЬ SECRETLY» (⌥⌘S).
//
// 🔴 ГЛАВНОЕ ЗДЕСЬ — ЧЕСТНОСТЬ ПЕРЕКЛЮЧАТЕЛЯ. Сочетание общесистемное, и его
// может держать другая программа. Переключатель, который в этом случае остался
// бы включённым, врал бы: человек нажимал бы ⌥⌘S, ничего бы не происходило, и
// винил бы нас.
//
// 🔴 И ОТДЕЛЬНО — ВЫКЛЮЧЕНО ПО УМОЛЧАНИЮ. Включив молча, мы отняли бы
// комбинацию у программы, которой человек пользуется, и он не понял бы, кто её
// забрал.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_global_hotkey_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('secretly/global_hotkey');
  late List<MethodCall> calls;

  void mock(Object? Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async {
      calls.add(c);
      return handler(c);
    });
  }

  setUp(() => calls = <MethodCall>[]);
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('по умолчанию выключено', () {
    final s = DesktopGlobalHotKeyService(channel: channel, onMacOS: true);
    addTearDown(s.dispose);
    expect(s.enabled.value, isFalse);
    expect(s.taken.value, isFalse);
  });

  test('включение доходит до системы', () async {
    mock((_) => true);
    final s = DesktopGlobalHotKeyService(channel: channel, onMacOS: true);
    addTearDown(s.dispose);
    final ok = await s.setEnabled(true, persist: false);
    expect(ok, isTrue);
    expect(s.enabled.value, isTrue);
    expect(calls.single.arguments['enabled'], isTrue);
  });

  test('🔴 сочетание занято — переключатель возвращается и говорит почему',
      () async {
    mock((_) => false);
    final s = DesktopGlobalHotKeyService(channel: channel, onMacOS: true);
    addTearDown(s.dispose);
    final ok = await s.setEnabled(true, persist: false);
    expect(ok, isFalse);
    expect(s.enabled.value, isFalse, reason: 'включённым остаться нельзя');
    expect(s.taken.value, isTrue, reason: 'причину надо показать человеку');
  });

  test('🔴 выключение удаётся ВСЕГДА', () async {
    // Нечего держать — значит и снимать нечего. Запереть переключатель во
    // включённом состоянии из-за отказа площадки было бы ложью наоборот.
    mock((_) => false);
    final s = DesktopGlobalHotKeyService(channel: channel, onMacOS: true);
    addTearDown(s.dispose);
    expect(await s.setEnabled(false, persist: false), isTrue);
    expect(s.enabled.value, isFalse);
    expect(s.taken.value, isFalse);
  });

  test('сбой моста не роняет приложение', () async {
    mock((_) => throw PlatformException(code: 'boom'));
    final s = DesktopGlobalHotKeyService(channel: channel, onMacOS: true);
    addTearDown(s.dispose);
    expect(await s.setEnabled(true, persist: false), isFalse);
    expect(s.enabled.value, isFalse);
  });

  test('🔴 не на маке служба честно НИЧЕГО не делает', () async {
    // Сочетание общесистемное и регистрируется через Carbon — этого нет ни у
    // Windows, ни у Linux. Переключатель, который там притворяется рабочим,
    // хуже отсутствующего: человек решит, что забрал комбинацию у другой
    // программы, и пойдёт искать несуществующую беду.
    mock((_) => true);
    final s = DesktopGlobalHotKeyService(channel: channel, onMacOS: false);
    addTearDown(s.dispose);
    expect(s.supported, isFalse);
    expect(await s.setEnabled(true, persist: false), isFalse);
    expect(calls, isEmpty, reason: 'на чужой площадке полезли к системе');
    expect(s.enabled.value, isFalse);
  });
}
