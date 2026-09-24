// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ширина одного столбика волны, в точках.
///
/// 🔴 ТОНКИЕ СТОЛБИКИ, КАК В TELEGRAM (24.09.2026, указание владельца).
///
/// Было четырнадцать столбиков на всю ширину пузыря: каждый растягивался на
/// свою долю и выходил толстым бруском в десяток точек. Волну так не читают —
/// привычный вид у мессенджеров другой: много тонких скруглённых штрихов, и
/// чем шире место, тем их больше. Две точки с зазором в 1,6 — пропорция
/// телефона (2,1 и 1,3), чуть просторнее: на компьютере волна длиннее.
const double kVoiceBarWidth = 2.0;

/// Зазор между столбиками волны.
const double kVoiceBarGap = 1.6;

/// Сколько столбиков помещается в ширину [width].
///
/// Число — от ширины, а не постоянное: у короткого пузыря штрихов меньше, у
/// длинного больше, а толщина остаётся той же. Постоянное число и было
/// причиной толстых брусков.
int voiceBarCount(double width) {
  if (!width.isFinite || width <= 0) return 1;
  return math.max(
    1,
    ((width + kVoiceBarGap) / (kVoiceBarWidth + kVoiceBarGap)).floor(),
  );
}

/// Наименьшая ширина голосового пузыря по длине записи.
///
/// Как в Telegram: длинное голосовое — длинная волна. За первую минуту пузырь
/// растёт с 230 до 320 точек и дальше не растёт: волна часового сообщения во
/// всю переписку ничего нового не сказала бы.
double voiceBubbleMinWidth(Duration duration) {
  final seconds = duration.inMilliseconds / 1000.0;
  return (230 + 1.5 * seconds).clamp(230.0, 320.0);
}

/// Высоты [count] столбиков, доли 0..1.
///
/// Огибающая приходит от записи произвольной длины со значениями 0..100.
/// Длинная сводится к числу столбиков ПИКОМ в каждом отрезке (усреднение
/// сглаживает волну в невыразительную полку), короткая растягивается
/// линейной интерполяцией (повтор давал бы ступеньки).
///
/// Высота нормируется по самому громкому месту записи — так делает Telegram:
/// тихо надиктованное голосовое иначе было бы плоской полоской. Но не сильнее
/// чем вдвое с половиной: запись почти без звука не должна притворяться
/// громкой.
///
/// Пола в 0,1 нет у тишины как таковой: нулевой штрих выглядит дырой в волне,
/// а тишина посреди записи — это тишина, а не обрыв.
///
/// Без огибающей (старые голосовые, до того как её стали передавать) — ровная
/// невысокая дуга. Она честно говорит «данных о громкости нет» и не
/// притворяется записью.
List<double> voiceWaveformHeights(List<int>? raw, int count) {
  if (count <= 0) return const <double>[];
  final src = raw ?? const <int>[];
  if (src.isEmpty) {
    if (count == 1) return const <double>[0.3];
    return List<double>.generate(
      count,
      (i) => 0.22 + 0.18 * (1 - (2 * i / (count - 1) - 1).abs()),
    );
  }
  final vals = <double>[for (final v in src) v.clamp(0, 100).toDouble()];
  final peak = math.max(vals.reduce(math.max), 40.0);
  double at(int i) {
    if (vals.length >= count) {
      final from = (vals.length * i) ~/ count;
      var to = (vals.length * (i + 1)) ~/ count;
      if (to <= from) to = from + 1;
      var m = 0.0;
      for (var j = from; j < to && j < vals.length; j++) {
        if (vals[j] > m) m = vals[j];
      }
      return m;
    }
    if (count == 1 || vals.length == 1) return vals.first;
    final t = i * (vals.length - 1) / (count - 1);
    final lo = t.floor();
    final hi = math.min(lo + 1, vals.length - 1);
    return vals[lo] + (vals[hi] - vals[lo]) * (t - lo);
  }

  return List<double>.generate(
    count,
    (i) => (0.1 + 0.9 * (at(i) / peak)).clamp(0.1, 1.0),
  );
}

/// Волна голосового: тонкие штрихи, прослушанная часть — цветом [played].
///
/// Граница прослушанного проходит ТОЧНО по доле [progress], в том числе
/// посреди штриха, а не по целым столбикам: так волна движется плавно, а не
/// скачками по три с половиной точки.
///
/// [onSeek] — перемотка щелчком и протяжкой по волне; `null` — волна только
/// рисуется.
///
/// 🔴 Без [LayoutBuilder]: голосовой пузырь обёрнут в [IntrinsicWidth], а
/// строитель не умеет называть свою естественную ширину и роняет разметку.
/// Ширину для перемотки берём у отрисованного прямоугольника в миг нажатия.
class DesktopVoiceWaveform extends StatelessWidget {
  const DesktopVoiceWaveform({
    super.key,
    required this.progress,
    required this.played,
    required this.unplayed,
    required this.semanticsLabel,
    this.waveform,
    this.onSeek,
    this.height = 22,
  });

