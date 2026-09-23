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

/// Живая обложка. Заполняет отведённое место.
class LiveCoverView extends StatelessWidget {
  const LiveCoverView({
    super.key,
    required this.id,
    this.avatarCenter = const Offset(0.5, 0.36),
    this.avatarRadius = 0.1,
    this.animate = true,
  });

  final String id;

  /// Где на обложке стоит портрет — в долях ширины и высоты. Нужно сценам,
  /// построенным вокруг фотографии.
  final Offset avatarCenter;
  final double avatarRadius;

  final bool animate;

  @override
  Widget build(BuildContext context) {
    final style = kLiveCoverKinds[id];
    if (style == null) return const SizedBox.shrink();
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
        avatarCenter: avatarCenter,
        avatarRadius: avatarRadius,
        // Обложка — фон под именем и кнопками: она не должна перехватывать
        // нажатия, которые человек адресует им.
        interactive: false,
      ),
    );
  }
}
