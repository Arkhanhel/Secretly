// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Reactions picker, PR3.8 / PR3.9 rewrite (2026-05-19,
// SPRINT2_AUDIT §13 / §14).
//
// Telegram-style flow:
//   • Default state — a compact horizontal row of 7 «quick» reactions with
//     a chevron-down expand button on the right. Height ≈ 52 px.
//   • Expand state — the same popover grows downward (or upward, depending
//     on anchor side) into a 9-section scrollable grid with a sticky
//     category header strip and a left-rail jump column. Height ≈ 360 px.
//
// Implementation notes:
//   • We don't reuse `DesktopPopover.show` because its position is fixed at
//     open time based on a static popover size — once we grow vertically
//     in place, the popover would float in empty space above the bubble.
//     Instead this file owns its own [Overlay]-driven popover via
//     `showGeneralDialog`, computes the bottom-anchored position so the
//     popover ALWAYS touches the same edge of the anchor regardless of
//     whether it's in compact or expanded mode.
//   • PR3.9: the expanded grid is now a [CustomScrollView] with one
//     [SliverPersistentHeader] + [SliverGrid] per category from the upstream
//     Noto manifest (`kDesktopNotoCategoryOrder`). A persistent left rail
//     mounts representative emoji icons that animate-scroll to the section
//     via a precomputed `slug → y-offset` map. A top «Недавние» section is
//     synthesized from [DesktopRecentReactionsStore] when non-empty.
//   • Picking any emoji (compact OR expanded) pops the popover with the
//     emoji string. Dismiss (click outside / esc) pops with null.
//   • [QuickReactionRow] is the same compact row factored out as a public
//     widget so the right-click `ContextMenu` can mount it above the menu
//     items without the wrapper popover (mobile / Telegram parity).

import '../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../design/tokens.dart';
import 'noto_emoji_lottie.dart';
import 'recent_reactions_store.dart';

/// Visual side the popover should anchor to. Same enum-shape as
/// `PopoverSide` so existing callers can keep their semantics; we keep our
/// own copy here so this file doesn't depend on `desktop_popover.dart`.
enum ReactionsAnchorSide { above, below }

/// Quick-row emojis. Mirrors mobile + the inline bubble hover-bar.
const List<String> kQuickReactionsRow = <String>[
  '❤️',
  '👍',
  '😂',
  '😮',
  '😢',
  '🔥',
  '🎉',
];

/// Sentinel passed through `onPicked` when the user taps the chevron to
/// expand. Hosts that mount [QuickReactionRow] directly inside a context
/// menu listen for this value and open the full [ReactionsPopover] in
/// expanded mode.
const String kQuickReactionsExpandSentinel = '__expand__';

class ReactionsPopover {
  ReactionsPopover._();

  /// Opens the picker anchored to [anchorKey]. Starts collapsed; the user
  /// can grow it inline by tapping the chevron. Returns the picked emoji
  /// or null on dismiss.
  static Future<String?> show(
    BuildContext context, {
    required GlobalKey anchorKey,
    ReactionsAnchorSide side = ReactionsAnchorSide.above,
    bool startExpanded = false,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true)
        .context
        .findRenderObject() as RenderBox?;
    final anchorBox =
        anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null || anchorBox == null) return Future.value(null);

    final anchorTL = anchorBox.localToGlobal(Offset.zero, ancestor: overlay);
    final anchorSize = anchorBox.size;
    final screenSize = overlay.size;

    return showGeneralDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'reactions',
      transitionDuration: DMotion.fast,
      pageBuilder: (ctx, anim, _) {
        return _ReactionsScaffold(
          anchorTL: anchorTL,
          anchorSize: anchorSize,
          screenSize: screenSize,
          side: side,
          startExpanded: startExpanded,
          animation: anim,
        );
      },
      transitionBuilder: (ctx, a, b, child) => child,
    );
  }
}

class _ReactionsScaffold extends StatefulWidget {
  const _ReactionsScaffold({
    required this.anchorTL,
    required this.anchorSize,
    required this.screenSize,
    required this.side,
    required this.startExpanded,
    required this.animation,
  });

  final Offset anchorTL;
  final Size anchorSize;
  final Size screenSize;
  final ReactionsAnchorSide side;
  final bool startExpanded;
  final Animation<double> animation;

