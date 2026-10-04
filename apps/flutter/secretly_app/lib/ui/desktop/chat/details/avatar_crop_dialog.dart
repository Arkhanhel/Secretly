// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../design/tokens.dart';
import '../../primitives/desktop_button.dart';
import '../../primitives/desktop_dialog.dart';

/// Сторона готового портрета. Общий сеттер всё равно ужимает до 512 и берёт
/// центральный квадрат — отдаём ему уже квадрат, и он ничего не отрежет.
const int kDesktopAvatarCropSide = 512;

/// Кадрирование портрета перед загрузкой (29.09.2026).
///
/// Раньше ПК отправлял исходник как есть, и общий сеттер брал из него
/// центральный квадрат: на вертикальном снимке голова уезжала за край. У
/// телефона для этого есть `CoverCropScreen(circle: true)`; его не берём —
/// в нём зашит русский текст, а результат ложится файлом в «Документы».
///
/// [round] — круг для людей, скруглённый квадрат для комнат. Возвращает
/// PNG-квадрат [kDesktopAvatarCropSide] или `null` при отмене. Снимок, который
/// не прочитался, — [FormatException]: об этом надо сказать словами.
Future<Uint8List?> showDesktopAvatarCropDialog(
  BuildContext context, {
  required Uint8List bytes,
  required bool round,
}) async {
  final ui.Image image;
  try {
    // 🔴 Снимок читается сразу уменьшенным (29.09.2026, разбор Р1): снимок
    // с камеры на 48 Мп в полном размере — почти 200 МБ памяти ради
    // портрета 512×512. Декодер после чтения закрывается.
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: desktopAvatarDecodeSize,
    );
    try {
      image = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  } catch (_) {
    throw const FormatException('image is not decodable');
  }
  if (!context.mounted) {
    image.dispose();
    return null;
  }
  final l10n = AppLocalizations.of(context)!;
  final state = DesktopAvatarCropState(
    imageWidth: image.width.toDouble(),
    imageHeight: image.height.toDouble(),
  );
  final ok = await DesktopDialog.show<bool>(
    context,
    title: l10n.desktopAvatarCropTitle,
    size: DDialogSize.small,
    body: _CropBody(image: image, state: state, round: round),
    primary: DDialogAction(
      label: l10n.desktopApply,
      onPressed: () => Navigator.of(context).maybePop(true),
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      kind: DButtonKind.ghost,
      onPressed: () => Navigator.of(context).maybePop(false),
    ),
  );
  // Окно ещё гаснет и рисует снимок, но у окна своя копия ([_CropBody]): эту
  // можно отпустить, как только готов портрет.
  try {
    if (ok != true) return null;
    return await renderDesktopAvatarCrop(image, state.sourceRect());
  } finally {
    image.dispose();
  }
}

/// Размер, до которого читается снимок для кадрирования: короткая сторона —
/// не больше, чем нужно портрету при наибольшем увеличении (512 × 4), и
/// длинная — не больше вдвое того. Меньше — как есть: увеличивать незачем.
ui.TargetImageSize desktopAvatarDecodeSize(int width, int height) {
  const maxShort = kDesktopAvatarCropSide * DesktopAvatarCropState.maxZoom;
  const maxLong = maxShort * 2;
  final short = math.min(width, height);
  final long = math.max(width, height);
  if (short <= 0) return const ui.TargetImageSize();
  final scale = math.min(1.0, math.min(maxShort / short, maxLong / long));
  if (scale >= 1.0) return const ui.TargetImageSize();
  // Одна сторона: вторую декодер посчитает сам, сохранив пропорции.
  return ui.TargetImageSize(width: math.max(1, (width * scale).round()));
}

/// Вырезает [src] из [image] в квадрат [kDesktopAvatarCropSide], PNG.
Future<Uint8List?> renderDesktopAvatarCrop(ui.Image image, Rect src) async {
  final side = kDesktopAvatarCropSide.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    src,
    Rect.fromLTWH(0, 0, side, side),
    Paint()..filterQuality = FilterQuality.high,
  );
  final picture = recorder.endRecording();
  final out = await picture.toImage(
    kDesktopAvatarCropSide,
    kDesktopAvatarCropSide,
  );
  picture.dispose();
  try {
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    out.dispose();
  }
}

