// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Страница эмодзи: девять в ряд (слово владельца; в макете восемь), разделы с
/// заголовками, поиск по словам, тон кожи удержанием (тон запоминается),
/// недавние — обновляются при закрытии панели, а не под пальцем.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../emoji/emoji_search_index.dart' show filterEmojiByQuery;
import '../../scroll_feel.dart';
import '../../emoji/noto_emoji_catalog.dart'
    show kNotoCategories, kNotoSkinToneVariants;
import '../solo_emoji_fx.dart' show hasSoloEmojiEffect;
import 'emoji_panel_prefs.dart';
import 'emoji_panel_rail.dart';
import 'emoji_panel_style.dart';
import 'emoji_panel_widgets.dart';

/// Эмодзи в ряд.
const int kPanelEmojiColumns = 9;

/// Раздел каталога (подпись уже переведена).
typedef EmojiPanelCategory = ({String label, List<String> emoji});

/// Числа раскладки — общие для отрисовки и для «где какой раздел».
abstract final class _EmojiLayout {
  static const double sidePad = 8;
  // Поиск — в верхней строке панели (22.11.2026), здесь только отступ.
  static const double searchBlock = 4;
  static const double sectionHead = 32; // 4 + 28
  static const double bottomPad = 12;
}

/// Состояние страницы эмодзи — живёт в панели, рейка и сетка читают его.
class EmojiTabModel extends ChangeNotifier {
  EmojiTabModel({required this.categories, required this.profileKey}) {
    _all = [for (final c in categories) ...c.emoji];
    scroll.addListener(_spy);
    unawaited(_load());
  }

  final List<EmojiPanelCategory> categories;
  final String profileKey;
  late final List<String> _all;

  final ScrollController scroll = ScrollController();
  final TextEditingController search = TextEditingController();
  final FocusNode searchFocus = FocusNode(debugLabel: 'emoji-panel:search');

  /// Подсвеченный раздел рейки.
  final ValueNotifier<int> active = ValueNotifier<int>(0);

  List<String> recents = const <String>[];
  Map<String, String> tones = <String, String>{};
  String query = '';

  /// Выбранные за этот показ панели — уйдут в недавние при закрытии.
  final List<String> _pending = <String>[];

  double _width = 0;
  List<double> _starts = const <double>[];
  bool _lock = false;
  Timer? _lockTimer;
  bool _disposed = false;

  Future<void> _load() async {
    final r = await EmojiPanelPrefs.loadRecents(profileKey);
    final t = await EmojiPanelPrefs.loadTones(profileKey);
    if (_disposed) return;
    recents = r;
    tones = t;
    notifyListeners();
  }

  bool get showRecents => recents.isNotEmpty;

  /// Разделы, как они стоят в ленте (и в рейке).
  int get railCount => categories.length + (showRecents ? 1 : 0);

  /// Слаг раздела рейки (для значка): `recent` или категория Noto.
  String railSlug(int i) {
    if (showRecents) {
      if (i == 0) return 'recent';
      i -= 1;
    }
    final c = categories[i];
    return c.emoji.isEmpty ? 'symbols' : (kNotoCategories[c.emoji.first] ?? 'symbols');
  }

  String railLabel(int i, AppLocalizations l10n) {
    if (showRecents) {
      if (i == 0) return l10n.desktopEmojiRecents;
      i -= 1;
    }
    return categories[i].label;
  }

  List<({String label, List<String> emoji})> sections(AppLocalizations l10n) {
    if (query.isNotEmpty) {
      final found = filterEmojiByQuery(_all, query);
      if (found.isEmpty) return const [];
      return [(label: l10n.emojiPanelResults, emoji: found)];
    }
    return [
      if (showRecents) (label: l10n.desktopEmojiRecents, emoji: recents),
      ...categories,
    ];
  }

  /// Что вставить: выбранный тон или сама основа.
  String display(String base) => tones[base] ?? base;

  bool toneable(String base) => kNotoSkinToneVariants.containsKey(base);

  void setQuery(String q) {
    final next = q.trim().toLowerCase();
    if (next == query) return;
    query = next;
    if (scroll.hasClients) scroll.jumpTo(0);
    notifyListeners();
  }

  void picked(String base) {
    _pending
      ..remove(base)
      ..insert(0, base);
  }

  void setTone(String base, String variant) {
    tones = <String, String>{...tones, base: variant};
    unawaited(EmojiPanelPrefs.saveTones(profileKey, tones));
    notifyListeners();
  }

  /// Недавние — при закрытии панели или смене раздела.
  void flush() {
    if (_pending.isEmpty) return;
    recents = EmojiPanelPrefs.merge(List<String>.of(_pending), recents);
    _pending.clear();
    unawaited(EmojiPanelPrefs.saveRecents(profileKey, recents));
    if (!_disposed) notifyListeners();
  }

