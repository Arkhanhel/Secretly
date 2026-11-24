// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Воспроизведение видео-заметок в чате (макет «Video Notes», 5a, 22.11.2026).
///
/// Общий распорядитель на весь чат:
///   * одна раскрытая заметка за раз — открыл другую, прежняя свернулась;
///   * пока заметка раскрыта, остальная лента приглушена до 35 %
///     ([VideoNoteDim]), касание мимо квадрата сворачивает её
///     ([VideoNoteOutsideTap]) и НЕ открывает меню того, по чему попали;
///   * в ленте без звука по кругу играют не больше двух самых видимых заметок
///     — остальные показывают кадр (плееры дороги, особенно на Android);
///   * «просмотрено» запоминается на устройстве; синяя точка — у входящих,
///     ещё не просмотренных; заметки старше первого запуска этой сборки
///     считаются просмотренными (иначе после обновления точки зажглись бы на
///     всей истории);
///   * цепочка: досмотрел — через 380 мс раскрывается следующая
///     непросмотренная входящая заметка ниже.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Пружина раскрытия и сворачивания: 450 мс, лёгкий перелёт.
const Cubic kVideoNoteSpring = Cubic(.2, .9, .25, 1.08);
const Duration kVideoNoteSpringDuration = Duration(milliseconds: 450);

/// Акцент контура и точки «не просмотрено».
const Color kVideoNoteAccent = Color(0xFF7FD0FF);

/// Сторона квадрата в ленте (5a): 176, на узком экране — меньше.
double videoNoteSmallSide(double screenWidth) =>
    math.min(176.0, screenWidth * 0.47);

/// Раскрытый квадрат: почти во всю ширину с зазором 12 по краям, но не выше
/// 62 % экрана (горизонтальный телефон, маленький экран).
double videoNoteLargeSide(Size screen) =>
    math.max(0.0, math.min(screen.width - 24, screen.height * 0.62));

/// Скругление — 20 % стороны (176 → 35, 288 → 58).
double videoNoteRadiusFor(double side) => side * 0.2;

/// Что умеет раскрытая заметка (для мини-плеера и распорядителя).
abstract interface class VideoNoteSessionHost {
  String get noteId;
  String get title;
  BuildContext? get squareContext;
  ValueListenable<VideoNoteTime> get time;
  bool get isPaused;
  void togglePause();
  void collapse();
}

@immutable
class VideoNoteTime {
  const VideoNoteTime(this.position, this.duration, {this.paused = false});

  static const VideoNoteTime zero = VideoNoteTime(Duration.zero, Duration.zero);
  final Duration position;
  final Duration duration;
  final bool paused;

  double get fraction {
    final d = duration.inMilliseconds;
    if (d <= 0) return 0;
    return (position.inMilliseconds / d).clamp(0.0, 1.0);
  }
}

/// Заметка в ленте — для цепочки и ленты без звука.
abstract interface class VideoNoteFeedClient {
  String get noteId;
  int get createdAtMs;
  bool get isMe;
  void setFeedLive(bool live);
  void openFromChain();
}

class VideoNotePlayback {
  VideoNotePlayback._();

  static final VideoNotePlayback instance = VideoNotePlayback._();

  /// Раскрытая заметка (null — нет).
  final ValueNotifier<VideoNoteSessionHost?> active =
      ValueNotifier<VideoNoteSessionHost?>(null);

  // ─── Одна раскрытая ───────────────────────────────────────────────────────

  void activate(VideoNoteSessionHost host) {
    final prev = active.value;
    if (prev != null && !identical(prev, host)) prev.collapse();
    active.value = host;
    _chainTimer?.cancel();
    _recomputeFeed();
  }

  void deactivate(VideoNoteSessionHost host) {
    if (identical(active.value, host)) active.value = null;
    _recomputeFeed();
  }

  /// Свернуть раскрытую (звук другого трека, уход с экрана).
  bool collapseActive() {
    final a = active.value;
    if (a == null) return false;
    a.collapse();
    return true;
  }

  // ─── Касание мимо ─────────────────────────────────────────────────────────

  DateTime? _swallowUntil;

  /// Касание, которое свернуло заметку, не должно ещё и открыть меню
  /// сообщения: чат спрашивает здесь перед своей обработкой касания.
  bool takeSwallowedTap() {
    final until = _swallowUntil;
    _swallowUntil = null;
    return until != null && DateTime.now().isBefore(until);
  }

  // ─── Лента без звука ──────────────────────────────────────────────────────

  /// Сколько заметок одновременно играют в ленте.
  static const int maxFeedPlayers = 2;

