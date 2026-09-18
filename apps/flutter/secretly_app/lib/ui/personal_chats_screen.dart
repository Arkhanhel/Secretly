// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart' as material_motion;
import 'package:flutter_svg/flutter_svg.dart';

import '../app/app_controller.dart';
import '../security/app_security_manager.dart';
import 'app_asset_paths.dart';
import 'chat_screen.dart';
import 'favorites_title.dart';
import 'icons/app_icons.dart';
import 'security_lock_flow.dart';
import 'wave1_l10n.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/call_return_banner.dart';
import 'widgets/chat_list_subtitle_preview.dart';
import 'widgets/frosted_header_island.dart';
import 'widgets/liquid_glass_segment.dart';
import 'widgets/liquid_pressable.dart';


class PersonalChatsScreen extends StatefulWidget {
  const PersonalChatsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<PersonalChatsScreen> createState() => _PersonalChatsScreenState();
}

class _PersonalChatsScreenState extends State<PersonalChatsScreen> {
  final Set<String> _selected = <String>{};

  // Personal(0) / Archive(1) category, driven by the glass segment and the
  // swipeable PageView in lock-step (replaces the old TabController).
  int _category = 0;
  final PageController _pageController = PageController();

  void _selectCategory(int i) {
    if (i == _category) return;
    setState(() => _category = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // PERF (tab-switch flash): cache the last successful conversation list so a
  // re-show (tab switch / `controller.changed` rebuild) renders instantly from
  // cache instead of flashing empty for ~1 s while the next DB reload runs. The
  // resolved future always overwrites the cache, so correctness is unchanged.
  List<Conversation> _lastConvos = const <Conversation>[];

  bool get _selectionMode => _selected.isNotEmpty;

  int _compareConversationOrder(Conversation left, Conversation right) {
    final byPinned = (right.pinnedAtMs ?? 0).compareTo(left.pinnedAtMs ?? 0);
    if (byPinned != 0) return byPinned;
    final byLastEvent = right.lastEventAtMs.compareTo(left.lastEventAtMs);
    if (byLastEvent != 0) return byLastEvent;
    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  }

  String _label(
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
      }
    });
  }

  void _clearSelection() {
    setState(_selected.clear);
  }

  Future<void> _moveSelectedToMain(List<Conversation> convos) async {
    if (convos.isEmpty) return;
    for (final c in convos) {
      await widget.controller.setChatArchived(
        convoId: c.convoId,
        archived: false,
      );
      await widget.controller.setChatPersonal(
        convoId: c.convoId,
        personal: false,
      );
    }
    if (!mounted) return;
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final personalTitle = _label(context, ru: 'Личные', en: 'Personal');
    final archiveTitle = _label(context, ru: 'Архив', en: 'Archive');

    return Builder(
      builder: (context) {
          return StreamBuilder<void>(
            stream: controller.changed,
            builder: (context, _) {
              return FutureBuilder<List<Conversation>>(
                future: controller.listConversations(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    _lastConvos = snapshot.data!;
                  }
                  final all = snapshot.data ?? _lastConvos;
                  final allowedIds = controller.personalConvoIds;

                  final personal =
                      all
                          .where(
                            (c) =>
                                allowedIds.contains(c.convoId) &&
                                c.archivedAtMs == null,
                          )
                          .toList(growable: false)
                        ..sort(_compareConversationOrder);
                  final archived =
                      all
                          .where((c) => c.archivedAtMs != null)
                          .toList(growable: false)
                        ..sort(_compareConversationOrder);
                  final unreadPersonalChatsCount = personal
                      .where((c) => c.unreadCount > 0)
                      .length;
                  final unreadArchivedChatsCount = archived
                      .where((c) => c.unreadCount > 0)
                      .length;

                  final byId = <String, Conversation>{
                    for (final c in [...personal, ...archived]) c.convoId: c,
                  };
                  final selectedConvos = _selected
                      .map((id) => byId[id])
                      .whereType<Conversation>()
                      .toList(growable: false);

                  // Island header (owner: no top app bar). Left island holds
                  // the back arrow + page title; in selection mode it becomes
                  // cancel + count + "move to main". A separate glass segment
                  // below switches Personal↔Archive with the nav-bar jelly.
                  Widget buildHeader() {
                    final Widget leftIsland;
                    if (!_selectionMode) {
                      leftIsland = FrostedHeaderIsland(
                        radius: 22,
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LiquidIconButton(
                              icon: AppIcons.arrowBack,
                              tooltip: _label(context, ru: 'Назад', en: 'Back'),
                              size: 22,
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            const SizedBox(width: 2),
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Text(
                                personalTitle,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      leftIsland = FrostedHeaderIsland(
                        radius: 22,
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LiquidIconButton(
                              icon: Icons.close,
                              tooltip: _label(
                                context,
                                ru: 'Отмена',
                                en: 'Cancel',
                              ),
                              size: 22,
                              onPressed: _clearSelection,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '${_selected.length}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            LiquidIconButton(
                              icon: Icons.unarchive_outlined,
                              tooltip: _label(
                                context,
                                ru: 'На главную',
                                en: 'Move to main',
                              ),
                              size: 22,
                              onPressed: selectedConvos.isEmpty
                                  ? null
                                  : () => _moveSelectedToMain(selectedConvos),
                            ),
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: leftIsland,
                          ),
                          const SizedBox(height: 10),
                          LiquidGlassSegment(
                            selected: _category,
                            onSelect: _selectCategory,
                            labels: [personalTitle, archiveTitle],
                            badges: [
                              unreadPersonalChatsCount,
                              unreadArchivedChatsCount,
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  // The list scrolls UNDER the floating header, so reserve the
                  // header height at the top; the glass then has live content to
                  // refract (a flat background refracts to nothing — the "плоское
                  // белое стекло" the owner saw).
                  final headerReserve =
                      MediaQuery.of(context).padding.top + 8 + 44 + 10 + 44 + 12;
                  Widget listFor(List<Conversation> source) {
                    if (source.isEmpty) {
                      return Center(
                        child: Text(
                          _label(
                            context,
                            ru: 'Пока пусто',
                            en: 'Empty for now',
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: EdgeInsets.only(top: headerReserve),
                      itemCount: source.length,
                      itemBuilder: (context, i) {
                        final c = source[i];
                        final isRequest = c.convoId.startsWith('req:');
                        final isGroup = c.convoId.startsWith('group:');
                        final isFavoritesChat = controller.isSavedMessagesConvo(
                          c.convoId,
                        );
                        final baseTitle = isFavoritesChat
                          ? localizedFavoritesTitle(context)
                          : c.title;
                        final titleText =
                          (c.emoji != null && c.emoji!.isNotEmpty)
                          ? '$baseTitle ${c.emoji!}'
                          : baseTitle;
                        final selected = _selected.contains(c.convoId);

                        final chatDestination = isRequest
                            ? ChatScreen(
                                controller: controller,
                                convoId: c.convoId,
                                title: titleText,
                                requestProfileId:
                                    c.peerProfileId ?? c.convoId.substring(4),
                              )
                          : isGroup
                          ? ChatScreen(
                            controller: controller,
                            convoId: c.convoId,
                            title: titleText,
                            initialForwardDraft: controller.forwardDraft,
                            )
                            : ChatScreen(
                                controller: controller,
                                convoId: c.peerProfileId ?? c.convoId,
                                title: titleText,
                                peerProfileIdForSend:
                                    c.peerProfileId ?? c.convoId,
                                initialForwardDraft: controller.forwardDraft,
                              );

                        return material_motion.OpenContainer<void>(
                          // Без ключа Element переиспользуется ПО ПОЗИЦИИ: новый
                          // чат в начале списка сдвигает все строки, и каждая
                          // получает чужой convoId — то есть заново оплачивает
                          // загрузку превью. Тот же ключ, что и в общем списке
                          // чатов (`chat-tile-…`), только там он уже был.
                          key: ValueKey<String>('personal-tile-${c.convoId}'),
                          transitionDuration: const Duration(milliseconds: 230),
                          transitionType:
                              material_motion.ContainerTransitionType.fade,
                          closedElevation: 0,
                          openElevation: 0,
                          closedColor: Colors.transparent,
                          openColor: Theme.of(context).colorScheme.surface,
                          tappable: false,
                          openBuilder: (_, __) => chatDestination,
                          closedBuilder: (context, openContainer) {
                            return InkWell(
                              onLongPress: () => _toggleSelected(c.convoId),
                              onTap: () async {
                                if (_selectionMode) {
                                  _toggleSelected(c.convoId);
                                  return;
                                }
                                final unlocked = await ensureSecurityScopeUnlocked(
                                  context: context,
                                  controller: controller,
                                  scope: SecurityLockScope.personal,
                                );
                                if (!unlocked || !context.mounted) {
                                  return;
                                }
                                openContainer();
                              },
                              child: ColoredBox(
                                color: selected
                                    ? Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer
                                          .withValues(alpha: 0.45)
                                    : Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 52,
                                        height: 52,
                                        child: _selectionMode
                                            ? AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                child: CircleAvatar(
                                                  radius: 26,
                                                  key: ValueKey<bool>(selected),
                                                  child: Icon(
                                                    selected
                                                        ? AppIcons.check
                                                        : AppIcons
                                                              .radioUnchecked,
                                                  ),
                                                ),
                                              )
                                            : isFavoritesChat
                                            ? CircleAvatar(
                                                radius: 26,
                                                backgroundColor:
                                                    const Color(0xFF0D5F38),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  child: SvgPicture.asset(
                                                    AppAssetPaths
                                                        .favoritesNotebookSvg,
                                                    colorFilter:
                                                        const ColorFilter.mode(
                                                      Colors.white,
                                                      BlendMode.srcIn,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : Builder(
                                                builder: (context) {
                                                  final ap = c.avatarPath;
                                                  final hasAvatar =
                                                      ap != null &&
                                                      ap.isNotEmpty &&
                                                      File(ap).existsSync();
                                                  if (hasAvatar) {
                                                    return CircleAvatar(
                                                      radius: 26,
                                                      backgroundImage:
                                                          FileImage(File(ap)),
                                                    );
                                                  }
                                                  final seed =
                                                      c.peerProfileId ??
                                                      c.convoId;
                                                  return CircleAvatar(
                                                    radius: 26,
                                                    backgroundColor:
                                                        AvatarInitials
                                                            .backgroundColor(
                                                              context,
                                                              seed: seed,
                                                            ),
                                                    // Значок комнаты — тем же
                                                    // цветом, что буквы.
                                                    foregroundColor:
                                                        AvatarInitials
                                                            .foregroundColor(
                                                              context,
                                                              seed: seed,
                                                            ),
                                                    child: isGroup
                                                        ? const Icon(
                                                            AppIcons
                                                                .groupOutline,
                                                          )
                                                        : Text(
                                                            AvatarInitials
                                                                .label(
                                                              displayName:
                                                                  c.title,
                                                              fallbackId: seed,
                                                            ),
                                                            style: Theme.of(
                                                              context,
                                                            ).textTheme.labelLarge?.copyWith(
                                                              color:
                                                                  AvatarInitials
                                                                      .foregroundColor(
                                                                        context,
                                                                        seed:
                                                                            seed,
                                                                      ),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                  );
                                                },
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
                                                padding:
                                                    const EdgeInsets.only(
                                                  top: 3,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        titleText,
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style:
                                                            const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    if (c.premiumBadge) ...[
                                                      const SizedBox(width: 5),
                                                      const Icon(
                                                        Icons.star_rounded,
                                                        size: 15,
                                                        color: Color(
                                                          0xFFE8A33D,
                                                        ),
                                                      ),
                                                    ],
                                                    if (c.emojiStatus != null &&
                                                        c
                                                            .emojiStatus!
                                                            .isNotEmpty) ...[
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        c.emojiStatus!,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ],
                                                    const SizedBox(width: 8),
                                                    _TimePill(
                                                      ms: c.lastEventAtMs,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                  bottom: 3,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: ChatListSubtitlePreview(
                                                        key: ValueKey<String>(
                                                          'personal-subtitle-${c.convoId}',
                                                        ),
                                                        controller: controller,
                                                        convoId: c.convoId,
                                                        // + per-convo preview
                                                        // epoch so edits (same
                                                        // createdAtMs) refresh.
                                                        previewVersion:
                                                            c.lastEventAtMs +
                                                            controller
                                                                .convoPreviewEpoch(
                                                                  c.convoId,
                                                                ),
                                                        subtitleFallback:
                                                            c.peerProfileId ??
                                                            c.convoId,
                                                      ),
                                                    ),
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
                        );
                      },
                    );
                  }

                  final topInset = MediaQuery.of(context).padding.top;
                  return Scaffold(
                    body: Stack(
                      children: [
                        // The list fills the screen and scrolls UNDER the
                        // floating header, giving the glass live content to
                        // refract (like the nav bar over the chats list).
                        Positioned.fill(
                          child: PopScope(
                            canPop: !_selectionMode,
                            onPopInvokedWithResult: (didPop, _) {
                              if (!didPop && _selectionMode) {
                                _clearSelection();
                              }
                            },
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (i) =>
                                  setState(() => _category = i),
                              children: [
                                listFor(personal),
                                listFor(archived),
                              ],
                            ),
                          ),
                        ),
                        // Floating header (island + glass segment) on top.
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              SizedBox(height: topInset + 8),
                              buildHeader(),
                              const CallReturnBanner(),
                            ],
                          ),
                        ),
                        if (controller.security.isLocked(SecurityLockScope.personal))
                          SecurityScopeLockOverlay(
                            controller: controller,
                            scope: SecurityLockScope.personal,
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
    );
  }
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

class _TimePill extends StatelessWidget {
  const _TimePill({required this.ms});

  final int ms;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.09)
            : Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _formatTime(ms),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark
              ? Colors.white.withValues(alpha: 0.45)
              : Colors.black.withValues(alpha: 0.38),
        ),
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
  return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}
