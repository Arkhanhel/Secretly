// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// СТОРОЖ БУФЕРА ДЛЯ НАБОРА ВОССТАНОВЛЕНИЯ (01.10.2026).
//
// 🔴 Телефонный экран набора (выпущен и заморожен) кладёт набор в буфер и
// оставляет там навсегда. Компьютер сторожит снаружи: через минуту после
// копирования и при закрытии окна стирает буфер — только если там всё ещё
// набор. Чужое не читается без нужды: «ещё там» проверяется счётчиком буфера.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_clipboard_guard.dart';

const _secret = 'secretly-kit:v1:AAAA';

class _Board {
  String text = 'чужое';
  int count = 1;
  int reads = 0;

  void copy(String t) {
    text = t;
    count++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/clipboard_guard');

  late _Board board;

  DesktopClipboardGuard guardWith({required bool counter}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      // Без счётчика — как Linux: нативной стороны нет.
      (call) async =>
          counter ? board.count : throw MissingPluginException('no guard'),
    );
    return DesktopClipboardGuard(
      channel: channel,
      readText: () async {
        board.reads++;
        return board.text;
      },
      clear: () async => board.copy(''),
    );
  }

  setUp(() => board = _Board());
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> wait(WidgetTester t, Duration d) async {
    final end = d.inMilliseconds;
    for (var ms = 0; ms < end; ms += 100) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('🔴 через минуту после копирования набор стирается из буфера',
      (t) async {
    final guard = guardWith(counter: true);
    final open = Completer<void>();
    final done = guard.guard(_secret, open.future);
    await wait(t, const Duration(seconds: 2));
    expect(board.reads, 0, reason: 'пока не копировали — буфер не читаем');

    board.copy(_secret);
    await wait(t, const Duration(seconds: 2));
    expect(board.text, _secret, reason: 'сразу не стираем — дали вставить');

    await wait(t, const Duration(seconds: 60));
    expect(board.text, '', reason: 'минута прошла — набор убран');

    open.complete();
    await wait(t, const Duration(seconds: 1));
    await done;
  });

  testWidgets('🔴 закрыли окно — набор стирается сразу', (t) async {
    final guard = guardWith(counter: true);
    final open = Completer<void>();
    final done = guard.guard(_secret, open.future);
    board.copy(_secret);
    await wait(t, const Duration(seconds: 1));
    open.complete();
    await wait(t, const Duration(seconds: 1));
    await done;
    expect(board.text, '');
  });

  testWidgets('скопировали в последний миг перед закрытием — тоже стирается',
      (t) async {
    final guard = guardWith(counter: true);
    final open = Completer<void>();
    final done = guard.guard(_secret, open.future);
    await wait(t, const Duration(seconds: 1));
    board.copy(_secret);
    open.complete();
    await wait(t, const Duration(seconds: 1));
    await done;
    expect(board.text, '');
  });

  testWidgets('🔴 человек скопировал другое — его буфер не трогаем', (t) async {
    final guard = guardWith(counter: true);
    final open = Completer<void>();
    final done = guard.guard(_secret, open.future);
    board.copy(_secret);
    await wait(t, const Duration(seconds: 1));
    board.copy('адрес для друга');
    await wait(t, const Duration(seconds: 61));
    open.complete();
    await wait(t, const Duration(seconds: 1));
    await done;
    expect(board.text, 'адрес для друга');
  });

  testWidgets('без нативного счётчика — сравнение текста', (t) async {
    final guard = guardWith(counter: false);
    final open = Completer<void>();
    final done = guard.guard(_secret, open.future);
    board.copy(_secret);
    await wait(t, const Duration(seconds: 1));
    open.complete();
    await wait(t, const Duration(seconds: 1));
    await done;
    expect(board.text, '');
  });

  test('нативные стороны отдают счётчик, а окно набора под сторожем', () {
    final mac = File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();
    expect(mac, contains('"secretly/clipboard_guard"'));
    expect(mac, contains('NSPasteboard.general.changeCount'));
    expect(mac, contains('clipboardGuardBridge.attach('));
    final win = File('windows/runner/flutter_window.cpp').readAsStringSync();
    expect(win, contains('"secretly/clipboard_guard"'));
    expect(win, contains('GetClipboardSequenceNumber()'));
    final kit =
        File('lib/ui/desktop/app/recovery_kit_export.dart').readAsStringSync();
    expect(kit, contains('DesktopClipboardGuard.instance).guard('));
  });
}
