// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../profile_fx.dart';

/// 🔴 ЕДИНСТВЕННЫЙ ФАЙЛ ЭТОГО НАБОРА, КОТОРЫЙ НАПИСАН НЕ ГЕНЕРАТОРОМ.
///
/// Остальные восемь — выгрузка со страницы дизайна, и править их нельзя:
/// следующая выгрузка затрёт правки, а расхождение с макетом мы заметим уже
/// на экране. Всё, что нужно приложению сверх открытого набора, живёт здесь.
///
/// Нужно ровно одно: получить симуляцию рамки отдельно от виджета.
/// `AnimatedAvatarFrame` рисует фотографию сам, а у нас её рисует вызывающая
/// сторона — портрет собирают `FramedAvatar` и `Avatar`, — и рамка ложится
/// сверху прозрачной накладкой. Фабрика `_create` закрыта, но этот файл
/// является частью той же библиотеки и потому её видит.
/// Наши рамки, которых в перечислении набора нет вовсе: «Дрифт» и
/// «Космонавт» пришли отдельной посылкой, см. `extras_drift_astro.dart`.
FrameSim? createOwnFrameSim(String id) => switch (id) {
  'drift' => DriftFrame(),
  'astronaut' => AstronautFrame(),
  _ => null,
};

FrameSim createFrameSim(AvatarFrame frame) => switch (frame) {
  // 🔴 Две рамки мы рисуем СВОИМИ классами, см. `extras.dart`: у наборного
  // слайма кольцо ровной толщины и капли по таймеру, а у наборной луны
  // полумесяц вырезан заливкой цвета фона — на светлой обложке это чёрная
  // клякса. Остальные двадцать два приходят из выгрузки как есть.
  AvatarFrame.slime => SlimeFrame(),
  AvatarFrame.sleep => SleepFrame(),
  _ => frame._create(),
};
