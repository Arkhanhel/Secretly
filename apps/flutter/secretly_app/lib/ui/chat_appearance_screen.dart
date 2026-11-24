// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// «Настройки → Чаты → Оформление» на одном экране — макет владельца
/// «Chat Appearance v2» (20.11.2026), для Android и iPhone.
///
/// Сверху закреплено превью, под ним лента из восьми категорий (как в
/// макете: Тема, Фон, Обои, Пузыри, Текст, Иконки, Значок, Поведение), ниже —
/// одна открытая категория. Её варианты помещаются почти без прокрутки:
/// вместо длинной страницы с семью каруселями человек видит 6–12 вариантов
/// одного типа. Превью меняется под категорию: переписка, список настроек
/// (для «Иконок») или главный экран телефона (для «Значка»). Точка на вкладке
/// — в категории есть отличия от стандартного оформления; «Сбросить»
/// возвращает всё, кроме защиты и значка приложения.
///
/// Ползунки (размер текста, скругление) двигают превью вживую и пишут на
/// диск один раз — когда палец отпущен (`chat_look_prefs.dart`).
///
/// Покупки и Premium-ограничения не дублируются здесь: экран зовёт те же
/// функции настроек ([ChatAppearanceDelegate]), что и прежняя страница.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../entitlements/cosmetic_catalog.dart';
import '../l10n/app_localizations.dart';
import '../security/screen_privacy.dart';
import 'app_backdrop.dart';
import 'chat_look_prefs.dart';
import 'chat_wallpapers.dart';
import 'haptics.dart';
import 'liquid_glass_flags.dart';
import 'motion/app_dialogs.dart';
import 'motion/motion.dart';
import 'premium/app_icon_picker.dart';
import 'secretly_snackbar.dart';
import 'apple_controls.dart' show SecretlyAlertDialog;
import 'apple_glass.dart' show AppleGlassPanel, panelCardsEnabled;
import 'settings_apple_root.dart' show appleSecondaryLabel;
import 'settings_icons/settings_glyph_tile.dart';
import 'settings_icons/settings_glyphs.dart';
import 'settings_icons/settings_icon_style.dart';
import 'settings_screen_l10n.dart';
import 'theme_presets.dart';
import 'theme_transition.dart';
import 'widgets/frosted_top_bar.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';

/// Выключатель нового экрана: `false` — прежняя длинная страница «Чаты» с
/// каруселями (мгновенный откат, ничего больше менять не нужно).
const bool kChatAppearanceV2 = true;

/// То, что экран берёт у настроек: живое превью переписки, проверки Premium
/// и выбор обоев (с окном анимированных обоев и полным списком).
class ChatAppearanceDelegate {
  const ChatAppearanceDelegate({
    required this.controller,
    required this.chatPreview,
    required this.isLocked,
    required this.pickCosmetic,
    required this.wallpaperOptions,
    required this.pickWallpaper,
    required this.openAllWallpapers,
  });

  final AppController controller;

  /// Настоящее превью переписки (те же обои, пузыри и цвета, что в чате).
  final Widget Function(BuildContext context, double height) chatPreview;
  final bool Function(CosmeticKind kind, String id) isLocked;
  final Future<void> Function(
    BuildContext context, {
    required CosmeticKind kind,
    required String id,
    required Future<void> Function() apply,
  })
  pickCosmetic;
  final List<ChatWallpaperOption> Function(BuildContext context)
  wallpaperOptions;
  final Future<void> Function(BuildContext context, ChatWallpaperOption option)
  pickWallpaper;

  /// Полный выбор обоев: свои фото, анимированные, с сервера.
  final Future<void> Function(BuildContext context) openAllWallpapers;
}

enum AppearanceTab {
  theme,
  background,
  wallpaper,
  bubbles,
  text,
  icons,
  appIcon,
  behavior,
}

extension on AppearanceTab {
  SettingsGlyph get glyph => switch (this) {
    AppearanceTab.theme => SettingsGlyph.appearance,
    AppearanceTab.wallpaper => SettingsGlyph.wallpaper,
    AppearanceTab.bubbles => SettingsGlyph.bubbles,
    AppearanceTab.background => SettingsGlyph.background,
    AppearanceTab.text => SettingsGlyph.text,
    AppearanceTab.icons => SettingsGlyph.iconStyle,
    AppearanceTab.appIcon => SettingsGlyph.appIcon,
    AppearanceTab.behavior => SettingsGlyph.behavior,
  };

