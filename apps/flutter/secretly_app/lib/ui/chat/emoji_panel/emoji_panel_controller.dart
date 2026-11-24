// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Панель эмодзи на месте клавиатуры: кто открыт — клавиатура или панель, и
/// какой высоты место внизу экрана.
///
/// ☺ ⇄ ⌨ без прыжка ленты: высота панели равна последней настоящей высоте
/// клавиатуры, и пока одна уезжает, другая уже стоит на её месте — нижний
/// отступ ленты и поля ввода (`max(клавиатура, панель)`) не меняется.
///
/// Всё, что меняется на каждом кадре, — в [ValueNotifier]-ах: экран чата
/// `setState` не получает ни разу (слушают только листья-якоря).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'emoji_panel_style.dart';

/// 🔴 Выключатель. `false` — прежний лист `_openEmojiPanel` ровно как был.
const bool kInlineEmojiPanel = true;

/// Высота клавиатуры, если её ещё ни разу не видели: iPhone ~300, Android
/// ~270 плюс нижний системный отступ.
double emojiPanelDefaultHeight({required bool ios, required double safeBottom}) =>
    (ios ? 300.0 : 270.0) + safeBottom;

class EmojiPanelController {
  EmojiPanelController({
    required TickerProvider vsync,
    this.field,
    bool? ios,
    ui.FlutterView? view,
  }) : ios = ios ?? defaultTargetPlatform == TargetPlatform.iOS,
       _view = view {
    _anim = AnimationController(vsync: vsync, duration: _openDuration)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    _metrics = _MetricsObserver(_onMetrics);
    WidgetsBinding.instance.addObserver(_metrics);
    field?.addListener(_onFieldFocus);
    _onMetrics();
  }

  static const Duration _openDuration = Duration(milliseconds: 450);

  /// Поле ввода сообщения: его фокус = клавиатура.
  final FocusNode? field;
  final bool ios;
  final ui.FlutterView? _view;

  late final AnimationController _anim;
  late final _MetricsObserver _metrics;

  /// Панель открыта (☺ показывает ⌨).
  final ValueNotifier<bool> isOpen = ValueNotifier<bool>(false);

  /// Видимая высота панели (анимируется).
  final ValueNotifier<double> height = ValueNotifier<double>(0);

  /// Сколько места внизу должны обойти лента и поле ввода — «вторая
  /// клавиатура». Якорь берёт `max(клавиатура, inset)`.
  final ValueNotifier<double> inset = ValueNotifier<double>(0);

  /// Нынешняя высота клавиатуры.
  final ValueNotifier<double> keyboard = ValueNotifier<double>(0);

  /// Выбранный раздел: 0 эмодзи, 1 стикеры, 2 GIF.
  final ValueNotifier<int> tab = ValueNotifier<int>(0);

  /// Панель раскрыта ручкой выше.
  final ValueNotifier<bool> expanded = ValueNotifier<bool>(false);

  /// Фокус в поиске панели: панель встаёт над клавиатурой, компактная.
  final ValueNotifier<bool> searchFocused = ValueNotifier<bool>(false);

  /// Закрытие панели — недавние эмодзи записываются здесь, а не под пальцем.
  final List<VoidCallback> _flushers = <VoidCallback>[];

  double? _lastKeyboard;
  double _prevKeyboard = 0;
  bool _keyboardRising = false;
  double _from = 0;
  double _to = 0;
  bool _handingToKeyboard = false;
  bool _searchSawKeyboard = false;
  Timer? _handoffTimer;
  bool _disposed = false;

  /// С-16 (22.11.2026): передача панель → клавиатура ждала, пока клавиатура
  /// дорастёт до высоты панели. Раскрытая панель (540) или высота по
  /// умолчанию выше настоящей клавиатуры — условие не выполнялось никогда, и
  /// 0,7 с под полем висела полоса, а потом поле падало. Теперь передача
  /// кончается и тогда, когда клавиатура дошла до прошлой известной высоты
  /// ([_handoffKeyboardTarget]) или перестала расти ([_handoffSettle] —
  /// [handoffSettleDelay] без новых метрик), а панель доезжает до клавиатуры
  /// плавно ([_zeroWhenSettled]).
  double? _handoffKeyboardTarget;
  Timer? _handoffSettle;
  bool _zeroWhenSettled = false;

  /// Сколько клавиатура должна простоять без изменений, чтобы считаться
  /// вставшей (~4 кадра при 60 Гц).
  static const Duration handoffSettleDelay = Duration(milliseconds: 64);

