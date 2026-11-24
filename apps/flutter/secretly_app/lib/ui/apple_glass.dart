// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Стеклянный материал iPhone (Liquid Glass) — один на всё приложение.
///
/// Макет владельца «iPhone · Liquid Glass» (20.11.2026) задаёт панели:
/// полупрозрачная заливка (тёмная тема — белый 8 %, светлая — белый 55 %),
/// светлая кромка сверху и тонкий ободок, скругление 26. Здесь эти числа
/// живут в одном месте, а пользуются ими тема (`Card`, окна, нижние листы),
/// панели настроек и экраны со своими плашками.
///
/// 🔴 ПРОИЗВОДИТЕЛЬНОСТЬ. Панели в прокрутке — БЕЗ `BackdropFilter`: под ними
/// плавный градиентный фон приложения, а размытие плавного градиента даёт
/// тот же градиент. Десяток размытий, пересчитываемых каждый кадр прокрутки,
/// грел бы телефон ради невидимой разницы. Размытие оставлено только там,
/// где под стеклом действительно разное содержимое и оно не прокручивается:
/// окна подтверждения и нижние листы ([AppleGlassBlur]).
///
/// Всё это — только на iPhone ([appleGlassPanelsEnabled]). Выключатель
/// [kAppleGlassPanels] возвращает прежний вид одной строкой.
library;

import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'widgets/app_background.dart';
import 'widgets/island_backdrop.dart';

/// Стеклянные панели на iPhone (карточки, группы настроек, окна, листы).
const bool kAppleGlassPanels = true;

bool get appleGlassPanelsEnabled =>
    kAppleGlassPanels && defaultTargetPlatform == TargetPlatform.iOS;

/// Числа стекла из макета.
class AppleGlass {
  const AppleGlass._();

  /// Скругление панели.
  static const double radius = 26;

  /// Скругление окна подтверждения и нижнего листа.
  static const double sheetRadius = 30;

  /// Заливка панели поверх фона страницы.
  /// Светлая тема — почти белая, как группы настроек iOS: полупрозрачная
  /// (0x8C) над светло-серым фоном давала серую «мутную» карточку
  /// (решение владельца 20.11.2026: «светлая тема как грязь»).
  static Color fill(bool dark) =>
      dark ? const Color(0x14FFFFFF) : const Color(0xF5FFFFFF);

  /// Заливка окна и листа: под ними — размытое содержимое, а не ровный фон,
  /// поэтому плотнее, иначе текст окна теряется на пёстром экране.
  static Color sheetFill(bool dark) =>
      dark ? const Color(0xB81C1C1F) : const Color(0xC7F5F5F7);

  /// Светлая кромка сверху.
  static Color highlight(bool dark) =>
      dark ? const Color(0x38FFFFFF) : const Color(0xF2FFFFFF);

  /// Тонкий ободок по краю.
  static Color rim(bool dark) =>
      dark ? const Color(0x1FFFFFFF) : const Color(0xB3FFFFFF);

  /// Разделитель строк внутри панели (iOS: от текста, а не от края).
  static Color separator(bool dark) =>
      dark ? const Color(0x1FFFFFFF) : const Color(0x1F3C3C43);

  /// Вторичный текст iOS (`secondaryLabel`).
  static Color secondaryLabel(bool dark) =>
      dark ? const Color(0x99EBEBF5) : const Color(0x993C3C43);

  /// Подсветка нажатой строки.
  static Color pressed(bool dark) =>
      dark ? const Color(0x1FFFFFFF) : const Color(0x14000000);

  /// Тень панели в светлой теме (в тёмной её не видно — не рисуем).
  /// Едва заметная и нейтральная: прежняя сине-серая (8 %, 20 px, сдвиг 6)
  /// ложилась грязным ореолом под каждой карточкой.
  static List<BoxShadow> shadow(bool dark) => dark
      ? const <BoxShadow>[]
      : const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ];
}

/// Форма стеклянной панели: скругление + тонкий ободок + светлая кромка
/// сверху, гаснущая к бокам. Годится для `Card`, окон и листов через тему,
/// поэтому все карточки приложения становятся стеклом без правки экранов.
class AppleGlassBorder extends OutlinedBorder {
  const AppleGlassBorder({
    this.radius = AppleGlass.radius,
    this.dark = true,
    this.topOnly = false,
    super.side = BorderSide.none,
  });