  final Map<String, VideoNoteFeedClient> _clients =
      <String, VideoNoteFeedClient>{};
  final Map<String, double> _visible = <String, double>{};
  final Set<String> _live = <String>{};

  /// Выключить ленту без звука (меньше движения, тесты).
  bool feedAutoplayEnabled = true;

  /// Сколько «перекрытий» сейчас над лентой: меню реакций, просмотр медиа,
  /// запись кружка. Пока > 0 — лента без звука стоит (разбор 22.11.2026:
  /// заметки играли под ними — камера, два декодера и полноэкранное
  /// размытие в каждом кадре на слабом Android).
  int _suspended = 0;

  /// Перекрыть ленту; вызвать возвращённую функцию, когда перекрытие ушло.
  VoidCallback suspendFeed() {
    _suspended++;
    _recomputeFeed();
    var done = false;
    return () {
      if (done) return;
      done = true;
      if (_suspended > 0) _suspended--;
      _recomputeFeed();
    };
  }

  void register(VideoNoteFeedClient c) => _clients[c.noteId] = c;

  void unregister(VideoNoteFeedClient c) {
    if (!identical(_clients[c.noteId], c)) return;
    _clients.remove(c.noteId);
    _visible.remove(c.noteId);
    _live.remove(c.noteId);
    _recomputeFeed();
  }

  /// Видимая доля заметки изменилась.
  void reportVisibility(String id, double fraction) {
    if (fraction <= 0.01) {
      _visible.remove(id);
    } else {
      _visible[id] = fraction;
    }
    _recomputeFeed();
  }

  void _recomputeFeed() {
    final want = <String>{};
    if (feedAutoplayEnabled && active.value == null && _suspended == 0) {
      final ranked = _visible.entries.where((e) => e.value >= .5).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in ranked.take(maxFeedPlayers)) {
        want.add(e.key);
      }
    }
    for (final id in _live.difference(want).toList()) {
      _live.remove(id);
      _clients[id]?.setFeedLive(false);
    }
    for (final id in want.difference(_live)) {
      final c = _clients[id];
      if (c == null) continue;
      _live.add(id);
      c.setFeedLive(true);
    }
  }

  // ─── Цепочка ──────────────────────────────────────────────────────────────

  Timer? _chainTimer;

  /// Досмотрена заметка [id] — через 380 мс раскрыть следующую
  /// непросмотренную входящую ниже (новее).
  void scheduleChainAfter(String id) {
    final cur = _clients[id];
    if (cur == null) return;
    VideoNoteFeedClient? next;
    for (final c in _clients.values) {
      if (c.isMe || c.noteId == id) continue;
      if (c.createdAtMs <= cur.createdAtMs) continue;
      if (VideoNoteWatched.instance.isWatched(c.noteId, c.createdAtMs)) {
        continue;
      }
      if (next == null || c.createdAtMs < next.createdAtMs) next = c;
    }
    final target = next;
    if (target == null) return;
    _chainTimer?.cancel();
    _chainTimer = Timer(const Duration(milliseconds: 380), () {
      if (identical(_clients[target.noteId], target) && active.value == null) {
        target.openFromChain();
      }
    });
  }

  @visibleForTesting
  void resetForTest() {
    _chainTimer?.cancel();
    active.value = null;
    _clients.clear();
    _visible.clear();
    _live.clear();
    _swallowUntil = null;
    feedAutoplayEnabled = true;
  }
}

/// «Просмотрено» — на устройстве, только для синей точки и цепочки.
class VideoNoteWatched {
  VideoNoteWatched._();

  static final VideoNoteWatched instance = VideoNoteWatched._();

  static const String _kIds = 'video_note_watched_v1';
  static const String _kSince = 'video_note_watched_since_v1';
  static const int _cap = 3000;

  final LinkedHashSet<String> _ids = LinkedHashSet<String>();
  int? _sinceMs;
  Future<void>? _load;
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<void> ensureLoaded() => _load ??= () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ids.addAll(prefs.getStringList(_kIds) ?? const <String>[]);
      var since = prefs.getInt(_kSince);
      if (since == null) {
        since = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(_kSince, since);
      }
      _sinceMs = since;
    } catch (_) {
      _sinceMs ??= DateTime.now().millisecondsSinceEpoch;
    }
    revision.value++;
  }();

  /// Не загружено — считаем просмотренной (точка не мигнёт зря).
  bool isWatched(String id, int createdAtMs) {
    final since = _sinceMs;
    if (since == null) return true;
    if (createdAtMs < since) return true;
    return _ids.contains(id);
  }

  Future<void> markWatched(String id) async {
    if (_ids.contains(id)) return;
    _ids.add(id);
    while (_ids.length > _cap) {
      _ids.remove(_ids.first);
    }
    revision.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kIds, _ids.toList(growable: false));
    } catch (_) {
      // Не записалось — точка вернётся после перезапуска, не страшно.
    }
  }

  @visibleForTesting
  void resetForTest({int? sinceMs}) {
    _ids.clear();
    _sinceMs = sinceMs;
    _load = sinceMs == null ? null : Future<void>.value();
    revision.value++;
  }
}

