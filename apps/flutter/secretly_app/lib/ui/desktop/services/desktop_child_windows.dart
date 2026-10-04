// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/semantics.dart' show SemanticsBinding;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Второе окно ОС, в котором рисует ТОТ ЖЕ движок (29.09.2026, Р1).
///
/// 🔴 Жалоба владельца: «при нажатии на "позвонить" должно открываться
/// отдельное окно Windows, а не внутри приложения… и я мог его закрепить
/// поверх приложений».
///
/// Почему свой слой, а не готовое:
/// * экспериментальный API окон Flutter 3.41 (`_window.dart`) на stable
///   выключен, а на macOS роняет приложение (`NSAssert(self.viewController ==
///   nil)`);
/// * второй движок не видит текстур первого — видео звонка пришлось бы
///   переносить целиком.
///
/// Здесь окно ОС создаёт раннер (Windows — `child_window.cpp`, macOS —
/// `ChildWindowBridge` в `MainFlutterWindow.swift`), а рисует в него этот же
/// изолят через [ViewAnchor]: одно состояние звонка, общий реестр текстур.
class DesktopChildWindowSpec {
  const DesktopChildWindowSpec({
    required this.id,
    required this.title,
    required this.size,
    required this.builder,
    this.minSize = const Size(320, 240),
    this.topmost = false,
    this.onCloseRequested,
    this.notificationSlot,
  });

  /// Одно окно на [id]: повторное открытие поднимает уже открытое.
  final String id;
  final String title;
  final Size size;
  final Size minSize;
  final bool topmost;

  /// Содержимое окна. Своё окно — свой навигатор и слой всплывающих: иначе
  /// меню и подсказки открывались бы в главном окне. Поэтому корень
  /// содержимого — `MaterialApp`/`WidgetsApp` (см. `DesktopChildWindowApp`).
  final WidgetBuilder builder;

  /// Крестик окна ОС. Нет обработчика — окно просто закрывается.
  final VoidCallback? onCloseRequested;

  /// Окошко уведомления (Windows): без рамки, фокус не забирает, стоит в
  /// правом нижнем углу; номер — место снизу вверх. `null` — обычное окно.
  final int? notificationSlot;
}

class _OpenWindow {
  _OpenWindow(this.spec, this.view);
  final DesktopChildWindowSpec spec;
  final ui.FlutterView view;
}

/// Служба отдельных окон. Одна на приложение.
class DesktopChildWindows extends ChangeNotifier {
  DesktopChildWindows._() {
    _channel.setMethodCallHandler(_onNative);
    SemanticsBinding.instance.addSemanticsEnabledListener(_onSemanticsChanged);
  }

  static final DesktopChildWindows instance = DesktopChildWindows._();

  static const MethodChannel _channel = MethodChannel('secretly/child_window');

  final Map<String, _OpenWindow> _open = <String, _OpenWindow>{};

  /// Ответ раннера, есть ли нативный слой; `null` — ещё не спрашивали.
  bool? _nativeSupported;

  /// Дела каждого окна — по очереди (см. [_serial]).
  final Map<String, Future<void>> _queue = <String, Future<void>>{};

  /// Сколько раз окно просили закрыть. Открытие запоминает число на момент
  /// вызова и, увидев другое, сворачивается, не показав окна.
  final Map<String, int> _closeRequests = <String, int>{};

  /// Площадка — подменяемая: правило macOS ниже иначе не проверялось бы на
  /// CI, где тесты идут на Linux (правило о службах за `Platform.isX`).
  @visibleForTesting
  static String? debugOperatingSystem;

  static String get _os => debugOperatingSystem ?? Platform.operatingSystem;

  /// Сколько ждать кадра окна, прежде чем счесть, что кадров нет (см.
  /// [_awaitFrame]).
  @visibleForTesting
  static Duration frameTimeout = _kFrameTimeout;
  static const Duration _kFrameTimeout = Duration(seconds: 3);

  /// Меняется, когда свои окна становятся можно или нельзя открывать: на
  /// macOS — включили или выключили экранный диктор. Хозяин звонка по нему
  /// сверяется заново — окно уходит, звонок возвращается в главное окно.
  final ValueNotifier<int> availability = ValueNotifier<int>(0);

