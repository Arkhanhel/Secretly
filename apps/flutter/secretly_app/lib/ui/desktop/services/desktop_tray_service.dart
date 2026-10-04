// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// ЗНАЧОК В ТРЕЕ: КАКОЙ ФАЙЛ, КАКОЕ МЕНЮ, ЧТО ДЕЛАЕТ НАЖАТИЕ.
///
/// 🔴 ПОЧЕМУ ОТДЕЛЬНАЯ СЛУЖБА (28.09.2026, владелец: «нет мини-иконки справа
/// для фоновой работы»). Раньше значок ставился в `main_desktop.dart` из PNG.
/// На Windows `tray_manager` грузит значок через
/// `LoadImage(IMAGE_ICON, LR_LOADFROMFILE)`, а тот читает ТОЛЬКО `.ico`: из
/// PNG выходил пустой значок. Плагин при этом отвечал «успех», приложение
/// считало трей рабочим — и крестик прятал окно туда, откуда его не достать.
///
/// Теперь:
/// * на Windows — настоящий `.ico` (16…64 px) в трёх видах: обычный, «есть
///   непрочитанное», «без звука»; на macOS — шаблонный значок строки меню,
///   который система сама красит под светлую и тёмную строку;
/// * «трей готов» — только если файл значка действительно лежит в сборке и
///   это ICO ([desktopTrayIconFileLooksValid]); иначе крестик закрывает
///   приложение, как и раньше без значка;
/// * меню на языке приложения: «Открыть», число непрочитанных, «Без звука ▸
///   на час / на 8 часов / пока не включу», «Выйти».
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

import '../../../l10n/app_localizations.dart';

/// Вид значка.
enum DesktopTrayIconVariant { normal, unread, muted }

/// Какой вид значка показать.
///
/// «Без звука» важнее «непрочитанного»: как у Telegram, выключенный звук
/// виден сразу, а непрочитанное всё равно показывает подсказка и меню.
DesktopTrayIconVariant desktopTrayIconVariantFor({
  required int unread,
  required bool muted,
}) {
  if (muted) return DesktopTrayIconVariant.muted;
  if (unread > 0) return DesktopTrayIconVariant.unread;
  return DesktopTrayIconVariant.normal;
}

/// Путь ассета значка для ОС [platform].
String desktopTrayIconAsset(
  TargetPlatform platform,
  DesktopTrayIconVariant variant,
) {
  switch (platform) {
    case TargetPlatform.windows:
      switch (variant) {
        case DesktopTrayIconVariant.normal:
          return 'assets/desktop/tray/tray.ico';
        case DesktopTrayIconVariant.unread:
          return 'assets/desktop/tray/tray_unread.ico';
        case DesktopTrayIconVariant.muted:
          return 'assets/desktop/tray/tray_muted.ico';
      }
    case TargetPlatform.macOS:
      // Строка меню macOS — одноцветный шаблон. Цветной значок там выглядит
      // чужим и не перекрашивается под тёмную строку.
      return 'assets/desktop/tray/tray_template.png';
    default:
      return 'assets/app_ui/icons/app_icon.png';
  }
}

/// Где `tray_manager` на Windows будет искать ассет [asset].
///
/// Плагин сам склеивает путь из папки программы и `data/flutter_assets`
/// (`tray_manager.dart`, `setIcon`), и проверять надо ровно этот путь.
String desktopTrayIconFilePath(String asset, {String? executable}) => p.join(
      p.dirname(executable ?? Platform.resolvedExecutable),
      'data',
      'flutter_assets',
      asset,
    );

/// Лежит ли по [path] настоящий ICO.
///
/// Заголовок ICO — `00 00 01 00`. PNG, пустой файл или его отсутствие дают
/// `false`: из такого файла Windows значка не построит.
bool desktopTrayIconFileLooksValid(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) return false;
    final raf = file.openSync();
    try {
      final head = raf.readSync(4);
      return head.length == 4 &&
          head[0] == 0 &&
          head[1] == 0 &&
          head[2] == 1 &&
          head[3] == 0;
    } finally {
      raf.closeSync();
    }
  } catch (_) {
    return false;
  }
}

