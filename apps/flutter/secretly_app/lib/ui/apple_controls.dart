// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'apple_glass.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'apple_style.dart';
import 'motion/motion.dart';

/// Окна и элементы управления в стиле iPhone (решение владельца 17.11.2026).
///
/// Каждый виджет здесь на iPhone рисуется «по-яблочному», а на Android и
/// компьютере строит РОВНО тот Material-виджет, что стоял на его месте
/// раньше, с теми же параметрами. Поэтому замена в коде экранов —
/// `AlertDialog(` → `SecretlyAlertDialog(` и т. п. — для Android ничего не
/// меняет. Выключатели — в `apple_style.dart`.

/// Красный iOS для опасных действий.
const Color _iosRedLight = Color(0xFFFF3B30);
const Color _iosRedDark = Color(0xFFFF453A);

/// Окно подтверждения / окно с полем ввода.
///
/// На iPhone — как системное окно iOS: матовая панель по центру, заголовок и
/// текст по центру, кнопки во всю ширину с тонкими разделителями. Опасное
/// действие (красная кнопка) — красным, основное — жирным. Две кнопки —
/// рядом, три и больше — столбиком.
///
/// Окна, где внутри не только текст (списки выбора, формы пароля, галочки),
/// получают ту же оболочку, но шире: в узкой системной им тесно.
class SecretlyAlertDialog extends StatelessWidget {
  const SecretlyAlertDialog({
    super.key,
    this.title,
    this.titlePadding,
    this.content,
    this.actions,
    this.backgroundColor,
    this.scrollable = false,
  });

  final Widget? title;
  final EdgeInsetsGeometry? titlePadding;
  final Widget? content;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (!appleDialogsEnabled) {
      return AlertDialog(
        title: title,
        titlePadding: titlePadding,
        content: content,
        actions: actions,
        backgroundColor: backgroundColor,
        scrollable: scrollable,
      );
    }
    return _AppleAlert(
      title: title,
      content: content,
      actions: actions ?? const <Widget>[],
      backgroundColor: backgroundColor,
      scrollable: scrollable,
    );
  }
}

/// Простое ли содержимое: только текст или одно поле ввода — тогда окно
/// узкое, как системное (270), иначе — пошире.
bool _isSimpleContent(Widget? content) =>
    content == null ||
    content is Text ||
    content is TextField ||
    content is TextFormField;

