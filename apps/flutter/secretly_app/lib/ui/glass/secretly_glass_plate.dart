// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Пластина SecretlyGlass — своё жидкое стекло одним проходом (план стекла,
/// 23.11.2026; шейдер `assets/shaders/secretly_glass.frag`).
///
/// Один `BackdropFilterLayer` с `ImageFilter.shader`: фон захватывается один
/// раз, форма пластины и капли — формула в шейдере, анимация меняет только
/// числа (никаких `toImageSync` и текстур формы). Капля — часть того же
/// прохода, а не второе стекло поверх.
///
/// Включается, только когда [secretlyGlassEngineActive]: iPhone + стекло в
/// Настройках + Impeller + шейдер загружен + уровень выше Flat. Иначе —
/// [fallback] (прежняя пластина), без единого лишнего прохода.
library;

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../widgets/frosted_header_island.dart' show liquidGlassIslandsEnabled;
import 'glass_quality.dart';

/// Выключатель движка. `false` — везде прежнее стекло.
const bool kSecretlyGlassEngine = true;

/// Движок на iPhone в обычных сборках. Включён к выпуску 1.9 (владелец,
/// 24.11.2026: «Включить стекло на iPhone» — проверочные 727–748 шли с ним).
/// Работает, когда человек включил «Жидкое стекло» в Настройках
/// (`GlassPrefs`, по умолчанию выключено с 23.07 — нагрев); проверочная
/// сборка с `SECRETLY_GLASS_ENGINE_FORCE` обходит и этот переключатель.
/// Откат — `false`.
const bool kSecretlyGlassEngineOnIos = true;

/// Только для проверки на Android (снимок экрана через adb): сборка с
/// `--dart-define=SECRETLY_GLASS_ENGINE_FORCE=true` включает движок без
/// настройки и на Android. В выпусках не задаётся.
const bool _kForceEngine = bool.fromEnvironment('SECRETLY_GLASS_ENGINE_FORCE');

abstract final class SecretlyGlassProgram {
  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram?>? _loading;
  static final ValueNotifier<bool> ready = ValueNotifier<bool>(false);

  static ui.FragmentProgram? get program => _program;

  /// Загрузить шейдер один раз; ошибка — движок просто не включится.
  static Future<ui.FragmentProgram?> ensureLoaded() {
    return _loading ??= ui.FragmentProgram.fromAsset(
      'assets/shaders/secretly_glass.frag',
    ).then<ui.FragmentProgram?>((p) {
      _program = p;
      ready.value = true;
      return p;
    }, onError: (Object _) => null);
  }
}

/// Может ли движок вообще включиться на этой платформе (без учёта настройки
/// и уровня). `false` — пластина сразу рисует [SecretlyGlassPlate.fallback]
/// и ничего не запускает: ни шейдер, ни замер кадров (Android, Windows, …).
bool get secretlyGlassEngineEligible {
  if (!kSecretlyGlassEngine) return false;
  if (kIsWeb) return false;
  if (!_kForceEngine && !(kSecretlyGlassEngineOnIos && Platform.isIOS)) {
    return false;
  }
  return ui.ImageFilter.isShaderFilterSupported;
}

/// Можно ли рисовать пластину движком прямо сейчас.
bool get secretlyGlassEngineActive {
  if (!secretlyGlassEngineEligible) return false;
  if (!_kForceEngine && !liquidGlassIslandsEnabled) return false;
  if (SecretlyGlassProgram.program == null) return false;
  return GlassQualityController.quality.value != GlassQuality.flat;
}

/// Источники сдвига пластины по экрану: позиции всех прокручиваемых
/// предков (снизу вверх) и анимации ближайшего маршрута.
@visibleForTesting
List<Listenable> repositionSourcesOf(BuildContext context) {
  final out = <Listenable>[];
  var ctx = context;
  for (var guard = 0; guard < 16; guard++) {
    final scrollable = Scrollable.maybeOf(ctx);
    if (scrollable == null) break;
    out.add(scrollable.position);
    ctx = scrollable.context;
  }
  final route = ModalRoute.of(context);
  final a = route?.animation;
  final b = route?.secondaryAnimation;
  if (a != null) out.add(a);
  if (b != null) out.add(b);
  return out;
}

class SecretlyGlassPlate extends StatefulWidget {
  const SecretlyGlassPlate({
    super.key,
    required this.radius,
    required this.child,
    required this.fallback,
    this.thumb,
    this.lift,
    this.padding = EdgeInsets.zero,
  });

