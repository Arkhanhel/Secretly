// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../apple_controls.dart';

/// Стиль приветственных экранов и окна «Новый вход» по макету «Secretly Kit»
/// (17.11.2026).
///
/// Макет нарисован в двух видах: Apple (iOS, macOS — «жидкое стекло»,
/// синяя кнопка-пилюля) и Material 3 (Android — тональные кнопки, поля с
/// рамкой). Тёмная тема — как в макете, светлая выведена из неё же: те же
/// формы и отступы, цвета взяты из светлых палитр обеих систем.
@immutable
class WelcomeStyle {
  const WelcomeStyle._({
    required this.dark,
    required this.material,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.primaryGradient,
    required this.primaryShadow,
    required this.onPrimary,
    required this.disabledFill,
    required this.disabledText,
    required this.secondaryFill,
    required this.secondaryText,
    required this.fieldFill,
    required this.fieldFillFocused,
    required this.fieldBorder,
    required this.focus,
    required this.cardFill,
    required this.cardEdge,
    required this.segmentTrack,
    required this.segmentSelected,
    required this.segmentSelectedText,
    required this.dangerFill,
    required this.dangerText,
    required this.error,
    required this.success,
    required this.sheetFill,
    required this.divider,
    required this.avatarStops,
    this.fluent = false,
  });

  final bool dark;

  /// `true` — вид Material 3 (Android и прочие не-Apple системы).
  final bool material;

  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final List<Color> primaryGradient;
  final Color? primaryShadow;
  final Color onPrimary;
  final Color disabledFill;
  final Color disabledText;
  final Color secondaryFill;
  final Color secondaryText;
  final Color fieldFill;
  final Color fieldFillFocused;
  final Color fieldBorder;
  final Color focus;
  final Color cardFill;
  final Color cardEdge;
  final Color segmentTrack;
  final Color segmentSelected;
  final Color segmentSelectedText;
  final Color dangerFill;
  final Color dangerText;
  final Color error;
  final Color success;
  final Color sheetFill;
  final Color divider;
  final List<Color> avatarStops;

  /// Windows: вид Fluent 2 из макета — прямоугольные кнопки (скругление 6),
  /// поля с линией снизу, акцент Windows. Во всём остальном ведёт себя как
  /// [material]: без стекла и размытия.
  final bool fluent;

  /// Скругление кнопок: «пилюля» везде, кроме Fluent.
  double radiusFor(double height) => fluent ? 6 : height;

  /// Карточка внутри листа: у Material 3 лист и карточка одного цвета, и
  /// группа терялась бы — даём ей ступень светлее.
  Color? get sheetCardFill => material
      ? (dark ? const Color(0xFF2A2D33) : const Color(0xFFFFFFFF))
      : null;

  /// Цвета переключателя во включённом положении.
  Color get switchTrack =>
      material ? primaryGradient.first : const Color(0xFF34C759);
  Color? get switchThumb => material ? onPrimary : null;

  /// Высота главной кнопки: 54 у Apple, 56 у Material 3.
  double get primaryHeight => fluent ? 40 : (material ? 56 : 54);

  /// Скругление поля ввода: 14 у Apple, 4 у полей Material 3 с рамкой.
  double get fieldRadius => (material || fluent) ? 4 : 14;

  /// Высота однострочного поля.
  double get fieldHeight => fluent ? 40 : 56;

  static bool _isApple(TargetPlatform p) =>
      p == TargetPlatform.iOS || p == TargetPlatform.macOS;

  static WelcomeStyle resolve({
    required Brightness brightness,
    required TargetPlatform platform,
  }) {
    final dark = brightness == Brightness.dark;
    final material = !_isApple(platform);
    if (platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux) {
      return dark ? _fluentDark : _fluentLight;
    }
    if (material) {
      return dark ? _materialDark : _materialLight;
    }
    return dark ? _appleDark : _appleLight;
  }

  static WelcomeStyle of(BuildContext context) {
    final theme = Theme.of(context);
    return resolve(brightness: theme.brightness, platform: theme.platform);
  }

