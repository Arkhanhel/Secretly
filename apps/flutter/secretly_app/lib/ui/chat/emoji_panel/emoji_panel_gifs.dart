// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Страница GIF: «тетрис» из трёх колонок (каждая гифка — своих пропорций,
/// широкие на две колонки, см. `gif_packing.dart`), фишки быстрых запросов
/// сверху, поиск, подгрузка по мере прокрутки, мерцание-заглушка, значок
/// «GIF», нажатие ×0,95.
///
/// Запросы, подгрузка и недавние — та же логика, что у прежнего листа
/// (`_GifPickerView`): поколение запроса, курсор по числу записей GIPHY,
/// потолок 180, без повторов на стыке страниц.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';

import '../../../gifs/gif_categories.dart';
import '../../../l10n/app_localizations.dart';
import '../../apple_controls.dart' show SecretlySpinner;
import '../../scroll_feel.dart';
import 'emoji_panel_sources.dart';
import 'emoji_panel_style.dart';
import 'emoji_panel_widgets.dart';
import 'gif_packing.dart';

/// Подпись фишки категории на языке человека.
String gifCategoryLabel(AppLocalizations l10n, GifCategory c) =>
    switch (c.query) {
      'laugh' => l10n.emojiPanelGifLaugh,
      'love' => l10n.emojiPanelGifLove,
      'thumbs up' => l10n.emojiPanelGifApproval,
      'hello' => l10n.emojiPanelGifHello,
      'hug' => l10n.emojiPanelGifHug,
      'crying' => l10n.emojiPanelGifCrying,
      'excited' => l10n.emojiPanelGifExcited,
      'thinking' => l10n.emojiPanelGifThinking,
      'sleepy' => l10n.emojiPanelGifSleepy,
      'angry' => l10n.emojiPanelGifAngry,
      'shocked' => l10n.emojiPanelGifShocked,
      'dance' => l10n.emojiPanelGifDance,
      'party' => l10n.emojiPanelGifParty,
      'cat' => l10n.emojiPanelGifCats,
      'dog' => l10n.emojiPanelGifDogs,
      'fire' => l10n.emojiPanelGifFire,
      'food' => l10n.emojiPanelGifFood,
      'sport' => l10n.emojiPanelGifSport,
      _ => c.en,
    };

class GifTabModel extends ChangeNotifier {
  GifTabModel({required this.source}) {
    scroll.addListener(_onScroll);
  }

  final EmojiPanelGifSource source;
  final ScrollController scroll = ScrollController();
  final TextEditingController search = TextEditingController();
  final FocusNode searchFocus = FocusNode(debugLabel: 'emoji-panel:gif');

  /// Выбранная фишка: 0 — «В тренде», дальше — [kGifCategories]; `null` —
  /// идёт поиск по набранному слову.
  final ValueNotifier<int?> chip = ValueNotifier<int?>(0);

  List<PanelGif> gifs = const [];
  List<PanelGif> recents = const [];
  bool loadingFirst = false;
  bool loadingMore = false;
  bool failed = false;
  bool hasMore = false;
  bool _started = false;
  int _offset = 0;
  String? _term;
  String _lang = 'en';
  int _seq = 0;
  Timer? _debounce;
  bool _disposed = false;

  bool get searching => chip.value != 0 || search.text.trim().isNotEmpty;

  /// Первая загрузка — когда страница впервые видна (не грузим сеть зря).
  void ensureStarted() {
    if (_started) return;
    _started = true;
    unawaited(_loadFirst(null));
    unawaited(_loadRecents());
  }

  Future<void> _loadRecents() async {
    try {
      final r = await source.loadRecents();
      if (_disposed) return;
      recents = r;
      notifyListeners();
    } catch (_) {}
  }

