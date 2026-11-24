// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Система движения страниц профиля (макет «Profile Motion», 21.11.2026) —
/// одна на свой профиль, профиль собеседника и комнату.
///
/// Карта движений макета:
/// * потянуть вниз — аватар растёт за пальцем с сопротивлением резинки
///   (`d·(1 − 1/(x·0,55/d + 1))`, d = 520), узор расходится;
/// * порог 45 % — фото раскрывается во всю ширину сразу, под пальцем,
///   пружиной k320 c26, отклик «medium»;
/// * тянуть раскрытое — фото тянется по высоте (резинка, d = 600), отпустил
///   — возвращается;
/// * свайп вверх по фото — через 50 px сворачивается пружиной, отклик
///   «light»;
/// * прокрутка 0–170 px — аватар уходит под шапку, узор стягивается, фон
///   движется вдвое медленнее (параллакс ×0,5);
/// * имя причаливает к шапке и становится её заголовком (1 → 0,8).
///
/// Кнопки и раскладка экранов не меняются — только движение.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../storage/file_exists_cache.dart';
import '../apple_glass.dart'
    show opaquePanelColorFor, panelCardsEnabled, translucentCardsOn;
import '../premium/cosmetic_animation_scope.dart';
import '../premium/live_covers.dart' show CoverAvatarGeometry;
import '../thermal_guard.dart';
import '../widgets/app_background.dart';
import '../widgets/avatar_initials.dart';
import '../widgets/frosted_header_island.dart';
import 'key_fingerprint.dart';
import 'pattern_cover.dart';

/// Пружина раскрытия и сворачивания фото (k320 c26, масса 1).
const SpringDescription kProfileSpring = SpringDescription(
  mass: 1,
  stiffness: 320,
  damping: 26,
);

/// Сворачивание в круг — быстрее и без перелёта (критическое затухание):
/// хвост пружины не держит страницу (жалоба 22.11.2026: «после уменьшения
/// страница листается не сразу»).
const SpringDescription kProfileCollapseSpring = SpringDescription(
  mass: 1,
  stiffness: 520,
  damping: 46,
);

/// Сопротивление натяжения (макет): палец прошёл [raw] — аватар на столько.
const double kProfilePullRubber = 520;

/// Растяжение раскрытого фото.
const double kProfileStretchRubber = 600;

/// Свайп вверх по раскрытому фото, после которого оно сворачивается.
const double kProfileCollapseSwipe = 50;

/// Прокрутка, за которую аватар уходит под шапку.
const double kProfileScrollCollapse = 170;

/// Обратная резинка: сколько пальцу пройти, чтобы аватар ушёл на [px].
double profileRubberInverse(double px, double d) {
  if (px <= 0) return 0;
  final k = (px / d).clamp(0.0, 0.999);
  return d * (1 / (1 - k) - 1) / 0.55;
}

/// Доля раскрытия по пути пальца (с резинкой), 0…1 при [maxPx].
double profilePullFraction(double raw, double maxPx) =>
    (profileRubber(raw, kProfilePullRubber) / maxPx).clamp(0.0, 1.0);

/// Растяжение раскрытого фото по пути пальца, px.
double profileStretchPx(double raw) => profileRubber(raw, kProfileStretchRubber);

/// Отклик по карте макета.
void profileHaptic(ProfileHaptic kind) {
  switch (kind) {
    // Карта вибро макета: на Android mediumImpact (KEYBOARD_TAP) у многих
    // телефонов слабее лёгкого — крупные события там heavyImpact.
    case ProfileHaptic.medium:
      if (defaultTargetPlatform == TargetPlatform.android) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    case ProfileHaptic.light:
      HapticFeedback.lightImpact();
    case ProfileHaptic.selection:
      HapticFeedback.selectionClick();
  }
}

enum ProfileHaptic { medium, light, selection }

// ── Что знает обложка о странице ──────────────────────────────────────────

@immutable
class ProfileMotionState {
  const ProfileMotionState({
    this.pullPx = 0,
    this.scroll = 0,
    this.expanded = 0,
    this.fadeY = 260,
  });

  /// Натяжение вниз, px (после резинки).
  final double pullPx;

  /// Прокрутка страницы, px.
  final double scroll;

  /// Раскрытие фото 0…1.
  final double expanded;

  /// Линия в обложке, ниже которой узор гаснет (кнопки, имя).
  final double fadeY;

  double get collapse => (scroll / kProfileScrollCollapse).clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) =>
      other is ProfileMotionState &&
      other.pullPx == pullPx &&
      other.scroll == scroll &&
      other.expanded == expanded &&
      other.fadeY == fadeY;

  @override
  int get hashCode => Object.hash(pullPx, scroll, expanded, fadeY);
}

/// Экран профиля кладёт сюда натяжение, прокрутку и раскрытие; живая
/// обложка-узор берёт их отсюда. Без области — узор в покое (плитки
/// выбора, ПК).
class ProfileMotionScope extends InheritedWidget {
  const ProfileMotionScope({
    super.key,
    required this.motion,
    required this.tint,
    required super.child,
  });

  final ValueListenable<ProfileMotionState> motion;

  /// Цвет аватара — для подсветки за ним.
  final Color tint;

  static ProfileMotionScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileMotionScope>();

  @override
  bool updateShouldNotify(ProfileMotionScope old) =>
      old.motion != motion || old.tint != tint;
}

// ── Живая обложка-узор ────────────────────────────────────────────────────

class PatternCoverView extends StatefulWidget {
  const PatternCoverView({super.key, required this.style, this.animate = true});

  final PatternCoverStyle style;
  final bool animate;

  @override
  State<PatternCoverView> createState() => _PatternCoverViewState();
}

