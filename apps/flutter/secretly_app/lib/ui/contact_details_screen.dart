// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'animations/animations.dart';
import 'icons/app_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/app_controller.dart';
import '../calls/call_failure.dart';
import '../calls/call_manager.dart';
import '../rooms/room_policy_failure.dart';
import 'app_asset_paths.dart';
import 'call_error_text.dart';
import 'call_history_screen.dart';
import 'chat_screen.dart';
import 'contact_share_sheet.dart';
import 'edit_contact_screen.dart';
import 'emoji/noto_status_emoji.dart';
import 'favorites_title.dart';
import 'fullscreen_image_viewer.dart';
import 'l10n.dart';
import 'premium/cosmetic_animation_scope.dart';
import 'premium/cosmetics_catalog.dart';
import 'report_abuse_sheet.dart';
import 'room_policy_error_text.dart';
import 'share_utils.dart';
import 'wave1_l10n.dart';
import 'widgets/app_background.dart';
import 'widgets/conversation_media_gallery.dart';
import 'widgets/secretly_glass_sheet.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/frosted_header_island.dart';
import 'widgets/frosted_top_bar.dart';
import 'widgets/broken_media_box.dart';

class ContactDetailsScreen extends StatefulWidget {
  const ContactDetailsScreen({
    super.key,
    required this.controller,
    required this.peerProfileId,
    this.convoId,
    this.initialTitle,
    this.initialAvatarPath,
    this.heroTag,
    this.openChatByPush = false,
  });

  final AppController controller;
  final String peerProfileId;
  final String? convoId;
  final String? initialTitle;
  final String? initialAvatarPath;
  final String? heroTag;

