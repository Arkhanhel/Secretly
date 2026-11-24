// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Нижние острова главного экрана, v3 (макет «Secretly iPhone Islands v3»,
/// 20.11.2026).
///
/// Четыре круглых острова одного размера: слева профиль и поиск, справа Чаты
/// и Комнаты.
/// * **Покой** — четыре круга.
/// * **Листание вниз** — поиск вытягивается вправо к Чатам и обнимает аватар:
///   одна капсула «профиль + поиск». Листание вверх (или край списка)
///   разделяет их обратно.
/// * **Поиск** — поле растягивается на всю ширину и встаёт над клавиатурой;
///   профиль и Чаты уходят, остров Комнат поворачивается в крестик отмены.
///
/// iPhone: все острова и капля выбранного раздела — фигуры ОДНОЙ группы
/// жидкого стекла, поэтому соседние сливаются как капли: капля выбора
/// перетекает между Чатами и Комнатами через зазор, поиск сливается с
/// профилем. Android и выключенное стекло: те же формы и движения, но
/// сплошные острова — без чтения фона под ними (дёшево на любом телефоне).
library;

import '../whats_new/pen_mark.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../icons/app_icons.dart';
import '../liquid_glass_flags.dart';
import '../motion/motion.dart';
import '../motion/press_feedback.dart';
import '../widgets/frosted_header_island.dart'
    show GlassHighlightBorderPainter, MatteIslandLook, kMatteIslandsLikeChat;
import '../widgets/app_background.dart' show AppBackground;
import '../widgets/island_backdrop.dart';

/// Выключатель на случай отката: `false` — прежняя нижняя панель.
const bool kHomeIslands = true;

/// Разделы, которые знают острова.
enum HomeTab { chats, rooms, contacts, profile }

enum HomeIslandsMode { idle, merged, search }

/// Состояние островов: режим, строка поиска, фокус.
class HomeIslandsController extends ChangeNotifier {
  HomeIslandsMode _mode = HomeIslandsMode.idle;
  HomeIslandsMode get mode => _mode;
  bool get searching => _mode == HomeIslandsMode.search;

  final TextEditingController text = TextEditingController();
  final FocusNode focus = FocusNode(debugLabel: 'home-search');

  String get query => text.text;

  double _scrollRun = 0;

  /// Открыть поиск: поле на всю ширину, клавиатура.
  void openSearch() {
    if (searching) return;
    _mode = HomeIslandsMode.search;
    _scrollRun = 0;
    HapticFeedback.mediumImpact();
    notifyListeners();
    // Фокус — после кадра: поле должно уже стоять в дереве.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (searching) focus.requestFocus();
    });
  }

  /// Закрыть поиск: крестик на месте Комнат, «Назад», выбор результата.
  void closeSearch({bool haptic = true}) {
    if (!searching) return;
    text.clear();
    focus.unfocus();
    _mode = HomeIslandsMode.idle;
    _scrollRun = 0;
    if (haptic) HapticFeedback.lightImpact();
    notifyListeners();
  }

  /// Вернуть острова в покой (смена раздела).
  void resetToIdle() {
    if (_mode != HomeIslandsMode.merged) return;
    _mode = HomeIslandsMode.idle;
    _scrollRun = 0;
    notifyListeners();
  }

  /// Листание любого вертикального списка в разделах: вниз — слить поиск с
  /// профилем, вверх или край — разделить. Порог — чтобы дрожь пальца не
  /// дёргала острова.
  void handleScroll(ScrollNotification n) {
    if (searching) return;
    if (n.metrics.axis != Axis.vertical) return;
    if (n is! ScrollUpdateNotification) return;
    final dy = n.scrollDelta ?? 0;
    if (dy == 0) return;
    final fromTop = n.metrics.pixels - n.metrics.minScrollExtent;
    if (_scrollRun.sign != dy.sign) _scrollRun = 0;
    _scrollRun += dy;
    if (_mode == HomeIslandsMode.idle && _scrollRun > 14 && fromTop > 12) {
      _mode = HomeIslandsMode.merged;
      HapticFeedback.selectionClick();
      notifyListeners();
    } else if (_mode == HomeIslandsMode.merged &&
        (_scrollRun < -14 || fromTop <= 2)) {
      _mode = HomeIslandsMode.idle;
      HapticFeedback.selectionClick();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }
}

