// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app/desktop_app_view_model.dart';
import '../app/desktop_child_window_app.dart';
import '../services/desktop_child_windows.dart';
import '../services/desktop_ui_prefs.dart';
import 'call_main_window_reveal.dart';
import 'one_to_one_call_screen.dart' show DesktopCallOwnWindow;
import 'room_call_window.dart';

/// Созвон комнаты — в СВОЁМ окне ОС (29.09.2026, Р1, этап 3).
///
/// Как у звонка один на один ([DesktopDirectCallWindow]): окно можно увести на
/// другой монитор и закрепить поверх всех. Отличие одно — крестик НЕ выводит
/// из созвона: он только прячет окно, созвон идёт дальше, а в главном окне
/// остаются мини-окно и полоса «Вернуться». Выйти из группового разговора
/// случайно — дороже, чем положить трубку в разговоре на двоих.
///
/// Нет слоя окон, выключена настройка или ОС отказала — [open] отвечает
/// `false`, и созвон открывается поверх главного окна, как раньше.
abstract final class DesktopRoomCallWindows {
  static const String windowId = 'room-call';
  static const Size size = Size(1100, 720);
  static const Size minSize = Size(640, 460);

  static String? _roomId;

  /// Сколько раз окно созвона закрывали (см. [open]).
  static int _closes = 0;

  /// Комната, чей созвон сейчас в своём окне.
  static String? get openRoomId =>
      DesktopChildWindows.instance.isOpen(windowId) ? _roomId : null;

  static Future<bool> open({
    required DesktopAppViewModel vm,
    required String groupId,
    required String title,
  }) async {
    if (!DesktopUiPrefs.callInOwnWindow.value) return false;
    final windows = DesktopChildWindows.instance;
    if (!await windows.isSupported()) return false;
    if (windows.isOpen(windowId)) {
      if (_roomId == groupId) {
        await windows.focus(windowId);
        return true;
      }
      // Один созвон за раз: окно прошлой комнаты уступает место.
      await close();
    }
    _roomId = groupId;
    final closes = _closes;
    final ok = await windows.open(
      DesktopChildWindowSpec(
        id: windowId,
        title: title.trim().isEmpty ? 'Secretly' : title.trim(),
        size: size,
        minSize: minSize,
        topmost: DesktopUiPrefs.callWindowPinned.value,
        onCloseRequested: () => unawaited(minimize()),
        builder: (_) => DesktopChildWindowApp(
          locale: vm.controller.appLocaleOverride,
          resolveLocale: vm.controller.resolveAppUiLocale,
          home: DesktopRoomCallWindow(
            vm: vm,
            groupId: groupId,
            title: title,
            onClose: () => unawaited(close()),
            ownWindow: DesktopCallOwnWindow(
              pinned: DesktopUiPrefs.callWindowPinned,
              onTogglePin: () => unawaited(togglePin()),
              onSetFullScreen: (on) => windows.setFullScreen(windowId, on),
            ),
          ),
        ),
      ),
    );
    if (!ok) {
      _roomId = null;
      // Окно закрыли, пока оно открывалось (выход из созвона, перезапуск,
      // выключили настройку): показывать созвон поверх главного окна вместо
      // своего не нужно — «нет» здесь значило бы «покажи иначе».
      if (_closes != closes) return true;
    }
    return ok;
  }

  /// Спрятать окно. Созвон при этом идёт дальше. Окно, которое ещё
  /// открывается, не появится (см. [DesktopChildWindows.close]).
  static Future<void> close() async {
    _closes++;
    _roomId = null;
    await DesktopChildWindows.instance.close(windowId);
  }

  /// Крестик окна: спрятать окно, созвон идёт дальше мини-окном и полосой в
  /// главном окне. 🔴 А главное спрятано в трей — выводим и его, иначе живой
  /// микрофон остался бы без единого окна на экране (30.09.2026).
  static Future<void> minimize() async {
    await close();
    await DesktopMainWindowReveal.revealIfHidden();
  }

  static Future<void> focus() => DesktopChildWindows.instance.focus(windowId);

  static Future<void> togglePin() async {
    final next = !DesktopUiPrefs.callWindowPinned.value;
    await DesktopUiPrefs.setCallWindowPinned(next);
    if (DesktopChildWindows.instance.isOpen(windowId)) {
      await DesktopChildWindows.instance.setTopmost(windowId, next);
    }
  }
}
