// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 TOUCH ID — ТОЛЬКО ПЕРЕД ГЛАЗАМИ (01.10.2026).
//
// Замок взводится и в спрятанном окне, и пока человек работает в другом
// приложении. Запрос отпечатка всплывал сразу — системным окном поверх чужой
// работы. Теперь он ждёт экрана и фокуса и уходит один раз на замок.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_lock_overlay.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_app_lock_service.dart';

class _CountingLock extends DesktopAppLockService {
  int prompts = 0;

  @override
  Future<bool> requestUnlock({required String reason}) async {
    prompts++;
    return false;
  }
}

void main() {
  late _CountingLock lock;
  late ValueNotifier<bool> focused;
  late ValueNotifier<bool> visible;

  setUp(() {
    lock = _CountingLock();
    focused = ValueNotifier<bool>(false);
    visible = ValueNotifier<bool>(true);
  });

  tearDown(() {
    focused.dispose();
    visible.dispose();
  });

  Future<void> pump(WidgetTester t) => t.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DColors(
            colors: kDColorsDark,
            child: Scaffold(
              // Слой замка — `Positioned.fill`: ему нужен `Stack`.
              body: Stack(
                children: [
                  DesktopLockOverlay(
                    service: lock,
                    windowVisible: visible,
                    windowFocused: focused,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  testWidgets('окно без фокуса — отпечаток не спрашивается', (t) async {
    await pump(t);
    await t.pump();
    expect(lock.prompts, 0);
  });

  testWidgets('вернулись в окно — один запрос, и только один', (t) async {
    await pump(t);
    await t.pump();
    focused.value = true;
    await t.pump();
    expect(lock.prompts, 1);

    // Системное окно отпечатка забирает фокус и возвращает его.
    focused.value = false;
    await t.pump();
    focused.value = true;
    await t.pump();
    expect(lock.prompts, 1, reason: 'один запрос на один замок');
  });

  testWidgets('спрятанное окно в фокусе не считается', (t) async {
    visible.value = false;
    focused.value = true;
    await pump(t);
    await t.pump();
    expect(lock.prompts, 0);

    visible.value = true;
    await t.pump();
    expect(lock.prompts, 1);
  });

  testWidgets('окно уже впереди — запрос сразу, как раньше', (t) async {
    focused.value = true;
    await pump(t);
    await t.pump();
    expect(lock.prompts, 1);
  });
}
