// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Строки и группы страниц настроек iPhone — как в «Настройках» iOS:
/// цветной значок 30 со скруглением, название 17, пояснение под ним, справа
/// значение, переключатель или «›», тонкий разделитель от текста, а не от
/// края. Группа — стеклянная панель (`apple_glass.dart`).
///
/// Внутренние страницы настроек пользуются этим через [AppleSettingsPageTheme]
/// и общие построители экрана настроек, поэтому десятки строк меняются разом,
/// а Android и компьютер остаются прежними.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'apple_glass.dart';
import 'haptics.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';

/// Вид страниц настроек iPhone — и на Android (23.11.2026, владелец: «на
/// айфоне выглядят невероятно и грамотно, на андроиде большие надписи и
/// большие расстояния между плашками»): группы-панели, цветные значки 30,
/// тонкие разделители от текста, плотные строки. Без стекла и размытия —
/// панель просто залита. `false` — Android снова со строками Material.
const bool kAndroidSettingsIosLayout = true;

/// Страницы настроек рисуются в виде iPhone (на iPhone — всегда).
bool get settingsIosLayout =>
    appleGlassPanelsEnabled ||
    (kAndroidSettingsIosLayout &&
        defaultTargetPlatform == TargetPlatform.android);

/// Кегль названия строки: iOS — 17, Android — 16 (его привычный размер).
double get settingsRowTitleSize =>
    defaultTargetPlatform == TargetPlatform.android ? 16 : 17;

/// Отступ разделителя: 14 (край) + 30 (значок) + 14 (зазор).
const double kAppleRowSeparatorInset = 58;

/// Тема страницы настроек: на iPhone — строки iOS и тонкие разделители от
/// текста, на Android — компактные строки Material без линий
/// ([applyCompactMaterial]). Оборачивает тело страницы.
class AppleSettingsPageTheme extends StatelessWidget {
  const AppleSettingsPageTheme({super.key, required this.child});

  final Widget child;

  static ThemeData apply(ThemeData base) {
    final dark = base.brightness == Brightness.dark;
    final onSurface = base.colorScheme.onSurface;
    final secondary = AppleGlass.secondaryLabel(dark);
    return base.copyWith(
      listTileTheme: base.listTileTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        // Android — плотность прежних компактных страниц (не меняет уже
        // сделанные «Устройства» и др.).
        minVerticalPadding:
            defaultTargetPlatform == TargetPlatform.android ? 6 : 10,
        visualDensity: defaultTargetPlatform == TargetPlatform.android
            ? const VisualDensity(vertical: -2)
            : null,
        minLeadingWidth: 30,
        horizontalTitleGap: 14,
        titleTextStyle: TextStyle(
          fontSize: settingsRowTitleSize,
          letterSpacing: -0.4,
          height: 1.25,
          color: onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          letterSpacing: -0.08,
          height: 1.3,
          color: secondary,
        ),
        leadingAndTrailingTextStyle: TextStyle(
          fontSize: settingsRowTitleSize,
          letterSpacing: -0.4,
          color: secondary,
        ),
      ),
      // Отступ разделителя от текста задаёт сама группа
      // ([AppleSettingsGroup]) — на странице, в окнах и листах линия идёт
      // от края, как задумал экран.
      // Android (23.11.2026, владелец): линий между строками нет — это
      // примета iOS; строки разделяет воздух, как на главной настроек.
      dividerTheme: defaultTargetPlatform == TargetPlatform.android
          ? const DividerThemeData(
              color: Colors.transparent,
              thickness: 0,
              space: 0,
            )
          : DividerThemeData(
              color: AppleGlass.separator(dark),
              thickness: 0.5,
              space: 0.5,
            ),
    );
  }

  /// Android (20.11.2026, «настройки внутри категорий так же компактно, как
  /// главная»): строки плотнее — меньше отступов по вертикали, название 16,
  /// пояснение 13 серым, линии между строками не видны. Вид Material
  /// сохраняется: цвета, отклик на нажатие и переключатели прежние.
  static ThemeData applyCompactMaterial(ThemeData base) {
    final cs = base.colorScheme;
    return base.copyWith(
      listTileTheme: base.listTileTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 6,
        minLeadingWidth: 32,
        horizontalTitleGap: 14,
        visualDensity: const VisualDensity(vertical: -2),
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.25,
          color: cs.onSurface,
        ),
        subtitleTextStyle: base.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          height: 1.3,
          color: cs.onSurfaceVariant,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    if (settingsIosLayout) {
      return Theme(data: apply(base), child: child);
    }
    // Компактный вид — только Android: экраны настроек телефона иногда
    // открываются и на компьютере (набор восстановления), там свой вид.
    if (defaultTargetPlatform != TargetPlatform.android) return child;
    return Theme(data: applyCompactMaterial(base), child: child);
  }
}