  String title(AppLocalizations l) => switch (this) {
    AppearanceTab.theme => l.appearanceTabTheme,
    AppearanceTab.wallpaper => l.appearanceTabWallpaper,
    AppearanceTab.bubbles => l.appearanceTabBubbles,
    AppearanceTab.background => l.appearanceTabBackground,
    AppearanceTab.text => l.appearanceTabText,
    AppearanceTab.icons => l.appearanceTabIcons,
    AppearanceTab.appIcon => l.appearanceTabAppIcon,
    AppearanceTab.behavior => l.appearanceTabBehavior,
  };

  String description(AppLocalizations l) => switch (this) {
    AppearanceTab.theme => l.appearanceTabThemeDesc,
    AppearanceTab.wallpaper => l.appearanceTabWallpaperDesc,
    AppearanceTab.background => l.appearanceTabBackgroundDesc,
    AppearanceTab.bubbles => l.appearanceTabBubblesShapeDesc,
    AppearanceTab.text => l.appearanceTabTextDesc,
    AppearanceTab.icons => l.appearanceTabIconsDesc,
    AppearanceTab.appIcon => l.appearanceTabAppIconDesc,
    AppearanceTab.behavior => l.appearanceTabBehaviorDesc,
  };
}


class ChatAppearanceScreen extends StatefulWidget {
  const ChatAppearanceScreen({
    super.key,
    required this.delegate,
    this.initialTab = AppearanceTab.theme,
  });

  final ChatAppearanceDelegate delegate;
  final AppearanceTab initialTab;

  @override
  State<ChatAppearanceScreen> createState() => _ChatAppearanceScreenState();
}

class _ChatAppearanceScreenState extends State<ChatAppearanceScreen> {
  late final List<AppearanceTab> _tabs = <AppearanceTab>[
    for (final t in AppearanceTab.values)
      if (t != AppearanceTab.appIcon || AppIconService.isSupportedPlatform) t,
  ];
  late int _index = _tabs.indexOf(widget.initialTab).clamp(0, _tabs.length - 1);
  late final PageController _pages = PageController(initialPage: _index);
  final ScrollController _strip = ScrollController();
  final List<GlobalKey> _tabKeys = <GlobalKey>[];

  AppController get _c => widget.delegate.controller;