@immutable
class _AppleAction {
  const _AppleAction({
    required this.onPressed,
    required this.child,
    required this.destructive,
    required this.primary,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool destructive;

  /// Кнопка Material с заливкой (`FilledButton`) — основное действие окна.
  final bool primary;
}

bool _isReddish(Color? c, ColorScheme scheme) {
  if (c == null) return false;
  if (c.toARGB32() == scheme.error.toARGB32()) return true;
  return c.r > 0.7 && c.g < 0.42 && c.b < 0.42;
}

/// Цвет обычных кнопок окна — акцент приложения. Если акцент сам почти
/// красный (розовая, малиновая, оранжевая темы), «Отмена» станет похожа на
/// «Удалить» — тогда берётся системный синий iOS.
Color _alertAccent(ColorScheme scheme, bool dark) {
  final hsl = HSLColor.fromColor(scheme.primary);
  final reddish = hsl.saturation > 0.35 && (hsl.hue < 30 || hsl.hue > 320);
  if (!reddish) return scheme.primary;
  return dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
}

Color? _textColorOf(Widget child) {
  if (child is Text) return child.style?.color;
  return null;
}

/// Кнопку окна (`TextButton`, `FilledButton`…) разбирает на нажатие,
/// надпись и «опасность». Неизвестный виджет остаётся как есть.
_AppleAction? _actionFrom(Widget w, ColorScheme scheme) {
  if (w is! ButtonStyleButton) return null;
  final style = w.style;
  final fg = style?.foregroundColor?.resolve(const <WidgetState>{});
  final bg = style?.backgroundColor?.resolve(const <WidgetState>{});
  final child = w.child ?? const SizedBox.shrink();
  final filled = w is FilledButton || w is ElevatedButton;
  final destructive =
      _isReddish(fg, scheme) ||
      _isReddish(_textColorOf(child), scheme) ||
      (filled && _isReddish(bg, scheme));
  return _AppleAction(
    onPressed: w.onPressed,
    child: child,
    destructive: destructive,
    primary: filled,
  );
}

class _AppleAlert extends StatelessWidget {
  const _AppleAlert({
    required this.title,
    required this.content,
    required this.actions,
    required this.backgroundColor,
    required this.scrollable,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final Color? backgroundColor;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Окно со своим фоном (тёмная плашка стикеров): цвета текста, линий и
    // полей — от этого фона, а не от темы, иначе в светлой теме поле ввода
    // становится белым под белым текстом.
    final ownFill = backgroundColor;
    final dark = ownFill != null
        ? ThemeData.estimateBrightnessForColor(ownFill) == Brightness.dark
        : theme.brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final simple = _isSimpleContent(content);
    final accent = _alertAccent(scheme, dark);
    final width = math.min(simple ? 270.0 : 320.0, media.size.width - 48);

    final fill =
        backgroundColor ??
        (dark ? const Color(0xD91E1E20) : const Color(0xE6F2F2F4));
    final hairline = dark ? const Color(0x33FFFFFF) : const Color(0x333C3C43);
    final textColor = dark ? Colors.white : Colors.black;
    final secondary = dark ? const Color(0xB3EBEBF5) : const Color(0xFF3C3C43);

    final parsed = [for (final a in actions) _actionFrom(a, scheme)];
    final anyDestructive = parsed.any((a) => a?.destructive ?? false);
    final nonDestructive = parsed
        .where((a) => a != null && !a.destructive)
        .toList();

    // «Отмена» рядом с опасным действием: единственная простая (без
    // заливки) не-опасная кнопка. В iOS она жирная, а в столбике — внизу.
    final plainSafe = [
      for (var i = 0; i < parsed.length; i++)
        if (parsed[i] != null && !parsed[i]!.destructive && !parsed[i]!.primary)
          i,
    ];
    final cancelIndex = anyDestructive
        ? (nonDestructive.length == 1
              ? parsed.indexWhere((a) => a != null && !a.destructive)
              : (plainSafe.length == 1 ? plainSafe.first : -1))
        : -1;

    bool isBold(int i) {
      final a = parsed[i]!;
      if (a.destructive) return false;
      if (anyDestructive) return i == cancelIndex;
      return a.primary || parsed.length == 1;
    }

    Widget buttonAt(int i) {
      final original = actions[i];
      final a = parsed[i];
      if (a == null) return Center(child: original);
      // Ключ исходной кнопки сохраняется: по нему её находят тесты.
      return KeyedSubtree(
        key: original.key,
        child: _AppleAlertButton(
          action: a,
          bold: isBold(i),
          color: a.destructive ? (dark ? _iosRedDark : _iosRedLight) : accent,
        ),
      );
    }

    final order = [for (var i = 0; i < actions.length; i++) i];
    if (actions.length > 2 && cancelIndex >= 0) {
      order
        ..remove(cancelIndex)
        ..add(cancelIndex);
    }
    final buttons = <Widget>[for (final i in order) buttonAt(i)];

    Widget? body = content;
    if (body != null) {
      body = DefaultTextStyle.merge(
        textAlign: simple ? TextAlign.center : null,
        style: TextStyle(
          color: secondary,
          fontSize: 13.5,
          height: 1.3,
          letterSpacing: -0.08,
        ),
        child: ownFill != null
            ? body
            : Theme(
                data: theme.copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    isDense: true,
                    filled: true,
                    fillColor: dark ? const Color(0xFF1C1C1E) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: hairline, width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: hairline, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: accent, width: 1),
                    ),
                  ),
                ),
                child: body,
              ),
      );
      body = scrollable ? SingleChildScrollView(child: body) : body;
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 19, 16, 15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            DefaultTextStyle.merge(
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.25,
                letterSpacing: -0.4,
              ),
              child: title!,
            ),
          if (title != null && body != null) const SizedBox(height: 4),
          if (body != null) Flexible(child: body),
        ],
      ),
    );

    final side = buttons.length == 2;
    final actionArea = buttons.isEmpty
        ? null
        : side
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: buttons[0]),
                Container(width: 0.5, color: hairline),
                Expanded(child: buttons[1]),
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) Container(height: 0.5, color: hairline),
                buttons[i],
              ],
            ],
          );

    // Liquid Glass (20.11.2026): скругление крупнее, как у окон iOS 26, и
    // светлая кромка стекла поверх. Размытие под окном было и раньше.
    final radius = appleGlassPanelsEnabled ? AppleGlass.radius : 14.0;
    final panel = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: appleGlassPanelsEnabled
              ? ShapeDecoration(
                  shape: AppleGlassBorder(radius: radius, dark: dark),
                )
              : const BoxDecoration(),
          child: ColoredBox(
          color: fill,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(child: header),
                if (actionArea != null) ...[
                  Container(height: 0.5, color: hairline),
                  actionArea,
                ],
              ],
            ),
          ),
          ),
        ),
      ),
    );

    // Появление как у iOS: из чуть увеличенного к обычному. Уход — только
    // растворением, без увеличения (так закрывается окно iOS). Без
    // CurvedAnimation на каждое построение: окно с полем ввода
    // перестраивается на каждом кадре клавиатуры.
    final animation = ModalRoute.of(context)?.animation;
    Widget sized = SizedBox(width: width, child: panel);
    if (animation != null && !media.disableAnimations) {
      sized = AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final leaving = animation.status == AnimationStatus.reverse;
          final scale = leaving
              ? 1.0
              : 1.12 - 0.12 * Curves.easeOutCubic.transform(animation.value);
          return Transform.scale(scale: scale, child: child);
        },
        child: sized,
      );
    }

    // Заголовок окна читает сам экранный диктор: как у системного окна iOS,
    // без общей подписи «Предупреждение» поверх него.
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        padding:
            media.viewInsets +
            const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: MediaQuery.removeViewInsets(
          removeLeft: true,
          removeTop: true,
          removeRight: true,
          removeBottom: true,
          context: context,
          child: Center(child: sized),
        ),
      ),
    );
  }
}