/// Геометрия островов для ширины [width] (макет v4, вариант 5C «Тумблер
/// разделов»). Отдельно, чтобы тест проверял раскладку на любом экране.
///
/// 393 pt: профиль 16·58, поиск 84·58, переключатель Чаты|Комнаты 213·164
/// высотой 62 с ползунком 77×52. Листание: поиск 16…203 (аватар внутри).
/// Поиск: поле 16…309, переключатель сжат в крестик 315·62.
@immutable
class HomeIslandsGeometry {
  factory HomeIslandsGeometry.forWidth(double width) {
    // Узкий экран сжимает острова, но не меньше 48 (палец); широкий не
    // раздувает больше 62.
    final size = (width * 58 / 393).clamp(48.0, 62.0);
    final margin = (width * 16 / 393).clamp(12.0, 20.0);
    final gap = (size * 10 / 58).clamp(8.0, 12.0);
    return HomeIslandsGeometry._(width, size, margin, gap);
  }

  const HomeIslandsGeometry._(this.width, this.size, this.margin, this.gap);

  final double width;

  /// Круги профиля и поиска.
  final double size;
  final double margin;
  final double gap;

  /// Высота ряда: переключатель на 4 pt выше кругов.
  double get rowHeight => size + 6;
  double get tabsHeight => size + 4;
  double get knobWidth => size * 77 / 58;
  double get knobHeight => size - 6;
  double get knobInset => (tabsHeight - knobHeight) / 2;
  double get tabsWidth => knobWidth * 2 + knobInset * 2;
  double get tabsLeft => width - margin - tabsWidth;
  double get chatsKnobLeft => tabsLeft + knobInset;
  double get roomsKnobLeft => chatsKnobLeft + knobWidth;

  double get profileLeft => margin;
  double get searchIdleLeft => margin + size + gap;

  /// Слияние: поиск забирает профиль и доходит до переключателя.
  double get mergedWidth => tabsLeft - gap - margin;

  /// Поиск: переключатель сжат в круг крестика у правого края.
  double get cancelLeft => width - margin - tabsHeight;
  double get searchWidth => cancelLeft - gap * 0.6 - margin;
}

/// Нижние острова. Собственных данных не держат: всё приходит параметрами.
class HomeBottomIslands extends StatefulWidget {
  const HomeBottomIslands({
    super.key,
    required this.controller,
    required this.tab,
    required this.onSelect,
    required this.avatar,
    required this.searchHint,
    required this.glass,
    this.avatarFrame,
    this.pagePosition,
    this.chatsBadge = 0,
    this.roomsBadge = 0,
    this.roomLive = false,
    this.onSubmitSearch,
    this.labels = const HomeIslandsLabels(),
  });

  final HomeIslandsController controller;
  final HomeTab tab;
  final ValueChanged<HomeTab> onSelect;

  /// Положение ряда Чаты ↔ Комнаты: 0 — Чаты, 1 — Комнаты, дробное — палец
  /// посреди свайпа (`TabController.animation`). Ползунок едет ЗА ПАЛЬЦЕМ.
  final ValueListenable<double>? pagePosition;

  /// Портрет в острове профиля (заполняет переданный круг).
  final Widget avatar;

  /// Рамка профиля (украшение): рисуется в полный размер и выходит за
  /// остров. `null` — без рамки.
  final Widget Function(double size)? avatarFrame;
  final String searchHint;

