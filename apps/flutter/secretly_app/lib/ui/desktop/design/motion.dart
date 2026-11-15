// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// ДВИЖЕНИЕ ПК — ОДИН ЯЗЫК НА ВСЁ ОКНО.
///
/// 🔴 05.10.2026, владелец: «приложение выглядит дёшево, потому что оно не
/// плавное, не анимированное — плоское. Всё должно быть плавным, приятным,
/// дорогим; где можно — превращение кнопок одна в другую; не детские и не
/// плоские анимации, а современные и грамотные; и чтобы всё работало быстро».
///
/// Правила, из которых собраны все анимации ПК:
///
///   1. ВХОД ЗАМЕДЛЯЕТСЯ, УХОД УСКОРЯЕТСЯ. Появляющееся влетает быстро и
///      мягко садится на место ([decelerate]); уходящее трогается мягко и
///      исчезает быстро ([accelerate]). Уход всегда короче входа: закрытое
///      человеку уже не нужно, ждать его нельзя.
///   2. БЕЗ ОТСКОКОВ. Перелёт за конечное положение («пружинка») — признак
///      игрушки. Отметки выбора скользят по [glideCurve] — быстрый старт и
///      долгий мягкий подход без перелёта. Единственное исключение — реакции
///      под сообщением: там отскок — смысл («поставил!»), а не украшение.
///   3. НАЖАТИЕ ОТВЕЧАЕТ СРАЗУ. Кнопка вжимается за [press] и отпускается
///      дольше — за [release]: короткое «вниз» и мягкое «назад» читаются как
///      физическая кнопка, а не как смена картинки.
///   4. МЕНЯЕТСЯ — ЗНАЧИТ ПРЕВРАЩАЕТСЯ. Значок и подпись на месте не
///      подменяются, а перетекают одно в другое ([morph]): старое сжимается
///      и гаснет, новое вырастает из того же центра.
///   5. ДВИЖЕТСЯ ТОЛЬКО ДЕШЁВОЕ. Прозрачность, сдвиг и масштаб — их считает
///      видеокарта; размеры меняются лишь у мелких вещей (подпись кнопки,
///      карточка ответа). Длинные списки при переходах не перекладываются.
///   6. «УМЕНЬШИТЬ ДВИЖЕНИЕ» В СИСТЕМЕ — УВАЖАЕМ. Тогда длительности
///      нулевые ([of]): всё меняется сразу, как просил человек.
library;

import 'package:flutter/widgets.dart';

class DMotion {
  DMotion._();

  // ── Длительности ─────────────────────────────────────────────────────────

  /// Наведение и мелкие смены цвета.
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 280);
  static const Duration xslow = Duration(milliseconds: 320);

  /// Кнопка вжимается — сразу.
  static const Duration press = Duration(milliseconds: 90);

  /// …и отпускается мягче, чем вжималась.
  static const Duration release = Duration(milliseconds: 240);

  /// Значок или подпись превращается в другую.
  static const Duration morph = Duration(milliseconds: 220);

  /// Отметка выбора переезжает к новому пункту (рейка, сегменты, разделы
  /// настроек).
  static const Duration glide = Duration(milliseconds: 320);

  /// Всплывающее: меню, подсказка, карточка у кнопки.
  static const Duration popIn = Duration(milliseconds: 200);
  static const Duration popOut = Duration(milliseconds: 130);

  /// Окно поверх приложения.
  static const Duration modalIn = Duration(milliseconds: 280);
  static const Duration modalOut = Duration(milliseconds: 170);

  /// Смена раздела, страницы, открытой переписки.
  static const Duration page = Duration(milliseconds: 300);

  // ── Кривые ───────────────────────────────────────────────────────────────

  static const Cubic easeOutCubic = Cubic(0.33, 1.0, 0.68, 1.0);
  static const Cubic easeInCubic = Cubic(0.32, 0.0, 0.67, 0.0);
  static const Cubic easeOutBack = Cubic(0.34, 1.56, 0.64, 1.0);
  static const Curve easeInOut = Curves.easeInOut;

  /// Обычное движение «отсюда туда» внутри экрана.
  static const Cubic standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Вход: быстро влетает, долго и мягко садится.
  static const Cubic decelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Уход: мягко трогается, быстро исчезает.
  static const Cubic accelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Скольжение отметки выбора: резвый старт, подход без перелёта.
  static const Cubic glideCurve = Cubic(0.32, 0.72, 0.0, 1.0);

  static final SpringDescription snap = SpringDescription(
    mass: 1,
    stiffness: 180,
    damping: 22,
  );

  // ── «Уменьшить движение» ─────────────────────────────────────────────────

  /// Попросил ли человек систему уменьшить движение.
  static bool reduced(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return true;
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.reduceMotion || features.disableAnimations;
  }

  /// [duration], а при «уменьшить движение» — ноль.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  /// Значение [animation] на кривой: вперёд — [inCurve], назад — уход по
  /// [outCurve] во ВРЕМЕНИ (кривая обращена: уходящее трогается мягко и
  /// исчезает быстро).
  ///
  /// Для переходов маршрутов: их строитель зовётся на каждом кадре, и
  /// заводить там `CurvedAnimation` (он подписывается на родителя) незачем.
  static double eased(
    Animation<double> animation, {
    Curve inCurve = decelerate,
    Curve outCurve = accelerate,
  }) {
    final v = animation.value.clamp(0.0, 1.0);
    final leaving =
        animation.status == AnimationStatus.reverse ||
        animation.status == AnimationStatus.dismissed;
    return leaving ? outCurve.flipped.transform(v) : inCurve.transform(v);
  }
}
