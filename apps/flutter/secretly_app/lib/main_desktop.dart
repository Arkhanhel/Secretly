// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Production entrypoint for the Secretly **desktop** client.
///
/// This entry is intentionally separate from [lib/main.dart] so that the
/// mobile builds (Android + iOS — already shipping) remain untouched.
///
/// **Platform status (22.09.2026) — stated as fact, not as intent.**
///
/// 🔴 ЭТА ТАБЛИЦА ВРАЛА В ОБЕ СТОРОНЫ, и это стоит записать. Она говорила, что
/// macOS собирается в CI работой `desktop_macos`, — такой работы в
/// `docs/public/github/workflows/ci.yml` не было ни одной (настоящая добавлена
/// этим же заходом). И что Windows «never built in CI», — а работа
/// `Windows — build` зелёная с 20.09.2026. Таблица, которой нельзя верить,
/// хуже отсутствующей: по ней принимают решения. Сверять её надо ПО ФАЙЛУ
/// рабочего потока, а не по памяти.
///
/// | Platform | Status |
/// |---|---|
/// | macOS | **shipped target**, но ещё не отгружаемый. Собирается в CI (работа `macOS — build`) и подписывается `Developer ID Application: Secretly SIA (3HF84UAL32)`. Заверения (notarization) ещё не было: `spctl --assess` отвечает `Unnotarized Developer ID`, то есть скачанную копию Gatekeeper пока не откроет. |
/// | Windows | **собирается в CI** с 20.09.2026 (работа `Windows — build`). Не отгружается: нет установщика и подписи (A-5), второй запуск не выводит окно вперёд — файл-замок вместо именованного мьютекса (A-6), после сна не переподключается (A-7), PDF показать нечем (A-8). |
/// | Linux | **not supported.** There is no `linux/` runner directory — `flutter build linux` will fail until someone runs `flutter create --platforms=linux` (A-9). |
///
/// Сверять эту таблицу надо по файлу рабочего потока и по выводу
/// `security find-identity -v -p codesigning`, а не по памяти.
///
/// The runtime guard below still admits all three so a developer can run on
/// Windows/Linux; that is a developer affordance, not a shipping claim.
///
/// Build / run:
///   flutter run     -t lib/main_desktop.dart -d macos
///   flutter build macos --target=lib/main_desktop.dart
///   flutter build windows --target=lib/main_desktop.dart   # experimental
///   # flutter build linux — unavailable, no linux/ runner (R-11)
///
/// macOS + iCloud: репозиторий ЖИЛ под ~/Documents, а это каталог под iCloud.
/// Его служба помечает каждый файл в поддереве xattr-ами
/// `com.apple.fileprovider.fpfs#P`, и codesign отказывается подписывать
/// что-либо с таким «мусором». Поэтому сборочные помощники
/// (`tools/desktop_build_macos.sh`, `tools/desktop_release_macos.sh`) делают
/// `build/macos` ссылкой на `~/Library/Caches/secretly_app_build_macos`.
///
/// С переезда в `~/dev/Secretly-code` (вне iCloud) исходники этим xattr-ам
/// больше не подвержены, но ссылка ОСТАВЛЕНА: она ничего не стоит, снимает
/// сборку с любого возможного синхронизируемого каталога разом и защищает от
/// возврата проекта под iCloud. Пересоздавать её после `flutter clean` —
/// повторным запуском помощника.
library;

import 'dart:async';
import 'ui/desktop/chat/attachment_save.dart' show clearAttachmentOpenCopies;
import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart' show debugPrintScheduleFrameStacks;
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'diagnostics/diag_log.dart';
import 'desktop/single_instance.dart';
import 'legal/third_party_licenses.dart';
import 'ui/desktop/onboarding/desktop_account_setup.dart';
import 'ui/desktop/services/desktop_update_service.dart';
import 'ui/desktop/app/desktop_production_app.dart';
import 'ui/desktop/chat/chat_thread_panel.dart' show DesktopDraftStore;
import 'ui/desktop/chat/recent_reactions_store.dart';
import 'ui/desktop/services/desktop_ui_prefs.dart';
import 'ui/desktop/services/desktop_window_activity.dart';
import 'ui/desktop/services/desktop_window_state.dart';

