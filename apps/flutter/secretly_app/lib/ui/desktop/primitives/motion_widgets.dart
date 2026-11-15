// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// КИРПИЧИ ДВИЖЕНИЯ ПК (05.10.2026) — правила в `design/motion.dart`.
///
/// Всё здесь стоит на [DMotion] и само гаснет при «уменьшить движение».
/// Новых зависимостей нет: `animations` уже в проекте ради [PageTransitionSwitcher].
library;

import 'package:animations/animations.dart';
import 'package:flutter/gestures.dart' show GestureBinding;
import 'package:flutter/material.dart';

import '../design/motion.dart';

/// Как значок превращается в другой.
enum DMorphStyle {
  /// Старый сжимается и гаснет, новый вырастает из того же центра.
  scale,

  /// То же с четвертью оборота — для переключателей с действием: микрофон,
  /// камера, отправка ↔ запись. Поворот говорит «это другое состояние той же
  /// кнопки», а не «здесь теперь другая кнопка».
  spin,

  /// Только перетекание прозрачности — для значков, которые различаются
  /// заливкой (контур ↔ залитый): масштаб там читается подёргиванием.
  fade,
}

/// Значок, который при смене ПРЕВРАЩАЕТСЯ, а не подменяется.
///
/// Цвет при этом тоже не прыгает: тот же значок другим цветом (наведение,
/// «выбрано») перетекает за [DMotion.fast].
class DMorphIcon extends StatelessWidget {
  const DMorphIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.style = DMorphStyle.scale,
    this.semanticLabel,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final DMorphStyle style;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final duration = DMotion.of(context, DMotion.morph);
    final currentKey = ValueKey<IconData>(icon);
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: duration * 0.7,
      switchInCurve: DMotion.decelerate,
      switchOutCurve: DMotion.accelerate,
      layoutBuilder: _centerStack,
      transitionBuilder: (child, animation) {
        final incoming = child.key == currentKey;
        // Уходящий значок диктору не нужен — он читает только нынешний.
        return ExcludeSemantics(
          excluding: !incoming,
          child: _morph(child, animation, style, incoming: incoming),
        );
      },
      child: _ColorTweenIcon(
        key: currentKey,
        icon: icon,
        size: size,
        color: color,
        semanticLabel: semanticLabel,
      ),
    );
  }

  static Widget _morph(
    Widget child,
    Animation<double> animation,
    DMorphStyle style, {
    required bool incoming,
  }) {
    final fade = FadeTransition(opacity: animation, child: child);
    if (style == DMorphStyle.fade) return fade;
    final scaled = ScaleTransition(
      scale: Tween<double>(begin: 0.55, end: 1).animate(animation),
      child: fade,
    );
    if (style == DMorphStyle.scale) return scaled;
    // Входящий доворачивается с −¼ до нуля, уходящий уезжает дальше по
    // кругу: оба крутятся в одну сторону, как одна деталь.
    return RotationTransition(
      turns: Tween<double>(
        begin: incoming ? -0.25 : 0.25,
        end: 0,
      ).animate(animation),
      child: scaled,
    );
  }
}

class _ColorTweenIcon extends StatelessWidget {
  const _ColorTweenIcon({
    super.key,
    required this.icon,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final target = color;
    if (target == null) {
      return Icon(icon, size: size, semanticLabel: semanticLabel);
    }
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: DMotion.of(context, DMotion.fast),
      curve: DMotion.standard,
      builder: (context, value, _) => Icon(
        icon,
        size: size,
        color: value ?? target,
        semanticLabel: semanticLabel,
      ),
    );
  }
}

Widget _centerStack(Widget? current, List<Widget> previous) => Stack(
  alignment: Alignment.center,
  children: <Widget>[...previous, if (current != null) current],
);

