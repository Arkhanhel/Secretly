// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Заливка своих пузырей, которая принадлежит ЭКРАНУ, а не пузырю.
///
/// **Что было не так.** Каждый свой пузырь красился собственным градиентом от
/// своего верхнего угла к своему нижнему. У пузыря в три строки переход
/// успевал пройти весь путь, у односложного «ок» — тот же путь на высоте в
/// двадцать точек. Десять сообщений подряд читались как десять одинаковых
/// полосок, а не как один сплошной переход, и при прокрутке ничего не менялось:
/// заливка ехала вместе с пузырём.
///
/// **Как должно быть.** Градиент один на всю видимую область: сверху начало,
/// снизу конец. Пузырь берёт из него ровно тот участок, над которым стоит
/// сейчас. При прокрутке участок меняется сам собой — лента едет поверх
/// неподвижной заливки, как витраж перед окном.
///
/// **Почему отдельный render object, а не `BoxDecoration`.** Чтобы взять свой
/// участок, нужно знать, где ты относительно видимой области. Декорации этого
/// не знают: `BoxPainter` получает только смещение внутри своего слоя. Знать
/// это может render object — он умеет спросить своё положение относительно
/// любого предка.
///
/// **Почему нужна отдельная слежка за положением.** У списка сообщений нарочно
/// включены границы перерисовки: каждый пузырь рисует в свой слой, иначе
/// «хаотичное появление пузырей при наборе» (исправлено 18.05.2026), и ломать
/// это нельзя. Но у слоя есть свойство: когда лента едет, он не
/// перерисовывается, а просто сдвигается — заливка уехала бы вместе с пузырём,
/// ровно как раньше.
///
/// 🔴 И подписки на одну прокрутку НЕ ХВАТАЕТ. Мобильная версия за это уже
/// заплатила (поле 01.08.2026): «цвет пузырей не меняется, когда поднимается
/// клавиатура, а отправленное во время набора сообщение получает правильный
/// промежуточный цвет и перестаёт совпадать с соседями». Клавиатура не
/// прокручивает ничего — ленту поднимает отступ, `pixels` не двигается, ни один
/// слушатель не срабатывает, и уже нарисованные пузыри хранят цвет того места,
/// где стояли раньше.
///
/// На десктопе клавиатуры нет, но причина та же и поводов даже больше:
/// растущее в несколько строк поле ввода, панель ответа над ним, смена размера
/// окна. Поэтому сторожим не причину, а СЛЕДСТВИЕ — само положение пузыря
/// относительно видимой области, раз в кадр. Проверка идёт в
/// `addPostFrameCallback`, то есть только в тех кадрах, которые и так
/// рисуются: простаивающее приложение кадров не строит и ничего не стоит.
/// Подписка на прокрутку при этом остаётся — она убирает отставание на кадр в
/// самом частом случае.
class ScreenGradientBox extends SingleChildRenderObjectWidget {
  const ScreenGradientBox({
    super.key,
    required this.colors,
    required this.borderRadius,
    required Widget super.child,
  });

  /// Цвета перехода сверху вниз — те же, что заданы темой для своих пузырей.
  final List<Color> colors;

  /// Форма пузыря. Заливка ложится точно по ней, включая срезанный угол.
  final BorderRadius borderRadius;

  @override
  RenderScreenGradientBox createRenderObject(BuildContext context) {
    return RenderScreenGradientBox(
      colors: colors,
      borderRadius: borderRadius,
      scrollable: Scrollable.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderScreenGradientBox renderObject,
  ) {
    renderObject
      ..colors = colors
      ..borderRadius = borderRadius
      ..scrollable = Scrollable.maybeOf(context);
  }
}

class RenderScreenGradientBox extends RenderProxyBox {
  RenderScreenGradientBox({
    required List<Color> colors,
    required BorderRadius borderRadius,
    required ScrollableState? scrollable,
  })  : _colors = colors,
        _borderRadius = borderRadius {
    _bind(scrollable);
  }

  List<Color> _colors;
  set colors(List<Color> value) {
    if (_sameColors(_colors, value)) return;
    _colors = value;
    markNeedsPaint();
  }

  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (_borderRadius == value) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  ScrollableState? _scrollable;
  ScrollPosition? _position;

