// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Страница стикеров: пять в ряд (слово владельца; в макете четыре), одна
/// лента — «Недавние» с клеткой «Создать», «Избранное», затем наборы. Тап —
/// стикер улетает в чат; удержание — крупное превью, ведите пальцем по
/// сетке — превью меняется; отпустили — меню.
///
/// Всё, что умела прежняя лента (`SecretlyStickerPickerTab`), на месте:
/// поиск, ⚙ своего набора (окно набора), ⋯ чужого (убрать из моих),
/// удержание значка поставленного набора — снять набор, в меню стикера —
/// избранное, обложка и удаление у своего набора, каждое удаление с вопросом.
/// «Отправить без звука» из макета нет: беззвучной отправки в приложении нет
/// вообще (её нельзя изображать).
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../stickers/premium_sticker_packs.dart'
    show isDesignerStickerPackId;
import '../../../stickers/sticker_catalog.dart';
import '../../motion/app_dialogs.dart';
import '../../apple_controls.dart' show SecretlyAlertDialog, SecretlySpinner;
import '../../scroll_feel.dart';
import '../../secretly_snackbar.dart';
import '../../widgets/secretly_sticker_widgets.dart'
    show
        SecretlyStickerAssetView,
        bundledStickerLottie,
        confirmSecretlyStickerDelete,
        confirmSecretlyStickerDestructive,
        showSecretlyForeignStickerPackSheet;
import 'emoji_panel_rail.dart';
import 'emoji_panel_sources.dart';
import 'emoji_panel_style.dart';
import 'emoji_panel_widgets.dart';
import 'premium_sticker_sheet.dart' show premiumPackTitle;

/// Стикеров в ряд.
const int kPanelStickerColumns = 5;

abstract final class _StickerLayout {
  static const double sidePad = 8;
  static const double gap = 2;
  // Поиск — в верхней строке панели (22.11.2026), здесь только отступ.
  static const double searchBlock = 4;
  static const double head = 36; // 6 + 30
  static const double emptyBox = 64;
  static const double bottomPad = 14;
}

// ─── Воспроизведение ────────────────────────────────────────────────────────

/// Играют только видимые, не больше шести сразу; на быстрой прокрутке —
/// пауза. Клетка просит слот при появлении и отдаёт при уходе; остановка —
/// через [TickerMode] (Lottie и анимированный WebP оба её слушают).
class StickerPlaybackGate extends ChangeNotifier {
  static const int maxPlaying = 6;

  final LinkedHashSet<Object> _tokens = LinkedHashSet<Object>.identity();
  bool _paused = false;
  bool _scheduled = false;

  bool get paused => _paused;

  set paused(bool v) {
    if (_paused == v) return;
    _paused = v;
    _schedule();
  }

  bool allows(Object token) {
    if (_paused) return false;
    var i = 0;
    for (final t in _tokens) {
      if (identical(t, token)) return true;
      if (++i >= maxPlaying) return false;
    }
    return false;
  }

  /// Сколько сейчас играет (для теста).
  int get playing => _paused ? 0 : math.min(maxPlaying, _tokens.length);

  void register(Object token) {
    if (_tokens.add(token)) _schedule();
  }

  void unregister(Object token) {
    if (_tokens.remove(token)) _schedule();
  }

  // Клетки появляются во время сборки кадра — оповещаем после него.
  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      // Панель закрыли в этом же кадре — оповещать некого.
      if (_disposed) return;
      notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Стикер в клетке: декодируется в размер клетки, анимированный играет,
/// только если [gate] разрешает.
class PanelStickerThumb extends StatefulWidget {
  const PanelStickerThumb({
    super.key,
    required this.sticker,
    required this.size,
    this.gate,
  });

  final SecretlyStickerDescriptor sticker;
  final double size;

  /// `null` — статично (рейка).
  final StickerPlaybackGate? gate;

  @override
  State<PanelStickerThumb> createState() => _PanelStickerThumbState();
}

class _PanelStickerThumbState extends State<PanelStickerThumb> {
  bool get _animated =>
      widget.sticker.animated ||
      widget.sticker.format == SecretlyStickerFormat.lottie;

  @override
  void initState() {
    super.initState();
    if (_animated) widget.gate?.register(this);
  }

  @override
  void didUpdateWidget(covariant PanelStickerThumb old) {
    super.didUpdateWidget(old);
    if (old.gate != widget.gate || old.sticker != widget.sticker) {
      old.gate?.unregister(this);
      if (_animated) widget.gate?.register(this);
    }
  }

  @override
  void dispose() {
    widget.gate?.unregister(this);
    super.dispose();
  }

  bool get _lottie => widget.sticker.format == SecretlyStickerFormat.lottie;

  /// Lottie играет, только если [StickerPlaybackGate] пускает; иначе —
  /// неподвижный кадр картинкой (см. [BundledStickerLottie]).
  Widget _lottieCell(bool play) => bundledStickerLottie(
    widget.sticker,
    size: widget.size,
    maxLoops: null,
    animate: play,
  );

