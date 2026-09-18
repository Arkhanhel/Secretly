// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

/// 🔴 ЗУМ ПО ВСЕМУ ЭКРАНУ, а не внутри рамки медиа.
///
/// Полевой отчёт (02.08.2026): «если фото или видео после открытия не на весь
/// экран, то при увеличении оно увеличивается только внутри своей коробки».
///
/// ПРИЧИНА. `InteractiveViewer` обрезает по СВОЕМУ размеру. Если положить его
/// под `Center` и дать внутрь `Image(fit: contain)` или `AspectRatio`, то он
/// сжимается ровно по кадру: у горизонтального фото на вертикальном экране это
/// узкая полоса посередине. Дальше всё честно и бесполезно — картинка при
/// увеличении растёт, но видно её только в исходной полосе, а чёрные поля
/// сверху и снизу так и остаются чёрными.
///
/// ЛЕЧЕНИЕ. Область зума — ВЕСЬ доступный прямоугольник; кадр живёт внутри неё.
/// Тогда увеличение занимает экран целиком, и щипок, начатый на чёрном поле,
/// тоже работает.
///
/// ЧТО ПЕРЕДАВАТЬ В [child]:
///  * **фото** — `Image(fit: BoxFit.contain)` напрямую. Он получит ЖЁСТКИЕ
///    размеры во весь прямоугольник, и `contain` впишет снимок по ширине, не
///    растягивая. Заодно небольшой снимок перестанет открываться марочкой
///    посередине — `contain` увеличит его до экрана, сохранив пропорции;
///  * **видео и всё, что само держит пропорции** — `Center(child:
///    AspectRatio(...))`. Под жёсткими размерами `AspectRatio` не может ничего
///    выбрать и просто отдаёт их обратно, поэтому ему нужен `Center`, который
///    вернёт свободу выбора.
class FullBleedZoom extends StatelessWidget {
  const FullBleedZoom({
    super.key,
    required this.child,
    this.transformationController,
    this.minScale = 1.0,
    this.maxScale = 4.0,
    this.onInteractionEnd,
  });

  final Widget child;
  final TransformationController? transformationController;
  final double minScale;
  final double maxScale;
  final void Function(ScaleEndDetails)? onInteractionEnd;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: transformationController,
      minScale: minScale,
      maxScale: maxScale,
      onInteractionEnd: onInteractionEnd,
      // Вся суть правки — в этом `SizedBox.expand`. Всё остальное осталось тем
      // же, включая разбор жестов у вызывающих: щипок и «смахнуть вниз» уже
      // разведены по числу пальцев, и трогать это нельзя.
      child: SizedBox.expand(child: child),
    );
  }
}
