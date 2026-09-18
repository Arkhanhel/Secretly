// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/widgets.dart';

/// Плавная смена значка внутри кнопки, которая САМА не меняет размер.
///
/// 🔴 ЗАЧЕМ. В кнопке справа от поля ввода живут три значка — микрофон, камера
/// и самолётик, — и раньше они подменялись рывком: ветка `if` внутри сборки,
/// `setState`, мгновенная подмена. А переход между отправкой и записью раздувал
/// круг: масштаб шёл от 0.82 с кривой `easeOutBack`, а она ПЕРЕЛЕТАЕТ за
/// единицу, поэтому круг вырастал больше своего размера и оседал обратно.
///
/// 🔴 ПОЧЕМУ ЭТО НЕ НАСТОЯЩИЙ МОРФ КОНТУРА. Превратить микрофон в камеру
/// перетеканием линий можно двумя способами: сведёнными вручную векторными
/// путями одинаковой топологии либо готовой анимацией Lottie на каждую пару.
/// Первое ломается от любой смены значка, второго у нас нет. Поворот с
/// растворением внутри неподвижного круга читается как превращение — именно так
/// сделано в мессенджерах, на которые мы смотрим, — и не зависит от того, какие
/// значки стоят внутри.
///
/// Размер задаётся снаружи и держится жёстко: содержимое разного размера не
/// имеет права двигать кнопку.
class ComposerGlyphMorph extends StatelessWidget {
  const ComposerGlyphMorph({
    super.key,
    required this.child,
    this.box = 24,
    this.turns = 0.125,
  });

  /// Значок. Обязан нести [Key], иначе смена состояния не будет замечена и
  /// анимации не произойдёт вовсе.
  final Widget child;

  /// Сторона квадрата, в котором живёт значок.
  final double box;

  /// На сколько оборота поворачивается значок за переход. 0.125 — это 45°.
  final double turns;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: box,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        reverseDuration: const Duration(milliseconds: 200),
        // 🔴 БЕЗ `easeOutBack`. Кривые с перелётом — ровно то, из-за чего
        // кнопка «меняла размер».
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        // Уходящий и входящий стоят друг на друге по центру. Иначе уходящий
        // остаётся в потоке и на миг раздвигает кнопку.
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...previous,
            if (current != null) current,
          ],
        ),
        transitionBuilder: (child, animation) {
          // Оба — и уходящий, и входящий — крутятся В ОДНУ сторону: тогда это
          // читается как один значок, уехавший на место другого, а не как две
          // независимо дёрнувшиеся картинки.
          return FadeTransition(
            opacity: animation,
            child: RotationTransition(
              turns: Tween<double>(begin: -turns, end: 0).animate(animation),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.72, end: 1).animate(animation),
                child: Center(child: child),
              ),
            ),
          );
        },
        child: child,
      ),
    );
  }
}
