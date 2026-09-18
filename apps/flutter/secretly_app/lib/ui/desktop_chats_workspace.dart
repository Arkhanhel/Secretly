// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/app_controller.dart';
import '../models/e2e_payload_v1.dart';
import '../rooms/room_call_state.dart';
import 'app_asset_paths.dart';
import 'window_title.dart';
import 'chat_screen.dart';
import 'contact_details_screen.dart';
import 'contacts_screen.dart';
import 'favorites_title.dart';
import 'icons/app_icons.dart';
import 'profile_screen.dart';
import 'room_call_screen.dart';
import 'room_details_screen.dart';
import 'settings_screen.dart';
import 'wave1_l10n.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/room_call_presence.dart';

const String _favoritesNoteAssetPath = AppAssetPaths.favoritesNotePng;

// ── Desktop UI size tokens ───────────────────────────────────────────────────
const double _kAvatarRadiusLg = 22.0; // list item avatar
const double _kAvatarRadiusMd = 16.0; // header mini avatar
const double _kIconSizeLg = 22.0; // primary toolbar icons
const double _kIconSizeMd = 18.0; // secondary buttons, search
const double _kIconSizeSm = 13.0; // pin/mute status icons
const double _kBtnSize = 34.0; // icon button tap area
const double _kSearchHeight = 36.0; // search field height
const double _kHeaderControlSize = 36.0;
const double _kFilterChipH = 28.0; // filter chip row height
const double _kChipHPad = 12.0; // filter chip horizontal padding

String _desktopConversationTitle(
  BuildContext context,
  AppController controller,
  Conversation convo,
) {
  return controller.isSavedMessagesConvo(convo.convoId)
      ? localizedFavoritesTitle(context)
      : convo.title;
}

String _desktopText(
  BuildContext context, {
  required String ru,
  required String en,
  String? uk,
  String? es,
  String? pt,
  String? ptBr,
  String? fr,
  String? de,
}) {
  return wave1Text(
    context,
    ru: ru,
    en: en,
    uk: uk,
    es: es,
    pt: pt,
    ptBr: ptBr,
    fr: fr,
    de: de,
  );
}

const double _kSectionGap = 8.0; // common vertical gap
const double _kPanelRadius = 20.0; // panel border radius
const double _kItemRadius = 12.0; // list item border radius
const double _kBadgeMinW = 20.0; // unread badge min width
const double _kOnlineDotSize = 11.0; // online indicator dot
const double _kOnlineDotBorder = 2.0;
const double _kListItemVPad = 9.0; // list item vertical padding
const double _kListItemHPad = 10.0; // list item horizontal padding
const double _kHeaderVPad = 11.0; // panel header vertical padding

class DesktopChatsWorkspace extends StatefulWidget {
  const DesktopChatsWorkspace({
    super.key,
    required this.controller,
    this.shellTab = 0,
  });

  final AppController controller;
  final int shellTab;

  @override
  State<DesktopChatsWorkspace> createState() => _DesktopChatsWorkspaceState();
}

