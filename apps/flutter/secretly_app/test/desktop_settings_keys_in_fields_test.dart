// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Клавиши окна настроек не отнимают нажатия у полей ввода (30.09.2026).
//
// 🔴 ЧТО БЫЛО. Обработчик окна стоит выше любого поля и слышит нажатие раньше
// правки текста. ↑/↓ в «Поддержке» переключали раздел — панель со всем
// набранным письмом уходила со сцены, и текст пропадал. Esc в том же поле
// закрывал окно целиком — с тем же итогом.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/workspace/workspace_layout.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(
      body: SizedBox(width: 1100, height: 700, child: child),
    ),
  ),
);

/// Раздел с многострочным полем — как письмо в «Поддержке».
WorkspaceSection _withField(String id, String label) => WorkspaceSection(
  id: id,
  icon: Icons.circle,
  label: label,
  builder: (_) => Column(
    children: [
      Text('pane-$id'),
      TextField(key: ValueKey('field-$id'), maxLines: 5, minLines: 3),
    ],
  ),
);

void main() {
  late int closes;

  Future<void> pumpLayout(WidgetTester t) async {
    closes = 0;
    await t.pumpWidget(
      _host(
        WorkspaceLayout(
          title: 'Настройки',
          onClose: () => closes += 1,
          sections: [
            _withField('support', 'Поддержка'),
            _withField('about', 'О программе'),
            _withField('danger', 'Удалить аккаунт'),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('без фокуса в поле стрелки по-прежнему ходят по разделам', (
    t,
  ) async {
    await pumpLayout(t);
    expect(find.text('pane-support'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    expect(find.text('pane-about'), findsOneWidget);
    expect(find.text('pane-support'), findsNothing);
  });

  testWidgets('🔴 ↑/↓ в поле раздела двигают курсор, а не раздел', (t) async {
    await pumpLayout(t);
    await t.enterText(
      find.byKey(const ValueKey('field-support')),
      'Первая строка\nвторая строка',
    );
    await t.pump();

    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();

    expect(find.text('pane-support'), findsOneWidget);
    expect(find.text('pane-about'), findsNothing);
    expect(find.text('Первая строка\nвторая строка'), findsOneWidget);
  });

  testWidgets('🔴 Esc в поле сперва выводит из поля, окно закрывает второй', (
    t,
  ) async {
    await pumpLayout(t);
    await t.enterText(find.byKey(const ValueKey('field-support')), 'письмо');
    await t.pump();

    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(closes, 0, reason: 'первый Esc не закрывает окно с набранным');
    expect(find.text('письмо'), findsOneWidget);

    // Фокус вернулся окну: стрелки снова ходят по разделам, Esc закрывает.
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(closes, 1);
  });

  testWidgets('из поиска стрелки ходят по найденным разделам', (t) async {
    await pumpLayout(t);
    // Поиск — первое поле окна (в боковой колонке).
    await t.enterText(find.byType(TextField).first, 'о');
    await t.pumpAndSettle();
    final before = find.text('pane-support').evaluate().isNotEmpty;
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    final after = find.text('pane-support').evaluate().isNotEmpty;
    expect(before && !after, isTrue, reason: 'стрелка из поиска не сработала');
  });
}
