// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../media/video_thumbnail_cache.dart';
import '../app/desktop_file_match.dart' show formatAttachmentSize;
import '../design/tokens.dart';
import '../primitives/desktop_tooltip.dart';
import 'desktop_video_thumb.dart';
import 'media_group_layout.dart';
import 'message_bubble.dart' show MessageAttachment, MessageAttachmentKind;

/// Размеры медиа в ленте — числа Telegram Desktop (`ui/chat/chat.style`).
///
/// 🔴 Указание владельца 16.09.2026: фото, видео и файлы «ровно так же, как в
/// телеграме». Числа сверены с исходниками Telegram Desktop; внешний вид
/// окна отправки и строки файла — со скриншотов Telegram для macOS, которые
/// прислал владелец.
abstract final class DMedia {
  /// Наибольшая сторона одиночного снимка и ширина альбома (maxMediaSize).
  static const double maxSize = 430;

  /// Наименьшая сторона снимка и плитки альбома (minPhotoSize).
  static const double minSize = 100;

  /// Снимок с подписью живёт в пузыре — уже 200 он не бывает
  /// (historyPhotoBubbleMinWidth).
  static const double minInBubble = 200;

  /// Шов между плитками альбома (historyGroupSkip).
  static const double albumSkip = 4;

  /// Скругление медиа без пузыря (bubbleRadiusLarge) и стороны, прилегающей
  /// к соседнему сообщению той же серии (bubbleRadiusSmall).
  static const double radius = 16;
  static const double attachedRadius = 6;

  /// Кнопка в центре снимка или ролика: загрузка, воспроизведение.
  static const double centerButton = 44;

  /// Плашки поверх медиа (время, длительность): ≈33% чёрного
  /// (msgDateImgBg = #00000054).
  static const Color badgeBg = Color(0x54000000);
  static const Color badgeBgHover = Color(0x74000000);

  /// Строка файла: круг 44 или миниатюра 72, ширина от 268 до 430.
  static const double fileIcon = 44;
  static const double fileThumb = 72;
  static const double fileMinWidth = 268;
}

/// Размер одиночного снимка или ролика в ленте.
///
/// Как в Telegram: картинка только УМЕНЬШАЕТСЯ до 430×430 (и до доступной
/// ширины), но не бывает меньше 100 по каждой стороне; в пузыре — не уже 200.
Size singleMediaSize(
  Size source, {
  required double maxWidth,
  bool inBubble = false,
}) {
  var w = source.width;
  var h = source.height;
  if (w <= 0 || h <= 0) {
    w = 1;
    h = 1;
  }
  final limitW = math.min(DMedia.maxSize, maxWidth);
  const limitH = DMedia.maxSize;
  final scale = math.min(1.0, math.min(limitW / w, limitH / h));
  if (w * scale < 1 || h * scale < 1) {
    // Крошечная картинка без размеров (1×1) — квадрат наименьшего размера.
    w = h = DMedia.minSize;
  } else {
    w *= scale;
    h *= scale;
  }
  final minW = math.min(inBubble ? DMedia.minInBubble : DMedia.minSize, limitW);
  w = w.clamp(minW, limitW);
  h = math.max(h, DMedia.minSize);
  return Size(w.roundToDouble(), h.roundToDouble());
}

/// Раскладка альбома в ленте: считается на полной ширине 430 и сжимается
/// вместе со швом, если места меньше (`history_view_media_grouped.cpp`).
List<MediaTileLayout> albumLayout(List<Size> sizes, {required double width}) {
  final full = layoutMediaGroup(
    sizes,
    maxWidth: DMedia.maxSize,
    minWidth: DMedia.minSize,
    spacing: DMedia.albumSkip,
  );
  final target = math.min(width, DMedia.maxSize);
  if (target >= DMedia.maxSize) return full;
  final factor = target / DMedia.maxSize;
  final skip = (DMedia.albumSkip * factor).roundToDouble();
  return [
    for (final t in full)
      MediaTileLayout(
        Rect.fromLTRB(
          (t.rect.left * factor).roundToDouble(),
          (t.rect.top * factor).roundToDouble(),
          // Край, упиравшийся в край альбома, остаётся на краю; остальные
          // сдвигаются так, чтобы шов остался ровно [skip].
          t.rect.right >= DMedia.maxSize - 0.5
              ? target
              : ((t.rect.right + DMedia.albumSkip) * factor).roundToDouble() -
                    skip,
          ((t.rect.bottom + DMedia.albumSkip) * factor).roundToDouble() - skip,
        ),
        t.corners,
      ),
  ];
}