  set scrollable(ScrollableState? value) {
    if (identical(_scrollable, value)) return;
    _bind(value);
    markNeedsPaint();
  }

  void _bind(ScrollableState? value) {
    _position?.removeListener(markNeedsPaint);
    _scrollable = value;
    _position = value?.position;
    _position?.addListener(markNeedsPaint);
  }

  /// Положение, по которому заливка нарисована СЕЙЧАС. Если оно разошлось с
  /// настоящим — цвет устарел и пузырь надо перерисовать.
  double? _paintedTop;
  bool _watching = false;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_watching) return;
    _watching = true;
    _scheduleFrameCheck();
  }

  @override
  void detach() {
    _watching = false;
    super.detach();
  }

  /// Перерегистрируется сама, поэтому срабатывает раз в кадр, пока пузырь в
  /// дереве. Кадров не заказывает: если ничего не происходит, её просто не
  /// зовут.
  void _scheduleFrameCheck() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_watching || !attached) {
        _watching = false;
        return;
      }
      final painted = _paintedTop;
      final current = _topInViewport();
      // Полточки — порог против дрожания на дробных координатах.
      if (painted != null && current != null && (current - painted).abs() > 0.5) {
        markNeedsPaint();
      }
      _scheduleFrameCheck();
    });
  }

  /// Насколько верх пузыря ниже верха видимой области, или null, если списка
  /// рядом нет.
  ///
  /// 🔴 Считается НЕ ЧАЩЕ РАЗА В КАДР. За кадр это спрашивают дважды — сначала
  /// отрисовка, потом покадровая проверка, — а каждый вопрос это обход дерева
  /// виджетов вверх до списка. Мобильная версия ловила ровно это в аудите
  /// подтормаживания 03.09.2026: «положение окна прокрутки считается ОДИН РАЗ
  /// ЗА КАДР вместо обхода дерева в каждой поверхности».
  ///
  /// Отметка кадра делает кэш самоочищающимся и не ломает проверку: если в
  /// новом кадре отрисовки не было, проверка приходит с НОВОЙ отметкой, мимо
  /// кэша, и честно видит, что пузырь уехал.
  Duration? _topFrame;
  double? _topCached;

  double? _topInViewport() {
    final frame = SchedulerBinding.instance.currentFrameTimeStamp;
    if (_topFrame == frame) return _topCached;
    _topFrame = frame;
    _topCached = _measureTopInViewport();
    return _topCached;
  }

  double? _measureTopInViewport() {
    final viewport = _scrollable?.context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize || !viewport.attached) {
      return null;
    }
    if (!attached || !hasSize) return null;
    try {
      return localToGlobal(Offset.zero, ancestor: viewport).dy;
    } catch (_) {
      // Предок мог смениться между кадрами — не падаем.
      return null;
    }
  }

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _position?.removeListener(markNeedsPaint);
    _position = null;
    _scrollable = null;
    super.dispose();
  }

  /// Прямоугольник, по которому строится переход.
  ///
  /// Берёт положение пузыря относительно видимой области и передаёт решение
  /// чистому правилу [screenGradientRect]. Если списка рядом нет (пузырь
  /// показан отдельно — в подсказке, в предпросмотре, в тесте), переход
  /// строится по самому пузырю: прежнее поведение, ничего не ломается.
  Rect _gradientRect(Rect bubble) {
    final viewport = _scrollable?.context.findRenderObject();
    final top = _topInViewport();
    if (viewport is! RenderBox || top == null) {
      _paintedTop = null;
      return bubble;
    }
    _paintedTop = top;
    return screenGradientRect(
      bubble: bubble,
      topInViewport: top,
      viewportHeight: viewport.size.height,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final bubble = offset & size;
    if (!bubble.isEmpty && _colors.isNotEmpty) {
      final paint = Paint()
        ..shader = ScreenGradientShaders.of(_colors).shaderFor(
          _gradientRect(bubble),
        );
      context.canvas.drawRRect(_borderRadius.toRRect(bubble), paint);
    }
    // Содержимое — поверх заливки.
    super.paint(context, offset);
  }
}

