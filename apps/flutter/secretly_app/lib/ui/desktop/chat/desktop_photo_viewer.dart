// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// PR8 (SPRINT2_AUDIT §20): Telegram-style fullscreen photo viewer for
// desktop. Opens as a translucent black overlay covering the whole
// window; the user can:
//
//   • swipe / arrow-key between photos in the same conversation,
//   • zoom with the scroll wheel or pinch (InteractiveViewer),
//   • double-click to reset zoom,
//   • copy the photo to the clipboard,
//   • save it to disk (file_picker save dialog),
//   • reveal it in Finder / Explorer,
//   • close with Esc, the X button, or by tapping the backdrop.
//
// We deliberately re-use the in-process Navigator (showGeneralDialog) and
// don't open a second OS window — that would require a brand-new
// FlutterEngine per popup (window_manager doesn't multi-instance us for
// free) and the visual is indistinguishable from a fullscreen modal on
// macOS. If we ever wire `multi_window` we can host the same widget
// inside a real NSWindow.

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'attachment_save.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_controller.dart';
import '../../../models/e2e_payload_v1.dart';

/// One image entry in the desktop photo viewer's gallery. Carries enough
/// metadata to render the header (author + time) and resolve the blob on
/// demand via [AppController.ensureCachedAttachmentFile].
class DesktopPhotoItem {
  const DesktopPhotoItem({
    required this.messageId,
    required this.attachment,
    required this.authorName,
    required this.timeLabel,
    this.caption = '',
  });

  /// `MessageData.id` — used as a stable key for the PageView so swiping
  /// between photos doesn't tear down the InteractiveViewer state.
  final String messageId;
  final AttachmentEventV1 attachment;
  final String authorName;
  final String timeLabel;
  final String caption;
}

class DesktopPhotoViewer extends StatefulWidget {
  const DesktopPhotoViewer({
    super.key,
    required this.controller,
    required this.items,
    required this.initialIndex,
  });

  final AppController controller;
  final List<DesktopPhotoItem> items;
  final int initialIndex;

  /// Convenience entry-point. Pushes the viewer as a full-screen modal
  /// dialog with a fade transition. Returns when the user closes it.
  static Future<void> show({
    required BuildContext context,
    required AppController controller,
    required List<DesktopPhotoItem> items,
    required int initialIndex,
  }) {
    if (items.isEmpty) return Future<void>.value();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim, secondary) {
        return DesktopPhotoViewer(
          controller: controller,
          items: items,
          initialIndex: initialIndex.clamp(0, items.length - 1),
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }

  @override
  State<DesktopPhotoViewer> createState() => _DesktopPhotoViewerState();
}

class _DesktopPhotoViewerState extends State<DesktopPhotoViewer> {
  late final PageController _page;
  late final FocusNode _focusNode;
  late int _index;

  /// Per-page transformation state. Indexed by item.messageId so it
  /// survives page swipes (the next image starts at 1.0 / centred, but
  /// stepping back returns the user to their previous zoom).
  final Map<String, TransformationController> _transforms =
      <String, TransformationController>{};

  /// Per-page file cache. Filled on demand by [_resolve], so once a photo
  /// has been decrypted to disk we don't go through `ensureCachedAttachmentFile`
  /// again on swipe-back.
  final Map<String, _PhotoFileState> _files = <String, _PhotoFileState>{};

  /// Last toast message — shown briefly when an action completes (e.g.
  /// "Скопировано", "Сохранено"). Auto-clears after 1.6 s.
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _page = PageController(initialPage: _index);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _page.dispose();
    _focusNode.dispose();
    for (final t in _transforms.values) {
      t.dispose();
    }
    _toastTimer?.cancel();
    super.dispose();
  }

  TransformationController _transformFor(String key) {
    return _transforms.putIfAbsent(key, () => TransformationController());
  }

  /// Resolves the on-disk file for the given item. While the future is
  /// pending the viewer shows a spinner; on completion (or failure) the
  /// state is cached so subsequent page swipes are instant.
  Future<File?> _resolve(DesktopPhotoItem item) async {
    final key = item.attachment.blobId;
    final existing = _files[key];
    if (existing != null) {
      // Re-await the in-flight future or return cached.
      if (existing.file != null) return existing.file;
      if (existing.error != null) return null;
      return existing.future;
    }
    final completer = Completer<File?>();
    _files[key] = _PhotoFileState(future: completer.future);
    () async {
      try {
        final cached = await widget.controller.cachedAttachmentFile(
          item.attachment,
        );
        if (cached != null) {
          _files[key] = _PhotoFileState(file: cached);
          if (mounted) setState(() {});
          completer.complete(cached);
          return;
        }
        final file = await widget.controller.ensureCachedAttachmentFile(
          item.attachment,
        );
        _files[key] = _PhotoFileState(file: file);
        if (mounted) setState(() {});
        completer.complete(file);
      } catch (e, st) {
        _files[key] = _PhotoFileState(error: '$e\n$st');
        if (mounted) setState(() {});
        completer.complete(null);
      }
    }();
    return completer.future;
  }

