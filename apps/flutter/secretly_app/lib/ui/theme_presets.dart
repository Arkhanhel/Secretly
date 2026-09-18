// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

class AppThemePreset {
  const AppThemePreset({
    required this.id,
    required this.nameRu,
    required this.nameEn,
    required this.seed,
    required this.lightPrimary,
    required this.lightSecondary,
    required this.lightSurface,
    this.lightBgTop,
    this.lightBgMid,
    this.lightBgBottom,
    required this.darkPrimary,
    required this.darkSecondary,
    required this.darkSurface,
    required this.darkBgTop,
    required this.darkBgMid,
    required this.darkBgBottom,
    this.lightTopBarTop,
    this.lightTopBarBottom,
    this.lightTopBarBorder,
    this.darkTopBarTop,
    this.darkTopBarBottom,
    this.darkTopBarBorder,
    this.lightActionTop = const Color(0xFF4A6BFF),
    this.lightActionBottom = const Color(0xFF33A2FF),
    this.darkActionTop = const Color(0xFF4A6BFF),
    this.darkActionBottom = const Color(0xFF33A2FF),
  });

  final String id;
  final String nameRu;
  final String nameEn;
  final Color seed;
  final Color lightPrimary;
  final Color lightSecondary;
  final Color lightSurface;
  final Color? lightBgTop;
  final Color? lightBgMid;
  final Color? lightBgBottom;
  final Color darkPrimary;
  final Color darkSecondary;
  final Color darkSurface;
  final Color darkBgTop;
  final Color darkBgMid;
  final Color darkBgBottom;
  final Color? lightTopBarTop;
  final Color? lightTopBarBottom;
  final Color? lightTopBarBorder;
  final Color? darkTopBarTop;
  final Color? darkTopBarBottom;
  final Color? darkTopBarBorder;
  final Color lightActionTop;
  final Color lightActionBottom;
  final Color darkActionTop;
  final Color darkActionBottom;
}

class ChatBubbleStylePreset {
  const ChatBubbleStylePreset({
    required this.id,
    required this.nameRu,
    required this.nameEn,
    required this.darkTop,
    required this.darkBottom,
    required this.lightTop,
    required this.lightBottom,
    required this.darkShadowTop,
    required this.darkShadowBottom,
    required this.lightShadowTop,
    required this.lightShadowBottom,
    this.darkMid,
    this.lightMid,
  });

  final String id;
  final String nameRu;
  final String nameEn;
  final Color darkTop;
  final Color darkBottom;
  final Color lightTop;
  final Color lightBottom;
  final Color darkShadowTop;
  final Color darkShadowBottom;
  final Color lightShadowTop;
  final Color lightShadowBottom;
  final Color? darkMid;
  final Color? lightMid;
}

class NicknameStylePreset {
  const NicknameStylePreset({
    required this.id,
    required this.nameRu,
    required this.nameEn,
    required this.outgoing,
    required this.incoming,
  });

  final String id;
  final String nameRu;
  final String nameEn;
  final Color outgoing;
  final Color incoming;
}

/// PR-J — indicator (accent) colour preset.
///
/// Drives `ColorScheme.primary` for everything that follows the theme accent:
/// buttons, switches, FABs, progress bars, badges, etc.
///
/// The special id `'theme'` means "follow the active theme preset" —
/// `lightPrimary` / `darkPrimary` are ignored and `_buildTheme()` keeps the
/// theme-derived primary. Every other preset overrides the primary directly
/// with the matching variant for the active brightness.
///
/// The palette is drawn from [kSharedAvatarGradients]
/// (`lib/ui/widgets/shared_palette.dart`) so "the colour of my avatar" and
/// "the colour of my buttons" feel like one coherent Discord-style palette.
class IndicatorColorPreset {
  const IndicatorColorPreset({
    required this.id,
    required this.nameRu,
    required this.nameEn,
    required this.lightPrimary,
    required this.darkPrimary,
    this.followsTheme = false,
  });

  final String id;
  final String nameRu;
  final String nameEn;
  final Color lightPrimary;
  final Color darkPrimary;
  final bool followsTheme;
}

