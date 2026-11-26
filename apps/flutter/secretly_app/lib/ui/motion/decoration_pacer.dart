// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Украшения на телефоне — не чаще 60 кадров в секунду (23.11.2026).
///
/// 🔴 ЗАМЕР (Xiaomi 120 Гц, сборка 727). В покое список чатов и профиль
/// рисовали 120 кадров в секунду без остановки: живые рамки шагают позой
/// 60 раз в секунду, но их тикер всё равно заказывает кадр на КАЖДОЕ
/// обновление экрана, и Flutter каждый раз заново отдаёт на отрисовку всё
/// дерево — около 6 мс работы видеочипа каждые 8,3 мс. Нагрев и батарея.
///
/// [PacedTicker] — тот же тикер, но следующий кадр он просит не сразу, а
/// чуть меньше чем через 1/60 секунды после своего шага: на экране 120 Гц
/// кадр приходит через одно обновление (ровно 60 в секунду, в такт экрану,
/// без рывков таймера), на 60 Гц — каждое обновление, как раньше, на
/// 90 Гц — каждое (45 было бы хуже, чем ничего), на 144 Гц — 72. Если экран
/// и так рисуется (прокрутка, переход), украшение берёт ближайший кадр.
///
/// Только телефон: на ПК свои часы украшений (`DecorationClock`), в
/// проверках механизм выключен, пока проверка не включит его сама.
/// Выключатель — [kDecorationPacer].
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Выключатель. `false` — украшения снова просят кадр на каждое обновление.
const bool kDecorationPacer = true;

/// Выключатель покоя украшений (25.11.2026). `false` — без остановки, как
/// раньше.
const bool kDecorationRest = true;

/// Покой украшений на телефоне: рамки, обложки, значки, эмодзи-статусы и
/// дрейф обоев не двигаются вечно, если экран никто не трогает.
///
/// 🔴 ЗАМЕР (iPhone 14 Pro Max, 763, 25.11.2026): спокойный чат держал
/// видеочип на 70–90 % — украшение заказывает кадр, а кадр пересчитывает ВСЁ
/// стекло экрана (17 проходов). Касание — 60 кадров в секунду; через
/// [calmAfter] без касаний — 30; через [restAfter] — замирают и продолжают с
/// того же места при первом касании. Содержимое (стикеры, эмодзи сообщений,
/// «печатает», отправка) не затронуто. На ПК так же с 15.11 (там 10 с).
abstract final class DecorationActivity {
  static const Duration calmAfter = Duration(seconds: 3);
  static const Duration restAfter = Duration(seconds: 20);

  static bool _on = false;
  static bool _calm = false;
  static bool _touchedSinceArm = false;
  static Timer? _timer;
  static _ResumeObserver? _observer;

  /// Замерли.
  static final ValueNotifier<bool> resting = ValueNotifier<bool>(false);

  /// Реже: 30 кадров в секунду.
  static bool get calm => _on && _calm;

  static void _enable() {
    if (_on || !kDecorationRest) return;
    _on = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    WidgetsBinding.instance.addObserver(_observer = _ResumeObserver());
    _arm(calmAfter);
  }

  static void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent || e is PointerMoveEvent) touch();
  }

  /// Человек здесь.
  static void touch() {
    if (!_on) return;
    if (!_calm && !resting.value) {
      // Без перезаводки таймера на каждое движение пальца.
      _touchedSinceArm = true;
      return;
    }
    _calm = false;
    resting.value = false;
    _arm(calmAfter);
  }

  static void _arm(Duration d) {
    _touchedSinceArm = false;
    _timer?.cancel();
    _timer = Timer(d, _onTimer);
  }

  static void _onTimer() {
    if (_touchedSinceArm) {
      _arm(calmAfter);
    } else if (!_calm) {
      _calm = true;
      _arm(restAfter - calmAfter);
    } else {
      _timer = null;
      resting.value = true;
    }
  }

  static void _reset() {
    _timer?.cancel();
    _timer = null;
    if (_on) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
      final o = _observer;
      if (o != null) WidgetsBinding.instance.removeObserver(o);
    }
    _observer = null;
    _on = false;
    _calm = false;
    _touchedSinceArm = false;
    resting.value = false;
  }
}

/// Вернулись в приложение — украшения снова живые.
class _ResumeObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) DecorationActivity.touch();
  }
}

abstract final class DecorationPacer {
  static bool _enabled = false;
  static bool _listening = false;

  /// Период обновления экрана — самый короткий промежуток между кадрами,
  /// какой встречался (не короче 4 мс), и не больше 120 Гц-ного.
  ///
  /// 🔴 ТОЛЬКО ВНИЗ (замер 730 на Xiaomi). Раньше брался минимум за окно в
  /// 120 кадров — а в покое все кадры наши, через 1/60 с, и окно «видело»
  /// экран 60 Гц, пауза укорачивалась, кадры снова шли 120 к/с, окно снова
  /// видело 120 Гц… — качели, в среднем ~75 к/с. Брать меньший период
  /// безопасно: пауза 10,4 мс на экране 60 Гц всё равно короче обновления
  /// (кадр в каждое), на 90 Гц — тоже (каждое), а 144 Гц уменьшит период и
  /// даст свои 72. Значению `display.refreshRate` верить нельзя: Flutter
  /// узнаёт его при старте, а Xiaomi переключает 60↔120 на ходу.
  static int _periodUs = 8333;
  static int _lastFrameUs = 0;