  /// Жидкое стекло (iPhone) или матовые острова (Android, стекло выключено).
  final bool glass;
  final int chatsBadge;
  final int roomsBadge;

  /// В комнате идёт звонок — зелёная точка на Комнатах.
  final bool roomLive;
  final VoidCallback? onSubmitSearch;
  final HomeIslandsLabels labels;

  @override
  State<HomeBottomIslands> createState() => _HomeBottomIslandsState();
}

/// Подписи разделов и подсказки для читалки экрана.
class HomeIslandsLabels {
  const HomeIslandsLabels({
    this.profile = 'Profile',
    this.search = 'Search',
    this.chats = 'Chats',
    this.rooms = 'Rooms',
    this.cancel = 'Cancel',
    this.clear = 'Clear',
  });

  final String profile;
  final String search;
  final String chats;
  final String rooms;
  final String cancel;
  final String clear;
}

class _HomeBottomIslandsState extends State<HomeBottomIslands>
    with SingleTickerProviderStateMixin {
  // Своя анимация ползунка — когда оболочка не дала положение ряда.
  late final AnimationController _pos = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
    value: widget.tab == HomeTab.rooms ? 1 : 0,
  );

  static const Curve _shapeCurve = Cubic(0.32, 1.12, 0.45, 1.0);
  static const Curve _popCurve = Cubic(0.3, 1.3, 0.5, 1.0);
  static const Duration _shapeDur = Duration(milliseconds: 550);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.pagePosition?.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant HomeBottomIslands old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    if (old.pagePosition != widget.pagePosition) {
      old.pagePosition?.removeListener(_onChanged);
      widget.pagePosition?.addListener(_onChanged);
    }
    if (old.tab != widget.tab && widget.pagePosition == null) {
      if (widget.tab == HomeTab.chats || widget.tab == HomeTab.rooms) {
        final target = widget.tab == HomeTab.rooms ? 1.0 : 0.0;
        if (motionReduced(context)) {
          _pos.value = target;
        } else {
          _pos.animateTo(target, curve: Motion.standard);
        }
      }
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.pagePosition?.removeListener(_onChanged);
    _pos.dispose();
    super.dispose();
  }

  void _select(HomeTab tab) {
    if (tab != widget.tab) HapticFeedback.selectionClick();
    widget.onSelect(tab);
  }

  double get _position =>
      (widget.pagePosition?.value ?? _pos.value).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final mode = widget.controller.mode;
    final search = mode == HomeIslandsMode.search;
    final merged = mode == HomeIslandsMode.merged;
    final reduce = motionReduced(context);
    final shapeDur = reduce ? Duration.zero : _shapeDur;
    final popDur = reduce ? Duration.zero : const Duration(milliseconds: 450);
    final fadeDur = reduce ? Duration.zero : const Duration(milliseconds: 280);
    final palette = _IslandPalette.of(context, glass: widget.glass);

    return AnimatedBuilder(
      animation: _pos,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final g = HomeIslandsGeometry.forWidth(constraints.maxWidth);
          final s = g.size;
          final rowH = g.rowHeight;
          final pos = _position;
          final tabsTab =
              widget.tab == HomeTab.chats || widget.tab == HomeTab.rooms;

          /// Остров: подложка по геометрии; спрятанный — сжат в точку
          /// (стекло не видит прозрачности виджета).
          Widget island({
            required Key key,
            required double left,
            required double width,
            required double height,
            Widget child = const SizedBox.expand(),
            bool visible = true,
          }) {
            final cx = left + width / 2;
            return AnimatedPositioned(
              key: key,
              duration: shapeDur,
              curve: _shapeCurve,
              left: visible ? left : cx,
              width: visible ? width : 0,
              bottom: visible ? (rowH - height) / 2 : rowH / 2,
              height: visible ? height : 0,
              child: _IslandSurface(
                glass: widget.glass,
                palette: palette,
                radius: height / 2,
                child: child,
              ),
            );
          }

          final searchLeft = search || merged ? g.margin : g.searchIdleLeft;
          final searchWidth = search
              ? g.searchWidth
              : (merged ? g.mergedWidth : s);

          // ── Ползунок переключателя ───────────────────────────────────────
          // Форма — капсула 77×52, в полёте вытягивается и чуть сплющивается,
          // как капля. Сам ползунок — жидкое стекло (iPhone) или матовая
          // подложка (Android), не цветной: выбор несут значок и подпись.
          final knobVisible = tabsTab && !search;
          Widget knob() => TweenAnimationBuilder<double>(
            tween: Tween<double>(end: knobVisible ? 1 : 0),
            duration: popDur,
            curve: knobVisible ? _popCurve : Curves.easeInCubic,
            builder: (context, vis, _) {
              final kw = g.knobWidth, kh = g.knobHeight;
              final x0 = g.chatsKnobLeft, x1 = g.roomsKnobLeft;
              final cx = x0 + (x1 - x0) * pos + kw / 2;
              final stretch = math.sin(math.pi * pos);
              final w = (kw + stretch * kw * 0.28) * vis;
              final h = (kh - stretch * 6) * vis;
              if (w <= 0.5 || h <= 0.5) return const SizedBox.shrink();
              final moving = pos > 0.002 && pos < 0.998;
              return Positioned(
                left: cx - w / 2,
                bottom: (rowH - h) / 2,
                width: w,
                height: h,
                child: IgnorePointer(
                  child: _GlassDrop(
                    glass: widget.glass,
                    moving: moving,
                    palette: palette,
                    radius: h / 2,
                  ),
                ),
              );
            },
          );

          // Насколько ползунок под разделом: значок и подпись светлеют за ним.
          final chatsOn = !search && tabsTab ? 1 - pos : 0.0;
          final roomsOn = !search && tabsTab ? pos : 0.0;
          Color tint(double on) =>
              Color.lerp(palette.icon, palette.active, on.clamp(0.0, 1.0))!;

          Widget tabSlot({
            required Key key,
            required double left,
            required bool visible,
            required Widget child,
          }) => AnimatedPositioned(
            key: key,
            duration: shapeDur,
            curve: _shapeCurve,
            left: left,
            width: g.knobWidth,
            bottom: (rowH - g.knobHeight) / 2,
            height: g.knobHeight,
            child: IgnorePointer(
              ignoring: !visible,
              child: AnimatedOpacity(
                duration: fadeDur,
                opacity: visible ? 1 : 0,
                child: AnimatedScale(
                  duration: popDur,
                  curve: _popCurve,
                  scale: visible ? 1 : 0.4,
                  child: child,
                ),
              ),
            ),
          );

          final islands = Stack(
            clipBehavior: Clip.none,
            children: [
              // Стекло профиля — фигурой (в поиске и слиянии сжимается).
              island(
                key: const ValueKey('island-profile-glass'),
                left: g.profileLeft,
                width: s,
                height: s,
                visible: !search && !merged,
              ),
              island(
                key: const ValueKey('island-search'),
                left: searchLeft,
                width: searchWidth,
                height: s,
                child: _SearchContent(
                  controller: widget.controller,
                  hint: widget.searchHint,
                  merged: merged,
                  search: search,
                  size: s,
                  palette: palette,
                  labels: widget.labels,
                  onOpen: widget.controller.openSearch,
                  onSubmit: widget.onSubmitSearch,
                  duration: shapeDur,
                  fade: fadeDur,
                ),
              ),
              // Переключатель Чаты|Комнаты; в поиске — круг крестика.
              island(
                key: const ValueKey('island-tabs'),
                left: search ? g.cancelLeft : g.tabsLeft,
                width: search ? g.tabsHeight : g.tabsWidth,
                height: g.tabsHeight,
              ),
              knob(),
              tabSlot(
                key: const ValueKey('tab-chats'),
                left: g.chatsKnobLeft,
                visible: !search,
                child: _TabButton(
                  semantics: widget.labels.chats,
                  label: widget.labels.chats,
                  selected: widget.tab == HomeTab.chats,
                  icon: AppIcons.chatsFilled,
                  color: tint(chatsOn),
                  badge: widget.chatsBadge,
                  palette: palette,
                  onTap: () => _select(HomeTab.chats),
                ),
              ),
              tabSlot(
                key: const ValueKey('tab-rooms'),
                left: search
                    ? g.cancelLeft + (g.tabsHeight - g.knobWidth) / 2
                    : g.roomsKnobLeft,
                visible: true,
                child: _TabButton(
                  semantics: search
                      ? widget.labels.cancel
                      : widget.labels.rooms,
                  label: widget.labels.rooms,
                  selected: widget.tab == HomeTab.rooms,
                  icon: AppIcons.groupsFilled,
                  color: tint(roomsOn),
                  badge: search ? 0 : widget.roomsBadge,
                  live: widget.roomLive && !search,
                  cancel: search,
                  duration: popDur,
                  fade: fadeDur,
                  palette: palette,
                  onTap: search
                      ? widget.controller.closeSearch
                      : () => _select(HomeTab.rooms),
                ),
              ),
              // Профиль — поверх капсулы поиска (в слиянии аватар внутри неё).
              AnimatedPositioned(
                key: const ValueKey('island-profile'),
                duration: shapeDur,
                curve: _shapeCurve,
                left: g.profileLeft,
                bottom: (rowH - s) / 2,
                width: s,
                height: s,
                child: AnimatedOpacity(
                  duration: fadeDur,
                  opacity: search ? 0 : 1,
                  child: AnimatedSlide(
                    duration: popDur,
                    curve: _popCurve,
                    offset: search ? const Offset(-0.5, 0) : Offset.zero,
                    child: AnimatedScale(
                      duration: popDur,
                      curve: _popCurve,
                      scale: search ? 0.4 : 1,
                      child: IgnorePointer(
                        ignoring: search,
                        child: _ProfileButton(
                          semantics: widget.labels.profile,
                          palette: palette,
                          merged: merged,
                          active: widget.tab == HomeTab.profile,
                          avatar: widget.avatar,
                          frame: widget.avatarFrame,
                          size: s,
                          onTap: () => _select(HomeTab.profile),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

          final body = SizedBox(
            // Сверху место под значки и рамку профиля, выходящую за остров.
            height: rowH + 12,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: islands,
            ),
          );
          if (!widget.glass) {
            // Матовые острова Android: ОДИН снимок фона на все острова
            // (BackdropGroup), а не по снимку на каждый.
            return BackdropGroup(child: body);
          }
          return AdaptiveLiquidGlassLayer(
            settings: secretlyIslandGlass(Theme.of(context).brightness),
            quality: GlassQuality.premium,
            // Порог слияния меньше зазора в покое — иначе острова слиплись бы.
            blendAmount: g.gap * 0.9,
            clipExpansion: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 18,
            ),
            child: body,
          );
        },
      ),
    );
  }
}

/// Цвета островов от темы.
class _IslandPalette {
  const _IslandPalette({
    required this.fill,
    required this.icon,
    required this.ink,
    required this.active,
    required this.hint,
    required this.ring,
    required this.highlight,
    required this.dropFill,
    required this.frosted,
    required this.dark,
  });

  factory _IslandPalette.of(BuildContext context, {required bool glass}) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final frosted = !glass && PanelPrefs.frostedEnabled.value;
    final Color fill;
    if (glass) {
      // Над жидким стеклом — лёгкая вуаль.
      fill = dark ? const Color(0x33242A36) : const Color(0x8CFFFFFF);
    } else if (frosted) {
      // Матовое стекло Android: размытие фона + вуаль, как у прежней панели.
      fill = MatteIslandLook.flatFill(dark);
    } else {
      // «Матовые панели» выключены — сплошная пластина.
      fill = opaquePanelFill(context);
    }
    final ink = dark ? const Color(0xFFF2F3F5) : const Color(0xFF14161A);
    // Серый акцент («Графит»): выбранный — полной яркости, остальные
    // приглушены. Цветной акцент — выбранный в цвет акцента.
    final greyAccent = HSLColor.fromColor(cs.primary).saturation < 0.18;
    return _IslandPalette(
      fill: fill,
      icon: ink.withValues(alpha: greyAccent ? 0.55 : 0.78),
      ink: ink,
      active: greyAccent ? ink : cs.primary,
      hint: dark ? const Color(0x80EBEEF5) : const Color(0x8C3C3C43),
      // Обводка счётчика — цвет самого островка поверх страницы (разбор
      // 22.11.2026): scaffoldBackgroundColor в приложении прозрачный, и
      // запасной серый не совпадал ни со стеклом, ни с матовым островом.
      ring: Color.alphaBlend(fill, AppBackground.scrimColorOf(context)),
      // Матовые (Android) — кант как у островков в чате; над стеклом — прежний.
      highlight: frosted
          ? MatteIslandLook.highlight(dark)
          : dark
          ? Colors.white.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.6),
      dropFill: dark ? const Color(0x29FFFFFF) : const Color(0x17000000),
      frosted: frosted,
      dark: dark,
    );
  }

  final Color fill;

  /// Значки невыбранных разделов.
  final Color icon;

  /// Полная яркость: лупа, крестик, текст поля.
  final Color ink;

  /// Значок и подпись выбранного раздела.
  final Color active;
  final Color hint;
  final Color ring;
  final Color highlight;

  /// Ползунок без стекла: нейтральная подложка, не цветная.
  final Color dropFill;
  final bool frosted;
  final bool dark;
}