const List<AppThemePreset> kAppThemePresets = [
  AppThemePreset(
    id: 'flutter_dash',
    nameRu: 'Flutter Dash',
    nameEn: 'Flutter Dash',
    seed: Color(0xFF4E94D5),
    lightPrimary: Color(0xFF2AABEE),
    lightSecondary: Color(0xFF4F95C8),
    lightSurface: Color(0xFFF1F4F7),
    darkPrimary: Color(0xFF3390EC),
    darkSecondary: Color(0xFF84B9E3),
    darkSurface: Color(0xFF232E3C),
    darkBgTop: Color(0xFF1D2733),
    darkBgMid: Color(0xFF18222D),
    darkBgBottom: Color(0xFF151E27),
    lightTopBarTop: Color(0xFFF4FBFF),
    lightTopBarBottom: Color(0xFFE7F4FC),
    lightTopBarBorder: Color(0xFFC7E4F5),
    darkTopBarTop: Color(0xFF18222C),
    darkTopBarBottom: Color(0xFF1E2A35),
    darkTopBarBorder: Color(0xFF587387),
    lightActionTop: Color(0xFF57B8F2),
    lightActionBottom: Color(0xFF2AABEE),
    darkActionTop: Color(0xFF7FD0FF),
    darkActionBottom: Color(0xFF2E9FE4),
  ),
  AppThemePreset(
    id: 'ocean',
    nameRu: 'Океан',
    nameEn: 'Ocean',
    seed: Color(0xFF158FB6),
    lightPrimary: Color(0xFF148CB4),
    lightSecondary: Color(0xFF2EA9BE),
    lightSurface: Color(0xFFF0F6FA),
    darkPrimary: Color(0xFF28C0E3),
    darkSecondary: Color(0xFF37D3BE),
    darkSurface: Color(0xFF0A1A29),
    darkBgTop: Color(0xFF040810),
    darkBgMid: Color(0xFF07121C),
    darkBgBottom: Color(0xFF0A1C2A),
    darkTopBarTop: Color(0xFF08161A),
    darkTopBarBottom: Color(0xFF0B1D22),
    darkTopBarBorder: Color(0xFF214A47),
    lightActionTop: Color(0xFF1C7FD4),
    lightActionBottom: Color(0xFF2DB8BE),
    darkActionTop: Color(0xFF0D9FD8),
    darkActionBottom: Color(0xFF2CCEB0),
  ),
  AppThemePreset(
    id: 'graphite',
    nameRu: 'Графит',
    nameEn: 'Graphite',
    seed: Color(0xFF5E6670),
    lightPrimary: Color(0xFF4E5966),
    lightSecondary: Color(0xFF6F7A88),
    lightSurface: Color(0xFFF4F5F7),
    darkPrimary: Color(0xFF98A3B2),
    darkSecondary: Color(0xFF7D8898),
    darkSurface: Color(0xFF141821),
    darkBgTop: Color(0xFF07080C),
    darkBgMid: Color(0xFF0A0C12),
    darkBgBottom: Color(0xFF0E1018),
    lightActionTop: Color(0xFF4F5A6C),
    lightActionBottom: Color(0xFF72859D),
    darkActionTop: Color(0xFF7D8C9F),
    darkActionBottom: Color(0xFF95A8BE),
  ),
  AppThemePreset(
    id: 'amethyst',
    nameRu: 'Аметист',
    nameEn: 'Amethyst',
    seed: Color(0xFF7C63FF),
    lightPrimary: Color(0xFF664DE6),
    lightSecondary: Color(0xFFA37DFF),
    lightSurface: Color(0xFFF6F1FF),
    darkPrimary: Color(0xFFB39BFF),
    darkSecondary: Color(0xFF8D72F5),
    darkSurface: Color(0xFF1F1739),
    darkBgTop: Color(0xFF07050F),
    darkBgMid: Color(0xFF0C0916),
    darkBgBottom: Color(0xFF110D22),
    lightActionTop: Color(0xFF6F53E8),
    lightActionBottom: Color(0xFF9D75F6),
    darkActionTop: Color(0xFF8F72F2),
    darkActionBottom: Color(0xFFB093FF),
  ),
  AppThemePreset(
    id: 'sunset',
    nameRu: 'Сансет',
    nameEn: 'Sunset',
    seed: Color(0xFFFF7A4E),
    lightPrimary: Color(0xFFE35C2F),
    lightSecondary: Color(0xFFFFB07D),
    lightSurface: Color(0xFFFFF3ED),
    darkPrimary: Color(0xFFFFA981),
    darkSecondary: Color(0xFFFF7FC3),
    darkSurface: Color(0xFF351818),
    darkBgTop: Color(0xFF0D0808),
    darkBgMid: Color(0xFF14090B),
    darkBgBottom: Color(0xFF1C0E0F),
    lightActionTop: Color(0xFFE46541),
    lightActionBottom: Color(0xFFEB7D68),
    darkActionTop: Color(0xFFE88064),
    darkActionBottom: Color(0xFFC66B99),
  ),
  AppThemePreset(
    id: 'aurora',
    nameRu: 'Аврора',
    nameEn: 'Aurora',
    seed: Color(0xFF2EC8A7),
    lightPrimary: Color(0xFF1D9E86),
    lightSecondary: Color(0xFF48D8C7),
    lightSurface: Color(0xFFF0FAF8),
    darkPrimary: Color(0xFF59E4CD),
    darkSecondary: Color(0xFF46B7FF),
    darkSurface: Color(0xFF122832),
    darkBgTop: Color(0xFF060F14),
    darkBgMid: Color(0xFF091A20),
    darkBgBottom: Color(0xFF0D2530),
    lightActionTop: Color(0xFF29A58F),
    lightActionBottom: Color(0xFF43C3D1),
    darkActionTop: Color(0xFF2FB89F),
    darkActionBottom: Color(0xFF47B0E5),
  ),
  AppThemePreset(
    id: 'rosewood',
    nameRu: 'Роузвуд',
    nameEn: 'Rosewood',
    seed: Color(0xFFD06A8B),
    lightPrimary: Color(0xFFB94D74),
    lightSecondary: Color(0xFFE08BA9),
    lightSurface: Color(0xFFFFF1F5),
    darkPrimary: Color(0xFFFF9FBE),
    darkSecondary: Color(0xFFD98DD8),
    darkSurface: Color(0xFF321C2B),
    darkBgTop: Color(0xFF08060A),
    darkBgMid: Color(0xFF0E080F),
    darkBgBottom: Color(0xFF160B19),
    lightActionTop: Color(0xFFC06283),
    lightActionBottom: Color(0xFFD57CA8),
    darkActionTop: Color(0xFFD57CA8),
    darkActionBottom: Color(0xFFB36BC3),
  ),
  AppThemePreset(
    id: 'toplenoe_moloko',
    nameRu: 'Топленое молоко',
    nameEn: 'Baked Milk',
    seed: Color(0xFFD1A87A),
    lightPrimary: Color(0xFFC49A6A),
    lightSecondary: Color(0xFFAA7F5E),
    lightSurface: Color(0xFFF1EBDD),
    lightBgTop: Color(0xFFE5DFD2),
    lightBgMid: Color(0xFFDDD5C6),
    lightBgBottom: Color(0xFFD3C9B8),
    darkPrimary: Color(0xFFD9AF7B),
    darkSecondary: Color(0xFFA67D62),
    darkSurface: Color(0xFF2B1F1A),
    darkBgTop: Color(0xFF0B0908),
    darkBgMid: Color(0xFF130E0A),
    darkBgBottom: Color(0xFF1A120D),
    lightTopBarTop: Color(0xFFE8DDC9),
    lightTopBarBottom: Color(0xFFDED0B9),
    lightTopBarBorder: Color(0xFFC7A884),
    lightActionTop: Color(0xFFE5CB9D),
    lightActionBottom: Color(0xFFD4AE7B),
    darkActionTop: Color(0xFFD3A06F),
    darkActionBottom: Color(0xFFA96B4D),
  ),
  AppThemePreset(
    id: 'noch_na_marse',
    nameRu: 'Ночь на марсе!',
    nameEn: 'Night on Mars!',
    seed: Color(0xFFB6653A),
    lightPrimary: Color(0xFFA35B37),
    lightSecondary: Color(0xFF6E463A),
    lightSurface: Color(0xFFF4E9E3),
    darkPrimary: Color(0xFFE08A52),
    darkSecondary: Color(0xFF7F4A3E),
    darkSurface: Color(0xFF1C1316),
    darkBgTop: Color(0xFF06070E),
    darkBgMid: Color(0xFF0D0A12),
    darkBgBottom: Color(0xFF160D12),
    lightActionTop: Color(0xFFCC8256),
    lightActionBottom: Color(0xFF8A4D42),
    darkActionTop: Color(0xFFD97742),
    darkActionBottom: Color(0xFF7D3E35),
  ),
];

