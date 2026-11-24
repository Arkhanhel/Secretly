// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Правки фото параметрами — оригинал не меняется (макет «Просмотр медиа»,
/// раздел «Редактор», 22.11.2026).
///
/// Геометрия повторяет прототип `MediaViewerPhone.dc.html` один в один:
/// `layout()`, `coverScale()`, `filterCss()`, `applyCrop()`, `aspectCrop()`.
/// Одна модель и одна функция раскладки служат ленте чата, просмотру, ленте
/// миниатюр, редактору и выгрузке готового снимка.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Ширина системы координат рисунка: линии хранятся в единицах изображения,
/// где ширина целого (необрезанного) снимка = 1000, высота = 1000 / aspect.
const double kMediaDrawViewBox = 1000;

@immutable
class CropRect {
  const CropRect(this.x, this.y, this.w, this.h);

  /// Доли исходника.
  final double x, y, w, h;

  static const CropRect full = CropRect(0, 0, 1, 1);

  bool get isFull => x == 0 && y == 0 && w == 1 && h == 1;

  CropRect copyWith({double? x, double? y, double? w, double? h}) =>
      CropRect(x ?? this.x, y ?? this.y, w ?? this.w, h ?? this.h);

  Map<String, Object?> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  static CropRect fromJson(Object? raw) {
    if (raw is! Map) return full;
    double v(String k, double d) {
      final n = raw[k];
      return n is num && n.isFinite ? n.toDouble() : d;
    }

    final w = v('w', 1).clamp(0.05, 1.0);
    final h = v('h', 1).clamp(0.05, 1.0);
    return CropRect(
      v('x', 0).clamp(0.0, 1.0 - w),
      v('y', 0).clamp(0.0, 1.0 - h),
      w,
      h,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CropRect && other.x == x && other.y == y && other.w == w && other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);
}

@immutable
class Adjustments {
  const Adjustments({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
    this.vignette = 0,
  });

  /// −1…1.
  final double brightness, contrast, saturation, warmth;

  /// 0…1.
  final double vignette;

  bool get isIdentity =>
      brightness == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      warmth == 0 &&
      vignette == 0;

  /// Цветовые правки без виньетки (виньетка — отдельный слой поверх).
  bool get hasColor =>
      brightness != 0 || contrast != 0 || saturation != 0 || warmth != 0;

  Adjustments copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
    double? vignette,
  }) => Adjustments(
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    warmth: warmth ?? this.warmth,
    vignette: vignette ?? this.vignette,
  );

  Map<String, Object?> toJson() => {
    'b': brightness,
    'c': contrast,
    's': saturation,
    'w': warmth,
    'v': vignette,
  };

  static Adjustments fromJson(Object? raw) {
    if (raw is! Map) return const Adjustments();
    double v(String k, double lo, double hi) {
      final n = raw[k];
      return n is num && n.isFinite ? n.toDouble().clamp(lo, hi) : 0;
    }

    return Adjustments(
      brightness: v('b', -1, 1),
      contrast: v('c', -1, 1),
      saturation: v('s', -1, 1),
      warmth: v('w', -1, 1),
      vignette: v('v', 0, 1),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Adjustments &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.saturation == saturation &&
      other.warmth == warmth &&
      other.vignette == vignette;

  @override
  int get hashCode =>
      Object.hash(brightness, contrast, saturation, warmth, vignette);
}

enum StrokeTool { pen, marker, neon }

@immutable
class DrawStroke {
  const DrawStroke({
    required this.id,
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
  });

  final String id;
  final StrokeTool tool;
  final Color color;

  /// В единицах изображения (ширина целого снимка = 1000).
  final double width;

  /// Единицы изображения: x ∈ 0…1000, y ∈ 0…1000/aspect.
  final List<Offset> points;

  DrawStroke copyWith({List<Offset>? points}) => DrawStroke(
    id: id,
    tool: tool,
    color: color,
    width: width,
    points: points ?? this.points,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    't': tool.name,
    'c': color.toARGB32(),
    'w': width,
    'p': <double>[
      for (final p in points) ...[
        (p.dx * 10).roundToDouble() / 10,
        (p.dy * 10).roundToDouble() / 10,
      ],
    ],
  };

  static DrawStroke? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final pts = raw['p'];
    if (pts is! List || pts.length < 2) return null;
    final points = <Offset>[];
    for (var i = 0; i + 1 < pts.length; i += 2) {
      final x = pts[i], y = pts[i + 1];
      if (x is num && y is num) points.add(Offset(x.toDouble(), y.toDouble()));
    }
    if (points.isEmpty) return null;
    final tool = StrokeTool.values.firstWhere(
      (t) => t.name == raw['t'],
      orElse: () => StrokeTool.pen,
    );
    final c = raw['c'];
    final w = raw['w'];
    return DrawStroke(
      id: '${raw['id'] ?? 's${points.length}'}',
      tool: tool,
      color: Color(c is int ? c : 0xFFFFFFFF),
      width: w is num && w > 0 ? w.toDouble() : 8,
      points: List<Offset>.unmodifiable(points),
    );
  }
}

