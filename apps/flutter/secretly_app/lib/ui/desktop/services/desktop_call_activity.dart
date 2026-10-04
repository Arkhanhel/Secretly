// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';

import '../../../calls/call_manager.dart';
import '../../../rooms/room_call_manager.dart';

/// Идёт ли сейчас звонок — 1:1 или созвон комнаты.
///
/// Нужен проверкам в настройках звонков: пока идёт разговор, они молчат.
/// Проверка микрофона открыла бы тот же микрофон второй раз, превью —
/// камеру, которую держит звонок (на Windows камера открывается только
/// одним), а проверочный сигнал прозвучал бы собеседнику в ухо.
class DesktopCallActivity extends ValueNotifier<bool> {
  DesktopCallActivity() : super(false) {
    _call = CallManager.instance?.state;
    _room = RoomCallManager.instance?.state;
    _call?.addListener(_update);
    _room?.addListener(_update);
    _update();
  }

  ValueListenable<Object?>? _call;
  ValueListenable<Object?>? _room;

  void _update() {
    value = (CallManager.instance?.state.value.isActive ?? false) ||
        (RoomCallManager.instance?.state.value.hasActiveSession ?? false);
  }

  @override
  void dispose() {
    // Менеджеры звонков могут уйти раньше (выход из профиля) вместе со своими
    // уведомителями; отписка от уже закрытого — не повод падать.
    try {
      _call?.removeListener(_update);
    } catch (_) {}
    try {
      _room?.removeListener(_update);
    } catch (_) {}
    super.dispose();
  }
}