  @override
  void initState() {
    super.initState();
    _tabKeys.addAll(List<GlobalKey>.generate(_tabs.length, (_) => GlobalKey()));
    SettingsIconStylePrefs.ensureLoaded();
    if (AppIconService.isSupportedPlatform) AppIconService.currentIconKey();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerTab(animate: false));
  }

  @override
  void dispose() {
    _pages.dispose();
    _strip.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index < 0 || index >= _tabs.length) return;
    Haptics.tap();
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Motion.standard,
    );
  }

  void _onPage(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    _centerTab();
  }

  /// Выбранная вкладка встаёт по центру ленты.
  void _centerTab({bool animate = true}) {
    final ctx = _tabKeys[_index].currentContext;
    if (ctx == null || !_strip.hasClients) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: animate ? const Duration(milliseconds: 260) : Duration.zero,
      curve: Motion.standard,
    );
  }

  Future<void> _reset() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showAppDialog<bool>(
      context: context,
      // Окно iOS на iPhone, обычное на Android — общий компонент приложения.
      builder: (ctx) => SecretlyAlertDialog(
        title: Text(l.appearanceResetTitle),
        content: Text(l.appearanceResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.reset),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Haptics.tap();
    await SettingsIconStylePrefs.reset();
    await ChatLookPrefs.reset();
    await _c.resetAppearance();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ios = _isIos;
    return StreamBuilder<void>(
      stream: _c.changed,
      builder: (context, _) => SettingsIconStyleBuilder(
        builder: (context, style) => ValueListenableBuilder<String>(
          valueListenable: AppIconService.current,
          builder: (context, iconKey, _) {
            final media = MediaQuery.of(context);
            final previewHeight = (media.size.height * 0.33).clamp(200.0, 292.0);
            final tab = _tabs[_index];
            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: frostedAppBar(
                // Заголовок — как строка в настройках («Стиль», 23.11.2026).
                title: Text(l.settingsStyleSection),
                centerTitle: ios,
                actions: [
                  TextButton(onPressed: _reset, child: Text(l.reset)),
                  const SizedBox(width: 4),
                ],
              ),
              body: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  media.padding.top + kToolbarHeight + 4,
                  12,
                  media.padding.bottom + 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: previewHeight,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: KeyedSubtree(
                          key: ValueKey<String>(switch (tab) {
                            AppearanceTab.icons => 'settings',
                            AppearanceTab.appIcon => 'home',
                            _ => 'chat',
                          }),
                          child: switch (tab) {
                            AppearanceTab.icons => _SettingsListPreview(
                              style: style,
                            ),
                            AppearanceTab.appIcon => _HomeScreenPreview(
                              iconKey: iconKey,
                            ),
                            _ => widget.delegate.chatPreview(
                              context,
                              previewHeight,
                            ),
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _TabStrip(
                      controller: _strip,
                      tabs: _tabs,
                      keys: _tabKeys,
                      index: _index,
                      style: style,
                      onTap: _go,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PanelHeader(
                              title: tab.title(l),
                              description: tab.description(l),
                              index: _index,
                              count: _tabs.length,
                              onPrev: _index > 0 ? () => _go(_index - 1) : null,
                              onNext: _index < _tabs.length - 1
                                  ? () => _go(_index + 1)
                                  : null,
                            ),
                            Expanded(
                              child: PageView.builder(
                                controller: _pages,
                                onPageChanged: _onPage,
                                itemCount: _tabs.length,
                                itemBuilder: (context, i) => SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                                  child: _tabBody(context, _tabs[i], style),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tabBody(BuildContext context, AppearanceTab tab, SettingsIconStyle style) {
    final d = widget.delegate;
    switch (tab) {
      case AppearanceTab.theme:
        return _ThemeTab(delegate: d);
      case AppearanceTab.wallpaper:
        return _WallpaperTab(delegate: d);
      case AppearanceTab.bubbles:
        return _BubblesTab(delegate: d);
      case AppearanceTab.background:
        return _BackgroundTab(controller: d.controller);
      case AppearanceTab.text:
        return _TextTab(delegate: d);
      case AppearanceTab.icons:
        return _IconStylesTab(selected: style);
      case AppearanceTab.appIcon:
        return _AppIconTab(controller: d.controller);
      case AppearanceTab.behavior:
        return _BehaviorTab(controller: d.controller);
    }
  }
}

// ─── Оболочка ───────────────────────────────────────────────────────────────

// Платформа берётся из `defaultTargetPlatform`, а не из `dart:io`: так тесты
// могут нарисовать экран в виде iPhone, а в приложении это одно и то же.
bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;
bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

Color _accent(BuildContext context) => Theme.of(context).colorScheme.primary;

Color _secondary(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return _isIos
      ? appleSecondaryLabel(dark)
      : Theme.of(context).colorScheme.onSurfaceVariant;
}

/// Панель категории: та же панель, что во всех настройках (вид — по
/// «Прозрачным плашкам»; 23.11.2026, владелец: «на странице „Чаты“ плашки
/// забыл»). На компьютере — прежняя плотная карточка Material.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (panelCardsEnabled) {
      return AppleGlassPanel(radius: 24, child: child);
    }
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: dark ? 0.9 : 0.95),
        borderRadius: BorderRadius.circular(26),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(26), child: child),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.description,
    required this.index,
    required this.count,
    required this.onPrev,
    required this.onNext,
  });

  final String title;
  final String description;
  final int index;
  final int count;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final secondary = _secondary(context);
    Widget arrow(IconData icon, String label, VoidCallback? onTap) => Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.onSurface.withValues(alpha: 0.07),
          ),
          child: Icon(
            icon,
            size: 20,
            color: cs.onSurface.withValues(alpha: onTap == null ? 0.3 : 0.9),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: secondary),
                ),
              ],
            ),
          ),
          Text(
            '${index + 1} / $count',
            semanticsLabel: l.appearanceTabPosition(index + 1, count),
            style: TextStyle(
              fontSize: 12,
              color: secondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          arrow(AdaptiveIcons.chevron_left_rounded, l.appearancePrevTab, onPrev),
          arrow(AdaptiveIcons.chevron_right_rounded, l.appearanceNextTab, onNext),
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.controller,
    required this.tabs,
    required this.keys,
    required this.index,
    required this.style,
    required this.onTap,
  });

  final ScrollController controller;
  final List<AppearanceTab> tabs;
  final List<GlobalKey> keys;
  final int index;
  final SettingsIconStyle style;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent(context);
    final ios = _isIos;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    return SizedBox(
      height: 72 * textScale,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final tab = tabs[i];
          final on = i == index;
          return Semantics(
            key: keys[i],
            button: true,
            selected: on,
            label: tab.title(l),
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 70 * textScale,
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: on
                      ? accent.withValues(alpha: dark ? 0.18 : 0.12)
                      : (ios
                            ? (dark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.white.withValues(alpha: 0.5))
                            : Colors.transparent),
                  border: Border.all(
                    color: on ? accent.withValues(alpha: 0.6) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                // Значок и подпись — точно по центру рамки (раньше Stack без
                // выравнивания прижимал их к левому краю). Точки «изменено»
                // больше нет — решение владельца 20.11.2026.
                child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SettingsGlyphTile(glyph: tab.glyph, style: style, size: 30),
                        const SizedBox(height: 6),
                        // Длинное слово («Поведение», «Comportement»)
                        // чуть уменьшается, а не обрезается многоточием.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Text(
                              tab.title(l),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                                color: on ? cs.onSurface : _secondary(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Кольцо выбранного варианта.
BoxDecoration _ring(BuildContext context, bool on, {double radius = 14}) =>
    BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: on ? _accent(context) : Colors.transparent,
        width: 2,
      ),
    );

/// Звезда Premium на варианте, который без подписки не выбрать.
class _PremiumMark extends StatelessWidget {
  const _PremiumMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Premium',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '★',
          style: TextStyle(color: Color(0xFFFFD27A), fontSize: 9, height: 1.1),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, {required this.on, this.maxLines = 1});
  final String text;
  final bool on;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 11,
      fontWeight: on ? FontWeight.w600 : FontWeight.w400,
      color: on ? Theme.of(context).colorScheme.onSurface : _secondary(context),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 2),
    child: Text(
      text,
      style: TextStyle(fontSize: 12.5, color: _secondary(context)),
    ),
  );
}