@immutable
class TextItem {
  const TextItem({
    required this.id,
    required this.center,
    required this.text,
    required this.color,
    this.background = false,
    required this.fontFraction,
  });

  final String id;

  /// Доли целого (необрезанного) снимка.
  final Offset center;
  final String text;
  final Color color;
  final bool background;

  /// Кегль / ширина целого снимка.
  final double fontFraction;

  TextItem copyWith({
    Offset? center,
    String? text,
    Color? color,
    bool? background,
  }) => TextItem(
    id: id,
    center: center ?? this.center,
    text: text ?? this.text,
    color: color ?? this.color,
    background: background ?? this.background,
    fontFraction: fontFraction,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'x': center.dx,
    'y': center.dy,
    'text': text,
    'c': color.toARGB32(),
    'bg': background,
    'f': fontFraction,
  };

  static TextItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    if (text is! String || text.trim().isEmpty) return null;
    double v(String k, double d) {
      final n = raw[k];
      return n is num && n.isFinite ? n.toDouble() : d;
    }

    final c = raw['c'];
    return TextItem(
      id: '${raw['id'] ?? 't'}',
      center: Offset(v('x', .5).clamp(0, 1), v('y', .5).clamp(0, 1)),
      text: text,
      color: Color(c is int ? c : 0xFFFFFFFF),
      background: raw['bg'] == true,
      fontFraction: v('f', .06).clamp(.005, .5),
    );
  }
}

@immutable
class MediaEdits {
  const MediaEdits({
    this.crop = CropRect.full,
    this.rotation = 0,
    this.flip = false,
    this.angle = 0,
    this.adjust = const Adjustments(),
    this.strokes = const <DrawStroke>[],
    this.texts = const <TextItem>[],
  });

  static const MediaEdits identity = MediaEdits();

  final CropRect crop;

  /// Поворот в градусах, кратный 90; «против часовой» = −90 за нажатие.
  /// Хранится накопленным (−90, −180, …), чтобы поворот анимировался в одну
  /// сторону, а не «через ноль».
  final int rotation;
  final bool flip;

  /// Выпрямление, −45…45°.
  final double angle;
  final Adjustments adjust;
  final List<DrawStroke> strokes;
  final List<TextItem> texts;

  /// Число четвертей поворота, 0…3.
  int get k => (((rotation / 90).round() % 4) + 4) % 4;
  bool get odd => k.isOdd;

  bool get hasGeometry =>
      !crop.isFull || k != 0 || flip || angle != 0;

  bool get isIdentity =>
      crop.isFull &&
      k == 0 &&
      !flip &&
      angle == 0 &&
      adjust.isIdentity &&
      strokes.isEmpty &&
      texts.every((t) => t.text.trim().isEmpty);

