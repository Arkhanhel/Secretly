// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 УВЕДОМЛЕНИЯ КАК В TELEGRAM — СВОИ ОКОШКИ (29.09.2026, Р1, этап 5).
//
// Владелец: «уведомления как будто от Windows системные — хочу как в
// Telegram». До трёх окошек стопкой в углу, новое — снизу; та же переписка
// обновляет своё окошко; фокус не забирают; не вышло — системное.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_child_windows.dart';
import 'package:secretly_app/ui/desktop/services/desktop_notification_windows.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('secretly/child_window');
  final calls = <MethodCall>[];
  var openFails = false;
  final windows = DesktopNotificationWindows.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
    DesktopChildWindows.instance.debugReset();
    // Окошки — Windows: и сама служба окон, а не только окошки уведомлений.
    // Без этого на CI (Linux) служба отвечала «окна не поддерживаются», а
    // на Mac тест проходил лишь потому, что macOS тоже их поддерживает.
    DesktopChildWindows.debugOperatingSystem = 'windows';
    windows.debugReset();
    DesktopNotificationWindows.debugForceWindows = true;
    calls.clear();
    openFails = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      switch (call.method) {
        case 'isSupported':
          return true;
        case 'open':
          if (openFails) throw PlatformException(code: 'create_failed');
          return binding.platformDispatcher.views.first.viewId;
      }
      return null;
    });
  });

  tearDown(() {
    DesktopNotificationWindows.debugForceWindows = false;
    DesktopChildWindows.debugOperatingSystem = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  DesktopNotificationCard card(String convo, {String body = 'Привет'}) =>
      DesktopNotificationCard(title: 'Игорь', body: body, payload: convo);

  Future<bool> present(WidgetTester t, DesktopNotificationCard c) async {
    var done = false;
    var result = false;
    windows.present(c, sound: true, onTap: () {}).then((ok) {
      result = ok;
      done = true;
    });
    for (var i = 0; i < 60 && !done; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(done, isTrue);
    return result;
  }

  Iterable<MethodCall> named(String m) => calls.where((c) => c.method == m);

  testWidgets('окошко: без рамки, в углу, со звуком', (t) async {
    expect(await present(t, card('chat:a')), isTrue);
    final open = named('open').single.arguments as Map;
    expect(open['notification'], isTrue);
    expect(open['slot'], 0);
    expect(open['width'], DesktopNotificationWindows.size.width);
    expect(named('playNotificationSound'), isNotEmpty);
    expect(windows.debugSlots.first, isNotNull);
    windows.debugReset(); // таймеры погасания — не дольше теста
  });

  testWidgets('новое — снизу, старое поднимается', (t) async {
    await present(t, card('chat:a'));
    final first = windows.debugSlots[0];
    await present(t, card('chat:b'));
    expect(windows.debugSlots[1], first);
    final moved = named('placeAtCorner').single.arguments as Map;
    expect(moved['id'], first);
    expect(moved['slot'], 1);
    windows.debugReset(); // таймеры погасания — не дольше теста
  });

  testWidgets('та же переписка — обновить окошко, а не плодить новое', (t) async {
    await present(t, card('chat:a'));
    calls.clear();
    expect(await present(t, card('chat:a', body: 'Ещё')), isTrue);
    expect(named('open'), isEmpty);
    expect(windows.debugSlots.whereType<String>().length, 1);
    windows.debugReset(); // таймеры погасания — не дольше теста
  });

  testWidgets('мест нет — уходит самое старое', (t) async {
    await present(t, card('chat:a'));
    final oldest = windows.debugSlots[0];
    await present(t, card('chat:b'));
    await present(t, card('chat:c'));
    expect(windows.debugSlots.whereType<String>().length, 3);
    calls.clear();
    await present(t, card('chat:d'));
    final closed = named('close').single.arguments as Map;
    expect(closed['id'], oldest);
    expect(windows.debugSlots.contains(oldest), isFalse);
    windows.debugReset(); // таймеры погасания — не дольше теста
  });

  testWidgets('гаснет само через 6 секунд', (t) async {
    await present(t, card('chat:a'));
    calls.clear();
    await t.pump(DesktopNotificationWindows.visibleFor);
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(named('close'), isNotEmpty);
    expect(windows.debugSlots.every((s) => s == null), isTrue);
  });

  testWidgets('закрыли нижнее — стопка сползает', (t) async {
    await present(t, card('chat:a'));
    await present(t, card('chat:b'));
    final lower = windows.debugSlots[0]!;
    final upper = windows.debugSlots[1]!;
    calls.clear();
    var done = false;
    windows.dismiss(lower).then((_) => done = true);
    for (var i = 0; i < 30 && !done; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(windows.debugSlots[0], upper);
    final moved = named('placeAtCorner').single.arguments as Map;
    expect(moved['slot'], 0);
    windows.debugReset(); // таймеры погасания — не дольше теста
  });

  testWidgets('окно не открылось — «нет», покажут системное', (t) async {
    openFails = true;
    expect(await present(t, card('chat:a')), isFalse);
    expect(windows.debugSlots.every((s) => s == null), isTrue);
    windows.debugReset(); // таймеры погасания — не дольше теста
  });

  testWidgets('выключено в настройках — системные', (t) async {
    DesktopUiPrefs.customNotifications.value = false;
    expect(await present(t, card('chat:a')), isFalse);
    expect(named('open'), isEmpty);
    windows.debugReset(); // таймеры погасания — не дольше теста
  });

  group('🔴 подключено', () {
    final svc = File(
      'lib/ui/desktop/services/desktop_notification_service.dart',
    ).readAsStringSync();

    test('на Windows — сначала своё окошко, потом системное', () {
      final present = svc.substring(svc.indexOf('Future<void> _present({'));
      expect(
        present.indexOf('DesktopNotificationWindows.instance.present('),
        lessThan(present.indexOf('LocalNotification(')),
      );
      expect(present.contains('if (shown) return;'), isTrue);
    });

    test('портрет — только когда имя можно показывать', () {
      expect(svc.contains('avatarPath: showSender ? evt.avatarPath : null,'), isTrue);
    });

    test('входящий в своём окне — без второго уведомления', () {
      expect(svc.contains('if (callShownInOwnWindow?.call(s) ?? false) return;'), isTrue);
    });
  });
}
