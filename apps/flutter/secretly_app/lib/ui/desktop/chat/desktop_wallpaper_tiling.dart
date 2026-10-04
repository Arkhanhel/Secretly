// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// ОБОИ ПК: УЗОР ПО ВЫСОТЕ, КОЛОНКИ ОТ ЦЕНТРА — РАСШИРЕНИЕ ВМЕСТО РАСТЯГИВАНИЯ.
///
/// 🔴 ЗАЧЕМ (30.09.2026, О1, владелец: «динамические обои и стандартные обои с
/// узорами при расширении чата растягиваются, а в Telegram они как будто
/// генеративно расширяются»).
///
/// Было: картинка и маска узора ложились «по покрытию» (cover). На широкой
/// панели масштаб решала ШИРИНА: дудл ~45 px на телефоне, ~91 px в окне 1000,
/// ~174 px в окне 1900. Вдобавок каждое изменение ширины окна заново
/// декодировало картинку (~15 МБ) — фон мигал, пока окно тянут.
///
/// Стало — как в Telegram Desktop (`chat_theme.cpp`, `CacheBackgroundByRequest`):
/// узор масштабируется по ВЫСОТЕ области и повторяется колонками от центра,
/// нечётным числом колонок. Шире окно — больше колонок, а не крупнее дудлы.
/// Цветовые пятна живых обоев по-прежнему на всю область. Декодируется картинка
/// один раз на плотность пикселей, до постоянной высоты: ширина окна на
/// декодирование больше не влияет вовсе.
///
/// КАК СТЫКУЮТСЯ КОЛОНКИ — ПО ЗАМЕРАМ (30.09.2026, отчёт О1).
///
/// Настоящей бесшовной плитки у нас нет, и собрать её автоматически нельзя:
///   • у маски живых обоев краем обрезаны 36 дудлов из 525 (21 слева, 15
///     справа). Пары одинаковых путей «через пустоту» сверху донизу, которые
///     дали бы бесшовную плитку без перерисовки, нет ни при каком периоде от
///     700 до 1620 px;
///   • статичные обои — 12 JPEG, где градиент и узор запечены вместе. Собрать
///     их слоями из общей маски нельзя, не изменив вид: рисунок тот же
///     (корреляция 0.80 ровно при нулевом сдвиге, масштаб 8/9), но линии в
///     JPEG в ~4 раза толще, чем в маске, и с фактурой.
/// Остаются два честных стыка, и у каждого своя цена:
///   • ПОВТОР — дудлы не отражены, узор читается как обычные обои; на стыке
///     обрезанные краем дудлы встречаются половинками. Если края картинки
///     разного цвета, на каждом стыке ещё и видна вертикальная «штора»;
///   • ЗЕРКАЛО — непрерывно при любой картинке, но у каждого стыка узор
///     симметричен: пары дудлов-близнецов «как в калейдоскопе», и это
///     бросается в глаза сильнее половинок.
/// Поэтому повтор — везде, где края совпадают по цвету: у живых обоев (цвет
/// там рисуют пятна на всю область, маска — только линии) и у трёх светлых
/// картинок с чисто вертикальным градиентом. Скачок цвета на их стыке не
/// больше, чем между любыми соседними полосами картинки (0,81–0,82 от обычного).
/// Остальным девяти — зеркало: у них стык по цвету в 1,6–6,9 раза резче
/// обычного, это видимая линия. Фронт волны «проводит сообщение» на стыке
/// повтора сдвигается на 11–17 px — в пределах обычного разброса самого поля
/// между соседними участками (медиана 7–11 px, у каждого десятого — 18–26).
///
/// Появится свой бесшовный узор — всем картинкам станет можно повтор.
///
/// 🔴 ПОСТОЯННЫЙ РАЗМЕР УЗОРА И РЯДЫ (01.10.2026, владелец: «фоны генеративно
/// расширяются, не растягиваются — увеличивается количество узоров»). По
/// высоте области масштаб шёл вслед за окном: выше окно — крупнее дудлы, то
/// есть по вертикали узор всё-таки «растягивался». Теперь в переписке плитка
/// узора всегда [kDesktopWallpaperTileHeight] логических точек в высоту: шире
/// окно — больше колонок, выше — больше рядов, дудлы одного размера. Ряды
/// растут от НИЗА (там поле ввода и новые сообщения): тянешь окно — узор у
/// поля стоит на месте. Стык рядов: у живых обоев повтор (маска — только
/// линии), у картинок зеркало (градиент в JPEG сверху вниз, повтор дал бы
/// ступеньку цвета). Поле волны «проводит сообщение» остаётся по высоте
/// области: свет всё равно виден только на линиях (маска `dstIn`), а
/// непрерывный фронт на высоком окне важнее точного следования дудлам.
/// Плитки выбора статичных картинок — по-прежнему целиком по высоте (виден
/// весь градиент), живые — настоящим масштабом, куском как в чате.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../widgets/telegram_wallpaper.dart' show WallpaperPatternLayout;