  Widget _image() {
    final s = widget.sticker;
    final d = widget.size;
    final px = (d * MediaQuery.devicePixelRatioOf(context)).round();
    Widget broken() => SecretlyStickerAssetView(sticker: s, size: d);
    switch (s.assetSource) {
      case SecretlyStickerAssetSource.missing:
        return broken();
      case SecretlyStickerAssetSource.bundledAsset:
        return switch (s.format) {
          SecretlyStickerFormat.lottie => bundledStickerLottie(s, size: d, maxLoops: null),
          _ => Image.asset(
            s.assetPath,
            width: d,
            height: d,
            fit: BoxFit.contain,
            cacheWidth: px,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => broken(),
          ),
        };
      case SecretlyStickerAssetSource.file:
        final file = File(s.assetPath);
        if (!file.existsSync()) return broken();
        return switch (s.format) {
          SecretlyStickerFormat.lottie => bundledStickerLottie(s, size: d, maxLoops: null),
          _ => Image.file(
            file,
            width: d,
            height: d,
            fit: BoxFit.contain,
            cacheWidth: px,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => broken(),
          ),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = widget.gate;
    if (_lottie && widget.sticker.assetSource != SecretlyStickerAssetSource.missing) {
      Widget cell(bool play) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(child: _lottieCell(play)),
      );
      if (gate == null) return cell(false);
      return ListenableBuilder(
        listenable: gate,
        builder: (context, _) => cell(gate.allows(this)),
      );
    }
    final image = SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(child: _image()),
    );
    if (!_animated) return image;
    if (gate == null) return TickerMode(enabled: false, child: image);
    return ListenableBuilder(
      listenable: gate,
      child: image,
      builder: (context, child) =>
          TickerMode(enabled: gate.allows(this), child: child!),
    );
  }
}

// ─── Модель ─────────────────────────────────────────────────────────────────

enum PanelStickerSectionKind { recent, favorites, pack, results }

class PanelStickerSection {
  PanelStickerSection({
    required this.kind,
    required this.id,
    required this.title,
    required this.stickers,
    this.pack,
    this.create = false,
    this.emptyHint,
  });

  final PanelStickerSectionKind kind;
  final String id;
  final String title;
  final List<SecretlyStickerDescriptor> stickers;
  final SecretlyStickerPack? pack;

  /// Первая клетка — «Создать».
  final bool create;
  final String? emptyHint;

  // Раскладка (заполняется [StickerTabModel.layout]).
  double start = 0;
  double gridTop = 0;
  int rows = 0;

  int get cells => stickers.length + (create ? 1 : 0);
}

class StickerTabModel extends ChangeNotifier {
  StickerTabModel({required this.source, required this.canCreate}) {
    scroll.addListener(_spy);
    _showSnapshot();
    unawaited(_open());
  }

  /// Недавние по профилю с прошлого показа — чтобы первый кадр панели сразу
  /// был полным. Владелец 24.11.2026: панель на долю секунды показывала
  /// пустые «Недавние» и короткую рейку, потом «моргала» и наполнялась.
  static final Map<String, List<SecretlyStickerDescriptor>> _recentsCache =
      <String, List<SecretlyStickerDescriptor>>{};

  /// Прочитать недавние заранее (чат открыт, панель ещё нет).
  static Future<void> warmUp(EmojiPanelStickerSource source) async {
    final key = source.cacheKey;
    if (key == null) return;
    try {
      _recentsCache[key] = await source.loadRecent();
    } catch (_) {}
  }

  /// Из того, что уже в памяти: наборы и недавние — до первого кадра.
  void _showSnapshot() {
    final all = source.packsNow();
    final key = source.cacheKey;
    final r = key == null ? null : _recentsCache[key];
    if (all == null) return;
    _apply(r ?? const [], all);
    loading = r == null;
  }

  /// Открытие: сперва всё, что есть без сети (одним обновлением), потом
  /// каталог с сервера.
  Future<void> _open() async {
    await reload();
    if (_disposed) return;
    try {
      final all = await source.loadPacks();
      // Тот же список — каталог не менялся, сетку не трогаем. Недавние
      // остаются как есть: под пальцем они не переставляются.
      if (_disposed || identical(all, _shownPacks)) return;
      _apply(recents, all);
      notifyListeners();
    } catch (_) {
      // Нет сети — остаётся показанное.
    }
  }

  List<SecretlyStickerPack>? _shownPacks;