/// 🔴 СЛОМАННЫЙ ВИДЖЕТ НЕ ЗАЛИВАЕТ ОКНО КРАСНЫМ — И НЕ УХОДИТ МОЛЧА.
///
/// Жалоба владельца 16.09.2026: «при появлении менюшки над пузырём МОРГАЕТ
/// ЭКРАН КРАСНЫМ ЦВЕТОМ». Красный прямоугольник во весь экран — это `ErrorWidget`
/// Flutter: он подменяет собой поддерево, которое не смогло собраться. Миг — и
/// его нет, потому что следующий кадр рисует уже исправное поддерево. То есть
/// человек видит вспышку и не получает НИ СЛОВА о том, что именно упало.
///
/// Здесь две правки, и обе — про честность окна перед тем, кто им пользуется:
///
///   1. Причина уходит в журнал (`DiagLog`) с именем виджета. Ошибка,
///      случившаяся один раз в чужих руках, перестаёт быть догадкой.
///   2. Вместо красного полотна остаётся ПУСТОЕ МЕСТО. Мигание красным поверх
///      переписки выглядит как сбой всего окна, хотя не собралась одна
///      кнопка; молчаливый пропуск честнее — остальное окно продолжает
///      работать, а разбор идёт по журналу.
///
/// Красное полотно можно вернуть — тем же способом, что и стеки кадров:
///
///     SECRETLY_SHOW_WIDGET_ERRORS=1 Secretly.app/Contents/MacOS/Secretly
///
/// Оно нужно тому, кто чинит, и НЕ нужно тому, кто переписывается: окно
/// владельца — это отладочная сборка (её собирает `tools/desktop_build_macos.sh`),
/// то есть по умолчанию он видел бы красное полотно каждый раз.
void _installDesktopErrorGuard() {
  final inner = FlutterError.onError;
  FlutterError.onError = (details) {
    DiagLog.event('ui', 'widget_error', {
      'lib': details.library ?? '-',
      'ctx': details.context?.toDescription() ?? '-',
      'err': details.exceptionAsString().split('\n').first,
    });
    inner?.call(details);
  };
  if (Platform.environment['SECRETLY_SHOW_WIDGET_ERRORS'] == '1') return;
  ErrorWidget.builder = (details) => const SizedBox.shrink();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installDesktopErrorGuard();
  // Лицензии вшитых шрифтов (OFL, Apache 2.0) обязаны ехать вместе с
  // дистрибутивом, а Flutter видит только пакеты из `pub`. На компьютере вызова
  // не было, и экран лицензий молчал о тринадцати семействах шрифтов
  // (17.09.2026). Один раз — повторный вызов задвоит записи.
  registerThirdPartyLicenses();

  // 🔎 Кто заказывает кадры.
  //
  // Включается переменной среды, поэтому пересобирать ради неё не надо:
  //
  //     SECRETLY_TRACE_FRAMES=1 Secretly.app/Contents/MacOS/Secretly
  //
  // Flutter напечатает стек на КАЖДЫЙ заказ кадра. Это единственный способ
  // назвать виновника непрерывной перерисовки: в профиле видно только, что
  // кадры идут подряд, но не кто их просит. Вывод обильный — включать на
  // секунды, не на сеанс.
  assert(() {
    if (Platform.environment['SECRETLY_TRACE_FRAMES'] == '1') {
      debugPrintScheduleFrameStacks = true;
    }
    return true;
  }());

  final isDesktopOs = !kIsWeb &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  if (isDesktopOs) {
    // 1. Single-instance: if another Secretly is already running, ask it to
    // surface and exit ourselves.
    final guard = await SingleInstance.forApp();
    final acquired = await guard.becomePrimary(
      onFocusRequested: () async {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (_) {}
      },
    );
    if (!acquired) {
      await guard.sendFocus();
      exit(0);
    }

    // 2. Window: hidden-titlebar shell, intercepted close → hide.
    // Restore the last size/position if we have one; otherwise center at the
    // default size.
    await windowManager.ensureInitialized();
    final savedBounds = await DesktopWindowState.load();
    // Only restore the saved POSITION if it still lands on an attached display;
    // otherwise center (a window saved on a now-unplugged monitor would open
    // off-screen and be unreachable on Windows/Linux). The saved SIZE is always
    // honored via WindowOptions.size.
    final restoreBounds =
        (savedBounds != null && await DesktopWindowState.isReachable(savedBounds))
            ? savedBounds
            : null;
    final opts = WindowOptions(
      size: DesktopWindowState.sizeOr(savedBounds, const Size(1440, 920)),
      minimumSize: const Size(960, 640),
      center: restoreBounds == null,
      title: 'Secretly',
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: const Color(0xFF1A1B1E),
    );
    await windowManager.waitUntilReadyToShow(opts, () async {
      if (restoreBounds != null) {
        try {
          await windowManager.setBounds(restoreBounds);
        } catch (_) {}
      }
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });

    // 3. System tray: icon + Show/Hide/Quit menu. Failures are non-fatal
    // (running headless in CI etc.).
    try {
      await _setupTray();
    } catch (_) {}

    // 4. PR3.10 (SPRINT2_AUDIT §15): warm up the desktop reactions «Недавние»
    // cache so the first right-click + expand has the recents row ready
    // without waiting on a SharedPreferences read. Fire-and-forget; the
    // store's `load()` is idempotent and best-effort.
    unawaited(DesktopRecentReactionsStore.instance.load());

    // 5. Desktop UI preferences (Enter-to-send). Loaded before the first chat
    // can be opened so the composer never briefly honours the default instead
    // of the user's choice. Best-effort: defaults hold if the read fails.
    unawaited(DesktopUiPrefs.load());
    // Спрашиваем нативную сторону, настроена ли проверка обновлений. Ответ
    // решает только одно: показывать ли пункт меню. Поэтому не ждём — пункт
    // появится, когда ответ придёт (меню слушает `configured`).
    unawaited(DesktopUpdateService.instance.load());
    // Признак «аккаунт заведён здесь, ключа ещё нет» — до первого кадра:
    // иначе шаг «сохраните набор» мигнёт после того, как оболочка уже
    // показалась.
    unawaited(DesktopAccountSetup.load());

    // 6. Composer drafts. Loaded before any chat can be opened so a restored
    // draft is already in place rather than appearing a moment later.
    unawaited(DesktopDraftStore.load());

    // 7. Временные копии вложений, которые прошлый сеанс отдавал внешним
    // программам: это расшифрованные файлы, и держать их дольше сеанса
    // незачем. Стираем в фоне — запуск ждать не должен.
    unawaited(clearAttachmentOpenCopies());
  }

  runApp(const DesktopProductionApp());
}

