// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Видео в просмотре (макет «Просмотр медиа», раздел «Видео»).
///
/// Живой плеер — только у текущей страницы: соседи показывают кадр-превью.
/// Так листание не держит в памяти три декодера, а Android не теряет кадры.
/// Начинается само; звук и скорость запоминаются на всё время просмотра.
/// Панель: ▶/❚❚, время, дорожка 4 px с бегунком 12 (при перетаскивании
/// ×1,35), длительность, скорость 1× → 1,5× → 2× → 0,5×, звук.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../media/progressive_playback.dart';
import 'media_viewer_tokens.dart';

/// Скорости по кругу.
const List<double> kMediaVideoSpeeds = <double>[1.0, 1.5, 2.0, 0.5];

double nextMediaVideoSpeed(double current) {
  final i = kMediaVideoSpeeds.indexWhere((s) => (s - current).abs() < 0.01);
  return kMediaVideoSpeeds[(i + 1) % kMediaVideoSpeeds.length];
}

/// «1,5×» с десятичным знаком языка.
String mediaVideoSpeedLabel(double speed, String decimalSeparator) {
  final whole = speed == speed.roundToDouble();
  final text = whole ? speed.toInt().toString() : speed.toString();
  return '${text.replaceAll('.', decimalSeparator)}×';
}

/// «1:05» / «1:02:05».
String formatMediaTime(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// Плеер текущей страницы.
class MediaViewerVideo with WidgetsBindingObserver {
  /// Полный файл на диске. [startAt] — продолжить с места (после плеера по
  /// ходу скачивания).
  MediaViewerVideo({
    required File file,
    required bool muted,
    required double speed,
    Duration? startAt,
  }) : this._(
         file: file,
         server: null,
         controller: VideoPlayerController.file(file),
         muted: muted,
         speed: speed,
         startAt: startAt,
       );

  /// В-2: ролик ещё качается — плеер читает его с локального HTTP
  /// ([LoopbackMediaServer]), который ждёт расшифровки нужных байтов.
  MediaViewerVideo.progressive({
    required LoopbackMediaServer server,
    required bool muted,
    required double speed,
  }) : this._(
         file: null,
         server: server,
         controller: VideoPlayerController.networkUrl(server.url),
         muted: muted,
         speed: speed,
         startAt: null,
       );

  MediaViewerVideo._({
    required this.file,
    required this.server,
    required this.controller,
    required bool muted,
    required double speed,
    required Duration? startAt,
  }) {
    WidgetsBinding.instance.addObserver(this);
    _muted = muted;
    _speed = speed;
    _init = controller.initialize().then((_) async {
      if (_disposed) return;
      await controller.setLooping(false);
      await controller.setVolume(_muted ? 0 : 1);
      await controller.setPlaybackSpeed(_speed);
      if (startAt != null && startAt > Duration.zero) {
        await controller.seekTo(startAt);
      }
      if (_disposed) return;
      ready.value = true;
    }).catchError((Object _) {
      if (!_disposed) failed.value = true;
    });
    controller.addListener(_onTick);
  }

  /// Полный файл; `null` — играет по ходу скачивания ([server]).
  final File? file;

  /// В-2: локальный источник, пока ролик качается.
  final LoopbackMediaServer? server;
  bool get isProgressive => server != null;
  final VideoPlayerController controller;
  late final Future<void> _init;
  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  final ValueNotifier<bool> failed = ValueNotifier<bool>(false);

  /// Досмотрено до конца — вместо ▶ знак «снова».
  final ValueNotifier<bool> ended = ValueNotifier<bool>(false);

  /// Человек хочет, чтобы играло (может временно не играть: перемотка,
  /// шторка, редактор, свёрнутое приложение).
  final ValueNotifier<bool> wantPlay = ValueNotifier<bool>(true);
  bool _muted = false;
  double _speed = 1;
  bool _scrubbing = false;
  bool _blocked = false;
  bool _disposed = false;
  bool _wasPlaying = false;

  bool get muted => _muted;
  double get speed => _speed;

  void _onTick() {
    final v = controller.value;
    // Ошибка посреди игры (у плеера по ходу скачивания — оборвалась связь
    // с локальным источником): просмотр переходит на полный файл.
    if (v.hasError && !failed.value && !_disposed) failed.value = true;
    if (!v.isInitialized) return;
    final atEnd =
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 60) &&
        !v.isPlaying;
    if (atEnd && !ended.value) {
      ended.value = true;
      wantPlay.value = false;
    }
    if (_wasPlaying != v.isPlaying) _wasPlaying = v.isPlaying;
  }

  /// Подогнать «играть / не играть» под желание и помехи.
  Future<void> sync() async {
    await _init;
    if (_disposed || !ready.value) return;
    final should = wantPlay.value && !_scrubbing && !_blocked;
    final v = controller.value;
    if (should && !v.isPlaying) {
      await controller.play();
    } else if (!should && v.isPlaying) {
      await controller.pause();
    }
  }

  /// Помеха (шторка, редактор, перелёт): пауза, но желание помнится.
  set blocked(bool v) {
    if (_blocked == v) return;
    _blocked = v;
    unawaited(sync());
  }

  Future<void> togglePlay() async {
    await _init;
    if (_disposed) return;
    if (wantPlay.value && controller.value.isPlaying) {
      wantPlay.value = false;
    } else {
      if (ended.value ||
          controller.value.position >=
              controller.value.duration - const Duration(milliseconds: 60)) {
        await controller.seekTo(Duration.zero);
      }
      ended.value = false;
      wantPlay.value = true;
    }
    await sync();
  }

  Future<void> seekBy(Duration delta) async {
    await _init;
    if (_disposed) return;
    final v = controller.value;
    var t = v.position + delta;
    final max = v.duration - const Duration(milliseconds: 50);
    if (t < Duration.zero) t = Duration.zero;
    if (max > Duration.zero && t > max) t = max;
    ended.value = false;
    await controller.seekTo(t);
  }

  void beginScrub() {
    _scrubbing = true;
    unawaited(sync());
  }

  Future<void> scrubTo(double fraction) async {
    final d = controller.value.duration;
    if (d <= Duration.zero) return;
    ended.value = false;
    await controller.seekTo(
      Duration(milliseconds: (d.inMilliseconds * fraction.clamp(0, 1)).round()),
    );
  }

  void endScrub() {
    _scrubbing = false;
    unawaited(sync());
  }

  Future<void> setMuted(bool v) async {
    _muted = v;
    await _init;
    if (!_disposed) await controller.setVolume(v ? 0 : 1);
  }

  Future<void> cycleSpeed() async {
    _speed = nextMediaVideoSpeed(_speed);
    await _init;
    if (!_disposed) await controller.setPlaybackSpeed(_speed);
  }

  // 🔴 Play Vitals (15.11.2026): кадр видео не должен приходить в движок,
  // отсоединённый от окна. Уходя в фон — пауза.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        unawaited(controller.pause());
      }
    } else if (state == AppLifecycleState.resumed) {
      unawaited(sync());
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_onTick);
    unawaited(controller.dispose());
    // Сервер закрывает все соединения; файл не трогает.
    unawaited(server?.close());
    ready.dispose();
    failed.dispose();
    ended.dispose();
    wantPlay.dispose();
  }
}