/// Стык колонок живых обоев: повтор (см. шапку). Маска — только линии, цвет
/// рисуют пятна на всю область, поэтому «шторы» тут не бывает.
const TileMode kDesktopLiveWallpaperTileMode = TileMode.repeated;

/// Картинки набора, чьи левый и правый края совпадают по цвету, — им повтор.
///
/// Замер (высота чата 900, полосы по 24 px по обе стороны стыка): скачок
/// цвета на стыке против того же скачка в обычных местах картинки — мята
/// 0,81, персик 0,82, небо 0,82. У остальных 1,6 (лаванда) … 6,9 (светлая
/// стандартная): на стыке видна линия, им — зеркало. Список сверяет с самими
/// картинками тест `desktop_wallpaper_tiling_test.dart`.
const Set<String> kDesktopWallpaperRepeatAssets = <String>{
  'wallpaper_light_mint.jpg',
  'wallpaper_light_peach.jpg',
  'wallpaper_light_sky.jpg',
};

/// Стык колонок для картинки набора [assetPath]: повтор, если её края
/// совпадают по цвету, иначе зеркало.
TileMode desktopWallpaperTileModeFor(String assetPath) {
  final slash = assetPath.lastIndexOf('/');
  final name = slash < 0 ? assetPath : assetPath.substring(slash + 1);
  return kDesktopWallpaperRepeatAssets.contains(name)
      ? TileMode.repeated
      : TileMode.mirror;
}

/// Самая высокая панель переписки, под которую декодируются обои, в
/// логических пикселях.
///
/// 1600 покрывает окно во весь экран 4K при 150 % и 5K при 200 %. Выше —
/// лёгкое растяжение на самых высоких мониторах, а не лишняя память у всех:
/// при 100 % картинка занимает 5,8 МБ вместо прежних до 14,7.
const double kDesktopWallpaperMaxChatHeight = 1600;

/// Высота одной плитки узора в переписке, в логических точках (01.10.2026).
///
/// Дудл при ней ~47 точек — как на телефоне (~45). Окно выше — узор
/// достраивается рядами, ниже — плитка обрезается сверху, но не сжимается.
const double kDesktopWallpaperTileHeight = 900;

/// Высота декодирования плиток выбора статичных обоев, в физических пикселях:
/// плитка ~165 логических в высоту, при 200 % — 330, запас есть.
///
/// Только для картинок: у них линии толстые и мелкий декод их не портит.
/// Маска живых обоев в плитках декодируется как в чате — её линии в 1,3 px
/// при уменьшении в 6 раз рассыпаются в искры (проверено снимком), а общий
/// с чатом ключ кэша и так не стоит лишней памяти.
const int kDesktopWallpaperPreviewDecodeHeight = 480;

