// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Стиль значков разделов настроек — выбирает человек (Настройки → Чаты →
/// Оформление → «Иконки»), один на всё приложение и все платформы.
///
/// Макет владельца (20.11.2026): десять стилей плюс Liquid Glass. По
/// умолчанию — «Объём» на всех платформах (решение владельца 20.11.2026).
///
/// Хранится только на этом устройстве (`shared_preferences`), как и
/// переключатель стекла: это вкус, а не данные, и в копию профиля не идёт.
library;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

enum SettingsIconStyle {
  classic,
  glossy,
  clay,
  frost,
  pastel,
  neon,
  aurora,
  material,
  sticker,
  mono,
  glass,
}

extension SettingsIconStyleL10n on SettingsIconStyle {
  /// Название стиля в списке выбора.
  String label(AppLocalizations l10n) => switch (this) {
    SettingsIconStyle.classic => l10n.iconStyleClassic,
    SettingsIconStyle.glossy => l10n.iconStyleGlossy,
    SettingsIconStyle.clay => l10n.iconStyleClay,
    SettingsIconStyle.frost => l10n.iconStyleFrost,
    SettingsIconStyle.pastel => l10n.iconStylePastel,
    SettingsIconStyle.neon => l10n.iconStyleNeon,
    SettingsIconStyle.aurora => l10n.iconStyleAurora,
    SettingsIconStyle.material => l10n.iconStyleCircles,
    SettingsIconStyle.sticker => l10n.iconStyleStickers,
    SettingsIconStyle.mono => l10n.iconStyleMono,
    SettingsIconStyle.glass => l10n.iconStyleGlass,
  };
}

/// Выбранный стиль значков. Слушается всеми списками настроек, поэтому смена
/// стиля перерисовывает их сразу, без перезапуска.
class SettingsIconStylePrefs {
  const SettingsIconStylePrefs._();

  static const String prefsKey = 'settings_icon_style_v1';

  /// Стиль по умолчанию для этой платформы.
  static SettingsIconStyle get platformDefault => SettingsIconStyle.clay;

  static final ValueNotifier<SettingsIconStyle> style =
      ValueNotifier<SettingsIconStyle>(platformDefault);

  static bool _loaded = false;

  /// Читает сохранённый выбор. Зовётся при запуске (до первого кадра), а
  /// также лениво из [ensureLoaded] — на случай точки входа, которая забыла.
  static Future<void> load([SharedPreferences? prefs]) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      style.value = parse(p.getString(prefsKey)) ?? platformDefault;
    } catch (_) {
      // Остаётся стиль по умолчанию — значок не стоит того, чтобы падать.
    }
    _loaded = true;
  }

  static void ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    load();
  }

  static SettingsIconStyle? parse(String? raw) {
    if (raw == null) return null;
    for (final s in SettingsIconStyle.values) {
      if (s.name == raw) return s;
    }
    return null;
  }

  static Future<void> set(SettingsIconStyle value) async {
    if (style.value == value) return;
    style.value = value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(prefsKey, value.name);
    } catch (_) {
      // Новый стиль уже на экране; сохранение — по возможности.
    }
  }

  /// Вернуть стиль по умолчанию (кнопка «Сбросить» в «Оформлении»).
  static Future<void> reset() async {
    style.value = platformDefault;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(prefsKey);
    } catch (_) {}
  }

  @visibleForTesting
  static void debugReset() {
    _loaded = false;
    style.value = platformDefault;
  }
}

/// Перестраивает [builder] при смене стиля значков.
class SettingsIconStyleBuilder extends StatelessWidget {
  const SettingsIconStyleBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, SettingsIconStyle style) builder;

  @override
  Widget build(BuildContext context) {
    SettingsIconStylePrefs.ensureLoaded();
    return ValueListenableBuilder<SettingsIconStyle>(
      valueListenable: SettingsIconStylePrefs.style,
      builder: (context, style, _) => builder(context, style),
    );
  }
}
