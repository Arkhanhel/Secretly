// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Вкладка «Кадр»: целый снимок в коробке (отступ 28), рамка с уголками и
/// серединами сторон, затемнение вокруг, сетка третей во время жеста;
/// шкала выпрямления, поворот, отражение, «Сбросить», пропорции.
///
/// Прототип: `cropGeo`, `cropMedia`, `cropDown`/`cropMove`/`cropUp`,
/// `angDown`/`angMove`/`angUp`, блок `cf` в `renderVals()`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../edited_media_view.dart';
import '../media_edits.dart';
import '../media_viewer_tokens.dart';
import 'media_editor_model.dart';
import 'media_editor_widgets.dart';

/// Отступ коробки кадра от краёв рабочей зоны (прототип: B {28,28,334,440}).
const double kCropBoxInset = 28;

/// Рамка в системе экрана: центр, размер целого снимка до поворота на
/// четверти (bw × bh) и угол. Во время анимации поворота размеры плавно
/// идут между раскладками соседних четвертей — как в [EditedMediaLayers].
@immutable
class _FrameGeo {
  const _FrameGeo(this.center, this.size, this.radians, this.crop);

  final Offset center;
  final Size size;
  final double radians;
  final Rect crop;

  static _FrameGeo of(double aspect, CropRect c, double rotationDeg, Rect box) {
    final q = rotationDeg / 90;
    final q0 = q.floorToDouble();
    final f = q - q0;
    Size pre(double quarters) => EditedLayout.compute(
      aspect,
      MediaEdits(rotation: quarters.round() * 90),
      box.size,
    ).preRotate;
    final s0 = pre(q0);
    final s1 = f == 0 ? s0 : pre(q0 + 1);
    final bw = s0.width + (s1.width - s0.width) * f;
    final bh = s0.height + (s1.height - s0.height) * f;
    return _FrameGeo(
      box.center,
      Size(bw, bh),
      rotationDeg * math.pi / 180,
      Rect.fromLTWH(c.x * bw, c.y * bh, c.w * bw, c.h * bh),
    );
  }

  /// Точка экрана → система рамки (до поворота, от левого верхнего угла).
  Offset toFrame(Offset p) {
    final v = p - center;
    final cs = math.cos(-radians), sn = math.sin(-radians);
    return Offset(
      v.dx * cs - v.dy * sn + size.width / 2,
      v.dx * sn + v.dy * cs + size.height / 2,
    );
  }
}

@immutable
class _FrameTarget {
  const _FrameTarget(this.crop, this.rotation);

  final CropRect crop;
  final double rotation;

  static _FrameTarget lerp(_FrameTarget a, _FrameTarget b, double t) =>
      _FrameTarget(
        CropRect(
          ui.lerpDouble(a.crop.x, b.crop.x, t)!,
          ui.lerpDouble(a.crop.y, b.crop.y, t)!,
          ui.lerpDouble(a.crop.w, b.crop.w, t)!,
          ui.lerpDouble(a.crop.h, b.crop.h, t)!,
        ),
        ui.lerpDouble(a.rotation, b.rotation, t)!,
      );

  @override
  bool operator ==(Object o) =>
      o is _FrameTarget && o.crop == crop && o.rotation == rotation;

  @override
  int get hashCode => Object.hash(crop, rotation);
}

/// Рабочая зона вкладки «Кадр».
class MediaEditorCropArea extends StatefulWidget {
  const MediaEditorCropArea({
    super.key,
    required this.model,
    required this.image,
    required this.area,
  });

  final MediaEditorModel model;
  final ImageProvider image;

  /// Размер рабочей зоны.
  final Size area;

  @override
  State<MediaEditorCropArea> createState() => _MediaEditorCropAreaState();
}

