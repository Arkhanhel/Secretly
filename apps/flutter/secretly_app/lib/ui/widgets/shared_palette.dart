// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

/// Shared Discord-style avatar palette.
///
/// Single source of truth for **all** generated avatars across both the mobile
/// and the desktop UI: the desktop primitive
/// `lib/ui/desktop/primitives/avatar.dart` and the mobile `AvatarInitials`
/// helper (`lib/ui/widgets/avatar_initials.dart`) both take their colours
/// from here.
///
/// 8 vivid two-stop pairs — same hue family Discord uses for default
/// avatars. The indicator-color presets (`kIndicatorColorPresets`) in
/// `theme_presets.dart` are drawn from the same hues so that "the colour of
/// my avatar" and "the colour of my buttons & switches" feel like one
/// coherent palette.
///
/// A portrait without a photo is no longer painted with a pair directly — see
/// [sharedAvatarInk]: a muted fill of the pair's hue, with the colour living in
/// the letters.
const List<List<Color>> kSharedAvatarGradients = <List<Color>>[
  <Color>[Color(0xFF6366F1), Color(0xFF8B5CF6)], // Indigo → Violet
  <Color>[Color(0xFFEC4899), Color(0xFFF43F5E)], // Pink → Rose
  <Color>[Color(0xFFF59E0B), Color(0xFFEF4444)], // Amber → Red
  <Color>[Color(0xFF10B981), Color(0xFF06B6D4)], // Emerald → Cyan
  <Color>[Color(0xFF14B8A6), Color(0xFF3B82F6)], // Teal → Blue
  <Color>[Color(0xFFA855F7), Color(0xFFEC4899)], // Purple → Pink
  <Color>[Color(0xFFEAB308), Color(0xFFF97316)], // Yellow → Orange
  <Color>[Color(0xFF22C55E), Color(0xFF84CC16)], // Green → Lime
];

/// Deterministic index into [kSharedAvatarGradients] from any string seed
/// (profile id, display name, group id, etc.). Identical hashing rule used
/// by both desktop and mobile call sites so the same person hashes to the
/// same colours on every device.
int sharedAvatarGradientIndex(String seed) {
  final s = seed.trim().isEmpty ? '?' : seed;
  final hash = s.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7FFFFFFF);
  return hash % kSharedAvatarGradients.length;
}

/// Returns the two-stop color pair for a seed.
List<Color> sharedAvatarGradientColors(String seed) =>
    kSharedAvatarGradients[sharedAvatarGradientIndex(seed)];

/// Цвета заглушки портрета: заливка и буквы.
@immutable
class SharedAvatarInk {
  const SharedAvatarInk({required this.fill, required this.ink});

  /// Непрозрачная заливка кружка (у комнаты на компьютере — квадрата).
  final Color fill;

  /// Цвет инициалов (и значка, если вместо букв значок).
  final Color ink;
}

/// 🔴 ЗАГЛУШКА ПОРТРЕТА — ОДНА ФОРМУЛА НА ТЕЛЕФОН И КОМПЬЮТЕР (17.09.2026).
///
/// Указание владельца: портреты с буквами на телефоне — «такими же цветами, как
/// в пк версии». Компьютер с 14.09 рисует заглушку по макету: приглушённая
/// заливка своего оттенка и ЦВЕТНЫЕ буквы. Телефон рисовал яркий градиент во
/// всю плитку и белые буквы, и один и тот же человек выглядел на двух
/// устройствах по-разному. Теперь оба берут цвета здесь, а оттенок — прежний:
/// тот же хэш того же ключа.
///
/// [background] — то, на чём лежит портрет. Заливка — 15 % оттенка поверх него,
/// и она НЕПРОЗРАЧНАЯ: портрет не должен просвечивать обоями чата или обложкой.
///
/// Тёмный фон — формула макета компьютера, без изменений: буквы светлотой 0,66
/// (зелёная комната в макете — заливка #12302A, буквы #5BD6A8).
///
/// Светлый фон — буквы темнее, причём темнее ПО ЯРКОСТИ, а не по светлоте HSL.
/// Одна и та же светлота даёт бирюзе контраст 2 : 1, а индиго 10 : 1: зелёный
/// глаз видит куда ярче синего. Поэтому светлота подбирается так, чтобы
/// яркость букв у всех оттенков была одна ([_kLightInkLuminance]), и контраст
/// с заливкой у всех выходит 4,3–5,2 : 1. Раньше у компьютера в светлой теме
/// стояла та же светлота 0,66, что и в тёмной, — буквы сливались с заливкой:
/// у бирюзового контраст был 1,2 : 1, у семи оттенков из восьми — ниже 2,5.
SharedAvatarInk sharedAvatarInk(String seed, {required Color background}) =>
    sharedAvatarInkFor(
      sharedAvatarGradientColors(seed),
      background: background,
    );

