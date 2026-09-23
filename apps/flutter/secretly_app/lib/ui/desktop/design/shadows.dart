// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import 'colors.dart';

/// Тени десктопа.
///
/// 🔴 СВЕРЕНЫ С ИСХОДНИКОМ МАКЕТА (14.09.2026). Были вдвое-вчетверо тише:
/// самый большой размыв — 32 точки против 130 у макета, прозрачности ниже
/// макетных. На большом экране такая тень не отделяет всплывающее окно от
/// переписки, а лишь слегка пачкает край: диалог читается как часть ленты.
///
/// Значения из макета:
///   окно            0 50px 130px rgba(0,0,0,.65)
///   меню            0 32px  76px rgba(0,0,0,.62)
///   карточка        0 26px  64px rgba(0,0,0,.58)
///   тост            0 14px  32px rgba(0,0,0,.50)
class DShadows {
  DShadows._();

  /// Окно поверх окна: самая глубокая тень макета.
  static const List<BoxShadow> window = [
    BoxShadow(
      color: Color(0xA6000000), // .65
      blurRadius: 130,
      offset: Offset(0, 50),
    ),
  ];

  /// Выпадающее меню.
  static const List<BoxShadow> menu = [
    BoxShadow(
      color: Color(0x9E000000), // .62
      blurRadius: 76,
      offset: Offset(0, 32),
    ),
  ];

  /// Модальный диалог. Прежнее имя сохранено — на него завязана разметка.
  static const List<BoxShadow> dialog = window;

  /// Всплывающая карточка.
  static const List<BoxShadow> popover = [
    BoxShadow(
      color: Color(0x94000000), // .58
      blurRadius: 64,
      offset: Offset(0, 26),
    ),
  ];

  /// Тост и небольшие плавающие элементы.
  static const List<BoxShadow> toast = [
    BoxShadow(
      color: Color(0x80000000), // .50
      blurRadius: 32,
      offset: Offset(0, 14),
    ),
  ];

  /// Карточка в потоке. В макете своей ступени у неё нет — берём тостовую,
  /// приглушённую: это фон, а не то, что должно выпрыгивать.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> floating = toast;

  // ── ЦВЕТНЫЕ СВЕЧЕНИЯ ─────────────────────────────────────────────────────
  //
  // 🔴 Отдельный класс теней макета, которого в токенах не было вовсе. Это не
  // украшение: свечение под своим пузырём и под активной плиткой рейки — то,
  // чем макет отделяет «моё и выбранное» от остального, не рисуя ни одной
  // линии. В разметке такие свечения местами уже были заведены руками, но
  // ровно два места из макета их не получали — как раз эти два.


  /// Активная плитка рейки: 0 10px 24px rgba(76,141,246,.3).
  static List<BoxShadow> glowRailActive(DColorSet c) => [
    BoxShadow(
      color: c.accentPrimary.withValues(alpha: 0.30),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  /// Кнопка «Написать»: 0 6px 16px rgba(76,141,246,.28).
  static List<BoxShadow> glowCompose(DColorSet c) => [
    BoxShadow(
      color: c.accentPrimary.withValues(alpha: 0.28),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  // ── ФОКУС ────────────────────────────────────────────────────────────────

  /// Кольцо выделения из макета: `0 0 0 2px #0B1016, 0 0 0 4px #4C8DF6`.
  ///
  /// 🔴 ДВУХСТУПЕНЧАТОЕ, И ЭТО НЕ ПРИДИРКА. Выделение рисовалось внутренней
  /// обводкой: кольцо уходило ВНУТРЬ элемента, съедая две точки содержимого,
  /// и без разделительного кольца край акцента сливался с портретом на
  /// тёмном фоне. Здесь сперва кольцо цвета подложки, потом кольцо акцента —
  /// ровно как в макете.
  ///
  /// `spreadRadius` без размыва и есть css-кольцо.
  static List<BoxShadow> focusRing(DColorSet c) => [
    BoxShadow(color: c.bg, spreadRadius: 2),
    BoxShadow(color: c.accentPrimary, spreadRadius: 4),
  ];
}