  /// Пропорция итогового снимка (после кадра и поворота).
  double outputAspect(double sourceAspect) {
    final ca = crop.w * sourceAspect / crop.h;
    return odd ? 1 / ca : ca;
  }

  MediaEdits copyWith({
    CropRect? crop,
    int? rotation,
    bool? flip,
    double? angle,
    Adjustments? adjust,
    List<DrawStroke>? strokes,
    List<TextItem>? texts,
  }) => MediaEdits(
    crop: crop ?? this.crop,
    rotation: rotation ?? this.rotation,
    flip: flip ?? this.flip,
    angle: angle ?? this.angle,
    adjust: adjust ?? this.adjust,
    strokes: strokes ?? this.strokes,
    texts: texts ?? this.texts,
  );

  /// Пустые тексты не сохраняются (прототип: `cleanE`).
  MediaEdits cleaned() => texts.any((t) => t.text.trim().isEmpty)
      ? copyWith(
          texts: List<TextItem>.unmodifiable(
            texts.where((t) => t.text.trim().isNotEmpty),
          ),
        )
      : this;

  Map<String, Object?> toJson() => {
    'v': 1,
    'crop': crop.toJson(),
    'rd': rotation,
    'flip': flip,
    'angle': angle,
    'adj': adjust.toJson(),
    'strokes': [for (final s in strokes) s.toJson()],
    'texts': [
      for (final t in texts)
        if (t.text.trim().isNotEmpty) t.toJson(),
    ],
  };

  String encode() => jsonEncode(toJson());

  static MediaEdits fromJson(Object? raw) {
    if (raw is! Map) return identity;
    final rd = raw['rd'];
    final angle = raw['angle'];
    final strokes = raw['strokes'];
    final texts = raw['texts'];
    return MediaEdits(
      crop: CropRect.fromJson(raw['crop']),
      rotation: rd is num ? ((rd / 90).round() * 90) : 0,
      flip: raw['flip'] == true,
      angle: angle is num && angle.isFinite
          ? angle.toDouble().clamp(-45.0, 45.0)
          : 0,
      adjust: Adjustments.fromJson(raw['adj']),
      strokes: List<DrawStroke>.unmodifiable(<DrawStroke>[
        if (strokes is List)
          for (final s in strokes) ?DrawStroke.fromJson(s),
      ]),
      texts: List<TextItem>.unmodifiable(<TextItem>[
        if (texts is List)
          for (final t in texts) ?TextItem.fromJson(t),
      ]),
    );
  }

  static MediaEdits? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// Сравнение по смыслу (как `JSON.stringify` в прототипе).
  bool sameAs(MediaEdits other) =>
      identical(this, other) || cleaned().encode() == other.cleaned().encode();
}

/// Наименьший масштаб, при котором рамка кадра после выпрямления не
/// захватывает пустые углы. W, H — размер целого (необрезанного) снимка.
double coverScale(CropRect c, double W, double H, double angleDeg) {
  if (angleDeg == 0 || W <= 0 || H <= 0) return 1;
  final r = angleDeg * math.pi / 180, cs = math.cos(r), sn = math.sin(r);
  final x0 = c.x * W - W / 2, y0 = c.y * H - H / 2;
  final x1 = x0 + c.w * W, y1 = y0 + c.h * H;
  var s = 1.0;
  for (final p in [Offset(x0, y0), Offset(x1, y0), Offset(x0, y1), Offset(x1, y1)]) {
    final u = p.dx * cs + p.dy * sn, v = -p.dx * sn + p.dy * cs;
    s = math.max(s, math.max(u.abs() / (W / 2), v.abs() / (H / 2)));
  }
  return s;
}

/// Раскладка правленого снимка в коробке — `layout()` прототипа.
@immutable
class EditedLayout {
  const EditedLayout._({
    required this.display,
    required this.preRotate,
    required this.full,
    required this.scale,
    required this.k,
  });

  /// Где лежит итоговый снимок в коробке (dw × dh со сдвигом ox, oy).
  final Rect display;