  bool isOpen(String id) => _open.containsKey(id);

  /// Известно ли уже, есть ли нативный слой: `null` — ещё не спрашивали.
  /// Решения при построении кадра синхронны, поэтому слой опрашивают заранее
  /// ([isSupported] на старте), а до ответа считается, что его нет.
  bool? get supportedCached {
    final known = _nativeSupported;
    if (known == null) return null;
    return known && !_blockedByScreenReader;
  }

  /// 🔴 macOS + ЭКРАННЫЙ ДИКТОР — СВОИХ ОКОН НЕТ (29.09.2026, разбор Р1).
  ///
  /// Движок macOS 3.41 отдаёт ВСЕ обновления семантики главному окну, чьему
  /// бы виду они ни принадлежали (`FlutterEngine.mm`,
  /// `update_semantics_callback2`: «TODO(dkwingsmt): This callback only
  /// supports single-view»). Со вторым видом дерево доступности главного
  /// окна перемешивается с деревом окна звонка — VoiceOver читает чужое и
  /// теряет своё. Поэтому, пока система просит семантику, звонок живёт в
  /// главном окне, как до Р1. Движок Windows разводит семантику по видам —
  /// там запрета нет.
  ///
  /// Флаг — СИСТЕМЫ, а не фреймворка: семантику фреймворка включают и
  /// отладочные инструменты, и сами тесты.
  bool get _blockedByScreenReader =>
      _os == 'macos' &&
      WidgetsBinding.instance.platformDispatcher.semanticsEnabled;

  void _onSemanticsChanged() {
    if (_os == 'macos') availability.value++;
  }

  /// Вид окна [id] — для проверок и самотеста.
  ui.FlutterView? viewOf(String id) => _open[id]?.view;

  /// Есть ли нативный слой. Нет — звонок остаётся внутри главного окна.
  Future<bool> isSupported() async {
    var known = _nativeSupported;
    if (known == null) {
      if (_os != 'windows' && _os != 'macos') {
        known = false;
      } else {
        try {
          known = await _channel.invokeMethod<bool>('isSupported') ?? false;
        } catch (_) {
          known = false;
        }
      }
      _nativeSupported = known;
    }
    return known && !_blockedByScreenReader;
  }

  /// Открыть окно. `false` — окна нет (нет слоя, ОС отказала, окно так и не
  /// получило кадра или его закрыли, пока оно открывалось): вызывающий
  /// показывает то же содержимое внутри главного окна.
  Future<bool> open(DesktopChildWindowSpec spec) {
    final ticket = _closeRequests[spec.id] ?? 0;
    return _serial<bool>(spec.id, () => _openNow(spec, ticket));
  }

  Future<bool> _openNow(DesktopChildWindowSpec spec, int ticket) async {
    final id = spec.id;
    // 🔴 Окно закрыли, пока оно открывалось. Раньше `close` в эту минуту не
    // делал ничего (окна ещё не было в списке), и оно появлялось уже
    // ненужным — без хозяина и без способа уйти.
    bool cancelled() => (_closeRequests[id] ?? 0) != ticket;
    if (_open.containsKey(id)) {
      await focus(id);
      return true;
    }
    if (!await isSupported() || cancelled()) return false;
    int? viewId;
    try {
      viewId = await _channel.invokeMethod<int>('open', <String, Object?>{
        'id': id,
        'title': spec.title,
        'width': spec.size.width,
        'height': spec.size.height,
        'minWidth': spec.minSize.width,
        'minHeight': spec.minSize.height,
        'topmost': spec.topmost,
        'notification': spec.notificationSlot != null,
        'slot': spec.notificationSlot ?? 0,
        'engineId': ui.PlatformDispatcher.instance.engineId,
      });
    } catch (e) {
      debugPrint('child window open failed: $e');
      return false;
    }
    if (viewId == null) return false;
    final view = await _waitForView(viewId);
    if (view == null || cancelled()) {
      if (view == null) {
        debugPrint('child window $viewId never reached the framework');
      }
      await _invoke('close', <String, Object?>{'id': id});
      return false;
    }
    final opened = _OpenWindow(spec, view);
    _open[id] = opened;
    notifyListeners();
    // Окно ОС создано скрытым: показываем после первого кадра, иначе мигнул
    // бы пустой прямоугольник.
    final painted = await _awaitFrame();
    if (!painted || cancelled()) {
      if (!painted) debugPrint('child window $id got no frame in $frameTimeout');
      if (identical(_open[id], opened)) {
        _open.remove(id);
        notifyListeners();
        // Сначала из дерева уходит View, потом окно ОС (см. [close]). Кадров
        // нет — ждать их незачем: рисовать в закрытый вид будет некому.
        if (painted) await _awaitFrame();
      }
      await _invoke('close', <String, Object?>{'id': id});
      return false;
    }
    await _invoke('show', <String, Object?>{'id': id});
    return true;
  }

