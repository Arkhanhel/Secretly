// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Места внутри пузыря, от которых зависит, что делает нажатие мыши.
///
/// Лента узнаёт их проверкой попадания (`MetaData` в пути попадания): с
/// текста начинается выделение ТЕКСТА, у вложения — свои жесты (перемотка
/// голосового, открытие снимка), со всего остального — выделение СООБЩЕНИЙ
/// протягиванием (см. [RowDragSelectRecognizer]).
enum DesktopBubbleZone { text, media }

/// Метка строки ленты: по ней лента узнаёт, над каким сообщением мышь.
@immutable
class DesktopMessageRowTag {
  const DesktopMessageRowTag(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      other is DesktopMessageRowTag && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Выделяемый текст сообщения — как в любом текстовом окне.
///
/// Двойной щелчок выделяет слово, тройной — абзац, протягивание — кусок;
/// курсор над текстом — «палочка»; ⌘C копирует выделенное. Указание
/// владельца 16.09.2026: «создай функцию выделения текста в пузырях двойным
/// нажатием … чтобы было очень удобно».
///
/// 🔴 СИСТЕМНОГО МЕНЮ У ТЕКСТА НЕТ: правой кнопкой открывается меню самого
/// сообщения, и в нём есть «Копировать выделенное». Правый щелчок до текста
/// не доходит вовсе — см. [SecondaryClickArea].
class MessageSelectableText extends StatelessWidget {
  const MessageSelectableText({
    super.key,
    required this.child,
    required this.selectionColor,
    this.onChanged,
  });

  final Widget child;

  /// Цвет выделения. На своём пузыре стандартный цвет темы сливается с
  /// заливкой — поэтому его задаёт пузырь.
  final Color selectionColor;

  /// Выделенный текст; пустая строка — выделения больше нет.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final report = onChanged;
    return MetaData(
      metaData: DesktopBubbleZone.text,
      behavior: HitTestBehavior.translucent,
      child: DefaultSelectionStyle(
        selectionColor: selectionColor,
        mouseCursor: SystemMouseCursors.text,
        child: SelectionArea(
          contextMenuBuilder: null,
          onSelectionChanged: report == null
              ? null
              : (content) => report(content?.plainText ?? ''),
          child: child,
        ),
      ),
    );
  }
}

/// Правый щелчок, который забирает нажатие СРАЗУ.
///
/// 🔴 Выделяемый текст сам слушает правую кнопку и на macOS выделяет слово
/// под курсором: выделенная фраза пропадала бы, не успев попасть в
/// «Копировать выделенное». Этот распознаватель объявляет победу ещё при
/// нажатии, и до текста правый щелчок не доходит. Меню при этом открывается
/// сразу по нажатию — как в самой системе.
class EagerSecondaryClickRecognizer extends OneSequenceGestureRecognizer {
  EagerSecondaryClickRecognizer({super.debugOwner})
    : super(allowedButtonsFilter: _secondaryOnly);

  static bool _secondaryOnly(int buttons) => buttons == kSecondaryButton;

  ValueChanged<Offset>? onSecondaryDown;

  Offset? _downPosition;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      event.buttons == kSecondaryButton &&
      onSecondaryDown != null &&
      super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _downPosition = event.position;
    resolve(GestureDisposition.accepted);
  }

  @override
  void acceptGesture(int pointer) {
    final at = _downPosition;
    _downPosition = null;
    if (at != null) onSecondaryDown?.call(at);
  }

  @override
  void rejectGesture(int pointer) {
    _downPosition = null;
    stopTrackingPointer(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _downPosition = null;
  }

  @override
  String get debugDescription => 'eager secondary click';
}

/// Обёртка для [EagerSecondaryClickRecognizer].
class SecondaryClickArea extends StatelessWidget {
  const SecondaryClickArea({
    super.key,
    required this.onSecondaryClick,
    required this.child,
  });

  final ValueChanged<Offset>? onSecondaryClick;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final callback = onSecondaryClick;
    if (callback == null) return child;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        EagerSecondaryClickRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerSecondaryClickRecognizer>(
              () => EagerSecondaryClickRecognizer(debugOwner: this),
              (r) => r.onSecondaryDown = callback,
            ),
      },
      child: child,
    );
  }
}