const Map<String, String> kLegacyChatBubbleStylePresetIdAliases = {
  'forest_teal': 'ocean',
  'graphite_cool': 'graphite',
  'mint_ink': 'aurora',
  'aurora_steel': 'aurora',
  'violet_night': 'amethyst',
  'sunset_fusion': 'sunset',
  'arctic_glow': 'ocean',
};

String normalizeChatBubbleStylePresetId(String id) {
  final normalized = id.trim();
  if (normalized.isEmpty) return 'flutter_dash';
  return kLegacyChatBubbleStylePresetIdAliases[normalized] ?? normalized;
}

const List<ChatBubbleStylePreset> kChatBubbleStylePresets = [
  ChatBubbleStylePreset(
    id: 'flutter_dash',
    nameRu: 'Flutter Dash',
    nameEn: 'Flutter Dash',
    darkTop: Color(0xFF8F04A8),
    darkBottom: Color(0xFF0B61A4),
    lightTop: Color(0xFF8F04A8),
    lightBottom: Color(0xFF0B61A4),
    darkShadowTop: Color(0xFFC33BD0),
    darkShadowBottom: Color(0xFF4296D8),
    lightShadowTop: Color(0xFFD24CDA),
    lightShadowBottom: Color(0xFF57A8E5),
  ),
  ChatBubbleStylePreset(
    id: 'ocean',
    nameRu: 'Океан',
    nameEn: 'Ocean',
    darkTop: Color(0xFF15849A),
    darkBottom: Color(0xFF12558E),
    lightTop: Color(0xFF2CA8C1),
    lightBottom: Color(0xFF4C82C8),
    darkShadowTop: Color(0xFF36AFC0),
    darkShadowBottom: Color(0xFF4D7FC0),
    lightShadowTop: Color(0xFF59C4D4),
    lightShadowBottom: Color(0xFF6A98D9),
  ),
  ChatBubbleStylePreset(
    id: 'graphite',
    nameRu: 'Графит',
    nameEn: 'Graphite',
    darkTop: Color(0xFF4A525E),
    darkBottom: Color(0xFF33465C),
    lightTop: Color(0xFF667180),
    lightBottom: Color(0xFF506884),
    darkShadowTop: Color(0xFF687382),
    darkShadowBottom: Color(0xFF56708B),
    lightShadowTop: Color(0xFF818C9A),
    lightShadowBottom: Color(0xFF6A84A0),
  ),
  ChatBubbleStylePreset(
    id: 'amethyst',
    nameRu: 'Аметист',
    nameEn: 'Amethyst',
    darkTop: Color(0xFF6944A5),
    darkBottom: Color(0xFF4658A2),
    lightTop: Color(0xFF9068CA),
    lightBottom: Color(0xFF6F86CB),
    darkShadowTop: Color(0xFF885FCA),
    darkShadowBottom: Color(0xFF6276BE),
    lightShadowTop: Color(0xFFAE89E2),
    lightShadowBottom: Color(0xFF8EA4DE),
  ),
  ChatBubbleStylePreset(
    id: 'sunset',
    nameRu: 'Сансет',
    nameEn: 'Sunset',
    darkTop: Color(0xFFA15A3F),
    darkBottom: Color(0xFF7B4734),
    lightTop: Color(0xFFD9875C),
    lightBottom: Color(0xFFB96947),
    darkShadowTop: Color(0xFFC87550),
    darkShadowBottom: Color(0xFF986048),
    lightShadowTop: Color(0xFFEEA379),
    lightShadowBottom: Color(0xFFD7835E),
  ),
  ChatBubbleStylePreset(
    id: 'aurora',
    nameRu: 'Аврора',
    nameEn: 'Aurora',
    darkTop: Color(0xFF1D8A73),
    darkBottom: Color(0xFF256B93),
    lightTop: Color(0xFF39B191),
    lightBottom: Color(0xFF4B97C3),
    darkShadowTop: Color(0xFF3DB39A),
    darkShadowBottom: Color(0xFF4786B3),
    lightShadowTop: Color(0xFF60C8AD),
    lightShadowBottom: Color(0xFF67AAD1),
  ),
  ChatBubbleStylePreset(
    id: 'rosewood',
    nameRu: 'Роузвуд',
    nameEn: 'Rosewood',
    darkTop: Color(0xFF965471),
    darkBottom: Color(0xFF704A75),
    lightTop: Color(0xFFC77A9A),
    lightBottom: Color(0xFFA37AB8),
    darkShadowTop: Color(0xFFB26A89),
    darkShadowBottom: Color(0xFF865B89),
    lightShadowTop: Color(0xFFD997B2),
    lightShadowBottom: Color(0xFFB591C9),
  ),
  ChatBubbleStylePreset(
    id: 'toplenoe_moloko',
    nameRu: 'Топленое молоко',
    nameEn: 'Baked Milk',
    darkTop: Color(0xFFA9794C),
    darkBottom: Color(0xFF7C6145),
    lightTop: Color(0xFFE1BC86),
    lightBottom: Color(0xFFC8986C),
    darkShadowTop: Color(0xFFC08C61),
    darkShadowBottom: Color(0xFF927154),
    lightShadowTop: Color(0xFFEBCB99),
    lightShadowBottom: Color(0xFFD6AA7D),
  ),
  ChatBubbleStylePreset(
    id: 'noch_na_marse',
    nameRu: 'Ночь на марсе!',
    nameEn: 'Night on Mars!',
    darkTop: Color(0xFF935946),
    darkBottom: Color(0xFF5D363E),
    lightTop: Color(0xFFCA8B61),
    lightBottom: Color(0xFF9A655C),
    darkShadowTop: Color(0xFFAB715A),
    darkShadowBottom: Color(0xFF73484E),
    lightShadowTop: Color(0xFFDFA078),
    lightShadowBottom: Color(0xFFB27A70),
  ),
  // ── Vivid vertical-gradient presets (10) ──
  ChatBubbleStylePreset(
    id: 'mint_aqua',
    nameRu: 'Мятная аква',
    nameEn: 'Mint Aqua',
    darkTop: Color(0xFF42E29C),
    darkBottom: Color(0xFF5BCFFA),
    lightTop: Color(0xFF42E29C),
    lightBottom: Color(0xFF5BCFFA),
    darkShadowTop: Color(0xFF7CEFC1),
    darkShadowBottom: Color(0xFF8FDFFB),
    lightShadowTop: Color(0xFF7CEFC1),
    lightShadowBottom: Color(0xFF8FDFFB),
  ),
  ChatBubbleStylePreset(
    id: 'deep_plum',
    nameRu: 'Тёмная слива',
    nameEn: 'Deep Plum',
    darkTop: Color(0xFF3D1352),
    darkBottom: Color(0xFFA93FB3),
    lightTop: Color(0xFF3D1352),
    lightBottom: Color(0xFFA93FB3),
    darkShadowTop: Color(0xFF6A2C82),
    darkShadowBottom: Color(0xFFC868CE),
    lightShadowTop: Color(0xFF6A2C82),
    lightShadowBottom: Color(0xFFC868CE),
  ),
  ChatBubbleStylePreset(
    id: 'coral_pink',
    nameRu: 'Коралл-малина',
    nameEn: 'Coral Crimson',
    darkTop: Color(0xFFF26F4E),
    darkBottom: Color(0xFFE2306E),
    lightTop: Color(0xFFF26F4E),
    lightBottom: Color(0xFFE2306E),
    darkShadowTop: Color(0xFFF7937A),
    darkShadowBottom: Color(0xFFEE5C92),
    lightShadowTop: Color(0xFFF7937A),
    lightShadowBottom: Color(0xFFEE5C92),
  ),
  ChatBubbleStylePreset(
    id: 'royal_magenta',
    nameRu: 'Королевская магента',
    nameEn: 'Royal Magenta',
    darkTop: Color(0xFF341050),
    darkBottom: Color(0xFFD8369F),
    lightTop: Color(0xFF341050),
    lightBottom: Color(0xFFD8369F),
    darkShadowTop: Color(0xFF5F2A82),
    darkShadowBottom: Color(0xFFE56CB8),
    lightShadowTop: Color(0xFF5F2A82),
    lightShadowBottom: Color(0xFFE56CB8),
  ),
  ChatBubbleStylePreset(
    id: 'cyan_violet',
    nameRu: 'Циан-виолет',
    nameEn: 'Cyan Violet',
    darkTop: Color(0xFF3DDCFC),
    darkMid: Color(0xFF4F77F0),
    darkBottom: Color(0xFF7C2FE0),
    lightTop: Color(0xFF3DDCFC),
    lightMid: Color(0xFF4F77F0),
    lightBottom: Color(0xFF7C2FE0),
    darkShadowTop: Color(0xFF6FE5FD),
    darkShadowBottom: Color(0xFF9D5BEC),
    lightShadowTop: Color(0xFF6FE5FD),
    lightShadowBottom: Color(0xFF9D5BEC),
  ),
  ChatBubbleStylePreset(
    id: 'pink_violet',
    nameRu: 'Розово-фиолет',
    nameEn: 'Pink Violet',
    darkTop: Color(0xFFEB48A0),
    darkBottom: Color(0xFFA22BC6),
    lightTop: Color(0xFFEB48A0),
    lightBottom: Color(0xFFA22BC6),
    darkShadowTop: Color(0xFFEF73B5),
    darkShadowBottom: Color(0xFFBA56D5),
    lightShadowTop: Color(0xFFEF73B5),
    lightShadowBottom: Color(0xFFBA56D5),
  ),
  ChatBubbleStylePreset(
    id: 'sunset_coral',
    nameRu: 'Закатный коралл',
    nameEn: 'Sunset Coral',
    darkTop: Color(0xFFF4A538),
    darkMid: Color(0xFFEB6F4F),
    darkBottom: Color(0xFFDA4368),
    lightTop: Color(0xFFF4A538),
    lightMid: Color(0xFFEB6F4F),
    lightBottom: Color(0xFFDA4368),
    darkShadowTop: Color(0xFFF7BC65),
    darkShadowBottom: Color(0xFFE56889),
    lightShadowTop: Color(0xFFF7BC65),
    lightShadowBottom: Color(0xFFE56889),
  ),
  ChatBubbleStylePreset(
    id: 'sky_cobalt',
    nameRu: 'Небесный кобальт',
    nameEn: 'Sky Cobalt',
    darkTop: Color(0xFF5DC0F2),
    darkBottom: Color(0xFF3F58E5),
    lightTop: Color(0xFF5DC0F2),
    lightBottom: Color(0xFF3F58E5),
    darkShadowTop: Color(0xFF82D0F5),
    darkShadowBottom: Color(0xFF6677EC),
    lightShadowTop: Color(0xFF82D0F5),
    lightShadowBottom: Color(0xFF6677EC),
  ),
  ChatBubbleStylePreset(
    id: 'midnight_indigo',
    nameRu: 'Полуночный индиго',
    nameEn: 'Midnight Indigo',
    darkTop: Color(0xFF1A0F8B),
    darkBottom: Color(0xFF5B22C8),
    lightTop: Color(0xFF1A0F8B),
    lightBottom: Color(0xFF5B22C8),
    darkShadowTop: Color(0xFF453BAB),
    darkShadowBottom: Color(0xFF7B4ED4),
    lightShadowTop: Color(0xFF453BAB),
    lightShadowBottom: Color(0xFF7B4ED4),
  ),
  ChatBubbleStylePreset(
    id: 'electric_lilac',
    nameRu: 'Электрик сирень',
    nameEn: 'Electric Lilac',
    darkTop: Color(0xFFC530D6),
    darkBottom: Color(0xFF7820D6),
    lightTop: Color(0xFFC530D6),
    lightBottom: Color(0xFF7820D6),
    darkShadowTop: Color(0xFFD45BDE),
    darkShadowBottom: Color(0xFF9750E0),
    lightShadowTop: Color(0xFFD45BDE),
    lightShadowBottom: Color(0xFF9750E0),
  ),
];