  final double radius;
  final Widget child;

  /// Прежняя пластина целиком (с [child] внутри) — когда движок не активен.
  final Widget fallback;

  /// Рамка капли в координатах пластины (с учётом [padding]); `null` — нет.
  final ValueListenable<Rect?>? thumb;

  /// 0..1 — сила линзы капли (во время движения и нажатия).
  final ValueListenable<double>? lift;
  final EdgeInsets padding;

  @override
  State<SecretlyGlassPlate> createState() => _SecretlyGlassPlateState();
}

class _SecretlyGlassPlateState extends State<SecretlyGlassPlate> {
  late final bool _eligible = secretlyGlassEngineEligible;

  /// Всё, что двигает пластину по экрану БЕЗ её перерисовки: прокрутка любого
  /// предка (страница профиля, список, вкладки) и анимация перехода экрана.
  /// Шейдер берёт фон в координатах экрана, поэтому его начало (u_origin)
  /// надо пересчитывать при каждом таком сдвиге — иначе блик и преломление
  /// остаются на месте, а пластина уезжает (профиль собеседника, 23.11).
  Listenable? _reposition;
  List<Listenable> _repositionSources = const [];

  @override
  void initState() {
    super.initState();
    if (!_eligible) return;
    GlassQualityController.ensureStarted();
    if (SecretlyGlassProgram.program == null) {
      unawaited(SecretlyGlassProgram.ensureLoaded());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_eligible) return;
    final sources = repositionSourcesOf(context);
    if (!listEquals(sources, _repositionSources)) {
      _repositionSources = sources;
      _reposition = sources.isEmpty ? null : Listenable.merge(sources);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_eligible) return widget.fallback;
    return ValueListenableBuilder<bool>(
      valueListenable: SecretlyGlassProgram.ready,
      builder: (context, _, _) => ValueListenableBuilder<GlassQuality>(
        valueListenable: GlassQualityController.quality,
        builder: (context, quality, _) {
          if (!secretlyGlassEngineActive) return widget.fallback;
          final dark = Theme.of(context).brightness == Brightness.dark;
          return ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: _GlassBackdrop(
              program: SecretlyGlassProgram.program!,
              radius: widget.radius,
              quality: quality,
              dark: dark,
              dpr: MediaQuery.devicePixelRatioOf(context),
              thumb: widget.thumb,
              lift: widget.lift,
              reposition: _reposition,
              thumbOffset: Offset(widget.padding.left, widget.padding.top),
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          );
        },
      ),
    );
  }
}

class _GlassBackdrop extends SingleChildRenderObjectWidget {
  const _GlassBackdrop({
    required this.program,
    required this.radius,
    required this.quality,
    required this.dark,
    required this.dpr,
    required this.thumb,
    required this.lift,
    required this.reposition,
    required this.thumbOffset,
    required super.child,
  });

  final ui.FragmentProgram program;
  final double radius;
  final GlassQuality quality;
  final bool dark;
  final double dpr;
  final ValueListenable<Rect?>? thumb;
  final ValueListenable<double>? lift;
  final Listenable? reposition;
  final Offset thumbOffset;

  @override
  RenderGlassBackdrop createRenderObject(BuildContext context) =>
      RenderGlassBackdrop(
        shader: program.fragmentShader(),
        radius: radius,
        quality: quality,
        dark: dark,
        dpr: dpr,
        thumb: thumb,
        lift: lift,
        reposition: reposition,
        thumbOffset: thumbOffset,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassBackdrop renderObject,
  ) {
    renderObject
      ..radius = radius
      ..quality = quality
      ..dark = dark
      ..dpr = dpr
      ..thumb = thumb
      ..lift = lift
      ..reposition = reposition
      ..thumbOffset = thumbOffset;
  }
}

/// Рисует фильтр фона с шейдером и ребёнка поверх. Перерисовывается, когда
/// меняется капля или сила линзы, — только числа, без перестройки дерева.
@visibleForTesting
class RenderGlassBackdrop extends RenderProxyBox {
  RenderGlassBackdrop({
    required ui.FragmentShader shader,
    required double radius,
    required GlassQuality quality,
    required bool dark,
    required double dpr,
    required ValueListenable<Rect?>? thumb,
    required ValueListenable<double>? lift,
    Listenable? reposition,
    required Offset thumbOffset,
  }) : _shader = shader,
       _radius = radius,
       _quality = quality,
       _dark = dark,
       _dpr = dpr,
       _thumb = thumb,
       _lift = lift,
       _reposition = reposition,
       _thumbOffset = thumbOffset;

