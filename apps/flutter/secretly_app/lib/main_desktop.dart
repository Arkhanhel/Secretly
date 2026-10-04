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

import 'package:flutter/foundation.dart' show PlatformDispatcher, kIsWeb;
import 'package:flutter/scheduler.dart' show debugPrintScheduleFrameStacks;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'diagnostics/diag_log.dart';
import 'l10n/app_localizations.dart';
import 'desktop/ffmpeg_license.dart';
import 'desktop/single_instance.dart';
import 'desktop/windows_private_documents.dart';
import 'legal/third_party_licenses.dart';
import 'ui/desktop/onboarding/desktop_account_setup.dart';
import 'ui/desktop/services/desktop_update_service.dart';
import 'ui/desktop/app/desktop_production_app.dart';
import 'ui/desktop/chat/chat_thread_panel.dart' show DesktopDraftStore;
import 'ui/desktop/chat/recent_reactions_store.dart';
import 'ui/desktop/design/emoji_font.dart';
import 'ui/desktop/services/desktop_login_item_windows.dart'
    show kDesktopMinimizedArg;
import 'ui/desktop/services/desktop_child_window_selftest.dart';
import 'ui/desktop/services/desktop_child_windows.dart';
import 'ui/desktop/services/desktop_crash_log.dart';
import 'ui/desktop/services/desktop_diag_file_log.dart';
import 'ui/desktop/services/desktop_emoji_font_loader.dart';
import 'ui/desktop/services/desktop_emoji_font_selftest.dart';
import 'ui/desktop/services/desktop_global_hotkey_service.dart';
import 'ui/desktop/services/desktop_tray_service.dart';
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
      'at': DesktopCrashLog.stackTop(details.stack),
    });
    inner?.call(details);
  };
  if (Platform.environment['SECRETLY_SHOW_WIDGET_ERRORS'] == '1') return;
  ErrorWidget.builder = (details) => const SizedBox.shrink();
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Потолок кэша декодированных картинок — явно (01.10.2026). По умолчанию
  // 100 МБ, и пара полноразмерных фото из переписки вытесняла из него все
  // портреты списка: при прокрутке они декодировались заново. Портреты теперь
  // декодируются под размер на экране (`desktopAvatarImage`), так что запас
  // уходит на фото и медиа. Телефону здесь ничего не меняется — это вход ПК.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 * 1024 * 1024;
  // 🔴 Ошибки — в журнал с первой строки (30.09.2026): до открытия файла
  // строки ждут в памяти, необработанные ошибки зон ловит
  // PlatformDispatcher.onError (см. [DesktopCrashLog]).
  DesktopDiagFileLog.captureEarly();
  DesktopCrashLog.install();
  _installDesktopErrorGuard();
  // Лицензии вшитых шрифтов (OFL, Apache 2.0) обязаны ехать вместе с
  // дистрибутивом, а Flutter видит только пакеты из `pub`. На компьютере вызова
  // не было, и экран лицензий молчал о тринадцати семействах шрифтов
  // (17.09.2026). Один раз — повторный вызов задвоит записи.
  registerThirdPartyLicenses();
  // FFmpeg у ПК — «full-gpl», то есть GPL-3.0; пакет заявляет LGPL (30.09.2026).
  registerDesktopFfmpegLicense();

  // 🔴 ЭМОДЗИ WINDOWS — NOTO, КАК НА ТЕЛЕФОНЕ (30.09.2026, Э1). Файл едет
  // только в сборке Windows (`data\`), и лицензия заявляется только там.
  // Загрузка начинается ЗДЕСЬ, первой, и идёт параллельно с подготовкой окна
  // и трея; перед `runApp` её ждут не дольше
  // [kDesktopEmojiFontStartupWait]. Нет файла или движок его не принял —
  // остаётся Segoe, запуск не падает (см. `DesktopEmojiFontLoader`). На macOS
  // и Linux вызов сразу возвращается, не трогая диск.
  if (DesktopEmojiFont.enabled) registerWindowsEmojiFontLicense();
  final emojiFont = DesktopEmojiFontLoader.load();
  // Самотест шрифта (CI Windows): своё маленькое окно вместо приложения —
  // без замка второго экземпляра, окна, трея и сети. См.
  // `desktop_emoji_font_selftest.dart`.
  if (args.contains(kEmojiFontSelftestArg)) {
    await runDesktopEmojiFontSelftest(emojiFont);
    return;
  }

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
    // Файл журнала — сразу за замком: второй экземпляр в тот же файл не
    // пишет. Вызов из приложения потом ничего не делает.
    await DesktopDiagFileLog.start();

    // 🔴 WINDOWS: «ДОКУМЕНТЫ» ПРИЛОЖЕНИЯ — В ЕГО ПАПКЕ (30.09.2026). Иначе
    // расшифрованные вложения и фото контактов лежат в общих «Документах»,
    // которые синхронизирует OneDrive. Строго после замка единственного
    // экземпляра (переносить файлы из-под работающей копии нельзя) и до
    // `runApp` (контроллер ещё не открыл ни одного файла). См.
    // `windows_private_documents.dart`.
    final moved = await installWindowsPrivateDocuments();
    if (moved != null && (moved.moved > 0 || moved.failed > 0)) {
      DiagLog.event('storage', 'windows_documents_moved', {
        'moved': moved.moved,
        'skipped': moved.skipped,
        'failed': moved.failed,
      });
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
    // Автозапуск «свёрнутым» (Windows, `--autostart --minimized`): окно не
    // показываем — приложение ждёт в трее. Раннер тоже не показывает его на
    // первом кадре (flutter_window.cpp).
    final startHidden = args.contains(kDesktopMinimizedArg);
    await windowManager.waitUntilReadyToShow(opts, () async {
      if (restoreBounds != null) {
        try {
          await windowManager.setBounds(restoreBounds);
        } catch (_) {}
      }
      await windowManager.setPreventClose(true);
      if (!startHidden) {
        await windowManager.show();
        await windowManager.focus();
      }
    });

    // 3. Значок в трее и его меню. «Трей готов» — только если значок
    // настоящий: на Windows файл `.ico` обязан лежать в сборке (см.
    // `DesktopTrayService.install`). Иначе крестик закрывает приложение, а не
    // прячет его туда, откуда не достать. Пути приложения (спрятать через
    // учёт видимости, «без звука») подставит само приложение после запуска.
    try {
      DesktopWindowActivity.trayReady =
          await DesktopTrayService.instance.install(
        actions: DesktopTrayActions(
          show: _showMainWindow,
          hide: () async {
            final hide = DesktopWindowActivity.hideHandler;
            await (hide != null ? hide() : windowManager.hide());
          },
          quit: quitDesktopApp,
        ),
        l10n: _startupL10n(),
      );
    } catch (_) {
      DesktopWindowActivity.trayReady = false;
    }
    if (startHidden) {
      if (DesktopWindowActivity.trayReady) {
        DesktopWindowActivity.startedHidden = true;
      } else {
        // Значка нет — спрятанное окно было бы недоступно.
        await _showMainWindow();
      }
    }

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
    // Общесистемное ⌥⌘S (macOS): если человек его включал, занимаем сочетание
    // сразу при запуске, а не когда он откроет «Горячие клавиши» (01.10.2026).
    // Не на маке вызов сразу возвращается.
    unawaited(DesktopGlobalHotKeyService.instance.load());
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

  // Шрифт эмодзи (Э1) к этой строке обычно уже загружен; если диск медленный —
  // ждём не дольше предела, опоздавший шрифт движок применит сам.
  await DesktopEmojiFontLoader.waitAtMost(kDesktopEmojiFontStartupWait);

  // 🔴 Хозяин отдельных окон — НАД приложением (29.09.2026, Р1): у окна
  // звонка свой навигатор, чужого выше быть не должно. См.
  // [DesktopChildWindowHost].
  runApp(const DesktopChildWindowHost(child: DesktopProductionApp()));
  if (args.contains(kChildWindowSelftestArg)) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(runDesktopChildWindowSelftest()),
    );
  }
}

Future<void> _showMainWindow() async {
  try {
    await windowManager.show();
    await windowManager.focus();
  } catch (_) {}
}

/// Переводы до того, как приложение прочитало язык из настроек: берём язык
/// системы, а если его нет среди восьми — английский. Позже меню трея
/// перестраивает само приложение на выбранном языке.
AppLocalizations _startupL10n() {
  try {
    return lookupAppLocalizations(
      Locale(PlatformDispatcher.instance.locale.languageCode),
    );
  } catch (_) {
    return lookupAppLocalizations(const Locale('en'));
  }
}