/// Выделение сообщений протягиванием — как в телеграме.
///
/// Указание владельца 16.09.2026: «пузыри должны выделяться, если я нажал
/// ЛКМ и даже чуть-чуть провёл на пустом месте от пузыря, и при ведении
/// дальше вверх или вниз также должны выделяться другие».
///
/// Нажатие на ленте (решает [canStart]: не на тексте и не на вложении) и сдвиг
/// мыши хотя бы на [mouseSlop] точки начинают выделение — дальше лента
/// получает каждое положение курсора ([onDragUpdate]). Удержание без движения
/// тоже начинает выделение ([onLongPress]) — так было и раньше. Щелчок без
/// движения отдаётся ленте через [onClick]: в режиме выделения он отмечает
/// строку и забирает нажатие себе, вне режима — возвращает `false`, и нажатие
/// достаётся пузырю (цитата, карточка ссылки, реакция).
///
/// Пальцем лента прокручивается, поэтому протягивание — только мышью; удержание
/// и щелчок работают любым указателем.
class RowDragSelectRecognizer extends OneSequenceGestureRecognizer {
  RowDragSelectRecognizer({super.debugOwner});

  bool Function(Offset globalPosition)? canStart;
  bool Function(Offset globalPosition)? onClick;
  ValueChanged<Offset>? onLongPress;
  ValueChanged<Offset>? onDragStart;
  ValueChanged<Offset>? onDragUpdate;
  VoidCallback? onDragEnd;

  /// «Даже чуть-чуть»: сдвиг, после которого нажатие считается протягиванием.
  static const double mouseSlop = 3;
  static const Duration longPressDelay = Duration(milliseconds: 500);

  int? _pointer;
  PointerDeviceKind? _kind;
  Offset? _down;
  bool _dragging = false;
  bool _longPressed = false;
  Timer? _timer;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_pointer != null) return false;
    if (event.buttons != kPrimaryButton) return false;
    if (!super.isPointerAllowed(event)) return false;
    return canStart?.call(event.position) ?? false;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _pointer = event.pointer;
    _kind = event.kind;
    _down = event.position;
    _timer = Timer(longPressDelay, _onLongPressTimeout);
  }

  void _onLongPressTimeout() {
    _timer = null;
    final down = _down;
    if (_pointer == null || _dragging || down == null) return;
    _longPressed = true;
    resolve(GestureDisposition.accepted);
    onLongPress?.call(down);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    final down = _down;
    if (down == null) return;
    if (event is PointerMoveEvent) {
      if (!_dragging) {
        final moved = (event.position - down).distance;
        if (_kind != PointerDeviceKind.mouse) {
          // Пальцем это прокрутка — отдаём нажатие ленте.
          if (!_longPressed && moved > kTouchSlop) {
            _cancelTimer();
            resolve(GestureDisposition.rejected);
            stopTrackingPointer(event.pointer);
          }
          return;
        }
        if (moved <= mouseSlop) return;
        _dragging = true;
        _cancelTimer();
        resolve(GestureDisposition.accepted);
        onDragStart?.call(down);
      }
      onDragUpdate?.call(event.position);
    } else if (event is PointerUpEvent) {
      _cancelTimer();
      if (_dragging) {
        _dragging = false;
        onDragEnd?.call();
      } else if (!_longPressed) {
        final claimed = onClick?.call(event.position) ?? false;
        resolve(
          claimed ? GestureDisposition.accepted : GestureDisposition.rejected,
        );
      }
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      _cancelTimer();
      if (_dragging) {
        _dragging = false;
        onDragEnd?.call();
      }
      resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    _cancelTimer();
    if (_dragging) {
      _dragging = false;
      onDragEnd?.call();
    }
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _cancelTimer();
    _pointer = null;
    _kind = null;
    _down = null;
    _dragging = false;
    _longPressed = false;
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  String get debugDescription => 'row drag select';
}
