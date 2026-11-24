// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// The scroll feel for VERTICAL content lists — chats, messages, stickers.
///
/// 🔴 WHY THIS EXISTS (2026-08-01, field: "Telegram glides longer and smoother").
///
/// Every list in the app was pinned to [BouncingScrollPhysics], which is the
/// **iOS** curve: iOS friction plus a rubber-band at the ends. On Android that
/// is doubly wrong — it does not match the platform's own deceleration, and it
/// does not match any other app on the device, including the one being compared
/// against. Telegram for Android is a native `RecyclerView` driven by the
/// system `OverScroller`, so it inherits the platform curve for free.
///
/// [ClampingScrollPhysics] is Flutter's model of that same `OverScroller`, and
/// Android ends a list with a stretch/glow rather than a bounce. So the fix is
/// not to invent a curve — it is to stop overriding the platform's.
///
/// **This is about FEEL, not smoothness.** Frame drops come from work done
/// during the scroll (image decoding above all); no amount of physics tuning
/// hides them. The two were investigated together and fixed separately — see
/// `chatWallpaperDecodeWidth` for the other half.
library;

import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Android's fling friction, scaled. 1.0 is the platform default exactly.
///
/// 🔴 HOW THIS MUST BE TUNED — the previous attempt got it backwards
/// (2026-08-01, field: "horribly sharp and fast scrolling, just awful").
///
/// The first version lengthened the glide by handing the simulation a LARGER
/// STARTING VELOCITY (×1.25), on the belief that `ClampingScrollSimulation`
/// exposes no friction. It does — `friction`, default 0.015, right there in the
/// constructor. And multiplying velocity is not "glides longer": it makes the
/// list leave the finger 25% FASTER than the finger actually moved. That breaks
/// the one thing a scroll must never break — the list travelling at the speed
/// you flicked it — so it reads as harsh and twitchy, not smooth.
///
/// Lower friction is the honest knob: the list starts at exactly the speed your
/// finger gave it and simply coasts further before settling. Below 1.0 = longer
/// coast, same launch. Never scale velocity again.
///
/// Measured, not guessed — a 2000 px/s flick:
///
/// | model                  | distance | settles | launches at   |
/// |------------------------|----------|---------|---------------|
/// | stock Android (1.00)   |   647 px |  0.77 s | 2000  correct |
/// | the ×1.25 velocity bug |   954 px |  0.90 s | 2500  WRONG   |
/// | this (0.80 friction)   |   763 px |  0.90 s | 2000  correct |
///
/// 0.80 is chosen so the list SETTLES in the same 0.90 s the velocity version
/// did — the pacing was never the complaint — while launching at the finger's
/// real speed, which was. Raising the coast further is one number here; do that
/// only on a fresh report, and never by touching velocity.
const double kScrollFrictionScale = 0.80;

/// Android's own curve with a longer coast.
///
/// Deliberately re-implements `ClampingScrollPhysics.createBallisticSimulation`
/// instead of delegating, because the ONLY way to reach `friction` is to build
/// the simulation here. Every guard from the original is preserved verbatim —
/// the snap-back spring when out of range, the below-tolerance no-op, and the
/// two at-the-edge no-ops — so the only behavioural difference is how far an
/// in-range fling coasts.
class _GlideClampingScrollPhysics extends ClampingScrollPhysics {
  const _GlideClampingScrollPhysics({super.parent});

  @override
  _GlideClampingScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _GlideClampingScrollPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // 🔴 Out of range this method builds the SNAP-BACK spring that returns an
    // over-scrolled list to its edge — nothing to do with a fling. Delegate it
    // untouched; a "longer" snap-back reads as a bug, not as glide.
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    final Tolerance tolerance = toleranceFor(position);
    if (velocity.abs() < tolerance.velocity) {
      return null;
    }
    if (velocity > 0.0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    if (velocity < 0.0 && position.pixels <= position.minScrollExtent) {
      return null;
    }
    if (kAndroidSmoothGlide) {
      // 23.11.2026: торможение с плавным длинным «хвостом» (см.
      // [kAndroidSmoothGlide]). Скорость — та же, что у пальца.
      return FrictionSimulation(
        kSmoothGlideDrag,
        position.pixels,
        velocity,
        tolerance: tolerance,
      );
    }
    return ClampingScrollSimulation(
      position: position.pixels,
      // Untouched, on purpose. This is the finger's own speed.
      velocity: velocity,
      friction: 0.015 * kScrollFrictionScale,
      tolerance: tolerance,
    );
  }
}