  /// When true (opened from a room member tap), the "Chat" action opens a real
  /// 1:1 conversation with [peerProfileId] instead of popping back — otherwise
  /// popping would return to the room this screen was opened from.
  final bool openChatByPush;

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen>
    with SingleTickerProviderStateMixin {
  static const String _favoritesNoteAssetPath =
      AppAssetPaths.favoritesNotebookSvg;
  final ScrollController _scrollController = ScrollController();
  bool _collapseGestureActive = false;
  double _pullExpand = 0;
  double _avatarPullPx = 0;
  double _avatarFullscreenPullPx = 0;
  bool _avatarWasFullyExpanded = false;
  bool _avatarViewerOpening = false;
  // 240px finger travel for a full open → the photo expands at half the finger
  // speed (2× slower / more gradual) than a 1:1 drag.
  static const double _avatarPullMaxPx = 240;
  static const double _avatarSnapThreshold = 0.45;
  static const double _avatarFullscreenPullThreshold = 28;
  late final AnimationController _pullSnapController;

  // Memoized profile VM (agent audit 2026-07-23). _loadVm() awaits several DB
  // reads + file-exists checks (and a network fetch for unknown peers); it used
  // to be recreated inline in build() by BOTH the header and body FutureBuilders
  // AND on every `changed` tick, churning queries right through the enter
  // transition. Cache the future, reload it throttled on `changed` so the
  // live "online"/last-seen still refreshes, and keep the last resolved VM so a
  // reload never flashes the shimmer.
  Future<_ContactDetailsVm>? _vmFuture;
  _ContactDetailsVm? _lastVm;
  int _vmReloadAtMs = 0;
  StreamSubscription<void>? _changedSub;
  static const int _vmReloadThrottleMs = 1500;
  Animation<double>? _pullSnapAnimation;

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
            _pullExpand = animation.value;
            _avatarPullPx = (_pullExpand * _avatarPullMaxPx).clamp(
              0.0,
              _avatarPullMaxPx,
            );
          });
          _updateAvatarPhotoFeedback();
        });
    _vmFuture = _loadVm();
    _changedSub = widget.controller.changed.listen((_) => _maybeReloadVm());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPeerProfileMeta();
    });
  }

  /// Reload the memoized VM at most once per [_vmReloadThrottleMs] so live
  /// presence still refreshes, without re-querying on every `changed` tick.
  void _maybeReloadVm() {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _vmReloadAtMs < _vmReloadThrottleMs) return;
    _vmReloadAtMs = now;
    setState(() {
      _vmFuture = _loadVm();
    });
  }

  Future<void> _refreshPeerProfileMeta() async {
    final peerProfileId = widget.peerProfileId.trim();
    if (peerProfileId.isEmpty) return;
    try {
      await widget.controller.refreshProfileMeta(peerProfileId);
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // Best-effort refresh only.
    }
  }

  @override
  void dispose() {
    _changedSub?.cancel();
    _scrollController.dispose();
    _pullSnapController.dispose();
    super.dispose();
  }

  void _stopPullSnap() {
    if (_pullSnapController.isAnimating) {
      _pullSnapController.stop();
    }
  }

  void _updateAvatarPhotoFeedback() {
    final fullyOpen = _pullExpand >= 0.995;
    final fullyClosed = _pullExpand <= 0.001;
    if (fullyOpen && !_avatarWasFullyExpanded) {
      _avatarWasFullyExpanded = true;
      unawaited(widget.controller.triggerUiHaptic());
      return;
    }
    if (fullyClosed && _avatarWasFullyExpanded) {
      _avatarWasFullyExpanded = false;
      unawaited(widget.controller.triggerUiHaptic());
    }
  }

  Future<void> _openAvatarFullScreen(String? avatarPath, String title) async {
    final existingPath = _existingAvatarPath(avatarPath);
    if (existingPath == null || _avatarViewerOpening) {
      return;
    }
    _avatarFullscreenPullPx = 0;
    _avatarViewerOpening = true;
    try {
      await openFullscreenImageViewer(
        context,
        imagePath: existingPath,
        title: title,
        heroTag: widget.heroTag,
      );
    } finally {
      _avatarViewerOpening = false;
    }
  }

  void _handleAvatarSurfaceDragUpdate(
    DragUpdateDetails details, {
    required String? avatarPath,
    required String title,
  }) {
    final delta = details.delta.dy;
    if (_pullExpand >= 0.995 && delta > 0) {
      _avatarFullscreenPullPx += delta;
      if (_avatarFullscreenPullPx >= _avatarFullscreenPullThreshold) {
        _avatarFullscreenPullPx = 0;
        unawaited(_openAvatarFullScreen(avatarPath, title));
        return;
      }
    } else {
      _avatarFullscreenPullPx = 0;
    }

    _stopPullSnap();
    setState(() {
      _avatarPullPx = (_avatarPullPx + delta).clamp(0.0, _avatarPullMaxPx);
      _pullExpand = (_avatarPullPx / _avatarPullMaxPx).clamp(0.0, 1.0);
    });
    _updateAvatarPhotoFeedback();
  }

  void _handleAvatarSurfaceDragEnd(DragEndDetails _) {
    _avatarFullscreenPullPx = 0;
    _animatePullTo(_pullExpand >= _avatarSnapThreshold ? 1.0 : 0.0);
  }

  void _animatePullTo(double target) {
    final clamped = target.clamp(0.0, 1.0);
    if ((_pullExpand - clamped).abs() < 0.001) {
      setState(() {
        _pullExpand = clamped;
        _avatarPullPx = (_pullExpand * _avatarPullMaxPx).clamp(
          0.0,
          _avatarPullMaxPx,
        );
      });
      _updateAvatarPhotoFeedback();
      return;
    }
    _stopPullSnap();
    _pullSnapAnimation = Tween<double>(begin: _pullExpand, end: clamped)
        .animate(
          CurvedAnimation(
            parent: _pullSnapController,
            curve: Curves.easeOutCubic,
          ),
        );
    _pullSnapController
      ..reset()
      ..forward();
  }

  void _handleCollapseDrag(DragUpdateDetails details) {
    _stopPullSnap();
    _collapseGestureActive = true;
    setState(() {
      _avatarPullPx = (_avatarPullPx + details.delta.dy).clamp(
        0.0,
        _avatarPullMaxPx,
      );
      _pullExpand = (_avatarPullPx / _avatarPullMaxPx).clamp(0.0, 1.0);
    });
    _updateAvatarPhotoFeedback();
  }

  void _handleCollapseDragEnd(DragEndDetails _) {
    _collapseGestureActive = false;
    _animatePullTo(_pullExpand >= _avatarSnapThreshold ? 1.0 : 0.0);
  }

  String? _existingAvatarPath(String? rawPath) {
    final path = rawPath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    try {
      final file = File(path);
      if (!file.existsSync() || file.lengthSync() <= 0) {
        return null;
      }
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _bestExistingAvatarPath(List<String?> rawPaths) async {
    final paths = <String>[];
    for (final rawPath in rawPaths) {
      final path = _existingAvatarPath(rawPath);
      if (path == null || paths.contains(path)) continue;
      paths.add(path);
    }
    if (paths.isEmpty) return null;

    String bestPath = paths.first;
    var bestPixels = -1;
    var bestBytes = -1;
    for (final path in paths) {
      final score = await _avatarFileScore(path);
      if (score == null) continue;
      if (score.pixels > bestPixels ||
          (score.pixels == bestPixels && score.bytes > bestBytes)) {
        bestPath = path;
        bestPixels = score.pixels;
        bestBytes = score.bytes;
      }
    }
    return bestPath;
  }

  Future<({int pixels, int bytes})?> _avatarFileScore(String path) async {
    try {
      final file = File(path);
      final byteCount = await file.length();
      final bytes = await file.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      final pixels = decoded.width * decoded.height;
      decoded.dispose();
      return (pixels: pixels, bytes: byteCount);
    } catch (_) {
      return null;
    }
  }

  bool _handleAvatarPull(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.depth != 0) return false;

    final atTop =
        notification.metrics.pixels <= 0.5 &&
        notification.metrics.extentBefore <= 0.5;

    if (notification is OverscrollNotification) {
      if (notification.dragDetails == null) return false;
      final delta = notification.overscroll;
      if (atTop && delta < 0) {
        _stopPullSnap();
        setState(() {
          _avatarPullPx = (_avatarPullPx + (-delta)).clamp(
            0.0,
            _avatarPullMaxPx,
          );
          _pullExpand = (_avatarPullPx / _avatarPullMaxPx).clamp(0.0, 1.0);
        });
        _updateAvatarPhotoFeedback();
      }
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null) return false;
      final delta = notification.scrollDelta ?? 0;
      if (atTop && delta < 0) {
        _stopPullSnap();
        setState(() {
          _avatarPullPx = (_avatarPullPx + (-delta)).clamp(
            0.0,
            _avatarPullMaxPx,
          );
          _pullExpand = (_avatarPullPx / _avatarPullMaxPx).clamp(0.0, 1.0);
        });
        _updateAvatarPhotoFeedback();
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      // Always settle to the nearest end on finger-up. dragDetails is usually
      // null here (the drag has already ended), so gating the snap on it left the
      // avatar frozen mid-zoom when released early.
      if (_avatarPullPx > 0.001) {
        _animatePullTo(_pullExpand >= _avatarSnapThreshold ? 1.0 : 0.0);
      }
      return false;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        // No full top bar — it cropped the cover/photo. Suppress frostedAppBar's
        // default FrostedTopBarBackground; back + more live in floating islands
        // so the cover/photo shows through behind them.
        flexibleSpace: const SizedBox.shrink(),
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        leading: Opacity(
          opacity: (1.0 - _pullExpand * 2.0).clamp(0.0, 1.0),
          child: Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
            child: FrostedHeaderIsland(
              radius: 24,
              height: 48,
              child: SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ),
        title:
            widget.controller.isSavedMessagesConvo(
              widget.convoId ?? widget.peerProfileId,
            )
            ? Opacity(
                opacity: (1.0 - _pullExpand * 2.0).clamp(0.0, 1.0),
                child: Text(localizedFavoritesTitle(context)),
              )
            : null,
        actions: [
          Opacity(
            opacity: (1.0 - _pullExpand * 2.0).clamp(0.0, 1.0),
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              child: FutureBuilder<_ContactDetailsVm>(
                future: _vmFuture,
                builder: (context, snap) {
                  final vm = snap.data;
                  if (vm?.isFavoritesConvo == true) {
                    return const SizedBox.shrink();
                  }
                  return FrostedHeaderIsland(
                    radius: 24,
                    height: 48,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: context.l10n.more,
                        onPressed: (vm == null || vm.isFavoritesConvo)
                            ? null
                            : () => _showFrostedMenu(vm),
                        icon: const Icon(AppIcons.moreVert, size: 23),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<void>(
        stream: widget.controller.changed,
        builder: (context, _) {
          return FutureBuilder<_ContactDetailsVm>(
            future: _loadVm(),
            builder: (context, infoSnap) {
              // Retain the last resolved VM so a throttled reload never drops
              // back to the shimmer while the fresh query is in flight.
              final vm = infoSnap.data ?? _lastVm;
              if (vm == null) {
                return const ShimmerContactDetails();
              }
              _lastVm = vm;

              final screen = MediaQuery.of(context).size;
              final safeTop = MediaQuery.of(context).padding.top;
              final screenW = screen.width;
              final expandedImageHeight = (screen.height * 0.52).clamp(
                320.0,
                520.0,
              );
              // Animated-hero geometry — IDENTICAL formulas to own-profile
              // (profile_screen.dart): avatar + name + status + buttons all
              // live in a single Stack(Clip.none) whose positions/sizes lerp
              // on _pullExpand (0 collapsed → 1 fully-expanded photo).
              final avatarSize = lerpDouble(112, screenW, _pullExpand)!;
              final avatarHeight = lerpDouble(
                112,
                expandedImageHeight,
                _pullExpand,
              )!;
              final avatarRadius = lerpDouble(56, 0, _pullExpand)!;
              final collapsedAvatarTop = safeTop + 8;
              const expandedAvatarTop = 0.0;
              final avatarTop = lerpDouble(
                collapsedAvatarTop,
                expandedAvatarTop,
                _pullExpand,
              )!;

              final collapsedNameTop = collapsedAvatarTop + 112 + 18;
              final expandedNameTop = expandedAvatarTop + avatarHeight - 126;
              final nameTop = lerpDouble(
                collapsedNameTop,
                expandedNameTop,
                _pullExpand,
              )!;

              final collapsedStatusTop = collapsedNameTop + 42;
              final expandedStatusTop = expandedNameTop + 38;
              final statusTop = lerpDouble(
                collapsedStatusTop,
                expandedStatusTop,
                _pullExpand,
              )!;

              final collapsedButtonsTop = collapsedStatusTop + 38;
              final expandedButtonsTop = expandedNameTop + 58;
              final buttonsTop = lerpDouble(
                collapsedButtonsTop,
                expandedButtonsTop,
                _pullExpand,
              )!;

              final collapsedHeroBottom = collapsedButtonsTop + 66 + 20;
              final expandedHeroBottom = expandedAvatarTop + avatarHeight + 18;
              final heroHeight = lerpDouble(
                collapsedHeroBottom,
                expandedHeroBottom,
                _pullExpand,
              )!;
              final titleScale = lerpDouble(1.0, 1.06, _pullExpand)!;
              final subtitleScale = lerpDouble(1.0, 1.04, _pullExpand)!;
              // 🔴 Раскрытая шапка без фото — это заливка заглушки, а в
              // светлой теме она почти белая: белые имя и статус по ней не
              // читались (1,3–1,6 : 1). Там они остаются цветом темы; над фото
              // и над тёмной заливкой белеют, как раньше (17.09.2026).
              final heroPhoto = vm.avatarPath;
              final heroOnLightFallback =
                  !vm.isFavoritesConvo &&
                  !(heroPhoto != null &&
                      heroPhoto.isNotEmpty &&
                      File(heroPhoto).existsSync()) &&
                  AvatarInitials.fillIsLight(
                    context,
                    seed: vm.profileId.trim().isNotEmpty
                        ? vm.profileId.trim()
                        : vm.title,
                  );
              final heroTextWhite = _pullExpand > 0.35 && !heroOnLightFallback;
              // Back/front cover split (black hole): the peer's photo must
              // sit INSIDE the scene exactly like on the own-profile page —
              // back layer under the photo, near disk edge drawn over it.
              final cover = vm.isFavoritesConvo
                  ? null
                  : coverBackWidgetFor(
                      vm.coverId,
                      customImagePath: vm.coverImagePath,
                    );
              final coverFront = vm.isFavoritesConvo
                  ? null
                  : coverFrontWidgetFor(
                      vm.coverId,
                      customImagePath: vm.coverImagePath,
                    );
              final frame = vm.isFavoritesConvo ? null : frameById(vm.frameId);

              final bottomInset = MediaQuery.of(context).padding.bottom;

              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate:
                    (_pullExpand >= 1.0 || _collapseGestureActive)
                    ? _handleCollapseDrag
                    : null,
                onVerticalDragEnd:
                    (_pullExpand >= 1.0 || _collapseGestureActive)
                    ? _handleCollapseDragEnd
                    : null,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleAvatarPull,
                  child: ListView(
                    controller: _scrollController,
                    physics: (_pullExpand >= 1.0 || _collapseGestureActive)
                        ? const NeverScrollableScrollPhysics()
                        // Match own-profile's smooth pull: explicit clamping +
                        // always-scrollable so overscroll at the top feeds the
                        // avatar-expand instead of the iOS gesture arena freezing
                        // the scroll mid-swipe.
                        : const ClampingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                    padding: EdgeInsets.only(top: 0, bottom: 12 + bottomInset),
                    children: [
                      if (vm.isFavoritesConvo) ...[
                        // Favorites: no cover/frame, no pull-expand photo —
                        // keep the simple static hero (a green notes card).
                        SizedBox(height: safeTop + kToolbarHeight + 8),
                        Center(
                          child: _LargeAvatar(
                            avatarPath: null,
                            fallbackTitle: localizedFavoritesTitle(context),
                            fallbackId: widget.peerProfileId,
                            isFavoritesConvo: true,
                            favoritesAssetPath: _favoritesNoteAssetPath,
                            width: 112,
                            height: 112,
                            borderRadius: 56,
                            fallbackIconSize: 42,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            localizedFavoritesTitle(context),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            wave1Text(
                              context,
                              ru: 'Ваши личные заметки',
                              en: 'Your personal notes',
                              uk: 'Ваші особисті нотатки',
                              es: 'Tus notas personales',
                              pt: 'Suas notas pessoais',
                              ptBr: 'Suas notas pessoais',
                              fr: 'Vos notes personnelles',
                              de: 'Ihre persönlichen Notizen',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!vm.isFavoritesConvo)
                        // ANIMATED HERO — mirrors own-profile exactly: a
                        // SizedBox(heroHeight) holding a Stack(Clip.none) of
                        // cover + decoupled scrim + Positioned-lerp avatar /
                        // frame / name / status / 4 action buttons. Pulling
                        // the avatar (or overscrolling the list) drives
                        // _pullExpand and the whole hero animates together.
                        SizedBox(
                          height: heroHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (cover != null) ...[
                                // 1) Cover image — bottom-aligned to the
                                //    buttons row; fades out as we pull-expand.
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: collapsedButtonsTop + 66,
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: (1.0 - _pullExpand * 2.0).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      // Showcase: the banner is the biggest thing on this page,
                                      // so it rasterises at full resolution here.
                                      child: CosmeticShowcaseScope(child: cover),
                                    ),
                                  ),
                                ),
                                // 2) Decoupled page-colour scrim — a SEPARATE
                                //    layer running DOWN PAST the cover (Clip.none
                                //    overflow) so the cover darkens into the page
                                //    colour cleanly with no bright bleed.
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: collapsedHeroBottom + 16,
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: (1.0 - _pullExpand * 2.0).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          // Theme-background scrim so the peer
                                          // cover blends on light + dark themes.
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            stops: const [0.55, 1.0],
                                            colors: [
                                              AppBackground.scrimColorOf(
                                                context,
                                              ).withValues(alpha: 0.0),
                                              AppBackground.scrimColorOf(
                                                context,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              Positioned(
                                top: avatarTop,
                                left: (screenW - avatarSize) / 2,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _openAvatarFullScreen(
                                    vm.avatarPath,
                                    vm.title,
                                  ),
                                  onVerticalDragUpdate: (details) =>
                                      _handleAvatarSurfaceDragUpdate(
                                        details,
                                        avatarPath: vm.avatarPath,
                                        title: vm.title,
                                      ),
                                  onVerticalDragEnd:
                                      _handleAvatarSurfaceDragEnd,
                                  child: _LargeAvatar(
                                    avatarPath: vm.avatarPath,
                                    fallbackTitle: vm.title,
                                    fallbackId: vm.profileId,
                                    heroTag: widget.heroTag,
                                    isFavoritesConvo: vm.isFavoritesConvo,
                                    favoritesAssetPath: _favoritesNoteAssetPath,
                                    width: avatarSize,
                                    height: avatarHeight,
                                    borderRadius: avatarRadius,
                                    fallbackIconSize: lerpDouble(
                                      42,
                                      88,
                                      _pullExpand,
                                    )!,
                                  ),
                                ),
                              ),
                              if (frame != null)
                                // Frame ring encircles the photo: box =
                                // photo/0.86 (matches FramedAvatar's gap).
                                Positioned(
                                  top:
                                      avatarTop +
                                      avatarHeight / 2 -
                                      (avatarSize / 0.86) / 2,
                                  left: (screenW - avatarSize / 0.86) / 2,
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: (1.0 - _pullExpand * 3.0).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      child: SizedBox(
                                        width: avatarSize / 0.86,
                                        height: avatarSize / 0.86,
                                        // Showcase: this one big avatar paints live from vectors —
                                  // full resolution and one frame per vsync,
                                  // instead of the list-sized baked texture.
                                  child: CosmeticShowcaseScope(
                                    child: frame.builder(avatarSize / 0.86),
                                  ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (coverFront != null)
                                // Foreground cover pass (black hole's near
                                // disk edge) OVER the peer's photo+frame —
                                // the avatar reads as sitting INSIDE the
                                // event horizon. Transparent where empty.
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: collapsedButtonsTop + 66,
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: (1.0 - _pullExpand * 2.0).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      child: coverFront,
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: nameTop,
                                left: 24,
                                right: 24,
                                child: Align(
                                  alignment: Alignment.lerp(
                                    Alignment.topCenter,
                                    Alignment.topLeft,
                                    _pullExpand,
                                  )!,
                                  child: Transform.scale(
                                    scale: titleScale,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            vm.title,
                                            textAlign: _pullExpand > 0.35
                                                ? TextAlign.left
                                                : TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: heroTextWhite
                                                      ? Colors.white
                                                      : null,
                                                ),
                                          ),
                                        ),
                                        // Order: name → emoji status → premium
                                        // star. The local contact emoji (vm.emoji)
                                        // is intentionally not shown here so there
                                        // is only ONE emoji (the synced status).
                                        if (vm.emojiStatus != null &&
                                            vm.emojiStatus!.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          // Rendered through the Noto catalog
                                          // so supported statuses animate and
                                          // unknown ones still draw an image
                                          // (fixes the Android tofu box). Hero
                                          // can afford the looping Lottie.
                                          NotoStatusEmoji(
                                            emoji: vm.emojiStatus!,
                                            size: 24,
                                          ),
                                        ],
                                        if (vm.premiumBadge) ...[
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 20,
                                            color: Color(0xFFE8A33D),
                                          ),
                                        ],
                                        if (vm.isVerified) ...[
                                          const SizedBox(width: 8),
                                          Icon(
                                            AppIcons.verified,
                                            color: Colors.green.shade500,
                                            size: 22,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: statusTop,
                                left: 24,
                                right: 24,
                                child: Align(
                                  alignment: Alignment.lerp(
                                    Alignment.topCenter,
                                    Alignment.topLeft,
                                    _pullExpand,
                                  )!,
                                  child: Transform.scale(
                                    scale: subtitleScale,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _statusText(
                                        context,
                                        vm.isOnline,
                                        vm.lastSeenAtMs,
                                      ),
                                      textAlign: _pullExpand > 0.35
                                          ? TextAlign.left
                                          : TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: heroTextWhite
                                                ? Colors.white.withValues(
                                                    alpha: 0.9,
                                                  )
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: buttonsTop,
                                left: 12,
                                right: 12,
                                // Four equal-width action chips (chat / sound /
                                // call / video) — same chips/onTaps as before,
                                // now animating with the hero.
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _ActionChip(
                                        icon: AppIcons.chatBubbleSolid,
                                        label: l10n.contactDetailsChat,
                                        onTap: () => _openChatAction(vm),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ActionChip(
                                        icon: AppIcons.bellSolid,
                                        label: l10n.contactDetailsSound,
                                        onTap:
                                            _showContactNotificationPrivacySheet,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ActionChip(
                                        icon: AppIcons.callSolid,
                                        label: l10n.contactDetailsCall,
                                        onTap: () => _startSecureCall(
                                          video: false,
                                          peerName: vm.title,
                                          peerAvatarPath: vm.avatarPath,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ActionChip(
                                        icon: AppIcons.videoSolid,
                                        label: l10n.contactDetailsVideo,
                                        onTap: () => _startSecureCall(
                                          video: true,
                                          peerName: vm.title,
                                          peerAvatarPath: vm.avatarPath,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!vm.isFavoritesConvo) ...[
                        // The "about" text dropped out of the static column
                        // and now lives just under the animated hero so it
                        // still scrolls with the rest of the page.
                        if (vm.aboutText != null &&
                            vm.aboutText!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Text(
                              vm.aboutText!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _InfoBlock(
                            children: [
                              _InfoRow(
                                icon: AppIcons.tag,
                                title: vm.usernameText,
                                subtitle: l10n.contactDetailsUsernameLabel,
                              ),
                              const Divider(height: 1),
                              _InfoRow(
                                icon: AppIcons.badge,
                                title: vm.profileId,
                                subtitle: l10n.secretlyIdLabel,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          shape: const CircleBorder(),
                                          padding: EdgeInsets.zero,
                                        ),
                                        onPressed: () => _shareContactId(vm),
                                        child: const Icon(
                                          Icons.share_outlined,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          shape: const CircleBorder(),
                                          padding: EdgeInsets.zero,
                                        ),
                                        onPressed: () => _copyContactId(vm),
                                        child: const Icon(
                                          Icons.copy_rounded,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              _InfoRow(
                                icon: AppIcons.call,
                                title: wave1Text(
                                  context,
                                  ru: 'История звонков',
                                  en: 'Call history',
                                  uk: 'Історія дзвінків',
                                  es: 'Historial de llamadas',
                                  pt: 'Historico de chamadas',
                                  ptBr: 'Historico de chamadas',
                                  fr: 'Historique des appels',
                                  de: 'Anrufverlauf',
                                ),
                                subtitle: wave1Text(
                                  context,
                                  ru: 'Все звонки с этим контактом',
                                  en: 'All calls with this contact',
                                  uk: 'Усі дзвінки з цим контактом',
                                  es: 'Todas las llamadas con este contacto',
                                  pt: 'Todas as chamadas com este contato',
                                  ptBr: 'Todas as chamadas com este contato',
                                  fr: 'Tous les appels avec ce contact',
                                  de: 'Alle Anrufe mit diesem Kontakt',
                                ),
                                trailing: const Icon(AppIcons.chevronRight),
                                onTap: () {
                                  Navigator.of(context).push(
                                    SecretlyPageRoute(
                                      builder: (_) => CallHistoryScreen(
                                        controller: widget.controller,
                                        convoId:
                                            widget.convoId ??
                                            widget.peerProfileId,
                                        peerProfileId: widget.peerProfileId,
                                        title: vm.title,
                                        avatarPath: vm.avatarPath,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: FutureBuilder<bool>(
                            future: widget.controller.isContactCallsAllowed(
                              widget.peerProfileId,
                            ),
                            builder: (context, permissionSnap) {
                              final allowed = permissionSnap.data ?? true;
                              return _InfoBlock(
                                children: [
                                  SwitchListTile.adaptive(
                                    value: allowed,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    title: Text(
                                      wave1Text(
                                        context,
                                        ru: 'Разрешить звонки',
                                        en: 'Allow calls',
                                        uk: 'Дозволити дзвінки',
                                        es: 'Permitir llamadas',
                                        pt: 'Permitir chamadas',
                                        ptBr: 'Permitir chamadas',
                                        fr: 'Autoriser les appels',
                                        de: 'Anrufe erlauben',
                                      ),
                                    ),
                                    subtitle: Text(
                                      wave1Text(
                                        context,
                                        ru: 'Индивидуальное разрешение на звонки для этого контакта',
                                        en: 'Per-contact call permission',
                                        uk: 'Індивідуальний дозвіл на дзвінки для цього контакту',
                                        es: 'Permiso de llamadas para este contacto',
                                        pt: 'Permissao de chamadas para este contato',
                                        ptBr:
                                            'Permissao de chamadas para este contato',
                                        fr: 'Autorisation d appels pour ce contact',
                                        de: 'Anrufberechtigung fur diesen Kontakt',
                                      ),
                                    ),
                                    onChanged: (v) => widget.controller
                                        .setContactCallsAllowed(
                                          profileId: widget.peerProfileId,
                                          allowed: v,
                                        ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                      if (!vm.isFavoritesConvo && !vm.isContact) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _InfoBlock(
                            children: [
                              ListTile(
                                leading: const Icon(AppIcons.personAdd),
                                title: Text(l10n.contactDetailsAddToContacts),
                                onTap: () async {
                                  await widget.controller.addContact(
                                    profileId: widget.peerProfileId,
                                    displayName: vm.title,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      // The SHARED gallery — the same widget the room
                      // profile and the chat's "Media and files" sheet use.
                      // This screen used to carry its own copy of the loader,
                      // the grid and the file list, so every improvement had
                      // to be written twice; the copy had silently fallen
                      // behind, opening photos in a bare dialog and ignoring
                      // taps on video outright.
                      ConversationMediaGallerySection(
                        controller: widget.controller,
                        convoId: vm.resolvedConvoId,
                        title: vm.title,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<_ContactDetailsVm> _loadVm() async {
    final contacts = await widget.controller.listContacts();
    final contact = contacts
        .where((c) => c.profileId == widget.peerProfileId)
        .cast<Contact?>()
        .firstOrNull;

    final convos = await widget.controller.listConversations();
    Conversation? convo;
    if (widget.convoId != null && widget.convoId!.isNotEmpty) {
      convo = convos
          .where((c) => c.convoId == widget.convoId)
          .cast<Conversation?>()
          .firstOrNull;
    }
    convo ??= convos
        .where((c) => c.convoId == widget.peerProfileId)
        .cast<Conversation?>()
        .firstOrNull;
    convo ??= convos
        .where((c) => c.convoId == 'req:${widget.peerProfileId}')
        .cast<Conversation?>()
        .firstOrNull;

    // Prefer the RAW stored display name. widget.initialTitle is only a
    // pre-load hint and may carry a trailing emoji-status / premium glyph (the
    // chat list & header append the synced emoji to the displayed title) —
    // using it as the title would double up with the emoji-status widget shown
    // next to the name. Fall back to the hint only when nothing else is known.
    String? title;
    final loadedName = contact?.displayName?.trim();
    if (loadedName != null && loadedName.isNotEmpty) {
      title = loadedName;
    }
    final convoTitle = convo?.title.trim();
    if (title == null && convoTitle != null && convoTitle.isNotEmpty) {
      title = convoTitle;
    }
    final hintTitle = widget.initialTitle?.trim();
    if (title == null && hintTitle != null && hintTitle.isNotEmpty) {
      title = hintTitle;
    }
    // Unknown peer (e.g. a room member not in contacts): their published
    // profile was never fetched, so the only "name" we have is the raw id.
    // Pull it from the keys server once and re-resolve so the profile opens
    // with a real name instead of the id.
    if (contact == null &&
        (title == null ||
            title.trim().isEmpty ||
            title.trim() == widget.peerProfileId)) {
      try {
        await widget.controller.refreshProfileMeta(widget.peerProfileId);
        final fetched = (await widget.controller.resolveConvoTitle(
          widget.peerProfileId,
        )).trim();
        if (fetched.isNotEmpty && fetched != widget.peerProfileId) {
          title = fetched;
        }
      } catch (_) {
        // best-effort; fall back to the id below
      }
    }
    if (title == null || title.trim().isEmpty) {
      title = widget.peerProfileId;
    }

    final publishedAvatarPath = await widget.controller
        .cachedPublishedProfileAvatarPath(widget.peerProfileId);
    final cachedAvatarPath = await widget.controller.cachedProfileAvatarPath(
      widget.peerProfileId,
    );
    final avatarPath = await _bestExistingAvatarPath([
      publishedAvatarPath,
      widget.initialAvatarPath,
      contact?.avatarPath,
      convo?.avatarPath,
      cachedAvatarPath,
    ]);

    final devices = await widget.controller.listContactDevices(
      widget.peerProfileId,
    );
    final verified =
        devices.isNotEmpty && devices.every((d) => d.verifiedAtMs != null);

    final displayForUsername =
        (contact?.displayName?.trim().isNotEmpty ?? false)
        ? contact!.displayName!.trim()
        : title;

    final username = displayForUsername
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final aboutText = await widget.controller.cachedProfileBio(
      widget.peerProfileId,
    );

    return _ContactDetailsVm(
      profileId: widget.peerProfileId,
      title: title,
      avatarPath: avatarPath,
      aboutText: aboutText,
      isVerified: verified,
      isBlocked: await widget.controller.isProfileBlocked(widget.peerProfileId),
      isContact: contact != null,
      isOnline: convo?.isOnline ?? false,
      lastSeenAtMs: convo?.peerLastSeenAtMs,
      usernameText: username.isEmpty
          ? '@${widget.peerProfileId.substring(0, 8)}'
          : '@$username',
      resolvedConvoId:
          (convo?.convoId ?? widget.convoId ?? widget.peerProfileId),
      autoDeleteSeconds: convo?.autoDeleteSeconds,
      emoji: contact?.emoji,
      isFavoritesConvo: widget.controller.isSavedMessagesConvo(
        convo?.convoId ?? widget.convoId ?? '',
      ),
      frameId: contact?.frameId,
      coverId: contact?.coverId,
      coverImagePath: contact?.coverImagePath,
      emojiStatus: contact?.emojiStatus,
      premiumBadge: contact?.premiumBadge ?? false,
    );
  }

  String _statusText(BuildContext context, bool isOnline, int? lastSeenAtMs) {
    final l10n = context.l10n;
    if (isOnline) return l10n.onlineStatus;
    if (lastSeenAtMs == null || lastSeenAtMs <= 0) {
      return l10n.contactDetailsStatusRecently;
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(lastSeenAtMs);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return l10n.contactDetailsStatusAt('$hh:$mm');
  }

  /// "Chat" action. From a 1:1 this screen sits on top of the peer's chat, so
  /// popping returns to it. From a room member tap ([openChatByPush]) there is
  /// no such chat behind us — open a real 1:1 with this person instead of
  /// popping back into the room.
  void _openChatAction(_ContactDetailsVm vm) {
    if (!widget.openChatByPush) {
      Navigator.of(context).pop();
      return;
    }
    final pid = widget.peerProfileId.trim();
    if (pid.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      SecretlyPageRoute(
        builder: (_) => ChatScreen(
          controller: widget.controller,
          convoId: pid,
          title: vm.title,
          peerProfileIdForSend: pid,
        ),
      ),
    );
  }

  Future<void> _copyContactId(_ContactDetailsVm vm) async {
    final id = vm.profileId.trim();
    if (id.isEmpty || id == 'unknown') return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    final msg = wave1Text(
      context,
      ru: 'ID скопирован',
      en: 'ID copied',
      uk: 'ID скопійовано',
      es: 'ID copiado',
      pt: 'ID copiado',
      ptBr: 'ID copiado',
      fr: 'ID copié',
      de: 'ID kopiert',
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SecretlySnackBar(content: Text(msg)));
  }

  Future<void> _shareContactId(_ContactDetailsVm vm) async {
    final id = vm.profileId.trim();
    if (id.isEmpty || id == 'unknown') return;
    final text = buildProfileShareText(
      profileId: id,
      isRu: wave1LocaleIsRussian(context),
      displayName: vm.title,
    );
    await shareTextExternally(text: text);
  }

  Future<void> _openContactShareSheet(_ContactDetailsVm vm) async {
    final action = await showContactShareSheet(
      context,
      controller: widget.controller,
      profileId: widget.peerProfileId,
      title: vm.title,
      avatarPath: vm.avatarPath,
    );
    if (!mounted || action == null) return;

    final shareText = buildProfileShareText(
      profileId: widget.peerProfileId,
      isRu: wave1LocaleIsRussian(context),
      displayName: vm.title,
    );

    if (action.externalShare) {
      await shareTextExternally(text: shareText);
      return;
    }

    final conversation = action.conversation;
    if (conversation == null) return;
    await _sendSharedContactToConversation(conversation, shareText: shareText);
  }

  Future<void> _sendSharedContactToConversation(
    Conversation conversation, {
    required String shareText,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (conversation.convoId.startsWith('group:')) {
        await widget.controller.sendGroupMessage(
          groupId: conversation.convoId,
          text: shareText,
        );
      } else {
        final rawProfileId =
            (conversation.peerProfileId ?? conversation.convoId).trim();
        final peerProfileId = rawProfileId.startsWith('req:')
            ? rawProfileId.substring(4)
            : rawProfileId;
        if (peerProfileId.isEmpty) {
          throw StateError('Missing peer profile id');
        }
        await widget.controller.sendMessage(
          peerProfileId: peerProfileId,
          text: shareText,
        );
      }

      if (!mounted) return;
      final sentLabel = wave1Text(
        context,
        ru: 'Контакт отправлен в ${conversation.title}',
        en: 'Contact sent to ${conversation.title}',
        uk: 'Контакт надіслано в ${conversation.title}',
        es: 'Contacto enviado a ${conversation.title}',
        pt: 'Contato enviado para ${conversation.title}',
        ptBr: 'Contato enviado para ${conversation.title}',
        fr: 'Contact envoyé à ${conversation.title}',
        de: 'Kontakt an ${conversation.title} gesendet',
      );
      messenger
        ..clearSnackBars()
        ..showSnackBar(SecretlySnackBar(content: Text(sentLabel)));
    } on RoomPolicyFailure catch (error) {
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SecretlySnackBar(
            content: Text(roomPolicyErrorText(context.l10n, error)),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SecretlySnackBar(
            content: Text(context.l10n.sendFailed(error.toString())),
          ),
        );
    }
  }

  String _notificationPrivacyLevelLabel(BuildContext context, int level) {
    switch (level.clamp(0, 2)) {
      case 0:
        return wave1Text(
          context,
          ru: 'Скрыто',
          en: 'Hidden',
          uk: 'Приховано',
          es: 'Oculto',
          pt: 'Oculto',
          fr: 'Masqué',
          de: 'Verborgen',
        );
      case 1:
        return wave1Text(
          context,
          ru: 'Только отправитель',
          en: 'Sender only',
          uk: 'Лише відправник',
          es: 'Solo remitente',
          pt: 'Apenas remetente',
          fr: 'Expéditeur uniquement',
          de: 'Nur Absender',
        );
      default:
        return wave1Text(
          context,
          ru: 'Отправитель и текст',
          en: 'Sender + message',
          uk: 'Відправник і текст',
          es: 'Remitente y mensaje',
          pt: 'Remetente e mensagem',
          fr: 'Expéditeur et message',
          de: 'Absender und Nachricht',
        );
    }
  }

  Future<void> _showContactNotificationPrivacySheet() async {
    final sheetTitle = wave1Text(
      context,
      ru: 'Уведомления контакта',
      en: 'Contact notifications',
      uk: 'Сповіщення контакту',
      es: 'Notificaciones del contacto',
      pt: 'Notificacoes do contato',
      ptBr: 'Notificacoes do contato',
      fr: 'Notifications du contact',
      de: 'Kontaktbenachrichtigungen',
    );
    final globalDefaultLabel = wave1Text(
      context,
      ru: 'По умолчанию',
      en: 'Use global default',
      uk: 'За замовчуванням',
      es: 'Usar valor global',
      pt: 'Usar padrao global',
      ptBr: 'Usar padrao global',
      fr: 'Utiliser le réglage global',
      de: 'Globale Vorgabe verwenden',
    );
    final globalSettingsAppliedText = wave1Text(
      context,
      ru: 'Применены глобальные настройки',
      en: 'Using global notification privacy',
      uk: 'Застосовано глобальні налаштування',
      es: 'Usando la privacidad global de notificaciones',
      pt: 'Usando privacidade global de notificacoes',
      ptBr: 'Usando privacidade global de notificacoes',
      fr: 'Confidentialité globale des notifications utilisée',
      de: 'Globale Benachrichtigungsoptionen werden verwendet',
    );
    final notificationPrivacyUpdatedText = wave1Text(
      context,
      ru: 'Настройка уведомлений сохранена',
      en: 'Notification privacy updated',
      uk: 'Налаштування сповіщень збережено',
      es: 'Privacidad de notificaciones actualizada',
      pt: 'Privacidade das notificacoes atualizada',
      ptBr: 'Privacidade das notificacoes atualizada',
      fr: 'Confidentialité des notifications mise à jour',
      de: 'Benachrichtigungsschutz aktualisiert',
    );
    // Source of truth is the per-conversation override (for a 1:1 the
    // conversation id IS the peer profile id), shared with the in-chat
    // notifications menu so both screens — and the notification code — agree.
    final currentOverride = await widget.controller
        .getChatNotificationPrivacyOverride(widget.peerProfileId.trim());
    if (!mounted) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        const options = <int>[0, 1, 2];
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: SecretlyGlassSheetSurface(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: SecretlyGlassSheetHandle()),
                    const SizedBox(height: 14),
                    Text(
                      sheetTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final option in options)
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          _notificationPrivacyLevelLabel(context, option),
                        ),
                        trailing: currentOverride == option
                            ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(option),
                      ),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: const Icon(AppIcons.refresh),
                      title: Text(globalDefaultLabel),
                      trailing: currentOverride == null
                          ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(-1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    // selected < 0 → clear the override (fall back to the global default).
    await widget.controller.setChatNotificationPrivacyOverride(
      widget.peerProfileId.trim(),
      selected < 0 ? null : selected.clamp(0, 2).toInt(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(
        content: Text(
          selected < 0
              ? globalSettingsAppliedText
              : notificationPrivacyUpdatedText,
        ),
      ),
    );
  }

  Future<void> _startSecureCall({
    required bool video,
    required String peerName,
    String? peerAvatarPath,
  }) async {
    final cm = CallManager.instance;
    if (cm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            callErrorText(
              context.l10n,
              CallFailure(CallFailureCode.serviceUnavailable),
            ),
          ),
        ),
      );
      return;
    }
    if (cm.state.value.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            callErrorText(
              context.l10n,
              CallFailure(CallFailureCode.alreadyInProgress),
            ),
          ),
        ),
      );
      return;
    }
    try {
      await cm.startCall(
        peerProfileId: widget.peerProfileId,
        peerName: peerName.isNotEmpty ? peerName : widget.peerProfileId,
        peerAvatarPath: peerAvatarPath,
        video: video,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(content: Text(callErrorText(context.l10n, e))),
      );
    }
  }

  Future<void> _showFrostedMenu(_ContactDetailsVm vm) async {
    final selected = await showFrostedPopup<String>(
      context: context,
      alignment: Alignment.topRight,
      builder: (context) {
        final l10n = context.l10n;
        final topPad = MediaQuery.of(context).padding.top + kToolbarHeight - 8;
        final cs = Theme.of(context).colorScheme;

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: topPad,
                right: 12,
                child: FrostedPopupContainer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 210,
                      maxWidth: 250,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _menuItem(
                          context,
                          value: 'share',
                          icon: AppIcons.reply,
                          title: l10n.contactDetailsShareContact,
                        ),
                        _menuItem(
                          context,
                          value: 'autodelete',
                          icon: AppIcons.timer,
                          title: l10n.contactDetailsAutoDelete,
                          trailing: const Icon(AppIcons.chevronRight, size: 20),
                        ),
                        _menuItem(
                          context,
                          value: 'block',
                          icon: AppIcons.block,
                          title: vm.isBlocked ? l10n.unblock : l10n.block,
                        ),
                        _menuItem(
                          context,
                          value: 'report',
                          icon: AppIcons.errorOutline,
                          title: reportAbuseMenuLabel(context),
                          iconColor: cs.error,
                          textColor: cs.error,
                        ),
                        _menuItem(
                          context,
                          value: 'edit',
                          icon: AppIcons.edit,
                          title: l10n.contactDetailsEditContact,
                        ),
                        if (vm.isContact)
                          _menuItem(
                            context,
                            value: 'delete',
                            icon: AppIcons.delete,
                            title: l10n.contactDetailsDeleteContact,
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

    if (selected == null || !mounted) return;

    switch (selected) {
      case 'share':
        await _openContactShareSheet(vm);
        return;
      case 'autodelete':
        await _showAutoDeleteDialog(vm);
        return;
      case 'block':
        await widget.controller.setProfileBlocked(
          profileId: widget.peerProfileId,
          blocked: !vm.isBlocked,
          deleteChatHistory: false,
        );
        if (mounted) setState(() {});
        return;
      case 'report':
        await _reportContact(vm);
        return;
      case 'edit':
        final changed = await Navigator.of(context).push<bool>(
          SecretlyPageRoute(
            builder: (_) => EditContactScreen(
              controller: widget.controller,
              profileId: widget.peerProfileId,
              initialName: vm.title,
              initialEmoji: vm.emoji,
              initialAvatarPath: vm.avatarPath,
            ),
          ),
        );
        if (changed == true && mounted) setState(() {});
        return;
      case 'delete':
        await _deleteContact(vm);
        return;
    }
  }

  Future<void> _reportContact(_ContactDetailsVm vm) async {
    final result = await showReportAbuseSheet(
      context: context,
      target: ReportAbuseTarget(
        type: ReportAbuseTargetType.profile,
        id: widget.peerProfileId,
        title: vm.title,
        conversationId: vm.resolvedConvoId,
      ),
      buildMarker: widget.controller.buildMarker,
      reporterDeviceId: widget.controller.deviceId,
      reporterProfileId: widget.controller.profileId,
      additionalTechnicalLines:
          widget.controller.pushRegistrationTechnicalLines,
      allowBlockTarget: true,
      targetAlreadyBlocked: vm.isBlocked,
    );
    if (!mounted || result == null) return;

    if (result.blockTarget && !vm.isBlocked) {
      await widget.controller.setProfileBlocked(
        profileId: widget.peerProfileId,
        blocked: true,
        deleteChatHistory: false,
      );
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(
        content: Text(reportAbuseDeliveryMessage(context, result)),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required String value,
    required IconData icon,
    required String title,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: iconColor ?? cs.onSurface.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Future<void> _deleteContact(_ContactDetailsVm vm) async {
    if (!vm.isContact) return;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.contactDetailsDeleteConfirmTitle),
          content: Text(widget.peerProfileId),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.deleteContact),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await widget.controller.deleteContact(profileId: widget.peerProfileId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showAutoDeleteDialog(_ContactDetailsVm vm) async {
    final l10n = context.l10n;
    final options = <({int? secs, String label})>[
      (secs: null, label: l10n.contactAutoDeleteOff),
      (secs: 24 * 60 * 60, label: l10n.contactAutoDelete1Day),
      (secs: 7 * 24 * 60 * 60, label: l10n.contactAutoDelete7Days),
      (secs: 30 * 24 * 60 * 60, label: l10n.contactAutoDelete30Days),
    ];

    final selected = await showDialog<int?>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(l10n.contactDetailsAutoDelete),
          children: [
            for (final opt in options)
              ListTile(
                leading: Icon(
                  vm.autoDeleteSeconds == opt.secs
                      ? AppIcons.radioChecked
                      : AppIcons.radioUnchecked,
                ),
                title: Text(opt.label),
                onTap: () => Navigator.of(context).pop(opt.secs),
              ),
          ],
        );
      },
    );

    if (selected == vm.autoDeleteSeconds) return;
    await widget.controller.setChatAutoDeleteSeconds(
      convoId: vm.resolvedConvoId,
      autoDeleteSeconds: selected,
    );
    if (!mounted) return;
    setState(() {});
  }
}

class _ContactDetailsVm {
  const _ContactDetailsVm({
    required this.profileId,
    required this.title,
    required this.avatarPath,
    required this.aboutText,
    required this.isVerified,
    required this.isBlocked,
    required this.isContact,
    required this.isOnline,
    required this.lastSeenAtMs,
    required this.usernameText,
    required this.resolvedConvoId,
    required this.autoDeleteSeconds,
    required this.emoji,
    required this.isFavoritesConvo,
    this.frameId,
    this.coverId,
    this.coverImagePath,
    this.emojiStatus,
    this.premiumBadge = false,
  });

  final String profileId;
  final String title;
  final String? avatarPath;
  final String? aboutText;
  final bool isVerified;
  final bool isBlocked;
  final bool isContact;
  final bool isOnline;
  final int? lastSeenAtMs;
  final String usernameText;
  final String resolvedConvoId;
  final int? autoDeleteSeconds;
  final String? emoji;
  final bool isFavoritesConvo;

  /// Peer's premium emoji status (cosmetic, from profile_meta).
  final String? emojiStatus;

  /// Whether the peer has a genuine paid tier (premium_badge).
  final bool premiumBadge;

  /// Peer's premium animated frame/cover ids (cosmetic, from profile_meta).
  final String? frameId;
  final String? coverId;

  /// Peer's custom cover image (cached file) when coverId == 'custom'.
  final String? coverImagePath;
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({
    required this.avatarPath,
    required this.fallbackTitle,
    this.fallbackId,
    this.heroTag,
    required this.isFavoritesConvo,
    required this.favoritesAssetPath,
    this.width = 112,
    this.height = 112,
    this.borderRadius = 56,
    this.fallbackIconSize = 42,
  });

  final String? avatarPath;
  final String fallbackTitle;
  final String? fallbackId;
  final String? heroTag;
  final bool isFavoritesConvo;
  final String favoritesAssetPath;
  final double width;
  final double height;
  final double borderRadius;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final p = avatarPath;
    final has = p != null && p.isNotEmpty && File(p).existsSync();
    final cs = Theme.of(context).colorScheme;
    // Decode the peer photo at DISPLAY resolution, not its native size. This
    // avatar lerps up to the full screen width on pull-expand, and a 2000×2000
    // source decoded at full res hitched the whole profile-enter transition
    // (agent audit 2026-07-23). cacheWidth/Height cap the decode to the box in
    // physical pixels — the image is shown at that size anyway, so it is
    // pixel-for-pixel identical on screen, just far cheaper to rasterize.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeW = (width * dpr).round().clamp(1, 4096);
    final decodeH = (height * dpr).round().clamp(1, 4096);
    final seed = (fallbackId ?? '').trim().isNotEmpty
        ? fallbackId!.trim()
        : fallbackTitle;
    // Заглушка — в общих с компьютером цветах: приглушённая заливка оттенка и
    // цветные буквы (17.09.2026).
    final fallback = AvatarInitials.colors(context, seed: seed);
    final fallbackFg = fallback.ink;
    final initials = AvatarInitials.label(
      displayName: fallbackTitle,
      fallbackId: fallbackId,
    );
    Widget avatar = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: has ? cs.surfaceContainerHighest : fallback.fill,
      ),
      clipBehavior: Clip.antiAlias,
      child: isFavoritesConvo
          ? ColoredBox(
              color: const Color(0xFF0D5F38),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: SvgPicture.asset(
                  favoritesAssetPath,
                  fit: BoxFit.contain,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            )
          : has
          ? Image.file(
              File(p),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 28, rounded: true),
              cacheWidth: decodeW,
              cacheHeight: decodeH,
            )
          : Center(
              child: Text(
                initials,
                maxLines: 1,
                style: TextStyle(
                  color: fallbackFg,
                  fontSize: fallbackIconSize * 0.62,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
    );
    if (heroTag != null) {
      avatar = Hero(tag: heroTag!, child: avatar);
    }
    return avatar;
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Matches own-profile's _circleAction (profile_screen.dart): frosted glass
    // island, icon + label tinted with colorScheme.onSurface (theme-aware,
    // not hard white). Horizontal padding kept at 8 so four chips fit a row
    // without overflow; other metrics (radius 18, icon 22, w600) match own.
    return FrostedHeaderIsland(
      radius: 18,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: cs.onSurface),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
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

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? cs.surfaceContainerHigh,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary.withValues(alpha: 0.9)),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