  final double radius;
  final bool dark;

  /// Скруглены только верхние углы (нижний лист у края экрана).
  final bool topOnly;

  BorderRadius get _borderRadius => topOnly
      ? BorderRadius.vertical(top: Radius.circular(radius))
      : BorderRadius.circular(radius);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_borderRadius.toRRect(rect).deflate(0.5));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_borderRadius.toRRect(rect));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final rr = _borderRadius.toRRect(rect);
    canvas.drawRRect(
      rr.deflate(0.25),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = AppleGlass.rim(dark),
    );
    final fade = rect.height <= 0
        ? 0.5
        : (radius / rect.height).clamp(0.05, 0.5).toDouble();
    canvas.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppleGlass.highlight(dark), const Color(0x00FFFFFF)],
          stops: [0, fade],
        ).createShader(rect),
    );
  }

  @override
  ShapeBorder scale(double t) => AppleGlassBorder(
    radius: radius * t,
    dark: dark,
    topOnly: topOnly,
    side: side.scale(t),
  );

  @override
  AppleGlassBorder copyWith({BorderSide? side}) => AppleGlassBorder(
    radius: radius,
    dark: dark,
    topOnly: topOnly,
    side: side ?? this.side,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is AppleGlassBorder) {
      return AppleGlassBorder(
        radius: lerpDouble(a.radius, radius, t)!,
        dark: t < 0.5 ? a.dark : dark,
        topOnly: topOnly,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  bool operator ==(Object other) =>
      other is AppleGlassBorder &&
      other.radius == radius &&
      other.dark == dark &&
      other.topOnly == topOnly &&
      other.side == side;

  @override
  int get hashCode => Object.hash(radius, dark, topOnly, side);
}

/// Включены ли прозрачные плашки (настройка «Прозрачные плашки»).
bool get translucentCardsOn => PanelPrefs.translucentCards.value;

/// Насколько плотная плашка светлее фона страницы: доля пути от цвета фона
/// к поверхности темы. Свой профиль был 0,5 (макет «Profile Redesign»).
/// Владелец 23.11.2026: «везде чуть-чуть светлее, чем на странице профиля;
/// главное — чтобы плашка не сильно выделялась, но была видна».
const double kOpaquePanelLift = 0.62;

/// Цвет плотной плашки («Прозрачные плашки» выключены) — ОДИН на всё
/// приложение: настройки, профили, комнаты, окна. Тёмная тема — между фоном
/// страницы [page] и поверхностью темы [surface] ([kOpaquePanelLift]),
/// полностью непрозрачный (прежний цвет карточек темы был плотным на 88 % и
/// на разных фонах выглядел по-разному — светлее в настройках, чем в
/// профиле). Светлая тема — белый, как группы iOS и карточки профиля.
Color opaquePanelColorFor({
  required bool dark,
  required Color page,
  required Color surface,
}) {
  if (!dark) return Colors.white;
  final c = Color.lerp(page, surface, kOpaquePanelLift) ?? surface;
  return c.withValues(alpha: 1);
}

/// Плотная заливка плашки, когда прозрачность выключена: [opaquePanelColorFor]
/// от настоящего фона страницы (с фоном из «Оформления» — от него).
///
/// Внутри окна или нижнего листа фон — сам лист (он светлее страницы):
/// плашка там на ступень светлее листа, как группы в листах iOS, а не
/// тёмная «дыра» цвета страницы.
Color opaqueCardColor(BuildContext context) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  final route = ModalRoute.of(context);
  if (route is PopupRoute) {
    if (!dark) return Colors.white;
    final page = AppBackground.scrimColorOf(context);
    final sheet = route is ModalBottomSheetRoute
        ? theme.bottomSheetTheme.backgroundColor
        : theme.dialogTheme.backgroundColor;
    final under = Color.alphaBlend(sheet ?? theme.colorScheme.surface, page);
    return Color.alphaBlend(
      Colors.white.withValues(alpha: 0.06),
      under,
    ).withValues(alpha: 1);
  }
  return opaquePanelColorFor(
    dark: theme.brightness == Brightness.dark,
    page: AppBackground.scrimColorOf(context),
    surface: theme.colorScheme.surface,
  );
}

