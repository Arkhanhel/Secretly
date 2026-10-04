// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ОКОШКИ УВЕДОМЛЕНИЙ — ПО ОЧЕРЕДИ (29.09.2026, разбор Р1).
//
// Показы и гашения шли внахлёст: между ожиданиями окна ОС список мест менял
// другой показ или гашение, а неудачное открытие чистило место 0 — уже чужое.
// Окошко, потерявшее место, не гасло никогда и висело поверх всех окон.
// Заодно: Windows просит не беспокоить — своё окошко не выскакивает; при
// перезапуске гаснут все.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_child_windows.dart';
import 'package:secretly_app/ui/desktop/services/desktop_notification_windows.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('secretly/child_window');
  final calls = <MethodCall>[];
  final windows = DesktopNotificationWindows.instance;

  /// Раннер Windows: окна открываются, кроме [failing] — те падают после
  /// [slow]; [accepts] — ответ «можно ли беспокоить».
  void mockRunner({
    String? failing,
    Future<void>? slow,
    bool accepts = true,
  }) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      switch (call.method) {
        case 'isSupported':
          return true;
        case 'acceptsNotifications':
          return accepts;
        case 'open':
          if ((call.arguments as Map)['id'] == failing) {
            await slow;
            throw PlatformException(code: 'create_failed');
          }
          return binding.platformDispatcher.views.first.viewId;
      }
      return null;
    });
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
    DesktopChildWindows.instance.debugReset();
    // Площадка — Windows и на Linux-CI: иначе служба окон ответила бы «нет».
    DesktopChildWindows.debugOperatingSystem = 'windows';
    windows.debugReset();
    DesktopNotificationWindows.debugForceWindows = true;
    calls.clear();
    mockRunner();
  });

  tearDown(() {
    windows.debugReset(); // таймеры погасания — не дольше теста
    DesktopChildWindows.instance.debugReset();
    DesktopNotificationWindows.debugForceWindows = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  DesktopNotificationCard card(String convo) =>
      DesktopNotificationCard(title: 'Игорь', body: 'Привет', payload: convo);

  Iterable<MethodCall> named(String m) => calls.where((c) => c.method == m);

  Future<void> settle(WidgetTester t, bool Function() done) async {
    for (var i = 0; i < 80 && !done(); i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue);
  }

  Future<bool> present(WidgetTester t, String convo) async {
    var done = false;
    var result = false;
    windows.present(card(convo), sound: false, onTap: () {}).then((ok) {
      result = ok;
      done = true;
    });
    await settle(t, () => done);
    return result;
  }

  testWidgets('показы внахлёст — ни одно окошко не теряет места', (t) async {
    // Второе окошко открывается долго и в итоге не открывается.
    final slow = Completer<void>();
    mockRunner(failing: 'notification-1', slow: slow.future);
    expect(await present(t, 'chat:a'), isTrue);
    final a = windows.debugSlots[0]!;
    var bDone = false;
    var bShown = true;
    windows.present(card('chat:b'), sound: false, onTap: () {}).then((ok) {
      bShown = ok;
      bDone = true;
    });
    await t.pump(const Duration(milliseconds: 20));
    // Пока второе открывается: третье сообщение и погасшее первое.
    var cDone = false;
    windows.present(card('chat:c'), sound: false, onTap: () {}).then((_) {
      cDone = true;
    });
    var aGone = false;
    windows.dismiss(a).then((_) => aGone = true);
    // Второе падает, когда третье уже у ОС. С очередью третье ждёт второе, и
    // до ОС не доходит — ждём недолго и роняем второе.
    bool thirdAtOs() => named('open').any(
      (c) => (c.arguments as Map)['id'] == 'notification-2',
    );
    for (var i = 0; i < 20 && !thirdAtOs(); i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    slow.complete();
    await settle(t, () => bDone && cDone && aGone);
    expect(bShown, isFalse, reason: 'не открылось — покажут системное');
    // Раньше неудачное второе чистило место 0 — уже третьего: третье окно
    // оставалось на экране без места, а несуществующее второе числилось в
    // стопке.
    const b = 'notification-1';
    const c = 'notification-2';
    expect(windows.debugSlots, <String?>[c, null, null]);
    expect(DesktopChildWindows.instance.isOpen(c), isTrue);
    expect(DesktopChildWindows.instance.isOpen(b), isFalse);
    // Третье гаснет как обычно — окно ОС закрывается.
    calls.clear();
    var cGone = false;
    windows.dismiss(c).then((_) => cGone = true);
    await settle(t, () => cGone);
    expect((named('close').single.arguments as Map)['id'], c);
    expect(windows.debugSlots.every((s) => s == null), isTrue);
  });

  testWidgets('погасить окошко без места — окно ОС всё равно закрывается', (
    t,
  ) async {
    // Окно открыто, а в стопке его нет — как у окошка, потерявшего место.
    var opened = false;
    DesktopChildWindows.instance
        .open(
          DesktopChildWindowSpec(
            id: 'notification-lost',
            title: 'Игорь',
            size: DesktopNotificationWindows.size,
            notificationSlot: 0,
            builder: (_) => const SizedBox(),
          ),
        )
        .then((ok) => opened = ok);
    await settle(t, () => opened);
    calls.clear();
    var done = false;
    windows.dismiss('notification-lost').then((_) => done = true);
    await settle(t, () => done);
    expect((named('close').single.arguments as Map)['id'], 'notification-lost');
    expect(DesktopChildWindows.instance.isOpen('notification-lost'), isFalse);
  });

  testWidgets('Windows просит не беспокоить — своё окошко не выскакивает', (
    t,
  ) async {
    mockRunner(accepts: false); // презентация, полноэкранная игра…
    expect(await present(t, 'chat:a'), isFalse);
    expect(
      named('open'),
      isEmpty,
      reason: 'покажут системное — его Windows придержит сама',
    );
  });

  testWidgets('перезапуск — гаснут все окошки', (t) async {
    await present(t, 'chat:a');
    await present(t, 'chat:b');
    calls.clear();
    var done = false;
    windows.dismissAll().then((_) => done = true);
    await settle(t, () => done);
    expect(named('close').length, 2);
    expect(windows.debugSlots.every((s) => s == null), isTrue);
  });

  test('🔴 раннер Windows спрашивает систему, можно ли беспокоить', () {
    final cpp = File('windows/runner/child_window.cpp').readAsStringSync();
    expect(cpp.contains('method == "acceptsNotifications"'), isTrue);
    expect(cpp.contains('SHQueryUserNotificationState(&state)'), isTrue);
    expect(cpp.contains('state == QUNS_ACCEPTS_NOTIFICATIONS'), isTrue);
  });

  test('🔴 открыли переписку в главном окне — её окошко гаснет', () {
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    expect(app.contains('_dismissPopupsOnOpen(_chatsSelection.selectedConvoId);'), isTrue);
    expect(app.contains('_dismissPopupsOnOpen(_roomsSelection.selectedConvoId);'), isTrue);
    final open = app.substring(app.indexOf('void _dismissPopupsOnOpen(String convoId) {'));
    // Только при смене переписки: склад оповещает и на каждом обновлении.
    expect(open.indexOf('convoId == _popupsDismissedFor'), lessThan(open.indexOf('dismissFor(convoId)')));
    final focus = app.substring(app.indexOf('void onWindowFocus() {'));
    expect(focus.substring(0, focus.indexOf('\n  }\n')).contains('dismissFor(open)'), isTrue);
  });
}