/// Ключи пунктов меню трея.
abstract final class DesktopTrayMenuKeys {
  static const String open = 'open';
  static const String unread = 'unread';
  static const String muteHour = 'mute_1h';
  static const String muteEightHours = 'mute_8h';
  static const String muteForever = 'mute_forever';
  static const String unmute = 'unmute';
  static const String quit = 'quit';
}

/// Меню трея.
///
/// Чистая функция: её проверяют тесты, а платформенный вызов остаётся
/// снаружи.
Menu buildDesktopTrayMenu({
  required AppLocalizations l10n,
  required int unread,
  required bool muted,
  String? mutedUntilLabel,
}) {
  return Menu(
    items: [
      MenuItem(key: DesktopTrayMenuKeys.open, label: l10n.desktopTrayOpen),
      if (unread > 0)
        MenuItem(
          key: DesktopTrayMenuKeys.unread,
          label: l10n.desktopTrayUnread(unread),
          disabled: true,
        ),
      MenuItem.separator(),
      if (muted) ...[
        if (mutedUntilLabel != null)
          MenuItem(
            key: 'muted_until',
            label: l10n.desktopTrayMutedUntil(mutedUntilLabel),
            disabled: true,
          ),
        MenuItem(key: DesktopTrayMenuKeys.unmute, label: l10n.desktopTrayUnmute),
      ] else
        MenuItem.submenu(
          key: 'mute',
          label: l10n.desktopTrayMute,
          submenu: Menu(
            items: [
              MenuItem(
                key: DesktopTrayMenuKeys.muteHour,
                label: l10n.desktopTrayMuteHour,
              ),
              MenuItem(
                key: DesktopTrayMenuKeys.muteEightHours,
                label: l10n.desktopTrayMuteEightHours,
              ),
              MenuItem(
                key: DesktopTrayMenuKeys.muteForever,
                label: l10n.desktopTrayMuteForever,
              ),
            ],
          ),
        ),
      MenuItem.separator(),
      MenuItem(key: DesktopTrayMenuKeys.quit, label: l10n.desktopTrayQuit),
    ],
  );
}

/// Что делать по нажатиям. Приложение подставляет свои пути после запуска;
/// до этого работают безопасные запасные (показать окно, выйти).
class DesktopTrayActions {
  const DesktopTrayActions({
    required this.show,
    required this.hide,
    required this.quit,
    this.isWindowInFront,
    this.mute,
    this.unmute,
  });

  final Future<void> Function() show;
  final Future<void> Function() hide;
  final Future<void> Function() quit;

  /// Окно на экране и в фокусе — тогда нажатие по значку на Windows его
  /// прячет, как у Telegram.
  final bool Function()? isWindowInFront;

  /// `null` — «пока не включу».
  final Future<void> Function(Duration? duration)? mute;
  final Future<void> Function()? unmute;
}

class DesktopTrayService with TrayListener {
  DesktopTrayService._({TargetPlatform? platform})
      : _platform = platform ?? defaultTargetPlatform;

  static final DesktopTrayService instance = DesktopTrayService._();

  @visibleForTesting
  factory DesktopTrayService.forTest(TargetPlatform platform) =>
      DesktopTrayService._(platform: platform);

  final TargetPlatform _platform;
  DesktopTrayActions? _actions;
  DesktopTrayIconVariant? _shownVariant;
  String _menuSignature = '';
  String _tooltip = '';
  bool _installed = false;

  bool get _isWindows => _platform == TargetPlatform.windows;

  /// Ставит значок и меню. Возвращает, есть ли у человека настоящий значок.
  ///
  /// 🔴 На Windows `false`, если файла значка нет в сборке: тогда прятать
  /// окно некуда, и крестик обязан закрывать приложение.
  Future<bool> install({
    required DesktopTrayActions actions,
    required AppLocalizations l10n,
  }) async {
    _actions = actions;
    if (_isWindows) {
      final asset =
          desktopTrayIconAsset(_platform, DesktopTrayIconVariant.normal);
      if (!desktopTrayIconFileLooksValid(desktopTrayIconFilePath(asset))) {
        return false;
      }
    }
    await _setIcon(DesktopTrayIconVariant.normal);
    await trayManager.setToolTip('Secretly');
    _tooltip = 'Secretly';
    await _setMenu(l10n: l10n, unread: 0, muted: false);
    trayManager.addListener(this);
    _installed = true;
    return true;
  }

