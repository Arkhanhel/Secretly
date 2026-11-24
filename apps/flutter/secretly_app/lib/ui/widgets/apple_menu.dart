// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Единое меню «⋯» для iPhone — как `UIMenu` iOS (решение владельца
/// 20.11.2026: «все бургер-меню в едином айфоновском стиле»).
///
/// * Стеклянная панель (размытие + материал `AppleGlass`), радиус 18 — как
///   у `PopupMenuButton` в теме iPhone.
/// * Строки iOS: подпись слева 17 pt, значок справа, высота от 44 pt (растёт
///   с крупным шрифтом), тонкие разделители между строками, «опасное»
///   действие — красным. Подсветка нажатия, без «волны».
/// * Раскрытие из угла, ближайшего к кнопке: масштаб 0,6 → 1 и проявление по
///   кривой Telegram (≈ 0,32 с), закрытие — быстрее и короче.
/// * Место выбирается по экрану: под кнопкой, если помещается, иначе над
///   ней; по горизонтали — от того края кнопки, что ближе к середине;
///   всегда внутри безопасной зоны с отступом 8; не помещается по высоте —
///   прокручивается. Ширина — по содержимому, 220…280, но не шире экрана.
///
/// На Android и компьютере всё это не используется — там прежние меню.
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../apple_glass.dart';
import '../haptics.dart';
import '../motion/motion.dart';
import '../motion/press_feedback.dart';

/// Меню iOS включено: iPhone, стекло включено.
bool appleMenusEnabled(BuildContext context) =>
    defaultTargetPlatform == TargetPlatform.iOS && appleGlassPanelsEnabled;

/// Радиус панели меню (тот же у `PopupMenuButton` в теме iPhone).
const double kAppleMenuRadius = 18;

/// Цвет тонкого разделителя строк меню.
Color appleMenuSeparator(bool dark) =>
    dark ? const Color(0x33FFFFFF) : const Color(0x26000000);

/// Прямоугольник виджета на экране — к нему «пристёгивается» меню.
Rect? anchorRectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Стеклянная панель меню iOS. Используется и [showAppleMenu], и прежними
/// всплывающими меню (`FrostedPopupContainer` на iPhone).
class AppleMenuPanel extends StatelessWidget {
  const AppleMenuPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(kAppleMenuRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.40 : 0.16),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: ShapeDecoration(
              shape: AppleGlassBorder(radius: kAppleMenuRadius, dark: dark),
            ),
            child: ColoredBox(
              color: dark ? const Color(0xC72A2A2E) : const Color(0xD9F7F7F9),
              child: Material(
                type: MaterialType.transparency,
                child: _AppleMenuTheme(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Тема внутри меню: строки `PopupMenuItem` (меню с кнопок `⋯`) выглядят
/// как строки iOS, разделители `Divider` — невидимые (строки сами
/// разделены тонкой линией).
class _AppleMenuTheme extends StatelessWidget {
  const _AppleMenuTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final label = dark ? Colors.white : Colors.black;
    return Theme(
      data: theme.copyWith(
        splashFactory: NoSplash.splashFactory,
        highlightColor: dark
            ? const Color(0x1FFFFFFF)
            : const Color(0x14000000),
        hoverColor: Colors.transparent,
        dividerTheme: const DividerThemeData(
          color: Colors.transparent,
          space: 1,
          thickness: 1,
        ),
        popupMenuTheme: theme.popupMenuTheme.copyWith(
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: label,
              letterSpacing: -0.4,
            ),
          ),
        ),
        iconTheme: theme.iconTheme.copyWith(color: label, size: 20),
        listTileTheme: theme.listTileTheme.copyWith(
          iconColor: label,
          textColor: label,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: 17, color: label, letterSpacing: -0.4),
        child: IconTheme.merge(
          data: IconThemeData(color: label, size: 20),
          child: child,
        ),
      ),
    );
  }
}

/// Строка меню iOS: подпись слева, значок справа, тонкая линия снизу.
class AppleMenuRow extends StatefulWidget {
  const AppleMenuRow({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.destructive = false,
    this.enabled = true,
    this.separator = true,
    required this.onTap,
  });

  final String title;
  final IconData? icon;

  /// Свой значок (например, анимированный) вместо [icon].
  final Widget? leading;
  final bool destructive;
  final bool enabled;

