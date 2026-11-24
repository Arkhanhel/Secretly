// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Анимированный список (М3, docs/TZ_MOTION_TELEGRAM_PARITY_2026-11-20.md):
/// новая строка вырастает и проявляется, перемещённая (чат поднялся наверх)
/// и сдвинутые соседи переезжают на новое место, а не прыгают. Telegram iOS
/// (`ListView.swift`): вставка/сдвиг — 0,4 с фирменной кривой, появление
/// строки — 0,25 с.
///
/// Без `AnimatedList` и без переписывания списка: экран сообщает
/// [ListMotionController] порядок id при каждой сборке, а каждая строка,
/// обёрнутая в [ListMotionItem], сама узнаёт, вставлена ли она и на сколько
/// строк сдвинулась. Сдвиг — `FractionalTranslation` на долю своей высоты
/// (строки списка чатов одной высоты), то есть только перерисовка, без
/// перестройки соседей.
///
/// Не анимирует: первую загрузку, смену папки/поиска (много изменений сразу),
/// «Уменьшить движение», компьютер, выключенный [kTelegramMotion].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';

class ListMotionController {
  ListMotionController({this.maxChangesToAnimate = 6});

  /// Больше вставок+удалений за раз — это не «пришло сообщение», а смена
  /// папки или поиска: перестраиваем без анимации.
  final int maxChangesToAnimate;

  List<String> _ids = const <String>[];
  Map<String, int> _index = const <String, int>{};
  final Map<String, int> _delta = <String, int>{};
  final Set<String> _inserted = <String>{};
  int _generation = 0;
  final Stopwatch _clock = Stopwatch()..start();
  int _changedAtMicros = -1000000000;

  static bool get enabled =>
      kTelegramMotion &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  int get generation => _generation;

  /// Индекс строки по id в последнем порядке (для `findChildIndexCallback`).
  int? indexOf(String id) {
    return _index[id];
  }

  /// Сообщить порядок строк. Зовётся в `build` экрана; одинаковый порядок —
  /// ничего не делает.
  void update(List<String> ids) {
    if (listEquals(ids, _ids)) return;
    final old = _ids;
    _ids = List<String>.unmodifiable(ids);
    _index = <String, int>{for (var i = 0; i < ids.length; i++) ids[i]: i};
    _delta.clear();
    _inserted.clear();
    _generation++;
    if (!enabled || old.isEmpty) return;
    final oldIndex = <String, int>{
      for (var i = 0; i < old.length; i++) old[i]: i,
    };
    final now = ids.toSet();
    var removed = 0;
    for (final id in old) {
      if (!now.contains(id)) removed++;
    }
    var inserted = 0;
    for (var i = 0; i < ids.length; i++) {
      final o = oldIndex[ids[i]];
      if (o == null) {
        inserted++;
        _inserted.add(ids[i]);
      } else if (o != i) {
        _delta[ids[i]] = (o - i).clamp(-12, 12);
      }
    }
    if (inserted + removed > maxChangesToAnimate) {
      _delta.clear();
      _inserted.clear();
      return;
    }
    _changedAtMicros = _clock.elapsedMicroseconds;
  }

  /// Изменение свежее — строки, построенные сейчас, ещё должны его показать.
  bool get _fresh => _clock.elapsedMicroseconds - _changedAtMicros < 350000;

  bool _isInserted(String id) => _fresh && _inserted.contains(id);
  int _moveOf(String id) => _fresh ? (_delta[id] ?? 0) : 0;
}

class ListMotionItem extends StatefulWidget {
  const ListMotionItem({
    super.key,
    required this.controller,
    required this.id,
    required this.child,
  });

  final ListMotionController controller;
  final String id;
  final Widget child;

  @override
  State<ListMotionItem> createState() => _ListMotionItemState();
}

class _ListMotionItemState extends State<ListMotionItem>
    with TickerProviderStateMixin {
  // Создаются сразу: ленивые `late` впервые тронул бы dispose (на
  // компьютере build их не трогает), а тикер в dispose создавать нельзя.
  late final AnimationController _move;
  late final AnimationController _appear;
  late final Listenable _both;
  int _seen = -1;
  double _fromRows = 0;

  bool _first = true;

  @override
  void initState() {
    super.initState();
    _move = AnimationController(
      vsync: this,
      duration: MotionDurations.list,
      value: 1,
    );
    _appear = AnimationController(
      vsync: this,
      duration: MotionDurations.list,
      value: 1,
    );
    _both = Listenable.merge([_move, _appear]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Первая сверка — здесь, а не в initState: ей нужен MediaQuery.
    if (_first) {
      _first = false;
      _sync();
    }
  }

  @override
  void didUpdateWidget(ListMotionItem old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final c = widget.controller;
    if (_seen == c.generation) return;
    _seen = c.generation;
    if (!ListMotionController.enabled) return;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) return;
    if (c._isInserted(widget.id)) {
      _appear.forward(from: 0);
      return;
    }
    final d = c._moveOf(widget.id);
    if (d != 0) {
      // Строка была на d строк ниже (d > 0) или выше — начинаем оттуда.
      // Если она уже ехала, продолжаем с текущего места, без рывка.
      final current = _fromRows * (1 - Motion.standard.transform(_move.value));
      _fromRows = d + current;
      _move.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _appear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ListMotionController.enabled) return widget.child;
    // 🔴 Дерево одной формы всегда — иначе строка (и её смахивание,
    // нажатие) пересоздавалась бы в начале и в конце анимации.
    return AnimatedBuilder(
      animation: _both,
      child: widget.child,
      builder: (context, child) {
        final a = _appear.value;
        final grow = Motion.standard.transform(a);
        final fade = Motion.fade.transform((a / 0.625).clamp(0.0, 1.0));
        final m = _move.value;
        final dy = m >= 1 ? 0.0 : _fromRows * (1 - Motion.standard.transform(m));
        return ClipRect(
          clipBehavior: a < 1 ? Clip.hardEdge : Clip.none,
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: grow,
            child: Opacity(
              opacity: fade,
              child: FractionalTranslation(
                translation: Offset(0, dy),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
