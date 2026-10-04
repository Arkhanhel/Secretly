// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// «ВНЕШНИЙ ВИД» ПО МАКЕТУ ВЛАДЕЛЬЦА (29.09.2026).
///
/// 🔴 ЗАЧЕМ ПЕРЕДЕЛКА. Раздел был лентой из девяти одинаковых карточек:
/// двадцать пузырей сеткой три в ряд, четыре переключателя «поведения
/// анимации», из которых включённым может быть только один, и ни одного
/// способа увидеть результат, не закрывая настроек. Владелец нарисовал
/// раздел заново: три вкладки («Тема и текст», «Фон чата», «Сообщения»),
/// готовые наборы, выбор цвета глазами, а справа — живой предпросмотр
/// переписки, в котором видно каждое изменение.
///
/// Всё здесь применяется СРАЗУ и сохраняется само — как и в остальных
/// разделах настроек; «По умолчанию» возвращает исходный вид одним нажатием
/// и даёт отменить возврат.
///
/// Контроллер сюда не импортируется (сторож швов): всё берётся из
/// [DesktopAppViewModel.controller] без называния его типа.
library;

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../cosmetics/cosmetics_catalog_service.dart';
import '../../../entitlements/cosmetic_catalog.dart'
    show CosmeticKind, isCosmeticAllowed;
import '../../../l10n/app_localizations.dart';
import '../../chat_wallpapers.dart';
import '../../theme_presets.dart';
import '../app/desktop_app_view_model.dart';
import '../app/desktop_selector.dart' show kDesktopNoTicks;
import '../chat/bubble_look.dart' show desktopSenderNameColor;
import '../chat/desktop_wallpaper_picker.dart';
import '../design/theme_bridge.dart';
import '../design/tokens.dart';
import '../../widgets/avatar_initials.dart';
import '../primitives/desktop_snackbar.dart';
import '../primitives/hover_listener.dart';
import '../services/desktop_ui_prefs.dart';
import 'accent_color_picker.dart';
import 'appearance_preview.dart';
import 'settings_kit.dart';
import 'settings_style.dart';
import 'workspace_layout.dart';

/// Ширина колонки настроек (с полями 32) и пределы колонки предпросмотра —
/// из макета: `max-width: 760px` у содержимого, `360…460px` у предпросмотра.
const double kAppearanceContentWidth = 760;
const double kAppearancePreviewMin = 360;
const double kAppearancePreviewMax = 460;

/// Раздел целиком: содержимое плюс предпросмотр.
const double kAppearancePaneMaxWidth =
    kAppearanceContentWidth + kAppearancePreviewMax;

/// Готовый набор: акцент, обои, пузыри, индикаторы и цвет имён одним
/// нажатием (макет: «Классика», «Океан», «Закат», «Лес», «Ночь»).
@immutable
class DesktopAppearancePreset {
  const DesktopAppearancePreset({
    required this.id,
    required this.themeId,
    this.customAccent,
    required this.wallpaperDark,
    required this.wallpaperLight,
    required this.bubbleId,
    required this.indicatorId,
    required this.names,
  });

  final String id;

  /// Схема оформления; действует, когда у набора нет [customAccent].
  final String themeId;

  /// Свой цвет акцента (как плитка «Свой цвет»); `null` — цвет схемы.
  final Color? customAccent;
  final String wallpaperDark;
  final String wallpaperLight;
  final String bubbleId;
  final String indicatorId;

  /// `person` — у каждого своё; иначе id набора «Цвет имени».
  final String names;

  String wallpaper({required bool dark}) =>
      dark ? wallpaperDark : wallpaperLight;
}

/// 🔴 «КЛАССИКА» — ЭТО РОВНО ТО, ЧТО ДАЁТ «ПО УМОЛЧАНИЮ». Один и тот же вид
/// не может называться двумя именами и выглядеть по-разному: после возврата
/// к исходному карточка «Классика» загорается выбранной.
///
/// Цвета акцента «Заката», «Леса» и «Ночи» — свои (как плитка «Свой цвет»):
/// среди схем нет зелёной бесплатной, а набор не должен требовать подписки
/// за то, что человек может выбрать и сам. Платными наборы делают только
/// платные части — живые обои и индикаторы не из бесплатных трёх, — и на
/// карточке тогда замок.
List<DesktopAppearancePreset> desktopAppearancePresets() => [
  DesktopAppearancePreset(
    id: 'classic',
    themeId: 'flutter_dash',
    wallpaperDark: themeStandardChatWallpaperId(darkMode: true),
    wallpaperLight: themeStandardChatWallpaperId(darkMode: false),
    bubbleId: normalizeChatBubbleStylePresetId('flutter_dash'),
    indicatorId: 'theme',
    names: 'person',
  ),
  DesktopAppearancePreset(
    id: 'ocean',
    themeId: 'ocean',
    wallpaperDark: encodeAnimatedChatWallpaperId('cold_steel'),
    wallpaperLight: encodeAnimatedChatWallpaperId('cold_steel'),
    bubbleId: 'deep',
    indicatorId: 'blue',
    names: 'ice',
  ),
  DesktopAppearancePreset(
    id: 'sunset',
    themeId: 'flutter_dash',
    customAccent: const Color(0xFFE67E22),
    wallpaperDark: encodeAnimatedChatWallpaperId('neon_dusk'),
    wallpaperLight: encodeAnimatedChatWallpaperId('neon_dusk'),
    bubbleId: 'golden_hour',
    indicatorId: 'amber',
    names: 'amber',
  ),
  DesktopAppearancePreset(
    id: 'forest',
    themeId: 'flutter_dash',
    customAccent: const Color(0xFF23A55A),
    wallpaperDark: encodeAssetChatWallpaperId(
      '${kBundledChatWallpaperAssetRoot}wallpaper_dark_teal.jpg',
    ),
    wallpaperLight: encodeAssetChatWallpaperId(
      kLightThemeStandardChatWallpaperAssetPath,
    ),
    bubbleId: 'mint',
    indicatorId: 'emerald',
    names: 'person',
  ),
  DesktopAppearancePreset(
    id: 'night',
    themeId: 'flutter_dash',
    customAccent: const Color(0xFF9B84EE),
    wallpaperDark: encodeAnimatedChatWallpaperId('midnight'),
    wallpaperLight: encodeAnimatedChatWallpaperId('midnight'),
    bubbleId: 'nebula',
    indicatorId: 'violet',
    names: 'violet',
  ),
];

/// Имя из набора данных — русское для русского интерфейса, иначе английское.
String _dataName(BuildContext context, String ru, String en) =>
    Localizations.localeOf(context).languageCode == 'ru' ? ru : en;

class DesktopAppearancePane extends StatefulWidget {
  const DesktopAppearancePane({
    super.key,
    this.vm,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.tint,
  });

  /// `null` — демо-сборка без профиля: всё рисуется, ничего не пишется.
  final DesktopAppViewModel? vm;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color tint;

  @override
  State<DesktopAppearancePane> createState() => _DesktopAppearancePaneState();
}

/// Вкладка, открытая в прошлый раз: вернувшись в раздел, человек попадает
/// туда, где был, а не на первую вкладку.
int _lastAppearanceTab = 0;