/// Скругление плотной плашки — как у карточек своего профиля (18). Явно
/// заданное экраном другое скругление сохраняется.
double opaqueCardRadius(double radius) =>
    radius == AppleGlass.radius ? 18 : radius;

/// Вид любой плашки-панели: прозрачная (заливка 8 %, тонкая кромка) или
/// плотная, как карточки своего профиля — по настройке «Прозрачные плашки».
ShapeDecoration panelDecoration(
  BuildContext context, {
  double radius = AppleGlass.radius,
  List<BoxShadow>? shadows,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (!translucentCardsOn) {
    return ShapeDecoration(
      color: opaqueCardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(opaqueCardRadius(radius)),
      ),
    );
  }
  return ShapeDecoration(
    color: AppleGlass.fill(dark),
    shadows: shadows ?? AppleGlass.shadow(dark),
    shape: AppleGlassBorder(radius: radius, dark: dark),
  );
}

/// Оформление стеклянной панели для `Container`/`DecoratedBox` — для экранов,
/// которые рисуют плашку сами, а не через `Card`.
ShapeDecoration appleGlassDecoration(
  BuildContext context, {
  double radius = AppleGlass.radius,
}) {
  return panelDecoration(context, radius: radius);
}

/// Заливка плашки, заданная экраном вручную: на iPhone — стекло, на
/// остальных платформах — прежняя [fallback].
///
/// [androidToo] — `false` для плашек ПОВЕРХ ленты (на Android прозрачная там
/// не читалась бы): на Android остаётся прежняя [fallback].
Color appleGlassFillOr(
  BuildContext context,
  Color fallback, {
  bool androidToo = true,
}) =>
    !(androidToo ? panelCardsEnabled : appleGlassPanelsEnabled)
    ? fallback
    : translucentCardsOn
    ? AppleGlass.fill(Theme.of(context).brightness == Brightness.dark)
    : opaqueCardColor(context);

/// Оформление плашки, заданное экраном вручную: на iPhone — стекло
/// с тем же скруглением, на остальных платформах — прежнее [fallback].
/// Android: блоки страниц и карточки — те же панели, что в настройках
/// (23.11.2026, владелец: «сделай такие плашки везде — на страницах профилей
/// и т. д.»). Прозрачная заливка 8 %, тонкая кромка, без размытия — дёшево.
/// `false` — на Android прежние непрозрачные карточки.
const bool kAndroidCardsAsPanels = true;

/// Панели вместо карточек: iPhone — всегда, Android — по [kAndroidCardsAsPanels].
bool get panelCardsEnabled =>
    appleGlassPanelsEnabled ||
    (kAndroidCardsAsPanels && defaultTargetPlatform == TargetPlatform.android);

/// [androidToo] — `false` для того, что лежит ПОВЕРХ пёстрого содержимого
/// (подсказки упоминаний над лентой, карточка замка): прозрачная панель там
/// не читалась бы — на Android остаётся прежняя плотная подложка.
Decoration appleGlassDecorationOr(
  BuildContext context,
  Decoration fallback, {
  double? radius,
  bool androidToo = true,
}) {
  if (!(androidToo ? panelCardsEnabled : appleGlassPanelsEnabled)) {
    return fallback;
  }
  var r = radius;
  List<BoxShadow>? shadows;
  if (fallback is BoxDecoration) {
    final br = fallback.borderRadius;
    if (r == null && br != null) {
      r = br.resolve(Directionality.maybeOf(context)).topLeft.x;
    }
    // Своя тень экрана (например, глубокая у карточки замка) сохраняется.
    shadows = fallback.boxShadow;
  }
  return panelDecoration(
    context,
    radius: r ?? AppleGlass.radius,
    shadows: shadows,
  );
}

