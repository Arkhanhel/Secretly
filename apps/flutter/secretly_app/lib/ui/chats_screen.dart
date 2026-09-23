// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:animations/animations.dart' as material_motion;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_controller.dart';
import '../rooms/room_call_state.dart';
import '../security/app_security_manager.dart';
import 'animations/animations.dart';
import 'app_asset_paths.dart';
import 'app_brand_logo.dart';
import 'call_history_screen.dart';
import 'chat_screen.dart';
import 'own_device_removed_banner.dart';
import 'delivery_health_banner.dart';
import 'contact_details_screen.dart';
import 'desktop_chats_workspace.dart';
import 'desktop_surface_policy.dart';
import 'emoji/noto_status_emoji.dart';
import 'premium/cosmetic_animation_scope.dart';
import 'premium/cosmetic_motion_gate.dart';
import 'favorites_title.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'new_chat_picker_screen.dart';
import 'new_group_screen.dart';
import 'personal_chats_screen.dart';
import 'room_call_screen.dart';
import 'room_details_screen.dart';
import 'security_lock_flow.dart';
import 'security_settings_screen.dart';
import 'shared_audio_controls.dart';
import 'theme_transition.dart';
import 'wave1_l10n.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/framed_avatar.dart';
import 'widgets/chat_list_subtitle_preview.dart';
import 'widgets/content_edge_fade.dart';
import 'widgets/dismiss_keyboard_on_tap.dart';
import 'widgets/premium_glass.dart';
import 'widgets/secretly_glass_fab.dart';
// Prefixed: `glass_kit` (already used on this screen) exports its own
// GlassContainer, so the two collide unqualified.
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;
import 'liquid_glass_flags.dart';
import 'scroll_feel.dart';
import 'widgets/frosted_header_island.dart';
import 'widgets/liquid_glass_segment.dart';
import 'widgets/frosted_top_bar.dart';
import 'widgets/typing_dots.dart';
import 'widgets/room_call_return_banner.dart';
import 'widgets/broken_media_box.dart';
import 'haptics.dart';

