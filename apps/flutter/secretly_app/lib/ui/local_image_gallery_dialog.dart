// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'icons/app_icons.dart';
import 'l10n.dart';
import 'wave1_l10n.dart';
import 'widgets/full_bleed_zoom.dart';

class LocalImageGalleryItem {
  const LocalImageGalleryItem({
    required this.id,
    required this.imagePath,
    required this.timestamp,
  });

  final String id;
  final String imagePath;
  final DateTime timestamp;
}

enum _LocalImageGalleryMenuAction { showAllMedia, share, delete }

class LocalImageGalleryDialog extends StatefulWidget {
  const LocalImageGalleryDialog({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.galleryTitle,
    required this.onForward,
    required this.onShare,
    required this.onDelete,
  });

  final List<LocalImageGalleryItem> items;
  final int initialIndex;
  final String galleryTitle;
  final Future<void> Function(LocalImageGalleryItem item) onForward;
  final Future<void> Function(LocalImageGalleryItem item) onShare;
  final Future<void> Function(LocalImageGalleryItem item) onDelete;

  @override
  State<LocalImageGalleryDialog> createState() =>
      _LocalImageGalleryDialogState();
}

class _LocalImageGalleryDialogState extends State<LocalImageGalleryDialog> {
  late final PageController _controller;
  late int _currentIndex;
  bool _chromeVisible = true;

  LocalImageGalleryItem get _currentItem => widget.items[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _label(
    BuildContext context, {
    required String ru,
    required String en,
  }) {
    return wave1Text(context, ru: ru, en: en);
  }

  String _counterText(BuildContext context) {
    final current = _currentIndex + 1;
    final total = widget.items.length;
    return _label(context, ru: '$current из $total', en: '$current / $total');
  }

  String _timestampText(BuildContext context, LocalImageGalleryItem item) {
    final material = MaterialLocalizations.of(context);
    final dateText = material.formatShortDate(item.timestamp);
    final timeText = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(item.timestamp),
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

  Future<void> _performAndClose(
    Future<void> Function(LocalImageGalleryItem item) action,
  ) async {
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
                  final item = widget.items[index];
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
                        child: Image.file(
                          File(item.imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.28),
                              ),
                              child: const Center(
                                child: Icon(
                                  AppIcons.photo,
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

  Future<void> _handleMenuAction(_LocalImageGalleryMenuAction action) async {
    switch (action) {
      case _LocalImageGalleryMenuAction.showAllMedia:
        await _showAllMediaGrid();
        return;
      case _LocalImageGalleryMenuAction.share:
        await _performAndClose(widget.onShare);
        return;
      case _LocalImageGalleryMenuAction.delete:
        await _performAndClose(widget.onDelete);
        return;
    }
  }

  Future<void> _openActionsMenu() async {
    final media = MediaQuery.of(context);
    final actions =
        <({IconData icon, String label, _LocalImageGalleryMenuAction value})>[
          if (widget.items.length > 1)
            (
              icon: Icons.grid_view_rounded,
              label: _label(
                context,
                ru: 'Показать все медиа',
                en: 'Show all media',
              ),
              value: _LocalImageGalleryMenuAction.showAllMedia,
            ),
          (
            icon: Icons.share_outlined,
            label: _label(context, ru: 'Поделиться', en: 'Share'),
            value: _LocalImageGalleryMenuAction.share,
          ),
          (
            icon: AppIcons.delete,
            label: context.l10n.chatMenuDelete,
            value: _LocalImageGalleryMenuAction.delete,
          ),
        ];

    final selected = await showDialog<_LocalImageGalleryMenuAction>(
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                child: FullBleedZoom(
                  minScale: 0.85,
                  child: Image.file(
                    File(item.imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        AppIcons.brokenImage,
                        color: Colors.white70,
                        size: 44,
                      );
                    },
                  ),
                ),
              );
            },
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
                          _glassPanel(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: context.l10n.close,
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: const Icon(
                                      AppIcons.arrowBack,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.galleryTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _timestampText(context, _currentItem),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.84,
                                            ),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: context.l10n.chatMenuForward,
                                    onPressed: () =>
                                        _performAndClose(widget.onForward),
                                    icon: const Icon(
                                      AppIcons.forward,
                                      color: Colors.white,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: _label(
                                      context,
                                      ru: 'Меню',
                                      en: 'Menu',
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
          if (total > 1)
            Positioned(
              left: 10,
              right: 10,
              bottom: 12,
              child: IgnorePointer(
                ignoring: !_chromeVisible,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  offset: _chromeVisible ? Offset.zero : const Offset(0, 0.2),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: _chromeVisible ? 1 : 0,
                    child: SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: total,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          final selected = index == _currentIndex;
                          return GestureDetector(
                            onTap: () {
                              _controller.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: 64,
                              height: 64,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.25),
                                  width: selected ? 2 : 1,
                                ),
                                color: Colors.black.withValues(alpha: 0.24),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(item.imagePath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          AppIcons.photo,
                                          color: Colors.white60,
                                          size: 18,
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
                ),
              ),
            ),
        ],
      ),
    );
  }
}