/// Стеклянная панель: полупрозрачная заливка, светлая кромка, скругление.
class AppleGlassPanel extends StatelessWidget {
  const AppleGlassPanel({
    super.key,
    required this.child,
    this.radius = AppleGlass.radius,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (!translucentCardsOn) {
      // «Прозрачные плашки» выключены — плотная карточка, как в профиле.
      final r = opaqueCardRadius(radius);
      return ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: ColoredBox(
          color: opaqueCardColor(context),
          child: Padding(padding: padding, child: child),
        ),
      );
    }
    final shape = AppleGlassBorder(radius: radius, dark: dark);
    final br = BorderRadius.circular(radius);
    // Заливка и тень — сзади, кромка — один раз спереди (поверх подсветки
    // нажатой строки). Обрезка — дешёвый ClipRRect, а не ClipPath.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppleGlass.fill(dark),
        borderRadius: br,
        boxShadow: AppleGlass.shadow(dark),
      ),
      child: ClipRRect(
        borderRadius: br,
        child: DecoratedBox(
          // Кромка поверх содержимого: подсветка нажатой строки её не прячет.
          position: DecorationPosition.foreground,
          decoration: ShapeDecoration(shape: shape),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Размытие под окном или листом. Окно не прокручивается и живёт недолго,
/// поэтому одно размытие здесь стоит дёшево, а без него текст окна
/// смешивался бы с пёстрым экраном под ним.
class AppleGlassBlur extends StatelessWidget {
  const AppleGlassBlur({
    super.key,
    required this.child,
    required this.borderRadius,
    this.sigma = 30,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}

/// Заливка листа или окна, заданная экраном вручную: на iPhone — плотное
/// стекло ([AppleGlass.sheetFill]), на остальных платформах — [fallback].
Color appleSheetFillOr(BuildContext context, Color fallback) =>
    appleGlassPanelsEnabled
    ? AppleGlass.sheetFill(
        Theme.of(context).brightness == Brightness.dark,
      ).withValues(alpha: 0.97)
    : fallback;

/// Форма листа, заданная экраном вручную: на iPhone — стекло с кромкой и
/// скруглением сверху, на остальных платформах — [fallback].
ShapeBorder? appleSheetShapeOr(BuildContext context, ShapeBorder? fallback) =>
    appleGlassPanelsEnabled
    ? AppleGlassBorder(
        radius: AppleGlass.sheetRadius,
        dark: Theme.of(context).brightness == Brightness.dark,
        topOnly: true,
      )
    : fallback;

/// Заливка поверхности, которая УЖЕ лежит на размытии (меню, всплывающие
/// плашки): на iPhone — полупрозрачное стекло iOS, сквозь которое видно
/// размытое содержимое; на остальных платформах — [fallback].
Color appleBlurredFillOr(BuildContext context, Color fallback) =>
    appleGlassPanelsEnabled
    ? AppleGlass.sheetFill(Theme.of(context).brightness == Brightness.dark)
    : fallback;

/// Цвет значка, заданный экраном вручную: на iPhone — цвет текста iOS
/// (белый в тёмной теме, чёрный в светлой), иначе прежний [fallback].
Color appleLabelColorOr(BuildContext context, Color fallback) =>
    appleGlassPanelsEnabled
    ? (Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black)
    : fallback;

/// Индикатор вкладки iOS: «пилюля» с отступами внутри вкладки (как
/// выбранный сегмент `UISegmentedControl`), а не подчёркивание Material.
class ApplePillTabIndicator extends Decoration {
  const ApplePillTabIndicator({required this.dark});

  final bool dark;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _ApplePillPainter(dark);
}

class _ApplePillPainter extends BoxPainter {
  _ApplePillPainter(this.dark);

  final bool dark;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = (offset & size).deflate(5);
    final h = rect.height.clamp(0.0, 32.0);
    final pill = Rect.fromCenter(
      center: rect.center,
      width: rect.width,
      height: h,
    );
    final rrect = RRect.fromRectAndRadius(pill, Radius.circular(h / 2));
    if (!dark) {
      canvas.drawRRect(
        rrect.shift(const Offset(0, 1.5)),
        Paint()
          ..color = const Color(0x1A000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawRRect(
      rrect,
      Paint()..color = dark ? const Color(0xFF48484A) : Colors.white,
    );
  }
}