  /// Линия снизу. У последней строки её прячет край панели.
  final bool separator;
  final VoidCallback onTap;

  @override
  State<AppleMenuRow> createState() => _AppleMenuRowState();
}

class _AppleMenuRowState extends State<AppleMenuRow> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.destructive
        ? CupertinoColors.systemRed.resolveFrom(context)
        : (dark ? Colors.white : Colors.black);
    final color = widget.enabled ? base : base.withValues(alpha: 0.35);
    final scaler = MediaQuery.textScalerOf(context);
    final iconWidget = widget.leading ??
        (widget.icon == null
            ? null
            : Icon(widget.icon, size: 20, color: color));
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.title,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _set(true) : null,
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.enabled
            ? () {
                Haptics.tap();
                widget.onTap();
              }
            : null,
        child: AnimatedContainer(
          duration: Duration(milliseconds: _down ? 0 : 200),
          constraints: BoxConstraints(minHeight: scaler.scale(44)),
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
          decoration: BoxDecoration(
            color: _down
                ? (dark ? const Color(0x1FFFFFFF) : const Color(0x14000000))
                : Colors.transparent,
            border: widget.separator
                ? Border(
                    bottom: BorderSide(
                      color: appleMenuSeparator(dark),
                      width: 0.5,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.2,
                    letterSpacing: -0.4,
                    color: color,
                  ),
                ),
              ),
              if (iconWidget != null) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 24,
                  child: Center(
                    child: IconTheme.merge(
                      data: IconThemeData(color: color, size: 20),
                      child: iconWidget,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Разрыв между группами строк (как толстый разделитель `UIMenu`).
class AppleMenuGroupGap extends StatelessWidget {
  const AppleMenuGroupGap({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 8,
      color: dark ? const Color(0x40000000) : const Color(0x14000000),
    );
  }
}

/// Показать меню iOS у [anchor] (прямоугольник кнопки на экране).
/// [children] — строки ([AppleMenuRow], `PopupMenuItem` — их значения
/// возвращаются через `Navigator.pop`), [AppleMenuGroupGap].
Future<T?> showAppleMenu<T>({
  required BuildContext context,
  required Rect anchor,
  required List<Widget> children,
  bool useRootNavigator = true,
}) {
  final nav = Navigator.of(context, rootNavigator: useRootNavigator);
  return nav.push<T>(
    _AppleMenuRoute<T>(
      anchor: anchor,
      children: children,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      capturedThemes: InheritedTheme.capture(from: context, to: nav.context),
    ),
  );
}

/// Можно ли показать записи меню строками iOS. Свои записи (не
/// `PopupMenuItem` / `PopupMenuDivider`) — нет: тогда остаётся меню
/// Material, чтобы ничего не потерять.
bool appleMenuSupportsEntries<T>(List<PopupMenuEntry<T>> entries) =>
    entries.every((e) => e is PopupMenuItem<T> || e is PopupMenuDivider);

/// Записи `PopupMenuButton` / `showMenu` → строки меню iOS. Из записи
/// берутся подпись, значок и цвет («опасное» — красное); `PopupMenuDivider`
/// — разрыв группы. Нажатие возвращает `value` записи.
List<Widget> appleMenuChildrenFromEntries<T>(List<PopupMenuEntry<T>> entries) {
  final out = <Widget>[];
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    if (e is PopupMenuDivider) {
      if (out.isNotEmpty) out.add(const AppleMenuGroupGap());
      continue;
    }
    if (e is! PopupMenuItem<T>) continue;
    final next = i + 1 < entries.length ? entries[i + 1] : null;
    out.add(
      _EntryRow<T>(
        item: e,
        separator: next != null && next is! PopupMenuDivider,
      ),
    );
  }
  return out;
}

/// Подпись, значок и «опасность» из содержимого записи меню.
({String? title, IconData? icon, Widget? leading, bool destructive})
_parseEntry(Widget? child) {
  String? title;
  IconData? icon;
  Widget? leading;
  var destructive = false;
  bool isDanger(Color? c) =>
      c != null &&
      (c == Colors.red ||
          (c.r > 0.75 && c.g < 0.4 && c.b < 0.4));
  void visit(Widget? w) {
    if (w == null) return;
    if (w is Text) {
      title ??= w.data ?? w.textSpan?.toPlainText();
      if (isDanger(w.style?.color)) destructive = true;
    } else if (w is Icon) {
      icon ??= w.icon;
      if (isDanger(w.color)) destructive = true;
    } else if (w is ListTile) {
      visit(w.leading);
      visit(w.title);
      if (isDanger(w.textColor) || isDanger(w.iconColor)) destructive = true;
    } else if (w is Row) {
      for (final c in w.children) {
        visit(c);
      }
    } else if (w is Flex) {
      for (final c in w.children) {
        visit(c);
      }
    } else if (w is Expanded) {
      visit(w.child);
    } else if (w is Flexible) {
      visit(w.child);
    } else if (w is Padding) {
      visit(w.child);
    } else if (w is SizedBox) {
      visit(w.child);
    } else if (w is Center) {
      visit(w.child);
    } else if (w is Align) {
      visit(w.child);
    } else if (title == null && leading == null) {
      // Своё содержимое (например, анимированный значок) — как есть.
      leading = w;
    }
  }
  visit(child);
  return (
    title: title,
    icon: icon,
    leading: title == null ? leading : null,
    destructive: destructive,
  );
}

class _EntryRow<T> extends StatelessWidget {
  const _EntryRow({required this.item, required this.separator});

  final PopupMenuItem<T> item;
  final bool separator;

  @override
  Widget build(BuildContext context) {
    final parsed = _parseEntry(item.child);
    void tap() {
      item.onTap?.call();
      Navigator.of(context).pop<T>(item.value);
    }
    final checked = item is CheckedPopupMenuItem<T> &&
        (item as CheckedPopupMenuItem<T>).checked;
    if (parsed.title == null) {
      // Подпись не нашлась — показываем содержимое записи в строке iOS.
      final dark = Theme.of(context).brightness == Brightness.dark;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: item.enabled ? tap : null,
        child: Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.textScalerOf(context).scale(44),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: separator
                ? Border(
                    bottom: BorderSide(
                      color: appleMenuSeparator(dark),
                      width: 0.5,
                    ),
                  )
                : null,
          ),
          child: item.child,
        ),
      );
    }
    return AppleMenuRow(
      title: parsed.title!,
      icon: checked ? CupertinoIcons.checkmark : parsed.icon,
      leading: checked ? null : parsed.leading,
      destructive: parsed.destructive,
      enabled: item.enabled,
      separator: separator,
      onTap: tap,
    );
  }
}

