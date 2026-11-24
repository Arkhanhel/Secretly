// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Панель «Эмодзи, стикеры, GIF» на месте клавиатуры — макет 2a владельца
/// (22.11.2026), iPhone и Android.
///
///  * Высота = высота клавиатуры: ☺ ⇄ ⌨ без прыжка ленты
///    ([EmojiPanelController]). Ручка сверху раскрывает выше.
///  * Сетка идёт до самого низа экрана; внизу поверх неё — отдельные
///    островки своим стеклом: разделы «Эмодзи / Стикеры / GIF» с бегунком и
///    «стереть» (правка владельца 22.11.2026 после сборки 719).
///  * Сверху — рейка разделов текущей страницы (подсветка едет за
///    прокруткой) и лупа справа: поиск выдвигается на место рейки.
///  * Три страницы листаются вбок (и пальцем).
///  * iPhone: размытие фона панели + одно общее у островков; Android —
///    матовое стекло.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../stickers/sticker_catalog.dart';
import '../../icons/adaptive_icons.dart';
import 'emoji_panel_controller.dart';
import 'emoji_panel_emoji.dart';
import 'emoji_panel_gifs.dart';
import 'emoji_panel_sources.dart';
import 'emoji_panel_stickers.dart';
import 'emoji_panel_style.dart';
import 'emoji_panel_widgets.dart';

export 'emoji_panel_controller.dart'
    show EmojiPanelController, kInlineEmojiPanel;
export 'emoji_panel_emoji.dart' show EmojiPanelCategory;
export 'emoji_panel_sources.dart'
    show
        AppControllerStickerSource,
        EmojiPanelGifSource,
        EmojiPanelStickerSource,
        GiphyPanelGifSource;

// ─── Правка поля ввода ──────────────────────────────────────────────────────

/// Вставить [value] на место курсора (или выделения), курсор — после.
/// Фокус не трогаем: клавиатура не должна выскочить поверх панели.
void emojiPanelInsertText(TextEditingController c, String value) {
  final v = c.value;
  final text = v.text;
  final sel = v.selection;
  final start = sel.isValid
      ? math.min(sel.start, sel.end).clamp(0, text.length)
      : text.length;
  final end = sel.isValid
      ? math.max(sel.start, sel.end).clamp(0, text.length)
      : text.length;
  c.value = TextEditingValue(
    text: text.replaceRange(start, end, value),
    selection: TextSelection.collapsed(offset: start + value.length),
  );
}

/// «Стереть»: выделение целиком или один символ (графема — эмодзи с тоном и
/// флаг стираются целиком) перед курсором.
void emojiPanelBackspace(TextEditingController c) {
  final v = c.value;
  final text = v.text;
  if (text.isEmpty) return;
  final sel = v.selection;
  var start = sel.isValid ? math.min(sel.start, sel.end) : text.length;
  var end = sel.isValid ? math.max(sel.start, sel.end) : text.length;
  start = start.clamp(0, text.length);
  end = end.clamp(0, text.length);
  if (start != end) {
    c.value = TextEditingValue(
      text: text.replaceRange(start, end, ''),
      selection: TextSelection.collapsed(offset: start),
    );
    return;
  }
  if (end == 0) return;
  final before = text.substring(0, end).characters;
  final kept = before.skipLast(1).toString();
  c.value = TextEditingValue(
    text: kept + text.substring(end),
    selection: TextSelection.collapsed(offset: kept.length),
  );
}

// ─── Панель ─────────────────────────────────────────────────────────────────

class EmojiPanel extends StatefulWidget {
  const EmojiPanel({
    super.key,
    required this.controller,
    required this.textController,
    required this.categories,
    required this.stickerSource,
    required this.gifSource,
    required this.profileKey,
    required this.onSendSticker,
    required this.onSendGif,
    required this.frosted,
    required this.solidFill,
    this.onCreateSticker,
    this.composerRect,
    this.ios,
  });

  final EmojiPanelController controller;