/// Smart-sorting modes for the Chats tab list (PART 2). Persisted by name to
/// SharedPreferences so an unknown/legacy value fails safe back to [byTime].
enum _ChatsSortMode { byTime, unreadFirst, pinnedFirst }

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({
    super.key,
    required this.controller,
    this.desktopShellTab = 0,
  });

  final AppController controller;
  final int desktopShellTab;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen>
    with TickerProviderStateMixin {
  static const String _noteIconAssetPath = AppAssetPaths.favoritesNotebookSvg;
  // The pull-down gesture now drives ONLY the "Personal" reveal (search is
  // tap-only). So the full pull extent is just the personal travel.
  static const double _personalPullMax = 252;
  static const double _pullExtentMax = _personalPullMax;
  static const double _pullOpenDamping = 0.76;
  static const double _pullCloseDamping = 0.48;
  static const double _collapsedTopListGap = 14;
  static const double _expandedTopListGap = 6;
  // Top-bar matte islands (chat-header style).
  static const double _kListIslandHeight = 48;
  static const double _kListIslandRadius = 24;
  // Wider so the three header icons (search / sort / more) sit harmoniously
  // without crowding inside the frosted island.
  static const double _kListActionsIslandWidth = 128;

  // Chat folders + smart sorting (local to this screen, no DB; persisted to
  // SharedPreferences). Fail-safe defaults: folder = 'all', sort = by time.
  static const String _kFolderPrefsKey = 'secretly_chats_folder_v1';
  // Pinned folder strip height: 40 segment + fromLTRB(14,2,14,6) padding.
  static const double _kFolderStripHeight = 40 + 2 + 6;
  static const String _kSortPrefsKey = 'secretly_chats_sort_v1';
  // _activeFolder is either 'all' or a custom folder id from
  // controller.customChatFolders. Anything else fails safe to 'all'.
  String _activeFolder = 'all';
  // Direction of the last folder switch (+1 = moved right, -1 = left). Drives
  // the AnimatedSwitcher slide so the chat list pages the way the finger went.
  int _folderNavDir = 1;
  _ChatsSortMode _sortMode = _ChatsSortMode.byTime;

  // Cache of custom-folder membership (folderId -> set of convoIds), filled
  // lazily and refreshed whenever controller.changed fires (see _onChanged).
  // The filter is fail-safe: an unknown / not-yet-loaded folder shows all chats
  // until its membership resolves.
  final Map<String, Set<String>> _folderMembers = <String, Set<String>>{};
  String _lastKnownFolderIdsSig = '';

  final Set<String> _selected = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _listScrollController = ScrollController();
  bool _searchOpen = false;
  String _searchQuery = '';
  Timer? _searchDebounce;
  int _searchVersion = 0;
  bool _searchingMessages = false;
  Set<String> _messageMatchedConvoIds = const <String>{};
  double _pullExtent = 0;
  bool _isClosingPull = false;
  // True while the Personal reveal is fully open AT REST. In this state the
  // chats list is locked (NeverScrollable) and a dedicated vertical-drag handler
  // drives the close — otherwise, with a long (scrollable) list, the list
  // scrolls instead of closing the reveal (the swipe-up-to-close bug).
  bool _personalOpenLocked = false;
  bool _personalWasFullyOpen = false;
  bool _lockListScrollUntilDragEnd = false;
  bool _fabVisible = true;
  double _dragOpenCap = _pullExtentMax;
  late final AnimationController _pullSnapController;
  late final AnimationController _personalCollapseController;
  // Where the in-flight pull snap is headed (null when idle). Lets the swipe
  // handler tell "snapping OPEN" from "snapping CLOSED" so a swipe-up during
  // the opening animation can reverse it instantly from its current position.
  double? _pullSnapTarget;
  // Tap-only search bubble expansion (0 = closed, 1 = open).
  late final AnimationController _searchRevealController;
  // Drives the bubble morph of the top islands between normal and selection
  // mode (0 = normal, 1 = selection). The same persistent island plates reshape
  // (width + content cross-fade) instead of two island sets being swapped.
  late final AnimationController _selectionRevealController;
  Animation<double>? _pullSnapAnimation;

  // PERF (tab-switch flash): the FutureBuilder below rebuilds a fresh future on
  // every build() (e.g. when `controller.changed` fires, or when this page is
  // re-shown after a tab switch), which momentarily resets the snapshot to
  // null and would paint an EMPTY list for ~1 s until the DB reload resolves.
  // Cache the last successful result and fall back to it while the next load is
  // in flight so the list stays visible (Telegram-style instant re-show). This
  // only affects what is shown DURING the reload window — data correctness is
  // unchanged because the resolved future always overwrites the cache.
  List<Conversation> _lastConvos = const <Conversation>[];
  Map<String, int> _lastMissedByConvo = const <String, int>{};
  // Memoized conversations query — recomputed only when controller.changeVersion
  // changes (a real data change), NOT on every rebuild. Stops re-querying the DB
  // + re-entering the FutureBuilder loading state on every animation frame (e.g.
  // the "Личные" sheet reveal).
  Future<(List<Conversation>, Map<String, int>)>? _convosFuture;
  int _convosFutureVersion = -1;
  // Тот же приём, что и у `_convosFuture`, и по той же причине. Баннер
  // «вернуться в звонок» строился новым Future прямо в `build`, а внутри —
  // запрос снимка на КАЖДУЮ активную комнату. При анимации раскрытия «Личных»
  // это давало запросы в БД на каждом кадре: сама анимация оплачивала чтение
  // хранилища. Ключ — `changeVersion` плюс список чатов, потому что заголовок
  // баннера берётся из них.
  Future<(CachedRoomCall?, String)>? _roomCallBannerFuture;
  int _roomCallBannerVersion = -1;
  int _roomCallBannerConvosHash = 0;
  // COLD START (2026-07-28, field report "чаты пустые, после перезахода
  // появляются"): the list falls back to `_lastConvos` while the query is in
  // flight, and on a COLD start that cache is empty — so an unfinished first
  // load was indistinguishable from "this user has no chats" and we rendered the
  // "Чатов пока нет" placeholder. The first query can take seconds when the DB is
  // busy applying an inbound backlog (busy_timeout is 7 s), which is exactly when
  // a user opens the app after a while. This flag separates "never loaded yet"
  // from "loaded, genuinely empty": until the first result arrives we show a
  // spinner instead of the wrong empty state.
  bool _convosEverLoaded = false;

  // Search reveal is tap-only now — driven by its own controller, NOT the pull
  // gesture. The pull gesture maps straight into the Personal reveal.
  double get _searchRevealRaw => _searchRevealController.value.clamp(0.0, 1.0);
  double get _personalRevealRaw =>
      (_pullExtent / _personalPullMax).clamp(0.0, 1.0);
  double get _searchReveal => Curves.easeOutCubic.transform(_searchRevealRaw);
  double get _selectionRevealRaw =>
      _selectionRevealController.value.clamp(0.0, 1.0);
  // easeOutBack overshoots slightly past 1.0 near the end → the "soap bubble"
  // pop on the island widths. Opacity callers clamp it to [0,1].
  double get _selectionReveal =>
      Curves.easeOutBack.transform(_selectionRevealRaw);
  double get _personalReveal {
    final visualProgress = (_personalRevealRaw / 0.88).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(visualProgress);
  }

  double get _personalCollapseProgress =>
      _personalCollapseController.value.clamp(0.0, 1.0);

  bool get _selectionMode => _selected.isNotEmpty;

  // Coalesced view of controller.changed — see _coalesceChanged().
  late final Stream<void> _coalescedChanged;
  StreamSubscription<void>? _coalescedChangedSub;

  Future<void> _openCallHistory() async {
    await Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => CallHistoryScreen(controller: widget.controller),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _coalescedChanged = _coalesceChanged(widget.controller.changed);
    _pullSnapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          final animation = _pullSnapAnimation;
          if (animation == null || !mounted) return;
          setState(() {
            _pullExtent = animation.value.clamp(0.0, _pullExtentMax);
          });
          _updatePersonalRevealEffects();
        });
    _personalCollapseController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 320),
        )..addListener(() {
          if (!mounted) return;
          setState(() {});
        });
    _searchRevealController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          if (!mounted) return;
          setState(() {});
        });
    _selectionRevealController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 340),
        )..addListener(() {
          if (!mounted) return;
          setState(() {});
        });
    unawaited(_loadFolderAndSortPrefs());
  }

  /// PERF: coalesces the controller's `changed` firehose for this screen —
  /// typing / presence / read receipts can tick several times per second, and
  /// each tick used to rebuild the whole chats screen. Leading edge passes
  /// through instantly (a new message shows with zero added latency); ticks
  /// arriving within the window collapse into a single trailing emit, so the
  /// final state always lands.
  Stream<void> _coalesceChanged(Stream<void> source) {
    const window = Duration(milliseconds: 180);
    final out = StreamController<void>.broadcast();
    Timer? gate;
    var pendingTrailing = false;
    _coalescedChangedSub = source.listen((_) {
      if (gate == null) {
        out.add(null);
        gate = Timer(window, () {
          gate = null;
          if (pendingTrailing) {
            pendingTrailing = false;
            out.add(null);
          }
        });
      } else {
        pendingTrailing = true;
      }
    });
    out.onCancel = () {
      gate?.cancel();
      gate = null;
    };
    return out.stream;
  }

  // Restore the persisted folder + sort selection. Any error or unknown stored
  // value is swallowed and leaves the fail-safe defaults ('all' / by time).
  Future<void> _loadFolderAndSortPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final folder = prefs.getString(_kFolderPrefsKey);
      final sort = prefs.getString(_kSortPrefsKey);
      if (!mounted) return;
      setState(() {
        // 'all' or a custom folder id. The custom id is validated against the
        // live folder list at render time (see _applyFolderAndSort), so a stale
        // id simply falls back to 'all'.
        if (folder != null && folder.isNotEmpty) {
          _activeFolder = folder;
        }
        _sortMode = _ChatsSortMode.values
            .where((m) => m.name == sort)
            .firstOrNull ??
            _ChatsSortMode.byTime;
      });
    } catch (_) {
      // Keep fail-safe defaults.
    }
  }

  /// Keeps [_folderMembers] in sync with the controller's current custom
  /// folders. Drops cache entries for folders that no longer exist, fetches
  /// membership for folders we haven't loaded yet, and (only when the set of
  /// folder ids actually changed) re-runs once per change to pick up edits.
  /// Fail-safe: any error leaves the previous cache untouched.
  void _syncFolderMembersCache() {
    final folders = widget.controller.customChatFolders;
    final ids = folders.map((f) => f.id).toList(growable: false);
    final sig = ids.join('|');
    final idSet = ids.toSet();
    // Prune cache entries for deleted folders.
    _folderMembers.keys
        .where((k) => !idSet.contains(k))
        .toList(growable: false)
        .forEach(_folderMembers.remove);
    final signatureChanged = sig != _lastKnownFolderIdsSig;
    _lastKnownFolderIdsSig = sig;
    // Load membership for any folder we don't have cached, OR refresh all when
    // the folder-id set changed (covers create + membership edits via
    // updateChatFolder, which also bumps controller.changed).
    for (final id in ids) {
      if (signatureChanged || !_folderMembers.containsKey(id)) {
        unawaited(_loadFolderMembers(id));
      }
    }
  }

  Future<void> _loadFolderMembers(String id) async {
    try {
      final members = await widget.controller.folderMemberConvoIds(id);
      if (!mounted) return;
      final next = members.toSet();
      final existing = _folderMembers[id];
      if (existing != null &&
          existing.length == next.length &&
          existing.containsAll(next)) {
        return; // No change — avoid a needless rebuild.
      }
      setState(() => _folderMembers[id] = next);
    } catch (_) {
      // Fail-safe: leave the folder unfiltered (shows all) until it resolves.
    }
  }

  /// The pinned island stack under the top bar: folder strip, then the music /
  /// call island. Extracted so it can be rendered either standalone or as
  /// shapes inside one shared glass layer (see [SecretlyGlassGroup]).
  Widget _pinnedIslandColumn(BuildContext context, AppController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller.customChatFolders.isNotEmpty)
          _ChatsFolderTabStrip(
            activeFolder: _activeFolder,
            folders: controller.customChatFolders,
            allLabel: wave1Text(
              context,
              ru: 'Все',
              en: 'All',
              uk: 'Усі',
              es: 'Todos',
              pt: 'Todos',
              ptBr: 'Todos',
              fr: 'Tous',
              de: 'Alle',
            ),
            onSelect: _setActiveFolder,
            onFolderLongPress: _openFolderChipMenu,
          ),
        SharedAudioTopIslands(controller: controller),
      ],
    );
  }

  Future<void> _setActiveFolder(String folder) async {
    if (_activeFolder == folder) return;
    // Pick the page-slide direction from the tab order ['all', ...folders].
    final ids = <String>[
      'all',
      ...widget.controller.customChatFolders.map((f) => f.id),
    ];
    final oldIdx = ids.indexOf(_activeFolder);
    final newIdx = ids.indexOf(folder);
    setState(() {
      if (oldIdx >= 0 && newIdx >= 0) {
        _folderNavDir = newIdx >= oldIdx ? 1 : -1;
      }
      _activeFolder = folder;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFolderPrefsKey, folder);
    } catch (_) {
      // Non-fatal: selection still applies for this session.
    }
  }

  Future<void> _setSortMode(_ChatsSortMode mode) async {
    if (_sortMode == mode) return;
    setState(() => _sortMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSortPrefsKey, mode.name);
    } catch (_) {
      // Non-fatal: selection still applies for this session.
    }
  }

  /// Applies the active folder filter (PART 1) and smart-sort comparator
  /// (PART 2) to the already-computed visible list. Pure + additive: returns a
  /// new list and never mutates [base].
  List<Conversation> _applyFolderAndSort(List<Conversation> base) {
    Iterable<Conversation> result = base;
    // Custom-folder filter. 'all' (or an unknown id) leaves the list untouched.
    // A known folder keeps only its members; while membership is still loading
    // (no cache entry yet) we fail safe to showing everything.
    if (_activeFolder != 'all') {
      final members = _folderMembers[_activeFolder];
      if (members != null) {
        result = result.where((c) => members.contains(c.convoId));
      }
    }
    final list = result.toList(growable: false);
    switch (_sortMode) {
      case _ChatsSortMode.byTime:
        // Keep the DB order (already pinned-then-time). No re-sort.
        return list;
      case _ChatsSortMode.unreadFirst:
        final sorted = [...list];
        sorted.sort((a, b) {
          final au = a.unreadCount > 0 ? 1 : 0;
          final bu = b.unreadCount > 0 ? 1 : 0;
          if (au != bu) return bu - au; // unread first
          return b.lastEventAtMs.compareTo(a.lastEventAtMs);
        });
        return sorted;
      case _ChatsSortMode.pinnedFirst:
        final sorted = [...list];
        sorted.sort((a, b) {
          final ap = a.pinnedAtMs;
          final bp = b.pinnedAtMs;
          if (ap != null && bp != null) {
            final cmp = bp.compareTo(ap); // most-recently pinned first
            if (cmp != 0) return cmp;
          } else if (ap != null) {
            return -1; // pinned before unpinned (nulls last)
          } else if (bp != null) {
            return 1;
          }
          return b.lastEventAtMs.compareTo(a.lastEventAtMs);
        });
        return sorted;
    }
  }

  String _sortModeLabel(BuildContext context, _ChatsSortMode mode) {
    switch (mode) {
      case _ChatsSortMode.byTime:
        return wave1Text(
          context,
          ru: 'По времени',
          en: 'By time',
          uk: 'За часом',
          es: 'Por hora',
          pt: 'Por hora',
          ptBr: 'Por hora',
          fr: 'Par date',
          de: 'Nach Zeit',
        );
      case _ChatsSortMode.unreadFirst:
        return wave1Text(
          context,
          ru: 'Сначала непрочитанные',
          en: 'Unread first',
          uk: 'Спершу непрочитані',
          es: 'No leidos primero',
          pt: 'Nao lidos primeiro',
          ptBr: 'Nao lidos primeiro',
          fr: 'Non lus d abord',
          de: 'Ungelesene zuerst',
        );
      case _ChatsSortMode.pinnedFirst:
        return wave1Text(
          context,
          ru: 'Сначала закреплённые',
          en: 'Pinned first',
          uk: 'Спершу закріплені',
          es: 'Fijados primero',
          pt: 'Fixados primeiro',
          ptBr: 'Fixados primeiro',
          fr: 'Epingles d abord',
          de: 'Angeheftete zuerst',
        );
    }
  }

  Future<void> _openSortMenu() async {
    final selected = await showFrostedPopup<_ChatsSortMode>(
      context: context,
      alignment: Alignment.topRight,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: FrostedPopupContainer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 230,
                      maxWidth: 280,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final mode in _ChatsSortMode.values)
                          _GlassMenuAction(
                            leading: Icon(
                              _sortMode == mode
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 22,
                              color: _sortMode == mode
                                  ? kPremiumGold
                                  : cs.onSurface.withValues(alpha: 0.55),
                            ),
                            title: _sortModeLabel(context, mode),
                            onTap: () => Navigator.of(context).pop(mode),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    await _setSortMode(selected);
  }

  void _clearSearchState() {
    _searchController.clear();
    _searchQuery = '';
    _messageMatchedConvoIds = const <String>{};
    _searchingMessages = false;
  }

  void _stopPullSnap() {
    if (_pullSnapController.isAnimating) {
      _pullSnapController.stop();
    }
    _pullSnapTarget = null;
  }

  void _resetPersonalCollapse() {
    if (_personalCollapseController.isAnimating) {
      _personalCollapseController.stop();
    }
    if (_personalCollapseController.value != 0) {
      _personalCollapseController.value = 0;
    }
  }

  void _startPersonalCollapseIfNeeded() {
    if (_personalCollapseController.isAnimating ||
        _personalCollapseController.value > 0.001) {
      return;
    }
    _personalCollapseController.forward(from: 0);
  }

  void _updatePersonalRevealEffects() {
    final fullyOpen = _personalReveal >= 0.995;
    final fullyClosed = _personalRevealRaw <= 0.001;
    final leftOpenState = _personalReveal < 0.985;

    if (fullyOpen) {
      if (!_personalWasFullyOpen) {
        _personalWasFullyOpen = true;
        unawaited(widget.controller.triggerUiHaptic());
      }
      if (!_isClosingPull) {
        _startPersonalCollapseIfNeeded();
      }
      return;
    }

    if (fullyClosed && _personalWasFullyOpen) {
      _personalWasFullyOpen = false;
      unawaited(widget.controller.triggerUiHaptic());
      _resetPersonalCollapse();
      return;
    }

    if (leftOpenState) {
      _resetPersonalCollapse();
    }
  }

  void _resetPersonalRevealFeedback() {
    _personalWasFullyOpen = false;
    _resetPersonalCollapse();
  }

  void _animatePullToExtent(double target) {
    final clamped = target.clamp(0.0, _pullExtentMax);
    // Lock the list only when fully open AT REST (so the swipe-up close is
    // handled by the dedicated drag handler, not eaten by list scrolling).
    final willLock = clamped >= (_pullExtentMax - 0.001);
    if ((_pullExtent - clamped).abs() < 0.001) {
      setState(() {
        _pullExtent = clamped;
        _personalOpenLocked = willLock;
      });
      _updatePersonalRevealEffects();
      return;
    }

    _stopPullSnap();
    final opensPersonalFully = clamped >= (_pullExtentMax - 0.001);
    _pullSnapController.duration = Duration(
      milliseconds: clamped < _pullExtent
          ? 340
          : (opensPersonalFully ? 460 : 300),
    );
    _pullSnapAnimation = Tween<double>(begin: _pullExtent, end: clamped)
        .animate(
          CurvedAnimation(
            parent: _pullSnapController,
            curve: clamped < _pullExtent
                ? Curves.easeOutQuart
                : Curves.easeOutCubic,
          ),
        );

    _pullSnapTarget = clamped;
    _pullSnapController
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted) return;
        _pullSnapTarget = null;
        setState(() => _personalOpenLocked = willLock);
        _updatePersonalRevealEffects();
      });
  }

  void _toggleSelected(String convoId) {
    setState(() {
      if (_selected.contains(convoId)) {
        _selected.remove(convoId);
      } else {
        _selected.add(convoId);
        if (_searchOpen) {
          _searchOpen = false;
          _searchRevealController.value = 0;
          _clearSearchState();
          _searchFocusNode.unfocus();
        }
      }
    });
    _syncSelectionReveal();
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _fabVisible = true;
    });
    _syncSelectionReveal();
  }

  // Animate the island bubble morph to match the current selection state.
  // The controller stays linear; _selectionReveal applies the easeOutBack pop.
  void _syncSelectionReveal() {
    _selectionRevealController.animateTo(
      _selectionMode ? 1.0 : 0.0,
      duration: Duration(milliseconds: _selectionMode ? 360 : 260),
      curve: Curves.linear,
    );
  }

  void _setFabVisible(bool visible) {
    if (_fabVisible == visible || !mounted) {
      return;
    }
    setState(() {
      _fabVisible = visible;
    });
  }

  void _updateFabVisibilityForScrollDirection(ScrollDirection direction) {
    switch (direction) {
      case ScrollDirection.reverse:
        _setFabVisible(false);
        return;
      case ScrollDirection.forward:
        _setFabVisible(true);
        return;
      case ScrollDirection.idle:
        return;
    }
  }

  void _toggleSearch({bool? open, bool focusKeyboard = true}) {
    final nextOpen = open ?? !_searchOpen;
    setState(() {
      _searchOpen = nextOpen;
    });
    // Tap-only: animate the search bubble open/closed (independent of pull).
    _searchRevealController.animateTo(
      nextOpen ? 1.0 : 0.0,
      curve: nextOpen ? Curves.easeOutCubic : Curves.easeInCubic,
    );
    if (!nextOpen) {
      _searchDebounce?.cancel();
      setState(_clearSearchState);
    }
    if (_searchOpen && focusKeyboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
    }
  }

  bool _handleSearchSwipe(ScrollNotification notification) {
    // PERF: freeze cosmetic frame animations while the list is flinging
    // (ballistic updates carry no dragDetails) — the whole frame budget goes
    // to the scroll; they auto-resume ~120 ms after the fling settles.
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails == null) {
      CosmeticMotionGate.noteBallisticScroll();
    }
    if (notification is UserScrollNotification) {
      _updateFabVisibilityForScrollDirection(notification.direction);
    }
    if (_selectionMode) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollStartNotification) {
      // Single-stage pull straight into the Personal reveal.
      _dragOpenCap = _pullExtentMax;
    }

    if (notification is ScrollEndNotification) {
      _lockListScrollUntilDragEnd = false;
    }

    final isTopPullOverscroll =
        notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.metrics.pixels <= 0.5 &&
        notification.metrics.extentBefore <= 0.5 &&
        notification.overscroll < 0;
    final isTopPullUpdate =
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        notification.metrics.pixels <= 0.5 &&
        notification.metrics.extentBefore <= 0.5 &&
        (notification.scrollDelta ?? 0) < 0;

    if (isTopPullOverscroll || isTopPullUpdate) {
      _stopPullSnap();
      final pull = notification is OverscrollNotification
          ? -notification.overscroll
          : -((notification as ScrollUpdateNotification).scrollDelta ?? 0);
      setState(() {
        _isClosingPull = false;
        _pullExtent = (_pullExtent + (pull * _pullOpenDamping)).clamp(
          0.0,
          _dragOpenCap,
        );
      });
      _updatePersonalRevealEffects();
      return false;
    }

    // While the Personal reveal is open the chats list must NOT scroll away —
    // every upward movement (finger drag AND fling momentum) should drive the
    // reveal closed. Momentum frames have `dragDetails == null`, so we must NOT
    // require drag details here, otherwise a fling (common with many chats)
    // scrolls the list instead of closing Personal — the reported bug where it
    // only closed with a short list. (jumpTo(0) below pins the list; its own
    // notification carries a negative scrollDelta so it never matches here.)
    final isPushUpUpdate =
        notification is ScrollUpdateNotification &&
        (notification.scrollDelta ?? 0) > 0 &&
        (_pullExtent > 0.001);
    final isPushUpOverscroll =
        notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll > 0 &&
        (_pullExtent > 0.001);

    if (_lockListScrollUntilDragEnd && _pullExtent <= 0.001) {
      if (notification is ScrollUpdateNotification &&
          notification.dragDetails != null &&
          (notification.scrollDelta ?? 0) > 0) {
        if (_listScrollController.hasClients &&
            _listScrollController.offset > 0.001) {
          _listScrollController.jumpTo(0);
        }
        return true;
      }
      if (notification is OverscrollNotification &&
          notification.dragDetails != null &&
          notification.overscroll > 0) {
        return true;
      }
    }

    if (isPushUpUpdate || isPushUpOverscroll) {
      // Gesture beats animation: a swipe-up while the reveal is still
      // SNAPPING OPEN is an explicit "close it" — reverse immediately from
      // the current position instead of making the user wait out the opening
      // (the old damped finger-close barely moved the pull during a quick
      // flick, and the release band then snapped it back open — the reported
      // "нельзя закрыть, пока анимация не доиграет").
      if (_pullSnapController.isAnimating) {
        final target = _pullSnapTarget;
        if (target != null && target <= 0.001) {
          // Already reversing — let it play; swallow the scroll so the list
          // doesn't move underneath.
          return true;
        }
        _stopPullSnap();
        setState(() {
          _isClosingPull = true;
          _lockListScrollUntilDragEnd = true;
        });
        _animatePullToExtent(0);
        if (_listScrollController.hasClients &&
            _listScrollController.offset > 0.001) {
          _listScrollController.jumpTo(0);
        }
        return true;
      }
      _stopPullSnap();
      final delta = notification is OverscrollNotification
          ? notification.overscroll
          : (notification as ScrollUpdateNotification).scrollDelta ?? 0;
      setState(() {
        _isClosingPull = true;
        _lockListScrollUntilDragEnd = true;
        _pullExtent = (_pullExtent - (delta * _pullCloseDamping)).clamp(
          0.0,
          _pullExtentMax,
        );
      });
      if (_listScrollController.hasClients &&
          _listScrollController.offset > 0.001) {
        _listScrollController.jumpTo(0);
      }
      _updatePersonalRevealEffects();
      return true;
    }

    if (notification is ScrollEndNotification && _pullExtent > 0.001) {
      // A snap started by an interrupt (or the release below) is already in
      // control — don't let the release band re-decide, it used to re-open a
      // reveal the user had explicitly dismissed mid-animation.
      if (_pullSnapController.isAnimating) return false;
      // Personal-only snap.
      if (_isClosingPull) {
        // Closing intent: any meaningful upward swipe should dismiss. With many
        // chats the close travels via the (damped) list scroll, so the pull
        // decreases slowly — keep the "stay open" band narrow (only if the user
        // barely moved) so closing works regardless of chat count.
        if (_pullExtent > (_personalPullMax * 0.82)) {
          _animatePullToExtent(_pullExtentMax);
        } else {
          _animatePullToExtent(0);
        }
      } else if (_pullExtent < (_personalPullMax * 0.35)) {
        _animatePullToExtent(0);
      } else {
        _animatePullToExtent(_pullExtentMax);
      }
      return false;
    }

    return false;
  }

  Future<void> _openPersonalChats() async {
    if (_personalReveal > 0 || _searchReveal > 0) {
      _resetPersonalRevealFeedback();
      setState(() {
        _pullExtent = 0;
        _personalOpenLocked = false;
        _searchOpen = false;
        _searchRevealController.value = 0;
      });
    }
    final unlocked = await ensureSecurityScopeUnlocked(
      context: context,
      controller: widget.controller,
      scope: SecurityLockScope.personal,
      forcePrompt: true,
    );
    if (!unlocked || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => PersonalChatsScreen(controller: widget.controller),
      ),
    );
    if (mounted) {
      await widget.controller.security.lockNow(SecurityLockScope.personal);
    }
  }

  Future<void> _showPersonalQuickActions() async {
    final protectionEnabled = widget.controller.security.isEnabled(
      SecurityLockScope.personal,
    );
    final choice = await showFrostedPopup<String>(
      context: context,
      alignment: Alignment.topRight,
      builder: (context) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: 8,
                right: 10,
                child: FrostedPopupContainer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 220,
                      maxWidth: 260,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GlassMenuAction(
                          icon: Icons.lock_outline_rounded,
                          title: _menuLabel(
                            context,
                            ru: protectionEnabled
                                ? 'Настроить защиту Личных'
                                : 'Добавить пароль на Личные',
                            en: protectionEnabled
                                ? 'Manage Personal protection'
                                : 'Add protection to Personal',
                          ),
                          onTap: () => Navigator.of(context).pop('security'),
                        ),
                        if (protectionEnabled) ...[
                          const Divider(height: 1),
                          _GlassMenuAction(
                            icon: Icons.lock_clock_rounded,
                            title: _menuLabel(
                              context,
                              ru: 'Заблокировать Личные сейчас',
                              en: 'Lock Personal now',
                            ),
                            onTap: () => Navigator.of(context).pop('lock_now'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) {
      return;
    }
    switch (choice) {
      case 'security':
        await openSecurityScopeSettings(
          context: context,
          controller: widget.controller,
          scope: SecurityLockScope.personal,
        );
        return;
      case 'lock_now':
        await widget.controller.security.lockNow(SecurityLockScope.personal);
        return;
    }
  }

  Future<String?> _pickArchiveDestination() async {
    return showFrostedPopup<String>(
      context: context,
      alignment: Alignment.topRight,
      builder: (context) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: 8,
                right: 10,
                child: FrostedPopupContainer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 220,
                      maxWidth: 260,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GlassMenuAction(
                          icon: AppIcons.personAdd,
                          title: _menuLabel(
                            context,
                            ru: 'В категорию Личные',
                            en: 'Move to Personal',
                          ),
                          onTap: () => Navigator.of(context).pop('personal'),
                        ),
                        _GlassMenuAction(
                          icon: AppIcons.archive,
                          title: _menuLabel(
                            context,
                            ru: 'В категорию Архив',
                            en: 'Move to Archive',
                          ),
                          onTap: () => Navigator.of(context).pop('archive'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Custom folders (UI only — all persistence goes through the controller API).
  // ---------------------------------------------------------------------------

  /// Island-style single-field name prompt. Returns the trimmed name on
  /// "Create"/"Save", or null on cancel / empty. Reused for create + rename.
  Future<String?> _promptFolderName({
    String? initial,
    String? confirmLabel,
  }) async {
    final textController = TextEditingController(text: initial ?? '');
    final cs = Theme.of(context).colorScheme;
    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: FrostedPopupContainer(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      wave1Text(
                        context,
                        ru: 'Новая папка',
                        en: 'New folder',
                        uk: 'Нова папка',
                        es: 'Nueva carpeta',
                        pt: 'Nova pasta',
                        ptBr: 'Nova pasta',
                        fr: 'Nouveau dossier',
                        de: 'Neuer Ordner',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: textController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (v) =>
                          Navigator.of(dialogContext).pop(v.trim()),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: wave1Text(
                          context,
                          ru: 'Название папки',
                          en: 'Folder name',
                          uk: 'Назва папки',
                          es: 'Nombre de carpeta',
                          pt: 'Nome da pasta',
                          ptBr: 'Nome da pasta',
                          fr: 'Nom du dossier',
                          de: 'Ordnername',
                        ),
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: cs.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(),
                          child: Text(
                            wave1Text(
                              context,
                              ru: 'Отмена',
                              en: 'Cancel',
                              uk: 'Скасувати',
                              es: 'Cancelar',
                              pt: 'Cancelar',
                              ptBr: 'Cancelar',
                              fr: 'Annuler',
                              de: 'Abbrechen',
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: () => Navigator.of(
                            dialogContext,
                          ).pop(textController.text.trim()),
                          child: Text(
                            confirmLabel ??
                                wave1Text(
                                  context,
                                  ru: 'Создать',
                                  en: 'Create',
                                  uk: 'Створити',
                                  es: 'Crear',
                                  pt: 'Criar',
                                  ptBr: 'Criar',
                                  fr: 'Creer',
                                  de: 'Erstellen',
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    textController.dispose();
    final trimmed = result?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  /// Selection-mode "To folder" action: prompts for a name then creates a
  /// custom folder containing the currently-selected conversations. On success
  /// the selection clears and the folder strip appears with the new chip.
  Future<void> _createFolderFromSelection() async {
    final convoIds = _selected.toList(growable: false);
    if (convoIds.isEmpty) return;
    final name = await _promptFolderName();
    if (!mounted || name == null) return;
    try {
      await widget.controller.createChatFolder(
        name: name,
        convoIds: convoIds,
      );
    } catch (_) {
      // Fail-safe: folders are a convenience; never crash the chats screen.
    }
    if (!mounted) return;
    _clearSelection();
    setState(() {});
  }

  /// Long-press a custom-folder chip → small frosted menu: rename / delete.
  Future<void> _openFolderChipMenu(ChatFolder folder) async {
    final action = await showFrostedPopup<String>(
      context: context,
      builder: (popupContext) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(popupContext).pop(),
                ),
              ),
              Center(
                child: FrostedPopupContainer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 200,
                      maxWidth: 260,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GlassMenuAction(
                          icon: Icons.edit_outlined,
                          title: wave1Text(
                            context,
                            ru: 'Переименовать',
                            en: 'Rename',
                            uk: 'Перейменувати',
                            es: 'Renombrar',
                            pt: 'Renomear',
                            ptBr: 'Renomear',
                            fr: 'Renommer',
                            de: 'Umbenennen',
                          ),
                          onTap: () =>
                              Navigator.of(popupContext).pop('rename'),
                        ),
                        _GlassMenuAction(
                          icon: Icons.delete_outline_rounded,
                          title: wave1Text(
                            context,
                            ru: 'Удалить',
                            en: 'Delete',
                            uk: 'Видалити',
                            es: 'Eliminar',
                            pt: 'Excluir',
                            ptBr: 'Excluir',
                            fr: 'Supprimer',
                            de: 'Loschen',
                          ),
                          onTap: () =>
                              Navigator.of(popupContext).pop('delete'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      final name = await _promptFolderName(
        initial: folder.name,
        confirmLabel: wave1Text(
          context,
          ru: 'Сохранить',
          en: 'Save',
          uk: 'Зберегти',
          es: 'Guardar',
          pt: 'Salvar',
          ptBr: 'Salvar',
          fr: 'Enregistrer',
          de: 'Speichern',
        ),
      );
      if (!mounted || name == null) return;
      try {
        // Preserve membership + emoji; only the name changes.
        final members = await widget.controller.folderMemberConvoIds(folder.id);
        await widget.controller.updateChatFolder(
          id: folder.id,
          name: name,
          emoji: folder.emoji,
          convoIds: members,
        );
      } catch (_) {
        // Fail-safe.
      }
    } else if (action == 'delete') {
      try {
        await widget.controller.deleteChatFolder(folder.id);
      } catch (_) {
        // Fail-safe.
      }
      if (!mounted) return;
      if (_activeFolder == folder.id) {
        setState(() => _activeFolder = 'all');
      }
    }
  }

  bool _matchesConversation(Conversation convo, String queryLower) {
    if (queryLower.isEmpty) return true;
    // Telegram-style: match the visible title and the peer's handle/profile id
    // (so pasting a handle still finds the chat). Never match the internal
    // convoId (`group:<uuid>`, `dev:<uuid>`) — typing "group"/"dev"/a uuid
    // fragment must not surface unrelated chats.
    final title = convo.title.toLowerCase();
    final peer = (convo.peerProfileId ?? '').toLowerCase();
    return title.contains(queryLower) || peer.contains(queryLower);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _scheduleMessageSearch();
  }

  String _menuLabel(
    BuildContext context, {
    required String ru,
    required String en,
  }) {
    return wave1Text(context, ru: ru, en: en);
  }

  Future<void> _openMainMenu() async {
    final controller = widget.controller;
    final missedCallCount = await controller.missedCallCount();
    if (!mounted) return;
    final action = await showFrostedPopup<String>(
      context: context,
      alignment: Alignment.topRight,
      builder: (context) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: FrostedPopupContainer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 210,
                      maxWidth: 250,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GlassMenuAction(
                          leading: _ThemeMenuAnimatedIcon(
                            darkMode: controller.darkMode,
                          ),
                          title: _menuLabel(
                            context,
                            ru: controller.darkMode
                                ? 'Светлая тема'
                                : 'Тёмная тема',
                            en: controller.darkMode
                                ? 'Light theme'
                                : 'Dark theme',
                          ),
                          onTap: () => Navigator.of(context).pop('theme'),
                        ),
                        _GlassMenuAction(
                          leading: const _GroupMenuAnimatedIcon(),
                          icon: AppIcons.createGroup,
                          title: _menuLabel(
                            context,
                            ru: 'Создать комнату',
                            en: 'Create room',
                          ),
                          onTap: () => Navigator.of(context).pop('group'),
                        ),
                        _GlassMenuAction(
                          leading: const _FavoritesMenuAnimatedIcon(),
                          title: localizedFavoritesTitle(context),
                          onTap: () => Navigator.of(context).pop('favorites'),
                        ),
                        _GlassMenuAction(
                          leading: _CallHistoryMenuAnimatedIcon(
                            missedCount: missedCallCount,
                          ),
                          title: _menuLabel(context, ru: 'Звонки', en: 'Calls'),
                          onTap: () =>
                              Navigator.of(context).pop('call_history'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    if (action == 'theme') {
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);
      final topPad = MediaQuery.paddingOf(context).top;
      final center = Offset(size.width - 40, topPad + kToolbarHeight / 2);
      final scope = ThemeTransitionScope.of(context);
      if (scope != null) {
        scope.triggerTransition(center, !controller.darkMode);
      } else {
        await controller.setDarkMode(!controller.darkMode);
      }
      return;
    }
    if (action == 'group') {
      final fallbackTitle = context.l10n.tabGroups;
      final groupId = await Navigator.of(context).push<String>(
        SecretlyPageRoute(
          builder: (_) => NewGroupScreen(controller: controller),
        ),
      );
      if (!mounted || groupId == null || groupId.isEmpty) return;
      final updated = await controller.listConversations();
      Conversation? created;
      for (final convo in updated) {
        if (convo.convoId == groupId) {
          created = convo;
          break;
        }
      }
      final title = created?.title ?? fallbackTitle;
      if (!mounted) return;
      Navigator.of(context).push(
        SecretlyPageRoute(
          builder: (_) => ChatScreen(
            controller: controller,
            convoId: groupId,
            title: title,
          ),
        ),
      );
      return;
    }
    if (action == 'favorites') {
      await _openFavorites();
      return;
    }
    if (action == 'call_history') {
      await _openCallHistory();
    }
  }

  Future<void> _openFavorites() async {
    final controller = widget.controller;
    final title = localizedFavoritesTitle(context);
    final convoId = await controller.ensureFavoritesChat(title: title);
    if (!mounted) return;
    Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => ChatScreen(
          controller: controller,
          convoId: convoId,
          title: title,
          peerProfileIdForSend: convoId,
          initialForwardDraft: controller.forwardDraft,
        ),
      ),
    );
  }

  void _scheduleMessageSearch() {
    _searchDebounce?.cancel();
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      setState(() {
        _messageMatchedConvoIds = const <String>{};
        _searchingMessages = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      unawaited(_runMessageSearch(query));
    });
  }

  Future<void> _runMessageSearch(String query) async {
    final token = ++_searchVersion;
    if (mounted) {
      setState(() {
        _searchingMessages = true;
      });
    }

    final queryLower = query.toLowerCase();
    final convos = await widget.controller.listConversations();
    final ids = <String>{};
    for (final convo in convos) {
      if (_matchesConversation(convo, queryLower)) {
        ids.add(convo.convoId);
        continue;
      }
      final hit = await widget.controller.searchChatFirstMatch(
        convoId: convo.convoId,
        query: query,
      );
      if (hit != null) {
        ids.add(convo.convoId);
      }
    }

    if (!mounted || token != _searchVersion) return;
    setState(() {
      _messageMatchedConvoIds = ids;
      _searchingMessages = false;
    });
  }

  @override
  void dispose() {
    unawaited(_coalescedChangedSub?.cancel());
    _stopPullSnap();
    _pullSnapController.dispose();
    _personalCollapseController.dispose();
    _searchRevealController.dispose();
    _selectionRevealController.dispose();
    _listScrollController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    // sizeOf (not MediaQuery.of): the full-aspect dependency used to rebuild
    // the whole chats screen on every keyboard-animation frame.
    // Policy (incl. the desktop-OS opt-out) lives in one place —
    // see [useLegacyWideLayout].
    final isDesktopLike = useLegacyWideLayout(
      MediaQuery.sizeOf(context).width,
    );
    if (isDesktopLike) {
      return DesktopChatsWorkspace(
        controller: controller,
        shellTab: widget.desktopShellTab,
      );
    }
    return StreamBuilder<void>(
      stream: _coalescedChanged,
      builder: (context, _) {
        // Keep folder membership in sync with create/edit/delete (each fires
        // controller.changed). Fail-safe: errors leave the prior cache.
        _syncFolderMembersCache();
        // Fall back to 'all' if the active custom folder no longer exists.
        if (_activeFolder != 'all' &&
            !controller.customChatFolders.any((f) => f.id == _activeFolder)) {
          _activeFolder = 'all';
        }
        final dataVersion = controller.changeVersion;
        if (_convosFuture == null || _convosFutureVersion != dataVersion) {
          _convosFutureVersion = dataVersion;
          _convosFuture = () async {
            final convos = await controller.listConversations();
            final missedByConvo = await controller.missedCallCountsByConvoIds(
              convos.map((c) => c.convoId),
            );
            return (convos, missedByConvo);
          }();
        }
        return FutureBuilder<(List<Conversation>, Map<String, int>)>(
          future: _convosFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _lastConvos = snapshot.data!.$1;
              _lastMissedByConvo = snapshot.data!.$2;
              _convosEverLoaded = true;
            }
            final convos = snapshot.data?.$1 ?? _lastConvos;
            final missedByConvo = snapshot.data?.$2 ?? _lastMissedByConvo;
            final queryLower = _searchQuery.trim().toLowerCase();
            final filtered = convos
                .where(
                  (c) =>
                      queryLower.isEmpty ||
                      _messageMatchedConvoIds.contains(c.convoId) ||
                      _matchesConversation(c, queryLower),
                )
                .toList(growable: false);
            // Base Chats-tab list (search + un-archived + excludes groups and
            // personal chats). Folders + smart sort are applied ON TOP of this.
            final baseActive = filtered
                .where(
                  (c) =>
                      c.archivedAtMs == null &&
                      !c.convoId.startsWith('group:') &&
                      !controller.isPersonalChat(c.convoId),
                )
                .toList(growable: false);
            // PART 1 (custom-folder filter) + PART 2 (smart sort) — additive,
            // pure.
            final active = _applyFolderAndSort(baseActive);

            final byId = <String, Conversation>{
              for (final c in convos) c.convoId: c,
            };
            final selectedConvos = _selected
                .map((id) => byId[id])
                .whereType<Conversation>()
                .toList(growable: false);

            AppBar buildAppBar() {
              // BUBBLE MORPH (2026-06-19): build BOTH island layouts every frame
              // and cross-fade them with a spring AnimatedSwitcher (single
              // frostedAppBar return at the end), so the top islands pop softly
              // between normal and selection like bubbles instead of hard-cutting.
              final s = _searchReveal; // 0 = idle, 1 = search fully open
              // BUBBLE MORPH: the two top islands are PERSISTENT frosted frames
              // built once in the return below. These are the content LAYERS that
              // cross-fade INSIDE those frames as search / selection reveal — the
              // frame itself never disappears, so the islands reshape seamlessly.
              final Widget logoContent = AppBrandLogo(controller: controller);
              final Widget compactRightContent = Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: l10n.search,
                    icon: Icon(AppIcons.search, color: cs.onSurface),
                    onPressed: () => _toggleSearch(focusKeyboard: true),
                  ),
                  IconButton(
                    tooltip: wave1Text(
                      context,
                      ru: 'Сортировка',
                      en: 'Sort',
                      uk: 'Сортування',
                      es: 'Ordenar',
                      pt: 'Ordenar',
                      ptBr: 'Ordenar',
                      fr: 'Trier',
                      de: 'Sortieren',
                    ),
                    icon: Icon(Icons.swap_vert_rounded, color: cs.onSurface),
                    iconSize: 23,
                    onPressed: _openSortMenu,
                  ),
                  IconButton(
                    tooltip: l10n.more,
                    icon: Icon(AppIcons.moreVert, color: cs.onSurface),
                    iconSize: 23,
                    onPressed: _openMainMenu,
                  ),
                ],
              );
              final Widget searchFieldContent = Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(AppIcons.search, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chat-search-open'),
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: false,
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: l10n.queryLabel,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.cancel,
                    icon: const Icon(AppIcons.close),
                    onPressed: () =>
                        _toggleSearch(open: false, focusKeyboard: false),
                  ),
                ],
              );

              final anyActive = selectedConvos.any(
                (c) => c.archivedAtMs == null,
              );
              final shouldArchive =
                  anyActive; // if mixed or any active -> archive all

              final anyUnmuted = selectedConvos.any((c) => !c.muted);
              final shouldMute =
                  anyUnmuted; // if mixed or any unmuted -> mute all

              final anyUnpinned = selectedConvos.any(
                (c) => c.pinnedAtMs == null,
              );
              final shouldPin = anyUnpinned;
              final selectedDirect = selectedConvos
                  .where((c) => !c.convoId.startsWith('group:'))
                  .toList(growable: false);
              final anyNotPersonal = selectedDirect.any(
                (c) => !controller.isPersonalChat(c.convoId),
              );
              final shouldPersonal = anyNotPersonal;

              // Selection mode: islands morph into a cancel+count island on the
              // left and an actions island on the right. All selection-mode
              // icons are bright white (via the wrapping IconTheme below).
              final Widget selCountContent = IconTheme(
                data: IconThemeData(color: cs.onSurface),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.cancelSelection,
                      icon: const Icon(Icons.close),
                      onPressed: _clearSelection,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 10, left: 2),
                      child: Text(
                        '${_selected.length}',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              final Widget selActionsContent = IconTheme(
                data: IconThemeData(color: cs.onSurface),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: selectedConvos.isEmpty
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text(
                                    l10n.deleteChatsConfirmTitle(
                                      _selected.length,
                                    ),
                                  ),
                                  content: Text(l10n.deleteChatsConfirmBody),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: Text(l10n.cancel),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: Text(l10n.delete),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (!mounted) return;
                            if (ok != true) return;
                            for (final c in selectedConvos) {
                              await controller.deleteChat(convoId: c.convoId);
                            }
                            _clearSelection();
                          },
                  ),
                  IconButton(
                    tooltip: shouldArchive ? l10n.archive : l10n.unarchive,
                    icon: Icon(
                      shouldArchive
                          ? Icons.archive_outlined
                          : Icons.unarchive_outlined,
                    ),
                    onPressed: selectedConvos.isEmpty
                        ? null
                        : () async {
                            if (shouldArchive) {
                              final destination =
                                  await _pickArchiveDestination();
                              if (!mounted || destination == null) return;
                              if (destination == 'personal') {
                                await controller.setManyChatsPersonal(
                                  convoIds: selectedConvos.map(
                                    (c) => c.convoId,
                                  ),
                                  personal: true,
                                );
                                for (final c in selectedConvos) {
                                  await controller.setChatArchived(
                                    convoId: c.convoId,
                                    archived: false,
                                  );
                                }
                              } else {
                                await controller.setManyChatsPersonal(
                                  convoIds: selectedConvos.map(
                                    (c) => c.convoId,
                                  ),
                                  personal: false,
                                );
                                for (final c in selectedConvos) {
                                  await controller.setChatArchived(
                                    convoId: c.convoId,
                                    archived: true,
                                  );
                                }
                              }
                            } else {
                              for (final c in selectedConvos) {
                                await controller.setChatArchived(
                                  convoId: c.convoId,
                                  archived: false,
                                );
                                await controller.setChatPersonal(
                                  convoId: c.convoId,
                                  personal: false,
                                );
                              }
                            }
                            _clearSelection();
                          },
                  ),
                  IconButton(
                    tooltip: wave1Text(
                      context,
                      ru: 'В папку',
                      en: 'To folder',
                      uk: 'До папки',
                      es: 'A carpeta',
                      pt: 'Para pasta',
                      ptBr: 'Para pasta',
                      fr: 'Vers dossier',
                      de: 'In Ordner',
                    ),
                    icon: const Icon(Icons.create_new_folder_outlined),
                    onPressed: selectedConvos.isEmpty
                        ? null
                        : _createFolderFromSelection,
                  ),
                  IconButton(
                    tooltip: shouldMute
                        ? l10n.muteNotifications
                        : l10n.unmuteNotifications,
                    icon: Icon(
                      shouldMute
                          ? Icons.notifications_off_outlined
                          : Icons.notifications_outlined,
                    ),
                    onPressed: selectedConvos.isEmpty
                        ? null
                        : () async {
                            for (final c in selectedConvos) {
                              await controller.setChatMuted(
                                convoId: c.convoId,
                                muted: shouldMute,
                              );
                            }
                            _clearSelection();
                          },
                  ),
                  IconButton(
                    tooltip: shouldPersonal
                        ? _menuLabel(
                            context,
                            ru: 'В личные',
                            en: 'Add to personal',
                          )
                        : _menuLabel(
                            context,
                            ru: 'Убрать из личных',
                            en: 'Remove from personal',
                          ),
                    icon: Icon(
                      shouldPersonal
                          ? Icons.person_add_outlined
                          : Icons.person_remove_outlined,
                    ),
                    onPressed: selectedDirect.isEmpty
                        ? null
                        : () async {
                            await controller.setManyChatsPersonal(
                              convoIds: selectedDirect.map((c) => c.convoId),
                              personal: shouldPersonal,
                            );
                            if (!mounted) return;
                            _clearSelection();
                          },
                  ),
                  PopupMenuButton<String>(
                    tooltip: l10n.more,
                    onSelected: (v) async {
                      if (v == 'pin') {
                        for (final c in selectedConvos) {
                          await controller.setChatPinned(
                            convoId: c.convoId,
                            pinned: shouldPin,
                          );
                        }
                        _clearSelection();
                      } else if (v == 'clear') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text(
                                l10n.clearHistoryConfirmTitle(_selected.length),
                              ),
                              content: Text(l10n.clearHistoryConfirmBody),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text(l10n.cancel),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: Text(l10n.clear),
                                ),
                              ],
                            );
                          },
                        );
                        if (!mounted) return;
                        if (ok != true) return;
                        for (final c in selectedConvos) {
                          await controller.clearChatHistory(convoId: c.convoId);
                        }
                        _clearSelection();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Text(shouldPin ? l10n.pin : l10n.unpin),
                      ),
                      PopupMenuItem(
                        value: 'clear',
                        child: Text(l10n.clearHistory),
                      ),
                    ],
                  ),
                  ],
                ),
              );

              // BUBBLE MORPH (seamless): ONE persistent frosted frame per side.
              // The frames are the SAME widgets in every state, so the glass
              // never disappears — only the CONTENT layers inside cross-fade and
              // the right frame's WIDTH lerps, so the islands physically reshape
              // (logo ⇄ ✕count, search/menu ⇄ actions) instead of one set
              // popping in. Driven by _selectionRevealController (spring
              // easeOutBack via _selectionReveal) and the search reveal `s`.
              return frostedAppBar(
                automaticallyImplyLeading: false,
                flexibleSpace: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: SizedBox(
                      height: _kListIslandHeight,
                      child: AnimatedBuilder(
                        animation: _selectionRevealController,
                        builder: (context, _) {
                          final selO = _selectionReveal.clamp(0.0, 1.0);
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final total = constraints.maxWidth;
                              final normalRightW = lerpDouble(
                                _kListActionsIslandWidth,
                                total,
                                s,
                              )!;
                              // 300 comfortably fits the 6 full-size action
                              // icons (delete / to-folder / archive / mute /
                              // personal / more); clamped so it never overflows.
                              final rightW = lerpDouble(
                                normalRightW,
                                300.0,
                                selO,
                              )!.clamp(0.0, total);
                              return Row(
                                children: [
                                  Expanded(
                                    child: FrostedHeaderIsland(
                                      radius: _kListIslandRadius,
                                      height: _kListIslandHeight,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      child: Stack(
                                        alignment: Alignment.centerLeft,
                                        children: [
                                          Opacity(
                                            opacity: ((1 - s) * (1 - selO))
                                                .clamp(0.0, 1.0),
                                            child: IgnorePointer(
                                              ignoring: selO > 0.5,
                                              child: Center(child: logoContent),
                                            ),
                                          ),
                                          Opacity(
                                            opacity: selO,
                                            child: IgnorePointer(
                                              ignoring: selO < 0.5,
                                              child: selCountContent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8 * (1 - s)),
                                  SizedBox(
                                    width: rightW,
                                    height: _kListIslandHeight,
                                    child: FrostedHeaderIsland(
                                      radius: _kListIslandRadius,
                                      height: _kListIslandHeight,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Stack(
                                        alignment: Alignment.centerRight,
                                        children: [
                                          Opacity(
                                            opacity: ((1 - s) * (1 - selO))
                                                .clamp(0.0, 1.0),
                                            child: IgnorePointer(
                                              ignoring: s > 0.5 || selO > 0.5,
                                              child: compactRightContent,
                                            ),
                                          ),
                                          Opacity(
                                            opacity: (s * (1 - selO)).clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            child: IgnorePointer(
                                              ignoring: s < 0.5 || selO > 0.5,
                                              child: searchFieldContent,
                                            ),
                                          ),
                                          Opacity(
                                            opacity: selO,
                                            child: IgnorePointer(
                                              ignoring: selO < 0.5,
                                              child: selActionsContent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            }

            final media = MediaQuery.of(context);
            final bottomInset = media.padding.bottom;
            // Search now expands inside the toolbar island (no bottom field),
            // so the app-bar inset is constant.
            final appBarInset = media.padding.top + kToolbarHeight;
            final listTopGap = lerpDouble(
              _collapsedTopListGap,
              _expandedTopListGap,
              _searchReveal,
            )!;

            // Пересоздаётся только при смене данных, а не на каждом кадре: см.
            // комментарий у `_roomCallBannerFuture`. Хеш списка нужен потому,
            // что заголовок баннера читается из `convos`, — без него баннер
            // застыл бы со старым названием комнаты.
            final roomCallConvosHash = Object.hashAll(
              convos.map((c) => c.convoId),
            );
            if (_roomCallBannerFuture == null ||
                _roomCallBannerVersion != dataVersion ||
                _roomCallBannerConvosHash != roomCallConvosHash) {
              _roomCallBannerVersion = dataVersion;
              _roomCallBannerConvosHash = roomCallConvosHash;
              _roomCallBannerFuture = () async {
                final call = await controller
                    .getPrimarySelfJoinedCachedRoomCall();
                if (call == null) return (null, '');
                final match = convos
                    .where((c) => c.convoId == call.roomId)
                    .firstOrNull;
                final title = (match?.title ?? call.roomId).trim().isEmpty
                    ? call.roomId
                    : (match?.title ?? call.roomId);
                return (call, title);
              }();
            }

            Widget buildRoomCallBanner(CachedRoomCall? call, String title) {
              if (call == null) return const SizedBox.shrink();
              return RuntimeAwareRoomCallReturnBanner(
                title: title,
                call: call,
                onTap: () {
                  Haptics.tap();
                  Navigator.of(context).push(
                    SecretlyPageRoute(
                      builder: (_) => RoomCallScreen(
                        controller: controller,
                        groupId: call.roomId,
                        initialTitle: title,
                      ),
                    ),
                  );
                },
              );
            }

            Widget buildList({
              required double appBarInset,
              required double topGap,
              required CachedRoomCall? roomCall,
              required String roomCallTitle,
            }) {
              final headerItems = <Widget>[
                SizedBox(height: appBarInset),
                // The music island is rendered as a fixed overlay (see the Stack
                // at the buildList call site) so it stays pinned under the top
                // bar instead of scrolling away with the chat list. Reserve its
                // height here so the first row isn't hidden behind it.
                SharedAudioTopIslandsReserve(controller: controller),
                SharedAudioCallBannerGate(controller: controller),
                buildRoomCallBanner(roomCall, roomCallTitle),
                // Предупреждение о системных ограничениях: пустое, пока всё в
                // порядке. Ставится здесь, а не только в настройках, потому что
                // проявляется проблема как «звонков нет вообще» — искать её в
                // настройках человеку неоткуда (поле 22.08, Xiaomi HyperOS).
                const DeliveryHealthBanner(),
                // У-1: устройство отключено от аккаунта — сказать прямо.
                OwnDeviceRemovedBanner(controller: controller),
                // PART 1 — custom-folder strip is now a PINNED overlay (below),
                // so it stays fixed under the top islands instead of scrolling
                // away. Reserve its height here so the first row isn't hidden.
                if (controller.customChatFolders.isNotEmpty)
                  const SizedBox(height: _kFolderStripHeight),
                SizedBox(height: topGap),
              ];
              final showPersonalEntry = _personalRevealRaw > 0.001;
              final showEmptyPlaceholder = active.isEmpty;
              // See _convosEverLoaded: the very first load renders a spinner in
              // this same slot, never the "no chats yet" text. Item count is
              // unchanged (one placeholder either way).
              final placeholderIsLoading = active.isEmpty && !_convosEverLoaded;
              final itemCount =
                  headerItems.length +
                  active.length +
                  (showPersonalEntry ? 1 : 0) +
                  (showEmptyPlaceholder ? 1 : 0);
              return NotificationListener<ScrollNotification>(
                onNotification: _handleSearchSwipe,
                child: ListView.builder(
                  controller: _listScrollController,
                  physics: _personalOpenLocked
                      ? const NeverScrollableScrollPhysics()
                      // Clamping is REQUIRED here — `_handleSearchSwipe` reads
                      // top-edge overscroll to drive the Personal reveal, and
                      // an iOS rubber-band would fight it. `secretlyPullListPhysics`
                      // keeps exactly that on iOS while giving Android the glide.
                      : secretlyPullListPhysics(),
                  padding: EdgeInsets.only(bottom: 108 + bottomInset),
                  itemCount: itemCount,
                  itemBuilder: (context, i) {
                    if (i < headerItems.length) {
                      return headerItems[i];
                    }

                    final contentIndex = i - headerItems.length;
                    final normalizedIndex =
                        contentIndex - (showPersonalEntry ? 1 : 0);
                    if (showPersonalEntry && contentIndex == 0) {
                      return StreamBuilder<void>(
                        stream: controller.security.changed,
                        builder: (context, __) {
                          final protectionEnabled = controller.security
                              .isEnabled(SecurityLockScope.personal);
                          final personalLocked = controller.security.isLocked(
                            SecurityLockScope.personal,
                          );
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              18,
                              2,
                              18,
                              8 * _personalReveal,
                            ),
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.topCenter,
                                heightFactor: _personalReveal,
                                child: Opacity(
                                  opacity: _personalReveal,
                                  child: Transform.translate(
                                    offset: Offset(
                                      0,
                                      8 * (1 - _personalReveal),
                                    ),
                                    child: SizedBox(
                                      height: 88,
                                      child: _PersonalGlassEntryCard(
                                        title: _menuLabel(
                                          context,
                                          ru: 'Личные',
                                          en: 'Personal',
                                        ),
                                        subtitle: protectionEnabled
                                            ? _menuLabel(
                                                context,
                                                ru: personalLocked
                                                    ? 'Защищено и закрыто'
                                                    : 'Защищено и готово',
                                                en: personalLocked
                                                    ? 'Protected and locked'
                                                    : 'Protected and ready',
                                              )
                                            : _menuLabel(
                                                context,
                                                ru: 'Скрытая коллекция чатов',
                                                en: 'Hidden chat collection',
                                              ),
                                        menuTooltip: _menuLabel(
                                          context,
                                          ru: 'Меню Личных',
                                          en: 'Personal menu',
                                        ),
                                        protectionEnabled: protectionEnabled,
                                        locked: personalLocked,
                                        revealProgress: _personalReveal,
                                        postOpenCollapseProgress:
                                            _personalCollapseProgress,
                                        isClosing: _isClosingPull,
                                        onTap: _openPersonalChats,
                                        onMenuTap: _showPersonalQuickActions,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }

                    if (showEmptyPlaceholder && normalizedIndex == 0) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (placeholderIsLoading)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Text(
                                _searchQuery.trim().isEmpty
                                    ? l10n.noChatsYet
                                    : (_searchingMessages
                                          ? l10n.search
                                          : l10n.noMatches),
                              ),
                          ],
                        ),
                      );
                    }

                    final listIndex = showEmptyPlaceholder
                        ? normalizedIndex - 1
                        : normalizedIndex;

                    final c = active[listIndex];

                    final selected = _selected.contains(c.convoId);
                    final isRequest = c.convoId.startsWith('req:');
                    final subtitleFallback = c.peerProfileId ?? c.convoId;
                    final peerProfileId =
                        c.peerProfileId ??
                        (isRequest ? c.convoId.substring(4) : c.convoId);
                    final isFavoritesNotes = controller.isSavedMessagesConvo(
                      c.convoId,
                    );
                    final isTyping = controller.isConversationTyping(c.convoId);
                    final missedCallCount = missedByConvo[c.convoId] ?? 0;

                    void openAvatarDetails() {
                      if (c.convoId.startsWith('group:')) {
                        Navigator.of(context).push(
                          SecretlyPageRoute(
                            builder: (_) => RoomDetailsScreen(
                              controller: controller,
                              groupId: c.convoId,
                              initialTitle: c.title,
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        SecretlyPageRoute(
                          builder: (_) => ContactDetailsScreen(
                            controller: controller,
                            peerProfileId: peerProfileId,
                            convoId: c.convoId,
                            initialTitle: isFavoritesNotes
                                ? localizedFavoritesTitle(context)
                                : c.title,
                            initialAvatarPath: isFavoritesNotes
                                ? null
                                : c.avatarPath,
                            heroTag: 'avatar-${c.convoId}',
                          ),
                        ),
                      );
                    }

                    final baseTitle = isFavoritesNotes
                        ? localizedFavoritesTitle(context)
                        : c.title;
                    // Peer's premium emoji status (synced from profile_meta) is
                    // shown next to the name so contacts can see it; falls back
                    // to the locally-set contact emoji when there is no status.
                    final statusEmoji =
                        (c.emojiStatus != null &&
                            c.emojiStatus!.trim().isNotEmpty)
                        ? c.emojiStatus!.trim()
                        : ((c.emoji != null && c.emoji!.trim().isNotEmpty)
                              ? c.emoji!.trim()
                              : '');
                    final titleText = statusEmoji.isNotEmpty
                        ? '$baseTitle $statusEmoji'
                        : baseTitle;

                    final draft = controller.forwardDraft;
                    final chatDestination = isRequest
                        ? ChatScreen(
                            controller: controller,
                            convoId: c.convoId,
                            title: titleText,
                            requestProfileId:
                                c.peerProfileId ?? c.convoId.substring(4),
                          )
                        : c.convoId.startsWith('group:')
                        ? ChatScreen(
                            controller: controller,
                            convoId: c.convoId,
                            title: titleText,
                            initialForwardDraft: draft,
                          )
                        : ChatScreen(
                            controller: controller,
                            convoId: c.peerProfileId ?? c.convoId,
                            title: titleText,
                            peerProfileIdForSend: c.peerProfileId ?? c.convoId,
                            initialForwardDraft: draft,
                          );

                    void openConversation() {
                      Navigator.of(context).push(
                        SecretlyPageRoute(builder: (_) => chatDestination),
                      );
                    }

                    return InkWell(
                      key: ValueKey<String>('chat-tile-${c.convoId}'),
                      // Самое частое нажатие во всём приложении, и отклика в нём
                      // не было. Долгое нажатие — средний: вход в режим выбора
                      // это смена состояния экрана, а не просто переход.
                      onLongPress: () {
                        Haptics.confirm();
                        _toggleSelected(c.convoId);
                      },
                      onTap: () {
                        Haptics.tap();
                        if (_selectionMode) {
                          _toggleSelected(c.convoId);
                          return;
                        }
                        openConversation();
                      },
                      child: ColoredBox(
                        color: selected
                            ? Theme.of(context).colorScheme.secondaryContainer
                                  .withValues(alpha: 0.45)
                            : Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                // Width is intrinsic: in selection mode the row
                                // grows to fit [checkmark + photo]; otherwise it
                                // is just the 52px avatar.
                                height: 52,
                                child: _ChatLeading(
                                  selectionMode: _selectionMode,
                                  selected: selected,
                                  avatarPath: c.avatarPath,
                                  title: c.title,
                                  fallbackId: subtitleFallback,
                                  muted: c.muted,
                                  isFavoritesNotes: isFavoritesNotes,
                                  isOnline: c.isOnline,
                                  heroTag: 'avatar-${c.convoId}',
                                  frameId: c.frameId,
                                  onTap: _selectionMode
                                      ? null
                                      : openAvatarDetails,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Name + emoji status share one
                                            // Expanded so the time pill stays
                                            // right-aligned as before. The emoji
                                            // is rendered as a Noto asset beside
                                            // the name (not concatenated) so it
                                            // animates and never shows the
                                            // Android tofu box. List rows stay
                                            // cheap: static first frame only.
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Flexible(
                                                    child: _FadingText(
                                                      baseTitle,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  if (statusEmoji
                                                      .isNotEmpty) ...[
                                                    const SizedBox(width: 5),
                                                    NotoStatusEmoji(
                                                      emoji: statusEmoji,
                                                      size: 18,
                                                      animate: true,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (c.pinnedAtMs != null) ...[
                                                  Icon(
                                                    AppIcons.pin,
                                                    size: 12,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                        .withValues(
                                                          alpha: 0.55,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 3),
                                                ],
                                                _TimePill(ms: c.lastEventAtMs),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 3,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: isTyping
                                                  ? _ChatListTypingSubtitle(
                                                      controller: controller,
                                                      convoId: c.convoId,
                                                      isRoom: c.convoId
                                                          .startsWith('group:'),
                                                    )
                                                  : ChatListSubtitlePreview(
                                                      key: ValueKey<String>(
                                                        'chat-subtitle-${c.convoId}',
                                                      ),
                                                      controller: controller,
                                                      convoId: c.convoId,
                                                      // Version by last-event
                                                      // time (NOT the global
                                                      // changeVersion, which
                                                      // bumped every tick →
                                                      // flicker) PLUS the
                                                      // per-convo preview epoch
                                                      // so an edited last
                                                      // message (same
                                                      // createdAtMs) still
                                                      // refreshes the preview.
                                                      previewVersion:
                                                          c.lastEventAtMs +
                                                          controller
                                                              .convoPreviewEpoch(
                                                                c.convoId,
                                                              ),
                                                      subtitleFallback:
                                                          subtitleFallback,
                                                    ),
                                            ),
                                            if (missedCallCount > 0) ...[
                                              const SizedBox(width: 6),
                                              _MissedCallBadge(
                                                count: missedCallCount,
                                              ),
                                            ],
                                            if (c.unreadCount > 0) ...[
                                              const SizedBox(width: 6),
                                              _UnreadBadge(
                                                count: c.unreadCount,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }

            // One formula for both platforms: the bar's own footprint plus a
            // single shared gap, so the distance above the bar is identical
            // on iOS and Android instead of two hardcoded numbers.
            final fabBottomOffset = fabBottomOffsetFor(context);
            final fabShiftX = mobileBottomNavSettingsFabShiftX(context);
            // Peer cosmetics (avatar frames / status emoji) in LIST rows obey
            // the user's animation setting; profile pages stay animated.
            return CosmeticAnimationScope(
              enabled: controller.peerCosmeticAnimEnabled,
              child: Scaffold(
              extendBodyBehindAppBar: true,
              appBar: buildAppBar(),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
              floatingActionButton: !_selectionMode
                  ? Padding(
                      padding: EdgeInsets.only(bottom: fabBottomOffset + 4),
                      child: AnimatedFab(
                        visible: _fabVisible,
                        child: Transform.translate(
                          offset: Offset(fabShiftX, 0),
                          child: material_motion.OpenContainer<void>(
                            transitionDuration: const Duration(
                              milliseconds: 320,
                            ),
                            transitionType: material_motion
                                .ContainerTransitionType
                                .fadeThrough,
                            closedElevation: 0,
                            openElevation: 0,
                            closedColor: Colors.transparent,
                            openColor: Theme.of(context).colorScheme.surface,
                            closedShape: const CircleBorder(),
                            openBuilder: (_, __) =>
                                NewChatPickerScreen(controller: controller),
                            closedBuilder: (context, openContainer) {
                              return SecretlyGlassFabButton(
                                tooltip: l10n.newChat,
                                icon: const _ChatBubbleFabIcon(),
                                onPressed: openContainer,
                              );
                            },
                          ),
                        ),
                      ),
                    )
                  : null,
              body: PopScope(
                canPop: !_selectionMode,
                onPopInvokedWithResult: (didPop, _) {
                  if (didPop) return;
                  if (_selectionMode) {
                    _clearSelection();
                  }
                },
                child: DismissKeyboardOnTap(
                  child: FutureBuilder<(CachedRoomCall?, String)>(
                    future: _roomCallBannerFuture,
                    builder: (context, roomCallSnap) {
                      final roomCall = roomCallSnap.data?.$1;
                      final roomCallTitle = roomCallSnap.data?.$2 ?? '';
                      return GestureDetector(
                        // When the Personal reveal is fully open the list is
                        // locked; this handler drives the swipe-up close
                        // directly (1:1 with the finger) so it works regardless
                        // of how many chats are in the list.
                        onVerticalDragUpdate: _personalOpenLocked
                            ? (d) {
                                setState(() {
                                  _isClosingPull = true;
                                  _pullExtent = (_pullExtent + d.delta.dy)
                                      .clamp(0.0, _pullExtentMax);
                                });
                                _updatePersonalRevealEffects();
                              }
                            : null,
                        onVerticalDragEnd: _personalOpenLocked
                            ? (_) {
                                if (_pullExtent > (_personalPullMax * 0.82)) {
                                  _animatePullToExtent(_pullExtentMax);
                                } else {
                                  _animatePullToExtent(0);
                                }
                              }
                            : null,
                        child: Stack(
                          children: [
                            // Telegram-style content edge fade: the list's
                            // CONTENT dissolves to transparent at the top (under
                            // the header islands) and bottom (over the nav-pill
                            // gesture area). Paints no shading itself — it only
                            // masks the list's alpha, so the SystemTopFadeLayer
                            // below and the shell's SystemBottomFadeLayer compose
                            // on top of it.
                            ContentEdgeFade(
                              topFadeEndPx: appBarInset,
                              bottomFadeFraction: 0.07,
                              // Folder switch = a smooth page slide (in the
                              // direction the finger moved through the tabs),
                              // like the jelly indicator gliding under the tabs.
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, anim) {
                                  final incoming =
                                      (child.key as ValueKey?)?.value ==
                                          _activeFolder;
                                  final dx = incoming
                                      ? _folderNavDir * 0.10
                                      : -_folderNavDir * 0.05;
                                  return FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: Offset(dx, 0),
                                        end: Offset.zero,
                                      ).animate(anim),
                                      child: child,
                                    ),
                                  );
                                },
                                layoutBuilder:
                                    (currentChild, previousChildren) => Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                ),
                                child: KeyedSubtree(
                                  key: ValueKey<String>(_activeFolder),
                                  child: buildList(
                                    appBarInset: appBarInset,
                                    topGap: listTopGap,
                                    roomCall: roomCall,
                                    roomCallTitle: roomCallTitle,
                                  ),
                                ),
                              ),
                            ),
                            // Soft top scrim (like the chat screen) so the list
                            // dissolves under the floating header islands.
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: SystemTopFadeLayer(
                                height: appBarInset,
                                blurSigma: 20,
                              ),
                            ),
                            // Pinned under the top islands: the folder strip
                            // (fixed, never scrolls away) then the music island.
                            Positioned(
                              top: appBarInset,
                              left: 0,
                              right: 0,
                              // ONE LAYER FOR THE STACK (2026-07-20). These
                              // islands each owned a glass layer, so the screen
                              // paid one backdrop capture and one shader pass
                              // PER island, every frame — the reason a 14 Pro
                              // Max heats up. They are shapes in a single layer
                              // now, which is how Apple's compositor draws many
                              // glass surfaces at once. Quality stays premium,
                              // so the depth is unchanged; only the pass count
                              // drops. The layer sits ABOVE the list (it is the
                              // pinned overlay), so it still refracts the live
                              // scroll rather than the screen backdrop — the
                              // mistake that flattened build 336.
                              child: liquidGlassIslandsEnabled
                                  ? SecretlyGlassGroup(
                                      grouped: true,
                                      child: lg.AdaptiveLiquidGlassLayer(
                                        settings: secretlyIslandGlass(
                                          Theme.of(context).brightness,
                                        ),
                                        quality: lg.GlassQuality.premium,
                                        child: _pinnedIslandColumn(
                                          context,
                                          controller,
                                        ),
                                      ),
                                    )
                                  : _pinnedIslandColumn(context, controller),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ));
          },
        );
      },
    );
  }
}

class _PersonalGlassEntryCard extends StatelessWidget {
  const _PersonalGlassEntryCard({
    required this.title,
    required this.subtitle,
    required this.menuTooltip,
    required this.protectionEnabled,
    required this.locked,
    required this.revealProgress,
    required this.postOpenCollapseProgress,
    required this.isClosing,
    required this.onTap,
    required this.onMenuTap,
  });

  final String title;
  final String subtitle;
  final String menuTooltip;
  final bool protectionEnabled;
  final bool locked;
  final double revealProgress;
  final double postOpenCollapseProgress;
  final bool isClosing;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final dragProgress = revealProgress.clamp(0.0, 1.0);
    final fillProgress = Curves.easeOutCubic.transform(dragProgress);
    final postOpenProgress = Curves.easeOutCubic.transform(
      postOpenCollapseProgress.clamp(0.0, 1.0),
    );
    final closingCollapseProgress = Curves.easeOutCubic.transform(
      ((dragProgress - 0.24) / 0.76).clamp(0.0, 1.0),
    );
    final colorCollapseProgress = isClosing
        ? closingCollapseProgress
        : postOpenProgress;
    final borderRadius = BorderRadius.circular(26);
    final accentColor = protectionEnabled ? cs.primary : cs.secondary;
    final glassTint = accentColor.withValues(alpha: isDark ? 0.035 : 0.028);
    final iconSurfaceTop = Color.lerp(
      Colors.white.withValues(alpha: isDark ? 0.10 : 0.22),
      accentColor.withValues(alpha: isDark ? 0.94 : 0.84),
      fillProgress,
    )!;
    final iconSurfaceBottom = Color.lerp(
      accentColor.withValues(alpha: isDark ? 0.12 : 0.12),
      accentColor.withValues(alpha: isDark ? 0.74 : 0.66),
      fillProgress,
    )!;
    final cardGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          glassTint,
          Colors.white.withValues(alpha: isDark ? 0.045 : 0.14),
        ),
        Color.alphaBlend(
          accentColor.withValues(alpha: isDark ? 0.015 : 0.018),
          Colors.white.withValues(alpha: isDark ? 0.018 : 0.07),
        ),
      ],
    );
    final borderGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: isDark ? 0.16 : 0.26),
        accentColor.withValues(alpha: isDark ? 0.05 : 0.08),
        Colors.white.withValues(alpha: isDark ? 0.07 : 0.11),
      ],
    );
    final menuSurface = isDark
        ? Colors.white.withValues(alpha: 0.045)
        : Colors.white.withValues(alpha: 0.12);
    final titleColor = isDark ? Colors.white : cs.onSurface;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : cs.onSurfaceVariant.withValues(alpha: 0.86);
    final titleLockColor = accentColor.withValues(alpha: isDark ? 0.88 : 0.76);

    return GlassContainer(
      // Never pass width: double.infinity — glass_kit's frosted layer calls
      // width.toInt(), and double.infinity.toInt() throws ("Unsupported
      // operation: Infinity or NaN toInt"), which crashed the entire chats list
      // render. Omitting width lets glass_kit honor the bounded ListView
      // cross-axis constraint (still full width) without throwing.
      height: 88,
      blur: 22,
      borderWidth: 0.9,
      elevation: isDark ? 1.4 : 2.6,
      isFrostedGlass: true,
      frostedOpacity: isDark ? 0.075 : 0.04,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
      borderRadius: borderRadius,
      gradient: cardGradient,
      borderGradient: borderGradient,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const cardHeight = 88.0;
            const iconSize = 42.0;
            const iconLeft = 14.0;
            final overlayLeft = lerpDouble(0, iconLeft, colorCollapseProgress)!;
            final overlayTop = lerpDouble(
              0,
              (cardHeight - iconSize) / 2,
              colorCollapseProgress,
            )!;
            final overlayWidth = lerpDouble(
              constraints.maxWidth,
              iconSize,
              colorCollapseProgress,
            )!;
            final overlayHeight = lerpDouble(
              cardHeight,
              iconSize,
              colorCollapseProgress,
            )!;
            final overlayRadius = lerpDouble(
              28,
              iconSize / 2,
              colorCollapseProgress,
            )!;
            final overlayStrength = isClosing
                ? Curves.easeOutQuad.transform(dragProgress)
                : Curves.easeOutCubic.transform(
                    (dragProgress * 1.06).clamp(0.0, 1.0),
                  );
            final overlayTopColor = accentColor.withValues(
              alpha: isDark
                  ? lerpDouble(0.10, 0.68, overlayStrength)!
                  : lerpDouble(0.09, 0.58, overlayStrength)!,
            );
            final overlayBottomColor = accentColor.withValues(
              alpha: isDark
                  ? lerpDouble(0.08, 0.60, overlayStrength)!
                  : lerpDouble(0.07, 0.54, overlayStrength)!,
            );
            final iconBorderColor = Color.lerp(
              Colors.white.withValues(alpha: isDark ? 0.12 : 0.22),
              accentColor.withValues(alpha: isDark ? 0.34 : 0.24),
              fillProgress,
            )!;

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: overlayLeft,
                  top: overlayTop,
                  width: overlayWidth,
                  height: overlayHeight,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(overlayRadius),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [overlayTopColor, overlayBottomColor],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: borderRadius,
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [iconSurfaceTop, iconSurfaceBottom],
                                ),
                                border: Border.all(color: iconBorderColor),
                              ),
                              child: Icon(
                                AppIcons.archive,
                                color: isDark ? Colors.white : cs.onPrimary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.1,
                                                color: titleColor,
                                              ),
                                        ),
                                      ),
                                      if (protectionEnabled) ...[
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.lock_rounded,
                                          size: 16,
                                          color: titleLockColor,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: subtitleColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: menuSurface,
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: isDark ? 0.09 : 0.16,
                                  ),
                                ),
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: onMenuTap,
                                  child: Tooltip(
                                    message: menuTooltip,
                                    child: Center(
                                      child: Icon(
                                        AppIcons.more,
                                        size: 16,
                                        color: titleColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _ChatListSubtitlePreview extends StatefulWidget {
  const _ChatListSubtitlePreview({
    required this.controller,
    required this.convoId,
    required this.previewVersion,
    required this.subtitleFallback,
  });

  final AppController controller;
  final String convoId;
  final int previewVersion;
  final String subtitleFallback;

  @override
  State<_ChatListSubtitlePreview> createState() =>
      _ChatListSubtitlePreviewState();
}

class _ChatListSubtitlePreviewState extends State<_ChatListSubtitlePreview> {
  static const int _previewCacheMaxEntries = 160;
  static final Map<String, ChatListPreview> _previewCache =
      <String, ChatListPreview>{};
  ChatListPreview? _preview;
  Future<ChatListPreview>? _future;
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _preview = _previewCache[widget.convoId];
    _future = _loadFor(widget.convoId);
  }

  @override
  void didUpdateWidget(covariant _ChatListSubtitlePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.convoId != widget.convoId ||
        oldWidget.previewVersion != widget.previewVersion) {
      _preview = _previewCache[widget.convoId];
      _future = _loadFor(widget.convoId);
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<ChatListPreview> _loadFor(String convoId) async {
    final requestSeq = ++_loadSeq;
    final preview = await widget.controller.lastMessagePreviewRich(convoId);
    if (!_previewCache.containsKey(convoId) &&
        _previewCache.length >= _previewCacheMaxEntries) {
      _previewCache.remove(_previewCache.keys.first);
    }
    _previewCache[convoId] = preview;
    if (!mounted) return preview;
    if (requestSeq != _loadSeq) return preview;
    if (convoId != widget.convoId) return preview;
    setState(() {
      _preview = preview;
    });
    return preview;
  }

  String _formatLabel(BuildContext context, ChatListPreview preview) {
    switch (preview.kind) {
      case ChatListPreviewKind.photo:
        return wave1Text(context, ru: 'Фотография', en: 'Photo');
      case ChatListPreviewKind.music:
        return wave1Text(context, ru: 'Музыка', en: 'Music');
      case ChatListPreviewKind.voice:
        return wave1Text(
          context,
          ru: 'Голосовое сообщение',
          en: 'Voice message',
          uk: 'Голосове повідомлення',
          es: 'Mensaje de voz',
          pt: 'Mensagem de voz',
          ptBr: 'Mensagem de voz',
          fr: 'Message vocal',
          de: 'Sprachnachricht',
        );
      case ChatListPreviewKind.file:
        return wave1Text(context, ru: 'Файл', en: 'File');
      case ChatListPreviewKind.link:
        return wave1Text(context, ru: 'Ссылка', en: 'Link');
      case ChatListPreviewKind.text:
        return (preview.text ?? '').trim();
      case ChatListPreviewKind.empty:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatListPreview>(
      future: _future,
      initialData: _preview,
      builder: (context, snap) {
        final preview = snap.data;
        if (preview == null || preview.kind == ChatListPreviewKind.empty) {
          return Text(
            widget.subtitleFallback,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }

        final label = _formatLabel(context, preview);

        // Build optional sender-name prefix for rooms.
        final sn = (preview.senderName ?? '').trim();
        final isRoom = widget.convoId.startsWith('group:');
        Widget? senderPrefix;
        if (isRoom && sn.isNotEmpty) {
          final nickColor = AvatarInitials.nicknameColor(
            seed: preview.senderDeviceId ?? sn,
          );
          senderPrefix = Text(
            '$sn: ',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: nickColor,
              fontWeight: FontWeight.w600,
            ),
          );
        }

        if (preview.kind == ChatListPreviewKind.text) {
          final s = label.isNotEmpty ? label : widget.subtitleFallback;
          final greyStyle = TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );
          if (senderPrefix != null) {
            return Row(
              children: [
                senderPrefix,
                Expanded(
                  child: Text(
                    s,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: greyStyle,
                  ),
                ),
              ],
            );
          }
          return Text(
            s,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: greyStyle,
          );
        }

        Widget leading;
        if (preview.kind == ChatListPreviewKind.photo &&
            preview.imageBlobIds.isNotEmpty) {
          leading = Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _PhotoFanMiniPreview(
              controller: widget.controller,
              blobIds: preview.imageBlobIds,
            ),
          );
        } else {
          final icon = switch (preview.kind) {
            ChatListPreviewKind.music => AppIcons.musicNote,
            ChatListPreviewKind.voice => AppIcons.mic,
            ChatListPreviewKind.file => AppIcons.fileOutline,
            ChatListPreviewKind.link => AppIcons.attach,
            _ => AppIcons.attach,
          };
          leading = Icon(icon, size: 16);
        }

        final s = label.isNotEmpty ? label : widget.subtitleFallback;
        final accentColor = Theme.of(context).colorScheme.primary;
        return Row(
          children: [
            if (senderPrefix != null) senderPrefix,
            IconTheme(
              data: IconThemeData(color: accentColor, size: 16),
              child: leading,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DefaultTextStyle.of(
                  context,
                ).style.copyWith(color: accentColor),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PhotoFanMiniPreview extends StatelessWidget {
  const _PhotoFanMiniPreview({required this.controller, required this.blobIds});

  final AppController controller;
  final List<String> blobIds;

  @override
  Widget build(BuildContext context) {
    final unique = blobIds
        .where((b) => b.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    final ids = unique.take(3).toList(growable: false);
    if (ids.isEmpty) {
      return const Icon(AppIcons.photo, size: 16);
    }

    return SizedBox(
      width: 32,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < ids.length; i++)
            Positioned(
              left: (ids.length - 1 - i) * 6.0,
              top: (ids.length - 1 - i) * 1.2,
              child: _PhotoMiniTile(
                controller: controller,
                blobId: ids[i],
                tiltRadians: (i - (ids.length - 1) / 2) * 0.12,
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoMiniTile extends StatefulWidget {
  const _PhotoMiniTile({
    required this.controller,
    required this.blobId,
    required this.tiltRadians,
  });

  final AppController controller;
  final String blobId;
  final double tiltRadians;

  @override
  State<_PhotoMiniTile> createState() => _PhotoMiniTileState();
}

class _PhotoMiniTileState extends State<_PhotoMiniTile> {
  static const int _fileCacheMaxEntries = 120;
  static final Map<String, File?> _fileCache = <String, File?>{};
  File? _file;
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _file = _fileCache[widget.blobId];
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _PhotoMiniTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blobId != widget.blobId) {
      _file = _fileCache[widget.blobId];
      _future = _load();
    }
  }

  Future<File?> _load() async {
    final f = await widget.controller.cachedAttachmentFileByBlobId(
      widget.blobId,
    );
    if (!_fileCache.containsKey(widget.blobId) &&
        _fileCache.length >= _fileCacheMaxEntries) {
      _fileCache.remove(_fileCache.keys.first);
    }
    _fileCache[widget.blobId] = f;
    if (mounted) {
      setState(() {
        _file = f;
      });
    }
    return f;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Transform.rotate(
      angle: widget.tiltRadians,
      child: ClipOval(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.65),
              width: 1,
            ),
          ),
          child: FutureBuilder<File?>(
            future: _future,
            initialData: _file,
            builder: (context, snap) {
              final file = snap.data;
              if (file == null || !file.existsSync()) {
                return Icon(
                  AppIcons.photo,
                  size: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.82),
                );
              }
              // Decode to the 18×18 box (px = logical × DPR) — these tiny
              // avatars never need full-res source bytes in memory.
              final cacheDim = (18 * MediaQuery.devicePixelRatioOf(context))
                  .round();
              return Image.file(
                file,
                fit: BoxFit.cover,
                cacheWidth: cacheDim,
                cacheHeight: cacheDim,
                errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 14),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChatLeading extends StatelessWidget {
  const _ChatLeading({
    required this.selectionMode,
    required this.selected,
    required this.avatarPath,
    required this.title,
    required this.fallbackId,
    required this.muted,
    this.isFavoritesNotes = false,
    this.isOnline = false,
    this.heroTag,
    this.onTap,
    this.frameId,
  });

  final bool selectionMode;
  final bool selected;
  final String? avatarPath;
  final String title;
  final String fallbackId;
  final bool muted;
  final bool isFavoritesNotes;
  final bool isOnline;
  final String? heroTag;
  final VoidCallback? onTap;

  /// Peer's premium animated frame id (cosmetic). Null → plain avatar.
  final String? frameId;

  @override
  Widget build(BuildContext context) {
    final p = avatarPath;
    final hasAvatar = p != null && p.isNotEmpty && File(p).existsSync();

    Widget base;
    if (isFavoritesNotes) {
      base = CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFF0D5F38),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: SvgPicture.asset(
            _ChatsScreenState._noteIconAssetPath,
            fit: BoxFit.contain,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      );
    } else {
      final seed = fallbackId.isNotEmpty ? fallbackId : title;
      // 🔴 СПИСОК — БЕЗ ДВИЖЕНИЯ, НО С ПЕРСОНАЖЕМ. Решение владельца
      // 23.09.2026. Живая рамка смотрит на `TickerMode`: выключенный здесь,
      // он оставляет неподвижную позу и не заводит тикера вовсе. Двадцать
      // рядов по 0.3 мс на кадр — это половина бюджета кадра на слабом
      // Android, и ровно ради этого в проекте живёт атлас испечённых рамок.
      base = TickerMode(
        enabled: false,
        child: FramedAvatar(
        size: 52,
        frameId: frameId,
        avatarPath: hasAvatar ? p : null,
        fallbackSeed: seed,
        fallbackName: title,
        fallbackId: fallbackId,
      ),
      );
    }

    // Wrap with Hero for shared-element transition.
    if (heroTag != null) {
      base = Hero(tag: heroTag!, child: base);
    }

    // Bottom-right indicator: muted or online dot.
    Widget? bottomRight;
    if (muted) {
      bottomRight = DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
        ),
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: Icon(AppIcons.bellOffSolid, size: 14),
        ),
      );
    } else if (isOnline) {
      bottomRight = DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
        ),
        child: const Padding(padding: EdgeInsets.all(2), child: _OnlineDot()),
      );
    }

    // Typing is no longer an avatar badge — the chat-list row subtitle shows a
    // "Пишет" line instead. Only muted / online indicators decorate the avatar.
    final Widget avatar = bottomRight == null
        ? base
        : Stack(
            clipBehavior: Clip.none,
            children: [
              base,
              Positioned(right: -2, bottom: -2, child: bottomRight),
            ],
          );

    // Selection mode shows the checkmark BESIDE (to the left of) the photo —
    // the avatar is never hidden. AnimatedSize springs the row width as the
    // checkmark grows in / out so entering selection feels like a soft bubble
    // rather than a hard cut.
    return AnimatedSize(
      // 🔴 НЕ РЕЗАТЬ. По умолчанию `AnimatedSize` обрезает по своим границам,
      // и холст живой рамки — он почти вдвое шире портрета — терял уши, хвост
      // и ноутбук: работа делалась, а на экране оставалось одно кольцо.
      clipBehavior: Clip.none,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: selectionMode
                ? Padding(
                    key: ValueKey<bool>(selected),
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 24,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          GestureDetector(onTap: onTap, child: avatar),
        ],
      ),
    );
  }
}

/// Single-line text that fades out at the right edge on overflow instead of
/// showing an ellipsis. The shader only modulates alpha (`BlendMode.dstIn`) so
/// the child keeps its own (inherited) color. Mirrors the header name fade in
/// chat_screen.dart for visual consistency.
class _FadingText extends StatelessWidget {
  const _FadingText(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      style: style,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Only fade the trailing edge when the name genuinely doesn't fit the
        // available width. Previously the fade was applied unconditionally, so
        // the last characters of a SHORT name looked like they "disappeared"
        // right before the emoji status. Measure the natural text width and
        // fall back to a plain, fully-visible name when it fits.
        final maxWidth = constraints.maxWidth;
        if (maxWidth.isFinite) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            maxLines: 1,
            textDirection: Directionality.of(context),
          )..layout();
          // +0.5 guards against sub-pixel rounding falsely flagging overflow.
          if (painter.width <= maxWidth + 0.5) {
            return textWidget;
          }
        }
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.0, 0.86, 1.0],
          ).createShader(rect),
          child: textWidget,
        );
      },
    );
  }
}

/// Chat-list row subtitle shown while the peer (1:1) or a room member is
/// typing: animated [TypingDots] + an accent label ("Пишет", or "name + Пишет"
/// for rooms). Replaces the normal last-message preview for that row.
class _ChatListTypingSubtitle extends StatelessWidget {
  const _ChatListTypingSubtitle({
    required this.controller,
    required this.convoId,
    required this.isRoom,
  });

  final AppController controller;
  final String convoId;
  final bool isRoom;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final typingWord = wave1Text(
      context,
      ru: 'Пишет',
      en: 'typing',
      uk: 'Друкує',
      es: 'Escribiendo',
      pt: 'Digitando',
      fr: 'En train d\'écrire',
      de: 'Schreibt',
    );
    return Row(
      children: [
        TypingDots(color: accent),
        const SizedBox(width: 6),
        Expanded(
          child: FutureBuilder<String?>(
            future: isRoom
                ? controller.conversationTypingDisplayName(convoId)
                : Future<String?>.value(null),
            builder: (context, snap) {
              final name = (snap.data ?? '').trim();
              final label = (isRoom && name.isNotEmpty)
                  ? '$name $typingWord'
                  : typingWord;
              return Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: accent,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A small green circle indicating the peer is currently online.
class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 1.5,
        ),
      ),
    );
  }
}

/// Rounded pill badge showing unread message count.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Gray pill placeholder showing message timestamp.
class _TimePill extends StatelessWidget {
  const _TimePill({required this.ms});

  final int ms;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.09)
            : Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _formatTime(ms),
        style: TextStyle(
          color: isDark
              ? Colors.white.withValues(alpha: 0.45)
              : Colors.black.withValues(alpha: 0.38),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }
}

class _MissedCallBadge extends StatelessWidget {
  const _MissedCallBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.surface, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onError,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

String _formatTime(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
}

/// PART 1 — horizontal custom-folder strip above the Chats list. Minimalist:
/// neutral frosted pills matching the top header islands (no gold). Shows "All"
/// plus one chip per custom folder; the active chip is conveyed by weight, not
/// colour. The whole strip is only mounted when at least one custom folder
/// exists (see the build site).
class _ChatsFolderTabStrip extends StatelessWidget {
  const _ChatsFolderTabStrip({
    required this.activeFolder,
    required this.folders,
    required this.allLabel,
    required this.onSelect,
    required this.onFolderLongPress,
  });

  final String activeFolder;
  final List<ChatFolder> folders;
  final String allLabel;
  final ValueChanged<String> onSelect;
  final ValueChanged<ChatFolder> onFolderLongPress;

  @override
  Widget build(BuildContext context) {
    // Segments: "All" + each folder. Equal-width across the screen while few;
    // once there are MORE THAN 4 folders the strip becomes a horizontal scroll
    // (owner spec). Same glass + jelly as the Personal segment / nav bar.
    final ids = <String>['all', for (final f in folders) f.id];
    final segmentLabels = <String>[
      allLabel,
      for (final f in folders)
        (f.emoji != null && f.emoji!.trim().isNotEmpty)
            ? '${f.emoji!.trim()} ${f.name}'
            : f.name,
    ];
    var selectedIndex = ids.indexOf(activeFolder);
    if (selectedIndex < 0) selectedIndex = 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      child: LiquidGlassSegment(
        labels: segmentLabels,
        selected: selectedIndex,
        onSelect: (i) => onSelect(ids[i]),
        // Long-press a folder (not "All", index 0) opens its chip menu.
        onLongPress: (i) {
          if (i >= 1 && i - 1 < folders.length) onFolderLongPress(folders[i - 1]);
        },
        scrollable: folders.length > 4,
      ),
    );
  }
}

class _GlassMenuAction extends StatelessWidget {
  const _GlassMenuAction({
    this.icon,
    this.leading,
    required this.title,
    required this.onTap,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            leading ??
                Icon(
                  icon ?? AppIcons.more,
                  size: 22,
                  color: cs.onSurface.withValues(alpha: 0.92),
                ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeMenuAnimatedIcon extends StatelessWidget {
  const _ThemeMenuAnimatedIcon({required this.darkMode});

  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    final path = darkMode ? AppAssetPaths.sunLottie : AppAssetPaths.moonLottie;
    return _MenuLottieIcon(
      assetPath: path,
      fallback: darkMode ? AppIcons.themeLight : AppIcons.themeDark,
    );
  }
}

class _GroupMenuAnimatedIcon extends StatelessWidget {
  const _GroupMenuAnimatedIcon();

  @override
  Widget build(BuildContext context) {
    return const _MenuLottieIcon(
      assetPath: AppAssetPaths.roomLottie,
      fallback: AppIcons.createGroup,
    );
  }
}

class _FavoritesMenuAnimatedIcon extends StatefulWidget {
  const _FavoritesMenuAnimatedIcon();

  @override
  State<_FavoritesMenuAnimatedIcon> createState() =>
      _FavoritesMenuAnimatedIconState();
}

class _FavoritesMenuAnimatedIconState extends State<_FavoritesMenuAnimatedIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MenuLottieIcon(
      assetPath: AppAssetPaths.starLottie,
      fallback: AppIcons.favorites,
      lottieSize: 19,
      controller: _ctrl,
      onLoaded: (composition) {
        _ctrl.duration = composition.duration * 2;
        _ctrl.repeat();
      },
    );
  }
}

class _CallHistoryMenuAnimatedIcon extends StatelessWidget {
  const _CallHistoryMenuAnimatedIcon({required this.missedCount});

  final int missedCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: _MenuLottieIcon(
              assetPath: AppAssetPaths.callLottie,
              fallback: AppIcons.call,
            ),
          ),
          if (missedCount > 0)
            Positioned(
              top: -2,
              right: -4,
              child: _MissedCallBadge(count: missedCount),
            ),
        ],
      ),
    );
  }
}

class _MenuLottieIcon extends StatelessWidget {
  const _MenuLottieIcon({
    required this.assetPath,
    required this.fallback,
    this.lottieSize = 22,
    this.controller,
    this.onLoaded,
  });

  final String assetPath;
  final IconData fallback;
  final double lottieSize;
  final AnimationController? controller;
  final void Function(LottieComposition)? onLoaded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : cs.onSurface;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
      ),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        child: SizedBox(
          width: lottieSize,
          height: lottieSize,
          child: Lottie.asset(
            assetPath,
            key: ValueKey(assetPath),
            repeat: controller == null,
            animate: controller == null,
            controller: controller,
            onLoaded: onLoaded,
            fit: BoxFit.contain,
            frameRate: FrameRate.max,
            errorBuilder: (_, __, ___) =>
                Icon(fallback, size: 22, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _ChatBubbleFabIcon extends StatefulWidget {
  const _ChatBubbleFabIcon();

  @override
  State<_ChatBubbleFabIcon> createState() => _ChatBubbleFabIconState();
}

class _ChatBubbleFabIconState extends State<_ChatBubbleFabIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.82,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.82,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_ctrl);
    _ctrl.addStatusListener(_onStatus);
    Future<void>.delayed(const Duration(milliseconds: 1200), _play);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      Future<void>.delayed(const Duration(milliseconds: 2600), _play);
    }
  }

  void _play() {
    if (mounted) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Chat bubbles — animated bounce, tinted white, fills upper-left area
          Positioned(
            top: 0,
            left: 0,
            right: 8,
            bottom: 8,
            child: ScaleTransition(
              scale: _scale,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  AppAssetPaths.chatBubbleFabPng,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // Badge: white filled circle + primary-colored "+" (same style as contacts add-badge)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.add, size: 13, color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}