/// Цветной значок строки iOS: скруглённый квадрат 30 цвета [tint] и белый
/// знак — [icon] или картинка [asset] (перекрашивается в белый).
class AppleRowIcon extends StatelessWidget {
  const AppleRowIcon({super.key, required this.tint, this.icon, this.asset})
    : assert(icon != null || asset != null);

  final Color tint;
  final IconData? icon;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(tint);
    final top = hsl
        .withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0))
        .toColor();
    final glyph = asset != null
        ? Image.asset(
            asset!,
            width: 18,
            height: 18,
            color: Colors.white,
            colorBlendMode: BlendMode.srcIn,
          )
        : Icon(icon, size: 18, color: Colors.white);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, tint],
        ),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.35), width: 0.6),
        ),
      ),
      alignment: Alignment.center,
      child: glyph,
    );
  }
}

/// Строка настроек iPhone.
class AppleSettingsRow extends StatefulWidget {
  const AppleSettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// «›» у нажимаемой строки без своего элемента справа.
  final bool showChevron;

  @override
  State<AppleSettingsRow> createState() => _AppleSettingsRowState();
}

class _AppleSettingsRowState extends State<AppleSettingsRow> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = AppleGlass.secondaryLabel(dark);
    final onTap = widget.onTap;
    final trailing = widget.trailing;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 46),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 12, 8),
        child: Row(
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: settingsRowTitleSize,
                      letterSpacing: -0.4,
                      height: 1.25,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (widget.subtitle != null &&
                      widget.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: -0.08,
                        height: 1.3,
                        color: secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
            if (trailing == null && onTap != null && widget.showChevron) ...[
              const SizedBox(width: 6),
              Icon(AdaptiveIcons.chevron_right_rounded, size: 24, color: secondary),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return MergeSemantics(child: row);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _set(true),
          onTapCancel: () => _set(false),
          onTapUp: (_) => _set(false),
          onTap: () {
            Haptics.tap();
            onTap();
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: _down ? 0 : 220),
            color: _down ? AppleGlass.pressed(dark) : Colors.transparent,
            child: row,
          ),
        ),
      ),
    );
  }
}

/// Группа строк: стеклянная панель с отступами страницы. Разделители между
/// строками рисует сама — от текста, как в iOS.
class AppleSettingsGroup extends StatelessWidget {
  const AppleSettingsGroup({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: AppleGlassPanel(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Theme(
          // Разделитель строк в группе iOS начинается от текста.
          data: Theme.of(context).copyWith(
            dividerTheme: defaultTargetPlatform == TargetPlatform.android
                // Android — без линий между строками (см. тему страницы).
                ? const DividerThemeData(
                    color: Colors.transparent,
                    thickness: 0,
                    space: 0,
                  )
                : Theme.of(context).dividerTheme.copyWith(
                    indent: kAppleRowSeparatorInset,
                    color: AppleGlass.separator(
                      Theme.of(context).brightness == Brightness.dark,
                    ),
                    thickness: 0.5,
                  ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}
