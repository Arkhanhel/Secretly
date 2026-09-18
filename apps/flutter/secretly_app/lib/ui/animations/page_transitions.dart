// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';

import '../widgets/app_background.dart';

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

  @override
  Widget buildContent(BuildContext context) =>
      AppGradientBackdrop(child: builder(context));

  @override
  String? get title => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => _useCupertino
      ? CupertinoRouteTransitionMixin.kTransitionDuration
      : const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => _useCupertino
      ? CupertinoRouteTransitionMixin.kTransitionDuration
      : const Duration(milliseconds: 300);

  // Parity with the old PageRouteBuilder behaviour: the covered route keeps
  // animating its outgoing leg for ANY page route pushed on top. The Cupertino
  // mixin's default would freeze the covered page when the next route is not
  // itself a Cupertino-mixin route (e.g. the few MaterialPageRoute pushes:
  // call screen, root shell).
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is PageRoute;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // popGestureInProgress → linear Cupertino transition tracking the finger.
    if (_useCupertino || popGestureInProgress) {
      return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
        this,
        context,
        animation,
        secondaryAnimation,
        child,
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
    curve: Curves.easeOutCubic,
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
