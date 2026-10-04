// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ЗВОНОК В СВОЁМ ОКНЕ ОС (29.09.2026, Р1).
//
// Владелец: «при нажатии на "позвонить" открывалось отдельное окно Windows,
// не внутри приложения… и я мог его закрепить поверх приложений». Одно окно
// на весь звонок: входящий — маленькое поверх всех, после «Принять» оно
// растёт; звонок кончился — окно закрывается; ОС отказала — звонок остаётся
// в главном окне, как раньше.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_state.dart';
import 'package:secretly_app/ui/desktop/calls/direct_call_window.dart';
import 'package:secretly_app/ui/desktop/services/desktop_child_windows.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('secretly/child_window');
  final calls = <MethodCall>[];
  var openFails = false;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
    DesktopChildWindows.instance.debugReset();
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
          // Вид окна — тот, что есть у тестовой среды.
          return binding.platformDispatcher.views.first.viewId;
      }
      return null;
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  CallState state(CallPhase phase, {String id = 'c1', bool video = false}) =>
      CallState(phase: phase, callId: id, isVideo: video, peerName: 'Игорь');

  Future<DesktopDirectCallWindow> ready() async {
    await DesktopChildWindows.instance.isSupported();
    return DesktopDirectCallWindow(
      builder: (_) => const SizedBox(),
      onCloseRequested: () {},
    );
  }

  List<String> methods() => calls
      .map((c) => c.method)
      .where((m) => m != 'isSupported')
      .toList(growable: false);

  Map<Object?, Object?> argsOf(String method) =>
      calls.lastWhere((c) => c.method == method).arguments
          as Map<Object?, Object?>;

  /// Служба окон ждёт кадра (`endOfFrame`) — в тесте кадры рисует `pump`.
  Future<void> drive(WidgetTester t, Future<void> Function() body) async {
    var done = false;
    Object? error;
    body().then((_) => done = true, onError: (Object e) {
      error = e;
      done = true;
    });
    for (var i = 0; i < 50 && !done; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    if (error != null) throw error!;
    expect(done, isTrue, reason: 'сверка окна не закончилась');
  }

  testWidgets('входящий — маленькое окно поверх всех', (t) async {
    final w = await ready();
    expect(w.handles(state(CallPhase.ringingIncoming)), isTrue);
    await drive(t, () => w.sync(state(CallPhase.ringingIncoming), title: 'Игорь'));
    final open = argsOf('open');
    expect(open['width'], DesktopDirectCallWindowShape.incoming.size.width);
    expect(open['topmost'], isTrue);
    expect(open['title'], 'Игорь');
    expect(w.isOpen, isTrue);
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  testWidgets('«Принять» — окно растёт до разговора и перестаёт висеть поверх', (
    t,
  ) async {
    final w = await ready();
    await drive(t, () => w.sync(state(CallPhase.ringingIncoming), title: 'Игорь'));
    calls.clear();
    await drive(t, () => w.sync(state(CallPhase.connecting), title: 'Игорь'));
    expect(methods(), containsAllInOrder(<String>['setSize', 'setTopmost', 'setTitle']));
    expect(argsOf('setSize')['height'], DesktopDirectCallWindowShape.audio.size.height);
    // Наименьший — от разговора, а не 340×190 входящего.
    expect(argsOf('setSize')['minWidth'], DesktopDirectCallWindowShape.audio.minSize.width);
    expect(argsOf('setSize')['minHeight'], DesktopDirectCallWindowShape.audio.minSize.height);
    expect(argsOf('setTopmost')['on'], isFalse);
    expect(w.shape, DesktopDirectCallWindowShape.audio);
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  testWidgets('видео — окно шире; обратно не сжимается', (t) async {
    final w = await ready();
    await drive(t, () => w.sync(state(CallPhase.connected), title: 'И'));
    calls.clear();
    await drive(t, () => w.sync(state(CallPhase.connected, video: true), title: 'И'));
    expect(argsOf('setSize')['width'], DesktopDirectCallWindowShape.video.size.width);
    calls.clear();
    await drive(t, () => w.sync(state(CallPhase.connected), title: 'И'));
    expect(methods(), isNot(contains('setSize')));
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  testWidgets('звонок кончился — окно закрывается', (t) async {
    final w = await ready();
    await drive(t, () => w.sync(state(CallPhase.connected), title: 'И'));
    // Закрытие ждёт кадра: сначала из дерева уходит View окна.
    await drive(t, () => w.sync(state(CallPhase.ended), title: 'И'));
    expect(methods(), contains('close'));
    expect(w.isOpen, isFalse);
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  testWidgets('ОС отказала — звонок остаётся в главном окне', (t) async {
    openFails = true;
    final w = await ready();
    var changed = 0;
    w.changes.addListener(() => changed++);
    await drive(t, () => w.sync(state(CallPhase.ringingOutgoing), title: 'И'));
    expect(w.isOpen, isFalse);
    expect(w.handles(state(CallPhase.ringingOutgoing)), isFalse);
    expect(changed, 1, reason: 'главное окно должно перерисоваться и показать звонок');
    // Следующий звонок пробует снова.
    expect(w.handles(state(CallPhase.ringingOutgoing, id: 'c2')), isTrue);
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  test('настройка выключена — как раньше, внутри главного окна', () async {
    final w = await ready();
    DesktopUiPrefs.callInOwnWindow.value = false;
    expect(w.handles(state(CallPhase.connected)), isFalse);
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  // 🔴 Выход или перезапуск, пока окно звонка открывается: раньше isOpen в
  // эту минуту отвечал «нет», и окно появлялось уже без хозяина.
  testWidgets('dispose, пока окно открывается, — окно закрыто и не показано', (
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
    final w = await ready();
    var synced = false;
    w.sync(state(CallPhase.ringingIncoming), title: 'Игорь').then((_) {
      synced = true;
    });
    await t.pump();
    expect(methods(), contains('open'), reason: 'ОС уже создаёт окно');
    var disposed = false;
    w.dispose().then((_) => disposed = true);
    nativeOpen.complete();
    for (var i = 0; i < 50 && !(synced && disposed); i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(synced && disposed, isTrue);
    expect(methods(), isNot(contains('show')));
    expect(methods().last, 'close');
    expect(w.isOpen, isFalse);
  });

  // 🔴 Крестик окна, когда звонка уже нет: «положить трубку» ничего не
  // делало, и окно оставалось на экране без способа его убрать.
  testWidgets('крестик без звонка закрывает окно сам, со звонком — спрашивает хозяина', (
    t,
  ) async {
    DesktopChildWindows.debugOperatingSystem = 'windows';
    var asked = 0;
    var active = true;
    await DesktopChildWindows.instance.isSupported();
    final w = DesktopDirectCallWindow(
      builder: (_) => const SizedBox(),
      onCloseRequested: () => asked++,
      callActive: () => active,
    );
    await drive(t, () => w.sync(state(CallPhase.connected), title: 'И'));
    // Крестик окна ОС — так его передаёт раннер.
    Future<void> pressCross() => binding.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('closeRequested', <String, Object?>{
              'id': DesktopDirectCallWindow.windowId,
            }),
          ),
          (_) {},
        );
    await drive(t, pressCross);
    expect(asked, 1, reason: 'звонок идёт — решает хозяин');
    expect(w.isOpen, isTrue);
    // Звонка уже нет, а окно ещё на экране.
    active = false;
    calls.clear();
    await drive(t, pressCross);
    for (var i = 0; i < 20 && !methods().contains('close'); i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(asked, 1, reason: 'без звонка хозяина не спрашивают');
    expect(w.isOpen, isFalse);
    expect(methods(), contains('close'));
  });

  group('🔴 подключено', () {
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/ui/desktop/calls/one_to_one_call_screen.dart',
    ).readAsStringSync();

    test('главное окно не рисует звонок, который живёт в своём окне', () {
      expect(app.contains('if (_callWindow?.handles(s) ?? false) return null;'), isTrue);
      expect(app.contains('!(_callWindow?.handles(s) ?? false);'), isTrue);
      expect(app.contains('unawaited(_callWindow?.sync(s, title: _callWindowTitle(s)));'), isTrue);
    });

    test('крестик окна: входящий — отклонить, разговор — положить трубку', () {
      final close = app.substring(app.indexOf('void _onCallWindowCloseRequested()'));
      expect(close.indexOf('declineIncoming()'), lessThan(close.indexOf('hangup()')));
    });

    test('«Вернуться» из полосы — окно звонка вперёд', () {
      expect(app.contains('unawaited(w.focus());'), isTrue);
    });

    String body(String signature) {
      final from = app.indexOf(signature);
      expect(from, greaterThan(0), reason: signature);
      return app.substring(from, app.indexOf('\n  }\n', from));
    }

    test('перезапуск и выход закрывают окно созвона и окошки уведомлений', () {
      expect(
        body('void _disposeCallManager() {')
            .contains('unawaited(DesktopRoomCallWindows.close());'),
        isTrue,
      );
      expect(
        body('Future<void> _disposeNotificationService() async {')
            .contains('DesktopNotificationWindows.instance.dismissAll()'),
        isTrue,
      );
    });

    test('«звонок в своём окне» и экранный диктор слушаются посреди звонка', () {
      expect(
        app.contains(
          'DesktopUiPrefs.callInOwnWindow.addListener(_onCallPresentationChanged);',
        ),
        isTrue,
      );
      expect(
        app.contains(
          'DesktopUiPrefs.callInOwnWindow.removeListener(_onCallPresentationChanged);',
        ),
        isTrue,
      );
      expect(
        app.contains('DesktopChildWindows.instance.availability.addListener('),
        isTrue,
      );
      final handler = body('void _onCallPresentationChanged() {');
      expect(handler.contains('window.sync(s, title: _callWindowTitle(s))'), isTrue);
      expect(handler.contains('DesktopRoomCallWindows.close()'), isTrue);
    });

    // 🔴 «Принять» у входящего у края экрана уводило кнопки разговора под
    // панель задач: окно росло от левого верхнего угла.
    test('окно растёт от середины, в пределах экрана, наименьший — от нового вида', () {
      final cpp = File('windows/runner/child_window.cpp').readAsStringSync();
      final from = cpp.indexOf('void SecretlyChildWindow::SetLogicalSize(');
      final setSize = cpp.substring(from, cpp.indexOf('\n}\n', from));
      expect(setSize.contains('SWP_NOMOVE'), isFalse);
      expect(setSize.contains('mi.rcWork'), isTrue);
      expect(setSize.contains('min_width_ = static_cast<int>(min_width);'), isTrue);
      expect(cpp.contains('DoubleArg(*args, "minHeight", 0)'), isTrue);
      final swift = File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();
      final resize = swift.substring(
        swift.indexOf('private func resize(_ window: NSWindow, content: NSSize) {'),
      );
      expect(resize.contains('visibleFrame'), isTrue);
      expect(resize.contains('old.midX'), isTrue);
      expect(swift.contains('window.contentMinSize = NSSize(\n            width: minWidth.doubleValue'), isTrue);
    });

    test('окно звонка не открылось — уведомление о входящем сверяется заново', () {
      expect(
        body('void _onCallWindowChanged() {')
            .contains('_notifService?.recheckIncomingCall();'),
        isTrue,
      );
      expect(app.contains('callActive: () => cm.state.value.isActive,'), isTrue);
    });

    test('в своём окне у экрана звонка нет чужих кнопок окна', () {
      expect(screen.contains('if (ownWindow == null)\n            const Positioned.fill(child: DesktopWindowDragRegion()),'), isTrue);
      expect(screen.contains('if (_isWindows && ownWindow == null)'), isTrue);
      expect(screen.contains('l10n.desktopCallPinWindow'), isTrue);
      // «Во весь экран» — у своего окна, а не у главного.
      final toggle = screen.substring(screen.indexOf('Future<void> _toggleFullScreen() async {'));
      expect(toggle.indexOf('own.onSetFullScreen(next)'), lessThan(toggle.indexOf('windowManager.isFullScreen()')));
    });
  });
}