class _DesktopAppearancePaneState extends State<DesktopAppearancePane> {
  late int _tab = _lastAppearanceTab;

  /// Какой набор обоев показан: `null` — по выбранным обоям.
  bool? _liveFilter;

  List<String> _bundledWallpapers = const <String>[];
  List<({String id, String title})> _serverWallpapers =
      const <({String id, String title})>[];

  static final Listenable _prefs = Listenable.merge(<Listenable>[
    DesktopUiPrefs.themeMode,
    DesktopUiPrefs.customAccentArgb,
    DesktopUiPrefs.textScale,
    DesktopUiPrefs.messageDensity,
    DesktopUiPrefs.bubbleShape,
    DesktopUiPrefs.wallpaperDim,
    DesktopUiPrefs.senderNameColors,
  ]);

  @override
  void initState() {
    super.initState();
    unawaited(_loadWallpaperSources());
  }

  Future<void> _loadWallpaperSources() async {
    final bundled = await loadBundledChatWallpaperAssets();
    var server = const <({String id, String title})>[];
    final ctrl = widget.vm?.controller;
    if (ctrl != null) {
      try {
        CosmeticsCatalogService.instance.configure(ctrl.relayHttpBaseUrl);
        final items = await CosmeticsCatalogService.instance.wallpapers();
        server = items
            .map((it) => (id: it.id, title: it.title))
            .toList(growable: false);
      } catch (_) {
        // Без сети — только обои из приложения.
      }
    }
    if (!mounted) return;
    setState(() {
      _bundledWallpapers = bundled;
      _serverWallpapers = server;
    });
  }

  // ── Права на платное ───────────────────────────────────────────────────

  /// Разрешено ли выбрать [id] вида [kind]. Без профиля — всё (демо).
  bool _allowed(CosmeticKind kind, String id) {
    final ctrl = widget.vm?.controller;
    if (ctrl == null) return true;
    return isCosmeticAllowed(ctrl.entitlementStateNow, kind, id);
  }

  bool _presetAllowed(DesktopAppearancePreset p, {required bool dark}) =>
      (p.customAccent != null || _allowed(CosmeticKind.theme, p.themeId)) &&
      _allowed(CosmeticKind.wallpaper, p.wallpaper(dark: dark)) &&
      _allowed(CosmeticKind.bubbleStyle, p.bubbleId) &&
      _allowed(CosmeticKind.indicatorColor, p.indicatorId);

  /// 🔴 ПЛАТНОЕ БЕЗ ПОДПИСКИ — СРАЗУ СКАЗАТЬ, А НЕ ПРИНЯТЬ МОЛЧА. Контроллер
  /// при чтении возвращает платный выбор к бесплатному; выбор, который
  /// «сохранился», но ничего не поменял, — худшее, что может сделать
  /// настройка. Подписка оформляется на телефоне (ПК ничего не продаёт).
  void _premiumOnly() {
    DesktopSnackbar.show(
      context,
      message: AppLocalizations.of(context)!.desktopAppearancePremiumOnly,
    );
  }

  // ── Действия ───────────────────────────────────────────────────────────

  Future<void> _setScheme(String mode) async {
    await DesktopUiPrefs.setThemeMode(mode);
    final ctrl = widget.vm?.controller;
    if (ctrl == null || mode == 'auto') return;
    await ctrl.setDarkMode(mode == 'dark');
  }

  Future<void> _selectTheme(String id) async {
    final ctrl = widget.vm?.controller;
    if (ctrl == null) return;
    if (!_allowed(CosmeticKind.theme, id)) return _premiumOnly();
    // ◆ Нажатие по схеме СНИМАЕТ свой цвет. Иначе кружок схемы выглядел бы
    // выбранным, а окно оставалось бы прежнего цвета — выбор без последствий.
    await DesktopUiPrefs.setCustomAccent(0);
    await ctrl.setAppThemePresetId(id);
  }

  Future<void> _pickCustomAccent() async {
    final app = SettingsScope.appColorsOf(context);
    final current = DesktopUiPrefs.customAccentArgb.value;
    final argb = await showAccentColorPicker(
      context,
      // Открываем на том цвете, который окно носит сейчас: свой, если он
      // выбран, иначе акцент текущей схемы.
      initial: current != 0 ? Color(current) : app.accentPrimary,
      dark: app.isDark,
    );
    if (argb == null) return;
    await DesktopUiPrefs.setCustomAccent(argb);
  }

  Future<void> _selectWallpaper(String id) async {
    final ctrl = widget.vm?.controller;
    if (ctrl == null) return;
    if (!_allowed(CosmeticKind.wallpaper, id)) return _premiumOnly();
    await ctrl.setDefaultChatWallpaperId(id);
  }

  Future<void> _selectBubble(String id) async {
    final ctrl = widget.vm?.controller;
    if (ctrl == null) return;
    if (!_allowed(CosmeticKind.bubbleStyle, id)) return _premiumOnly();
    await ctrl.setChatBubbleStylePresetId(id);
  }

  Future<void> _selectIndicator(String id) async {
    final ctrl = widget.vm?.controller;
    if (ctrl == null) return;
    if (!_allowed(CosmeticKind.indicatorColor, id)) return _premiumOnly();
    await ctrl.setIndicatorColorPresetId(id);
  }

  /// `person` — у каждого свой цвет; иначе один цвет набора [names] на всех.
  Future<void> _selectNames(String names) async {
    final ctrl = widget.vm?.controller;
    if (names == 'person') {
      await DesktopUiPrefs.setSenderNameColors('person');
      return;
    }
    if (ctrl == null) return;
    await ctrl.setNicknameStylePresetId(names);
    await DesktopUiPrefs.setSenderNameColors('preset');
  }

  Future<void> _applyPreset(DesktopAppearancePreset p) async {
    final ctrl = widget.vm?.controller;
    if (ctrl == null) return;
    final dark = SettingsScope.appColorsOf(context).isDark;
    if (!_presetAllowed(p, dark: dark)) return _premiumOnly();
    // Схема — ПЕРВОЙ: она возвращает пузырь к своему по умолчанию, и пузырь
    // набора должен лечь уже поверх.
    var bubbleFollowsTheme = false;
    if (p.customAccent == null) {
      await DesktopUiPrefs.setCustomAccent(0);
      await ctrl.setAppThemePresetId(p.themeId);
      // Пузырь набора совпал с пузырём схемы — оставляем его «от схемы»:
      // поставленный вручную, он перестал бы следовать за сменой схемы.
      bubbleFollowsTheme =
          normalizeChatBubbleStylePresetId(
            kThemeToBubbleDefaults[p.themeId] ?? '',
          ) ==
          p.bubbleId;
    } else {
      await DesktopUiPrefs.setCustomAccent(p.customAccent!.toARGB32());
    }
    if (!bubbleFollowsTheme) await ctrl.setChatBubbleStylePresetId(p.bubbleId);
    await ctrl.setDefaultChatWallpaperId(p.wallpaper(dark: dark));
    await ctrl.setIndicatorColorPresetId(p.indicatorId);
    await _selectNames(p.names);
    if (mounted) setState(() => _liveFilter = null);
  }

