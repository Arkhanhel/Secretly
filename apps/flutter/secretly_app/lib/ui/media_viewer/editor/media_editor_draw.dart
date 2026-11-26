// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Рабочая зона вкладок «Рисунок» и «Коррекция» (снимок «contain» с
/// отступом 12) и панель «Рисунок».
///
/// Прототип: `drawBox`, `toImg`, `hitText`, `drDown`/`drMove`/`drUp`,
/// `eraseAt`; блоки `tools`, `swatches`, `drawHint` в `renderVals()`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../edited_media_view.dart';
import '../media_edits.dart';
import '../media_viewer_tokens.dart';
import 'media_editor_adjust.dart';
import 'media_editor_model.dart';
import 'media_editor_widgets.dart';

/// Отступ коробки рисунка от краёв рабочей зоны (прототип: {12,12,366,472}).
const double kDrawBoxInset = 12;

/// Точка пальца в системе снимка (`toImg`).
@immutable
class _ImgPoint {
  const _ImgPoint(this.nx, this.ny, this.v, this.full, this.scale);

  /// Доли целого снимка.
  final double nx, ny;

  /// Единицы рисунка (ширина целого снимка = 1000).
  final Offset v;

  /// Целый снимок на экране (W × H) и масштаб выпрямления.
  final Size full;
  final double scale;

  /// Единиц рисунка в одном экранном пикселе.
  double get unit => kMediaDrawViewBox / (full.width * scale);
}

/// Экран → снимок: обратная цепочка преобразований `EditedMediaLayers`.
_ImgPoint _toImg(Offset p, MediaEdits e, double aspect, Size box) {
  final l = EditedLayout.compute(aspect, e, box);
  final d = l.display;
  final px = p.dx - d.left - d.width / 2, py = p.dy - d.top - d.height / 2;
  const cosK = <double>[1, 0, -1, 0], sinK = <double>[0, 1, 0, -1];
  final cs = cosK[l.k], sn = sinK[l.k];
  final x1 = px * cs + py * sn, y1 = -px * sn + py * cs;
  final W = l.full.width, H = l.full.height;
  final rx = x1 + l.preRotate.width / 2 + e.crop.x * W - W / 2;
  final ry = y1 + l.preRotate.height / 2 + e.crop.y * H - H / 2;
  final th = e.angle * math.pi / 180, c = math.cos(th), s = math.sin(th);
  final x2 = (rx * c + ry * s) / l.scale, y2 = (-rx * s + ry * c) / l.scale;
  final nx = x2 / W + .5, ny = y2 / H + .5;
  return _ImgPoint(
    nx,
    ny,
    Offset(nx * kMediaDrawViewBox, ny * kMediaDrawViewBox / aspect),
    l.full,
    l.scale,
  );
}

TextItem? _hitText(_ImgPoint p, MediaEdits e) {
  final W = p.full.width, H = p.full.height;
  for (var i = e.texts.length - 1; i >= 0; i--) {
    final tx = e.texts[i];
    final fs = tx.fontFraction * W;
    final len = math.max(2, tx.text.length);
    final hw = .3 * fs * len + fs * (tx.background ? .6 : .35);
    final hh = fs * (tx.background ? .85 : .7);
    if (((p.nx - tx.center.dx) * W).abs() < hw &&
        ((p.ny - tx.center.dy) * H).abs() < hh) {
      return tx;
    }
  }
  return null;
}

enum _DragMode { stroke, erase, text }

/// Снимок с правками в рабочей зоне; на «Рисунке» — ввод пальцем, на
/// «Коррекции» — остров «Сравнить».
class MediaEditorCanvasArea extends StatefulWidget {
  const MediaEditorCanvasArea({
    super.key,
    required this.model,
    required this.image,
    required this.area,
  });

  final MediaEditorModel model;
  final ImageProvider image;
  final Size area;

  @override
  State<MediaEditorCanvasArea> createState() => _MediaEditorCanvasAreaState();
}

class _MediaEditorCanvasAreaState extends State<MediaEditorCanvasArea> {
  int? _pointer;
  _DragMode? _mode;
  String? _textId;
  _ImgPoint? _p0;
  Offset _t0 = Offset.zero;
  bool _moved = false;
  List<Offset> _pts = <Offset>[];

