// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

class DType {
  DType._();

  /// 🔴 ШРИФТ МАКЕТА — MANROPE, А НЕ INTER (14.09.2026).
  ///
  /// Здесь стоял `Inter`, и я сказал владельцу, что это «то же семейство, что
  /// в макете». Это было НЕВЕРНО: в исходнике макета
  /// (`Secretly Desktop Pro.html`) стоит `font-family:Manrope,system-ui`.
  /// Ошибка проверяется в одну строку — и именно поэтому её стоит записать:
  /// сверять шрифт надо ПО ИСХОДНИКУ макета, а не по виду на снимке, где
  /// гротески без засечек похожи друг на друга.
  ///
  /// Мобильную версию это не касается: её типографика живёт отдельно и
  /// осталась на Inter. Manrope читает только десктопное окно.
  static const String family = 'Manrope';

  static const TextStyle display = TextStyle(
    fontFamily: family,
    // Explicit: without it a style inherits `decoration` from the ambient
    // DefaultTextStyle, which outside a Material ancestor is Flutter's error
    // style — yellow double underline under every label.
    decoration: TextDecoration.none,
    fontSize: 22,
    // 22/800/-0.02em — прямо из исходника макета
    // (`font-size:22px;font-weight:800;letter-spacing:-0.02em`). Трекинг
    // Flutter принимает в ТОЧКАХ: 22 × 0.02 = 0.44.
    fontWeight: FontWeight.w800,
    letterSpacing: -0.44,
    height: 28 / 22,
  );

  static const TextStyle title = TextStyle(
    fontFamily: family,
    // Explicit: without it a style inherits `decoration` from the ambient
    // DefaultTextStyle, which outside a Material ancestor is Flutter's error
    // style — yellow double underline under every label.
    decoration: TextDecoration.none,
    fontSize: 16,
    // 16/800 — в макете шестнадцатый кегль встречается только с весом 800.
    fontWeight: FontWeight.w800,
    letterSpacing: -0.24,
    height: 22 / 16,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    // Explicit: without it a style inherits `decoration` from the ambient
    // DefaultTextStyle, which outside a Material ancestor is Flutter's error
    // style — yellow double underline under every label.
    decoration: TextDecoration.none,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: family,
    // Explicit: without it a style inherits `decoration` from the ambient
    // DefaultTextStyle, which outside a Material ancestor is Flutter's error
    // style — yellow double underline under every label.
    decoration: TextDecoration.none,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
  );

  static const TextStyle label = TextStyle(
    fontFamily: family,
    // Explicit: without it a style inherits `decoration` from the ambient
    // DefaultTextStyle, which outside a Material ancestor is Flutter's error
    // style — yellow double underline under every label.
    decoration: TextDecoration.none,
    fontSize: 13,
    // 🔴 ВЕСА 500 В МАКЕТЕ НЕТ НИ ОДНОГО РАЗА (проверено по исходнику:
    // 400 — 3 раза, 600 — 34, 700 — 92, 800 — 58). Он стоял здесь и в [tiny]
    // «по ощущению», и от этого подписи выглядели бледнее макета всюду разом.
    fontWeight: FontWeight.w600,
    height: 18 / 13,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    // Explicit: without it a style inherits `decoration` from the ambient
    // DefaultTextStyle, which outside a Material ancestor is Flutter's error
    // style — yellow double underline under every label.
    decoration: TextDecoration.none,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
  );

  static const TextStyle tiny = TextStyle(
    fontFamily: family,
    // Explicit: without it a style inherits `decoration` from the ambient
    // DefaultTextStyle, which outside a Material ancestor is Flutter's error
    // style — yellow double underline under every label.
    decoration: TextDecoration.none,
    fontSize: 11,
    // См. [label]: веса 500 в макете нет.
    fontWeight: FontWeight.w600,
    height: 14 / 11,
  );

  // ── Стили из макета, которых шкале не хватало ──────────────────────────
  //
  // 🔴 ПОЧЕМУ ИХ ПРИШЛОСЬ ЗАВЕСТИ (14.09.2026, разбор исходника макета).
  //
  // Заголовки в макете набраны весом 700–800 с ОТРИЦАТЕЛЬНЫМ трекингом
  // (-0.015…-0.02em), а в шкале выше самый жирный вес — 600 и трекинга нет ни
  // у одного стиля. Разметка добирала недостающее руками: по всему
  // `lib/ui/desktop` набралось больше пятидесяти самодельных `TextStyle`, из
  // них три десятка с весом 700. Это и есть та самая «почти как в макете»
  // типографика — каждый раз чуть по-своему.
  //
  // Трекинг Flutter принимает в ТОЧКАХ, а не в em: значения ниже пересчитаны
  // как размер × em.

