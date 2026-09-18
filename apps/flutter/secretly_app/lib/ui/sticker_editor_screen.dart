// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../app/app_controller.dart';
import '../stickers/sticker_segmentation_service.dart';
import 'secretly_snackbar.dart';
import 'sticker_preview_screen.dart';

/// Telegram-parity sticker editor — ONE screen, everything at once:
///  • photo in a fixed SQUARE frame (pan / pinch-zoom / rotate, two fingers);
///  • «Вырезать объект» pill BELOW the frame → on-device AI, subjects glow along
///    their contour, tap to keep, the background disintegrates («рассыпание»);
///  • a bottom ISLAND — Рисунок (brush + eraser + contour, a white CapCut-style
///    teardrop size slider on the left, a colour row), Коррекция (Экспозиция /
///    Контраст / Насыщенность), Текст, Эмодзи;
///  • ✓ at the top is always «Готово» → opens the preview screen.
///
/// Smart selection: tap a layer to select it, then drag / pinch / rotate from
/// anywhere on the canvas. Pops a [StickerFlowResult] (path + action + emoji) or
/// null on back.
class StickerEditorScreen extends StatefulWidget {
  const StickerEditorScreen({
    super.key,
    required this.sourcePath,
    required this.controller,
    this.textOnly = false,
  });

  final String sourcePath;
  final AppController controller;

  /// Text-only sticker: no photo, transparent canvas, opens straight into text
  /// editing (the «Вырезать объект» pill is hidden).
  final bool textOnly;

  @override
  State<StickerEditorScreen> createState() => _StickerEditorScreenState();
}

enum _Panel { none, draw, adjust, bg }

/// Drawing brushes (CapCut-style). [pen] is the classic solid stroke; [marker]
/// is a translucent highlighter; [neon] is a glowing halo + sharp core;
/// [eraser] clears pixels.
enum _Brush { pen, marker, neon, eraser }

/// Background behind a text layer (Instagram/CapCut style).
enum _TextBgStyle { none, solid, pill }