class _PatternCoverViewState extends State<PatternCoverView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final PatternCoverBands _bands = PatternCoverBands();
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _time = 0;
  ValueListenable<ProfileMotionState>? _motion;

  /// Накопленное время с прошлой перерисовки: в покое узор дрейфует медленно
  /// (≤ 4 px/с) — ему хватает 30 кадров в секунду; на жесте — каждый кадр.
  double _sincePaint = 0;

  ProfileMotionState get _state =>
      _motion?.value ?? const ProfileMotionState();

  bool _allowed(BuildContext context) =>
      widget.animate &&
      CosmeticAnimationScope.of(context) &&
      TickerMode.valuesOf(context).enabled &&
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false) &&
      ThermalGuard.effectsAllowed.value &&
      _visible;

  /// 🔴 22.11.2026 (разбор): узора не видно — фото раскрыто или страница
  /// прокручена так, что узор погас (та же формула гашения, что в макете) —
  /// тикер стоит, а не перерисовывает невидимое 60–120 раз в секунду.
  bool get _visible {
    final s = _state;
    if (s.expanded >= 0.995) return false;
    return s.collapse < 0.9;
  }

  @override
  void initState() {
    super.initState();
    // Перегрев меняется на ходу — тикер следует за ним, а не за значением
    // на момент открытия.
    ThermalGuard.effectsAllowed.addListener(_wake);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = ProfileMotionScope.of(context)?.motion;
    if (motion != _motion) {
      _motion?.removeListener(_wake);
      _motion = motion;
      _motion?.addListener(_wake);
    }
    _sync();
  }

  @override
  void didUpdateWidget(PatternCoverView old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_allowed(context)) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else {
      if (_ticker.isActive) _ticker.stop();
      // Без движения — полосы сразу в цели, кадр стоит.
      final target = PatternCoverBands.target(_input(1));
      for (var i = 0; i < 6; i++) {
        _bands.x[i] = target;
        _bands.v[i] = 0;
      }
      _frame.value++;
    }
  }

  /// Движение страницы или перегрев меняются — включить или остановить
  /// расчёт.
  void _wake() {
    if (!mounted) return;
    final want = _allowed(context);
    if (want != _ticker.isActive) _sync();
  }

  PatternCoverInput _input(double height) {
    final s = _state;
    final geo = CoverAvatarGeometry.of(context);
    final cy = (geo?.center.dy ?? 0.3) * height;
    return PatternCoverInput(
      pull: s.pullPx,
      collapse: s.collapse,
      expanded: s.expanded,
      avatarCenterY: cy,
      fadeY: s.fadeY,
    );
  }

  double _height = 460;

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.033);
    _last = elapsed;
    _time += dt;
    _bands.step(dt, PatternCoverBands.target(_input(_height)));
    _sincePaint += dt;
    // Полосы ещё едут (жест, пружина) — каждый кадр; в покое — 30 к/с.
    if (!_bands.settled || _sincePaint >= 1 / 30) {
      _sincePaint = 0;
      _frame.value++;
    }
  }

  @override
  void dispose() {
    ThermalGuard.effectsAllowed.removeListener(_wake);
    _motion?.removeListener(_wake);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final scope = ProfileMotionScope.of(context);
    // 🔴 Цвет страницы, а не scaffoldBackgroundColor: тот в приложении
    // прозрачный, и подсветка/виньетки шли к прозрачному чёрному — в
    // светлой теме вокруг аватара было серое кольцо (разбор 22.11.2026).
    final background = AppBackground.scrimColorOf(context);
    // Третья волна: у обложки свой глубокий фон вместо цвета аватара.
    final ownTint = patternCoverOwnTint(widget.style, brightness);
    final tint =
        ownTint ??
        patternCoverTint(
          scope?.tint ?? theme.colorScheme.primary,
          brightness,
        );
    return LayoutBuilder(
      builder: (context, box) {
        _height = box.maxHeight.isFinite ? box.maxHeight : 460;
        final geo = CoverAvatarGeometry.of(context);
        return RepaintBoundary(
          child: PatternCoverBackdrop(
            tint: tint,
            ownTint: ownTint != null,
            background: background,
            avatarCenterY: (geo?.center.dy ?? 0.3) * _height,
            child: ValueListenableBuilder<int>(
              valueListenable: _frame,
              builder: (context, _, _) => CustomPaint(
                painter: PatternCoverPainter(
                  style: widget.style,
                  // «Отпечаток ключа»: узор из ключа этого человека.
                  keyBytes: PatternCoverKey.maybeOf(context),
                  input: _input(_height),
                  bands: List<double>.of(_bands.x),
                  time: _time,
                  ink: patternCoverInk(brightness),
                  inkStrength: patternCoverInkStrength(brightness),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Шапка: фон проявляется, имя причаливает ───────────────────────────────

/// Слой над страницей: при прокрутке проявляется фон шапки, имя
/// «причаливает» — встаёт в шапку заголовком (масштаб 0,8 от исходного).
/// Кнопки шапки — те же, что были; они рисуются над этим слоем.
class ProfileDockedHeader extends StatelessWidget {
  const ProfileDockedHeader({
    super.key,
    required this.scroll,
    required this.dockAt,
    required this.headerHeight,
    required this.title,
    this.subtitle,
    this.expanded = 0,
    this.leftInset = 68,
    this.rightInset = 68,
  });

  final ValueListenable<double> scroll;

  /// Прокрутка, при которой имя в странице упирается в шапку.
  final double dockAt;
  final double headerHeight;
  final Widget title;
  final Widget? subtitle;

  /// Раскрытое фото шапку прячет.
  final double expanded;

  /// Отступы заголовка от краёв — место кнопок шапки слева и справа.
  final double leftInset;
  final double rightInset;

  /// 0…1: насколько имя «причалило» (последние 28 px перед шапкой).
  static double dockProgress(double scroll, double dockAt) =>
      ((scroll - (dockAt - 28)) / 28).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Цвет страницы (у фона приложения он свой, а scaffold прозрачный —
    // из-за этого имя в шапке «висело поверх всего»).
    final bg = AppBackground.scrimColorOf(context);
    final top = MediaQuery.paddingOf(context).top;
    return IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: scroll,
        builder: (context, offset, _) {
          final c = (offset / kProfileScrollCollapse).clamp(0.0, 1.0);
          final dock = dockProgress(offset, dockAt);
          // Фон шапки — с 72 % сворачивания, полностью к причаливанию.
          final sm = _smooth(0.72, 1, c);
          final bgOpacity = math.max(sm, dock) * (1 - expanded.clamp(0, 1));
          if (bgOpacity <= 0.001 && dock <= 0.001) {
            return const SizedBox.shrink();
          }
          return SizedBox(
            height: top + headerHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: bgOpacity.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: bg,
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerColor.withValues(
                            alpha: 0.35 * bgOpacity,
                          ),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: leftInset,
                  right: rightInset,
                  top: top,
                  bottom: 0,
                  child: Opacity(
                    opacity: (dock * (1 - expanded.clamp(0, 1))).clamp(
                      0.0,
                      1.0,
                    ),
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - dock)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DefaultTextStyle.merge(
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            child: title,
                          ),
                          if (subtitle != null)
                            DefaultTextStyle.merge(
                              style: TextStyle(
                                fontSize: 12.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              child: subtitle!,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

double _smooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Аватар уходит под шапку: масштаб (1 − 0,7·c) и прозрачность гаснет на
/// 55–95 % сворачивания.
double profileAvatarScrollScale(double scroll) =>
    1 - 0.7 * (scroll / kProfileScrollCollapse).clamp(0.0, 1.0);

double profileAvatarScrollOpacity(double scroll) =>
    1 - _smooth(0.55, 0.95, (scroll / kProfileScrollCollapse).clamp(0.0, 1.0));

/// Имя на странице, пока не причалило: масштаб 1 → 0,8 за первые 129 px.
double profileNameScrollScale(double scroll) =>
    1 - 0.2 * (scroll / 129).clamp(0.0, 1.0);

// ── Двигатель шапки: натяжение, раскрытие, растяжение, сворачивание ───────

/// Одна логика движения шапки на три экрана (раньше — три копии).
///
/// Экран отдаёт сюда движения пальца и прокрутку, а берёт [expand] (0…1),
/// [stretchPx] и [motion] для обложки. Отклик — по карте макета: «medium»
/// при раскрытии на пороге, «light» при сворачивании свайпом.
class ProfileHeroDriver {
  ProfileHeroDriver({
    required TickerProvider vsync,
    required this.onChanged,
    this.maxPx = 240,
    this.snap = 0.45,
    this.hapticsEnabled,
  }) : _spring = AnimationController.unbounded(vsync: vsync),
       _stretchBack = AnimationController(
         vsync: vsync,
         duration: const Duration(milliseconds: 260),
       ) {
    _spring.addListener(_onSpring);
    _stretchBack.addListener(_onStretchBack);
  }

  final VoidCallback onChanged;
  final double maxPx;
  final double snap;

  /// Настройка «отклик» приложения; `null` — включён.
  final bool Function()? hapticsEnabled;

  final AnimationController _spring;
  final AnimationController _stretchBack;

  double expand = 0;
  double pullRaw = 0;
  double stretchRaw = 0;
  double _swipeUp = 0;
  double _from = 0;
  double _to = 0;
  double _stretchFrom = 0;
  bool _autoOpening = false;

  /// Пружина возвращает недотянутое (не раскрытие и не сворачивание фото):
  /// такую можно подхватить пальцем снова.
  bool _settling = false;

  /// Номер текущего хода пружины: подхваченный пальцем ход не должен
  /// «доезжать» в своём обработчике завершения.
  int _springRun = 0;

  /// Прокрутка страницы — для параллакса, имени и обложки.
  final ValueNotifier<double> scroll = ValueNotifier<double>(0);

  /// Что видит обложка.
  final ValueNotifier<ProfileMotionState> motion =
      ValueNotifier<ProfileMotionState>(const ProfileMotionState());

  double fadeY = 260;

  bool get isAnimating => _spring.isAnimating;

  /// Палец ведёт раскрытое (или раскрывающееся) фото — жест страницы.
  bool get ownsDrag => expand >= 0.995 || (_spring.isAnimating && _to >= 1);

  /// Хвост сворачивания: фото уже круг, пружина досчитывает остаток —
  /// страницу листать можно.
  bool get closingTail =>
      _spring.isAnimating && _to <= 0 && expand < 0.08;

  /// Страница стоит: фото тянется, раскрыто, растянуто или его ведёт
  /// пружина — кроме хвоста сворачивания.
  bool get freezesScroll => heroActive && !closingTail;

  /// Фото «в игре»: тянется, раскрыто, растянуто или его ведёт пружина.
  /// Пока так — страница стоит, а палец ведёт фото ([dragHero]).
  bool get heroActive =>
      expand > 0.001 || _spring.isAnimating || stretchRaw > 0;

  /// Фото уже раскрывалось в этом жесте/цикле — дальше оно идёт за пальцем
  /// линейно (без резинки и порога), пока не закроется совсем.
  bool _wasOpened = false;
  double _lastDy = 0;

  /// 🔴 Единственный вход пальца для фото «в игре» (21.11.2026, жалоба:
  /// «задержка после увеличения/уменьшения — не могу сразу свайпнуть
  /// обратно»). Любую анимацию можно перехватить в любой момент: пружина
  /// останавливается, фото идёт за пальцем, по отпусканию — пружиной туда,
  /// куда вёл палец.
  void dragHero(double dy) {
    if (dy == 0) return;
    _lastDy = dy;
    if (_spring.isAnimating) {
      // Раскрывается, а палец тянет дальше вниз — не мешаем; повёл вверх —
      // перехватываем. Закрывается, а палец повёл вниз — перехватываем.
      final opening = _to >= 1;
      if ((opening && dy > 0) || (!opening && dy < 0)) return;
      _springRun++;
      _spring.stop();
      _autoOpening = false;
      _settling = false;
      if (opening) _wasOpened = true;
    }
    _stretchBack.stop();
    // Раскрыто и тянут вниз (или уже растянуто) — растяжение.
    if (expand >= 0.995 && (dy > 0 || stretchRaw > 0)) {
      _wasOpened = true;
      stretchRaw = dy > 0 ? stretchRaw + dy : math.max(0, stretchRaw + dy);
      onChanged();
      return;
    }
    if (_wasOpened) {
      // За пальцем, линейно: 240 px — от фото до круга.
      final e = (expand + dy / maxPx).clamp(0.0, 1.0);
      pullRaw = profileRubberInverse(e * maxPx, kProfilePullRubber);
      _set(e);
      if (e <= 0.001) _wasOpened = false;
      return;
    }
    pull(dy);
  }

  /// Палец отпущен после [dragHero].
  void releaseHero() {
    _swipeUp = 0;
    if (stretchRaw > 0) releaseStretch();
    if (_spring.isAnimating) return;
    if (expand <= 0.001) {
      pullRaw = 0;
      _wasOpened = false;
      if (expand != 0) _set(0);
      return;
    }
    if (expand >= 0.995) return;
    final double target;
    if (_wasOpened) {
      target = _lastDy > 0.4
          ? 1
          : (_lastDy < -0.4 ? 0 : (expand >= 0.5 ? 1 : 0));
    } else {
      target = expand >= snap ? 1 : 0;
    }
    _haptic(target >= 1 ? ProfileHaptic.medium : ProfileHaptic.light);
    animateTo(target);
    _settling = target == 0 && !_wasOpened;
  }

  /// Страницу листать нельзя, пока фото раскрыто или пружина ещё ведёт его
  /// в круг — иначе прокрутка обгоняла анимацию и шапка застревала.
  bool get blocksScroll =>
      (_spring.isAnimating && !_settling) || expand >= 0.995;
  bool get isOpen => expand >= 0.995;
  double get stretchPx => profileStretchPx(stretchRaw);

  /// Натяжение для обложки, px (до раскрытия).
  double get pullPx =>
      expand >= 0.995 ? 0 : profileRubber(pullRaw, kProfilePullRubber);

  void _haptic(ProfileHaptic kind) {
    if (hapticsEnabled?.call() ?? true) profileHaptic(kind);
  }

  void _publish() {
    motion.value = ProfileMotionState(
      pullPx: pullPx,
      scroll: scroll.value,
      expanded: expand.clamp(0.0, 1.0),
      fadeY: fadeY,
    );
  }

  void _set(double e) {
    expand = e.clamp(0.0, 1.0);
    _publish();
    onChanged();
  }

  void setScroll(double offset) {
    final v = offset < 0 ? 0.0 : offset;
    if (v == scroll.value) return;
    scroll.value = v;
    _publish();
  }

  /// Палец тянет шапку вниз (`delta` > 0) или отпускает натяжение вверх.
  void pull(double delta) {
    // 🔴 Пока пружина раскрывает или сворачивает фото, палец её не
    // останавливает: раньше остановка оставляла фото на полпути. А вот
    // возврат недотянутого палец подхватывает (жалоба 21.11.2026: «чуть
    // потянул — на вторую попытку не реагирует»).
    if (_autoOpening) return;
    if (_spring.isAnimating) {
      if (!_settling) return;
      _springRun++;
      _spring.stop();
      _settling = false;
      pullRaw = profileRubberInverse(expand * maxPx, kProfilePullRubber);
    }
    pullRaw = math.max(0, pullRaw + delta);
    _set(profilePullFraction(pullRaw, maxPx));
    // Порог 45 % — фото раскрывается сразу, под пальцем.
    if (delta > 0 && expand >= snap) {
      _autoOpening = true;
      _haptic(ProfileHaptic.medium);
      animateTo(1);
    }
  }

  /// Движение пальца, когда фото раскрыто: вниз — растяжение, вверх —
  /// сперва снять растяжение, затем 50 px до сворачивания.
  void dragOpen(double delta) {
    if (!isOpen && !_spring.isAnimating) {
      pull(delta);
      return;
    }
    if (_spring.isAnimating) {
      // 🔴 Фото ещё раскрывается, а палец уже повёл вверх — сворачиваем
      // сразу, не дожидаясь конца анимации (жалоба 21.11.2026).
      if (_to >= 1 && delta < 0) {
        _swipeUp += -delta;
        if (_swipeUp > 14) {
          _swipeUp = 0;
          _haptic(ProfileHaptic.light);
          animateTo(0);
        }
      }
      return;
    }
    _stretchBack.stop();
    if (delta > 0 && _swipeUp <= 0) {
      stretchRaw += delta;
      onChanged();
      return;
    }
    if (delta < 0 && stretchRaw > 0) {
      stretchRaw = math.max(0, stretchRaw + delta);
      onChanged();
      return;
    }
    _swipeUp = math.max(0, _swipeUp - delta);
    if (_swipeUp > kProfileCollapseSwipe) {
      _swipeUp = 0;
      _haptic(ProfileHaptic.light);
      animateTo(0);
    }
  }

  /// Палец отпущен: растяжение возвращается, недотянутое — к ближнему краю.
  void release() {
    _swipeUp = 0;
    if (stretchRaw > 0) releaseStretch();
    if (_autoOpening || _spring.isAnimating) return;
    if (expand > 0.001 && expand < 0.995) {
      final open = expand >= snap;
      animateTo(open ? 1 : 0);
      _settling = !open;
    } else if (expand <= 0.001 && pullRaw > 0) {
      pullRaw = 0;
      _set(0);
    }
  }

  void releaseStretch() {
    if (stretchRaw <= 0) return;
    _stretchFrom = stretchRaw;
    _stretchBack.forward(from: 0);
  }

  void _onStretchBack() {
    final k = Curves.easeOutCubic.transform(_stretchBack.value);
    stretchRaw = _stretchFrom * (1 - k);
    onChanged();
  }

  /// Пружиной k320 c26 к [target] (0 или 1).
  void animateTo(double target) {
    _springRun++;
    _spring.stop();
    _settling = false;
    _from = expand;
    _to = target.clamp(0.0, 1.0);
    if ((_from - _to).abs() < 0.001) {
      _autoOpening = false;
      _set(_to);
      if (_to == 0) pullRaw = 0;
      return;
    }
    _spring.value = 0;
    final run = ++_springRun;
    _spring
        .animateWith(
          SpringSimulation(
            _to <= 0 ? kProfileCollapseSpring : kProfileSpring,
            0,
            1,
            0,
          ),
        )
        .whenCompleteOrCancel(() {
          if (run != _springRun) return;
          _autoOpening = false;
          _settling = false;
          if (_to == 0) {
            pullRaw = 0;
            stretchRaw = 0;
            _wasOpened = false;
          } else {
            _wasOpened = true;
          }
          _set(_to);
        });
  }

  void _onSpring() {
    // Перелёт пружины не выходит за край: прозрачности и размеры шапки
    // рассчитаны на 0…1.
    final v = _spring.value.clamp(0.0, 1.0);
    final e = _from + (_to - _from) * v;
    expand = e.clamp(0.0, 1.0);
    pullRaw = profileRubberInverse(expand * maxPx, kProfilePullRubber);
    _publish();
    onChanged();
  }

  void stop() {
    if (_spring.isAnimating) _spring.stop();
  }

  void dispose() {
    _spring.dispose();
    _stretchBack.dispose();
    scroll.dispose();
    motion.dispose();
  }
}

// ── Обёртки прокрутки (только перерисовка, без перестройки экрана) ───────

/// Обложка: фон движется вдвое медленнее страницы и гаснет к 85 %.
class ProfileCoverParallax extends StatelessWidget {
  const ProfileCoverParallax({
    super.key,
    required this.driver,
    required this.child,
  });

  final ProfileHeroDriver driver;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: driver.scroll,
    child: child,
    builder: (context, offset, child) {
      // 🔴 Обёртка одна и та же и в покое (разбор 22.11.2026): раньше в покое
      // возвращался голый child — тип на месте менялся, и при каждом уходе
      // страницы с верха аватар, обложка и рамка создавались заново (видео
      // перезапускалось, анимации прыгали в начало).
      final off = math.max(0.0, offset);
      final c = (off / kProfileScrollCollapse).clamp(0.0, 1.0);
      return Transform.translate(
        offset: Offset(0, off * 0.5),
        child: Opacity(opacity: (1 - c * 0.85).clamp(0.0, 1.0), child: child),
      );
    },
  );
}

/// Аватар (и всё, что на нём: рамка, передний слой обложки) уходит под
/// шапку: медленнее страницы (0,62), уменьшаясь и растворяясь.
class ProfileAvatarScroll extends StatelessWidget {
  const ProfileAvatarScroll({
    super.key,
    required this.driver,
    required this.child,
  });

  final ProfileHeroDriver driver;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: driver.scroll,
    child: child,
    builder: (context, offset, child) {
      // 🔴 Обёртка одна и та же и в покое (разбор 22.11.2026): раньше в покое
      // возвращался голый child — тип на месте менялся, и при каждом уходе
      // страницы с верха аватар, обложка и рамка создавались заново (видео
      // перезапускалось, анимации прыгали в начало).
      final on = offset > 0 && driver.expand <= 0.001;
      final travel = on ? math.min(offset, kProfileScrollCollapse) * 0.38 : 0.0;
      return Transform.translate(
        offset: Offset(0, travel),
        child: Transform.scale(
          scale: on ? profileAvatarScrollScale(offset) : 1.0,
          child: Opacity(
            opacity: on
                ? profileAvatarScrollOpacity(offset).clamp(0.0, 1.0)
                : 1.0,
            child: child,
          ),
        ),
      );
    },
  );
}

/// Имя и статус на странице: 1 → 0,8 за 129 px и уступают место имени в
/// шапке за последние 28 px перед ней.
class ProfileNameScroll extends StatelessWidget {
  const ProfileNameScroll({
    super.key,
    required this.driver,
    required this.dockAt,
    required this.child,
    this.minScale = 0.8,
  });

  final ProfileHeroDriver driver;
  final double dockAt;
  final double minScale;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: driver.scroll,
    child: child,
    builder: (context, offset, child) {
      // 🔴 Обёртка одна и та же и в покое (разбор 22.11.2026): раньше в покое
      // возвращался голый child — тип на месте менялся, и при каждом уходе
      // страницы с верха аватар, обложка и рамка создавались заново (видео
      // перезапускалось, анимации прыгали в начало).
      final on = offset > 0 && driver.expand <= 0.001;
      final k = on ? (offset / 129).clamp(0.0, 1.0) : 0.0;
      final dock = on ? ProfileDockedHeader.dockProgress(offset, dockAt) : 0.0;
      return Opacity(
        opacity: (1 - dock).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 1 - (1 - minScale) * k,
          alignment: Alignment.topCenter,
          child: child,
        ),
      );
    },
  );
}


// ── Магнитная привязка страницы ───────────────────────────────────────────

/// Отпустил страницу между «шапка наверху», «имя в шапке» и «галерея у
/// шапки» — она доезжает до ближней точки. Ниже галереи — свободно.
/// Внизу добавляется пустое место, чтобы галерея доезжала до шапки даже без
/// фото.
class ProfileScrollSnapper {
  ProfileScrollSnapper({required this.controller, this.hapticsEnabled});

  final ScrollController controller;

  /// Настройка «Отклик»: аватар, примагнитившись в остров, даёт отклик.
  final bool Function()? hapticsEnabled;

  /// Метка над вкладками галереи.
  final GlobalKey galleryKey = GlobalKey();

  /// Пустое место внизу страницы.
  final ValueNotifier<double> spacer = ValueNotifier<double>(0);

  /// Прокрутка, на которой имя встаёт в шапку.
  double dockAt = 0;

  /// Нижний край шапки на экране.
  double headerBottom = 0;

  bool _snapping = false;
  bool _measureQueued = false;

  /// Прокрутка, при которой галерея встаёт под шапку.
  double? galleryAt() {
    if (!controller.hasClients) return null;
    final box = galleryKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final y = box.localToGlobal(Offset.zero).dy;
    return controller.offset + y - headerBottom;
  }

  /// После раскладки: хватает ли страницы, чтобы галерея дошла до шапки.
  void measureSoon() {
    if (_measureQueued) return;
    _measureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureQueued = false;
      if (!controller.hasClients) return;
      final g = galleryAt();
      if (g == null) return;
      final pos = controller.position;
      final withoutSpacer = pos.maxScrollExtent - spacer.value;
      final need = math.max(0.0, g - withoutSpacer);
      if ((need - spacer.value).abs() > 1) spacer.value = need;
    });
  }

  /// Страница остановилась — притянуть к ближней точке.
  void onScrollEnd() {
    if (_snapping || !controller.hasClients) return;
    final pos = controller.position;
    if (pos.isScrollingNotifier.value) return;
    final off = controller.offset;
    final g = galleryAt();
    final points = <double>[
      0,
      if (dockAt > 8) dockAt,
      if (g != null && g > dockAt + 24) g,
    ];
    if (off <= 0.5 || off >= points.last - 0.5) return;
    var a = points.first, b = points.last;
    for (var i = 0; i + 1 < points.length; i++) {
      if (off >= points[i] && off <= points[i + 1]) {
        a = points[i];
        b = points[i + 1];
        break;
      }
    }
    final target = (off - a) < (b - a) / 2 ? a : b;
    if ((target - off).abs() < 1) return;
    _snapping = true;
    controller
        .animateTo(
          target.clamp(0.0, pos.maxScrollExtent),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          _snapping = false;
          // Аватар сел в остров (или вкладки — в шапку) — лёгкий отклик.
          if (target > 0 && (hapticsEnabled?.call() ?? true)) {
            HapticFeedback.lightImpact();
          }
        });
  }

  void dispose() => spacer.dispose();
}

/// Пустое место внизу страницы профиля (см. [ProfileScrollSnapper]).
class ProfileSnapSpacer extends StatelessWidget {
  const ProfileSnapSpacer({super.key, required this.snapper});

  final ProfileScrollSnapper snapper;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: snapper.spacer,
      builder: (context, h, _) {
        // Пересчёт после каждой смены места: короткая страница доходит
        // за два кадра (сначала растёт до экрана, потом до шапки).
        snapper.measureSoon();
        return SizedBox(height: h);
      },
    );
  }
}

// ── «Профиль сворачивается в свой остров» (макет «Profile Redesign») ─────

double profileSmooth(double a, double b, double x) => _smooth(a, b, x);

/// Доля сворачивания по прокрутке (0…1 за 170 px).
double profileCollapse(double scroll) =>
    (scroll / kProfileScrollCollapse).clamp(0.0, 1.0);

/// Большой аватар по дуге перелетает в левый остров: размер 112 → 34,
/// x — по степени 1,6 (сперва вверх, потом влево), y — к центру острова.
/// Рамку оборачивать тем же — она центрирована на аватаре.
class ProfileAvatarFlight extends StatelessWidget {
  const ProfileAvatarFlight({
    super.key,
    required this.driver,
    required this.restCenter,
    required this.islandCenter,
    required this.child,
  });

  final ProfileHeroDriver driver;

  /// Центр аватара в покое (экран, без прокрутки).
  final Offset restCenter;

  /// Куда он садится: центр аватара в острове.
  final Offset islandCenter;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: driver.scroll,
    child: child,
    builder: (context, offset, child) {
      // 🔴 Обёртка одна и та же и в покое (разбор 22.11.2026): раньше в покое
      // возвращался голый child — тип на месте менялся, и при каждом уходе
      // страницы с верха аватар, обложка и рамка создавались заново (видео
      // перезапускалось, анимации прыгали в начало).
      final on = offset > 0 && driver.expand <= 0.001;
      if (!on) {
        return Opacity(
          opacity: 1,
          child: Transform.translate(
            offset: Offset.zero,
            child: Transform.scale(scale: 1, child: child),
          ),
        );
      }
      final c = profileCollapse(offset);
      final k = _smooth(0, 1, c);
      final size = 112 + (34 - 112) * k;
      final cx =
          restCenter.dx +
          (islandCenter.dx - restCenter.dx) * math.pow(k, 1.6).toDouble();
      final cy = restCenter.dy + (islandCenter.dy - restCenter.dy) * k;
      // Список уже увёз аватар на `offset` вверх — возвращаем разницу.
      final dx = cx - restCenter.dx;
      final dy = cy - (restCenter.dy - offset);
      return Opacity(
        opacity: (1 - _smooth(0.82, 1, c)).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(scale: size / 112, child: child),
        ),
      );
    },
  );
}

/// Имя и статус на странице при сворачивании: имя уменьшается к 16/24 и
/// уступает имени в острове; статус гаснет первым.
class ProfileTextCollapse extends StatelessWidget {
  const ProfileTextCollapse({
    super.key,
    required this.driver,
    required this.child,
    this.status = false,
  });

  final ProfileHeroDriver driver;
  final bool status;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: driver.scroll,
    child: child,
    builder: (context, offset, child) {
      // 🔴 Обёртка одна и та же и в покое (разбор 22.11.2026): раньше в покое
      // возвращался голый child — тип на месте менялся, и при каждом уходе
      // страницы с верха аватар, обложка и рамка создавались заново (видео
      // перезапускалось, анимации прыгали в начало).
      final on = offset > 0 && driver.expand <= 0.001;
      final c = on ? profileCollapse(offset) : 0.0;
      if (status) {
        return Opacity(
          opacity: (1 - _smooth(0, 0.35, c)).clamp(0.0, 1.0),
          child: child,
        );
      }
      final k2 = _smooth(0.1, 1, c);
      return Opacity(
        opacity: (1 - _smooth(0.25, 0.7, c)).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 1 + (16 / 24 - 1) * k2,
          alignment: Alignment.topCenter,
          child: child,
        ),
      );
    },
  );
}

/// Кнопки под именем гаснут, уходя под шапку: `(верх − линия) / 50`.
class ProfileFadeUnderHeader extends StatelessWidget {
  const ProfileFadeUnderHeader({
    super.key,
    required this.driver,
    required this.restTop,
    required this.line,
    required this.child,
  });

  final ProfileHeroDriver driver;

  /// Верх кнопок в покое (экран).
  final double restTop;

  /// Линия шапки, у которой они гаснут.
  final double line;
  final Widget child;

  /// Ушли ли кнопки под шапку (для шестерёнки в правом острове).
  static bool hidden(double scroll, double restTop, double line) =>
      restTop - scroll < line + 4;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: driver.scroll,
    child: child,
    builder: (context, offset, child) {
      // 🔴 Обёртка одна и та же и в покое (разбор 22.11.2026): раньше в покое
      // возвращался голый child — тип на месте менялся, и при каждом уходе
      // страницы с верха аватар, обложка и рамка создавались заново (видео
      // перезапускалось, анимации прыгали в начало).
      final on = offset > 0 && driver.expand <= 0.001;
      final o = on ? ((restTop - offset - line) / 50).clamp(0.0, 1.0) : 1.0;
      return Opacity(opacity: o, child: IgnorePointer(ignoring: o < 0.2, child: child));
    },
  );
}