  /// Поле ввода сообщения: эмодзи вставляются в него, «стереть» стирает.
  final TextEditingController textController;
  final List<EmojiPanelCategory> categories;
  final EmojiPanelStickerSource stickerSource;
  final EmojiPanelGifSource gifSource;

  /// Чьи недавние эмодзи и тона (профиль).
  final String profileKey;
  final ValueChanged<SecretlyStickerDescriptor> onSendSticker;
  final ValueChanged<String> onSendGif;

  /// «Создать стикер»; [targetPackId] — «+» в окне своего набора. `null` —
  /// клетки «Создать» нет.
  final void Function({String? targetPackId})? onCreateSticker;

  /// Где поле ввода (для полёта эмодзи и стикера).
  final Rect? Function()? composerRect;

  /// «Размытие панелей».
  final bool frosted;
  final Color solidFill;

  /// Для тестов: оформление iPhone / Android независимо от платформы.
  final bool? ios;

  @override
  State<EmojiPanel> createState() => EmojiPanelState();
}

class EmojiPanelState extends State<EmojiPanel>
    with SingleTickerProviderStateMixin {
  late final EmojiTabModel _emoji = EmojiTabModel(
    categories: widget.categories,
    profileKey: widget.profileKey,
  );
  late final StickerTabModel _stickers = StickerTabModel(
    source: widget.stickerSource,
    canCreate: widget.onCreateSticker != null,
  );
  late final GifTabModel _gifs = GifTabModel(source: widget.gifSource);
  late final PageController _pages = PageController(
    initialPage: widget.controller.tab.value,
  );
  final GlobalKey<StickerGridPageState> _stickerPage = GlobalKey();
  bool _programmatic = false;
  Timer? _repeat;

  /// Поиск в верхней строке: выдвигается от значка лупы (пружина 420 мс),
  /// задвигается быстрее (300 мс).
  late final AnimationController _searchAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 300),
  );
  late final CurvedAnimation _searchCurve = CurvedAnimation(
    parent: _searchAnim,
    curve: kPanelTrackCurve,
    reverseCurve: Curves.easeOutCubic,
  );
  final ValueNotifier<bool> _searchOpen = ValueNotifier<bool>(false);

  /// В каком разделе открыт поиск (у каждого своё поле и свой запрос).
  int _searchTab = 0;

  EmojiPanelController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addFlusher(_emoji.flush);
    for (final f in [_emoji.searchFocus, _stickers.searchFocus, _gifs.searchFocus]) {
      f.addListener(_onSearchFocus);
    }
    _c.tab.addListener(_onTab);
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _c.removeFlusher(_emoji.flush);
    _c.tab.removeListener(_onTab);
    for (final f in [_emoji.searchFocus, _stickers.searchFocus, _gifs.searchFocus]) {
      f.removeListener(_onSearchFocus);
    }
    _searchCurve.dispose();
    _searchAnim.dispose();
    _searchOpen.dispose();
    _emoji.dispose();
    _stickers.dispose();
    _gifs.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _onSearchFocus() {
    final any =
        _emoji.searchFocus.hasFocus ||
        _stickers.searchFocus.hasFocus ||
        _gifs.searchFocus.hasFocus;
    _c.setSearchFocused(any);
  }

  /// Раздел сменили снаружи (или кнопкой) — страницы едут следом; поиск
  /// прежнего раздела закрывается.
  void _onTab() {
    final t = _c.tab.value;
    if (_searchOpen.value && t != _searchTab) _closeSearch();
    if (!_pages.hasClients) return;
    final cur = _pages.page?.round() ?? t;
    if (cur == t) return;
    _programmatic = true;
    _pages
        .animateToPage(
          t,
          duration: const Duration(milliseconds: 500),
          curve: kPanelTrackCurve,
        )
        .whenComplete(() => _programmatic = false);
  }

  void _selectTab(int i) {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    _c.selectTab(i);
  }

  // ── Поиск ──

  ({
    TextEditingController text,
    FocusNode focus,
    ValueChanged<String> onChanged,
    ScrollController scroll,
  })
  _searchOf(int tab) => switch (tab) {
    0 => (
      text: _emoji.search,
      focus: _emoji.searchFocus,
      onChanged: _emoji.setQuery,
      scroll: _emoji.scroll,
    ),
    1 => (
      text: _stickers.search,
      focus: _stickers.searchFocus,
      onChanged: _stickers.setQuery,
      scroll: _stickers.scroll,
    ),
    _ => (
      text: _gifs.search,
      focus: _gifs.searchFocus,
      onChanged: _gifs.onQueryChanged,
      scroll: _gifs.scroll,
    ),
  };

  /// Лупа справа от рейки: рейка уезжает, поиск выдвигается, фокус в поле.
  void _openSearch() {
    HapticFeedback.selectionClick();
    _searchTab = _c.tab.value;
    final s = _searchOf(_searchTab);
    if (s.scroll.hasClients) {
      s.scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    _searchOpen.value = true;
    _searchAnim.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _searchOpen.value) s.focus.requestFocus();
    });
  }

  /// «Назад» в поиске (или смена раздела): запрос стирается, рейка
  /// возвращается.
  void _closeSearch() {
    if (!_searchOpen.value) return;
    final s = _searchOf(_searchTab);
    if (s.text.text.isNotEmpty) {
      s.text.clear();
      s.onChanged('');
    }
    if (s.focus.hasFocus) s.focus.unfocus();
    _searchOpen.value = false;
    _searchAnim.reverse();
  }

  // ── Действия ──

  Offset? _fieldTarget() {
    final r = widget.composerRect?.call();
    if (r == null) return null;
    final ios = widget.ios ?? _c.ios;
    return Offset(r.right - (ios ? 84 : 90), r.bottom - (ios ? 30 : 32));
  }

  void _pickEmoji(String emoji, Rect from) {
    HapticFeedback.selectionClick();
    emojiPanelInsertText(widget.textController, emoji);
    final to = _fieldTarget();
    if (to != null && from != Rect.zero) {
      launchPanelFlight(
        context: context,
        from: from,
        to: to,
        child: PanelEmojiGlyph(emoji: emoji),
      );
    }
  }

  void _sendSticker(SecretlyStickerDescriptor s, Rect? from) {
    HapticFeedback.lightImpact();
    widget.onSendSticker(s);
    final r = widget.composerRect?.call();
    if (from != null && from != Rect.zero && r != null) {
      launchPanelFlight(
        context: context,
        from: from,
        to: Offset(r.right - 60, r.top - 60),
        big: true,
        child: Center(
          child: PanelStickerThumb(sticker: s, size: from.shortestSide - 12),
        ),
      );
    }
  }

  void _sendGif(PanelGif g) {
    HapticFeedback.lightImpact();
    widget.onSendGif(g.fullUrl);
  }

  void _backspace() {
    emojiPanelBackspace(widget.textController);
  }

  void _startRepeat() {
    _repeat?.cancel();
    HapticFeedback.selectionClick();
    _repeat = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (widget.textController.text.isEmpty) {
        _repeat?.cancel();
        return;
      }
      _backspace();
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  Widget build(BuildContext context) {
    final s = EmojiPanelStyle.of(
      context,
      frosted: widget.frosted,
      solidFill: widget.solidFill,
      ios: widget.ios,
    );
    final l10n = AppLocalizations.of(context)!;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final botPad = s.ios
        ? math.max(8.0, safeBottom - 12)
        : 8 + safeBottom;
    // Сетка идёт до самого низа экрана, островки плавают поверх; в конце
    // сетки — пустое место под ними.
    final bottomInset = botPad + _Islands.height + 6;
    final content = ValueListenableBuilder<bool>(
      valueListenable: _c.searchFocused,
      builder: (context, searching, _) {
        final pages = ValueListenableBuilder<int>(
          valueListenable: _c.tab,
          builder: (context, tab, _) => PageView(
            key: const ValueKey('emoji-panel:pages'),
            controller: _pages,
            physics: searching
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            onPageChanged: (i) {
              if (_programmatic) return;
              _c.selectTab(i);
            },
            children: [
              TickerMode(
                enabled: tab == 0,
                child: EmojiGridPage(model: _emoji, style: s, onPick: _pickEmoji),
              ),
              TickerMode(
                enabled: tab == 1,
                child: StickerGridPage(
                  key: _stickerPage,
                  model: _stickers,
                  style: s,
                  onSend: _sendSticker,
                  onCreate: widget.onCreateSticker == null
                      ? null
                      : () => widget.onCreateSticker!(),
                  onAddToPack: widget.onCreateSticker == null
                      ? null
                      : (packId) => widget.onCreateSticker!(targetPackId: packId),
                ),
              ),
              TickerMode(
                enabled: tab == 2,
                child: GifGridPage(model: _gifs, style: s, onPick: _sendGif),
              ),
            ],
          ),
        );
        return Column(
          children: [
            // Ручка: раскрыть выше и обратно; вниз — закрыть.
            if (!searching)
              GestureDetector(
                key: const ValueKey('emoji-panel:handle'),
                behavior: HitTestBehavior.opaque,
                onTap: _c.toggleExpanded,
                onVerticalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v < -150 && !_c.expanded.value) _c.toggleExpanded();
                  if (v > 150) {
                    _c.expanded.value ? _c.toggleExpanded() : _c.close();
                  }
                },
                child: Semantics(
                  button: true,
                  label: l10n.emojiPanelExpand,
                  child: SizedBox(
                    height: 14,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: s.handle,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: _TopBar(
                style: s,
                tab: _c.tab,
                anim: _searchCurve,
                open: _searchOpen,
                searchOf: _searchOf,
                hints: [
                  l10n.emojiPanelSearchHint,
                  l10n.searchStickers,
                  l10n.desktopGifSearchHint,
                ],
                searchLabel: l10n.search,
                closeLabel: l10n.close,
                onOpen: _openSearch,
                onClose: _closeSearch,
                railFor: (tab) => switch (tab) {
                  0 => EmojiCategoryRail(
                    key: const ValueKey('rail:e'),
                    model: _emoji,
                    style: s,
                  ),
                  1 => StickerPackRail(
                    key: const ValueKey('rail:s'),
                    model: _stickers,
                    style: s,
                    onUninstall: (p) =>
                        _stickerPage.currentState?.uninstall(p),
                  ),
                  _ => GifChipRail(
                    key: const ValueKey('rail:g'),
                    model: _gifs,
                    style: s,
                  ),
                },
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PanelBottomInset(
                      value: searching ? 0 : bottomInset,
                      child: pages,
                    ),
                  ),
                  // Островки — отдельно, вокруг пусто: сетку видно до низа.
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: botPad,
                    child: IgnorePointer(
                      ignoring: searching,
                      child: AnimatedSlide(
                        offset: searching ? const Offset(0, 1.6) : Offset.zero,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: searching ? 0 : 1,
                          duration: const Duration(milliseconds: 220),
                          child: _Islands(
                            style: s,
                            tab: _c.tab,
                            text: widget.textController,
                            labels: [
                              l10n.desktopEmojiTabEmoji,
                              l10n.desktopEmojiTabStickers,
                              'GIF',
                            ],
                            backspaceLabel: l10n.delete,
                            onTab: _selectTab,
                            onBackspace: _backspace,
                            onBackspaceHold: _startRepeat,
                            onBackspaceRelease: _stopRepeat,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    return _PanelSurface(
      style: s,
      // Тапы по пустым местам панели не уходят в ленту (там они закрывают
      // панель).
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Material(type: MaterialType.transparency, child: content),
      ),
    );
  }
}

/// Верхняя строка: рейка разделов текущей страницы и лупа справа. Лупа
/// выдвигает поиск на всю строку, рейка уезжает влево и гаснет; «назад» —
/// обратно.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.style,
    required this.tab,
    required this.anim,
    required this.open,
    required this.searchOf,
    required this.hints,
    required this.searchLabel,
    required this.closeLabel,
    required this.onOpen,
    required this.onClose,
    required this.railFor,
  });

  final EmojiPanelStyle style;
  final ValueListenable<int> tab;
  final Animation<double> anim;
  final ValueListenable<bool> open;
  final ({
    TextEditingController text,
    FocusNode focus,
    ValueChanged<String> onChanged,
    ScrollController scroll,
  })
  Function(int tab)
  searchOf;
  final List<String> hints;
  final String searchLabel;
  final String closeLabel;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final Widget Function(int tab) railFor;

  static const List<String> _fieldKeys = [
    'emoji-panel:emoji-search',
    'emoji-panel:sticker-search',
    'emoji-panel:gif-search',
  ];

  @override
  Widget build(BuildContext context) {
    const side = 6.0;
    // Правый край рейки гаснет к лупе: недовлезший значок не обрубается.
    final rail = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => LinearGradient(
        colors: const [Colors.white, Colors.white, Color(0x00FFFFFF)],
        stops: [0, r.width <= 28 ? 0 : (r.width - 28) / r.width, 1],
      ).createShader(r),
      child: ValueListenableBuilder<int>(
        valueListenable: tab,
        builder: (context, t, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: railFor(t),
        ),
      ),
    );
    return ValueListenableBuilder<int>(
      valueListenable: tab,
      builder: (context, t, _) => ValueListenableBuilder<bool>(
        valueListenable: open,
        builder: (context, isOpen, _) => AnimatedBuilder(
          animation: anim,
          child: rail,
          builder: (context, rail) {
            final v = anim.value;
            final tc = v.clamp(0.0, 1.0);
            final search = searchOf(t);
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  right: PanelSearchBar.button + side + 2,
                  child: IgnorePointer(
                    ignoring: tc > .02,
                    child: Opacity(
                      opacity: (1 - tc * 1.5).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(-36 * tc, 0),
                        child: rail,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: side,
                  right: side,
                  top: 4,
                  bottom: 4,
                  child: PanelSearchBar(
                    key: const ValueKey('emoji-panel:search-bar'),
                    style: style,
                    t: v,
                    open: isOpen,
                    controller: search.text,
                    focusNode: search.focus,
                    hint: hints[t],
                    onChanged: search.onChanged,
                    onOpen: onOpen,
                    onClose: onClose,
                    searchLabel: searchLabel,
                    closeLabel: closeLabel,
                    fieldKey: ValueKey(_fieldKeys[t]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Фон панели: стекло (одно размытие), матовое стекло или сплошная плита;
/// скругление верха и блик / кант.
class _PanelSurface extends StatelessWidget {
  const _PanelSurface({required this.style, required this.child});

  final EmojiPanelStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = style;
    final radius = BorderRadius.vertical(top: Radius.circular(s.radius));
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [s.fill, s.fillBottom],
        ),
      ),
      child: child,
    );
    if (s.filter != null) {
      body = BackdropFilter(filter: s.filter!, child: body);
    }
    return ClipRRect(
      key: const ValueKey('emoji-panel:surface'),
      borderRadius: radius,
      child: CustomPaint(
        foregroundPainter: _TopEdgePainter(radius: s.radius, color: s.edge),
        child: body,
      ),
    );
  }
}

/// Кант верха: `inset 0 .5px 0` (iPhone) / линия 1 (Android), гаснет вниз по
/// скруглению.
class _TopEdgePainter extends CustomPainter {
  _TopEdgePainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndCorners(
      (Offset.zero & Size(size.width, radius * 2 + 2)).deflate(.4),
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, .55],
        ).createShader(Offset.zero & Size(size.width, radius * 2 + 2)),
    );
  }

  @override
  bool shouldRepaint(_TopEdgePainter old) =>
      old.radius != radius || old.color != color;
}

/// Островки внизу: «Эмодзи / Стикеры / GIF» по центру и «стереть» справа —
/// каждый своим стеклом, вокруг пусто (сетку видно до низа экрана). Одно
/// снимок фона на оба ([BackdropGroup]).
class _Islands extends StatelessWidget {
  const _Islands({
    required this.style,
    required this.tab,
    required this.text,
    required this.labels,
    required this.backspaceLabel,
    required this.onTab,
    required this.onBackspace,
    required this.onBackspaceHold,
    required this.onBackspaceRelease,
  });

  static const double height = 38;

  final EmojiPanelStyle style;
  final ValueListenable<int> tab;
  final TextEditingController text;
  final List<String> labels;
  final String backspaceLabel;
  final ValueChanged<int> onTab;
  final VoidCallback onBackspace;
  final VoidCallback onBackspaceHold;
  final VoidCallback onBackspaceRelease;

  @override
  Widget build(BuildContext context) {
    final s = style;
    return BackdropGroup(
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            const SizedBox(width: height),
            Expanded(
              child: Center(
                child: _Segment(style: s, tab: tab, labels: labels, onTab: onTab),
              ),
            ),
            // «Стереть» — только у эмодзи и только когда есть что стирать.
            ValueListenableBuilder<int>(
              valueListenable: tab,
              builder: (context, t, _) => ValueListenableBuilder<TextEditingValue>(
                valueListenable: text,
                builder: (context, v, _) {
                  final shown = t == 0;
                  final enabled = shown && v.text.isNotEmpty;
                  return AnimatedOpacity(
                    opacity: shown ? (enabled ? 1 : .45) : 0,
                    duration: const Duration(milliseconds: 250),
                    child: AnimatedScale(
                      scale: shown ? 1 : .6,
                      duration: const Duration(milliseconds: 380),
                      curve: kPanelPopCurve,
                      child: IgnorePointer(
                        ignoring: !enabled,
                        child: Semantics(
                          button: true,
                          enabled: enabled,
                          label: backspaceLabel,
                          child: GestureDetector(
                            key: const ValueKey('emoji-panel:backspace'),
                            behavior: HitTestBehavior.opaque,
                            onTap: enabled ? onBackspace : null,
                            onLongPressStart: enabled
                                ? (_) => onBackspaceHold()
                                : null,
                            onLongPressEnd: (_) => onBackspaceRelease(),
                            onLongPressCancel: onBackspaceRelease,
                            child: PanelPress(
                              child: PanelIsland(
                                style: s,
                                radius: height / 2,
                                child: SizedBox(
                                  width: height,
                                  height: height,
                                  child: Icon(
                                    Icons.backspace_outlined,
                                    size: 19,
                                    color: s.hdr,
                                  ),
                                ),
                              ),
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
    );
  }
}

/// Переключатель разделов — компактный островок 210 × 38, бегунок 30 с
/// пружиной `cubic-bezier(.3,1.35,.5,1)` 450 мс.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.style,
    required this.tab,
    required this.labels,
    required this.onTab,
  });

  final EmojiPanelStyle style;
  final ValueListenable<int> tab;
  final List<String> labels;
  final ValueChanged<int> onTab;

  static const double _width = 210;
  static const double _pad = 4;
  static const double _ind = _Islands.height - _pad * 2;

  @override
  Widget build(BuildContext context) {
    final s = style;
    return PanelIsland(
      key: const ValueKey('emoji-panel:segment'),
      style: s,
      radius: _Islands.height / 2,
      padding: const EdgeInsets.all(_pad),
      child: SizedBox(
        width: _width - _pad * 2,
        height: _ind,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / labels.length;
            return ValueListenableBuilder<int>(
              valueListenable: tab,
              builder: (context, t, _) => Stack(
                children: [
                  AnimatedPositioned(
                    key: const ValueKey('emoji-panel:segment-indicator'),
                    duration: const Duration(milliseconds: 450),
                    curve: kPanelSegmentCurve,
                    left: t * w,
                    top: 0,
                    width: w,
                    height: _ind,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: s.ind,
                        borderRadius: BorderRadius.circular(_ind / 2),
                        border: s.ios && s.dark
                            ? Border(top: BorderSide(color: s.indHighlight, width: .8))
                            : null,
                        boxShadow: s.ios && !s.dark
                            ? const [
                                BoxShadow(
                                  color: Color(0x1F000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: i == t,
                            child: GestureDetector(
                              key: ValueKey('emoji-panel:tab:$i'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onTab(i),
                              child: SizedBox(
                                height: _ind,
                                child: Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 250),
                                    style: DefaultTextStyle.of(context).style.merge(TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: i == t ? s.on : s.off,
                                    )),
                                    child: Text(
                                      labels[i],
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Место в экране чата ────────────────────────────────────────────────────

/// Ставит панель внизу экрана высотой [EmojiPanelController.height]; пока
/// панель выезжает, её содержимое уже полной высоты и выезжает снизу, как
/// клавиатура. Панель строится, только пока у неё есть высота.
///
/// Android: «назад» закрывает панель (а не экран).
class EmojiPanelHost extends StatelessWidget {
  const EmojiPanelHost({
    super.key,
    required this.controller,
    required this.builder,
  });

  final EmojiPanelController controller;

  /// Строит [EmojiPanel] (один раз на показ).
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ValueListenableBuilder<double>(
      valueListenable: c.height,
      builder: (context, h, _) {
        if (h <= 0.5) return const SizedBox.shrink();
        return _PanelBox(controller: c, builder: builder);
      },
    );
  }
}

class _PanelBox extends StatefulWidget {
  const _PanelBox({required this.controller, required this.builder});

  final EmojiPanelController controller;
  final WidgetBuilder builder;

  @override
  State<_PanelBox> createState() => _PanelBoxState();
}

class _PanelBoxState extends State<_PanelBox> {
  Widget? _panel;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final panel = _panel ??= widget.builder(context);
    final merged = Listenable.merge([c.height, c.keyboard, c.searchFocused]);
    Widget box = ListenableBuilder(
      listenable: merged,
      child: panel,
      builder: (context, child) {
        final h = c.height.value;
        final layoutH = c.searchFocused.value
            ? h
            : math.max(h, c.baseHeight);
        return Padding(
          padding: EdgeInsets.only(bottom: c.bottomOffset),
          child: SizedBox(
            height: h,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: layoutH,
                maxHeight: layoutH,
                child: child,
              ),
            ),
          ),
        );
      },
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      box = ValueListenableBuilder<bool>(
        valueListenable: c.isOpen,
        child: box,
        builder: (context, open, child) => PopScope(
          canPop: !open,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) c.close();
          },
          child: child!,
        ),
      );
    }
    return box;
  }
}

/// ☺ ⇄ ⌨ в поле ввода: значки перетекают (поворот и масштаб, 300 мс).
class EmojiPanelToggleGlyph extends StatelessWidget {
  const EmojiPanelToggleGlyph({
    super.key,
    required this.open,
    required this.smile,
    required this.color,
  });

  final ValueListenable<bool> open;

  /// Прежняя живая ☺ (Lottie) — не перестраивается.
  final Widget smile;
  final Color color;

  static const IconData _keyboard = AdaptiveIconData(
    Icons.keyboard_rounded,
    CupertinoIcons.keyboard,
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: open,
      child: smile,
      builder: (context, isOpen, smile) {
        Widget fade(bool on, double turns, Widget child) => AnimatedOpacity(
          opacity: on ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedScale(
            scale: on ? 1 : .4,
            duration: const Duration(milliseconds: 380),
            curve: kPanelPopCurve,
            child: AnimatedRotation(
              turns: on ? 0 : turns,
              duration: const Duration(milliseconds: 380),
              curve: kPanelPopCurve,
              child: child,
            ),
          ),
        );
        return Stack(
          alignment: Alignment.center,
          children: [
            fade(!isOpen, -.15, smile!),
            fade(
              isOpen,
              .15,
              Icon(
                _keyboard,
                key: const ValueKey('emoji-panel:keyboard-glyph'),
                size: 25,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }
}
