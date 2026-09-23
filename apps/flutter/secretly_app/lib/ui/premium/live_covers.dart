// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// 🔴 ЖИВЫЕ ОБЛОЖКИ: двадцать четыре сцены из набора `profile_fx`.
//
// Отдельно от `live_frames.dart` по той же причине, по какой рамки отделены от
// атласа: здесь другой предмет. Общее — только правило про тикер.
import 'package:flutter/material.dart';

import '../thermal_guard.dart';
import 'cosmetic_animation_scope.dart';
import 'profile_fx.dart' as fx;

/// Идентификатор обложки в профиле → сцена набора.
///
/// 🔴 ЧЕТЫРЁХ СЦЕН НАБОРА ЗДЕСЬ НЕТ, И ЭТО НЕ ЗАБЫВЧИВОСТЬ. «Светлячки»,
/// «Салют», «Галактика» и «Чёрная дыра» у нас уже есть — своей реализацией, и
/// «Чёрная дыра» вдобавок единственная умеет пускать фотографию ВНУТРЬ сцены
/// (передний слой поверх портрета). Подменить их набором значит молча изменить
/// то, что человек уже выбрал. Нужна замена — это решение владельца, не
/// побочный итог переноса.
const Map<String, fx.ProfileCoverStyle> kLiveCoverKinds =
    <String, fx.ProfileCoverStyle>{
  'snow': fx.ProfileCoverStyle.snow,
  // 🔴 `aurora` и `sakura` уже заняты РАМКАМИ («Аврора», «Сакура»), а
  // таблица переводов имён общая для рамок и обложек — одинаковый ключ дал
  // бы обложке чужое имя. Отсюда суффикс.
  'aurora_fx': fx.ProfileCoverStyle.aurora,
  'embers': fx.ProfileCoverStyle.embers,
  'mesh': fx.ProfileCoverStyle.mesh,
  'starfall': fx.ProfileCoverStyle.starfall,
  'synthwave': fx.ProfileCoverStyle.synthwave,
  'bokeh': fx.ProfileCoverStyle.bokeh,
  'ocean': fx.ProfileCoverStyle.ocean,
  'rain_glass': fx.ProfileCoverStyle.rainGlass,
  'soap_bubbles': fx.ProfileCoverStyle.soapBubbles,
  'topography': fx.ProfileCoverStyle.topography,
  'silk': fx.ProfileCoverStyle.silk,
  'constellations': fx.ProfileCoverStyle.constellations,
  'sakura_fx': fx.ProfileCoverStyle.sakura,
  'clouds': fx.ProfileCoverStyle.clouds,
  'night_city': fx.ProfileCoverStyle.nightCity,
  'flow': fx.ProfileCoverStyle.flow,
  'hologram': fx.ProfileCoverStyle.hologram,
  'dot_ocean': fx.ProfileCoverStyle.dotOcean,
  'kaleidoscope': fx.ProfileCoverStyle.kaleidoscope,
  'eclipse': fx.ProfileCoverStyle.eclipse,
  'moon_path': fx.ProfileCoverStyle.moonPath,
  'ripples': fx.ProfileCoverStyle.ripples,
  'spotlight': fx.ProfileCoverStyle.spotlight,
};

List<String> get kLiveCoverIds => kLiveCoverKinds.keys.toList(growable: false);

bool isLiveCoverId(String? id) => id != null && kLiveCoverKinds.containsKey(id);

/// Сцена построена ВОКРУГ фотографии: портрет в ней — луна, камень, предмет
/// под прожектором. Такой сцене нужно знать, где стоит аватар.
bool liveCoverUsesAvatar(String? id) =>
    kLiveCoverKinds[id]?.usesAvatar ?? false;

/// Где на обложке стоит портрет — доли от её ширины и высоты.
///
/// 🔴 НАСЛЕДУЕМОЙ, А НЕ ПАРАМЕТРОМ. Обложку строит `coverBackWidgetFor` — она
/// общая для телефона, компьютера и плиток выбора и о раскладке экрана ничего
/// не знает. Экран, который знает, кладёт геометрию над обложкой, и её берут
/// только те сцены, которым она нужна.
class CoverAvatarGeometry extends InheritedWidget {
  const CoverAvatarGeometry({
    super.key,
    required this.center,
    required this.radius,
    required super.child,
  });

  final Offset center;
  final double radius;

  static CoverAvatarGeometry? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoverAvatarGeometry>();