  void _apply(
    List<SecretlyStickerDescriptor> r,
    List<SecretlyStickerPack> all,
  ) {
    final favId = source.favoritesPackId;
    recents = r;
    _shownPacks = all;
    favorites = all.where((p) => p.id == favId).firstOrNull;
    // Наборы, где есть что показать (как у прежней ленты).
    premium = source.premiumPacks();
    final premiumIds = {for (final p in premium) p.id};
    packs = all
        .where(
          (p) =>
              p.id != favId &&
              p.stickers.isNotEmpty &&
              !premiumIds.contains(p.id),
        )
        .toList(growable: false);
  }

  final EmojiPanelStickerSource source;
  final bool canCreate;

  final ScrollController scroll = ScrollController();
  final TextEditingController search = TextEditingController();
  final FocusNode searchFocus = FocusNode(debugLabel: 'emoji-panel:stickers');
  final ValueNotifier<int> active = ValueNotifier<int>(0);
  final StickerPlaybackGate gate = StickerPlaybackGate();

  List<SecretlyStickerDescriptor> recents = const [];
  List<SecretlyStickerPack> packs = const [];

  /// Премиум-наборы (значки закреплены слева от лупы). С Premium они ещё и
  /// разделы сетки в конце; без Premium — только окно набора с покупкой.
  List<SecretlyStickerPack> premium = const [];

  /// Есть ли Premium — читается каждый раз (после покупки или поздней
  /// загрузки подписки панель отпирается без переоткрытия).
  bool get premiumUnlocked => source.premiumUnlocked;

  /// Страница покупки; по возвращении панель перестраивается — замки
  /// снимаются сразу, если подписка оформлена.
  Future<void> openPremium(BuildContext context) async {
    await source.openPremium(context);
    if (!_disposed) notifyListeners();
  }
  SecretlyStickerPack? favorites;
  bool loading = true;
  String query = '';

  List<PanelStickerSection> _sections = const [];
  double _cell = 60;
  bool _lock = false;
  Timer? _lockTimer;
  bool _disposed = false;

  Future<void> reload({bool refresh = false}) async {
    try {
      final r = await source.loadRecent();
      final all = await source.loadPacks(refresh: refresh);
      if (_disposed) return;
      final key = source.cacheKey;
      if (key != null) _recentsCache[key] = r;
      _apply(r, all);
    } catch (_) {
      // Сбой — показываем то, что было.
    }
    if (_disposed) return;
    loading = false;
    notifyListeners();
  }

  void setQuery(String q) {
    final next = q.trim().toLowerCase();
    if (next == query) return;
    query = next;
    if (scroll.hasClients) scroll.jumpTo(0);
    notifyListeners();
  }

  bool isOwn(SecretlyStickerPack? pack) =>
      pack != null && pack.id.startsWith('user:${source.profileId}:');

  List<PanelStickerSection> buildSections(AppLocalizations l10n) {
    if (query.isNotEmpty) {
      return [
        PanelStickerSection(
          kind: PanelStickerSectionKind.results,
          id: '__results__',
          title: l10n.emojiPanelResults,
          stickers: source.search(query),
        ),
      ];
    }
    final fav = favorites?.stickers ?? const <SecretlyStickerDescriptor>[];
    return [
      if (recents.isNotEmpty || canCreate)
        PanelStickerSection(
          kind: PanelStickerSectionKind.recent,
          id: SecretlyStickerCatalog.recentPackId,
          title: l10n.stickersRecent,
          stickers: recents,
          create: canCreate,
        ),
      PanelStickerSection(
        kind: PanelStickerSectionKind.favorites,
        id: source.favoritesPackId,
        title: l10n.stickerFavoritesPackTitle,
        stickers: fav,
        pack: favorites,
        emptyHint: fav.isEmpty ? l10n.emojiPanelFavoritesEmpty : null,
      ),
      for (final p in packs)
        PanelStickerSection(
          kind: PanelStickerSectionKind.pack,
          id: p.id,
          // Встроенные наборы дизайнера — на языке интерфейса.
          title: premiumPackTitle(l10n, p),
          stickers: p.stickers,
          pack: p,
        ),
      // Премиум — всегда последними: их значки закреплены у лупы, а не в
      // прокручиваемой рейке ([railCount]).
      if (premiumUnlocked)
        for (final p in premium)
          PanelStickerSection(
            kind: PanelStickerSectionKind.pack,
            id: p.id,
            title: premiumPackTitle(l10n, p),
            stickers: p.stickers,
            pack: p,
          ),
    ];
  }

  /// Сколько разделов показывает прокручиваемая рейка: все, кроме премиум.
  int railCount(List<PanelStickerSection> secs) =>
      secs.where((s) => s.pack?.premium != true).length;

  /// Прокрутить сетку к разделу набора [packId] (значок у лупы).
  void jumpToPack(AppLocalizations l10n, String packId) {
    final secs = buildSections(l10n);
    final i = secs.indexWhere((s) => s.id == packId);
    if (i >= 0) jump(i);
  }

  static double cellSize(double width) =>
      (width -
          _StickerLayout.sidePad * 2 -
          _StickerLayout.gap * (kPanelStickerColumns - 1)) /
      kPanelStickerColumns;