  /// Подставить пути приложения (после запуска дерева).
  void bind(DesktopTrayActions actions) => _actions = actions;

  /// Показать главное окно ТЕМ ЖЕ путём, что пункт «Открыть»: приложение
  /// при этом ведёт учёт видимости окна (присутствие, анимации). Для тех, кто
  /// выводит окно не из трея, — например, окна созвона (30.09.2026).
  Future<void> showMainWindow() async {
    final actions = _actions;
    if (actions != null) {
      await actions.show();
      return;
    }
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  /// Обновить значок, подсказку и меню. Ничего не делает, если нечего менять:
  /// каждое изменение — вызов через платформенный канал.
  Future<void> update({
    required AppLocalizations l10n,
    required int unread,
    required bool muted,
    String? mutedUntilLabel,
  }) async {
    if (!_installed) return;
    try {
      await _setIcon(desktopTrayIconVariantFor(unread: unread, muted: muted));
      final tooltip = unread > 0 ? l10n.desktopUnreadTitle(unread) : 'Secretly';
      if (tooltip != _tooltip) {
        _tooltip = tooltip;
        await trayManager.setToolTip(tooltip);
      }
      await _setMenu(
        l10n: l10n,
        unread: unread,
        muted: muted,
        mutedUntilLabel: mutedUntilLabel,
      );
    } catch (_) {
      // Трей — удобство. Отказ оболочки не должен ронять приложение.
    }
  }

  Future<void> _setIcon(DesktopTrayIconVariant variant) async {
    if (variant == _shownVariant) return;
    // На macOS один шаблон на все случаи: строка меню — не место для точек.
    if (!_isWindows && _shownVariant != null) return;
    await trayManager.setIcon(
      desktopTrayIconAsset(_platform, variant),
      isTemplate: _platform == TargetPlatform.macOS,
    );
    _shownVariant = variant;
  }

  Future<void> _setMenu({
    required AppLocalizations l10n,
    required int unread,
    required bool muted,
    String? mutedUntilLabel,
  }) async {
    final signature =
        '${l10n.localeName}|$unread|$muted|${mutedUntilLabel ?? ''}';
    if (signature == _menuSignature) return;
    _menuSignature = signature;
    await trayManager.setContextMenu(
      buildDesktopTrayMenu(
        l10n: l10n,
        unread: unread,
        muted: muted,
        mutedUntilLabel: mutedUntilLabel,
      ),
    );
  }

  /// Что делает левое нажатие по значку.
  ///
  /// Windows: как у Telegram — окно впереди → спрятать, иначе показать.
  /// macOS: значок строки меню открывает меню, как у любого значка там.
  @visibleForTesting
  Future<void> handlePrimaryClick() async {
    final actions = _actions;
    if (actions == null) return;
    if (_platform == TargetPlatform.macOS) {
      await trayManager.popUpContextMenu();
      return;
    }
    final front = actions.isWindowInFront?.call() ?? false;
    await (front ? actions.hide() : actions.show());
  }

  @visibleForTesting
  Future<void> handleMenuKey(String? key) async {
    final actions = _actions;
    if (actions == null) return;
    switch (key) {
      case DesktopTrayMenuKeys.open:
        await actions.show();
      case DesktopTrayMenuKeys.muteHour:
        await actions.mute?.call(const Duration(hours: 1));
      case DesktopTrayMenuKeys.muteEightHours:
        await actions.mute?.call(const Duration(hours: 8));
      case DesktopTrayMenuKeys.muteForever:
        await actions.mute?.call(null);
      case DesktopTrayMenuKeys.unmute:
        await actions.unmute?.call();
      case DesktopTrayMenuKeys.quit:
        await actions.quit();
    }
  }

  @override
  void onTrayIconMouseDown() => unawaited(handlePrimaryClick());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) =>
      unawaited(handleMenuKey(menuItem.key));
}
