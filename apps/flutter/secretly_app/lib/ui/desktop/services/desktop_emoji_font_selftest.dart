// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../design/colors.dart';
import '../design/emoji_font.dart';
import '../design/material_theme.dart';
import '../design/typography.dart';
import 'desktop_emoji_font_loader.dart';

/// Самотест шрифта эмодзи Windows: `Secretly --emoji-font-selftest`
/// (30.09.2026, Э1).
///
/// Сборка Windows проверяется в CI, где глазами не посмотреть. А «шрифт
/// загрузился» ещё не значит «эмодзи цветные, как на телефоне»: DirectWrite
/// может принять файл и не нарисовать его картинки. Поэтому программа рисует
/// четыре эмодзи по-настоящему — тем же движком, с той же темой и теми же
/// стилями, что окно, — снимает картинку и считает пиксели:
///   * строки «тема» (как плитка сетки и фишка реакции) и «кусок DType» (как
///     текст пузыря) обязаны совпасть с эталоном «Noto напрямую»;
///   * эталон Noto обязан ОТЛИЧАТЬСЯ от «как было» (системный шрифт) — иначе
///     совпадение ничего бы не доказывало;
///   * эмодзи обязаны быть цветными и не пустыми: не квадрат-заглушка и не
///     одноцветный контур.
///
/// Итог — код выхода (0 — всё так), журнал
/// `%TEMP%/secretly_emoji_font_selftest.txt` и снимок
/// `%TEMP%/secretly_emoji_font_selftest.png`: CI печатает журнал и кладёт
/// снимок в архив сборки.
const String kEmojiFontSelftestArg = '--emoji-font-selftest';

/// Образцы: обычный смайлик, тон кожи (последовательность из двух знаков),
/// знак Unicode 14 (в Segoe Windows 10 его нет) и флаг-последовательность
/// через ZWJ.
const List<String> kEmojiSelftestSamples = <String>['😀', '👍🏽', '🫡', '🏳️‍🌈'];

/// Строки листа самотеста — сверху вниз.
enum EmojiSelftestRow {
  /// Текст без своего семейства: запасной шрифт — из темы.
  theme('theme'),

  /// Вложенный кусок со стилем `DType` — так устроен пузырь сообщения.
  dtypeSpan('DType span'),

  /// Эталон: только наш Noto, без запасных.
  noto('Noto reference'),

  /// Эталон «как было»: незнакомое семейство — рисует система (Segoe).
  system('system (before)');

  const EmojiSelftestRow(this.label);
  final String label;
}

/// Геометрия листа: подписи слева, дальше клетки по [cell] точек.
abstract final class EmojiSelftestGeometry {
  static const double labelWidth = 180;
  static const double cell = 96;
  static const double glyph = 64;

  /// Серый фон: цветной знак на нём виден по насыщенности, а заглушка или
  /// контур — нет.
  static const Color background = Color(0xFF808080);

  static int get width =>
      (labelWidth + cell * kEmojiSelftestSamples.length).round();
  static int get height => (cell * EmojiSelftestRow.values.length).round();

  /// Левый верхний угол клетки в пикселях снимка (масштаб 1).
  static (int, int) cellOrigin(EmojiSelftestRow row, int sample) => (
        (labelWidth + cell * sample).round(),
        (cell * row.index).round(),
      );
}

/// Лист самотеста. Внутри `Material` — как главное окно.
class DesktopEmojiSelftestSheet extends StatelessWidget {
  const DesktopEmojiSelftestSheet({super.key});

  static const TextStyle _glyphBase = TextStyle(
    fontSize: EmojiSelftestGeometry.glyph,
    height: 1.0,
    letterSpacing: 0,
    fontWeight: FontWeight.w400,
  );