  void selectChip(int i) {
    HapticFeedback.selectionClick();
    _debounce?.cancel();
    if (search.text.isNotEmpty) search.clear();
    chip.value = i;
    unawaited(_loadFirst(i == 0 ? null : kGifCategories[i - 1].query));
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    chip.value = q.isEmpty ? 0 : null;
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (_disposed) return;
      unawaited(_loadFirst(q.isEmpty ? null : q));
    });
  }

  void retry() {
    final q = search.text.trim();
    final c = chip.value;
    unawaited(
      _loadFirst(
        q.isNotEmpty ? q : (c == null || c == 0 ? null : kGifCategories[c - 1].query),
      ),
    );
  }

  Future<void> _loadFirst(String? raw) async {
    final seq = ++_seq;
    loadingFirst = true;
    loadingMore = false;
    failed = false;
    gifs = const [];
    hasMore = false;
    _offset = 0;
    notifyListeners();

    final plan = panelGifQueryPlan(raw ?? '');
    var page = PanelGifPage.empty;
    String? term;
    var lang = 'en';
    if (plan.isEmpty) {
      page = await source.fetch(query: null, offset: 0);
      if (seq != _seq || _disposed) return;
    } else {
      for (final attempt in plan) {
        page = await source.fetch(
          query: attempt.term,
          lang: attempt.lang,
          offset: 0,
        );
        if (seq != _seq || _disposed) return;
        term = attempt.term;
        lang = attempt.lang;
        if (page.items.isNotEmpty || page.failed) break;
      }
    }
    gifs = page.items;
    hasMore = page.hasMore && page.items.length < kPanelGifMaxItems;
    failed = page.failed;
    loadingFirst = false;
    _offset = page.returned;
    _term = term;
    _lang = lang;
    notifyListeners();
  }

  Future<void> _loadMore() async {
    if (loadingMore || !hasMore) return;
    final seq = _seq;
    loadingMore = true;
    notifyListeners();
    final page = await source.fetch(query: _term, lang: _lang, offset: _offset);
    if (seq != _seq || _disposed) return;
    final before = gifs.length;
    final merged = <PanelGif>[...gifs];
    final seen = merged.map((g) => g.fullUrl).toSet();
    for (final item in page.items) {
      if (!seen.add(item.fullUrl)) continue;
      merged.add(item);
      if (merged.length >= kPanelGifMaxItems) break;
    }
    gifs = merged;
    _offset += page.returned;
    hasMore =
        page.hasMore &&
        !page.failed &&
        merged.length > before &&
        merged.length < kPanelGifMaxItems;
    loadingMore = false;
    notifyListeners();
  }

  void _onScroll() {
    if (loadingFirst || loadingMore || !hasMore || !scroll.hasClients) return;
    final pos = scroll.position;
    if (pos.pixels < pos.maxScrollExtent - kPanelGifPrefetchExtent) return;
    unawaited(_loadMore());
  }


  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    scroll.removeListener(_onScroll);
    scroll.dispose();
    search.dispose();
    searchFocus.dispose();
    chip.dispose();
    super.dispose();
  }
}

/// Фишки быстрых запросов: «В тренде» и категории.
class GifChipRail extends StatelessWidget {
  const GifChipRail({super.key, required this.model, required this.style});

