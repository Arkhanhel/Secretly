// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Единый словарь движения приложения (М1, docs/TZ_MOTION_TELEGRAM_PARITY_
/// 2026-11-20.md). Числа взяты из открытого кода Telegram:
///
/// * iPhone — одна фирменная кривая `(0.38, 0.70, 0.125, 1.0)` почти на всё
///   (`CAAnimationUtils.swift`), пружины без отскока (`UIKitUtils.m`).
/// * Android — `EASE_OUT_QUINT (0.23, 1, 0.32, 1)` основная,
///   `DEFAULT (0.25, 0.1, 0.25, 1)` для появлений, `EASE_OUT_BACK` там, где
///   Telegram даёт лёгкий перелёт (`CubicBezierInterpolator.java`).
///
/// Компьютер (macOS/Windows/Linux) получает ПРЕЖНЮЮ кривую места — у него
/// свой дизайн, и эта работа его не касается.
///
/// Всё — `const`: кривые подставляются и в `const`-конструкторы, ничего не
/// выделяется на кадр. Выбор платформы — `defaultTargetPlatform`, его
/// подменяют тесты (`TargetPlatformVariant`).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Выключатель всего «движения как в Telegram». `false` — каждая кривая
/// возвращает прежнюю (ту, что стояла в коде до 20.11.2026), пружины —
/// прежние числа. Откат одной строкой, без правок по местам.
const bool kTelegramMotion = true;

/// Кривая, выбранная по платформе. На iPhone и Android — кривые Telegram,
/// иначе (и при выключенном [kTelegramMotion]) — [other], прежняя кривая.
class MotionCurve extends Curve {
  const MotionCurve({
    required this.ios,
    required this.android,
    required this.other,
  });

  final Curve ios;
  final Curve android;
  final Curve other;

  Curve get _current {
    if (!kTelegramMotion) return other;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return other;
    }
  }

  @override
  double transform(double t) => _current.transform(t);

  @override
  String toString() => 'MotionCurve($_current)';
}

/// Кривые Telegram без выбора платформы.
abstract final class TgCurves {
  /// Фирменная кривая iOS: быстрый старт, долгий мягкий докат.
  static const Cubic ios = Cubic(0.38, 0.70, 0.125, 1.0);

  /// `.slide` iOS — для сдвигов панелей.
  static const Cubic iosSlide = Cubic(0.33, 0.52, 0.25, 0.99);

  /// `EASE_OUT_QUINT` — основная кривая Android.
  static const Cubic androidQuint = Cubic(0.23, 1.0, 0.32, 1.0);

  /// `DEFAULT` Android — появления и прозрачность.
  static const Cubic androidDefault = Cubic(0.25, 0.1, 0.25, 1.0);

  /// `EASE_OUT_BACK` Android — лёгкий перелёт (≈ 10 %), не «резинка».
  static const Cubic androidBack = Cubic(0.34, 1.56, 0.64, 1.0);

  /// `EmphasizedDecelerate` — листы и окна на Android.
  static const Cubic emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Появление сообщения на Android (`ChatListItemAnimator`).
  static const Cubic androidMessage = Cubic(0.1992, 0.0106, 0.2792, 0.9103);
}

/// Кривые приложения. Имя говорит, ЧТО двигается, а не какая формула.
abstract final class Motion {
  /// Обычное движение: сдвиг, рост, смена размера, прокрутка к месту.
  /// Заменяет `Curves.easeOutCubic` / `Curves.easeOutQuart`.
  static const MotionCurve standard = MotionCurve(
    ios: TgCurves.ios,
    android: TgCurves.androidQuint,
    other: Curves.easeOutCubic,
  );

  /// То же для мест, где прежде стоял `Curves.easeOutQuart`.
  static const MotionCurve standardQuart = MotionCurve(
    ios: TgCurves.ios,
    android: TgCurves.androidQuint,
    other: Curves.easeOutQuart,
  );

  /// Мягкое появление/исчезание (прозрачность, цвет). Заменяет
  /// `Curves.easeOut`.
  static const MotionCurve fade = MotionCurve(
    ios: TgCurves.ios,
    android: TgCurves.androidDefault,
    other: Curves.easeOut,
  );

  /// «Выскакивание» с лёгким перелётом — меню, значки, выбранная плитка.
  /// Заменяет `Curves.easeOutBack`: на iPhone Telegram не перелетает, на
  /// Android — едва заметно.
  static const MotionCurve pop = MotionCurve(
    ios: TgCurves.ios,
    android: TgCurves.androidBack,
    other: Curves.easeOutBack,
  );

  /// Заменяет `Curves.elasticOut` («болтанку»): у Telegram её нет нигде.
  static const MotionCurve popElastic = MotionCurve(
    ios: TgCurves.ios,
    android: TgCurves.androidBack,
    other: Curves.elasticOut,
  );

  /// Нижние листы и окна (М6 доведёт до пружины).
  static const MotionCurve sheet = MotionCurve(
    ios: TgCurves.ios,
    android: TgCurves.emphasizedDecelerate,
    other: Curves.easeOutCubic,
  );
}

/// Пружины. У Telegram они НЕ отскакивают: соотношение демпфирования 1,0
/// (критическое) или больше. Значения `damping` посчитаны заранее
/// (`2·√(m·k)·ratio`), чтобы оставаться `const`.
abstract final class MotionSprings {
  /// iOS 26 Telegram: масса 1, жёсткость 555.027, демпфирование 47.118 —
  /// отклик ≈ 0,27 с, без отскока. Для небольших «доводок».
  static const SpringDescription standard = kTelegramMotion
      ? SpringDescription(mass: 1, stiffness: 555.027, damping: 47.118)
      : SpringDescription(mass: 1, stiffness: 350, damping: 25);

  /// Переход экрана по нажатию: отклик 0,3 с, ratio 1,0.
  static const SpringDescription navigation = SpringDescription(
    mass: 1,
    stiffness: 438.6,
    damping: 41.89,
  );

  /// Доводка после свайпа: ratio 0,85 — едва заметный «докат» со скоростью
  /// пальца (как в Telegram после свайпа назад).
  static const SpringDescription afterSwipe = SpringDescription(
    mass: 1,
    stiffness: 438.6,
    damping: 35.6,
  );

  /// Большие перемещения (мини-окно звонка к углу): мягче, но без отскока.
  static const SpringDescription large = kTelegramMotion
      ? SpringDescription(mass: 1, stiffness: 220, damping: 29.67)
      : SpringDescription(mass: 1, stiffness: 220, damping: 22);

  /// Плавающий пузырь звонка к краю экрана.
  static const SpringDescription bubble = kTelegramMotion
      ? SpringDescription(mass: 1, stiffness: 300, damping: 34.64)
      : SpringDescription(mass: 1, stiffness: 300, damping: 24);
}

/// Длительности Telegram. Сами по себе места их не меняют — новые и
/// переделанные анимации берут отсюда.
abstract final class MotionDurations {
  /// Нажатие iOS (сжатие).
  static const Duration press = Duration(milliseconds: 200);

  /// Короткая смена состояния (переключатели, подсветка).
  static const Duration quick = Duration(milliseconds: 200);

  /// Обычное движение элемента.
  static const Duration standard = Duration(milliseconds: 300);

  /// Перестройка списков и вкладок (Telegram iOS — 0,4 с).
  static const Duration list = Duration(milliseconds: 400);
}

/// Человек просил меньше движения (системная настройка «Уменьшить
/// движение» / «Удалить анимации»).
bool motionReduced(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
