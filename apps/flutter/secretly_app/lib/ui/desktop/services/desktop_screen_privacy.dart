// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Есть ли у сборки компьютера нативная «Защита от снимков экрана»
/// (01.10.2026).
///
/// Канал `secretly/screen_privacy` на компьютере отвечает раннер:
/// `macos/Runner/MainFlutterWindow.swift` (`sharingType = .none` у всех окон)
/// и `windows/runner/screen_privacy.cpp`
/// (`SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)`, запасной
/// `WDA_MONITOR`). У Linux раннера нет вовсе.
///
/// 🔴 `ScreenPrivacy.isSupported` в общем коде — телефонный, и менять его
/// нельзя: телефон выпущен. Поэтому проверка компьютера — своя.
class DesktopScreenPrivacy {
  const DesktopScreenPrivacy._();

  /// 🔴 Площадка подменяема ТОЛЬКО ради проверок: CI идёт на Linux, где
  /// раздела не было бы вовсе.
  @visibleForTesting
  static bool? debugSupported;

  static bool get isSupported =>
      debugSupported ?? (!kIsWeb && (Platform.isMacOS || Platform.isWindows));
}
