// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Постоянный дрейф обоев не должен гореть, пока на него никто не смотрит.
//
// 🔴 Замер 12.09.2026, окно с открытым чатом:
//
//     спереди          35,8 %
//     в фоне           34,5 %   ← столько же
//     свёрнуто          2,1 %
//     чат не открыт     6,3 %
//
// То есть обычная защита «в фоне не рисуем» на столе не срабатывает вовсе:
// окно без фокуса — и даже целиком закрытое чужим окном — остаётся для системы
// живым (`AppLifecycleState.resumed`), и контроллер обоев продолжает заказывать
// кадр на каждом вsync. Гасило только сворачивание.
//
// Здесь закреплено, что именно мы гасим, — и, не менее важно, чего НЕ трогаем.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_window_activity.dart';
import 'package:secretly_app/ui/widgets/telegram_wallpaper.dart'
    show ChatWallpaperAnimMode;

void main() {
  test('без фокуса постоянный дрейф замирает', () {
    expect(
      desktopWallpaperAnimModeFor(
        setting: ChatWallpaperAnimMode.continuous,
        windowFocused: false,
      ),
      ChatWallpaperAnimMode.onEnter,
      reason: 'это декорация — её никто не видит, а стоит она непрерывной '
          'перерисовки всего экрана',
    );
  });

  test('с фокусом дрейф идёт как настроено', () {
    expect(
      desktopWallpaperAnimModeFor(
        setting: ChatWallpaperAnimMode.continuous,
        windowFocused: true,
      ),
      ChatWallpaperAnimMode.continuous,
      reason: 'человек выбрал этот вид и сейчас на него смотрит',
    );
  });

  test('🔴 остальные режимы не трогаем ни при каком фокусе', () {
    for (final mode in <ChatWallpaperAnimMode>[
      ChatWallpaperAnimMode.onEnter,
      ChatWallpaperAnimMode.tap,
      ChatWallpaperAnimMode.off,
    ]) {
      for (final focused in <bool>[true, false]) {
        expect(
          desktopWallpaperAnimModeFor(setting: mode, windowFocused: focused),
          mode,
          reason: 'правка обязана касаться ТОЛЬКО постоянного дрейфа: '
              'режим $mode при focused=$focused',
        );
      }
    }
  });

  test('окно считается в фокусе, пока не сказано обратное', () {
    // Ошибка в эту сторону стоит кадров; в обратную — заморозила бы самую
    // первую отрисовку.
    expect(DesktopWindowActivity.focused.value, isTrue);
  });

  test('потеря и возврат фокуса переключают состояние', () {
    final a = DesktopWindowActivity();
    addTearDown(a.dispose);

    a.onBlurred();
    expect(DesktopWindowActivity.focused.value, isFalse);
    a.onFocused();
    expect(DesktopWindowActivity.focused.value, isTrue);
  });
}