const List<NicknameStylePreset> kNicknameStylePresets = [
  NicknameStylePreset(
    id: 'accent',
    nameRu: 'Акцент',
    nameEn: 'Accent',
    outgoing: Color(0xFF9AF4FF),
    incoming: Color(0xFF47B6FF),
  ),
  NicknameStylePreset(
    id: 'amber',
    nameRu: 'Янтарь',
    nameEn: 'Amber',
    outgoing: Color(0xFFFFDCA8),
    incoming: Color(0xFFFFBE6E),
  ),
  NicknameStylePreset(
    id: 'violet',
    nameRu: 'Виолет',
    nameEn: 'Violet',
    outgoing: Color(0xFFD8C8FF),
    incoming: Color(0xFFB8A4FF),
  ),
  NicknameStylePreset(
    id: 'ice',
    nameRu: 'Лёд',
    nameEn: 'Ice',
    outgoing: Color(0xFFB8F2FF),
    incoming: Color(0xFF89DCFF),
  ),
];

/// PR-J — 10-preset indicator-colour palette.
///
/// Slot 0 is the special "follow the active theme" preset. Slots 1–9 are
/// vivid Discord-style accent colours pulled from the **same** hue family
/// the desktop avatar gradients use (`kSharedAvatarGradients`). For each
/// fixed colour we ship a light- and dark-mode variant so the accent stays
/// readable on both bright and dark surfaces.
///
/// Light variants are darker shades (better contrast on white surfaces),
/// dark variants stay vibrant for OLED black backgrounds.
const List<IndicatorColorPreset> kIndicatorColorPresets = [
  IndicatorColorPreset(
    id: 'theme',
    nameRu: 'По теме',
    nameEn: 'Theme',
    lightPrimary: Color(0xFF2AABEE),
    darkPrimary: Color(0xFF53B7F4),
    followsTheme: true,
  ),
  IndicatorColorPreset(
    id: 'indigo',
    nameRu: 'Индиго',
    nameEn: 'Indigo',
    lightPrimary: Color(0xFF4F46E5), // indigo-600
    darkPrimary: Color(0xFF6366F1), // indigo-500 (matches gradient slot 0a)
  ),
  IndicatorColorPreset(
    id: 'violet',
    nameRu: 'Виолет',
    nameEn: 'Violet',
    lightPrimary: Color(0xFF7C3AED), // violet-600
    darkPrimary: Color(0xFF8B5CF6), // violet-500 (gradient slot 0b/5a)
  ),
  IndicatorColorPreset(
    id: 'pink',
    nameRu: 'Розовый',
    nameEn: 'Pink',
    lightPrimary: Color(0xFFDB2777), // pink-600
    darkPrimary: Color(0xFFEC4899), // pink-500 (gradient slot 1a/5b)
  ),
  IndicatorColorPreset(
    id: 'rose',
    nameRu: 'Роза',
    nameEn: 'Rose',
    lightPrimary: Color(0xFFE11D48), // rose-600
    darkPrimary: Color(0xFFF43F5E), // rose-500 (gradient slot 1b)
  ),
  IndicatorColorPreset(
    id: 'amber',
    nameRu: 'Янтарь',
    nameEn: 'Amber',
    lightPrimary: Color(0xFFD97706), // amber-600
    darkPrimary: Color(0xFFF59E0B), // amber-500 (gradient slot 2a)
  ),
  IndicatorColorPreset(
    id: 'emerald',
    nameRu: 'Изумруд',
    nameEn: 'Emerald',
    lightPrimary: Color(0xFF059669), // emerald-600
    darkPrimary: Color(0xFF10B981), // emerald-500 (gradient slot 3a)
  ),
  IndicatorColorPreset(
    id: 'blue',
    nameRu: 'Синий',
    nameEn: 'Blue',
    lightPrimary: Color(0xFF2563EB), // blue-600
    darkPrimary: Color(0xFF3B82F6), // blue-500 (gradient slot 4b)
  ),
  IndicatorColorPreset(
    id: 'cyan',
    nameRu: 'Циан',
    nameEn: 'Cyan',
    lightPrimary: Color(0xFF0891B2), // cyan-600
    darkPrimary: Color(0xFF06B6D4), // cyan-500 (gradient slot 3b)
  ),
  IndicatorColorPreset(
    id: 'orange',
    nameRu: 'Оранжевый',
    nameEn: 'Orange',
    lightPrimary: Color(0xFFEA580C), // orange-600
    darkPrimary: Color(0xFFF97316), // orange-500 (gradient slot 6b)
  ),
];

