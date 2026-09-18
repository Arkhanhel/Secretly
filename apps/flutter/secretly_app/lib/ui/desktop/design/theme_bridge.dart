// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Maps the cross-platform [AppThemePreset]s (defined in
/// `lib/ui/theme_presets.dart`, shared with mobile) into desktop-specific
/// [DColorSet] overrides.
///
/// The desktop palette is a dark, surface-heavy design that doesn't share the
/// mobile `ColorScheme` plumbing — but accent / bubble / selection colors do
/// flow through. This helper applies just those tinted fields so a user that
/// picks "Ocean" or "Aurora" on mobile gets a visibly matching desktop UI.
library;

import 'package:flutter/material.dart' show Color, HSVColor;

import '../../theme_presets.dart';
import 'colors.dart';

/// Derives a tinted [DColorSet] from [base] by overriding accent / bubble /
/// selection / mention colors with the preset's dark-mode palette.
///
/// Why only these fields:
///   • The desktop design language is dark-surface-first; surface colors
///     (`bg`, `sidebar`, `thread`, `elevated`) stay constant so we don't have
///     to redesign per preset.
///   • Accent + bubble + unread-dot are the visible signal that the preset
///     was applied.
/// Resolves the delivery-indicator colour for the desktop palette.
///
/// The «Цвета индикаторов» preset was the one cosmetic family desktop never
/// read: ticks took the bubble's text colour, so a user who picked a colour on
/// their phone saw it there and not here. `followsTheme` presets defer to the
/// accent, which is why this needs the resolved accent rather than the raw id.
Color resolveIndicatorColor({
  required String presetId,
  required Color accent,
  required bool dark,
}) {
  final preset = resolveIndicatorColorPreset(presetId);
  if (preset.followsTheme) return accent;
  return dark ? preset.darkPrimary : preset.lightPrimary;
}

/// ◆ «СВОЙ ЦВЕТ»: ВТОРАЯ ТОЧКА ГРАДИЕНТА, ВЫВЕДЕННАЯ ИЗ ПЕРВОЙ.
///
/// У готовых схем пара цветов подобрана вручную и правила в ней нет: у
/// «Аметиста» второй темнее первого, у «Океана» — светлее и другого тона.
/// Для цвета, который человек выбрал сам, пары не существует, и выдумывать
/// её каждый раз заново нельзя: градиент кнопки «Отправить» и кольцо на
/// портрете должны получаться из одного и того же правила.
///
/// Правило простое и предсказуемое: тот же цвет, повёрнутый на 16° по кругу
/// и поднятый к свету. Так градиент читается как свет, падающий сверху
/// слева, — ровно то, чем он нарисован (`begin: topLeft`).
Color desktopAccentAlt(Color base) {
  final hsv = HSVColor.fromColor(base);
  return hsv
      .withHue((hsv.hue + 16) % 360)
      .withSaturation((hsv.saturation * 0.9).clamp(0.0, 1.0))
      .withValue((hsv.value + 0.10).clamp(0.0, 1.0))
      .toColor();
}

/// 🔴 АКЦЕНТ ОБЯЗАН ОСТАТЬСЯ ВИДИМЫМ НА ПОДЛОЖКЕ ОКНА.
///
/// Свой цвет выбирают один раз, а схему окна меняют когда угодно, — и почти
/// чёрный акцент, прекрасный на светлой подложке, на тёмной превращает
/// кнопку «Отправить» в пустое место. Поэтому храним выбранный цвет как
/// есть, а подгоняем его при ПРИМЕНЕНИИ: так смена схемы ничего не портит и
/// ничего не переписывает за спиной.
///
/// Двигается только яркость, тон и насыщенность остаются: человек выбирал
/// цвет, а не светлоту, и «мой зелёный» должен остаться зелёным.
Color legibleAccent(Color base, {required bool dark}) {
  final hsv = HSVColor.fromColor(base);
  // На тёмном фоне глухие цвета пропадают; на светлом — наоборот, слепят и
  // не держат белую подпись на кнопке.
  final v = dark
      ? hsv.value.clamp(0.45, 1.0)
      : hsv.value.clamp(0.30, 0.90);
  return hsv.withValue(v).toColor();
}

DColorSet applyThemePreset(
  DColorSet base,
  String presetId, {
  bool dark = true,
  String indicatorPresetId = 'theme',
  String? bubblePresetId,
  Color? customAccent,
}) {
  final preset = resolveAppThemePreset(presetId);
  // Presets carry a light and a dark variant of each colour. Desktop used the
  // dark pair unconditionally, which was fine while the palette was always
  // dark — on the light palette it produced accents mixed for a dark surface.
  //
  // ◆ Свой цвет, если он выбран, встаёт НА МЕСТО пары из схемы. Схема при
  // этом не сбрасывается: к ней возвращаются одним нажатием по её плитке, и
  // всё, что она красит помимо акцента (пузырь, индикаторы), остаётся на
  // месте.
  final accent = customAccent != null
      ? legibleAccent(customAccent, dark: dark)
      : (dark ? preset.darkPrimary : preset.lightPrimary);
  final accentAlt = customAccent != null
      ? desktopAccentAlt(accent)
      : (dark ? preset.darkSecondary : preset.lightSecondary);

  // The outgoing bubble has its OWN shared preset, separate from the app
  // accent — that is how the phone works, and the desktop settings screen was
  // already writing `chatBubbleStylePresetId` while nothing here read it back.
  // The picker changed the phone's bubbles and left the desktop's alone: a
  // placebo. Resolving it here is what makes the two surfaces agree.
  //
  // Null id → fall back to the accent pair, which is the old behaviour and the
  // right answer for callers that have no controller to ask.
  Color bubbleStart = accent;
  Color bubbleEnd = accentAlt;
  Color? bubbleMid;
  if (bubblePresetId != null && bubblePresetId.isNotEmpty) {
    final b = resolveChatBubbleStylePreset(bubblePresetId);
    bubbleStart = dark ? b.darkTop : b.lightTop;
    bubbleEnd = dark ? b.darkBottom : b.lightBottom;
    bubbleMid = dark ? b.darkMid : b.lightMid;
  }

  // NOTE: copyWith cannot set a nullable field back to null, so a preset
  // WITHOUT a mid relies on `base` not having one. The two palette constants
  // never define bubbleSelfMid, which is what keeps this correct — don't add
  // it to them.
  return base.copyWith(
    accentPrimary: accent,
    accentPrimaryAlt: accentAlt,
    bubbleSelfStart: bubbleStart,
    bubbleSelfEnd: bubbleEnd,
    bubbleSelfMid: bubbleMid,
    // 🔴 Счётчики непрочитанного НЕ идут за темой оформления. Тема меняет
    // настроение окна, а «тут не прочитано» — это сигнал, и перекрашивать его
    // в цвет обоев значит его гасить.
    //
    // Их три, и каждый называет своё: голубой — личная переписка, фиолетовый —
    // комната, красный — «сколько РАЗГОВОРОВ ждут» в фильтрах и на рейке.
    unreadDot: base.unreadDot,
    unreadRoom: base.unreadRoom,
    unreadChannel: base.unreadChannel,
    unreadRail: base.unreadRail,
    deliveryIndicator: resolveIndicatorColor(
      presetId: indicatorPresetId,
      accent: accent,
      dark: dark,
    ),
    selected: accent.withValues(alpha: 0.16),
    mentionBg: accent.withValues(alpha: 0.18),
  );
}
