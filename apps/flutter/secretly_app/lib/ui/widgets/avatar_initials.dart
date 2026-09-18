// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import 'app_background.dart';
import 'shared_palette.dart';

/// Helpers for the "user has no profile photo → show initials" fallback.
///
/// 🔴 С 17.09.2026 заглушка телефона — та же, что на компьютере
/// (`lib/ui/desktop/primitives/avatar.dart`): приглушённая заливка оттенка из
/// [kSharedAvatarGradients] и цветные буквы, см. [sharedAvatarInk]. Оттенок
/// берётся из того же хэша того же ключа (profile id / convo id / group id),
/// поэтому у человека прежний цвет — только спокойнее, и такой же, как на
/// компьютере. Раньше здесь был яркий градиент во всю плитку и белые буквы.
class AvatarInitials {
  AvatarInitials._();

  // ── Initials ──────────────────────────────────────────────────────────
  static String label({String? displayName, String? fallbackId}) {
    final primary = (displayName ?? '').trim();
    final fallback = (fallbackId ?? '').trim();
    final source = primary.isNotEmpty ? primary : fallback;
    if (source.isEmpty) return '?';

    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.length >= 2) {
      final first = _firstChar(parts[0]);
      final second = _firstChar(parts[1]);
      final initials = '$first$second'.trim();
      return initials.isEmpty ? '?' : initials.toUpperCase();
    }

    final chunk = parts.isEmpty ? source : parts.first;
    final chars = chunk.characters.take(2).toList(growable: false);
    final value = chars.join().trim();
    return value.isEmpty ? '?' : value.toUpperCase();
  }

  // ── Цвета заглушки (17.09.2026) ───────────────────────────────────────
  /// Фон страницы, на котором лежит портрет.
  ///
  /// Обычные экраны прозрачны (`scaffoldBackgroundColor` в `main.dart`) и
  /// лежат на общем градиенте приложения. Экран со СВОИМ непрозрачным фоном —
  /// витрина украшений, обрезка обложки — тёмный в любой теме, и заливка
  /// считается от него: иначе при светлой теме там вышел бы светлый кружок.
  static Color pageColor(BuildContext context) {
    final scaffold = Theme.of(context).scaffoldBackgroundColor;
    if (scaffold.a >= 1.0) return scaffold;
    return AppBackground.scrimColorOf(context);
  }

  /// Заливка и цвет букв заглушки для [seed].
  ///
  /// [background] — когда портрет лежит не на странице: экран звонка и тёмная
  /// витрина украшений тёмные в любой теме, и светлая заливка там выглядела бы
  /// дырой.
  static SharedAvatarInk colors(
    BuildContext context, {
    required String seed,
    Color? background,
  }) => sharedAvatarInk(seed, background: background ?? pageColor(context));

  /// Заливка заглушки — для `CircleAvatar`, которому нужен один цвет.
  static Color backgroundColor(BuildContext context, {required String seed}) =>
      colors(context, seed: seed).fill;

  /// Цвет букв (и значка вместо букв) заглушки — пара к [backgroundColor].
  static Color foregroundColor(BuildContext context, {required String seed}) =>
      colors(context, seed: seed).ink;

  /// Светлая ли заливка заглушки: белый текст по ней не читается.
  ///
  /// Шапки собеседника и комнаты раскрываются во всю ширину, и без фото под
  /// именем лежит сама заливка — в светлой теме почти белая.
  static bool fillIsLight(BuildContext context, {required String seed}) =>
      colors(context, seed: seed).fill.computeLuminance() > 0.5;

  /// Яркий оттенок человека — для большой цветной ПОДЛОЖКИ, а не для портрета
  /// (плитка участника созвона без камеры). Тот же оттенок, что у его заглушки.
  static Color accentColor({required String seed}) =>
      sharedAvatarGradientColors(seed).first;

  // ── Nickname / accent colour for chat bubbles & reply strips ──────────
  /// Single hue for nicknames & reply-quote strips. We pick the **first**
  /// stop of the seed's pair so the nickname colour visually matches the
  /// user's avatar.
  static Color nicknameColor({required String seed}) =>
      sharedAvatarGradientColors(seed).first;

  // ── Reply-quote panel background derived from nick colour ─────────────
  static Color replyPanelColor({required String seed, required bool isMe}) {
    final nick = sharedAvatarGradientColors(seed).first;
    return isMe
        ? nick.withValues(alpha: 0.18)
        : nick.withValues(alpha: 0.12);
  }

  /// Builds the canonical "initials in a circle" widget — the fallback avatar
  /// used wherever a profile photo is missing.
  ///
  /// Pass [radius] (matches `CircleAvatar.radius`) or compute it from the
  /// available size at the call site. [seed] determines the hue (use the same
  /// stable id everywhere — profile id, group id, etc.). The initials come
  /// from [displayName] / [fallbackId] via [label]. [background] — see
  /// [colors].
  static Widget fallbackBubble({
    required BuildContext context,
    required double radius,
    required String seed,
    String? displayName,
    String? fallbackId,
    TextStyle? labelStyle,
    BoxBorder? border,
    Color? background,
  }) {
    final size = radius * 2;
    final initials = label(displayName: displayName, fallbackId: fallbackId);
    final fontSize = size * 0.38;
    final palette = colors(context, seed: seed, background: background);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.fill,
        border: border,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style:
            (labelStyle ??
                    Theme.of(context).textTheme.labelLarge ??
                    const TextStyle())
                .copyWith(
                  color: palette.ink,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: 1.0,
                ),
      ),
    );
  }

  static String _firstChar(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.characters.first;
  }
}
