// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/physics.dart';

import '../motion/motion.dart';
import '../widgets/app_background.dart';
import '../widgets/covered_route_media_freeze.dart';

/// Telegram-style page transitions for the entire app.
///
/// Usage: replace `MaterialPageRoute(builder: ...)` with
///   `SecretlyPageRoute(builder: ...)`
///
/// iOS/macOS: delegates to the native Cupertino transition (horizontal slide
/// with parallax + edge shadow). Mixing in [CupertinoRouteTransitionMixin] is
/// what makes the interactive edge-swipe back gesture work — the previous
/// implementation was a plain PageRouteBuilder, which has no back-gesture
/// detector, so swipe-back silently didn't exist anywhere in the app. During
/// a drag the transition is linear, tracking the finger 1:1.
///
/// Android: Telegram-Android-style transition — the incoming page slides in
/// fully OPAQUE from the right while the covered page parallaxes left under a
/// dim scrim. Deliberately NO full-page FadeTransitions: fading a whole opaque
/// page forces an offscreen saveLayer for each route on every frame of the
/// 320 ms push; an opaque slide + a foreground-rect scrim needs none. (Each
/// page still paints its own gradient via [AppGradientBackdrop], so the old
/// "background pop" cannot come back.)
class SecretlyPageRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T> {
  SecretlyPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
  });

  final WidgetBuilder builder;

  static final bool _useCupertino = Platform.isIOS || Platform.isMacOS;

  /// М4: переход экрана iPhone — пружина Telegram (ratio 1,0, отклик 0,3 с),
  /// после свайпа — ratio 0,85 со скоростью пальца; кривые Cupertino сверху
  /// не накладываются (иначе пружина «смазывается» второй кривой). Только
  /// iPhone: Mac остаётся на штатном переходе.
  static bool get _tgSpringIos =>
      kTelegramMotion && defaultTargetPlatform == TargetPlatform.iOS;

  /// М4: Android — как Telegram: 150 мс, сдвиг 48 dp + появление, нижний
  /// экран стоит на месте (без параллакса и затемнения).
  static bool get _tgAndroid =>
      kTelegramMotion && defaultTargetPlatform == TargetPlatform.android;

  @override
  AnimationController createAnimationController() {
    if (!_tgSpringIos || fullscreenDialog) {
      return super.createAnimationController();
    }
    return _SpringRouteController(
      duration: transitionDuration,
      reverseDuration: reverseTransitionDuration,
      debugLabel: debugLabel,
      vsync: navigator!,
    );
  }

  @override
  Widget buildContent(BuildContext context) => CoveredRouteMediaFreeze(
    // Закрытая другой страницей — не перестраивается от клавиатуры.
    child: AppGradientBackdrop(child: builder(context)),
  );

  @override
  String? get title => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => _useCupertino
      ? CupertinoRouteTransitionMixin.kTransitionDuration
      : (_tgAndroid && !fullscreenDialog
            ? const Duration(milliseconds: 150)
            : const Duration(milliseconds: 320));

  @override
  Duration get reverseTransitionDuration => _useCupertino
      ? CupertinoRouteTransitionMixin.kTransitionDuration
      : (_tgAndroid && !fullscreenDialog
            ? const Duration(milliseconds: 150)
            : const Duration(milliseconds: 300));

  // Parity with the old PageRouteBuilder behaviour: the covered route keeps
  // animating its outgoing leg for ANY page route pushed on top. The Cupertino
  // mixin's default would freeze the covered page when the next route is not
  // itself a Cupertino-mixin route (e.g. the few MaterialPageRoute pushes:
  // call screen, root shell).
  //
  // 🔴 22.11.2026: только НЕПРОЗРАЧНАЯ следующая страница. Прозрачные окна
  // поверх (меню реакций, просмотр медиа, редактор фото) — не переход на
  // другой экран: раньше страница чата под ними уезжала влево на треть
  // (iPhone — параллакс Cupertino, Android — сдвиг и затемнение).
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is PageRoute && nextRoute.opaque;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // popGestureInProgress → linear Cupertino transition tracking the finger.
    if (_useCupertino || popGestureInProgress) {
      final built = CupertinoRouteTransitionMixin.buildPageTransitions<T>(
        this,
        context,
        animation,
        secondaryAnimation,
        child,
      );
      // Пружина уже задаёт характер движения — переход идёт линейно по её
      // значению. Детектор свайпа назад (child штатного перехода) сохраняем.
      if (_tgSpringIos && !fullscreenDialog && built is CupertinoPageTransition) {
        return CupertinoPageTransition(
          primaryRouteAnimation: animation,
          secondaryRouteAnimation: secondaryAnimation,
          linearTransition: true,
          child: built.child,
        );
      }
      return built;
    }
    if (_tgAndroid && !fullscreenDialog) {
      return _TgAndroidPageTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    }
    return fullscreenDialog
        ? _buildAndroidFullscreenTransition(
            animation,
            secondaryAnimation,
            child,
          )
        : _buildAndroidTransition(animation, secondaryAnimation, child);
  }

  static final Animatable<Offset> _incomingSlide = Tween<Offset>(
    begin: const Offset(1.0, 0.0),
    end: Offset.zero,
  );
  static final Animatable<Offset> _outgoingParallax = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.30, 0.0),
  );
  static final Animatable<Offset> _incomingSlideUp = Tween<Offset>(
    begin: const Offset(0.0, 1.0),
    end: Offset.zero,
  );
  // Foreground rect scrim over the covered page — a plain alpha-rect draw,
  // no opacity layer.
  static final Animatable<Decoration> _coveredScrim = DecorationTween(
    begin: const BoxDecoration(color: Color(0x00000000)),
    end: const BoxDecoration(color: Color(0x47000000)),
  );

  static CurvedAnimation _curve(Animation<double> parent) => CurvedAnimation(
    parent: parent,
    curve: Motion.standard,
    reverseCurve: Curves.easeInCubic,
  );

  /// Push: incoming page slides in opaque from the right; when covered, the
  /// page parallaxes left behind a dim scrim (Telegram Android).
  static Widget _buildAndroidTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incoming = _curve(animation);
    final outgoing = _curve(secondaryAnimation);
    return SlideTransition(
      position: _outgoingParallax.animate(outgoing),
      child: DecoratedBoxTransition(
        position: DecorationPosition.foreground,
        decoration: _coveredScrim.animate(outgoing),
        child: SlideTransition(
          position: _incomingSlide.animate(incoming),
          child: child,
        ),
      ),
    );
  }

  /// Fullscreen dialog: slides up from the bottom; the covered page stays
  /// still and only dims.
  static Widget _buildAndroidFullscreenTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incoming = _curve(animation);
    final outgoing = _curve(secondaryAnimation);
    return DecoratedBoxTransition(
      position: DecorationPosition.foreground,
      decoration: _coveredScrim.animate(outgoing),
      child: SlideTransition(
        position: _incomingSlideUp.animate(incoming),
        child: child,
      ),
    );
  }
}

