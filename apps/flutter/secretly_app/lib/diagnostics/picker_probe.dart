// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Замер открытия галереи по скрепке (25.11.2026) — только в проверочных
/// сборках (`SECRETLY_FRAME_STATS=true`), в обычных не делает ничего.
///
/// Строка на открытие: когда пришёл список, когда загрузились первые
/// миниатюры и какими были кадры первых четырёх секунд. Файл
/// `picker_probe.csv` в Application Support.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

import '../ui/motion/frame_stats.dart' show kFrameStats;

abstract final class PickerProbe {
  static const String header =
      'time,from_memory,list_ms,thumbs_ms,frames,over_16ms,over_33ms,'
      'worst_build_ms,worst_raster_ms,worst_span_ms';

  static final Stopwatch _clock = Stopwatch();
  static final Map<String, int> _marks = <String, int>{};
  static final List<FrameTiming> _frames = <FrameTiming>[];
  static bool _open = false;
  static bool _fromMemory = false;

  static void opened({required bool fromMemory}) {
    if (!kFrameStats || _open) return;
    _open = true;
    _fromMemory = fromMemory;
    _marks.clear();
    _frames.clear();
    _clock
      ..reset()
      ..start();
    SchedulerBinding.instance.addTimingsCallback(_onFrames);
    Timer(const Duration(seconds: 4), _finish);
  }

  static void mark(String name) {
    if (!_open) return;
    _marks.putIfAbsent(name, () => _clock.elapsedMilliseconds);
  }

  static void _onFrames(List<FrameTiming> t) => _frames.addAll(t);

  static void _finish() {
    SchedulerBinding.instance.removeTimingsCallback(_onFrames);
    _open = false;
    double ms(Duration d) => d.inMicroseconds / 1000;
    double worst(double Function(FrameTiming) of) =>
        _frames.fold(0, (m, f) => of(f) > m ? of(f) : m);
    int over(double limit) =>
        _frames.where((f) => ms(f.totalSpan) > limit).length;
    final row = [
      DateTime.now().toIso8601String().substring(0, 19),
      _fromMemory ? 1 : 0,
      _marks['list'] ?? '',
      _marks['thumbs'] ?? '',
      _frames.length,
      over(16.7),
      over(33.4),
      worst((f) => ms(f.buildDuration)).toStringAsFixed(1),
      worst((f) => ms(f.rasterDuration)).toStringAsFixed(1),
      worst((f) => ms(f.totalSpan)).toStringAsFixed(1),
    ].join(',');
    debugPrint('[Picker] $row');
    unawaited(_write(row));
  }

  static Future<void> _write(String row) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/picker_probe.csv');
      if (!await f.exists()) await f.writeAsString('$header\n');
      await f.writeAsString('$row\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // Замер не должен мешать.
    }
  }
}
