// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Журнал нагрева (24.11.2026, владелец: «стекло включено, но измеряй очень
/// детально, чтобы телефоны не перегревались после длительной работы»).
///
/// Только в проверочных сборках (`--dart-define=SECRETLY_FRAME_STATS=true`,
/// как замер кадров): в магазинных сборках кода нет совсем — константа
/// времени сборки. Раз в 30 секунд — строка CSV в файл приложения:
/// температурное состояние ОС, заряд и зарядка, загрузка процессора
/// приложением (по приросту процессорного времени), на Android — температура
/// батареи в °C, уровень стекла, включено ли стекло, кадры за отрезок
/// (сколько, растр p90, сколько вышли за бюджет 60 Гц), активно ли
/// приложение. Файл выгружается из Настроек («Журнал нагрева»).
///
/// Ничего личного: ни идентификаторов, ни текста, ни адресов — только
/// числа о самом телефоне.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../ui/glass/glass_quality.dart';
import '../ui/glass/secretly_glass_plate.dart';
import '../ui/liquid_glass_flags.dart';
import '../ui/motion/frame_stats.dart';

/// Журнал включён в этой сборке.
const bool kHeatLog = kFrameStats;

abstract final class HeatLog {
  static const MethodChannel _probe = MethodChannel('secretly/heat_probe');
  static const Duration period = Duration(seconds: 30);
  static const int _maxBytes = 4 * 1024 * 1024;
  static const String header =
      'time,uptime_min,life,thermal,battery,charging,low_power,battery_temp_c,'
      'cpu_pct,brightness,glass_on,glass_engine,glass_quality,frames,'
      'raster_p90_ms,over_16ms';

  static bool _started = false;
  static Timer? _timer;
  static File? _file;
  static final Stopwatch _uptime = Stopwatch();
  static int? _lastCpuMs;
  static int? _lastWallMs;
  static final List<int> _rasterUs = <int>[];
  static int _frames = 0;

  /// Подключить журнал. Ничего не делает вне проверочной сборки и вне
  /// телефонов.
  static void start() {
    if (!kHeatLog || _started) return;
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    _started = true;
    _uptime.start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    unawaited(_sample());
    _timer = Timer.periodic(period, (_) => unawaited(_sample()));
  }

  /// Файл журнала (для выгрузки). `null` — журнала нет.
  static Future<File?> logFile() async {
    if (!kHeatLog) return null;
    final f = await _ensureFile();
    return (f != null && f.existsSync()) ? f : null;
  }

  static void _onTimings(List<FrameTiming> timings) {
    _frames += timings.length;
    for (final t in timings) {
      _rasterUs.add(t.rasterDuration.inMicroseconds);
    }
    // Память ограничена: при 120 Гц за 30 с — 3600 кадров.
    if (_rasterUs.length > 8000) _rasterUs.removeRange(0, 4000);
  }

  static Future<File?> _ensureFile() async {
    if (_file != null) return _file;
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/heat_log.csv');
      return _file;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _sample() async {
    Map<Object?, Object?> s = const {};
    try {
      s = await _probe.invokeMethod<Map<Object?, Object?>>('sample') ?? const {};
    } catch (_) {
      // Нет пробы (старая нативная часть) — пишем то, что знает Dart.
    }
    final now = DateTime.now();
    final wall = now.millisecondsSinceEpoch;
    final cpu = (s['cpuMs'] as num?)?.toInt();
    String cpuPct = '';
    if (cpu != null && _lastCpuMs != null && _lastWallMs != null) {
      final dw = wall - _lastWallMs!;
      if (dw > 0) cpuPct = ((cpu - _lastCpuMs!) * 100 / dw).toStringAsFixed(1);
    }
    _lastCpuMs = cpu;
    _lastWallMs = wall;
    final row = heatLogRow(
      time: now,
      uptimeMin: _uptime.elapsed.inSeconds / 60,
      life: WidgetsBinding.instance.lifecycleState?.name ?? 'unknown',
      probe: s,
      cpuPct: cpuPct,
      glassOn: GlassPrefs.enabled.value,
      glassEngine: secretlyGlassEngineActive,
      glassQuality: GlassQualityController.quality.value.name,
      frames: _frames,
      rasterUs: List<int>.of(_rasterUs),
    );
    _frames = 0;
    _rasterUs.clear();
    debugPrint('[Heat] $row');
    final f = await _ensureFile();
    if (f == null) return;
    try {
      if (f.existsSync() && f.lengthSync() > _maxBytes) {
        final old = File('${f.path}.1');
        if (old.existsSync()) old.deleteSync();
        f.renameSync(old.path);
      }
      if (!f.existsSync()) f.writeAsStringSync('$header\n');
      f.writeAsStringSync('$row\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // Журнал — подсказка, не повод ронять приложение.
    }
  }

  @visibleForTesting
  static void debugStop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}

/// Одна строка CSV — отдельно, чтобы её можно было проверить тестом.
@visibleForTesting
String heatLogRow({
  required DateTime time,
  required double uptimeMin,
  required String life,
  required Map<Object?, Object?> probe,
  required String cpuPct,
  required bool glassOn,
  required bool glassEngine,
  required String glassQuality,
  required int frames,
  required List<int> rasterUs,
}) {
  String n(Object? v, [int digits = 2]) =>
      v is num ? v.toStringAsFixed(digits) : '';
  String b(Object? v) => v is bool ? (v ? '1' : '0') : '';
  String p90 = '';
  var over = 0;
  if (rasterUs.isNotEmpty) {
    final xs = List<int>.of(rasterUs)..sort();
    p90 = (xs[((xs.length - 1) * 0.9).round()] / 1000).toStringAsFixed(1);
    over = xs.where((x) => x > 16700).length;
  }
  final thermal = probe['thermal'];
  return [
    time.toIso8601String(),
    uptimeMin.toStringAsFixed(1),
    life,
    thermal is num ? thermal.toInt().toString() : '',
    n(probe['battery']),
    b(probe['charging']),
    b(probe['lowPower']),
    n(probe['batteryTempC'], 1),
    cpuPct,
    n(probe['brightness']),
    glassOn ? '1' : '0',
    glassEngine ? '1' : '0',
    glassQuality,
    '$frames',
    p90,
    '$over',
  ].join(',');
}