  @override
  State<_ReactionsScaffold> createState() => _ReactionsScaffoldState();
}

class _ReactionsScaffoldState extends State<_ReactionsScaffold> {
  static const double _kWidth = 360;
  static const double _kCompactH = 52;
  static const double _kExpandedH = 360;
  static const double _kGap = 8;

  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.startExpanded;
  }

  /// Computed popover x position. We center horizontally on the anchor's
  /// midpoint, then clamp so the card stays on-screen.
  double get _x {
    final centred =
        widget.anchorTL.dx + widget.anchorSize.width / 2 - _kWidth / 2;
    final maxX = widget.screenSize.width - _kWidth - 8;
    return centred.clamp(8.0, maxX < 8.0 ? 8.0 : maxX);
  }

  /// Computed popover y position. The popover always touches the same
  /// edge of the anchor — if [side] == above, the popover's BOTTOM edge
  /// sits at `anchorTL.dy - gap`; growth happens upward as the height
  /// changes. If `below`, the TOP edge sits at `anchorTL.dy + anchorH + gap`
  /// and growth happens downward. We clamp so the card never overflows.
  double get _y {
    final h = _expanded ? _kExpandedH : _kCompactH;
    if (widget.side == ReactionsAnchorSide.above) {
      final desired = widget.anchorTL.dy - h - _kGap;
      if (desired < 8) {
        // Doesn't fit above — flip below.
        return (widget.anchorTL.dy + widget.anchorSize.height + _kGap)
            .clamp(8.0, widget.screenSize.height - h - 8);
      }
      return desired;
    }
    final desired = widget.anchorTL.dy + widget.anchorSize.height + _kGap;
    if (desired + h > widget.screenSize.height - 8) {
      // Doesn't fit below — flip above.
      return (widget.anchorTL.dy - h - _kGap).clamp(8.0, double.infinity);
    }
    return desired;
  }

  void _onPicked(String emoji) {
    Navigator.of(context).maybePop<String>(emoji);
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _DismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _DismissIntent: CallbackAction<_DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Stack(
          children: [
            // Click-outside dismiss.
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox.expand(),
            ),
            AnimatedPositioned(
              duration: DMotion.fast,
              curve: DMotion.easeOutCubic,
              left: _x,
              top: _y,
              width: _kWidth,
              height: _expanded ? _kExpandedH : _kCompactH,
              child: AnimatedBuilder(
                animation: widget.animation,
                builder: (ctx, child) {
                  final t = Curves.easeOutBack
                      .transform(widget.animation.value.clamp(0.0, 1.0));
                  return Opacity(
                    opacity: widget.animation.value,
                    child: Transform.scale(
                      scale: 0.94 + 0.06 * t,
                      alignment:
                          widget.side == ReactionsAnchorSide.above
                              ? Alignment.bottomCenter
                              : Alignment.topCenter,
                      child: child,
                    ),
                  );
                },
                child: _Card(
                  c: c,
                  child: _expanded
                      ? _ExpandedGrid(
                          onPicked: _onPicked,
                          onCollapse: _toggleExpanded,
                        )
                      : _CompactRow(
                          onPicked: _onPicked,
                          onExpand: _toggleExpanded,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.c, required this.child});
  final DColorSet c;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.elevated,
          borderRadius: BorderRadius.circular(DRadii.lg),
          border: Border.all(color: c.borderSubtle),
          boxShadow: DShadows.popover,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// Compact horizontal row of 7 quick reactions + an expand chevron.
///
/// Public widget so the right-click `ContextMenu` can mount the same row
/// above its menu items without going through [ReactionsPopover.show] (no
/// nested popovers, no double-dismiss handling).
///
/// The host passes [onPicked] which fires either with one of [kQuickReactionsRow]
/// (the user clicked an emoji) or with [kQuickReactionsExpandSentinel] (the
/// user tapped the chevron — host should open the full picker).
class QuickReactionRow extends StatelessWidget {
  const QuickReactionRow({
    super.key,
    required this.onPicked,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  });

  final ValueChanged<String> onPicked;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.elevated,
          borderRadius: BorderRadius.circular(DRadii.pill),
          border: Border.all(color: c.borderSubtle),
          boxShadow: DShadows.popover,
        ),
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in kQuickReactionsRow)
              _QuickReactBtn(emoji: e, onTap: () => onPicked(e)),
            Container(
              width: 1,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: c.borderSubtle,
            ),
            _ExpandBtn(
              onTap: () => onPicked(kQuickReactionsExpandSentinel),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.onPicked, required this.onExpand});
  final ValueChanged<String> onPicked;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final e in kQuickReactionsRow)
            _QuickReactBtn(emoji: e, onTap: () => onPicked(e)),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: c.borderSubtle,
          ),
          _ExpandBtn(onTap: onExpand),
        ],
      ),
    );
  }
}

