// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Ссылки, которые компьютер открывает САМ, а не отдаёт браузеру.
///
/// 🔴 ЗАЧЕМ (17.09.2026). Приглашение в комнату, присланное в переписке, на
/// компьютере уходило во внешний браузер: там открывалась страница-заглушка, а
/// человек возвращался в приложение ни с чем. На телефоне такая ссылка
/// открывает экран входа с проверкой и понятными отказами.
///
/// Обработчик ставит оболочка окна (она и так знает контроллер), а спрашивают
/// его виджеты ленты. Так лента не начинает зависеть от контроллера: этот шов
/// сторожит `desktop_controller_seam_ratchet_test`.
class DesktopLinkRouter {
  DesktopLinkRouter._();

  /// Возвращает `true`, если ссылка обработана внутри приложения.
  static bool Function(Uri uri)? handler;

  /// Пробует открыть ссылку внутри приложения. `false` — пусть идёт наружу.
  ///
  /// Ошибку обработчика проглатываем: нажатие на ссылку не должно ронять
  /// ленту, а внешний путь остаётся запасным.
  static bool handle(Uri uri) {
    final fn = handler;
    if (fn == null) return false;
    try {
      return fn(uri);
    } catch (_) {
      return false;
    }
  }
}