  final ui.FragmentShader _shader;
  final LayerHandle<BackdropFilterLayer> _layer =
      LayerHandle<BackdropFilterLayer>();

  double _radius;
  set radius(double v) {
    if (v == _radius) return;
    _radius = v;
    markNeedsPaint();
  }

  GlassQuality _quality;
  set quality(GlassQuality v) {
    if (v == _quality) return;
    _quality = v;
    markNeedsPaint();
  }

  bool _dark;
  set dark(bool v) {
    if (v == _dark) return;
    _dark = v;
    markNeedsPaint();
  }

  double _dpr;
  set dpr(double v) {
    if (v == _dpr) return;
    _dpr = v;
    markNeedsPaint();
  }

  Offset _thumbOffset;
  set thumbOffset(Offset v) {
    if (v == _thumbOffset) return;
    _thumbOffset = v;
    markNeedsPaint();
  }

  ValueListenable<Rect?>? _thumb;
  set thumb(ValueListenable<Rect?>? v) {
    if (identical(v, _thumb)) return;
    if (attached) _thumb?.removeListener(markNeedsPaint);
    _thumb = v;
    if (attached) _thumb?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  ValueListenable<double>? _lift;
  set lift(ValueListenable<double>? v) {
    if (identical(v, _lift)) return;
    if (attached) _lift?.removeListener(markNeedsPaint);
    _lift = v;
    if (attached) _lift?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Listenable? _reposition;
  set reposition(Listenable? v) {
    if (identical(v, _reposition)) return;
    if (attached) _reposition?.removeListener(_onReposition);
    _reposition = v;
    if (attached) _reposition?.addListener(_onReposition);
    markNeedsPaint();
  }

  /// Прокрутка или переход сдвинули предка — перерисовать с новым началом.
  /// Без сравнения положений: уведомление приходит ДО раскладки кадра, когда
  /// положение на экране ещё прежнее. Стоит одной перерисовки пластины на
  /// кадр и только пока что-то едет (и только там, где движок включён).
  void _onReposition() {
    if (attached) markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _thumb?.addListener(markNeedsPaint);
    _lift?.addListener(markNeedsPaint);
    _reposition?.addListener(_onReposition);
  }

  @override
  void detach() {
    _thumb?.removeListener(markNeedsPaint);
    _lift?.removeListener(markNeedsPaint);
    _reposition?.removeListener(_onReposition);
    super.detach();
  }

  @override
  void dispose() {
    _layer.layer = null;
    _shader.dispose();
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  /// Тинт: белым 2,5 % в тёмной теме (поверх серого), 10 % в светлой — как
  /// у Telegram; плюс лёгкое затемнение в тёмной для читаемости подписей.
  @visibleForTesting
  static List<double> tintFor({required bool dark}) => dark
      ? const [0.16, 0.17, 0.19, 0.38]
      : const [1.0, 1.0, 1.0, 0.42];

  @override
  void paint(PaintingContext context, Offset offset) {
    final s = _dpr;
    final origin = localToGlobal(Offset.zero) * s;
    final t = _thumb?.value;
    final tint = tintFor(dark: _dark);
    var i = 0;
    void f(double v) => _shader.setFloat(i++, v);
    f(0); // u_size.x — задаёт движок
    f(0); // u_size.y
    f(origin.dx);
    f(origin.dy);
    f(size.width * s);
    f(size.height * s);
    f(_radius * s);
    if (t == null || t.isEmpty) {
      f(0);
      f(0);
      f(0);
      f(0);
    } else {
      final r = t.shift(_thumbOffset);
      f(r.left * s);
      f(r.top * s);
      f(r.width * s);
      f(r.height * s);
    }
    f((_lift?.value ?? 0).clamp(0.0, 1.0));
    f(s);
    f(switch (_quality) {
      GlassQuality.full => 3,
      GlassQuality.balanced => 2,
      GlassQuality.edge => 1,
      GlassQuality.flat => 0,
    });
    for (final v in tint) {
      f(v);
    }
    f(_dark ? 1.35 : 1.25); // насыщенность
    final layer = (_layer.layer ??= BackdropFilterLayer())
      ..filter = ui.ImageFilter.shader(_shader);
    context.pushLayer(layer, super.paint, offset);
  }
}
