// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/motion.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../primitives/glass.dart';
import '../primitives/hover_listener.dart';

/// Identifiers for the built-in categories. Custom folders use their own id,
/// which is a DB row id and can never collide with these `__`-prefixed names.
class ChatCategoryIds {
  ChatCategoryIds._();

  static const String all = '__all';
  static const String unread = '__unread';
  static const String archive = '__archive';
  static const String personal = '__personal';

  /// Комнаты, группы и каналы — всё, что не личная переписка.
  ///
  /// Есть только на десктопе: на телефоне в полосе стоят «Все» и папки
  /// человека, встроенных категорий там нет вовсе. Добавка мобильной версии не
  /// касается.
  static const String groups = '__groups';

  static bool isBuiltIn(String id) => id.startsWith('__');
}

/// One chip in the category strip.
class ChatCategory {
  const ChatCategory({
    required this.id,
    required this.label,
    this.icon,
    this.emoji,
    this.badge = 0,
    this.locked = false,
  });

  final String id;
  final String label;

  /// Shown for built-in categories. Custom folders use [emoji] instead, or
  /// nothing at all — a folder named by the user needs no decoration.
  final IconData? icon;
  final String? emoji;

  /// Unread count. Zero hides the badge.
  final int badge;

  /// Personal chats sit behind a security scope. A closed padlock tells the
  /// user why tapping will ask for a password, rather than surprising them.
  final bool locked;
}

/// Horizontal category strip above the chat list.
///
/// Replaces the collapsible in-list sections the desktop used to have. Those
/// forced every group to compete for the same vertical space: with the archive
/// open you scrolled past it to reach a live chat, and "Личные"/"Группы"
/// duplicated a split the shell navigation already makes. Categories are a
/// filter, not a layout, so they belong beside the search field — one row,
/// always visible, one active at a time.
///
/// Mirrors the mobile folder strip (`_ChatsFolderTabStrip`) in behaviour and
/// order so muscle memory carries across devices, but is built from desktop
/// tokens and hover states rather than the mobile glass segments.
class ChatCategoryBar extends StatefulWidget {
  const ChatCategoryBar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    this.onContextMenu,
    this.glass = false,
  });

  final List<ChatCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelect;

  /// Right-click on a chip. Only wired for custom folders (rename / delete);
  /// null for the built-ins, which have nothing to manage.
  final void Function(ChatCategory category, Offset globalPosition)?
  onContextMenu;

  /// Папки — отдельными островками матового стекла, как у телефона. Так они
  /// стоят над списком чатов, который проезжает под ними (24.09.2026).
  ///
  /// Затухания у обрезанных краёв в этом виде нет: оно рисуется маской
  /// поверх полосы, а стекло под маской читало бы фон уже внутри маски, то
  /// есть пустоту, и становилось бы плоским.
  final bool glass;

  @override
  State<ChatCategoryBar> createState() => _ChatCategoryBarState();
}

/// Ширина затухания у обрезанного края, в точках.
const double _kFadeWidth = 24;

class _ChatCategoryBarState extends State<ChatCategoryBar> {
  final ScrollController _scroll = ScrollController();

  /// Какие края полосы «обрезаны». Обновляется без `setState`: затухание
  /// перерисовывается само, а чипы при прокрутке не трогаются вовсе.
  final ValueNotifier<_Edges> _edges = ValueNotifier<_Edges>(_Edges.none);

  /// Ключ выбранного чипа — по нему полоса подтягивает его в видимую часть.
  final GlobalKey _selectedKey = GlobalKey();

  /// 🔴 Ключ на самой полосе — чтобы она ПЕРЕЕЗЖАЛА, а не пересоздавалась.
  ///
  /// Затухание появляется и исчезает вместе с обрезанным краем, то есть
  /// [ShaderMask] то встаёт над полосой, то уходит. Для Flutter это смена
  /// формы дерева: без общего ключа поддерево размонтируется и собирается
  /// заново — вместе с [Scrollable], а значит прокрутка молча сбрасывается в
  /// ноль.
  ///
  /// Ловилось это крайне неприятно: полоса открывалась на выбранном фильтре,
  /// и в следующем же кадре уезжала обратно в начало. Глазами — «подтягивание
  /// не работает», хотя работало и тут же отменялось.
  final GlobalKey _stripKey = GlobalKey();

  /// Первый показ подкручивает полосу БЕЗ анимации: движение сразу после
  /// открытия окна читается как дёрганье, а не как подсказка.
  bool _firstReveal = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  @override
  void didUpdateWidget(covariant ChatCategoryBar old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _edges.dispose();
    super.dispose();
  }