/// То же для явной пары цветов — у портрета с заданным градиентом.
SharedAvatarInk sharedAvatarInkFor(
  List<Color> pair, {
  required Color background,
}) {
  final tint = Color.lerp(pair.first, pair.last, 0.5)!;
  final fill = Color.alphaBlend(
    tint.withValues(alpha: _kFillAlpha),
    background,
  );
  // Тот же порог, что у палитры компьютера (`DColorSet.isDark`).
  final dark = background.computeLuminance() < 0.5;
  return SharedAvatarInk(
    fill: fill,
    ink: _withMinContrast(
      dark ? _darkInk(tint) : _lightInk(tint),
      fill,
      lighten: dark,
    ),
  );
}

/// Доля оттенка в заливке — подобрана по заливкам макета компьютера.
const double _kFillAlpha = 0.15;

/// Наименьший контраст букв с заливкой — та же планка, что в тестах.
const double _kMinInkContrast = 3.0;

/// 🔴 Буквы не бледнее [_kMinInkContrast] к своей заливке (17.09.2026).
///
/// Формула рассчитана на фон страницы — почти чёрный или почти белый. Экран
/// звонка кладёт портрет на цветной градиент, заливка там светлее, и индиго на
/// синем фоне активного звонка давал 2,2 : 1. Тогда светлота букв сдвигается
/// ровно до планки (к белому на тёмном фоне, к чёрному на светлом). На фонах
/// страниц обеих версий планка и так взята — там ничего не меняется.
Color _withMinContrast(Color ink, Color fill, {required bool lighten}) {
  if (_contrast(ink, fill) >= _kMinInkContrast) return ink;
  final hsl = HSLColor.fromColor(ink);
  var failing = hsl.lightness;
  var passing = lighten ? 1.0 : 0.0;
  if (_contrast(hsl.withLightness(passing).toColor(), fill) <
      _kMinInkContrast) {
    // Фон посередине яркости: планку не взять, край — лучшее, что есть.
    return hsl.withLightness(passing).toColor();
  }
  for (var i = 0; i < 20; i++) {
    final mid = (failing + passing) / 2;
    if (_contrast(hsl.withLightness(mid).toColor(), fill) >=
        _kMinInkContrast) {
      passing = mid;
    } else {
      failing = mid;
    }
  }
  return hsl.withLightness(passing).toColor();
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

/// Светлота букв на тёмном фоне — из макета компьютера.
const double _kDarkInkLightness = 0.66;

/// Яркость букв на светлом фоне: так пишут цветной текст по бледной подложке
/// (оттенки «700»). Контраст с заливкой — не ниже 4,3 : 1 на обычных светлых
/// фонах и не ниже 3,5 : 1 на самом тёмном из светлых (песочная тема).
const double _kLightInkLuminance = 0.13;

Color _darkInk(Color tint) {
  final hsl = HSLColor.fromColor(tint);
  return hsl
      .withLightness(_kDarkInkLightness)
      .withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0))
      .toColor();
}

/// Оттенков восемь, светлых фонов — несколько, а портретов в списке — сотни:
/// подбор светлоты запоминается по оттенку.
final Map<int, Color> _lightInkCache = <int, Color>{};

Color _lightInk(Color tint) {
  final key = tint.toARGB32();
  final cached = _lightInkCache[key];
  if (cached != null) return cached;
  final hsl = HSLColor.fromColor(tint);
  final base = hsl.withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0));
  // Яркость растёт вместе со светлотой — ищем половинным делением.
  var lo = 0.0;
  var hi = _kDarkInkLightness;
  for (var i = 0; i < 20; i++) {
    final mid = (lo + hi) / 2;
    final luminance = base.withLightness(mid).toColor().computeLuminance();
    if (luminance > _kLightInkLuminance) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  final ink = base.withLightness((lo + hi) / 2).toColor();
  // Явные градиенты бывают любыми — кэш не должен расти без предела.
  if (_lightInkCache.length > 64) _lightInkCache.clear();
  _lightInkCache[key] = ink;
  return ink;
}
