// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'package:lottie/lottie.dart';
import 'animations/animations.dart';
import 'icons/app_icons.dart';

import '../app/app_controller.dart';
import 'app_asset_paths.dart';
import 'call_history_screen.dart';
import 'contact_action_error_text.dart';
import 'contact_qr_flow.dart';
import 'chat_screen.dart';
import 'l10n.dart';
import 'qr_scan_screen.dart';
import 'share_utils.dart';
import 'settings_screen.dart';
import 'wave1_l10n.dart';
import 'widgets/content_edge_fade.dart';
import 'widgets/dismiss_keyboard_on_tap.dart';
import 'widgets/avatar_initials.dart';
import 'liquid_glass_flags.dart';
import 'widgets/frosted_header_island.dart';
import 'widgets/frosted_top_bar.dart';
import 'widgets/morphing_selection_islands.dart';
import 'widgets/secretly_glass_fab.dart';

enum _AddContactDialogAction { add, invite }

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with TickerProviderStateMixin {
  static const bool _allowSearchSwipe = false;
  // Top-bar matte islands (chat-header style).
  static const double _kIslandH = 48;
  static const double _kIslandR = 24;
  static const double _kActionsIslandW = 152; // search + qr + more
  // Title row + quick-action row (Contacts/Requests tab island removed).
  static const double _kHeaderToolbarH = 4 + _kIslandH + 8 + _kIslandH; // 108
  // Selection mode keeps only the single morphing island row (no quick-actions).
  static const double _kSelToolbarH = 4 + _kIslandH; // 52
  // The "quick actions" row + its gap that collapse away in selection mode.
  static const double _kQuickRowCollapse =
      _kHeaderToolbarH - _kSelToolbarH; // 56
  static const double _searchPullMax = 84;
  static const double _pullOpenDamping = 0.76;
  static const double _pullCloseDamping = 0.48;
  final Set<String> _selectedContacts = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchOpen = false;
  String _searchQuery = '';
  int _lookupToken = 0;
  Timer? _lookupDebounce;
  bool _lookupLoading = false;
  List<UserLookupResult> _lookupResults = const [];
  String? _lookupError;
  double _pullExtent = 0;
  bool _isClosingPull = false;
  bool _lockListScrollUntilDragEnd = false;
  late final AnimationController _pullSnapController;
  Animation<double>? _pullSnapAnimation;
  bool _fabVisible = true;

  // Seamless "bubble morph" from the normal/search islands into the selection
  // islands (mirrors chats/groups). Linear 0..1; the easeOutBack overshoot is
  // applied in [_selReveal] for the island visuals, while the raw linear value
  // drives the toolbar-height / body-inset lerp (no layout wobble).
  late final AnimationController _selRevealController;

  double get _searchRevealRaw => (_pullExtent / _searchPullMax).clamp(0.0, 1.0);
  double get _searchReveal => Curves.easeOutCubic.transform(_searchRevealRaw);

  /// Selection morph progress with the "bubble pop" overshoot (for islands).
  double get _selReveal =>
      Curves.easeOutBack.transform(_selRevealController.value);

  bool get _selectionMode => _selectedContacts.isNotEmpty;

  void _syncSelReveal() {
    _selRevealController.animateTo(_selectionMode ? 1.0 : 0.0);
  }

  void _toggleSelected(String profileId) {
    setState(() {
      if (_selectedContacts.contains(profileId)) {
        _selectedContacts.remove(profileId);
      } else {
        _selectedContacts.add(profileId);
        if (_searchOpen) {
          _searchOpen = false;
          _searchController.clear();
          _searchQuery = '';
          _searchFocusNode.unfocus();
        }
      }
    });
    _syncSelReveal();
  }

  void _clearSelection() {
    setState(() {
      _selectedContacts.clear();
      _fabVisible = true;
    });
    _syncSelReveal();
  }

  void _setFabVisible(bool visible) {
    if (_fabVisible == visible || !mounted) {
      return;
    }
    setState(() {
      _fabVisible = visible;
    });
  }

  void _stopPullSnap() {
    if (_pullSnapController.isAnimating) {
      _pullSnapController.stop();
    }
  }

  void _clearSearchEntryState() {
    _searchController.clear();
    _searchQuery = '';
    _lookupResults = const [];
    _lookupError = null;
    _lookupLoading = false;
    _lookupDebounce?.cancel();
  }

  void _animatePullToExtent(double target, {bool clearSearch = false}) {
    final clamped = target.clamp(0.0, _searchPullMax);
    if ((_pullExtent - clamped).abs() < 0.001) {
      setState(() {
        _pullExtent = clamped;
        _searchOpen = clamped > 0.001;
        if (clearSearch && clamped <= 0.001) _clearSearchEntryState();
      });
      return;
    }
    if (clearSearch) {
      _lookupDebounce?.cancel();
      _searchFocusNode.unfocus();
    }
    _stopPullSnap();
    _pullSnapController.duration = Duration(
      milliseconds: clamped < _pullExtent ? 340 : 300,
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
    _pullSnapController
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted) return;
        if (clearSearch && clamped <= 0.001) setState(_clearSearchEntryState);
      });
  }

  void _toggleSearch({bool? open, bool focusKeyboard = true}) {
    final nextOpen = open ?? !_searchOpen;
    if (_searchOpen == nextOpen &&
        ((nextOpen && _searchRevealRaw >= 1) ||
            (!nextOpen && _pullExtent <= 0.001))) {
      return;
    }
    setState(() {
      _searchOpen = nextOpen;
    });
    _animatePullToExtent(nextOpen ? _searchPullMax : 0, clearSearch: !nextOpen);
    if (!nextOpen) _lookupDebounce?.cancel();
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
    if (notification is UserScrollNotification) {
      switch (notification.direction) {
        case ScrollDirection.reverse:
          _setFabVisible(false);
          break;
        case ScrollDirection.forward:
          _setFabVisible(true);
          break;
        case ScrollDirection.idle:
          break;
      }
    }
    if (_selectionMode) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (!_allowSearchSwipe) return false;

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
          _searchPullMax,
        );
        if (_pullExtent > 0.001) _searchOpen = true;
      });
      _searchFocusNode.unfocus();
      return false;
    }

    final isPushUpUpdate =
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        (notification.scrollDelta ?? 0) > 0 &&
        _pullExtent > 0.001;
    final isPushUpOverscroll =
        notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll > 0 &&
        _pullExtent > 0.001;

    if (_lockListScrollUntilDragEnd && _pullExtent <= 0.001) {
      if (notification is ScrollUpdateNotification &&
          notification.dragDetails != null &&
          (notification.scrollDelta ?? 0) > 0) {
        return true;
      }
      if (notification is OverscrollNotification &&
          notification.dragDetails != null &&
          notification.overscroll > 0) {
        return true;
      }
    }

    if (isPushUpUpdate || isPushUpOverscroll) {
      _stopPullSnap();
      final delta = notification is OverscrollNotification
          ? notification.overscroll
          : (notification as ScrollUpdateNotification).scrollDelta ?? 0;
      setState(() {
        _isClosingPull = true;
        _lockListScrollUntilDragEnd = true;
        _pullExtent = (_pullExtent - (delta * _pullCloseDamping)).clamp(
          0.0,
          _searchPullMax,
        );
        if (_pullExtent <= 0.001) {
          _searchOpen = false;
          _clearSearchEntryState();
        }
      });
      return true;
    }

    if (notification is ScrollEndNotification && _pullExtent > 0.001) {
      if (_isClosingPull) {
        _animatePullToExtent(0, clearSearch: true);
      } else if (_pullExtent < (_searchPullMax * 0.45)) {
        _animatePullToExtent(0, clearSearch: true);
      } else {
        _animatePullToExtent(_searchPullMax);
      }
      _isClosingPull = false;
      return false;
    }

    return false;
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _lookupError = null;
    });
    _lookupDebounce?.cancel();
    _lookupDebounce = Timer(const Duration(milliseconds: 240), () {
      unawaited(_lookupUser(value));
    });
  }

  Future<void> _openContactsTopMenu(BuildContext outerContext) async {
    final action = await showFrostedPopup<String>(
      context: outerContext,
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
                        _ContactsMenuAction(
                          icon: AppIcons.settings,
                          title: context.l10n.settingsTitle,
                          onTap: () => Navigator.of(context).pop('settings'),
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
    if (!outerContext.mounted || action == null) return;
    if (action == 'settings') {
      Navigator.of(outerContext).push(
        SecretlyPageRoute(
          builder: (_) => SettingsScreen(controller: widget.controller),
        ),
      );
    }
  }

  Future<void> _openContactsSelectionMenu(BuildContext outerContext) async {
    final action = await showFrostedPopup<String>(
      context: outerContext,
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
                        _ContactsMenuAction(
                          icon: AppIcons.delete,
                          title: context.l10n.deleteContact,
                          onTap: () => Navigator.of(context).pop('delete'),
                        ),
                        _ContactsMenuAction(
                          icon: AppIcons.block,
                          title: context.l10n.block,
                          onTap: () => Navigator.of(context).pop('block'),
                        ),
                        _ContactsMenuAction(
                          icon: AppIcons.checkCircle,
                          title: context.l10n.unblock,
                          onTap: () => Navigator.of(context).pop('unblock'),
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

    if (!outerContext.mounted || action == null) return;
    final ids = _selectedContacts.toList(growable: false);
    if (ids.isEmpty) return;

    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: outerContext,
        builder: (context) {
          return AlertDialog(
            title: Text(context.l10n.deleteContactsConfirmTitle(ids.length)),
            content: Text(context.l10n.deleteContactsConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.cancel),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.delete),
              ),
            ],
          );
        },
      );
      if (!mounted || ok != true) return;
      for (final pid in ids) {
        await widget.controller.deleteContact(profileId: pid);
      }
      _clearSelection();
      return;
    }

    if (action == 'block') {
      try {
        for (final pid in ids) {
          await widget.controller.setProfileBlocked(
            profileId: pid,
            blocked: true,
            deleteChatHistory: false,
          );
        }
      } catch (e) {
        if (!outerContext.mounted) return;
        ScaffoldMessenger.of(outerContext).showSnackBar(
          SecretlySnackBar(
            content: Text(contactActionErrorText(outerContext.l10n, e)),
          ),
        );
        return;
      }
      _clearSelection();
      return;
    }

    if (action == 'unblock') {
      try {
        for (final pid in ids) {
          await widget.controller.setProfileBlocked(
            profileId: pid,
            blocked: false,
            deleteChatHistory: false,
          );
        }
      } catch (e) {
        if (!outerContext.mounted) return;
        ScaffoldMessenger.of(outerContext).showSnackBar(
          SecretlySnackBar(
            content: Text(contactActionErrorText(outerContext.l10n, e)),
          ),
        );
        return;
      }
      _clearSelection();
    }
  }

  Future<void> _shareInviteFriend() async {
    await shareTextExternally(
      text: buildInviteFriendShareText(
        controller: widget.controller,
        localeTag: wave1LocaleTagFromContext(context),
      ),
    );
  }

  Future<void> _openCallHistory() async {
    await Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => CallHistoryScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _lookupUser(String rawQuery) async {
    final query = rawQuery.trim();
    final token = ++_lookupToken;
    final isLikelyId = query.contains('-');
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _lookupLoading = false;
        _lookupResults = const [];
        _lookupError = null;
      });
      return;
    }

    if (!isLikelyId && query.runes.length < 2) {
      if (!mounted) return;
      setState(() {
        _lookupLoading = false;
        _lookupResults = const [];
        _lookupError = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _lookupLoading = true;
      });
    }

    try {
      final result = await widget.controller.lookupUsers(query);
      if (!mounted || token != _lookupToken) return;
      setState(() {
        _lookupResults = result;
        _lookupError = null;
        _lookupLoading = false;
      });
    } catch (e) {
      if (!mounted || token != _lookupToken) return;
      setState(() {
        _lookupResults = const [];
        _lookupError = contactLookupErrorText(context.l10n, e);
        _lookupLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _pullSnapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          final animation = _pullSnapAnimation;
          if (animation == null || !mounted) return;
          setState(() {
            _pullExtent = animation.value.clamp(0.0, _searchPullMax);
            _searchOpen = _pullExtent > 0.001;
          });
        });
    _selRevealController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 340),
          value: _selectionMode ? 1.0 : 0.0,
        )..addListener(() {
          if (mounted) setState(() {});
        });
  }

  @override
  void dispose() {
    _selRevealController.dispose();
    _pullSnapController.dispose();
    _lookupDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          // Access the tab controller so we can force Contacts tab during selection mode.
          final tab = DefaultTabController.of(context);
          if (_selectionMode && tab.index != 0) {
            // Best-effort: keep selection mode only in Contacts tab.
            Future.microtask(() => tab.animateTo(0));
          }

          AppBar buildAppBar() {
            final s = _searchReveal;
            final selC = _selRevealController.value.clamp(0.0, 1.0);
            final selO = _selReveal;
            final toolbarH = _kHeaderToolbarH - _kQuickRowCollapse * selC;
            return frostedAppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: toolbarH,
              flexibleSpace: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: title island + actions island (search bubble).
                      SizedBox(
                        height: _kIslandH,
                        child: MorphingSelectionIslands(
                          searchReveal: s,
                          selectionReveal: selO,
                          islandRadius: _kIslandR,
                          islandHeight: _kIslandH,
                          leftPadding: 16,
                          centerLeftNormal: false,
                          compactRightWidth: _kActionsIslandW,
                          selectionActionsWidth: 56,
                          leftNormalContent: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              context.l10n.contactsTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 19,
                              ),
                            ),
                          ),
                          leftSelectionContent: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: context.l10n.cancelSelection,
                                icon: const Icon(AppIcons.close),
                                onPressed: _clearSelection,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 10,
                                  left: 2,
                                ),
                                child: Text(
                                  '${_selectedContacts.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          rightCompactContent: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: context.l10n.search,
                                icon: const Icon(AppIcons.search),
                                onPressed: () =>
                                    _toggleSearch(focusKeyboard: true),
                              ),
                              IconButton(
                                tooltip: context.l10n.scanQr,
                                icon: const Icon(AppIcons.qrScanner),
                                onPressed: () => _scanQr(context),
                              ),
                              IconButton(
                                tooltip: context.l10n.more,
                                icon: const Icon(AppIcons.moreVert, size: 23),
                                onPressed: () => _openContactsTopMenu(context),
                              ),
                            ],
                          ),
                          rightSearchContent: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(AppIcons.search, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  key: const ValueKey('contacts-search-open'),
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  autofocus: false,
                                  onTapOutside: (_) {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                  },
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: false,
                                    fillColor: Colors.transparent,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    hintText: context.l10n.queryLabel,
                                  ),
                                  onChanged: _onSearchChanged,
                                ),
                              ),
                              IconButton(
                                tooltip: context.l10n.cancel,
                                icon: const Icon(AppIcons.close),
                                onPressed: () => _toggleSearch(
                                  open: false,
                                  focusKeyboard: false,
                                ),
                              ),
                            ],
                          ),
                          rightSelectionContent: IconButton(
                            tooltip: context.l10n.more,
                            icon: const Icon(AppIcons.moreVert, size: 23),
                            onPressed: () =>
                                _openContactsSelectionMenu(context),
                          ),
                        ),
                      ),
                      // Quick-action islands collapse + fade out in selection.
                      ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: (1 - selC).clamp(0.0, 1.0),
                          child: Opacity(
                            opacity: (1 - selO).clamp(0.0, 1.0),
                            child: IgnorePointer(
                              ignoring: selC > 0.5,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: _kIslandH,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: FrostedHeaderIsland(
                                            radius: _kIslandR,
                                            height: _kIslandH,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      _kIslandR,
                                                    ),
                                                onTap: _shareInviteFriend,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      AppIcons.send,
                                                      size: 18,
                                                      color: Color(0xFF2092E7),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        wave1Text(
                                                          context,
                                                          ru: 'Добавить друзей',
                                                          en: 'Add friends',
                                                          uk: 'Додати друзів',
                                                          es: 'Agregar amigos',
                                                          pt: 'Adicionar amigos',
                                                          fr: 'Ajouter des amis',
                                                          de: 'Freunde hinzufugen',
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FrostedHeaderIsland(
                                            radius: _kIslandR,
                                            height: _kIslandH,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      _kIslandR,
                                                    ),
                                                onTap: _openCallHistory,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      AppIcons.call,
                                                      size: 18,
                                                      color: Color(0xFF2DBE4C),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        wave1Text(
                                                          context,
                                                          ru: 'Журнал звонков',
                                                          en: 'Call log',
                                                          uk: 'Журнал дзвінків',
                                                          es: 'Registro de llamadas',
                                                          pt: 'Registo de chamadas',
                                                          ptBr:
                                                              'Historico de chamadas',
                                                          fr: 'Journal d appels',
                                                          de: 'Anrufliste',
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
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
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final media = MediaQuery.of(context);
          final topBodyInset =
              media.padding.top +
              (_kHeaderToolbarH -
                  _kQuickRowCollapse *
                      _selRevealController.value.clamp(0.0, 1.0)) +
              6;

          // One formula for both platforms: the bar's own footprint plus a single
          // shared gap, so the distance above the bar is identical on iOS and
          // Android instead of two hardcoded numbers.
          final fabBottomOffset = fabBottomOffsetFor(context);
          final fabShiftX = mobileBottomNavSettingsFabShiftX(context);
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: buildAppBar(),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: _selectionMode
                ? null
                : Padding(
                    padding: EdgeInsets.only(bottom: fabBottomOffset + 4),
                    child: AnimatedFab(
                      visible: _fabVisible,
                      child: Transform.translate(
                        offset: Offset(fabShiftX, 0),
                        child: SecretlyGlassFabButton(
                          tooltip: context.l10n.addContact,
                          icon: const _ContactsFabLottieIcon(),
                          onPressed: () => _showAddContactDialog(context),
                        ),
                      ),
                    ),
                  ),
            body: PopScope(
              canPop: !_selectionMode,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                if (_selectionMode) {
                  _clearSelection();
                }
              },
              child: DismissKeyboardOnTap(
                child: Stack(
                  children: [
                    // Telegram-style content edge fade: the lists' CONTENT
                    // dissolves to transparent at the top (under the header
                    // islands) and bottom (over the nav-pill gesture area).
                    // Wraps the lookup pane and both tabs at once. Paints no
                    // shading itself — it only masks the lists' alpha, so the
                    // SystemTopFadeLayer below and the shell's
                    // SystemBottomFadeLayer compose on top of it.
                    ContentEdgeFade(
                      topFadeEndPx: topBodyInset,
                      bottomFadeFraction: 0.07,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleSearchSwipe,
                        child: (_searchOpen && _searchQuery.trim().isNotEmpty)
                            ? _UserLookupPane(
                                controller: controller,
                                topInset: topBodyInset,
                                query: _searchQuery.trim(),
                                loading: _lookupLoading,
                                results: _lookupResults,
                                error: _lookupError,
                              )
                            : TabBarView(
                                physics: _selectionMode
                                    ? const NeverScrollableScrollPhysics()
                                    : null,
                                children: [
                                  _ContactsTab(
                                    controller: controller,
                                    topInset: topBodyInset,
                                    selectionMode: _selectionMode,
                                    selected: _selectedContacts,
                                    onToggleSelected: _toggleSelected,
                                    onInviteFriends: _shareInviteFriend,
                                    onOpenCallHistory: _openCallHistory,
                                  ),
                                  _RequestsTab(
                                    controller: controller,
                                    topInset: topBodyInset,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SystemTopFadeLayer(
                        height: topBodyInset,
                        blurSigma: 20,
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

  Future<void> _showAddContactDialog(BuildContext context) async {
    final profileIdController = TextEditingController();
    final nameController = TextEditingController();
    final l10n = context.l10n;

    final action = await showDialog<_AddContactDialogAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
          title: Row(
            children: [
              Expanded(child: Text(l10n.addContact)),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: profileIdController,
                decoration: InputDecoration(
                  labelText: l10n.secretlyIdLabel,
                  hintText: l10n.secretlyIdHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.nameOptionalLabel),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_AddContactDialogAction.invite),
              child: Text(
                wave1Text(
                  context,
                  ru: 'Пригласить друга',
                  en: 'Invite a friend',
                  uk: 'Запросити друга',
                  es: 'Invitar a un amigo',
                  pt: 'Convidar um amigo',
                  fr: 'Inviter un ami',
                  de: 'Freund einladen',
                ),
              ),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_AddContactDialogAction.add),
              child: Text(l10n.add),
            ),
          ],
        );
      },
    );

    if (action == _AddContactDialogAction.invite) {
      profileIdController.dispose();
      nameController.dispose();
      await _shareInviteFriend();
      return;
    }

    if (action != _AddContactDialogAction.add) {
      profileIdController.dispose();
      nameController.dispose();
      return;
    }

    final profileId = profileIdController.text.trim();
    final name = nameController.text.trim();
    profileIdController.dispose();
    nameController.dispose();
    if (profileId.isEmpty) return;

    try {
      await widget.controller.addContact(
        profileId: profileId,
        displayName: name.isEmpty ? null : name,
        displayNameIsCustom: name.isNotEmpty,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(contactActionErrorText(context.l10n, e)),
        ),
      );
    }
  }

  Future<void> _scanQr(BuildContext context) async {
    final raw = await QrScanScreen.scan(
      context,
      title: context.l10n.scanContactQrTitle,
    );
    if (!context.mounted) return;
    if (raw == null || raw.trim().isEmpty) return;
    await handleContactQrScan(
      context: context,
      controller: widget.controller,
      raw: raw,
    );
  }
}

class _ContactsMenuAction extends StatelessWidget {
  const _ContactsMenuAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
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
            Icon(icon, size: 22, color: cs.onSurface.withValues(alpha: 0.92)),
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

class _ContactsTab extends StatelessWidget {
  const _ContactsTab({
    required this.controller,
    required this.topInset,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelected,
    required this.onInviteFriends,
    required this.onOpenCallHistory,
  });

  final AppController controller;
  final double topInset;
  final bool selectionMode;
  final Set<String> selected;
  final void Function(String profileId) onToggleSelected;
  final Future<void> Function() onInviteFriends;
  final Future<void> Function() onOpenCallHistory;

  Widget _contactAvatar(
    BuildContext context, {
    required String? avatarPath,
    required String title,
    required String fallbackId,
  }) {
    final existingPath = avatarPath?.trim();
    if (existingPath != null &&
        existingPath.isNotEmpty &&
        File(existingPath).existsSync()) {
      return CircleAvatar(backgroundImage: FileImage(File(existingPath)));
    }

    final seed = fallbackId.trim().isNotEmpty ? fallbackId.trim() : title;
    // Default CircleAvatar radius is 20 → match it exactly.
    return AvatarInitials.fallbackBubble(
      context: context,
      radius: 20,
      seed: seed,
      displayName: title,
      fallbackId: fallbackId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: controller.changed,
      builder: (context, _) {
        return FutureBuilder<List<Contact>>(
          future: controller.listContacts(),
          builder: (context, snapshot) {
            final bottomInset = MediaQuery.of(context).viewPadding.bottom + 120;
            final contacts = (snapshot.data ?? const [])
                .where((c) => !controller.isSavedMessagesConvo(c.profileId))
                .toList(growable: false);
            if (contacts.isEmpty) {
              return ListView(
                padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                    child: Center(child: Text(context.l10n.noContactsYet)),
                  ),
                ],
              );
            }
            // Lazy: build only the visible rows. Was an eager
            // `ListView(children: [...contacts.map(...)])` that built EVERY
            // contact tile up front — janky for large contact lists.
            return ListView.builder(
              padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
              itemCount: contacts.length,
              itemBuilder: (context, i) {
                final c = contacts[i];
                final baseTitle =
                    (c.displayName != null && c.displayName!.isNotEmpty)
                    ? c.displayName!
                    : c.profileId;
                final title = (c.emoji != null && c.emoji!.isNotEmpty)
                    ? '$baseTitle ${c.emoji!}'
                    : baseTitle;
                final isSelected = selected.contains(c.profileId);

                return ListTile(
                  leading: selectionMode
                      ? CircleAvatar(
                          child: Icon(
                            isSelected
                                ? AppIcons.check
                                : AppIcons.radioUnchecked,
                          ),
                        )
                      : _contactAvatar(
                          context,
                          avatarPath: c.avatarPath,
                          title: baseTitle,
                          fallbackId: c.profileId,
                        ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onLongPress: () => onToggleSelected(c.profileId),
                  onTap: () {
                    if (selectionMode) {
                      onToggleSelected(c.profileId);
                      return;
                    }
                    Navigator.of(context).push(
                      SecretlyPageRoute(
                        builder: (_) => ChatScreen(
                          controller: controller,
                          convoId: c.profileId,
                          title: title,
                          peerProfileIdForSend: c.profileId,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({required this.controller, required this.topInset});

  final AppController controller;
  final double topInset;

  Widget _requestAvatar(
    BuildContext context, {
    required RequestItem request,
    required String title,
  }) {
    final avatarPath = request.avatarPath?.trim();
    if (avatarPath != null &&
        avatarPath.isNotEmpty &&
        File(avatarPath).existsSync()) {
      return CircleAvatar(backgroundImage: FileImage(File(avatarPath)));
    }

    final seed = request.profileId.trim().isNotEmpty
        ? request.profileId.trim()
        : title;
    return AvatarInitials.fallbackBubble(
      context: context,
      radius: 20,
      seed: seed,
      displayName: title,
      fallbackId: request.profileId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: controller.changed,
      builder: (context, _) {
        return FutureBuilder<List<RequestItem>>(
          future: controller.listRequests(),
          builder: (context, snapshot) {
            final reqs = snapshot.data ?? const [];
            if (reqs.isEmpty) {
              return Center(child: Text(context.l10n.noRequests));
            }

            return ListView.builder(
              padding: EdgeInsets.only(
                top: topInset,
                bottom: MediaQuery.of(context).viewPadding.bottom + 120,
              ),
              itemCount: reqs.length,
              itemBuilder: (context, i) {
                final r = reqs[i];
                final title =
                    (r.nickname != null && r.nickname!.trim().isNotEmpty)
                    ? r.nickname!.trim()
                    : r.profileId;
                return ListTile(
                  leading: _requestAvatar(context, request: r, title: title),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: FutureBuilder<String?>(
                    future: controller.lastMessagePreview(r.convoId),
                    builder: (context, snap) {
                      final preview = snap.data;
                      if (preview == null || preview.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(r.lastEventAtMs),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: context.l10n.block,
                        icon: const Icon(AppIcons.block),
                        onPressed: () async {
                          try {
                            await controller.blockRequest(r.profileId);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SecretlySnackBar(
                                content: Text(
                                  contactActionErrorText(context.l10n, e),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        tooltip: context.l10n.accept,
                        icon: const Icon(AppIcons.checkCircle),
                        onPressed: () async {
                          try {
                            await controller.acceptRequest(r.profileId);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SecretlySnackBar(
                                content: Text(
                                  contactActionErrorText(context.l10n, e),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      SecretlyPageRoute(
                        builder: (_) => ChatScreen(
                          controller: controller,
                          convoId: r.convoId,
                          title: title,
                          requestProfileId: r.profileId,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _UserLookupPane extends StatelessWidget {
  const _UserLookupPane({
    required this.controller,
    required this.topInset,
    required this.query,
    required this.loading,
    required this.results,
    required this.error,
  });

  final AppController controller;
  final double topInset;
  final String query;
  final bool loading;
  final List<UserLookupResult> results;
  final String? error;

  @override
  Widget build(BuildContext context) {
    // Telegram-style two-tier search: existing contacts that match the query
    // are shown first (instant, local), the global directory results below.
    return FutureBuilder<List<Contact>>(
      future: controller.listContacts(),
      builder: (context, snapshot) {
        final ql = query.toLowerCase();
        final localMatches = (snapshot.data ?? const <Contact>[])
            .where((c) => !controller.isSavedMessagesConvo(c.profileId))
            .where((c) {
              final name = (c.displayName ?? '').toLowerCase();
              final pid = c.profileId.toLowerCase();
              return ql.isEmpty || name.contains(ql) || pid.contains(ql);
            })
            .toList(growable: false);
        return _buildBody(context, localMatches);
      },
    );
  }

  Widget _buildBody(BuildContext context, List<Contact> localMatches) {
    final l10n = context.l10n;
    if (loading && localMatches.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topInset),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final localIds = localMatches.map((c) => c.profileId).toSet();
    final globalResults = results
        .where((r) => !localIds.contains(r.profileId))
        .toList(growable: false);

    if (!loading &&
        localMatches.isEmpty &&
        globalResults.isEmpty &&
        (error == null || error!.isEmpty)) {
      return Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.noMatches),
          ),
        ),
      );
    }

    final children = <Widget>[];
    if (localMatches.isNotEmpty) {
      children.add(
        _sectionHeader(
          context,
          wave1Text(context, ru: 'Контакты', en: 'Contacts'),
        ),
      );
      for (final c in localMatches) {
        final title =
            (c.displayName != null && c.displayName!.trim().isNotEmpty)
            ? c.displayName!.trim()
            : c.profileId;
        children.add(
          _buildResultTile(
            context,
            UserLookupResult(
              profileId: c.profileId,
              nickname:
                  (c.displayName != null && c.displayName!.trim().isNotEmpty)
                  ? c.displayName!.trim()
                  : null,
              alreadyInContacts: true,
            ),
            title,
          ),
        );
      }
    }

    if (error != null && error!.isNotEmpty && globalResults.isEmpty) {
      // Surface the directory error only when it didn't yield anything.
      children.add(
        Padding(padding: const EdgeInsets.all(24), child: Text(error!)),
      );
    } else if (globalResults.isNotEmpty) {
      children.add(
        _sectionHeader(
          context,
          wave1Text(context, ru: 'Глобальный поиск', en: 'Global search'),
        ),
      );
      if (loading) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      for (final r in globalResults) {
        final title = (r.nickname != null && r.nickname!.trim().isNotEmpty)
            ? r.nickname!.trim()
            : r.profileId;
        children.add(_buildResultTile(context, r, title));
      }
    } else if (loading) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        topInset + 8,
        0,
        MediaQuery.of(context).viewPadding.bottom + 120,
      ),
      children: children,
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.55),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildResultTile(
    BuildContext context,
    UserLookupResult r,
    String title,
  ) {
    final l10n = context.l10n;
    return ListTile(
      leading: AvatarInitials.fallbackBubble(
        context: context,
        radius: 20,
        seed: r.profileId,
        displayName: title,
        fallbackId: r.profileId,
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: r.alreadyInContacts
          ? FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).push(
                  SecretlyPageRoute(
                    builder: (_) => ChatScreen(
                      controller: controller,
                      convoId: r.profileId,
                      title: title,
                      peerProfileIdForSend: r.profileId,
                    ),
                  ),
                );
              },
              child: Text(l10n.contactDetailsChat),
            )
          : FilledButton(
              onPressed: () async {
                try {
                  await controller.addContact(
                    profileId: r.profileId,
                    displayName:
                        (r.nickname != null && r.nickname!.trim().isNotEmpty)
                        ? r.nickname!.trim()
                        : null,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SecretlySnackBar(
                      content: Text(contactActionErrorText(l10n, e)),
                    ),
                  );
                  return;
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SecretlySnackBar(content: Text(l10n.addContact)),
                );
              },
              child: Text(l10n.add),
            ),
    );
  }
}

class _ContactsFabLottieIcon extends StatelessWidget {
  const _ContactsFabLottieIcon();

  static const String _assetPath = AppAssetPaths.addUserMaleLottie;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
              child: Lottie.asset(
                _assetPath,
                repeat: true,
                animate: true,
                fit: BoxFit.contain,
                frameRate: FrameRate.max,
                errorBuilder: (_, __, ___) => const Icon(
                  AppIcons.personAdd,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(AppIcons.add, size: 11, color: cs.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(int ms) {
  if (ms <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
