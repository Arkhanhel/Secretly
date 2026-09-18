// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

/// Видимая заглушка на месте картинки, которую не удалось открыть.
///
/// 🔴 ПОЧЕМУ ОНА ОБЯЗАНА БЫТЬ ВИДИМОЙ. Картинка по мёртвому пути бросает
/// исключение при КАЖДОЙ перерисовке, а каждое такое исключение — пропущенный
/// кадр; так и появляется «подтормаживает». Но погасить ошибку молча значило бы
/// превратить «подтормаживает» в «часть фото пропала», и это было бы хуже: одно
/// человек переживёт, второе выглядит как потеря.
///
/// Мёртвые пути у нас находились трижды — фото профиля (13.07), стикеры (08.08) и
/// медиа в чате — и причина каждый раз одна: абсолютный путь не переживает
/// переустановку, потому что на iOS каталог приложения меняет UUID. Заглушка это
/// не лечит, она делает потерю ЗАМЕТНОЙ вместо шумной.
class BrokenMediaBox extends StatelessWidget {
  const BrokenMediaBox({
    super.key,
    this.iconSize = 22,
    this.rounded = false,
    this.onDarkSurface = false,
  });

  final double iconSize;

  /// Кругом — там, где заглушка встаёт на место аватара.
  final bool rounded;

  /// Поверх обоев, фото или видео, где темы экрана не видно и белое читается
  /// лучше цветов схемы.
  final bool onDarkSurface;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fill = onDarkSurface
        ? Colors.white.withValues(alpha: 0.06)
        : cs.surfaceContainerHighest.withValues(alpha: 0.55);
    final ink = onDarkSurface
        ? Colors.white.withValues(alpha: 0.35)
        : cs.onSurfaceVariant.withValues(alpha: 0.45);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        shape: rounded ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: iconSize,
          color: ink,
        ),
      ),
    );
  }
}