bool isValidIndicatorColorPresetId(String id) =>
    kIndicatorColorPresets.any((p) => p.id == id);

IndicatorColorPreset resolveIndicatorColorPreset(String id) {
  for (final preset in kIndicatorColorPresets) {
    if (preset.id == id) return preset;
  }
  return kIndicatorColorPresets.first;
}

AppThemePreset resolveAppThemePreset(String id) {
  for (final preset in kAppThemePresets) {
    if (preset.id == id) return preset;
  }
  return kAppThemePresets.first;
}

ChatBubbleStylePreset resolveChatBubbleStylePreset(String id) {
  final normalizedId = normalizeChatBubbleStylePresetId(id);
  for (final preset in kChatBubbleStylePresets) {
    if (preset.id == normalizedId) return preset;
  }
  return kChatBubbleStylePresets.first;
}

NicknameStylePreset resolveNicknameStylePreset(String id) {
  for (final preset in kNicknameStylePresets) {
    if (preset.id == id) return preset;
  }
  return kNicknameStylePresets.first;
}

/// Default bubble preset to apply automatically when the user picks a theme.
/// Overridden when the user explicitly chooses a bubble style (manual mode).
const Map<String, String> kThemeToBubbleDefaults = {
  'flutter_dash': 'flutter_dash',
  'ocean': 'ocean',
  'graphite': 'graphite',
  'amethyst': 'amethyst',
  'sunset': 'sunset',
  'aurora': 'aurora',
  'rosewood': 'rosewood',
  'toplenoe_moloko': 'toplenoe_moloko',
  'noch_na_marse': 'noch_na_marse',
};