  final GifTabModel model;
  final EmojiPanelStyle style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = style;
    final labels = <String>[
      l10n.emojiPanelGifTrending,
      for (final c in kGifCategories) '${c.emoji} ${gifCategoryLabel(l10n, c)}',
    ];
    return ValueListenableBuilder<int?>(
      valueListenable: model.chip,
      builder: (context, active, _) => ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final on = i == active;
          return Semantics(
            button: true,
            selected: on,
            child: GestureDetector(
              key: ValueKey('emoji-panel:gif-chip:$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => model.selectChip(i),
              child: _ChipPress(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? s.chipOn : s.pill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: DefaultTextStyle.of(context).style.merge(TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: on ? s.chipOnFg : s.hdr,
                      fontFamilyFallback: kPanelEmojiFontFallback,
                    )),
                    child: Text(labels[i]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChipPress extends StatefulWidget {
  const _ChipPress({required this.child});

  final Widget child;

  @override
  State<_ChipPress> createState() => _ChipPressState();
}

class _ChipPressState extends State<_ChipPress> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => _down = true),
    onPointerUp: (_) => setState(() => _down = false),
    onPointerCancel: (_) => setState(() => _down = false),
    child: AnimatedScale(
      scale: _down ? .92 : 1,
      duration: const Duration(milliseconds: 300),
      curve: kPanelPressCurve,
      child: widget.child,
    ),
  );
}

/// Сетка GIF.
class GifGridPage extends StatefulWidget {
  const GifGridPage({
    super.key,
    required this.model,
    required this.style,
    required this.onPick,
  });

  final GifTabModel model;
  final EmojiPanelStyle style;
  final ValueChanged<PanelGif> onPick;

  @override
  State<GifGridPage> createState() => _GifGridPageState();
}

class _GifGridPageState extends State<GifGridPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  /// Одно мерцание на всю страницу (`es-shim` 1,1 с).
  ///
  /// С-8 (22.11.2026): тикает, только пока на экране есть хоть одна
  /// незагруженная плитка (см. [GifShimmerClock]); раньше `..repeat()` крутил
  /// кадры без конца под тремя размытиями — батарея и нагрев на слабом Android.
  late final GifShimmerClock _shimmer = GifShimmerClock(
    AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    ),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.model.ensureStarted();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  void _pick(PanelGif g) {
    unawaited(widget.model.source.remember(g));
    widget.onPick(g);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = widget.style;
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 16;
        return ListenableBuilder(
          listenable: widget.model,
          builder: (context, _) {
            final m = widget.model;
            final showRecents = m.recents.isNotEmpty && !m.searching;
            final slivers = <Widget>[
              // Поиск — в верхней строке панели (22.11.2026).
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
            ];
            if (!m.source.available) {
              slivers.add(_message(s, l10n.desktopGifNoKey));
            } else if (m.loadingFirst && m.gifs.isEmpty) {
              slivers.add(
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  sliver: SliverToBoxAdapter(
                    child: _Skeleton(width: width, shimmer: _shimmer, style: s),
                  ),
                ),
              );
            } else if (m.gifs.isEmpty && !showRecents) {
              slivers.add(
                _message(
                  s,
                  m.failed ? l10n.desktopGifConnectionLost : l10n.emojiPanelGifNotFound,
                  action: m.failed ? l10n.uploadRetry : null,
                  onAction: m.retry,
                ),
              );
            } else {
              if (showRecents) {
                slivers
                  ..add(_label(s, l10n.desktopEmojiRecents))
                  ..add(
                    _PackedSliver(
                      gifs: m.recents,
                      width: width,
                      scroll: m.scroll,
                      shimmer: _shimmer,
                      style: s,
                      image: m.source.previewImage,
                      onPick: _pick,
                    ),
                  );
                if (m.gifs.isNotEmpty) {
                  slivers.add(_label(s, l10n.emojiPanelGifTrending));
                }
              }
              if (m.gifs.isNotEmpty) {
                slivers.add(
                  _PackedSliver(
                    gifs: m.gifs,
                    width: width,
                    scroll: m.scroll,
                    shimmer: _shimmer,
                    style: s,
                    image: m.source.previewImage,
                    onPick: _pick,
                  ),
                );
              }
              if (m.loadingMore) {
                slivers.add(
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: SecretlySpinner(strokeWidth: 2.1, color: s.primary),
                        ),
                      ),
                    ),
                  ),
                );
              }
            }
            // GIPHY требует видимой подписи везде, где показаны гифки.
            slivers.add(
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    10,
                    14,
                    14 + PanelBottomInset.of(context),
                  ),
                  child: Text(
                    'Powered by GIPHY',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: .6,
                      fontWeight: FontWeight.w600,
                      color: s.muted.withValues(alpha: .8),
                    ),
                  ),
                ),
              ),
            );
            return CustomScrollView(
              key: const ValueKey('emoji-panel:gif-scroll'),
              controller: m.scroll,
              physics: secretlyListPhysics(),
              slivers: slivers,
            );
          },
        );
      },
    );
  }

  Widget _label(EmojiPanelStyle s, String text) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: .48,
          color: s.muted,
        ),
      ),
    ),
  );

  Widget _message(
    EmojiPanelStyle s,
    String text, {
    String? action,
    VoidCallback? onAction,
  }) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 12),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: s.muted),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action, style: TextStyle(color: s.primary)),
            ),
        ],
      ),
    ),
  );
}

