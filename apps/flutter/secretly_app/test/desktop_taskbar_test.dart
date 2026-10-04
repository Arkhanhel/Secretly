// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 НЕПРОЧИТАННЫЕ НА ПАНЕЛИ ЗАДАЧ И МИГАНИЕ — WINDOWS, КАК У TELEGRAM
// (29.09.2026). Значок рисует Dart, раннер ставит его поверх кнопки окна.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_taskbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('подпись: число, за 99 — «99+»', () {
    expect(DesktopTaskbar.badgeLabel(7), '7');
    expect(DesktopTaskbar.badgeLabel(99), '99');
    expect(DesktopTaskbar.badgeLabel(100), '99+');
  });

  testWidgets('значок: красный кружок, прозрачные углы, 32×32', (t) async {
    await t.runAsync(() async {
      final rgba = await DesktopTaskbar.renderBadge(5);
      expect(rgba, isNotNull);
      final side = DesktopTaskbar.badgeSide;
      expect(rgba!.length, side * side * 4);
      int alphaAt(int x, int y) => rgba[(y * side + x) * 4 + 3];
      expect(alphaAt(0, 0), 0, reason: 'угол прозрачный — это кружок');
      // Точка на кольце кружка (не под цифрой) — красная.
      final i = (side ~/ 2 * side + 2) * 4;
      expect(rgba[i], greaterThan(200));
      expect(rgba[i + 1], lessThan(100));
      final muted = await DesktopTaskbar.renderBadge(5, muted: true);
      final j = (side ~/ 2 * side + 2) * 4;
      expect((muted![j] - muted[j + 1]).abs(), lessThan(10), reason: 'серый');
      // Картинку можно разобрать обратно.
      final codec = await ui.ImageDescriptor.raw(
        await ui.ImmutableBuffer.fromUint8List(rgba),
        width: side,
        height: side,
        pixelFormat: ui.PixelFormat.rgba8888,
      ).instantiateCodec();
      expect((await codec.getNextFrame()).image.width, side);
    });
  });

  group('🔴 подключено', () {
    test('раннер: значок поверх кнопки, мигание, возврат после explorer', () {
      final cpp = File('windows/runner/taskbar_badge.cpp').readAsStringSync();
      expect(cpp.contains('SetOverlayIcon(window_, icon_, description_.c_str())'), isTrue);
      expect(cpp.contains('FLASHW_TRAY | FLASHW_TIMERNOFG'), isTrue);
      final win = File('windows/runner/flutter_window.cpp').readAsStringSync();
      expect(win.contains('TaskbarBadge::TaskbarButtonCreatedMessage()'), isTrue);
      expect(win.indexOf('taskbar_badge_ = nullptr;'),
          lessThan(win.indexOf('flutter_controller_ = nullptr;')));
      final cmake = File('windows/runner/CMakeLists.txt').readAsStringSync();
      expect(cmake.contains('"taskbar_badge.cpp"'), isTrue);
    });

    test('число — вместе с треем; мигание — вместе с уведомлением', () {
      final app = File('lib/ui/desktop/app/desktop_production_app.dart').readAsStringSync();
      expect(app.contains('DesktopTaskbar.setUnread('), isTrue);
      final svc = File('lib/ui/desktop/services/desktop_notification_service.dart').readAsStringSync();
      final onChat = svc.substring(svc.indexOf('Future<void> _onChatEvent('));
      expect(onChat.indexOf('doNotDisturb'), lessThan(onChat.indexOf('DesktopTaskbar.flash()')));
    });
  });
}
