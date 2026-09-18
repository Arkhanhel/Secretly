// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
typedef ProfileIconGradientPair = ({int startArgb, int endArgb});

const List<ProfileIconGradientPair> kProfileIconPrimaryGradients =
    <ProfileIconGradientPair>[
      (startArgb: 0xFF42E29C, endArgb: 0xFF5BCFFA),
      (startArgb: 0xFF3D1352, endArgb: 0xFFA93FB3),
      (startArgb: 0xFFF26F4E, endArgb: 0xFFE2306E),
      (startArgb: 0xFF341050, endArgb: 0xFFD8369F),
      (startArgb: 0xFF3DDCFC, endArgb: 0xFF7C2FE0),
      (startArgb: 0xFFEB48A0, endArgb: 0xFFA22BC6),
      (startArgb: 0xFFF4A538, endArgb: 0xFFDA4368),
      (startArgb: 0xFF5DC0F2, endArgb: 0xFF3F58E5),
      (startArgb: 0xFF1A0F8B, endArgb: 0xFF5B22C8),
      (startArgb: 0xFFC530D6, endArgb: 0xFF7820D6),
    ];

const List<ProfileIconGradientPair> kProfileIconSecondaryGradients =
    <ProfileIconGradientPair>[
      (startArgb: 0xFFE8F7FF, endArgb: 0xFFCDE9FF),
      (startArgb: 0xFFEFFBF2, endArgb: 0xFFD8F3E4),
      (startArgb: 0xFFFFF6EC, endArgb: 0xFFFFE8D1),
      (startArgb: 0xFFFFEEF4, endArgb: 0xFFFFD9E8),
      (startArgb: 0xFFF2EEFF, endArgb: 0xFFE1D8FF),
      (startArgb: 0xFFEFF3FF, endArgb: 0xFFDCE4FF),
      (startArgb: 0xFFF3FFF8, endArgb: 0xFFDCF6EA),
      (startArgb: 0xFFF2F6FA, endArgb: 0xFFE1EAF2),
      (startArgb: 0xFF1F1F1F, endArgb: 0xFF000000),
    ];

const List<ProfileIconGradientPair> kProfileIconAllGradients =
    <ProfileIconGradientPair>[
      ...kProfileIconPrimaryGradients,
      ...kProfileIconSecondaryGradients,
    ];