class _AppleAlertButton extends StatelessWidget {
  const _AppleAlertButton({
    required this.action,
    required this.bold,
    required this.color,
  });

  final _AppleAction action;
  final bool bold;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = action.onPressed != null;
    final effective = enabled
        ? color
        : (dark ? const Color(0x4DEBEBF5) : const Color(0x4D3C3C43));
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: action.onPressed,
        splashFactory: NoSplash.splashFactory,
        highlightColor: dark
            ? const Color(0x1FFFFFFF)
            : const Color(0x14000000),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: IconTheme.merge(
                data: IconThemeData(color: effective, size: 20),
                child: DefaultTextStyle.merge(
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: effective,
                    fontSize: 17,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: -0.4,
                  ),
                  child: _recolor(action.child, effective, bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Надпись кнопки часто несёт свой цвет (красный у «Удалить»): в окне iOS
  /// цвет задаёт роль кнопки, поэтому у простого `Text` он снимается.
  static Widget _recolor(Widget child, Color color, bool bold) {
    if (child is! Text || child.data == null) return child;
    return Text(
      child.data!,
      key: child.key,
      maxLines: child.maxLines ?? 2,
      overflow: child.overflow ?? TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      semanticsLabel: child.semanticsLabel,
      style: (child.style ?? const TextStyle()).copyWith(
        color: color,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        fontSize: 17,
      ),
    );
  }
}

/// Переключатель: на iPhone — системный Apple, иначе прежний Material.
class SecretlySwitch extends StatelessWidget {
  const SecretlySwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.activeThumbColor,
    this.activeTrackColor,
    this.inactiveThumbColor,
    this.inactiveTrackColor,
    this.thumbColor,
    this.trackColor,
    this.trackOutlineColor,
    this.thumbIcon,
    this.materialTapTargetSize,
    this.focusNode,
    this.autofocus = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final Color? activeThumbColor;
  final Color? activeTrackColor;
  final Color? inactiveThumbColor;
  final Color? inactiveTrackColor;
  final WidgetStateProperty<Color?>? thumbColor;
  final WidgetStateProperty<Color?>? trackColor;
  final WidgetStateProperty<Color?>? trackOutlineColor;
  final WidgetStateProperty<Icon?>? thumbIcon;
  final MaterialTapTargetSize? materialTapTargetSize;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    if (appleControlsEnabled) {
      // Зелёный — цвет «включено» у iOS; акцент приложения сюда не идёт:
      // зелёный переключатель на iPhone узнаётся сразу.
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: CupertinoColors.systemGreen,
        focusNode: focusNode,
        autofocus: autofocus,
      );
    }
    return Switch(
      value: value,
      onChanged: onChanged,
      // Прежние экраны передавали и его — сохраняется как было.
      // ignore: deprecated_member_use
      activeColor: activeColor,
      activeThumbColor: activeThumbColor,
      activeTrackColor: activeTrackColor,
      inactiveThumbColor: inactiveThumbColor,
      inactiveTrackColor: inactiveTrackColor,
      thumbColor: thumbColor,
      trackColor: trackColor,
      trackOutlineColor: trackOutlineColor,
      thumbIcon: thumbIcon,
      materialTapTargetSize: materialTapTargetSize,
      focusNode: focusNode,
      autofocus: autofocus,
    );
  }
}