  void layout(double width, List<PanelStickerSection> secs) {
    _cell = cellSize(width);
    var y = _StickerLayout.searchBlock;
    for (final s in secs) {
      s.start = y;
      y += _StickerLayout.head;
      if (s.emptyHint != null && s.cells == 0) y += _StickerLayout.emptyBox;
      s.gridTop = y;
      s.rows = (s.cells / kPanelStickerColumns).ceil();
      if (s.rows > 0) {
        y += s.rows * _cell + (s.rows - 1) * _StickerLayout.gap;
      }
    }
    _sections = secs;
  }

  /// Стикер под точкой [local] (координаты окна прокрутки), если есть.
  ({SecretlyStickerDescriptor sticker, PanelStickerSection section})? hit(
    Offset local,
  ) {
    if (!scroll.hasClients) return null;
    final y = local.dy + scroll.position.pixels;
    final step = _cell + _StickerLayout.gap;
    for (final s in _sections) {
      final bottom = s.gridTop + s.rows * step;
      if (y < s.gridTop || y >= bottom) continue;
      final row = ((y - s.gridTop) / step).floor();
      final col = ((local.dx - _StickerLayout.sidePad) / step).floor();
      if (col < 0 || col >= kPanelStickerColumns) return null;
      final i = row * kPanelStickerColumns + col - (s.create ? 1 : 0);
      if (i < 0 || i >= s.stickers.length) return null;
      return (sticker: s.stickers[i], section: s);
    }
    return null;
  }

  void _spy() {
    if (_lock || !scroll.hasClients || query.isNotEmpty) return;
    final pos = scroll.position;
    var idx = 0;
    for (var k = 0; k < _sections.length; k++) {
      if (_sections[k].start - 40 <= pos.pixels) idx = k;
    }
    if (active.value != idx) active.value = idx;
  }

  void jump(int i) {
    if (query.isNotEmpty) {
      search.clear();
      query = '';
      notifyListeners();
    }
    active.value = i;
    _lock = true;
    _lockTimer?.cancel();
    _lockTimer = Timer(const Duration(milliseconds: 750), () => _lock = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients || i >= _sections.length) return;
      final pos = scroll.position;
      final to = math.min(
        pos.maxScrollExtent,
        math.max(0.0, _sections[i].start - 2),
      );
      scroll.animateTo(
        to,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }


  @override
  void dispose() {
    _disposed = true;
    _lockTimer?.cancel();
    // Отправленное за этот показ — в снимок для следующего.
    unawaited(warmUp(source));
    scroll.removeListener(_spy);
    scroll.dispose();
    search.dispose();
    searchFocus.dispose();
    active.dispose();
    gate.dispose();
    super.dispose();
  }
}

// ─── Рейка ──────────────────────────────────────────────────────────────────

class StickerPackRail extends StatelessWidget {
  const StickerPackRail({
    super.key,
    required this.model,
    required this.style,
    required this.onUninstall,
  });

  final StickerTabModel model;
  final EmojiPanelStyle style;

  /// Удержание значка поставленного набора — снять набор (с вопросом).
  final ValueChanged<SecretlyStickerPack> onUninstall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final secs = model.buildSections(l10n);
        return PanelRail(
          style: style,
          // Премиум-разделы — последними, их значки у лупы.
          count: model.railCount(secs),
          active: model.active,
          clampActive: false,
          indicatorHeight: 38,
          indicatorRadius: 14,
          minItemWidth: 44,
          semanticLabels: [for (final s in secs) s.title],
          onTap: (i) {
            HapticFeedback.selectionClick();
            model.jump(i);
          },
          onLongPress: (i) {
            final p = secs[i].pack;
            if (p != null &&
                p.origin == SecretlyStickerPackOrigin.remote &&
                p.installed &&
                !model.isOwn(p)) {
              onUninstall(p);
            }
          },
          itemBuilder: (context, i, active) {
            final sec = secs[i];
            switch (sec.kind) {
              case PanelStickerSectionKind.recent:
                return PanelRailIcon(
                  style: style,
                  icon: Icons.watch_later_rounded,
                  activeIcon: Icons.watch_later_rounded,
                  active: active,
                  size: 22,
                );
              case PanelStickerSectionKind.favorites:
                return PanelRailIcon(
                  style: style,
                  icon: Icons.star_rounded,
                  activeIcon: Icons.star_rounded,
                  active: active,
                  size: 22,
                );
              case PanelStickerSectionKind.pack:
              case PanelStickerSectionKind.results:
                final pack = sec.pack!;
                return AnimatedOpacity(
                  opacity: active ? 1 : .5,
                  duration: const Duration(milliseconds: 250),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PanelStickerThumb(sticker: pack.iconSticker, size: 28),
                      if (model.source.isPackBusy(pack))
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: SecretlySpinner(
                              strokeWidth: 1.4,
                              color: style.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
            }
          },
        );
      },
    );
  }
}

// ─── Сетка ──────────────────────────────────────────────────────────────────

class StickerGridPage extends StatefulWidget {
  const StickerGridPage({
    super.key,
    required this.model,
    required this.style,
    required this.onSend,
    this.onCreate,
    this.onAddToPack,
  });