/// Какой участок общего перехода достаётся пузырю.
///
/// Правило одно: переход строится по прямоугольнику ВЫСОТОЙ С ВИДИМУЮ ОБЛАСТЬ,
/// поднятому так, чтобы его верх совпал с верхом этой области. Пузырь рисует
/// себя по своей форме и тем самым показывает ровно свой кусок — тот, над
/// которым стоит. Пузырь у верхнего края берёт начало перехода, у нижнего —
/// конец, а при прокрутке кусок меняется сам, потому что меняется
/// [topInViewport].
///
/// Отдельная чистая функция, потому что это и есть вся суть правки: остальное
/// — подписка на прокрутку и рисование. Проверять надо именно её.
///
/// [bubble] — рамка пузыря в системе координат холста.
/// [topInViewport] — насколько верх пузыря ниже верха видимой области
/// (отрицательное значение = пузырь частично уехал вверх).
/// [viewportHeight] — высота видимой области.
///
/// Возвращает рамку пузыря без изменений, если высота видимой области
/// невменяемая: лучше прежний вид, чем пустое место.
Rect screenGradientRect({
  required Rect bubble,
  required double topInViewport,
  required double viewportHeight,
}) {
  if (!viewportHeight.isFinite || viewportHeight <= 0) return bubble;
  if (!topInViewport.isFinite) return bubble;
  // Пузырь выше видимой области (длинное сообщение на низком окне) иначе
  // получил бы переход КОРОЧЕ себя, и низ залило бы одним последним цветом.
  final height =
      viewportHeight > bubble.height ? viewportHeight : bubble.height;
  return Rect.fromLTWH(
    bubble.left,
    bubble.top - topInViewport,
    bubble.width,
    height,
  );
}

/// Готовые шейдеры на весь экран: один набор цветов — один переход.
///
/// 🔴 Зачем. Шейдер создавался при КАЖДОЙ отрисовке каждого своего пузыря.
/// Мобильная версия это измерила (аудит подтормаживания 03.09.2026): «за
/// тридцать кадров создавалось триста шейдеров там, где хватает десяти».
///
/// Два уровня. Верхний — по цветам: они берутся из темы и на весь экран
/// одинаковы, поэтому переходов нужно ровно столько, сколько различных
/// сочетаний, обычно один. Ключ включает все цвета по порядку, так что смена
/// темы честно даёт другой переход, а не подсовывает старые цвета.
///
/// Нижний — по прямоугольнику. Он считается от положения пузыря, то есть у
/// каждого свой, и одного слота хватало бы ровно на один пузырь: следующий
/// вытеснял бы предыдущего, и попаданий не случалось бы никогда. Поэтому мест
/// несколько, с вытеснением самых давних.
///
/// Во время прокрутки кэш помогает мало — геометрия меняется каждый кадр,
/// попадать не во что, и это нормально. Он окупается в ПОКОЕ: когда лента
/// стоит, а перерисовки идут (наведение, подсказки, набор текста).
class ScreenGradientShaders {
  ScreenGradientShaders._(List<Color> colors)
      : _gradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        );

  final LinearGradient _gradient;

  static final Map<String, ScreenGradientShaders> _byColors =
      <String, ScreenGradientShaders>{};

  static ScreenGradientShaders of(List<Color> colors) {
    final key = colors.map((c) => c.toARGB32()).join('|');
    return _byColors[key] ??= ScreenGradientShaders._(List<Color>.of(colors));
  }

  /// Ёмкость с запасом: своих пузырей на экране редко больше десятка, а
  /// вытеснение давних не даёт словарю разрастись в кэш на всю переписку.
  static const int _capacity = 24;
  final Map<Rect, Shader> _shaders = <Rect, Shader>{};

  Shader shaderFor(Rect rect) {
    // `remove` + повторная вставка держат свежие в конце: Dart хранит порядок
    // вставки, поэтому первый ключ — самый давний.
    final cached = _shaders.remove(rect);
    if (cached != null) {
      _shaders[rect] = cached;
      return cached;
    }
    final shader = _gradient.createShader(rect);
    if (_shaders.length >= _capacity) {
      _shaders.remove(_shaders.keys.first);
    }
    _shaders[rect] = shader;
    return shader;
  }

  @visibleForTesting
  int get cachedShaderCount => _shaders.length;

  @visibleForTesting
  static int get paletteCount => _byColors.length;

  @visibleForTesting
  static void resetForTest() {
    _byColors.clear();
  }
}