/// Скругление плитки: внешние углы альбома — [outer], внутренние — прямые.
BorderRadius tileRadius(MediaTileCorners corners, BorderRadius outer) =>
    BorderRadius.only(
      topLeft: corners.topLeft ? outer.topLeft : Radius.zero,
      topRight: corners.topRight ? outer.topRight : Radius.zero,
      bottomLeft: corners.bottomLeft ? outer.bottomLeft : Radius.zero,
      bottomRight: corners.bottomRight ? outer.bottomRight : Radius.zero,
    );

/// Плашка поверх медиа — время, длительность ролика.
class MediaBadge extends StatelessWidget {
  const MediaBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: DMedia.badgeBg,
        borderRadius: BorderRadius.circular(DRadii.pill),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 16 / 12,
        ),
        child: child,
      ),
    );
  }
}

/// Круглая кнопка в центре медиа: воспроизведение, загрузка, повтор.
class MediaCenterButton extends StatefulWidget {
  const MediaCenterButton({
    super.key,
    required this.icon,
    this.busy = false,
    this.onTap,
    this.tooltip,
  });

  final IconData icon;

  /// Идёт загрузка: вместо значка — бегущее кольцо.
  final bool busy;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  State<MediaCenterButton> createState() => _MediaCenterButtonState();
}

class _MediaCenterButtonState extends State<MediaCenterButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    Widget button = MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DMotion.fast,
          width: DMedia.centerButton,
          height: DMedia.centerButton,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover ? DMedia.badgeBgHover : DMedia.badgeBg,
          ),
          child: widget.busy
              ? const SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Icon(widget.icon, size: 22, color: Colors.white),
        ),
      ),
    );
    final tip = widget.tooltip;
    if (tip != null) button = DesktopTooltip(message: tip, child: button);
    return button;
  }
}

/// Кольцо отправки с крестиком — как в Telegram: видно, сколько ушло, а
/// нажатие отменяет отправку.
class MediaUploadRing extends StatelessWidget {
  const MediaUploadRing({
    super.key,
    required this.progress,
    this.onCancel,
    this.diameter = DMedia.centerButton,
    this.background = DMedia.badgeBg,
    this.foreground = Colors.white,
  });

  /// 0..1. Пока ничего не ушло (идёт сжатие ролика, шифрование) — кольцо
  /// бежит, а не стоит на нуле.
  final double progress;
  final VoidCallback? onCancel;
  final double diameter;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final value = progress <= 0.01 ? null : progress.clamp(0.0, 1.0);
    final ring = Container(
      key: const ValueKey('media-upload-ring'),
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(shape: BoxShape.circle, color: background),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: diameter - 6,
            height: diameter - 6,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(foreground),
            ),
          ),
          Icon(
            FluentIcons.dismiss_24_regular,
            size: (diameter * 0.36).roundToDouble(),
            color: foreground,
          ),
        ],
      ),
    );
    final cancel = onCancel;
    if (cancel == null) return ring;
    return DesktopTooltip(
      message: 'Отменить отправку',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: cancel,
          child: ring,
        ),
      ),
    );
  }
}

/// Сколько ушло: «1.2 МБ / 4.5 МБ».
String uploadStatusText(MessageAttachment a) {
  final total = formatAttachmentSize(a.sizeBytes);
  final fraction = (a.uploadProgress ?? 0).clamp(0.0, 1.0);
  final sent = (a.sizeBytes * fraction).round();
  if (sent <= 0) return total.isEmpty ? 'Отправка…' : 'Отправка… · $total';
  return '${formatAttachmentSize(sent)} / $total';
}