/// Поверхность видео (contain), поверх — превью, пока нет первого кадра.
class MediaViewerVideoSurface extends StatelessWidget {
  const MediaViewerVideoSurface({
    super.key,
    required this.video,
    required this.poster,
  });

  final MediaViewerVideo video;
  final Widget poster;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: video.ready,
      builder: (context, ready, _) {
        if (!ready) return poster;
        final a = video.controller.value.aspectRatio;
        return Center(
          child: AspectRatio(
            aspectRatio: a > 0 && a.isFinite ? a : 16 / 9,
            child: VideoPlayer(video.controller),
          ),
        );
      },
    );
  }
}

/// Панель видео (bottom 146, высота 44, радиус 22).
class MediaViewerVideoPanel extends StatefulWidget {
  const MediaViewerVideoPanel({
    super.key,
    required this.video,
    required this.tokens,
    required this.island,
    required this.playLabel,
    required this.pauseLabel,
    required this.replayLabel,
    required this.speedLabel,
    required this.muteLabel,
    required this.unmuteLabel,
    required this.icons,
    required this.onInteract,
  });

  final MediaViewerVideo video;
  final MediaViewerTokens tokens;

  /// Остров (стекло или сплошной) — строит просмотр.
  final Widget Function({required BorderRadius radius, required Widget child})
  island;
  final String playLabel, pauseLabel, replayLabel, speedLabel;
  final String muteLabel, unmuteLabel;
  final MediaVideoIcons icons;

  /// Любое касание панели — продлить показ оформления.
  final VoidCallback onInteract;

  @override
  State<MediaViewerVideoPanel> createState() => _MediaViewerVideoPanelState();
}

@immutable
class MediaVideoIcons {
  const MediaVideoIcons({
    required this.play,
    required this.pause,
    required this.replay,
    required this.volumeOn,
    required this.volumeOff,
  });

  final IconData play, pause, replay, volumeOn, volumeOff;
}

class _MediaViewerVideoPanelState extends State<MediaViewerVideoPanel> {
  final ValueNotifier<double?> _scrub = ValueNotifier<double?>(null);

  @override
  void dispose() {
    _scrub.dispose();
    super.dispose();
  }

