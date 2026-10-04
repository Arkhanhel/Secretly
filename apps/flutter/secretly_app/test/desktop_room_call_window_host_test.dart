// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 СОЗВОН КОМНАТЫ — В СВОЁМ ОКНЕ ОС (29.09.2026, Р1, этап 3).
//
// Как звонок на двоих: окно можно увести на другой монитор и закрепить поверх
// всех. Отличие — крестик НЕ выводит из созвона: окно прячется, созвон идёт,
// в главном окне остаются мини-окно и полоса «Вернуться».

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/calls/room_call_window_host.dart';
import 'package:secretly_app/ui/desktop/services/desktop_child_windows.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('secretly/child_window');
  final calls = <MethodCall>[];
  var supported = true;
  late DesktopAppViewModel vm;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
    DesktopChildWindows.instance.debugReset();
    calls.clear();
    supported = true;
    vm = DesktopAppViewModel(controller: AppController());
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      switch (call.method) {
        case 'isSupported':
          return supported;
        case 'open':
          return binding.platformDispatcher.views.first.viewId;
      }
      return null;
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<bool> open(WidgetTester t, String room) async {
    var done = false;
    var result = false;
    DesktopRoomCallWindows.open(vm: vm, groupId: room, title: 'Кофе').then((
      ok,
    ) {
      result = ok;
      done = true;
    });
    for (var i = 0; i < 50 && !done; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(done, isTrue);
    return result;
  }

  Future<void> closeWindow(WidgetTester t) async {
    var done = false;
    DesktopRoomCallWindows.close().then((_) => done = true);
    for (var i = 0; i < 50 && !done; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('своё окно: размер созвона, закрепление — как решил человек', (
    t,
  ) async {
    DesktopUiPrefs.callWindowPinned.value = true;
    expect(await open(t, 'group:r1'), isTrue);
    final args = calls.lastWhere((c) => c.method == 'open').arguments as Map;
    expect(args['id'], DesktopRoomCallWindows.windowId);
    expect(args['width'], DesktopRoomCallWindows.size.width);
    expect(args['topmost'], isTrue);
    expect(DesktopRoomCallWindows.openRoomId, 'group:r1');
    await closeWindow(t);
    expect(DesktopRoomCallWindows.openRoomId, isNull);
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  testWidgets('та же комната — окно вперёд, другая — старое уступает', (
    t,
  ) async {
    expect(await open(t, 'group:r1'), isTrue);
    calls.clear();
    expect(await open(t, 'group:r1'), isTrue);
    expect(calls.map((c) => c.method), contains('focus'));
    expect(calls.map((c) => c.method), isNot(contains('open')));
    calls.clear();
    expect(await open(t, 'group:r2'), isTrue);
    final order = calls.map((c) => c.method).toList();
    expect(order.indexOf('close'), lessThan(order.indexOf('open')));
    expect(DesktopRoomCallWindows.openRoomId, 'group:r2');
    await closeWindow(t);
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  // 🔴 Окно закрыли, пока оно открывалось (выход из созвона, перезапуск):
  // «нет» от open значило бы «покажи созвон поверх главного окна».
  testWidgets('закрыли, пока окно созвона открывалось, — созвон не всплывает поверх главного', (
    t,
  ) async {
    DesktopChildWindows.debugOperatingSystem = 'windows';
    final nativeOpen = Completer<void>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      switch (call.method) {
        case 'isSupported':
          return true;
        case 'open':
          await nativeOpen.future;
          return binding.platformDispatcher.views.first.viewId;
      }
      return null;
    });
    var done = false;
    var own = false;
    DesktopRoomCallWindows.open(vm: vm, groupId: 'group:r1', title: 'Кофе').then(
      (ok) {
        own = ok;
        done = true;
      },
    );
    await t.pump();
    var closed = false;
    DesktopRoomCallWindows.close().then((_) => closed = true);
    nativeOpen.complete();
    for (var i = 0; i < 50 && !(done && closed); i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(done && closed, isTrue);
    expect(own, isTrue, reason: 'созвон закрыли нарочно — другого показа не нужно');
    expect(calls.map((c) => c.method), isNot(contains('show')));
    expect(DesktopRoomCallWindows.openRoomId, isNull);
  });

  testWidgets('нет слоя или выключено — созвон поверх главного окна', (t) async {
    DesktopUiPrefs.callInOwnWindow.value = false;
    expect(await open(t, 'group:r1'), isFalse);
    DesktopUiPrefs.callInOwnWindow.value = true;
    supported = false;
    DesktopChildWindows.instance.debugReset();
    expect(await open(t, 'group:r1'), isFalse);
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  group('🔴 подключено', () {
    final host = File(
      'lib/ui/desktop/calls/room_call_window_host.dart',
    ).readAsStringSync();
    final window = File(
      'lib/ui/desktop/calls/room_call_window.dart',
    ).readAsStringSync();
    final section = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();

    test('крестик прячет окно, из созвона не выводит', () {
      // `minimize` = `close` + вывести главное окно из трея (30.09.2026).
      expect(host.contains('onCloseRequested: () => unawaited(minimize()),'), isTrue);
      expect(host.contains('leaveRelayRoomCall'), isFalse);
    });

    test('окно созвона закрывается хозяином, а не навигатором главного окна', () {
      final minimize = window.substring(window.indexOf('void _minimize() {'));
      expect(minimize.contains('_closeWindow();'), isTrue);
      expect(window.contains('if (mounted) _closeWindow();'), isTrue);
      expect(window.contains('if (ownWindow == null)\n            const Positioned.fill(child: DesktopWindowDragRegion()),'), isTrue);
      expect(window.contains('l10n.desktopCallPinWindow'), isTrue);
    });

    test('«Позвонить» в группе и «Вернуться» идут через своё окно, с откатом', () {
      final start = section.substring(section.indexOf('void _startRoomCall() {'));
      expect(start.indexOf('DesktopRoomCallWindows.open('), lessThan(start.indexOf('_pushRoomCallRoute();')));
      final ret = app.substring(app.indexOf('void _returnToRoomCall('));
      expect(ret.contains('unawaited(DesktopRoomCallWindows.focus());'), isTrue);
      expect(ret.indexOf('DesktopRoomCallWindows.open('), lessThan(ret.indexOf('_pushRoomCallRoute(vm, roomId, title);')));
    });

    test('выход с полосы закрывает и своё окно созвона', () {
      final leave = app.substring(app.indexOf('Future<void> _leaveRoomCall() async {'));
      expect(leave.indexOf('unawaited(DesktopRoomCallWindows.close());'), greaterThan(0));
    });
  });
}