  bool _presetSelected(DesktopAppearancePreset p, {required bool dark}) {
    final ctrl = widget.vm?.controller;
    if (ctrl == null) return false;
    final custom = DesktopUiPrefs.customAccentArgb.value;
    final accentOk = p.customAccent == null
        ? custom == 0 && ctrl.appThemePresetId == p.themeId
        : custom == p.customAccent!.toARGB32();
    return accentOk &&
        normalizeChatWallpaperId(ctrl.defaultChatWallpaperId) ==
            p.wallpaper(dark: dark) &&
        normalizeChatBubbleStylePresetId(ctrl.chatBubbleStylePresetId) ==
            p.bubbleId &&
        ctrl.indicatorColorPresetId == p.indicatorId &&
        _currentNames() == p.names;
  }

  /// Выбор «Цвета имени» в словах набора: `person` или id набора.
  String _currentNames() {
    if (DesktopUiPrefs.senderNameColors.value != 'preset') return 'person';
    return widget.vm?.controller.nicknameStylePresetId ?? 'accent';
  }

  /// Палитра окна для схемы [dark] — тем же правилом, что у корня окна
  /// (`desktop_production_app.dart`, `applyThemePreset`): карточки схем
  /// показывают, как будет выглядеть ИМЕННО это окно, с выбранным акцентом,
  /// пузырями и индикаторами, а не условные «тёмное» и «светлое».
  DColorSet _paletteFor({required bool dark}) {
    final ctrl = widget.vm?.controller;
    final base = dark ? kDColorsDark : kDColorsLight;
    final custom = DesktopUiPrefs.customAccentArgb.value;
    return applyThemePreset(
      base,
      ctrl?.appThemePresetId ?? kAppThemePresets.first.id,
      dark: dark,
      indicatorPresetId: ctrl?.indicatorColorPresetId ?? 'theme',
      bubblePresetId: ctrl?.chatBubbleStylePresetId,
      customAccent: custom == 0 ? null : Color(custom),
    );
  }

  /// «По умолчанию»: снимок нынешнего вида, возврат к исходному, и
  /// «Вернуть» в подсказке — на случай, если нажали не глядя.
  Future<void> _resetDefaults() async {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = widget.vm?.controller;
    final dark = SettingsScope.appColorsOf(context).isDark;
    final before = ctrl == null
        ? null
        : _AppearanceSnapshot(
            themeMode: DesktopUiPrefs.themeMode.value,
            customAccent: DesktopUiPrefs.customAccentArgb.value,
            themeId: ctrl.appThemePresetId,
            bubbleId: ctrl.chatBubbleStylePresetId,
            wallpaperId: ctrl.defaultChatWallpaperId,
            animMode: ctrl.chatWallpaperAnimMode,
            conduct: ctrl.chatWallpaperConduct,
            indicatorId: ctrl.indicatorColorPresetId,
            nicknameId: ctrl.nicknameStylePresetId,
            names: DesktopUiPrefs.senderNameColors.value,
            textScale: DesktopUiPrefs.textScale.value,
            density: DesktopUiPrefs.messageDensity.value,
            shape: DesktopUiPrefs.bubbleShape.value,
            dim: DesktopUiPrefs.wallpaperDim.value,
          );
    await DesktopUiPrefs.setTextScale(1.0);
    await DesktopUiPrefs.setMessageDensity('cozy');
    await DesktopUiPrefs.setBubbleShape('medium');
    await DesktopUiPrefs.setWallpaperDim(0);
    await DesktopUiPrefs.setSenderNameColors('person');
    await DesktopUiPrefs.setCustomAccent(0);
    if (ctrl != null) {
      // Схема оформления возвращает и пузырь к своему по умолчанию — поэтому
      // пузырь отдельно не ставится: иначе он стал бы «выбранным вручную» и
      // перестал бы следовать за схемой.
      await ctrl.setAppThemePresetId('flutter_dash');
      await ctrl.setDefaultChatWallpaperId(
        themeStandardChatWallpaperId(darkMode: dark),
      );
      await ctrl.setChatWallpaperAnimMode(ChatWallpaperAnimMode.onEnter);
      await ctrl.setChatWallpaperConduct(false);
      await ctrl.setIndicatorColorPresetId('theme');
      await ctrl.setNicknameStylePresetId('accent');
    }
    await _setScheme('dark');
    if (!mounted) return;
    setState(() => _liveFilter = null);
    DesktopSnackbar.show(
      context,
      message: l10n.desktopAppearanceResetDone,
      kind: DSnackKind.success,
      actionLabel: before == null ? null : l10n.desktopAppearanceResetUndo,
      onAction: before == null ? null : () => unawaited(_restore(before)),
    );
  }

  Future<void> _restore(_AppearanceSnapshot s) async {
    final ctrl = widget.vm?.controller;
    await _setScheme(s.themeMode);
    await DesktopUiPrefs.setTextScale(s.textScale);
    await DesktopUiPrefs.setMessageDensity(s.density);
    await DesktopUiPrefs.setBubbleShape(s.shape);
    await DesktopUiPrefs.setWallpaperDim(s.dim);
    await DesktopUiPrefs.setSenderNameColors(s.names);
    await DesktopUiPrefs.setCustomAccent(s.customAccent);
    if (ctrl != null) {
      await ctrl.setAppThemePresetId(s.themeId);
      await ctrl.setChatBubbleStylePresetId(s.bubbleId);
      await ctrl.setDefaultChatWallpaperId(s.wallpaperId);
      await ctrl.setChatWallpaperAnimMode(s.animMode);
      await ctrl.setChatWallpaperConduct(s.conduct);
      await ctrl.setIndicatorColorPresetId(s.indicatorId);
      await ctrl.setNicknameStylePresetId(s.nicknameId);
    }
    if (mounted) setState(() => _liveFilter = null);
  }

