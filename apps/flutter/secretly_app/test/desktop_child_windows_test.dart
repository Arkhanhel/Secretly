// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ОТДЕЛЬНЫЕ ОКНА ОС НА ТОМ ЖЕ ДВИЖКЕ (29.09.2026, Р1).
//
// Владелец: «при нажатии на "позвонить" должно открываться отдельное окно
// Windows… чтобы я мог его закрепить поверх приложений». Свой слой: второй
// вид того же движка (Windows — `child_window.cpp`, macOS — `ChildWindowBridge`
// в `MainFlutterWindow.swift`). Спайк 29.09: на macOS самотест прошёл трижды
// (виды 1, 2, 3) на отладочном движке, без срабатывания NSAssert.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_child_windows.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('secretly/child_window');
  final calls = <MethodCall>[];

  void mockNative(Object? Function(MethodCall call) answer) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer(call);
    });
  }

  setUp(() {
    calls.clear();
    DesktopChildWindows.instance.debugReset();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  DesktopChildWindowSpec spec() => DesktopChildWindowSpec(
    id: 'call',
    title: 'Звонок',
    size: const Size(420, 560),
    builder: (_) => const SizedBox(),
  );

  test('нет нативного слоя — окно не открывается, звонок остаётся в главном', () async {
    mockNative((call) => call.method == 'isSupported' ? false : null);
    final ok = await DesktopChildWindows.instance.open(spec());
    expect(ok, isFalse);
    expect(calls.map((c) => c.method), isNot(contains('open')));
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  test('отказ ОС — честное «нет», без исключения', () async {
    mockNative((call) {
      if (call.method == 'isSupported') return true;
      if (call.method == 'open') {
        throw PlatformException(code: 'create_failed');
      }
      return null;
    });
    expect(await DesktopChildWindows.instance.open(spec()), isFalse);
    expect(DesktopChildWindows.instance.isOpen('call'), isFalse);
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  test('в запросе — номер движка и размеры', () async {
    mockNative((call) {
      if (call.method == 'isSupported') return true;
      if (call.method == 'open') return null; // вида нет — не открылось
      return null;
    });
    await DesktopChildWindows.instance.open(spec());
    final open = calls.firstWhere((c) => c.method == 'open');
    final args = open.arguments as Map;
    expect(args['id'], 'call');
    expect(args['width'], 420);
    expect(args['height'], 560);
    expect(args.containsKey('engineId'), isTrue);
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  // Раннер, у которого окно открывается: вид — тот, что есть у тестовой среды.
  Object? nativeOpens(MethodCall call) => switch (call.method) {
    'isSupported' => true,
    'open' => binding.platformDispatcher.views.first.viewId,
    _ => null,
  };

  List<String> methods() => calls
      .map((c) => c.method)
      .where((m) => m != 'isSupported')
      .toList(growable: false);

  // 🔴 Движок macOS 3.41 отдаёт всю семантику главному окну — второй вид
  // перемешивал дерево доступности (разбор Р1, 29.09.2026).
  group('🔴 macOS + экранный диктор — своих окон нет', () {
    tearDown(binding.platformDispatcher.clearSemanticsEnabledTestValue);

    test('диктор включён — окно не открывается, звонок остаётся в главном', () async {
      DesktopChildWindows.debugOperatingSystem = 'macos';
      mockNative(nativeOpens);
      binding.platformDispatcher.semanticsEnabledTestValue = true;
      final windows = DesktopChildWindows.instance;
      expect(await windows.isSupported(), isFalse);
      expect(windows.supportedCached, isFalse);
      expect(await windows.open(spec()), isFalse);
      expect(methods(), isNot(contains('open')));
      // Диктор выключили — окна снова можно, без нового опроса раннера.
      binding.platformDispatcher.semanticsEnabledTestValue = false;
      expect(windows.supportedCached, isTrue);
    });

    test('Windows разводит семантику по видам — диктор окнам не мешает', () async {
      DesktopChildWindows.debugOperatingSystem = 'windows';
      mockNative(nativeOpens);
      binding.platformDispatcher.semanticsEnabledTestValue = true;
      expect(await DesktopChildWindows.instance.isSupported(), isTrue);
    });

    test('диктор включили посреди звонка — хозяин звонка узнаёт сразу', () {
      DesktopChildWindows.debugOperatingSystem = 'macos';
      final availability = DesktopChildWindows.instance.availability;
      var ticks = 0;
      void onTick() => ticks++;
      availability.addListener(onTick);
      addTearDown(() => availability.removeListener(onTick));
      binding.platformDispatcher.semanticsEnabledTestValue = true;
      expect(ticks, greaterThan(0));
    });
  });

  // 🔴 Скрытое приложение на macOS (другой стол, полноэкранная программа,
  // заблокированный экран) не заказывает кадров: `endOfFrame` не наступал, и
  // окно входящего не показывалось никогда.
  group('🔴 кадр нового окна', () {
    testWidgets('кадры выключены — кадр заказывается принудительно, окно показывается', (
      t,
    ) async {
      DesktopChildWindows.debugOperatingSystem = 'windows';
      mockNative(nativeOpens);
      await t.pump();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      addTearDown(
        () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
      );
      expect(binding.framesEnabled, isFalse);
      expect(binding.hasScheduledFrame, isFalse);
      var done = false;
      var ok = false;
      DesktopChildWindows.instance.open(spec()).then((v) {
        ok = v;
        done = true;
      });
      for (var i = 0; i < 20 && !binding.hasScheduledFrame; i++) {
        await binding.delayed(const Duration(milliseconds: 16));
      }
      expect(binding.hasScheduledFrame, isTrue, reason: 'кадр заказан, хотя кадры выключены');
      for (var i = 0; i < 20 && !done; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(ok, isTrue);
      expect(methods(), containsAllInOrder(<String>['open', 'show']));
      var closed = false;
      DesktopChildWindows.instance.close('call').then((_) => closed = true);
      for (var i = 0; i < 20 && !closed; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(closed, isTrue, reason: 'закрытие тоже не ждёт обычного кадра');
    });

    testWidgets('кадра нет вовсе — открытие не висит: «нет», окно ОС закрыто', (
      t,
    ) async {
      DesktopChildWindows.debugOperatingSystem = 'windows';
      DesktopChildWindows.frameTimeout = const Duration(milliseconds: 300);
      mockNative(nativeOpens);
      var done = false;
      var ok = true;
      DesktopChildWindows.instance.open(spec()).then((v) {
        ok = v;
        done = true;
      });
      // Время идёт, а кадров нет — как у скрытого приложения.
      for (var i = 0; i < 40 && !done; i++) {
        await binding.delayed(const Duration(milliseconds: 50));
      }
      expect(done, isTrue, reason: 'открытие обязано закончиться');
      expect(ok, isFalse, reason: 'хозяин покажет звонок прежним путём');
      expect(DesktopChildWindows.instance.isOpen('call'), isFalse);
      expect(methods(), <String>['open', 'close']);
    });
  });

  // 🔴 Открыть и закрыть одно окно шли наперегонки.
  group('🔴 открыть и закрыть — по очереди', () {
    Future<void> settle(WidgetTester t, bool Function() done) async {
      for (var i = 0; i < 50 && !done(); i++) {
        await t.pump(const Duration(milliseconds: 20));
      }
      expect(done(), isTrue);
    }

    testWidgets('закрыли, пока окно открывалось, — окно не показывается', (t) async {
      DesktopChildWindows.debugOperatingSystem = 'windows';
      final nativeOpen = Completer<void>();
      mockNative((call) {
        if (call.method == 'open') {
          return nativeOpen.future.then(
            (_) => binding.platformDispatcher.views.first.viewId,
          );
        }
        return nativeOpens(call);
      });
      final windows = DesktopChildWindows.instance;
      var opened = true;
      var openDone = false;
      windows.open(spec()).then((v) {
        opened = v;
        openDone = true;
      });
      await t.pump();
      expect(methods(), contains('open'), reason: 'ОС уже создаёт окно');
      var closeDone = false;
      windows.close('call').then((_) => closeDone = true);
      nativeOpen.complete();
      await settle(t, () => openDone && closeDone);
      expect(opened, isFalse);
      expect(windows.isOpen('call'), isFalse);
      expect(methods(), isNot(contains('show')));
      expect(methods().last, 'close', reason: 'окно ОС не остаётся без хозяина');
    });

    testWidgets('открыли, пока окно закрывалось, — сначала закрытие, потом новое', (
      t,
    ) async {
      DesktopChildWindows.debugOperatingSystem = 'windows';
      mockNative(nativeOpens);
      final windows = DesktopChildWindows.instance;
      var first = false;
      windows.open(spec()).then((v) => first = v);
      await settle(t, () => first);
      calls.clear();
      var closeDone = false;
      var reopened = false;
      windows.close('call').then((_) => closeDone = true);
      windows.open(spec()).then((v) => reopened = v);
      await settle(t, () => closeDone && reopened);
      expect(methods(), <String>['close', 'open', 'show']);
      expect(windows.isOpen('call'), isTrue);
      var closed = false;
      windows.close('call').then((_) => closed = true);
      await settle(t, () => closed);
    });
  });

  group('🔴 нативная часть', () {
    final cpp = File('windows/runner/child_window.cpp').readAsStringSync();
    final h = File('windows/runner/child_window.h').readAsStringSync();
    final flutterWindow = File(
      'windows/runner/flutter_window.cpp',
    ).readAsStringSync();
    final cmake = File('windows/runner/CMakeLists.txt').readAsStringSync();
    final swift = File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();

    test('Windows: прототипы внутреннего API движка — как в flutter_windows_internal.h', () {
      expect(
        cpp.contains(
          'FlutterDesktopEngineCreateViewController(\n'
          '    FlutterDesktopEngineRef engine,\n'
          '    const FlutterDesktopViewControllerProperties* properties);',
        ),
        isTrue,
      );
      expect(cpp.contains('FlutterDesktopEngineForId(int64_t engine_id);'), isTrue);
      expect(cmake.contains('"child_window.cpp"'), isTrue);
    });

    test('Windows: окна уходят ДО движка, вид — один раз', () {
      final destroy = flutterWindow.indexOf('child_windows_ = nullptr;');
      final engine = flutterWindow.indexOf('flutter_controller_ = nullptr;');
      expect(destroy, greaterThan(0));
      expect(destroy, lessThan(engine));
      expect(cpp.contains('SecretlyChildWindow::~SecretlyChildWindow() { Destroy(); }'), isTrue);
      expect(cpp.contains('controller_ = nullptr;\n    FlutterDesktopViewControllerDestroy(controller);'), isTrue);
    });

    // 🔴 Окошко уведомления создавалось обычным окном, и OnCreate отдавал фокус
    // виду ещё до того, как оно становилось окошком без активации.
    test('Windows: окошко уведомления рождается без фокуса, главное окно — как было', () {
      final win32 = File('windows/runner/win32_window.cpp').readAsStringSync();
      final win32h = File('windows/runner/win32_window.h').readAsStringSync();
      expect(
        win32.contains('creation_ex_style_, window_class, title.c_str(), creation_style_,'),
        isTrue,
      );
      expect(win32h.contains('DWORD creation_style_ = WS_OVERLAPPEDWINDOW;'), isTrue);
      expect(win32h.contains('DWORD creation_ex_style_ = 0;'), isTrue);
      expect(win32h.contains('bool focus_content_ = true;'), isTrue);
      final setChild = win32.substring(win32.indexOf('void Win32Window::SetChildContent('));
      expect(
        setChild.indexOf('if (focus_content_)'),
        lessThan(setChild.indexOf('SetFocus(child_content_);')),
      );
      final ctor = cpp.substring(
        cpp.indexOf('SecretlyChildWindow::SecretlyChildWindow('),
        cpp.indexOf('SecretlyChildWindow::~SecretlyChildWindow()'),
      );
      expect(ctor.contains('SetCreationStyle(WS_POPUP,'), isTrue);
      expect(ctor.contains('WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_TOPMOST'), isTrue);
      expect(ctor.contains('no_activate_(notification)'), isTrue);
      expect(flutterWindow.contains('SetCreationStyle'), isFalse, reason: 'главное окно — прежнее');
      final popup = cpp.substring(cpp.indexOf('void SecretlyChildWindow::MakeNotificationPopup()'));
      expect(popup.substring(0, popup.indexOf('\n}\n')).contains('SetWindowLongPtr'), isFalse);
    });

    test('крестик окна спрашивает Dart, а не закрывает сам', () {
      expect(cpp.contains('case WM_CLOSE:'), isTrue);
      expect(cpp.contains('"closeRequested"'), isTrue);
      expect(swift.contains('func windowShouldClose(_ sender: NSWindow) -> Bool'), isTrue);
      expect(swift.contains('invokeMethod("closeRequested"'), isTrue);
      expect(h.contains('class ChildWindowHost'), isTrue);
    });

    test('macOS: наведение и в окне звонка без фокуса (закреплённом поверх всех)', () {
      final open = swift.substring(swift.indexOf('let controller = FlutterViewController(engine: engine'));
      expect(open.contains('controller.mouseTrackingMode = .always'), isTrue);
    });

    test('macOS: мультивид — через поле, без NSAssert enableMultiView', () {
      expect(swift.contains('class_getInstanceVariable(FlutterEngine.self, "_multiViewEnabled")'), isTrue);
      expect(swift.contains('perform(NSSelectorFromString("enableMultiView")'), isFalse);
      expect(swift.contains('FlutterViewController(engine: engine, nibName: nil, bundle: nil)'), isTrue);
    });

    test('хозяин окон стоит НАД приложением, дерево не меняет форму', () {
      final main = File('lib/main_desktop.dart').readAsStringSync();
      expect(
        main.contains('runApp(const DesktopChildWindowHost(child: DesktopProductionApp()));'),
        isTrue,
      );
      final host = File(
        'lib/ui/desktop/services/desktop_child_windows.dart',
      ).readAsStringSync();
      expect(host.contains('return ViewAnchor(\n          view: open.isEmpty'), isTrue);
    });

    final ciFile = File('../../../.github/workflows/windows-release.yml');
    test('самотест подключён и в CI Windows', () {
      expect(ciFile.readAsStringSync().contains('--child-window-selftest'), isTrue);
    }, skip: !ciFile.existsSync());
  });
}