  /// Высота компактной панели над клавиатурой во время поиска.
  static const double searchHeight = 212;

  ui.FlutterView? get _flutterView =>
      _view ?? WidgetsBinding.instance.platformDispatcher.implicitView;

  double get _safeBottom {
    final v = _flutterView;
    if (v == null) return 0;
    return v.viewPadding.bottom / v.devicePixelRatio;
  }

  double get _screenHeight {
    final v = _flutterView;
    if (v == null) return 800;
    return v.physicalSize.height / v.devicePixelRatio;
  }

  double get _safeTop {
    final v = _flutterView;
    if (v == null) return 0;
    return v.viewPadding.top / v.devicePixelRatio;
  }

  /// Обычная высота — как у клавиатуры.
  double get baseHeight {
    final screen = _screenHeight;
    final h =
        _lastKeyboard ??
        emojiPanelDefaultHeight(ios: ios, safeBottom: _safeBottom);
    return h.clamp(220.0, math.max(240.0, screen * .55)).toDouble();
  }

  /// Раскрытая ручкой (макет: 540 из 844).
  double get expandedHeight {
    final screen = _screenHeight;
    final h = math.min(screen * .64, screen - _safeTop - 230);
    return math.max(baseHeight, h);
  }

  double get _target => searchFocused.value
      ? searchHeight
      : (expanded.value ? expandedHeight : baseHeight);

  void addFlusher(VoidCallback f) => _flushers.add(f);
  void removeFlusher(VoidCallback f) => _flushers.remove(f);

  void flushRecents() {
    for (final f in List<VoidCallback>.of(_flushers)) {
      f();
    }
  }

  // ─── Команды ──────────────────────────────────────────────────────────────

  /// ☺ / ⌨ в поле ввода.
  void toggle() {
    if (isOpen.value) {
      showKeyboard();
    } else {
      open();
    }
  }

