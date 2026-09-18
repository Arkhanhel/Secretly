// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../app/app_controller.dart' show ChatEvent;
import '../../media/video_thumbnail_cache.dart';
import '../../models/e2e_payload_v1.dart';
import '../chat_screen_l10n.dart';
import '../icons/app_icons.dart';
import '../l10n.dart';
import 'full_bleed_zoom.dart';
import 'broken_media_box.dart';

bool _isVideoMediaMime(String mime) =>
    mime.trim().toLowerCase().startsWith('video/');

/// Fullscreen media viewer — swipe paging, zoom, drag-to-dismiss, mixed
/// photo/video, a glass top bar, a filmstrip and a grid picker.
///
/// Extracted from chat_screen.dart so screens OTHER than the chat (the profile
/// and room mini-galleries) get the same viewer instead of a bare
/// showDialog+InteractiveViewer. It deliberately knows nothing about the chat:
/// the timeline entry it used to carry is gone, every action is an optional
/// callback, and the filmstrip thumbnail is injected — the chat renders video
/// frames with a live player surface, which a 120-cell gallery grid cannot
/// afford.

class MediaViewerItem {
  const MediaViewerItem({
    required this.event,
    required this.attachment,
  });

  final ChatEvent event;
  final AttachmentEventV1 attachment;

  String? get payloadEventId => event.payloadEventId;
}

enum MediaViewerMenuAction {
  saveToGallery,
  showAllMedia,
  showInChat,
  reply,
  share,
  delete,
}

class MediaViewerDialog extends StatefulWidget {
  const MediaViewerDialog({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.chatTitle,
    required this.loadImageFile,
    required this.thumbnailBuilder,
    this.onForward,
    this.onReply,
    this.onSaveToGallery,
    this.onShare,
    this.onDelete,
    this.onShowInChat,
  });

  final List<MediaViewerItem> items;
  final int initialIndex;
  final String chatTitle;
  final Future<File> Function(AttachmentEventV1 attachment) loadImageFile;

  /// Every action is optional: a profile gallery supports fewer of them than
  /// the chat does (there is nothing to reply to outside a chat), and the menu
  /// hides whatever is null rather than offering a dead entry.
  ///
  /// Builds a thumbnail for the filmstrip / grid picker. Injected because the
  /// chat renders video frames with a live (expensive) player surface, while a
  /// profile gallery must use a cheap cached still — the viewer must not care
  /// which, and must not drag the chat's widget along.
  final Widget Function(
    BuildContext context,
    File? file,
    String mime, {
    bool forStrip,
  })
  thumbnailBuilder;
  final Future<void> Function(MediaViewerItem item)? onForward;
  final Future<void> Function(MediaViewerItem item)? onReply;
  final Future<void> Function(MediaViewerItem item)? onSaveToGallery;
  final Future<void> Function(MediaViewerItem item)? onShare;
  final Future<void> Function(MediaViewerItem item)? onDelete;
  final Future<void> Function(MediaViewerItem item)? onShowInChat;

  @override
  State<MediaViewerDialog> createState() =>
      MediaViewerDialogState();
}

class MediaViewerDialogState extends State<MediaViewerDialog> {
  late final PageController _controller;
  late int _currentIndex;
  bool _chromeVisible = true;
  final Map<int, Future<File>> _imageFutures = {};

  /// Per-page zoom controllers — used to read the active page's scale so the
  /// swipe-to-dismiss is disabled while an image is zoomed in (otherwise a
  /// vertical pan to look around would dismiss the viewer).
  final Map<int, TransformationController> _zoomControllers = {};

  /// Vertical-drag-to-dismiss offset (ported from [FullscreenImageViewerScreen]).
  double _dragOffsetY = 0;

  /// PINCH FIX (2026-07-17): number of touch pointers currently down on the
  /// pager. With two+ fingers the page-swipe physics and the vertical
  /// drag-to-dismiss hand the arena to InteractiveViewer's scale gesture —
  /// pinch-to-zoom used to lose to both nearly every time.
  int _activePointers = 0;

  bool get _pinchActive => _activePointers >= 2;

