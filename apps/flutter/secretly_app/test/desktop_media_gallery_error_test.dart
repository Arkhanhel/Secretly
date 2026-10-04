// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ГАЛЕРЕЯ ПОДРОБНОСТЕЙ: ОШИБКА — НЕ ВЕЧНЫЙ КРУЖОК (01.10.2026).
//
// Сорвавшаяся загрузка вложений оставляла галерею крутить кружок бесконечно.
// Теперь — объяснение и «Повторить», который действительно перечитывает.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/details/desktop_media_gallery.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

class _FlakyController extends AppController {
  int calls = 0;
  bool fail = true;

  @override
  Future<List<ChatEvent>> loadEventsAll(
    String convoId, {
    int limit = 5000,
  }) async {
    calls++;
    if (fail) throw StateError('база заперта');
    return const <ChatEvent>[];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ошибка — объяснение и «Повторить», а не кружок', (t) async {
    final ctrl = _FlakyController();
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: DesktopMediaGallery(controller: ctrl, convoId: 'c1'),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Не удалось загрузить вложения'), findsOneWidget);
    expect(ctrl.calls, 1);

    ctrl.fail = false;
    await t.tap(find.text('Повторить'));
    await t.pump();
    await t.pump();

    expect(ctrl.calls, 2, reason: '«Повторить» перечитывает по-настоящему');
    expect(find.text('Не удалось загрузить вложения'), findsNothing);
  });
}
