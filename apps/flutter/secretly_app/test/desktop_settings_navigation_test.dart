// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Настройки: разделы сгруппированы, а указатели ведут куда обещают.
//
// 🔴 ДВА ДЕФЕКТА, КОТОРЫЕ ЭТОТ ФАЙЛ ДЕРЖИТ ЗАКРЫТЫМИ.
//
// 1. Заголовок группы рисовался всякий раз, когда группа отличалась от
//    предыдущей строки. Один раздел, объявленный не среди своих, давал
//    «ПРИВАТНОСТЬ И БЕЗОПАСНОСТЬ» дважды и «АККАУНТ И ДАННЫЕ» дважды —
//    человек читает это как два разных раздела с одинаковым именем.
//
// 2. Строка «Имя, фото, статус» с шевроном показывала всплывашку «Профиль — в
//    левом нижнем углу, рядом с аватаром», а строка «Устройства» в профиле
//    вместо действия говорила «Настройки → Устройства». Интерфейс объяснял
//    словами то, что должно быть нажатием.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/workspace/workspace_layout.dart';

// Реальное окружение: `WorkspaceLayout` — окно на всю площадь, с полем
// поиска (значит нужен Material) и с прокруткой в боковой колонке.
Widget host(Widget child) => MaterialApp(
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: SizedBox(width: 1100, height: 700, child: child),
        ),
      ),
    );

WorkspaceSection section(String id, String label, String group) =>
    WorkspaceSection(
      id: id,
      icon: Icons.circle,
      label: label,
      group: group,
      builder: (_) => Text('pane-$id'),
    );

void main() {
  _signOutTests();
  _appearanceLinkTests();
  testWidgets('🔴 заголовок группы рисуется ОДИН раз, даже вразнобой',
      (t) async {
    await t.pumpWidget(host(WorkspaceLayout(
      title: 'Настройки',
      sections: [
        section('a', 'Общие', 'Приложение'),
        section('b', 'Безопасность', 'Приватность'),
        // Объявлен не среди своих — ровно тот случай, что ломал панель.
        section('c', 'Резервная копия', 'Аккаунт'),
        section('d', 'Заблокированные', 'Приватность'),
        section('e', 'Хранилище', 'Аккаунт'),
      ],
    )));
    await t.pumpAndSettle();
    expect(find.text('ПРИВАТНОСТЬ'), findsOneWidget);
    expect(find.text('АККАУНТ'), findsOneWidget);
    expect(find.text('ПРИЛОЖЕНИЕ'), findsOneWidget);
  });

  testWidgets('порядок групп — по первому появлению, а не по алфавиту',
      (t) async {
    await t.pumpWidget(host(WorkspaceLayout(
      title: 'Настройки',
      sections: [
        section('a', 'Общие', 'Приложение'),
        section('b', 'Аккаунт', 'Яблоко'),
        section('c', 'Ещё', 'Приложение'),
      ],
    )));
    await t.pumpAndSettle();
    final appY = t.getTopLeft(find.text('ПРИЛОЖЕНИЕ')).dy;
    final appleY = t.getTopLeft(find.text('ЯБЛОКО')).dy;
    expect(appY < appleY, isTrue,
        reason: 'по алфавиту «Яблоко» было бы последним, но порядок задаёт '
            'объявление: «Удалить аккаунт» обязан остаться внизу');
  });

  testWidgets('разделы одной группы стоят подряд под своим заголовком',
      (t) async {
    await t.pumpWidget(host(WorkspaceLayout(
      title: 'Настройки',
      // Открыт «Безопасность»: имя ОТКРЫТОГО раздела печатается ещё и в шапке
      // содержимого, и измерять его положение в боковой колонке нельзя.
      initialIndex: 1,
      sections: [
        section('a', 'Общие', 'Приложение'),
        section('b', 'Безопасность', 'Приватность'),
        section('c', 'Ещё одно', 'Приложение'),
      ],
    )));
    await t.pumpAndSettle();
    final headerY = t.getTopLeft(find.text('ПРИВАТНОСТЬ')).dy;
    expect(t.getTopLeft(find.text('Общие')).dy < headerY, isTrue);
    expect(t.getTopLeft(find.text('Ещё одно')).dy < headerY, isTrue,
        reason: 'второй раздел «Приложения» обязан подняться к первому');
  });

  testWidgets('initialIndex открывает нужный раздел сразу', (t) async {
    await t.pumpWidget(host(WorkspaceLayout(
      title: 'Настройки',
      initialIndex: 2,
      sections: [
        section('a', 'Общие', 'Приложение'),
        section('b', 'Безопасность', 'Приватность'),
        section('c', 'Устройства', 'Приватность'),
      ],
    )));
    await t.pumpAndSettle();
    expect(find.text('pane-c'), findsOneWidget);
  });
}

