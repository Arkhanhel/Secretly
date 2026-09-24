// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Сообщает размер ребёнка после каждой раскладки, в которой он поменялся.
///
/// Нужен островкам, которые плавают над списком: список отступает от края
/// ровно на их высоту, а высота живая — открылась строка поиска по чату,
/// появилась плашка закреплённого, поле ввода стало многострочным. Замер «после
/// перестройки родителя» такие перемены пропускал: островок менялся сам, без
/// родителя, и отступ списка расходился с ним.
///
/// Сообщение уходит после кадра, а не посреди раскладки: вызывающий обычно
/// делает `setState`, а менять дерево во время раскладки нельзя.
class DesktopSizeReporter extends SingleChildRenderObjectWidget {
  const DesktopSizeReporter({super.key, required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderSizeReporter).onSize = onSize;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final s = size;
    if (s == _last) return;
    _last = s;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(s);
    });
  }
}