  /// Заголовок панели («Чаты», «Комнаты») — 17/800/-0.015em.
  static const TextStyle panelTitle = TextStyle(
    fontFamily: family,
    decoration: TextDecoration.none,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.26,
    height: 22 / 17,
  );

  /// Имя собеседника в шапке переписки — 19/800/-0.015em.
  static const TextStyle threadTitle = TextStyle(
    fontFamily: family,
    decoration: TextDecoration.none,
    fontSize: 19,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.29,
    height: 24 / 19,
  );

  /// Имя в строке списка — 13,5/600. Между `label` и `bodyStrong`: в макете
  /// строка набрана мельче основного текста, и именно это держит плотность.
  static const TextStyle rowName = TextStyle(
    fontFamily: family,
    decoration: TextDecoration.none,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 18 / 13.5,
  );

  /// Превью последнего сообщения в строке — 12/400.
  static const TextStyle preview = TextStyle(
    fontFamily: family,
    decoration: TextDecoration.none,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
  );

  /// Время в строке списка и под пузырём — 11/400.
  static const TextStyle timeSmall = TextStyle(
    fontFamily: family,
    decoration: TextDecoration.none,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 14 / 11,
  );

  /// Имя темы в полосе над лентой — 15/700/-0.01em.
  static const TextStyle topicName = TextStyle(
    fontFamily: family,
    decoration: TextDecoration.none,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.15,
    height: 20 / 15,
  );

  // ── Моноширинные служебные подписи ─────────────────────────────────────
  //
  // 🔴 ПОЧЕМУ МОНОШИРИННЫЙ, А НЕ ТОТ ЖЕ MANROPE.
  //
  // В макете все служебные подписи — «ЗАКРЕПЛЁННЫЕ», «СЕГОДНЯ», «ТЕМЫ · 4»,
  // «В СЕТИ · 11», код безопасности `6R2K-5KJI-VT2M-B7RT`, «1080p · 30 fps» —
  // набраны ДРУГИМ шрифтом: моноширинным, с разрядкой и в верхнем регистре.
  // Это не украшение. Подпись раздела и имя собеседника стоят в одной колонке
  // друг под другом, и если они одного шрифта, глаз читает их как один список.
  // Смена шрифта говорит «это не строка чата, это ярлык» быстрее любого
  // отступа.
  //
  // Для кодов и размеров у моноширинного есть вторая, прямая польза: цифры
  // одинаковой ширины не пляшут при обновлении. Секундомер созвона на Manrope
  // дёргает соседние значки каждую секунду — на моноширинном не дёргает.
  //
  // 🔴 Семейство: в макете указан `'JetBrains Mono', monospace`. Самого шрифта
  // в сборке нет, и тащить ради подписей в 10 точек ещё один файл начертаний
  // не стоит того — поэтому берём ВТОРОЕ имя из той же строки макета, то есть
  // системный моноширинный. На macOS это Menlo, на Windows Consolas; оба
  // рисуют ровно тот же приём. Если понадобится точное совпадение — вшить
  // JetBrains Mono (OFL) и поменять `monoFamily` в одном месте.
  static const String monoFamily = 'Menlo';
  static const List<String> monoFallback = <String>[
    'JetBrains Mono',
    'SF Mono',
    'Consolas',
    'Roboto Mono',
    'monospace',
  ];

  /// Подпись раздела: «ЗАКРЕПЛЁННЫЕ», «СЕГОДНЯ», «В СЕТИ · 11».
  ///
  /// Размер 9,5 и разрядка 0,07em — из макета. Прописные буквы задаёт РАЗМЕТКА
  /// (`toUpperCase()`), а не стиль: в стиле такого свойства нет, а подпись
  /// должна оставаться читаемой для программ чтения с экрана.
  static const TextStyle meta = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    decoration: TextDecoration.none,
    fontSize: 9.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.67,
    height: 13 / 9.5,
  );

  /// Технические значения: код безопасности, «1.2 МБ», «1080p · 30 fps»,
  /// секундомер созвона. Тот же шрифт, обычный регистр, без разрядки.
  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    decoration: TextDecoration.none,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 15 / 11,
  );
}