// ─── Тема ───────────────────────────────────────────────────────────────────

enum _Mode { light, dark, auto }

class _ThemeTab extends StatelessWidget {
  const _ThemeTab({required this.delegate});
  final ChatAppearanceDelegate delegate;

  Future<void> _setMode(BuildContext context, _Mode mode) async {
    final c = delegate.controller;
    Haptics.tap();
    if (mode == _Mode.auto) {
      await c.setFollowSystemTheme(true);
      return;
    }
    if (c.followSystemTheme) await c.setFollowSystemTheme(false);
    final dark = mode == _Mode.dark;
    if (dark == c.darkMode || !context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final center = box != null
        ? box.localToGlobal(box.size.center(Offset.zero))
        : Offset.zero;
    final transition = ThemeTransitionScope.of(context);
    if (transition != null) {
      transition.triggerTransition(center, dark);
    } else {
      await c.setDarkMode(dark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = delegate.controller;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mode = c.followSystemTheme
        ? _Mode.auto
        : (c.darkMode ? _Mode.dark : _Mode.light);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Segmented<_Mode>(
          value: mode,
          items: <(_Mode, String)>[
            (_Mode.light, l.appearanceModeLight),
            (_Mode.dark, l.appearanceModeDark),
            (_Mode.auto, l.appearanceModeAuto),
          ],
          onChanged: (m) => _setMode(context, m),
        ),
        const SizedBox(height: 14),
        _Grid(
          columns: 5,
          children: [
            for (final p in kAppThemePresets)
              _ThemeSwatch(
                preset: p,
                dark: dark,
                selected: p.id == c.appThemePresetId,
                locked: delegate.isLocked(CosmeticKind.theme, p.id),
                name: settingsScreenPresetName(
                  context,
                  id: p.id,
                  ru: p.nameRu,
                  en: p.nameEn,
                ),
                onTap: () => delegate.pickCosmetic(
                  context,
                  kind: CosmeticKind.theme,
                  id: p.id,
                  apply: () => c.setAppThemePresetId(p.id),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.preset,
    required this.dark,
    required this.selected,
    required this.locked,
    required this.name,
    required this.onTap,
  });

  final AppThemePreset preset;
  final bool dark;
  final bool selected;
  final bool locked;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = dark ? preset.darkPrimary : preset.lightPrimary;
    final surface = dark ? preset.darkSurface : preset.lightSurface;
    final secondary = dark ? preset.darkSecondary : preset.lightSecondary;
    return _Choice(
      label: name,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? _accent(context) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      startAngle: 0,
                      endAngle: 6.2832,
                      transform: const GradientRotation(3.49),
                      colors: [primary, primary, surface, surface, secondary, secondary],
                      stops: const [0, 0.5, 0.5, 0.75, 0.75, 1],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                ),
                if (locked)
                  const Positioned(right: -4, top: -3, child: _PremiumMark()),
              ],
            ),
          ),
          const SizedBox(height: 5),
          // Названия тем бывают в два слова («Топлёное молоко»).
          _Caption(name, on: selected, maxLines: 2),
        ],
      ),
    );
  }
}