  /// Пересчёт начала каждого раздела при ширине [width].
  void layout(double width, List<({String label, List<String> emoji})> secs) {
    _width = width;
    final cell = cellSize(width);
    final starts = <double>[];
    var y = _EmojiLayout.searchBlock;
    for (final s in secs) {
      starts.add(y);
      y += _EmojiLayout.sectionHead +
          (s.emoji.length / kPanelEmojiColumns).ceil() * cell;
    }
    _starts = starts;
  }

  static double cellSize(double width) =>
      (width - _EmojiLayout.sidePad * 2) / kPanelEmojiColumns;

  void _spy() {
    if (_lock || !scroll.hasClients || query.isNotEmpty) return;
    final pos = scroll.position;
    var idx = 0;
    for (var k = 0; k < _starts.length; k++) {
      if (_starts[k] - 40 <= pos.pixels) idx = k;
    }
    if (pos.pixels >= pos.maxScrollExtent - 4 && _starts.isNotEmpty) {
      idx = _starts.length - 1;
    }
    if (active.value != idx) active.value = idx;
  }

  /// Тап по значку: плавно к разделу.
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
      if (!scroll.hasClients || i >= _starts.length) return;
      final pos = scroll.position;
      final to = math.min(pos.maxScrollExtent, math.max(0.0, _starts[i] - 2));
      scroll.animateTo(
        to,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }


  double get width => _width;

  @override
  void dispose() {
    _disposed = true;
    flush();
    _lockTimer?.cancel();
    scroll.removeListener(_spy);
    scroll.dispose();
    search.dispose();
    searchFocus.dispose();
    active.dispose();
    super.dispose();
  }
}

/// Значки рейки эмодзи (Material Symbols макета, заливка у выбранного).
({IconData icon, IconData active}) emojiRailIcon(String slug) => switch (slug) {
  'recent' => (icon: Icons.watch_later_outlined, active: Icons.watch_later_rounded),
  'smileys_and_emotions' => (
    icon: Icons.emoji_emotions_outlined,
    active: Icons.emoji_emotions_rounded,
  ),
  'people' => (icon: Icons.waving_hand_outlined, active: Icons.waving_hand_rounded),
  'animals_and_nature' => (icon: Icons.pets_outlined, active: Icons.pets_rounded),
  'food_and_drink' => (
    icon: Icons.restaurant_outlined,
    active: Icons.restaurant_rounded,
  ),
  'travel_and_places' => (
    icon: Icons.directions_car_outlined,
    active: Icons.directions_car_rounded,
  ),
  'activities_and_events' => (
    icon: Icons.sports_basketball_outlined,
    active: Icons.sports_basketball_rounded,
  ),
  'objects' => (icon: Icons.lightbulb_outline_rounded, active: Icons.lightbulb_rounded),
  'flags' => (icon: Icons.flag_outlined, active: Icons.flag_rounded),
  _ => (icon: Icons.favorite_border_rounded, active: Icons.favorite_rounded),
};

/// Рейка разделов эмодзи.
class EmojiCategoryRail extends StatelessWidget {
  const EmojiCategoryRail({super.key, required this.model, required this.style});

  final EmojiTabModel model;
  final EmojiPanelStyle style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final n = model.railCount;
        return PanelRail(
          style: style,
          count: n,
          active: model.active,
          semanticLabels: [for (var i = 0; i < n; i++) model.railLabel(i, l10n)],
          onTap: (i) {
            HapticFeedback.selectionClick();
            model.jump(i);
          },
          itemBuilder: (context, i, active) {
            final ic = emojiRailIcon(model.railSlug(i));
            return PanelRailIcon(
              style: style,
              icon: ic.icon,
              activeIcon: ic.active,
              active: active,
            );
          },
        );
      },
    );
  }
}

/// Сетка эмодзи.
class EmojiGridPage extends StatefulWidget {
  const EmojiGridPage({
    super.key,
    required this.model,
    required this.style,
    required this.onPick,
  });

  final EmojiTabModel model;
  final EmojiPanelStyle style;

  /// Выбран эмодзи [emoji]; [from] — прямоугольник клетки (для полёта).
  final void Function(String emoji, Rect from) onPick;

  @override
  State<EmojiGridPage> createState() => _EmojiGridPageState();
}