  /// Обрезанная область до поворота на четверти (bw × bh).
  final Size preRotate;

  /// Целый (необрезанный) снимок, W × H.
  final Size full;

  /// Масштаб выпрямления.
  final double scale;
  final int k;

  static EditedLayout compute(
    double sourceAspect,
    MediaEdits e,
    Size box, {
    bool cover = false,
  }) {
    final c = e.crop;
    final a = sourceAspect > 0 && sourceAspect.isFinite ? sourceAspect : 1.0;
    final ca = c.w * a / c.h;
    final oa = e.odd ? 1 / ca : ca;
    double dw, dh;
    final boxAspect = box.height <= 0 ? oa : box.width / box.height;
    if ((!cover) == (boxAspect > oa)) {
      dh = box.height;
      dw = dh * oa;
    } else {
      dw = box.width;
      dh = dw / oa;
    }
    final bw = e.odd ? dh : dw, bh = e.odd ? dw : dh;
    final W = bw / c.w, H = bh / c.h;
    return EditedLayout._(
      display: Rect.fromLTWH((box.width - dw) / 2, (box.height - dh) / 2, dw, dh),
      preRotate: Size(bw, bh),
      full: Size(W, H),
      scale: coverScale(c, W, H, e.angle),
      k: e.k,
    );
  }
}

/// Прямоугольник «contain» снимка с правками в коробке (точка перелёта F).
Rect containRect(double sourceAspect, MediaEdits e, Size box) =>
    EditedLayout.compute(sourceAspect, e, box).display;

/// Матрица цвета, равная цепочке CSS-фильтров прототипа.
/// `ColorFilter.matrix(colorMatrix(a))`.
List<double> colorMatrix(Adjustments a) {
  var m = _identity();
  m = _mul(_brightness(1 + a.brightness * .35), m);
  m = _mul(_contrast(1 + a.contrast * .45), m);
  m = _mul(_saturation(1 + a.saturation * (a.saturation > 0 ? .9 : 1)), m);
  if (a.warmth > 0) {
    m = _mul(_sepia(a.warmth * .32), m);
    m = _mul(_saturation(1 + a.warmth * .2), m);
  } else if (a.warmth < 0) {
    m = _mul(_hueRotate(a.warmth * -14), m);
    m = _mul(_saturation(1 + a.warmth * .12), m);
  }
  return m;
}

/// Виньетка: радиальный градиент от прозрачного на (62 − v·30) % до чёрного
/// с прозрачностью v·0,75.
RadialGradient vignetteGradient(double v) => RadialGradient(
  radius: .7072, // «ellipse at center» прототипа: до углов коробки.
  colors: [
    const Color(0x00000000),
    Color.fromRGBO(0, 0, 0, (v * .75).clamp(0.0, 1.0)),
  ],
  stops: [((62 - v * 30) / 100).clamp(0.0, 1.0), 1],
);

List<double> _identity() => <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

List<double> _mul(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var r = 0; r < 4; r++) {
    for (var c = 0; c < 5; c++) {
      var v = c == 4 ? a[r * 5 + 4] : 0.0;
      for (var i = 0; i < 4; i++) {
        v += a[r * 5 + i] * (c == 4 ? b[i * 5 + 4] : b[i * 5 + c]);
      }
      out[r * 5 + c] = v;
    }
  }
  return out;
}

List<double> _brightness(double b) => <double>[
  b, 0, 0, 0, 0, //
  0, b, 0, 0, 0,
  0, 0, b, 0, 0,
  0, 0, 0, 1, 0,
];

List<double> _contrast(double c) {
  final t = 127.5 * (1 - c);
  return <double>[
    c, 0, 0, 0, t, //
    0, c, 0, 0, t,
    0, 0, c, 0, t,
    0, 0, 0, 1, 0,
  ];
}

