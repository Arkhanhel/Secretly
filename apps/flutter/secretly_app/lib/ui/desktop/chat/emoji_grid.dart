// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';
import '../../emoji/emoji_search_index.dart' show filterEmojiByQuery;
import '../../emoji/noto_emoji_catalog.dart'
    show
        kNotoCategories,
        kNotoCategoryOrder,
        kNotoCodepoints,
        kNotoSkinToneHidden,
        kNotoSkinToneVariants;
import '../design/tokens.dart';
import '../primitives/hover_listener.dart';

/// Ключ недавних эмодзи окна выбора в переписке.
const String kDesktopEmojiRecentsKey = 'desktop_emoji_recents_v1';

/// Ключ недавних эмодзи-статусов.
const String kDesktopStatusRecentsKey = 'desktop_status_recents_v1';

/// Недавние эмодзи — по ключу, последние сверху.
///
/// 🔴 Раздел «Недавние» в окне выбора ПК был, но не показывался НИКОГДА:
/// список передавал вызывающий, а не передавал никто (29.09.2026). Теперь
/// сетка ведёт его сама.
abstract final class DesktopEmojiRecents {
  static const int max = 32;

  static Future<List<String>> load(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(key) ?? const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  static Future<List<String>> record(String key, String emoji) async {
    final next = <String>[emoji, ...(await load(key)).where((e) => e != emoji)];
    if (next.length > max) next.removeRange(max, next.length);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, next);
    } catch (_) {}
    return next;
  }
}

/// Подпись категории общего каталога — строками ПК, 8 языков.
///
/// 🔴 Раньше заголовки брались из `kNotoCategoryLabelsRu` и печатались
/// капсом: в английском и немецком окне стояли русские слова.
String desktopEmojiCategoryLabel(AppLocalizations l10n, String slug) {
  switch (slug) {
    case 'smileys_and_emotions':
      return l10n.desktopEmojiSmileys;
    case 'people':
      return l10n.desktopEmojiPeople;
    case 'animals_and_nature':
      return l10n.desktopEmojiNature;
    case 'food_and_drink':
      return l10n.desktopEmojiFood;
    case 'travel_and_places':
      return l10n.desktopEmojiTravel;
    case 'activities_and_events':
      return l10n.desktopEmojiActivities;
    case 'objects':
      return l10n.desktopEmojiObjects;
    case 'symbols':
      return l10n.desktopEmojiSymbols;
    case 'flags':
      return l10n.desktopEmojiFlags;
  }
  return l10n.desktopEmojiOther;
}

IconData _categoryIcon(String slug) {
  switch (slug) {
    case _kRecentsSlug:
      return FluentIcons.history_24_regular;
    case 'smileys_and_emotions':
      return FluentIcons.emoji_24_regular;
    case 'people':
      return FluentIcons.person_24_regular;
    case 'animals_and_nature':
      return FluentIcons.animal_cat_24_regular;
    case 'food_and_drink':
      return FluentIcons.food_24_regular;
    case 'travel_and_places':
      return FluentIcons.vehicle_car_24_regular;
    case 'activities_and_events':
      return FluentIcons.sport_soccer_24_regular;
    case 'objects':
      return FluentIcons.lightbulb_24_regular;
    case 'symbols':
      return FluentIcons.heart_24_regular;
    case 'flags':
      return FluentIcons.flag_24_regular;
  }
  return FluentIcons.symbols_24_regular;
}

const String _kRecentsSlug = '_recents';

/// Каталог по категориям в порядке производителя, без вариантов тона.
///
/// Тона спрятаны под свой базовый символ: 👍 лежит в каталоге шестью
/// записями, и без этого сетка на треть состояла бы из одной руки. Это тот же
/// набор, что у телефона: 611 знаков.
List<({String slug, List<String> emoji})> desktopEmojiCatalogGroups({
  String query = '',
}) {
  final buckets = <String, List<String>>{
    for (final slug in kNotoCategoryOrder) slug: <String>[],
  };
  for (final emoji in kNotoCodepoints.keys) {
    if (kNotoSkinToneHidden.contains(emoji)) continue;
    final slug = kNotoCategories[emoji] ?? 'symbols';
    (buckets[slug] ??= <String>[]).add(emoji);
  }
  final q = query.trim();
  return [
    for (final slug in kNotoCategoryOrder)
      if ((q.isEmpty ? buckets[slug]! : filterEmojiByQuery(buckets[slug]!, q))
          case final list when list.isNotEmpty)
        (slug: slug, emoji: list),
  ];
}

/// Сетка эмодзи ПК: весь общий каталог телефона, ленивая, с полосой
/// категорий и «Недавними» (29.09.2026).
///
/// Её берут и окно эмодзи в переписке, и выбор эмодзи-статуса — один набор,
/// один вид, одни недавние на двоих экранах быть не должны (у каждого свой
/// ключ [recentsKey]).
///
/// Знаки рисуются ТЕКСТОМ, а не анимацией: шестьсот проигрывателей Lottie в
/// одном окне — это шестьсот запросов кадра. Так же поступает телефон;
/// оживают эмодзи уже в переписке.
class DesktopEmojiGrid extends StatefulWidget {
  const DesktopEmojiGrid({
    super.key,
    required this.onPicked,
    this.query = '',
    this.recentsKey,
    this.selected,
    this.cell = 40,
    this.glyph = 26,
    this.showCategoryBar = true,
  });

