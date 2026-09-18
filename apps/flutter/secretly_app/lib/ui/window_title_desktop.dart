// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Desktop implementation — only compiled on platforms with dart:io support
import 'package:window_manager/window_manager.dart';

Future<void> initWindowTitleImpl() async {
  await windowManager.ensureInitialized();
  await windowManager.setTitle('Secretly');
}

Future<void> setWindowTitleImpl(String title) async {
  await windowManager.setTitle(title);
}