List<double> _saturation(double s) {
  const lr = .2126, lg = .7152, lb = .0722;
  return <double>[
    lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0, 0, //
    lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0, 0,
    lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> _sepia(double amount) {
  final a = 1 - amount;
  return <double>[
    .393 + .607 * a, .769 - .769 * a, .189 - .189 * a, 0, 0, //
    .349 - .349 * a, .686 + .314 * a, .168 - .168 * a, 0, 0,
    .272 - .272 * a, .534 - .534 * a, .131 + .869 * a, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> _hueRotate(double deg) {
  final r = deg * math.pi / 180, c = math.cos(r), s = math.sin(r);
  return <double>[
    .213 + c * .787 - s * .213, .715 - c * .715 - s * .715, .072 - c * .072 + s * .928, 0, 0, //
    .213 - c * .213 + s * .143, .715 + c * .285 + s * .140, .072 - c * .072 - s * .283, 0, 0,
    .213 - c * .213 - s * .787, .715 - c * .715 + s * .715, .072 + c * .928 + s * .072, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Сглаженная линия: квадратичные кривые через середины (`pathD()`).
Path strokePath(List<Offset> p) {
  final path = Path();
  if (p.isEmpty) return path;
  path.moveTo(p.first.dx, p.first.dy);
  if (p.length == 1) return path..lineTo(p.first.dx + .01, p.first.dy);
  for (var i = 1; i < p.length - 1; i++) {
    final m = Offset((p[i].dx + p[i + 1].dx) / 2, (p[i].dy + p[i + 1].dy) / 2);
    path.quadraticBezierTo(p[i].dx, p[i].dy, m.dx, m.dy);
  }
  return path..lineTo(p.last.dx, p.last.dy);
}

/// Неон — три слоя; маркер — ширина ×2,2 и прозрачность ,5; ручка — сплошная.
/// Холст — в единицах изображения.
void paintStroke(Canvas canvas, DrawStroke s) {
  final path = strokePath(s.points);
  Paint base(double w, Color c) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true
    ..strokeWidth = w
    ..color = c;
  switch (s.tool) {
    case StrokeTool.pen:
      canvas.drawPath(path, base(s.width, s.color));
    case StrokeTool.marker:
      canvas.drawPath(path, base(s.width * 2.2, s.color.withValues(alpha: .5)));
    case StrokeTool.neon:
      canvas.drawPath(path, base(s.width * 2.6, s.color.withValues(alpha: .22)));
      canvas.drawPath(path, base(s.width * 1.4, s.color.withValues(alpha: .55)));
      canvas.drawPath(path, base(s.width * .5, const Color(0xFFFFFFFF)));
  }
}

/// Текст на цветной подложке: тёмный или светлый по яркости подложки.
Color onColor(Color c) =>
    (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 0.62
    ? const Color(0xFF0E141B)
    : const Color(0xFFFFFFFF);

/// Оформление текста на снимке: кегль [fontSize] в пикселях целого снимка.
TextStyle mediaTextStyle(TextItem t, double fontSize) => TextStyle(
  fontSize: fontSize,
  fontWeight: FontWeight.w700,
  height: 1.15,
  color: t.background ? onColor(t.color) : t.color,
  shadows: t.background
      ? null
      : const <Shadow>[Shadow(color: Color(0x59000000), blurRadius: 8, offset: Offset(0, 1))],
);

/// Пропорция рамки для выбранного варианта; null — «Свободно».
/// `orig` — пропорция исходника; при повороте на 90° пропорции 1:1, 4:5,
/// 16:9 переворачиваются (прототип: `aspectR`).
enum CropAspect { free, original, square, portrait45, wide169 }

double? cropAspectRatio(CropAspect key, int k, double sourceAspect) {
  final double r;
  switch (key) {
    case CropAspect.free:
      return null;
    case CropAspect.original:
      return sourceAspect;
    case CropAspect.square:
      r = 1;
    case CropAspect.portrait45:
      r = .8;
    case CropAspect.wide169:
      r = 16 / 9;
  }
  return k.isOdd ? 1 / r : r;
}

/// Рамка заданной пропорции R (в системе исходника), вписанная по центру
/// прежней рамки (`aspectCrop`).
CropRect aspectCrop(double r, CropRect c, double a) {
  var w = math.min(1.0, r / a);
  var h = w * a / r;
  if (h > 1) {
    h = 1;
    w = r / a;
  }
  final cx = c.x + c.w / 2, cy = c.y + c.h / 2;
  return CropRect(
    (cx - w / 2).clamp(0.0, 1 - w),
    (cy - h / 2).clamp(0.0, 1 - h),
    w,
    h,
  );
}

/// Ручка рамки: углы, стороны или перенос всей рамки.
enum CropHandle { move, tl, tr, bl, br, t, b, l, r }

/// Перетаскивание рамки на (dnx, dny) в долях исходника (`applyCrop`).
/// При заданной пропорции R работают только углы; сторона = перенос.
CropRect applyCrop(
  CropHandle hd,
  CropRect c0,
  double dnx,
  double dny,
  double? r,
  double a,
) {
  const minSide = 0.12;
  if (r != null &&
      (hd == CropHandle.t ||
          hd == CropHandle.b ||
          hd == CropHandle.l ||
          hd == CropHandle.r)) {
    hd = CropHandle.move;
  }
  if (hd == CropHandle.move) {
    return CropRect(
      (c0.x + dnx).clamp(0.0, 1 - c0.w),
      (c0.y + dny).clamp(0.0, 1 - c0.h),
      c0.w,
      c0.h,
    );
  }
  final hasL = hd == CropHandle.tl || hd == CropHandle.bl || hd == CropHandle.l;
  final hasR = hd == CropHandle.tr || hd == CropHandle.br || hd == CropHandle.r;
  final hasT = hd == CropHandle.tl || hd == CropHandle.tr || hd == CropHandle.t;
  final hasB = hd == CropHandle.bl || hd == CropHandle.br || hd == CropHandle.b;
  var l = c0.x, t = c0.y, rr = c0.x + c0.w, b = c0.y + c0.h;
  if (r == null) {
    if (hasL) l = (l + dnx).clamp(0.0, rr - minSide);
    if (hasR) rr = (rr + dnx).clamp(l + minSide, 1.0);
    if (hasT) t = (t + dny).clamp(0.0, b - minSide);
    if (hasB) b = (b + dny).clamp(t + minSide, 1.0);
    return CropRect(l, t, rr - l, b - t);
  }
  final ax = hasL ? rr : l, ay = hasT ? b : t;
  final sx = hasL ? -1.0 : 1.0, sy = hasT ? -1.0 : 1.0;
  var nw = c0.w + sx * dnx;
  final nwH = (c0.h + sy * dny) * r / a;
  if ((sy * dny * r / a).abs() > (sx * dnx).abs()) nw = nwH;
  final maxW = math.min(sx < 0 ? ax : 1 - ax, (sy < 0 ? ay : 1 - ay) * r / a);
  final minW = math.max(minSide, minSide * r / a);
  nw = nw.clamp(math.min(minW, maxW), maxW);
  final nh = nw * a / r;
  l = sx < 0 ? ax - nw : ax;
  t = sy < 0 ? ay - nh : ay;
  return CropRect(l, t, nw, nh);
}

/// Отмена и повтор: один жест (протяжка рамки, шкала, ползунок) = один шаг.
/// Не больше 80 шагов.
class EditHistory {
  final List<MediaEdits> _past = <MediaEdits>[];
  final List<MediaEdits> _future = <MediaEdits>[];

  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;

  void push(MediaEdits before) {
    _past.add(before);
    if (_past.length > 80) _past.removeAt(0);
    _future.clear();
  }

  MediaEdits? undo(MediaEdits current) {
    if (_past.isEmpty) return null;
    _future.add(current);
    return _past.removeLast();
  }

  MediaEdits? redo(MediaEdits current) {
    if (_future.isEmpty) return null;
    _past.add(current);
    return _future.removeLast();
  }
}