bool isValidAppThemePresetId(String id) =>
    kAppThemePresets.any((p) => p.id == id);
bool isValidChatBubbleStylePresetId(String id) => kChatBubbleStylePresets.any(
  (p) => p.id == normalizeChatBubbleStylePresetId(id),
);
bool isValidNicknameStylePresetId(String id) =>
    kNicknameStylePresets.any((p) => p.id == id);

const Color kNeutralDarkTopBarColor = Color(0xFF12161B);

Color resolveThemeTopBarTop({
  required bool darkMode,
  required AppThemePreset themePreset,
  required ColorScheme colorScheme,
}) {
  if (darkMode) {
    return themePreset.darkTopBarTop ??
        Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.14),
          kNeutralDarkTopBarColor,
        );
  }
  final base = themePreset.lightTopBarTop ?? colorScheme.surface;
  return Color.alphaBlend(colorScheme.primary.withValues(alpha: 0.15), base);
}

Color resolveThemeTopBarBottom({
  required bool darkMode,
  required AppThemePreset themePreset,
  required ColorScheme colorScheme,
}) {
  if (darkMode) {
    return themePreset.darkTopBarBottom ??
        Color.alphaBlend(
          colorScheme.secondary.withValues(alpha: 0.16),
          kNeutralDarkTopBarColor,
        );
  }
  final base =
      themePreset.lightTopBarBottom ?? colorScheme.surfaceContainerHighest;
  return Color.alphaBlend(colorScheme.secondary.withValues(alpha: 0.15), base);
}