/// «00:15» — минуты всегда двумя цифрами, как в Telegram.
String formatMediaDuration(int ms) {
  final total = (ms / 1000).round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Подпись длительности ролика: пока не скачан — ещё и размер.
///
/// [durationMs] — длительность, узнанная по самому файлу: у обычного ролика
/// её в сообщении нет (поле заполняют только кружки и голосовые).
String videoBadgeText(MessageAttachment a, {int? durationMs}) {
  final parts = <String>[];
  final ms = a.durationMs ?? durationMs;
  if (ms != null && ms > 0) parts.add(formatMediaDuration(ms));
  if (a.filePath == null && a.sizeBytes > 0) {
    parts.add(formatAttachmentSize(a.sizeBytes));
  }
  return parts.isEmpty ? 'Видео' : parts.join(', ');
}

/// Одна плитка медиа: снимок или ролик заданного размера.
///
/// Пока снимок не скачан — размытая миниатюра от отправителя (или ровный
/// фон) и бегущее кольцо; не удалось — кнопка повтора. У ролика в центре
/// кнопка воспроизведения, слева сверху — длительность.
class DesktopMediaTile extends StatelessWidget {
  const DesktopMediaTile({
    super.key,
    required this.attachment,
    required this.size,
    required this.radius,
    this.onOpen,
    this.onRetry,
    this.onCancelUpload,
    this.showVideoBadge = true,
    this.placeholder,
  });

  final MessageAttachment attachment;
  final Size size;
  final BorderRadius radius;
  final VoidCallback? onOpen;
  final VoidCallback? onRetry;

  /// Отменить отправку — пока снимок уходит с этого компьютера.
  final VoidCallback? onCancelUpload;

  /// Плашка длительности — только у плиток во всю ширину альбома, как в
  /// Telegram: на узких она закрывала бы половину кадра.
  final bool showVideoBadge;

  /// Цвет подложки, пока снимка нет.
  final Color? placeholder;

  bool get _isVideo => attachment.kind == MessageAttachmentKind.video;

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    final bg = placeholder ?? const Color(0xFF1B1E25);
    final failed = a.failed;
    final ready = a.filePath != null && !failed;
    final uploading = a.uploadProgress != null;

    final Widget content;
    if (_isVideo) {
      content = ready
          ? VideoPoster(
              key: ValueKey('poster_${a.blobId}'),
              blobId: a.blobId,
              path: a.filePath!,
              size: size,
              background: bg,
            )
          : _thumbOrFill(bg);
    } else {
      content = ready
          ? LocalMediaImage(
              path: a.filePath!,
              size: size,
              sourceSize: (a.width != null && a.height != null)
                  ? Size(a.width!.toDouble(), a.height!.toDouble())
                  : null,
              background: bg,
              fallback: _thumbOrFill(bg),
            )
          : _thumbOrFill(bg);
    }

    Widget? center;
    if (uploading) {
      center = MediaUploadRing(
        progress: a.uploadProgress!,
        onCancel: onCancelUpload,
      );
    } else if (failed) {
      center = MediaCenterButton(
        icon: FluentIcons.arrow_clockwise_24_regular,
        tooltip: 'Повторить загрузку',
        onTap: onRetry,
      );
    } else if (a.loading || (!ready && a.downloadProgress != null)) {
      center = const MediaCenterButton(
        icon: FluentIcons.arrow_download_24_regular,
        busy: true,
      );
    } else if (_isVideo) {
      center = MediaCenterButton(
        icon: FluentIcons.play_24_filled,
        onTap: onOpen,
      );
    }

    // Пока снимок уходит, открывать нечего: нажатие — только по кольцу.
    final VoidCallback? tap = uploading
        ? null
        : (failed ? onRetry : (ready ? onOpen : null));
    return MouseRegion(
      cursor: tap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox.fromSize(
            size: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                content,
                if (center != null) Center(child: center),
                if (_isVideo && showVideoBadge)
                  Positioned(
                    left: 4,
                    top: 4,
                    child: _VideoBadge(attachment: a),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbOrFill(Color bg) {
    final thumb = attachment.thumbnail;
    if (thumb == null || thumb.isEmpty) return ColoredBox(color: bg);
    return BlurredThumb(bytes: thumb, background: bg);
  }
}

/// Длительность ролика в углу. Если сообщение её не несёт — узнаём по
/// самому файлу, тем же разбором, что даёт кадр (результат общий, второй раз
/// ffmpeg не запускается).
class _VideoBadge extends StatefulWidget {
  const _VideoBadge({required this.attachment});

  final MessageAttachment attachment;

  @override
  State<_VideoBadge> createState() => _VideoBadgeState();
}

class _VideoBadgeState extends State<_VideoBadge> {
  int? _probed;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  @override
  void didUpdateWidget(_VideoBadge old) {
    super.didUpdateWidget(old);
    if (old.attachment.filePath != widget.attachment.filePath ||
        old.attachment.blobId != widget.attachment.blobId) {
      _probe();
    }
  }

  void _probe() {
    final a = widget.attachment;
    final path = a.filePath;
    if (a.durationMs != null || path == null || a.blobId.isEmpty) return;
    final known = VideoThumbnailCache.peek(a.blobId)?.durationMs;
    if (known != null) {
      _probed = known;
      return;
    }
    final key = a.blobId;
    VideoThumbnailCache.forVideo(key: key, videoPath: path).then((t) {
      final ms = t?.durationMs;
      if (!mounted || ms == null || widget.attachment.blobId != key) return;
      setState(() => _probed = ms);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MediaBadge(
      child: Text(videoBadgeText(widget.attachment, durationMs: _probed)),
    );
  }
}

/// Размытая миниатюра — пока настоящий снимок не пришёл.
class BlurredThumb extends StatelessWidget {
  const BlurredThumb({super.key, required this.bytes, required this.background});

  final Uint8List bytes;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: ClipRect(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Снимок с диска, уменьшенный при декодировании до размера плитки.
///
/// 🔴 Прежний пузырь декодировал снимок в ПОЛНОМ размере: двенадцать
/// мегапикселей ради плитки в 300 точек, на каждом снимке ленты. Здесь
/// декодер сразу получает нужный размер.
///
/// Как в Telegram (`GetImageScaleSizeForGeometry`): плитка заполняется
/// снимком целиком, с обрезкой; только если пропорции отличаются ВДВОЕ и
/// больше (срезалась бы половина снимка), он вписывается целиком поверх
/// размытой копии себя самого. Раньше порог был «четверть» — и квадратный
/// снимок в высокой плитке альбома показывался с полосами.
class LocalMediaImage extends StatelessWidget {
  const LocalMediaImage({
    super.key,
    required this.path,
    required this.size,
    required this.background,
    required this.fallback,
    this.sourceSize,
  });

  final String path;
  final Size size;
  final Size? sourceSize;
  final Color background;
  final Widget fallback;

  /// Доля снимка, которая срезается при заполнении плитки.
  static double coverCut(Size source, Size box) {
    if (source.width <= 0 || source.height <= 0) return 0;
    final sa = source.width / source.height;
    final ba = box.width / box.height;
    return sa > ba ? 1 - ba / sa : 1 - sa / ba;
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final src = sourceSize;
    int? cacheWidth;
    int? cacheHeight;
    if (src != null && src.width > 0 && src.height > 0) {
      // Декодируем по стороне, которая упирается в плитку при заполнении.
      final wider = src.width / src.height > size.width / size.height;
      if (wider) {
        cacheHeight = (size.height * dpr).ceil();
      } else {
        cacheWidth = (size.width * dpr).ceil();
      }
    } else {
      cacheWidth = (math.max(size.width, size.height) * dpr).ceil();
    }
    final file = File(path);
    Widget image(BoxFit fit) => Image.file(
      file,
      fit: fit,
      width: size.width,
      height: size.height,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => fallback,
    );
    if (src != null && coverCut(src, size) >= 0.5) {
      return ColoredBox(
        color: background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: image(BoxFit.cover),
              ),
            ),
            const ColoredBox(color: Color(0x30000000)),
            image(BoxFit.contain),
          ],
        ),
      );
    }
    return ColoredBox(color: background, child: image(BoxFit.cover));
  }
}

/// Кадр ролика. Будущее запоминается: новое на каждой перерисовке мигало бы
/// заглушкой поверх готового кадра.
class VideoPoster extends StatefulWidget {
  const VideoPoster({
    super.key,
    required this.blobId,
    required this.path,
    required this.size,
    required this.background,
  });

  final String blobId;
  final String path;
  final Size size;
  final Color background;

  @override
  State<VideoPoster> createState() => _VideoPosterState();
}

class _VideoPosterState extends State<VideoPoster> {
  static final Map<String, String> _ready = <String, String>{};
  String? _poster;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(VideoPoster old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.blobId != widget.blobId) _resolve();
  }

  void _resolve() {
    final key = widget.blobId;
    _poster = _ready[key];
    if (_poster != null) return;
    DesktopVideoThumb.forVideo(key: key, videoPath: widget.path).then((p) {
      if (p == null) return;
      _ready[key] = p;
      if (mounted && widget.blobId == key) setState(() => _poster = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final poster = _poster;
    if (poster == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B1E25), Color(0xFF0E1014)],
          ),
        ),
      );
    }
    return LocalMediaImage(
      path: poster,
      size: widget.size,
      background: widget.background,
      fallback: ColoredBox(color: widget.background),
    );
  }
}

/// Сетка альбома.
class DesktopMediaGrid extends StatelessWidget {
  const DesktopMediaGrid({
    super.key,
    required this.attachments,
    required this.width,
    required this.outerRadius,
    required this.tileBuilder,
  });

  final List<MessageAttachment> attachments;
  final double width;

  /// Скругление внешних углов альбома.
  final BorderRadius outerRadius;

  final Widget Function(
    int index,
    Size size,
    BorderRadius radius,
    bool fullWidth,
  )
  tileBuilder;

  @override
  Widget build(BuildContext context) {
    final layout = albumLayout(
      [for (final a in attachments) a.mediaSize],
      width: width,
    );
    final size = mediaGroupSize(layout);
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        children: [
          for (var i = 0; i < layout.length; i++)
            Positioned.fromRect(
              rect: layout[i].rect,
              child: tileBuilder(
                i,
                layout[i].rect.size,
                tileRadius(layout[i].corners, outerRadius),
                layout[i].rect.width >= size.width - 0.5,
              ),
            ),
        ],
      ),
    );
  }
}