  MediaEditorModel get m => widget.model;

  Rect get _box => Rect.fromLTWH(
    kDrawBoxInset,
    kDrawBoxInset,
    math.max(1, widget.area.width - kDrawBoxInset * 2),
    math.max(1, widget.area.height - kDrawBoxInset * 2),
  );

  _ImgPoint _img(Offset local) =>
      _toImg(local - _box.topLeft, m.e, m.aspect, _box.size);

  void _down(PointerDownEvent ev) {
    if (_pointer != null || m.textEditId != null) return;
    final p = _img(ev.localPosition);
    final e = m.e;
    final hit = m.tool != MediaDrawTool.eraser ? _hitText(p, e) : null;
    _pointer = ev.pointer;
    if (hit != null) {
      _mode = _DragMode.text;
      _textId = hit.id;
      _p0 = p;
      _t0 = hit.center;
      _moved = false;
      m.begin();
      return;
    }
    switch (m.tool) {
      case MediaDrawTool.text:
        _pointer = null;
        m.startNewText(TextItem(
          id: 't${DateTime.now().microsecondsSinceEpoch}',
          center: Offset(p.nx.clamp(.05, .95), p.ny.clamp(.05, .95)),
          text: '',
          color: m.color,
          fontFraction: 26 / (p.full.width * p.scale),
        ));
      case MediaDrawTool.eraser:
        _mode = _DragMode.erase;
        m.begin();
        _eraseAt(p);
      case MediaDrawTool.pen:
      case MediaDrawTool.arrow:
      case MediaDrawTool.marker:
      case MediaDrawTool.neon:
        _mode = _DragMode.stroke;
        _pts = <Offset>[p.v];
        m.liveStroke.value = DrawStroke(
          id: 's${DateTime.now().microsecondsSinceEpoch}',
          tool: switch (m.tool) {
            MediaDrawTool.marker => StrokeTool.marker,
            MediaDrawTool.neon => StrokeTool.neon,
            MediaDrawTool.arrow => StrokeTool.arrow,
            _ => StrokeTool.pen,
          },
          color: m.color,
          width: m.size * p.unit,
          points: _pts,
        );
    }
  }

  void _move(PointerMoveEvent ev) {
    if (ev.pointer != _pointer) return;
    final p = _img(ev.localPosition);
    switch (_mode) {
      case _DragMode.text:
        final p0 = _p0!;
        final W = p.full.width, H = p.full.height;
        if (!_moved &&
            math.sqrt(
                  math.pow((p.nx - p0.nx) * W, 2) +
                      math.pow((p.ny - p0.ny) * H, 2),
                ) <
                4) {
          return;
        }
        _moved = true;
        final c = Offset(
          (_t0.dx + p.nx - p0.nx).clamp(0.0, 1.0),
          (_t0.dy + p.ny - p0.ny).clamp(0.0, 1.0),
        );
        final e = m.e;
        m.live(e.copyWith(texts: List<TextItem>.unmodifiable([
          for (final t in e.texts) t.id == _textId ? t.copyWith(center: c) : t,
        ])));
      case _DragMode.erase:
        _eraseAt(p);
      case _DragMode.stroke:
        final s = m.liveStroke.value;
        if (s == null) return;
        if ((p.v - _pts.last).distance < p.unit * 1.5) return;
        _pts.add(p.v);
        m.liveStroke.value = s.copyWith(points: _pts);
      case null:
        return;
    }
  }

  void _up(PointerEvent ev) {
    if (ev.pointer != _pointer) return;
    _pointer = null;
    final mode = _mode;
    _mode = null;
    switch (mode) {
      case _DragMode.text:
        if (_moved) {
          m.end();
        } else {
          m.startEditText(_textId!);
        }
      case _DragMode.erase:
        m.end();
      case _DragMode.stroke:
        m.commitStroke();
      case null:
        break;
    }
    _textId = null;
    _p0 = null;
  }