class _MediaEditorCropAreaState extends State<MediaEditorCropArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  _FrameTarget? _from;
  late _FrameTarget _to;

  int? _pointer;
  CropHandle? _handle;
  Offset _start = Offset.zero;
  CropRect _c0 = CropRect.full;

  MediaEditorModel get m => widget.model;

  Rect get _box => Rect.fromLTWH(
    kCropBoxInset,
    kCropBoxInset,
    math.max(1, widget.area.width - kCropBoxInset * 2),
    math.max(1, widget.area.height - kCropBoxInset * 2),
  );

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: kMediaEditorAnimDuration)
      ..addListener(() => setState(() {}));
    _to = _FrameTarget(m.e.crop, m.e.rotation.toDouble());
    m.edits.addListener(_onEdits);
    m.addListener(_onModel);
  }

  @override
  void didUpdateWidget(covariant MediaEditorCropArea old) {
    super.didUpdateWidget(old);
    if (old.model != widget.model) {
      old.model.edits.removeListener(_onEdits);
      old.model.removeListener(_onModel);
      widget.model.edits.addListener(_onEdits);
      widget.model.addListener(_onModel);
    }
  }

  @override
  void dispose() {
    m.edits.removeListener(_onEdits);
    m.removeListener(_onModel);
    _anim.dispose();
    super.dispose();
  }

  _FrameTarget _current() {
    final from = _from;
    if (from == null || !_anim.isAnimating) return _to;
    return _FrameTarget.lerp(from, _to, kMediaFlightCurve.transform(_anim.value));
  }

  void _onEdits() {
    final next = _FrameTarget(m.e.crop, m.e.rotation.toDouble());
    if (next != _to) {
      if (!m.busy) {
        _from = _current();
        _to = next;
        _anim.forward(from: 0);
      } else {
        _anim.stop();
        _from = null;
        _to = next;
      }
    }
    setState(() {});
  }

  void _onModel() => setState(() {});

  /// Ручка под пальцем: ближайшая из тех, чья зона 44×44 его накрывает;
  /// иначе внутри рамки — перенос.
  CropHandle? _hit(Offset local) {
    final g = _FrameGeo.of(m.aspect, m.e.crop, m.e.rotation.toDouble(), _box);
    final p = g.toFrame(local);
    final r = g.crop;
    final candidates = <CropHandle, Offset>{
      CropHandle.tl: r.topLeft,
      CropHandle.tr: r.topRight,
      CropHandle.bl: r.bottomLeft,
      CropHandle.br: r.bottomRight,
      if (m.cropAspect == CropAspect.free) ...{
        CropHandle.t: r.topCenter,
        CropHandle.b: r.bottomCenter,
        CropHandle.l: r.centerLeft,
        CropHandle.r: r.centerRight,
      },
    };
    CropHandle? best;
    var bestD = double.infinity;
    candidates.forEach((h, c) {
      final d = p - c;
      if (d.dx.abs() <= 22 && d.dy.abs() <= 22 && d.distance < bestD) {
        best = h;
        bestD = d.distance;
      }
    });
    if (best != null) return best;
    if (r.contains(p)) return CropHandle.move;
    return null;
  }

  void _down(PointerDownEvent ev) {
    if (_pointer != null) return;
    final h = _hit(ev.localPosition);
    if (h == null) return;
    _pointer = ev.pointer;
    _handle = h;
    _start = ev.localPosition;
    _c0 = m.e.crop;
    m.begin();
    m.busy = true;
  }

  void _move(PointerMoveEvent ev) {
    if (ev.pointer != _pointer) return;
    final hd = _handle;
    if (hd == null) return;
    final d = ev.localPosition - _start;
    final e = m.e;
    final k = e.k;
    const cosK = <double>[1, 0, -1, 0], sinK = <double>[0, 1, 0, -1];
    final cs = cosK[k], sn = sinK[k];
    final ux = d.dx * cs + d.dy * sn, uy = -d.dx * sn + d.dy * cs;
    final l = EditedLayout.compute(
      m.aspect,
      MediaEdits(rotation: e.rotation),
      _box.size,
    );
    final r = cropAspectRatio(m.cropAspect, k, m.aspect);
    final next = applyCrop(
      hd,
      _c0,
      ux / l.preRotate.width,
      uy / l.preRotate.height,
      r,
      m.aspect,
    );
    if (next != e.crop) m.live(e.copyWith(crop: next));
  }

  void _up(PointerEvent ev) {
    if (ev.pointer != _pointer) return;
    _pointer = null;
    _handle = null;
    m.end();
    m.busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = MediaViewerTokens.of(context);
    final e = m.e;
    final box = _box;
    final l = EditedLayout.compute(
      m.aspect,
      MediaEdits(rotation: e.rotation),
      box.size,
    );
    final s = coverScale(e.crop, l.preRotate.width, l.preRotate.height, e.angle);
    final shown = _current();
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fromRect(
            rect: box,
            child: IgnorePointer(
              child: EditedMediaView(
                image: widget.image,
                sourceAspect: m.aspect,
                edits: e.copyWith(
                  crop: CropRect.full,
                  adjust: e.adjust.copyWith(vignette: 0),
                ),
                animate: !m.busy,
                straightenScale: s,
                clipToCrop: false,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CropFramePainter(
                  geo: _FrameGeo.of(m.aspect, shown.crop, shown.rotation, box),
                  tokens: t,
                  grid: m.busy,
                  edges: m.cropAspect == CropAspect.free,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CropFramePainter extends CustomPainter {
  _CropFramePainter({
    required this.geo,
    required this.tokens,
    required this.grid,
    required this.edges,
  });

  final _FrameGeo geo;
  final MediaViewerTokens tokens;
  final bool grid;
  final bool edges;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tokens;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(geo.center.dx, geo.center.dy);
    canvas.rotate(geo.radians);
    canvas.translate(-geo.size.width / 2, -geo.size.height / 2);
    final r = geo.crop;
    final far = size.longestSide * 4 + geo.size.longestSide;
    // Затемнение снаружи рамки.
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Rect.fromCenter(center: r.center, width: far, height: far))
        ..addRect(r),
      Paint()..color = t.cropDim,
    );
    if (grid) {
      final g = Paint()..color = t.cropGrid;
      for (final f in const [1 / 3, 2 / 3]) {
        canvas.drawRect(Rect.fromLTWH(r.left + r.width * f, r.top, 1, r.height), g);
        canvas.drawRect(Rect.fromLTWH(r.left, r.top + r.height * f, r.width, 1), g);
      }
    }
    // Обводка 1 px снаружи (CSS outline).
    canvas.drawRect(
      r.inflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = t.cropLine,
    );
    final h = Paint()..color = t.cropHandle;
    // Уголки 20×20, линия 3 px, на 3 px снаружи рамки.
    void corner(double x, double y, double sx, double sy) {
      final ox = sx < 0 ? x - 3 : x + 3 - 20;
      final oy = sy < 0 ? y - 3 : y + 3 - 20;
      canvas.drawRect(Rect.fromLTWH(ox, sy < 0 ? y - 3 : y, 20, 3), h);
      canvas.drawRect(Rect.fromLTWH(sx < 0 ? x - 3 : x, oy, 3, 20), h);
    }

    corner(r.left, r.top, -1, -1);
    corner(r.right, r.top, 1, -1);
    corner(r.left, r.bottom, -1, 1);
    corner(r.right, r.bottom, 1, 1);
    if (edges) {
      final cx = r.center.dx, cy = r.center.dy;
      canvas.drawRect(Rect.fromLTWH(cx - 12, r.top - 3, 24, 3), h);
      canvas.drawRect(Rect.fromLTWH(cx - 12, r.bottom, 24, 3), h);
      canvas.drawRect(Rect.fromLTWH(r.left - 3, cy - 12, 3, 24), h);
      canvas.drawRect(Rect.fromLTWH(r.right, cy - 12, 3, 24), h);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CropFramePainter old) =>
      old.geo.crop != geo.crop ||
      old.geo.size != geo.size ||
      old.geo.radians != geo.radians ||
      old.geo.center != geo.center ||
      old.grid != grid ||
      old.edges != edges ||
      old.tokens != tokens;
}

/// Панель вкладки «Кадр» (164 px): шкала, кнопки, пропорции.
class MediaEditorCropPanel extends StatelessWidget {
  const MediaEditorCropPanel({super.key, required this.model});

  final MediaEditorModel model;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final t = MediaViewerTokens.of(context);
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge([m, m.edits]),
      builder: (context, _) {
        final e = m.e;
        final aspects = <(CropAspect, String)>[
          (CropAspect.free, l10n.meAspectFree),
          (CropAspect.original, l10n.meAspectOriginal),
          (CropAspect.square, '1:1'),
          (CropAspect.landscape32, '3:2'),
          (CropAspect.classic43, '4:3'),
          (CropAspect.portrait45, '4:5'),
          (CropAspect.wide169, '16:9'),
          (CropAspect.tall916, '9:16'),
          (CropAspect.portrait34, '3:4'),
        ];
        return Stack(
          children: [
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              height: 54,
              child: _StraightenRuler(model: m),
            ),
            Positioned(
              top: 64,
              left: 12,
              right: 14,
              height: 44,
              child: Row(
                children: [
                  EditorRoundButton(
                    icon: MediaEditorIcons.rotate,
                    tooltip: l10n.meRotate,
                    onTap: m.rotate,
                    background: t.chip,
                    foreground: t.editorInk,
                  ),
                  const SizedBox(width: 4),
                  EditorRoundButton(
                    icon: MediaEditorIcons.flip,
                    tooltip: l10n.meFlip,
                    selected: e.flip,
                    onTap: m.flip,
                    background: e.flip ? t.chipOn : t.chip,
                    foreground: e.flip ? t.chipOnInk : t.editorInk,
                  ),
                  const Spacer(),
                  if (m.cropChanged)
                    EditorTapTarget(
                      onTap: m.resetCrop,
                      label: l10n.meReset,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(MediaEditorIcons.reset, size: 18, color: t.accent),
                            const SizedBox(width: 6),
                            Text(
                              l10n.meReset,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: t.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 109,
              left: 14,
              right: 14,
              height: 44,
              // Девять пропорций (SendFlow) — лентой с прокруткой, а не
              // сжатием в одну строку.
              child: Center(
                child: SingleChildScrollView(
                  key: const ValueKey('me:aspects'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, (key, label)) in aspects.indexed) ...[
                        if (i > 0) const SizedBox(width: 6),
                        _AspectChip(
                          label: label,
                          selected: m.cropAspect == key,
                          tokens: t,
                          onTap: () => m.selectAspect(key),
                        ),
                      ],
                    ],
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

class _AspectChip extends StatelessWidget {
  const _AspectChip({
    required this.label,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final MediaViewerTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? t.chipOn : t.chip,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? t.chipOnInk : t.editorInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Шкала выпрямления: 91 деление по 7 px, палец влево — угол больше.
class _StraightenRuler extends StatefulWidget {
  const _StraightenRuler({required this.model});

  final MediaEditorModel model;

  @override
  State<_StraightenRuler> createState() => _StraightenRulerState();
}

class _StraightenRulerState extends State<_StraightenRuler> {
  int? _pointer;
  double _x0 = 0;
  double _a0 = 0;

  MediaEditorModel get m => widget.model;

  void _down(PointerDownEvent ev) {
    if (_pointer != null) return;
    _pointer = ev.pointer;
    _x0 = ev.position.dx;
    _a0 = m.e.angle;
    m.begin();
    m.busy = true;
  }

  void _move(PointerMoveEvent ev) {
    if (ev.pointer != _pointer) return;
    _setAngle(_a0 - (ev.position.dx - _x0) / 7);
  }

  void _setAngle(double raw) {
    var a = raw.clamp(-45.0, 45.0);
    a = a.abs() < .5 ? 0 : (a * 10).roundToDouble() / 10;
    final prev = m.e.angle;
    if (a == prev) return;
    if (a == 0) m.haptic(MediaEditorHaptic.selection);
    m.live(m.e.copyWith(angle: a));
  }

  void _up(PointerEvent ev) {
    if (ev.pointer != _pointer) return;
    _pointer = null;
    m.end();
    m.busy = false;
  }

  void _step(double d) {
    m.begin();
    _setAngle(m.e.angle + d);
    m.end();
  }

  @override
  Widget build(BuildContext context) {
    final t = MediaViewerTokens.of(context);
    final angle = m.e.angle;
    final label = formatAngle(angle);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final x = w / 2 - ((angle + 45) * 7 + 3.5);
        return Semantics(
          slider: true,
          label: context.l10n.meStraighten,
          value: label,
          increasedValue: formatAngle(math.min(45, angle + 1)),
          decreasedValue: formatAngle(math.max(-45, angle - 1)),
          onIncrease: () => _step(1),
          onDecrease: () => _step(-1),
          child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              onPointerCancel: _up,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  colors: [
                    Color(0x00000000),
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Color(0x00000000),
                  ],
                  stops: [0, .22, .78, 1],
                ).createShader(rect),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      top: 2,
                      left: 0,
                      right: 0,
                      child: ExcludeSemantics(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: angle != 0 ? t.accent : t.editorSub,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 24,
                      left: 0,
                      width: 91 * 7,
                      height: 24,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: x),
                        duration: m.busy
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        curve: Curves.ease,
                        builder: (context, v, child) =>
                            Transform.translate(offset: Offset(v, 0), child: child),
                        child: RepaintBoundary(
                          child: CustomPaint(
                            size: const Size(91 * 7, 24),
                            painter: _TicksPainter(t.editorInk),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: w / 2 - 1,
                      top: 20,
                      width: 2,
                      height: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ),
        );
      },
    );
  }
}

class _TicksPainter extends CustomPainter {
  _TicksPainter(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final strong = Paint()..color = ink.withValues(alpha: ink.a * .85);
    final weak = Paint()..color = ink.withValues(alpha: ink.a * .4);
    for (var i = 0; i < 91; i++) {
      final h = i == 45 ? 20.0 : (i % 5 == 0 ? 14.0 : 8.0);
      canvas.drawRect(
        Rect.fromLTWH(i * 7 + 3, size.height - h, 1, h),
        i % 5 == 0 ? strong : weak,
      );
    }
  }

  @override
  bool shouldRepaint(_TicksPainter old) => old.ink != ink;
}