  static bool get enabled => _enabled;

  /// Включить на телефоне (вход приложения). На ПК и в вебе — ничего.
  static void enableForMobile() {
    if (!kDecorationPacer || kIsWeb) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    _enable();
    DecorationActivity._enable();
  }

  static void _enable() {
    _enabled = true;
    if (_listening) return;
    _listening = true;
    // Постоянный обработчик кадра: кадров он не заказывает, только смотрит
    // на время тех, что и так идут, — одна разность за кадр.
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      final now = SchedulerBinding.instance.currentSystemFrameTimeStamp
          .inMicroseconds;
      final d = now - _lastFrameUs;
      _lastFrameUs = now;
      observeFrameGap(d);
    });
  }

  /// Промежуток между двумя кадрами (мкс). Период только уменьшается.
  @visibleForTesting
  static void observeFrameGap(int us) {
    if (us >= 4000 && us < _periodUs - 300) _periodUs = us;
  }

  /// Сколько обновлений экрана между шагами украшения: 120 Гц → 2 (60 к/с),
  /// 144 → 2 (72), 165 → 3 (55), 90 → 1 (45 было бы рвано), 60 → 1.
  @visibleForTesting
  static int stepFor(int periodUs) {
    final k = (16667 / periodUs + 0.3).floor();
    return k < 1 ? 1 : k;
  }

  /// Через сколько заказать кадр, если сейчас идёт кадр со временем
  /// [frameUs]: следующий кадр СЕТКИ — номер обновления, кратный [stepFor].
  ///
  /// 🔴 СЕТКА, а не «1/60 с после своего шага» (замер 731 на Xiaomi): эмодзи,
  /// заново запущенное посреди круга (появилось на экране), делало первый
  /// шаг на «нечётном» кадре и дальше жило со сдвигом в полкадра — две группы
  /// по 60 к/с вместе давали те же 120. По сетке все шагают в одних кадрах.
  /// Заказ — за 0,6 периода до нужного обновления: позже предыдущего, раньше
  /// нужного.
  @visibleForTesting
  static Duration delayFor({
    required int frameUs,
    required int periodUs,
    bool calm = false,
  }) {
    final k = stepFor(periodUs) * (calm ? 2 : 1);
    final i = (frameUs / periodUs).round();
    final j = (i ~/ k + 1) * k;
    final us = ((j - i) * periodUs - periodUs * 0.6).round();
    return Duration(microseconds: us < 0 ? 0 : us);
  }

  /// Пауза до заказа кадра — по сетке, от кадра, который идёт сейчас.
  static Duration gap({bool calm = false}) => delayFor(
    frameUs: SchedulerBinding.instance.currentSystemFrameTimeStamp
        .inMicroseconds,
    periodUs: _periodUs,
    calm: calm,
  );

  @visibleForTesting
  static int get debugPeriodUs => _periodUs;

  @visibleForTesting
  static void debugEnable({int periodUs = 8333, bool rest = false}) {
    _enabled = true;
    _periodUs = periodUs;
    if (rest) DecorationActivity._enable();
  }

  @visibleForTesting
  static void debugReset() {
    _enabled = false;
    _periodUs = 8333;
    DecorationActivity._reset();
  }
}

/// Тикер украшения: шаг — не чаще 60 раз в секунду (см. [DecorationPacer]).
/// Пока механизм выключен — обычный тикер, ровно как раньше.
///
/// 🔴 Один ОБЩИЙ таймер на все украшения, а не по таймеру на каждое: замер
/// профилировщиком на Xiaomi (729) — создание таймера в Dart будит поток
/// событий системным вызовом, и десяток рамок, каждая со своим таймером на
/// каждый шаг, съедали треть процессора в покое.
class PacedTicker extends Ticker {
  PacedTicker(
    TickerCallback onTick, {
    String? debugLabel,
    bool restsWhenIdle = false,
  }) : this._(onTick, _SleepShift(), restsWhenIdle, debugLabel);

  PacedTicker._(
    TickerCallback onTick,
    _SleepShift shift,
    this.restsWhenIdle,
    String? debugLabel,
  ) : _shift = shift,
      super((raw) => onTick(shift.apply(raw)), debugLabel: debugLabel);

  /// Украшение: без касаний реже, потом замирает ([DecorationActivity]).
  final bool restsWhenIdle;

  final _SleepShift _shift;
  bool _waiting = false;

  @override
  TickerFuture start() {
    _shift.reset();
    return super.start();
  }

  @override
  bool get scheduled => _waiting || super.scheduled;

