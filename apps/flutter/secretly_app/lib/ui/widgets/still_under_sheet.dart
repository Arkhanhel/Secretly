// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Страница под листом — неподвижной картинкой (25.11.2026).
///
/// Замер iPhone 14 Pro Max (docs/PICKER_GPU_2026-11-25.md): с открытой
/// скрепкой видеочип был занят на 100 %, кадров не хватало. Из 22 проходов
/// кадра 17 — чат ПОД листом: его стекло, обои и живая рамка рисовались
/// заново каждый кадр, хотя на него никто не смотрит. Под листом чат один раз
/// снимается в картинку, анимации в нём стоят; закрыли лист — снова живой.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Выключатель на случай отката.
const bool kStillUnderSheet = true;

class StillUnderSheetController {
  final SnapshotController _snapshot = SnapshotController();
  final ValueNotifier<bool> _still = ValueNotifier<bool>(false);
  bool _disposed = false;
  Timer? _refreshTimer;

  bool get still => _still.value;

  /// Замереть. Повторный вызов снимает заново (клавиатура успела уйти).
  void freeze() {
    if (!kStillUnderSheet || _disposed) return;
    if (_still.value) {
      _snapshot.clear();
      return;
    }
    _still.value = true;
    // Анимации встают этим же кадром, снимок — с уже стоящей страницы.
    _snapshot.allowSnapshotting = true;
  }

  void thaw() {
    if (_disposed || !_still.value) return;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _still.value = false;
    _snapshot.allowSnapshotting = false;
  }

  /// Содержимое изменилось (пришло сообщение) — снять заново; частые
  /// изменения складываются в один снимок.
  void refresh() {
    if (_disposed || !_still.value) return;
    _refreshTimer ??= Timer(const Duration(milliseconds: 400), () {
      _refreshTimer = null;
      if (!_disposed && _still.value) _snapshot.clear();
    });
  }

  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _snapshot.dispose();
    _still.dispose();
  }
}

class StillUnderSheet extends StatelessWidget {
  const StillUnderSheet({
    super.key,
    required this.controller,
    required this.child,
  });

  final StillUnderSheetController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: controller._still,
    builder: (context, still, child) =>
        TickerMode(enabled: !still, child: child!),
    // Есть platform view — снимок не делается, страница остаётся живой.
    child: SnapshotWidget(
      controller: controller._snapshot,
      mode: SnapshotMode.permissive,
      autoresize: true,
      child: child,
    ),
  );
}