/// Плоская плитка превью рисуется как полоса окна переписки не площе 4:3.
///
/// Карточка набора во «Внешнем виде» — 64 px в высоту при ширине ~250. Узор
/// по её собственной высоте — это колонки по 36 px и мелкая рябь вместо
/// дудлов, на обоях так не бывает. Поэтому превью строится для окна высотой
/// не меньше ширины × 3/4, а показывается его средняя полоса — как в чате.
const double kDesktopWallpaperPreviewMinHeightRatio = 0.75;

/// Раскладка узора по высоте области.
@immutable
class DesktopPatternTiling {
  const DesktopPatternTiling({
    required this.scale,
    required this.columnWidth,
    required this.columns,
    required this.originX,
    this.originY = 0,
  });

  /// Раскладка для пустой области или пустой картинки: рисовать нечего.
  static const DesktopPatternTiling empty = DesktopPatternTiling(
    scale: 0,
    columnWidth: 0,
    columns: 0,
    originX: 0,
  );

  /// Логических пикселей на пиксель картинки: высота области / высота
  /// картинки. От ширины не зависит — в этом весь смысл.
  final double scale;

  /// Ширина одной колонки (картинки целиком), логические пиксели.
  final double columnWidth;

  /// Сколько колонок нужно, чтобы закрыть ширину: нечётное, как у Telegram, —
  /// центральная и поровну по бокам.
  final int columns;

  /// Левый край центральной колонки. Она стоит ровно посередине области.
  final double originX;

  /// Где начинается плитка по вертикали, в точках области: ряды растут от
  /// низа, поэтому у окна выше плитки это отрицательное число (01.10.2026).
  final double originY;

  /// Левый край самой левой колонки (`xshift` у Telegram).
  double get firstColumnX => originX - (columns ~/ 2) * columnWidth;

  @override
  bool operator ==(Object other) =>
      other is DesktopPatternTiling &&
      other.scale == scale &&
      other.columnWidth == columnWidth &&
      other.columns == columns &&
      other.originX == originX &&
      other.originY == originY;

  @override
  int get hashCode =>
      Object.hash(scale, columnWidth, columns, originX, originY);

  @override
  String toString() =>
      'DesktopPatternTiling(scale: $scale, columnWidth: $columnWidth, '
      'columns: $columns, originX: $originX, originY: $originY)';
}

/// Раскладка картинки размером [image] на область [area]: масштаб по высоте,
/// колонки от центра, нечётным числом — формула Telegram Desktop:
/// `cols = ((ceil(W / w) / 2) * 2) + 1`.
///
/// Размер картинки — любой, с которым она декодирована: колонка зависит только
/// от ПРОПОРЦИИ картинки и высоты области, поэтому декод при 100 % и при 200 %
/// раскладываются одинаково.
DesktopPatternTiling desktopPatternTiling({
  required Size area,
  required Size image,
  double? tileHeight,
}) {
  if (area.isEmpty || image.isEmpty || !area.isFinite || !image.isFinite) {
    return DesktopPatternTiling.empty;
  }
  // [tileHeight] задан — плитка постоянного размера, ряды от низа области;
  // не задан — плитка во всю высоту области (плитки выбора картинок).
  final rowHeight =
      tileHeight != null && tileHeight > 0 ? tileHeight : area.height;
  final scale = rowHeight / image.height;
  final columnWidth = image.width * scale;
  final needed = (area.width / columnWidth).ceil();
  return DesktopPatternTiling(
    scale: scale,
    columnWidth: columnWidth,
    columns: (needed ~/ 2) * 2 + 1,
    originX: (area.width - columnWidth) / 2,
    originY: area.height - rowHeight,
  );
}

