// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../build_variant.dart';
import '../../media/video_thumbnail_cache.dart';
import '../../models/e2e_payload_v1.dart';
import '../l10n.dart';
import 'chat_media_circle.dart';
import 'video_note_playback.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';

export 'video_note_playback.dart'
    show videoNoteSmallSide, videoNoteLargeSide, videoNoteRadiusFor;

/// Видео-заметка в ленте — макет «Video Notes», 5a (22.11.2026).
///
///  * В ленте квадрат 176 (скругление 20 %) играет БЕЗ ЗВУКА ПО КРУГУ, если
///    он на экране и входит в две самые видимые заметки; иначе — кадр-превью.
///    Внизу слева — значок «без звука», длительность и синяя точка, пока
///    входящая заметка не просмотрена.
///  * Касание раскрывает квадрат НА МЕСТЕ почти во всю ширину (зазор 12 по
///    краям) пружиной 450 мс с лёгким перелётом; лента подкручивается, чтобы
///    квадрат встал по центру, остальная лента приглушается до 35 %. Звук
///    включается, ролик идёт сначала.
///  * Прогресс — ОДИН: по контуру квадрата. Мини-плеер сверху (пауза, «Анна ·
///    видео-заметка», время, закрыть) — без второй полосы.
///  * Касание по раскрытому — пауза/продолжить; протяжка вбок — перемотка
///    (ширина квадрата = вся длительность, по центру время с шевронами);
///    скорость 1× → 1,5× → 2× справа сверху.
///  * Закрытие — касание мимо, крестик мини-плеера или конец ролика (тогда
///    через 380 мс раскрывается следующая непросмотренная входящая ниже).
class VideoNoteBubble extends StatefulWidget {
  const VideoNoteBubble({
    super.key,
    required this.attachment,
    required this.isMe,
    required this.resolveFile,
    required this.footer,
    this.header,
    this.diameter,
    this.createdAtMs = 0,
    this.authorName,
    this.onSoundStart,
    this.hapticsEnabled,
  });

  final AttachmentEventV1 attachment;
  final bool isMe;

  /// Скачивает (кэширует) файл заметки.
  final Future<File> Function(AttachmentEventV1 attachment) resolveFile;

  /// Время, галочки и реакции — строит чат, без подложки.
  final Widget footer;

  /// Автор в комнате — над квадратом.
  final Widget? header;

  /// Своя сторона маленького квадрата (тесты, особые места).
  final double? diameter;

  /// Время сообщения — для цепочки «следующая непросмотренная ниже».
  final int createdAtMs;

  /// «Анна» / «Вы» — заголовок мини-плеера.
  final String? authorName;

  /// Перед тем как зазвучать: чат ставит на паузу голосовые и музыку.
  final VoidCallback? onSoundStart;
  final bool Function()? hapticsEnabled;

  @override
  State<VideoNoteBubble> createState() => _VideoNoteBubbleState();
}