/// Full-screen dialog route — native Cupertino vertical modal on iOS, and a
/// Telegram-style opaque slide-up + scrim on Android. No back-swipe gesture
/// (correct for modals) — dismissal is via the close affordance / system back.
class SecretlyFullscreenRoute<T> extends SecretlyPageRoute<T> {
  SecretlyFullscreenRoute({required super.builder, super.settings})
    : super(fullscreenDialog: true);

  @override
  Duration get transitionDuration => SecretlyPageRoute._useCupertino
      ? CupertinoRouteTransitionMixin.kTransitionDuration
      : const Duration(milliseconds: 340);
}

/// Android Telegram (`ActionBarLayout.java`): новый экран за 150 мс
/// `DecelerateInterpolator(1.5)` (= `easeOutCubic`) выезжает на 48 dp и
/// проявляется; закрытие — то же в обратную сторону. Нижний экран не
/// двигается. Затемнение даёт штатный барьер маршрута.
class _TgAndroidPageTransition extends StatefulWidget {
  const _TgAndroidPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;

  /// Движение страницы, открытой поверх: нижняя страница стоит, но её
  /// растр тоже нужен каждый кадр — на это время она тоже картинка.
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<_TgAndroidPageTransition> createState() =>
      _TgAndroidPageTransitionState();
}

