// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../design/theme_bridge.dart';
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_dialog.dart';

/// ◆ «СВОЙ ЦВЕТ» — ПЯТАЯ ПЛИТКА В ПОЛОСЕ АКЦЕНТА (макет 1126-1133).
///
/// Одиннадцать готовых схем закрывают вкусы, но не все: цвет компании, цвет
/// любимой кружки, цвет, который человек просто узнаёт своим. Плитка с
/// пунктиром и пипеткой открывает вот это окно.
///
/// 🔴 ЧТО ВЫБРАЛ, ТО И ПОЛУЧИШЬ. Поле выбора нарисовано НЕ во всю яркость, а
/// в тех пределах, в которых акцент остаётся видимым на подложке окна:
/// [legibleAccent] всё равно подтянет крайности, и показывать в выборе то,
/// чего потом не будет, — обман. Пределы у тёмной и светлой схемы разные,
/// поэтому поле перерисовывается вместе со схемой.
Future<int?> showAccentColorPicker(
  BuildContext context, {
  required Color initial,
  required bool dark,
}) {
  // Живое значение держим здесь: кнопки диалога собираются один раз, до
  // первого движения по полю, и до состояния тела им иначе не дотянуться.
  var picked = legibleAccent(initial, dark: dark);
  final l10n = AppLocalizations.of(context)!;
  return DesktopDialog.show<int>(
    context,
    title: l10n.desktopAccentCustom,
    size: DDialogSize.small,
    body: _AccentPickerBody(
      initial: picked,
      dark: dark,
      onChanged: (v) => picked = v,
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      kind: DButtonKind.ghost,
      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
    ),
    primary: DDialogAction(
      label: l10n.desktopApply,
      onPressed: () => Navigator.of(
        context,
        rootNavigator: true,
      ).pop(picked.toARGB32()),
    ),
  );
}

/// Границы яркости, в которых акцент остаётся видимым. Те же числа, что и в
/// [legibleAccent], — здесь они нужны, чтобы нарисовать поле ровно по ним.
({double min, double max}) accentValueBand({required bool dark}) =>
    dark ? (min: 0.45, max: 1.0) : (min: 0.30, max: 0.90);

class _AccentPickerBody extends StatefulWidget {
  const _AccentPickerBody({
    required this.initial,
    required this.dark,
    required this.onChanged,
  });

  final Color initial;
  final bool dark;
  final ValueChanged<Color> onChanged;

  @override
  State<_AccentPickerBody> createState() => _AccentPickerBodyState();
}

class _AccentPickerBodyState extends State<_AccentPickerBody> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  Color get _color => _hsv.toColor();

  void _set(HSVColor v) {
    setState(() => _hsv = v);
    widget.onChanged(_color);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final band = accentValueBand(dark: widget.dark);
    final alt = desktopAccentAlt(_color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SvField(
          key: const ValueKey('accentSvField'),
          hsv: _hsv,
          band: band,
          onChanged: _set,
        ),
        const SizedBox(height: DSpace.m),
        _HueBar(
          key: const ValueKey('accentHueBar'),
          hue: _hsv.hue,
          onChanged: (h) => _set(_hsv.withHue(h)),
        ),
        const SizedBox(height: DSpace.l),
        Row(
          children: [
            // Образец ровно тот, что встанет в кнопку «Отправить»: цвет и его
            // выведенная пара, а не одно пятно.
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_color, alt],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: DSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hex(_color),
                    style: DType.mono.copyWith(
                      fontSize: 13,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.desktopAccentAppliesTo,
                    style: DType.caption.copyWith(
                      color: c.textTertiary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _hex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).toUpperCase().padLeft(6, '0')}';
}

/// Поле «насыщенность × яркость» для текущего тона.
class _SvField extends StatelessWidget {
  const _SvField({
    super.key,
    required this.hsv,
    required this.band,
    required this.onChanged,
  });

  final HSVColor hsv;
  final ({double min, double max}) band;
  final ValueChanged<HSVColor> onChanged;

  void _handle(Offset local, Size size) {
    final x = (local.dx / size.width).clamp(0.0, 1.0);
    final y = (local.dy / size.height).clamp(0.0, 1.0);
    final value = band.max - y * (band.max - band.min);
    onChanged(hsv.withSaturation(x).withValue(value));
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    const height = 150.0;
    return LayoutBuilder(
      builder: (ctx, box) {
        final size = Size(box.maxWidth, height);
        final sx = hsv.saturation * size.width;
        final sy =
            (band.max - hsv.value) / (band.max - band.min) * size.height;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // 🔴 ЩЕЛЧОК И ПРОТЯЖКА — ДВА РАЗНЫХ РАСПОЗНАВАТЕЛЯ, И ОДНОГО МАЛО.
          //
          // Найдено на живом окне: щелчок по полю не делал НИЧЕГО. `onPanDown`
          // срабатывает не в момент нажатия, а когда протяжка выиграла спор
          // жестов, — то есть после того, как палец сдвинулся дальше порога.
          // Щелчок без движения такой распознаватель отклоняет сам.
          //
          // А по цветовому полю именно щёлкают: попал глазами — нажал.
          onTapDown: (d) => _handle(d.localPosition, size),
          onPanDown: (d) => _handle(d.localPosition, size),
          onPanUpdate: (d) => _handle(d.localPosition, size),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DRadii.md),
            child: SizedBox(
              width: size.width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: HSVColor.fromAHSV(
                          1,
                          hsv.hue,
                          1,
                          band.max,
                        ).toColor(),
                      ),
                    ),
                  ),
                  // Насыщенность: слева серое, справа чистый тон.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  // Яркость — только до нижней границы полосы, не до чёрного.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(
                              alpha: 1 - band.min / band.max,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: sx - 8,
                    top: sy - 8,
                    child: _Knob(color: hsv.toColor(), ring: c.bg),
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

class _HueBar extends StatelessWidget {
  const _HueBar({super.key, required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  static const List<Color> _stops = [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    const height = 16.0;
    return LayoutBuilder(
      builder: (ctx, box) {
        final w = box.maxWidth;
        void handle(Offset local) =>
            onChanged((local.dx / w).clamp(0.0, 1.0) * 360);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Щелчок по полосе тона — та же история, что и у поля выше.
          onTapDown: (d) => handle(d.localPosition),
          onPanDown: (d) => handle(d.localPosition),
          onPanUpdate: (d) => handle(d.localPosition),
          child: SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height / 2),
                      gradient: const LinearGradient(colors: _stops),
                    ),
                  ),
                ),
                Positioned(
                  left: (hue / 360 * w) - 8,
                  top: -1,
                  child: _Knob(
                    color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                    ring: c.bg,
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

class _Knob extends StatelessWidget {
  const _Knob({required this.color, required this.ring});

  final Color color;
  final Color ring;

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2.5),
      boxShadow: [BoxShadow(color: ring.withValues(alpha: 0.55), blurRadius: 4)],
    ),
  );
}
