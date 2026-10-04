// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../calls/call_state.dart';
import '../services/desktop_child_windows.dart';
import '../services/desktop_ui_prefs.dart';

/// Вид окна звонка: от него зависят размер и «поверх всех».
enum DesktopDirectCallWindowShape {
  /// Входящий: маленькое окно поверх всех — как у Telegram.
  incoming(Size(380, 208), Size(340, 190)),

  /// Голосовой разговор: портрет собеседника, пульт.
  audio(Size(420, 600), Size(360, 460)),

  /// Видеоразговор: картинка собеседника во всё окно.
  video(Size(960, 620), Size(480, 360));

  const DesktopDirectCallWindowShape(this.size, this.minSize);

  final Size size;
  final Size minSize;
}

/// Звонок один на один — в СВОЁМ окне ОС (29.09.2026, Р1).
///
/// 🔴 Владелец (28.09): «при нажатии на "позвонить" открывалось отдельное окно
/// Windows, не внутри приложения… и я мог его закрепить поверх приложений».
///
/// Одно окно на весь звонок:
/// * входящий — маленькое окно поверх всех, даже когда главное спрятано в
///   трей (раньше всплывашка жила внутри главного окна, и в трее её не было
///   видно);
/// * «Принять» — окно растёт до окна разговора;
/// * исходящий — сразу окно разговора;
/// * звонок кончился — окно закрывается само.
///
/// Нет нативного слоя или ОС отказала — звонок остаётся в главном окне, как
/// раньше ([handles] отвечает `false`).
class DesktopDirectCallWindow {
  DesktopDirectCallWindow({
    required this.builder,
    required this.onCloseRequested,
    this.callActive,
    DesktopChildWindows? windows,
  }) : _windows = windows ?? DesktopChildWindows.instance;

  static const String windowId = 'direct-call';

  /// Содержимое окна — целиком, со своим `MaterialApp` (см.
  /// [DesktopChildWindowSpec.builder]).
  final WidgetBuilder builder;

  /// Крестик окна ОС. Решает хозяин: входящий — отклонить, разговор —
  /// положить трубку (как у Telegram).
  final VoidCallback onCloseRequested;

  /// Идёт ли звонок прямо сейчас — по живому состоянию хозяина. Не задано —
  /// по последней сверке ([sync]).
  final bool Function()? callActive;

  final DesktopChildWindows _windows;

  /// Звонок, для которого окно не открылось: он живёт в главном окне.
  String _failedCallId = '';
  bool _opening = false;
  bool _disposed = false;
  DesktopDirectCallWindowShape? _shape;
  CallState? _latest;
  String _latestTitle = '';

