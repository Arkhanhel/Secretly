// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Telegram-style fullscreen video player for desktop. Opens as a translucent
// black overlay covering the window (showGeneralDialog — no second OS window,
// matching desktop_photo_viewer). PC-convenient: Space toggles play/pause, Esc
// closes, ←/→ seek ±5s, ↑/↓ volume, M mutes, click the frame to play/pause,
// and the control bar auto-hides while playing.

import '../../../l10n/app_localizations.dart';
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../design/tokens.dart';

class DesktopVideoViewer extends StatefulWidget {
  const DesktopVideoViewer({
    super.key,
    required this.file,
    this.authorName = '',
    this.timeLabel = '',
    this.filename,
  });

  final File file;
  final String authorName;
  final String timeLabel;
  final String? filename;

  static Future<void> show({
    required BuildContext context,
    required File file,
    String authorName = '',
    String timeLabel = '',
    String? filename,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'video',
      barrierColor: Colors.transparent,
      transitionDuration: DMotion.base,
      pageBuilder: (ctx, a, b) => DesktopVideoViewer(
        file: file,
        authorName: authorName,
        timeLabel: timeLabel,
        filename: filename,
      ),
      transitionBuilder: (ctx, a, b, child) =>
          FadeTransition(opacity: a, child: child),
    );
  }

  @override
  State<DesktopVideoViewer> createState() => _DesktopVideoViewerState();
}

class _DesktopVideoViewerState extends State<DesktopVideoViewer> {
  late final VideoPlayerController _ctl;
  final FocusNode _focus = FocusNode();
  bool _ready = false;
  String? _error;
  bool _controlsVisible = true;
  double _volume = 1.0;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _ctl = VideoPlayerController.file(widget.file);
    _ctl.addListener(_onTick);
    _init();
  }

  Future<void> _init() async {
    try {
      await _ctl.initialize();
      if (!mounted) return;
      await _ctl.setVolume(_volume);
      await _ctl.play();
      setState(() => _ready = true);
      _armHide();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = AppLocalizations.of(context)!.desktopVideoPlayFailed,
      );
    }
  }

  void _onTick() {
    if (mounted) setState(() {}); // refresh position / play state
  }

  void _armHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _ctl.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _wake() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _armHide();
  }

  void _togglePlay() {
    if (!_ready) return;
    setState(() {
      _ctl.value.isPlaying ? _ctl.pause() : _ctl.play();
    });
    _wake();
  }

  void _seekBy(int seconds) {
    if (!_ready) return;
    final pos = _ctl.value.position + Duration(seconds: seconds);
    final dur = _ctl.value.duration;
    _ctl.seekTo(pos < Duration.zero
        ? Duration.zero
        : (pos > dur ? dur : pos));
    _wake();
  }

  void _setVolume(double v) {
    final clamped = v.clamp(0.0, 1.0);
    setState(() => _volume = clamped);
    _ctl.setVolume(clamped);
    _wake();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.space) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      _seekBy(-5);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      _seekBy(5);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      _setVolume(_volume + 0.1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      _setVolume(_volume - 0.1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyM) {
      _setVolume(_volume == 0 ? 1.0 : 0.0);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _save() async {
    try {
      final name = widget.filename?.trim().isNotEmpty == true
          ? widget.filename!.trim()
          : 'video-${widget.file.path.split(Platform.pathSeparator).last}';
      final dest = await FilePicker.platform.saveFile(fileName: name);
      if (dest == null) return;
      await widget.file.copy(dest);
    } catch (_) {}
  }

  Future<void> _reveal() async {
    try {
      final dir = widget.file.parent.path;
      await launchUrl(Uri.file(dir), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _ctl.removeListener(_onTick);
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        onHover: (_) => _wake(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop — click outside the video closes.
            Semantics(
              button: true,
              label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(color: Colors.black.withValues(alpha: 0.92)),
              ),
            ),
            Center(child: _videoArea()),
            _header(),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _videoArea() {
    if (_error != null) {
      return Text(_error!,
          style: const TextStyle(color: Colors.white70, fontSize: 15));
    }
    if (!_ready) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
      );
    }
    return Semantics(
             button: true,
             label: _ctl.value.isPlaying
                 ? AppLocalizations.of(context)!.desktopA11yPause
                 : AppLocalizations.of(context)!.desktopA11yPlay,
             child: GestureDetector(
        onTap: _togglePlay,
        child: AspectRatio(
          aspectRatio: _ctl.value.aspectRatio == 0 ? 16 / 9 : _ctl.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_ctl),
              // Big play overlay while paused.
              if (!_ctl.value.isPlaying)
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(FluentIcons.play_24_filled,
                      color: Colors.white, size: 34),
                ),
            ],
          ),
        ),
      ),
           );
  }

  Widget _header() {
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: DMotion.base,
        opacity: _controlsVisible ? 1 : 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(DSpace.l, DSpace.m, DSpace.m, DSpace.m),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.authorName.isEmpty ? l10n.desktopVideoTitle : widget.authorName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: DType.family,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    if (widget.timeLabel.isNotEmpty)
                      Text(widget.timeLabel,
                          style: const TextStyle(
                              color: Colors.white60,
                              fontFamily: DType.family,
                              fontSize: 12)),
                  ],
                ),
              ),
              _GlyphButton(icon: FluentIcons.save_24_regular, tooltip: l10n.saveAction, onTap: _save),
              _GlyphButton(icon: FluentIcons.folder_24_regular, tooltip: l10n.desktopGalleryRevealFinder, onTap: _reveal),
              _GlyphButton(
                  icon: FluentIcons.dismiss_24_regular,
                  tooltip: l10n.desktopViewerCloseEsc,
                  onTap: () => Navigator.of(context).maybePop()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final l10n = AppLocalizations.of(context)!;
    final pos = _ctl.value.position;
    final dur = _ctl.value.duration;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: DMotion.base,
        opacity: _controlsVisible ? 1 : 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(DSpace.l, DSpace.m, DSpace.l, DSpace.l),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              _GlyphButton(
                icon: _ctl.value.isPlaying
                    ? FluentIcons.pause_24_filled
                    : FluentIcons.play_24_filled,
                tooltip: l10n.desktopKeySpace,
                onTap: _togglePlay,
              ),
              const SizedBox(width: DSpace.s),
              Text(_fmt(pos),
                  style: const TextStyle(
                      color: Colors.white, fontFamily: DType.family, fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: dur.inMilliseconds == 0
                        ? 0
                        : pos.inMilliseconds
                            .clamp(0, dur.inMilliseconds)
                            .toDouble(),
                    max: dur.inMilliseconds == 0
                        ? 1
                        : dur.inMilliseconds.toDouble(),
                    onChanged: _ready
                        ? (v) {
                            _ctl.seekTo(Duration(milliseconds: v.round()));
                            _wake();
                          }
                        : null,
                  ),
                ),
              ),
              Text(_fmt(dur),
                  style: const TextStyle(
                      color: Colors.white70, fontFamily: DType.family, fontSize: 12)),
              const SizedBox(width: DSpace.s),
              _GlyphButton(
                icon: _volume == 0
                    ? FluentIcons.speaker_mute_24_filled
                    : FluentIcons.speaker_2_24_filled,
                tooltip: 'M',
                onTap: () => _setVolume(_volume == 0 ? 1.0 : 0.0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final s = d.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    final hh = s ~/ 3600;
    return hh > 0 ? '$hh:$mm:$ss' : '$mm:$ss';
  }
}

class _GlyphButton extends StatelessWidget {
  const _GlyphButton(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
