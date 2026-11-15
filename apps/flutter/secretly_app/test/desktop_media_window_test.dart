// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ФОТО, ВИДЕО И ФАЙЛЫ — В СВОЁМ ОКНЕ ОС (05.10.2026).
//
// Владелец: «фото и видео и файлы — как в Telegram должны открываться в
// отдельных окнах, и на Windows, и на Mac». Окно просмотра одно: новое
// содержимое заменяет прежнее. Нет своих окон — просмотр внутри приложения,
// как раньше. Закрыть просмотр — закрыть окно, а не уйти маршрутом.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_media_window.dart';
import 'package:secretly_app/ui/desktop/services/desktop_child_windows.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('secretly/child_window');
  final calls = <MethodCall>[];
  var supported = true;

  setUp(() {
    calls.clear();
    supported = true;
    DesktopChildWindows.instance.debugReset();
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

  List<String> methods() => calls
      .map((c) => c.method)
      .where((m) => m != 'isSupported' && m != 'isScreenReaderRunning')
      .toList(growable: false);

  Future<BuildContext> host(WidgetTester t) async {
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    return ctx;
  }

  /// Служба окон ждёт кадра — в тесте кадры рисует `pump`.
  Future<T> drive<T>(WidgetTester t, Future<T> Function() body) async {
    var done = false;
    late T value;
    body().then((v) {
      value = v;
      done = true;
    });
    for (var i = 0; i < 60 && !done; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(done, isTrue, reason: 'открытие окна не закончилось');
    return value;
  }

  testWidgets('просмотр — в своём окне ОС, с именем в заголовке', (t) async {
    final ctx = await host(t);
    final ok = await drive(
      t,
      () => DesktopMediaWindow.open(
        context: ctx,
        title: 'Игорь',
        builder: (_) => const SizedBox(),
      ),
    );
    expect(ok, isTrue);
    expect(DesktopChildWindows.instance.isOpen(DesktopMediaWindow.windowId), isTrue);
    final open = calls.firstWhere((c) => c.method == 'open').arguments as Map;
    expect(open['id'], DesktopMediaWindow.windowId);
    expect(open['title'], 'Игорь');
    // Большое окно, как у Telegram, но не меньше рабочего минимума.
    expect(open['width'] as double, greaterThanOrEqualTo(640));
    expect(open['height'] as double, greaterThanOrEqualTo(480));
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  testWidgets('новое фото — в том же окне: прежнее содержимое уступает место', (
    t,
  ) async {
    final ctx = await host(t);
    await drive(
      t,
      () => DesktopMediaWindow.open(
        context: ctx,
        title: 'Первое',
        builder: (_) => const SizedBox(),
      ),
    );
    calls.clear();
    await drive(
      t,
      () => DesktopMediaWindow.open(
        context: ctx,
        title: 'Второе',
        builder: (_) => const SizedBox(),
      ),
    );
    expect(methods(), containsAllInOrder(<String>['close', 'open']));
    expect(methods().where((m) => m == 'open'), hasLength(1));
  }, skip: !(Platform.isMacOS || Platform.isWindows));

  testWidgets('своих окон нет — «нет», просмотр покажется внутри приложения', (
    t,
  ) async {
    supported = false;
    final ctx = await host(t);
    final ok = await drive(
      t,
      () => DesktopMediaWindow.open(
        context: ctx,
        title: 'Фото',
        builder: (_) => const SizedBox(),
      ),
    );
    expect(ok, isFalse);
    expect(methods(), isNot(contains('open')));
  });

  testWidgets('закрыть просмотр в своём окне — закрыть окно, а не маршрут', (
    t,
  ) async {
    var closed = 0;
    late BuildContext inner;
    await t.pumpWidget(
      MaterialApp(
        home: DesktopViewerScope(
          onClose: () => closed++,
          child: Builder(
            builder: (c) {
              inner = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(DesktopViewerScope.inOwnWindow(inner), isTrue);
    DesktopViewerScope.close(inner);
    expect(closed, 1);
  });

  testWidgets('внутри приложения — уходит маршрутом, как раньше', (t) async {
    late BuildContext inner;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.of(c).push(
              MaterialPageRoute<void>(
                builder: (c2) {
                  inner = c2;
                  return const Text('просмотр');
                },
              ),
            ),
            child: const Text('открыть'),
          ),
        ),
      ),
    );
    await t.tap(find.text('открыть'));
    await t.pumpAndSettle();
    expect(find.text('просмотр'), findsOneWidget);
    expect(DesktopViewerScope.inOwnWindow(inner), isFalse);
    DesktopViewerScope.close(inner);
    await t.pumpAndSettle();
    expect(find.text('просмотр'), findsNothing);
  });

  test('🔴 замок закрывает окно просмотра: документ не остаётся на экране', () {
    // Окно просмотра — своё окно ОС, замок главного окна его не накрывает.
    final src = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    final at = src.indexOf('void _afterLockChange() {');
    expect(at, greaterThan(0));
    final body = src.substring(at, at + 600);
    final engaged = body.indexOf('if (engaged) {');
    final close = body.indexOf('DesktopMediaWindow.close()');
    expect(engaged, greaterThan(0));
    expect(close, greaterThan(engaged));
  });

  test('все три просмотра сперва пробуют своё окно', () {
    for (final f in const [
      'lib/ui/desktop/chat/desktop_photo_viewer.dart',
      'lib/ui/desktop/chat/desktop_video_viewer.dart',
      'lib/ui/desktop/chat/document_viewer.dart',
    ]) {
      final src = File(f).readAsStringSync();
      final show = src.indexOf('static Future<void> show(');
      final window = src.indexOf('DesktopMediaWindow.open(', show);
      final overlay = src.indexOf('showDesktopOverlay<void>(', show);
      expect(window, greaterThan(show), reason: f);
      expect(window, lessThan(overlay), reason: '$f: окно — раньше слоя');
      // Закрывают через общую точку — окно или маршрут.
      expect(src.contains('Navigator.of(context).maybePop()'), isFalse, reason: f);
      expect(src.contains('DesktopViewerScope.close(context)'), isTrue, reason: f);
    }
  });
}