/// Переключатель из трёх положений: системный вид iOS на iPhone и вид
/// Material 3 на Android.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ios = _isIos;
    return Container(
      padding: EdgeInsets.all(ios ? 2 : 0),
      decoration: BoxDecoration(
        color: ios
            ? const Color(0xFF767680).withValues(alpha: dark ? 0.24 : 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(ios ? 10 : 20),
        border: ios
            ? null
            : Border.all(color: cs.onSurface.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          for (final (v, label) in items)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    constraints: BoxConstraints(minHeight: ios ? 32 : 38),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ios ? 8 : 19),
                      color: v == value
                          ? (ios
                                ? (dark ? const Color(0xFF636366) : Colors.white)
                                : cs.primary.withValues(alpha: dark ? 0.22 : 0.14))
                          : Colors.transparent,
                      boxShadow: v == value && ios
                          ? const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!ios && v == value) ...[
                          Icon(AdaptiveIcons.check_rounded, size: 16, color: cs.onSurface),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: v == value ? FontWeight.w600 : FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Сетка вариантов с заданным числом колонок; высота строки — по содержимому.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.columns,
    required this.children,
    this.spacing = 8,
    this.runSpacing = 12,
  });

  final int columns;
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children) SizedBox(width: w, child: child),
          ],
        );
      },
    );
  }
}

/// Нажимаемый вариант: подпись для экранного диктора, отметка выбора.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: child,
      ),
    );
  }
}

// ─── Обои ───────────────────────────────────────────────────────────────────