  /// Доля проигранного 0..1; выход за пределы обрезается.
  final double progress;
  final Color played;
  final Color unplayed;

  /// Что это за полоса — для экранного диктора.
  final String semanticsLabel;

  /// Огибающая громкости 0..100 произвольной длины; `null` — ровная дуга.
  final List<int>? waveform;

  final ValueChanged<double>? onSeek;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final wave = SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _VoiceWavePainter(
          progress: p,
          waveform: waveform,
          played: played,
          unplayed: unplayed,
        ),
      ),
    );
    return Semantics(
      container: true,
      label: semanticsLabel,
      value: '${(p * 100).round()}%',
      child: ExcludeSemantics(
        child: _SeekSurface(onSeek: onSeek, child: wave),
      ),
    );
  }
}

class _VoiceWavePainter extends CustomPainter {
  _VoiceWavePainter({
    required this.progress,
    required this.waveform,
    required this.played,
    required this.unplayed,
  });

  final double progress;
  final List<int>? waveform;
  final Color played;
  final Color unplayed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final n = voiceBarCount(size.width);
    final heights = voiceWaveformHeights(waveform, n);
    final bars = <RRect>[];
    for (var i = 0; i < n; i++) {
      final h = math.max(2.0, heights[i] * size.height);
      final x = i * (kVoiceBarWidth + kVoiceBarGap);
      final top = (size.height - h) / 2;
      bars.add(
        RRect.fromLTRBR(
          x,
          top,
          x + kVoiceBarWidth,
          top + h,
          const Radius.circular(kVoiceBarWidth / 2),
        ),
      );
    }
    final rest = Paint()..color = unplayed;
    for (final b in bars) {
      canvas.drawRRect(b, rest);
    }
    if (progress <= 0) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    final done = Paint()..color = played;
    for (final b in bars) {
      canvas.drawRRect(b, done);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VoiceWavePainter old) =>
      progress != old.progress ||
      played != old.played ||
      unplayed != old.unplayed ||
      !identical(waveform, old.waveform);
}

/// Полоса песни, у которой нет записанной волны: тонкая дорожка с бегунком.
///
/// Так Telegram показывает музыку: у голосового — волна, у песни — линия.
/// Волна у песни без данных о громкости была бы выдумкой, а линия честно
/// показывает то единственное, что известно, — где мы сейчас.
class DesktopAudioSeekLine extends StatelessWidget {
  const DesktopAudioSeekLine({
    super.key,
    required this.progress,
    required this.played,
    required this.unplayed,
    required this.semanticsLabel,
    this.onSeek,
    this.height = 14,
  });

  final double progress;
  final Color played;
  final Color unplayed;
  final String semanticsLabel;
  final ValueChanged<double>? onSeek;

  /// Высота области нажатия; сама дорожка — три точки посередине.
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final line = SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _SeekLinePainter(
          progress: p,
          played: played,
          unplayed: unplayed,
        ),
      ),
    );
    return Semantics(
      container: true,
      label: semanticsLabel,
      value: '${(p * 100).round()}%',
      child: ExcludeSemantics(
        child: _SeekSurface(onSeek: onSeek, child: line),
      ),
    );
  }
}

class _SeekLinePainter extends CustomPainter {
  _SeekLinePainter({
    required this.progress,
    required this.played,
    required this.unplayed,
  });

  final double progress;
  final Color played;
  final Color unplayed;

  static const double _track = 3;
  static const double _knob = 4.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cy = size.height / 2;
    final track = RRect.fromLTRBR(
      0,
      cy - _track / 2,
      size.width,
      cy + _track / 2,
      const Radius.circular(_track / 2),
    );
    canvas.drawRRect(track, Paint()..color = unplayed);
    final x = (size.width * progress).clamp(0.0, size.width);
    if (x > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, x, size.height));
      canvas.drawRRect(track, Paint()..color = played);
      canvas.restore();
    }
    final kx = x.clamp(_knob, math.max(_knob, size.width - _knob)).toDouble();
    canvas.drawCircle(Offset(kx, cy), _knob, Paint()..color = played);
  }

  @override
  bool shouldRepaint(_SeekLinePainter old) =>
      progress != old.progress ||
      played != old.played ||
      unplayed != old.unplayed;
}

/// Щелчок и протяжка по полосе — перемотка в долю 0..1.
///
/// Ширину берёт у себя в миг нажатия ([BuildContext.size]): строитель
/// разметки здесь не годится, см. [DesktopVoiceWaveform].
class _SeekSurface extends StatelessWidget {
  const _SeekSurface({required this.onSeek, required this.child});

  final ValueChanged<double>? onSeek;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final seek = onSeek;
    if (seek == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Builder(
        builder: (ctx) {
          void at(Offset local) {
            final w = ctx.size?.width ?? 0;
            if (w <= 0) return;
            seek((local.dx / w).clamp(0.0, 1.0));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => at(d.localPosition),
            onHorizontalDragUpdate: (d) => at(d.localPosition),
            child: child,
          );
        },
      ),
    );
  }
}
