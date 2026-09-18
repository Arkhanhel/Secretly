// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Conditional window title helper — only active on desktop platforms.
library;

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import: use real window_manager on desktop, stub on other platforms.
import 'window_title_stub.dart'
    if (dart.library.io) 'window_title_desktop.dart';

Future<void> initWindowTitle() async {
  if (kIsWeb) return;
  if (!Platform.isWindows && !Platform.isLinux) return;
  await initWindowTitleImpl();
}

Future<void> updateWindowTitle(int unreadCount) async {
  if (kIsWeb) return;
  if (!Platform.isWindows && !Platform.isLinux) return;
  final title = unreadCount > 0 ? 'Secretly ($unreadCount)' : 'Secretly';
  await setWindowTitleImpl(title);
}
