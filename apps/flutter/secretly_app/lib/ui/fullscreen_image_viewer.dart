// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';

import 'animations/animations.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'widgets/full_bleed_zoom.dart';

Future<void> openFullscreenImageViewer(
  BuildContext context, {
  required String imagePath,
  String? title,
  String? heroTag,
}) {
  return Navigator.of(context).push<void>(
    SecretlyFullscreenRoute(
      builder: (_) => FullscreenImageViewerScreen(
        imagePath: imagePath,
        title: title,
        heroTag: heroTag,
      ),
    ),
  );
}

class FullscreenImageViewerScreen extends StatefulWidget {
  const FullscreenImageViewerScreen({
    super.key,
    required this.imagePath,
    this.title,
    this.heroTag,
  });

  final String imagePath;
  final String? title;
  final String? heroTag;

  @override
  State<FullscreenImageViewerScreen> createState() =>
      _FullscreenImageViewerScreenState();
}

class _FullscreenImageViewerScreenState
    extends State<FullscreenImageViewerScreen> {
  final TransformationController _transformController =
      TransformationController();
  bool _chromeVisible = true;
  double _dragOffsetY = 0;

  double get _currentScale => _transformController.value.getMaxScaleOnAxis();

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_currentScale > 1.02) return;
    setState(() {
      _dragOffsetY = (_dragOffsetY + details.delta.dy).clamp(-220.0, 220.0);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_currentScale > 1.02) return;
    final shouldClose =
        _dragOffsetY.abs() > 96 || (details.primaryVelocity?.abs() ?? 0) > 920;
    if (shouldClose) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _dragOffsetY = 0);
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageFile = File(widget.imagePath);
    final fadeRatio = (_dragOffsetY.abs() / 240).clamp(0.0, 1.0);
    final titleText = (widget.title ?? '').trim();

    Widget image = Image.file(
      imageFile,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      semanticLabel: titleText.isEmpty ? null : titleText,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          AppIcons.brokenImage,
          color: Colors.white70,
          size: 44,
        );
      },
    );
    if (widget.heroTag != null) {
      image = Hero(tag: widget.heroTag!, child: image);
    }

    return Scaffold(
      backgroundColor: Colors.black.withValues(
        alpha: 0.94 - (fadeRatio * 0.34),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _chromeVisible = !_chromeVisible),
              onVerticalDragUpdate: _handleVerticalDragUpdate,
              onVerticalDragEnd: _handleVerticalDragEnd,
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, _dragOffsetY),
                  child: FullBleedZoom(
                    transformationController: _transformController,
                    maxScale: 4.2,
                    child: image,
                  ),
                ),
              ),
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
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: context.l10n.close,
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              AppIcons.arrowBack,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              titleText.isEmpty
                                  ? context.l10n.photo
                                  : titleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
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
}