  static const _appleDark = WelcomeStyle._(
    dark: true,
    material: false,
    text: Color(0xFFF5F5F4),
    textSecondary: Color(0x94F5F5F4),
    textTertiary: Color(0x73F5F5F4),
    primaryGradient: [Color(0xF2409CFF), Color(0xF20A78FF)],
    primaryShadow: Color(0x610A84FF),
    onPrimary: Color(0xFFFFFFFF),
    disabledFill: Color(0x2E767680),
    disabledText: Color(0x4DF5F5F4),
    secondaryFill: Color(0x1AFFFFFF),
    secondaryText: Color(0xFFF5F5F4),
    fieldFill: Color(0x3D767680),
    fieldFillFocused: Color(0x52767680),
    fieldBorder: Color(0x00000000),
    focus: Color(0xFF0A84FF),
    cardFill: Color(0x12FFFFFF),
    cardEdge: Color(0x24FFFFFF),
    segmentTrack: Color(0x3D767680),
    segmentSelected: Color(0x47FFFFFF),
    segmentSelectedText: Color(0xFFFFFFFF),
    dangerFill: Color(0x29FF453A),
    dangerText: Color(0xFFFF6961),
    error: Color(0xFFFB7185),
    success: Color(0xFF34D399),
    sheetFill: Color(0xC72A2A30),
    divider: Color(0x0DFFFFFF),
    avatarStops: [Color(0xFF64B5FF), Color(0xFF0A84FF), Color(0xFF5E5CE6)],
  );

  static const _appleLight = WelcomeStyle._(
    dark: false,
    material: false,
    text: Color(0xFF111114),
    textSecondary: Color(0x9E111114),
    textTertiary: Color(0x80111114),
    primaryGradient: [Color(0xFF3D98FF), Color(0xFF0A72F0)],
    primaryShadow: Color(0x4D0A84FF),
    onPrimary: Color(0xFFFFFFFF),
    disabledFill: Color(0x24767680),
    disabledText: Color(0x5C111114),
    secondaryFill: Color(0x0F000000),
    secondaryText: Color(0xFF111114),
    fieldFill: Color(0x1F767680),
    fieldFillFocused: Color(0x29767680),
    fieldBorder: Color(0x00000000),
    focus: Color(0xFF0A84FF),
    cardFill: Color(0xB8FFFFFF),
    cardEdge: Color(0x14000000),
    segmentTrack: Color(0x1F767680),
    segmentSelected: Color(0xFFFFFFFF),
    segmentSelectedText: Color(0xFF111114),
    dangerFill: Color(0x1FFF3B30),
    dangerText: Color(0xFFD70015),
    error: Color(0xFFD70015),
    success: Color(0xFF248A3D),
    sheetFill: Color(0xE6F7F7F9),
    divider: Color(0x12000000),
    avatarStops: [Color(0xFF64B5FF), Color(0xFF0A84FF), Color(0xFF5E5CE6)],
  );

  static const _materialDark = WelcomeStyle._(
    dark: true,
    material: true,
    text: Color(0xFFE2E2E9),
    textSecondary: Color(0x94F5F5F4),
    textTertiary: Color(0x73F5F5F4),
    primaryGradient: [Color(0xFFA8C7FA), Color(0xFFA8C7FA)],
    primaryShadow: null,
    onPrimary: Color(0xFF062E6F),
    disabledFill: Color(0x1FE2E2E9),
    disabledText: Color(0x61E2E2E9),
    secondaryFill: Color(0xFF3E4759),
    secondaryText: Color(0xFFDAE2F9),
    fieldFill: Color(0x00000000),
    fieldFillFocused: Color(0x00000000),
    fieldBorder: Color(0xFF8E9099),
    focus: Color(0xFFA8C7FA),
    cardFill: Color(0xFF1D2024),
    cardEdge: Color(0x00000000),
    segmentTrack: Color(0x00000000),
    segmentSelected: Color(0xFF3E4759),
    segmentSelectedText: Color(0xFFDAE2F9),
    dangerFill: Color(0xFF93000A),
    dangerText: Color(0xFFFFDAD6),
    error: Color(0xFFFFB4AB),
    success: Color(0xFF34D399),
    sheetFill: Color(0xFF1D2024),
    divider: Color(0x14FFFFFF),
    avatarStops: [Color(0xFFD3E3FD), Color(0xFFA8C7FA), Color(0xFF7CACF8)],
  );