class _DesktopChatsWorkspaceState extends State<DesktopChatsWorkspace> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  String? _selectedConvoId;
  double _listPanelWidth = 360;
  double _detailsPanelWidth = 340;
  bool _rightPaneVisible = true;
  _RightPaneMode _rightPaneMode = _RightPaneMode.chatDetails;
  Conversation? _detailsConvo;
  _ChatFilter _chatFilter = _ChatFilter.all;
  List<Conversation> _cachedItems = const [];

  @override
  void initState() {
    super.initState();
    _rightPaneVisible = widget.controller.desktopRightPaneVisible;
    _syncPaneModeWithShellTab();
    HardwareKeyboard.instance.addHandler(_handleKeyboardShortcut);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyboardShortcut);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _handleKeyboardShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted) return false;
    final ctrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;

    // Ctrl+, (или Cmd+,) → открыть Настройки
    if (ctrl && event.logicalKey == LogicalKeyboardKey.comma) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showSettingsDialog(context);
      });
      return true;
    }

    // Ctrl+K (или Cmd+K) → открыть Quick Switcher
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyK) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showQuickSwitcher();
      });
      return true;
    }

    // Alt+↑ → предыдущий чат
    if (alt && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _selectAdjacentChat(direction: -1);
      });
      return true;
    }

    // Alt+↓ → следующий чат
    if (alt && event.logicalKey == LogicalKeyboardKey.arrowDown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _selectAdjacentChat(direction: 1);
      });
      return true;
    }

    // Esc → закрыть правую панель (только если она открыта и есть что закрывать)
    if (!ctrl &&
        !alt &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _rightPaneVisible &&
        widget.shellTab <= 1 &&
        _rightPaneMode != _RightPaneMode.chatDetails) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _rightPaneMode = _RightPaneMode.chatDetails;
        });
      });
      return false; // don't consume — let Esc also close search in ChatScreen
    }

    return false;
  }

  void _selectAdjacentChat({required int direction}) {
    final items = _cachedItems;
    if (items.isEmpty) return;
    final currentId = _selectedConvoId;
    final currentIndex = currentId == null
        ? -1
        : items.indexWhere((c) => c.convoId == currentId);
    final nextIndex = (currentIndex + direction).clamp(0, items.length - 1);
    if (nextIndex != currentIndex) {
      setState(() {
        _selectedConvoId = items[nextIndex].convoId;
        if (widget.shellTab <= 1) {
          _rightPaneMode = _RightPaneMode.chatDetails;
          _detailsConvo = null;
        }
      });
    }
  }

  Future<void> _showQuickSwitcher() async {
    // Load ALL conversations (unfiltered) for the switcher.
    final allConvos = await widget.controller.listConversations();
    if (!mounted) return;

    // Sort: pinned first, then by lastEventAtMs desc.
    final sorted = List<Conversation>.from(allConvos)
      ..sort((a, b) {
        final aPin = a.pinnedAtMs ?? 0;
        final bPin = b.pinnedAtMs ?? 0;
        if (aPin != bPin) return bPin.compareTo(aPin);
        return b.lastEventAtMs.compareTo(a.lastEventAtMs);
      });

    final selectedId = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _QuickSwitcherDialog(
        conversations: sorted,
        currentConvoId: _selectedConvoId,
        controller: widget.controller,
      ),
    );

    if (!mounted || selectedId == null) return;
    setState(() {
      _selectedConvoId = selectedId;
      if (widget.shellTab <= 1) {
        _rightPaneMode = _RightPaneMode.chatDetails;
        _detailsConvo = null;
      }
    });
  }

  String _label({required String ru, required String en}) {
    return _desktopText(context, ru: ru, en: en);
  }

  void _openDetailsInline(Conversation convo) {
    setState(() {
      _detailsConvo = convo;
      _rightPaneMode = convo.convoId.startsWith('group:')
          ? _RightPaneMode.roomDetails
          : _RightPaneMode.contactDetails;
    });
  }

  void _openRoomCall(Conversation convo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomCallScreen(
          controller: widget.controller,
          groupId: convo.convoId,
          initialTitle: convo.title,
        ),
      ),
    );
  }

  void _syncPaneModeWithShellTab() {
    final nextMode = switch (widget.shellTab) {
      3 => _RightPaneMode.contacts,
      _ => _RightPaneMode.chatDetails,
    };
    if (_rightPaneMode != nextMode) {
      _rightPaneMode = nextMode;
    }
    final mustShowPane = widget.shellTab == 3;
    if (mustShowPane && !_rightPaneVisible) {
      _rightPaneVisible = true;
      unawaited(widget.controller.setDesktopRightPaneVisible(true));
    }
  }

  void _setRightPaneVisible(bool visible) {
    if (_rightPaneVisible == visible) return;
    setState(() {
      _rightPaneVisible = visible;
    });
    unawaited(widget.controller.setDesktopRightPaneVisible(visible));
  }

  void _showRightPaneMode(_RightPaneMode mode) {
    setState(() {
      _rightPaneVisible = true;
      _rightPaneMode = mode;
    });
    unawaited(widget.controller.setDesktopRightPaneVisible(true));
  }

  void _showSettingsDialog(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _DesktopModalShell(
        title: _desktopText(ctx, ru: 'Настройки', en: 'Settings'),
        child: SettingsScreen(controller: widget.controller),
      ),
    );
  }

  void _showProfileDialog(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _DesktopModalShell(
        title: _desktopText(ctx, ru: 'Профиль', en: 'Profile'),
        child: ProfileScreen(controller: widget.controller),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant DesktopChatsWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shellTab != widget.shellTab) {
      if (widget.shellTab == 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showProfileDialog(context);
        });
      } else if (widget.shellTab == 4) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showSettingsDialog(context);
        });
      } else {
        _syncPaneModeWithShellTab();
      }
    }
  }

  Widget _buildRightPane({
    required Conversation? selected,
    required Map<String, CachedRoomCall> activeRoomCalls,
  }) {
    final detailsConvo = _detailsConvo ?? selected;
    switch (_rightPaneMode) {
      case _RightPaneMode.profile:
        return ProfileScreen(controller: widget.controller);
      case _RightPaneMode.contacts:
        return ContactsScreen(controller: widget.controller);
      case _RightPaneMode.settings:
        return SettingsScreen(controller: widget.controller);
      case _RightPaneMode.contactDetails:
        if (detailsConvo == null) {
          return _DesktopPlaceholder(
            title: _label(ru: 'Профиль контакта', en: 'Contact profile'),
            subtitle: _label(
              ru: 'Выберите чат слева',
              en: 'Select a chat from the list',
            ),
          );
        }
        final peerId = detailsConvo.peerProfileId ?? detailsConvo.convoId;
        return _DesktopInlineDetailsPane(
          title: detailsConvo.title,
          onBack: () =>
              setState(() => _rightPaneMode = _RightPaneMode.chatDetails),
          child: ContactDetailsScreen(
            controller: widget.controller,
            peerProfileId: peerId,
            convoId: detailsConvo.convoId,
            initialTitle: detailsConvo.title,
            initialAvatarPath: detailsConvo.avatarPath,
          ),
        );
      case _RightPaneMode.roomDetails:
        if (detailsConvo == null) {
          return _DesktopPlaceholder(
            title: _label(ru: 'Профиль группы', en: 'Group profile'),
            subtitle: _label(
              ru: 'Выберите группу слева',
              en: 'Select a group from the list',
            ),
          );
        }
        return _DesktopInlineDetailsPane(
          title: detailsConvo.title,
          onBack: () =>
              setState(() => _rightPaneMode = _RightPaneMode.chatDetails),
          child: RoomDetailsScreen(
            controller: widget.controller,
            groupId: detailsConvo.convoId,
            initialTitle: detailsConvo.title,
          ),
        );
      case _RightPaneMode.chatDetails:
        return _DesktopInfoPanel(
          selected: selected,
          onOpenDetails: selected == null
              ? null
              : () => _openDetailsInline(selected),
          onMuteToggle: selected == null
              ? null
              : () async {
                  await widget.controller.setChatMuted(
                    convoId: selected.convoId,
                    muted: !selected.muted,
                  );
                },
          onOpenProfilePane: () => _showProfileDialog(context),
          onOpenContactsPane: () {
            _showRightPaneMode(_RightPaneMode.contacts);
          },
          onOpenSettingsPane: () => _showSettingsDialog(context),
          activeRoomCall: selected == null
              ? null
              : activeRoomCalls[selected.convoId],
          onOpenRoomCall:
              selected == null || !selected.convoId.startsWith('group:')
              ? null
              : () => _openRoomCall(selected),
          labelBuilder: _label,
          controller: widget.controller,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final cs = Theme.of(context).colorScheme;
    _syncPaneModeWithShellTab();
    return StreamBuilder<void>(
      stream: controller.changed,
      builder: (context, _) {
        return FutureBuilder<
          ({
            List<Conversation> conversations,
            Map<String, CachedRoomCall> activeRoomCalls,
          })
        >(
          future: () async {
            final conversations = await controller.listConversations();
            final activeCalls = await controller.listCachedActiveRoomCalls();
            final activeRoomCalls = <String, CachedRoomCall>{
              for (final call in activeCalls) call.roomId: call,
            };
            return (
              conversations: conversations,
              activeRoomCalls: activeRoomCalls,
            );
          }(),
          builder: (context, snapshot) {
            final all = snapshot.data?.conversations ?? const <Conversation>[];
            final activeRoomCalls =
                snapshot.data?.activeRoomCalls ??
                const <String, CachedRoomCall>{};
            final query = _query.trim().toLowerCase();
            // Base list without chat-filter (for unread badge on Unread chip)
            final baseItems = all
                .where((c) {
                  if (c.archivedAtMs != null) {
                    return false;
                  }
                  if (controller.isPersonalChat(c.convoId)) {
                    return false;
                  }
                  if (widget.shellTab == 0 && c.convoId.startsWith('group:')) {
                    return false;
                  }
                  if (widget.shellTab == 1 && !c.convoId.startsWith('group:')) {
                    return false;
                  }
                  return true;
                })
                .toList(growable: false);
            final baseUnreadCount = baseItems.fold<int>(
              0,
              (s, c) => s + c.unreadCount,
            );
            // D4: update window title with unread count
            WidgetsBinding.instance.addPostFrameCallback((_) {
              updateWindowTitle(baseUnreadCount);
            });
            final items = baseItems
                .where((c) {
                  if (_chatFilter == _ChatFilter.unread && c.unreadCount == 0) {
                    return false;
                  }
                  if (_chatFilter == _ChatFilter.personal &&
                      c.convoId.startsWith('group:')) {
                    return false;
                  }
                  if (_chatFilter == _ChatFilter.groups &&
                      !c.convoId.startsWith('group:')) {
                    return false;
                  }
                  if (query.isEmpty) return true;
                  final hay = '${c.title} ${c.peerProfileId ?? ''} ${c.convoId}'
                      .toLowerCase();
                  return hay.contains(query);
                })
                .toList(growable: false);

            // Keep _cachedItems in sync for Alt+↑/↓ keyboard shortcut (no rebuild needed)
            _cachedItems = items;
            if (_selectedConvoId == null ||
                !items.any((c) => c.convoId == _selectedConvoId)) {
              final newId = items.isNotEmpty ? items.first.convoId : null;
              if (_selectedConvoId != newId) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _selectedConvoId = newId;
                  });
                });
              }
            }

            final selected = _selectedConvoId == null
                ? null
                : items
                      .where((c) => c.convoId == _selectedConvoId)
                      .cast<Conversation?>()
                      .firstOrNull;

            final title = selected == null
                ? _label(ru: 'Выберите чат', en: 'Select a chat')
                : (() {
                    final baseTitle = _desktopConversationTitle(
                      context,
                      widget.controller,
                      selected,
                    );
                    return (selected.emoji == null || selected.emoji!.isEmpty)
                        ? baseTitle
                        : '$baseTitle ${selected.emoji}';
                  })();
            final rightPane = _buildRightPane(
              selected: selected,
              activeRoomCalls: activeRoomCalls,
            );
            final canToggleRightPane = widget.shellTab <= 1;
            final rightPaneVisible = canToggleRightPane
                ? _rightPaneVisible
                : true;

            return Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const handleWidth = 14.0;
                      const minCenterWidth = 420.0;
                      const minListWidth = 280.0;
                      const maxListWidth = 560.0;
                      const minDetailsWidth = 270.0;
                      const maxDetailsWidth = 560.0;

                      var listWidth = _listPanelWidth.clamp(
                        minListWidth,
                        maxListWidth,
                      );
                      var detailsWidth = _detailsPanelWidth.clamp(
                        minDetailsWidth,
                        maxDetailsWidth,
                      );
                      var centerWidth =
                          constraints.maxWidth -
                          listWidth -
                          (rightPaneVisible ? detailsWidth : 0) -
                          (handleWidth * (rightPaneVisible ? 2 : 1));

                      if (centerWidth < minCenterWidth) {
                        final deficit = minCenterWidth - centerWidth;
                        if (rightPaneVisible) {
                          final takeFromList = deficit / 2;
                          listWidth = (listWidth - takeFromList).clamp(
                            minListWidth,
                            maxListWidth,
                          );
                          detailsWidth =
                              (detailsWidth - (deficit - takeFromList)).clamp(
                                minDetailsWidth,
                                maxDetailsWidth,
                              );
                        } else {
                          listWidth = (listWidth - deficit).clamp(
                            minListWidth,
                            maxListWidth,
                          );
                        }
                        centerWidth =
                            constraints.maxWidth -
                            listWidth -
                            (rightPaneVisible ? detailsWidth : 0) -
                            (handleWidth * (rightPaneVisible ? 2 : 1));
                      }

                      final listNeedsSync =
                          (_listPanelWidth - listWidth).abs() > 0.1;
                      final detailsNeedsSync =
                          rightPaneVisible &&
                          (_detailsPanelWidth - detailsWidth).abs() > 0.1;
                      if (listNeedsSync || detailsNeedsSync) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _listPanelWidth = listWidth;
                            if (rightPaneVisible) {
                              _detailsPanelWidth = detailsWidth;
                            }
                          });
                        });
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: listWidth,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final slide = Tween<Offset>(
                                  begin: const Offset(0.06, 0),
                                  end: Offset.zero,
                                ).animate(animation);
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: slide,
                                    child: child,
                                  ),
                                );
                              },
                              child: _DesktopConversationPanel(
                                key: ValueKey<String>(
                                  'list-panel-tab-${widget.shellTab}',
                                ),
                                items: items,
                                activeRoomCalls: activeRoomCalls,
                                baseUnreadCount: baseUnreadCount,
                                controller: controller,
                                selectedConvoId: _selectedConvoId,
                                searchController: _searchController,
                                searchFocusNode: _searchFocusNode,
                                isGroupsTab: widget.shellTab == 1,
                                chatFilter: _chatFilter,
                                onChatFilterChanged: (f) {
                                  setState(() => _chatFilter = f);
                                },
                                onSearchChanged: (value) {
                                  setState(() {
                                    _query = value;
                                  });
                                },
                                onSelect: (convoId) {
                                  setState(() {
                                    _selectedConvoId = convoId;
                                    if (widget.shellTab <= 1) {
                                      _rightPaneMode =
                                          _RightPaneMode.chatDetails;
                                      _detailsConvo = null;
                                    }
                                  });
                                },
                                onPin: (convoId, pinned) =>
                                    controller.setChatPinned(
                                      convoId: convoId,
                                      pinned: pinned,
                                    ),
                                onMute: (convoId, muted) =>
                                    controller.setChatMuted(
                                      convoId: convoId,
                                      muted: muted,
                                    ),
                                onMarkRead: (convoId) async {
                                  final c = baseItems.firstWhere(
                                    (x) => x.convoId == convoId,
                                    orElse: () => baseItems.first,
                                  );
                                  final peer = c.convoId.startsWith('group:')
                                      ? c.convoId
                                      : c.peerProfileId;
                                  if (peer != null && peer.isNotEmpty) {
                                    await controller.markChatRead(
                                      peerProfileId: peer,
                                    );
                                  }
                                },
                                onArchive: (convoId) =>
                                    controller.setChatArchived(
                                      convoId: convoId,
                                      archived: true,
                                    ),
                                onShowProfile: () =>
                                    _showProfileDialog(context),
                                onShowSettings: () =>
                                    _showSettingsDialog(context),
                              ),
                            ),
                          ),
                          _VerticalResizeHandle(
                            width: handleWidth,
                            onPanUpdate: (dx) {
                              setState(() {
                                _listPanelWidth = (_listPanelWidth + dx).clamp(
                                  minListWidth,
                                  maxListWidth,
                                );
                              });
                            },
                          ),
                          SizedBox(
                            width: centerWidth,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                _kPanelRadius,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      cs.surface.withValues(alpha: 0.72),
                                      cs.surfaceContainerLowest.withValues(
                                        alpha: 0.92,
                                      ),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.34,
                                    ),
                                  ),
                                ),
                                child: selected == null
                                    ? _DesktopCenterPlaceholder(
                                        totalChats: baseItems.length,
                                        unreadChats: baseItems
                                            .where((c) => c.unreadCount > 0)
                                            .length,
                                        archivedChats: baseItems
                                            .where(
                                              (c) => c.archivedAtMs != null,
                                            )
                                            .length,
                                      )
                                    : ChatScreen(
                                        key: ValueKey<String>(
                                          'desktop-chat-${selected.convoId}',
                                        ),
                                        controller: controller,
                                        convoId: selected.convoId,
                                        title: title,
                                        peerProfileIdForSend:
                                            selected.convoId.startsWith(
                                              'group:',
                                            )
                                            ? null
                                            : (selected.peerProfileId ??
                                                  selected.convoId),
                                        initialForwardDraft:
                                            controller.forwardDraft,
                                      ),
                              ),
                            ),
                          ),
                          if (rightPaneVisible) ...[
                            _VerticalResizeHandle(
                              width: handleWidth,
                              onPanUpdate: (dx) {
                                setState(() {
                                  _detailsPanelWidth = (_detailsPanelWidth - dx)
                                      .clamp(minDetailsWidth, maxDetailsWidth);
                                });
                              },
                            ),
                            SizedBox(
                              width: detailsWidth,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  _kPanelRadius,
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        transitionBuilder: (child, animation) =>
                                            FadeTransition(
                                              opacity: animation,
                                              child: SlideTransition(
                                                position: Tween<Offset>(
                                                  begin: const Offset(0.04, 0),
                                                  end: Offset.zero,
                                                ).animate(animation),
                                                child: child,
                                              ),
                                            ),
                                        child: KeyedSubtree(
                                          key: ValueKey(_rightPaneMode),
                                          child: rightPane,
                                        ),
                                      ),
                                    ),
                                    if (canToggleRightPane)
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: _RightPaneToggleButton(
                                          collapse: true,
                                          tooltip: _label(
                                            ru: 'Скрыть панель',
                                            en: 'Hide panel',
                                          ),
                                          onPressed: () =>
                                              _setRightPaneVisible(false),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            SizedBox(
                              width: handleWidth,
                              child: Center(
                                child: _RightPaneToggleButton(
                                  collapse: false,
                                  tooltip: _label(
                                    ru: 'Показать панель',
                                    en: 'Show panel',
                                  ),
                                  onPressed: () => _setRightPaneVisible(true),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DesktopConversationPanel extends StatelessWidget {
  const _DesktopConversationPanel({
    super.key,
    required this.items,
    required this.activeRoomCalls,
    required this.baseUnreadCount,
    required this.controller,
    required this.selectedConvoId,
    required this.searchController,
    required this.searchFocusNode,
    required this.isGroupsTab,
    required this.chatFilter,
    required this.onChatFilterChanged,
    required this.onSearchChanged,
    required this.onSelect,
    required this.onPin,
    required this.onMute,
    required this.onMarkRead,
    required this.onArchive,
    required this.onShowProfile,
    required this.onShowSettings,
  });

  final List<Conversation> items;
  final Map<String, CachedRoomCall> activeRoomCalls;
  final int baseUnreadCount;
  final AppController controller;
  final String? selectedConvoId;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool isGroupsTab;
  final _ChatFilter chatFilter;
  final ValueChanged<_ChatFilter> onChatFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelect;
  final Future<void> Function(String convoId, bool pinned) onPin;
  final Future<void> Function(String convoId, bool muted) onMute;
  final Future<void> Function(String convoId) onMarkRead;
  final Future<void> Function(String convoId) onArchive;
  final VoidCallback onShowProfile;
  final VoidCallback onShowSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final newChatTooltip = _desktopText(
      context,
      ru: 'Новый чат (Ctrl+N)',
      en: 'New chat (Ctrl+N)',
      uk: 'Новий чат (Ctrl+N)',
      es: 'Nuevo chat (Ctrl+N)',
      pt: 'Novo chat (Ctrl+N)',
      ptBr: 'Nova conversa (Ctrl+N)',
      fr: 'Nouveau chat (Ctrl+N)',
      de: 'Neuer Chat (Ctrl+N)',
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(_kPanelRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.surface.withValues(alpha: 0.86),
                cs.surfaceContainerHigh.withValues(alpha: 0.74),
              ],
            ),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.32),
            ),
          ),
          child: Column(
            children: [
              // ── Header: avatar-menu + search + compose ──
              Padding(
                padding: EdgeInsets.fromLTRB(12, _kHeaderVPad, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ProfileAvatarMenuButton(
                      controller: controller,
                      onProfile: onShowProfile,
                      onSettings: onShowSettings,
                    ),
                    const SizedBox(width: _kSectionGap),
                    Expanded(
                      child: _DesktopSearchBar(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        hintText: _desktopText(
                          context,
                          ru: 'Поиск',
                          en: 'Search',
                        ),
                        onChanged: onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: _kSectionGap / 2),
                    Tooltip(
                      message: newChatTooltip,
                      child: SizedBox(
                        width: _kHeaderControlSize,
                        height: _kHeaderControlSize,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(_kItemRadius),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(_kItemRadius),
                            onTap: onShowProfile,
                            child: Center(
                              child: Icon(
                                AppIcons.personAdd,
                                size: _kIconSizeMd,
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: _kSectionGap / 2),
                  ],
                ),
              ),
              const SizedBox(height: _kSectionGap),
              // ── Filter chips ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: SizedBox(
                  height: _kFilterChipH,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: _desktopText(context, ru: 'Все', en: 'All'),
                        selected: chatFilter == _ChatFilter.all,
                        onTap: () => onChatFilterChanged(_ChatFilter.all),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: baseUnreadCount > 0
                            ? _desktopText(
                                context,
                                ru: 'Непрочит. ($baseUnreadCount)',
                                en: 'Unread ($baseUnreadCount)',
                                uk: 'Непрочитані ($baseUnreadCount)',
                                es: 'Sin leer ($baseUnreadCount)',
                                pt: 'Nao lidas ($baseUnreadCount)',
                                ptBr: 'Nao lidas ($baseUnreadCount)',
                                fr: 'Non lus ($baseUnreadCount)',
                                de: 'Ungelesen ($baseUnreadCount)',
                              )
                            : _desktopText(
                                context,
                                ru: 'Непрочит.',
                                en: 'Unread',
                              ),
                        selected: chatFilter == _ChatFilter.unread,
                        onTap: () => onChatFilterChanged(_ChatFilter.unread),
                      ),
                      if (!isGroupsTab) ...[
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: _desktopText(
                            context,
                            ru: 'Личные',
                            en: 'Personal',
                          ),
                          selected: chatFilter == _ChatFilter.personal,
                          onTap: () =>
                              onChatFilterChanged(_ChatFilter.personal),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: _desktopText(
                            context,
                            ru: 'Группы',
                            en: 'Groups',
                          ),
                          selected: chatFilter == _ChatFilter.groups,
                          onTap: () => onChatFilterChanged(_ChatFilter.groups),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Container(
                          width: 280,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(_kItemRadius),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.chatBubble,
                                size: _kIconSizeLg + 16,
                                color: cs.onSurface.withValues(alpha: 0.22),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _desktopText(
                                  context,
                                  ru: 'Пока нет чатов',
                                  en: 'No chats yet',
                                ),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _desktopText(
                                  context,
                                  ru: 'Используйте Ctrl+N для нового чата\nили Ctrl+K для быстрого перехода',
                                  en: 'Use Ctrl+N for a new chat\nor Ctrl+K for quick switch',
                                  uk: 'Використовуйте Ctrl+N для нового чату\nабо Ctrl+K для швидкого переходу',
                                  es: 'Usa Ctrl+N para un chat nuevo\no Ctrl+K para cambiar rapido',
                                  pt: 'Use Ctrl+N para um novo chat\nou Ctrl+K para alternar rapido',
                                  ptBr:
                                      'Use Ctrl+N para uma nova conversa\nou Ctrl+K para alternar rapido',
                                  fr: 'Utilisez Ctrl+N pour un nouveau chat\nou Ctrl+K pour basculer vite',
                                  de: 'Nutze Ctrl+N fur einen neuen Chat\noder Ctrl+K zum schnellen Wechsel',
                                ),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: cs.onSurface.withValues(
                                        alpha: 0.56,
                                      ),
                                      height: 1.35,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.center,
                                children: [
                                  _InfoPill(
                                    icon: AppIcons.checkCircle,
                                    text: _desktopText(
                                      context,
                                      ru: '$baseUnreadCount непрочитано',
                                      en: '$baseUnreadCount unread',
                                      uk: '$baseUnreadCount непрочитано',
                                      es: '$baseUnreadCount sin leer',
                                      pt: '$baseUnreadCount nao lidas',
                                      ptBr: '$baseUnreadCount nao lidas',
                                      fr: '$baseUnreadCount non lus',
                                      de: '$baseUnreadCount ungelesen',
                                    ),
                                  ),
                                  _InfoPill(
                                    icon: AppIcons.search,
                                    text: _desktopText(
                                      context,
                                      ru: 'Поиск активен',
                                      en: 'Search ready',
                                      uk: 'Пошук готовий',
                                      es: 'Busqueda lista',
                                      pt: 'Pesquisa pronta',
                                      ptBr: 'Pesquisa pronta',
                                      fr: 'Recherche prete',
                                      de: 'Suche bereit',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                        itemBuilder: (context, index) {
                          final convo = items[index];
                          return _DesktopChatListItem(
                            key: ValueKey(convo.convoId),
                            convo: convo,
                            activeRoomCall: activeRoomCalls[convo.convoId],
                            controller: controller,
                            selected: convo.convoId == selectedConvoId,
                            onTap: () => onSelect(convo.convoId),
                            onPin: (pinned) => onPin(convo.convoId, pinned),
                            onMute: (muted) => onMute(convo.convoId, muted),
                            onMarkRead: () => onMarkRead(convo.convoId),
                            onArchive: () => onArchive(convo.convoId),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter chip widget ──
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: _kFilterChipH),
              padding: const EdgeInsets.symmetric(horizontal: _kChipHPad),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary.withValues(alpha: 0.16)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? cs.primary.withValues(alpha: 0.5)
                      : cs.outlineVariant.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.72),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Chat list item with hover, preview and context menu ──
class _DesktopChatListItem extends StatefulWidget {
  const _DesktopChatListItem({
    super.key,
    required this.convo,
    required this.activeRoomCall,
    required this.controller,
    required this.selected,
    required this.onTap,
    required this.onPin,
    required this.onMute,
    required this.onMarkRead,
    required this.onArchive,
  });

  final Conversation convo;
  final CachedRoomCall? activeRoomCall;
  final AppController controller;
  final bool selected;
  final VoidCallback onTap;
  final Future<void> Function(bool pinned) onPin;
  final Future<void> Function(bool muted) onMute;
  final Future<void> Function() onMarkRead;
  final Future<void> Function() onArchive;

  @override
  State<_DesktopChatListItem> createState() => _DesktopChatListItemState();
}

class _DesktopChatListItemState extends State<_DesktopChatListItem> {
  bool _hovered = false;
  ChatListPreview? _preview;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant _DesktopChatListItem old) {
    super.didUpdateWidget(old);
    if (old.convo.convoId != widget.convo.convoId ||
        old.convo.lastEventAtMs != widget.convo.lastEventAtMs) {
      _loadPreview();
    }
  }

  void _loadPreview() {
    widget.controller
        .lastMessagePreviewRich(widget.convo.convoId)
        .then((p) {
          if (!mounted) return;
          setState(() => _preview = p);
        })
        .catchError((_) {});
  }

  String _previewText(BuildContext context) {
    final p = _preview;
    if (p == null) return '';
    switch (p.kind) {
      case ChatListPreviewKind.empty:
        return '';
      case ChatListPreviewKind.photo:
        return '📷 ${_desktopText(context, ru: 'Фото', en: 'Photo')}';
      case ChatListPreviewKind.music:
        return '🎵 ${_desktopText(context, ru: 'Аудио', en: 'Audio')}';
      case ChatListPreviewKind.voice:
        return '🎤 ${_desktopText(context, ru: 'Голосовое сообщение', en: 'Voice message')}';
      case ChatListPreviewKind.file:
        return '📄 ${_desktopText(context, ru: 'Файл', en: 'File')}';
      case ChatListPreviewKind.link:
        return '🔗 ${p.text ?? ''}';
      case ChatListPreviewKind.text:
        final base = p.text ?? '';
        if (p.senderName != null && p.senderName!.isNotEmpty) {
          if (p.senderName == 'Вы' || p.senderName!.toLowerCase() == 'you') {
            return '${_desktopText(context, ru: 'Вы', en: 'You')}: $base';
          }
          return '${p.senderName}: $base';
        }
        if (p.senderDeviceId == widget.controller.deviceId) {
          return '${_desktopText(context, ru: 'Вы', en: 'You')}: $base';
        }
        return base;
    }
  }

  static String _formatConvoTime(int ms) {
    if (ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (diff <= 6) {
      // Within a week: short date
      return '${dt.day}.${dt.month.toString().padLeft(2, '0')}';
    }
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${(dt.year % 100).toString().padLeft(2, '0')}';
  }

  void _showContextMenu(BuildContext context, Offset pos) {
    final convo = widget.convo;
    final isPinned = convo.pinnedAtMs != null;
    final isMuted = convo.muted;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        PopupMenuItem(
          value: isPinned ? 'unpin' : 'pin',
          child: Row(
            children: [
              Icon(
                AppIcons.pin,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Text(
                isPinned
                    ? _desktopText(context, ru: 'Открепить', en: 'Unpin')
                    : _desktopText(context, ru: 'Закрепить', en: 'Pin'),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: isMuted ? 'unmute' : 'mute',
          child: Row(
            children: [
              Icon(
                isMuted ? AppIcons.bell : AppIcons.bellOff,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Text(
                isMuted
                    ? _desktopText(context, ru: 'Включить звук', en: 'Unmute')
                    : _desktopText(context, ru: 'Заглушить', en: 'Mute'),
              ),
            ],
          ),
        ),
        if (convo.unreadCount > 0)
          PopupMenuItem(
            value: 'markread',
            child: Row(
              children: [
                Icon(
                  AppIcons.checkDouble,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Text(
                  _desktopText(
                    context,
                    ru: 'Пометить прочитанным',
                    en: 'Mark as read',
                  ),
                ),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'archive',
          child: Row(
            children: [
              Icon(
                AppIcons.archive,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Text(_desktopText(context, ru: 'Архивировать', en: 'Archive')),
            ],
          ),
        ),
      ],
    ).then((val) async {
      if (val == null) return;
      switch (val) {
        case 'pin':
          await widget.onPin(true);
        case 'unpin':
          await widget.onPin(false);
        case 'mute':
          await widget.onMute(true);
        case 'unmute':
          await widget.onMute(false);
        case 'markread':
          await widget.onMarkRead();
        case 'archive':
          await widget.onArchive();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final convo = widget.convo;
    final isPinned = convo.pinnedAtMs != null;
    final isMuted = convo.muted;
    final preview = _previewText(context);
    final timeStr = _formatConvoTime(convo.lastEventAtMs);
    final activeRoomCall = widget.activeRoomCall;
    final hasActiveRoomCall = activeRoomCall != null && activeRoomCall.isActive;
    final roomCallAccent = hasActiveRoomCall
        ? roomCallPresenceAccent(activeRoomCall, cs)
        : null;
    final subtitleText = hasActiveRoomCall
        ? formatRoomCallPresenceText(
            context,
            activeRoomCall,
            inactiveLabel: _desktopText(context, ru: 'Комната', en: 'Room'),
          )
        : (preview.isEmpty
              ? _desktopText(context, ru: 'Нет сообщений', en: 'No messages')
              : preview);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: widget.selected
                  ? cs.primaryContainer.withValues(alpha: 0.44)
                  : _hovered
                  ? cs.primaryContainer.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(_kItemRadius),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(_kItemRadius),
              onTap: widget.onTap,
              splashColor: cs.primary.withValues(alpha: 0.06),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _kListItemHPad,
                  vertical: _kListItemVPad,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar with optional online dot
                    Stack(
                      children: [
                        _DesktopAvatar(
                          path: convo.avatarPath,
                          title: convo.title,
                          fallbackId: convo.peerProfileId ?? convo.convoId,
                          isFavorites: widget.controller.isSavedMessagesConvo(
                            convo.convoId,
                          ),
                          radius: _kAvatarRadiusLg,
                        ),
                        if (convo.isOnline &&
                            !convo.convoId.startsWith('group:'))
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: _kOnlineDotSize,
                              height: _kOnlineDotSize,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: cs.surface,
                                  width: _kOnlineDotBorder,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title row: pin icon + name + mute icon + time
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (isPinned) ...[
                                Icon(
                                  AppIcons.pin,
                                  size: _kIconSizeSm,
                                  color: cs.primary.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 3),
                              ],
                              Expanded(
                                child: Text(
                                  _desktopConversationTitle(
                                    context,
                                    widget.controller,
                                    convo,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.0,
                                      ),
                                ),
                              ),
                              if (isMuted) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  AppIcons.bellOff,
                                  size: _kIconSizeSm,
                                  color: cs.onSurface.withValues(alpha: 0.35),
                                ),
                              ],
                              if (timeStr.isNotEmpty) ...[
                                const SizedBox(width: 5),
                                Text(
                                  timeStr,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: cs.onSurface.withValues(
                                          alpha: 0.45,
                                        ),
                                        fontSize: 11.5,
                                      ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          // Subtitle row: preview text + unread badge
                          Row(
                            children: [
                              if (hasActiveRoomCall) ...[
                                Icon(
                                  activeRoomCall.mediaType == 'video'
                                      ? AppIcons.video
                                      : AppIcons.callAlt,
                                  size: 13,
                                  color: roomCallAccent,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  subtitleText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: hasActiveRoomCall
                                            ? roomCallAccent
                                            : preview.isEmpty
                                            ? cs.onSurface.withValues(
                                                alpha: 0.28,
                                              )
                                            : cs.onSurface.withValues(
                                                alpha: 0.62,
                                              ),
                                        fontWeight: hasActiveRoomCall
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        fontSize: 12.5,
                                      ),
                                ),
                              ),
                              if (convo.unreadCount > 0)
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: _kBadgeMinW,
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMuted
                                          ? cs.onSurface.withValues(alpha: 0.18)
                                          : cs.primary,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      convo.unreadCount > 99
                                          ? '99+'
                                          : convo.unreadCount.toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: isMuted
                                                ? cs.onSurface.withValues(
                                                    alpha: 0.65,
                                                  )
                                                : cs.onPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                                ),
                            ],
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
      ),
    );
  }
}

class _DesktopAvatar extends StatelessWidget {
  const _DesktopAvatar({
    required this.path,
    required this.title,
    required this.fallbackId,
    this.isFavorites = false,
    this.radius = 20,
    this.showOnlineDot = false,
  });

  final String? path;
  final String title;
  final String fallbackId;
  final bool isFavorites;
  final double radius;
  final bool showOnlineDot;

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (isFavorites) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF0D5F38),
        child: Padding(
          padding: EdgeInsets.all(radius * 0.38),
          child: const ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
            child: Image(
              image: AssetImage(_favoritesNoteAssetPath),
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    } else {
      final p = (path ?? '').trim();
      final hasAvatar = p.isNotEmpty && File(p).existsSync();
      final seed = fallbackId.isNotEmpty ? fallbackId : title;
      if (hasAvatar) {
        avatar = CircleAvatar(
          radius: radius,
          backgroundImage: FileImage(File(p)),
        );
      } else {
        avatar = AvatarInitials.fallbackBubble(
          context: context,
          radius: radius,
          seed: seed,
          displayName: title,
          fallbackId: fallbackId,
          labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: (radius * 0.55).clamp(10, 22),
          ),
        );
      }
    }

    if (!showOnlineDot) return avatar;

    final dotSize = (radius * 0.38).clamp(7.0, 14.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Media stats model
// ─────────────────────────────────────────────────────────────────────────────

class _MediaStats {
  const _MediaStats({
    this.photos = 0,
    this.audio = 0,
    this.videos = 0,
    this.files = 0,
  });

  final int photos;
  final int audio;
  final int videos;
  final int files;

  bool get isEmpty => photos == 0 && audio == 0 && videos == 0 && files == 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// _DesktopInfoPanel — full chat info right panel
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopInfoPanel extends StatefulWidget {
  const _DesktopInfoPanel({
    required this.selected,
    required this.onOpenDetails,
    required this.onMuteToggle,
    required this.onOpenProfilePane,
    required this.onOpenContactsPane,
    required this.onOpenSettingsPane,
    required this.activeRoomCall,
    required this.onOpenRoomCall,
    required this.labelBuilder,
    required this.controller,
  });

  final Conversation? selected;
  final VoidCallback? onOpenDetails;
  final VoidCallback? onMuteToggle;
  final VoidCallback onOpenProfilePane;
  final VoidCallback onOpenContactsPane;
  final VoidCallback onOpenSettingsPane;
  final CachedRoomCall? activeRoomCall;
  final VoidCallback? onOpenRoomCall;
  final String Function({required String ru, required String en}) labelBuilder;
  final AppController controller;

  @override
  State<_DesktopInfoPanel> createState() => _DesktopInfoPanelState();
}

class _DesktopInfoPanelState extends State<_DesktopInfoPanel> {
  _MediaStats? _mediaStats;
  bool _statsLoading = false;
  String? _loadedConvoId;

  @override
  void initState() {
    super.initState();
    _loadMediaStats();
  }

  @override
  void didUpdateWidget(_DesktopInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected?.convoId != widget.selected?.convoId) {
      _mediaStats = null;
      _loadedConvoId = null;
      _loadMediaStats();
    }
  }

  Future<void> _loadMediaStats() async {
    final convoId = widget.selected?.convoId;
    if (convoId == null) {
      if (mounted) {
        setState(() {
          _mediaStats = null;
          _statsLoading = false;
          _loadedConvoId = null;
        });
      }
      return;
    }
    if (_loadedConvoId == convoId) return;
    if (mounted) setState(() => _statsLoading = true);

    int photos = 0, audio = 0, videos = 0, files = 0;
    try {
      final events = await widget.controller.loadEvents(convoId);
      for (final event in events) {
        if (event.type != 'att') continue;
        final payload = await widget.controller.payloadEventForChatEvent(event);
        if (payload is AttachmentEventV1) {
          final mime = (payload.mime ?? '').toLowerCase();
          if (mime.startsWith('image/')) {
            photos++;
          } else if (mime.startsWith('video/')) {
            videos++;
          } else if (mime.startsWith('audio/')) {
            audio++;
          } else {
            files++;
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _mediaStats = _MediaStats(
        photos: photos,
        audio: audio,
        videos: videos,
        files: files,
      );
      _statsLoading = false;
      _loadedConvoId = convoId;
    });
  }

  String _formatLastSeen(BuildContext context, int? ms) {
    if (ms == null || ms <= 0) {
      return _desktopText(
        context,
        ru: 'был(а) недавно',
        en: 'last seen recently',
        uk: 'був(ла) нещодавно',
        es: 'visto recientemente',
        pt: 'visto recentemente',
        fr: 'vu recemment',
        de: 'kurzlich gesehen',
      );
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return _desktopText(
        context,
        ru: 'был(а) в $hh:$mm',
        en: 'last seen at $hh:$mm',
        uk: 'був(ла) о $hh:$mm',
        es: 'visto a las $hh:$mm',
        pt: 'visto as $hh:$mm',
        ptBr: 'visto as $hh:$mm',
        fr: 'vu a $hh:$mm',
        de: 'zuletzt um $hh:$mm',
      );
    }
    final dd = dt.day.toString().padLeft(2, '0');
    final mon = dt.month.toString().padLeft(2, '0');
    return _desktopText(
      context,
      ru: 'был(а) $dd.$mon $hh:$mm',
      en: 'last seen $dd.$mon $hh:$mm',
      uk: 'був(ла) $dd.$mon $hh:$mm',
      es: 'visto $dd.$mon $hh:$mm',
      pt: 'visto $dd.$mon $hh:$mm',
      fr: 'vu $dd.$mon $hh:$mm',
      de: 'zuletzt $dd.$mon $hh:$mm',
    );
  }

  String _formatLastActivity(BuildContext context, int ms) {
    if (ms <= 0) {
      return _desktopText(
        context,
        ru: 'нет сообщений',
        en: 'no messages yet',
        uk: 'повідомлень ще немає',
        es: 'sin mensajes aun',
        pt: 'ainda sem mensagens',
        ptBr: 'ainda sem mensagens',
        fr: 'aucun message pour le moment',
        de: 'noch keine Nachrichten',
      );
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return _desktopText(
        context,
        ru: 'сегодня, $hh:$mm',
        en: 'today, $hh:$mm',
        uk: 'сьогодні, $hh:$mm',
        es: 'hoy, $hh:$mm',
        pt: 'hoje, $hh:$mm',
        fr: 'aujourd hui, $hh:$mm',
        de: 'heute, $hh:$mm',
      );
    }
    final dd = dt.day.toString().padLeft(2, '0');
    final mon = dt.month.toString().padLeft(2, '0');
    return '$dd.$mon $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = widget.labelBuilder;
    final selected = widget.selected;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_kPanelRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.surface.withValues(alpha: 0.88),
                cs.surfaceContainerHigh.withValues(alpha: 0.78),
              ],
            ),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.34),
            ),
          ),
          child: selected == null
              ? _buildEmptyState(context, cs, l)
              : _buildContent(context, selected, cs, l),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme cs,
    String Function({required String ru, required String en}) l,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.chatBubble,
            size: _kIconSizeLg + 24,
            color: cs.outlineVariant,
          ),
          const SizedBox(height: _kSectionGap + 4),
          Text(
            l(ru: 'Выберите чат', en: 'Select a chat'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Conversation selected,
    ColorScheme cs,
    String Function({required String ru, required String en}) l,
  ) {
    final isGroup = selected.convoId.startsWith('group:');
    final isFavorites = widget.controller.isSavedMessagesConvo(
      selected.convoId,
    );
    final activeRoomCall = widget.activeRoomCall;
    final hasActiveRoomCall =
        isGroup && activeRoomCall != null && activeRoomCall.isActive;
    final mediaTotal = _mediaStats == null
        ? null
        : (_mediaStats!.photos +
              _mediaStats!.videos +
              _mediaStats!.audio +
              _mediaStats!.files);
    final bottomOutlinedStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.34)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kItemRadius - 1),
      ),
      textStyle: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    // Status line for P2P
    String? statusLine;
    Color statusColor = cs.onSurfaceVariant;
    if (!isGroup && !isFavorites) {
      if (selected.isOnline) {
        statusLine = _desktopText(context, ru: 'в сети', en: 'online');
        statusColor = const Color(0xFF4CAF50);
      } else {
        statusLine = _formatLastSeen(context, selected.peerLastSeenAtMs);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Scrollable main content ──────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero: avatar + name + status
                Center(
                  child: _DesktopAvatar(
                    path: selected.avatarPath,
                    title: _desktopConversationTitle(
                      context,
                      widget.controller,
                      selected,
                    ),
                    fallbackId: selected.peerProfileId ?? selected.convoId,
                    isFavorites: isFavorites,
                    radius: 40,
                    showOnlineDot:
                        selected.isOnline && !isGroup && !isFavorites,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _desktopConversationTitle(
                    context,
                    widget.controller,
                    selected,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (statusLine != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    statusLine,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: selected.isOnline
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
                if (isGroup)
                  FutureBuilder<List<RoomMember>>(
                    future: widget.controller.listRoomMembersDetailed(
                      selected.convoId,
                    ),
                    builder: (context, snap) {
                      final count = snap.data?.length;
                      if (count == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _desktopText(
                            context,
                            ru: '$count участников',
                            en: '$count members',
                            uk: '$count учасників',
                            es: '$count miembros',
                            pt: '$count membros',
                            fr: '$count membres',
                            de: '$count Mitglieder',
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      );
                    },
                  ),

                if (hasActiveRoomCall) ...[
                  const SizedBox(height: 14),
                  RoomCallPresenceCard(
                    call: activeRoomCall,
                    onTap: widget.onOpenRoomCall,
                  ),
                ],

                const SizedBox(height: 18),

                _InfoSectionLabel(
                  label: l(ru: 'Обзор', en: 'Overview'),
                  cs: cs,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetricCard(
                        label: l(ru: 'Непрочитано', en: 'Unread'),
                        value: selected.unreadCount.toString(),
                        icon: AppIcons.chatBubble,
                        cs: cs,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniMetricCard(
                        label: l(ru: 'Медиа', en: 'Media'),
                        value: _statsLoading
                            ? '…'
                            : (mediaTotal?.toString() ?? '0'),
                        icon: AppIcons.photo,
                        cs: cs,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniMetricCard(
                        label: l(ru: 'Закреп', en: 'Pinned'),
                        value: selected.pinnedAtMs == null
                            ? l(ru: 'Нет', en: 'No')
                            : l(ru: 'Да', en: 'Yes'),
                        icon: AppIcons.pin,
                        cs: cs,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      icon: AppIcons.search,
                      text: _desktopText(
                        context,
                        ru: 'Активность: ${_formatLastActivity(context, selected.lastEventAtMs)}',
                        en: 'Activity: ${_formatLastActivity(context, selected.lastEventAtMs)}',
                        uk: 'Активність: ${_formatLastActivity(context, selected.lastEventAtMs)}',
                        es: 'Actividad: ${_formatLastActivity(context, selected.lastEventAtMs)}',
                        pt: 'Atividade: ${_formatLastActivity(context, selected.lastEventAtMs)}',
                        fr: 'Activite : ${_formatLastActivity(context, selected.lastEventAtMs)}',
                        de: 'Aktivitat: ${_formatLastActivity(context, selected.lastEventAtMs)}',
                      ),
                    ),
                    _InfoPill(
                      icon: selected.muted
                          ? AppIcons.bellOffSolid
                          : AppIcons.bell,
                      text: selected.muted
                          ? l(
                              ru: 'Уведомления отключены',
                              en: 'Notifications muted',
                            )
                          : l(
                              ru: 'Уведомления включены',
                              en: 'Notifications on',
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Quick action buttons
                Row(
                  children: [
                    Expanded(
                      child: _InfoActionButton(
                        icon: selected.muted
                            ? AppIcons.bell
                            : AppIcons.bellOffSolid,
                        label: selected.muted
                            ? l(ru: 'Включить\nзвук', en: 'Unmute')
                            : l(ru: 'Выключить\nзвук', en: 'Mute'),
                        onTap: widget.onMuteToggle,
                        cs: cs,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoActionButton(
                        icon: AppIcons.profile,
                        label: isGroup
                            ? l(ru: 'Детали\nгруппы', en: 'Group\nDetails')
                            : l(ru: 'Профиль', en: 'Profile'),
                        onTap: widget.onOpenDetails,
                        cs: cs,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Quick facts
                _InfoSectionLabel(
                  label: l(ru: 'Сведения', en: 'Info'),
                  cs: cs,
                ),
                const SizedBox(height: 8),
                _FactRow(
                  label: l(ru: 'Тип', en: 'Type'),
                  value: isGroup
                      ? l(ru: 'Группа', en: 'Group')
                      : l(ru: 'Личный чат', en: 'Direct'),
                ),
                _FactRow(
                  label: l(ru: 'Непрочитано', en: 'Unread'),
                  value: selected.unreadCount > 0
                      ? selected.unreadCount.toString()
                      : l(ru: 'нет', en: 'none'),
                ),
                _FactRow(
                  label: l(ru: 'Уведомления', en: 'Notifications'),
                  value: selected.muted
                      ? l(ru: 'Выключены', en: 'Muted')
                      : l(ru: 'Включены', en: 'On'),
                ),
                if (selected.pinnedAtMs != null)
                  _FactRow(
                    label: l(ru: 'Закреплён', en: 'Pinned'),
                    value: l(ru: 'Да', en: 'Yes'),
                  ),

                const SizedBox(height: 20),

                // Shared media section
                _InfoSectionLabel(
                  label: l(ru: 'Медиафайлы', en: 'Media'),
                  cs: cs,
                ),
                const SizedBox(height: 8),
                if (_statsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_mediaStats != null && !_mediaStats!.isEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_mediaStats!.photos > 0)
                        _MediaStatChip(
                          icon: AppIcons.photo,
                          count: _mediaStats!.photos,
                          label: l(ru: 'Фото', en: 'Photos'),
                          cs: cs,
                        ),
                      if (_mediaStats!.videos > 0)
                        _MediaStatChip(
                          icon: AppIcons.video,
                          count: _mediaStats!.videos,
                          label: l(ru: 'Видео', en: 'Videos'),
                          cs: cs,
                        ),
                      if (_mediaStats!.audio > 0)
                        _MediaStatChip(
                          icon: AppIcons.musicNote,
                          count: _mediaStats!.audio,
                          label: l(ru: 'Аудио', en: 'Audio'),
                          cs: cs,
                        ),
                      if (_mediaStats!.files > 0)
                        _MediaStatChip(
                          icon: AppIcons.fileOutline,
                          count: _mediaStats!.files,
                          label: l(ru: 'Файлы', en: 'Files'),
                          cs: cs,
                        ),
                    ],
                  )
                else if (_mediaStats != null && _mediaStats!.isEmpty)
                  Text(
                    l(ru: 'Нет вложений', en: 'No attachments'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // ── Pinned bottom: nav + archive/clear ──────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 10),
              // Nav chips (Я / Контакты / Настройки)
              Row(
                children: [
                  Expanded(
                    child: _NavActionButton(
                      icon: AppIcons.profile,
                      label: l(ru: 'Я', en: 'Me'),
                      onTap: widget.onOpenProfilePane,
                      cs: cs,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _NavActionButton(
                      icon: AppIcons.contacts,
                      label: l(ru: 'Контакты', en: 'Contacts'),
                      onTap: widget.onOpenContactsPane,
                      cs: cs,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _NavActionButton(
                      icon: AppIcons.settings,
                      label: l(ru: 'Настройки', en: 'Settings'),
                      onTap: widget.onOpenSettingsPane,
                      cs: cs,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Archive + Clear row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await widget.controller.setChatArchived(
                          convoId: selected.convoId,
                          archived: selected.archivedAtMs == null,
                        );
                      },
                      style: bottomOutlinedStyle,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(AppIcons.archive, size: _kIconSizeSm + 3),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              selected.archivedAtMs != null
                                  ? l(ru: 'Разарх.', en: 'Unarchive')
                                  : l(ru: 'Архив', en: 'Archive'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              l(ru: 'Очистить историю', en: 'Clear history'),
                            ),
                            content: Text(
                              l(
                                ru: 'Все сообщения будут удалены. Это нельзя отменить.',
                                en: 'All messages will be deleted. This cannot be undone.',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: Text(l(ru: 'Отмена', en: 'Cancel')),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text(l(ru: 'Очистить', en: 'Clear')),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          await widget.controller.clearChatHistory(
                            convoId: selected.convoId,
                          );
                        }
                      },
                      style: bottomOutlinedStyle,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(AppIcons.delete, size: _kIconSizeSm + 3),
                          const SizedBox(width: 6),
                          Text(
                            l(ru: 'Очистить', en: 'Clear'),
                            style: TextStyle(color: cs.error),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets for DesktopInfoPanel
// ─────────────────────────────────────────────────────────────────────────────

class _InfoSectionLabel extends StatelessWidget {
  const _InfoSectionLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InfoActionButton extends StatelessWidget {
  const _InfoActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Material(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(_kItemRadius + 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(_kItemRadius + 2),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: _kIconSizeLg, color: cs.primary),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaStatChip extends StatelessWidget {
  const _MediaStatChip({
    required this.icon,
    required this.count,
    required this.label,
    required this.cs,
  });

  final IconData icon;
  final int count;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(_kPanelRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _kIconSizeSm + 1, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _NavActionButton extends StatelessWidget {
  const _NavActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Material(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(_kItemRadius - 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(_kItemRadius - 2),
              onTap: onTap,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_kItemRadius - 2),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.22),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: _kIconSizeMd - 1,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DesktopInlineDetailsPane — wraps ContactDetails / RoomDetails in the right
// pane with a compact "← Back" header so users can return to _DesktopInfoPanel.
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopInlineDetailsPane extends StatelessWidget {
  const _DesktopInlineDetailsPane({
    required this.title,
    required this.onBack,
    required this.child,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kPanelRadius),
      child: Column(
        children: [
          // Back-button header bar
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.82),
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(AppIcons.arrowBack, size: _kIconSizeLg),
                  tooltip: _desktopText(context, ru: 'Назад', en: 'Back'),
                  onPressed: onBack,
                  color: cs.onSurface,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _DesktopPlaceholder extends StatelessWidget {
  const _DesktopPlaceholder({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.surface.withValues(alpha: 0.88),
            cs.surfaceContainerHigh.withValues(alpha: 0.78),
          ],
        ),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.34)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerticalResizeHandle extends StatefulWidget {
  const _VerticalResizeHandle({required this.width, required this.onPanUpdate});

  final double width;
  final ValueChanged<double> onPanUpdate;

  @override
  State<_VerticalResizeHandle> createState() => _VerticalResizeHandleState();
}

class _VerticalResizeHandleState extends State<_VerticalResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (details) => widget.onPanUpdate(details.delta.dx),
        child: SizedBox(
          width: widget.width,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              width: _hovered ? 3 : 2,
              height: _hovered ? 52 : 32,
              decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(
                  alpha: _hovered ? 0.65 : 0.22,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RightPaneToggleButton extends StatelessWidget {
  const _RightPaneToggleButton({
    required this.collapse,
    required this.tooltip,
    required this.onPressed,
  });

  final bool collapse;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: _kHeaderControlSize,
              height: _kHeaderControlSize,
              child: Center(
                child: AnimatedRotation(
                  turns: collapse ? 0 : 0.5,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    AppIcons.chevronRight,
                    size: _kIconSizeMd,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  const _MiniMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.cs,
  });

  final String label;
  final String value;
  final IconData icon;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(_kItemRadius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: _kIconSizeSm + 1, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

enum _ChatFilter { all, unread, personal, groups }

enum _RightPaneMode {
  chatDetails,
  profile,
  contacts,
  settings,
  contactDetails,
  roomDetails,
}

// ───────────────────────────────────────────────────────────────────────────────
// Quick Switcher (Ctrl+K)
// ───────────────────────────────────────────────────────────────────────────────

class _QuickSwitcherDialog extends StatefulWidget {
  const _QuickSwitcherDialog({
    required this.conversations,
    required this.currentConvoId,
    required this.controller,
  });

  final List<Conversation> conversations;
  final String? currentConvoId;
  final AppController controller;

  @override
  State<_QuickSwitcherDialog> createState() => _QuickSwitcherDialogState();
}

class _QuickSwitcherDialogState extends State<_QuickSwitcherDialog> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  List<Conversation> _filtered = const [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _filtered = widget.conversations;
    _focus.requestFocus();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _query.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, _filtered.length - 1);
      });
      _scrollToSelected();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, _filtered.length - 1);
      });
      _scrollToSelected();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _selectCurrent();
      return true;
    }
    return false;
  }

  void _scrollToSelected() {
    const itemH = 64.0;
    final offset = (_selectedIndex * itemH).clamp(
      0.0,
      (_filtered.length * itemH - 300).clamp(0.0, double.infinity),
    );
    _scroll.animateTo(
      offset,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  void _selectCurrent() {
    if (_filtered.isEmpty) return;
    Navigator.of(context).pop<String>(_filtered[_selectedIndex].convoId);
  }

  void _onQueryChanged(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.conversations
          : widget.conversations
                .where((c) {
                  final hay = '${c.title} ${c.peerProfileId ?? ''} ${c.convoId}'
                      .toLowerCase();
                  return hay.contains(q);
                })
                .toList(growable: false);
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFav = widget.controller.isSavedMessagesConvo;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 80),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 460),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.surface.withValues(alpha: 0.92),
                  cs.surfaceContainerHigh.withValues(alpha: 0.84),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search field
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.26),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.search,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _query,
                            focusNode: _focus,
                            onChanged: _onQueryChanged,
                            textAlignVertical: TextAlignVertical.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                            decoration: InputDecoration(
                              hintText: _desktopText(
                                context,
                                ru: 'Перейти к чату...',
                                en: 'Jump to chat...',
                                uk: 'Перейти до чату...',
                                es: 'Ir al chat...',
                                pt: 'Ir para o chat...',
                                ptBr: 'Ir para a conversa...',
                                fr: 'Aller au chat...',
                                de: 'Zum Chat springen...',
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: cs.outlineVariant.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                            ),
                            child: Text(
                              'Esc',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
                // Results list
                Flexible(
                  child: _filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _desktopText(
                              context,
                              ru: 'Ничего не найдено',
                              en: 'No results',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          itemCount: _filtered.length,
                          itemExtent: 64,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemBuilder: (context, index) {
                            final convo = _filtered[index];
                            final isSelected = index == _selectedIndex;
                            final isActive =
                                convo.convoId == widget.currentConvoId;
                            return InkWell(
                              onTap: () => Navigator.of(
                                context,
                              ).pop<String>(convo.convoId),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                color: isSelected
                                    ? cs.primaryContainer.withValues(
                                        alpha: 0.55,
                                      )
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    _DesktopAvatar(
                                      path: convo.avatarPath,
                                      title: convo.title,
                                      fallbackId:
                                          convo.peerProfileId ?? convo.convoId,
                                      isFavorites: isFav(convo.convoId),
                                      radius: 22,
                                      showOnlineDot:
                                          convo.isOnline &&
                                          !convo.convoId.startsWith('group:'),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _desktopConversationTitle(
                                              context,
                                              widget.controller,
                                              convo,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: isActive
                                                      ? cs.primary
                                                      : null,
                                                ),
                                          ),
                                          if (convo.convoId.startsWith(
                                            'group:',
                                          ))
                                            Text(
                                              _desktopText(
                                                context,
                                                ru: 'Комната',
                                                en: 'Room',
                                              ),
                                              maxLines: 1,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                            )
                                          else if (convo.unreadCount > 0)
                                            Text(
                                              _desktopText(
                                                context,
                                                ru: 'Непрочитано: ${convo.unreadCount}',
                                                en: 'Unread: ${convo.unreadCount}',
                                                uk: 'Непрочитано: ${convo.unreadCount}',
                                                es: 'Sin leer: ${convo.unreadCount}',
                                                pt: 'Nao lidas: ${convo.unreadCount}',
                                                ptBr:
                                                    'Nao lidas: ${convo.unreadCount}',
                                                fr: 'Non lus : ${convo.unreadCount}',
                                                de: 'Ungelesen: ${convo.unreadCount}',
                                              ),
                                              maxLines: 1,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(color: cs.primary),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (convo.unreadCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: convo.muted
                                              ? cs.onSurface.withValues(
                                                  alpha: 0.25,
                                                )
                                              : cs.primary,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          convo.unreadCount > 99
                                              ? '99+'
                                              : '${convo.unreadCount}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: convo.muted
                                                    ? cs.onSurface
                                                    : cs.onPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                  ],
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
// ---------------------------------------------------------------------------
// Desktop center placeholder — shown when no chat is selected
// ---------------------------------------------------------------------------

class _DesktopCenterPlaceholder extends StatelessWidget {
  const _DesktopCenterPlaceholder({
    required this.totalChats,
    required this.unreadChats,
    required this.archivedChats,
  });

  final int totalChats;
  final int unreadChats;
  final int archivedChats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final todayLabel = _desktopText(context, ru: 'Сегодня', en: 'Today');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      AppIcons.lock,
                      size: _kIconSizeLg + 20,
                      color: cs.primary.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Secretly',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _desktopText(
                context,
                ru: 'Безопасная коммуникация и рабочий контекст в одном окне',
                en: 'Secure communication and workspace context in one view',
                uk: 'Безпечне спілкування і робочий контекст в одному вікні',
                es: 'Comunicacion segura y contexto de trabajo en una vista',
                pt: 'Comunicacao segura e contexto de trabalho numa so vista',
                ptBr: 'Comunicacao segura e contexto de trabalho em uma tela',
                fr: 'Communication securisee et contexte de travail en une vue',
                de: 'Sichere Kommunikation und Arbeitskontext in einer Ansicht',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _InfoPill(
                  icon: AppIcons.chatBubble,
                  text: _desktopText(
                    context,
                    ru: '$totalChats чатов',
                    en: '$totalChats chats',
                    uk: '$totalChats чатів',
                    es: '$totalChats chats',
                    pt: '$totalChats chats',
                    ptBr: '$totalChats conversas',
                    fr: '$totalChats chats',
                    de: '$totalChats Chats',
                  ),
                ),
                _InfoPill(
                  icon: AppIcons.checkCircle,
                  text: _desktopText(
                    context,
                    ru: '$unreadChats непрочитано',
                    en: '$unreadChats unread',
                    uk: '$unreadChats непрочитано',
                    es: '$unreadChats sin leer',
                    pt: '$unreadChats nao lidas',
                    ptBr: '$unreadChats nao lidas',
                    fr: '$unreadChats non lus',
                    de: '$unreadChats ungelesen',
                  ),
                ),
                _InfoPill(
                  icon: AppIcons.archive,
                  text: _desktopText(
                    context,
                    ru: '$archivedChats в архиве',
                    en: '$archivedChats archived',
                    uk: '$archivedChats в архіві',
                    es: '$archivedChats archivados',
                    pt: '$archivedChats arquivados',
                    ptBr: '$archivedChats arquivadas',
                    fr: '$archivedChats archives',
                    de: '$archivedChats archiviert',
                  ),
                ),
                _InfoPill(
                  icon: AppIcons.schedule,
                  text: _desktopText(
                    context,
                    ru: '$todayLabel: активность',
                    en: '$todayLabel: activity',
                    uk: '$todayLabel: активність',
                    es: '$todayLabel: actividad',
                    pt: '$todayLabel: atividade',
                    fr: '$todayLabel : activite',
                    de: '$todayLabel: Aktivitat',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(_kItemRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 500,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(_kItemRadius),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    children: [
                      _ShortcutHintRow(
                        left: const [
                          _KbdKey(label: 'Ctrl'),
                          _KbdKey(label: 'K'),
                        ],
                        text: _desktopText(
                          context,
                          ru: 'Быстрый переход к любому чату',
                          en: 'Quick switch to any chat',
                          uk: 'Швидкий перехід до будь-якого чату',
                          es: 'Cambio rapido a cualquier chat',
                          pt: 'Alternar rapido para qualquer chat',
                          ptBr: 'Alternar rapido para qualquer conversa',
                          fr: 'Acces rapide a n importe quel chat',
                          de: 'Schnell zu jedem Chat wechseln',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ShortcutHintRow(
                        left: const [
                          _KbdKey(label: 'Ctrl'),
                          _KbdKey(label: 'N'),
                        ],
                        text: _desktopText(
                          context,
                          ru: 'Открыть новый чат / контакт',
                          en: 'Open new chat / contact',
                          uk: 'Відкрити новий чат / контакт',
                          es: 'Abrir chat / contacto nuevo',
                          pt: 'Abrir novo chat / contacto',
                          ptBr: 'Abrir nova conversa / contato',
                          fr: 'Ouvrir un nouveau chat / contact',
                          de: 'Neuen Chat / Kontakt offnen',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ShortcutHintRow(
                        left: const [
                          _KbdKey(label: 'Alt'),
                          _KbdKey(label: '↑'),
                          _KbdKey(label: '↓'),
                        ],
                        text: _desktopText(
                          context,
                          ru: 'Переключение между чатами',
                          en: 'Cycle through conversations',
                          uk: 'Перемикання між чатами',
                          es: 'Cambiar entre conversaciones',
                          pt: 'Alternar entre conversas',
                          fr: 'Faire defiler les conversations',
                          de: 'Zwischen Unterhaltungen wechseln',
                        ),
                      ),
                    ],
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _kIconSizeSm + 1, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ShortcutHintRow extends StatelessWidget {
  const _ShortcutHintRow({required this.left, required this.text});

  final List<Widget> left;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Wrap(spacing: 4, children: left),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
      ],
    );
  }
}

class _KbdKey extends StatelessWidget {
  const _KbdKey({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.15),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.onSurface.withValues(alpha: 0.75),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────── _DesktopModalShell ──────────────────────────────

class _DesktopModalShell extends StatefulWidget {
  const _DesktopModalShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  State<_DesktopModalShell> createState() => _DesktopModalShellState();
}

class _DesktopModalShellState extends State<_DesktopModalShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = Tween<double>(
      begin: 0.93,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final maxH = (mq.size.height * 0.88).clamp(400.0, 720.0);

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kPanelRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                width: 480,
                constraints: BoxConstraints(maxHeight: maxH),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(_kPanelRadius),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 36,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header bar
                    SizedBox(
                      height: 52,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              widget.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: _kBtnSize,
                              height: _kBtnSize,
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  _kItemRadius,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                    _kItemRadius,
                                  ),
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Center(
                                    child: Icon(
                                      AppIcons.close,
                                      size: _kIconSizeMd,
                                      color: cs.onSurface.withValues(
                                        alpha: 0.55,
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
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                    // Content
                    Flexible(child: widget.child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── _ProfileAvatarMenuButton ────────────────────────

class _ProfileAvatarMenuButton extends StatelessWidget {
  const _ProfileAvatarMenuButton({
    required this.controller,
    required this.onProfile,
    required this.onSettings,
  });

  final AppController controller;
  final VoidCallback onProfile;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: _desktopText(context, ru: 'Меню профиля', en: 'Profile menu'),
      child: SizedBox(
        width: _kBtnSize,
        height: _kBtnSize,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              final RenderBox button = context.findRenderObject()! as RenderBox;
              final RenderBox overlay =
                  Overlay.of(context).context.findRenderObject()! as RenderBox;
              final offset = button.localToGlobal(
                Offset(0, button.size.height + 4),
                ancestor: overlay,
              );
              final selected = await showMenu<String>(
                context: context,
                position: RelativeRect.fromLTRB(
                  offset.dx,
                  offset.dy,
                  offset.dx + 180,
                  offset.dy + 120,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kItemRadius),
                ),
                items: [
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.profileFilled,
                          size: _kIconSizeMd,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _desktopText(context, ru: 'Профиль', en: 'Profile'),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.settings,
                          size: _kIconSizeMd,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _desktopText(
                            context,
                            ru: 'Настройки',
                            en: 'Settings',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              if (selected == 'profile') onProfile();
              if (selected == 'settings') onSettings();
            },
            child: Center(
              child: _DesktopAvatar(
                path: controller.myAvatarPath,
                title: controller.myNickname,
                fallbackId: controller.profileId,
                radius: _kAvatarRadiusMd,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── _DesktopSearchBar ───────────────────────────────

class _DesktopSearchBar extends StatefulWidget {
  const _DesktopSearchBar({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  State<_DesktopSearchBar> createState() => _DesktopSearchBarState();
}

class _DesktopSearchBarState extends State<_DesktopSearchBar> {
  bool _focused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  void _onFocusChange() => setState(() => _focused = widget.focusNode.hasFocus);
  void _onTextChange() =>
      setState(() => _hasText = widget.controller.text.isNotEmpty);

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      height: _kSearchHeight,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(
          alpha: _focused ? 0.9 : 0.6,
        ),
        borderRadius: BorderRadius.circular(_kItemRadius),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.18),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsetsDirectional.fromSTEB(0, 8, 10, 8),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 36,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(start: 10, end: 6),
            child: Icon(
              AppIcons.search,
              size: _kIconSizeMd,
              color: cs.onSurface.withValues(alpha: _focused ? 0.7 : 0.42),
            ),
          ),
          hintText: widget.hintText,
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.38),
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
          suffixIcon: _hasText
              ? IconButton(
                  visualDensity: VisualDensity.compact,
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  icon: Icon(
                    AppIcons.close,
                    size: _kIconSizeSm,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}