class _AppleMenuRoute<T> extends PopupRoute<T> {
  _AppleMenuRoute({
    required this.anchor,
    required this.children,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final Rect anchor;
  final List<Widget> children;
  final CapturedThemes capturedThemes;

  @override
  final String? barrierLabel;

  @override
  Color? get barrierColor => const Color(0x14000000);

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final mq = MediaQuery.of(context);
    final placement = _AppleMenuPlacement.compute(
      anchor: anchor,
      screen: mq.size,
      padding: mq.padding + EdgeInsets.only(bottom: mq.viewInsets.bottom),
    );
    return capturedThemes.wrap(
      CustomSingleChildLayout(
        delegate: _AppleMenuLayout(placement),
        child: _AppleMenuBody(
          animation: animation,
          origin: placement.origin,
          maxHeight: placement.maxHeight,
          maxWidth: placement.maxWidth,
          children: children,
        ),
      ),
    );
  }
}

/// Где показать меню: под/над кнопкой и от какого её края.
@immutable
class _AppleMenuPlacement {
  const _AppleMenuPlacement({
    required this.anchor,
    required this.below,
    required this.alignRight,
    required this.maxHeight,
    required this.maxWidth,
    required this.safe,
  });

  final Rect anchor;
  final bool below;
  final bool alignRight;
  final double maxHeight;
  final double maxWidth;
  final Rect safe;

  static const double gap = 6;
  static const double margin = 8;

  /// Угол, из которого вырастает меню (ближний к кнопке).
  Alignment get origin => Alignment(
    alignRight ? 1 : -1,
    below ? -1 : 1,
  );

