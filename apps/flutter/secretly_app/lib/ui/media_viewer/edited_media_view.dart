// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Одна отрисовка снимка с правками — для ленты чата, просмотра, ленты
/// миниатюр, редактора и выгрузки (`media()` прототипа).
///
/// Слои, как в прототипе:
///   коробка → итоговый прямоугольник (dw × dh) →
///   поворот на четверти (bw × bh, обрезка, цвет) →
///   целый снимок W × H, сдвинутый на −crop, повёрнутый на угол выпрямления
///   и увеличенный ровно настолько, чтобы рамка не задела пустые углы →
///   снимок (отражение) + рисунок + тексты; виньетка — поверх итогового.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'media_edits.dart';

/// Пропорция снимка из провайдера (без лишнего декодирования, если снимок
/// уже в кэше картинок).
Future<double?> resolveImageAspect(
  ImageProvider provider, {
  ImageConfiguration configuration = ImageConfiguration.empty,
}) {
  final c = Completer<double?>();
  final stream = provider.resolve(configuration);
  late final ImageStreamListener l;
  l = ImageStreamListener(
    (info, _) {
      final w = info.image.width, h = info.image.height;
      if (!c.isCompleted) c.complete(w > 0 && h > 0 ? w / h : null);
      stream.removeListener(l);
    },
    onError: (Object _, StackTrace? _) {
      if (!c.isCompleted) c.complete(null);
      stream.removeListener(l);
    },
  );
  stream.addListener(l);
  return c.future;
}

/// Снимок [image] с правками [edits] в коробке, «contain» или «cover».
///
/// [sourceAspect] — пропорция исходника; если не задана, берётся из самого
/// снимка, когда он раскодируется (до того — пустое место нужного размера).
/// [animate] — плавно перейти к новым кадру, повороту и выпрямлению
/// (320 мс, редактор); [straightenScale] — свой масштаб выпрямления (экран
/// «Кадр» показывает целый снимок, но масштаб считает по рамке).
class EditedMediaView extends StatefulWidget {
  const EditedMediaView({
    super.key,
    required this.image,
    required this.edits,
    this.sourceAspect,
    this.cover = false,
    this.showAdjustments = true,
    this.liveStroke,
    this.selectedTextId,
    this.selectionColor = const Color(0xF27FD0FF),
    this.animate = false,
    this.straightenScale,
    this.filterQuality = FilterQuality.medium,
    this.placeholder,
    this.gaplessPlayback = true,
    this.clipToCrop = true,
  });

  final ImageProvider image;
  final MediaEdits edits;
  final double? sourceAspect;
  final bool cover;

  /// false — экран «Кадр»: снимок виден и за рамкой (там его притеняет
  /// затемнение редактора), как в прототипе (`cropMedia` без обрезки).
  final bool clipToCrop;

  /// false — «Сравнить»: без цвета и виньетки.
  final bool showAdjustments;
  final DrawStroke? liveStroke;
  final String? selectedTextId;
  final Color selectionColor;
  final bool animate;
  final double? straightenScale;
  final FilterQuality filterQuality;
  final Widget? placeholder;
  final bool gaplessPlayback;

  @override
  State<EditedMediaView> createState() => _EditedMediaViewState();
}