/// Мягкое затемнение под шапкой цветом страницы (вместо сплошной плашки):
/// список уходит под острова, а не обрезается.
class ProfileTopFade extends StatelessWidget {
  const ProfileTopFade({super.key, required this.driver});

  final ProfileHeroDriver driver;

  @override
  Widget build(BuildContext context) {
    final bg = AppBackground.scrimColorOf(context);
    final top = MediaQuery.paddingOf(context).top;
    return IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: driver.scroll,
        builder: (context, offset, _) {
          final o =
              _smooth(0.15, 0.7, profileCollapse(offset)) *
              (1 - driver.expand.clamp(0.0, 1.0));
          if (o <= 0.002) return const SizedBox.shrink();
          return Opacity(
            opacity: o,
            // Отступ страницы уже включает шапку — затемнение чуть ниже неё.
            child: Container(
              height: top + 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.55, 1],
                  colors: [
                    bg.withValues(alpha: 0.92),
                    bg.withValues(alpha: 0.6),
                    bg.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Содержимое левого острова в свёрнутом виде: аватар 34 + имя 16
/// (+ эмодзи-статус и знак). Как шапка чата.
class ProfileMiniIdentity extends StatelessWidget {
  const ProfileMiniIdentity({
    super.key,
    required this.avatar,
    required this.name,
    this.trailing = const <Widget>[],
    this.ghost = false,
    this.reserve = 0,
  });

  /// Место под прилетающие знаки (эмодзи-статус, знак), px.
  final double reserve;

  final Widget avatar;
  final String name;
  final List<Widget> trailing;

  /// Только место: имя и знаки прилетают сюда слоем поверх шапки
  /// ([ProfileFlyingLabel]) — второго имени в острове нет.
  final bool ghost;

  /// Ширина под имя (для плавного роста острова).
  static double widthFor(BuildContext context, String name, {int extras = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return 7 + 34 + 8 + tp.width + 14 + extras * 22;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 7, right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Место аватара: сам аватар прилетает сюда слоем поверх шапки.
          SizedBox.square(dimension: 34, child: ClipOval(child: avatar)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
                color: ghost
                    ? Colors.transparent
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (ghost) SizedBox(width: reserve) else ...trailing,
        ],
      ),
    );
  }
}

/// Левый край острова «аватар + имя» у собеседника и комнаты: остров
/// «назад» — отступ 8 + ширина 48, плюс зазор 10.
const double kProfileMiniIslandLeft = 8 + 48 + 10;

/// Свёрнутый профиль собеседника или комнаты: остров «аватар + имя»
/// появляется рядом с «назад», куда прилетает большой аватар. Касание —
/// наверх страницы.
class ProfileMiniIsland extends StatelessWidget {
  const ProfileMiniIsland({
    super.key,
    required this.driver,
    required this.scrollController,
    required this.child,
  });

  final ProfileHeroDriver driver;
  final ScrollController scrollController;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: driver.scroll,
    child: child,
    builder: (context, offset, child) {
      final mk =
          profileSmooth(0.35, 1, profileCollapse(offset)) *
          (1 - driver.expand.clamp(0.0, 1.0));
      if (mk <= 0.002) return const SizedBox.shrink();
      return IgnorePointer(
        ignoring: mk < 0.5,
        child: Opacity(
          opacity: mk.clamp(0.0, 1.0),
          // Появляется на месте, без сдвига влево — не наезжает на «назад».
          child: Transform.translate(
            offset: Offset.zero,
            child: Transform.scale(
              scale: 0.94 + 0.06 * mk,
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!scrollController.hasClients) return;
                  scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: FrostedHeaderIsland(
                  radius: 24,
                  height: 48,
                  padding: EdgeInsets.zero,
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Мини-аватар острова: фото или буквы в общих цветах заглушек.
class ProfileMiniPhoto extends StatelessWidget {
  const ProfileMiniPhoto({
    super.key,
    required this.path,
    required this.seed,
    required this.name,
  });

  final String? path;
  final String seed;
  final String name;

  @override
  Widget build(BuildContext context) {
    final p = path?.trim() ?? '';
    // Кэш «есть ли файл»: остров перестраивается на каждом кадре полёта.
    if (p.isNotEmpty && FileExistsCache.exists(p)) {
      return Image.file(File(p), fit: BoxFit.cover, gaplessPlayback: true);
    }
    // Буквы растут и уменьшаются вместе с кругом (летящий аватар 112 → 34).
    return ColoredBox(
      color: AvatarInitials.backgroundColor(context, seed: seed),
      child: LayoutBuilder(
        builder: (context, box) => Center(
          child: Text(
            AvatarInitials.label(displayName: name, fallbackId: seed),
            style: TextStyle(
              fontSize: (box.maxWidth.isFinite ? box.maxWidth : 34) * 0.34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
              decoration: TextDecoration.none,
              color: AvatarInitials.foregroundColor(context, seed: seed),
            ),
          ),
        ),
      ),
    );
  }
}

/// Карточки профиля (макет «Profile Redesign»): в тёмной теме — в тон фону
/// страницы, на ступень светлее (не голубее фона), в светлой — белые.
/// Только внутри страницы профиля.
///
/// 23.11.2026 (владелец): плотный цвет — общий для всех плашек приложения
/// ([opaqueCardColor], чуть светлее прежнего), а при включённых «Прозрачных
/// плашках» профиль — такие же прозрачные панели, как везде (тема не
/// меняется).
ThemeData profileCardTheme(BuildContext context) {
  final theme = Theme.of(context);
  if (panelCardsEnabled && translucentCardsOn) return theme;
  final dark = theme.brightness == Brightness.dark;
  final card = dark
      ? opaquePanelColorFor(
          dark: true,
          page: AppBackground.scrimColorOf(context),
          surface: theme.colorScheme.surface,
        )
      : Colors.white;
  return theme.copyWith(
    cardColor: card,
    cardTheme: theme.cardTheme.copyWith(color: card),
  );
}

// ── Один аватар летит НАД шапкой в остров (исправление 21.11.2026) ───────

/// Геометрия полёта аватара по прокрутке (экранные координаты). `null` —
/// не летит (страница наверху или фото раскрыто).
Rect? profileFlightRect({
  required double scroll,
  required double expand,
  required Offset restCenter,
  required Offset islandCenter,
}) {
  if (scroll <= 0 || expand > 0.001) return null;
  final k = _smooth(0, 1, profileCollapse(scroll));
  final size = 112 + (34 - 112) * k;
  final cx =
      restCenter.dx +
      (islandCenter.dx - restCenter.dx) * math.pow(k, 1.6).toDouble();
  final cy = restCenter.dy + (islandCenter.dy - restCenter.dy) * k;
  return Rect.fromCenter(center: Offset(cx, cy), width: size, height: size);
}

/// Летящий аватар — слой ПОВЕРХ шапки (кладётся над `Scaffold`), поэтому
/// он садится в остров, а не уходит под него. Пока он летит, аватар в
/// странице скрыт ([ProfileHideWhileFlying]), а в острове на его месте
/// пусто — аватар один.
class ProfileFlyingAvatar extends StatelessWidget {
  const ProfileFlyingAvatar({
    super.key,
    required this.driver,
    required this.restCenter,
    required this.islandCenter,
    required this.child,
    this.hidden,
  });

  final ProfileHeroDriver driver;
  final Offset restCenter;
  final Offset islandCenter;
  final Widget child;

  /// Когда острова уступили место вкладкам — аватар уходит вместе с ними.
  final ValueListenable<bool>? hidden;

  @override
  Widget build(BuildContext context) {
    Widget flight(bool hide) => ValueListenableBuilder<double>(
      valueListenable: driver.scroll,
      child: child,
      builder: (context, offset, child) {
        final r = profileFlightRect(
          scroll: offset,
          expand: driver.expand,
          restCenter: restCenter,
          islandCenter: islandCenter,
        );
        if (r == null) return const SizedBox.shrink();
        return Stack(
          children: [
            Positioned.fromRect(
              rect: r,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: hide ? 0 : 1,
                child: ClipOval(child: child),
              ),
            ),
          ],
        );
      },
    );
    final h = hidden;
    // 🔴 23.11.2026 (владелец: «под инициалами летящего аватара две
    // полоски»): слой полёта лежит в Stack экрана выше Scaffold, без
    // Material — текст букв брал запасной стиль Flutter с двойным жёлтым
    // подчёркиванием. Прозрачный Material даёт тексту обычный стиль.
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: h == null
            ? flight(false)
            : ValueListenableBuilder<bool>(
                valueListenable: h,
                builder: (context, hide, _) => flight(hide),
              ),
      ),
    );
  }
}

/// Аватар в странице: виден, пока страница наверху; летит — его рисует
/// [ProfileFlyingAvatar]. Рамка вокруг гаснет за первые 25 %.
class ProfileHideWhileFlying extends StatelessWidget {
  const ProfileHideWhileFlying({
    super.key,
    required this.driver,
    required this.child,
    this.frame = false,
  });

  final ProfileHeroDriver driver;
  final bool frame;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: driver.scroll,
    child: child,
    builder: (context, offset, child) {
      // 🔴 Обёртка одна и та же и в покое (разбор 22.11.2026): раньше в покое
      // возвращался голый child — тип на месте менялся, и при каждом уходе
      // страницы с верха аватар, обложка и рамка создавались заново (видео
      // перезапускалось, анимации прыгали в начало).
      final on = offset > 0 && driver.expand <= 0.001;
      final o = !on
          ? 1.0
          : frame
          ? (1 - _smooth(0, 0.25, profileCollapse(offset)))
          : 0.0;
      return Opacity(opacity: o.clamp(0.0, 1.0), child: child);
    },
  );
}

/// Имя (со статусом-эмодзи и знаком) летит ПОВЕРХ шапки в остров рядом с
/// прилетевшим аватаром: 24 → 16, по той же дуге. Имя одно — в острове
/// на его месте пусто (`ProfileMiniIdentity(ghost: true)`).
class ProfileFlyingLabel extends StatelessWidget {
  const ProfileFlyingLabel({
    super.key,
    required this.driver,
    required this.restTop,
    required this.restCenterX,
    required this.targetLeft,
    required this.targetCenterY,
    required this.targetMaxWidth,
    required this.child,
    this.hidden,
  });

  final ProfileHeroDriver driver;

  /// Верх строки имени в странице (экран, без прокрутки).
  final double restTop;
  final double restCenterX;

  /// Левый край имени в острове и центр острова по высоте.
  final double targetLeft;
  final double targetCenterY;

  /// Ширина под имя в острове (в масштабе 16 px).
  final double targetMaxWidth;
  final Widget child;
  final ValueListenable<bool>? hidden;

  @override
  Widget build(BuildContext context) {
    final restMax = MediaQuery.sizeOf(context).width - 48;
    Widget flight(bool hide) => ValueListenableBuilder<double>(
      valueListenable: driver.scroll,
      child: child,
      builder: (context, offset, child) {
        if (offset <= 0 || driver.expand > 0.001) {
          return const SizedBox.shrink();
        }
        final k = _smooth(0, 1, profileCollapse(offset));
        const endScale = 16 / 24;
        final scale = 1 + (endScale - 1) * k;
        final maxW = restMax + (targetMaxWidth / endScale - restMax) * k;
        return CustomSingleChildLayout(
          delegate: _LabelFlightDelegate(
            k: k,
            scale: scale,
            maxWidth: maxW,
            restTop: restTop,
            restCenterX: restCenterX,
            targetLeft: targetLeft,
            targetCenterY: targetCenterY,
            endScale: endScale,
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: hide ? 0 : 1,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
    final h = hidden;
    return IgnorePointer(
      child: h == null
          ? flight(false)
          : ValueListenableBuilder<bool>(
              valueListenable: h,
              builder: (context, hide, _) => flight(hide),
            ),
    );
  }
}

class _LabelFlightDelegate extends SingleChildLayoutDelegate {
  _LabelFlightDelegate({
    required this.k,
    required this.scale,
    required this.maxWidth,
    required this.restTop,
    required this.restCenterX,
    required this.targetLeft,
    required this.targetCenterY,
    required this.endScale,
  });

  final double k, scale, maxWidth, restTop, restCenterX;
  final double targetLeft, targetCenterY, endScale;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: math.max(40, maxWidth));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Центр строки: из покоя (по центру экрана) к левому краю места в
    // острове; масштаб — вокруг центра строки.
    final restCy = restTop + childSize.height / 2;
    final targetCx = targetLeft + childSize.width * endScale / 2;
    final cx =
        restCenterX + (targetCx - restCenterX) * math.pow(k, 1.6).toDouble();
    final cy = restCy + (targetCenterY - restCy) * k;
    return Offset(cx - childSize.width / 2, cy - childSize.height / 2);
  }

  @override
  bool shouldRelayout(_LabelFlightDelegate old) =>
      old.k != k || old.maxWidth != maxWidth || old.restTop != restTop;
}

// ── Плитки мини-галереи (макет «Profile Redesign») ───────────────────────

/// Пунктирная плитка «+» — добавить фото.
class ProfileGalleryAddTile extends StatelessWidget {
  const ProfileGalleryAddTile({super.key, required this.onTap, this.tooltip});

  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: CustomPaint(
            painter: _DashedRRectPainter(
              color: cs.outline.withValues(alpha: 0.7),
            ),
            child: Center(child: Icon(Icons.add_rounded, size: 28, color: cs.primary)),
          ),
        ),
      ),
    );
  }
}

/// Пустая рамка под будущее фото.
class ProfileGalleryEmptyTile extends StatelessWidget {
  const ProfileGalleryEmptyTile({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: cs.onSurface.withValues(alpha: 0.03),
          border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          const Radius.circular(12),
        ),
      );
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => old.color != color;
}


// ── Один вход пальца для шапки профиля ───────────────────────────────────

/// Страница профиля не листается, пока фото «в игре» — палец ведёт фото.
/// Физика читает это вживую: смены физики (и обрыва жеста) нет.
class ProfileHeroScrollPhysics extends ScrollPhysics {
  const ProfileHeroScrollPhysics({super.parent, required this.frozen});

  final bool Function() frozen;

  @override
  ProfileHeroScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      ProfileHeroScrollPhysics(parent: buildParent(ancestor), frozen: frozen);

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (frozen()) return 0;
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (frozen()) return null;
    return super.createBallisticSimulation(position, velocity);
  }
}

/// Слушает палец напрямую (не участвуя в разборе жестов): тянет фото у
/// верха страницы, ведёт его, когда оно «в игре», и отпускает пружиной.
/// Горизонтальные движения (галерея, вкладки) не трогает.
class ProfileHeroGestureLayer extends StatefulWidget {
  const ProfileHeroGestureLayer({
    super.key,
    required this.driver,
    required this.scrollController,
    required this.child,
    this.blocked,
    this.onPullToFullscreen,
    this.enabled = true,
  });

  final ProfileHeroDriver driver;
  final ScrollController scrollController;
  final Widget child;

  /// Например, открыто меню долгого нажатия на аватар.
  final bool Function()? blocked;

  /// Раскрытое фото дотянули ещё — полноэкранный просмотр.
  final VoidCallback? onPullToFullscreen;
  final bool enabled;

  @override
  State<ProfileHeroGestureLayer> createState() =>
      _ProfileHeroGestureLayerState();
}

class _ProfileHeroGestureLayerState extends State<ProfileHeroGestureLayer> {
  int? _pointer;
  Offset _total = Offset.zero;
  bool? _vertical;
  bool _driving = false;
  bool _fullscreenFired = false;

  bool get _atTop =>
      !widget.scrollController.hasClients ||
      widget.scrollController.offset <= 0.5;

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _total = Offset.zero;
    _vertical = null;
    _driving = false;
    _fullscreenFired = false;
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer || !widget.enabled) return;
    if (widget.blocked?.call() ?? false) return;
    final d = widget.driver;
    _total += e.delta;
    if (_vertical == null) {
      // Фото «в игре» — откликаемся сразу, без порога.
      if (d.heroActive) {
        _vertical = true;
      } else {
        if (_total.distance < 6) return;
        _vertical = _total.dy.abs() > _total.dx.abs();
      }
    }
    if (_vertical != true) return;
    final dy = e.delta.dy;
    // Хвост сворачивания: вверх — уже листаем страницу.
    if (d.heroActive && !(d.closingTail && dy < 0)) {
      _driving = true;
      d.dragHero(dy);
      if (!_fullscreenFired &&
          widget.onPullToFullscreen != null &&
          d.stretchRaw >= 84) {
        _fullscreenFired = true;
        d.releaseStretch();
        widget.onPullToFullscreen!();
      }
    } else if (_atTop && dy > 0) {
      _driving = true;
      d.dragHero(dy);
    }
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_driving) widget.driver.releaseHero();
    _driving = false;
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _up,
    child: widget.child,
  );
}
