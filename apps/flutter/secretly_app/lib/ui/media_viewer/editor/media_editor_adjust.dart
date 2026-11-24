// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Вкладка «Коррекция»: пять ползунков (`adjRows` прототипа) и остров
/// «Сравнить» — пока держите палец, виден оригинал.
library;

import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../media_edits.dart';
import '../media_viewer_tokens.dart';
import 'media_editor_model.dart';
import 'media_editor_widgets.dart';

enum _AdjustKey { brightness, contrast, saturation, warmth, vignette }

double _get(Adjustments a, _AdjustKey k) => switch (k) {
  _AdjustKey.brightness => a.brightness,
  _AdjustKey.contrast => a.contrast,
  _AdjustKey.saturation => a.saturation,
  _AdjustKey.warmth => a.warmth,
  _AdjustKey.vignette => a.vignette,
};

Adjustments _set(Adjustments a, _AdjustKey k, double v) => switch (k) {
  _AdjustKey.brightness => a.copyWith(brightness: v),
  _AdjustKey.contrast => a.copyWith(contrast: v),
  _AdjustKey.saturation => a.copyWith(saturation: v),
  _AdjustKey.warmth => a.copyWith(warmth: v),
  _AdjustKey.vignette => a.copyWith(vignette: v),
};

/// Панель «Коррекция» (164 px).
class MediaEditorAdjustPanel extends StatelessWidget {
  const MediaEditorAdjustPanel({super.key, required this.model});

  final MediaEditorModel model;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final t = MediaViewerTokens.of(context);
    final l10n = context.l10n;
    final rows = <(_AdjustKey, String, double)>[
      (_AdjustKey.brightness, l10n.meBrightness, -100),
      (_AdjustKey.contrast, l10n.meContrast, -100),
      (_AdjustKey.saturation, l10n.meSaturation, -100),
      (_AdjustKey.warmth, l10n.meWarmth, -100),
      (_AdjustKey.vignette, l10n.meVignette, 0),
    ];
    return ValueListenableBuilder<MediaEdits>(
      valueListenable: m.edits,
      builder: (context, e, _) => Stack(
        children: [
          Positioned(
            top: 6,
            left: 18,
            right: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, (key, label, min)) in rows.indexed) ...[
                  if (i > 0) const SizedBox(height: 2),
                  _AdjustRow(
                    key: ValueKey(key),
                    label: label,
                    min: min,
                    value: (_get(e.adjust, key) * 100).roundToDouble(),
                    tokens: t,
                    onStart: m.begin,
                    onChanged: (v) {
                      final nv = v.roundToDouble() / 100;
                      final cur = m.e;
                      if (_get(cur.adjust, key) == nv) return;
                      m.live(cur.copyWith(adjust: _set(cur.adjust, key, nv)));
                    },
                    onEnd: m.end,
                    onReset: () => m.resetAdjust(_set(m.e.adjust, key, 0)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustRow extends StatelessWidget {
  const _AdjustRow({
    super.key,
    required this.label,
    required this.min,
    required this.value,
    required this.tokens,
    required this.onStart,
    required this.onChanged,
    required this.onEnd,
    required this.onReset,
  });

  final String label;
  final double min;
  final double value;
  final MediaViewerTokens tokens;
  final VoidCallback onStart;
  final ValueChanged<double> onChanged;
  final VoidCallback onEnd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final v = value.round();
    final txt = formatAdjustValue(v);
    return SizedBox(
      height: 30,
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: onReset,
            child: SizedBox(
              width: 104,
              height: 30,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: t.editorInk),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: EditorSlider(
              value: value,
              min: min,
              max: 100,
              tokens: t,
              label: label,
              semanticValue: txt,
              onChangeStart: (_) => onStart(),
              onChanged: onChanged,
              onChangeEnd: (_) => onEnd(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              txt,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: v != 0 ? t.accent : t.editorSub,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Остров «Сравнить» в правом верхнем углу рабочей зоны: нажать и держать.
class MediaEditorCompareIsland extends StatelessWidget {
  const MediaEditorCompareIsland({super.key, required this.model});

  final MediaEditorModel model;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final t = MediaViewerTokens.of(context);
    final l10n = context.l10n;
    final label = m.compare ? l10n.meAspectOriginal : l10n.meCompare;
    Widget island = Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.islandFill,
        borderRadius: BorderRadius.circular(17),
        boxShadow: t.islandShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MediaEditorIcons.compare, size: 18, color: t.ink),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.ink,
            ),
          ),
        ],
      ),
    );
    if (mediaViewerGlass) {
      island = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          boxShadow: t.islandShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: BackdropFilter(
            filter: mediaViewerGlassFilter(10),
            child: island,
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => m.compare = true,
        onPointerUp: (_) => m.compare = false,
        onPointerCancel: (_) => m.compare = false,
        child: Padding(padding: const EdgeInsets.all(5), child: island),
      ),
    );
  }
}