class _EditedMediaViewState extends State<EditedMediaView>
    with SingleTickerProviderStateMixin {
  double? _aspect;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  AnimationController? _anim;
  _Geo? _from;
  _Geo? _to;
  double? _fromScale;

  @override
  void initState() {
    super.initState();
    _aspect = widget.sourceAspect;
    _to = _Geo.of(widget.edits);
    if (_aspect == null) _watchAspect();
  }

  void _watchAspect() {
    _unwatch();
    final stream = widget.image.resolve(ImageConfiguration.empty);
    final l = ImageStreamListener((info, _) {
      final w = info.image.width, h = info.image.height;
      if (w > 0 && h > 0 && mounted) {
        final a = w / h;
        if (_aspect != a) setState(() => _aspect = a);
      }
    }, onError: (Object _, StackTrace? _) {});
    stream.addListener(l);
    _stream = stream;
    _listener = l;
  }

  void _unwatch() {
    final s = _stream, l = _listener;
    if (s != null && l != null) s.removeListener(l);
    _stream = null;
    _listener = null;
  }

  @override
  void didUpdateWidget(covariant EditedMediaView old) {
    super.didUpdateWidget(old);
    if (widget.sourceAspect != null) {
      _aspect = widget.sourceAspect;
      _unwatch();
    } else if (old.image != widget.image || old.sourceAspect != null) {
      _aspect = null;
      _watchAspect();
    }
    final next = _Geo.of(widget.edits);
    if (next != _to) {
      if (widget.animate) {
        final anim = _anim ??= AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 320),
        )..addListener(() => setState(() {}));
        _from = _current();
        _fromScale = _currentScaleOverride(old);
        _to = next;
        anim.forward(from: 0);
      } else {
        _anim?.stop();
        _from = null;
        _to = next;
      }
    }
  }

  double? _currentScaleOverride(EditedMediaView old) => old.straightenScale;

  _Geo _current() {
    final to = _to ?? _Geo.of(widget.edits);
    final from = _from;
    final anim = _anim;
    if (from == null || anim == null || !anim.isAnimating) return to;
    return _Geo.lerp(from, to, const Cubic(.2, .8, .2, 1).transform(anim.value));
  }

  @override
  void dispose() {
    _unwatch();
    _anim?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _aspect;
    if (aspect == null) {
      return widget.placeholder ?? const SizedBox.expand();
    }
    final geo = _current();
    final anim = _anim;
    double? scaleOverride = widget.straightenScale;
    if (scaleOverride != null &&
        _fromScale != null &&
        anim != null &&
        anim.isAnimating) {
      scaleOverride = ui.lerpDouble(
        _fromScale,
        scaleOverride,
        const Cubic(.2, .8, .2, 1).transform(anim.value),
      );
    }
    final edits = widget.edits.copyWith(
      crop: geo.crop,
      angle: geo.angle,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        if (!box.width.isFinite || !box.height.isFinite) {
          return const SizedBox.shrink();
        }
        return EditedMediaLayers(
          image: widget.image,
          aspect: aspect,
          edits: edits,
          rotationDegrees: geo.rotation,
          box: box,
          cover: widget.cover,
          showAdjustments: widget.showAdjustments,
          liveStroke: widget.liveStroke,
          selectedTextId: widget.selectedTextId,
          selectionColor: widget.selectionColor,
          straightenScale: scaleOverride,
          filterQuality: widget.filterQuality,
          gaplessPlayback: widget.gaplessPlayback,
          clipToCrop: widget.clipToCrop,
        );
      },
    );
  }
}

/// Геометрия, которая анимируется: рамка, поворот, выпрямление.
@immutable
class _Geo {
  const _Geo(this.crop, this.rotation, this.angle);

  factory _Geo.of(MediaEdits e) =>
      _Geo(e.crop, e.rotation.toDouble(), e.angle);

  final CropRect crop;
  final double rotation;
  final double angle;

  static _Geo lerp(_Geo a, _Geo b, double t) => _Geo(
    CropRect(
      ui.lerpDouble(a.crop.x, b.crop.x, t)!,
      ui.lerpDouble(a.crop.y, b.crop.y, t)!,
      ui.lerpDouble(a.crop.w, b.crop.w, t)!,
      ui.lerpDouble(a.crop.h, b.crop.h, t)!,
    ),
    ui.lerpDouble(a.rotation, b.rotation, t)!,
    ui.lerpDouble(a.angle, b.angle, t)!,
  );

  @override
  bool operator ==(Object o) =>
      o is _Geo && o.crop == crop && o.rotation == rotation && o.angle == angle;

  @override
  int get hashCode => Object.hash(crop, rotation, angle);
}

/// Слои без состояния: всё считается из [box] и правок.
class EditedMediaLayers extends StatelessWidget {
  const EditedMediaLayers({
    super.key,
    required this.image,
    required this.aspect,
    required this.edits,
    required this.box,
    this.rotationDegrees,
    this.cover = false,
    this.showAdjustments = true,
    this.liveStroke,
    this.selectedTextId,
    this.selectionColor = const Color(0xF27FD0FF),
    this.straightenScale,
    this.filterQuality = FilterQuality.medium,
    this.gaplessPlayback = true,
    this.clipToCrop = true,
  });