  static const _materialLight = WelcomeStyle._(
    dark: false,
    material: true,
    text: Color(0xFF191C20),
    textSecondary: Color(0xFF44474E),
    textTertiary: Color(0xFF74777F),
    primaryGradient: [Color(0xFF0B57D0), Color(0xFF0B57D0)],
    primaryShadow: null,
    onPrimary: Color(0xFFFFFFFF),
    disabledFill: Color(0x1F191C20),
    disabledText: Color(0x61191C20),
    secondaryFill: Color(0xFFD3E3FD),
    secondaryText: Color(0xFF041E49),
    fieldFill: Color(0x00000000),
    fieldFillFocused: Color(0x00000000),
    fieldBorder: Color(0xFF74777F),
    focus: Color(0xFF0B57D0),
    cardFill: Color(0xFFF0F4F9),
    cardEdge: Color(0x00000000),
    segmentTrack: Color(0x00000000),
    segmentSelected: Color(0xFFD3E3FD),
    segmentSelectedText: Color(0xFF041E49),
    dangerFill: Color(0xFFFFDAD6),
    dangerText: Color(0xFF8C1D18),
    error: Color(0xFFB3261E),
    success: Color(0xFF146C2E),
    sheetFill: Color(0xFFF0F4F9),
    divider: Color(0x14000000),
    avatarStops: [Color(0xFF7CACF8), Color(0xFF0B57D0), Color(0xFF0842A0)],
  );

  static const _fluentDark = WelcomeStyle._(
    dark: true,
    material: true,
    fluent: true,
    text: Color(0xFFF5F5F4),
    textSecondary: Color(0x94F5F5F4),
    textTertiary: Color(0x73F5F5F4),
    primaryGradient: [Color(0xFF4CC2FF), Color(0xFF4CC2FF)],
    primaryShadow: null,
    onPrimary: Color(0xFF000000),
    disabledFill: Color(0x0AFFFFFF),
    disabledText: Color(0x5CF5F5F4),
    secondaryFill: Color(0x0FFFFFFF),
    secondaryText: Color(0xFFF5F5F4),
    fieldFill: Color(0x0FFFFFFF),
    fieldFillFocused: Color(0xFF1C1C1C),
    fieldBorder: Color(0x8CFFFFFF),
    focus: Color(0xFF4CC2FF),
    cardFill: Color(0x0DFFFFFF),
    cardEdge: Color(0x0FFFFFFF),
    segmentTrack: Color(0x0FFFFFFF),
    segmentSelected: Color(0xFFF5F5F4),
    segmentSelectedText: Color(0xFF0A0A0A),
    dangerFill: Color(0x1FFF99A4),
    dangerText: Color(0xFFFF99A4),
    error: Color(0xFFFF99A4),
    success: Color(0xFF6CCB5F),
    sheetFill: Color(0xFF2B2B2B),
    divider: Color(0x14FFFFFF),
    avatarStops: [Color(0xFF99EBFF), Color(0xFF4CC2FF), Color(0xFF0078D4)],
  );

