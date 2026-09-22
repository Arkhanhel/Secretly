// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';

/// Строка меню macOS.
///
/// 🔴 ПОЧЕМУ МЕНЮ СТРОИТСЯ ЗДЕСЬ, А НЕ ЛЕЖИТ В `MainMenu.xib`.
///
/// В `.xib` меню было стандартное флаттеровское и **только по-английски**:
/// `macos/Runner/Base.lproj/MainMenu.xib`, других `.lproj` для него нет. Окно
/// к 20.09.2026 переведено на восемь языков — и строка меню НАД ним осталась
/// английской. На Mac это первое, что видно.
///
/// Перевести сам `.xib` можно (`MainMenu.strings` на каждый язык), но он
/// пошёл бы за языком СИСТЕМЫ, а не за языком, выбранным в настройках
/// приложения. Человек, поставивший в Secretly русский на английском Mac,
/// получил бы русское окно под английским меню — то же расхождение, только
/// наоборот. `PlatformMenuBar` строит меню из тех же переводов, что и окно, и
/// перестраивает его, когда язык меняют.
///
/// 🔴 СИСТЕМНЫЕ ПУНКТЫ ОСТАЮТСЯ СИСТЕМНЫМИ. «О программе», «Службы»,
/// «Скрыть», «Завершить», «Во весь экран», «Свернуть», «Масштаб» — это
/// [PlatformProvidedMenuItem]: их подписывает macOS на языке системы и делает
/// ими ровно то, что от них ждут. Своя подпись у такого пункта означала бы
/// свой перевод системного слова — и он рано или поздно разошёлся бы с тем,
/// что человек видит в остальных приложениях.
class DesktopAppMenu extends StatelessWidget {
  const DesktopAppMenu({
    super.key,
    required this.child,
    this.onOpenSettings,
    this.onOpenShortcuts,
    this.onOpenAbout,
  });

  final Widget child;

  /// «Настройки… ⌘,». `null` — пункта нет вовсе.
  ///
  /// Пункт меню, который ничего не открывает, хуже отсутствующего: меню — это
  /// перечень того, что приложение УМЕЕТ.
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenShortcuts;
  final VoidCallback? onOpenAbout;

  static bool get _isMacOS => !kIsWeb && Platform.isMacOS;

  /// Сайт из «О программе» — тот же адрес, один на приложение.
  static const String _siteUrl = 'https://www.secretlyapp.com';

  /// Отправляет намерение правки туда, где сейчас курсор.
  ///
  /// Это ровно тот путь, которым идут сами сочетания ⌘C/⌘V внутри поля ввода
  /// (`Actions` вокруг редактируемого текста), поэтому пункт меню и клавиши
  /// делают одно и то же, а не два похожих дела.
  ///
  /// Курсор не в тексте — `maybeInvoke` ничего не найдёт и вернёт null. Так и
  /// надо: в macOS эти пункты в такой момент погашены, и «ничего не
  /// произошло» здесь — верный ответ, а не потерянное нажатие.
  static void _editIntent(Intent intent) {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return;
    Actions.maybeInvoke(ctx, intent);
  }

  static Future<void> _openSite() async {
    try {
      await launchUrl(Uri.parse(_siteUrl), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Нечем показать ошибку: меню живёт над окном, а не в нём. Молчание
      // здесь честнее, чем всплывашка поверх чужого приложения.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Строка меню есть только у macOS. На Windows и Linux меню приложения нет
    // как понятия оболочки, и `PlatformMenuBar` там ничего не рисует —
    // обёртка просто не нужна.
    if (!_isMacOS) return child;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return child;
    return PlatformMenuBar(menus: menus(l10n), child: child);
  }

  /// Дерево меню отдельно от `build`.
  ///
  /// Меню рисует macOS, и проверить его нажатием в тесте нельзя. Зато можно
  /// проверить ДЕРЕВО: подписи приходят из переводов, у каждого своего пункта
  /// есть обработчик, «Проверить обновления» нет. Ради этого метод и открыт —
  /// иначе проверка свелась бы к «на macOS что-то построилось», а на сборщике
  /// с Linux не свелась бы и к этому.
  @visibleForTesting
  List<PlatformMenuItem> menus(AppLocalizations l10n) => <PlatformMenuItem>[
        // Первое меню macOS всегда подписывает именем приложения — своя
        // подпись сюда не доходит, поэтому она и не переводится.
        PlatformMenu(
          label: 'Secretly',
          menus: <PlatformMenuItem>[
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                if (onOpenAbout != null)
                  PlatformMenuItem(
                    label: l10n.desktopSettingsAboutLabel,
                    onSelected: onOpenAbout,
                  )
                else
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.about,
                  ),
              ],
            ),
            if (onOpenSettings != null)
              PlatformMenuItemGroup(
                members: <PlatformMenuItem>[
                  PlatformMenuItem(
                    label: l10n.desktopMenuSettings,
                    // ⌘, — системное сочетание для настроек. Оно же написано
                    // на плитке рейки («Настройки ⌘,»), и в окне оно уже
                    // работает; здесь это ЕГО отображение в меню, а не второе
                    // такое же сочетание.
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.comma,
                      meta: true,
                    ),
                    onSelected: onOpenSettings,
                  ),
                ],
              ),
            const PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.servicesSubmenu,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hideOtherApplications,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.showAllApplications,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: l10n.desktopMenuEdit,
          menus: <PlatformMenuItem>[
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: l10n.desktopMenuUndo,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                  ),
                  onSelected: () => _editIntent(
                    const UndoTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
                PlatformMenuItem(
                  label: l10n.desktopMenuRedo,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                    shift: true,
                  ),
                  onSelected: () => _editIntent(
                    const RedoTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: l10n.desktopMenuCut,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyX,
                    meta: true,
                  ),
                  onSelected: () => _editIntent(
                    const CopySelectionTextIntent.cut(
                      SelectionChangedCause.keyboard,
                    ),
                  ),
                ),
                PlatformMenuItem(
                  label: l10n.copy,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyC,
                    meta: true,
                  ),
                  onSelected: () => _editIntent(CopySelectionTextIntent.copy),
                ),
                PlatformMenuItem(
                  label: l10n.desktopMenuPaste,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyV,
                    meta: true,
                  ),
                  onSelected: () => _editIntent(
                    const PasteTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: l10n.desktopMenuSelectAll,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyA,
                    meta: true,
                  ),
                  onSelected: () => _editIntent(
                    const SelectAllTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: l10n.desktopMenuView,
          menus: const <PlatformMenuItem>[
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
          ],
        ),
        PlatformMenu(
          label: l10n.desktopMenuWindow,
          menus: const <PlatformMenuItem>[
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.minimizeWindow,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.zoomWindow,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.arrangeWindowsInFront,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: l10n.desktopMenuHelp,
          menus: <PlatformMenuItem>[
            // «Проверить обновления» здесь НЕТ намеренно: автообновления в
            // приложении пока нет. Пункт, который ничего не проверяет, —
            // обещание, которого некому сдержать.
            if (onOpenShortcuts != null)
              PlatformMenuItem(
                label: l10n.desktopSettingsShortcutsLabel,
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.slash,
                  meta: true,
                ),
                onSelected: onOpenShortcuts,
              ),
            PlatformMenuItem(
              label: l10n.desktopMenuWebsite,
              onSelected: () => unawaited(_openSite()),
            ),
          ],
        ),
      ];
}
