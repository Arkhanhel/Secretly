// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../../theme_presets.dart';
import '../design/tokens.dart';

/// Как рисовать пузыри этой ленты: форма, плотность, цвет имён — выбор
/// человека в «Внешнем виде» (29.09.2026, макет владельца).
///
/// 🔴 ПОЧЕМУ НАСЛЕДУЕМЫЙ, А НЕ ПАРАМЕТР ПУЗЫРЯ. Пузырь рисуется не только в
/// ленте: в закреплённом, в поиске, в пересылке, в предпросмотре настроек.
/// Нет обёртки — пузырь выглядит как до 29.09 (средняя форма, обычная
/// плотность, у каждого имени свой цвет), и ни одно из этих мест не надо
/// трогать. Лента ставит обёртку одна — и перерисовывается при смене выбора,
/// потому что пузыри на неё подписаны.
class DesktopBubbleLook extends InheritedWidget {
  const DesktopBubbleLook({
    super.key,
    this.shape = 'medium',
    this.compact = false,
    this.senderNameColor,
    required super.child,
  });

  /// `sharp`, `medium` или `round` — см. [radiiFor].
  final String shape;

  /// Плотная лента: меньше зазоры между сообщениями и поля пузыря.
  final bool compact;

  /// Один цвет для всех имён в группах; `null` — у каждого свой.
  final Color? senderNameColor;

  static const DesktopBubbleLook fallback = DesktopBubbleLook(
    child: SizedBox.shrink(),
  );

  static DesktopBubbleLook of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopBubbleLook>() ??
      fallback;

  /// Скругление пузыря: основное и угол «хвоста».
  ///
  /// `medium` — ровно то, что было до выбора формы (16 и 6), поэтому у тех,
  /// кто ничего не менял, лента не сдвинулась ни на точку.
  static ({double main, double tail}) radiiFor(String shape) {
    switch (shape) {
      case 'sharp':
        return (main: 6.0, tail: 3.0);
      case 'round':
        return (main: 22.0, tail: 6.0);
      default:
        return (main: DRadii.r16, tail: DRadii.sm);
    }
  }

  ({double main, double tail}) get radii => radiiFor(shape);

  /// Зазор над сообщением: первое в серии и продолжение серии.
  double gapAbove({required bool continuation}) => compact
      ? (continuation ? 1 : 6)
      : (continuation ? 2 : DSpace.m);

  /// Поля текстового пузыря.
  EdgeInsets get textPadding => compact
      ? const EdgeInsets.fromLTRB(11, 6, 11, 5)
      : const EdgeInsets.fromLTRB(13, 10, 13, 8);

  @override
  bool updateShouldNotify(DesktopBubbleLook oldWidget) =>
      oldWidget.shape != shape ||
      oldWidget.compact != compact ||
      oldWidget.senderNameColor != senderNameColor;
}

/// Цвет имени отправителя по общей настройке «Цвет имени» — когда выбран
/// один цвет на всех.
///
/// «Акцент» — это цвет, выбранный для окна, а не голубой из телефонного
/// набора: слово обещает акцент, и на компьютере он у человека свой. Прочие —
/// входящий цвет набора; на светлой схеме он пастельный и на белом пузыре не
/// читается, поэтому там светлота опускается до читаемой.
Color desktopSenderNameColor({
  required String presetId,
  required Color accent,
  required bool dark,
}) {
  if (presetId == 'accent') return accent;
  final preset = resolveNicknameStylePreset(presetId);
  final base = preset.incoming;
  if (dark) return base;
  final hsl = HSLColor.fromColor(base);
  return hsl.withLightness(hsl.lightness.clamp(0.0, 0.42)).toColor();
}