/// Имя файла с многоточием В СЕРЕДИНЕ, как в Telegram: расширение остаётся
/// видно всегда («wallpaper_lig….png»).
class MiddleEllipsisText extends StatelessWidget {
  const MiddleEllipsisText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final dot = text.lastIndexOf('.');
    final hasExt = dot > 0 && text.length - dot <= 8;
    if (!hasExt) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return DesktopTooltip(
      message: text,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text.substring(0, dot),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
          Text(text.substring(dot), style: style, maxLines: 1),
        ],
      ),
    );
  }
}

/// Строка файла — как в Telegram для macOS: миниатюра 72 (у снимков) или
/// круг 44 со стрелкой, имя, «2,6 МБ — Загрузить» / «Показать в Finder».
class DesktopFileRow extends StatelessWidget {
  const DesktopFileRow({
    super.key,
    required this.attachment,
    required this.fg,
    required this.fgSoft,
    required this.accent,
    required this.iconBg,
    required this.iconFg,
    this.onDownload,
    this.onOpen,
    this.onReveal,
    this.onCancelUpload,
    this.grouped = false,
  });

  final MessageAttachment attachment;
  final Color fg;
  final Color fgSoft;

  /// Цвет ссылок «Загрузить» / «Показать в Finder».
  final Color accent;
  final Color iconBg;
  final Color iconFg;
  final VoidCallback? onDownload;
  final VoidCallback? onOpen;
  final VoidCallback? onReveal;