/// Подложка острова: фигура жидкого стекла в общей группе (iPhone), матовое
/// стекло (Android) или сплошная пластина («Матовые панели» выключены).
class _IslandSurface extends StatelessWidget {
  const _IslandSurface({
    required this.glass,
    required this.palette,
    required this.radius,
    required this.child,
  });

  final bool glass;
  final _IslandPalette palette;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    if (glass) {
      return Stack(
        fit: StackFit.expand,
        children: [
          AdaptiveGlass.grouped(
            shape: LiquidRoundedSuperellipse(borderRadius: radius),
            quality: GlassQuality.premium,
            child: const SizedBox.expand(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(color: palette.fill, borderRadius: r),
            child: child,
          ),
        ],
      );
    }
    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: palette.dark ? 0.28 : 0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    );
    final plate = CustomPaint(
      foregroundPainter: palette.frosted
          ? GlassHighlightBorderPainter(
              radius: radius,
              strokeWidth: 1.1,
              color: palette.highlight,
            )
          : null,
      child: DecoratedBox(
        decoration: BoxDecoration(color: palette.fill, borderRadius: r),
        child: child,
      ),
    );
    // Матовые в тёмной теме — без тени, как островки в чате (23.11.2026).
    final noShadow = kMatteIslandsLikeChat && palette.frosted && palette.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: noShadow ? null : [shadow],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: palette.frosted
            ? BackdropFilter.grouped(
                filter: islandBackdropFilter(sigmaX: 22, sigmaY: 22),
                child: plate,
              )
            : plate,
      ),
    );
  }
}