  final ValueChanged<String> onPicked;
  final String query;

  /// Куда записывать выбранное; `null` — без раздела «Недавние».
  final String? recentsKey;

  /// Подсвеченный знак (текущий статус).
  final String? selected;
  final double cell;
  final double glyph;
  final bool showCategoryBar;

  @override
  State<DesktopEmojiGrid> createState() => _DesktopEmojiGridState();
}

class _DesktopEmojiGridState extends State<DesktopEmojiGrid> {
  static const double _headerHeight = 28;
  static const double _sectionGap = 6;
  static const double _hPad = DSpace.s;

  final ScrollController _scroll = ScrollController();
  List<String> _recents = const <String>[];

  @override
  void initState() {
    super.initState();
    final key = widget.recentsKey;
    if (key != null) {
      DesktopEmojiRecents.load(key).then((r) {
        if (mounted) setState(() => _recents = r);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _pick(String emoji) {
    final key = widget.recentsKey;
    if (key != null) DesktopEmojiRecents.record(key, emoji);
    widget.onPicked(emoji);
  }

  List<({String slug, List<String> emoji})> _sections() {
    final groups = desktopEmojiCatalogGroups(query: widget.query);
    if (widget.query.trim().isNotEmpty || _recents.isEmpty) return groups;
    return [(slug: _kRecentsSlug, emoji: _recents), ...groups];
  }

  double _sectionExtent(int count, int columns) =>
      _headerHeight + (count / columns).ceil() * widget.cell + _sectionGap;

  void _jumpTo(
    List<({String slug, List<String> emoji})> sections,
    int index,
    int columns,
  ) {
    var offset = 0.0;
    for (var i = 0; i < index; i++) {
      offset += _sectionExtent(sections[i].emoji.length, columns);
    }
    final max = _scroll.position.maxScrollExtent;
    _scroll.animateTo(
      math.min(offset, max),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final sections = _sections();
    if (sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DSpace.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.emoji_24_regular, size: 48, color: c.textDisabled),
              const SizedBox(height: DSpace.s),
              Text(
                l10n.desktopEmojiNothingFound,
                style: DType.caption.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          1,
          ((constraints.maxWidth - _hPad * 2) / widget.cell).floor(),
        );
        final grid = CustomScrollView(
          controller: _scroll,
          slivers: [
            for (final s in sections) ...[
              SliverToBoxAdapter(
                child: Container(
                  height: _headerHeight,
                  padding: const EdgeInsets.fromLTRB(_hPad + 4, 8, _hPad, 0),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    s.slug == _kRecentsSlug
                        ? l10n.desktopEmojiRecents
                        : desktopEmojiCategoryLabel(l10n, s.slug),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DType.caption.copyWith(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_hPad, 0, _hPad, _sectionGap),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: widget.cell,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _EmojiCell(
                      emoji: s.emoji[i],
                      size: widget.cell,
                      glyph: widget.glyph,
                      selected: s.emoji[i] == widget.selected,
                      onPicked: _pick,
                    ),
                    childCount: s.emoji.length,
                  ),
                ),
              ),
            ],
          ],
        );
        if (!widget.showCategoryBar || widget.query.trim().isNotEmpty) {
          return grid;
        }
        return Column(
          children: [
            SizedBox(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < sections.length; i++)
                    Tooltip(
                      message: sections[i].slug == _kRecentsSlug
                          ? l10n.desktopEmojiRecents
                          : desktopEmojiCategoryLabel(l10n, sections[i].slug),
                      waitDuration: const Duration(milliseconds: 500),
                      child: HoverListener(
                        onTap: () => _jumpTo(sections, i, columns),
                        builder: (ctx, hovered, pressed) => Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: hovered ? c.hover : Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            _categoryIcon(sections[i].slug),
                            size: 18,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(height: 1, color: c.borderSubtle),
            Expanded(child: grid),
          ],
        );
      },
    );
  }
}

class _EmojiCell extends StatelessWidget {
  const _EmojiCell({
    required this.emoji,
    required this.size,
    required this.glyph,
    required this.selected,
    required this.onPicked,
  });

  final String emoji;
  final double size;
  final double glyph;
  final bool selected;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final tones = kNotoSkinToneVariants[emoji];
    return HoverListener(
      onTap: () => onPicked(emoji),
      // Тон кожи — правой кнопкой. На телефоне его выбирают нажатием по
      // знаку; здесь щелчок сразу вставляет знак, как в Telegram Desktop, а
      // правая кнопка спрашивает «а какие ещё бывают».
      onSecondaryTapDown: tones == null
          ? null
          : (d) => _pickSkinTone(context, tones, d.globalPosition),
      builder: (ctx, hovered, pressed) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? c.accentPrimary.withValues(alpha: 0.20)
              : (hovered ? c.hover : null),
          borderRadius: BorderRadius.circular(DRadii.md),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: glyph, height: 1.0)),
            // Точка в углу — единственный намёк, что у знака есть тона.
            if (tones != null)
              Positioned(
                right: 3,
                bottom: 3,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSkinTone(
    BuildContext context,
    List<String> tones,
    Offset at,
  ) async {
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        for (final variant in <String>[emoji, ...tones])
          PopupMenuItem<String>(
            value: variant,
            height: 40,
            child: Text(variant, style: TextStyle(fontSize: glyph)),
          ),
      ],
    );
    if (picked != null) onPicked(picked);
  }
}