/// Строка с переключателем (настройки): на iPhone — с переключателем Apple,
/// нажатие на всю строку переключает, как в «Настройках» iOS.
class SecretlySwitchListTile extends StatelessWidget {
  const SecretlySwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    if (!appleControlsEnabled) {
      return SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        secondary: secondary,
        contentPadding: contentPadding,
      );
    }
    final toggle = onChanged;
    return MergeSemantics(
      child: ListTile(
        title: title,
        subtitle: subtitle,
        leading: secondary,
        contentPadding: contentPadding,
        enabled: toggle != null,
        onTap: toggle == null ? null : () => toggle(!value),
        trailing: ExcludeFocus(
          child: SecretlySwitch(value: value, onChanged: onChanged),
        ),
      ),
    );
  }
}

/// Крутилка загрузки: на iPhone — системный «лучистый» индикатор Apple, если
/// ход неизвестен. Кольцо с известным ходом (загрузка файла на N %) остаётся
/// кольцом и на iPhone — так iOS показывает загрузки.
class SecretlySpinner extends StatelessWidget {
  const SecretlySpinner({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.valueColor,
    this.strokeWidth,
    this.strokeCap,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final Animation<Color?>? valueColor;
  final double? strokeWidth;
  final StrokeCap? strokeCap;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    if (appleControlsEnabled && value == null) {
      final tint = color ?? valueColor?.value;
      // Без LayoutBuilder: крутилка стоит и в рядах, которые меряют высоту
      // заранее (IntrinsicHeight у кнопок окна), а LayoutBuilder там падает.
      // В маленьком месте (16×16 на кнопке) индикатор ужимается, в большом —
      // не раздувается больше 36, как и прежнее кольцо.
      return Semantics(
        label: semanticsLabel,
        value: semanticsValue,
        // По размеру индикатора, а не на всё доступное место: прежнее кольцо
        // в колонке или в Stack тоже занимало только своё.
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 36, maxHeight: 36),
            child: FittedBox(
              child: CupertinoActivityIndicator(radius: 10, color: tint),
            ),
          ),
        ),
      );
    }
    return CircularProgressIndicator(
      value: value,
      color: color,
      backgroundColor: backgroundColor,
      valueColor: valueColor,
      strokeWidth: strokeWidth,
      strokeCap: strokeCap,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
    );
  }
}

