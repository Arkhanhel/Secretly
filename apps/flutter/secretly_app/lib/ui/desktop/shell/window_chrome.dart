// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io' show Platform;

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
///  • centered title text
///  • optional trailing action slot (badges, settings hook)
class DesktopWindowChrome extends StatelessWidget {
  const DesktopWindowChrome({
    super.key,
    this.title,
    this.leading,
    this.center,
    this.trailing,
    this.navBack,
    this.navForward,
    this.height = 48,
  });

  final String? title;

  /// Хлебные крошки слева от поиска.
  ///
  /// 🔴 Здесь же возвращается имя приложения. Заголовок окна (`title`)
  /// показывается только когда середина пуста, а середину занимает поиск ⌘K —
  /// то есть «Secretly» не было видно в окне НИГДЕ. На macOS заголовка окна
  /// нет и в системе: приложение опознаётся только значком в доке.
  final Widget? leading;

  final Widget? center;
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

          Padding(
            padding: EdgeInsets.fromLTRB(
              _isMacOS ? 80 : DSpace.m, // reserve for traffic lights
              0,
              _isWindows ? 0 : DSpace.m,
              0,
            ),
            child: Row(
              children: [
                // Стрелки истории — сразу за светофором, как в макете. См.
                // [DesktopNavHistory]: они настоящие, а не нарисованные.
                _NavArrow(
                  icon: FluentIcons.chevron_left_20_regular,
                  tooltip: 'Назад',
                  onTap: navBack,
                ),
                _NavArrow(
                  icon: FluentIcons.chevron_right_20_regular,
                  tooltip: 'Вперёд',
                  onTap: navForward,
                ),
                const SizedBox(width: DSpace.s),
                if (leading != null)
                  Flexible(child: leading!)
                else if (title != null && center == null)
                  Text(
                    title!,
                    style: DType.label.copyWith(color: c.textSecondary),
                  ),
                // 🔴 Поиск прижат ВПРАВО, а не по центру окна.
                //
                // По центру он вставал ровно над перепиской и читался как её
                // часть — как поиск по открытому чату, которым он не является.
                // В макете он в правой группе, рядом с кнопками окна: это
                // орудие ОКНА, а не переписки. Поиск по открытому чату в
                // шапке чата и остался, отдельной кнопкой.
                const Spacer(),
                if (center != null) center!,
                const SizedBox(width: 6),
                if (trailing != null) trailing!,
                if (_isWindows) const _WindowsControls(),
              ],
            ),
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
    return Row(
      children: [
        DesktopIconButton(
          icon: Icons.remove_rounded,
          size: 40,
          iconSize: 16,
          tooltip: 'Свернуть',
          onPressed: () => windowManager.minimize(),
        ),
        DesktopIconButton(
          icon: Icons.crop_square_rounded,
          size: 40,
          iconSize: 14,
          tooltip: 'Развернуть',
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
          tooltip: 'Закрыть',
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
const String kDesktopSearchScopeLabel = 'Чаты, люди, сообщения, файлы';

class WindowSearchEntry extends StatelessWidget {
  const WindowSearchEntry({super.key, required this.onTap, this.width = 320});

  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      builder: (ctx, hovered, pressed) => Container(
        width: width,
        height: 30,
        padding: const EdgeInsets.only(left: 9, right: 10),
        // 🔴 Заливка ПОСТОЯННАЯ, а не «подсветка при наведении».
        //
        // Поле подсвечивалось только под курсором, то есть до наведения
        // выглядело надписью, а не полем: человек не знал, что туда можно
        // нажать, пока случайно не проведёт мышью. В макете у него свой фон и
        // своя рамка всегда; наведение делает их чуть заметнее.
        decoration: BoxDecoration(
          color: hovered
              ? Colors.white.withValues(alpha: 0.09)
              : Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: Colors.white.withValues(alpha: hovered ? 0.12 : 0.07),
          ),
        ),
        child: Row(
          children: [
            Icon(
              FluentIcons.search_24_regular,
              size: 17,
              color: c.textTertiary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                kDesktopSearchScopeLabel,
                overflow: TextOverflow.ellipsis,
                style: DType.caption.copyWith(
                  fontSize: 12.5,
                  color: c.textTertiary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              // Горячая клавиша набрана моноширинным — как в макете и как
              // принято у клавиш вообще: ⌘K это не слово, а надпись на
              // клавише. См. DType.meta.
              child: Text(
                '⌘K',
                style: DType.mono.copyWith(
                  fontSize: 10,
                  color: c.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