  void _showToast(String message) {
    setState(() => _toast = message);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _toast = null);
    });
  }

  void _close() {
    Navigator.of(context).maybePop();
  }

  void _next() {
    if (_index + 1 >= widget.items.length) return;
    _page.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _prev() {
    if (_index - 1 < 0) return;
    _page.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _zoom(double factor) {
    final item = widget.items[_index];
    final ctrl = _transformFor(item.messageId);
    final current = ctrl.value;
    final currentScale = current.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(1.0, 6.0);
    final f = currentScale == 0 ? 1.0 : newScale / currentScale;
    if (f == 1.0) return;
    final matrix = Matrix4.copy(current)..scaleByDouble(f, f, 1.0, 1.0);
    ctrl.value = matrix;
  }

  void _resetZoom() {
    final item = widget.items[_index];
    final ctrl = _transformFor(item.messageId);
    ctrl.value = Matrix4.identity();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.arrowDown) {
      _next();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowUp) {
      _prev();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.equal ||
        k == LogicalKeyboardKey.add ||
        k == LogicalKeyboardKey.numpadAdd) {
      _zoom(1.2);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.minus || k == LogicalKeyboardKey.numpadSubtract) {
      _zoom(1 / 1.2);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.digit0 || k == LogicalKeyboardKey.numpad0) {
      _resetZoom();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _copyToClipboard(DesktopPhotoItem item) async {
    final file = _files[item.attachment.blobId]?.file ?? await _resolve(item);
    if (file == null) {
      _showToast('Файл недоступен');
      return;
    }
    // Flutter's `Clipboard` doesn't accept raw bytes — to interop with the
    // OS clipboard we shell out. On macOS we use `osascript` to set the
    // clipboard to the file's image data; this matches Telegram's "Copy
    // photo" behaviour (the image, not the file URL, ends up in pasteboards).
    if (Platform.isMacOS) {
      try {
        final esc = file.path.replaceAll('"', r'\"');
        await Process.run('osascript', [
          '-e',
          'set the clipboard to (read (POSIX file "$esc") as «class PNGf»)',
        ]);
        _showToast('Скопировано');
      } catch (e) {
        _showToast('Не удалось скопировать: $e');
      }
      return;
    }
    // Fallback: copy the path so other apps can paste it.
    await Clipboard.setData(ClipboardData(text: file.path));
    _showToast('Путь скопирован');
  }

  Future<void> _saveAs(DesktopPhotoItem item) async {
    final file = _files[item.attachment.blobId]?.file ?? await _resolve(item);
    // Диалог и запись делает общая `saveAttachmentAs` — та же, что зовёт
    // строка сохранения под снимком в ленте. Два диалога «сохранить» с разными
    // заголовками и разными именами по умолчанию — ровно то, чего эта общая
    // функция и не даёт случиться.
    final outcome = await saveAttachmentAs(
      file: file,
      suggestedName: _suggestedFileName(item),
      dialogTitle: 'Сохранить фото',
      type: FileType.image,
    );
    switch (outcome.result) {
      case AttachmentSaveResult.saved:
        _showToast('Сохранено');
      case AttachmentSaveResult.unavailable:
        _showToast('Файл недоступен');
      case AttachmentSaveResult.failed:
        _showToast('Не удалось сохранить: ${outcome.error}');
      case AttachmentSaveResult.cancelled:
        break;
    }
  }

  Future<void> _revealInFinder(DesktopPhotoItem item) async {
    final file = _files[item.attachment.blobId]?.file ?? await _resolve(item);
    if (file == null) {
      _showToast('Файл недоступен');
      return;
    }
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', file.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', file.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [file.parent.path]);
      } else {
        await launchUrl(Uri.file(file.parent.path));
      }
    } catch (e) {
      _showToast('Не удалось показать в Finder: $e');
    }
  }

  String _suggestedFileName(DesktopPhotoItem item) {
    final mime = (item.attachment.mime ?? '').toLowerCase();
    var ext = 'jpg';
    if (mime == 'image/png') ext = 'png';
    if (mime == 'image/gif') ext = 'gif';
    if (mime == 'image/webp') ext = 'webp';
    if (mime == 'image/heic') ext = 'heic';
    final clean = item.attachment.blobId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
    final short = clean.length > 12 ? clean.substring(0, 12) : clean;
    return 'secretly-$short.$ext';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];
    final hasPrev = _index > 0;
    final hasNext = _index + 1 < widget.items.length;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: Container(
          color: Colors.black.withValues(alpha: 0.94),
          child: Stack(
            children: [
              // Photo + swipe navigation.
              Positioned.fill(
                child: GestureDetector(
                  // Swallow taps on the page itself so they don't bubble up
                  // to the backdrop-close handler above.
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // intentionally empty
                  child: Listener(
                    onPointerSignal: (signal) {
                      if (signal is PointerScrollEvent) {
                        // Cmd-scroll (or any scroll) zooms. We ignore the
                        // sign — both directions step toward "more zoom" or
                        // "less zoom" via the wheel delta sign.
                        final dy = signal.scrollDelta.dy;
                        if (dy.abs() < 0.5) return;
                        _zoom(dy < 0 ? 1.12 : 1 / 1.12);
                      }
                    },
                    child: PageView.builder(
                      controller: _page,
                      itemCount: widget.items.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (ctx, i) {
                        return _PhotoPage(
                          key: ValueKey(widget.items[i].messageId),
                          item: widget.items[i],
                          state: _files[widget.items[i].attachment.blobId],
                          resolve: () => _resolve(widget.items[i]),
                          transform: _transformFor(widget.items[i].messageId),
                          onDoubleTap: _resetZoom,
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Top toolbar.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _Toolbar(
                  title: _title(item),
                  subtitle: '${_index + 1} / ${widget.items.length}',
                  onClose: _close,
                  onCopy: () => _copyToClipboard(item),
                  onSave: () => _saveAs(item),
                  onReveal: () => _revealInFinder(item),
                  onZoomIn: () => _zoom(1.2),
                  onZoomOut: () => _zoom(1 / 1.2),
                  onZoomReset: _resetZoom,
                ),
              ),

              // Caption (bottom).
              if (item.caption.trim().isNotEmpty)
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      constraints: const BoxConstraints(maxWidth: 720),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.caption,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

              // Navigation chevrons (only shown when there's somewhere to go).
              if (hasPrev)
                Positioned(
                  left: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ChevronButton(
                      icon: FluentIcons.chevron_left_24_regular,
                      onTap: _prev,
                    ),
                  ),
                ),
              if (hasNext)
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ChevronButton(
                      icon: FluentIcons.chevron_right_24_regular,
                      onTap: _next,
                    ),
                  ),
                ),

              // Floating toast.
              if (_toast != null)
                Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _toast!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
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

  String _title(DesktopPhotoItem item) {
    final author = item.authorName.isEmpty ? '—' : item.authorName;
    if (item.timeLabel.isEmpty) return author;
    return '$author · ${item.timeLabel}';
  }
}

class _PhotoFileState {
  _PhotoFileState({this.file, this.future, this.error});
  final File? file;
  final Future<File?>? future;
  final String? error;
}

class _PhotoPage extends StatelessWidget {
  const _PhotoPage({
    super.key,
    required this.item,
    required this.state,
    required this.resolve,
    required this.transform,
    required this.onDoubleTap,
  });

  final DesktopPhotoItem item;
  final _PhotoFileState? state;
  final Future<File?> Function() resolve;
  final TransformationController transform;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    // Fire the resolve future as a side effect on first build — the
    // parent will rebuild us with `state` populated once the future
    // completes.
    if (state == null) {
      // Schedule outside of build to avoid setState-in-build issues.
      WidgetsBinding.instance.addPostFrameCallback((_) => resolve());
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(Colors.white70),
          ),
        ),
      );
    }
    if (state!.file == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              FluentIcons.image_off_24_regular,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              state!.error == null ? 'Загрузка…' : 'Не удалось загрузить',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: InteractiveViewer(
        transformationController: transform,
        minScale: 1.0,
        maxScale: 6.0,
        boundaryMargin: const EdgeInsets.all(80),
        clipBehavior: Clip.none,
        child: Center(
          child: Image.file(
            state!.file!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (ctx, err, st) => const Icon(
              FluentIcons.image_off_24_regular,
              color: Colors.white70,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.onCopy,
    required this.onSave,
    required this.onReveal,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onZoomReset,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final VoidCallback onCopy;
  final VoidCallback onSave;
  final VoidCallback onReveal;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.65),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          // Title + counter.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _ToolbarButton(
            icon: FluentIcons.zoom_out_24_regular,
            tooltip: 'Уменьшить',
            onTap: onZoomOut,
          ),
          _ToolbarButton(
            icon: FluentIcons.full_screen_minimize_24_regular,
            tooltip: 'Сбросить масштаб',
            onTap: onZoomReset,
          ),
          _ToolbarButton(
            icon: FluentIcons.zoom_in_24_regular,
            tooltip: 'Увеличить',
            onTap: onZoomIn,
          ),
          const SizedBox(width: 16),
          _ToolbarButton(
            icon: FluentIcons.copy_24_regular,
            tooltip: 'Скопировать',
            onTap: onCopy,
          ),
          _ToolbarButton(
            icon: FluentIcons.save_24_regular,
            tooltip: 'Сохранить как…',
            onTap: onSave,
          ),
          _ToolbarButton(
            icon: FluentIcons.folder_24_regular,
            tooltip: 'Показать в Finder',
            onTap: onReveal,
          ),
          const SizedBox(width: 16),
          _ToolbarButton(
            icon: FluentIcons.dismiss_24_regular,
            tooltip: 'Закрыть (Esc)',
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _hover
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _ChevronButton extends StatefulWidget {
  const _ChevronButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_ChevronButton> createState() => _ChevronButtonState();
}

class _ChevronButtonState extends State<_ChevronButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: _hover ? 0.6 : 0.35),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