/// Приглушение остальной ленты, пока заметка раскрыта (35 %, 300 мс).
/// Строку, внутри которой раскрытая заметка, не приглушает.
class VideoNoteDim extends StatefulWidget {
  const VideoNoteDim({super.key, required this.child});

  final Widget child;

  @override
  State<VideoNoteDim> createState() => _VideoNoteDimState();
}

class _VideoNoteDimState extends State<VideoNoteDim> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoNoteSessionHost?>(
      valueListenable: VideoNotePlayback.instance.active,
      child: widget.child,
      builder: (context, host, child) {
        var dim = false;
        if (host != null) {
          final ctx = host.squareContext;
          final owner = ctx != null && ctx.mounted
              ? ctx.findAncestorStateOfType<_VideoNoteDimState>()
              : null;
          dim = !identical(owner, this);
        }
        return AnimatedOpacity(
          opacity: dim ? .35 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease,
          child: child,
        );
      },
    );
  }
}

/// Касание мимо раскрытого квадрата сворачивает его (обёртка ленты).
class VideoNoteOutsideTap extends StatefulWidget {
  const VideoNoteOutsideTap({super.key, required this.child});

  final Widget child;

  @override
  State<VideoNoteOutsideTap> createState() => _VideoNoteOutsideTapState();
}

class _VideoNoteOutsideTapState extends State<VideoNoteOutsideTap> {
  Offset? _down;
  DateTime? _downAt;

  bool _insideSquare(Offset global) {
    final ctx = VideoNotePlayback.instance.active.value?.squareContext;
    final box = ctx != null && ctx.mounted ? ctx.findRenderObject() : null;
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(global);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        final pb = VideoNotePlayback.instance;
        if (pb.active.value == null || _insideSquare(e.position)) {
          _down = null;
          return;
        }
        _down = e.position;
        _downAt = DateTime.now();
        // Касание по другому сообщению только сворачивает заметку.
        pb._swallowUntil = DateTime.now().add(const Duration(milliseconds: 700));
      },
      onPointerMove: (e) {
        final d = _down;
        if (d != null && (e.position - d).distance > 8) {
          // Это прокрутка, а не касание.
          _down = null;
          VideoNotePlayback.instance._swallowUntil = null;
        }
      },
      onPointerUp: (e) {
        final d = _down, at = _downAt;
        _down = null;
        if (d == null || at == null) return;
        if (DateTime.now().difference(at) > const Duration(milliseconds: 500)) {
          VideoNotePlayback.instance._swallowUntil = null;
          return;
        }
        VideoNotePlayback.instance.collapseActive();
      },
      onPointerCancel: (_) {
        _down = null;
        VideoNotePlayback.instance._swallowUntil = null;
      },
      child: widget.child,
    );
  }
}

/// Прогресс по контуру скруглённого квадрата: старт сверху посередине, по
/// часовой. Один-единственный указатель воспроизведения (без полосы снизу и
/// без второй в мини-плеере — так понятнее).
class VideoNotePerimeterPainter extends CustomPainter {
  VideoNotePerimeterPainter({
    required this.fraction,
    required this.radius,
    this.strokeWidth = 3.5,
    this.color = kVideoNoteAccent,
    this.trackColor = const Color(0x33FFFFFF),
  });

  final double fraction;
  final double radius;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2 + 1;
    final r = math.max(0.0, radius - inset);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
      Radius.circular(r),
    );
    final path = Path()..addRRect(rrect);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..isAntiAlias = true
        ..color = trackColor,
    );
    final f = fraction.clamp(0.0, 1.0);
    if (f <= 0) return;
    final metric = path.computeMetrics().first;
    final len = metric.length;
    // addRRect начинает с левого конца верхней прямой — сдвиг к середине.
    final start = (rrect.width - 2 * r) / 2;
    final length = f * len;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..color = color;
    final to = start + length;
    if (to <= len) {
      canvas.drawPath(metric.extractPath(start, to), p);
    } else {
      canvas.drawPath(metric.extractPath(start, len), p);
      canvas.drawPath(metric.extractPath(0, to - len), p);
    }
  }

  @override
  bool shouldRepaint(VideoNotePerimeterPainter old) =>
      old.fraction != fraction ||
      old.radius != radius ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

String formatVideoNoteTime(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}
