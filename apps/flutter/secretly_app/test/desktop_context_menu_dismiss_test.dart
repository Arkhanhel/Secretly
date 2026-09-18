// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Меню закрывается ДО того, как выполнится его пункт.
//
// 🔴 Порядок здесь и есть суть.
//
// Было: `Navigator.maybePop()` и сразу вызов действия. Но `maybePop`
// асинхронный — он ждёт разрешения маршрута и снимает его в микрозадаче, уже
// ПОСЛЕ того как действие отработало. Пункт, открывающий окно, успевал его
// открыть первым; снималось тогда окно, а меню оставалось висеть поверх
// интерфейса до следующего щелчка мимо.
//
// Поймать это можно было только пунктом, который что-то ОТКРЫВАЕТ, — а такой
// появился лишь 13.09 («Новый чат»). Все прежние пункты тихо что-то делали и с
// меню не спорили, поэтому дефект дожил до первого же нового пункта.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/context_menu.dart';

Widget _host(void Function(BuildContext) onReady) => MaterialApp(
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: ElevatedButton(
            onPressed: () => onReady(ctx),
            child: const Text('открыть'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('пункт выполняется — меню закрывается', (t) async {
    var ran = 0;
    await t.pumpWidget(
      _host(
        (ctx) => ContextMenu.show(
          ctx,
          globalPosition: const Offset(100, 100),
          sections: [
            [CtxMenuItem(label: 'Сделать', onTap: () => ran++)],
          ],
        ),
      ),
    );
    await t.tap(find.text('открыть'));
    await t.pumpAndSettle();
    expect(find.text('Сделать'), findsOneWidget);

    await t.tap(find.text('Сделать'));
    await t.pumpAndSettle();

    expect(ran, 1);
    expect(find.text('Сделать'), findsNothing);
  });

  testWidgets('🔴 пункт открывает окно — меню НЕ остаётся под ним', (t) async {
    // Ровно тот случай, на котором дефект и проявился.
    var opened = false;
    await t.pumpWidget(
      _host(
        (ctx) => ContextMenu.show(
          ctx,
          globalPosition: const Offset(100, 100),
          sections: [
            [
              CtxMenuItem(
                label: 'Новый чат',
                onTap: () {
                  opened = true;
                  showDialog<void>(
                    context: ctx,
                    builder: (_) =>
                        const AlertDialog(content: Text('окно выбора')),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
    await t.tap(find.text('открыть'));
    await t.pumpAndSettle();

    await t.tap(find.text('Новый чат'));
    await t.pumpAndSettle();

    expect(opened, isTrue);
    expect(find.text('окно выбора'), findsOneWidget, reason: 'окно открылось');
    expect(
      find.text('Новый чат'),
      findsNothing,
      reason:
          'меню обязано было уйти ПЕРЕД тем, как открылось окно — иначе '
          'оно висит поверх интерфейса до щелчка мимо',
    );
  });

  testWidgets('выключенный пункт не делает ничего и меню не закрывает', (
    t,
  ) async {
    var ran = 0;
    await t.pumpWidget(
      _host(
        (ctx) => ContextMenu.show(
          ctx,
          globalPosition: const Offset(100, 100),
          sections: [
            [CtxMenuItem(label: 'Нельзя', enabled: false, onTap: () => ran++)],
          ],
        ),
      ),
    );
    await t.tap(find.text('открыть'));
    await t.pumpAndSettle();

    await t.tap(find.text('Нельзя'));
    await t.pumpAndSettle();

    expect(ran, 0);
    expect(find.text('Нельзя'), findsOneWidget);
  });
}