/// Уложенные плитки — строятся только те, что рядом с экраном.
///
/// Плитки лежат в одном поле нужной высоты; поле слушает прокрутку и
/// перестраивается, только когда меняется НАБОР видимых плиток, а не на
/// каждом кадре.
class _PackedSliver extends StatelessWidget {
  const _PackedSliver({
    required this.gifs,
    required this.width,
    required this.scroll,
    required this.shimmer,
    required this.style,
    required this.image,
    required this.onPick,
  });

  final List<PanelGif> gifs;
  final double width;
  final ScrollController scroll;
  final Animation<double> shimmer;
  final EmojiPanelStyle style;
  final ImageProvider Function(PanelGif) image;
  final ValueChanged<PanelGif> onPick;

  @override
  Widget build(BuildContext context) {
    final pack = packGifTiles(
      [for (final g in gifs) g.aspect ?? 1.0],
      width: width,
    );
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: pack.height,
          child: _LazyTiles(
            pack: pack,
            gifs: gifs,
            scroll: scroll,
            shimmer: shimmer,
            style: style,
            image: image,
            onPick: onPick,
          ),
        ),
      ),
    );
  }
}

class _LazyTiles extends StatefulWidget {
  const _LazyTiles({
    required this.pack,
    required this.gifs,
    required this.scroll,
    required this.shimmer,
    required this.style,
    required this.image,
    required this.onPick,
  });

  final GifPackResult pack;
  final List<PanelGif> gifs;
  final ScrollController scroll;
  final Animation<double> shimmer;
  final EmojiPanelStyle style;
  final ImageProvider Function(PanelGif) image;
  final ValueChanged<PanelGif> onPick;

  @override
  State<_LazyTiles> createState() => _LazyTilesState();
}

class _LazyTilesState extends State<_LazyTiles> {
  /// Запас над и под экраном.
  static const double _margin = 400;
  Set<int> _visible = <int>{};

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_recompute);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
  }

  @override
  void didUpdateWidget(covariant _LazyTiles old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      old.scroll.removeListener(_recompute);
      widget.scroll.addListener(_recompute);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_recompute);
    super.dispose();
  }

  void _recompute() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    // Где поле внутри прокрутки и какая его часть видна.
    final reveal = viewport.getOffsetToReveal(box, 0).offset;
    final pixels = widget.scroll.hasClients ? widget.scroll.position.pixels : 0.0;
    final vh = widget.scroll.hasClients
        ? widget.scroll.position.viewportDimension
        : 800.0;
    final top = pixels - reveal - _margin;
    final bottom = pixels - reveal + vh + _margin;
    final next = <int>{
      for (var k = 0; k < widget.pack.tiles.length; k++)
        if (widget.pack.tiles[k].rect.bottom >= top &&
            widget.pack.tiles[k].rect.top <= bottom)
          k,
    };
    if (next.length == _visible.length && next.containsAll(_visible)) return;
    setState(() => _visible = next);
  }

  @override
  Widget build(BuildContext context) {
    final tiles = widget.pack.tiles;
    // До первого замера — первые плитки, чтобы не мигать пустотой.
    final show = _visible.isEmpty
        ? {for (var k = 0; k < math.min(12, tiles.length); k++) k}
        : _visible;
    return Stack(
      children: [
        for (final k in show.toList()..sort())
          if (k < tiles.length && tiles[k].index < widget.gifs.length)
            Positioned.fromRect(
              key: ValueKey(widget.gifs[tiles[k].index].fullUrl),
              rect: tiles[k].rect,
              child: _GifTile(
                gif: widget.gifs[tiles[k].index],
                shimmer: widget.shimmer,
                style: widget.style,
                image: widget.image,
                onTap: widget.onPick,
              ),
            ),
      ],
    );
  }
}

class _GifTile extends StatefulWidget {
  const _GifTile({
    required this.gif,
    required this.shimmer,
    required this.style,
    required this.image,
    required this.onTap,
  });

  final PanelGif gif;
  final Animation<double> shimmer;
  final EmojiPanelStyle style;
  final ImageProvider Function(PanelGif) image;
  final ValueChanged<PanelGif> onTap;

  @override
  State<_GifTile> createState() => _GifTileState();
}