  void _handlePointerDown(PointerDownEvent _) {
    _activePointers++;
    if (_activePointers == 2) setState(() {});
  }

  void _handlePointerUpOrCancel() {
    if (_activePointers > 0) _activePointers--;
    if (_activePointers <= 1) setState(() {});
  }

  MediaViewerItem get _currentItem => widget.items[_currentIndex];

  TransformationController _zoomControllerAt(int index) {
    return _zoomControllers.putIfAbsent(index, TransformationController.new);
  }

  double get _currentScale =>
      _zoomControllers[_currentIndex]?.value.getMaxScaleOnAxis() ?? 1.0;

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_currentScale > 1.02) return;
    setState(() {
      _dragOffsetY = (_dragOffsetY + details.delta.dy).clamp(-220.0, 220.0);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_currentScale > 1.02) {
      if (_dragOffsetY != 0) setState(() => _dragOffsetY = 0);
      return;
    }
    final shouldClose =
        _dragOffsetY.abs() > 96 || (details.primaryVelocity?.abs() ?? 0) > 920;
    if (shouldClose) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _dragOffsetY = 0);
  }

  Future<File> _imageFutureAt(int index) {
    return _imageFutures.putIfAbsent(
      index,
      () => widget.loadImageFile(widget.items[index].attachment),
    );
  }

  // MEDIA-VIEWER CAROUSEL (2026-07-16): the bottom filmstrip is a centered
  // carousel — the active item sits in the middle of the screen, neighbours
  // fan out left/right, and each thumb keeps the TRUE aspect ratio of its
  // media (resolved lazily from the photo file / cached video poster).
  final ScrollController _stripController = ScrollController();
  final Map<int, double> _stripAspectByIndex = {};
  final Set<int> _stripAspectRequested = {};

  /// Video controller of the ACTIVE page (registered by the page itself once
  /// initialized) — drives the seek timeline under the carousel. Null while a
  /// photo is open.
  VideoPlayerController? _activeVideoController;

  static const double _stripThumbHeight = 38;
  static const double _stripThumbGap = 6;
  static const double _stripMinAspect = 0.6;
  static const double _stripMaxAspect = 1.8;

  double _stripThumbWidth(int index) {
    final aspect = (_stripAspectByIndex[index] ?? 1.0).clamp(
      _stripMinAspect,
      _stripMaxAspect,
    );
    return _stripThumbHeight * aspect;
  }

  void _ensureStripAspect(int index) {
    if (_stripAspectByIndex.containsKey(index)) return;
    if (!_stripAspectRequested.add(index)) return;
    unawaited(_resolveStripAspect(index));
  }

  Future<void> _resolveStripAspect(int index) async {
    try {
      final att = widget.items[index].attachment;
      final mime = (att.mime ?? '').toLowerCase();
      final mediaFile = await _imageFutureAt(index);
      var sourceFile = mediaFile;
      if (_isVideoMediaMime(mime)) {
        // Never decode the video itself — its cached poster carries the same
        // aspect and is a tiny JPEG already on disk.
        final thumb = await VideoThumbnailCache.forVideo(
          key: att.blobId,
          videoPath: mediaFile.path,
        );
        if (thumb == null) return;
        sourceFile = thumb.file;
      }
      final bytes = await sourceFile.readAsBytes();
      // Tiny decode: dimensions only, aspect preserved by targetWidth scaling.
      final codec = await instantiateImageCodec(bytes, targetWidth: 32);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (w <= 0 || h <= 0 || !mounted) return;
      setState(() => _stripAspectByIndex[index] = w / h);
      // Thumb widths shifted — keep the active item glued to the center.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerStripOn(_currentIndex, animate: false);
      });
    } catch (_) {
      // Keep the square fallback for this thumb.
    }
  }

  double _stripLeadPadding(double screenW) {
    final pad = (screenW - _stripThumbWidth(0)) / 2;
    return pad > 0 ? pad : 0;
  }

  double _stripTrailPadding(double screenW) {
    final pad = (screenW - _stripThumbWidth(widget.items.length - 1)) / 2;
    return pad > 0 ? pad : 0;
  }

  void _centerStripOn(int index, {required bool animate}) {
    if (!_stripController.hasClients || widget.items.isEmpty) return;
    final screenW = MediaQuery.of(context).size.width;
    var prefix = 0.0;
    for (var i = 0; i < index; i++) {
      prefix += _stripThumbWidth(i) + _stripThumbGap;
    }
    final target =
        _stripLeadPadding(screenW) +
        prefix +
        _stripThumbWidth(index) / 2 -
        screenW / 2;
    final max = _stripController.position.maxScrollExtent;
    final clamped = target.clamp(0.0, max);
    if (animate) {
      _stripController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      _stripController.jumpTo(clamped);
    }
  }

  /// Registration from the active `_MediaViewerVideoPage`. `active:false`
  /// clears only if this exact controller is still current — a late dispose
  /// from an old page must not clobber the fresh page's registration.
  ///
  /// A page can dispose DURING the parent's build (PageView reaps offscreen
  /// children), when setState is illegal — defer to the end of the frame.
  void _handleActiveVideoController(
    VideoPlayerController? controller, {
    required bool active,
  }) {
    if (!mounted) return;
    void apply() {
      if (!mounted) return;
      setState(() {
        if (active) {
          _activeVideoController = controller;
        } else if (identical(_activeVideoController, controller)) {
          _activeVideoController = null;
        }
      });
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _controller = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerStripOn(_currentIndex, animate: false);
    });
  }

  @override
  void dispose() {
    // IMMERSIVE (2026-07-17): the viewer may exit while the bars are hidden —
    // always hand the system UI back in the app's normal edge-to-edge mode.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    _stripController.dispose();
    for (final c in _zoomControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// One tap on the media toggles our chrome AND the system bars together
  /// (IMMERSIVE 2026-07-17): fullscreen means truly fullscreen.
  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    SystemChrome.setEnabledSystemUIMode(
      _chromeVisible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  String _counterText(BuildContext context) {
    final current = _currentIndex + 1;
    final total = widget.items.length;
    return chatText(
      context,
      ru: '$current из $total',
      en: '$current / $total',
      uk: '$current з $total',
      es: '$current / $total',
      pt: '$current / $total',
      ptBr: '$current / $total',
      fr: '$current / $total',
      de: '$current / $total',
    );
  }

  String _timestampText(BuildContext context, MediaViewerItem item) {
    final material = MaterialLocalizations.of(context);
    final dt = DateTime.fromMillisecondsSinceEpoch(item.event.createdAtMs);
    final dateText = material.formatShortDate(dt);
    final timeText = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(dt),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return '$dateText • $timeText';
  }

  Widget _glassPanel({required Widget child, BorderRadius? borderRadius}) {
    final radius = borderRadius ?? BorderRadius.circular(22);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Runs an optional host action and closes the viewer. Null = the host does
  /// not support it; the entry is hidden below, so this is a defensive no-op.
  Future<void> _performAndClose(
    Future<void> Function(MediaViewerItem item)? action,
  ) async {
    if (action == null) return;
    final item = _currentItem;
    Navigator.of(context).pop();
    await action(item);
  }

  Future<void> _showAllMediaGrid() async {
    if (widget.items.length < 2) return;
    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: _glassPanel(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final selected = index == _currentIndex;
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(index),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.18),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: FutureBuilder<File>(
                          future: _imageFutureAt(index),
                          builder: (context, snapshot) {
                            final mime =
                                (widget.items[index].attachment.mime ?? '')
                                    .toLowerCase();
                            if (snapshot.hasData) {
                              return widget.thumbnailBuilder(
                                context,
                                snapshot.data,
                                mime,
                              );
                            }
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.28),
                              ),
                              child: Center(
                                child: Icon(
                                  _isVideoMediaMime(mime)
                                      ? AppIcons.playCircle
                                      : AppIcons.photo,
                                  color: Colors.white60,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    if (selectedIndex == null || !mounted) return;
    await _controller.animateToPage(
      selectedIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleMenuAction(MediaViewerMenuAction action) async {
    switch (action) {
      case MediaViewerMenuAction.showAllMedia:
        await _showAllMediaGrid();
        return;
      case MediaViewerMenuAction.saveToGallery:
        await _performAndClose(widget.onSaveToGallery);
        return;
      case MediaViewerMenuAction.showInChat:
        await _performAndClose(widget.onShowInChat);
        return;
      case MediaViewerMenuAction.reply:
        await _performAndClose(widget.onReply);
        return;
      case MediaViewerMenuAction.share:
        await _performAndClose(widget.onShare);
        return;
      case MediaViewerMenuAction.delete:
        await _performAndClose(widget.onDelete);
        return;
    }
  }

  Future<void> _openActionsMenu() async {
    final media = MediaQuery.of(context);
    final actions =
        <({IconData icon, String label, MediaViewerMenuAction value})>[
          if (widget.onSaveToGallery != null)
            (
              icon: Icons.save_alt_rounded,
              label: chatText(
                context,
                ru: 'Сохранить в галерею',
                en: 'Save to gallery',
              ),
              value: MediaViewerMenuAction.saveToGallery,
            ),
          if (widget.items.length > 1)
            (
              icon: Icons.grid_view_rounded,
              label: chatText(
                context,
                ru: 'Показать все медиа',
                en: 'Show all media',
              ),
              value: MediaViewerMenuAction.showAllMedia,
            ),
          if (widget.onShowInChat != null)
            (
              icon: Icons.visibility_outlined,
              label: chatText(
                context,
                ru: 'Показать в чате',
                en: 'Show in chat',
              ),
              value: MediaViewerMenuAction.showInChat,
            ),
          if (widget.onReply != null)
            (
              icon: AppIcons.reply,
              label: chatText(context, ru: 'Ответить', en: 'Reply'),
              value: MediaViewerMenuAction.reply,
            ),
          if (widget.onShare != null)
            (
              icon: Icons.share_outlined,
              label: chatText(context, ru: 'Поделиться', en: 'Share'),
              value: MediaViewerMenuAction.share,
            ),
          if (widget.onDelete != null)
            (
              icon: AppIcons.delete,
              label: chatText(context, ru: 'Удалить', en: 'Delete'),
              value: MediaViewerMenuAction.delete,
            ),
        ];

    final selected = await showDialog<MediaViewerMenuAction>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        final safeTop = media.viewPadding.top + 16;
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
                top: safeTop,
                right: 12,
                child: SizedBox(
                  width: 276,
                  child: _glassPanel(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: actions
                          .map(
                            (action) => ListTile(
                              dense: true,
                              minLeadingWidth: 24,
                              leading: Icon(action.icon, color: Colors.white),
                              title: Text(
                                action.label,
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () =>
                                  Navigator.of(context).pop(action.value),
                            ),
                          )
                          .toList(growable: false),
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
    await _handleMenuAction(selected);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    // Fade the black backdrop as the active page is dragged toward dismissal —
    // smooth swipe-up/down-to-close (parity with the profile image viewer).
    final fadeRatio = (_dragOffsetY.abs() / 240).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 1.0 - (fadeRatio * 0.5)),
      body: Stack(
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePointerDown,
            onPointerUp: (_) => _handlePointerUpOrCancel(),
            onPointerCancel: (_) => _handlePointerUpOrCancel(),
            child: PageView.builder(
            controller: _controller,
            // PINCH FIX (2026-07-17): while pinching (2+ fingers) or zoomed
            // in, the pager must not compete for the gesture — otherwise a
            // pinch turns into an accidental page swipe.
            physics: (_pinchActive || _currentScale > 1.02)
                ? const NeverScrollableScrollPhysics()
                : null,
            itemCount: total,
            onPageChanged: (i) {
              setState(() {
                _currentIndex = i;
                _dragOffsetY = 0;
                // A photo page never registers a controller — drop the old
                // video's one so the timeline hides; a video page re-registers
                // as soon as it initializes.
                _activeVideoController = null;
              });
              _centerStripOn(i, animate: true);
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleChrome,
                // Two fingers down → this is a pinch; stand down so
                // InteractiveViewer owns the gesture.
                onVerticalDragUpdate:
                    _pinchActive ? null : _handleVerticalDragUpdate,
                onVerticalDragEnd: _pinchActive ? null : _handleVerticalDragEnd,
                child: Transform.translate(
                  offset: Offset(0, index == _currentIndex ? _dragOffsetY : 0),
                  child: Center(
                    child: FutureBuilder<File>(
                      future: _imageFutureAt(index),
                      builder: (context, snapshot) {
                        final mime = (widget.items[index].attachment.mime ?? '')
                            .toLowerCase();
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator(
                            color: Colors.white,
                          );
                        }
                        if (snapshot.hasError || snapshot.data == null) {
                          return const Icon(
                            AppIcons.brokenImage,
                            color: Colors.white70,
                            size: 44,
                          );
                        }
                        if (_isVideoMediaMime(mime)) {
                          return _MediaViewerVideoPage(
                            file: snapshot.data!,
                            isActive: index == _currentIndex,
                            chromeVisible: _chromeVisible,
                            onToggleChrome: _toggleChrome,
                            onActiveController: _handleActiveVideoController,
                          );
                        }
                        return FullBleedZoom(
                          transformationController: _zoomControllerAt(index),
                          minScale: 0.85,
                          maxScale: 4,
                          // Refresh the cached scale so the drag-to-dismiss
                          // guard knows whether this page is currently zoomed.
                          onInteractionEnd: (_) => setState(() {}),
                          child: Image.file(
                            snapshot.data!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 40, onDarkSurface: true),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                offset: _chromeVisible ? Offset.zero : const Offset(0, -0.16),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: _chromeVisible ? 1 : 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Column(
                        children: [
                          // MEDIA-VIEWER ISLANDS (2026-07-16): the single wide
                          // glass bar is split into three separate frosted
                          // islands — back / title / actions — matching the
                          // main-screen header language. Each island floats on
                          // the media independently.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _glassPanel(
                                borderRadius: BorderRadius.circular(999),
                                child: SizedBox(
                                  width: 46,
                                  height: 46,
                                  child: IconButton(
                                    tooltip: context.l10n.close,
                                    padding: EdgeInsets.zero,
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: const Icon(
                                      AppIcons.arrowBack,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _glassPanel(
                                  borderRadius: BorderRadius.circular(23),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.chatTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          _timestampText(context, _currentItem),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.84,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _glassPanel(
                                borderRadius: BorderRadius.circular(999),
                                child: SizedBox(
                                  height: 46,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: chatText(
                                          context,
                                          ru: 'Переслать',
                                          en: 'Forward',
                                          uk: 'Переслати',
                                          es: 'Reenviar',
                                          pt: 'Reencaminhar',
                                          ptBr: 'Encaminhar',
                                          fr: 'Transferer',
                                          de: 'Weiterleiten',
                                        ),
                                        onPressed: () =>
                                            _performAndClose(widget.onForward),
                                        icon: const Icon(
                                          AppIcons.forward,
                                          color: Colors.white,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: chatText(
                                          context,
                                          ru: 'Меню',
                                          en: 'Menu',
                                          uk: 'Меню',
                                          es: 'Menu',
                                          pt: 'Menu',
                                          ptBr: 'Menu',
                                          fr: 'Menu',
                                          de: 'Menue',
                                        ),
                                        onPressed: _openActionsMenu,
                                        icon: const Icon(
                                          AppIcons.moreVert,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _glassPanel(
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Text(
                                _counterText(context),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
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
            ),
          ),
          // Bottom chrome: the centered filmstrip carousel raised above a
          // minimalist video seek timeline (timeline only while a video page
          // is active and initialized).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                offset: _chromeVisible ? Offset.zero : const Offset(0, 0.2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: _chromeVisible ? 1 : 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (total > 1) _buildStripCarousel(context),
                          // FIXED TIMELINE SLOT (2026-07-17): the seek bar
                          // lives in a constant-height slot that exists for
                          // photos too, so the carousel sits at EXACTLY the
                          // same level on every page. Reflowing the column
                          // (old behaviour) made the strip jump when swiping
                          // photo↔video — and even video→video, because the
                          // controller re-registers mid-swipe. The timeline
                          // now only fades in/out inside its slot.
                          SizedBox(
                            height: 44,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 160),
                              opacity: _activeVideoController != null ? 1 : 0,
                              child: _activeVideoController == null
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                      ),
                                      child: Center(
                                        child: _VideoTimelineBar(
                                          controller: _activeVideoController!,
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
            ),
          ),
        ],
      ),
    );
  }

  /// Centered carousel of true-aspect thumbnails: the active item is pinned to
  /// the middle of the screen, neighbours fan out to both sides. Thumbs are
  /// half the old 64px squares and keep each media's real proportions.
  Widget _buildStripCarousel(BuildContext context) {
    final total = widget.items.length;
    final screenW = MediaQuery.of(context).size.width;
    return SizedBox(
      height: _stripThumbHeight + 10,
      // Edge dissolve: the strip's outermost thumbs melt into transparency on
      // both sides instead of clipping hard (2026-07-17).
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.10, 0.90, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
        controller: _stripController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(
          left: _stripLeadPadding(screenW),
          right: _stripTrailPadding(screenW),
        ),
        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(width: _stripThumbGap),
        itemBuilder: (context, index) {
          _ensureStripAspect(index);
          final selected = index == _currentIndex;
          return GestureDetector(
            onTap: () {
              _controller.animateToPage(
                index,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
              );
            },
            child: Align(
              alignment: Alignment.center,
              child: AnimatedScale(
                scale: selected ? 1.16 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: selected ? 1.0 : 0.62,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    width: _stripThumbWidth(index),
                    height: _stripThumbHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.22),
                        width: selected ? 1.6 : 1,
                      ),
                      color: Colors.black.withValues(alpha: 0.24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: FutureBuilder<File>(
                        future: _imageFutureAt(index),
                        builder: (context, snapshot) {
                          final mime =
                              (widget.items[index].attachment.mime ?? '')
                                  .toLowerCase();
                          final isVideo = _isVideoMediaMime(mime);
                          final Widget thumb = snapshot.hasData
                              ? widget.thumbnailBuilder(
                                  context,
                                  snapshot.data,
                                  mime,
                                  forStrip: true,
                                )
                              : DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                  child: const SizedBox.expand(),
                                );
                          if (!isVideo) return thumb;
                          // Tiny bare play triangle — no circle plate
                          // (2026-07-17): the 38px thumbs read cleaner with a
                          // minimal glyph; the builders suppress their own
                          // circled badge via forStrip.
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              thumb,
                              const Center(
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 15,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            );
          },
        ),
      ),
    );
  }
}

/// Minimalist seek timeline for the active video: thin white track, small
/// thumb, mm:ss labels on both sides. Dragging pauses playback and resumes it
/// on release (if it was playing).
class _VideoTimelineBar extends StatefulWidget {
  const _VideoTimelineBar({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_VideoTimelineBar> createState() => _VideoTimelineBarState();
}

class _VideoTimelineBarState extends State<_VideoTimelineBar> {
  /// While dragging, the slider follows the finger, not the player.
  double? _dragValueMs;
  bool _wasPlayingBeforeDrag = false;

  String _fmt(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final durationMs = value.duration.inMilliseconds;
        if (!value.isInitialized || durationMs <= 0) {
          return const SizedBox.shrink();
        }
        final positionMs =
            (_dragValueMs ?? value.position.inMilliseconds.toDouble())
                .clamp(0.0, durationMs.toDouble())
                .toDouble();
        const labelStyle = TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        );
        return Row(
          children: [
            Text(
              _fmt(Duration(milliseconds: positionMs.round())),
              style: labelStyle,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2.5,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.28),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5.5,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  overlayColor: Colors.white.withValues(alpha: 0.12),
                ),
                child: Slider(
                  min: 0,
                  max: durationMs.toDouble(),
                  value: positionMs,
                  onChangeStart: (_) {
                    _wasPlayingBeforeDrag = value.isPlaying;
                    if (value.isPlaying) {
                      unawaited(widget.controller.pause());
                    }
                  },
                  onChanged: (v) => setState(() => _dragValueMs = v),
                  onChangeEnd: (v) async {
                    setState(() => _dragValueMs = null);
                    await widget.controller.seekTo(
                      Duration(milliseconds: v.round()),
                    );
                    if (_wasPlayingBeforeDrag) {
                      unawaited(widget.controller.play());
                    }
                  },
                ),
              ),
            ),
            Text(_fmt(value.duration), style: labelStyle),
          ],
        );
      },
    );
  }
}

class _MediaViewerVideoPage extends StatefulWidget {
  const _MediaViewerVideoPage({
    required this.file,
    required this.isActive,
    this.chromeVisible = true,
    this.onToggleChrome,
    this.onActiveController,
  });

  final File file;
  final bool isActive;

  /// Reports this page's initialized [VideoPlayerController] to the viewer so
  /// the seek timeline under the carousel can drive it. `active:false` on
  /// dispose/rotation lets the viewer clear the registration without an old
  /// page clobbering a newer one.
  final void Function(VideoPlayerController? controller, {required bool active})?
      onActiveController;

  /// Whether the viewer chrome (islands) is currently shown. The centered
  /// play/pause control rides WITH the chrome: it is visible while the chrome
  /// is up (so the user can pause/resume) and also whenever the video is
  /// paused (so a stopped video always offers a play affordance).
  final bool chromeVisible;

  /// Tapping the video surface (anywhere except the centered button) toggles
  /// the viewer chrome — parity with the photo pages, which toggle chrome on
  /// tap too. Null falls back to the old tap-to-play behaviour.
  final VoidCallback? onToggleChrome;

  @override
  State<_MediaViewerVideoPage> createState() => _MediaViewerVideoPageState();
}

class _MediaViewerVideoPageState extends State<_MediaViewerVideoPage> {
  VideoPlayerController? _controller;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _openController();
  }

  @override
  void didUpdateWidget(covariant _MediaViewerVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _disposeController();
      _openController();
      return;
    }
    if (!widget.isActive) {
      unawaited(_controller?.pause() ?? Future<void>.value());
      return;
    }
    // Became (or stayed) the active page — (re)register for the timeline.
    final controller = _controller;
    if (!oldWidget.isActive && controller != null &&
        controller.value.isInitialized) {
      widget.onActiveController?.call(controller, active: true);
    }
  }

  void _openController() {
    _loadFailed = false;
    final controller = VideoPlayerController.file(widget.file);
    _controller = controller;
    controller
        .initialize()
        .then((_) async {
          if (!mounted || !identical(_controller, controller)) return;
          await controller.setLooping(false);
          if (mounted) {
            setState(() {});
            if (widget.isActive) {
              widget.onActiveController?.call(controller, active: true);
            }
          }
        })
        .catchError((_) {
          if (!mounted || !identical(_controller, controller)) return;
          _loadFailed = true;
          setState(() {});
        });
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      widget.onActiveController?.call(controller, active: false);
      unawaited(controller.dispose());
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_loadFailed) {
      return const Icon(AppIcons.brokenImage, color: Colors.white70, size: 44);
    }
    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    if (!widget.isActive && controller.value.isPlaying) {
      unawaited(controller.pause());
    }

    final isPlaying = controller.value.isPlaying;
    // The centered control shows while the chrome is up OR whenever the video
    // is paused — a stopped video always offers a way to resume, and a playing
    // video with the chrome hidden goes fully immersive.
    final showCenterButton = widget.chromeVisible || !isPlaying;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Tap the surface → toggle the viewer chrome (islands), matching the
      // photo pages. The centered button below has its own tap for play/pause.
      onTap: widget.onToggleChrome ?? _togglePlayback,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FullBleedZoom(
            maxScale: 3,
            // Видео само держит пропорции, поэтому ему нужен Center — под
            // жёсткими размерами AspectRatio просто отдал бы их обратно.
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio <= 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            opacity: showCenterButton ? 1 : 0,
            child: IgnorePointer(
              ignoring: !showCenterButton,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlayback,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.34),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    isPlaying ? AppIcons.pause : AppIcons.playCircle,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