  static const _fluentLight = WelcomeStyle._(
    dark: false,
    material: true,
    fluent: true,
    text: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF5D5D5D),
    textTertiary: Color(0xFF8A8A8A),
    primaryGradient: [Color(0xFF005FB8), Color(0xFF005FB8)],
    primaryShadow: null,
    onPrimary: Color(0xFFFFFFFF),
    disabledFill: Color(0x0F000000),
    disabledText: Color(0x5C000000),
    secondaryFill: Color(0xB3FFFFFF),
    secondaryText: Color(0xFF1A1A1A),
    fieldFill: Color(0xB3FFFFFF),
    fieldFillFocused: Color(0xFFFFFFFF),
    fieldBorder: Color(0x72000000),
    focus: Color(0xFF005FB8),
    cardFill: Color(0xB3FFFFFF),
    cardEdge: Color(0x0F000000),
    segmentTrack: Color(0x0F000000),
    segmentSelected: Color(0xFF1A1A1A),
    segmentSelectedText: Color(0xFFFFFFFF),
    dangerFill: Color(0xFFFDE7E9),
    dangerText: Color(0xFFC42B1C),
    error: Color(0xFFC42B1C),
    success: Color(0xFF0F7B0F),
    sheetFill: Color(0xFFF9F9F9),
    divider: Color(0x0F000000),
    avatarStops: [Color(0xFF99EBFF), Color(0xFF4CC2FF), Color(0xFF0078D4)],
  );

  TextStyle get display => TextStyle(
    fontFamily: 'Manrope',
    fontSize: 46,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: material ? -0.46 : -1.38,
    color: text,
  );

  TextStyle get title => TextStyle(
    fontSize: 32,
    height: 1.12,
    fontWeight: material ? FontWeight.w500 : FontWeight.w700,
    letterSpacing: material ? -0.16 : -0.7,
    color: text,
  );

  TextStyle get body => TextStyle(
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  TextStyle get caption => TextStyle(
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: textTertiary,
  );

  TextStyle get mono => TextStyle(
    fontFamily: material ? 'monospace' : 'Menlo',
    fontFamilyFallback: const ['Courier', 'monospace'],
    fontSize: 14,
    letterSpacing: 0.9,
    fontWeight: FontWeight.w500,
    color: text,
  );

  /// Системные полосы поверх приветственных экранов.
  SystemUiOverlayStyle get overlayStyle => dark
      ? const SystemUiOverlayStyle(
          statusBarColor: Color(0x00000000),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarIconBrightness: Brightness.light,
        )
      : const SystemUiOverlayStyle(
          statusBarColor: Color(0x00000000),
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.dark,
        );
}

// ─── кнопки ──────────────────────────────────────────────────────────────────

/// Главная кнопка: синяя «пилюля» (Apple) или тональная (Material 3).
///
/// Без [onPressed] — серая, как в макете, когда шаг ещё не заполнен.
/// [busy] показывает крутилку на месте подписи и не пускает повторное нажатие.
class WelcomePrimaryButton extends StatefulWidget {
  const WelcomePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.danger = false,
    this.height,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  /// Например, значок «?» — у правого края кнопки, со своим нажатием.
  final Widget? trailing;

  /// Красная кнопка отказа (окно «Новый вход»).
  final bool danger;
  final double? height;

  @override
  State<WelcomePrimaryButton> createState() => _WelcomePrimaryButtonState();
}

class _WelcomePrimaryButtonState extends State<WelcomePrimaryButton> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final enabled = widget.onPressed != null && !widget.busy;
    // Крупный текст из настроек iPhone: две строки подписи должны
    // помещаться, поэтому кнопка растёт вместе с текстом (до ×2,2).
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.2);
    final height = (widget.height ?? s.primaryHeight) * textScale;
    final Decoration decoration;
    final Color fg;
    if (widget.danger) {
      decoration = BoxDecoration(
        color: s.dangerFill,
        borderRadius: BorderRadius.circular(s.radiusFor(height)),
      );
      fg = s.dangerText;
    } else if (widget.onPressed == null) {
      decoration = BoxDecoration(
        color: s.disabledFill,
        borderRadius: BorderRadius.circular(s.radiusFor(height)),
      );
      fg = s.disabledText;
    } else {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(s.radiusFor(height)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: s.primaryGradient,
        ),
        boxShadow: s.primaryShadow == null
            ? null
            : [
                BoxShadow(
                  color: s.primaryShadow!,
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
      );
      fg = s.onPrimary;
    }
    final button = Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: enabled ? widget.onPressed : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1,
            duration: const Duration(milliseconds: 150),
            // У Apple нажатая кнопка ещё и чуть бледнеет.
            child: AnimatedOpacity(
              opacity: _pressed && !s.material ? 0.82 : 1,
              duration: Duration(milliseconds: _pressed ? 60 : 180),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: height,
                width: double.infinity,
                decoration: decoration,
                foregroundDecoration: _hover && enabled
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          s.radiusFor(height),
                        ),
                        color: const Color(0x14FFFFFF),
                      )
                    : !s.material && widget.onPressed != null && !widget.danger
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          s.radiusFor(height),
                        ),
                        border: const Border(
                          top: BorderSide(color: Color(0x80FFFFFF), width: 0.8),
                        ),
                      )
                    : null,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.trailing == null ? 20 : 44,
                ),
                child: widget.busy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: SecretlySpinner(strokeWidth: 2.2, color: fg),
                      )
                    : Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    final trailing = widget.trailing;
    if (trailing == null) return button;
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        button,
        Padding(padding: const EdgeInsets.only(right: 14), child: trailing),
      ],
    );
  }
}

