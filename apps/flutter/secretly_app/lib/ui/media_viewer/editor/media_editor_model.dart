// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Состояние редактора фото — `state.ed` прототипа `MediaViewerPhone.dc.html`
/// (`openEditor`, `edSet`/`edCommit`/`edBegin`/`edLive`/`edEnd`,
/// `finishText`, отмена и повтор).
///
/// Правки живут в отдельном [ValueNotifier] ([edits]), живая линия — в
/// [liveStroke]: протяжка пальцем перерисовывает только рабочую зону, а не
/// весь экран. Сам объект уведомляет о «редких» переменах: вкладка,
/// инструмент, цвет, история, режим текста.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../media_edits.dart';

enum MediaEditorTab { crop, draw, adjust }

/// Инструменты вкладки «Рисунок».
enum MediaDrawTool { pen, arrow, marker, neon, eraser, text }

enum MediaEditorHaptic { selection, light, medium }

class MediaEditorModel extends ChangeNotifier {
  MediaEditorModel({
    required this.aspect,
    required this.initial,
    MediaEditorTab tab = MediaEditorTab.crop,
    this.hapticsEnabled,
  }) : edits = ValueNotifier<MediaEdits>(initial),
       _tab = tab;

  /// Пропорция исходника (ширина / высота).
  final double aspect;

  /// Правки на входе — с ними сравнивается «есть ли изменения».
  final MediaEdits initial;
  final bool Function()? hapticsEnabled;

  final ValueNotifier<MediaEdits> edits;
  final ValueNotifier<DrawStroke?> liveStroke = ValueNotifier<DrawStroke?>(null);

  final EditHistory _history = EditHistory();
  MediaEdits? _gestureStart;
  MediaEdits? _textStart;

  MediaEditorTab _tab;
  MediaDrawTool _tool = MediaDrawTool.pen;
  Color _color = const Color(0xFFFF5A5F);
  double _size = 8;
  CropAspect _cropAspect = CropAspect.free;
  String? _textEditId;
  bool _compare = false;
  bool _busy = false;

  MediaEdits get e => edits.value;
  MediaEditorTab get tab => _tab;
  MediaDrawTool get tool => _tool;
  Color get color => _color;

  /// Толщина кисти, 2…28 экранных px.
  double get size => _size;
  CropAspect get cropAspect => _cropAspect;
  String? get textEditId => _textEditId;
  bool get compare => _compare;

  /// Палец ведёт рамку или шкалу: без анимации, с сеткой третей.
  bool get busy => _busy;

  bool get canUndo => _history.canUndo && _textEditId == null;
  bool get canRedo => _history.canRedo && _textEditId == null;

  /// Есть ли что сохранять (пустые тексты не считаются).
  bool get changed => !e.sameAs(initial);

  TextItem? get editingText {
    final id = _textEditId;
    if (id == null) return null;
    for (final t in e.texts) {
      if (t.id == id) return t;
    }
    return null;
  }

  void haptic(MediaEditorHaptic kind) {
    if (!(hapticsEnabled?.call() ?? true)) return;
    switch (kind) {
      case MediaEditorHaptic.selection:
        unawaited(HapticFeedback.selectionClick());
      case MediaEditorHaptic.light:
        unawaited(HapticFeedback.lightImpact());
      case MediaEditorHaptic.medium:
        unawaited(HapticFeedback.mediumImpact());
    }
  }

  // ─── История ─────────────────────────────────────────────────────────────

  /// `edLive`: промежуточное значение жеста, без шага истории.
  void live(MediaEdits next) => edits.value = next;

  /// `edCommit`: новое значение — один шаг истории.
  void commit(MediaEdits next) {
    if (identical(next, e)) return;
    _history.push(e);
    edits.value = next;
    notifyListeners();
  }

  /// `edBegin`: запомнить, с чего начался жест.
  void begin() => _gestureStart = e;

  /// `edEnd`: жест закончился — один шаг, если что-то поменялось.
  void end() {
    final st = _gestureStart;
    _gestureStart = null;
    if (st != null && !identical(st, e)) {
      _history.push(st);
      notifyListeners();
    }
  }

  bool get inGesture => _gestureStart != null;

  void undo() {
    if (!canUndo) return;
    final prev = _history.undo(e);
    if (prev == null) return;
    liveStroke.value = null;
    edits.value = prev;
    haptic(MediaEditorHaptic.light);
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    final next = _history.redo(e);
    if (next == null) return;
    liveStroke.value = null;
    edits.value = next;
    haptic(MediaEditorHaptic.light);
    notifyListeners();
  }

  // ─── Простые поля ────────────────────────────────────────────────────────

  set busy(bool v) {
    if (_busy == v) return;
    _busy = v;
    notifyListeners();
  }

  set compare(bool v) {
    if (_compare == v) return;
    _compare = v;
    notifyListeners();
  }

