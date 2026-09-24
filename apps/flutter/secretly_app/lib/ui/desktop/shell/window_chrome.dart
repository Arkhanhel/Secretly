// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_tooltip.dart';
import '../primitives/hover_listener.dart';

/// Custom title bar that hosts:
///  • draggable region (whole bar minus interactive parts)
///  • macOS traffic-light reserve area (the native buttons are overlaid by AppKit)
///  • Windows min / max / close controls (we draw them)
///  • history arrows + breadcrumbs, the global search, the now-playing island
///  • optional trailing action slot (badges, settings hook)
class DesktopWindowChrome extends StatelessWidget {
  const DesktopWindowChrome({
    super.key,
    this.title,
    this.leading,
    this.search,
    this.island,
    this.trailing,
    this.navBack,
    this.navForward,
    this.height = 48,
  });

  final String? title;

  /// Хлебные крошки слева от поиска.
  ///
  /// 🔴 Здесь же возвращается имя приложения. Заголовок окна (`title`)
  /// показывается только когда крошек нет — иначе «Secretly» не было бы
  /// видно в окне НИГДЕ: на macOS заголовка окна нет и в системе, приложение
  /// опознаётся только значком в доке.
  final Widget? leading;

  /// Поле глобального поиска — слева от середины, сразу перед островком.
  final Widget? search;

  /// Островок «сейчас играет» — в середине окна. Сам решает, показываться ли:
  /// шапка держит под него место всегда, чтобы поиск не прыгал, когда музыка
  /// начинается и кончается.
  final Widget? island;

  final Widget? trailing;

  /// «Назад» по истории открытых переписок. `null` — идти некуда, и стрелка
  /// гаснет, а не исчезает: пропадающая кнопка сдвигает соседние и заставляет
  /// целиться заново.
  final VoidCallback? navBack;

  /// «Вперёд» по той же истории.
  final VoidCallback? navForward;
  final double height;

  bool get _isMacOS => !kIsWeb && Platform.isMacOS;
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return Container(
      height: height,
      // 🔴 ШАПКА ОКНА — ОТДЕЛЬНАЯ ПОВЕРХНОСТЬ, А НЕ ПРОЗРАЧНАЯ ПОЛОСА.
      //
      // В макете она залита своим цветом и отделена чертой: хлебные крошки,
      // поиск и кнопки окна лежат НАД приложением, а не внутри него. Без
      // заливки полоса сливалась с рейкой слева и со списком справа, и черта
      // внизу выглядела случайной линией поперёк окна.
      //
      // Высота 48 — тоже из макета; на 40 точках светофор macOS и поле поиска
      // стояли впритык к краям.
      // Шапка окна — СВОЯ поверхность (#121A24), а не тон всплывающих
      // карточек: она идёт вдоль всего верха, и на этой длине «почти тот» тон
      // читается как чужая полоса, приклеенная сверху.
      color: c.titleBar,
      child: Stack(
        children: [
          // The whole bar is draggable except for interactive children below.
          Positioned.fill(child: _DragRegion()),

          // 🔴 РАСКЛАДКА ШАПКИ — СВОЯ, А НЕ СТРОКА С РАСПОРКОЙ (24.09.2026).
          //
          // Здесь была строка «крошки (гибкие) · распорка · поиск · кнопки», и
          // поиск «прижимался вправо» только на словах: гибких детей было двое,
          // крошки и распорка, и свободное место делилось между ними пополам.
          // Поле вставало около середины, а правая четверть шапки пустовала.
          //
          // Теперь в середине окна — островок «сейчас играет», поиск — сразу
          // слева от него, крошки — от левого края, кнопки — у правого. Место
          // под островок держится всегда, поэтому поле не прыгает, когда
          // песня начинается и кончается. См. [_ChromeLayout].
          CustomMultiChildLayout(
            delegate: _ChromeLayout(
              padLeft: _isMacOS ? 80 : DSpace.m, // reserve for traffic lights
              padRight: _isWindows ? 0 : DSpace.m,
            ),
            children: [
              LayoutId(
                id: _ChromeSlot.lead,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Стрелки истории — сразу за светофором, как в макете. См.
                    // [DesktopNavHistory]: они настоящие, а не нарисованные.
                    _NavArrow(
                      icon: FluentIcons.chevron_left_20_regular,
                      tooltip: l10n.desktopWindowBack,
                      onTap: navBack,
                    ),
                    _NavArrow(
                      icon: FluentIcons.chevron_right_20_regular,
                      tooltip: l10n.desktopWindowForward,
                      onTap: navForward,
                    ),
                    const SizedBox(width: DSpace.s),
                    if (leading != null)
                      Flexible(child: leading!)
                    else if (title != null)
                      Flexible(
                        child: Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DType.label.copyWith(color: c.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              if (search != null)
                LayoutId(id: _ChromeSlot.search, child: search!),
              if (island != null)
                LayoutId(id: _ChromeSlot.island, child: island!),
              LayoutId(
                id: _ChromeSlot.trail,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (trailing != null) trailing!,
                    if (_isWindows) const _WindowsControls(),
                  ],
                ),
              ),
            ],
          ),
          // Bottom border (1pt subtle line)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(height: 1, color: c.borderHairline),
          ),
        ],
      ),
    );
  }
}