  /// Отменить отправку — пока файл уходит с этого компьютера.
  final VoidCallback? onCancelUpload;

  /// В стопке файлов строки плотнее.
  final bool grouped;

  bool get _uploading => attachment.uploadProgress != null;

  /// Путь у уходящего файла есть (это сам исходник), но «скачанным» он не
  /// считается: показывать его в Finder как вложение ещё нечего.
  bool get _downloaded =>
      attachment.filePath != null && !attachment.failed && !_uploading;
  bool get _busy => attachment.loading || attachment.downloadProgress != null;

  /// Снимок, отправленный файлом, показывается миниатюрой.
  bool get _hasThumb =>
      attachment.kind == MessageAttachmentKind.image &&
      (attachment.thumbnail != null ||
          _downloaded ||
          (_uploading && attachment.filePath != null));

  String get _name {
    final n = (attachment.fileName ?? '').trim();
    if (n.isNotEmpty) return n;
    return switch (attachment.kind) {
      MessageAttachmentKind.image => 'Изображение',
      MessageAttachmentKind.video => 'Видео',
      MessageAttachmentKind.audio => 'Аудиофайл',
      _ => 'Файл',
    };
  }

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    final size = formatAttachmentSize(a.sizeBytes);
    final statusStyle = DType.caption.copyWith(color: fgSoft);
    final linkStyle = DType.caption.copyWith(
      color: accent,
      fontWeight: FontWeight.w600,
    );