  void selectTab(MediaEditorTab t) {
    if (_textEditId != null) finishText();
    liveStroke.value = null;
    _compare = false;
    if (_tab != t) {
      _tab = t;
      haptic(MediaEditorHaptic.selection);
    }
    notifyListeners();
  }

  void selectTool(MediaDrawTool t) {
    if (_tool == t) return;
    _tool = t;
    haptic(MediaEditorHaptic.selection);
    notifyListeners();
  }

  set size(double v) {
    final n = v.roundToDouble().clamp(2.0, 28.0);
    if (n == _size) return;
    _size = n;
    notifyListeners();
  }

  /// Цвет кисти; при правке текста — и цвет этого текста.
  void selectColor(Color c) {
    _color = c;
    final id = _textEditId;
    if (id != null) {
      live(e.copyWith(texts: [
        for (final t in e.texts) t.id == id ? t.copyWith(color: c) : t,
      ]));
    }
    notifyListeners();
  }

  // ─── Кадр ────────────────────────────────────────────────────────────────

  void selectAspect(CropAspect key) {
    final r = cropAspectRatio(key, e.k, aspect);
    final next = r == null ? e : e.copyWith(crop: aspectCrop(r, e.crop, aspect));
    if (_cropAspect != key) haptic(MediaEditorHaptic.selection);
    _cropAspect = key;
    if (!next.sameAs(e)) {
      commit(next);
    } else {
      notifyListeners();
    }
  }

  /// 90° против часовой; заданная пропорция вписывается заново.
  void rotate() {
    var next = e.copyWith(rotation: e.rotation - 90);
    final r = cropAspectRatio(_cropAspect, next.k, aspect);
    if (r != null) next = next.copyWith(crop: aspectCrop(r, next.crop, aspect));
    haptic(MediaEditorHaptic.light);
    commit(next);
  }

  void flip() {
    haptic(MediaEditorHaptic.light);
    commit(e.copyWith(flip: !e.flip));
  }

  bool get cropChanged => !e.crop.isFull || e.k != 0 || e.angle != 0 || e.flip;

  /// «Сбросить»: рамка, поворот (к ближайшему кратному 360 — без лишнего
  /// оборота в анимации), выпрямление, отражение; пропорция — «Свободно».
  void resetCrop() {
    haptic(MediaEditorHaptic.light);
    _cropAspect = CropAspect.free;
    commit(e.copyWith(
      crop: CropRect.full,
      rotation: (e.rotation / 360).round() * 360,
      angle: 0,
      flip: false,
    ));
  }

  // ─── Коррекция ───────────────────────────────────────────────────────────

  /// Двойное нажатие по названию — сброс одного ползунка (один шаг).
  void resetAdjust(Adjustments next) {
    if (next == e.adjust) return;
    commit(e.copyWith(adjust: next));
  }

  // ─── Текст ───────────────────────────────────────────────────────────────

  /// Касание с инструментом «Текст»: новый пустой текст и поле ввода.
  void startNewText(TextItem t) {
    _textStart = e;
    _textEditId = t.id;
    live(e.copyWith(texts: List<TextItem>.unmodifiable([...e.texts, t])));
    notifyListeners();
  }

  /// Касание по готовому тексту без сдвига — правка (шаг — от начала касания).
  void startEditText(String id) {
    _textStart = _gestureStart ?? e;
    _gestureStart = null;
    _textEditId = id;
    final t = editingText;
    if (t != null) _color = t.color;
    notifyListeners();
  }

  void _patchText(TextItem Function(TextItem t) f) {
    final id = _textEditId;
    if (id == null) return;
    live(e.copyWith(texts: List<TextItem>.unmodifiable([
      for (final t in e.texts) t.id == id ? f(t) : t,
    ])));
  }

  void updateText(String text) => _patchText((t) => t.copyWith(text: text));

  void toggleTextBackground() {
    _patchText((t) => t.copyWith(background: !t.background));
    notifyListeners();
  }

  /// Конец правки текста: пустой убирается; вся правка — один шаг.
  void finishText() {
    if (_textEditId == null) return;
    final cleaned = e.cleaned();
    final st = _textStart;
    _textStart = null;
    _textEditId = null;
    edits.value = cleaned;
    if (st != null && !identical(st, cleaned) && !st.sameAs(cleaned)) {
      _history.push(st);
    }
    notifyListeners();
  }

  // ─── Рисунок ─────────────────────────────────────────────────────────────

  /// Линия закончена — один шаг.
  void commitStroke() {
    final s = liveStroke.value;
    if (s == null) return;
    liveStroke.value = null;
    commit(e.copyWith(
      strokes: List<DrawStroke>.unmodifiable([
        ...e.strokes,
        s.copyWith(points: List<Offset>.unmodifiable(s.points)),
      ]),
    ));
  }

  @override
  void dispose() {
    edits.dispose();
    liveStroke.dispose();
    super.dispose();
  }
}