/// Подпись, которая при смене перетекает: старая уходит вверх и гаснет,
/// новая поднимается снизу. Ширина при этом меняется плавно — соседние
/// кнопки не прыгают.
class DMorphText extends StatelessWidget {
  const DMorphText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.alignment = Alignment.centerLeft,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final duration = DMotion.of(context, DMotion.morph);
    final currentKey = ValueKey<String>(text);
    return AnimatedSize(
      duration: duration,
      curve: DMotion.standard,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: duration,
        reverseDuration: duration * 0.6,
        switchInCurve: DMotion.decelerate,
        switchOutCurve: DMotion.accelerate,
        layoutBuilder: (current, previous) => Stack(
          alignment: alignment,
          children: <Widget>[...previous, if (current != null) current],
        ),
        transitionBuilder: (child, animation) {
          final incoming = child.key == currentKey;
          // Уходящая подпись диктору не нужна — он читает только нынешнюю.
          return ExcludeSemantics(
            excluding: !incoming,
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, incoming ? 0.35 : -0.35),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
          );
        },
        child: Text(
          text,
          key: currentKey,
          style: style,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        ),
      ),
    );
  }
}

/// Вжимается под нажатием и мягко отпускается.
///
/// [pressed] даёт тот, кто знает о нажатии (обычно `HoverListener`). Вниз —
/// за [DMotion.press], назад — за [DMotion.release]: так кнопка ощущается
/// кнопкой. Масштаб, а не размер: соседей не толкает и считается дёшево.
class DPressScale extends StatelessWidget {
  const DPressScale({
    super.key,
    required this.pressed,
    required this.child,
    this.scale = 0.96,
    this.hovered = false,
    this.hoverScale = 1.0,
  });

  final bool pressed;
  final bool hovered;
  final double scale;

  /// Подрастание под курсором; 1 — не расти (по умолчанию: большие кнопки
  /// под курсором не растут, растут только плитки рейки).
  final double hoverScale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final target = pressed ? scale : (hovered ? hoverScale : 1.0);
    return AnimatedScale(
      scale: target,
      duration: DMotion.of(
        context,
        pressed ? DMotion.press : DMotion.release,
      ),
      curve: pressed ? DMotion.standard : DMotion.decelerate,
      child: child,
    );
  }
}