/// 🔴 Производительность: проявление ВСЕЙ страницы — это слой прозрачности
/// над ней, и каждый кадр перехода заново отрисовывал всё содержимое, в том
/// числе размытия стеклянных островков чата (на Xiaomi открытие чата
/// заметно «дёргалось»). Как в штатном переходе Flutter (Zoom), на время
/// движения страница один раз снимается в картинку ([SnapshotWidget]), и
/// двигается и проявляется уже картинка; по окончании — снова живая
/// страница. Есть platform view (видео) — снимок не делается (permissive).
class _TgAndroidPageTransitionState extends State<_TgAndroidPageTransition> {
  final SnapshotController _snapshot = SnapshotController();
  late CurvedAnimation _curved;

  static const double _shiftDp = 48;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(_TgAndroidPageTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation ||
        old.secondaryAnimation != widget.secondaryAnimation) {
      old.animation.removeStatusListener(_onStatus);
      old.secondaryAnimation.removeStatusListener(_onStatus);
      _curved.dispose();
      _bind();
    }
  }

  void _bind() {
    _curved = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    widget.animation.addStatusListener(_onStatus);
    widget.secondaryAnimation.addStatusListener(_onStatus);
    _onStatus(widget.animation.status);
  }

  void _onStatus(AnimationStatus _) {
    _snapshot.allowSnapshotting =
        widget.animation.status.isAnimating ||
        widget.secondaryAnimation.status.isAnimating;
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    widget.secondaryAnimation.removeStatusListener(_onStatus);
    _curved.dispose();
    _snapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return FadeTransition(
      opacity: _curved,
      child: AnimatedBuilder(
        animation: _curved,
        child: SnapshotWidget(
          controller: _snapshot,
          mode: SnapshotMode.permissive,
          child: widget.child,
        ),
        builder: (context, child) => Transform.translate(
          offset: Offset((rtl ? -1 : 1) * _shiftDp * (1 - _curved.value), 0),
          child: child,
        ),
      ),
    );
  }
}

/// Контроллер маршрута, который вместо «длительность + кривая» ведёт
/// переход пружиной Telegram. Свайп назад двигает `value` пальцем — по этим
/// шагам считаем скорость, и доводка после отпускания продолжает движение
/// пальца (ratio 0,85), а не начинает с нуля.
class _SpringRouteController extends AnimationController {
  _SpringRouteController({
    super.duration,
    super.reverseDuration,
    super.debugLabel,
    required super.vsync,
  });

  final Stopwatch _clock = Stopwatch()..start();
  int _lastSetMicros = -1000000000;
  double _fingerVelocity = 0;

  static const Tolerance _tolerance = Tolerance(distance: 0.001, velocity: 0.01);

  @override
  set value(double newValue) {
    final now = _clock.elapsedMicroseconds;
    final dt = (now - _lastSetMicros) / 1e6;
    if (dt > 0 && dt < 0.1) {
      final v = (newValue - super.value) / dt;
      _fingerVelocity = 0.6 * v + 0.4 * _fingerVelocity;
    } else {
      _fingerVelocity = 0;
    }
    _lastSetMicros = now;
    super.value = newValue;
  }

  TickerFuture _springTo(double target) {
    final fromFinger =
        !isAnimating && _clock.elapsedMicroseconds - _lastSetMicros < 100000;
    final v = isAnimating ? velocity : (fromFinger ? _fingerVelocity : 0.0);
    final spring = fromFinger
        ? MotionSprings.afterSwipe
        : MotionSprings.navigation;
    final start = value;
    stop();
    final sim = SpringSimulation(
      spring,
      start,
      target,
      v,
      tolerance: _tolerance,
    );
    // Назад — когда цель ниже, или когда уже стоим на нуле (pop готовой
    // страницы): иначе статус был бы «completed», и маршрут не закрылся бы.
    final back = target < start || (target == start && target == lowerBound);
    return back ? animateBackWith(sim) : animateWith(sim);
  }

  @override
  TickerFuture forward({double? from}) {
    if (from != null) super.value = from;
    return _springTo(upperBound);
  }

  @override
  TickerFuture reverse({double? from}) {
    if (from != null) super.value = from;
    return _springTo(lowerBound);
  }

  @override
  TickerFuture animateTo(
    double target, {
    Duration? duration,
    Curve curve = Curves.linear,
  }) => _springTo(target);

  @override
  TickerFuture animateBack(
    double target, {
    Duration? duration,
    Curve curve = Curves.linear,
  }) => _springTo(target);
}