/// Положение снимка под рамкой кадра. Отдельно от виджета, чтобы считалось
/// и проверялось без экрана.
///
/// Рамка кадра — квадрат [viewport] (в точках окна). Снимок масштабирован так,
/// что при [zoom] = 1 он ровно покрывает рамку (короткой стороной), и сдвинут
/// на [offset] от центра. Сдвиг всегда такой, что рамка целиком лежит на
/// снимке — пустых полос в портрете не бывает.
class DesktopAvatarCropState extends ChangeNotifier {
  DesktopAvatarCropState({
    required this.imageWidth,
    required this.imageHeight,
    this.viewport = 280,
  });

  final double imageWidth;
  final double imageHeight;
  final double viewport;

  static const double minZoom = 1;
  static const double maxZoom = 4;

  double _zoom = 1;
  Offset _offset = Offset.zero;

  double get zoom => _zoom;
  Offset get offset => _offset;

  /// Масштаб «снимок → точки окна».
  double get scale =>
      viewport / math.min(imageWidth, imageHeight) * _zoom;

  void setZoom(double value) {
    _zoom = value.clamp(minZoom, maxZoom);
    _offset = _clamp(_offset);
    notifyListeners();
  }

  void panBy(Offset delta) {
    _offset = _clamp(_offset + delta);
    notifyListeners();
  }

  Offset _clamp(Offset o) {
    final maxX = math.max(0.0, (imageWidth * scale - viewport) / 2);
    final maxY = math.max(0.0, (imageHeight * scale - viewport) / 2);
    return Offset(o.dx.clamp(-maxX, maxX), o.dy.clamp(-maxY, maxY));
  }

  /// Часть снимка под рамкой кадра — в пикселях снимка.
  Rect sourceRect() {
    final s = scale;
    final side = viewport / s;
    final cx = imageWidth / 2 - _offset.dx / s;
    final cy = imageHeight / 2 - _offset.dy / s;
    return Rect.fromCenter(center: Offset(cx, cy), width: side, height: side);
  }
}

class _CropBody extends StatefulWidget {
  const _CropBody({
    required this.image,
    required this.state,
    required this.round,
  });

  final ui.Image image;
  final DesktopAvatarCropState state;
  final bool round;

  @override
  State<_CropBody> createState() => _CropBodyState();
}

class _CropBodyState extends State<_CropBody> {
  /// 🔴 Своя копия снимка (29.09.2026, разбор Р1). Ответ окна приходит в
  /// начале его ухода: снимок отпускался сразу, а гаснущее окно ещё несколько
  /// кадров рисовало его — рисовать отпущенный снимок нельзя. Копия живёт,
  /// пока живёт само окно.
  late final ui.Image _image;

  @override
  void initState() {
    super.initState();
    _image = widget.image.clone();
  }

  @override
  void dispose() {
    _image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final state = widget.state;
    final vp = state.viewport;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Listener(
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) {
                state.setZoom(state.zoom * (e.scrollDelta.dy < 0 ? 1.08 : 1 / 1.08));
              }
            },
            child: GestureDetector(
              onPanUpdate: (d) => state.panBy(d.delta),
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: SizedBox(
                  width: vp,
                  height: vp,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DRadii.md),
                    child: AnimatedBuilder(
                      animation: state,
                      builder: (ctx, _) => CustomPaint(
                        painter: _CropPainter(
                          image: _image,
                          src: state.sourceRect(),
                          round: widget.round,
                          shade: c.bg,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: DSpace.m),
        AnimatedBuilder(
          animation: state,
          builder: (ctx, _) => Slider(
            value: state.zoom,
            min: DesktopAvatarCropState.minZoom,
            max: DesktopAvatarCropState.maxZoom,
            onChanged: state.setZoom,
          ),
        ),
        Text(
          l10n.desktopAvatarCropHint,
          textAlign: TextAlign.center,
          style: DType.caption.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.src,
    required this.round,
    required this.shade,
  });

  final ui.Image image;
  final Rect src;
  final bool round;
  final Color shade;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    // Затемнение вне будущего портрета: видно, что именно останется.
    final hole = round
        ? (Path()..addOval(dst.deflate(2)))
        : (Path()..addRRect(
            RRect.fromRectAndRadius(
              dst.deflate(2),
              Radius.circular(size.width * 0.33),
            ),
          ));
    final mask = Path.combine(
      PathOperation.difference,
      Path()..addRect(dst),
      hole,
    );
    canvas.drawPath(mask, Paint()..color = shade.withValues(alpha: 0.62));
    canvas.drawPath(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.src != src || old.round != round || old.image != image;
}