  @override
  void scheduleTick({bool rescheduling = false}) {
    // Первый шаг после запуска — сразу; ждём только между шагами.
    if (!rescheduling || !DecorationPacer.enabled) {
      super.scheduleTick(rescheduling: rescheduling);
      return;
    }
    _waiting = true;
    if (restsWhenIdle && DecorationActivity.resting.value) {
      _shift.asleep = true;
      _RestingDecorations.add(this);
      return;
    }
    _PacerClock.wait(this);
  }

  void _wake() {
    _waiting = false;
    // Не `rescheduling`: заказ идёт из таймера, а не из шага тикера.
    if (shouldScheduleTick) super.scheduleTick();
  }

  @override
  void unscheduleTick() {
    if (_waiting) {
      _waiting = false;
      _PacerClock.cancel(this);
      _RestingDecorations.remove(this);
    }
    super.unscheduleTick();
  }

  @override
  void dispose() {
    if (_waiting) {
      _waiting = false;
      _PacerClock.cancel(this);
      _RestingDecorations.remove(this);
    }
    super.dispose();
  }
}

/// Время украшения без сна: проснулось — продолжает с той же позы, а не
/// прыгает туда, где «было бы» сейчас.
class _SleepShift {
  Duration _slept = Duration.zero;
  Duration _last = Duration.zero;
  bool asleep = false;

  Duration apply(Duration raw) {
    if (asleep) {
      asleep = false;
      final gap = raw - _last - const Duration(microseconds: 16667);
      if (gap > Duration.zero) _slept += gap;
    }
    _last = raw;
    return raw - _slept;
  }

  void reset() {
    _slept = Duration.zero;
    _last = Duration.zero;
    asleep = false;
  }
}

/// Замершие украшения: ни таймера, ни кадров — ждут касания.
abstract final class _RestingDecorations {
  static final Set<PacedTicker> _all = <PacedTicker>{};
  static bool _listening = false;

  static void add(PacedTicker t) {
    _all.add(t);
    if (_listening) return;
    _listening = true;
    DecorationActivity.resting.addListener(_onChange);
  }

  static void remove(PacedTicker t) => _all.remove(t);

  static void _onChange() {
    if (DecorationActivity.resting.value) return;
    final due = List<PacedTicker>.of(_all);
    _all.clear();
    for (final t in due) {
      t._wake();
    }
  }
}

/// Общий таймер ожидающих украшений.
abstract final class _PacerClock {
  static final Set<PacedTicker> _waiting = <PacedTicker>{};
  static Timer? _timer;
  static bool _calmTimer = false;

  static void wait(PacedTicker t) {
    _waiting.add(t);
    final calm = t.restsWhenIdle && DecorationActivity.calm;
    if (_timer == null) {
      _calmTimer = calm;
      _timer = Timer(DecorationPacer.gap(calm: calm), _fire);
    } else if (_calmTimer && !calm) {
      // Есть и содержимое на 60 — украшения идут с ним, отдельных кадров нет.
      _timer!.cancel();
      _calmTimer = false;
      _timer = Timer(DecorationPacer.gap(), _fire);
    }
  }

  static void cancel(PacedTicker t) {
    _waiting.remove(t);
    if (_waiting.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  static void _fire() {
    _timer = null;
    final due = List<PacedTicker>.of(_waiting);
    _waiting.clear();
    for (final t in due) {
      t._wake();
    }
  }
}

@visibleForTesting
int get debugPacerTimersPending => _PacerClock._timer == null ? 0 : 1;

/// Как `SingleTickerProviderStateMixin`, но тикер — [PacedTicker]. Немеет
/// под `TickerMode` так же (закрытый маршрут, списки без движения).
mixin PacedTickerProviderStateMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  PacedTicker? _pacedTicker;
  ValueListenable<TickerModeData>? _pacedTickerMode;

  /// Украшение, а не содержимое: без касаний замирает ([DecorationActivity]).
  bool get restsWhenIdle => false;

  @override
  Ticker createTicker(TickerCallback onTick) {
    assert(_pacedTicker == null, 'PacedTickerProviderStateMixin: один тикер');
    _pacedTicker = PacedTicker(
      onTick,
      debugLabel: kDebugMode ? 'paced by ${describeIdentity(this)}' : null,
      restsWhenIdle: restsWhenIdle,
    );
    _updatePacedTickerMode();
    _applyPacedTickerMode();
    return _pacedTicker!;
  }

  @override
  void activate() {
    super.activate();
    _updatePacedTickerMode();
    _applyPacedTickerMode();
  }

  @override
  void dispose() {
    _pacedTickerMode?.removeListener(_applyPacedTickerMode);
    _pacedTickerMode = null;
    super.dispose();
  }

  void _applyPacedTickerMode() {
    final t = _pacedTicker;
    final mode = _pacedTickerMode;
    if (t == null || mode == null) return;
    t.muted = !mode.value.enabled;
    t.forceFrames = mode.value.forceFrames;
  }

  void _updatePacedTickerMode() {
    final next = TickerMode.getValuesNotifier(context);
    if (identical(next, _pacedTickerMode)) return;
    _pacedTickerMode?.removeListener(_applyPacedTickerMode);
    next.addListener(_applyPacedTickerMode);
    _pacedTickerMode = next;
  }
}