/// Второстепенная кнопка: стеклянная (Apple), тональная (Material 3) или
/// «тонкая» с рамкой (Fluent).
class WelcomeSecondaryButton extends StatefulWidget {
  const WelcomeSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Например, значок «?» с пояснением — у правого края кнопки.
  final Widget? trailing;

  @override
  State<WelcomeSecondaryButton> createState() => _WelcomeSecondaryButtonState();
}

class _WelcomeSecondaryButtonState extends State<WelcomeSecondaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final height = s.fluent ? 40.0 : 50.0;
    final radius = s.radiusFor(height);
    final label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: s.secondaryText,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
    final Widget face;
    if (s.fluent) {
      face = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
        decoration: BoxDecoration(
          color: _hover
              ? s.text.withValues(alpha: s.dark ? 0.1 : 0.05)
              : s.secondaryFill,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: s.cardEdge.withValues(alpha: 0.14)),
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: widget.trailing == null ? 12 : 36,
        ),
        child: label,
      );
    } else {
      face = WelcomeGlass(
        radius: radius,
        fill: _hover
            ? Color.lerp(s.secondaryFill, s.text, 0.06)
            : s.secondaryFill,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.trailing == null ? 12 : 36,
            ),
            child: Center(child: label),
          ),
        ),
      );
    }
    final button = Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: MouseRegion(
        cursor: widget.onPressed != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: WelcomePressFade(
          onTap: widget.onPressed,
          pressedOpacity: s.material ? 1 : 0.7,
          pressedScale: s.material ? 1 : 0.98,
          child: face,
        ),
      ),
    );
    final trailing = widget.trailing;
    if (trailing == null) return button;
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        button,
        Padding(padding: const EdgeInsets.only(right: 10), child: trailing),
      ],
    );
  }
}