/// Высота, до которой декодируются обои ПК, в физических пикселях.
///
/// 🔴 ЗАВИСИТ ТОЛЬКО ОТ ПЛОТНОСТИ ПИКСЕЛЕЙ — не от размера окна. Узор рисуется
/// по высоте области, и эта высота — самая большая, какая бывает у панели
/// переписки. Раньше обои декодировались по ширине окна, и каждый шаг
/// растягивания окна был новым ключом кэша, то есть новым декодированием
/// ~15 МБ — отсюда и мигание (ТЗ О1 §8.4).
int desktopWallpaperDecodeHeight({
  required double devicePixelRatio,
  bool preview = false,
}) {
  if (preview) return kDesktopWallpaperPreviewDecodeHeight;
  final dpr = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio.clamp(1.0, 4.0)
      : 1.0;
  return (kDesktopWallpaperMaxChatHeight * dpr).ceil();
}

/// [source], декодированный до высоты [desktopWallpaperDecodeHeight].
///
/// `allowUpscaling: false`: картинка ниже этой высоты декодируется как есть —
/// раздувать её значит тратить память и мылить линии. Ключ кэша — источник и
/// высота, ширины окна в нём нет.
ImageProvider<Object> desktopWallpaperImage(
  ImageProvider<Object> source, {
  required double devicePixelRatio,
  bool preview = false,
}) => ResizeImage(
  source,
  height: desktopWallpaperDecodeHeight(
    devicePixelRatio: devicePixelRatio,
    preview: preview,
  ),
  allowUpscaling: false,
);

/// Матрица шейдера картинки: пиксель картинки → логическая точка области
/// с левым верхним углом в [origin].
Float64List desktopPatternMatrix(DesktopPatternTiling tiling, Offset origin) {
  final m = Float64List(16);
  m[0] = tiling.scale;
  m[5] = tiling.scale;
  m[10] = 1;
  m[15] = 1;
  m[12] = origin.dx + tiling.originX;
  m[13] = origin.dy + tiling.originY;
  return m;
}

/// Рисует [image] на всю [rect] по раскладке: по высоте, колонками от центра,
/// стык колонок — [tileMode] (повтор или зеркало, см. шапку).
///
/// Одним прямоугольником с шейдером картинки, а не картинкой на каждую
/// колонку: у колонок, нарисованных по отдельности, на стыках остаются
/// полупиксели двойного или пропущенного покрытия, а маска живых обоев
/// (`dstIn`) превращает их в светлые или тёмные нитки. Шейдер кладёт колонки
/// встык без единого шва.
void paintDesktopPattern(
  Canvas canvas,
  ui.Image image,
  Rect rect,
  Paint paint, {
  required TileMode tileMode,
  double? tileHeight,
  TileMode rowTileMode = TileMode.clamp,
}) {
  final tiling = desktopPatternTiling(
    area: rect.size,
    image: Size(image.width.toDouble(), image.height.toDouble()),
    tileHeight: tileHeight,
  );
  if (tiling.columns == 0) return;
  final shader = ImageShader(
    image,
    tileMode,
    rowTileMode,
    desktopPatternMatrix(tiling, rect.topLeft),
    filterQuality: paint.filterQuality,
  );
  canvas.drawRect(rect, paint..shader = shader);
  paint.shader = null;
  // Нарисованное уже держит свою ссылку на шейдер — свою можно отпустить.
  shader.dispose();
}

// ── Поле волны «проводит сообщение» ─────────────────────────────────────────

/// Сборка поля по колонкам — на картинку поля, пока та жива.
final Expando<_ComposedField> _composedFields = Expando<_ComposedField>(
  'desktop wallpaper field',
);

class _ComposedField {
  _ComposedField(this.columns, this.tileMode, this.image);

  final int columns;
  final TileMode tileMode;
  final ui.Image image;
}

