// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Перелёт миниатюра ↔ просмотр (макет «Просмотр медиа», «Открытие /
/// закрытие»).
///
/// Не Hero: Hero лишь меняет прямоугольник, а миниатюра в ленте — это
/// обрезка «cover» полного кадра. Здесь снимок летит в своём слое: обрезка
/// миниатюры плавно раскрывается до полного кадра, скругление уходит в ноль.
///
/// [MediaFlightAnchor] — обёртка вокруг миниатюры (ячейка альбома, фото в
/// чате, плитка галереи профиля, аватар). Она сообщает своё место на экране
/// и прячется (прозрачность 0), пока её снимок открыт в просмотре.
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Поза летящего слоя относительно прямоугольника «contain» F.
@immutable
class FlightPose {
  const FlightPose({
    required this.translate,
    required this.scale,
    required this.clip,
    required this.radius,
    this.opacity = 1,
  });

  final Offset translate;
  final double scale;

  /// Обрезка в несжатых пикселях F.
  final EdgeInsets clip;

  /// Скругление в несжатых пикселях F (углы: лв, пв, пн, лн).
  final BorderRadius radius;
  final double opacity;

  static const FlightPose identity = FlightPose(
    translate: Offset.zero,
    scale: 1,
    clip: EdgeInsets.zero,
    radius: BorderRadius.zero,
  );

  /// Поза «в миниатюре» T (прототип `thumbTf`).
  factory FlightPose.toThumb(Rect f, Rect t, BorderRadius thumbRadius) {
    final s = (t.width / f.width) > (t.height / f.height)
        ? t.width / f.width
        : t.height / f.height;
    final ix = (f.width - t.width / s) / 2, iy = (f.height - t.height / s) / 2;
    Radius r(Radius x) => Radius.elliptical(x.x / s, x.y / s);
    return FlightPose(
      translate: Offset(t.left - f.left - s * ix, t.top - f.top - s * iy),
      scale: s,
      clip: EdgeInsets.symmetric(horizontal: ix, vertical: iy),
      radius: BorderRadius.only(
        topLeft: r(thumbRadius.topLeft),
        topRight: r(thumbRadius.topRight),
        bottomRight: r(thumbRadius.bottomRight),
        bottomLeft: r(thumbRadius.bottomLeft),
      ),
    );
  }

  /// Поза открытого снимка, уменьшенного на [scale] вокруг центра F и
  /// сдвинутого на [offset] (приближение или смахивание).
  factory FlightPose.centered(Size f, double scale, Offset offset) =>
      FlightPose(
        translate: Offset(
          (1 - scale) * f.width / 2 + offset.dx,
          (1 - scale) * f.height / 2 + offset.dy,
        ),
        scale: scale,
        clip: EdgeInsets.zero,
        radius: BorderRadius.zero,
      );

  /// Миниатюры нет на экране: тает, уменьшаясь до 0,92 от нынешнего.
  /// [f] — размер F, чтобы уменьшение шло вокруг центра снимка.
  FlightPose fadedOut(Size f) => FlightPose(
    translate: Offset(
      translate.dx + (1 - .92) * scale * f.width / 2,
      translate.dy + (1 - .92) * scale * f.height / 2,
    ),
    scale: scale * .92,
    clip: clip,
    radius: radius,
    opacity: 0,
  );

  /// Запасное появление без миниатюры: снизу на 30 px, 0,94, прозрачность 0.
  static const FlightPose appear = FlightPose(
    translate: Offset(0, 30),
    scale: .94,
    clip: EdgeInsets.zero,
    radius: BorderRadius.zero,
    opacity: 0,
  );

  static FlightPose lerp(FlightPose a, FlightPose b, double t) => FlightPose(
    translate: Offset.lerp(a.translate, b.translate, t)!,
    scale: lerpDouble(a.scale, b.scale, t)!,
    clip: EdgeInsets.lerp(a.clip, b.clip, t)!,
    radius: BorderRadius.lerp(a.radius, b.radius, t)!,
    opacity: lerpDouble(a.opacity, b.opacity, t)!,
  );
}

/// Летящий слой: кладётся в Stack просмотра; [fit] — прямоугольник F.
class MediaFlightLayer extends StatelessWidget {
  const MediaFlightLayer({
    super.key,
    required this.pose,
    required this.fit,
    required this.child,
  });