  void _scrubAt(Offset local, double width) {
    if (width <= 0) return;
    final f = (local.dx / width).clamp(0.0, 1.0);
    _scrub.value = f;
    unawaited(widget.video.scrubTo(f));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final v = widget.video;
    final dec = Localizations.localeOf(context).languageCode == 'en' ? '.' : ',';
    const tabular = <FontFeature>[FontFeature.tabularFigures()];
    // С-11: панель фиксированной высоты 44 — крупный шрифт не больше 1,3×.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: widget.island(
      radius: BorderRadius.circular(22),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: v.controller,
            builder: (context, value, _) {
              final d = value.duration;
              final playing = value.isPlaying;
              return Row(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: v.ended,
                    builder: (context, ended, _) {
                      final icon = playing
                          ? widget.icons.pause
                          : ended
                          ? widget.icons.replay
                          : widget.icons.play;
                      final label = playing
                          ? widget.pauseLabel
                          : ended
                          ? widget.replayLabel
                          : widget.playLabel;
                      return _PanelButton(
                        width: 36,
                        tooltip: label,
                        onTap: () {
                          widget.onInteract();
                          unawaited(v.togglePlay());
                        },
                        child: Icon(icon, size: 26, color: t.ink),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<double?>(
                    valueListenable: _scrub,
                    builder: (context, scrub, _) {
                      final pos = scrub != null && d > Duration.zero
                          ? Duration(
                              milliseconds: (d.inMilliseconds * scrub).round(),
                            )
                          : value.position;
                      return ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 30),
                        child: Text(
                          formatMediaTime(pos),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: t.ink,
                            fontFeatures: tabular,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final w = c.maxWidth;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (e) {
                            widget.onInteract();
                            v.beginScrub();
                            _scrubAt(e.localPosition, w);
                          },
                          onHorizontalDragUpdate: (e) =>
                              _scrubAt(e.localPosition, w),
                          onHorizontalDragEnd: (_) {
                            _scrub.value = null;
                            v.endScrub();
                          },
                          onHorizontalDragCancel: () {
                            _scrub.value = null;
                            v.endScrub();
                          },
                          onTapDown: (e) {
                            widget.onInteract();
                            v.beginScrub();
                            _scrubAt(e.localPosition, w);
                          },
                          onTapUp: (_) {
                            _scrub.value = null;
                            v.endScrub();
                          },
                          onTapCancel: () {
                            if (_scrub.value != null) return;
                            v.endScrub();
                          },
                          child: SizedBox(
                            height: 44,
                            child: ValueListenableBuilder<double?>(
                              valueListenable: _scrub,
                              builder: (context, scrub, _) {
                                final f = scrub ??
                                    (d > Duration.zero
                                        ? (value.position.inMilliseconds /
                                                  d.inMilliseconds)
                                              .clamp(0.0, 1.0)
                                        : 0.0);
                                return CustomPaint(
                                  painter: _TrackPainter(
                                    fraction: f,
                                    track: t.track,
                                    ink: t.ink,
                                    knobScale: scrub != null ? 1.35 : 1,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 30),
                    child: Text(
                      formatMediaTime(d),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.sub,
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: widget.speedLabel,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        widget.onInteract();
                        unawaited(v.cycleSpeed().then((_) {
                          if (mounted) setState(() {});
                        }));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Container(
                          height: 26,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.chip,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text(
                            mediaVideoSpeedLabel(v.speed, dec),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: t.ink,
                              fontFeatures: tabular,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _PanelButton(
                    width: 32,
                    tooltip: v.muted ? widget.unmuteLabel : widget.muteLabel,
                    onTap: () {
                      widget.onInteract();
                      unawaited(v.setMuted(!v.muted).then((_) {
                        if (mounted) setState(() {});
                      }));
                    },
                    child: Icon(
                      v.muted ? widget.icons.volumeOff : widget.icons.volumeOn,
                      size: 22,
                      color: t.ink,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.width,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final double width;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(width: width, height: 44, child: Center(child: child)),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.fraction,
    required this.track,
    required this.ink,
    required this.knobScale,
  });

  final double fraction;
  final Color track;
  final Color ink;
  final double knobScale;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final r = RRect.fromLTRBR(0, y - 2, size.width, y + 2, const Radius.circular(2));
    canvas.drawRRect(r, Paint()..color = track);
    final x = size.width * fraction;
    canvas.drawRRect(
      RRect.fromLTRBR(0, y - 2, x, y + 2, const Radius.circular(2)),
      Paint()..color = ink,
    );
    canvas.drawCircle(Offset(x, y), 6 * knobScale, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.fraction != fraction ||
      old.knobScale != knobScale ||
      old.track != track ||
      old.ink != ink;
}