class _GifTileState extends State<_GifTile> {
  bool _down = false;
  bool _loaded = false;
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () => widget.onTap(widget.gif),
      child: AnimatedScale(
        scale: _down ? .95 : 1,
        duration: const Duration(milliseconds: 300),
        curve: kPanelPressCurve,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!_loaded && !_failed)
                _Shimmer(animation: widget.shimmer, style: s),
              Image(
                image: widget.image(widget.gif),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, sync) {
                  if ((frame != null || sync) && !_loaded) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_loaded) setState(() => _loaded = true);
                    });
                  }
                  return AnimatedOpacity(
                    opacity: frame != null || sync ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: child,
                  );
                },
                errorBuilder: (_, _, _) {
                  // Не загрузилась — мерцание под значком ошибки не нужно.
                  if (!_failed) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_failed) setState(() => _failed = true);
                    });
                  }
                  return ColoredBox(
                    color: s.pill,
                    child: Icon(Icons.gif_box_outlined, color: s.muted),
                  );
                },
              ),
              Positioned(
                left: 7,
                bottom: 7,
                child: AnimatedOpacity(
                  opacity: _loaded ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const _GifBadge(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GifBadge extends StatelessWidget {
  const _GifBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0x61000000),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      'GIF',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.2,
      ),
    ),
  );
}

/// Общее мерцание страницы GIF, которое крутится, только пока его кто-то
/// показывает: каждая заглушка [_Shimmer] берёт его при появлении и отдаёт
/// при уходе (плитка загрузилась, ушла с экрана, страница закрыта). Нет
/// заглушек — контроллер стоит, кадров нет.
class GifShimmerClock extends ProxyAnimation {
  GifShimmerClock(this._controller) : super(_controller);

  final AnimationController _controller;
  int _users = 0;

  /// Сколько мерцаний сейчас крутится (для тестов).
  @visibleForTesting
  static int debugTicking = 0;

  /// Крутится ли это мерцание.
  bool get ticking => _controller.isAnimating;

  void acquire() {
    _users++;
    if (_users == 1 && !_controller.isAnimating) {
      _controller.repeat();
      debugTicking++;
    }
  }

  void release() {
    if (_users == 0) return;
    _users--;
    if (_users == 0 && _controller.isAnimating) {
      _controller.stop();
      debugTicking--;
    }
  }

  void dispose() {
    if (_controller.isAnimating) debugTicking--;
    _users = 0;
    _controller.dispose();
  }
}

/// `es-shim`: светлая полоса едет справа налево.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.animation, required this.style});

  final Animation<double> animation;
  final EmojiPanelStyle style;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> {
  @override
  void initState() {
    super.initState();
    _take(widget.animation);
  }

  @override
  void didUpdateWidget(covariant _Shimmer old) {
    super.didUpdateWidget(old);
    if (!identical(old.animation, widget.animation)) {
      _give(old.animation);
      _take(widget.animation);
    }
  }

  @override
  void dispose() {
    _give(widget.animation);
    super.dispose();
  }

  static void _take(Animation<double> a) {
    if (a is GifShimmerClock) a.acquire();
  }

  static void _give(Animation<double> a) {
    if (a is GifShimmerClock) a.release();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final animation = widget.animation;
    final base = style.dark ? const Color(0x0DFFFFFF) : const Color(0x0A000000);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // background-position 100% → −100% при ширине фона 200 %.
        final x = 1 - 2 * animation.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: [base, style.shimmer, base],
            ),
          ),
        );
      },
    );
  }
}

/// Заглушка первой загрузки — плитки высот макета, уложенные тем же
/// «тетрисом».
class _Skeleton extends StatelessWidget {
  const _Skeleton({
    required this.width,
    required this.shimmer,
    required this.style,
  });

  final double width;
  final Animation<double> shimmer;
  final EmojiPanelStyle style;

  static const List<double> _aspects = [
    0.95, 1.78, 1.3, 0.8, 1.1, 1.9, 0.9, 1.25, 0.75,
  ];

  @override
  Widget build(BuildContext context) {
    final pack = packGifTiles(_aspects, width: width);
    return SizedBox(
      key: const ValueKey('emoji-panel:gif-skeleton'),
      height: pack.height,
      child: Stack(
        children: [
          for (final t in pack.tiles)
            Positioned.fromRect(
              rect: t.rect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _Shimmer(animation: shimmer, style: style),
              ),
            ),
        ],
      ),
    );
  }
}