  /// Ластик: линии целиком в радиусе 14 px экрана (+ доля толщины) и
  /// тексты под пальцем.
  void _eraseAt(_ImgPoint p) {
    final e = m.e;
    final r = 14 * p.unit;
    final strokes = e.strokes.where((st) {
      final lim = r + st.width * (st.tool == StrokeTool.marker ? 1.1 : .6);
      for (final q in st.points) {
        if ((q - p.v).distance < lim) return false;
      }
      return true;
    }).toList(growable: false);
    final hit = _hitText(p, e);
    final texts = hit == null
        ? e.texts
        : e.texts.where((x) => !identical(x, hit)).toList(growable: false);
    if (strokes.length != e.strokes.length || texts.length != e.texts.length) {
      m.live(e.copyWith(
        strokes: List<DrawStroke>.unmodifiable(strokes),
        texts: List<TextItem>.unmodifiable(texts),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([m, m.edits]),
      builder: (context, _) {
        final cmp = m.compare && m.tab == MediaEditorTab.adjust;
        final box = _box;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fromRect(
              rect: box,
              child: IgnorePointer(
                child: ValueListenableBuilder<DrawStroke?>(
                  valueListenable: m.liveStroke,
                  builder: (context, live, _) => EditedMediaView(
                    image: widget.image,
                    sourceAspect: m.aspect,
                    edits: cmp ? MediaEdits.identity : m.e,
                    showAdjustments: !cmp,
                    liveStroke: live,
                    selectedTextId: m.textEditId,
                    animate: !m.busy,
                  ),
                ),
              ),
            ),
            if (m.tab == MediaEditorTab.draw)
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _down,
                  onPointerMove: _move,
                  onPointerUp: _up,
                  onPointerCancel: _up,
                ),
              ),
            if (m.tab == MediaEditorTab.adjust)
              Positioned(
                right: 14 - 5,
                top: 10 - 5,
                child: MediaEditorCompareIsland(model: m),
              ),
          ],
        );
      },
    );
  }
}

/// Панель «Рисунок» (164 px): инструменты, толщина, цвета, подсказка.
class MediaEditorDrawPanel extends StatelessWidget {
  const MediaEditorDrawPanel({super.key, required this.model});

  final MediaEditorModel model;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final t = MediaViewerTokens.of(context);
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: m,
      builder: (context, _) {
        final tools = <(MediaDrawTool, IconData, String)>[
          (MediaDrawTool.pen, MediaEditorIcons.pen, l10n.meToolPen),
          (MediaDrawTool.arrow, Icons.north_east_rounded, l10n.meToolArrow),
          (MediaDrawTool.marker, MediaEditorIcons.marker, l10n.meToolMarker),
          (MediaDrawTool.neon, MediaEditorIcons.neon, l10n.meToolNeon),
          (MediaDrawTool.eraser, MediaEditorIcons.eraser, l10n.meToolEraser),
          (MediaDrawTool.text, MediaEditorIcons.text, l10n.meToolText),
        ];
        final hint = switch (m.tool) {
          MediaDrawTool.text => l10n.meHintText,
          MediaDrawTool.eraser => l10n.meHintEraser,
          _ => l10n.meHintDraw,
        };
        final dot = m.size.clamp(4.0, 28.0);
        return Stack(
          children: [
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              height: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final (id, icon, label) in tools)
                    Flexible(
                      child: _ToolTile(
                        icon: icon,
                        label: label,
                        selected: m.tool == id,
                        tokens: t,
                        onTap: () => m.selectTool(id),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 78,
              left: 14,
              right: 14,
              height: 44,
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: EditorSlider(
                      value: m.size,
                      min: 2,
                      max: 28,
                      tokens: t,
                      label: l10n.meBrushSize,
                      semanticValue: '${m.size.round()}',
                      onChanged: (v) => m.size = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: Center(
                      child: Container(
                        width: dot,
                        height: dot,
                        decoration: BoxDecoration(
                          color: m.color,
                          shape: BoxShape.circle,
                          boxShadow: const <BoxShadow>[
                            BoxShadow(color: Color(0x66808080), spreadRadius: 1),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final c in kMediaDrawPalette)
                          EditorSwatch(
                            color: c,
                            selected: m.color == c,
                            diameter: 24,
                            tokens: t,
                            onTap: () => m.selectColor(c),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: t.editorSub),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final MediaViewerTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final fg = selected ? t.accent : t.editorInk;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 66,
          height: 58,
          decoration: BoxDecoration(
            color: selected ? t.chip : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: fg),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
