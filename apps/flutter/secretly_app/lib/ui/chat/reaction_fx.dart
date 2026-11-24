// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Анимация реакций (макет «Reactions Animation», новая версия, 21.11.2026).
///
/// 1. Открытие: фон размывается (сообщение остаётся резким в вырезе, с
///    тенью «приподнято»), панель вырастает пружиной, эмодзи — каскадом,
///    пункты меню — лесенкой.
/// 2. Выбор: остальные эмодзи схлопываются от выбранного к краям, меню уходит.
/// 3. Полёт: эмодзи летит по дуге к сообщению и вырастает до 96.
/// 4. Приземление: эмодзи играет крупно, вокруг — свой эффект
///    ([reactionBurstFor]).
/// 5. Посадка: эмодзи сжимается в чип, чип пружинит и даёт кольцо-импульс.
///
/// Снятие реакции: чип сжимается и гаснет, место под ним закрывается.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/island_backdrop.dart' show PanelPrefs;
import 'reaction_burst.dart';
import 'route_bound_fx.dart';
import 'video_note_playback.dart' show VideoNotePlayback;

/// Что сейчас происходит с чипом своей реакции.
enum ReactionChipFx {
  /// Эмодзи летит к чипу — знак в чипе скрыт.
  waiting,

  /// Эмодзи сел — чип пружинит, кольцо-импульс.
  landed,

  /// Реакцию снимают — чип сжимается и гаснет.
  removing,
}

/// Общая доска эффектов чипов: меню и полёт пишут, чипы в ленте читают.
/// Ключ — `событие|эмодзи` (как у меток проигрывания реакций).
class ReactionFxRegistry {
  ReactionFxRegistry._();
  static final ReactionFxRegistry instance = ReactionFxRegistry._();

  final ValueNotifier<Map<String, ReactionChipFx>> fx = ValueNotifier(
    const {},
  );
  final Map<String, GlobalKey> _keys = {};

  static String id(String eventId, String emoji) => '$eventId|$emoji';

  ReactionChipFx? of(String id) => fx.value[id];

  void set(String id, ReactionChipFx f) {
    fx.value = {...fx.value, id: f};
  }

  void clear(String id) {
    if (!fx.value.containsKey(id)) return;
    fx.value = {...fx.value}..remove(id);
    _keys.remove(id);
  }

  /// Ключ знака в чипе — цель полёта. Выдаётся только пока эффект идёт
  /// (один чип на ключ — без конфликтов глобальных ключей).
  GlobalKey? keyFor(String id) =>
      fx.value.containsKey(id) ? _keys.putIfAbsent(id, GlobalKey.new) : null;

