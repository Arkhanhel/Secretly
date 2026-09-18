// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

/// Wraps a single list item with a staggered fade+slide-up entrance animation.
///
/// Usage: Wrap each item in your `ListView.builder`:
/// ```dart
/// itemBuilder: (context, i) => StaggeredListItem(
///   index: i,
///   child: ListTile(...),
/// )
/// ```
class StaggeredListItem extends StatefulWidget {
  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = const Duration(milliseconds: 30),
    this.duration = const Duration(milliseconds: 280),
    this.slideOffset = 0.06,
  });

  final int index;
  final Widget child;
  final Duration baseDelay;
  final Duration duration;
  final double slideOffset;

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(curved);

    // Stagger: each item waits a bit longer.
    final delay = widget.baseDelay * widget.index.clamp(0, 12);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Animated FAB that fades and slides in from below.
class AnimatedFab extends StatefulWidget {
  const AnimatedFab({
    super.key,
    required this.child,
    this.visible = true,
    this.duration = const Duration(milliseconds: 560),
    this.delay = const Duration(milliseconds: 140),
    this.hiddenOffset = const Offset(0, 0.82),
  });

  final Widget child;
  final bool visible;
  final Duration duration;
  final Duration delay;
  final Offset hiddenOffset;

  @override
  State<AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<AnimatedFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: Duration(
        milliseconds: (widget.duration.inMilliseconds * 0.78).round(),
      ),
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.88, curve: Curves.easeOutCubic),
        reverseCurve: const Interval(0.0, 0.7, curve: Curves.easeInCubic),
      ),
    );

    _slide = Tween<Offset>(
      begin: widget.hiddenOffset,
      end: Offset.zero,
    ).animate(curved);

    Future.delayed(widget.delay, () {
      if (!mounted) return;
      if (widget.visible) {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AnimatedFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) {
      return;
    }
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.visible,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}

double mobileBottomNavSettingsFabShiftX(
  BuildContext context, {
  double navHorizontalInset = 10,
  int navItemCount = 5,
  double fabSize = 56,
  double endFloatMargin = 16,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final slotWidth = (screenWidth - (navHorizontalInset * 2)) / navItemCount;
  final settingsCenterX =
      navHorizontalInset + (slotWidth * (navItemCount - 0.5));
  final defaultFabCenterX = screenWidth - endFloatMargin - (fabSize / 2);
  return settingsCenterX - defaultFabCenterX;
}

/// Animated nav bar icon that scales/bounces on selection.
class AnimatedNavIcon extends StatelessWidget {
  const AnimatedNavIcon({
    super.key,
    required this.icon,
    required this.selected,
    required this.color,
    this.size = 23,
    this.duration = const Duration(milliseconds: 250),
  });

  final IconData icon;
  final bool selected;
  final Color color;
  final double size;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: selected ? 1.15 : 1.0),
      duration: duration,
      curve: selected ? Curves.elasticOut : Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Icon(icon, size: size, color: color),
    );
  }
}

/// Animated selection indicator (sliding pill) for the bottom nav bar.
class AnimatedNavIndicator extends StatelessWidget {
  const AnimatedNavIndicator({
    super.key,
    required this.selected,
    required this.color,
    this.width = 28,
    this.height = 3,
    this.duration = const Duration(milliseconds: 200),
  });

  final bool selected;
  final Color color;
  final double width;
  final double height;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      width: selected ? width : 0,
      height: height,
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

/// Smooth crossfade wrapper for tab body switching.
class AnimatedTabBody extends StatelessWidget {
  const AnimatedTabBody({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: child,
    );
  }
}