/// Выбор даты и времени барабаном снизу, как в iOS: сверху полоска с
/// «Готово». Тап мимо — без изменений (`null`).
Future<DateTime?> showAppleDateTimePicker(
  BuildContext context, {
  required DateTime initial,
  required DateTime minimum,
  required DateTime maximum,
  required String doneLabel,
  bool useRootNavigator = true,
}) {
  var picked = initial;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (context) {
      final theme = Theme.of(context);
      final dark = theme.brightness == Brightness.dark;
      final bottom = MediaQuery.paddingOf(context).bottom;
      return Material(
        type: MaterialType.transparency,
        child: Container(
          height: 300 + bottom,
          padding: EdgeInsets.only(bottom: bottom),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1C1C1E) : const Color(0xFFF9F9F9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () => Navigator.of(context).pop(picked),
                    child: Text(
                      doneLabel,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                height: 0.5,
                color: dark ? const Color(0x33FFFFFF) : const Color(0x333C3C43),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: theme.brightness,
                    primaryColor: theme.colorScheme.primary,
                  ),
                  child: CupertinoDatePicker(
                    initialDateTime: initial,
                    minimumDate: minimum,
                    maximumDate: maximum,
                    use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                    onDateTimeChanged: (v) => picked = v,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Кнопка, открывающаяся смахиванием строки (список чатов на iPhone).
@immutable
class AppleSwipeAction {
  const AppleSwipeAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
}

/// Смахивание строки, как в «Сообщениях» и «Почте» iOS: влево — кнопки
/// справа ([trailing]), вправо — слева ([leading]). Кнопки раскрываются из-под
/// строки по мере движения пальца; открыта всегда только одна строка; тап по
/// открытой строке или прокрутка списка — закрыть. Те же действия доступны
/// экранному диктору из его меню действий.
class AppleSwipeActions extends StatefulWidget {
  const AppleSwipeActions({
    super.key,
    required this.child,
    this.leading = const <AppleSwipeAction>[],
    this.trailing = const <AppleSwipeAction>[],
  });

  final Widget child;
  final List<AppleSwipeAction> leading;
  final List<AppleSwipeAction> trailing;

  @override
  State<AppleSwipeActions> createState() => _AppleSwipeActionsState();
}

class _AppleSwipeActionsState extends State<AppleSwipeActions>
    with SingleTickerProviderStateMixin {
  /// Открытая сейчас строка — открыть другую значит закрыть эту.
  static _AppleSwipeActionsState? _open;
  static const double _buttonWidth = 74;

  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  ValueListenable<bool>? _scrolling;

  double get _leadWidth => widget.leading.length * _buttonWidth;
  double get _trailWidth => widget.trailing.length * _buttonWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position.isScrollingNotifier;
    if (!identical(next, _scrolling)) {
      _scrolling?.removeListener(_onScroll);
      _scrolling = next;
      _scrolling?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrolling?.removeListener(_onScroll);
    if (identical(_open, this)) _open = null;
    _offset.dispose();
    super.dispose();
  }

  void _onScroll() {
    if ((_scrolling?.value ?? false) && _offset.value != 0) _close();
  }

  void _animateTo(double target) {
    _offset.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Motion.standard,
    );
    if (target != 0) {
      if (!identical(_open, this)) HapticFeedback.selectionClick();
      _open = this;
    } else if (identical(_open, this)) {
      _open = null;
    }
  }

  void _close() => _animateTo(0);

  void _onStart(DragStartDetails _) {
    final other = _open;
    if (other != null && !identical(other, this) && other.mounted) {
      other._close();
    }
    _offset.stop();
  }

  void _onUpdate(DragUpdateDetails d) {
    var next = _offset.value + d.delta.dx;
    final min = -_trailWidth;
    final max = _leadWidth;
    // За краем — с сопротивлением, как резинка у iOS.
    if (next < min) next = min + (next - min) * 0.25;
    if (next > max) next = max + (next - max) * 0.25;
    if (_trailWidth == 0 && next < 0) next = 0;
    if (_leadWidth == 0 && next > 0) next = 0;
    _offset.value = next;
  }

  void _onEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final dx = _offset.value;
    var target = 0.0;
    if (dx < 0 && (dx < -_trailWidth / 2 || v < -500) && v <= 500) {
      target = -_trailWidth;
    } else if (dx > 0 && (dx > _leadWidth / 2 || v > 500) && v >= -500) {
      target = _leadWidth;
    }
    _animateTo(target);
  }

  Widget _button(AppleSwipeAction action) {
    return _SwipeButton(
      action: action,
      width: _buttonWidth,
      onTap: () {
        _close();
        action.onPressed();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.leading, ...widget.trailing];
    return Semantics(
      customSemanticsActions: {
        for (final a in all) CustomSemanticsAction(label: a.label): a.onPressed,
      },
      // Нажатие в любом другом месте экрана закрывает открытую строку —
      // как в iOS.
      child: TapRegion(
        onTapOutside: (_) {
          if (_offset.value != 0) _close();
        },
        child: GestureDetector(
          onHorizontalDragStart: _onStart,
          onHorizontalDragUpdate: _onUpdate,
          onHorizontalDragEnd: _onEnd,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _offset,
              builder: (context, child) {
                final dx = _offset.value;
                // Состав детей Stack НЕ меняется при открытии и закрытии:
                // иначе строка (аватар, живая рамка, эмодзи) пересоздаётся
                // на первом же пикселе смахивания и мигает.
                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      width: dx < 0 ? -dx : 0,
                      // Закрыто — кнопок нет вовсе (и для диктора тоже);
                      // место в Stack при этом остаётся, строка не мигает.
                      child: dx < 0
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final a in widget.trailing)
                                  Expanded(child: _button(a)),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: dx > 0 ? dx : 0,
                      child: dx > 0
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final a in widget.leading)
                                  Expanded(child: _button(a)),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    Transform.translate(
                      key: const ValueKey('apple-swipe-row'),
                      offset: Offset(dx, 0),
                      child: child,
                    ),
                    // Строка открыта: тап по ней закрывает кнопки, а не
                    // открывает чат — как в iOS.
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: dx > 0 ? dx : 0,
                      right: dx < 0 ? -dx : 0,
                      child: IgnorePointer(
                        ignoring: dx == 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _close,
                        ),
                      ),
                    ),
                  ],
                );
              },
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Кнопка под строкой: под пальцем темнеет, как кнопки смахивания iOS;
/// подпись при крупном тексте ужимается, а не обрезается.
class _SwipeButton extends StatefulWidget {
  const _SwipeButton({
    required this.action,
    required this.width,
    required this.onTap,
  });

  final AppleSwipeAction action;
  final double width;
  final VoidCallback onTap;

  @override
  State<_SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<_SwipeButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.action.color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap,
      child: ColoredBox(
        color: _pressed ? Color.lerp(color, Colors.black, 0.22)! : color,
        child: ClipRect(
          child: OverflowBox(
            minWidth: 0,
            maxWidth: widget.width,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.action.icon, color: Colors.white, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        widget.action.label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
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

/// Значки действий. На iPhone — системные iOS, которые человек узнаёт сразу:
/// «Поделиться» — квадрат со стрелкой вверх, «Назад» — уголок, «Ещё» — три
/// точки в ряд. Иначе — тот же значок, что стоял (его передаёт экран).
IconData appleShareIcon(IconData material) =>
    appleControlsEnabled ? CupertinoIcons.share : material;

IconData appleBackIcon(IconData material) =>
    appleControlsEnabled ? CupertinoIcons.back : material;

IconData appleMoreIcon(IconData material) =>
    appleControlsEnabled ? CupertinoIcons.ellipsis : material;