class _StickerEditorScreenState extends State<StickerEditorScreen>
    with TickerProviderStateMixin {
  ui.Image? _base; // the working base — the photo, then the cutout
  bool _busy = false;
  double _squareSide = 1;

  // base transform
  Offset _bOff = Offset.zero;
  double _bScale = 1, _bRot = 0;
  Offset _g0 = Offset.zero, _bOff0 = Offset.zero;
  double _bScale0 = 1, _bRot0 = 0;

  // cutout
  bool _selecting = false;
  bool _dissolving = false;
  StickerSegmentation? _seg;
  ui.Image? _frameImg; // captured frame, kept for the particle source
  final List<ui.Image> _subjectImg = <ui.Image>[];
  final Set<int> _selected = <int>{};
  List<_Particle> _particles = const <_Particle>[];
  bool _didCut = false;

  // panels / draw
  _Panel _panel = _Panel.none;
  _Brush _brush = _Brush.pen;
  double _brushSize = 0.025;
  Color _drawColor = const Color(0xFFFF4D6D);
  bool _contour = false;
  double _contourWidth = 0.03; // white sticker-border thickness
  Color _contourColor = Colors.white;
  // The raw photo fills the square (cover); a cutout is shown whole (contain).
  bool _baseCover = true;
  Color? _stickerBg; // optional solid background behind the sticker
  final List<_Stroke> _strokes = <_Stroke>[];

  // adjust
  double _exposure = 0, _contrast = 1, _saturation = 1;

  // layers
  final List<_Layer> _layers = <_Layer>[];
  int _active = -1;
  // Centre-snap guides shown while dragging a layer.
  bool _snapH = false, _snapV = false;

  // Undo / redo — snapshots of strokes + layers + adjust, pushed before each
  // discrete edit. Capped so a long session can't grow unbounded.
  final List<_EditSnapshot> _undoStack = <_EditSnapshot>[];
  final List<_EditSnapshot> _redoStack = <_EditSnapshot>[];
  static const int _undoCap = 40;

  // Inline ("on-canvas") text editing — TikTok/CapCut style, no modal sheet.
  bool _editingText = false;
  int? _editingLayer; // null = creating a new layer
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _textFocus = FocusNode();
  Color _textColor = Colors.white;
  String _textFont = 'Inter';
  _TextBgStyle _textBgStyle = _TextBgStyle.none;
  Color _textBgColor = Colors.black;
  bool _colorTargetBg = false; // right colour slider edits bg vs text
  Color? _textOutline; // null = none; cycles none → white → black

  /// Fonts offered in the text editor (bundled families — Inter/Roboto plus the
  /// OFL display/handwriting set). Shown in a horizontal scroll.
  static const List<String> _editorFonts = <String>[
    'Inter',
    'Roboto',
    'Pacifico',
    'Lobster',
    'Bangers',
    'Anton',
    'BebasNeue',
    'Righteous',
    'Monoton',
    'Kalam',
    'Creepster',
    'PressStart2P',
  ];

  // Repaint ticker for live drawing — bumped per brush point WITHOUT a full
  // setState/rebuild so strokes show up instantly (the painter listens to it).
  final ValueNotifier<int> _strokeTick = ValueNotifier<int>(0);

  final GlobalKey _exportKey = GlobalKey();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final AnimationController _dissolve = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _loadBase();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _dissolve.dispose();
    _strokeTick.dispose();
    _textCtrl.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  Future<void> _loadBase() async {
    if (widget.textOnly) {
      // No photo — transparent canvas, jump straight into text editing.
      _baseCover = false;
      _didCut = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addOrEditText();
      });
      return;
    }
    final im = await _decode(widget.sourcePath);
    if (mounted) setState(() => _base = im);
  }

  bool get _brushing => _panel == _Panel.draw && !_contour;

  // ───────────────────────────────────────────────────────── cutout ──
  Future<void> _cutout() async {
    if (_busy || _dissolving) return;
    setState(() {
      _busy = true;
      _panel = _Panel.none;
    });
    try {
      final framePath = await _captureBaseFlat();
      final frameImg = framePath == null ? null : await _decode(framePath);
      final seg = framePath == null
          ? null
          : await StickerSegmentationService.instance.segment(framePath);
      if (!mounted) return;
      if (seg == null || seg.subjects.isEmpty || frameImg == null) {
        setState(() => _busy = false);
        _toast('Объект не распознан');
        return;
      }
      _subjectImg.clear();
      for (final s in seg.subjects) {
        final im = await _decode(s.maskedPngPath);
        if (im != null) _subjectImg.add(im);
      }
      if (!mounted) return;
      setState(() {
        _frameImg = frameImg;
        _seg = seg;
        _selected
          ..clear()
          ..addAll(List<int>.generate(seg.subjects.length, (i) => i));
        _selecting = true;
        _busy = false;
      });
      _pulse.repeat(reverse: true);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyCutout() async {
    final seg = _seg;
    if (seg == null || _selected.isEmpty) {
      _toast('Выберите объект');
      return;
    }
    setState(() => _busy = true);
    await _buildParticles();
    final composed = await StickerSegmentationService.instance.composeSticker(
      (_selected.toList()..sort())
          .map((i) => seg.subjects[i].maskedPngPath)
          .toList(growable: false),
    );
    final composedImg = composed == null ? null : await _decode(composed);
    if (!mounted) return;
    _pulse.stop();
    setState(() {
      _busy = false;
      _selecting = false;
      _dissolving = true;
    });
    await _dissolve.forward(from: 0);
    if (!mounted) return;
    setState(() {
      if (composedImg != null) _base = composedImg;
      _baseCover = false;
      _bOff = Offset.zero;
      _bScale = 1;
      _bRot = 0;
      _exposure = 0;
      _contrast = 1;
      _saturation = 1;
      _strokes.clear();
      // The cutout swaps the base image — past snapshots reference the old base,
      // so the undo history starts fresh from the cutout.
      _undoStack.clear();
      _redoStack.clear();
      _dissolving = false;
      _didCut = true;
    });
  }

  void _cancelCutout() {
    _pulse.stop();
    setState(() {
      _selecting = false;
      _seg = null;
      _subjectImg.clear();
      _selected.clear();
    });
  }

  /// Render the base (with its transform) into a flat opaque image for the AI.
  Future<String?> _captureBaseFlat() async {
    final base = _base;
    if (base == null) return null;
    try {
      const double side = 1024;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, side, side),
        Paint()..color = const Color(0xFF000000),
      );
      final k = side / _squareSide;
      _paintBase(
        canvas,
        const Size(side, side),
        base,
        _bOff * k,
        _bScale,
        _bRot,
        cover: true,
      );
      final pic = rec.endRecording();
      final image = await pic.toImage(side.toInt(), side.toInt());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/sticker_frame_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image?> _decode(String path) async {
    try {
      final codec = await ui.instantiateImageCodec(
        await File(path).readAsBytes(),
      );
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  Future<void> _buildParticles() async {
    final frame = _frameImg, seg = _seg;
    if (frame == null || seg == null) return;
    try {
      final w = frame.width, h = frame.height;
      final photo = await frame.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (photo == null) return;
      final kept = Uint8List(w * h);
      for (final i in _selected) {
        if (i < 0 || i >= _subjectImg.length) continue;
        final s = await _subjectImg[i].toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (s == null) continue;
        for (var p = 0; p < w * h; p++) {
          final a = s.getUint8(p * 4 + 3);
          if (a > kept[p]) kept[p] = a;
        }
      }
      final cell = math.max(3, (math.max(w, h) / 70).round());
      final rnd = math.Random(7);
      final parts = <_Particle>[];
      for (var y = 0; y < h; y += cell) {
        for (var x = 0; x < w; x += cell) {
          final idx = y * w + x;
          if (kept[idx] > 40) continue;
          final o = idx * 4;
          final a = photo.getUint8(o + 3);
          if (a < 8) continue;
          parts.add(
            _Particle(
              nx: x / w,
              ny: y / h,
              color: Color.fromARGB(
                a,
                photo.getUint8(o),
                photo.getUint8(o + 1),
                photo.getUint8(o + 2),
              ),
              vx: (rnd.nextDouble() - 0.5) * 0.5,
              vy: -0.15 - rnd.nextDouble() * 0.5,
              delay: (x / w) * 0.35 + rnd.nextDouble() * 0.2,
              cell: cell / w,
            ),
          );
        }
      }
      _particles = parts;
    } catch (_) {
      _particles = const <_Particle>[];
    }
  }

  // ───────────────────────────────────────────── gestures (smart) ──
  void _onTapUp(Offset pos, Size size) {
    if (_selecting) {
      _toggleSubject(pos, size);
      return;
    }
    if (_brushing) return;
    for (var i = _layers.length - 1; i >= 0; i--) {
      if (_layers[i].hitTest(pos, size)) {
        if (_active == i && _layers[i].isText) {
          _addOrEditText(i);
        } else {
          setState(() => _active = i);
        }
        return;
      }
    }
    setState(() => _active = -1);
  }

  void _toggleSubject(Offset pos, Size size) {
    final seg = _seg;
    if (seg == null) return;
    final sx = size.width / seg.srcWidth, sy = size.height / seg.srcHeight;
    int? hit;
    double best = double.infinity;
    for (var i = 0; i < seg.subjects.length; i++) {
      final r = Rect.fromLTWH(
        seg.subjects[i].bounds.left * sx,
        seg.subjects[i].bounds.top * sy,
        seg.subjects[i].bounds.width * sx,
        seg.subjects[i].bounds.height * sy,
      );
      if (r.contains(pos) && r.width * r.height < best) {
        hit = i;
        best = r.width * r.height;
      }
    }
    if (hit == null) return;
    setState(
      () =>
          _selected.contains(hit) ? _selected.remove(hit) : _selected.add(hit!),
    );
  }

  void _scaleStart(ScaleStartDetails d, Size size) {
    if (_selecting) return;
    _g0 = d.focalPoint;
    if (_brushing) {
      _pushUndo();
      _strokes.add(
        _Stroke(brush: _brush, color: _drawColor, radius: _brushSize)
          ..points.add(_norm(d.localFocalPoint, size)),
      );
      setState(() {});
      return;
    }
    if (_active >= 0 && _active < _layers.length) {
      final l = _layers[_active];
      l.startScale = l.scale;
      l.startRot = l.rotation;
      l.startCenter = l.center;
    } else {
      _bOff0 = _bOff;
      _bScale0 = _bScale;
      _bRot0 = _bRot;
    }
  }

  void _scaleUpdate(ScaleUpdateDetails d, Size size) {
    if (_selecting) return;
    if (_brushing) {
      if (_strokes.isNotEmpty) {
        // Add the point and repaint via the ticker only — NO setState, so the
        // stroke renders live without rebuilding the whole editor each move.
        _strokes.last.points.add(_norm(d.localFocalPoint, size));
        _strokeTick.value++;
      }
      return;
    }
    if (_active >= 0 && _active < _layers.length) {
      final l = _layers[_active];
      setState(() {
        l.scale = (l.startScale * d.scale).clamp(0.15, 8.0);
        l.rotation = l.startRot + d.rotation;
        var cx = l.startCenter.dx + (d.focalPoint.dx - _g0.dx) / size.width;
        var cy = l.startCenter.dy + (d.focalPoint.dy - _g0.dy) / size.height;
        // Magnetic snap to the canvas centre, with a guide line + a tick.
        const snap = 0.018;
        final sh = (cx - 0.5).abs() < snap;
        final sv = (cy - 0.5).abs() < snap;
        if (sh) cx = 0.5;
        if (sv) cy = 0.5;
        if ((sh && !_snapH) || (sv && !_snapV)) {
          HapticFeedback.selectionClick();
        }
        _snapH = sh;
        _snapV = sv;
        l.center = Offset(cx, cy);
      });
      return;
    }
    setState(() {
      _bScale = (_bScale0 * d.scale).clamp(0.3, 8.0);
      _bRot = _bRot0 + d.rotation;
      _bOff = _bOff0 + (d.focalPoint - _g0);
    });
  }

  Offset _norm(Offset p, Size s) => Offset(p.dx / s.width, p.dy / s.height);

  // ───────────────────────────────────────────────────────── layers ──
  Future<void> _addEmoji() async {
    final e = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (_) => const _EmojiSheet(),
    );
    if (e == null || !mounted) return;
    _pushUndo();
    setState(() {
      _panel = _Panel.none;
      _layers.add(_Layer(text: e, isText: false, fontSize: 0.22));
      _active = _layers.length - 1;
    });
  }

  /// Enter inline ("on-canvas") text editing — no modal sheet. The text is
  /// typed + styled directly over the sticker; «Готово» commits it to a layer.
  void _addOrEditText([int? editIndex]) {
    final existing = editIndex != null ? _layers[editIndex] : null;
    setState(() {
      _panel = _Panel.none;
      _editingText = true;
      _editingLayer = editIndex;
      _textCtrl.text = existing?.text ?? '';
      _textColor = existing?.color ?? Colors.white;
      _textFont = existing?.fontFamily ?? 'Inter';
      _textBgStyle = existing?.bgStyle ?? _TextBgStyle.none;
      _textBgColor =
          (existing != null && existing.bgColor != const Color(0x00000000))
          ? existing.bgColor
          : Colors.black;
      _textOutline = existing?.outline;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFocus.requestFocus();
    });
  }

  void _commitTextEdit() {
    final text = _textCtrl.text.trim();
    final idx = _editingLayer;
    _textFocus.unfocus();
    if (text.isNotEmpty || idx != null) _pushUndo();
    setState(() {
      _editingText = false;
      _editingLayer = null;
      final bg = _textBgStyle == _TextBgStyle.none
          ? const Color(0x00000000)
          : _textBgColor;
      if (text.isEmpty) {
        if (idx != null && idx >= 0 && idx < _layers.length) {
          _layers.removeAt(idx);
          _active = -1;
        }
        return;
      }
      if (idx != null && idx >= 0 && idx < _layers.length) {
        final l = _layers[idx]
          ..text = text
          ..color = _textColor
          ..fontFamily = _textFont
          ..bgStyle = _textBgStyle
          ..bgColor = bg
          ..outline = _textOutline;
        l.isText = true;
        _active = idx;
      } else {
        _layers.add(
          _Layer(
            text: text,
            isText: true,
            fontSize: 0.13,
            color: _textColor,
            fontFamily: _textFont,
            bgStyle: _textBgStyle,
            bgColor: bg,
            outline: _textOutline,
          ),
        );
        _active = _layers.length - 1;
      }
    });
  }

  void _deleteActive() {
    if (_active < 0 || _active >= _layers.length) return;
    HapticFeedback.mediumImpact();
    _pushUndo();
    setState(() {
      _layers.removeAt(_active);
      _active = -1;
    });
  }

  // ───────────────────────────────────────────────────────── undo/redo ──
  _EditSnapshot _snapshot() => _EditSnapshot(
    strokes: _strokes.map((s) => s.clone()).toList(),
    layers: _layers.map((l) => l.clone()).toList(),
    exposure: _exposure,
    contrast: _contrast,
    saturation: _saturation,
  );

  /// Capture the current state BEFORE a discrete edit (stroke / layer change).
  void _pushUndo() {
    _undoStack.add(_snapshot());
    if (_undoStack.length > _undoCap) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _applySnapshot(_EditSnapshot s) {
    _strokes
      ..clear()
      ..addAll(s.strokes.map((e) => e.clone()));
    _layers
      ..clear()
      ..addAll(s.layers.map((e) => e.clone()));
    _exposure = s.exposure;
    _contrast = s.contrast;
    _saturation = s.saturation;
    _active = -1;
    _strokeTick.value++;
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    HapticFeedback.selectionClick();
    _redoStack.add(_snapshot());
    final s = _undoStack.removeLast();
    setState(() => _applySnapshot(s));
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    HapticFeedback.selectionClick();
    _undoStack.add(_snapshot());
    final s = _redoStack.removeLast();
    setState(() => _applySnapshot(s));
  }

  /// Corner handles on the active layer: ✕ (delete) top-left, ↻ (scale/rotate)
  /// bottom-right, positioned on the layer's ROTATED bounding box.
  List<Widget> _activeLayerHandles(Size size) {
    if (_active < 0 || _active >= _layers.length) return const <Widget>[];
    final l = _layers[_active];
    final cx = l.center.dx * size.width;
    final cy = l.center.dy * size.height;
    final half = l.fontSize * size.width * l.scale * 1.15 + 16;
    final cosR = math.cos(l.rotation), sinR = math.sin(l.rotation);
    Offset corner(double dx, double dy) =>
        Offset(cx + dx * cosR - dy * sinR, cy + dx * sinR + dy * cosR);
    final del = corner(-half, -half);
    final sr = corner(half, half);

    Widget handle(
      Offset p,
      IconData icon, {
      VoidCallback? onTap,
      GestureDragUpdateCallback? onPan,
    }) {
      return Positioned(
        left: p.dx - 15,
        top: p.dy - 15,
        width: 30,
        height: 30,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onPanUpdate: onPan,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 4),
              ],
            ),
            child: Icon(icon, size: 16, color: Colors.black87),
          ),
        ),
      );
    }

    return <Widget>[
      handle(del, Icons.close_rounded, onTap: _deleteActive),
      handle(
        sr,
        Icons.open_in_full_rounded,
        onPan: (d) => _handleScaleRotate(d, size),
      ),
    ];
  }

  void _handleScaleRotate(DragUpdateDetails d, Size size) {
    if (_active < 0 || _active >= _layers.length) return;
    final box = _exportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final l = _layers[_active];
    final center =
        box.localToGlobal(Offset.zero) +
        Offset(l.center.dx * size.width, l.center.dy * size.height);
    final v = d.globalPosition - center;
    final prev = v - d.delta;
    if (prev.distance < 6 || v.distance < 6) return;
    setState(() {
      l.scale = (l.scale * (v.distance / prev.distance)).clamp(0.15, 8.0);
      l.rotation += v.direction - prev.direction;
    });
  }

  // ───────────────────────────────────────────────────────── confirm ──
  Future<void> _confirm() async {
    if (_busy || _dissolving) return;
    if (_selecting) {
      await _applyCutout();
      return;
    }
    setState(() {
      _busy = true;
      _active = -1;
      _panel = _Panel.none;
    });
    await WidgetsBinding.instance.endOfFrame;
    String? path;
    try {
      final b =
          _exportKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final pr = b.size.width > 0 ? 512.0 / b.size.width : 2.0;
      final image = await b.toImage(pixelRatio: pr);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data != null) {
        final dir = await getTemporaryDirectory();
        path =
            '${dir.path}/sticker_final_${DateTime.now().millisecondsSinceEpoch}.png';
        await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    if (path == null) return;
    final finalPath = path;
    // Push the preview; bubble its result up so back returns HERE (the editor).
    final result = await Navigator.of(context).push<StickerPreviewResult>(
      MaterialPageRoute(
        builder: (_) => StickerPreviewScreen(
          stickerPath: finalPath,
          controller: widget.controller,
        ),
      ),
    );
    if (result == null || !mounted) return;
    Navigator.of(context).pop(
      StickerFlowResult(
        // The preview hands back an animated-WebP override when the user «оживил»
        // the sticker; otherwise keep the editor's static PNG.
        stickerPath: result.stickerPathOverride ?? finalPath,
        action: result.action,
        emoji: result.emoji,
        format: result.format,
      ),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SecretlySnackBar(content: Text(m)));
  }

  // ──────────────────────────────────────────────────────────── build ──
  void _cancelTextEdit() {
    _textFocus.unfocus();
    setState(() {
      _editingText = false;
      _editingLayer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _busy ? null : _cancelCutout,
              )
            : (_editingText
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _cancelTextEdit,
                    )
                  : null),
        title: Text(
          _editingText ? 'Текст' : (_selecting ? 'Выделите объект' : 'Стикер'),
        ),
        actions: [
          if (!_selecting && !_editingText) ...[
            IconButton(
              tooltip: 'Отменить',
              icon: const Icon(Icons.undo_rounded),
              onPressed: _undoStack.isEmpty ? null : _undo,
            ),
            IconButton(
              tooltip: 'Вернуть',
              icon: const Icon(Icons.redo_rounded),
              onPressed: _redoStack.isEmpty ? null : _redo,
            ),
          ],
          if (!_selecting && !_editingText && _active >= 0)
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _deleteActive,
            ),
          if (_editingText)
            IconButton(
              tooltip: 'Готово',
              icon: const Icon(Icons.check_rounded),
              onPressed: _commitTextEdit,
            )
          else if (!_selecting)
            IconButton(
              tooltip: 'Готово',
              icon: const Icon(Icons.check_rounded),
              onPressed: _busy ? null : _confirm,
            ),
        ],
      ),
      body: _editingText
          ? _textEditBody()
          : Column(
              children: [
                Expanded(child: Center(child: _square())),
                if (_selecting)
                  _selectingBar()
                else ...[
                  if (!widget.textOnly) _cutPill(),
                  _islandOrPanel(),
                ],
              ],
            ),
    );
  }

  // ── Inline (on-canvas) text editor — TikTok/CapCut style ───────────────
  Widget _textEditBody() {
    // Column + default resizeToAvoidBottomInset: the canvas area shrinks above
    // the keyboard and grows back when it hides, so the docked style bar (and
    // its buttons) is ALWAYS on-screen — never stranded behind the system nav
    // bar when the keyboard is dismissed mid-edit.
    return ColoredBox(
      color: const Color(0xFF101012),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Tap the backdrop to commit + leave editing.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _commitTextEdit,
                    child: const SizedBox.expand(),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(52, 16, 52, 16),
                      child: _inlineTextField(),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 16,
                  bottom: 16,
                  child: _ColorSlider(
                    color: _colorTargetBg ? _textBgColor : _textColor,
                    onChanged: (c) => setState(() {
                      if (_colorTargetBg) {
                        _textBgColor = c;
                      } else {
                        _textColor = c;
                      }
                    }),
                  ),
                ),
              ],
            ),
          ),
          _textStyleBar(),
        ],
      ),
    );
  }

  Widget _inlineTextField() {
    const fs = 40.0;
    final editable = TextField(
      controller: _textCtrl,
      focusNode: _textFocus,
      autofocus: true,
      maxLength: 80,
      maxLines: null,
      textAlign: TextAlign.center,
      cursorColor: Colors.white,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(
        color: _textColor,
        fontSize: fs,
        fontFamily: _textFont,
        fontWeight: FontWeight.w800,
        shadows: _textOutline == null
            ? const [Shadow(color: Colors.black54, blurRadius: 8)]
            : null,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        counterText: '',
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: 'Текст',
        hintStyle: TextStyle(color: Colors.white38),
      ),
      onChanged: (_) => setState(() {}),
    );
    Widget field = IntrinsicWidth(
      child: _textOutline == null
          ? editable
          : Stack(
              alignment: Alignment.center,
              children: [
                // Live stroke mirror behind the editable fill.
                IgnorePointer(
                  child: Text(
                    _textCtrl.text.isEmpty ? ' ' : _textCtrl.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fs,
                      fontFamily: _textFont,
                      fontWeight: FontWeight.w800,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = fs * 0.14
                        ..strokeJoin = StrokeJoin.round
                        ..color = _textOutline!,
                    ),
                  ),
                ),
                editable,
              ],
            ),
    );
    if (_textBgStyle != _TextBgStyle.none) {
      field = Container(
        decoration: BoxDecoration(
          color: _textBgColor,
          borderRadius: _textBgStyle == _TextBgStyle.pill
              ? BorderRadius.circular(999)
              : BorderRadius.zero,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: field,
      );
    }
    return field;
  }

  Widget _textStyleBar() {
    return Material(
      color: const Color(0xFF1C1C1E),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fonts — horizontal scroll.
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _editorFonts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _fontChip(_editorFonts[i]),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _outlineChip(),
                    const SizedBox(width: 8),
                    Center(
                      child: Container(
                        width: 1,
                        height: 22,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _bgChip(_TextBgStyle.none, 'Без фона'),
                    const SizedBox(width: 8),
                    _bgChip(_TextBgStyle.solid, 'Заливка'),
                    const SizedBox(width: 8),
                    _bgChip(_TextBgStyle.pill, 'Плашка'),
                    if (_textBgStyle != _TextBgStyle.none) ...[
                      const SizedBox(width: 8),
                      _colorTargetToggle(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fontChip(String family) {
    final sel = _textFont == family;
    return GestureDetector(
      onTap: () => setState(() => _textFont = family),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: sel ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? Colors.white : Colors.white24,
            width: sel ? 2 : 1,
          ),
        ),
        child: Text(
          family == 'PressStart2P' ? 'Aa' : family,
          style: TextStyle(
            color: Colors.white,
            fontFamily: family,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _bgChip(_TextBgStyle style, String label) {
    final sel = _textBgStyle == style;
    return GestureDetector(
      onTap: () => setState(() {
        _textBgStyle = style;
        if (style == _TextBgStyle.none) _colorTargetBg = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: sel ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? Colors.white : Colors.white24,
            width: sel ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  /// Cycles the text outline none → white → black. The dot shows the current.
  Widget _outlineChip() {
    final on = _textOutline != null;
    return GestureDetector(
      onTap: () => setState(() {
        _textOutline = _textOutline == null
            ? Colors.white
            : (_textOutline == Colors.white ? Colors.black : null);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: on ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: on ? Colors.white : Colors.white24,
            width: on ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _textOutline ?? Colors.transparent,
                border: Border.all(color: Colors.white54, width: 2),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Контур',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  /// Toggles whether the right colour slider edits the TEXT or the BACKGROUND.
  Widget _colorTargetToggle() {
    Widget dot(String label, Color c, bool active) => GestureDetector(
      onTap: () => setState(() => _colorTargetBg = label == 'Фон'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? Colors.white : Colors.white24,
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot('Текст', _textColor, !_colorTargetBg),
        const SizedBox(width: 6),
        dot('Фон', _textBgColor, _colorTargetBg),
      ],
    );
  }

  Widget _square() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, c) {
            final side = math.min(c.maxWidth, c.maxHeight);
            _squareSide = side;
            final size = Size(side, side);
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: _busy
                          ? null
                          : (e) => _onTapUp(e.localPosition, size),
                      onScaleStart: _busy ? null : (d) => _scaleStart(d, size),
                      onScaleUpdate: _busy
                          ? null
                          : (d) => _scaleUpdate(d, size),
                      onScaleEnd: (_) {
                        if (_snapH || _snapV) {
                          setState(() => _snapH = _snapV = false);
                        }
                      },
                      child: AnimatedBuilder(
                        animation: _dissolve,
                        builder: (context, _) => Stack(
                          fit: StackFit.expand,
                          children: _stackChildren(size),
                        ),
                      ),
                    ),
                  ),
                ),
                // Centre-snap guides (magenta) while dragging a layer.
                if (_snapH)
                  Positioned(
                    left: side / 2 - 0.5,
                    top: 0,
                    bottom: 0,
                    width: 1,
                    child: const IgnorePointer(
                      child: ColoredBox(color: Color(0xCCFF2D92)),
                    ),
                  ),
                if (_snapV)
                  Positioned(
                    top: side / 2 - 0.5,
                    left: 0,
                    right: 0,
                    height: 1,
                    child: const IgnorePointer(
                      child: ColoredBox(color: Color(0xCCFF2D92)),
                    ),
                  ),
                // Handles for the active layer (✕ delete + ↻ scale/rotate).
                if (!_brushing && !_selecting && _active >= 0)
                  ..._activeLayerHandles(size),
                // Size/width slider (left) + colour slider (right) for both the
                // brush AND the contour outline (so its thickness + colour are
                // adjustable, not fixed).
                if (_panel == _Panel.draw && !_selecting) ...[
                  Positioned(
                    left: 2,
                    top: side * 0.18,
                    height: side * 0.5,
                    child: _TeardropSlider(
                      value: _contour ? _contourWidth : _brushSize,
                      min: _contour ? 0.008 : 0.004,
                      max: _contour ? 0.07 : 0.08,
                      onChanged: (v) => setState(() {
                        if (_contour) {
                          _contourWidth = v;
                        } else {
                          _brushSize = v;
                        }
                      }),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: side * 0.16,
                    height: side * 0.66,
                    child: _ColorSlider(
                      color: _contour ? _contourColor : _drawColor,
                      onChanged: (c) => setState(() {
                        if (_contour) {
                          _contourColor = c;
                        } else {
                          _drawColor = c;
                        }
                      }),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _stackChildren(Size size) {
    final d = Curves.easeIn.transform(_dissolve.value);
    final children = <Widget>[CustomPaint(painter: _CheckerPainter())];

    children.add(
      RepaintBoundary(
        key: _exportKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Optional solid background — exported as part of the sticker.
            if (_stickerBg != null) ColoredBox(color: _stickerBg!),
            if (_dissolving)
              CustomPaint(painter: _ParticlePainter(_particles, d))
            else
              CustomPaint(
                painter: _RefinePainter(
                  base: _base,
                  off: _bOff,
                  scale: _bScale,
                  rot: _bRot,
                  strokes: _strokes,
                  contour: _contour,
                  contourWidth: _contourWidth,
                  contourColor: _contourColor,
                  adjust: _adjustMatrix(),
                  cover: _baseCover,
                  repaintTick: _strokeTick,
                ),
              ),
            // During the dissolve keep the chosen subjects crisp on top.
            if (_dissolving && _seg != null)
              for (final i in _selected)
                if (i >= 0 && i < _subjectImg.length)
                  RawImage(image: _subjectImg[i], fit: BoxFit.cover),
            for (var i = 0; i < _layers.length; i++)
              _layerWidget(i, size, i == _active && !_brushing),
          ],
        ),
      ),
    );

    if (_selecting && _seg != null) {
      children.add(
        Positioned.fill(
          child: CustomPaint(
            painter: _ContourGlowPainter(
              subjects: _subjectImg,
              selected: _selected,
              pulse: _pulse,
            ),
          ),
        ),
      );
    }
    if (_busy) {
      children.add(
        const ColoredBox(
          color: Color(0x88000000),
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }
    return children;
  }

  List<double>? _adjustMatrix() {
    if (_exposure == 0 && _contrast == 1 && _saturation == 1) return null;
    final s = _saturation;
    final l = 1 - s;
    final sr = l * 0.213, sg = l * 0.715, sb = l * 0.072;
    final c = _contrast;
    final o = ((0.5 * (1 - c)) + _exposure) * 255.0;
    return <double>[
      (sr + s) * c, sg * c, sb * c, 0, o, //
      sr * c, (sg + s) * c, sb * c, 0, o, //
      sr * c, sg * c, (sb + s) * c, 0, o, //
      0, 0, 0, 1, 0,
    ];
  }

  Widget _layerWidget(int i, Size size, bool selected) {
    final l = _layers[i];
    return Positioned(
      left: l.center.dx * size.width - size.width / 2,
      top: l.center.dy * size.height - size.height / 2,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: Center(
          child: Transform.rotate(
            angle: l.rotation,
            child: Transform.scale(
              scale: l.scale,
              child: Container(
                decoration: selected
                    ? BoxDecoration(
                        border: Border.all(color: Colors.white70),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                padding: const EdgeInsets.all(4),
                child: _layerTextChild(l, size),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The text/emoji of a layer, with the chosen font and — for text — an
  /// optional solid/pill background drawn behind it.
  /// Text with an optional stroke outline (CapCut/sticker style): a soft shadow
  /// when there's no outline, a stroke-behind-fill Stack when there is.
  Widget _outlinedText(
    String text, {
    required double fontSize,
    required Color color,
    required String family,
    required Color? outline,
  }) {
    final base = TextStyle(
      fontSize: fontSize,
      fontFamily: family,
      fontWeight: FontWeight.w800,
    );
    if (outline == null) {
      return Text(
        text,
        textAlign: TextAlign.center,
        style: base.copyWith(
          color: color,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      );
    }
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.14
              ..strokeJoin = StrokeJoin.round
              ..color = outline,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(color: color),
        ),
      ],
    );
  }

  Widget _layerTextChild(_Layer l, Size size) {
    Widget child = l.isText
        ? _outlinedText(
            l.text,
            fontSize: l.fontSize * size.width,
            color: l.color,
            family: l.fontFamily,
            outline: l.outline,
          )
        : Text(
            l.text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: l.fontSize * size.width),
          );
    if (l.isText && l.bgStyle != _TextBgStyle.none) {
      child = Container(
        decoration: BoxDecoration(
          color: l.bgColor,
          borderRadius: l.bgStyle == _TextBgStyle.pill
              ? BorderRadius.circular(999)
              : BorderRadius.zero,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: child,
      );
    }
    return child;
  }

  // ───────────────────────────────────────────────── bottom chrome ──
  Widget _cutPill() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Material(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _busy ? null : _cutout,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_fix_high_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _didCut ? 'Вырезать заново' : 'Вырезать объект',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Compact CapCut-style editing dock ──────────────────────────────────
  // A slim icon tab bar; the active tool's controls dock compactly above it.
  Widget _islandOrPanel() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_panel != _Panel.none) ...[
              _compactToolPanel(),
              const SizedBox(height: 6),
            ],
            _compactTabBar(),
          ],
        ),
      ),
    );
  }

  Widget _compactTabBar() {
    return Material(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            _compactTabButton(
              Icons.brush_rounded,
              'Рисунок',
              _panel == _Panel.draw,
              () => setState(
                () =>
                    _panel = _panel == _Panel.draw ? _Panel.none : _Panel.draw,
              ),
            ),
            _compactTabButton(
              Icons.tune_rounded,
              'Коррекция',
              _panel == _Panel.adjust,
              () => setState(
                () => _panel = _panel == _Panel.adjust
                    ? _Panel.none
                    : _Panel.adjust,
              ),
            ),
            _compactTabButton(
              Icons.format_color_fill_rounded,
              'Фон',
              _panel == _Panel.bg,
              () => setState(
                () => _panel = _panel == _Panel.bg ? _Panel.none : _Panel.bg,
              ),
            ),
            _compactTabButton(Icons.title_rounded, 'Текст', false, () {
              setState(() => _panel = _Panel.none);
              _addOrEditText();
            }),
            _compactTabButton(
              Icons.emoji_emotions_outlined,
              'Эмодзи',
              false,
              () {
                setState(() => _panel = _Panel.none);
                _addEmoji();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactTabButton(
    IconData icon,
    String tip,
    bool active,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Tooltip(
        message: tip,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Colors.white.withValues(alpha: 0.12) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Colors.white.withValues(alpha: active ? 1.0 : 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactToolPanel() {
    return Material(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: switch (_panel) {
          _Panel.draw => _compactDrawTools(),
          _Panel.adjust => _compactAdjustTools(),
          _Panel.bg => _compactBgTools(),
          _Panel.none => const SizedBox.shrink(),
        },
      ),
    );
  }

  Widget _toolDivider() => Container(
    width: 1,
    height: 22,
    color: Colors.white.withValues(alpha: 0.12),
  );

  Widget _compactDrawTools() {
    Widget brushToggle(_Brush b, IconData icon) =>
        _compactToolToggle(icon, _brush == b && !_contour, () {
          HapticFeedback.selectionClick();
          setState(() {
            _brush = b;
            _contour = false;
          });
        });
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Current colour — chosen with the right-side colour slider.
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _drawColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          _toolDivider(),
          const SizedBox(width: 12),
          brushToggle(_Brush.pen, Icons.edit_rounded),
          brushToggle(_Brush.marker, Icons.highlight_rounded),
          brushToggle(_Brush.neon, Icons.auto_awesome_rounded),
          brushToggle(_Brush.eraser, Icons.cleaning_services_rounded),
          const SizedBox(width: 12),
          _toolDivider(),
          const SizedBox(width: 12),
          // White sticker-border outline (Telegram-style). Width + colour are
          // set with the left/right sliders while it's active.
          _compactToolToggle(Icons.border_outer_rounded, _contour, () {
            HapticFeedback.selectionClick();
            setState(() => _contour = !_contour);
          }),
        ],
      ),
    );
  }

  Widget _compactToolToggle(IconData icon, bool active, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: Colors.white.withValues(alpha: active ? 1.0 : 0.65),
        ),
      ),
    );
  }

  Widget _compactBgTools() {
    const swatches = <Color?>[
      null,
      Colors.white,
      Colors.black,
      Color(0xFFFF4D6D),
      Color(0xFFFFD60A),
      Color(0xFF34C759),
      Color(0xFF4DA3FF),
      Color(0xFFAF52DE),
      Color(0xFFFF9F0A),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in swatches)
              GestureDetector(
                onTap: () => setState(() => _stickerBg = c),
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: c ?? Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _stickerBg == c ? Colors.white : Colors.white24,
                      width: _stickerBg == c ? 3 : 1,
                    ),
                  ),
                  child: c == null
                      ? const Icon(
                          Icons.block_rounded,
                          size: 16,
                          color: Colors.white54,
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _compactAdjustTools() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _compactSliderRow(
            'Экспозиция',
            _exposure,
            -0.35,
            0.35,
            (v) => setState(() => _exposure = v),
            reset: 0,
          ),
          _compactSliderRow(
            'Контраст',
            _contrast,
            0.6,
            1.5,
            (v) => setState(() => _contrast = v),
            reset: 1,
          ),
          _compactSliderRow(
            'Насыщенность',
            _saturation,
            0,
            2,
            (v) => setState(() => _saturation = v),
            reset: 1,
          ),
        ],
      ),
    );
  }

  Widget _compactSliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    required double reset,
  }) {
    return Row(
      children: [
        // Double-tap the label to reset this adjustment to its default.
        GestureDetector(
          onDoubleTap: () {
            HapticFeedback.selectionClick();
            onChanged(reset);
          },
          child: SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  /// Cutout-selection footer: a hint + the CONFIRM button right under the photo
  /// (the confirm is here, not a top-bar ✓, per device feedback).
  Widget _selectingBar() {
    final multi = (_seg?.subjects.length ?? 0) > 1;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              multi ? 'Нажмите на объекты, которые оставить' : 'Объект выделен',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4DA3FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: _busy ? null : _applyCutout,
                icon: const Icon(Icons.content_cut_rounded),
                label: const Text('Вырезать объект'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shared base draw — used by the painter and the AI-capture recorder.
  static void _paintBase(
    Canvas canvas,
    Size size,
    ui.Image image,
    Offset off,
    double scale,
    double rot, {
    bool cover = false,
    Paint? paint,
  }) {
    canvas.save();
    canvas.translate(size.width / 2 + off.dx, size.height / 2 + off.dy);
    canvas.rotate(rot);
    canvas.scale(scale);
    canvas.translate(-size.width / 2, -size.height / 2);
    final ia = image.width / image.height;
    double w, h;
    if (cover) {
      if (ia > 1) {
        h = size.height;
        w = h * ia;
      } else {
        w = size.width;
        h = w / ia;
      }
    } else {
      if (ia > 1) {
        w = size.width;
        h = w / ia;
      } else {
        h = size.height;
        w = h * ia;
      }
    }
    final dst = Rect.fromLTWH(
      (size.width - w) / 2,
      (size.height - h) / 2,
      w,
      h,
    );
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(
      image,
      src,
      dst,
      paint ?? (Paint()..isAntiAlias = true),
    );
    canvas.restore();
  }
}

// ─────────────────────────────────────────────────────────── models ──
class _Particle {
  _Particle({
    required this.nx,
    required this.ny,
    required this.color,
    required this.vx,
    required this.vy,
    required this.delay,
    required this.cell,
  });
  final double nx, ny, vx, vy, delay, cell;
  final Color color;
}

class _Stroke {
  _Stroke({required this.brush, required this.color, required this.radius});
  final _Brush brush;
  final Color color;
  final double radius;
  final List<Offset> points = <Offset>[];

  _Stroke clone() =>
      _Stroke(brush: brush, color: color, radius: radius)
        ..points.addAll(points);
}

class _Layer {
  _Layer({
    required this.text,
    required this.isText,
    required this.fontSize,
    this.color = Colors.white,
    this.fontFamily = 'Inter',
    this.bgStyle = _TextBgStyle.none,
    this.bgColor = const Color(0x00000000),
    this.outline,
  });
  String text;
  bool isText;
  double fontSize;
  Color color;
  String fontFamily;
  _TextBgStyle bgStyle;
  Color bgColor;
  Color? outline; // null = none; otherwise the stroke colour
  Offset center = const Offset(0.5, 0.5);
  double scale = 1, rotation = 0;
  double startScale = 1, startRot = 0;
  Offset startCenter = const Offset(0.5, 0.5);

  bool hitTest(Offset pos, Size size) {
    final c = Offset(center.dx * size.width, center.dy * size.height);
    final half = fontSize * size.width * scale * 1.4 + 24;
    return (pos - c).distance <= half;
  }

  _Layer clone() =>
      _Layer(
          text: text,
          isText: isText,
          fontSize: fontSize,
          color: color,
          fontFamily: fontFamily,
          bgStyle: bgStyle,
          bgColor: bgColor,
          outline: outline,
        )
        ..center = center
        ..scale = scale
        ..rotation = rotation;
}

/// Immutable snapshot of the reversible editor state for undo/redo.
class _EditSnapshot {
  _EditSnapshot({
    required this.strokes,
    required this.layers,
    required this.exposure,
    required this.contrast,
    required this.saturation,
  });
  final List<_Stroke> strokes;
  final List<_Layer> layers;
  final double exposure, contrast, saturation;
}

// ─────────────────────────────────────────────── teardrop slider ──
/// Vertical colour bar (right side, mirrors the size slider). A single drag
/// sweeps white → full-spectrum hues → black, so it covers colour AND
/// brightness — more flexible than a fixed swatch row. A ring shows the current
/// colour.
class _ColorSlider extends StatelessWidget {
  const _ColorSlider({required this.color, required this.onChanged});
  final Color color;
  final ValueChanged<Color> onChanged;

  static const List<Color> _stops = <Color>[
    Colors.white,
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C7BE),
    Color(0xFF007AFF),
    Color(0xFFAF52DE),
    Color(0xFFFF2D92),
    Colors.black,
  ];

  static Color _colorAt(double t) {
    t = t.clamp(0.0, 1.0);
    final seg = t * (_stops.length - 1);
    final i = seg.floor().clamp(0, _stops.length - 2);
    return Color.lerp(_stops[i], _stops[i + 1], seg - i)!;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        void pick(Offset local) {
          final h = c.maxHeight <= 0 ? 1.0 : c.maxHeight;
          onChanged(_colorAt(local.dy / h));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => pick(d.localPosition),
          onVerticalDragStart: (d) => pick(d.localPosition),
          onVerticalDragUpdate: (d) => pick(d.localPosition),
          child: Container(
            width: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _stops,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 6),
              ],
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// White CapCut-style vertical size slider (narrow at the bottom, wide at the
/// top). Compact — about a third the height of a full-canvas slider.
class _TeardropSlider extends StatelessWidget {
  const _TeardropSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final double value, min, max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final t = ((value - min) / (max - min)).clamp(0.0, 1.0);
        void handle(Offset local) {
          final nt = (1 - (local.dy / h)).clamp(0.0, 1.0);
          onChanged(min + nt * (max - min));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (d) => handle(d.localPosition),
          onVerticalDragUpdate: (d) => handle(d.localPosition),
          onTapDown: (d) => handle(d.localPosition),
          child: SizedBox(
            width: 34,
            height: h,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(size: Size(34, h), painter: _TeardropPainter()),
                Positioned(
                  top: (1 - t) * h - 9,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TeardropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const wTop = 18.0, wBot = 3.0;
    final cx = size.width / 2;
    final path = Path()
      ..moveTo(cx - wBot / 2, size.height)
      ..lineTo(cx - wTop / 2, wTop / 2)
      ..arcToPoint(
        Offset(cx + wTop / 2, wTop / 2),
        radius: const Radius.circular(wTop / 2),
        clockwise: true,
      )
      ..lineTo(cx + wBot / 2, size.height)
      ..arcToPoint(
        Offset(cx - wBot / 2, size.height),
        radius: const Radius.circular(wBot / 2),
        clockwise: true,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _TeardropPainter old) => false;
}

// ─────────────────────────────────────────────────────────── painters ──
class _RefinePainter extends CustomPainter {
  _RefinePainter({
    required this.base,
    required this.off,
    required this.scale,
    required this.rot,
    required this.strokes,
    required this.contour,
    required this.contourWidth,
    required this.contourColor,
    required this.adjust,
    required this.cover,
    required Listenable repaintTick,
  }) : super(repaint: repaintTick);
  final ui.Image? base;
  final Offset off;
  final double scale, rot, contourWidth;
  final Color contourColor;
  final List<_Stroke> strokes;
  final bool contour;
  final List<double>? adjust;
  final bool cover;

  @override
  void paint(Canvas canvas, Size size) {
    final image = base;
    if (image == null) return;
    canvas.saveLayer(Offset.zero & size, Paint());

    if (contour) {
      final r = contourWidth * size.width;
      final sil = Paint()
        ..colorFilter = ColorFilter.mode(contourColor, BlendMode.srcIn)
        ..isAntiAlias = true;
      for (var i = 0; i < 24; i++) {
        final a = i / 24 * 2 * math.pi;
        canvas.save();
        canvas.translate(math.cos(a) * r, math.sin(a) * r);
        _StickerEditorScreenState._paintBase(
          canvas,
          size,
          image,
          off,
          scale,
          rot,
          cover: cover,
          paint: sil,
        );
        canvas.restore();
      }
    }

    final basePaint = Paint()..isAntiAlias = true;
    final m = adjust;
    if (m != null) basePaint.colorFilter = ColorFilter.matrix(m);
    _StickerEditorScreenState._paintBase(
      canvas,
      size,
      image,
      off,
      scale,
      rot,
      cover: cover,
      paint: basePaint,
    );

    for (final s in strokes) {
      final path = _path(s, size);
      // Neon draws a soft blurred halo first, then the sharp core on top.
      if (s.brush == _Brush.neon) {
        final rad = s.radius * size.width;
        final halo = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rad * 2
          ..color = s.color.withValues(alpha: 0.4)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
          ..isAntiAlias = true;
        canvas.drawPath(path, halo);
      }
      canvas.drawPath(path, _buildStrokePaint(s, size));
    }
    canvas.restore();
  }

  /// Per-brush Paint — the only place stroke appearance is defined.
  Paint _buildStrokePaint(_Stroke s, Size size) {
    final rad = s.radius * size.width;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rad * 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    switch (s.brush) {
      case _Brush.pen:
        p.color = s.color;
      case _Brush.marker:
        // Translucent highlighter that layers naturally over the photo.
        p
          ..color = s.color.withValues(alpha: 0.65)
          ..strokeCap = StrokeCap.butt
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5)
          ..blendMode = BlendMode.multiply;
      case _Brush.neon:
        // Sharp core (the halo is drawn separately in paint()).
        p.color = s.color;
      case _Brush.eraser:
        p.blendMode = BlendMode.clear;
    }
    return p;
  }

  Path _path(_Stroke s, Size size) {
    final p = Path();
    if (s.points.isEmpty) return p;
    Offset px(Offset n) => Offset(n.dx * size.width, n.dy * size.height);
    final first = px(s.points.first);
    p.moveTo(first.dx, first.dy);
    for (final pt in s.points.skip(1)) {
      final q = px(pt);
      p.lineTo(q.dx, q.dy);
    }
    if (s.points.length == 1) {
      p.addOval(Rect.fromCircle(center: first, radius: 0.5));
    }
    return p;
  }

  @override
  bool shouldRepaint(covariant _RefinePainter old) =>
      old.base != base ||
      old.off != off ||
      old.scale != scale ||
      old.rot != rot ||
      old.contour != contour ||
      old.contourWidth != contourWidth ||
      old.contourColor != contourColor ||
      old.adjust != adjust ||
      old.cover != cover ||
      old.strokes.length != strokes.length ||
      (strokes.isNotEmpty &&
          old.strokes.isNotEmpty &&
          old.strokes.last.points.length != strokes.last.points.length);
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final lt = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      final s = p.cell * size.width;
      if (lt <= 0) {
        paint.color = p.color;
        canvas.drawRect(
          Rect.fromLTWH(p.nx * size.width, p.ny * size.height, s, s),
          paint,
        );
        continue;
      }
      final ease = Curves.easeOut.transform(lt);
      paint.color = p.color.withValues(alpha: (1 - ease) * p.color.a);
      final sz = s * (1 - 0.4 * ease);
      canvas.drawRect(
        Rect.fromLTWH(
          (p.nx + p.vx * ease) * size.width,
          (p.ny + p.vy * ease) * size.height,
          sz,
          sz,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.t != t;
}

class _ContourGlowPainter extends CustomPainter {
  _ContourGlowPainter({
    required this.subjects,
    required this.selected,
    required this.pulse,
  }) : super(repaint: pulse);
  final List<ui.Image> subjects;
  final Set<int> selected;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < subjects.length; i++) {
      final image = subjects[i];
      final isSel = selected.contains(i);
      final glow = isSel ? (0.45 + 0.55 * pulse.value) : 0.4;
      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final dst = Offset.zero & size;
      canvas.saveLayer(dst, Paint());
      canvas.drawImageRect(
        image,
        src,
        dst,
        Paint()
          ..colorFilter = ColorFilter.mode(
            (isSel ? const Color(0xFF7FD0FF) : Colors.white).withValues(
              alpha: glow,
            ),
            BlendMode.srcIn,
          )
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            (isSel ? 6.0 : 3.0) + (isSel ? 4.0 * pulse.value : 0),
          ),
      );
      canvas.drawImageRect(
        image,
        src,
        dst,
        Paint()..blendMode = BlendMode.dstOut,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ContourGlowPainter old) =>
      old.selected.length != selected.length || old.subjects != subjects;
}

class _CheckerPainter extends CustomPainter {
  static const double _cell = 14;
  final Paint _light = Paint()..color = const Color(0xFF2A2A2A);
  final Paint _dark = Paint()..color = const Color(0xFF1A1A1A);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _dark);
    for (var y = 0.0; y < size.height; y += _cell) {
      for (var x = 0.0; x < size.width; x += _cell) {
        if ((((x / _cell).floor() + (y / _cell).floor()) % 2) == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, _cell, _cell), _light);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerPainter old) => false;
}

// ─────────────────────────────────────────────────────────── sheets ──
class _EmojiSheet extends StatelessWidget {
  const _EmojiSheet();
  static const List<String> _e = <String>[
    '😀',
    '😂',
    '😍',
    '😎',
    '🥳',
    '😭',
    '😡',
    '👍',
    '👎',
    '🙏',
    '👏',
    '🔥',
    '💯',
    '❤️',
    '💔',
    '⭐',
    '✨',
    '🎉',
    '🎁',
    '💀',
    '👀',
    '💪',
    '🤡',
    '👻',
    '🚀',
    '🌈',
    '☀️',
    '🌙',
    '⚡',
    '💎',
    '🍀',
    '🎯',
  ];
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 8,
        children: [
          for (final e in _e)
            InkWell(
              onTap: () => Navigator.of(context).pop(e),
              child: Center(
                child: Text(e, style: const TextStyle(fontSize: 28)),
              ),
            ),
        ],
      ),
    ),
  );
}