/// Ползунок переключателя: линза жидкого стекла поверх островка (iPhone) —
/// в покое плоская, в движении преломляет; на Android — матовая подложка.
class _GlassDrop extends StatelessWidget {
  const _GlassDrop({
    required this.glass,
    required this.moving,
    required this.palette,
    required this.radius,
  });

  final bool glass;
  final bool moving;
  final _IslandPalette palette;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (!glass) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: palette.dropFill,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: palette.highlight, width: 0.6),
        ),
      );
    }
    final b = Theme.of(context).brightness;
    return AdaptiveGlass(
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      settings: moving ? secretlyIslandGlass(b) : secretlyIslandLensFlat(b),
      quality: GlassQuality.premium,
      useOwnLayer: true,
      child: const SizedBox.expand(),
    );
  }
}

/// Половина переключателя: значок и подпись под ним; на Комнатах в поиске —
/// крестик отмены.
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.semantics,
    required this.label,
    required this.selected,
    required this.icon,
    required this.color,
    required this.badge,
    required this.palette,
    required this.onTap,
    this.live = false,
    this.cancel = false,
    this.duration = const Duration(milliseconds: 450),
    this.fade = const Duration(milliseconds: 280),
  });

  final String semantics;
  final String label;
  final bool selected;
  final IconData icon;
  final Color color;
  final int badge;
  final _IslandPalette palette;
  final VoidCallback onTap;
  final bool live;
  final bool cancel;
  final Duration duration;
  final Duration fade;

  @override
  Widget build(BuildContext context) {
    const turn = Cubic(0.3, 1.4, 0.5, 1.0);
    // Подпись не растёт с крупным шрифтом выше 1,2 — ползунок фиксирован.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2);
    return Semantics(
      button: true,
      selected: selected && !cancel,
      label: semantics,
      child: PressFeedback(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Center(
                child: AnimatedOpacity(
                  duration: fade,
                  opacity: cancel ? 0 : 1,
                  child: AnimatedRotation(
                    duration: duration,
                    curve: turn,
                    turns: cancel ? -0.25 : 0,
                    child: AnimatedScale(
                      duration: duration,
                      curve: turn,
                      scale: cancel ? 0.4 : 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 21, color: color),
                          const SizedBox(height: 3),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            textScaler: scaler,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: color,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: AnimatedOpacity(
                  duration: fade,
                  opacity: cancel ? 1 : 0,
                  child: AnimatedRotation(
                    duration: duration,
                    curve: turn,
                    turns: cancel ? 0 : 0.25,
                    child: AnimatedScale(
                      duration: duration,
                      curve: turn,
                      scale: cancel ? 1 : 0.4,
                      child: Icon(AppIcons.close, size: 21, color: palette.ink),
                    ),
                  ),
                ),
              ),
              // Счётчик непрочитанного — всегда, и на выбранном разделе тоже.
              if (badge > 0)
                Positioned(
                  top: 2,
                  right: 6,
                  child: _Badge(count: badge, ring: palette.ring),
                ),
              if (live)
                Positioned(
                  bottom: 3,
                  right: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3DD68C),
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.ring, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.semantics,
    required this.palette,
    required this.merged,
    required this.active,
    required this.avatar,
    required this.frame,
    required this.size,
    required this.onTap,
  });

  final String semantics;
  final _IslandPalette palette;
  final bool merged;
  final bool active;
  final Widget avatar;
  final Widget Function(double size)? frame;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // С рамкой: портрет почти во весь остров, рамка — в полный размер
    // поверх (как в карточке контакта: фото ≈ 0,86 рамки), её сияние и
    // украшения выходят за остров. Без рамки — портрет с полями.
    final hasFrame = frame != null;
    final frameSize = size * 1.16;
    final avatarD = hasFrame ? frameSize * 0.86 : size - (merged ? 12 : 10);
    return Semantics(
      button: true,
      selected: active,
      label: semantics,
      child: PressFeedback(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: avatarD,
                height: avatarD,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: active && !hasFrame
                      ? [BoxShadow(color: palette.active, spreadRadius: 2.5)]
                      : const <BoxShadow>[],
                ),
                child: ClipOval(child: avatar),
              ),
              if (hasFrame)
                Positioned(
                  left: (size - frameSize) / 2,
                  top: (size - frameSize) / 2,
                  width: frameSize,
                  height: frameSize,
                  child: IgnorePointer(child: frame!(frameSize)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Содержимое капсулы поиска во всех трёх видах.
class _SearchContent extends StatelessWidget {
  const _SearchContent({
    required this.controller,
    required this.hint,
    required this.merged,
    required this.search,
    required this.size,
    required this.palette,
    required this.labels,
    required this.onOpen,
    required this.onSubmit,
    required this.duration,
    required this.fade,
  });

  final HomeIslandsController controller;
  final String hint;
  final bool merged;
  final bool search;
  final double size;
  final _IslandPalette palette;
  final HomeIslandsLabels labels;
  final VoidCallback onOpen;
  final VoidCallback? onSubmit;
  final Duration duration;
  final Duration fade;

  @override
  Widget build(BuildContext context) {
    // Положение значка лупы: в круге — по центру, в слиянии — правее аватара,
    // в поле — у левого края.
    final iconLeft = search
        ? 18.0
        : (merged ? size + 6 : (size - 21) / 2);
    final textLeft = size + 33;
    final textStyle = TextStyle(
      fontSize: 15.5,
      color: palette.hint,
      fontWeight: FontWeight.w400,
    );
    // Пока поиск закрыт, капсула — КНОПКА «Поиск» (касание открывает
    // поле), а не текстовое поле: диктор читал «текстовое поле», и внутри
    // было ещё одно (разбор 22.11.2026).
    // «Что нового 1.9»: перо вокруг лупы — «Поиск по нику и контактам».
    return PenMark(
      hint: PenHint.search,
      round: true,
      enabled: !search,
      child: Semantics(
      button: !search,
      textField: search ? null : false,
      label: labels.search,
      onTap: search ? null : onOpen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: search ? null : onOpen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: const Cubic(0.32, 1.12, 0.45, 1.0),
                left: iconLeft,
                top: (size - 21) / 2,
                width: 21,
                height: 21,
                child: Icon(
                  AppIcons.search,
                  size: 21,
                  color: search ? palette.hint : palette.ink,
                ),
              ),
              // Подсказка в слиянии: «Поиск по чатам».
              Positioned(
                left: textLeft,
                top: 0,
                bottom: 0,
                right: 8,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: fade,
                    opacity: merged ? 1 : 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      // В слиянии — короткое «Поиск» (макет v4): полная
                      // подсказка живёт в поле ввода.
                      child: Text(
                        labels.search,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: textStyle,
                      ),
                    ),
                  ),
                ),
              ),
              // Поле ввода — только в поиске.
              Positioned(
                left: 48,
                right: 44,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !search,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: search ? 1 : 0,
                    child: Center(
                      child: TextField(
                        controller: controller.text,
                        focusNode: controller.focus,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => onSubmit?.call(),
                        style: TextStyle(fontSize: 17, color: palette.ink),
                        cursorColor: palette.active,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: hint,
                          hintStyle: textStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Очистить строку.
              Positioned(
                right: 12,
                top: (size - 28) / 2,
                width: 28,
                height: 28,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller.text,
                  builder: (context, value, _) {
                    final show = search && value.text.isNotEmpty;
                    return IgnorePointer(
                      ignoring: !show,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: show ? 1 : 0,
                        child: Semantics(
                          button: true,
                          label: labels.clear,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              controller.text.clear();
                              controller.focus.requestFocus();
                            },
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette.ink.withValues(alpha: 0.16),
                              ),
                              child: Icon(
                                AppIcons.close,
                                size: 13,
                                color: palette.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.ring});

  final int count;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 21),
      height: 21,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5A5F),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: ring, width: 2.5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        // Капсула 21: цифры растут не больше 1,3× при крупном шрифте.
        textScaler: MediaQuery.textScalerOf(context).clamp(
          maxScaleFactor: 1.3,
        ),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