class _EmojiGridPageState extends State<EmojiGridPage>
    with AutomaticKeepAliveClientMixin {
  OverlayEntry? _tone;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _closeTone();
    super.dispose();
  }

  void _closeTone() {
    final e = _tone;
    _tone = null;
    if (e != null && e.mounted) e.remove();
  }

  void _pick(String base, Rect from) {
    if (_tone != null) {
      _closeTone();
      return;
    }
    final m = widget.model;
    m.picked(base);
    widget.onPick(m.display(base), from);
  }

  void _openTone(String base, Rect cell) {
    _closeTone();
    final variants = kNotoSkinToneVariants[base];
    if (variants == null) return;
    HapticFeedback.selectionClick();
    final overlay = Overlay.of(context);
    final box = overlay.context.findRenderObject()! as RenderBox;
    final local = Rect.fromPoints(
      box.globalToLocal(cell.topLeft),
      box.globalToLocal(cell.bottomRight),
    );
    final list = <String>[base, ...variants];
    final w = list.length * 44.0 + 8;
    final left = (local.center.dx - w / 2).clamp(4.0, box.size.width - w - 4);
    final top = math.max(4.0, local.top - 56);
    final s = widget.style;
    final current = widget.model.display(base);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeTone,
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: _TonePopup(
              style: s,
              list: list,
              current: current,
              onPick: (variant) {
                _closeTone();
                final m = widget.model;
                m.setTone(base, variant);
                m.picked(base);
                widget.onPick(variant, cell);
              },
            ),
          ),
        ],
      ),
    );
    _tone = entry;
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = widget.style;
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListenableBuilder(
          listenable: widget.model,
          builder: (context, _) {
            final m = widget.model;
            final secs = m.sections(l10n);
            m.layout(constraints.maxWidth, secs);
            final cell = EmojiTabModel.cellSize(constraints.maxWidth);
            return NotificationListener<ScrollStartNotification>(
              onNotification: (_) {
                _closeTone();
                return false;
              },
              child: CustomScrollView(
                key: const ValueKey('emoji-panel:emoji-scroll'),
                controller: m.scroll,
                physics: secretlyListPhysics(),
                slivers: [
                  const SliverToBoxAdapter(
                    child: SizedBox(height: _EmojiLayout.searchBlock),
                  ),
                  if (secs.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
                        child: Text(
                          l10n.emojiPanelNothingFound,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: s.muted),
                        ),
                      ),
                    ),
                  for (final sec in secs) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        _EmojiLayout.sidePad,
                        4,
                        _EmojiLayout.sidePad,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: PanelSectionLabel(text: sec.label, style: s),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _EmojiLayout.sidePad,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: kPanelEmojiColumns,
                          mainAxisExtent: cell,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final base = sec.emoji[i];
                            return _EmojiCell(
                              key: ValueKey(base),
                              base: base,
                              shown: m.display(base),
                              toneMark: m.toneable(base) ? s.toneMark : null,
                              onTap: _pick,
                              onLongPress: m.toneable(base) ? _openTone : null,
                            );
                          },
                          childCount: sec.emoji.length,
                          addAutomaticKeepAlives: false,
                        ),
                      ),
                    ),
                  ],
                  // Под островками внизу — последний ряд выезжает над ними.
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height:
                          _EmojiLayout.bottomPad + PanelBottomInset.of(context),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Серая точка на эмодзи с расширенной анимацией отдельным сообщением
/// (23.11.2026). `false` — без точек.
const bool kEmojiPanelFxDot = true;

class _EmojiCell extends StatefulWidget {
  const _EmojiCell({
    super.key,
    required this.base,
    required this.shown,
    required this.toneMark,
    required this.onTap,
    required this.onLongPress,
  });

  final String base;
  final String shown;
  final Color? toneMark;
  final void Function(String base, Rect from) onTap;
  final void Function(String base, Rect from)? onLongPress;

  @override
  State<_EmojiCell> createState() => _EmojiCellState();
}

class _EmojiCellState extends State<_EmojiCell> {
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
      onTap: () => widget.onTap(widget.base, _rect()),
      onLongPressStart: widget.onLongPress == null
          ? null
          : (_) {
              _set(false);
              widget.onLongPress!(widget.base, _rect());
            },
      child: AnimatedScale(
        scale: _down ? 1.3 : 1,
        duration: const Duration(milliseconds: 350),
        curve: kPanelEmojiPressCurve,
        child: PanelEmojiGlyph(
          emoji: widget.shown,
          toneMark: widget.toneMark,
          fxDot: kEmojiPanelFxDot && hasSoloEmojiEffect(widget.shown)
              ? const Color(0x998E8E93)
              : null,
        ),
      ),
    );
  }
}

/// Выбор тона кожи (`es-pop`): основа и пять тонов, выбранный подсвечен.
class _TonePopup extends StatelessWidget {
  const _TonePopup({
    required this.style,
    required this.list,
    required this.current,
    required this.onPick,
  });

  final EmojiPanelStyle style;
  final List<String> list;
  final String current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final s = style;
    Widget body = Container(
      key: const ValueKey('emoji-panel:tone-popup'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: s.menu,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 12)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in list)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: GestureDetector(
                key: ValueKey('emoji-panel:tone:$e'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onPick(e),
                child: PanelPress(
                  pressedScale: 1.15,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: e == current
                          ? (s.dark ? const Color(0x29FFFFFF) : const Color(0x14000000))
                          : null,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: PanelEmojiGlyph(emoji: e, scale: .66),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (s.filter != null) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(filter: s.filter!, child: body),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: kPanelPopCurve,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(
          scale: .4 + .6 * t,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
      child: Material(type: MaterialType.transparency, child: body),
    );
  }
}