  final StickerTabModel model;
  final EmojiPanelStyle style;

  /// Отправить; [from] — клетка (для полёта), `null` — из меню превью.
  final void Function(SecretlyStickerDescriptor sticker, Rect? from) onSend;

  /// «Создать» — клетка в «Недавних».
  final VoidCallback? onCreate;

  /// «+» в окне своего набора — стикер сразу в этот набор.
  final ValueChanged<String>? onAddToPack;

  @override
  State<StickerGridPage> createState() => StickerGridPageState();
}

class StickerGridPageState extends State<StickerGridPage>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey _scrollKey = GlobalKey(debugLabel: 'emoji-panel:stickers');
  final ValueNotifier<_PreviewState?> _preview = ValueNotifier(null);
  OverlayEntry? _previewEntry;
  bool _longPressed = false;

  // Быстрая прокрутка — пауза анимаций.
  final Stopwatch _clock = Stopwatch()..start();
  int _lastMs = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _closePreview();
    _preview.dispose();
    super.dispose();
  }

  StickerTabModel get _m => widget.model;

  void _snack(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SecretlySnackBar(content: Text(text)));
  }

  // ── Превью ──

  void _openPreview(SecretlyStickerDescriptor s, PanelStickerSection sec) {
    HapticFeedback.mediumImpact();
    _preview.value = _PreviewState(sticker: s, section: sec, dragging: true);
    if (_previewEntry != null) return;
    final entry = OverlayEntry(
      builder: (ctx) => _StickerPreviewOverlay(
        state: _preview,
        style: widget.style,
        isFavorite: _m.source.isFavorite,
        isOwnPack: (sec) =>
            sec.pack != null &&
            _m.isOwn(sec.pack) &&
            sec.pack!.id != _m.source.favoritesPackId,
        onClose: _closePreview,
        onAction: _onPreviewAction,
      ),
    );
    _previewEntry = entry;
    Overlay.of(context).insert(entry);
  }

  void _closePreview() {
    final e = _previewEntry;
    _previewEntry = null;
    if (e != null && e.mounted) e.remove();
    if (mounted) _preview.value = null;
  }

  void _dragTo(Offset global) {
    final cur = _preview.value;
    if (cur == null) return;
    final box = _scrollKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final hit = _m.hit(box.globalToLocal(global));
    if (hit == null || identical(hit.sticker, cur.sticker)) return;
    HapticFeedback.selectionClick();
    _preview.value = _PreviewState(
      sticker: hit.sticker,
      section: hit.section,
      dragging: true,
    );
  }

  void _release() {
    final cur = _preview.value;
    if (cur == null) return;
    _preview.value = _PreviewState(
      sticker: cur.sticker,
      section: cur.section,
      dragging: false,
    );
  }

  Future<void> _onPreviewAction(String action) async {
    final cur = _preview.value;
    _closePreview();
    if (cur == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final s = cur.sticker;
    final pack = cur.section.pack;
    final src = _m.source;
    try {
      switch (action) {
        case 'send':
          widget.onSend(s, null);
          return;
        case 'favorite':
          await src.addFavorite(s, favoritesTitle: l10n.stickerFavoritesPackTitle);
          _snack(l10n.stickerAddedToFavorites);
        case 'unfavorite':
          await src.removeFavorite(s.stickerId);
          _snack(l10n.stickerRemovedFromFavorites);
        case 'cover':
          await src.setCover(packId: pack!.id, stickerId: s.stickerId);
          _snack(l10n.stickerPackCoverUpdated);
        case 'delete':
          final ok = await confirmSecretlyStickerDelete(
            context,
            packTitle: pack!.title,
            isLast: pack.stickers.length <= 1,
          );
          if (!ok) return;
          await src.deleteFromPack(packId: pack.id, stickerId: s.stickerId);
      }
    } catch (e) {
      _snack(l10n.stickerSaveFailed('$e'));
    }
    if (mounted) await _m.reload();
  }

  // ── Наборы ──

  Future<void> uninstall(SecretlyStickerPack pack) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => SecretlyAlertDialog(
        title: Text(l10n.stickerPackRemoveTitle),
        content: Text(l10n.stickerPackRemoveBody(pack.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.stickerPackRemoveAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _m.source.uninstallPack(pack);
      if (!mounted) return;
      await _m.reload();
      _snack(l10n.stickerPackRemovedSnack(pack.title));
    } catch (e) {
      if (mounted) _snack(l10n.stickerPackRemoveFailed('$e'));
    }
  }

  Future<void> _settings(SecretlyStickerPack pack) async {
    final addTo = widget.onAddToPack;
    String? addRequested;
    await _m.source.openPackEditor(
      context,
      pack,
      onAddSticker: addTo == null ? null : () => addRequested = pack.id,
    );
    if (!mounted) return;
    await _m.reload();
    final target = addRequested;
    if (target != null) addTo?.call(target);
  }

  Future<void> _foreign(SecretlyStickerPack pack) async {
    final l10n = AppLocalizations.of(context)!;
    final remove = await showSecretlyForeignStickerPackSheet(context);
    if (!remove || !mounted) return;
    final ok = await confirmSecretlyStickerDestructive(
      context,
      title: l10n.stickerPackRemoveFromMine,
      body: l10n.stickerPackRemoveFromMineBody(pack.title),
      action: l10n.stickerPackRemoveAction,
    );
    if (!ok || !mounted) return;
    await _m.source.deleteUserPack(pack.id);
    if (mounted) await _m.reload();
  }

  // ── Прокрутка ──

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification) {
      final now = _clock.elapsedMilliseconds;
      final dt = math.max(1, now - _lastMs);
      _lastMs = now;
      final v = (n.scrollDelta ?? 0).abs() / dt * 1000;
      // Пока лента едет — все стоят картинками (24.11.2026: живые векторы
      // во время прокрутки давали 9–10 мс растра на кадр при бюджете 8,3).
      // До конца жеста: иначе на замедлении клетки мигали бы туда-обратно.
      if (v > 250) _m.gate.paused = true;
    } else if (n is ScrollEndNotification) {
      _m.gate.paused = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = widget.style;
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListenableBuilder(
          listenable: _m,
          builder: (context, _) {
            final secs = _m.buildSections(l10n);
            _m.layout(constraints.maxWidth, secs);
            final cell = StickerTabModel.cellSize(constraints.maxWidth);
            final slivers = <Widget>[
              const SliverToBoxAdapter(
                child: SizedBox(height: _StickerLayout.searchBlock),
              ),
            ];
            if (_m.loading && secs.every((x) => x.cells == 0)) {
              slivers.add(
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
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
            for (final sec in secs) {
              slivers
                ..add(
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _StickerLayout.sidePad,
                    ),
                    sliver: SliverToBoxAdapter(child: _header(sec, l10n)),
                  ),
                )
                ..addAll([
                  if (sec.emptyHint != null && sec.cells == 0)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _StickerLayout.sidePad,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _EmptyHint(style: s, text: sec.emptyHint!),
                      ),
                    ),
                  if (sec.kind == PanelStickerSectionKind.results && sec.cells == 0)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        child: Text(
                          l10n.noStickersFound,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: s.muted),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _StickerLayout.sidePad,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: kPanelStickerColumns,
                        mainAxisExtent: cell,
                        mainAxisSpacing: _StickerLayout.gap,
                        crossAxisSpacing: _StickerLayout.gap,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          if (sec.create && i == 0) {
                            return _CreateTile(
                              style: s,
                              label: l10n.stickerCreate,
                              onTap: widget.onCreate,
                            );
                          }
                          final st = sec.stickers[i - (sec.create ? 1 : 0)];
                          return _StickerCell(
                            key: ValueKey('${sec.id}/${st.lookupKey}'),
                            sticker: st,
                            size: cell - 12,
                            gate: _m.gate,
                            onTap: (rect) {
                              if (_longPressed) return;
                              widget.onSend(st, rect);
                            },
                            onLongPressStart: () {
                              _longPressed = true;
                              _openPreview(st, sec);
                            },
                            onLongPressMove: _dragTo,
                            onLongPressEnd: () {
                              _longPressed = false;
                              _release();
                            },
                          );
                        },
                        childCount: sec.cells,
                        addAutomaticKeepAlives: false,
                      ),
                    ),
                  ),
                ]);
            }
            slivers.add(
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      _StickerLayout.bottomPad + PanelBottomInset.of(context),
                ),
              ),
            );
            return NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: CustomScrollView(
                key: _scrollKey,
                controller: _m.scroll,
                physics: secretlyListPhysics(),
                cacheExtent: 80,
                slivers: slivers,
              ),
            );
          },
        );
      },
    );
  }

  Widget _header(PanelStickerSection sec, AppLocalizations l10n) {
    final s = widget.style;
    final pack = sec.pack;
    final own = _m.isOwn(pack);
    VoidCallback? onSettings;
    VoidCallback? onMore;
    if (pack != null && sec.kind != PanelStickerSectionKind.recent) {
      if (own) {
        onSettings = () => _settings(pack);
      } else {
        onMore = () => _foreign(pack);
      }
    }
    final sub = switch (sec.kind) {
      PanelStickerSectionKind.pack => l10n.emojiPanelStickerCount(sec.stickers.length),
      PanelStickerSectionKind.favorites when sec.stickers.isNotEmpty =>
        '${sec.stickers.length}',
      _ => '',
    };
    Widget small(IconData icon, String tip, VoidCallback onTap, String key) {
      return Tooltip(
        message: tip,
        child: InkResponse(
          key: ValueKey('stickers:$key:${sec.id}'),
          onTap: onTap,
          radius: 18,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: s.muted),
          ),
        ),
      );
    }

    return Container(
      height: _StickerLayout.head,
      padding: const EdgeInsets.fromLTRB(6, 6, 0, 0),
      child: Row(
        children: [
          Flexible(
            child: Text(
              sec.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: s.hdr,
              ),
            ),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(sub, style: TextStyle(fontSize: 12, color: s.muted)),
          ],
          const Spacer(),
          if (onSettings != null)
            small(
              Icons.settings_outlined,
              l10n.stickerPackSettings,
              onSettings,
              'settings',
            ),
          if (onMore != null)
            small(Icons.more_horiz_rounded, l10n.stickerMore, onMore, 'more'),
        ],
      ),
    );
  }
}

