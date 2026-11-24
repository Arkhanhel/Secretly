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
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Выключатель. `false` — украшения снова просят кадр на каждое обновление.
const bool kDecorationPacer = true;

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
  static Duration delayFor({required int frameUs, required int periodUs}) {
    final k = stepFor(periodUs);
    final i = (frameUs / periodUs).round();
    final j = (i ~/ k + 1) * k;
    final us = ((j - i) * periodUs - periodUs * 0.6).round();
    return Duration(microseconds: us < 0 ? 0 : us);
  }

  /// Пауза до заказа кадра — по сетке, от кадра, который идёт сейчас.
  static Duration get gap => delayFor(
    frameUs: SchedulerBinding.instance.currentSystemFrameTimeStamp
        .inMicroseconds,
    periodUs: _periodUs,
  );

  @visibleForTesting
  static int get debugPeriodUs => _periodUs;

  @visibleForTesting
  static void debugEnable({int periodUs = 8333}) {
    _enabled = true;
    _periodUs = periodUs;
  }

  @visibleForTesting
  static void debugReset() {
    _enabled = false;
    _periodUs = 8333;
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
  PacedTicker(super.onTick, {super.debugLabel});

  bool _waiting = false;

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
    }
    super.unscheduleTick();
  }

  @override
  void dispose() {
    if (_waiting) {
      _waiting = false;
      _PacerClock.cancel(this);
    }
    super.dispose();
  }
}

/// Общий таймер ожидающих украшений.
abstract final class _PacerClock {
  static final Set<PacedTicker> _waiting = <PacedTicker>{};
  static Timer? _timer;

  static void wait(PacedTicker t) {
    _waiting.add(t);
    _timer ??= Timer(DecorationPacer.gap, _fire);
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

  @override
  Ticker createTicker(TickerCallback onTick) {
    assert(_pacedTicker == null, 'PacedTickerProviderStateMixin: один тикер');
    _pacedTicker = PacedTicker(
      onTick,
      debugLabel: kDebugMode ? 'paced by ${describeIdentity(this)}' : null,
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
