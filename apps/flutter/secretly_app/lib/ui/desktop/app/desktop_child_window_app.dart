// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../../l10n/app_localizations.dart';
import '../design/colors.dart';
import '../design/material_theme.dart';
import '../services/desktop_ui_prefs.dart';

/// Корень отдельного окна ОС (звонок) — 29.09.2026, Р1.
///
/// Своё окно — свой навигатор и слой всплывающих: меню устройств, подсказки,
/// выбор экрана открываются в ЭТОМ окне, а не в главном. Язык и размер текста
/// — те же, что у приложения; палитра всегда тёмная, как у звонка.
///
/// Контроллер сюда не передаётся — только язык и правило его выбора
/// (`appLocaleOverride`, `resolveAppUiLocale`): окну больше ничего не нужно.
class DesktopChildWindowApp extends StatelessWidget {
  const DesktopChildWindowApp({
    super.key,
    required this.locale,
    required this.resolveLocale,
    required this.home,
  });

  /// Язык, выбранный в приложении; `null` — язык системы.
  final Locale? locale;

  /// Правило выбора языка системы — то же, что у главного окна.
  final Locale Function(List<Locale> deviceLocales) resolveLocale;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Secretly',
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (deviceLocales, supportedLocales) =>
          resolveLocale(
            (deviceLocales == null || deviceLocales.isEmpty)
                ? WidgetsBinding.instance.platformDispatcher.locales
                : deviceLocales,
          ),
      theme: desktopMaterialTheme(kDColorsDark, dark: true),
      builder: (ctx, child) => DColors(
        colors: kDColorsDark,
        child: ValueListenableBuilder<double>(
          valueListenable: DesktopUiPrefs.textScale,
          builder: (ctx2, scale, _) => MediaQuery(
            data: MediaQuery.of(ctx2).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            // Эмодзи Windows — Noto (Э1): у экрана звонка в своём окне нет
            // `Material`, и тема до его текста не доходит.
            child: desktopEmojiTextFallback(child ?? const SizedBox.shrink()),
          ),
        ),
      ),
      home: home,
    );
  }
}
