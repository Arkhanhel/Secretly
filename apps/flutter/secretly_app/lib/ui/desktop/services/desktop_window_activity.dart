// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';
import '../../widgets/telegram_wallpaper.dart' show ChatWallpaperAnimMode;

/// Tracks whether the desktop window is actually on screen.
///
/// Why this exists: Secretly Desktop hides to the tray instead of quitting, so
/// "closed" windows keep a full Flutter tree alive. Any perpetual animation in
/// that tree — the splash / pairing spinner, the sync banner pulse, typing dots
/// — keeps requesting frames from the display link forever, burning CPU and
/// battery for pixels nobody can see. Measured at ~1/3 of a core with a single
/// indeterminate spinner on screen.
///
/// [visible] drives a `TickerMode` around the whole app, which mutes every
/// ticker in the subtree at once. That is deliberately preferred over pausing
/// each AnimationController by hand: new animations are then correct by
/// default instead of each one being a fresh chance to leak frames.
///
/// **Visibility, not focus.** A visible-but-unfocused window keeps animating —
/// freezing a spinner just because the user clicked another app would read as
/// a hang. Only genuinely off-screen states (hidden to tray, minimised) pause.
class DesktopWindowActivity {
  /// True while the window is on screen. Starts true: the app is launched
  /// visible, and being wrong in this direction merely costs frames, whereas
  /// starting false would freeze the very first paint.
  final ValueNotifier<bool> visible = ValueNotifier<bool>(true);

  /// Hidden to the tray (our close-button interception) or minimised.
  void onHidden() => visible.value = false;

  /// Restored from the tray / dock, or focused — focus implies on screen.
  void onShown() => visible.value = true;

  /// Есть ли у окна фокус.
  ///
  /// Отдельно от [visible], и разница здесь не формальная. На телефоне «не на
  /// переднем плане» значит «не видно». На столе окно может быть на экране и
  /// без фокуса, а может быть целиком закрыто чужим окном — и всё это время
  /// система считает приложение живым (`AppLifecycleState.resumed`), то есть
  /// обычная защита «в фоне не рисуем» не срабатывает вовсе.
  ///
  /// Замер 12.09.2026: открытый чат жёг 34,5% в фоне против 35,8% спереди —
  /// то есть ровно столько же. И только сворачивание роняло до 2,1%.
  ///
  /// Статическое, потому что окно у настольного приложения одно: тянуть
  /// экземпляр через полдерева только ради чтения — больше проводов, чем
  /// пользы.
  static final ValueNotifier<bool> focused = ValueNotifier<bool>(true);

  void onFocused() => focused.value = true;
  void onBlurred() => focused.value = false;

  /// Как спрятать окно в трей, не минуя учёт видимости (17.09.2026).
  ///
  /// Пункт трея живёт в `main_desktop.dart`, вне дерева приложения, и звал
  /// `windowManager.hide()` напрямую: окно пропадало, а приложение считало
  /// себя на экране. Приложение регистрирует здесь свой путь; пока не
  /// зарегистрировало — трей прячет окно сам.
  static Future<void> Function()? hideHandler;

  void dispose() => visible.dispose();
}

/// Каким режимом рисовать обои чата прямо сейчас.
///
/// 🔴 Гасим ТОЛЬКО постоянный дрейф и ТОЛЬКО когда окно без фокуса. Это
/// декорация: её никто не видит, пока человек работает в другом приложении, а
/// стоит она непрерывной перерисовки всего экрана на каждом вsync.
///
/// Остальные режимы не трогаем. И тем более не трогаем индикаторы: в
/// `onWindowBlur` не зря записано, что замерший кружок рядом с чужим окном
/// читается как зависание. Обои — не кружок, они ничего не сообщают.
///
/// Возврат фокуса продолжает дрейф с того же места: контроллер повторяется от
/// текущего значения, а не с нуля.
ChatWallpaperAnimMode desktopWallpaperAnimModeFor({
  required ChatWallpaperAnimMode setting,
  required bool windowFocused,
}) {
  if (windowFocused) return setting;
  if (setting == ChatWallpaperAnimMode.continuous) {
    return ChatWallpaperAnimMode.onEnter;
  }
  return setting;
}