  /// Открыть панель. Если клавиатура стоит — панель сразу её высоты, без
  /// анимации: клавиатура уезжает, а место внизу не меняется.
  void open({int? tab}) {
    if (tab != null) this.tab.value = tab;
    _handoffTimer?.cancel();
    _handoffSettle?.cancel();
    _handingToKeyboard = false;
    _zeroWhenSettled = false;
    searchFocused.value = false;
    final kb = keyboard.value;
    isOpen.value = true;
    if (kb > 80) {
      _anim.stop();
      _setHeight(math.max(kb, baseHeight));
    } else {
      _animateTo(_target);
    }
    // Клавиатуру убираем ПОСЛЕ того, как панель встала на её место.
    final f = field;
    if (f != null && f.hasFocus) f.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Тап по полю / ⌨: клавиатура въезжает поверх панели, панель уходит,
  /// когда клавиатура встала.
  void showKeyboard() {
    if (!isOpen.value && height.value <= 0) {
      field?.requestFocus();
      return;
    }
    isOpen.value = false;
    expanded.value = false;
    searchFocused.value = false;
    flushRecents();
    _handingToKeyboard = true;
    _handoffKeyboardTarget = _lastKeyboard;
    _handoffTimer?.cancel();
    _handoffSettle?.cancel();
    // Страховка: клавиатура могла не появиться (внешняя, отказ системы).
    _handoffTimer = Timer(const Duration(milliseconds: 700), _finishHandoff);
    final f = field;
    if (f != null && !f.hasFocus) f.requestFocus();
  }

  /// Закрыть совсем (тап по ленте, «назад»).
  void close() {
    if (!isOpen.value && height.value <= 0) return;
    _handoffTimer?.cancel();
    _handoffSettle?.cancel();
    _handingToKeyboard = false;
    isOpen.value = false;
    expanded.value = false;
    if (searchFocused.value) {
      searchFocused.value = false;
      FocusManager.instance.primaryFocus?.unfocus();
    }
    flushRecents();
    _animateTo(0);
  }

  /// Ручка сверху: выше и обратно.
  void toggleExpanded() {
    if (!isOpen.value) return;
    expanded.value = !expanded.value;
    _animateTo(_target);
  }

  /// Поиск в панели получил / потерял фокус.
  void setSearchFocused(bool value) {
    if (searchFocused.value == value || !isOpen.value) return;
    _searchSawKeyboard = false;
    searchFocused.value = value;
    _animateTo(_target, ms: 320);
    _publishInset();
  }

  void selectTab(int index) {
    if (tab.value == index) return;
    flushRecents();
    tab.value = index;
  }

  // ─── Внутреннее ───────────────────────────────────────────────────────────

  void _onFieldFocus() {
    final f = field;
    if (f == null || !f.hasFocus) return;
    if (isOpen.value || height.value > 0) showKeyboard();
  }

  void _onMetrics() {
    if (_disposed) return;
    final v = _flutterView;
    if (v == null) return;
    final kb = v.viewInsets.bottom / v.devicePixelRatio;
    // Запоминаем высоту, пока клавиатура поднимается или стоит после подъёма;
    // на спуске — нет, иначе запомнили бы промежуточный кадр. Направление
    // помним отдельно (22.11.2026): одно и то же значение приходит дважды
    // (повтор метрик), и прежнее `kb >= prev` записывало кадр спуска.
    if (kb > _prevKeyboard + .5) {
      _keyboardRising = true;
    } else if (kb < _prevKeyboard - .5) {
      _keyboardRising = false;
    }
    if (kb > 120 && _keyboardRising) _lastKeyboard = kb;
    _prevKeyboard = kb;
    if (keyboard.value != kb) keyboard.value = kb;
    if (_handingToKeyboard && kb > 0) {
      final target = _handoffKeyboardTarget;
      if (kb >= height.value - 1 || (target != null && kb >= target - 1)) {
        _finishHandoff();
      } else {
        // Клавиатура ниже панели и прошлой высоты не достигла — ждём, пока
        // она перестанет расти (новые метрики перезапускают ожидание).
        _handoffSettle?.cancel();
        if (kb > 120) {
          _handoffSettle = Timer(handoffSettleDelay, _finishHandoff);
        }
      }
    }
    // Поиск в панели: клавиатуру убрали («назад», свернули) — поиск
    // отпускает фокус, панель возвращается к обычной высоте.
    if (searchFocused.value) {
      if (kb > 120) {
        _searchSawKeyboard = true;
      } else if (_searchSawKeyboard && kb < 1) {
        _searchSawKeyboard = false;
        FocusManager.instance.primaryFocus?.unfocus();
      }
    }
    _publishInset();
  }

  void _finishHandoff() {
    _handoffTimer?.cancel();
    _handoffSettle?.cancel();
    if (_disposed || !_handingToKeyboard) return;
    _handingToKeyboard = false;
    if (isOpen.value) return;
    // Клавиатура уже не ниже панели — панель просто исчезает под ней; иначе
    // клавиатура ниже — панель доезжает до её верха и прячется под ней
    // (поле опускается плавно, без падения); клавиатуры нет — опускается.
    final kb = keyboard.value;
    if (kb >= height.value - 1) {
      _anim.stop();
      _setHeight(0);
    } else if (kb > 0) {
      _animateTo(kb, ms: 220);
      if (_anim.isAnimating) {
        _zeroWhenSettled = true;
      } else {
        _setHeight(0);
      }
    } else {
      _animateTo(0, ms: 260);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_zeroWhenSettled) return;
    _zeroWhenSettled = false;
    if (isOpen.value) return;
    _setHeight(0);
  }

  void _animateTo(double target, {int ms = 450}) {
    _zeroWhenSettled = false;
    _from = height.value;
    _to = target;
    if ((_from - _to).abs() < .5) {
      _setHeight(_to);
      return;
    }
    _anim
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0);
  }

  void _onTick() {
    final t = kPanelHeightCurve.transform(_anim.value);
    _setHeight(math.max(0, _from + (_to - _from) * t));
  }

  void _setHeight(double h) {
    if (_disposed) return;
    if (height.value != h) height.value = h;
    _publishInset();
  }

  void _publishInset() {
    if (_disposed) return;
    final h = height.value;
    final next = searchFocused.value ? keyboard.value + h : h;
    if (inset.value != next) inset.value = next;
  }

  /// Нижний отступ панели (над клавиатурой во время поиска).
  double get bottomOffset => searchFocused.value ? keyboard.value : 0;

  void dispose() {
    _disposed = true;
    _handoffTimer?.cancel();
    _handoffSettle?.cancel();
    field?.removeListener(_onFieldFocus);
    WidgetsBinding.instance.removeObserver(_metrics);
    _anim.dispose();
    isOpen.dispose();
    height.dispose();
    inset.dispose();
    keyboard.dispose();
    tab.dispose();
    expanded.dispose();
    searchFocused.dispose();
  }
}

class _MetricsObserver with WidgetsBindingObserver {
  _MetricsObserver(this.onMetrics);

  final VoidCallback onMetrics;

  @override
  void didChangeMetrics() => onMetrics();
}