/// Поле волны, разложенное теми же колонками и тем же стыком [tileMode], что
/// и маска.
///
/// Шейдер волны общий с телефоном и читает поле одним прямоугольником
/// «масштаб + сдвиг», без повтора и отражения. Поэтому поле раскладывается
/// заранее: картинка из нечётного числа колонок поля, центральная как есть,
/// соседние — повтор или отражение, ровно как у маски. Сборка — одна на
/// картинку поля и число колонок (270×480 на колонку, ~0,5 МБ), а не на кадр:
/// ширина окна меняет только прямоугольник.
///
/// Возвращает картинку и её прямоугольник (в её пикселях), ложащийся на всю
/// область [size], — ту же пару, что «покрытие» у телефона.
(ui.Image, Rect) desktopPatternFieldSource(
  ui.Image field,
  Size size, {
  required TileMode tileMode,
}) {
  final fw = field.width.toDouble();
  final fh = field.height.toDouble();
  final tiling = desktopPatternTiling(area: size, image: Size(fw, fh));
  if (tiling.columns == 0) return (field, Rect.fromLTWH(0, 0, fw, fh));
  var composed = _composedFields[field];
  if (composed == null ||
      composed.columns < tiling.columns ||
      composed.tileMode != tileMode) {
    // Не меньше пяти колонок: окно чаще всего растягивают, а не сужают, и
    // запас избавляет от пересборки на первом же шаге.
    final n = math.max(tiling.columns, 5);
    final previous = composed;
    composed = _ComposedField(n, tileMode, _composeField(field, n, tileMode));
    _composedFields[field] = composed;
    previous?.image.dispose();
  }
  final n = composed.columns;
  final firstX = tiling.originX - (n ~/ 2) * tiling.columnWidth;
  return (
    composed.image,
    Rect.fromLTWH(
      -firstX / tiling.columnWidth * fw,
      0,
      size.width / tiling.columnWidth * fw,
      fh,
    ),
  );
}

ui.Image _composeField(ui.Image field, int columns, TileMode tileMode) {
  final w = field.width;
  final h = field.height;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final m = Float64List(16)
    ..[0] = 1
    ..[5] = 1
    ..[10] = 1
    ..[15] = 1
    ..[12] = ((columns ~/ 2) * w).toDouble();
  // Пиксель в пиксель: поле копируется, а не масштабируется, — фильтр не нужен.
  final shader = ImageShader(
    field,
    tileMode,
    TileMode.clamp,
    m,
    filterQuality: FilterQuality.none,
  );
  canvas.drawRect(
    Rect.fromLTWH(0, 0, (columns * w).toDouble(), h.toDouble()),
    Paint()..shader = shader,
  );
  shader.dispose();
  final picture = recorder.endRecording();
  final image = picture.toImageSync(columns * w, h);
  picture.dispose();
  return image;
}

/// Раскладка живых обоев ПК для общего `TelegramWallpaper`: маска и поле
/// волны — по высоте, колонками от центра, стык —
/// [kDesktopLiveWallpaperTileMode].
///
/// Одна на чат и плитки выбора: маска у всех декодируется одинаково (см.
/// [kDesktopWallpaperPreviewDecodeHeight]) — один ключ кэша на всё окно.
@immutable
class DesktopTiledPatternLayout extends WallpaperPatternLayout {
  const DesktopTiledPatternLayout();

  @override
  ImageProvider maskProvider(ImageProvider mask, MediaQueryData? media) =>
      desktopWallpaperImage(
        mask,
        devicePixelRatio: media?.devicePixelRatio ?? 1.0,
      );

  @override
  void paintMask(Canvas canvas, ui.Image mask, Rect rect, Paint paint) =>
      paintDesktopPattern(
        canvas,
        mask,
        rect,
        paint,
        tileMode: kDesktopLiveWallpaperTileMode,
        tileHeight: kDesktopWallpaperTileHeight,
        rowTileMode: kDesktopLiveWallpaperTileMode,
      );

  @override
  (ui.Image, Rect) fieldSource(ui.Image field, Size size) =>
      desktopPatternFieldSource(
        field,
        size,
        tileMode: kDesktopLiveWallpaperTileMode,
      );

  @override
  bool operator ==(Object other) => other is DesktopTiledPatternLayout;

  @override
  int get hashCode => (DesktopTiledPatternLayout).hashCode;
}