enum _ChromeSlot { lead, search, island, trail }

/// Раскладка шапки: крошки слева, островок посередине окна, поиск — сразу
/// слева от островка, кнопки справа.
///
/// Порядок уступок, когда окно узкое: сначала крошки не дают себя задвинуть
/// под поле (поиск и островок сдвигаются вправо), потом островок сужается до
/// [islandMin], потом поле до [searchMin], и только затем островок уходит
/// совсем. Поле поиска не исчезает никогда: это вход в приложение, а музыку
/// можно остановить и в пузыре.
class _ChromeLayout extends MultiChildLayoutDelegate {
  _ChromeLayout({required this.padLeft, required this.padRight});

  final double padLeft;
  final double padRight;

  static const double gap = 12;
  static const double searchWidth = 280;
  static const double searchMin = 190;
  static const double islandWidth = 340;
  static const double islandMin = 220;

  /// Больше этого крошкам не отдаём: длинное название темы ужмётся
  /// многоточием, а не вытолкнет поиск за середину.
  static const double leadCap = 360;

  @override
  void performLayout(Size size) {
    final w = size.width;
    final h = size.height;
    void put(_ChromeSlot id, double x, Size s) =>
        positionChild(id, Offset(x, (h - s.height) / 2));

    var trailW = 0.0;
    if (hasChild(_ChromeSlot.trail)) {
      final s = layoutChild(
        _ChromeSlot.trail,
        BoxConstraints.loose(Size(w, h)),
      );
      trailW = s.width;
      put(_ChromeSlot.trail, w - padRight - trailW, s);
    }
    final right = w - padRight - trailW - (trailW > 0 ? gap / 2 : 0);

    final hasSearch = hasChild(_ChromeSlot.search);
    final hasIsland = hasChild(_ChromeSlot.island);
    final middleMin =
        (hasSearch ? searchMin + gap : 0) + (hasIsland ? islandMin + gap : 0);

    var leadW = 0.0;
    if (hasChild(_ChromeSlot.lead)) {
      final cap = math.max(
        0.0,
        math.min(leadCap, right - padLeft - middleMin),
      );
      final s = layoutChild(
        _ChromeSlot.lead,
        BoxConstraints.loose(Size(cap, h)),
      );
      leadW = s.width;
      put(_ChromeSlot.lead, padLeft, s);
    }
    final minX = padLeft + leadW + gap;

    var sW = hasSearch ? searchWidth : 0.0;
    var iW = hasIsland ? islandWidth : 0.0;
    // Островок — посередине ОКНА, а не свободного места между крошками и
    // кнопками: середина окна не зависит от того, какой чат открыт.
    var islandX = (w - islandWidth) / 2;
    var searchX = hasSearch ? islandX - gap - sW : islandX;
    if (searchX < minX) {
      searchX = minX;
      islandX = hasSearch ? searchX + sW + gap : searchX;
    }
    final end = hasIsland ? islandX + iW : searchX + sW;
    var overflow = end - (right - gap);
    if (overflow > 0 && hasIsland) {
      final take = math.min(overflow, iW - islandMin);
      iW -= take;
      overflow -= take;
    }
    if (overflow > 0 && hasSearch) {
      final take = math.min(overflow, sW - searchMin);
      sW -= take;
      islandX -= take;
      overflow -= take;
    }
    if (overflow > 0 && hasIsland) iW = 0;

    if (hasSearch) {
      final s = layoutChild(
        _ChromeSlot.search,
        BoxConstraints(minWidth: sW, maxWidth: sW, maxHeight: h),
      );
      put(_ChromeSlot.search, searchX, s);
    }
    if (hasIsland) {
      final s = layoutChild(
        _ChromeSlot.island,
        BoxConstraints(minWidth: iW, maxWidth: iW, maxHeight: h),
      );
      put(_ChromeSlot.island, islandX, s);
    }
  }

  @override
  bool shouldRelayout(_ChromeLayout old) =>
      old.padLeft != padLeft || old.padRight != padRight;
}

class _DragRegion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: const SizedBox.expand(),
    );
  }
}