Future<void> _setupTray() async {
  // Reuse the app icon for the tray. On macOS this won't be a template image
  // (i.e. not auto-tinted to match menubar) — acceptable until we ship a
  // proper monochrome trayTemplate.png.
  await trayManager.setIcon('assets/app_ui/icons/app_icon.png');
  await trayManager.setToolTip('Secretly');
  await trayManager.setContextMenu(Menu(items: [
    MenuItem(key: 'show', label: 'Показать окно'),
    MenuItem(key: 'hide', label: 'Скрыть окно'),
    MenuItem.separator(),
    MenuItem(key: 'quit', label: 'Выйти'),
  ]));
  trayManager.addListener(_TrayBridge());
}

class _TrayBridge with TrayListener {
  @override
  void onTrayIconMouseDown() {
    unawaited(windowManager.show());
    unawaited(windowManager.focus());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(windowManager.show());
        unawaited(windowManager.focus());
        break;
      case 'hide':
        // Тем же путём, что и кнопка закрытия: иначе приложение считает себя
        // на экране (присутствие «в сети»).
        final hide = DesktopWindowActivity.hideHandler;
        unawaited(hide != null ? hide() : windowManager.hide());
        break;
      case 'quit':
        unawaited(windowManager.setPreventClose(false));
        unawaited(windowManager.destroy());
        break;
    }
  }
}