  // ── Отрисовка ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Одна перерисовка на устоявшуюся пачку тиков контроллера — через общий
    // узел, а не своей подпиской на `changed` (см. [DesktopSelectorHub.ticks]).
    return ValueListenableBuilder<int>(
      valueListenable: widget.vm?.ticks ?? kDesktopNoTicks,
      builder: (context, _, _) => ListenableBuilder(
        listenable: _prefs,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = widget.vm?.controller;
    final app = SettingsScope.appColorsOf(context);
    final wallpaperId = normalizeChatWallpaperId(
      ctrl?.defaultChatWallpaperId ??
          themeStandardChatWallpaperId(darkMode: app.isDark),
    );
    final isLive = decodeAnimatedChatWallpaperStyle(wallpaperId) != null;
    final animMode = ctrl?.chatWallpaperAnimMode ?? ChatWallpaperAnimMode.onEnter;
    // Превью обоев рисуются палитрой ОКНА: «Ночной» — это однотонный фон окна,
    // а не серой страницы настроек вокруг.
    return DesktopWallpaperPalette(
      colors: app,
      child: LayoutBuilder(
      builder: (ctx, box) {
        final wide = box.maxWidth >= 460 + kAppearancePreviewMin;
        final previewWidth = wide
            ? (box.maxWidth - kAppearanceContentWidth).clamp(
                kAppearancePreviewMin,
                kAppearancePreviewMax,
              )
            : 0.0;
        final mainWidth = box.maxWidth - previewWidth;
        // «Сохраняется автоматически» — пояснение, а не действие: когда
        // крупный текст не оставляет места заголовку, уходит оно, а не кнопка.
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final main = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkspaceContentHeader(
              title: widget.title,
              subtitle: widget.subtitle,
              icon: widget.icon,
              tint: widget.tint,
              trailing: _headerActions(
                l10n,
                showAutosave: mainWidth >= 640 * textScale,
              ),
              bottom: SettingsTabs(
                tabs: [
                  SettingsTab(
                    icon: FluentIcons.dark_theme_24_regular,
                    label: l10n.desktopAppearanceTabTheme,
                  ),
                  SettingsTab(
                    icon: FluentIcons.image_24_regular,
                    label: l10n.desktopAppearanceTabWallpaper,
                  ),
                  SettingsTab(
                    icon: FluentIcons.chat_24_regular,
                    label: l10n.desktopAppearanceTabMessages,
                  ),
                ],
                index: _tab,
                onChanged: (i) => setState(() {
                  _tab = i;
                  _lastAppearanceTab = i;
                }),
              ),
            ),
            Expanded(
              child: ListView(
                key: PageStorageKey<String>('appearance-tab-$_tab'),
                padding: const EdgeInsets.fromLTRB(32, 4, 32, 96),
                children: [
                  ...switch (_tab) {
                    1 => _wallpaperTab(context, l10n, wallpaperId, isLive,
                        animMode),
                    2 => _messagesTab(context, l10n),
                    _ => _themeTab(context, l10n),
                  },
                  _summary(context, l10n, wallpaperId),
                ],
              ),
            ),
          ],
        );
        if (!wide) return main;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: main),
            SizedBox(
              width: previewWidth,
              child: DesktopAppearancePreview(
                wallpaperId: wallpaperId,
                animMode: animMode,
                conduct: ctrl?.chatWallpaperConduct ?? false,
                nicknamePresetId: ctrl?.nicknameStylePresetId ?? 'accent',
              ),
            ),
          ],
        );
      },
      ),
    );
  }

  Widget _headerActions(AppLocalizations l10n, {required bool showAutosave}) {
    final p = SettingsScope.paletteOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showAutosave) ...[
          Icon(FluentIcons.cloud_checkmark_24_regular, size: 16, color: p.faint),
          const SizedBox(width: 4),
          Text(
            l10n.desktopAppearanceAutosave,
            style: TextStyle(
              fontFamily: DType.family,
              fontSize: 12,
              color: p.faint,
            ),
          ),
          const SizedBox(width: 12),
        ],
        SettingsSoftButton(
          icon: FluentIcons.arrow_reset_24_regular,
          label: l10n.desktopAppearanceReset,
          onTap: () => unawaited(_resetDefaults()),
        ),
      ],
    );
  }

  // ── Вкладка «Тема и текст» ─────────────────────────────────────────────

  List<Widget> _themeTab(BuildContext context, AppLocalizations l10n) {
    final ctrl = widget.vm?.controller;
    final p = SettingsScope.paletteOf(context);
    final app = SettingsScope.appColorsOf(context);
    final dark = app.isDark;
    final custom = DesktopUiPrefs.customAccentArgb.value;
    final themeId = ctrl?.appThemePresetId ?? kAppThemePresets.first.id;
    final themePreset = resolveAppThemePreset(themeId);
    final accentName = custom != 0
        ? l10n.desktopAccentCustom
        : _dataName(context, themePreset.nameRu, themePreset.nameEn);
    final accentHex =
        '#${(app.accentPrimary.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return [
      SettingsSection(
        title: l10n.desktopAppearancePresets,
        description: l10n.desktopAppearancePresetsHint,
        child: _AutoGrid(
          minTileWidth: 128,
          gap: 10,
          children: [
            for (final preset in desktopAppearancePresets())
              _PresetCard(
                preset: preset,
                name: _presetName(l10n, preset.id),
                selected: _presetSelected(preset, dark: dark),
                locked: !_presetAllowed(preset, dark: dark),
                onTap: ctrl == null ? null : () => unawaited(_applyPreset(preset)),
              ),
          ],
        ),
      ),
      SettingsSection(
        title: l10n.desktopAppearanceScheme,
        description: l10n.desktopAppearanceHint,
        child: _AutoGrid(
          minTileWidth: 120,
          maxColumns: 3,
          gap: 10,
          children: [
            for (final mode in const ['dark', 'light', 'auto'])
              _SchemeCard(
                mode: mode,
                darkColors: _paletteFor(dark: true),
                lightColors: _paletteFor(dark: false),
                label: switch (mode) {
                  'dark' => l10n.desktopAppearanceDark,
                  'light' => l10n.desktopAppearanceLight,
                  _ => l10n.desktopAppearanceSystem,
                },
                selected: DesktopUiPrefs.themeMode.value == mode,
                onTap: () => unawaited(_setScheme(mode)),
              ),
          ],
        ),
      ),
      SettingsSection(
        title: l10n.desktopAppearanceAccent,
        titleTrailing: Text(
          '$accentName · $accentHex',
          style: DType.mono.copyWith(fontSize: 12, color: p.faint),
        ),
        description: l10n.desktopAppearanceAccentHint,
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final t in kAppThemePresets)
              _ColorDot(
                size: 32,
                color: legibleAccent(
                  dark ? t.darkPrimary : t.lightPrimary,
                  dark: dark,
                ),
                tooltip: _dataName(context, t.nameRu, t.nameEn),
                selected: custom == 0 && t.id == themeId,
                locked: !_allowed(CosmeticKind.theme, t.id),
                onTap: ctrl == null ? null : () => unawaited(_selectTheme(t.id)),
              ),
            Container(width: 1, height: 24, color: p.border),
            _CustomAccentDot(
              color: custom == 0 ? null : Color(custom),
              tooltip: l10n.desktopAccentCustom,
              onTap: ctrl == null ? null : () => unawaited(_pickCustomAccent()),
            ),
          ],
        ),
      ),
      _TwoColumns(
        minColumnWidth: 240,
        left: _textSizeBlock(context, l10n),
        right: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsSectionTitle(l10n.desktopAppearanceDensity),
            const SizedBox(height: 10),
            SettingsSegmented<String>(
              values: DesktopUiPrefs.messageDensityValues,
              labels: [
                l10n.desktopAppearanceDensityCozy,
                l10n.desktopAppearanceDensityCompact,
              ],
              value: DesktopUiPrefs.messageDensity.value,
              onChanged: (v) => unawaited(DesktopUiPrefs.setMessageDensity(v)),
            ),
          ],
        ),
      ),
    ];
  }

  String _presetName(AppLocalizations l10n, String id) => switch (id) {
    'ocean' => l10n.desktopAppearancePresetOcean,
    'sunset' => l10n.desktopAppearancePresetSunset,
    'forest' => l10n.desktopAppearancePresetForest,
    'night' => l10n.desktopAppearancePresetNight,
    _ => l10n.desktopAppearancePresetClassic,
  };

  /// «Размер текста»: ползунок по пяти ступеням, подписи ступеней под ним.
  ///
  /// 🔴 СТУПЕНИ, А НЕ ПРОИЗВОЛЬНОЕ ЧИСЛО. Ползунок в макете, но с ПЯТЬЮ
  /// положениями: произвольный масштаб даёт раскладку, которая ведёт себя
  /// непредсказуемо, и вернуться ровно к «как было» становится нечем.
  Widget _textSizeBlock(BuildContext context, AppLocalizations l10n) {
    final p = SettingsScope.paletteOf(context);
    final accent = SettingsScope.appColorsOf(context).accentPrimary;
    final steps = DesktopUiPrefs.textScaleSteps;
    final scale = DesktopUiPrefs.textScale.value;
    final index = steps.indexOf(scale).clamp(0, steps.length - 1);
    // Знак процента ставится по-разному: «90%» в английском, «90 %» в
    // русском и французском. Строку собирает `intl`, а не руки.
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toString(),
    );
    String label(double v) => percent.format(v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsSectionTitle(
          l10n.desktopAppearanceTextSize,
          trailing: Text(
            label(scale),
            style: TextStyle(
              fontFamily: DType.family,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Образцы «Aa» не масштабируются вместе с текстом окна: это
            // шкала, и она должна оставаться шкалой.
            Text(
              'Aa',
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontFamily: DType.family, fontSize: 12, color: p.faint),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, box) {
                  final w = box.maxWidth;
                  const inset = 14.0;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SettingsSlider(
                        value: index.toDouble(),
                        min: 0,
                        max: (steps.length - 1).toDouble(),
                        divisions: steps.length - 1,
                        semanticLabel: l10n.desktopAppearanceTextSize,
                        semanticValue: label(scale),
                        onChanged: (v) => unawaited(
                          DesktopUiPrefs.setTextScale(steps[v.round()]),
                        ),
                      ),
                      SizedBox(
                        height: 16,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (var i = 0; i < steps.length; i++)
                              Positioned(
                                left: inset +
                                    (w - inset * 2) * i / (steps.length - 1) -
                                    20,
                                width: 40,
                                child: Text(
                                  '${(steps[i] * 100).round()}',
                                  textAlign: TextAlign.center,
                                  textScaler: TextScaler.noScaling,
                                  style: TextStyle(
                                    fontFamily: DType.family,
                                    fontSize: 11,
                                    fontWeight: i == index
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: i == index ? p.head : p.faint,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Aa',
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontFamily: DType.family, fontSize: 19, color: p.faint),
            ),
          ],
        ),
      ],
    );
  }

  // ── Вкладка «Фон чата» ─────────────────────────────────────────────────

  List<DesktopWallpaperChoice> _staticChoices(
    AppLocalizations l10n, {
    required bool dark,
  }) {
    final ctrl = widget.vm?.controller;
    return buildDesktopWallpaperChoices(
      l10n: l10n,
      dark: dark,
      bundledAssets: _bundledWallpapers,
      profileFiles: ctrl?.profileBackgroundPaths ?? const <String>[],
      server: _serverWallpapers,
    ).where((w) => decodeAnimatedChatWallpaperStyle(w.id) == null).toList();
  }

  List<Widget> _wallpaperTab(
    BuildContext context,
    AppLocalizations l10n,
    String wallpaperId,
    bool isLive,
    ChatWallpaperAnimMode animMode,
  ) {
    final ctrl = widget.vm?.controller;
    final p = SettingsScope.paletteOf(context);
    final app = SettingsScope.appColorsOf(context);
    final showLive = _liveFilter ?? isLive;
    final statics = _staticChoices(l10n, dark: app.isDark);
    final lives = [
      for (final style in WallpaperStyles.all)
        DesktopWallpaperChoice(
          id: encodeAnimatedChatWallpaperId(style.key),
          title: style.name,
          premium: true,
        ),
    ];
    final list = showLive ? lives : statics;
    return [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              spacing: 12,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SettingsSectionTitle(l10n.desktopAppearanceWallpaper),
                      const SizedBox(height: 4),
                      SettingsDescription(l10n.desktopAppearanceWallpaperAllChats),
                    ],
                  ),
                ),
                SettingsSegmented<bool>(
                  expand: false,
                  values: const [false, true],
                  labels: [
                    l10n.desktopAppearanceStatic,
                    l10n.desktopAppearanceLive,
                  ],
                  counts: [statics.length, lives.length],
                  value: showLive,
                  onChanged: (v) => setState(() => _liveFilter = v),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _AutoGrid(
              minTileWidth: 92,
              gap: 10,
              aspectRatio: 3 / 4,
              children: [
                for (final choice in list)
                  DesktopWallpaperTile(
                    choice: choice,
                    selected: choice.id == wallpaperId,
                    locked: !_allowed(CosmeticKind.wallpaper, choice.id),
                    onTap: ctrl == null
                        ? null
                        : () => unawaited(_selectWallpaper(choice.id)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(FluentIcons.brightness_high_24_regular, size: 19, color: p.muted),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: Text(
                    l10n.desktopAppearanceDim,
                    style: TextStyle(fontFamily: DType.family, fontSize: 14, color: p.text),
                  ),
                ),
                Expanded(
                  child: SettingsSlider(
                    value: DesktopUiPrefs.wallpaperDim.value.toDouble(),
                    min: 0,
                    max: DesktopUiPrefs.wallpaperDimMax.toDouble(),
                    divisions: DesktopUiPrefs.wallpaperDimMax ~/ 5,
                    semanticLabel: l10n.desktopAppearanceDim,
                    semanticValue: '${DesktopUiPrefs.wallpaperDim.value} %',
                    onChanged: (v) =>
                        unawaited(DesktopUiPrefs.setWallpaperDim(v.round())),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    NumberFormat.percentPattern(
                      Localizations.localeOf(context).toString(),
                    ).format(DesktopUiPrefs.wallpaperDim.value / 100),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: DType.family,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      SettingsSection(
        title: l10n.desktopAppearanceAnimPattern,
        badge: isLive ? null : l10n.desktopAppearanceLiveOnlyBadge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔴 ОДИН ВЫБОР ИЗ ЧЕТЫРЁХ — СЕГМЕНТАМИ, А НЕ ЧЕТЫРЬМЯ
            // ПЕРЕКЛЮЧАТЕЛЯМИ. Прежние четыре тумблера позволяли «выключить»
            // выбранный режим и не говорили, что включённым может быть только
            // один.
            Opacity(
              opacity: isLive ? 1 : 0.45,
              child: SettingsSegmented<ChatWallpaperAnimMode>(
                enabled: isLive && ctrl != null,
                values: const [
                  ChatWallpaperAnimMode.continuous,
                  ChatWallpaperAnimMode.onEnter,
                  ChatWallpaperAnimMode.tap,
                  ChatWallpaperAnimMode.off,
                ],
                labels: [
                  l10n.desktopWallAnimShortContinuous,
                  l10n.desktopWallAnimShortOnEnter,
                  l10n.desktopWallAnimShortTap,
                  l10n.desktopWallAnimShortOff,
                ],
                icons: const [
                  FluentIcons.arrow_repeat_all_24_regular,
                  FluentIcons.open_24_regular,
                  FluentIcons.cursor_click_24_regular,
                  FluentIcons.pause_circle_24_regular,
                ],
                value: animMode,
                onChanged: (m) => unawaited(ctrl?.setChatWallpaperAnimMode(m)),
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: isLive ? 1 : 0.45,
              child: SettingsToggleCard(
                icon: FluentIcons.weather_squalls_24_regular,
                title: l10n.desktopAppearanceWallPulse,
                subtitle: l10n.desktopAppearanceWallPulseHint,
                value: ctrl?.chatWallpaperConduct ?? false,
                onChanged: isLive && ctrl != null
                    ? (v) => unawaited(ctrl.setChatWallpaperConduct(v))
                    : null,
              ),
            ),
            if (!isLive) ...[
              const SizedBox(height: 10),
              _GoLiveHint(
                text: l10n.desktopAppearanceGoLive('\u0000'),
                link: l10n.desktopAppearanceGoLiveLink,
                onTap: () => setState(() => _liveFilter = true),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  // ── Вкладка «Сообщения» ────────────────────────────────────────────────

  List<Widget> _messagesTab(BuildContext context, AppLocalizations l10n) {
    final ctrl = widget.vm?.controller;
    final p = SettingsScope.paletteOf(context);
    final app = SettingsScope.appColorsOf(context);
    final dark = app.isDark;
    final bubbleId = normalizeChatBubbleStylePresetId(
      ctrl?.chatBubbleStylePresetId ?? 'flutter_dash',
    );
    final bubble = resolveChatBubbleStylePreset(bubbleId);
    final indicatorId = ctrl?.indicatorColorPresetId ?? 'theme';
    final indicator = resolveIndicatorColorPreset(indicatorId);
    final names = _currentNames();
    return [
      SettingsSection(
        title: l10n.desktopAppearanceBubbleStyle,
        titleTrailing: Text(
          _dataName(context, bubble.nameRu, bubble.nameEn),
          style: TextStyle(
            fontFamily: DType.family,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: p.head,
          ),
        ),
        description: l10n.desktopAppearanceBubbleStyleHint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _AutoGrid(
              minTileWidth: 76,
              gap: 8,
              children: [
                for (final b in kChatBubbleStylePresets)
                  _BubbleTile(
                    preset: b,
                    name: _dataName(context, b.nameRu, b.nameEn),
                    selected: b.id == bubbleId,
                    locked: !_allowed(CosmeticKind.bubbleStyle, b.id),
                    onTap: ctrl == null ? null : () => unawaited(_selectBubble(b.id)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    l10n.desktopAppearanceShape,
                    style: TextStyle(fontFamily: DType.family, fontSize: 14, color: p.text),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
                  child: SettingsSegmented<String>(
                    values: DesktopUiPrefs.bubbleShapeValues,
                    labels: [
                      l10n.desktopAppearanceShapeSharp,
                      l10n.desktopAppearanceShapeMedium,
                      l10n.desktopAppearanceShapeRound,
                    ],
                    leading: [
                      for (final r in const [2.0, 5.0, 8.0])
                        (Color color) => Container(
                          width: 18,
                          height: 12,
                          decoration: BoxDecoration(
                            border: Border.all(color: color, width: 2),
                            borderRadius: BorderRadius.circular(r),
                          ),
                        ),
                    ],
                    value: DesktopUiPrefs.bubbleShape.value,
                    onChanged: (v) => unawaited(DesktopUiPrefs.setBubbleShape(v)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      _TwoColumns(
        minColumnWidth: 260,
        left: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsSectionTitle(l10n.desktopAppearanceSenderColour),
            const SizedBox(height: 4),
            SettingsDescription(l10n.desktopAppearanceSenderColourHint),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // «Разноцветные» — цвета тех же людей, что в предпросмотре
                // справа: у каждого свой, как в настоящей группе.
                _NameChip(
                  label: l10n.desktopAppearanceNamesMulti,
                  first: AvatarInitials.nicknameColor(
                    seed: 'appearance-preview-0',
                  ),
                  second: AvatarInitials.nicknameColor(
                    seed: 'appearance-preview-1',
                  ),
                  selected: names == 'person',
                  onTap: () => unawaited(_selectNames('person')),
                ),
                for (final n in kNicknameStylePresets)
                  _NameChip(
                    label: _dataName(context, n.nameRu, n.nameEn),
                    first: desktopSenderNameColor(
                      presetId: n.id,
                      accent: app.accentPrimary,
                      dark: dark,
                    ),
                    second: n.id == 'accent'
                        ? app.accentPrimary.withValues(alpha: 0.6)
                        : n.outgoing,
                    selected: names == n.id,
                    onTap: ctrl == null ? null : () => unawaited(_selectNames(n.id)),
                  ),
              ],
            ),
          ],
        ),
        right: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsSectionTitle(
              l10n.desktopAppearanceIndicatorColour,
              trailing: Text(
                _dataName(context, indicator.nameRu, indicator.nameEn),
                style: TextStyle(
                  fontFamily: DType.family,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.head,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SettingsDescription(l10n.desktopAppearanceIndicatorHint),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in kIndicatorColorPresets)
                  _ColorDot(
                    size: 28,
                    color: resolveIndicatorColor(
                      presetId: i.id,
                      accent: app.accentPrimary,
                      dark: dark,
                    ),
                    icon: i.followsTheme ? FluentIcons.sparkle_16_filled : null,
                    tooltip: _dataName(context, i.nameRu, i.nameEn),
                    selected: i.id == indicatorId,
                    locked: !_allowed(CosmeticKind.indicatorColor, i.id),
                    onTap: ctrl == null
                        ? null
                        : () => unawaited(_selectIndicator(i.id)),
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  // ── Итог ───────────────────────────────────────────────────────────────

  Widget _summary(BuildContext context, AppLocalizations l10n, String wallpaperId) {
    final p = SettingsScope.paletteOf(context);
    final ctrl = widget.vm?.controller;
    final app = SettingsScope.appColorsOf(context);
    final scheme = switch (DesktopUiPrefs.themeMode.value) {
      'light' => l10n.desktopAppearanceSummaryLight,
      'auto' => l10n.desktopAppearanceSummarySystem,
      _ => l10n.desktopAppearanceSummaryDark,
    };
    final live = decodeAnimatedChatWallpaperStyle(wallpaperId);
    String wallpaperName = live?.name ?? '';
    if (live == null) {
      for (final w in _staticChoices(l10n, dark: app.isDark)) {
        if (w.id == wallpaperId) {
          wallpaperName = w.title;
          break;
        }
      }
    }
    final bubble = resolveChatBubbleStylePreset(
      ctrl?.chatBubbleStylePresetId ?? 'flutter_dash',
    );
    final text = NumberFormat.percentPattern(
      Localizations.localeOf(context).toString(),
    ).format(DesktopUiPrefs.textScale.value);
    final parts = <String>[
      scheme,
      if (wallpaperName.isNotEmpty) wallpaperName,
      l10n.desktopAppearanceSummaryBubbles(
        _dataName(context, bubble.nameRu, bubble.nameEn),
      ),
      l10n.desktopAppearanceSummaryText(text),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(FluentIcons.info_16_regular, size: 18, color: p.faint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${l10n.desktopAppearanceSummaryPrefix} ${parts.join(' · ')}',
              style: TextStyle(
                fontFamily: DType.family,
                fontSize: 13,
                height: 1.4,
                color: p.faint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Снимок вида до «По умолчанию» — для «Вернуть».
class _AppearanceSnapshot {
  const _AppearanceSnapshot({
    required this.themeMode,
    required this.customAccent,
    required this.themeId,
    required this.bubbleId,
    required this.wallpaperId,
    required this.animMode,
    required this.conduct,
    required this.indicatorId,
    required this.nicknameId,
    required this.names,
    required this.textScale,
    required this.density,
    required this.shape,
    required this.dim,
  });

  final String themeMode;
  final int customAccent;
  final String themeId;
  final String bubbleId;
  final String wallpaperId;
  final ChatWallpaperAnimMode animMode;
  final bool conduct;
  final String indicatorId;
  final String nicknameId;
  final String names;
  final double textScale;
  final String density;
  final String shape;
  final int dim;
}

// ── Раскладка ─────────────────────────────────────────────────────────────

/// Сетка «сколько влезет, но не уже [minTileWidth]» — `repeat(auto-fill,
/// minmax(…, 1fr))` макета: плитки растягиваются поровну и заполняют ряд.
class _AutoGrid extends StatelessWidget {
  const _AutoGrid({
    required this.minTileWidth,
    required this.gap,
    required this.children,
    this.aspectRatio,
    this.maxColumns,
  });

  final double minTileWidth;
  final double gap;
  final List<Widget> children;

  /// Ширина к высоте; `null` — высота по содержимому.
  final double? aspectRatio;
  final int? maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, box) {
        final w = box.maxWidth;
        var cols = ((w + gap) / (minTileWidth + gap)).floor();
        if (cols < 1) cols = 1;
        if (maxColumns != null && cols > maxColumns!) cols = maxColumns!;
        final tile = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(
                width: tile,
                height: aspectRatio == null ? null : tile / aspectRatio!,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

/// Две колонки через 24, как в макете (`auto-fit, minmax(…, 1fr)`); узко —
/// одна под другой. Внизу — черта раздела.
class _TwoColumns extends StatelessWidget {
  const _TwoColumns({
    required this.minColumnWidth,
    required this.left,
    required this.right,
  });

  final double minColumnWidth;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: LayoutBuilder(
        builder: (ctx, box) {
          if (box.maxWidth < minColumnWidth * 2 + 24) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: 24), right],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 24),
              Expanded(child: right),
            ],
          );
        },
      ),
    );
  }
}

// ── Плитки ────────────────────────────────────────────────────────────────

/// Карточка готового набора: обои набора с полоской «чужого» и пузырём
/// «своего» сообщения, под ними — точка акцента и имя.
class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.name,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final DesktopAppearancePreset preset;
  final String name;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final app = SettingsScope.appColorsOf(context);
    final dark = app.isDark;
    final theme = resolveAppThemePreset(preset.themeId);
    final accent = preset.customAccent ??
        legibleAccent(dark ? theme.darkPrimary : theme.lightPrimary, dark: dark);
    final bubble = resolveChatBubbleStylePreset(preset.bubbleId);
    final bubbleColors = bubble.colorsFor(dark);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: HoverListener(
        onTap: onTap,
        cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        builder: (ctx, hovered, _) => AnimatedContainer(
          duration: DMotion.fast,
          decoration: BoxDecoration(
            color: hovered ? Color.lerp(p.card, p.head, 0.04) : p.card,
            borderRadius: BorderRadius.circular(10),
            boxShadow: settingsCardRing(
              selected: selected,
              accent: app.accentPrimary,
              border: p.border,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 64,
                  child: LayoutBuilder(
                    // Полоска «чужого» — 56 % ширины, пузырь «своего» — 52 %,
                    // как в макете.
                    builder: (ctx, box) => Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          child: DesktopWallpaperPreview(
                            wallpaperId: preset.wallpaper(dark: dark),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          top: 10,
                          width: box.maxWidth * 0.56,
                          height: 12,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          width: box.maxWidth * 0.52,
                          height: 16,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: bubbleColors,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: DType.family,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: p.head,
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(
                          FluentIcons.checkmark_circle_16_filled,
                          size: 17,
                          color: app.accentPrimary,
                        )
                      else if (locked)
                        Icon(FluentIcons.lock_closed_12_filled, size: 13, color: p.faint),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Карточка схемы: окно Secretly в миниатюре — рейка, список чатов, переписка
/// с чужим и своим пузырём — В НАСТОЯЩИХ ЦВЕТАХ ЭТОГО ОКНА.
///
/// 🔴 30.09.2026, владелец: «превью… не те, что у нас на самом деле». Первая
/// версия рисовала схемы серыми тонами макета настроек, а окно переписки у нас
/// сине-чёрное (или светлое) — карточка «Тёмная» не была похожа на тёмное окно
/// Secretly. Теперь цвета — из той же палитры, что строит корень окна
/// ([_DesktopAppearancePaneState._paletteFor]): с выбранным акцентом, стилем
/// пузырей и индикаторами. «Системная» — половина тёмного окна и половина
/// светлого.
class _SchemeCard extends StatelessWidget {
  const _SchemeCard({
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.darkColors,
    required this.lightColors,
  });

  final String mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final DColorSet darkColors;
  final DColorSet lightColors;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final accent = SettingsScope.appColorsOf(context).accentPrimary;
    final icon = switch (mode) {
      'dark' => FluentIcons.weather_moon_24_regular,
      'light' => FluentIcons.weather_sunny_24_regular,
      _ => FluentIcons.desktop_24_regular,
    };
    final window = switch (mode) {
      'dark' => _MiniWindow(colors: darkColors),
      'light' => _MiniWindow(colors: lightColors),
      _ => Stack(
        fit: StackFit.expand,
        children: [
          _MiniWindow(colors: darkColors),
          ClipRect(
            clipper: const _RightHalfClipper(),
            child: _MiniWindow(colors: lightColors),
          ),
        ],
      ),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: HoverListener(
        onTap: onTap,
        cursor: SystemMouseCursors.click,
        builder: (ctx, hovered, _) => AnimatedContainer(
          duration: DMotion.fast,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hovered ? Color.lerp(p.card, p.head, 0.04) : p.card,
            borderRadius: BorderRadius.circular(10),
            boxShadow: settingsCardRing(
              selected: selected,
              accent: accent,
              border: p.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(height: 58, child: window),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 2),
                child: Row(
                  children: [
                    Icon(icon, size: 17, color: p.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: DType.family,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.head,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Окно Secretly в миниатюре: рейка, список, переписка.
class _MiniWindow extends StatelessWidget {
  const _MiniWindow({required this.colors});

  final DColorSet colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    Widget bar(double height, Color color) => Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    final lines = c.textDisabled.withValues(alpha: 0.55);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Рейка разделов.
        Expanded(
          flex: 9,
          child: ColoredBox(
            color: c.sidebar,
            child: Column(
              children: [
                const SizedBox(height: 6),
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == 0
                            ? c.accentPrimary
                            : c.railIconIdle.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Список переписок.
        Expanded(
          flex: 30,
          child: Container(
            color: c.chatList,
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Column(
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.avatarNeutral,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              bar(3, lines),
                              const SizedBox(height: 2),
                              FractionallySizedBox(
                                widthFactor: 0.6,
                                child: bar(3, lines.withValues(alpha: 0.35)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Переписка: чужой пузырь сверху, свой — переходом выбранного стиля.
        Expanded(
          flex: 61,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.76, -1.0),
                radius: 1.3,
                colors: [c.threadGlow, c.thread, c.threadEdge],
                stops: const [0.0, 0.58, 1.0],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.62,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: c.bubblePeer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.55,
                      child: Container(
                        height: 11,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              c.bubbleSelfStart,
                              if (c.bubbleSelfMid != null) c.bubbleSelfMid!,
                              if (c.bubbleSelfMid2 != null) c.bubbleSelfMid2!,
                              c.bubbleSelfEnd,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Правая половина — для «Системной»: слева тёмное окно, справа светлое.
class _RightHalfClipper extends CustomClipper<Rect> {
  const _RightHalfClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

/// Кружок цвета (акцент, индикатор): у выбранного — галочка и двойное
/// кольцо, у платного без подписки — замочек в углу.
class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.size,
    required this.color,
    required this.tooltip,
    required this.selected,
    required this.onTap,
    this.locked = false,
    this.icon,
  });

  final double size;
  final Color color;
  final String tooltip;
  final bool selected;
  final bool locked;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        excludeSemantics: true,
        child: HoverListener(
          onTap: onTap,
          cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
          builder: (ctx, hovered, _) => AnimatedScale(
            duration: DMotion.fast,
            scale: hovered && !selected ? 1.08 : 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: DMotion.fast,
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: settingsSwatchRing(
                      selected: selected,
                      color: color,
                      page: p.main,
                    ),
                  ),
                  child: Center(
                    child: selected
                        ? Icon(
                            FluentIcons.checkmark_12_filled,
                            size: size * 0.5,
                            color: Colors.white,
                          )
                        : (icon == null
                              ? null
                              : Icon(icon, size: size * 0.5, color: Colors.white)),
                  ),
                ),
                if (locked && !selected)
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: p.ter,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.main, width: 1.5),
                      ),
                      child: Icon(
                        FluentIcons.lock_closed_12_filled,
                        size: 8,
                        color: p.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «Свой цвет»: радуга с пипеткой, пока своего нет; сам цвет — когда выбран.
class _CustomAccentDot extends StatelessWidget {
  const _CustomAccentDot({
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final Color? color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final c = color;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: c != null,
        label: tooltip,
        excludeSemantics: true,
        child: HoverListener(
          onTap: onTap,
          cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
          builder: (ctx, hovered, _) => AnimatedScale(
            duration: DMotion.fast,
            scale: hovered ? 1.08 : 1,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c,
                gradient: c != null
                    ? null
                    : const SweepGradient(
                        colors: [
                          Color(0xFFED4245),
                          Color(0xFFF0B232),
                          Color(0xFF23A55A),
                          Color(0xFF00A8FC),
                          Color(0xFF5865F2),
                          Color(0xFFEB459E),
                          Color(0xFFED4245),
                        ],
                      ),
                boxShadow: settingsSwatchRing(
                  selected: c != null,
                  color: c ?? Colors.transparent,
                  page: p.main,
                ),
              ),
              child: const Center(
                child: Icon(
                  FluentIcons.eyedropper_24_regular,
                  size: 17,
                  color: Colors.white,
                  shadows: [Shadow(color: Color(0x66000000), blurRadius: 2)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Плитка стиля пузырей: сам пузырь в цветах набора и имя под ним.
class _BubbleTile extends StatelessWidget {
  const _BubbleTile({
    required this.preset,
    required this.name,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final ChatBubbleStylePreset preset;
  final String name;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final app = SettingsScope.appColorsOf(context);
    return Tooltip(
      message: name,
      child: Semantics(
        button: true,
        selected: selected,
        label: name,
        excludeSemantics: true,
        child: HoverListener(
          onTap: onTap,
          cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
          builder: (ctx, hovered, _) => AnimatedContainer(
            duration: DMotion.fast,
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 7),
            decoration: BoxDecoration(
              color: selected ? p.sel : (hovered ? p.hover : p.card),
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected
                  ? [BoxShadow(color: app.accentPrimary, spreadRadius: 2)]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 22,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: preset.colorsFor(app.isDark),
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(11),
                          topRight: Radius.circular(11),
                          bottomLeft: Radius.circular(11),
                          bottomRight: Radius.circular(3),
                        ),
                      ),
                    ),
                    if (locked)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: p.ter,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.card, width: 1.5),
                          ),
                          child: Icon(
                            FluentIcons.lock_closed_12_filled,
                            size: 8,
                            color: p.muted,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: DType.family,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? p.head : p.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Фишка цвета имён: два кружка и имя этим цветом.
class _NameChip extends StatelessWidget {
  const _NameChip({
    required this.label,
    required this.first,
    required this.second,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color first;
  final Color second;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final accent = SettingsScope.appColorsOf(context).accentPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: HoverListener(
        onTap: onTap,
        cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        builder: (ctx, hovered, _) => AnimatedContainer(
          duration: DMotion.fast,
          padding: const EdgeInsets.fromLTRB(7, 6, 10, 6),
          decoration: BoxDecoration(
            color: selected ? p.sel : (hovered ? p.hover : p.card),
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [BoxShadow(color: accent, spreadRadius: 2)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 23,
                height: 14,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      child: _dot(first, null),
                    ),
                    Positioned(
                      left: 9,
                      child: _dot(second, selected ? p.sel : p.card),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: DType.family,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: first,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _dot(Color color, Color? ring) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: ring == null
          ? null
          : [BoxShadow(color: ring, spreadRadius: 2)],
    ),
  );
}

/// «Выберите живые обои, чтобы настроить анимацию» — со ссылкой-переходом.
class _GoLiveHint extends StatelessWidget {
  const _GoLiveHint({
    required this.text,
    required this.link,
    required this.onTap,
  });

  /// Фраза, где на месте ссылки стоит `\u0000`.
  final String text;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final accent = SettingsScope.appColorsOf(context).accentPrimary;
    final parts = text.split('\u0000');
    final style = TextStyle(fontFamily: DType.family, fontSize: 13, color: p.faint);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (parts.isNotEmpty && parts.first.isNotEmpty)
          Text(parts.first, style: style),
        Semantics(
          link: true,
          label: link,
          excludeSemantics: true,
          child: HoverListener(
            onTap: onTap,
            cursor: SystemMouseCursors.click,
            builder: (ctx, hovered, _) => Text(
              link,
              style: style.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
                decoration: hovered ? TextDecoration.underline : null,
                decorationColor: accent,
              ),
            ),
          ),
        ),
        if (parts.length > 1 && parts.last.isNotEmpty)
          Text(parts.last, style: style),
      ],
    );
  }
}