class _QuickReactBtn extends StatefulWidget {
  const _QuickReactBtn({required this.emoji, required this.onTap});
  final String emoji;
  final VoidCallback onTap;
  @override
  State<_QuickReactBtn> createState() => _QuickReactBtnState();
}

class _QuickReactBtnState extends State<_QuickReactBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: DMotion.fast,
          curve: DMotion.easeOutBack,
          scale: _h ? 1.3 : 1.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: isAnimatableNotoEmoji(widget.emoji)
                    ? NotoEmojiLottie(
                        emoji: widget.emoji,
                        size: 24,
                        mode: NotoLottieMode.looping,
                      )
                    : Text(
                        widget.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandBtn extends StatefulWidget {
  const _ExpandBtn({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_ExpandBtn> createState() => _ExpandBtnState();
}

class _ExpandBtnState extends State<_ExpandBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 32,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _h ? c.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(DRadii.pill),
          ),
          child: Icon(
            FluentIcons.chevron_down_24_regular,
            size: 18,
            color: c.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Expanded scrollable picker. PR3.9: split into category sections with a
/// sticky header per slug + a vertical left-rail of representative icons
/// that animate-scrolls the grid to the corresponding section. A top
/// «Недавние» section is rendered when [DesktopRecentReactionsStore] has
/// entries; the store is updated from `chat_thread_panel._applyReaction`.
class _ExpandedGrid extends StatefulWidget {
  const _ExpandedGrid({required this.onPicked, required this.onCollapse});
  final ValueChanged<String> onPicked;
  final VoidCallback onCollapse;

  @override
  State<_ExpandedGrid> createState() => _ExpandedGridState();
}

class _ExpandedGridState extends State<_ExpandedGrid> {
  // Grid geometry — also used to precompute scroll offsets for the
  // left-rail jump targets.
  static const int _kCols = 8;
  static const double _kHeaderH = 28;
  static const double _kRowH = 34;
  static const double _kGridPadV = 6;
  static const String _kRecentsSlug = '__recents__';

  /// Representative emoji per category for the left rail. Picked to be
  /// instantly recognisable; covered by `kDesktopNotoCodepoints` so the
  /// rail renders as a Lottie preview rather than text.
  static const Map<String, String> _kRailEmoji = <String, String>{
    'smileys_and_emotions': '😀',
    'people': '👌',
    'animals_and_nature': '🐶',
    'food_and_drink': '🍔',
    'travel_and_places': '✈️',
    'activities_and_events': '⚽',
    'objects': '💡',
    'symbols': '❤️',
    'flags': '🏳️',
  };

  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtl = TextEditingController();
  String _q = '';
  List<String> _recents = const <String>[];
  late final List<String> _allEmojis;
  late final Map<String, List<String>> _bySlug;
  late Map<String, double> _offsetBySlug;

  @override
  void initState() {
    super.initState();
    _bySlug = <String, List<String>>{
      for (final s in kDesktopNotoCategoryOrder) s: <String>[],
    };
    kDesktopNotoCategories.forEach((emoji, slug) {
      (_bySlug[slug] ??= <String>[]).add(emoji);
    });
    _allEmojis = kDesktopNotoCodepoints.keys.toList(growable: false);
    _recents = DesktopRecentReactionsStore.instance.current;
    _offsetBySlug = _computeOffsets();
    // PR3.10: subscribe to the store so the «Недавние» section refreshes
    // live within a single picker session. Keeps the SharedPreferences
    // round-trip off the open-popover hot path (the store is eager-loaded
    // at app boot — see main_desktop.dart).
    DesktopRecentReactionsStore.instance.addListener(_onRecentsChanged);
    // Defensive: if for some reason the boot-time load didn't run yet,
    // kick it now. `load()` is idempotent.
    DesktopRecentReactionsStore.instance.load();
  }

  void _onRecentsChanged() {
    if (!mounted) return;
    final next = DesktopRecentReactionsStore.instance.current;
    // Only rebuild when the visible row really changed — every record()
    // notifies even when the new emoji is already in the set further back.
    final unchanged = next.length == _recents.length &&
        (_recents.isEmpty || next.first == _recents.first);
    if (unchanged) return;
    setState(() {
      _recents = next;
      _offsetBySlug = _computeOffsets();
    });
  }

  @override
  void dispose() {
    DesktopRecentReactionsStore.instance.removeListener(_onRecentsChanged);
    _scroll.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  /// Precompute the vertical offset of every section header inside the
  /// `CustomScrollView`. The rail uses these to animate-scroll to a slug.
  /// Numbers track the SliverGrid geometry below; if you change padding or
  /// cell size, update [_kHeaderH], [_kRowH], [_kGridPadV] in lockstep.
  Map<String, double> _computeOffsets() {
    final m = <String, double>{};
    double y = 0;
    if (_recents.isNotEmpty) {
      m[_kRecentsSlug] = y;
      final rows = (_recents.length / _kCols).ceil();
      y += _kHeaderH + rows * _kRowH + _kGridPadV * 2;
    }
    for (final slug in kDesktopNotoCategoryOrder) {
      m[slug] = y;
      final count = _bySlug[slug]?.length ?? 0;
      final rows = (count / _kCols).ceil();
      y += _kHeaderH + rows * _kRowH + _kGridPadV * 2;
    }
    return m;
  }

  void _jumpTo(String slug) {
    final y = _offsetBySlug[slug];
    if (y == null || !_scroll.hasClients) return;
    _scroll.animateTo(
      y.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  List<String> _filterAll() {
    final q = _q.toLowerCase();
    return _allEmojis.where((e) {
      if (e.contains(_q)) return true;
      final cp = kDesktopNotoCodepoints[e] ?? '';
      return cp.contains(q);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final searching = _q.isNotEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onCollapse,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      FluentIcons.chevron_up_24_regular,
                      size: 18,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: c.thread,
                    borderRadius: BorderRadius.circular(DRadii.pill),
                    border: Border.all(color: c.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        FluentIcons.search_24_regular,
                        size: 14,
                        color: c.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: (v) => setState(() => _q = v),
                          style: DType.caption.copyWith(color: c.textPrimary),
                          cursorColor: c.accentPrimary,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 6),
                            hintText: l10n.desktopEmojiSearchShort,
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
        Container(height: 1, color: c.borderSubtle),
        Expanded(
          child: Row(
            children: [
              // Left rail — fixed column of category jump buttons. Hidden
              // when searching so the matches grid gets the full width.
              if (!searching)
                _CategoryRail(
                  onJump: _jumpTo,
                ),
              if (!searching)
                Container(width: 1, color: c.borderSubtle),
              Expanded(
                child: Scrollbar(
                  controller: _scroll,
                  thumbVisibility: true,
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: _buildSlivers(c, searching),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSlivers(DColorSet c, bool searching) {
    final l10n = AppLocalizations.of(context)!;
    if (searching) {
      // PR3.10 (SPRINT2_AUDIT §15): sectioned search. Group matches by
      // their category slug so the user can tell `🐶 dog` from `🌭 hot dog`
      // (different sections) at a glance. Iterating in manifest order
      // preserves the same vertical layout as the non-search view.
      final groups = _groupBySlug(_filterAll());
      if (groups.isEmpty) {
        return <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.desktopListNothingFound,
                  style: DType.caption.copyWith(color: c.textSecondary),
                ),
              ),
            ),
          ),
        ];
      }
      final slivers = <Widget>[];
      for (final slug in kDesktopNotoCategoryOrder) {
        final list = groups[slug];
        if (list == null || list.isEmpty) continue;
        final label = desktopNotoCategoryLabel(slug, l10n);
        slivers.addAll(_sectionSlivers(c, label, list));
      }
      return slivers;
    }
    final slivers = <Widget>[];
    if (_recents.isNotEmpty) {
      slivers.addAll(_sectionSlivers(c, l10n.desktopEmojiRecents, _recents));
    }
    for (final slug in kDesktopNotoCategoryOrder) {
      final list = _bySlug[slug] ?? const <String>[];
      if (list.isEmpty) continue;
      final label = desktopNotoCategoryLabel(slug, l10n);
      slivers.addAll(_sectionSlivers(c, label, list));
    }
    return slivers;
  }

  /// Bucket [matches] by their `kDesktopNotoCategories` slug, preserving
  /// original iteration order within each bucket. Emojis without a slug
  /// (shouldn't happen against the manifest-generated map but we guard
  /// anyway) bucket under `'other'`.
  Map<String, List<String>> _groupBySlug(List<String> matches) {
    final m = <String, List<String>>{};
    for (final e in matches) {
      final slug = kDesktopNotoCategories[e] ?? 'other';
      (m[slug] ??= <String>[]).add(e);
    }
    return m;
  }

  Iterable<Widget> _sectionSlivers(
    DColorSet c,
    String label,
    List<String> emojis,
  ) sync* {
    yield SliverPersistentHeader(
      pinned: true,
      delegate: _SectionHeader(label: label, c: c),
    );
    yield SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _kCols,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final e = emojis[i];
            return _GridEmojiBtn(
              emoji: e,
              onTap: () => widget.onPicked(e),
            );
          },
          childCount: emojis.length,
        ),
      ),
    );
  }
}

/// Sticky section header sliver. Constant height ([_kHeaderH] = 28) so it
/// matches the offset math in `_ExpandedGridState._computeOffsets`.
class _SectionHeader extends SliverPersistentHeaderDelegate {
  _SectionHeader({required this.label, required this.c});
  final String label;
  final DColorSet c;

  @override
  double get minExtent => 28;
  @override
  double get maxExtent => 28;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 28,
      padding: const EdgeInsets.only(left: 10, right: 6),
      color: c.elevated,
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: DType.caption.copyWith(
          color: c.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SectionHeader oldDelegate) {
    return oldDelegate.label != label || oldDelegate.c != c;
  }
}

/// Vertical strip of category icons on the left edge of the expanded
/// picker. Tapping a button calls [onJump] with the upstream slug; the
/// host animate-scrolls the grid to the corresponding section.
class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.onJump});
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: <Widget>[
          for (final slug in kDesktopNotoCategoryOrder)
            _RailBtn(
              slug: slug,
              emoji: _ExpandedGridState._kRailEmoji[slug] ?? '⭐',
              onTap: () => onJump(slug),
            ),
        ],
      ),
    );
  }
}