  final ImageProvider image;
  final double aspect;
  final MediaEdits edits;
  final Size box;

  /// Поворот для отрисовки (во время анимации — промежуточный); по умолчанию
  /// из правок.
  final double? rotationDegrees;
  final bool cover;
  final bool showAdjustments;
  final DrawStroke? liveStroke;
  final String? selectedTextId;
  final Color selectionColor;
  final double? straightenScale;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final bool clipToCrop;

  @override
  Widget build(BuildContext context) {
    // Во время анимации поворота размеры плавно идут от раскладки одной
    // четверти к раскладке соседней — как CSS-переход прототипа, где ширина,
    // высота и угол меняются вместе.
    final rot = rotationDegrees ?? edits.rotation.toDouble();
    final q = rot / 90;
    final q0 = q.floorToDouble();
    final f = q - q0;
    final e = edits.copyWith(rotation: (f < .5 ? q0 : q0 + 1).round() * 90);
    final l0 = EditedLayout.compute(
      aspect,
      edits.copyWith(rotation: q0.round() * 90),
      box,
      cover: cover,
    );
    final l1 = f == 0
        ? l0
        : EditedLayout.compute(
            aspect,
            edits.copyWith(rotation: (q0 + 1).round() * 90),
            box,
            cover: cover,
          );
    double mix(double a, double b) => f == 0 ? a : a + (b - a) * f;
    final W = mix(l0.full.width, l1.full.width);
    final H = mix(l0.full.height, l1.full.height);
    final bw = mix(l0.preRotate.width, l1.preRotate.width);
    final bh = mix(l0.preRotate.height, l1.preRotate.height);
    final dw = mix(l0.display.width, l1.display.width);
    final dh = mix(l0.display.height, l1.display.height);
    final l = (
      display: Rect.fromLTWH(
        mix(l0.display.left, l1.display.left),
        mix(l0.display.top, l1.display.top),
        dw,
        dh,
      ),
    );
    final s = straightenScale ?? mix(l0.scale, l1.scale);

    Widget content = SizedBox(
      width: W,
      height: H,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform(
              alignment: Alignment.center,
              transform: e.flip
                  ? (Matrix4.identity()..scaleByDouble(-1, 1, 1, 1))
                  : Matrix4.identity(),
              child: Image(
                image: image,
                fit: BoxFit.fill,
                filterQuality: filterQuality,
                gaplessPlayback: gaplessPlayback,
                excludeFromSemantics: true,
              ),
            ),
          ),
          if (e.strokes.isNotEmpty || liveStroke != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _StrokesPainter(
                    strokes: e.strokes,
                    live: liveStroke,
                    unit: W / kMediaDrawViewBox,
                  ),
                ),
              ),
            ),
          for (final t in e.texts)
            _TextLayer(
              item: t,
              full: Size(W, H),
              selected: t.id == selectedTextId,
              selectionColor: selectionColor,
            ),
        ],
      ),
    );

    // Целый снимок, сдвинутый на рамку, повёрнутый и увеличенный вокруг
    // своего центра (CSS transform-origin: 50% 50%).
    Widget layer = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateZ(e.angle * math.pi / 180)
        ..scaleByDouble(s, s, 1, 1),
      child: content,
    );

    Widget inner = SizedBox(
      width: bw,
      height: bh,
      child: ClipRect(
        clipBehavior: clipToCrop ? Clip.hardEdge : Clip.none,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset(-e.crop.x * W, -e.crop.y * H),
            child: layer,
          ),
        ),
      ),
    );
    if (showAdjustments && e.adjust.hasColor) {
      inner = ColorFiltered(
        colorFilter: ColorFilter.matrix(colorMatrix(e.adjust)),
        child: inner,
      );
    }
    inner = Transform.rotate(angle: rot * math.pi / 180, child: inner);

    final finalBox = SizedBox(
      width: dw,
      height: dh,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: (dw - bw) / 2,
            top: (dh - bh) / 2,
            width: bw,
            height: bh,
            child: inner,
          ),
          if (showAdjustments && e.adjust.vignette > 0.001)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: vignetteGradient(e.adjust.vignette),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final placed = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: l.display.left,
          top: l.display.top,
          width: dw,
          height: dh,
          child: finalBox,
        ),
      ],
    );
    return SizedBox(
      width: box.width,
      height: box.height,
      child: cover ? ClipRect(child: placed) : placed,
    );
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter({required this.strokes, required this.live, required this.unit});

  final List<DrawStroke> strokes;
  final DrawStroke? live;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(unit);
    for (final s in strokes) {
      paintStroke(canvas, s);
    }
    final l = live;
    if (l != null) paintStroke(canvas, l);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrokesPainter old) =>
      !identical(old.strokes, strokes) ||
      !identical(old.live, live) ||
      old.live?.points.length != live?.points.length ||
      old.unit != unit;
}

