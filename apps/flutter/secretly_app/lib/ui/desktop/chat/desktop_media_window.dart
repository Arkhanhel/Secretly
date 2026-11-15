// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// 🔴 ФОТО, ВИДЕО И ФАЙЛЫ — В СВОЁМ ОКНЕ ОС, КАК В TELEGRAM (05.10.2026).
///
/// Владелец: «фото и видео и файлы — как в Telegram должны открываться в
/// отдельных окнах, и на Windows, и на Mac». Раньше просмотр был слоем
/// поверх главного окна: его нельзя было отодвинуть, увести на второй
/// монитор и смотреть рядом с перепиской.
///
/// Окно просмотра ОДНО: новое фото, видео или файл открываются в нём же —
/// прежнее содержимое уступает место. Рисует его тот же движок, что и
/// главное окно (`desktop_child_windows.dart`), поэтому видео играет без
/// переноса, а меню и подсказки открываются в самом окне просмотра.
///
/// Нет слоя своих окон или ОС отказала — вызывающий показывает просмотр
/// внутри приложения, как раньше ([DesktopMediaWindow.open] отвечает `false`).
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../diagnostics/diag_log.dart';
import '../app/desktop_child_window_app.dart';
import '../services/desktop_child_windows.dart';

/// Как закрыть просмотр: в своём окне ОС — закрыть окно, внутри
/// приложения — уйти маршрутом.
class DesktopViewerScope extends InheritedWidget {
  const DesktopViewerScope({
    super.key,
    required this.onClose,
    required super.child,
  });

  final VoidCallback onClose;

  /// Закрыть просмотр, где бы он ни был открыт.
  static void close(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<DesktopViewerScope>();
    if (scope != null) {
      scope.onClose();
      return;
    }
    Navigator.of(context).maybePop();
  }

  /// Открыт ли просмотр в своём окне ОС.
  static bool inOwnWindow(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DesktopViewerScope>() != null;

  @override
  bool updateShouldNotify(DesktopViewerScope old) => false;
}

/// Окно просмотра фото, видео и файлов.
abstract final class DesktopMediaWindow {
  static const String windowId = 'media-viewer';

  /// Сколько раз окно просили открыть: открытие, которое обогнало новое,
  /// не показывает своё содержимое поверх нового.
  static int _generation = 0;

  /// Открыть просмотр в своём окне. `false` — своё окно сейчас невозможно,
  /// показывай внутри приложения.
  ///
  /// [context] — место вызова: из него берётся язык окна.
  static Future<bool> open({
    required BuildContext context,
    required String title,
    required WidgetBuilder builder,
  }) async {
    final windows = DesktopChildWindows.instance;
    if (!await windows.isSupported()) return false;
    if (!context.mounted) return false;
    final locale = Localizations.maybeLocaleOf(context);
    final generation = ++_generation;
    // Новое содержимое — в том же окне: прежнее уступает место (окно
    // закрывается и открывается заново на том же месте экрана).
    if (windows.isOpen(windowId)) {
      await windows.close(windowId);
    }
    if (generation != _generation) return true;
    final ok = await windows.open(
      DesktopChildWindowSpec(
        id: windowId,
        title: title.trim().isEmpty ? 'Secretly' : title.trim(),
        size: preferredSize(),
        minSize: const Size(480, 360),
        builder: (_) => DesktopChildWindowApp(
          locale: locale,
          resolveLocale: (device) =>
              locale ?? (device.isEmpty ? const Locale('en') : device.first),
          home: DesktopViewerScope(
            onClose: () => unawaited(close()),
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
    if (!ok) {
      DiagLog.event('media_window', 'inline', const <String, Object?>{
        'reason': 'open_failed',
      });
    }
    return ok;
  }

  /// Закрыть окно просмотра.
  static Future<void> close() =>
      DesktopChildWindows.instance.close(windowId);

  /// Размер окна просмотра: большая часть экрана, как у Telegram, но не
  /// весь — окно видно окном, его можно отодвинуть.
  static Size preferredSize() {
    final displays = ui.PlatformDispatcher.instance.displays;
    if (displays.isNotEmpty) {
      final d = displays.first;
      final ratio = d.devicePixelRatio <= 0 ? 1.0 : d.devicePixelRatio;
      final logical = d.size / ratio;
      if (!logical.isEmpty) {
        return Size(
          (logical.width * 0.8).clamp(640.0, 1600.0),
          (logical.height * 0.82).clamp(480.0, 1100.0),
        );
      }
    }
    return const Size(1100, 760);
  }
}