/// Кнопка без подложки: «У меня уже есть аккаунт», «Не сейчас».
class WelcomeTextButton extends StatelessWidget {
  const WelcomeTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 46,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    if (!s.material) {
      // Apple и Fluent: текст бледнеет под пальцем, как у `CupertinoButton`,
      // без «волны» Android.
      return Semantics(
        button: true,
        enabled: onPressed != null,
        child: WelcomePressFade(
          onTap: onPressed,
          pressedOpacity: 0.4,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: SizedBox(
              width: double.infinity,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: s.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: s.textSecondary,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Круглая кнопка «назад» в левом верхнем углу.
class WelcomeBackButton extends StatelessWidget {
  const WelcomeBackButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;

  /// `null` — кнопка видна, но погашена (уйти с шага сейчас нельзя).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final icon = Icon(
      s.material ? Icons.arrow_back_rounded : Icons.arrow_back_ios_new_rounded,
      size: s.material ? 22 : 17,
      color: s.text,
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        onTap: onPressed,
        enabled: onPressed != null,
        child: WelcomePressFade(
          onTap: onPressed,
          pressedOpacity: s.material ? 1 : 0.4,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: onPressed == null ? 0.35 : 1,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: s.material
                    ? SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(child: icon),
                      )
                    : WelcomeGlass(
                        radius: 20,
                        fill: s.secondaryFill,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(child: icon),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Отклик на нажатие в стиле iOS: под пальцем кнопка бледнеет (и, если
/// задано, чуть сжимается), отпустил — плавно возвращается. Так ведёт себя
/// `CupertinoButton`. С `pressedOpacity: 1` и `pressedScale: 1` — без
/// видимого отклика (Material, где отклик свой).
class WelcomePressFade extends StatefulWidget {
  const WelcomePressFade({
    super.key,
    required this.onTap,
    required this.child,
    this.pressedOpacity = 0.4,
    this.pressedScale = 1,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double pressedOpacity;
  final double pressedScale;

  @override
  State<WelcomePressFade> createState() => _WelcomePressFadeState();
}

class _WelcomePressFadeState extends State<WelcomePressFade> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 150),
        child: AnimatedOpacity(
          // Гаснет сразу, возвращается мягко — как у iOS.
          opacity: _pressed ? widget.pressedOpacity : 1,
          duration: Duration(milliseconds: _pressed ? 60 : 200),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── стекло, карточки ────────────────────────────────────────────────────────

/// Подложка «жидкое стекло»: размытие того, что позади, тонкая светлая кромка
/// сверху. У Material 3 — обычная плоская заливка.
class WelcomeGlass extends StatelessWidget {
  const WelcomeGlass({
    super.key,
    required this.child,
    this.radius = 22,
    this.fill,
    this.blur = 24,
  });

  final Widget child;
  final double radius;
  final Color? fill;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final shape = BorderRadius.circular(radius);
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: fill ?? s.cardFill,
        borderRadius: shape,
        border: s.material || s.cardEdge.a == 0
            ? null
            : Border.all(color: s.cardEdge, width: 0.5),
      ),
      child: child,
    );
    if (s.material) return ClipRRect(borderRadius: shape, child: body);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: body,
      ),
    );
  }
}

/// Строка списка выбора: заголовок, пояснение и стрелка.
class WelcomeChoiceRow extends StatelessWidget {
  const WelcomeChoiceRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.first = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          decoration: BoxDecoration(
            border: first ? null : Border(top: BorderSide(color: s.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: s.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: s.caption.copyWith(
                        fontSize: 13.5,
                        color: s.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: s.textTertiary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── заголовок шага ──────────────────────────────────────────────────────────

class WelcomeHeading extends StatelessWidget {
  const WelcomeHeading({
    super.key,
    required this.title,
    this.body,
    this.titleSize,
  });

  final String title;
  final String? body;
  final double? titleSize;

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: titleSize == null
                ? s.title
                : s.title.copyWith(fontSize: titleSize),
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 12),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: s.body.copyWith(height: 1.55),
          ),
        ],
      ],
    );
  }
}

/// Круг с первой буквой имени (шаги «Имя» и «Готово»).
class WelcomeInitialAvatar extends StatelessWidget {
  const WelcomeInitialAvatar({
    super.key,
    required this.name,
    this.size = 84,
    this.ring = false,
  });

  final String name;
  final double size;
  final bool ring;

  static String initialOf(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return String.fromCharCode(t.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.4, -0.5),
            radius: 1.1,
            colors: s.avatarStops,
            stops: const [0, 0.45, 1],
          ),
          boxShadow: [
            if (ring)
              BoxShadow(color: s.text.withValues(alpha: 0.05), spreadRadius: 8),
            BoxShadow(
              color: const Color(0xFF4C8DF6).withValues(alpha: 0.38),
              blurRadius: 55,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          initialOf(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: s.material ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── поля ввода ──────────────────────────────────────────────────────────────

/// Поле ввода: заливка (Apple), рамка (Material 3) или заливка с линией
/// снизу (Fluent). [maxLines] больше одного — многострочное.
class WelcomeTextField extends StatefulWidget {
  const WelcomeTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.textAlign = TextAlign.start,
    this.monospace = false,
    this.autofocus = false,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final TextAlign textAlign;
  final bool monospace;
  final bool autofocus;
  final int maxLines;

  @override
  State<WelcomeTextField> createState() => _WelcomeTextFieldState();
}

class _WelcomeTextFieldState extends State<WelcomeTextField> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant WelcomeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _own)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final focused = _focus.hasFocus;
    final radius = BorderRadius.circular(s.fieldRadius);
    final secret = widget.obscure;
    final multiline = widget.maxLines > 1;
    final fontSize = s.fluent ? 15.0 : (s.material ? 16.0 : 17.0);
    final field = TextField(
      controller: widget.controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      obscureText: secret,
      enableSuggestions: !secret,
      autocorrect: !secret,
      keyboardType: multiline ? TextInputType.multiline : widget.keyboardType,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      textAlign: widget.textAlign,
      minLines: multiline ? widget.maxLines : null,
      maxLines: widget.maxLines,
      cursorColor: s.focus,
      style: widget.monospace
          ? s.mono.copyWith(fontSize: fontSize - 0.5, letterSpacing: 1.3)
          : TextStyle(
              color: s.text,
              fontSize: fontSize,
              fontWeight: s.material ? FontWeight.w400 : FontWeight.w500,
            ),
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: widget.hint,
        hintStyle: TextStyle(
          color: s.textTertiary.withValues(alpha: s.dark ? 0.55 : 0.8),
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          fontFamily: widget.monospace ? s.mono.fontFamily : null,
        ),
      ),
    );
    // Fluent: тонкая рамка вокруг и линия снизу — отдельным слоем. Рамка
    // с разными сторонами и скруглением Flutter не рисует вовсе.
    final Border border;
    if (s.fluent) {
      border = Border.all(color: s.cardEdge);
    } else if (s.material) {
      border = Border.all(
        color: focused ? s.focus : s.fieldBorder,
        width: focused ? 2 : 1,
      );
    } else {
      border = Border.all(
        color: focused ? s.focus : const Color(0x00000000),
        width: 2,
      );
    }
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: multiline ? null : s.fieldHeight,
      decoration: BoxDecoration(
        color: focused ? s.fieldFillFocused : s.fieldFill,
        borderRadius: radius,
        border: border,
      ),
      padding: EdgeInsets.only(
        left: s.fluent ? 12 : 18,
        right: widget.trailing == null ? (s.fluent ? 12 : 18) : 6,
        top: multiline ? 14 : 0,
        bottom: multiline ? 14 : 0,
      ),
      child: Row(
        children: [
          Expanded(child: field),
          ?widget.trailing,
        ],
      ),
    );
    if (!s.fluent) return box;
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          box,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: focused ? 2 : 1,
              color: focused ? s.focus : s.fieldBorder,
            ),
          ),
        ],
      ),
    );
  }
}