/// Высота окна, для которого строится превью обоев в плитке [tile] — см.
/// [kDesktopWallpaperPreviewMinHeightRatio]. Вытянутые вверх плитки (3:4)
/// остаются как есть.
double desktopWallpaperPreviewHeight(Size tile) =>
    math.max(tile.height, tile.width * kDesktopWallpaperPreviewMinHeightRatio);

/// Статичные обои-картинка на ПК: по высоте области, колонками от центра.
///
/// Картинка — та же, что у телефона, целиком, с градиентом и узором: в
/// центральной колонке она ровно такая, как задумана, и всегда целиком по
/// высоте.
class DesktopTiledWallpaperImage extends StatefulWidget {
  const DesktopTiledWallpaperImage({
    super.key,
    required this.image,
    this.tileMode = TileMode.mirror,
    this.preview = false,
  });

  /// Исходная картинка, без уменьшения: до какой высоты декодировать, решает
  /// [desktopWallpaperDecodeHeight].
  final ImageProvider<Object> image;

  /// Стык колонок; для картинок набора — [desktopWallpaperTileModeFor].
  /// По умолчанию зеркало: оно непрерывно при любой картинке.
  final TileMode tileMode;

  /// Плитка выбора обоев: декодируется мелко.
  final bool preview;

  @override
  State<DesktopTiledWallpaperImage> createState() =>
      _DesktopTiledWallpaperImageState();
}

class _DesktopTiledWallpaperImageState
    extends State<DesktopTiledWallpaperImage> {
  ImageProvider<Object>? _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(DesktopTiledWallpaperImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image || oldWidget.preview != widget.preview) {
      _resolve();
    }
  }

  void _resolve() {
    // Подписка только на плотность пикселей: изменение размера окна сюда
    // даже не доходит. Сменилась плотность (окно ушло на другой монитор) —
    // новый ключ, новое декодирование, это правильно.
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final provider = desktopWallpaperImage(
      widget.image,
      devicePixelRatio: dpr,
      preview: widget.preview,
    );
    if (provider == _provider) return;
    _provider = provider;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    final listener = _listener ??= ImageStreamListener(
      _onImage,
      onError: (error, _) {
        // Нет картинки — нет обоев, под ними фон панели. Прежняя картинка
        // (если была) остаётся, пока не придёт новая.
        if (!kReleaseMode) {
          debugPrint('DesktopTiledWallpaperImage: $error');
        }
      },
    );
    _stream?.removeListener(listener);
    _stream = stream..addListener(listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    // Слушатель получает свою копию картинки и сам её отпускает. Прежняя
    // остаётся на экране, пока не придёт новая: смена темы без вспышки.
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _info?.dispose();
      _info = info;
    });
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _info?.dispose();
    _info = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Свой слой: переписка над обоями прокручивается каждый кадр, а обои от
    // этого не меняются — перерисовывать их незачем.
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _TiledImagePainter(
          _info?.image,
          widget.tileMode,
          preview: widget.preview,
        ),
      ),
    );
  }
}

class _TiledImagePainter extends CustomPainter {
  _TiledImagePainter(this.image, this.tileMode, {this.preview = false});

  final ui.Image? image;
  final TileMode tileMode;

  /// Плитка выбора: картинка целиком по высоте, чтобы был виден весь
  /// градиент. В переписке — плитка постоянного размера и ряды (см. шапку).
  final bool preview;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) return;
    paintDesktopPattern(
      canvas,
      img,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
      tileMode: tileMode,
      tileHeight: preview ? null : kDesktopWallpaperTileHeight,
      // Зеркало: градиент картинки сверху вниз на стыке рядов не ломается.
      rowTileMode: preview ? TileMode.clamp : TileMode.mirror,
    );
  }

  @override
  bool shouldRepaint(_TiledImagePainter old) =>
      old.image != image || old.tileMode != tileMode || old.preview != preview;
}
