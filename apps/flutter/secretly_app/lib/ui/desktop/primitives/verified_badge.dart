// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// Значок рядом с именем: ГАЛОЧКА, а не звезда.
///
/// 🔴 ПОЧЕМУ ЗАМЕНА (14.09.2026, прямое указание владельца по макету).
///
/// Рядом с именем стояла `PremiumStarBadge` — искорка в кружке, общий виджет с
/// телефоном, который по своему назначению отмечает ПЛАТНУЮ ВОЗМОЖНОСТЬ
/// («это только в Premium»). Ставить её рядом с именем человека значило
/// говорить не то: имя — не возможность, которую можно купить.
///
/// В макете на этом месте синяя галочка `verified` (#6FA8F7), а платный тариф
/// назван отдельно — фиолетовым чипом «PRO» в карточке профиля. Два разных
/// смысла, два разных знака.
///
/// 🔴 Свой виджет, а не правка общего: `PremiumStarBadge` живёт в
/// `lib/ui/widgets/` и используется мобильной версией по прямому назначению —
/// у платных строк настроек. Мобильная версия выпущена, и менять там значок
/// нельзя.
class DesktopVerifiedBadge extends StatelessWidget {
  const DesktopVerifiedBadge({super.key, this.size = 14, this.show = true});

  /// Размер галочки в точках. В макете 13 в списке, 14–16 в шапке, 18 в
  /// карточке профиля.
  final double size;

  /// Ложь — не рисуем ничего.
  final bool show;

  /// Цвет галочки из макета. Не берётся из палитры темы намеренно: это
  /// опознавательный знак, а не акцент интерфейса, и в макете он один и тот же
  /// на всех четырёх артбордах.
  static const Color color = Color(0xFF6FA8F7);

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return Icon(FluentIcons.checkmark_circle_16_filled, size: size, color: color);
  }
}
