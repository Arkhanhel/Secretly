// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'motion/decoration_pacer.dart';
import 'dart:async';
import 'dart:io';

import 'package:animations/animations.dart' as material_motion;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../app/app_controller.dart';
import '../rooms/room_call_state.dart';
import '../storage/file_exists_cache.dart';
import 'app_asset_paths.dart';
import 'animations/animations.dart';
import 'apple_glass.dart';
import 'app_brand_logo.dart';
import 'chat/chat_list_row_parts.dart';
import 'chat_screen.dart';
import 'chats_screen.dart' show showHomeMainMenu;
import 'home/home_islands.dart';
import 'home/home_shell_scope.dart';
import 'home/home_top_islands.dart';
import 'room_invite_join_screen.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'motion/app_dialogs.dart';
import 'motion/motion.dart';
import 'motion/press_feedback.dart';
import 'new_group_screen.dart';
import 'wave1_l10n.dart';
import 'room_call_screen.dart';
import 'shared_audio_controls.dart';
import 'widgets/apple_menu.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/chat_list_subtitle_preview.dart';
import 'widgets/content_edge_fade.dart';
import 'liquid_glass_flags.dart';
import 'widgets/frosted_header_island.dart';
import 'widgets/morphing_selection_islands.dart';
import 'widgets/frosted_top_bar.dart';
import 'widgets/secretly_glass_fab.dart';
import 'widgets/room_call_presence.dart';
import 'widgets/room_call_return_banner.dart';
import 'package:secretly_app/ui/apple_controls.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  static const String _roomFabPeopleAssetPath = AppAssetPaths.roomLottie;
  // Top-bar matte islands (chat-header style).
  static const double _kListIslandHeight = 48;
  static const double _kListIslandRadius = 24;
  static const double _kListActionsIslandWidth = 56;

  final Set<String> _selected = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _fabVisible = true;
  bool _searchOpen = false;
  String _searchQuery = '';

  // PERF (tab-switch flash): keep the last successful list/room-call snapshot so
  // re-shows (after switching tabs or on a `controller.changed` rebuild) render
  // the cached list instantly instead of flashing empty for ~1 s while the next
  // DB reload is in flight. The resolved future always overwrites the cache, so
  // data correctness is unchanged.
  // С первого кадра — последний известный список (23.11.2026): новый экран
  // не стоит пустым, пока идёт запрос к базе.
  late List<Conversation> _lastConvos = widget.controller.lastKnownConversations;
  // COLD START (2026-07-28): same fix as the Chats tab — the list falls back to
  // the (empty on a cold start) cache while the first query is in flight, so an
  // unfinished load rendered the "nothing here yet" placeholder. Show a spinner
  // until the first result actually arrives.
  bool _roomsEverLoaded = false;
  Map<String, CachedRoomCall> _lastActiveRoomCallsById =
      const <String, CachedRoomCall>{};
  // Memoized rooms query — recomputed only when controller.changeVersion
  // changes, not on every rebuild/animation frame (mirrors the chats list).
  Future<(List<Conversation>, Map<String, CachedRoomCall>)>? _roomsFuture;
  int _roomsFutureVersion = -1;

  bool get _selectionMode => _selected.isNotEmpty;

  String _roomsLabel(BuildContext context) {
    return wave1Text(context, ru: 'Комнаты', en: 'Rooms');
  }

  String _menuLabel(
    BuildContext context, {
    required String ru,
    required String en,
  }) {
    return wave1Text(context, ru: ru, en: en);
  }

  void _toggleSelected(String convoId) {
    setState(() {
      if (_selected.contains(convoId)) {
        _selected.remove(convoId);
      } else {
        _selected.add(convoId);
        if (_searchOpen) {
          _searchOpen = false;
          _searchController.clear();
          _searchQuery = '';
          _searchFocusNode.unfocus();
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _fabVisible = true;
    });
  }

  void _setFabVisible(bool visible) {
    if (_fabVisible == visible || !mounted) {
      return;
    }
    setState(() {
      _fabVisible = visible;
    });
  }

  bool _handleFabScroll(ScrollNotification notification) {
    if (notification is! UserScrollNotification) {
      return false;
    }
    switch (notification.direction) {
      case ScrollDirection.reverse:
        _setFabVisible(false);
        return false;
      case ScrollDirection.forward:
        _setFabVisible(true);
        return false;
      case ScrollDirection.idle:
        return false;
    }
  }

  Future<String?> _pickArchiveDestination() async {
    return showAppDialog<String>(
      context: context,
      builder: (context) {
        return SecretlyAlertDialog(
          title: Text(
            _menuLabel(
              context,
              ru: 'Куда переместить комнаты?',
              en: 'Where should the rooms go?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('personal'),
              child: Text(
                _menuLabel(context, ru: 'В Личные', en: 'Move to Personal'),
              ),
            ),
            PressFeedback(child: FilledButton(
              onPressed: () => Navigator.of(context).pop('archive'),
              child: Text(
                _menuLabel(context, ru: 'В Архив', en: 'Move to Archive'),
              ),
            )),
          ],
        );
      },
    );
  }

  String _activeRoomCallSubtitle(CachedRoomCall call) {
    return formatRoomCallPresenceText(
      context,
      call,
      inactiveLabel: _menuLabel(context, ru: 'Комната', en: 'Room'),
    );
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ── Острова v3 ─────────────────────────────────────────────────────────

  bool _titleMenuOpen = false;

  Future<void> _openTitleMenu() async {
    setState(() => _titleMenuOpen = true);
    try {
      await showHomeMainMenu(context, widget.controller, anchorLeft: true);
    } finally {
      if (mounted) setState(() => _titleMenuOpen = false);
    }
  }

  String _tr({
    required String ru,
    required String en,
    required String uk,
    required String es,
    required String pt,
    required String fr,
    required String de,
  }) => wave1Text(
    context,
    ru: ru,
    en: en,
    uk: uk,
    es: es,
    pt: pt,
    ptBr: pt,
    fr: fr,
    de: de,
  );

  List<HomePlusAction> _homePlusActions() => [
    HomePlusAction(
      label: _tr(
        ru: 'Создать комнату',
        en: 'Create room',
        uk: 'Створити кімнату',
        es: 'Crear sala',
        pt: 'Criar sala',
        fr: 'Créer un salon',
        de: 'Raum erstellen',
      ),
      icon: AppIcons.createGroup,
      onTap: () async {
        final groupId = await Navigator.of(context).push<String>(
          SecretlyPageRoute(
            builder: (_) => NewGroupScreen(controller: widget.controller),
          ),
        );
        await _openCreatedGroupChat(
          controller: widget.controller,
          groupId: groupId,
        );
      },
    ),
    HomePlusAction(
      label: _tr(
        ru: 'Войти по приглашению',
        en: 'Join by invite link',
        uk: 'Увійти за запрошенням',
        es: 'Unirse con enlace',
        pt: 'Entrar por convite',
        fr: 'Rejoindre par lien',
        de: 'Per Einladung beitreten',
      ),
      icon: CupertinoIcons.link,
      onTap: _joinByInvite,
    ),
  ];

  /// Вставить ссылку-приглашение: если она уже в буфере — подставлена.
  Future<void> _joinByInvite() async {
    String initial = '';
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final text = (clip?.text ?? '').trim();
      final uri = Uri.tryParse(text);
      if (uri != null && tryParseRoomInviteUri(uri) != null) initial = text;
    } catch (_) {}
    if (!mounted) return;
    final field = TextEditingController(text: initial);
    final link = await showAppDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _tr(
            ru: 'Вход по приглашению',
            en: 'Join by invite',
            uk: 'Вхід за запрошенням',
            es: 'Unirse con invitación',
            pt: 'Entrar por convite',
            fr: 'Rejoindre par invitation',
            de: 'Per Einladung beitreten',
          ),
        ),
        content: TextField(
          controller: field,
          autofocus: initial.isEmpty,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: _tr(
              ru: 'Вставьте ссылку на комнату',
              en: 'Paste the room link',
              uk: 'Вставте посилання на кімнату',
              es: 'Pega el enlace de la sala',
              pt: 'Cole o link da sala',
              fr: 'Collez le lien du salon',
              de: 'Raum-Link einfügen',
            ),
          ),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(field.text),
            child: Text(
              _tr(
                ru: 'Открыть',
                en: 'Open',
                uk: 'Відкрити',
                es: 'Abrir',
                pt: 'Abrir',
                fr: 'Ouvrir',
                de: 'Öffnen',
              ),
            ),
          ),
        ],
      ),
    );
    field.dispose();
    if (!mounted || link == null || link.trim().isEmpty) return;
    final uri = Uri.tryParse(link.trim());
    final target = uri == null ? null : tryParseRoomInviteUri(uri);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              ru: 'Это не ссылка-приглашение в комнату',
              en: 'This is not a room invite link',
              uk: 'Це не посилання-запрошення до кімнати',
              es: 'No es un enlace de invitación a una sala',
              pt: 'Este não é um link de convite para sala',
              fr: 'Ce n’est pas un lien d’invitation à un salon',
              de: 'Das ist kein Raum-Einladungslink',
            ),
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => RoomInviteJoinScreen(
          controller: widget.controller,
          target: target,
        ),
      ),
    );
  }

  Future<void> _openCreatedGroupChat({
    required AppController controller,
    required String? groupId,
  }) async {
    if (!mounted || groupId == null || groupId.isEmpty) return;
    final updated = await controller.listConversations();
    if (!mounted) return;
    final created = updated
        .where((c) => c.convoId == groupId)
        .cast<Conversation?>()
        .firstOrNull;
    final title = created?.title ?? 'Group';
    Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) =>
            ChatScreen(controller: controller, convoId: groupId, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = context.l10n;
    return StreamBuilder<void>(
      stream: controller.changed,
      builder: (context, _) {
        final dataVersion = controller.changeVersion;
        if (_roomsFuture == null || _roomsFutureVersion != dataVersion) {
          _roomsFutureVersion = dataVersion;
          _roomsFuture = () async {
            final convos = await controller.listConversations();
            final activeRoomCalls = await controller
                .listCachedActiveRoomCalls();
            return (
              convos,
              <String, CachedRoomCall>{
                for (final call in activeRoomCalls) call.roomId: call,
              },
            );
          }();
        }
        return FutureBuilder<(List<Conversation>, Map<String, CachedRoomCall>)>(
          future: _roomsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _lastConvos = snapshot.data!.$1;
              _lastActiveRoomCallsById = snapshot.data!.$2;
              _roomsEverLoaded = true;
            }
            final convos = snapshot.data?.$1 ?? _lastConvos;
            final activeRoomCallsById =
                snapshot.data?.$2 ?? _lastActiveRoomCallsById;
            final queryLower = _searchQuery.trim().toLowerCase();
            final byId = <String, Conversation>{
              for (final convo in convos) convo.convoId: convo,
            };
            final selectedConvos = _selected
                .map((id) => byId[id])
                .whereType<Conversation>()
                .where((c) => c.convoId.startsWith('group:'))
                .toList(growable: false);
            final groups = convos
                .where((c) => c.convoId.startsWith('group:'))
                .where(
                  (c) =>
                      c.archivedAtMs == null &&
                      !controller.isPersonalChat(c.convoId),
                )
                .where(
                  // Match the room's visible title only — never the internal
                  // convoId (`group:<uuid>`), so "group"/uuid fragments don't
                  // surface every room.
                  (c) =>
                      queryLower.isEmpty ||
                      c.title.toLowerCase().contains(queryLower),
                )
                .toList(growable: true);
            groups.sort((a, b) {
              final aCall = activeRoomCallsById[a.convoId];
              final bCall = activeRoomCallsById[b.convoId];
              if ((aCall != null) != (bCall != null)) {
                return aCall != null ? -1 : 1;
              }
              if (aCall != null && bCall != null) {
                final updatedCompare = bCall.updatedAtMs.compareTo(
                  aCall.updatedAtMs,
                );
                if (updatedCompare != 0) {
                  return updatedCompare;
                }
              }
              final pinnedCompare = (b.pinnedAtMs ?? 0).compareTo(
                a.pinnedAtMs ?? 0,
              );
              if (pinnedCompare != 0) {
                return pinnedCompare;
              }
              return b.lastEventAtMs.compareTo(a.lastEventAtMs);
            });
            final media = MediaQuery.of(context);
            final bottomInset = media.padding.bottom;
            // Search expands inside the toolbar island now (no bottom field).
            final appBarInset = media.padding.top + kToolbarHeight;
            // One formula for both platforms: the bar's own footprint plus a single
            // shared gap, so the distance above the bar is identical on iOS and
            // Android instead of two hardcoded numbers.
            final fabBottomOffset = fabBottomOffsetFor(context);

            AppBar buildAppBar() {
              // BUBBLE MORPH (seamless): content layers for the two PERSISTENT
              // frosted frames rendered by MorphingSelectionIslands in the single
              // return below.
              final home = HomeShellScope.maybeOf(context);
              final Widget titleContent = home != null
                  ? HomeTitleIslandContent(
                      brand: AppBrandLogo(
                        controller: controller,
                        showPremiumBadge: false,
                        titleSize: 18,
                        tight: true,
                      ),
                      menuOpen: _titleMenuOpen,
                      onTap: _openTitleMenu,
                      semanticLabel: l10n.more,
                    )
                  : Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _roomsLabel(context),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
              );
              final Widget compactSearchContent = Center(
                child: PressFeedback(child: IconButton(
                  tooltip: l10n.search,
                  icon: const Icon(AppIcons.search),
                  onPressed: _toggleSearch,
                )),
              );
              final Widget searchFieldContent = Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(AppIcons.search, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: l10n.queryLabel,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  PressFeedback(child: IconButton(
                    tooltip: l10n.cancel,
                    icon: const Icon(AppIcons.close),
                    onPressed: _toggleSearch,
                  )),
                ],
              );

              final anyActive = selectedConvos.any(
                (c) => c.archivedAtMs == null,
              );
              final shouldArchive = anyActive;
              final anyUnmuted = selectedConvos.any((c) => !c.muted);
              final shouldMute = anyUnmuted;
              final anyUnpinned = selectedConvos.any(
                (c) => c.pinnedAtMs == null,
              );
              final shouldPin = anyUnpinned;
              final anyNotPersonal = selectedConvos.any(
                (c) => !controller.isPersonalChat(c.convoId),
              );
              final shouldPersonal = anyNotPersonal;

              final Widget selCountContent = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PressFeedback(child: IconButton(
                    tooltip: l10n.cancelSelection,
                    icon: const Icon(AdaptiveIcons.close),
                    onPressed: _clearSelection,
                  )),
                  Padding(
                    padding: const EdgeInsets.only(right: 10, left: 2),
                    child: Text(
                      '${_selected.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              );
              final Widget selActionsContent = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PressFeedback(child: IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(AdaptiveIcons.delete_outline_rounded),
                    onPressed: selectedConvos.isEmpty
                        ? null
                        : () async {
                            final ok = await showAppDialog<bool>(
                              context: context,
                              builder: (context) {
                                return SecretlyAlertDialog(
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
                            if (!mounted || ok != true) return;
                            for (final convo in selectedConvos) {
                              await controller.deleteChat(
                                convoId: convo.convoId,
                              );
                            }
                            _clearSelection();
                          },
                  )),
                  PressFeedback(child: IconButton(
                    tooltip: shouldArchive ? l10n.archive : l10n.unarchive,
                    icon: Icon(
                      shouldArchive
                          ? AdaptiveIcons.archive_outlined
                          : AdaptiveIcons.unarchive_outlined,
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
                                for (final convo in selectedConvos) {
                                  await controller.setChatArchived(
                                    convoId: convo.convoId,
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
                                for (final convo in selectedConvos) {
                                  await controller.setChatArchived(
                                    convoId: convo.convoId,
                                    archived: true,
                                  );
                                }
                              }
                            } else {
                              for (final convo in selectedConvos) {
                                await controller.setChatArchived(
                                  convoId: convo.convoId,
                                  archived: false,
                                );
                                await controller.setChatPersonal(
                                  convoId: convo.convoId,
                                  personal: false,
                                );
                              }
                            }
                            _clearSelection();
                          },
                  )),
                  PressFeedback(child: IconButton(
                    tooltip: shouldMute
                        ? l10n.muteNotifications
                        : l10n.unmuteNotifications,
                    icon: Icon(
                      shouldMute
                          ? AdaptiveIcons.notifications_off_outlined
                          : AdaptiveIcons.notifications_outlined,
                    ),
                    onPressed: selectedConvos.isEmpty
                        ? null
                        : () async {
                            for (final convo in selectedConvos) {
                              await controller.setChatMuted(
                                convoId: convo.convoId,
                                muted: shouldMute,
                              );
                            }
                            _clearSelection();
                          },
                  )),
                  PressFeedback(child: IconButton(
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
                          ? AdaptiveIcons.person_add_outlined
                          : AdaptiveIcons.person_remove_outlined,
                    ),
                    onPressed: selectedConvos.isEmpty
                        ? null
                        : () async {
                            await controller.setManyChatsPersonal(
                              convoIds: selectedConvos.map((c) => c.convoId),
                              personal: shouldPersonal,
                            );
                            if (!mounted) return;
                            _clearSelection();
                          },
                  )),
                  AppPopupMenuButton<String>(
                    tooltip: l10n.more,
                    onSelected: (value) async {
                      if (value == 'pin') {
                        for (final convo in selectedConvos) {
                          await controller.setChatPinned(
                            convoId: convo.convoId,
                            pinned: shouldPin,
                          );
                        }
                        _clearSelection();
                      } else if (value == 'clear') {
                        final ok = await showAppDialog<bool>(
                          context: context,
                          builder: (context) {
                            return SecretlyAlertDialog(
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
                        if (!mounted || ok != true) return;
                        for (final convo in selectedConvos) {
                          await controller.clearChatHistory(
                            convoId: convo.convoId,
                          );
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
              );

              return frostedAppBar(
                automaticallyImplyLeading: false,
                flexibleSpace: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: SizedBox(
                      height: _kListIslandHeight,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: _selectionMode ? 1.0 : 0.0),
                        duration: Duration(
                          milliseconds: _selectionMode ? 360 : 240,
                        ),
                        curve: Motion.pop,
                        builder: (context, sel, _) {
                          return TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: _searchOpen ? 1.0 : 0.0),
                            duration: const Duration(milliseconds: 260),
                            curve: Motion.standard,
                            builder: (context, s, _) {
                              return MorphingSelectionIslands(
                                searchReveal: s,
                                selectionReveal: sel,
                                leftNormalContent: titleContent,
                                leftSelectionContent: selCountContent,
                                rightCompactContent: home != null
                                    ? HomeTopActionsContent(
                                        plus: _homePlusActions(),
                                        contactsActive: false,
                                        onContacts: () =>
                                            home.select(HomeTab.contacts),
                                        plusLabel: _tr(
                                          ru: 'Создать',
                                          en: 'Create',
                                          uk: 'Створити',
                                          es: 'Crear',
                                          pt: 'Criar',
                                          fr: 'Créer',
                                          de: 'Erstellen',
                                        ),
                                        contactsLabel: l10n.tabContacts,
                                      )
                                    : compactSearchContent,
                                rightSearchContent: searchFieldContent,
                                rightSelectionContent: selActionsContent,
                                islandRadius: _kListIslandRadius,
                                islandHeight: _kListIslandHeight,
                                leftPadding: home != null ? 10 : 18,
                                compactRightWidth: home != null
                                    ? kHomeTopActionsWidth
                                    : _kListActionsIslandWidth,
                                centerLeftNormal: false,
                                compactLeft: home != null,
                                centerTitle: home != null
                                    ? _roomsLabel(context)
                                    : null,
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

            Future<(CachedRoomCall?, String)> loadRoomCallBanner() async {
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
            }

            Widget buildRoomCallBanner(CachedRoomCall? call, String title) {
              if (call == null) return const SizedBox.shrink();
              final sp = call.selfParticipant;
              return RuntimeAwareRoomCallReturnBanner(
                // Строка общей пластины островков (23.11.2026).
                merged: true,
                title: title,
                call: call,
                onMicTap: sp != null && sp.isJoined
                    ? () => unawaited(
                        controller.updateRelayRoomCallParticipant(
                          roomId: call.roomId,
                          callId: call.callId,
                          reconnecting: sp.isReconnecting,
                          muted: !sp.muted,
                          deafened: sp.deafened,
                          videoEnabled: sp.videoEnabled,
                          screenShareEnabled: sp.screenShareEnabled,
                          speaking: sp.speaking,
                        ),
                      )
                    : null,
                onTap: () {
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

            Widget buildGroupsBody({
              required double appBarInset,
              required CachedRoomCall? roomCall,
              required String roomCallTitle,
            }) {
              final headerItems = <Widget>[
                SizedBox(height: appBarInset),
                // Music island is rendered as a pinned overlay (see Stack at the
                // call site) so it no longer scrolls with the list — reserve its
                // height here.
                // Звонок в комнате — строкой той же пластины (23.11.2026).
                SharedAudioTopIslandsReserve(
                  controller: widget.controller,
                  roomCallVisible: roomCall != null,
                ),
                const SizedBox(height: 8),
              ];

              if (groups.isEmpty) {
                return ListView(
                  padding: EdgeInsets.only(bottom: 108 + bottomInset),
                  children: [
                    ...headerItems,
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: _roomsEverLoaded
                          ? Text(
                              _searchQuery.trim().isEmpty
                                  ? l10n.noChatsYet
                                  : l10n.noMatches,
                              textAlign: TextAlign.center,
                            )
                          : const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: SecretlySpinner(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              }

              return NotificationListener<ScrollNotification>(
                onNotification: _handleFabScroll,
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: 108 + bottomInset),
                  itemCount: headerItems.length + groups.length,
                  itemBuilder: (context, i) {
                    if (i < headerItems.length) {
                      return headerItems[i];
                    }

                    final c = groups[i - headerItems.length];
                    final selected = _selected.contains(c.convoId);
                    final activeRoomCall = activeRoomCallsById[c.convoId];
                    void openGroupChat() {
                      Navigator.of(context).push(
                        SecretlyPageRoute(
                          builder: (_) => ChatScreen(
                            controller: controller,
                            convoId: c.convoId,
                            title: c.title,
                          ),
                        ),
                      );
                    }

                    final avatarPath = c.avatarPath;
                    final hasAvatar =
                        avatarPath != null &&
                        avatarPath.isNotEmpty &&
                        FileExistsCache.exists(avatarPath);
                    final fallbackId = c.convoId;
                    final seed = fallbackId.isNotEmpty ? fallbackId : c.title;
                    final avatar = hasAvatar
                        ? CircleAvatar(
                            radius: 26,
                            backgroundImage: FileImage(File(avatarPath)),
                          )
                        : AvatarInitials.fallbackBubble(
                            context: context,
                            radius: 26,
                            seed: seed,
                            displayName: c.title,
                            fallbackId: fallbackId,
                          );
                    final defaultLeading = activeRoomCall == null
                        ? avatar
                        : Stack(
                            clipBehavior: Clip.none,
                            children: [
                              avatar,
                              Positioned(
                                right: -3,
                                bottom: -3,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    activeRoomCall.mediaType == 'video'
                                        ? AppIcons.video
                                        : AppIcons.callAlt,
                                    size: 10,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          );
                    final leading = _selectionMode
                        ? AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: CircleAvatar(
                              radius: 26,
                              key: ValueKey<bool>(selected),
                              child: Icon(
                                selected
                                    ? AppIcons.check
                                    : AppIcons.radioUnchecked,
                              ),
                            ),
                          )
                        : defaultLeading;
                    // Макет 3b, как в «Чатах»: после закреплённых — зазор 6.
                    final gi = i - headerItems.length;
                    final gapAfterPinned =
                        kChatListRowV2 &&
                        c.pinnedAtMs != null &&
                        gi + 1 < groups.length &&
                        groups[gi + 1].pinnedAtMs == null;
                    final row = InkWell(
                      onLongPress: () => _toggleSelected(c.convoId),
                      onTap: () {
                        if (_selectionMode) {
                          _toggleSelected(c.convoId);
                          return;
                        }
                        openGroupChat();
                      },
                      child: ColoredBox(
                        color: selected
                            ? Theme.of(context).colorScheme.secondaryContainer
                                  .withValues(alpha: 0.45)
                            : Colors.transparent,
                        child: ChatListRowFlash(
                          stamp: c.lastEventAtMs,
                          unread: c.unreadCount,
                          child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(width: 52, height: 52, child: leading),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  // Крупный шрифт: строка растёт вместе с
                                  // текстом (при обычном — прежние 52).
                                  height: MediaQuery.textScalerOf(context)
                                      .scale(52)
                                      .clamp(52.0, 96.0),
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
                                            Expanded(
                                              child: Text(
                                                c.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (c.pinnedAtMs != null &&
                                                kChatListRowV2)
                                              const ChatListPinGlyph()
                                            else if (c.pinnedAtMs != null) ...[
                                              Icon(
                                                AppIcons.pin,
                                                size: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: 0.55),
                                              ),
                                              const SizedBox(width: 3),
                                            ],
                                            activeRoomCall != null
                                                ? _ActiveRoomCallPill(
                                                    call: activeRoomCall,
                                                  )
                                                : kChatListRowV2
                                                ? ChatListTime(
                                                    ms: c.lastEventAtMs,
                                                    highlight:
                                                        c.unreadCount > 0 &&
                                                        !c.muted,
                                                  )
                                                : _TimePill(
                                                    ms: c.lastEventAtMs,
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
                                              child: activeRoomCall != null
                                                  ? Text(
                                                      _activeRoomCallSubtitle(
                                                        activeRoomCall,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    )
                                                  : ChatListRowSubtitle(
                                                    // Черновик комнаты — как
                                                    // во вкладке «Чаты».
                                                    draftKey: c.convoId,
                                                    preview: ChatListSubtitlePreview(
                                                      key: ValueKey<String>(
                                                        'room-subtitle-${c.convoId}',
                                                      ),
                                                      controller: controller,
                                                      convoId: c.convoId,
                                                      // Version by last event
                                                      // time (not the global
                                                      // changeVersion) PLUS the
                                                      // per-convo preview epoch
                                                      // so edits (same
                                                      // createdAtMs) refresh.
                                                      previewVersion:
                                                          c.lastEventAtMs +
                                                          controller
                                                              .convoPreviewEpoch(
                                                                c.convoId,
                                                              ),
                                                      subtitleFallback:
                                                          c.convoId,
                                                      rowV2: kChatListRowV2,
                                                      unreadCount:
                                                          c.unreadCount,
                                                    ),
                                                  ),
                                            ),
                                            if (c.unreadCount > 0) ...[
                                              const SizedBox(width: 6),
                                              if (kChatListRowV2)
                                                ChatListUnreadBadge(
                                                  count: c.unreadCount,
                                                  muted: c.muted,
                                                )
                                              else
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
                      ),
                    );
                    return gapAfterPinned
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: row,
                          )
                        : row;
                  },
                ),
              );
            }

            final fabShiftX = mobileBottomNavSettingsFabShiftX(context);
            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: buildAppBar(),
              // Острова v3: «Создать комнату» — в «+» верхнего островка.
              floatingActionButton:
                  !_selectionMode && HomeShellScope.maybeOf(context) == null
                  ? Padding(
                      padding: EdgeInsets.only(bottom: fabBottomOffset + 4),
                      child: AnimatedFab(
                        visible: _fabVisible,
                        child: Transform.translate(
                          offset: Offset(fabShiftX, 0),
                          child: material_motion.OpenContainer<String?>(
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
                                NewGroupScreen(controller: controller),
                            onClosed: (groupId) {
                              _openCreatedGroupChat(
                                controller: controller,
                                groupId: groupId,
                              );
                            },
                            closedBuilder: (context, openContainer) {
                              return SecretlyGlassFabButton(
                                tooltip: l10n.add,
                                icon: const _RoomsFabIcon(
                                  assetPath: _roomFabPeopleAssetPath,
                                ),
                                onPressed: openContainer,
                              );
                            },
                          ),
                        ),
                      ),
                    )
                  : null,
              body: FutureBuilder<(CachedRoomCall?, String)>(
                future: loadRoomCallBanner(),
                builder: (context, roomCallSnap) {
                  final roomCall = roomCallSnap.data?.$1;
                  final roomCallTitle = roomCallSnap.data?.$2 ?? '';
                  return Stack(
                    children: [
                      // Telegram-style content edge fade: the list's CONTENT
                      // dissolves to transparent at the top (under the header
                      // islands) and bottom (over the nav-pill gesture area).
                      // Paints no shading itself — it only masks the list's
                      // alpha, so the SystemTopFadeLayer below and the shell's
                      // SystemBottomFadeLayer compose on top of it.
                      ContentEdgeFade(
                        topFadeEndPx: appBarInset,
                        bottomFadeFraction: 0.07,
                        child: buildGroupsBody(
                          appBarInset: appBarInset,
                          roomCall: roomCall,
                          roomCallTitle: roomCallTitle,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SystemTopFadeLayer(
                          height: appBarInset,
                          blurSigma: 20,
                        ),
                      ),
                      // Pinned music island under the top bar (0-height idle).
                      Positioned(
                        top: appBarInset,
                        left: 0,
                        right: 0,
                        // Музыка, звонок и звонок в комнате — одна «жидкая»
                        // пластина (23.11.2026).
                        child: SharedAudioTopIslands(
                          controller: widget.controller,
                          roomCall: roomCall == null
                              ? null
                              : buildRoomCallBanner(roomCall, roomCallTitle),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

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
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
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
    // iPhone: время — просто текст цвета `secondaryLabel`, как в списках
    // iOS/Telegram. Серая «таблетка» с текстом 38 % (≈ 2,2 : 1) читалась
    // плохо в светлой теме.
    if (appleGlassPanelsEnabled) {
      return Text(
        _formatTime(ms),
        style: TextStyle(
          color: AppleGlass.secondaryLabel(isDark),
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.2,
        ),
      );
    }
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
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.black.withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }
}

class _ActiveRoomCallPill extends StatelessWidget {
  const _ActiveRoomCallPill({required this.call});

  final CachedRoomCall call;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selfReconnecting = call.selfParticipant?.isReconnecting ?? false;
    final accent = selfReconnecting ? const Color(0xFFE67E22) : cs.primary;
    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            call.mediaType == 'video' ? AppIcons.video : AppIcons.callAlt,
            size: 11,
            color: accent,
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE ${call.joinedParticipantCount}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomsFabIcon extends StatefulWidget {
  const _RoomsFabIcon({required this.assetPath});

  final String assetPath;

  @override
  State<_RoomsFabIcon> createState() => _RoomsFabIconState();
}

/// 23.11.2026: вечная анимация значка «Комнаты» шла внутренним контроллером
/// Lottie на каждое обновление экрана (замер Xiaomi: список комнат в покое
/// ~73 кадра в секунду). Свой контроллер на размеренном тикере — не чаще 60.
class _RoomsFabIconState extends State<_RoomsFabIcon>
    with PacedTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this);

  String get assetPath => widget.assetPath;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
                assetPath,
                controller: _ctrl,
                onLoaded: (composition) {
                  _ctrl
                    ..duration = composition.duration
                    ..repeat();
                },
                fit: BoxFit.contain,
                frameRate: FrameRate.max,
                errorBuilder: (_, __, ___) => const Icon(
                  AppIcons.groupOutline,
                  size: 24,
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
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
}