class _TextLayer extends StatelessWidget {
  const _TextLayer({
    required this.item,
    required this.full,
    required this.selected,
    required this.selectionColor,
  });

  final TextItem item;
  final Size full;
  final bool selected;
  final Color selectionColor;

  @override
  Widget build(BuildContext context) {
    final fs = item.fontFraction * full.width;
    final label = item.text.isEmpty ? ' ' : item.text;
    Widget text = Container(
      constraints: BoxConstraints(minWidth: fs * .6),
      padding: item.background
          ? EdgeInsets.symmetric(horizontal: fs * .34, vertical: fs * .14)
          : EdgeInsets.zero,
      decoration: item.background
          ? BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(fs * .3),
            )
          : null,
      child: Text(
        label,
        softWrap: false,
        textAlign: TextAlign.center,
        textScaler: TextScaler.noScaling,
        style: mediaTextStyle(item, fs),
      ),
    );
    if (selected) {
      text = CustomPaint(
        foregroundPainter: _DashedOutline(
          color: selectionColor,
          width: math.max(1, fs * .05),
          inset: -fs * .25,
          radius: fs * .3,
        ),
        child: text,
      );
    }
    return Positioned(
      left: item.center.dx * full.width,
      top: item.center.dy * full.height,
      child: FractionalTranslation(
        translation: const Offset(-.5, -.5),
        child: text,
      ),
    );
  }
}

class _DashedOutline extends CustomPainter {
  _DashedOutline({
    required this.color,
    required this.width,
    required this.inset,
    required this.radius,
  });

  final Color color;
  final double width;
  final double inset;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(inset);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    final dash = width * 3, gap = width * 2.4;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline old) =>
      old.color != color || old.width != width || old.inset != inset;
}

// ─── Выгрузка правленого снимка ─────────────────────────────────────────────

/// Длинная сторона выгружаемого снимка не больше этого — 12-мегапиксельный
/// снимок с правками не должен съесть память телефона.
const int kEditedExportMaxSide = 4096;