/// Android: торможение броска — плавное, с длинным хвостом, а не сплайн
/// Android (23.11.2026, владелец: «у Telegram останавливается гораздо
/// медленнее и плавнее, у нас почти резко»).
///
/// 🔴 ПОЧЕМУ. Flutter считает прокрутку сам по стандартной кривой Android
/// (сплайн `OverScroller`): короткий выбег и довольно резкая остановка. Xiaomi
/// (HyperOS) подменяет в системе эту кривую своей — длинный плавный выбег с
/// экспоненциальным хвостом, близкий к iPhone, — и обычные приложения, Telegram
/// в том числе, получают её даром; Flutter — нет. Бросок 2000 т/с: сплайн
/// ×0,8 — ~760 т за ~0,9 с с резким концом; здесь — ~1000 т за ~2,5 с, к концу
/// скорость тает плавно. Края — как были (растяжение Android), старт — ровно
/// скорость пальца. `false` — снова сплайн Android ×[kScrollFrictionScale].
const bool kAndroidSmoothGlide = true;

/// Физика списков Android — для проверок (на машине проверок не Android).
@visibleForTesting
ScrollPhysics debugAndroidGlidePhysics() => const _GlideClampingScrollPhysics();

/// Затухание скорости за секунду: 0,135 = 0,998 за миллисекунду —
/// `UIScrollView.decelerationRate.normal`.
const double kSmoothGlideDrag = 0.135;

ScrollPhysics secretlyListPhysics() {
  // `Platform` rather than `Theme.of(context).platform` on purpose: the theme's
  // platform is overridable for previews and tests, and the scroll curve should
  // follow the DEVICE the finger is actually on.
  if (Platform.isIOS || Platform.isMacOS) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
  return const _GlideClampingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );
}

/// The same glide, for lists that must KEEP clamping overscroll on every
/// platform because they carry a pull gesture of their own.
///
/// 🔴 WHY A SECOND ENTRY POINT (2026-08-01, field: "Android scrolling did not
/// change"). The chats list and the room/contact details lists read
/// `OverscrollNotification` at the top edge to drive their own pull-to-reveal.
/// iOS rubber-band overscroll competes with that gesture, which is why those
/// screens pin [ClampingScrollPhysics] on BOTH platforms instead of calling
/// [secretlyListPhysics] — and that pin is also why the glide never reached
/// them.
///
/// So: keep iOS byte-for-byte as it is today (plain clamping, gesture intact),
/// and give Android the glide it was supposed to get. The glide only scales the
/// BALLISTIC velocity of an in-range fling, so it cannot touch a drag-driven
/// pull either way.
///
/// 🔴 22.11.2026 (владелец: «на главной нет айфоновской пружинки, только
/// там»). [topPullDragActive] — список, у которого жест сверху свой: пока
/// палец ТЯНЕТ у верхнего края, край прижат (жест получает overscroll, как
/// раньше), а в остальном — пружина iOS: внизу списка и при броске к верху.
ScrollPhysics secretlyPullListPhysics({bool Function()? topPullDragActive}) {
  if (Platform.isIOS || Platform.isMacOS) {
    if (topPullDragActive != null) {
      return TopPullBounceScrollPhysics(
        topPullDragActive: topPullDragActive,
        parent: const AlwaysScrollableScrollPhysics(),
      );
    }
    return secretlyProfileScrollPhysics();
  }
  return const _GlideClampingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );
}

/// True when the running platform expects the iOS rubber-band at list ends.
///
/// Exposed so a widget that draws its own end-of-list affordance can match,
/// instead of each one re-deriving the platform.
bool get secretlyUsesBouncingScroll => Platform.isIOS || Platform.isMacOS;

/// Пружина iOS везде, кроме верхнего края под пальцем: там край прижат, и
/// весь overscroll уходит своему жесту сверху (у списка чатов — «Личные»).
class TopPullBounceScrollPhysics extends BouncingScrollPhysics {
  const TopPullBounceScrollPhysics({
    required this.topPullDragActive,
    super.parent,
  });

  /// Палец сейчас тянет список (а не бросок / возврат пружины).
  final bool Function() topPullDragActive;

  @override
  TopPullBounceScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return TopPullBounceScrollPhysics(
      topPullDragActive: topPullDragActive,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (topPullDragActive()) {
      // Как у ClampingScrollPhysics, только для верхнего края.
      if (value < position.pixels &&
          position.pixels <= position.minScrollExtent) {
        return value - position.pixels;
      }
      if (value < position.minScrollExtent &&
          position.minScrollExtent < position.pixels) {
        return value - position.minScrollExtent;
      }
    }
    return super.applyBoundaryConditions(position, value);
  }
}

// ─────────────── 23.11.2026: прокрутка как у Telegram на всех экранах ───────────────
// Разбор: docs/SCROLL_FEEL_TELEGRAM_2026-11-23.md.