  static _AppleMenuPlacement compute({
    required Rect anchor,
    required Size screen,
    required EdgeInsets padding,
  }) {
    final safe = Rect.fromLTRB(
      padding.left + margin,
      padding.top + margin,
      screen.width - padding.right - margin,
      screen.height - padding.bottom - margin,
    );
    final spaceBelow = safe.bottom - (anchor.bottom + gap);
    final spaceAbove = (anchor.top - gap) - safe.top;
    // Под кнопкой, если там не меньше трети экрана или больше, чем сверху.
    final below = spaceBelow >= math.min(260, safe.height / 3) ||
        spaceBelow >= spaceAbove;
    final alignRight = anchor.center.dx > screen.width / 2;
    return _AppleMenuPlacement(
      anchor: anchor,
      below: below,
      alignRight: alignRight,
      maxHeight: math.max(120, below ? spaceBelow : spaceAbove),
      maxWidth: math.min(280, safe.width),
      safe: safe,
    );
  }
}

class _AppleMenuLayout extends SingleChildLayoutDelegate {
  _AppleMenuLayout(this.p);

  final _AppleMenuPlacement p;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size(p.maxWidth, p.maxHeight));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = p.alignRight ? p.anchor.right - childSize.width : p.anchor.left;
    x = x.clamp(p.safe.left, math.max(p.safe.left, p.safe.right - childSize.width));
    var y = p.below
        ? p.anchor.bottom + _AppleMenuPlacement.gap
        : p.anchor.top - _AppleMenuPlacement.gap - childSize.height;
    y = y.clamp(p.safe.top, math.max(p.safe.top, p.safe.bottom - childSize.height));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_AppleMenuLayout old) =>
      old.p.anchor != p.anchor ||
      old.p.below != p.below ||
      old.p.alignRight != p.alignRight ||
      old.p.maxHeight != p.maxHeight ||
      old.p.maxWidth != p.maxWidth;
}

class _AppleMenuBody extends StatelessWidget {
  const _AppleMenuBody({
    required this.animation,
    required this.origin,
    required this.maxHeight,
    required this.maxWidth,
    required this.children,
  });