/// Крупное поле имени: подпись по центру, линия снизу (шаг «Как вас зовут?»).
class WelcomeNameField extends StatefulWidget {
  const WelcomeNameField({
    super.key,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.onSubmitted,
    this.maxLength = 40,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final int maxLength;

  @override
  State<WelcomeNameField> createState() => _WelcomeNameFieldState();
}

class _WelcomeNameFieldState extends State<WelcomeNameField> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _focus.hasFocus ? s.focus : s.text.withValues(alpha: 0.14),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: widget.onSubmitted,
        cursorColor: s.focus,
        inputFormatters: [LengthLimitingTextInputFormatter(widget.maxLength)],
        style: TextStyle(
          color: s.text,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: s.textTertiary.withValues(alpha: s.dark ? 0.55 : 0.75),
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// Переключатель из двух половин: «В облаке | На устройстве».
class WelcomeSegmented<T> extends StatelessWidget {
  const WelcomeSegmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final cells = <Widget>[];
    for (final (v, label) in options) {
      final selected = v == value;
      cells.add(
        Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            inMutuallyExclusiveGroup: true,
            label: label,
            excludeSemantics: true,
            onTap: onChanged == null ? null : () => onChanged!(v),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onChanged == null ? null : () => onChanged!(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: s.material ? 40 : 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? s.segmentSelected
                      : s.segmentSelected.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(s.material ? 0 : 38),
                  boxShadow: selected && !s.material
                      ? const [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected && s.material) ...[
                      Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: s.segmentSelectedText,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: selected
                              ? s.segmentSelectedText
                              : s.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final row = Row(children: cells);
    if (s.material) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: s.fieldBorder),
        ),
        child: row,
      );
    }
    return WelcomeGlass(
      radius: 44,
      fill: s.segmentTrack,
      child: Padding(padding: const EdgeInsets.all(3), child: row),
    );
  }
}

/// Тонкая полоска хода работы (создание ключей, восстановление).
class WelcomeProgressLine extends StatelessWidget {
  const WelcomeProgressLine({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    return SizedBox(
      width: 180,
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: s.text.withValues(alpha: 0.1)),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(end: value.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: const Cubic(0.2, 0.8, 0.2, 1),
              builder: (_, v, __) => FractionallySizedBox(
                widthFactor: v,
                child: ColoredBox(color: s.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── листы ───────────────────────────────────────────────────────────────────

/// Лист снизу в новом стиле: «парящий» стеклянный (Apple) или лист
/// Material 3 с ручкой.
Future<T?> showWelcomeSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  final s = WelcomeStyle.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: s.dark ? 0.32 : 0.18),
    builder: (ctx) => WelcomeSheetFrame(child: builder(ctx)),
  );
}

/// Рамка листа: отступы, скругления, ручка сверху.
class WelcomeSheetFrame extends StatelessWidget {
  const WelcomeSheetFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final handle = Center(
      child: Container(
        width: s.material ? 32 : 36,
        height: s.material ? 4 : 5,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: s.text.withValues(alpha: s.material ? 0.4 : 0.2),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
    final content = Padding(
      padding: EdgeInsets.fromLTRB(22, 10, 22, s.material ? 24 : 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          handle,
          Flexible(child: child),
        ],
      ),
    );
    final Widget sheet;
    if (s.material) {
      sheet = Material(
        color: s.sheetFill,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(top: false, child: content),
      );
    } else {
      sheet = Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 44, sigmaY: 44),
              child: Material(
                type: MaterialType.transparency,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: s.dark
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xCC303036), Color(0xE01C1C20)],
                          )
                        : null,
                    color: s.dark ? null : s.sheetFill,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: s.cardEdge, width: 0.5),
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: s.text),
        child: sheet,
      ),
    );
  }
}