    final Widget status;
    if (_uploading) {
      status = Text(uploadStatusText(a), style: statusStyle);
    } else if (a.failed) {
      status = _StatusLine(
        prefix: 'Не удалось загрузить',
        link: 'Повторить',
        style: statusStyle,
        linkStyle: linkStyle,
        onLink: onDownload,
      );
    } else if (_busy) {
      status = Text(
        size.isEmpty ? 'Загрузка…' : 'Загрузка… · $size',
        style: statusStyle,
      );
    } else if (_downloaded) {
      status = _StatusLine(
        prefix: size,
        link: onReveal == null ? null : 'Показать в Finder',
        style: statusStyle,
        linkStyle: linkStyle,
        onLink: onReveal,
      );
    } else {
      status = _StatusLine(
        prefix: size,
        link: onDownload == null ? null : 'Загрузить',
        style: statusStyle,
        linkStyle: linkStyle,
        onLink: onDownload,
      );
    }

    final thumbSide = _hasThumb ? DMedia.fileThumb : DMedia.fileIcon;
    final leading = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _uploading
            ? onCancelUpload
            : (_downloaded ? onOpen : (_busy ? null : onDownload)),
        child: SizedBox(
          width: thumbSide,
          height: thumbSide,
          child: _hasThumb ? _thumb() : _icon(),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: grouped ? 3 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          SizedBox(width: _hasThumb ? 12 : 11),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MiddleEllipsisText(
                  _name,
                  style: DType.bodyStrong.copyWith(color: fg),
                ),
                const SizedBox(height: 3),
                status,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon() {
    final a = attachment;
    if (_uploading) {
      return MediaUploadRing(
        progress: a.uploadProgress!,
        diameter: DMedia.fileIcon,
        background: iconBg,
        foreground: iconFg,
      );
    }
    final IconData icon;
    if (a.failed) {
      icon = FluentIcons.arrow_clockwise_24_regular;
    } else if (!_downloaded) {
      icon = FluentIcons.arrow_download_24_filled;
    } else {
      icon = switch (a.kind) {
        MessageAttachmentKind.image => FluentIcons.image_24_regular,
        MessageAttachmentKind.video => FluentIcons.video_24_regular,
        MessageAttachmentKind.audio => FluentIcons.music_note_2_24_regular,
        _ => FluentIcons.document_24_regular,
      };
    }
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
      alignment: Alignment.center,
      child: _busy
          ? SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(iconFg),
              ),
            )
          : Icon(icon, size: 22, color: iconFg),
    );
  }

  Widget _thumb() {
    final a = attachment;
    const bg = Color(0xFF1B1E25);
    final Widget picture = (_downloaded || (_uploading && a.filePath != null))
        ? LocalMediaImage(
            path: a.filePath!,
            size: const Size.square(DMedia.fileThumb),
            sourceSize: (a.width != null && a.height != null)
                ? Size(a.width!.toDouble(), a.height!.toDouble())
                : null,
            background: bg,
            fallback: const ColoredBox(color: bg),
          )
        : BlurredThumb(bytes: a.thumbnail!, background: bg);
    return ClipRRect(
      borderRadius: BorderRadius.circular(DRadii.r8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          picture,
          if (_uploading)
            Center(
              child: MediaUploadRing(
                progress: a.uploadProgress!,
                diameter: 36,
              ),
            )
          else if (!_downloaded)
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: DMedia.badgeBg,
                ),
                alignment: Alignment.center,
                child: _busy
                    ? const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Icon(
                        a.failed
                            ? FluentIcons.arrow_clockwise_24_regular
                            : FluentIcons.arrow_download_24_filled,
                        size: 18,
                        color: Colors.white,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// «2,6 МБ — Загрузить»: ссылка в конце строки состояния.
class _StatusLine extends StatefulWidget {
  const _StatusLine({
    required this.prefix,
    required this.link,
    required this.style,
    required this.linkStyle,
    required this.onLink,
  });

  final String prefix;
  final String? link;
  final TextStyle style;
  final TextStyle linkStyle;
  final VoidCallback? onLink;

  @override
  State<_StatusLine> createState() => _StatusLineState();
}

class _StatusLineState extends State<_StatusLine> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final prefix = widget.prefix;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prefix.isNotEmpty)
          Text(prefix, style: widget.style, maxLines: 1),
        if (prefix.isNotEmpty && link != null)
          Text(' — ', style: widget.style),
        if (link != null)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              onTap: widget.onLink,
              child: Text(
                link,
                maxLines: 1,
                style: widget.linkStyle.copyWith(
                  decoration: _hover
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: widget.linkStyle.color,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