  Widget _sample(EmojiSelftestRow row, String emoji) {
    switch (row) {
      case EmojiSelftestRow.theme:
        return Text(emoji, style: _glyphBase);
      case EmojiSelftestRow.dtypeSpan:
        return Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: emoji,
                style: DType.body.copyWith(
                  fontSize: EmojiSelftestGeometry.glyph,
                  height: 1.0,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        );
      case EmojiSelftestRow.noto:
        return Text(
          emoji,
          style: _glyphBase.copyWith(
            fontFamily: kDesktopEmojiFontFamily,
            fontFamilyFallback: const <String>[],
          ),
        );
      case EmojiSelftestRow.system:
        return Text(
          emoji,
          style: _glyphBase.copyWith(
            fontFamily: 'SecretlySelftestNoSuchFamily',
            fontFamilyFallback: const <String>[],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    const g = EmojiSelftestGeometry.cell;
    // Размер текста системы здесь ни при чём: клетки фиксированные.
    return MediaQuery.withNoTextScaling(
      child: ColoredBox(
        color: EmojiSelftestGeometry.background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final row in EmojiSelftestRow.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: EmojiSelftestGeometry.labelWidth,
                    height: g,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          row.label,
                          style: DType.label.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  for (final emoji in kEmojiSelftestSamples)
                    SizedBox(
                      width: g,
                      height: g,
                      child: Center(child: _sample(row, emoji)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Окно самотеста: та же тема и тот же стиль по умолчанию, что у ПК.
class DesktopEmojiSelftestApp extends StatelessWidget {
  const DesktopEmojiSelftestApp({super.key, required this.boundaryKey});

  final GlobalKey boundaryKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Secretly emoji selftest',
      theme: desktopMaterialTheme(kDColorsDark, dark: true),
      builder: (ctx, child) =>
          desktopEmojiTextFallback(child ?? const SizedBox.shrink()),
      home: Material(
        color: kDColorsDark.bg,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundaryKey,
            child: const DesktopEmojiSelftestSheet(),
          ),
        ),
      ),
    );
  }
}

/// Что видно в одной клетке снимка.
@immutable
class EmojiCellStats {
  const EmojiCellStats({
    required this.ink,
    required this.inkFraction,
    required this.colourfulFraction,
    required this.meanSaturation,
    required this.hueBuckets,
    required this.box,
  });

  /// Пикселей, заметно отличных от фона.
  final int ink;
  final double inkFraction;

  /// Доля «чернил» с насыщенностью от 0,35 — у цветного знака это бо́льшая
  /// часть, у контура и квадрата-заглушки — ноль.
  final double colourfulFraction;
  final double meanSaturation;

  /// Сколько тонов (секторов по 30°) заметно представлено.
  final int hueBuckets;

  /// Рамка «чернил» (x0, y0, x1, y1) внутри клетки, `null` — пусто.
  final (int, int, int, int)? box;

  @override
  String toString() {
    final b = box;
    final boxText = b == null ? '-' : '${b.$3 - b.$1 + 1}x${b.$4 - b.$2 + 1}';
    return 'ink=${(inkFraction * 100).toStringAsFixed(1)}% '
        'colour=${(colourfulFraction * 100).toStringAsFixed(1)}% '
        'sat=${meanSaturation.toStringAsFixed(2)} hues=$hueBuckets box=$boxText';
  }
}

const int _kInkThreshold = 40;

bool _isInk(Uint8List rgba, int i, int bg) =>
    (rgba[i] - bg).abs() > _kInkThreshold ||
    (rgba[i + 1] - bg).abs() > _kInkThreshold ||
    (rgba[i + 2] - bg).abs() > _kInkThreshold;

/// Разбор клетки [size]×[size] с левым верхним углом [origin] в снимке RGBA
/// шириной [width] на однотонном сером фоне яркости [bg].
@visibleForTesting
EmojiCellStats emojiCellStats(
  Uint8List rgba,
  int width,
  (int, int) origin,
  int size, {
  int bg = 0x80,
}) {
  var ink = 0;
  var colourful = 0;
  var satSum = 0.0;
  final hues = List<int>.filled(12, 0);
  var x0 = size, y0 = size, x1 = -1, y1 = -1;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final i = ((origin.$2 + y) * width + origin.$1 + x) * 4;
      if (!_isInk(rgba, i, bg)) continue;
      ink++;
      x0 = math.min(x0, x);
      y0 = math.min(y0, y);
      x1 = math.max(x1, x);
      y1 = math.max(y1, y);
      final r = rgba[i] / 255.0, g = rgba[i + 1] / 255.0, b = rgba[i + 2] / 255.0;
      final maxC = math.max(r, math.max(g, b));
      final minC = math.min(r, math.min(g, b));
      final sat = maxC <= 0 ? 0.0 : (maxC - minC) / maxC;
      satSum += sat;
      if (sat >= 0.35 && maxC >= 0.15) {
        colourful++;
        final d = maxC - minC;
        double h;
        if (maxC == r) {
          h = 60 * (((g - b) / d) % 6);
        } else if (maxC == g) {
          h = 60 * (((b - r) / d) + 2);
        } else {
          h = 60 * (((r - g) / d) + 4);
        }
        if (h < 0) h += 360;
        hues[(h ~/ 30) % 12]++;
      }
    }
  }
  final area = size * size;
  final bucketFloor = math.max(1, (colourful * 0.03).round());
  return EmojiCellStats(
    ink: ink,
    inkFraction: ink / area,
    colourfulFraction: ink == 0 ? 0 : colourful / ink,
    meanSaturation: ink == 0 ? 0 : satSum / ink,
    hueBuckets: hues.where((n) => n >= bucketFloor).length,
    box: x1 < 0 ? null : (x0, y0, x1, y1),
  );
}

/// Насколько две клетки непохожи: средняя разница каналов (0…255) по рамке
/// «чернил», совмещённой по левому верхнему углу. Рамки разного размера
/// (больше чем на 2 пикселя) — это разные картинки: 255.
@visibleForTesting
double emojiCellDiff(
  Uint8List rgba,
  int width,
  (int, int) a,
  (int, int) b,
  int size, {
  int bg = 0x80,
}) {
  final sa = emojiCellStats(rgba, width, a, size, bg: bg);
  final sb = emojiCellStats(rgba, width, b, size, bg: bg);
  final ba = sa.box, bb = sb.box;
  if (ba == null && bb == null) return 0;
  if (ba == null || bb == null) return 255;
  final wa = ba.$3 - ba.$1, ha = ba.$4 - ba.$2;
  final wb = bb.$3 - bb.$1, hb = bb.$4 - bb.$2;
  if ((wa - wb).abs() > 2 || (ha - hb).abs() > 2) return 255;
  final w = math.max(wa, wb) + 1, h = math.max(ha, hb) + 1;
  var sum = 0;
  var n = 0;
  int px(int ox, int oy, int x, int y, int c) {
    if (x < 0 || y < 0 || x >= size || y >= size) return bg;
    return rgba[((oy + y) * width + ox + x) * 4 + c];
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      for (var c = 0; c < 3; c++) {
        sum += (px(a.$1, a.$2, ba.$1 + x, ba.$2 + y, c) -
                px(b.$1, b.$2, bb.$1 + x, bb.$2 + y, c))
            .abs();
        n++;
      }
    }
  }
  return n == 0 ? 0 : sum / n;
}

/// Пороги решения. Совпадение с эталоном ждём почти точное (тот же шрифт,
/// тот же размер), а «как было» — заметно другое.
const double _kSameAsNoto = 12;
const double _kDifferentFromSystem = 12;
const double _kMinInk = 0.10;
const double _kMinColourful = 0.30;

/// Рамка знака в 64 точки — от 0,45 до 1,35 кегля. Картинка, нарисованная
/// в родном размере файла (109 точек) или сжатая в точку, в неё не влезет:
/// цвет был бы, а вида «как на телефоне» — нет.
bool _plausibleSize(EmojiCellStats stats) {
  final b = stats.box;
  if (b == null) return false;
  const glyph = EmojiSelftestGeometry.glyph;
  final w = b.$3 - b.$1 + 1, h = b.$4 - b.$2 + 1;
  return h >= glyph * 0.45 &&
      h <= glyph * 1.35 &&
      w >= glyph * 0.45 &&
      w <= glyph * 1.35;
}

/// Решение по снимку листа. [lines] — что писать в журнал.
@visibleForTesting
({bool ok, List<String> lines}) judgeEmojiSelftest(
  Uint8List rgba,
  int width, {
  required bool registered,
}) {
  final lines = <String>['registered=$registered'];
  var ok = registered;
  final size = EmojiSelftestGeometry.cell.round();
  final systemDiffs = <double>[];
  for (var s = 0; s < kEmojiSelftestSamples.length; s++) {
    final emoji = kEmojiSelftestSamples[s];
    final noto = EmojiSelftestGeometry.cellOrigin(EmojiSelftestRow.noto, s);
    final system =
        EmojiSelftestGeometry.cellOrigin(EmojiSelftestRow.system, s);
    for (final row in EmojiSelftestRow.values) {
      final o = EmojiSelftestGeometry.cellOrigin(row, s);
      final stats = emojiCellStats(rgba, width, o, size);
      final parts = <String>['$emoji ${row.label}: $stats'];
      if (row == EmojiSelftestRow.theme || row == EmojiSelftestRow.dtypeSpan) {
        final diff = emojiCellDiff(rgba, width, o, noto, size);
        final same = diff <= _kSameAsNoto;
        final coloured = stats.inkFraction >= _kMinInk &&
            stats.colourfulFraction >= _kMinColourful;
        final sized = _plausibleSize(stats);
        parts.add('diff_vs_noto=${diff.toStringAsFixed(1)}');
        if (!same) parts.add('FAIL: not the Noto glyph');
        if (!coloured) parts.add('FAIL: empty or not coloured');
        if (coloured && !sized) parts.add('FAIL: wrong glyph size');
        ok = ok && same && coloured && sized;
      } else if (row == EmojiSelftestRow.noto) {
        final diff = emojiCellDiff(rgba, width, o, system, size);
        systemDiffs.add(diff);
        parts.add('diff_vs_system=${diff.toStringAsFixed(1)}');
      }
      lines.add(parts.join(' '));
    }
  }
  final meanSystemDiff = systemDiffs.isEmpty
      ? 0.0
      : systemDiffs.reduce((a, b) => a + b) / systemDiffs.length;
  final distinct = meanSystemDiff >= _kDifferentFromSystem;
  lines.add(
    'noto_vs_system_mean=${meanSystemDiff.toStringAsFixed(1)}'
    '${distinct ? '' : ' FAIL: Noto draws like the system font'}',
  );
  ok = ok && distinct;
  return (ok: ok, lines: lines);
}

var _finished = false;

void _finish(int code, List<String> log) {
  if (_finished) return;
  _finished = true;
  try {
    File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'secretly_emoji_font_selftest.txt',
    ).writeAsStringSync('${code == 0 ? 'OK' : 'FAIL'}\n${log.join('\n')}\n');
  } catch (_) {}
  exit(code);
}

/// Запуск самотеста вместо приложения. [load] — загрузка шрифта, начатая в
/// `main` (та же, что у обычного запуска).
Future<void> runDesktopEmojiFontSelftest(
  Future<DesktopEmojiFontLoad> load,
) async {
  final log = <String>[];
  // Сторож: что бы ни зависло, процесс выходит сам и оставляет журнал.
  Timer(const Duration(seconds: 60), () {
    log.add('error=watchdog 60 s');
    _finish(2, log);
  });
  try {
    final watch = Stopwatch()..start();
    final loaded = await load.timeout(const Duration(seconds: 20));
    log.add('load: $loaded (awaited ${watch.elapsedMilliseconds} ms)');

    final key = GlobalKey();
    runApp(DesktopEmojiSelftestApp(boundaryKey: key));
    final framed = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!framed.isCompleted) framed.complete();
    });
    WidgetsBinding.instance.scheduleFrame();
    await framed.future.timeout(const Duration(seconds: 20));
    // Ещё один кадр — если придёт. Шрифт загружен ДО `runApp`, так что и
    // первый кадр рисовал им; второй лишь страхует и снимок не держит.
    try {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await WidgetsBinding.instance.endOfFrame.timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {}

    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('no RepaintBoundary');
    }
    final image = await boundary.toImage(pixelRatio: 1.0);
    try {
      log.add('image=${image.width}x${image.height}');
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png != null) {
        File(
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'secretly_emoji_font_selftest.png',
        ).writeAsBytesSync(png.buffer.asUint8List());
      }
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (raw == null) throw StateError('no pixels');
      final verdict = judgeEmojiSelftest(
        raw.buffer.asUint8List(),
        image.width,
        registered: DesktopEmojiFontLoader.probeRegistered(),
      );
      log.addAll(verdict.lines);
      _finish(verdict.ok ? 0 : 1, log);
    } finally {
      image.dispose();
    }
  } catch (e) {
    log.add('error=$e');
    _finish(3, log);
  }
}