  final Animation<double> animation;
  final Alignment origin;
  final double maxHeight;
  final double maxWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final reduced = motionReduced(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final forward = animation.status != AnimationStatus.reverse;
        final k = forward
            ? TgCurves.ios.transform(t)
            : Curves.easeIn.transform(t);
        final scale = reduced ? 1.0 : (forward ? 0.6 + 0.4 * k : 0.9 + 0.1 * k);
        final opacity = forward ? (t / 0.45).clamp(0.0, 1.0) : k;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            alignment: origin,
            child: child,
          ),
        );
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: math.min(220, maxWidth),
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: IntrinsicWidth(
          child: AppleMenuPanel(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `PopupMenuButton`, который на iPhone открывает меню iOS
/// ([showAppleMenu]) у самой кнопки, а на Android и компьютере — прежнее
/// меню Material. Кнопка сжимается при нажатии ([PressFeedback]).
class AppPopupMenuButton<T> extends PopupMenuButton<T> {
  const AppPopupMenuButton({
    super.key,
    required super.itemBuilder,
    super.initialValue,
    super.onOpened,
    super.onSelected,
    super.onCanceled,
    super.tooltip,
    super.elevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.padding,
    super.menuPadding,
    super.child,
    super.borderRadius,
    super.splashRadius,
    super.icon,
    super.iconSize,
    super.offset,
    super.enabled,
    super.shape,
    super.color,
    super.iconColor,
    super.enableFeedback,
    super.constraints,
    super.position,
    super.clipBehavior,
    super.useRootNavigator,
    super.popUpAnimationStyle,
    super.routeSettings,
    super.style,
    super.requestFocus,
  });

  @override
  PopupMenuButtonState<T> createState() => _AppPopupMenuButtonState<T>();
}

class _AppPopupMenuButtonState<T> extends PopupMenuButtonState<T> {
  @override
  void showButtonMenu() {
    if (!appleMenusEnabled(context)) {
      super.showButtonMenu();
      return;
    }
    final anchor = anchorRectOf(context);
    final items = widget.itemBuilder(context);
    if (items.isEmpty) return;
    if (anchor == null || !appleMenuSupportsEntries<T>(items)) {
      super.showButtonMenu();
      return;
    }
    widget.onOpened?.call();
    showAppleMenu<T>(
      context: context,
      anchor: anchor,
      useRootNavigator: widget.useRootNavigator,
      children: appleMenuChildrenFromEntries<T>(items),
    ).then((value) {
      if (!mounted) return;
      if (value == null) {
        widget.onCanceled?.call();
      } else {
        widget.onSelected?.call(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      PressFeedback(enabled: widget.enabled, child: super.build(context));
}

/// `showMenu`, который на iPhone показывает меню iOS у точки/прямоугольника
/// [position], а на Android и компьютере — прежнее меню Material.
Future<T?> showAppMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<PopupMenuEntry<T>> items,
  bool useRootNavigator = false,
}) {
  if (!appleMenusEnabled(context) || !appleMenuSupportsEntries<T>(items)) {
    return showMenu<T>(
      context: context,
      position: position,
      items: items,
      useRootNavigator: useRootNavigator,
    );
  }
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  final size = overlay?.size ?? MediaQuery.sizeOf(context);
  final anchor = Rect.fromLTRB(
    position.left,
    position.top,
    size.width - position.right,
    size.height - position.bottom,
  );
  return showAppleMenu<T>(
    context: context,
    anchor: anchor,
    useRootNavigator: useRootNavigator,
    children: appleMenuChildrenFromEntries<T>(items),
  );
}

/// Строка всплывающего меню для всех платформ: на iPhone — строка iOS
/// ([AppleMenuRow]), на Android и компьютере — прежняя (значок слева,
/// полужирная подпись, «волна»). Одна на все меню «⋯» приложения.
class AppMenuRow extends StatelessWidget {
  const AppMenuRow({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.trailing,
    this.destructive = false,
    this.iconColor,
    this.textColor,
    required this.onTap,
  });

  final String title;
  final IconData? icon;
  final Widget? leading;

  /// Знак справа (например, «›» у вложенного меню). На iPhone он занимает
  /// место значка — как у `UIMenu` с подменю.
  final Widget? trailing;
  final bool destructive;
  final Color? iconColor;
  final Color? textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (appleMenusEnabled(context)) {
      return AppleMenuRow(
        title: title,
        icon: icon,
        leading: trailing ?? leading,
        destructive: destructive,
        onTap: onTap,
      );
    }
    final cs = Theme.of(context).colorScheme;
    final danger = destructive ? cs.error : null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            leading ??
                Icon(
                  icon,
                  size: 22,
                  color:
                      iconColor ?? danger ?? cs.onSurface.withValues(alpha: 0.92),
                ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor ?? danger,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Выпадающий список: на iPhone — значение с «⌃⌄» и меню iOS у самой
/// кнопки (как `UIButton` с меню), на Android и компьютере — прежний
/// `DropdownButton`.
class AppDropdownButton<T> extends StatelessWidget {
  const AppDropdownButton({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.dropdownColor,
    this.style,
  });

  final T? value;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final Color? dropdownColor;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (!appleMenusEnabled(context)) {
      return DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        dropdownColor: dropdownColor,
        style: style,
      );
    }
    final entries = items ?? <DropdownMenuItem<T>>[];
    String labelOf(DropdownMenuItem<T> item) =>
        _parseEntry(item.child).title ?? '$value';
    final selected = entries.where((e) => e.value == value);
    final enabled = onChanged != null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = enabled
        ? AppleGlass.secondaryLabel(dark)
        : AppleGlass.secondaryLabel(dark).withValues(alpha: 0.35);
    return Builder(
      builder: (buttonContext) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !enabled
            ? null
            : () async {
                final anchor = anchorRectOf(buttonContext);
                if (anchor == null) return;
                final picked = await showAppleMenu<_Picked<T>>(
                  context: buttonContext,
                  anchor: anchor,
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      Builder(
                        builder: (rowContext) => AppleMenuRow(
                          title: labelOf(entries[i]),
                          icon: entries[i].value == value
                              ? CupertinoIcons.checkmark
                              : null,
                          separator: i < entries.length - 1,
                          onTap: () => Navigator.of(
                            rowContext,
                          ).pop(_Picked<T>(entries[i].value)),
                        ),
                      ),
                  ],
                );
                if (picked != null) onChanged?.call(picked.value);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selected.isEmpty ? '' : labelOf(selected.first),
                style: TextStyle(fontSize: 17, color: color),
              ),
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_up_chevron_down,
                size: 14,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Обёртка выбранного значения: `null` из меню — «закрыли без выбора»,
/// а не «выбрали null».
class _Picked<T> {
  const _Picked(this.value);
  final T? value;
}