  /// Меняется, когда окно открылось, закрылось или не смогло открыться —
  /// хозяину пора перерисовать главное окно.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  void _changed() {
    if (!_disposed) changes.value++;
  }

  bool get isOpen => _windows.isOpen(windowId);

  DesktopDirectCallWindowShape? get shape => _shape;

  /// Вид окна для этого состояния звонка.
  static DesktopDirectCallWindowShape shapeFor(CallState s) {
    if (s.phase == CallPhase.ringingIncoming) {
      return DesktopDirectCallWindowShape.incoming;
    }
    return s.isVideo
        ? DesktopDirectCallWindowShape.video
        : DesktopDirectCallWindowShape.audio;
  }

  /// Звонок идёт (или звонит) в своём окне — главное окно его не рисует.
  bool handles(CallState s) {
    if (!s.isActive) return false;
    if (!DesktopUiPrefs.callInOwnWindow.value) return false;
    if (_windows.supportedCached != true) return false;
    if (s.callId.isNotEmpty && s.callId == _failedCallId) return false;
    return true;
  }

  /// Сверить окно со звонком. Зовётся на каждом изменении звонка.
  Future<void> sync(CallState s, {required String title}) async {
    if (_disposed) return;
    _latest = s;
    _latestTitle = title;
    if (_opening) return; // по окончании открытия сверимся с последним
    if (!handles(s)) {
      if (isOpen) {
        _shape = null;
        await _windows.close(windowId);
        _changed();
      }
      if (!s.isActive) _failedCallId = '';
      return;
    }
    final shape = shapeFor(s);
    if (!isOpen) {
      _opening = true;
      final ok = await _windows.open(
        DesktopChildWindowSpec(
          id: windowId,
          title: title,
          size: shape.size,
          minSize: shape.minSize,
          topmost: shape == DesktopDirectCallWindowShape.incoming ||
              DesktopUiPrefs.callWindowPinned.value,
          builder: builder,
          onCloseRequested: _onCloseRequested,
        ),
      );
      _opening = false;
      // Выход из приложения во время открытия: окно уже закрыто [dispose].
      if (_disposed) return;
      if (!ok) {
        _failedCallId = s.callId;
        _changed();
        return;
      }
      _shape = shape;
      _changed();
      // Пока окно открывалось, звонок мог уйти дальше: принят, кончился.
      final latest = _latest;
      if (latest != null && !identical(latest, s)) {
        await sync(latest, title: _latestTitle);
      }
      return;
    }
    final previous = _shape;
    if (previous == shape) return;
    _shape = shape;
    // Окно только растёт: разговор, ставший голосовым после видео, не
    // сжимается посреди фразы — человек мог растянуть окно сам.
    final grow = previous == DesktopDirectCallWindowShape.incoming ||
        (previous == DesktopDirectCallWindowShape.audio &&
            shape == DesktopDirectCallWindowShape.video);
    // 🔴 Растёт от середины и в пределах экрана, наименьший размер — от
    // нового вида (29.09.2026, разбор Р1). Раньше рос правый нижний угол:
    // входящий стоит у края экрана, и после «Принять» кнопки разговора
    // уезжали под панель задач; а ужать разговор можно было до 340×190
    // входящего.
    if (grow) {
      await _windows.setSize(windowId, shape.size, minSize: shape.minSize);
    }
    if (previous == DesktopDirectCallWindowShape.incoming) {
      // Входящий висел поверх всех; разговор — как решил человек.
      await _windows.setTopmost(
        windowId,
        DesktopUiPrefs.callWindowPinned.value,
      );
    }
    await _windows.setTitle(windowId, title);
  }

  /// «Поверх всех окон» — кнопка в шапке окна звонка.
  Future<void> togglePin() async {
    final next = !DesktopUiPrefs.callWindowPinned.value;
    await DesktopUiPrefs.setCallWindowPinned(next);
    if (isOpen && _shape != DesktopDirectCallWindowShape.incoming) {
      await _windows.setTopmost(windowId, next);
    }
  }

  Future<void> setFullScreen(bool on) => _windows.setFullScreen(windowId, on);

  /// «Вернуться к звонку» из полосы главного окна.
  Future<void> focus() => _windows.focus(windowId);

  /// Крестик окна ОС. Звонок идёт — решает хозяин ([onCloseRequested]:
  /// отклонить или положить трубку). Звонка уже нет — окно закрывается само:
  /// «положить трубку» без звонка не делает ничего, и окно оставалось бы на
  /// экране без способа его убрать.
  void _onCloseRequested() {
    final active = callActive?.call() ?? (_latest?.isActive ?? false);
    if (active) {
      onCloseRequested();
      return;
    }
    _shape = null;
    unawaited(_windows.close(windowId).then((_) => _changed()));
  }

  /// Закрыть сразу (выход из приложения, перезапуск).
  ///
  /// 🔴 Закрываем, даже если окно ещё открывается: раньше [isOpen] в эту
  /// минуту отвечал «нет», и окно появлялось уже после выхода — без хозяина.
  /// Закрытие отменяет идущее открытие (см. [DesktopChildWindows.close]).
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    changes.dispose();
    await _windows.close(windowId);
  }
}