class _WallpaperTab extends StatelessWidget {
  const _WallpaperTab({required this.delegate});
  final ChatAppearanceDelegate delegate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = delegate.controller;
    final selectedId = resolveEffectiveChatWallpaperId(
      selectionId: c.defaultChatWallpaperId,
      defaultId: 'default',
    );
    final options = delegate.wallpaperOptions(context);
    return _Grid(
      columns: 4,
      children: [
        for (final o in options)
          _Choice(
            label: o.title,
            selected: o.id == selectedId,
            onTap: () => delegate.pickWallpaper(context, o),
            child: Column(
              children: [
                Container(
                  height: 92,
                  padding: const EdgeInsets.all(2),
                  decoration: _ring(context, o.id == selectedId, radius: 15),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        buildChatWallpaperBackground(context, o.id, preview: true),
                        if (delegate.isLocked(CosmeticKind.wallpaper, o.id))
                          const Positioned(
                            top: 5,
                            right: 5,
                            child: _PremiumMark(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                _Caption(o.title, on: o.id == selectedId),
              ],
            ),
          ),
        _Choice(
          label: l.appearanceAllWallpapers,
          selected: false,
          onTap: () => delegate.openAllWallpapers(context),
          child: Column(
            children: [
              Container(
                height: 92,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _secondary(context).withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: Icon(AdaptiveIcons.add_rounded, size: 26, color: _accent(context)),
              ),
              const SizedBox(height: 5),
              _Caption(l.appearanceAllWallpapers, on: false),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Пузыри ─────────────────────────────────────────────────────────────────

class _BubblesTab extends StatelessWidget {
  const _BubblesTab({required this.delegate});
  final ChatAppearanceDelegate delegate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = delegate.controller;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final current = normalizeChatBubbleStylePresetId(c.chatBubbleStylePresetId);
    String name(ChatBubbleStylePreset p) =>
        settingsScreenPresetName(context, id: p.id, ru: p.nameRu, en: p.nameEn);
    final selected = kChatBubbleStylePresets
        .where((p) => p.id == current)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Grid(
          // Шесть в ряд, как в макете: пузыри узкие, и так под сеткой
          // остаётся место для ползунка скругления без прокрутки.
          columns: 6,
          spacing: 4,
          runSpacing: 10,
          children: [
            for (final p in kChatBubbleStylePresets)
              _Choice(
                label: name(p),
                selected: p.id == current,
                onTap: () => delegate.pickCosmetic(
                  context,
                  kind: CosmeticKind.bubbleStyle,
                  id: p.id,
                  apply: () => c.setChatBubbleStylePresetId(p.id),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: _ring(context, p.id == current, radius: 18),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42,
                          height: 28,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(15),
                              topRight: Radius.circular(15),
                              bottomLeft: Radius.circular(15),
                              bottomRight: Radius.circular(5),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: dark
                                  ? [
                                      p.darkTop,
                                      if (p.darkMid != null) p.darkMid!,
                                      p.darkBottom,
                                    ]
                                  : [
                                      p.lightTop,
                                      if (p.lightMid != null) p.lightMid!,
                                      p.lightBottom,
                                    ],
                            ),
                          ),
                        ),
                        if (delegate.isLocked(CosmeticKind.bubbleStyle, p.id))
                          const Positioned(right: -5, top: -6, child: _PremiumMark()),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          Text(
            name(selected),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: _secondary(context)),
          ),
        ],
        const SizedBox(height: 10),
        _LookSlider(
          label: l.appearanceBubbleRadius,
          value: () => ChatLookPrefs.radius.value,
          min: ChatLookPrefs.minRadius,
          max: ChatLookPrefs.maxRadius,
          unit: 'px',
          onChanged: (v) => ChatLookPrefs.setRadius(v, persist: false),
          onChangeEnd: (v) => ChatLookPrefs.setRadius(v),
        ),
      ],
    );
  }
}

// ─── Цвета ──────────────────────────────────────────────────────────────────

class _TextTab extends StatelessWidget {
  const _TextTab({required this.delegate});
  final ChatAppearanceDelegate delegate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = delegate.controller;
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LookSlider(
          label: l.appearanceTextSize,
          value: () => ChatLookPrefs.fontSize.value,
          min: ChatLookPrefs.minFontSize,
          max: ChatLookPrefs.maxFontSize,
          unit: 'pt',
          smallEnd: 'A',
          bigEnd: 'A',
          onChanged: (v) => ChatLookPrefs.setFontSize(v, persist: false),
          onChangeEnd: (v) => ChatLookPrefs.setFontSize(v),
        ),
        const SizedBox(height: 14),
        _SectionLabel(l.appearanceNickColors),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in kNicknameStylePresets)
              Builder(
                builder: (context) {
                  final on = p.id == c.nicknameStylePresetId;
                  final name = settingsScreenPresetName(
                    context,
                    id: p.id,
                    ru: p.nameRu,
                    en: p.nameEn,
                  );
                  return _Choice(
                    label: name,
                    selected: on,
                    onTap: () => c.setNicknameStylePresetId(p.id),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: on ? accent.withValues(alpha: 0.14) : Colors.transparent,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: on
                              ? accent
                              : cs.onSurface.withValues(alpha: dark ? 0.14 : 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 10,
                            child: Stack(
                              children: [
                                _Dot(p.outgoing),
                                Positioned(left: 6, child: _Dot(p.incoming)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: TextStyle(fontSize: 12.5, color: cs.onSurface),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionLabel(l.appearanceIndicatorColors),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final p in kIndicatorColorPresets)
              Builder(
                builder: (context) {
                  final on = p.id == c.indicatorColorPresetId;
                  final name = settingsScreenPresetName(
                    context,
                    id: 'indicator_${p.id}',
                    ru: p.nameRu,
                    en: p.nameEn,
                  );
                  final locked = delegate.isLocked(CosmeticKind.indicatorColor, p.id);
                  return _Choice(
                    label: name,
                    selected: on,
                    onTap: () => delegate.pickCosmetic(
                      context,
                      kind: CosmeticKind.indicatorColor,
                      id: p.id,
                      apply: () => c.setIndicatorColorPresetId(p.id),
                    ),
                    child: Tooltip(
                      message: name,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: on ? accent : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p.followsTheme
                                    ? null
                                    : (dark ? p.darkPrimary : p.lightPrimary),
                                gradient: p.followsTheme
                                    ? const SweepGradient(
                                        colors: <Color>[
                                          Color(0xFF6366F1),
                                          Color(0xFFEC4899),
                                          Color(0xFFF59E0B),
                                          Color(0xFF10B981),
                                          Color(0xFF3B82F6),
                                          Color(0xFF6366F1),
                                        ],
                                      )
                                    : null,
                              ),
                            ),
                            if (locked)
                              const Positioned(right: -6, top: -5, child: _PremiumMark()),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

// ─── Ползунок ───────────────────────────────────────────────────────────────

/// Ползунок «Размер текста» / «Скругление углов»: подпись, значение справа,
/// по краям — маленькая и большая «A» (у размера текста). Значение двигает
/// превью вживую, на диск пишется по отпусканию.
class _LookSlider extends StatelessWidget {
  const _LookSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    required this.onChangeEnd,
    this.smallEnd,
    this.bigEnd,
  });

  final String label;
  final double Function() value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final String? smallEnd;
  final String? bigEnd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final secondary = _secondary(context);
    return ListenableBuilder(
      listenable: ChatLookPrefs.listenable,
      builder: (context, _) {
        final v = value();
        final slider = Slider.adaptive(
          value: v,
          min: min,
          max: max,
          divisions: (max - min).round(),
          label: '${v.round()} $unit',
          semanticFormatterCallback: (x) => '${x.round()} $unit',
          onChanged: (x) {
            if (x.round() != v.round()) Haptics.tap();
            onChanged(x.roundToDouble());
          },
          onChangeEnd: (x) => onChangeEnd(x.roundToDouble()),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 14.5, color: cs.onSurface),
                  ),
                ),
                Text(
                  '${v.round()} $unit',
                  style: TextStyle(
                    fontSize: 13,
                    color: secondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (smallEnd != null)
                  ExcludeSemantics(
                    child: Text(smallEnd!, style: TextStyle(fontSize: 12, color: secondary)),
                  ),
                Expanded(child: slider),
                if (bigEnd != null)
                  ExcludeSemantics(
                    child: Text(bigEnd!, style: TextStyle(fontSize: 19, color: secondary)),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─── Фон ────────────────────────────────────────────────────────────────────

class _BackgroundTab extends StatelessWidget {
  const _BackgroundTab({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = controller;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = resolveAppThemePreset(c.appThemePresetId);
    // «По теме» — настоящий градиент темы, а не рисунок «примерно такой».
    final themeColors = dark
        ? [theme.darkBgTop, theme.darkBgMid, theme.darkBgBottom]
        : [
            theme.lightBgTop ?? theme.lightSurface,
            theme.lightBgMid ?? theme.lightSurface,
            theme.lightBgBottom ?? theme.lightSurface,
          ];
    Widget tile({
      required String id,
      required String name,
      required Widget background,
    }) {
      final on = c.appBackdropId == id;
      final line = dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.5);
      return _Choice(
        label: name,
        selected: on,
        onTap: () => c.setAppBackdropId(id),
        child: Column(
          children: [
            Container(
              height: 86,
              padding: const EdgeInsets.all(2),
              decoration: _ring(context, on, radius: 15),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    background,
                    // Две «карточки» поверх — чтобы было видно, как фон
                    // смотрится под содержимым.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 9, 6, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: 0.6,
                            child: _GlassLine(color: line, height: 6),
                          ),
                          const SizedBox(height: 5),
                          _GlassLine(color: line, height: 20),
                          const SizedBox(height: 5),
                          _GlassLine(color: line, height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            _Caption(name, on: on),
          ],
        ),
      );
    }

    return _Grid(
      columns: 5,
      spacing: 8,
      children: [
        for (final p in kAppBackdropPresets)
          tile(
            id: p.id,
            name: p.name(l),
            background: CustomPaint(
              painter: AppBackdropPainter(preset: p, dark: dark),
            ),
          ),
        tile(
          id: kAppBackdropTheme,
          name: l.appBackdropTheme,
          background: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: themeColors,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassLine extends StatelessWidget {
  const _GlassLine({required this.color, required this.height});
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(height < 10 ? 3 : 6),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
    ),
  );
}

// ─── Иконки ─────────────────────────────────────────────────────────────────

class _IconStylesTab extends StatelessWidget {
  const _IconStylesTab({required this.selected});
  final SettingsIconStyle selected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent(context);
    return _Grid(
      columns: 4,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in SettingsIconStyle.values)
          _Choice(
            label: s.label(l),
            selected: s == selected,
            onTap: () => SettingsIconStylePrefs.set(s),
            child: Container(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: s == selected
                    ? accent.withValues(alpha: 0.12)
                    : Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: dark ? 0.04 : 0.035,
                      ),
                border: Border.all(
                  color: s == selected ? accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SettingsGlyphTile(glyph: SettingsGlyph.account, style: s, size: 26),
                      const SizedBox(width: 5),
                      SettingsGlyphTile(glyph: SettingsGlyph.chats, style: s, size: 26),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _Caption(s.label(l), on: s == selected),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Значок приложения ──────────────────────────────────────────────────────

class _AppIconTab extends StatelessWidget {
  const _AppIconTab({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppIconGrid(controller: controller),
        if (_isAndroid) ...[
          const SizedBox(height: 12),
          Text(
            l.appearanceAppIconAndroidNote,
            style: TextStyle(fontSize: 12, color: _secondary(context)),
          ),
        ],
      ],
    );
  }
}

// ─── Поведение ──────────────────────────────────────────────────────────────

class _BehaviorTab extends StatelessWidget {
  const _BehaviorTab({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = controller;
    final rows = <Widget>[
      _SwitchRow(
        title: l.blockUnverified,
        subtitle: l.blockUnverifiedSubtitle,
        value: c.blockUnverified,
        onChanged: (v) => c.setBlockUnverified(v),
      ),
      // SEC-11: скрытие содержимого экрана. Подпись РАЗНАЯ на двух системах:
      // iOS не даёт приложению запретить снимок экрана — закрывается только
      // карточка в переключателе. Одинаковый текст пообещал бы там защиту,
      // которой нет.
      if (ScreenPrivacy.isSupported)
        _SwitchRow(
          title: l.appearanceHideScreen,
          subtitle: ScreenPrivacy.blocksScreenshots
              ? l.appearanceHideScreenAndroid
              : l.appearanceHideScreenIos,
          value: c.screenPrivacy,
          onChanged: (v) async {
            final ok = await c.setScreenPrivacy(v);
            if (ok || !context.mounted) return;
            // Система отказала — переключатель остался выключенным
            // намеренно: молчаливый «включено» опаснее отказа.
            ScaffoldMessenger.of(context).showSnackBar(
              SecretlySnackBar(content: Text(l.appearanceHideScreenRefused)),
            );
          },
        ),
      // Стекло — только iPhone: на других системах строки просто нет.
      if (kLiquidGlassNavBar && _isIos)
        ValueListenableBuilder<bool>(
          valueListenable: GlassPrefs.enabled,
          builder: (context, on, _) => _SwitchRow(
            title: l.liquidGlassTitle,
            subtitle: l.liquidGlassSubtitle,
            value: on,
            onChanged: GlassPrefs.setEnabled,
          ),
        ),
    ];
    final divider = Divider(
      height: 1,
      thickness: _isIos ? 0.5 : 1,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
    );
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          // Android — без линий между строками (как во всех настройках).
          if (i > 0 && !_isAndroid) divider,
          rows[i],
        ],
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: InkWell(
        onTap: () {
          Haptics.tap();
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, color: cs.onSurface)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: _secondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: value,
                onChanged: (v) {
                  Haptics.tap();
                  onChanged(v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Превью ─────────────────────────────────────────────────────────────────

/// Превью для «Иконок»: начало настоящего списка настроек с выбранным
/// стилем значков и настоящими названиями разделов.
class _SettingsListPreview extends StatelessWidget {
  const _SettingsListPreview({required this.style});
  final SettingsIconStyle style;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final rows = <(SettingsGlyph, String)>[
      (SettingsGlyph.account, l.accountSection),
      (SettingsGlyph.privacy, l.privacySection),
      (SettingsGlyph.security, l.securityTitle),
      (SettingsGlyph.notifications, l.notificationsSection),
      (SettingsGlyph.chats, l.settingsStyleSection),
      (SettingsGlyph.storage, l.storageSection),
    ];
    final card = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (g, title) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(
              children: [
                SettingsGlyphTile(glyph: g, style: style, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, color: cs.onSurface),
                  ),
                ),
                Icon(AdaptiveIcons.chevron_right_rounded, size: 20, color: _secondary(context)),
              ],
            ),
          ),
      ],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(_isIos ? 24 : 26),
      child: ColoredBox(
        color: cs.surface.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  l.settingsTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: panelCardsEnabled
                      ? AppleGlassPanel(
                          radius: 18,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: card,
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: card,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Превью для «Значка»: главный экран телефона с настоящим выбранным значком
/// посередине. Соседние значки — пустые стеклянные места, а не выдуманные
/// чужие приложения.
class _HomeScreenPreview extends StatelessWidget {
  const _HomeScreenPreview({required this.iconKey});
  final String iconKey;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final option = kAppIconOptions.firstWhere(
      (o) => o.key == iconKey,
      orElse: () => kAppIconOptions.first,
    );
    final ios = _isIos;
    final iconRadius = ios ? 13.0 : 27.0;
    Widget slot() => Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(iconRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.black.withValues(alpha: 0.18),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 0.6),
      ),
    );
    final real = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, a) => ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1).animate(a),
            child: FadeTransition(opacity: a, child: child),
          ),
          child: ClipRRect(
            key: ValueKey<String>(option.key),
            borderRadius: BorderRadius.circular(iconRadius * 1.1),
            child: Image.asset(
              option.asset,
              width: 58,
              height: 58,
              cacheWidth: 180,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Secretly',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white,
            shadows: [Shadow(color: Color(0x66000000), blurRadius: 2)],
          ),
        ),
      ],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(ios ? 24 : 26),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.6, -0.6),
            radius: 1.4,
            colors: dark
                ? const [Color(0xFF3A2A8C), Color(0xFF0E3C5C), Color(0xFF0B0B16)]
                : const [Color(0xFF4F6FD8), Color(0xFF8A5AA8), Color(0xFF5A6A9E)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Wrap(
                    spacing: 22,
                    runSpacing: 18,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var i = 0; i < 5; i++) slot(),
                      real,
                      for (var i = 0; i < 2; i++) slot(),
                    ],
                  ),
                ),
              ),
              Container(
                height: 66,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: Colors.white.withValues(alpha: 0.14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [for (var i = 0; i < 4; i++) slot()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
