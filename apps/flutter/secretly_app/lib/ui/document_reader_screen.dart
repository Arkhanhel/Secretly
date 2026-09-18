// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/pdf_document.dart';
import 'icons/app_icons.dart';

/// Full-screen in-app document reader.
///
/// Deliberately built on the SAME chrome as the photo gallery: black canvas, a
/// tap toggles two blurred islands (top = title + page counter, bottom =
/// actions), pages zoom with a pinch and swipe vertically. Pages are rendered by
/// the platform's own PDF renderer (see [PdfDocument]) and drawn here as plain
/// images, so nothing about the reader's look comes from a third-party widget.
///
/// Smoothness: the visible page is rendered at the device's real pixel width and
/// its neighbours are warmed in the background, so a swipe normally lands on an
/// already-decoded page instead of a spinner.
class DocumentReaderScreen extends StatefulWidget {
  const DocumentReaderScreen({
    super.key,
    required this.document,
    required this.title,
    required this.onShare,
  });

  final PdfDocument document;
  final String title;
  final Future<void> Function() onShare;

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  final PageController _controller = PageController();
  bool _chromeVisible = true;
  int _index = 0;
  int _renderWidth = 1080;
  // PINCH-ZOOM (2026-07-29): a zoomed page must be pannable, but the PageView
  // would steal every drag and flip to the next page instead. While any page is
  // scaled past 1x we lock paging, so the drag belongs to the page; releasing
  // back to 1x restores swipe-to-page.
  bool _pageZoomed = false;

  void _setZoomed(bool zoomed) {
    if (_pageZoomed == zoomed) return;
    setState(() => _pageZoomed = zoomed);
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.document.dispose();
    super.dispose();
  }

  String _label(BuildContext context, {required String ru, required String en}) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    return code == 'ru' || code == 'uk' ? ru : en;
  }

  Widget _glassPanel({required Widget child}) {
    final radius = BorderRadius.circular(22);
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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Render at real device pixels (capped) so text stays crisp when zoomed a
    // little, without asking the renderer for a needlessly huge bitmap.
    final width = (media.size.width * media.devicePixelRatio).round().clamp(
      480,
      2560,
    );
    if (width != _renderWidth) {
      _renderWidth = width;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            physics: _pageZoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: widget.document.pageCount,
            onPageChanged: (i) {
              setState(() => _index = i);
              widget.document.preloadAround(i, width: _renderWidth);
            },
            itemBuilder: (_, i) => _PdfPageView(
              document: widget.document,
              index: i,
              width: _renderWidth,
              onTap: () => setState(() => _chromeVisible = !_chromeVisible),
              onZoomChanged: _setZoomed,
            ),
          ),
          _topIsland(context),
          _bottomIsland(context),
        ],
      ),
    );
  }

  Widget _topIsland(BuildContext context) {
    return Positioned(
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
                child: _glassPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            AppIcons.arrowBack,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_index + 1} / ${widget.document.pageCount}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomIsland(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
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
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _glassPanel(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await widget.onShare();
                          },
                          icon: const Icon(
                            Icons.ios_share_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: Text(
                            _label(context, ru: 'Поделиться', en: 'Share'),
                            style: const TextStyle(color: Colors.white),
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
      ),
    );
  }
}

class _PdfPageView extends StatefulWidget {
  const _PdfPageView({
    required this.document,
    required this.index,
    required this.width,
    required this.onTap,
    required this.onZoomChanged,
  });

  final PdfDocument document;
  final int index;
  final int width;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_PdfPageView> createState() => _PdfPageViewState();
}

class _PdfPageViewState extends State<_PdfPageView>
    with AutomaticKeepAliveClientMixin {
  Future<Uint8List?>? _future;
  final TransformationController _zoom = TransformationController();
  TapDownDetails? _lastTapDown;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.document.renderPage(widget.index, width: widget.width);
    _zoom.addListener(_reportZoom);
  }

  void _reportZoom() {
    // 1.02 rather than 1.0: the matrix can carry a hair of scale after an
    // inertial release, and a page that merely looks unzoomed must still page.
    widget.onZoomChanged(_zoom.value.getMaxScaleOnAxis() > 1.02);
  }

  /// Double tap zooms to 2.5x centred on the tapped point, or back out — the
  /// gesture people expect from a photo viewer, and much faster than pinching
  /// when you just want to read a paragraph.
  void _handleDoubleTap() {
    if (_zoom.value.getMaxScaleOnAxis() > 1.02) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final position = _lastTapDown?.localPosition;
    if (position == null) return;
    const scale = 2.5;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (scale - 1),
        -position.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
  }

  @override
  void dispose() {
    _zoom.removeListener(_reportZoom);
    _zoom.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PdfPageView old) {
    super.didUpdateWidget(old);
    if (old.width != widget.width || old.index != widget.index) {
      _future = widget.document.renderPage(widget.index, width: widget.width);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _lastTapDown = d,
      onDoubleTap: _handleDoubleTap,
      child: FutureBuilder<Uint8List?>(
        future: _future,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            );
          }
          return InteractiveViewer(
            transformationController: _zoom,
            maxScale: 6,
            minScale: 1,
            // Panning is what lets a zoomed page be dragged around; the reader
            // locks paging while that is true so the two never fight.
            panEnabled: true,
            clipBehavior: Clip.none,
            child: Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          );
        },
      ),
    );
  }
}