class _StickerCell extends StatefulWidget {
  const _StickerCell({
    super.key,
    required this.sticker,
    required this.size,
    required this.gate,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMove,
    required this.onLongPressEnd,
  });

  final SecretlyStickerDescriptor sticker;
  final double size;
  final StickerPlaybackGate gate;
  final ValueChanged<Rect> onTap;
  final VoidCallback onLongPressStart;
  final ValueChanged<Offset> onLongPressMove;
  final VoidCallback onLongPressEnd;

  @override
  State<_StickerCell> createState() => _StickerCellState();
}

class _StickerCellState extends State<_StickerCell> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v || !mounted) return;
    setState(() => _down = v);
  }

  Rect _rect() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: () => widget.onTap(_rect()),
      onLongPressStart: (_) {
        _set(false);
        widget.onLongPressStart();
      },
      onLongPressMoveUpdate: (d) => widget.onLongPressMove(d.globalPosition),
      onLongPressEnd: (_) => widget.onLongPressEnd(),
      onLongPressCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? .88 : 1,
        duration: const Duration(milliseconds: 350),
        curve: kPanelPressCurve,
        child: Center(
          child: PanelStickerThumb(
            sticker: widget.sticker,
            size: widget.size,
            gate: widget.gate,
          ),
        ),
      ),
    );
  }
}