/// Рисует правленый снимок в пиксели (тем же порядком слоёв, что и виджет).
Future<ui.Image> renderEditedImage(
  ui.Image src,
  MediaEdits e, {
  int maxSide = kEditedExportMaxSide,
}) async {
  final a = src.width / src.height;
  final c = e.crop;
  // Размер итогового снимка в пикселях исходника.
  var outW = c.w * src.width, outH = c.h * src.height;
  if (e.odd) {
    final t = outW;
    outW = outH;
    outH = t;
  }
  final k = math.min(1.0, maxSide / math.max(outW, outH));
  final box = Size((outW * k).roundToDouble(), (outH * k).roundToDouble());
  final l = EditedLayout.compute(a, e, box);
  final W = l.full.width, H = l.full.height;
  final bw = l.preRotate.width, bh = l.preRotate.height;

  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec, Offset.zero & box);
  canvas.save();
  // Поворот на четверти вокруг центра итогового снимка.
  canvas.translate(box.width / 2, box.height / 2);
  canvas.rotate(e.rotation * math.pi / 180);
  canvas.translate(-bw / 2, -bh / 2);
  canvas.clipRect(Rect.fromLTWH(0, 0, bw, bh));
  final colorPaint = Paint();
  if (e.adjust.hasColor) {
    colorPaint.colorFilter = ColorFilter.matrix(colorMatrix(e.adjust));
  }
  canvas.saveLayer(Rect.fromLTWH(0, 0, bw, bh), colorPaint);
  // Целый снимок: сдвиг на рамку, выпрямление вокруг центра.
  canvas.translate(-c.x * W, -c.y * H);
  canvas.translate(W / 2, H / 2);
  canvas.rotate(e.angle * math.pi / 180);
  canvas.scale(l.scale);
  canvas.translate(-W / 2, -H / 2);
  canvas.save();
  if (e.flip) {
    canvas.translate(W, 0);
    canvas.scale(-1, 1);
  }
  canvas.drawImageRect(
    src,
    Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
    Rect.fromLTWH(0, 0, W, H),
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.restore();
  canvas.save();
  canvas.scale(W / kMediaDrawViewBox);
  for (final s in e.strokes) {
    paintStroke(canvas, s);
  }
  canvas.restore();
  for (final t in e.texts) {
    if (t.text.trim().isEmpty) continue;
    final fs = t.fontFraction * W;
    final tp = TextPainter(
      text: TextSpan(text: t.text, style: mediaTextStyle(t, fs)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final padH = t.background ? fs * .34 : 0.0;
    final padV = t.background ? fs * .14 : 0.0;
    final bwT = math.max(tp.width + padH * 2, fs * .6);
    final bhT = tp.height + padV * 2;
    final center = Offset(t.center.dx * W, t.center.dy * H);
    final r = Rect.fromCenter(center: center, width: bwT, height: bhT);
    if (t.background) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(fs * .3)),
        Paint()..color = t.color,
      );
    }
    tp.paint(canvas, Offset(r.left + (bwT - tp.width) / 2, r.top + padV));
    tp.dispose();
  }
  canvas.restore(); // saveLayer
  canvas.restore(); // поворот и обрезка
  if (e.adjust.vignette > 0.001) {
    final rect = Offset.zero & box;
    canvas.drawRect(
      rect,
      Paint()..shader = vignetteGradient(e.adjust.vignette).createShader(rect),
    );
  }
  final picture = rec.endRecording();
  final out = await picture.toImage(box.width.round(), box.height.round());
  picture.dispose();
  return out;
}

/// 🔴 Раскрыть исходник СРАЗУ в нужном размере (22.11.2026, разбор):
/// раньше снимок 12–200 Мп раскрывался целиком, и вместе с копиями правки
/// это сотни мегабайт — слабый Android закрывал приложение. Берём ровно
/// столько пикселей, чтобы обрезанная часть дала [maxSide] итога.
Future<ui.Image> _decodeForExport(
  File source,
  MediaEdits edits,
  int maxSide,
) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await source.readAsBytes(),
  );
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final w = descriptor.width, h = descriptor.height;
    final c = edits.crop;
    final cropLong = math.max(c.w * w, c.h * h);
    final k = cropLong <= 0 ? 1.0 : math.min(1.0, maxSide / cropLong);
    final codec = await descriptor.instantiateCodec(
      targetWidth: k < 1 ? math.max(1, (w * k).round()) : null,
      targetHeight: k < 1 ? math.max(1, (h * k).round()) : null,
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}

/// Правленый снимок → JPEG (92) во временный файл [outPath].
Future<File> exportEditedImageFile({
  required File source,
  required MediaEdits edits,
  required String outPath,
}) async {
  final src = await _decodeForExport(source, edits, kEditedExportMaxSide);
  try {
    final out = await renderEditedImage(src, edits);
    try {
      final data = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('render failed');
      final jpg = await compute(_encodeJpeg, (
        data.buffer.asUint8List(),
        out.width,
        out.height,
      ));
      final f = File(outPath);
      await f.parent.create(recursive: true);
      await f.writeAsBytes(jpg, flush: true);
      return f;
    } finally {
      out.dispose();
    }
  } finally {
    src.dispose();
  }
}

/// Правленый снимок → PNG в памяти (для копирования в буфер обмена).
Future<Uint8List> exportEditedImagePng({
  required File source,
  required MediaEdits edits,
  int maxSide = 2048,
}) async {
  final src = await _decodeForExport(source, edits, maxSide);
  try {
    final out = await renderEditedImage(src, edits, maxSide: maxSide);
    try {
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('render failed');
      return data.buffer.asUint8List();
    } finally {
      out.dispose();
    }
  } finally {
    src.dispose();
  }
}

Uint8List _encodeJpeg((Uint8List, int, int) args) {
  final (rgba, w, h) = args;
  final image = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}
