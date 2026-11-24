// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Мелкие части редактора фото: значки, кнопки, ползунок, кружок цвета.
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../icons/adaptive_icons.dart';
import '../media_viewer_tokens.dart';

/// Значки редактора: на iPhone — знаки iOS, на Android — Material.
/// Только `const` (сокращение шрифтов значков при сборке).
abstract final class MediaEditorIcons {
  static const IconData undo = AdaptiveIcons.undo_rounded;
  static const IconData redo = AdaptiveIcons.redo_rounded;
  static const IconData tabCrop = AdaptiveIconData(
    Icons.crop_rotate_rounded,
    CupertinoIcons.crop_rotate,
  );
  static const IconData tabDraw = AdaptiveIcons.brush_rounded;
  static const IconData tabAdjust = AdaptiveIcons.tune_rounded;
  static const IconData rotate = AdaptiveIconData(
    Icons.rotate_90_degrees_ccw_rounded,
    CupertinoIcons.rotate_left,
  );
  static const IconData flip = AdaptiveIconData(
    Icons.flip_rounded,
    CupertinoIcons.arrow_left_right_square,
  );
  static const IconData reset = AdaptiveIconData(
    Icons.restart_alt_rounded,
    CupertinoIcons.arrow_counterclockwise,
  );
  static const IconData pen = AdaptiveIcons.edit_rounded;
  static const IconData marker = AdaptiveIconData(
    Icons.border_color_rounded,
    CupertinoIcons.paintbrush,
  );
  static const IconData neon = AdaptiveIconData(
    Icons.flare_rounded,
    CupertinoIcons.sparkles,
  );
  static const IconData eraser = AdaptiveIconData(
    Icons.cleaning_services_rounded,
    CupertinoIcons.delete_left,
  );
  static const IconData text = AdaptiveIcons.title_rounded;
  static const IconData textBackground = AdaptiveIcons.format_color_fill_rounded;
  static const IconData compare = AdaptiveIconData(
    Icons.compare_rounded,
    CupertinoIcons.square_split_2x1,
  );
}

/// Числа одинаковой ширины (значения ползунков, шкала).
const List<FontFeature> kTabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// Знак «минус» как в прототипе: `−5`, а не `-5`.
const String kMinusSign = '−';

/// Область касания не меньше 44×44 вокруг видимой части [child].
class EditorTapTarget extends StatelessWidget {
  const EditorTapTarget({
    super.key,
    required this.onTap,
    required this.child,
    this.label,
    this.tooltip,
    this.enabled = true,
    this.selected,
    this.minSize = 44,
  });

  final VoidCallback? onTap;
  final Widget child;
  final String? label;
  final String? tooltip;
  final bool enabled;
  final bool? selected;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    Widget w = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      ),
    );
    final tip = tooltip;
    if (tip != null) {
      w = Tooltip(message: tip, excludeFromSemantics: true, child: w);
    }
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label ?? tooltip,
      excludeSemantics: label != null || tooltip != null,
      child: w,
    );
  }
}

/// Круглая кнопка 40×40 (поворот, отражение) в зоне касания 44×44.
class EditorRoundButton extends StatelessWidget {
  const EditorRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.selected,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    return EditorTapTarget(
      tooltip: tooltip,
      selected: selected,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: 22, color: foreground),
      ),
    );
  }
}

/// Кружок цвета: выбранный — двойная обводка (фон, затем цвет текста).
class EditorSwatch extends StatelessWidget {
  const EditorSwatch({
    super.key,
    required this.color,
    required this.selected,
    required this.diameter,
    required this.tokens,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final double diameter;
  final MediaViewerTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: selected
                    ? <BoxShadow>[
                        BoxShadow(color: t.editorInk, spreadRadius: 4),
                        BoxShadow(color: t.editorBg, spreadRadius: 2),
                      ]
                    : const <BoxShadow>[
                        BoxShadow(color: Color(0x73808080), spreadRadius: 1),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ползунок цвета акцента (CSS `accent-color`), компактный по высоте.
class EditorSlider extends StatelessWidget {
  const EditorSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.tokens,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.label,
    this.semanticValue,
  });

  final double value;
  final double min;
  final double max;
  final MediaViewerTokens tokens;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final String? label;
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    Widget slider = SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: t.accent,
        inactiveTrackColor: t.track,
        thumbColor: t.accent,
        overlayColor: t.accent.withValues(alpha: .14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
        trackShape: const RoundedRectSliderTrackShape(),
        showValueIndicator: ShowValueIndicator.never,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: onChanged,
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd,
        semanticFormatterCallback: semanticValue == null
            ? null
            : (_) => semanticValue!,
      ),
    );
    final l = label;
    if (l != null) slider = Semantics(label: l, child: slider);
    return slider;
  }
}

/// Значение ползунка коррекции: `+12`, `−5`, `0`.
String formatAdjustValue(int v) =>
    v > 0 ? '+$v' : (v < 0 ? '$kMinusSign${v.abs()}' : '0');

/// Угол выпрямления: `+3,5°`, `−12°`, `0°`.
String formatAngle(double a) {
  final abs = a.abs();
  var s = abs.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  s = s.replaceAll('.', ',');
  final sign = a > 0 ? '+' : (a < 0 ? kMinusSign : '');
  return '$sign$s°';
}