class _RailBtn extends StatefulWidget {
  const _RailBtn({
    required this.slug,
    required this.emoji,
    required this.onTap,
  });
  final String slug;
  final String emoji;
  final VoidCallback onTap;

  @override
  State<_RailBtn> createState() => _RailBtnState();
}

class _RailBtnState extends State<_RailBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: desktopNotoCategoryLabel(widget.slug, l10n),
          waitDuration: const Duration(milliseconds: 400),
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _h ? c.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(DRadii.sm),
            ),
            child: isAnimatableNotoEmoji(widget.emoji)
                ? NotoEmojiLottie(
                    emoji: widget.emoji,
                    size: 20,
                    mode: NotoLottieMode.preview,
                  )
                : Text(
                    widget.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
          ),
        ),
      ),
    );
  }
}

class _GridEmojiBtn extends StatefulWidget {
  const _GridEmojiBtn({required this.emoji, required this.onTap});
  final String emoji;
  final VoidCallback onTap;
  @override
  State<_GridEmojiBtn> createState() => _GridEmojiBtnState();
}

class _GridEmojiBtnState extends State<_GridEmojiBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: DMotion.fast,
          curve: Curves.easeOutBack,
          scale: _h ? 1.18 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: _h ? c.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(DRadii.sm),
            ),
            alignment: Alignment.center,
            // Preview-mode Lottie = first frame only, so the grid doesn't
            // jitter with 800 concurrent animations.
            child: SizedBox(
              width: 30,
              height: 30,
              child: NotoEmojiLottie(
                emoji: widget.emoji,
                size: 26,
                mode: NotoLottieMode.preview,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}