class _WindowsControls extends StatelessWidget {
  const _WindowsControls();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        DesktopIconButton(
          icon: Icons.remove_rounded,
          size: 40,
          iconSize: 16,
          tooltip: l10n.desktopWindowMinimize,
          onPressed: () => windowManager.minimize(),
        ),
        DesktopIconButton(
          icon: Icons.crop_square_rounded,
          size: 40,
          iconSize: 14,
          tooltip: l10n.desktopWindowMaximize,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        DesktopIconButton(
          icon: Icons.close_rounded,
          size: 40,
          iconSize: 16,
          tooltip: l10n.desktopWindowClose,
          kind: DIconButtonKind.danger,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

/// Поле «перейти куда угодно» в шапке окна — видимый вход в тот же поиск,
/// который открывается по ⌘K.
///
/// 🔴 Зачем видимый вход, если горячая клавиша уже есть. Горячую клавишу знает
/// тот, кому её показали. Человек, который открыл мессенджер для работы и
/// держит в нём три десятка переписок, находит нужную глазами по списку — и
/// чем длиннее список, тем дороже каждый такой поиск. Поле в шапке показывает,
/// что искать вообще можно, и заодно учит сочетанию: подпись ⌘K стоит прямо в
/// нём.
///
/// Подсказка нарочно говорит про чаты и людей и НЕ говорит про каналы: каналов
/// в мессенджере пока нет, а интерфейс, обещающий несуществующее, — это то же
/// враньё, что «был(а) в сети» при отсутствии данных.
/// Хлебные крошки окна: где человек сейчас находится.
///
/// 🔴 Зачем они на столе и не нужны на телефоне.
///
/// На телефоне экран один, и «где я» отвечает сам экран. На столе одновременно
/// видны рейка, список, переписка и подробности — а открытая тема внутри
/// комнаты не видна нигде, кроме полосы под шапкой чата, куда взгляд не ходит.
/// Крошки собирают путь в одну строку у самого верха окна.
///
/// 🔴 СЛОВА «SECRETLY» ЗДЕСЬ БОЛЬШЕ НЕТ (14.09.2026, по макету).
///
/// Оно стояло первой крошкой, и объяснялось это тем, что больше нигде в окне
/// имя приложения не написано. Но имя ЕСТЬ — значком слева, тем самым, что
/// остался: в макете путь начинается с него и сразу идёт к собеседнику. Слово
/// рядом со значком повторяло значок и отодвигало вправо то, ради чего строку
/// и читают, — имя открытого чата и тему.
///
/// Последняя крошка выделена весом и цветом: она отвечает на вопрос «где я»,
/// остальные — только путь к ней.
class DesktopBreadcrumbs extends StatelessWidget {
  const DesktopBreadcrumbs({super.key, required this.crumbs});

  /// От общего к частному: раздел, чат, тема. Пустые пропускаются вызывающей
  /// стороной — здесь их быть не должно.
  final List<String> crumbs;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.accentPrimary, c.accentPrimaryAlt],
            ),
            borderRadius: BorderRadius.circular(DRadii.sm),
          ),
          child: const Text(
            'S',
            style: TextStyle(
              fontFamily: DType.family,
              fontSize: 11,
              height: 1.0,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 7),
        for (var i = 0; i < crumbs.length; i++) ...[
          if (i > 0)
            Icon(
              FluentIcons.chevron_right_16_regular,
              size: 15,
              color: c.textFaint,
            ),
          // Последняя крошка — самая частная, и ужимать надо НЕ её: обрезанное
          // название темы сообщает меньше, чем обрезанное имя раздела.
          Flexible(
            child: Text(
              crumbs[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DType.label.copyWith(
                color: i == crumbs.length - 1
                    ? c.textPrimary
                    : c.textSecondary,
                fontWeight: i == crumbs.length - 1
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Что именно ищет ⌘K — одной строкой и в ОДНОМ месте.
///
/// 🔴 Подпись перечисляет ровно то, что палитра действительно находит, и
/// потому живёт константой: её показывают и поле в шапке, и приглашение внутри
/// палитры. Разъехавшись, они дали бы два разных обещания об одном поиске.
///
/// Файлы появились последними: имя вложения лежит внутри зашифрованного груза,
/// указателя по нему нет, и до своего обхода присланный «договор.pdf» поиск не
/// находил вовсе. Слова «Поиск по…» в начале нет намеренно — слева уже стоит
/// лупа, и строка без них помещается в поле целиком, а не обрывается
/// многоточием на середине перечисления.
String desktopSearchScopeLabel(AppLocalizations l10n) =>
    l10n.desktopSearchEverything;

/// Стрелка истории в шапке окна.
///
/// Недоступная стрелка ГАСНЕТ, а не пропадает: исчезнувшая кнопка сдвигает
/// соседнюю на своё место, и следующий щелчок попадает не туда, куда целились.
class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final enabled = onTap != null;
    final arrow = HoverListener(
      onTap: onTap,
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: !enabled
              ? Colors.transparent
              : (pressed ? c.pressed : (hovered ? c.hover : Colors.transparent)),
          borderRadius: BorderRadius.circular(DRadii.sm),
        ),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Icon(icon, size: 18, color: c.textTertiary),
        ),
      ),
    );
    return enabled ? DesktopTooltip(message: tooltip, child: arrow) : arrow;
  }
}