// 🔴 ВЫХОД ИЗ АККАУНТА БЫЛ В ДВУХ МЕСТАХ С РАЗНЫМИ ТЕКСТАМИ.
//
// «Сессии и устройства» спрашивали материальным AlertDialog («Выйти из
// аккаунта на этом устройстве?») и — единственные — не давали выйти во время
// звонка. «Аккаунт» спрашивал своим DesktopDialog («Выйти из аккаунта?») с
// красной кнопкой, но про идущий звонок не знал. Два текста об одном
// необратимом действии — два разных обещания, и человек не мог знать, какое
// выполнится.
void _signOutTests() {
  test('🔴 выход один, и он знает про идущий звонок', () {
    final src = File(
      'lib/ui/desktop/workspace/settings_workspace.dart',
    ).readAsStringSync();
    expect(
      'Future<void> showSignOutDialog('.allMatches(src).length,
      1,
      reason: 'путь выхода обязан быть ровно один',
    );
    expect(src.contains('_promptSignOut'), isFalse);
    expect(src.contains('Future<void> _logout()'), isFalse);
    final i = src.indexOf('Future<void> showSignOutDialog(');
    final body = src.substring(i, i + 1600);
    expect(
      body.contains('cm.state.value.isActive'),
      isTrue,
      reason: 'проверка звонка жила только в одном из двух путей — она должна '
          'была пережить объединение, а не пропасть вместе с ним',
    );
    expect(body.contains('DButtonKind.danger'), isTrue);
    // Прижат к низу боковой колонки — как в макете.
    expect(src.contains('footer: controller == null'), isTrue);
    final layout = File(
      'lib/ui/desktop/workspace/workspace_layout.dart',
    ).readAsStringSync();
    expect(layout.contains('final Widget? footer;'), isTrue);
  });
}



// 🔴 ПРОФИЛЬ ССЫЛАЕТСЯ НА НАСТРОЙКИ, А НЕ КОПИРУЕТ ИХ.
//
// В макете тема, акцент и рамка стоят на одном экране профиля. Рамка здесь и
// есть — она про ЭТОТ профиль и живёт только тут. А тема и акцент это
// настройки ОКНА, и у них уже есть своё место; поставить те же переключатели
// ещё и в панель значило бы завести один выбор в двух местах — ровно то, за
// что уже убирали подтемы комнаты из списка и второй выход из аккаунта.
void _appearanceLinkTests() {
  test('в профиле ссылка на «Внешний вид», а не вторые органы управления', () {
    final view = File(
      'lib/ui/desktop/chat/details/self_profile_view.dart',
    ).readAsStringSync();
    expect(view.contains('onOpenAppearanceSettings'), isTrue);
    // Строки нет вовсе, если открыть настройки нечем: указатель в никуда
    // хуже отсутствия указателя.
    expect(
      view.contains('if (widget.onOpenAppearanceSettings != null)'),
      isTrue,
    );
    // Вторых переключателей схемы и полосы акцентов в панели НЕТ.
    expect(view.contains('setAppThemePresetId'), isFalse);
    expect(view.contains('DesktopSegmented'), isFalse);

    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    expect(app.contains("_openSettings(sectionId: 'appearance')"), isTrue);
  });
}