// ─── пояснения и диалоги ─────────────────────────────────────────────────────

/// Маленький «?» с пояснением (решение владельца 17.11.2026: пояснения на
/// экранах входа ПК — не абзацами, а значком). Подсказка открывается
/// наведением и нажатием; читалка экрана получает текст пояснения сразу.
class WelcomeInfoDot extends StatelessWidget {
  const WelcomeInfoDot({
    super.key,
    required this.message,
    this.size = 20,
    this.color,
  });

  final String message;
  final double size;

  /// Цвет значка — на цветной кнопке берётся цвет её подписи.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      waitDuration: const Duration(milliseconds: 120),
      showDuration: const Duration(seconds: 8),
      preferBelow: true,
      verticalOffset: size * 0.9,
      enableTapToDismiss: true,
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: s.dark ? const Color(0xF2242428) : const Color(0xF7FFFFFF),
        borderRadius: BorderRadius.circular(s.fluent ? 6 : 14),
        border: Border.all(color: s.text.withValues(alpha: 0.1), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      textStyle: TextStyle(
        color: s.text.withValues(alpha: 0.86),
        fontSize: 13,
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
      child: MouseRegion(cursor: SystemMouseCursors.help, child: _dot(s)),
    );
  }

  Widget _dot(WelcomeStyle s) {
    final ink = color ?? s.text;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ink.withValues(alpha: 0.12),
        border: Border.all(color: ink.withValues(alpha: 0.2)),
      ),
      child: Text(
        '?',
        style: TextStyle(
          color: ink.withValues(alpha: 0.78),
          fontSize: size * 0.6,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Разделитель «или» между главной кнопкой и второстепенными.
class WelcomeOrDivider extends StatelessWidget {
  const WelcomeOrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final line = Expanded(
      child: Container(height: 1, color: s.text.withValues(alpha: 0.1)),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: s.text.withValues(alpha: 0.3),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// Окно по центру в новом стиле (ПК): стекло на Apple, плоская карточка на
/// Windows. Возвращает то, с чем его закрыли.
Future<T?> showWelcomeDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final s = WelcomeStyle.of(context);
  return showGeneralDialog<T>(
    context: context,
    // Окно — над своим экраном, а не над всем окном приложения: у входа ПК
    // свой навигатор, и предупреждение должно лежать поверх того же фона.
    useRootNavigator: false,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: s.dark ? 0.3 : 0.16),
    transitionDuration: const Duration(milliseconds: 320),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: const Cubic(0.2, 0.8, 0.2, 1),
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, __) {
      final st = WelcomeStyle.of(ctx);
      final radius = BorderRadius.circular(st.fluent ? 8 : 30);
      final card = Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: !st.material && st.dark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xCC303036), Color(0xE01C1C20)],
                )
              : null,
          color: !st.material && st.dark ? null : st.sheetFill,
          borderRadius: radius,
          border: Border.all(color: st.cardEdge, width: st.fluent ? 1 : 0.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x73000000),
              blurRadius: 80,
              offset: Offset(0, 30),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: st.text),
            child: builder(ctx),
          ),
        ),
      );
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: st.material
                ? card
                : ClipRRect(
                    borderRadius: radius,
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 44, sigmaY: 44),
                      child: card,
                    ),
                  ),
          ),
        ),
      );
    },
  );
}