  final FlightPose pose;
  final Rect fit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = pose;
    return Positioned(
      left: fit.left,
      top: fit.top,
      width: fit.width,
      height: fit.height,
      child: IgnorePointer(
        child: Opacity(
          opacity: p.opacity.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.topLeft,
            transform: Matrix4.identity()
              ..translateByDouble(p.translate.dx, p.translate.dy, 0, 1)
              ..scaleByDouble(p.scale, p.scale, 1, 1),
            child: ClipPath(
              clipper: _InsetRRectClipper(p.clip, p.radius),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _InsetRRectClipper extends CustomClipper<Path> {
  _InsetRRectClipper(this.inset, this.radius);

  final EdgeInsets inset;
  final BorderRadius radius;

  @override
  Path getClip(Size size) => Path()
    ..addRRect(radius.toRRect(inset.deflateRect(Offset.zero & size)));

  @override
  bool shouldReclip(_InsetRRectClipper old) =>
      old.inset != inset || old.radius != radius;
}

/// Место миниатюры на экране для перелёта.
@immutable
class MediaAnchorGeometry {
  const MediaAnchorGeometry(this.rect, this.radius);

  final Rect rect;
  final BorderRadius radius;
}

/// Реестр миниатюр и «какая сейчас открыта».
class MediaFlightAnchors {
  MediaFlightAnchors._();

  static final Map<Object, List<_MediaFlightAnchorState>> _byTag =
      <Object, List<_MediaFlightAnchorState>>{};

  /// Миниатюра, которая сейчас открыта в просмотре (скрыта в ленте).
  static final ValueNotifier<Object?> hidden = ValueNotifier<Object?>(null);

  /// Где миниатюра [tag] на экране (только если она в маршруте [route] — тот,
  /// что под просмотром, — и хоть краешком видна). null — лететь некуда.
  static MediaAnchorGeometry? geometryOf(
    Object tag, {
    ModalRoute<Object?>? route,
    required Size screen,
  }) {
    final list = _byTag[tag];
    if (list == null || list.isEmpty) return null;
    for (final s in list.reversed) {
      if (!s.mounted) continue;
      if (route != null && s.route != null && !identical(s.route, route)) {
        continue;
      }
      final box = s.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final size = box.size;
      if (size.width < 2 || size.height < 2) continue;
      final r = box.localToGlobal(Offset.zero) & size;
      if (r.bottom < 0 || r.top > screen.height) continue;
      if (r.right < 0 || r.left > screen.width) continue;
      return MediaAnchorGeometry(r, s.widget.borderRadius);
    }
    return null;
  }

  static void _add(Object tag, _MediaFlightAnchorState s) =>
      (_byTag[tag] ??= <_MediaFlightAnchorState>[]).add(s);

  static void _remove(Object tag, _MediaFlightAnchorState s) {
    final list = _byTag[tag];
    if (list == null) return;
    list.remove(s);
    if (list.isEmpty) _byTag.remove(tag);
  }
}

/// Миниатюра-точка перелёта. [borderRadius] — её скругление на экране.
class MediaFlightAnchor extends StatefulWidget {
  const MediaFlightAnchor({
    super.key,
    required this.tag,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final Object tag;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<MediaFlightAnchor> createState() => _MediaFlightAnchorState();
}

class _MediaFlightAnchorState extends State<MediaFlightAnchor> {
  ModalRoute<Object?>? route;

  @override
  void initState() {
    super.initState();
    MediaFlightAnchors._add(widget.tag, this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    route = ModalRoute.of(context);
  }

  @override
  void didUpdateWidget(covariant MediaFlightAnchor old) {
    super.didUpdateWidget(old);
    if (old.tag != widget.tag) {
      MediaFlightAnchors._remove(old.tag, this);
      MediaFlightAnchors._add(widget.tag, this);
    }
  }

  @override
  void dispose() {
    MediaFlightAnchors._remove(widget.tag, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Object?>(
      valueListenable: MediaFlightAnchors.hidden,
      child: widget.child,
      builder: (context, hidden, child) {
        final hide = hidden != null && hidden == widget.tag;
        // Opacity 0 не рисует ребёнка вовсе — дёшево; место и состояние
        // (видео, загрузка) сохраняются.
        return Opacity(opacity: hide ? 0 : 1, child: child);
      },
    );
  }
}