  /// Дождаться кадра, заказав его принудительно. `false` — кадра не было за
  /// [frameTimeout].
  ///
  /// 🔴 macOS (29.09.2026, разбор Р1): приложение, которого не видно (другой
  /// стол, полноэкранная программа, заблокированный экран), получает
  /// состояние `hidden`, и фреймворк перестаёт заказывать кадры. Простой
  /// `endOfFrame` тогда не наступал НИКОГДА: окно входящего так и не
  /// показывалось, открытие висело, а всплывашка в главном окне и системное
  /// уведомление молчали — звонок числился «в своём окне». Принудительный
  /// кадр рисуется и у скрытого приложения; не пришёл и он — окна нет, и
  /// звонок показывается прежним путём.
  Future<bool> _awaitFrame() async {
    final binding = WidgetsBinding.instance;
    final frame = binding.endOfFrame;
    binding.scheduleForcedFrame();
    try {
      await frame.timeout(frameTimeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  /// Дела одного окна — строго по очереди: открыть и закрыть одно окно не
  /// идут наперегонки. Первое дело начинается сразу, как и раньше;
  /// следующее ждёт, пока закончится предыдущее.
  Future<T> _serial<T>(String id, Future<T> Function() op) {
    final previous = _queue[id];
    final run = previous == null ? op() : previous.then((_) => op());
    final tail = run.then<void>((_) {}, onError: (Object _) {});
    _queue[id] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_queue[id], tail)) _queue.remove(id);
      }),
    );
    return run;
  }

  /// Вид появляется у фреймворка не в тот же миг, что окно у ОС: движок
  /// сообщает о нём отдельным событием.
  Future<ui.FlutterView?> _waitForView(int viewId) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (true) {
      for (final v in ui.PlatformDispatcher.instance.views) {
        if (v.viewId == viewId) return v;
      }
      if (DateTime.now().isAfter(deadline)) return null;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  /// Закрыть окно. Сначала из дерева уходит его `View` — фреймворк не должен
  /// рисовать в вид, которого уже нет, — и только потом окно ОС.
  ///
  /// Окно ещё открывается — открытие сворачивается, не показав его.
  Future<void> close(String id) {
    _closeRequests[id] = (_closeRequests[id] ?? 0) + 1;
    return _serial<void>(id, () => _closeNow(id));
  }

  Future<void> _closeNow(String id) async {
    final o = _open.remove(id);
    if (o == null) return;
    notifyListeners();
    // Кадр — принудительно и не дольше [frameTimeout]: у скрытого приложения
    // обычного кадра не будет, а окно ОС закрыться должно (см. [_awaitFrame]).
    await _awaitFrame();
    await _invoke('close', <String, Object?>{'id': id});
  }

  Future<void> setTopmost(String id, bool on) =>
      _invoke('setTopmost', <String, Object?>{'id': id, 'on': on});

  Future<void> focus(String id) =>
      _invoke('focus', <String, Object?>{'id': id});

  /// Во весь экран — у ЭТОГО окна (без рамки на весь монитор).
  Future<void> setFullScreen(String id, bool on) =>
      _invoke('setFullScreen', <String, Object?>{'id': id, 'on': on});

  /// Окошку уведомления — принимать клавиатуру (нажали «Ответить»).
  /// Остальные окна фокус получают и так; на macOS своих окошек нет.
  Future<void> allowFocus(String id) =>
      _invoke('allowFocus', <String, Object?>{'id': id});

  /// Свернуть окно ОС.
  Future<void> minimize(String id) =>
      _invoke('minimize', <String, Object?>{'id': id});

  /// Переставить окошко уведомления на другое место в углу.
  Future<void> placeAtCorner(String id, int slot) =>
      _invoke('placeAtCorner', <String, Object?>{'id': id, 'slot': slot});

  /// Можно ли сейчас показывать свои окошки уведомлений (Windows).
  ///
  /// 🔴 Своё окошко поверх всех не знало, что Windows просит не беспокоить:
  /// во время презентации, полноэкранной игры или видео и на заблокированном
  /// экране оно выскакивало поверх. Раннер спрашивает систему
  /// (`SHQueryUserNotificationState`); «нет» — показывается системное
  /// уведомление, его Windows придержит сама («Фокусировка внимания»
  /// действует на него). Ответа нет — как раньше.
  Future<bool> acceptsNotifications() async {
    try {
      return await _channel.invokeMethod<bool>('acceptsNotifications') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Звук уведомления системы (Windows) — для своих окошек уведомлений.
  Future<void> playNotificationSound() async {
    try {
      await _channel.invokeMethod<void>('playNotificationSound');
    } catch (_) {}
  }

  Future<void> setTitle(String id, String title) =>
      _invoke('setTitle', <String, Object?>{'id': id, 'title': title});

  /// Размер рабочей области окна и, если окно сменило вид, его наименьший
  /// размер. Окно растёт от своей середины и не выходит за край экрана.
  Future<void> setSize(String id, Size size, {Size? minSize}) => _invoke(
    'setSize',
    <String, Object?>{
      'id': id,
      'width': size.width,
      'height': size.height,
      if (minSize != null) 'minWidth': minSize.width,
      if (minSize != null) 'minHeight': minSize.height,
    },
  );

  Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (e) {
      debugPrint('child window $method failed: $e');
    }
  }

  Future<Object?> _onNative(MethodCall call) async {
    final args = call.arguments is Map ? call.arguments as Map : const {};
    final id = args['id'] as String?;
    if (id == null) return null;
    switch (call.method) {
      case 'closeRequested':
        final o = _open[id];
        if (o == null) {
          // Окна у нас уже нет (или оно ещё открывается), а у ОС есть —
          // закрываем без спроса; идущее открытие свернётся само.
          _closeRequests[id] = (_closeRequests[id] ?? 0) + 1;
          await _invoke('close', <String, Object?>{'id': id});
          return null;
        }
        final cb = o.spec.onCloseRequested;
        if (cb != null) {
          cb();
        } else {
          await close(id);
        }
    }
    return null;
  }

  @visibleForTesting
  void debugReset() {
    _open.clear();
    _queue.clear();
    _closeRequests.clear();
    _nativeSupported = null;
    debugOperatingSystem = null;
    frameTimeout = _kFrameTimeout;
  }
}

/// Рисует открытые отдельные окна. Стоит НАД `MaterialApp` главного окна:
/// у содержимого окна не должно быть чужого навигатора выше — иначе
/// `showGeneralDialog` (он ищет корневой навигатор) открывал бы меню в
/// главном окне.
///
/// 🔴 Форма дерева не меняется, когда окна открываются и закрываются: всегда
/// [ViewAnchor], меняется только его `view`. Иначе главное окно при открытии
/// звонка пересобиралось бы с нуля и теряло состояние.
class DesktopChildWindowHost extends StatelessWidget {
  const DesktopChildWindowHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final windows = DesktopChildWindows.instance;
    return ListenableBuilder(
      listenable: windows,
      child: child,
      builder: (context, main) {
        final open = windows._open.values.toList(growable: false);
        return ViewAnchor(
          view: open.isEmpty
              ? null
              : ViewCollection(
                  views: <Widget>[
                    for (final o in open)
                      View(
                        key: ValueKey<String>('child-window-${o.spec.id}'),
                        view: o.view,
                        child: Builder(builder: o.spec.builder),
                      ),
                  ],
                ),
          child: main!,
        );
      },
    );
  }
}