  /// Где сейчас знак в чипе (в координатах экрана).
  Rect? glyphRect(String id) {
    final box = _keys[id]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Чип: знак скрыт в полёте, пружина и кольцо при посадке, сжатие при снятии
// ═══════════════════════════════════════════════════════════════════════════

/// Обёртка чипа своей реакции.
class ReactionChipFxScope extends StatefulWidget {
  const ReactionChipFxScope({
    super.key,
    required this.fxId,
    required this.ringColor,
    required this.child,
  });

  final String fxId;
  final Color ringColor;
  final Widget child;

  @override
  State<ReactionChipFxScope> createState() => _ReactionChipFxScopeState();
}

class _ReactionChipFxScopeState extends State<ReactionChipFxScope>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 440),
    value: 1,
  );
  late final AnimationController _remove = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  ReactionChipFx? _last;

  @override
  void initState() {
    super.initState();
    ReactionFxRegistry.instance.fx.addListener(_onFx);
    final now = ReactionFxRegistry.instance.of(widget.fxId);
    if (now == ReactionChipFx.waiting) {
      // Новый чип во время полёта — вырастает пружиной.
      _appear.value = 0;
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _appear.forward();
      });
    }
    _last = now;
  }

  void _onFx() {
    final now = ReactionFxRegistry.instance.of(widget.fxId);
    if (now == _last) return;
    _last = now;
    if (now == ReactionChipFx.landed) {
      _pulse.forward(from: 0);
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (ReactionFxRegistry.instance.of(widget.fxId) ==
            ReactionChipFx.landed) {
          ReactionFxRegistry.instance.clear(widget.fxId);
        }
      });
    } else if (now == ReactionChipFx.removing) {
      _remove.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ReactionFxRegistry.instance.fx.removeListener(_onFx);
    _pulse.dispose();
    _appear.dispose();
    _remove.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _appear, _remove]),
      child: widget.child,
      builder: (context, child) {
        // Посадка: 1 → 1,18 → 0,97 → 1 за 460 мс.
        final t = (_pulse.value * 520 / 460).clamp(0.0, 1.0);
        final pulse = _pulse.isAnimating || _pulse.value > 0 && t < 1
            ? (t < 0.3
                  ? 1 + 0.18 * Curves.easeOut.transform(t / 0.3)
                  : t < 0.65
                  ? 1.18 - 0.21 * Curves.easeInOut.transform((t - 0.3) / 0.35)
                  : 0.97 + 0.03 * Curves.easeOut.transform((t - 0.65) / 0.35))
            : 1.0;
        final appear = const ReactionSpringCurve().transform(_appear.value);
        final removeT = const Cubic(0.5, 0, 0.75, 0).transform(_remove.value);
        final scale =
            pulse * (0.3 + 0.7 * appear) * (1 - 0.8 * removeT);
        final opacity = (_appear.value * (1 - removeT)).clamp(0.0, 1.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: opacity,
              child: Transform.scale(scale: scale, child: child),
            ),
            if (_pulse.isAnimating)
              Positioned.fill(
                child: IgnorePointer(
                  child: Transform.scale(
                    scaleX: 1 + 0.3 * _pulse.value,
                    scaleY: 1 + 0.8 * _pulse.value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: widget.ringColor.withValues(
                            alpha: 0.9 * (1 - _pulse.value),
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Знак в чипе своей реакции: скрыт, пока эмодзи летит; при посадке —
/// пружинка 0,5 → 1. Даёт ключ — цель полёта.
class ReactionGlyphFxScope extends StatefulWidget {
  const ReactionGlyphFxScope({
    super.key,
    required this.fxId,
    required this.child,
  });

  final String fxId;
  final Widget child;

  @override
  State<ReactionGlyphFxScope> createState() => _ReactionGlyphFxScopeState();
}

class _ReactionGlyphFxScopeState extends State<ReactionGlyphFxScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  ReactionChipFx? _last;

  @override
  void initState() {
    super.initState();
    _last = ReactionFxRegistry.instance.of(widget.fxId);
    ReactionFxRegistry.instance.fx.addListener(_onFx);
  }

  void _onFx() {
    final now = ReactionFxRegistry.instance.of(widget.fxId);
    if (now == _last) return;
    if (now == ReactionChipFx.landed) _pop.forward(from: 0);
    _last = now;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ReactionFxRegistry.instance.fx.removeListener(_onFx);
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fx = ReactionFxRegistry.instance.of(widget.fxId);
    final key = ReactionFxRegistry.instance.keyFor(widget.fxId);
    return KeyedSubtree(
      key: key,
      child: AnimatedBuilder(
        animation: _pop,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: fx == ReactionChipFx.waiting ? 0 : 1,
          child: Transform.scale(
            scale:
                0.5 + 0.5 * const ReactionSpringCurve().transform(_pop.value),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Полёт, приземление, посадка
// ═══════════════════════════════════════════════════════════════════════════

/// Большой эмодзи полёта: `play` — проиграть анимацию (после приземления).
typedef ReactionEmojiBuilder =
    Widget Function(String emoji, double size, bool play);

/// Запустить полёт реакции поверх всего (корневой Overlay).
///
/// [start] — откуда (эмодзи в панели), [bubble] — сообщение (для точки
/// приземления, пока чипа ещё нет), [fxId] — чип-цель.
void launchReactionFlight({
  required BuildContext context,
  required String emoji,
  required Rect start,
  required Rect? bubble,
  required String fxId,
  required ReactionEmojiBuilder emojiBuilder,
  bool haptics = true,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  // Н-10: полёт привязан к экрану чата — закрыли чат посреди полёта, и он
  // снимается, а не доигрывает поверх списка чатов.
  final route = ModalRoute.of(context);
  final registry = ReactionFxRegistry.instance;
  registry.set(fxId, ReactionChipFx.waiting);
  late OverlayEntry entry;
  void remove() {
    if (entry.mounted) entry.remove();
  }
  entry = OverlayEntry(
    builder: (_) => RouteBoundFx(
      route: route,
      onCancel: () {
        // Чип не должен остаться спрятанным «в ожидании» полёта.
        registry.clear(fxId);
        remove();
      },
      child: ReactionFlight(
        emoji: emoji,
        start: start,
        bubble: bubble,
        fxId: fxId,
        emojiBuilder: emojiBuilder,
        haptics: haptics,
        onDone: remove,
      ),
    ),
  );
  overlay.insert(entry);
}

class ReactionFlight extends StatefulWidget {
  const ReactionFlight({
    super.key,
    required this.emoji,
    required this.start,
    required this.bubble,
    required this.fxId,
    required this.emojiBuilder,
    required this.onDone,
    this.haptics = true,
  });

  final String emoji;
  final Rect start;
  final Rect? bubble;
  final String fxId;
  final ReactionEmojiBuilder emojiBuilder;
  final VoidCallback onDone;
  final bool haptics;

  @override
  State<ReactionFlight> createState() => _ReactionFlightState();
}

class _ReactionFlightState extends State<ReactionFlight>
    with TickerProviderStateMixin {
  static const double _big = 96;
  static const double _hold = 1150;
  static const double _settle = 380;

  late final double _flight;
  late final bool _down;
  late final AnimationController _c;
  late final AnimationController _burst;
  late final List<ReactionParticle> _particles;
  late final double _burstMs;
  late Offset _land;
  late Offset _from;
  late Offset _ctrl;
  Offset? _target;
  bool _landed = false;
  bool _settling = false;

  @override
  void initState() {
    super.initState();
    final meta = reactionMeta(widget.emoji);
    _down = meta.fallsDown;
    _flight = _down ? 560 : 520;
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_flight + _hold + _settle).round()),
    );
    _particles = reactionBurstFor(widget.emoji);
    _burstMs = reactionBurstDuration(_particles);
    _burst = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _burstMs.round().clamp(1, 4000)),
    );
    _from = widget.start.center;
    _land = _landingPoint();
    _ctrl = Offset(
      (_from.dx + _land.dx) / 2 + (_land.dx > _from.dx ? -24 : 24),
      math.min(_from.dy, _land.dy) - (_down ? 150 : 85),
    );
    _c.addListener(_tick);
    _c.forward().whenComplete(_finish);
  }

  Offset _landingPoint() {
    final screen = WidgetsBinding.instance.platformDispatcher.views.first;
    final w = screen.physicalSize.width / screen.devicePixelRatio;
    final t = ReactionFxRegistry.instance.glyphRect(widget.fxId)?.center ??
        (widget.bubble == null
            ? widget.start.center + const Offset(0, 120)
            : Offset(widget.bubble!.left + 22, widget.bubble!.bottom - 14));
    return Offset((t.dx + 34).clamp(70.0, w - 70), t.dy - 54);
  }

  void _tick() {
    final ms = _c.value * (_flight + _hold + _settle);
    if (!_landed && ms >= _flight) {
      _landed = true;
      if (widget.haptics) {
        unawaited(
          (reactionMeta(widget.emoji).landing == ReactionLanding.squash
                  ? HapticFeedback.lightImpact
                  : HapticFeedback.mediumImpact)(),
        );
      }
      _burst.forward(from: 0);
    }
    if (!_settling && ms >= _flight + _hold) {
      _settling = true;
      // Цель — где чип СЕЙЧАС (лента могла сдвинуться).
      _target = ReactionFxRegistry.instance.glyphRect(widget.fxId)?.center;
    }
    setState(() {});
  }

  void _finish() {
    final registry = ReactionFxRegistry.instance;
    if (_target != null) {
      registry.set(widget.fxId, ReactionChipFx.landed);
    } else {
      registry.clear(widget.fxId);
    }
    // Эффект доигрывает и после посадки.
    final left = (_burstMs - (_hold + _settle)).clamp(0.0, 4000.0);
    Future<void>.delayed(Duration(milliseconds: left.round()), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _burst.dispose();
    super.dispose();
  }

  /// Положение и масштаб большого эмодзи.
  (Offset, double, double) _pose(double ms) {
    final s0 = math.max(0.2, widget.start.width * 0.85 / _big);
    if (ms < _flight) {
      final p = (_down ? const Cubic(0.5, 0, 0.9, 0.6) : const Cubic(0.4, 0, 0.2, 1))
          .transform(ms / _flight);
      final u = 1 - p;
      final pos =
          _from * (u * u) + _ctrl * (2 * u * p) + _land * (p * p);
      final sc = s0 + (1 - s0) * (1 - math.pow(1 - p, 2));
      return (pos, sc.toDouble(), 1);
    }
    if (ms < _flight + _hold) return (_land, 1, 1);
    final p = const Cubic(0.55, 0, 0.25, 1)
        .transform(((ms - _flight - _hold) / _settle).clamp(0.0, 1.0));
    final target = _target;
    if (target == null) return (_land, 1 - 0.3 * p, 1 - p);
    return (
      Offset.lerp(_land, target, p)!,
      1 + (18 / _big - 1) * p,
      1,
    );
  }

  /// Своя «игра» эмодзи после приземления (по макету).
  Matrix4 _inner(double ms) {
    final t = ms - _flight;
    final m = Matrix4.identity();
    if (t < 0) return m;
    final e = widget.emoji;
    double seg(double d) => (t / d).clamp(0.0, 1.0);
    switch (e) {
      case '😂':
      case '🤣':
        final k = seg(1000);
        m.rotateZ(math.sin(k * math.pi * 5) * (1 - k) * 0.18);
      case '😱':
      case '🥶':
        final k = seg(800);
        m.translateByDouble(k < 1 ? (math.sin(k * 60) * 3) : 0, 0, 0, 1);
      case '👏':
        final k = seg(620);
        m.scaleByDouble(1 + 0.14 * math.sin(k * math.pi * 3).abs(), 1 + 0.14 * math.sin(k * math.pi * 3).abs(), 1, 1);
      case '👀':
        final k = seg(1100);
        final x = k < 0.2
            ? -10 * k / 0.2
            : k < 0.45
            ? -10.0
            : k < 0.65
            ? -10 + 20 * (k - 0.45) / 0.2
            : k < 0.85
            ? 10.0
            : 10 * (1 - (k - 0.85) / 0.15);
        m.translateByDouble(x, 0, 0, 1);
      case '🚀':
        final k = seg(1000);
        final y = k < 0.15
            ? 10 * k / 0.15
            : k < 0.45
            ? 10 - 50 * (k - 0.15) / 0.3
            : -40 * (1 - (k - 0.45) / 0.55);
        m.translateByDouble(0, y, 0, 1);
      default:
        final meta = reactionMeta(e);
        final d = meta.landing == ReactionLanding.heavy ? 520.0 : 440.0;
        final k = seg(d);
        final (sx, sy) = switch (meta.landing) {
          ReactionLanding.heavy => (1.24, 0.74),
          ReactionLanding.boom => (1.3, 1.3),
          ReactionLanding.squash => (1.16, 0.86),
        };
        double ax, ay;
        if (k < 0.22) {
          final q = Curves.easeOut.transform(k / 0.22);
          ax = 1 + (sx - 1) * q;
          ay = 1 + (sy - 1) * q;
        } else if (k < 0.5) {
          final q = (k - 0.22) / 0.28;
          ax = sx + (0.93 - sx) * q;
          ay = sy + (1.08 - sy) * q;
        } else if (k < 0.75) {
          final q = (k - 0.5) / 0.25;
          ax = 0.93 + 0.10 * q;
          ay = 1.08 - 0.10 * q;
        } else {
          final q = (k - 0.75) / 0.25;
          ax = 1.03 - 0.03 * q;
          ay = 0.98 + 0.02 * q;
        }
        m.scaleByDouble(ax, ay, 1, 1);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final ms = _c.value * (_flight + _hold + _settle);
    var (pos, scale, opacity) = _pose(ms);
    // 🔴 23.11.2026 (владелец: «реакция как будто дублируется»): эмодзи сел
    // в чип — большой исчезает. Раньше он оставался поверх знака в чипе,
    // пока доигрывал эффект вокруг (у 💯 — секунды), и было видно два.
    if (_c.isCompleted) opacity = 0;
    return IgnorePointer(
      child: Stack(
        children: [
          if (_landed)
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _burst,
                  builder: (context, _) => CustomPaint(
                    painter: ReactionBurstPainter(
                      particles: _particles,
                      ms: _burst.value * _burstMs,
                      origin: _land,
                    ),
                  ),
                ),
              ),
            ),
          if (opacity > 0.01)
            Positioned(
              left: pos.dx - _big / 2,
              top: pos.dy - _big / 2,
              width: _big,
              height: _big,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: _inner(ms),
                    child: KeyedSubtree(
                      key: ValueKey(_landed),
                      child: widget.emojiBuilder(widget.emoji, _big, _landed),
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

// ═══════════════════════════════════════════════════════════════════════════
//   Меню: размытие с вырезом под сообщение, пружины и каскады
// ═══════════════════════════════════════════════════════════════════════════

/// Анимация открытия меню (общая для всех частей).
class ReactionMenuMotion extends InheritedWidget {
  const ReactionMenuMotion({
    super.key,
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  static Animation<double> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ReactionMenuMotion>()
          ?.animation ??
      kAlwaysCompleteAnimation;

  @override
  bool updateShouldNotify(ReactionMenuMotion old) =>
      old.animation != animation;
}

/// Полная длина открытия (мс): последний эмодзи каскада успевает сесть.
const double kReactionMenuOpenMs = 820;

/// Часть меню, появляющаяся по своему расписанию: задержка [delayMs],
/// длительность [ms], из сдвига [from] и масштаба [scaleFrom].
class ReactionMenuEntrance extends StatelessWidget {
  const ReactionMenuEntrance({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.ms = 480,
    this.from = Offset.zero,
    this.scaleFrom = const Offset(1, 1),
    this.alignment = Alignment.center,
    this.spring = true,
  });

  final Widget child;
  final double delayMs;
  final double ms;
  final Offset from;
  final Offset scaleFrom;
  final Alignment alignment;
  final bool spring;

  @override
  Widget build(BuildContext context) {
    final parent = ReactionMenuMotion.of(context);
    final a = (delayMs / kReactionMenuOpenMs).clamp(0.0, 1.0);
    final b = ((delayMs + ms) / kReactionMenuOpenMs).clamp(a, 1.0);
    final curved = CurvedAnimation(
      parent: parent,
      curve: Interval(
        a,
        b,
        curve: spring ? const ReactionSpringCurve() : Curves.easeOutCubic,
      ),
      reverseCurve: const Interval(0, 1, curve: Curves.easeInCubic),
    );
    final fade = CurvedAnimation(
      parent: parent,
      curve: Interval(a, (a + (b - a) * 0.45).clamp(a, 1.0)),
      reverseCurve: Curves.easeIn,
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final t = curved.value;
        return Opacity(
          opacity: fade.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: from * (1 - t),
            child: Transform(
              alignment: alignment,
              transform: Matrix4.diagonal3Values(
                scaleFrom.dx + (1 - scaleFrom.dx) * t,
                scaleFrom.dy + (1 - scaleFrom.dy) * t,
                1,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Схлопывание эмодзи панели после выбора: от выбранного к краям.
class ReactionCollapse extends StatefulWidget {
  const ReactionCollapse({
    super.key,
    required this.collapsing,
    required this.distance,
    required this.child,
    this.hidden = false,
  });

  /// Выбор сделан — схлопнуться.
  final bool collapsing;

  /// Расстояние (в ячейках) от выбранного: задержка 24 мс на ячейку.
  final int distance;

  /// Это и есть выбранный — он улетел, тут пусто.
  final bool hidden;
  final Widget child;

  @override
  State<ReactionCollapse> createState() => _ReactionCollapseState();
}

class _ReactionCollapseState extends State<ReactionCollapse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void didUpdateWidget(covariant ReactionCollapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsing && !oldWidget.collapsing) {
      Future<void>.delayed(Duration(milliseconds: widget.distance * 24), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hidden) return Opacity(opacity: 0, child: widget.child);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = const Cubic(0.5, 0, 0.75, 0).transform(_c.value);
        return Opacity(
          opacity: 1 - t,
          child: Transform.scale(scale: 1 - 0.7 * t, child: child),
        );
      },
    );
  }
}

/// Фон меню: размытие и затемнение, сообщение — резко в вырезе, с тенью
/// «приподнято».
class ReactionMenuBackdrop extends StatelessWidget {
  const ReactionMenuBackdrop({
    super.key,
    required this.animation,
    required this.hole,
    this.blur = true,
  });

  final Animation<double> animation;
  final Rect? hole;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 260 / kReactionMenuOpenMs, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        Widget layer = ColoredBox(
          color: Color.fromRGBO(8, 12, 18, 0.42 * v),
        );
        if (blur && v > 0.01) {
          layer = BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10 * v, sigmaY: 10 * v),
            child: layer,
          );
        }
        final h = hole;
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipPath(clipper: _HoleClipper(h), child: layer),
            if (h != null)
              IgnorePointer(
                child: CustomPaint(
                  painter: _LiftShadowPainter(hole: h, t: v),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HoleClipper extends CustomClipper<Path> {
  _HoleClipper(this.hole);
  final Rect? hole;

  @override
  Path getClip(Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final h = hole;
    if (h == null) return all;
    return Path.combine(
      PathOperation.difference,
      all,
      Path()..addRRect(RRect.fromRectAndRadius(h, const Radius.circular(18))),
    );
  }

  @override
  bool shouldReclip(_HoleClipper old) => old.hole != hole;
}

class _LiftShadowPainter extends CustomPainter {
  _LiftShadowPainter({required this.hole, required this.t});
  final Rect hole;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0.01) return;
    final rr = RRect.fromRectAndRadius(hole, const Radius.circular(18));
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(rr),
      ),
    );
    canvas.drawRRect(
      rr.shift(const Offset(0, 6)),
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, 0.38 * t)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiftShadowPainter old) =>
      old.t != t || old.hole != hole;
}

/// Открыть меню реакций: свой переход (фон с вырезом, пружины). Части меню
/// берут анимацию через [ReactionMenuMotion] и [ReactionMenuEntrance].
/// Открытие — 820 мс (каскад успевает сесть), закрытие — 300 мс.
Future<T?> showReactionMenu<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required Rect? bubble,
  bool blur = true,
}) {
  // Кружки в ленте под меню стоят; размытие — только при «Размытии
  // панелей» (разбор 22.11.2026).
  final resumeFeed = VideoNotePlayback.instance.suspendFeed();
  blur = blur && PanelPrefs.frostedEnabled.value;
  return Navigator.of(context, rootNavigator: true).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      // 🔴 22.11.2026: окно поверх, а не новая страница. Без этого переход
      // iPhone (CupertinoRouteTransitionMixin) сдвигал страницу чата под
      // меню влево на треть — как при уходе на следующий экран.
      fullscreenDialog: true,
      barrierDismissible: true,
      // Диктор читает «Закрыть», а не служебное слово.
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: Duration(milliseconds: kReactionMenuOpenMs.round()),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondary, child) => child,
      pageBuilder: (context, animation, secondaryAnimation) => Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: ReactionMenuBackdrop(
              animation: animation,
              hole: bubble,
              blur: blur,
            ),
          ),
          ReactionMenuMotion(
            animation: animation,
            child: Builder(builder: builder),
          ),
        ],
      ),
    ),
  ).whenComplete(resumeFeed);
}

/// Появление на монтировании с задержкой (ячейки раскрытой панели).
class ReactionDelayedPop extends StatefulWidget {
  const ReactionDelayedPop({
    super.key,
    required this.delayMs,
    required this.child,
    this.ms = 420,
    this.scaleFrom = 0.3,
    this.from = Offset.zero,
  });

  final double delayMs;
  final double ms;
  final double scaleFrom;
  final Offset from;
  final Widget child;

  @override
  State<ReactionDelayedPop> createState() => _ReactionDelayedPopState();
}

class _ReactionDelayedPopState extends State<ReactionDelayedPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.ms.round()),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.delayMs.round()), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = const ReactionSpringCurve().transform(_c.value);
        return Opacity(
          opacity: (_c.value * 2.2).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: widget.from * (1 - t),
            child: Transform.scale(
              scale: widget.scaleFrom + (1 - widget.scaleFrom) * t,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
