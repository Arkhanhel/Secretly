// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/physics.dart';
import 'package:flutter/material.dart';

/// A spring simulation helper for snap-to-target animations.
///
/// Used for PiP snap-to-corner and reply-swipe return.
class SpringAnimationHelper {
  SpringAnimationHelper._();

  /// Default spring description — snappy but not too stiff.
  static const SpringDescription defaultSpring = SpringDescription(
    mass: 1.0,
    stiffness: 350.0,
    damping: 25.0,
  );

  /// Softer spring for larger movements (PiP snap).
  static const SpringDescription pipSpring = SpringDescription(
    mass: 1.0,
    stiffness: 220.0,
    damping: 22.0,
  );

  /// Stiff spring for small, fast returns (reply swipe).
  static const SpringDescription swipeSpring = SpringDescription(
    mass: 1.0,
    stiffness: 500.0,
    damping: 30.0,
  );

  /// Creates a spring simulation from [start] to [end] with optional [velocity].
  static SpringSimulation simulation({
    required double start,
    required double end,
    double velocity = 0.0,
    SpringDescription spring = defaultSpring,
  }) {
    return SpringSimulation(spring, start, end, velocity);
  }
}

/// Manages an [AnimationController] with spring physics for 2D offset animations.
///
/// Useful for PiP snap-to-corner and similar drag-then-snap patterns.
mixin SpringOffsetMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  AnimationController? _springXCtrl;
  AnimationController? _springYCtrl;

  /// Call in initState to prepare the spring controllers.
  void initSpringOffset() {
    _springXCtrl = AnimationController.unbounded(vsync: this);
    _springYCtrl = AnimationController.unbounded(vsync: this);
  }

  /// Disposes spring controllers. Call in dispose().
  void disposeSpringOffset() {
    _springXCtrl?.dispose();
    _springYCtrl?.dispose();
  }

  /// Animate from current offset to [target] using spring physics.
  void animateToOffset(
    Offset target, {
    Offset currentVelocity = Offset.zero,
    required Offset current,
    required void Function(Offset) onUpdate,
    SpringDescription spring = SpringAnimationHelper.pipSpring,
  }) {
    final simX = SpringAnimationHelper.simulation(
      start: current.dx,
      end: target.dx,
      velocity: currentVelocity.dx,
      spring: spring,
    );
    final simY = SpringAnimationHelper.simulation(
      start: current.dy,
      end: target.dy,
      velocity: currentVelocity.dy,
      spring: spring,
    );

    _springXCtrl!.animateWith(simX);
    _springYCtrl!.animateWith(simY);

    void listener() {
      onUpdate(Offset(_springXCtrl!.value, _springYCtrl!.value));
    }

    _springXCtrl!.addListener(listener);
    _springYCtrl!.addListener(listener);

    // Clean up listeners when animation completes
    void cleanup(AnimationStatus status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _springXCtrl?.removeListener(listener);
        _springYCtrl?.removeListener(listener);
        _springXCtrl?.removeStatusListener(cleanup);
        _springYCtrl?.removeStatusListener(cleanup);
      }
    }

    _springXCtrl!.addStatusListener(cleanup);
    _springYCtrl!.addStatusListener(cleanup);
  }
}