/// Выключатель «одной прокрутки»: `false` — экраны без явной физики снова
/// получают стандарт Flutter (на Android выбег короче, чем в списке чатов).
const bool kUnifiedScrollFeel = true;

/// Выключатель кривой iOS на страницах с прижатым краем (профиль собеседника,
/// комната, свой профиль). `false` — там снова кривая Android, как до 23.11.
const bool kIosClampedGlide = true;

/// Прокрутка приложения по умолчанию (телефон).
///
/// 🔴 ПОЧЕМУ (23.11.2026). Нашу физику получали 16 списков из 181; профиль,
/// настройки, галерея и листы шли стандартом Flutter — на Android они
/// тормозили раньше списка чатов, и страницы ощущались по-разному. У
/// Telegram прокрутка везде одна (системная). Здесь — та же, что у чатов.
///
/// Явно заданная физика у списка остаётся главной (Flutter ставит её поверх
/// этой): жесты, «пейджеры», запреты прокрутки не меняются. iPhone — как
/// было (пружина iOS по умолчанию).
class SecretlyScrollBehavior extends MaterialScrollBehavior {
  const SecretlyScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (kUnifiedScrollFeel && Platform.isAndroid) {
      return const _GlideClampingScrollPhysics(
        parent: RangeMaintainingScrollPhysics(),
      );
    }
    return super.getScrollPhysics(context);
  }
}

/// Страница с прижатым верхним краем (жест «потянуть фото»): край прижат на
/// обеих платформах, а торможение — своё у каждой. На iPhone прежде была
/// кривая Android (резче и короче, чем у iOS, без разгона повторных
/// бросков) — теперь торможение `UIScrollView`.
ScrollPhysics secretlyProfileScrollPhysics() {
  if (Platform.isIOS || Platform.isMacOS) {
    if (!kIosClampedGlide) {
      return const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    return const IosClampedGlideScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
  return const _GlideClampingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );
}

/// Края прижаты, как у [ClampingScrollPhysics] (overscroll уходит жесту
/// страницы), но бросок тормозит как `UIScrollView .normal` — то же трение,
/// что у [BouncingScrollPhysics] (0,998 за мс), и тот же разгон повторных
/// бросков. Дошёл до края — останавливается (край прижат, пружины нет).
@visibleForTesting
class IosClampedGlideScrollPhysics extends ClampingScrollPhysics {
  const IosClampedGlideScrollPhysics({super.parent});

  @override
  IosClampedGlideScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      IosClampedGlideScrollPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Возврат из-за края — как у прижатой прокрутки, без изменений.
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    final Tolerance tolerance = toleranceFor(position);
    if (velocity.abs() < tolerance.velocity) return null;
    if (velocity > 0.0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    if (velocity < 0.0 && position.pixels <= position.minScrollExtent) {
      return null;
    }
    // UIScrollView.decelerationRate .normal = 0,998 за мс → 0,135 за секунду.
    // Перелёт за край обрезает прижатая граница, и бросок там заканчивается.
    return FrictionSimulation(
      0.135,
      position.pixels,
      velocity,
      tolerance: tolerance,
    );
  }

  /// Разгон повторных бросков — формула iOS из [BouncingScrollPhysics].
  @override
  double carriedMomentum(double existingVelocity) =>
      existingVelocity.sign *
      math.min(
        0.000816 * math.pow(existingVelocity.abs(), 1.967).toDouble(),
        40000.0,
      );

  /// Как у iOS: случайный сдвиг пальца при отрыве не считается броском.
  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}

/// Выключатель сглаживания касаний на Android.
const bool kTouchResampling = true;

/// На сколько раньше кадра берётся точка касания. Стандарт Flutter −38 мс
/// (заметно «тянется» за пальцем); у Android сама система — около −5 мс.
/// −8 мс — один кадр 120 Гц: между точками касания (Xiaomi шлёт их каждые
/// ~4 мс) всегда есть пара по обе стороны, и точка считается честно, без
/// угадывания вперёд.
const Duration kTouchSamplingOffset = Duration(milliseconds: -8);

/// Сглаживание касаний на Android (23.11.2026).
///
/// 🔴 ПОЧЕМУ. На экране 120 Гц точки касания приходят не в такт кадрам: в
/// один кадр попадает две, в соседний одна — список под пальцем шагает
/// неровно и «зернит». Telegram (обычные View Android) получает касания,
/// уже пересчитанные системой на время кадра. Flutter умеет так же, но по
/// умолчанию выключено. iPhone касания отдаёт в такт экрану — не трогаем.
void enableTouchResamplingForAndroid() {
  if (!kTouchResampling || !Platform.isAndroid) return;
  GestureBinding.instance
    ..resamplingEnabled = true
    ..samplingOffset = kTouchSamplingOffset;
}