/// «Создать» — первая клетка «Недавних»: «+» в скруглённом квадрате 68.
class _CreateTile extends StatelessWidget {
  const _CreateTile({required this.style, required this.label, this.onTap});

  final EmojiPanelStyle style;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = style;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: const ValueKey('stickers:create'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PanelPress(
          pressedScale: .88,
          duration: const Duration(milliseconds: 350),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: .86,
              heightFactor: .86,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: s.pill,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: s.card, width: .5),
                ),
                child: Icon(Icons.add_rounded, size: 34, color: s.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Пустое «Избранное»: пунктирная рамка и подсказка.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.style, required this.text});

  final EmojiPanelStyle style;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = style;
    return SizedBox(
      height: _StickerLayout.emptyBox,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: s.dark ? const Color(0x24FFFFFF) : const Color(0x26000000),
            radius: 16,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.35, color: s.muted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(.5),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    for (final metric in (Path()..addRRect(rr)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 5, metric.length)), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

// ─── Превью ─────────────────────────────────────────────────────────────────

class _PreviewState {
  const _PreviewState({
    required this.sticker,
    required this.section,
    required this.dragging,
  });

  final SecretlyStickerDescriptor sticker;
  final PanelStickerSection section;
  final bool dragging;
}

/// Крупное превью: размытие за ним на iPhone, затемнение на Android,
/// «дыхание» стикера (`es-idle`), всплывание при смене, меню после отпускания.
class _StickerPreviewOverlay extends StatefulWidget {
  const _StickerPreviewOverlay({
    required this.state,
    required this.style,
    required this.isFavorite,
    required this.isOwnPack,
    required this.onClose,
    required this.onAction,
  });

  final ValueListenable<_PreviewState?> state;
  final EmojiPanelStyle style;
  final bool Function(String stickerId) isFavorite;
  final bool Function(PanelStickerSection section) isOwnPack;
  final VoidCallback onClose;
  final ValueChanged<String> onAction;

  @override
  State<_StickerPreviewOverlay> createState() => _StickerPreviewOverlayState();
}

class _StickerPreviewOverlayState extends State<_StickerPreviewOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..forward();
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();
  String? _shown;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onState);
    _shown = widget.state.value?.sticker.lookupKey;
  }

  @override
  void dispose() {
    widget.state.removeListener(_onState);
    _idle.dispose();
    _pop.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _onState() {
    final k = widget.state.value?.sticker.lookupKey;
    if (k != null && k != _shown) {
      _shown = k;
      _pop.forward(from: 0);
    }
  }

  /// `es-idle`: 0 → −5° ×1,04 (25 %) → +5° ×1,04 (75 %) → 0.
  static (double, double) _idleAt(double t) {
    const deg = 3.141592653589793 / 180;
    double ease(double x) => Curves.easeInOut.transform(x.clamp(0, 1));
    if (t < .25) {
      final k = ease(t / .25);
      return (-5 * deg * k, 1 + .04 * k);
    }
    if (t < .75) {
      final k = ease((t - .25) / .5);
      return ((-5 + 10 * k) * deg, 1.04);
    }
    final k = ease((t - .75) / .25);
    return (5 * deg * (1 - k), 1.04 - .04 * k);
  }

  /// Всплывание: ×0,5 → ×1,1 (60 %) → ×1.
  static (double, double) _popAt(double raw) {
    final t = const Cubic(.3, .8, .4, 1).transform(raw);
    if (t < .6) {
      final k = t / .6;
      return (.5 + .6 * k, .3 + .7 * k);
    }
    final k = (t - .6) / .4;
    return (1.1 - .1 * k, 1);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<_PreviewState?>(
      valueListenable: widget.state,
      builder: (context, st, _) {
        if (st == null) return const SizedBox.shrink();
        final fav = widget.isFavorite(st.sticker.stickerId);
        final own = widget.isOwnPack(st.section);
        Widget backdrop = ColoredBox(color: s.overlay);
        if (s.overlayFilter != null) {
          backdrop = BackdropFilter(filter: s.overlayFilter!, child: backdrop);
        }
        Widget item(String id, IconData icon, String label, {bool danger = false}) {
          final c = danger ? s.danger : s.text;
          return _MenuRow(
            key: ValueKey('stickers:preview:$id'),
            style: s,
            icon: icon,
            label: label,
            color: c,
            onTap: () => widget.onAction(id),
          );
        }

        final menu = Container(
          width: 250,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: s.menu,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Color(0x73000000), blurRadius: 40, offset: Offset(0, 16)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item('send', Icons.send_rounded, l10n.stickerSend),
              // Встроенные наборы дизайнера — без «Избранного»: файла на
              // диске нет (стикер в сборке), а копия в своё избранное
              // сделала бы премиум-стикер «своим» в обход замка.
              if (isDesignerStickerPackId(st.sticker.packId))
                const SizedBox.shrink()
              else if (fav)
                item('unfavorite', Icons.star_rounded, l10n.stickerRemoveFromFavorites)
              else
                item('favorite', Icons.star_outline_rounded, l10n.stickerMakeFavorite),
              if (own) ...[
                item('cover', Icons.image_outlined, l10n.stickerMakeCover),
                item(
                  'delete',
                  Icons.delete_outline_rounded,
                  l10n.stickerDeleteAction,
                  danger: true,
                ),
              ],
            ],
          ),
        );
        Widget menuBox = menu;
        if (s.filter != null) {
          menuBox = ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(filter: s.filter!, child: menu),
          );
        }
        return FadeTransition(
          opacity: _fade,
          child: IgnorePointer(
            ignoring: st.dragging,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    key: const ValueKey('stickers:preview:backdrop'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onClose,
                    child: backdrop,
                  ),
                ),
                Center(
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: Listenable.merge([_idle, _pop]),
                          child: SecretlyStickerAssetView(
                            key: ValueKey(st.sticker.lookupKey),
                            sticker: st.sticker,
                            size: 180,
                          ),
                          builder: (context, child) {
                            final (rot, sc) = _idleAt(_idle.value);
                            final (ps, po) = _popAt(_pop.value);
                            return Opacity(
                              opacity: po.clamp(0, 1),
                              child: Transform.rotate(
                                angle: rot,
                                child: Transform.scale(scale: sc * ps, child: child),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          st.section.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: s.dark || s.overlayFilter == null
                                ? const Color(0xFFE3EAF1)
                                : s.text,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedOpacity(
                          opacity: st.dragging ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            l10n.emojiPanelPreviewHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: s.dark || s.overlayFilter == null
                                  ? const Color(0xFFC4CFDA)
                                  : s.muted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedOpacity(
                          opacity: st.dragging ? 0 : 1,
                          duration: const Duration(milliseconds: 200),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: st.dragging ? 0 : 1),
                            duration: const Duration(milliseconds: 400),
                            curve: kPanelMenuCurve,
                            child: menuBox,
                            builder: (context, t, child) => Transform.translate(
                              offset: Offset(0, 14 * (1 - t)),
                              child: Transform.scale(
                                scale: .94 + .06 * t,
                                alignment: Alignment.topCenter,
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({
    super.key,
    required this.style,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final EmojiPanelStyle style;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _down ? widget.style.menuHover : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 22, color: widget.color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: widget.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