class _VideoNoteBubbleState extends State<VideoNoteBubble>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver
    implements VideoNoteSessionHost, VideoNoteFeedClient {
  final GlobalKey _squareKey = GlobalKey();
  final OverlayPortalController _portal = OverlayPortalController();

  File? _file;
  Future<File?>? _fileFuture;
  File? _posterFile;
  bool _failed = false;

  /// Лента: без звука, по кругу, звук других приложений не перебивает.
  VideoPlayerController? _feed;
  bool _feedReady = false;
  bool _feedWanted = false;

  /// Раскрытая: со звуком, один раз.
  VideoPlayerController? _main;
  bool _mainReady = false;

  bool _enlarged = false;
  bool _endHandled = false;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: kVideoNoteSpringDuration,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _anim,
    curve: kVideoNoteSpring,
    reverseCurve: kVideoNoteSpring.flipped,
  );

  final ValueNotifier<VideoNoteTime> _time = ValueNotifier<VideoNoteTime>(
    VideoNoteTime.zero,
  );
  final ValueNotifier<double?> _scrub = ValueNotifier<double?>(null);
  bool _scrubbed = false;
  double _dragStartF = 0;
  double _dragStartX = 0;
  DateTime _lastSeek = DateTime.fromMillisecondsSinceEpoch(0);
  double _speed = 1;
  ValueListenable<TickerModeData>? _tickerMode;

  String get _id => widget.attachment.blobId;

  // ─── VideoNoteSessionHost / FeedClient ────────────────────────────────────

  @override
  String get noteId => _id;

  @override
  String get title => context.mounted
      ? context.l10n.vnNoteTitle(widget.authorName ?? '')
      : (widget.authorName ?? '');

  @override
  BuildContext? get squareContext => _squareKey.currentContext;

  @override
  ValueListenable<VideoNoteTime> get time => _time;

  @override
  bool get isPaused => !(_main?.value.isPlaying ?? false);

  @override
  int get createdAtMs => widget.createdAtMs;

  @override
  bool get isMe => widget.isMe;

  @override
  void togglePause() => _togglePause();

  @override
  void collapse() => _collapse();

  @override
  void openFromChain() => unawaited(_enlarge());

  @override
  void setFeedLive(bool live) {
    _feedWanted = live;
    if (live) {
      unawaited(_startFeed());
    } else {
      _disposeFeed();
    }
  }

  // ─── Жизнь ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    VideoNotePlayback.instance.register(this);
    unawaited(VideoNoteWatched.instance.ensureLoaded());
    if (kVideoToolsAvailable) unawaited(_loadPoster());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tm = TickerMode.getValuesNotifier(context);
    if (!identical(tm, _tickerMode)) {
      _tickerMode?.removeListener(_onTickerMode);
      _tickerMode = tm..addListener(_onTickerMode);
    }
  }

  /// Чат закрыт другим экраном — заметка сворачивается и молчит.
  void _onTickerMode() {
    if (_tickerMode?.value.enabled ?? true) {
      if (_feedWanted) unawaited(_startFeed());
      return;
    }
    if (_enlarged) _collapse();
    _disposeFeed(keepWanted: true);
  }

  @override
  void didUpdateWidget(covariant VideoNoteBubble old) {
    super.didUpdateWidget(old);
    if (old.attachment.blobId != widget.attachment.blobId) {
      VideoNotePlayback.instance.unregister(this);
      if (_enlarged) _collapse();
      _disposeFeed();
      _disposeMain();
      _file = null;
      _fileFuture = null;
      _posterFile = null;
      VideoNotePlayback.instance.register(this);
      if (kVideoToolsAvailable) unawaited(_loadPoster());
    }
  }

  // 🔴 Play Vitals п. 1/12 (15.11.2026): кадр видео не должен приходить в
  // движок, отсоединённый от окна. Уходя в фон — сворачиваемся и молчим.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_enlarged) _collapse();
      _disposeFeed(keepWanted: true);
    } else if (state == AppLifecycleState.resumed && _feedWanted) {
      unawaited(_startFeed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickerMode?.removeListener(_onTickerMode);
    VideoNotePlayback.instance.deactivate(this);
    VideoNotePlayback.instance.unregister(this);
    _disposeFeed();
    _disposeMain();
    _anim.dispose();
    _time.dispose();
    _scrub.dispose();
    super.dispose();
  }

  // ─── Файл и кадр ──────────────────────────────────────────────────────────

  Future<File?> _ensureFile() {
    final f = _file;
    if (f != null) return Future<File?>.value(f);
    return _fileFuture ??= () async {
      try {
        final file = await widget.resolveFile(widget.attachment);
        _file = file;
        if (_failed && mounted) setState(() => _failed = false);
        return file;
      } catch (_) {
        _fileFuture = null;
        if (mounted) setState(() => _failed = true);
        return null;
      }
    }();
  }

  Future<void> _loadPoster() async {
    final file = await _ensureFile();
    if (file == null || !mounted) return;
    try {
      final poster = await VideoThumbnailCache.forVideo(
        key: p.basenameWithoutExtension(file.path),
        videoPath: file.path,
      );
      if (poster != null && mounted) setState(() => _posterFile = poster.file);
    } catch (_) {
      // Без кадра — полосатая подложка, лента всё равно оживит заметку.
    }
  }

  // ─── Лента без звука ──────────────────────────────────────────────────────

  bool get _feedAllowed =>
      !_enlarged &&
      (_tickerMode?.value.enabled ?? true) &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  Future<void> _startFeed() async {
    if (_feed != null || !_feedAllowed) return;
    final file = await _ensureFile();
    if (file == null || !mounted || !_feedWanted || !_feedAllowed) return;
    if (_feed != null) return;
    final c = VideoPlayerController.file(
      file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _feed = c;
    try {
      await c.initialize();
      if (!mounted || !identical(_feed, c)) {
        unawaited(c.dispose());
        return;
      }
      await c.setVolume(0);
      await c.setLooping(true);
      await c.play();
      if (mounted && identical(_feed, c)) setState(() => _feedReady = true);
    } catch (_) {
      if (identical(_feed, c)) {
        _feed = null;
        _feedReady = false;
      }
      unawaited(c.dispose());
    }
  }

  void _disposeFeed({bool keepWanted = false}) {
    if (!keepWanted) _feedWanted = false;
    final c = _feed;
    _feed = null;
    if (_feedReady && mounted) {
      setState(() => _feedReady = false);
    } else {
      _feedReady = false;
    }
    if (c != null) unawaited(c.dispose());
  }

  // ─── Раскрытие ────────────────────────────────────────────────────────────

  bool _haptics() => widget.hapticsEnabled?.call() ?? true;

  Future<void> _enlarge() async {
    if (_enlarged) return;
    if (_failed) {
      setState(() => _failed = false);
    }
    final file = await _ensureFile();
    if (file == null || !mounted || _enlarged) return;
    VideoNotePlayback.instance.activate(this);
    _endHandled = false;
    _speed = 1;
    _time.value = VideoNoteTime(
      Duration.zero,
      Duration(milliseconds: widget.attachment.durationMs ?? 0),
    );
    setState(() => _enlarged = true);
    if (_haptics()) HapticFeedback.lightImpact();
    widget.onSoundStart?.call();
    _portal.show();
    unawaited(_anim.forward());
    // Лента подкручивается, чтобы раскрытый квадрат встал по центру.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _squareKey.currentContext;
      if (ctx == null || !mounted || !_enlarged) return;
      unawaited(
        Scrollable.ensureVisible(
          ctx,
          alignment: .5,
          duration: kVideoNoteSpringDuration,
          curve: Curves.easeOutCubic,
        ),
      );
    });
    final c = VideoPlayerController.file(file);
    _main = c;
    _mainReady = false;
    try {
      await c.initialize();
      if (!mounted || !identical(_main, c) || !_enlarged) {
        if (identical(_main, c)) _main = null;
        unawaited(c.dispose());
        return;
      }
      await c.setLooping(false);
      await c.setVolume(1);
      await c.setPlaybackSpeed(_speed);
      await c.seekTo(Duration.zero);
      c.addListener(_onMainTick);
      await c.play();
      if (mounted && identical(_main, c)) setState(() => _mainReady = true);
    } catch (_) {
      if (identical(_main, c)) {
        _main = null;
        _mainReady = false;
      }
      unawaited(c.dispose());
      if (mounted) {
        setState(() => _failed = true);
        _collapse();
      }
    }
  }

  void _onMainTick() {
    final c = _main;
    if (c == null || !mounted) return;
    final v = c.value;
    if (!v.isInitialized) return;
    if (_scrub.value == null) {
      _time.value = VideoNoteTime(v.position, v.duration, paused: !v.isPlaying);
    }
    final ended =
        v.duration > const Duration(milliseconds: 300) &&
        v.position >= v.duration - const Duration(milliseconds: 80) &&
        !v.isPlaying &&
        _scrub.value == null;
    if (ended && !_endHandled && _enlarged) {
      _endHandled = true;
      final id = _id;
      _collapse();
      VideoNotePlayback.instance.scheduleChainAfter(id);
    }
  }

  void _collapse() {
    if (!_enlarged) return;
    _enlarged = false;
    _scrub.value = null;
    unawaited(_main?.pause());
    unawaited(VideoNoteWatched.instance.markWatched(_id));
    _portal.hide();
    VideoNotePlayback.instance.deactivate(this);
    if (mounted) setState(() {});
    unawaited(
      _anim.reverse().whenComplete(() {
        if (!_enlarged) _disposeMain();
      }),
    );
  }

  void _disposeMain() {
    final c = _main;
    _main = null;
    _mainReady = false;
    if (c != null) {
      c.removeListener(_onMainTick);
      unawaited(c.dispose());
    }
  }

  void _togglePause() {
    final c = _main;
    if (c == null || !_mainReady) return;
    if (c.value.isPlaying) {
      unawaited(c.pause());
    } else {
      if (c.value.position >= c.value.duration - const Duration(milliseconds: 80)) {
        unawaited(c.seekTo(Duration.zero));
        _endHandled = false;
      }
      unawaited(c.play());
    }
    if (_haptics()) HapticFeedback.selectionClick();
  }

  void _cycleSpeed() {
    _speed = _speed == 1 ? 1.5 : (_speed == 1.5 ? 2 : 1);
    unawaited(_main?.setPlaybackSpeed(_speed));
    if (_haptics()) HapticFeedback.selectionClick();
    setState(() {});
  }

  // ─── Перемотка протяжкой ──────────────────────────────────────────────────

  void _scrubStart(DragStartDetails d) {
    final c = _main;
    if (c == null || !_mainReady) return;
    _dragStartX = d.globalPosition.dx;
    _dragStartF = _time.value.fraction;
    _scrub.value = _dragStartF;
    _scrubbed = true;
    unawaited(c.pause());
  }

  void _scrubUpdate(DragUpdateDetails d, double side) {
    final c = _main;
    if (c == null || _scrub.value == null || side <= 0) return;
    final f = (_dragStartF + (d.globalPosition.dx - _dragStartX) / side)
        .clamp(0.0, .999);
    _scrub.value = f;
    final dur = c.value.duration;
    _time.value = VideoNoteTime(
      Duration(milliseconds: (dur.inMilliseconds * f).round()),
      dur,
      paused: true,
    );
    final now = DateTime.now();
    if (now.difference(_lastSeek) > const Duration(milliseconds: 60)) {
      _lastSeek = now;
      unawaited(c.seekTo(_time.value.position));
    }
  }

  void _scrubEnd() {
    final c = _main;
    final f = _scrub.value;
    _scrub.value = null;
    if (c == null || f == null) return;
    final target = Duration(
      milliseconds: (c.value.duration.inMilliseconds * f).round(),
    );
    _endHandled = false;
    // Как в макете: отпустил после перемотки — играет дальше с этого места.
    unawaited(c.seekTo(target).then((_) => c.play()));
  }

  void _onTap() {
    if (_scrubbed) {
      _scrubbed = false;
      return;
    }
    if (_enlarged) {
      _togglePause();
    } else {
      unawaited(_enlarge());
    }
  }

  // ─── Отрисовка ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final smallSide = widget.diameter ?? videoNoteSmallSide(media.size.width);
    final largeSide = videoNoteLargeSide(media.size);
    return VisibilityDetector(
      key: ValueKey<String>('vn-vis-$_id-${identityHashCode(this)}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        VideoNotePlayback.instance.reportVisibility(_id, info.visibleFraction);
      },
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => _MiniPlayerLayer(host: this),
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final t = _t.value;
            final leftPad = _lerp(widget.isMe ? 48 : 8, 12, t.clamp(0, 1));
            final rightPad = _lerp(widget.isMe ? 8 : 48, 12, t.clamp(0, 1));
            final maxSide = math.max(0.0, media.size.width - leftPad - rightPad);
            final side = math.min(_lerp(smallSide, largeSide, t), maxSide);
            final align = Alignment.lerp(
              widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
              Alignment.center,
              t.clamp(0, 1),
            )!;
            return Padding(
              padding: EdgeInsets.fromLTRB(leftPad, 2, rightPad, 2),
              child: Column(
                crossAxisAlignment: widget.isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  ?widget.header,
                  SizedBox(
                    width: double.infinity,
                    child: Align(alignment: align, child: _square(side, t)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: widget.footer,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _square(double side, double t) {
    final radius = videoNoteRadiusFor(side);
    final tt = t.clamp(0.0, 1.0);
    final shadow = tt > .01
        ? <BoxShadow>[
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, .5 * tt),
              blurRadius: 60 * tt,
              offset: Offset(0, 24 * tt),
            ),
          ]
        : null;
    return SizedBox(
      key: _squareKey,
      width: side,
      height: side,
      child: Semantics(
        button: true,
        label: _enlarged ? context.l10n.vnScrubHint : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          onHorizontalDragStart: _enlarged ? _scrubStart : null,
          onHorizontalDragUpdate: _enlarged ? (d) => _scrubUpdate(d, side) : null,
          onHorizontalDragEnd: _enlarged ? (_) => _scrubEnd() : null,
          onHorizontalDragCancel: _enlarged ? _scrubEnd : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: shadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(child: _surface()),
                    if (tt > .01)
                      IgnorePointer(
                        child: Opacity(
                          opacity: tt,
                          child: ValueListenableBuilder<VideoNoteTime>(
                            valueListenable: _time,
                            builder: (context, time, _) => CustomPaint(
                              painter: VideoNotePerimeterPainter(
                                fraction: time.fraction,
                                radius: radius,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_enlarged) _centerOverlay(),
                    if (_enlarged)
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Opacity(
                          opacity: tt,
                          child: _SpeedChip(
                            label:
                                '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}×'
                                    .replaceAll(
                                      '.',
                                      Localizations.localeOf(context).languageCode == 'en'
                                          ? '.'
                                          : ',',
                                    ),
                            onTap: _cycleSpeed,
                          ),
                        ),
                      ),
                    Positioned(
                      left: _lerp(10, 14, tt),
                      bottom: _lerp(10, 14, tt),
                      child: IgnorePointer(child: _badge()),
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

  Widget _surface() {
    final c = _enlarged && _mainReady
        ? _main
        : (_feedReady ? _feed : (_mainReady ? _main : null));
    if (c != null && c.value.isInitialized) {
      final s = c.value.size;
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: s.width <= 0 ? 1 : s.width,
          height: s.height <= 0 ? 1 : s.height,
          child: VideoPlayer(c),
        ),
      );
    }
    final poster = _posterFile;
    if (poster != null) {
      return Image.file(
        poster,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
      );
    }
    return VideoNoteStripes(
      isMe: widget.isMe,
      child: _failed
          ? const ChatMediaCircle(glyph: ChatMediaGlyph.retry)
          : const ChatMediaCircle(glyph: ChatMediaGlyph.none, ring: true),
    );
  }

  /// Пауза — кнопка ▶ 60 по центру; перемотка — время с шевронами.
  Widget _centerOverlay() {
    return IgnorePointer(
      child: ValueListenableBuilder<double?>(
        valueListenable: _scrub,
        builder: (context, scrub, _) {
          return ValueListenableBuilder<VideoNoteTime>(
            valueListenable: _time,
            builder: (context, time, _) {
              if (scrub != null) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xA60A0E13),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _VnIc.chevronLeft,
                          size: 20,
                          color: Colors.white.withValues(alpha: .7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatVideoNoteTime(time.position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [ui.FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _VnIc.chevronRight,
                          size: 20,
                          color: Colors.white.withValues(alpha: .7),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final paused = _mainReady && time.paused;
              return AnimatedOpacity(
                opacity: paused ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedScale(
                  scale: paused ? 1 : .85,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: Center(
                    child: ClipOval(
                      child: BackdropFilter(
                        enabled: defaultTargetPlatform == TargetPlatform.iOS,
                        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          width: 60,
                          height: 60,
                          color: const Color(0x8C0A0E13),
                          alignment: Alignment.center,
                          child: const Icon(_VnIc.play, size: 36, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _badge() {
    return ValueListenableBuilder<int>(
      valueListenable: VideoNoteWatched.instance.revision,
      builder: (context, _, _) {
        final unread =
            !_enlarged &&
            !widget.isMe &&
            !VideoNoteWatched.instance.isWatched(_id, widget.createdAtMs);
        if (_enlarged) {
          return ValueListenableBuilder<VideoNoteTime>(
            valueListenable: _time,
            builder: (context, time, _) => VideoNoteDurationTag(
              label: formatVideoNoteTime(time.position),
              icon: _VnIc.volumeOn,
            ),
          );
        }
        final d = Duration(milliseconds: widget.attachment.durationMs ?? 0);
        final dur = d > Duration.zero
            ? d
            : (_feed?.value.isInitialized ?? false)
            ? _feed!.value.duration
            : Duration.zero;
        return VideoNoteDurationTag(
          label: formatVideoNoteTime(dur),
          icon: _VnIc.volumeOff,
          unread: unread,
        );
      },
    );
  }
}

class _VnIc {
  static const IconData play = AdaptiveIconData(
    Icons.play_arrow_rounded,
    CupertinoIcons.play_fill,
  );
  static const IconData pause = AdaptiveIconData(
    Icons.pause_rounded,
    CupertinoIcons.pause_fill,
  );
  static const IconData volumeOn = AdaptiveIconData(
    Icons.volume_up_rounded,
    CupertinoIcons.speaker_2_fill,
  );
  static const IconData volumeOff = AdaptiveIconData(
    Icons.volume_off_rounded,
    CupertinoIcons.speaker_slash_fill,
  );
  static const IconData close = AdaptiveIconData(
    Icons.close_rounded,
    CupertinoIcons.xmark,
  );
  static const IconData chevronLeft = AdaptiveIconData(
    Icons.chevron_left_rounded,
    CupertinoIcons.chevron_left,
  );
  static const IconData chevronRight = AdaptiveIconData(
    Icons.chevron_right_rounded,
    CupertinoIcons.chevron_right,
  );
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // Зона касания 44 при видимой капсуле 28.
          padding: const EdgeInsets.all(8),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x990A0E13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: [ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Мини-плеер под шапкой чата: пауза, «Анна · видео-заметка», время,
/// закрыть. Без полосы прогресса — прогресс один, по контуру квадрата.
class _MiniPlayerLayer extends StatelessWidget {
  const _MiniPlayerLayer({required this.host});

  final VideoNoteSessionHost host;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final ctx = host.squareContext;
    final scaffold = ctx != null && ctx.mounted ? Scaffold.maybeOf(ctx) : null;
    final top = (scaffold?.appBarMaxHeight ?? (mq.padding.top + 64)) + 6;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xD11D2733) : const Color(0xEBFFFFFF);
    final ink = dark ? Colors.white : const Color(0xFF0E141B);
    final sub = dark ? const Color(0xFF8FA3B7) : const Color(0x9E0E141B);
    final accent = dark ? kVideoNoteAccent : const Color(0xFF1F7AE0);
    final glass = defaultTargetPlatform == TargetPlatform.iOS;
    Widget island = DecoratedBox(
      decoration: BoxDecoration(
        color: glass ? bg : bg.withValues(alpha: dark ? .96 : .98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark ? const Color(0x33FFFFFF) : const Color(0x140E141B),
          width: .5,
        ),
        boxShadow: dark
            ? null
            : const [BoxShadow(color: Color(0x1A0E141B), blurRadius: 18, offset: Offset(0, 4))],
      ),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ValueListenableBuilder<VideoNoteTime>(
            valueListenable: host.time,
            builder: (context, time, _) {
              return Row(
                children: [
                  _RoundButton(
                    tooltip: time.paused ? context.l10n.mvPlay : context.l10n.mvPause,
                    onTap: host.togglePause,
                    background: accent.withValues(alpha: .16),
                    child: Icon(
                      time.paused ? _VnIc.play : _VnIc.pause,
                      size: 20,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          host.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                        Text(
                          '${formatVideoNoteTime(time.position)} / ${formatVideoNoteTime(time.duration)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: sub,
                            fontFeatures: const [ui.FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RoundButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onTap: host.collapse,
                    child: Icon(_VnIc.close, size: 20, color: sub),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (glass) {
      island = ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: island,
        ),
      );
    }
    return Positioned(
      top: top,
      left: 8,
      right: 8,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        builder: (context, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, -10 * (1 - v)), child: child),
        ),
        child: Material(type: MaterialType.transparency, child: island),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.background,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 44,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: background, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Скругление квадрата в ленте (5a: 176 → 35).
const double kVideoNoteRadius = 35;

/// Полосатая подложка, пока кадра нет: у своих — синяя, у чужих —
/// графитовая.
class VideoNoteStripes extends StatelessWidget {
  const VideoNoteStripes({super.key, required this.isMe, this.child});

  final bool isMe;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StripesPainter(
        a: isMe ? const Color(0xFF1C4E7A) : const Color(0xFF26323F),
        b: isMe ? const Color(0xFF19466E) : const Color(0xFF212C38),
      ),
      child: Center(child: child),
    );
  }
}

class _StripesPainter extends CustomPainter {
  const _StripesPainter({required this.a, required this.b});

  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = a);
    // Полосы под 135° шагом 20 (10 + 10), как `repeating-linear-gradient`.
    final paint = Paint()..color = b;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final span = size.width + size.height;
    for (double x = -size.height; x < span; x += 20 * math.sqrt2) {
      final path = Path()
        ..moveTo(x + 10 * math.sqrt2, 0)
        ..lineTo(x + 20 * math.sqrt2, 0)
        ..lineTo(x + 20 * math.sqrt2 + size.height, size.height)
        ..lineTo(x + 10 * math.sqrt2 + size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripesPainter old) => old.a != a || old.b != b;
}

/// Ярлык макета 5a: капсула 24 `rgba(10,14,19,.6)`, значок 15, время 12/600 и
/// синяя точка 6×6, пока входящая заметка не просмотрена.
class VideoNoteDurationTag extends StatelessWidget {
  const VideoNoteDurationTag({
    super.key,
    required this.label,
    this.icon,
    this.unread = false,
  });

  final String label;
  final IconData? icon;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: EdgeInsets.fromLTRB(icon == null ? 8 : 7, 0, 8, 0),
      decoration: BoxDecoration(
        color: const Color(0x990A0E13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
              fontFeatures: [ui.FontFeature.tabularFigures()],
            ),
          ),
          if (unread) ...[
            const SizedBox(width: 5),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: kVideoNoteAccent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