Color resolveThemeTopBarBorder({
  required bool darkMode,
  required AppThemePreset themePreset,
  required ColorScheme colorScheme,
}) {
  return Colors.transparent;
}

/// Returns the deep solid-dark color used by the "midnight" chat wallpaper for
/// a given app theme. Pure black for flutter_dash / graphite (where the user
/// explicitly wants a true black background); for the other themes we blend a
/// faint accent of the theme's dark primary onto pure black so the wallpaper
/// reads as "as dark as possible, but still belongs to this theme".
Color resolveChatWallpaperDeepColor(AppThemePreset preset) {
  switch (preset.id) {
    case 'flutter_dash':
    case 'graphite':
      return const Color(0xFF000000);
    default:
      // ~6% tint of the dark primary blended onto pure black keeps the
      // background near-black while letting the theme hue show through.
      return Color.alphaBlend(
        preset.darkPrimary.withValues(alpha: 0.06),
        const Color(0xFF000000),
      );
  }
}

@immutable
class ChatVisualsThemeExtension
    extends ThemeExtension<ChatVisualsThemeExtension> {
  const ChatVisualsThemeExtension({
    required this.bubbleTop,
    required this.bubbleBottom,
    required this.shadowTop,
    required this.shadowBottom,
    required this.outgoingNickname,
    required this.incomingNickname,
    required this.actionTop,
    required this.actionBottom,
    required this.topBarTop,
    required this.topBarBottom,
    required this.topBarBorder,
    required this.chatWallpaperDeepColor,
    this.bubbleMid,
  });

  final Color bubbleTop;
  final Color bubbleBottom;
  final Color? bubbleMid;
  final Color shadowTop;
  final Color shadowBottom;
  final Color outgoingNickname;
  final Color incomingNickname;
  final Color actionTop;
  final Color actionBottom;
  final Color topBarTop;
  final Color topBarBottom;
  final Color topBarBorder;
  final Color chatWallpaperDeepColor;

  @override
  ChatVisualsThemeExtension copyWith({
    Color? bubbleTop,
    Color? bubbleBottom,
    Color? bubbleMid,
    Color? shadowTop,
    Color? shadowBottom,
    Color? outgoingNickname,
    Color? incomingNickname,
    Color? actionTop,
    Color? actionBottom,
    Color? topBarTop,
    Color? topBarBottom,
    Color? topBarBorder,
    Color? chatWallpaperDeepColor,
  }) {
    return ChatVisualsThemeExtension(
      bubbleTop: bubbleTop ?? this.bubbleTop,
      bubbleBottom: bubbleBottom ?? this.bubbleBottom,
      bubbleMid: bubbleMid ?? this.bubbleMid,
      shadowTop: shadowTop ?? this.shadowTop,
      shadowBottom: shadowBottom ?? this.shadowBottom,
      outgoingNickname: outgoingNickname ?? this.outgoingNickname,
      incomingNickname: incomingNickname ?? this.incomingNickname,
      actionTop: actionTop ?? this.actionTop,
      actionBottom: actionBottom ?? this.actionBottom,
      topBarTop: topBarTop ?? this.topBarTop,
      topBarBottom: topBarBottom ?? this.topBarBottom,
      topBarBorder: topBarBorder ?? this.topBarBorder,
      chatWallpaperDeepColor:
          chatWallpaperDeepColor ?? this.chatWallpaperDeepColor,
    );
  }

  @override
  ChatVisualsThemeExtension lerp(
    ThemeExtension<ChatVisualsThemeExtension>? other,
    double t,
  ) {
    if (other is! ChatVisualsThemeExtension) return this;
    final selfMid = bubbleMid;
    final otherMid = other.bubbleMid;
    final lerpedMid = (selfMid == null && otherMid == null)
        ? null
        : Color.lerp(selfMid ?? other.bubbleTop, otherMid ?? bubbleTop, t);
    return ChatVisualsThemeExtension(
      bubbleTop: Color.lerp(bubbleTop, other.bubbleTop, t)!,
      bubbleBottom: Color.lerp(bubbleBottom, other.bubbleBottom, t)!,
      bubbleMid: lerpedMid,
      shadowTop: Color.lerp(shadowTop, other.shadowTop, t)!,
      shadowBottom: Color.lerp(shadowBottom, other.shadowBottom, t)!,
      outgoingNickname: Color.lerp(
        outgoingNickname,
        other.outgoingNickname,
        t,
      )!,
      incomingNickname: Color.lerp(
        incomingNickname,
        other.incomingNickname,
        t,
      )!,
      actionTop: Color.lerp(actionTop, other.actionTop, t)!,
      actionBottom: Color.lerp(actionBottom, other.actionBottom, t)!,
      topBarTop: Color.lerp(topBarTop, other.topBarTop, t)!,
      topBarBottom: Color.lerp(topBarBottom, other.topBarBottom, t)!,
      topBarBorder: Color.lerp(topBarBorder, other.topBarBorder, t)!,
      chatWallpaperDeepColor: Color.lerp(
        chatWallpaperDeepColor,
        other.chatWallpaperDeepColor,
        t,
      )!,
    );
  }
}