  /// 🔴 ВЫБРАННЫЙ ФИЛЬТР ОБЯЗАН БЫТЬ ВИДЕН.
  ///
  /// Список показывает не все чаты, а срез — и единственное, что об этом
  /// сообщает, это подсвеченный чип. Уехал чип за край (а «Архив» при ширине
  /// 320 точек уезжает) — и человек видит полупустой список чатов без всякого
  /// объяснения. Это уже не косметика: интерфейс молча врёт о том, что у него
  /// внутри.
  ///
  /// Двигаем МИНИМАЛЬНО, до ближайшего края с небольшим запасом, а не в центр:
  /// прыжок полосы на пол-экрана при каждом переключении сам по себе сбивает.
  void _revealSelected() {
    if (!mounted) return;
    final ctx = _selectedKey.currentContext;
    final bar = context.findRenderObject();
    if (ctx == null || bar is! RenderBox || !_scroll.hasClients) return;
    final chip = ctx.findRenderObject();
    if (chip is! RenderBox || !chip.hasSize || !bar.hasSize) return;

    final left = chip.localToGlobal(Offset.zero, ancestor: bar).dx;
    final right = left + chip.size.width;
    final width = bar.size.width;

    double shift = 0;
    if (left < DSpace.m) {
      shift = left - DSpace.m;
    } else if (right > width - DSpace.m) {
      shift = right - (width - DSpace.m);
    }

    final wasFirst = _firstReveal;
    _firstReveal = false;
    if (shift == 0) return;

    final pos = _scroll.position;
    final target = (pos.pixels + shift).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if ((target - pos.pixels).abs() < 0.5) return;

    if (wasFirst) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: DMotion.medium,
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// 🔴 ОБЫЧНОЕ КОЛЕСО МЫШИ ДОЛЖНО ДВИГАТЬ ПОЛОСУ.
  ///
  /// Flutter отдаёт горизонтальному списку только `dx`, а колесо мыши шлёт
  /// один `dy` — без модификатора. То есть до фильтров за краем мышью было не
  /// добраться ВООБЩЕ: полоса выглядела прокручиваемой и не прокручивалась.
  /// (У трекпада свой путь — жесты приезжают отдельными событиями и обе оси
  /// там есть, поэтому сюда они не попадают.)
  ///
  /// Берём `dy` только когда `dx` пустой: иначе горизонтальный жест
  /// применился бы дважды — и рамкой, и здесь.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) return;
    if (event.scrollDelta.dx != 0) return;
    final delta = event.scrollDelta.dy;
    if (delta == 0) return;

    final pos = _scroll.position;
    final target = (pos.pixels + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (target == pos.pixels) return;
    _scroll.jumpTo(target);
  }

  /// Пересчитывает обрезанные края. Зовётся и при прокрутке, и при смене
  /// размеров — окно можно сузить, не коснувшись полосы, и затухание обязано
  /// это заметить.
  bool _syncEdges(ScrollMetrics m) {
    _edges.value = _Edges(
      start: m.extentBefore > 0.5,
      end: m.extentAfter > 0.5,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    if (widget.categories.isEmpty) return const SizedBox.shrink();

    final strip = KeyedSubtree(
      key: _stripKey,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (n) => _syncEdges(n.metrics),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => _syncEdges(n.metrics),
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: DSpace.m),
              child: Row(
                children: [
                  for (var i = 0; i < widget.categories.length; i++) ...[
                    if (i > 0) const SizedBox(width: DSpace.xs),
                    Builder(
                      builder: (ctx) {
                        final cat = widget.categories[i];
                        final selected = cat.id == widget.selectedId;
                        return _CategoryChip(
                          // Ключ только на выбранном: он один и нужен для
                          // подтягивания в видимую часть.
                          key: selected ? _selectedKey : null,
                          category: cat,
                          selected: selected,
                          colors: c,
                          glass: widget.glass,
                          onTap: () => widget.onSelect(cat.id),
                          onContextMenu: widget.onContextMenu == null
                              ? null
                              : (pos) => widget.onContextMenu!(cat, pos),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.glass) return SizedBox(height: 40, child: strip);
    return SizedBox(
      height: 40,
      child: ValueListenableBuilder<_Edges>(
        valueListenable: _edges,
        builder: (ctx, edges, child) {
          if (!edges.any) return child!;
          return ShaderMask(
            shaderCallback: (rect) {
              // Ширина затухания В ТОЧКАХ, а не в долях полосы: в долях оно
              // расползалось бы на широкой панели и съёживалось до невидимого
              // на узкой — то есть ровно там, где нужнее всего.
              final fade = rect.width <= 0 ? 0.0 : _kFadeWidth / rect.width;
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  if (edges.start) const Color(0x00FFFFFF),
                  const Color(0xFFFFFFFF),
                  const Color(0xFFFFFFFF),
                  if (edges.end) const Color(0x00FFFFFF),
                ],
                stops: <double>[
                  if (edges.start) 0.0,
                  edges.start ? fade : 0.0,
                  edges.end ? 1.0 - fade : 1.0,
                  if (edges.end) 1.0,
                ],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: child,
          );
        },
        child: strip,
      ),
    );
  }
}

/// Какие края полосы обрезаны прокруткой.
///
/// 🔴 Затухание рисуется ТОЛЬКО там, где действительно что-то скрыто.
///
/// Раньше правый край гасился всегда — в том числе когда все фильтры помещались
/// и гасить было нечего. Постоянная дымка у края читается как приглушённый,
/// недоступный элемент, то есть ровно наоборот тому, что она должна сообщать.
///
/// Левый край не гасился никогда, и прокрученная полоса обрывалась по живому:
/// человек не видел, что слева что-то осталось.
class _Edges {
  const _Edges({required this.start, required this.end});

  static const _Edges none = _Edges(start: false, end: false);

  final bool start;
  final bool end;

  bool get any => start || end;

  @override
  bool operator ==(Object other) =>
      other is _Edges && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.colors,
    required this.onTap,
    this.onContextMenu,
    this.glass = false,
  });

  final ChatCategory category;
  final bool selected;
  final DColorSet colors;
  final bool glass;
  final VoidCallback onTap;
  final void Function(Offset globalPosition)? onContextMenu;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return HoverListener(
      onTap: onTap,
      onSecondaryTapDown: onContextMenu == null
          ? null
          : (d) => onContextMenu!(d.globalPosition),
      builder: (ctx, hovered, pressed) {
        // 🔴 ВЫБРАННЫЙ ФИЛЬТР — НЕЙТРАЛЬНАЯ ПЛАШКА, А НЕ СИНЯЯ (14.09.2026).
        //
        // Было: синяя заливка, синяя обводка, синяя подпись. Синим в этом окне
        // говорят три разные вещи — акцент кнопок, выбранная строка списка и
        // своё сообщение, — и четвёртая синева над списком добавляла шума там,
        // где нужен только ответ «какой фильтр включён».
        //
        // В макете это спокойная тёмная плашка с белой подписью: выбранность
        // назвал сам факт плашки, цвет для этого не нужен.
        final Color bg = selected
            ? c.elevated
            : (pressed ? c.pressed : (hovered ? c.hover : Colors.transparent));
        final Color fg = selected ? c.textPrimary : c.textSecondary;
        if (glass) {
          // Стеклянная «таблетка»: выбранная подкрашена акцентом, наведённая —
          // чуть светлее. Подпись та же, что у обычного чипа.
          return DesktopGlass(
            radius: 15,
            grouped: true,
            tint: selected
                ? c.accentPrimary.withValues(alpha: pressed ? 0.42 : 0.34)
                : (pressed
                      ? Colors.white.withValues(alpha: 0.08)
                      : (hovered
                            ? Colors.white.withValues(alpha: 0.05)
                            : null)),
            child: SizedBox(
              height: 30,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: _chipLabel(c, selected ? Colors.white : fg),
              ),
            ),
          );
        }
        return AnimatedContainer(
          duration: DMotion.fast,
          curve: Curves.easeOutCubic,
          // 28 и радиус 9 — из макета. «Таблетка» (радиус 999) превращала
          // каждый фильтр в кнопку-капсулу, и полоса читалась как ряд кнопок,
          // а не как переключатель одного и того же списка.
          height: 28,
          // Tighter than the usual DSpace.m: four categories have to survive a
          // 300px pane, and the chip's own shape already separates them.
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: _chipLabel(c, fg),
        );
      },
    );
  }

  /// Подпись чипа — одна на оба вида, обычный и стеклянный.
  Widget _chipLabel(DColorSet c, Color fg) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (category.emoji != null && category.emoji!.isNotEmpty) ...[
        Text(category.emoji!, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: DSpace.xs),
      ],
      // 🔴 Значка у встроенного фильтра НЕТ — в макете чипы только со
      // словом. Подпись «Непрочит.» называет фильтр точнее любого
      // значка, а ряд из четырёх значков подряд превращал полосу в
      // панель инструментов. Эмодзи папки выше — исключение: это
      // метка, которую поставил сам человек.
      Text(
        category.label,
        style: TextStyle(
          fontFamily: DType.family,
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: fg,
        ),
      ),
      if (category.locked) ...[
        const SizedBox(width: DSpace.xs),
        Icon(FluentIcons.lock_closed_16_filled, size: 11, color: fg),
      ],
      if (category.badge > 0) ...[
        const SizedBox(width: DSpace.xs),
        _Badge(count: category.badge, colors: c),
      ],
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.colors});

  final int count;
  final DColorSet colors;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // 🔴 Счётчик НЕ приглушается у невыбранного чипа.
        //
        // Было наоборот: у невыбранного он гас до серого. Но смысл этого
        // счётчика ровно в том, чтобы позвать туда, где человека СЕЙЧАС нет —
        // то есть именно на невыбранный чип. Приглушённый, он звал шёпотом.
        // В макете это самый громкий элемент полосы.
        // 🔴 Красный и НЕ по типу разговора: здесь число значит «сколько
        // РАЗГОВОРОВ ждут ответа», а фильтр собирает разговоры всех типов
        // сразу. См. [DColorSet.unreadRail].
        color: colors.unreadRail,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: DType.family,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}