  @override
  bool updateShouldNotify(CoverAvatarGeometry old) =>
      old.center != center || old.radius != radius;
}

/// Живая обложка. Заполняет отведённое место.
class LiveCoverView extends StatelessWidget {
  const LiveCoverView({
    super.key,
    required this.id,
    this.avatarCenter,
    this.avatarRadius,
    this.animate = true,
    this.interactive = true,
  });

  final String id;

  /// Где на обложке стоит портрет — в долях ширины и высоты. Нужно сценам,
  /// построенным вокруг фотографии.
  final Offset? avatarCenter;
  final double? avatarRadius;

  final bool animate;

  /// Сцена следит за пальцем и отзывается на касание. Выключается в плитках
  /// выбора: там сцен два десятка сразу, и слушатель на каждой ни к чему.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final style = kLiveCoverKinds[id];
    if (style == null) return const SizedBox.shrink();
    // Явно переданное важнее наследуемого: плитка выбора рисует сцену без
    // портрета и должна показывать её «как есть».
    final geo = CoverAvatarGeometry.of(context);
    final center = avatarCenter ?? geo?.center ?? const Offset(0.5, 0.36);
    final radius = avatarRadius ?? geo?.radius ?? 0.1;
    // 🔴 Те же четыре условия, что и у рамок: настройка «украшения
    // собеседников», немой тикер под закрытым маршрутом, «меньше движения» в
    // системе и нагрев. Набор сам смотрит только на TickerMode и «меньше
    // движения», поэтому остальные два мы гасим снаружи.
    final allowed =
        animate &&
        CosmeticAnimationScope.of(context) &&
        TickerMode.valuesOf(context).enabled &&
        ThermalGuard.effectsAllowed.value;
    return RepaintBoundary(
      child: fx.ProfileCover(
        style: style,
        animate: allowed,
        avatarCenter: center,
        avatarRadius: radius,
        // 🔴 Касание СЦЕНЫ разрешено. `Listener` в наборе не участвует в
        // разборе жестов и потому не отбирает нажатия у имени, кнопок и
        // потягивания шапки — те лежат выше в стопке и получают событие
        // первыми. Зато круги на воде идут от пальца, а прожектор следит за
        // ним, как и задумано.
        interactive: interactive && allowed,
      ),
    );
  }
}

/// Нижний край обложки, уходящий в прозрачность.
///
/// 🔴 ЗАЧЕМ ВМЕСТО СЛОЯ «ПОД ЦВЕТ СТРАНИЦЫ». Раньше низ обложки прятали
/// отдельной плашкой цвета фона, которая тянулась ниже обложки. На стыке она
/// лежала одновременно на краю картинки и на самой странице, и там, где под
/// полупрозрачной плашкой оказывались разные пиксели, выходила линия — на
/// тёмной теме почти незаметная, на светлой резкая (сообщил владелец
/// 24.09.2026). К тому же плашку приходилось подгонять под цвет фона каждой
/// темы.
///
/// Здесь обложка САМА теряет непрозрачность к низу: под ней просто видна
/// страница, какой бы та ни была. Подгонять нечего — и стыка нет.
///
/// Ширина перехода задана в ТОЧКАХ, а не долей высоты: обложки бывают разной
/// высоты, а переход должен выглядеть одинаково — мягким, но коротким.
class CoverBottomFade extends StatelessWidget {
  const CoverBottomFade({super.key, required this.child, this.fade = 56});

  final Widget child;

  /// Высота перехода в логических точках.
  final double fade;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (bounds) {
      final h = bounds.height <= 0 ? 1.0 : bounds.height;
      final start = ((h - fade) / h).clamp(0.0, 1.0);
      // Кривая, а не прямая: линейный спад прозрачности глаз читает как
      // «полосу» у начала перехода. Промежуточные точки дают мягкое плечо.
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0xB3FFFFFF),
          Color(0x40FFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: [
          0,
          start,
          start + (1 - start) * 0.35,
          start + (1 - start) * 0.72,
          1,
        ],
      ).createShader(bounds);
    },
    child: child,
  );
}

/// `IgnorePointer`, который можно отключить.
///
/// Нужен там, где слой обычно прозрачен для нажатий, но иногда обязан их
/// слышать: живая обложка отзывается на палец, а фотография или видео на её
/// месте — нет.
class LiveCoverTouch extends StatelessWidget {
  const LiveCoverTouch({super.key, required this.listen, required this.child});

  final bool listen;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      listen ? child : IgnorePointer(child: child);
}