/// Проявляется при первом показе: поднимается на [offset] и проявляется.
///
/// Только при создании — перестройка родителя анимацию не повторяет. [delay]
/// — для лесенки (карточки одной страницы по очереди, с шагом 30–40 мс).
class DAppear extends StatefulWidget {
  const DAppear({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = DMotion.page,
    this.offset = const Offset(0, 10),
    this.fromScale = 1.0,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double fromScale;

  /// Откуда растёт при [fromScale] < 1: выпадающее — от своего поля.
  final Alignment alignment;

  @override
  State<DAppear> createState() => _DAppearState();
}

class _DAppearState extends State<DAppear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (DMotion.reduced(context)) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        // 🔴 Строение одинаково в каждом кадре и после конца: смена набора
        // обёрток пересоздала бы всё, что внутри (ленту, поля, прокрутку).
        final t = DMotion.decelerate.transform(_c.value);
        final scale = widget.fromScale + (1 - widget.fromScale) * t;
        return Opacity(
          // Проявление быстрее подъёма: сначала видно, потом садится.
          opacity: Curves.easeOut.transform((_c.value * 1.6).clamp(0.0, 1.0)),
          child: Transform.translate(
            offset: widget.offset * (1 - t),
            child: Transform.scale(
              scale: scale,
              alignment: widget.alignment,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Смена страницы «через затухание»: старая быстро гаснет, новая проявляется
/// и чуть подрастает до своего размера. Обе сразу не видны — нет каши из
/// двух экранов, которую давал простой перекрёстный переход.
///
/// Ключ [child] решает, что это «другая страница».
class DPageSwitcher extends StatelessWidget {
  const DPageSwitcher({
    super.key,
    required this.child,
    this.duration = DMotion.page,
    this.fromScale = 0.985,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Duration duration;
  final double fromScale;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return PageTransitionSwitcher(
      duration: DMotion.of(context, duration),
      layoutBuilder: (entries) => Stack(
        alignment: alignment,
        fit: StackFit.passthrough,
        children: entries,
      ),
      transitionBuilder: (child, primary, secondary) => _FadeThrough(
        primary: primary,
        secondary: secondary,
        fromScale: fromScale,
        alignment: alignment,
        child: child,
      ),
      child: child,
    );
  }
}

class _FadeThrough extends StatelessWidget {
  const _FadeThrough({
    required this.primary,
    required this.secondary,
    required this.fromScale,
    required this.alignment,
    required this.child,
  });

  final Animation<double> primary;
  final Animation<double> secondary;
  final double fromScale;
  final Alignment alignment;
  final Widget child;

  // Уходящая гаснет в первые 35 % перехода, входящая проявляется после.
  static const Interval _out = Interval(0, 0.35, curve: DMotion.accelerate);
  static const Interval _in = Interval(0.3, 1, curve: DMotion.decelerate);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[primary, secondary]),
      child: child,
      builder: (context, child) {
        // Строение постоянно (см. [DAppear]): страница не пересоздаётся в
        // последнем кадре перехода.
        final p = primary.value;
        final s = secondary.value;
        final opacity = _in.transform(p) * (1 - _out.transform(s));
        final scale = fromScale + (1 - fromScale) * DMotion.decelerate.transform(p);
        return IgnorePointer(
          // Уходящую страницу уже не нажать.
          ignoring: s > 0,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              alignment: alignment,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Сменяемое содержимое одного места: перетекание с небольшим сдвигом.
///
/// Для полос, которые меняют вид целиком (поле ввода ↔ полоса записи, шапка
/// ↔ полоса выбора): старое уезжает на [offset] вверх и гаснет, новое
/// приезжает снизу. Высота меняется плавно.
class DSwapSwitcher extends StatelessWidget {
  const DSwapSwitcher({
    super.key,
    required this.child,
    this.offset = 0.25,
    this.duration = DMotion.medium,
    this.alignment = Alignment.center,
    this.animateSize = true,
  });

  final Widget child;
  final double offset;
  final Duration duration;
  final Alignment alignment;
  final bool animateSize;

  @override
  Widget build(BuildContext context) {
    final d = DMotion.of(context, duration);
    final currentKey = child.key;
    final switcher = AnimatedSwitcher(
      duration: d,
      reverseDuration: d * 0.6,
      switchInCurve: DMotion.decelerate,
      switchOutCurve: DMotion.accelerate,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: <Widget>[...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == currentKey;
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, incoming ? offset : -offset),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
    if (!animateSize) return switcher;
    return AnimatedSize(
      duration: d,
      curve: DMotion.standard,
      alignment: Alignment.bottomCenter,
      child: switcher,
    );
  }
}

/// Раскрывается и сворачивается: высота плавно, содержимое проявляется.
///
/// [open] — показано ли. Свёрнутое не занимает места и не ловит нажатий.
class DExpand extends StatelessWidget {
  const DExpand({
    super.key,
    required this.open,
    required this.child,
    this.duration = DMotion.medium,
    this.alignment = Alignment.topCenter,
  });

  final bool open;
  final Widget child;
  final Duration duration;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final d = DMotion.of(context, duration);
    return AnimatedSize(
      duration: d,
      curve: DMotion.standard,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: d,
        reverseDuration: d * 0.6,
        switchInCurve: DMotion.decelerate,
        switchOutCurve: DMotion.accelerate,
        layoutBuilder: (current, previous) => Stack(
          alignment: alignment,
          children: <Widget>[...previous, if (current != null) current],
        ),
        child: open
            ? KeyedSubtree(key: const ValueKey<bool>(true), child: child)
            : const SizedBox(key: ValueKey<bool>(false), width: double.infinity),
      ),
    );
  }
}

/// Карточка всплывающего (меню, карточка у кнопки, окно) — по анимации
/// маршрута: вход растёт от [alignment] с [fromScale] и проявляется, уход
/// быстрее и короче.
class DPopTransition extends StatelessWidget {
  const DPopTransition({
    super.key,
    required this.animation,
    required this.child,
    this.alignment = Alignment.center,
    this.fromScale = 0.94,
    this.fromOffset = Offset.zero,
  });

  final Animation<double> animation;
  final Widget child;
  final Alignment alignment;
  final double fromScale;

  /// Сдвиг в начале входа, в логических точках (окно поднимается снизу на
  /// несколько точек — так оно «приходит», а не «включается»).
  final Offset fromOffset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        // Строение постоянно (см. [DAppear]): поля окна не теряют фокус и
        // набранное в последнем кадре входа.
        final t = DMotion.eased(animation);
        // Прозрачность бежит впереди масштаба: к середине входа карточка уже
        // видна целиком и только досаживается.
        final opacity = Curves.easeOut.transform(
          (animation.value * 1.8).clamp(0.0, 1.0),
        );
        final leaving = animation.status == AnimationStatus.reverse;
        return Opacity(
          opacity: leaving ? t : opacity,
          child: Transform.translate(
            offset: fromOffset * (1 - t),
            child: Transform.scale(
              scale: fromScale + (1 - fromScale) * t,
              alignment: alignment,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Маршрут окна или всплывающего ПК: вход и уход разной длины.
///
/// `showGeneralDialog` даёт одну длительность на оба направления, а уход у
/// нас короче входа (см. правило 1 в `motion.dart`).
class DesktopOverlayRoute<T> extends RawDialogRoute<T> {
  DesktopOverlayRoute({
    required super.pageBuilder,
    super.barrierDismissible = true,
    super.barrierLabel,
    super.barrierColor = const Color(0x00000000),
    super.transitionDuration = DMotion.modalIn,
    Duration reverseTransitionDuration = DMotion.modalOut,
    super.transitionBuilder,
    super.settings,
  }) : _reverse = reverseTransitionDuration;

  final Duration _reverse;

  @override
  Duration get reverseTransitionDuration => _reverse;
}

/// Показать окно или всплывающее маршрутом [DesktopOverlayRoute].
///
/// Замена `showGeneralDialog`: те же параметры, плюс своя длительность ухода.
/// При «уменьшить движение» обе длительности нулевые.
Future<T?> showDesktopOverlay<T>({
  required BuildContext context,
  required RoutePageBuilder pageBuilder,
  bool barrierDismissible = true,
  String? barrierLabel,
  Color barrierColor = const Color(0x00000000),
  Duration transitionDuration = DMotion.modalIn,
  Duration reverseTransitionDuration = DMotion.modalOut,
  RouteTransitionsBuilder? transitionBuilder,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  final reduced = DMotion.reduced(context);
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    DesktopOverlayRoute<T>(
      pageBuilder: pageBuilder,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: barrierColor,
      transitionDuration: reduced ? Duration.zero : transitionDuration,
      reverseTransitionDuration:
          reduced ? Duration.zero : reverseTransitionDuration,
      transitionBuilder: transitionBuilder,
      settings: routeSettings,
    ),
  );
}

/// Общая для группы пунктов подложка выбранного, которая ПЕРЕЕЗЖАЕТ к
/// новому выбору (05.10.2026).
///
/// Пункты помечают себя [DSelectionTarget] со своим [id]; группа после
/// раскладки находит выбранный и ставит под него подложку [decoration],
/// а при смене выбора ведёт её по кривой скольжения. Пока подложка не
/// измерена (первый кадр), пункт рисует выделение сам —
/// [DSelectionGroup.slides] у него `false`, и вспышки нет.
class DSelectionGroup extends StatefulWidget {
  const DSelectionGroup({
    super.key,
    required this.selected,
    required this.decoration,
    required this.child,
  });

  /// [DSelectionTarget.id] выбранного пункта; `null` — ничего не выбрано.
  final Object? selected;
  final Decoration decoration;
  final Widget child;

  /// Рисует ли группа подложку сама — тогда пункту своё выделение не нужно.
  static bool slides(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SelectionScope>()?.measured ??
      false;

  @override
  State<DSelectionGroup> createState() => _DSelectionGroupState();
}

class _DSelectionGroupState extends State<DSelectionGroup> {
  final GlobalKey _stackKey = GlobalKey();
  final Map<Object, GlobalKey> _targets = <Object, GlobalKey>{};
  Rect? _rect;

  GlobalKey _keyFor(Object id) =>
      _targets.putIfAbsent(id, () => GlobalKey(debugLabel: 'sel:$id'));

  void _measure(Duration _) {
    if (!mounted) return;
    final id = widget.selected;
    Rect? next;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final target = id == null
        ? null
        : _targets[id]?.currentContext?.findRenderObject() as RenderBox?;
    if (stack != null && stack.hasSize && target != null && target.hasSize) {
      next =
          target.localToGlobal(Offset.zero, ancestor: stack) & target.size;
    }
    final old = _rect;
    final same =
        (old == null && next == null) ||
        (old != null &&
            next != null &&
            (old.left - next.left).abs() < 0.5 &&
            (old.top - next.top).abs() < 0.5 &&
            (old.width - next.width).abs() < 0.5 &&
            (old.height - next.height).abs() < 0.5);
    if (!same) setState(() => _rect = next);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    final rect = _rect;
    return _SelectionScope(
      keyFor: _keyFor,
      measured: rect != null,
      child: Stack(
        key: _stackKey,
        children: [
          if (rect != null)
            AnimatedPositioned(
              duration: DMotion.of(context, DMotion.glide),
              curve: DMotion.glideCurve,
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: DecoratedBox(decoration: widget.decoration),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _SelectionScope extends InheritedWidget {
  const _SelectionScope({
    required this.keyFor,
    required this.measured,
    required super.child,
  });

  final GlobalKey Function(Object id) keyFor;
  final bool measured;

  @override
  bool updateShouldNotify(_SelectionScope old) => old.measured != measured;
}

/// Пункт группы [DSelectionGroup]: по нему группа меряет место подложки.
class DSelectionTarget extends StatelessWidget {
  const DSelectionTarget({super.key, required this.id, required this.child});

  final Object id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_SelectionScope>();
    if (scope == null) return child;
    return KeyedSubtree(key: scope.keyFor(id), child: child);
  }
}

/// Значок-«пузырёк» (счётчик, отметка), который ВСПЛЫВАЕТ при появлении и
/// сжимается при уходе (05.10.2026).
///
/// Ключ [child] решает, «тот же ли это значок»: у счётчика ключ постоянный
/// (число внутри перекатывается само — [DMorphText]), а при нуле на его
/// место ставится пустой ключ — и счётчик уходит. [animateSize] — сдвигать
/// ли соседей плавно (строка списка), а не рывком.
class DPopSwitcher extends StatelessWidget {
  const DPopSwitcher({
    super.key,
    required this.child,
    this.animateSize = false,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final bool animateSize;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final inD = DMotion.of(context, DMotion.popIn);
    final switcher = AnimatedSwitcher(
      duration: inD,
      reverseDuration: DMotion.of(context, DMotion.popOut),
      switchInCurve: DMotion.decelerate,
      switchOutCurve: DMotion.accelerate,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: <Widget>[...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.4, end: 1).animate(animation),
          alignment: alignment,
          child: child,
        ),
      ),
      child: child,
    );
    if (!animateSize) return switcher;
    return AnimatedSize(
      duration: inD,
      curve: DMotion.standard,
      alignment: alignment,
      child: switcher,
    );
  }
}

/// Где человек нажал в последний раз — в координатах окна (05.10.2026).
///
/// Окна просмотра (фото, видео, документ, набор наклеек) раскрываются ИЗ
/// этой точки: открыл миниатюру — картинка выросла из неё. Это не переход
/// «миниатюра → окно» в чистом виде (для него пришлось бы тащить место
/// миниатюры через три слоя), но глаз читает его так же: окно пришло оттуда,
/// куда смотрели.
class DPointerMemory {
  DPointerMemory._();

  static Offset? lastDown;
  static bool _installed = false;

  /// Один раз при запуске ПК (`main_desktop.dart`).
  static void install() {
    if (_installed) return;
    _installed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
      if (event is PointerDownEvent) lastDown = event.position;
    });
  }
}

/// Окно, которое раскрывается из точки [origin] (обычно
/// [DPointerMemory.lastDown]) и уходит обратно в неё — быстрее, чем пришло.
class DZoomFromPoint extends StatelessWidget {
  const DZoomFromPoint({
    super.key,
    required this.animation,
    required this.child,
    this.origin,
    this.fromScale = 0.9,
  });

  final Animation<double> animation;
  final Widget child;
  final Offset? origin;
  final double fromScale;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final o = origin;
    final alignment = (o == null || size.isEmpty)
        ? Alignment.center
        : Alignment(
            ((o.dx / size.width) * 2 - 1).clamp(-1.0, 1.0),
            ((o.dy / size.height) * 2 - 1).clamp(-1.0, 1.0),
          );
    return DPopTransition(
      animation: animation,
      alignment: alignment,
      fromScale: fromScale,
      child: child,
    );
  }
}
