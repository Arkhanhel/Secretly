// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// «ОТВЕТИТЬ» И «ПРОЧИТАНО» В ОКОШКЕ УВЕДОМЛЕНИЯ WINDOWS (30.09.2026).
//
// Как у Telegram Desktop: под мышью у окошка — «Ответить», «Прочитано» и
// крестик; «Ответить» превращает текст в поле ответа. Окошко рождается без
// фокуса (не отнимает ввод у того, где человек печатает) — клавиатуру оно
// получает только после «Ответить».

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_notification_windows.dart';

void main() {
  late ValueNotifier<DesktopNotificationCard> card;
  late ValueNotifier<bool> hovered;
  late ValueNotifier<bool> replying;
  late List<String> events;

  setUp(() {
    card = ValueNotifier(const DesktopNotificationCard(
      title: 'Игорь',
      body: 'Привет, ты тут?',
      payload: 'peer-1',
      canAct: true,
    ));
    hovered = ValueNotifier(false);
    replying = ValueNotifier(false);
    events = <String>[];
  });

  Future<void> pump(WidgetTester t, {bool withActions = true}) async {
    t.view.physicalSize = const Size(360, 84);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: DesktopNotificationView(
            card: card,
            hovered: hovered,
            replying: replying,
            onOpen: () => events.add('open'),
            onClose: () => events.add('close'),
            onStartReply: () => events.add('focus'),
            onReply: withActions
                ? (text) async => events.add('reply:$text')
                : null,
            onMarkRead: withActions
                ? () async => events.add('read')
                : null,
          ),
        ),
      ),
    ));
    await t.pump();
  }

  Future<void> hover(WidgetTester t) async {
    final gesture = await t.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(t.getCenter(find.byType(DesktopNotificationView)));
    await t.pumpAndSettle();
  }

  testWidgets('под мышью — «Ответить», «Прочитано», крестик', (t) async {
    await pump(t);
    await hover(t);
    expect(hovered.value, isTrue);
    expect(find.byTooltip('Ответить'), findsOneWidget);
    expect(find.byTooltip('Прочитано'), findsOneWidget);
    expect(find.byTooltip('Закрыть'), findsOneWidget);
  });

  testWidgets('без разрешения на действия — только крестик', (t) async {
    card.value = const DesktopNotificationCard(
      title: 'Secretly',
      body: 'Новое сообщение',
      payload: 'peer-1',
    );
    await pump(t);
    await hover(t);
    expect(find.byTooltip('Ответить'), findsNothing);
    expect(find.byTooltip('Прочитано'), findsNothing);
    expect(find.byTooltip('Закрыть'), findsOneWidget);
  });

  testWidgets('🔴 «Ответить» — окошко берёт фокус, поле ответа, Enter шлёт',
      (t) async {
    await pump(t);
    await hover(t);
    await t.tap(find.byTooltip('Ответить'));
    await t.pumpAndSettle();
    expect(events, contains('focus'));
    expect(replying.value, isTrue);
    expect(find.byType(TextField), findsOneWidget);
    // Текст сообщения уступил место полю — щелчок по окошку в чат не уводит.
    expect(find.text('Привет, ты тут?'), findsNothing);
    await t.enterText(find.byType(TextField), 'Да, сейчас');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pumpAndSettle();
    expect(events, contains('reply:Да, сейчас'));
    expect(events, isNot(contains('open')));
  });

  testWidgets('Esc — передумали отвечать', (t) async {
    await pump(t);
    await hover(t);
    await t.tap(find.byTooltip('Ответить'));
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(replying.value, isFalse);
    expect(find.text('Привет, ты тут?'), findsOneWidget);
  });

  testWidgets('«Прочитано» — отметка без перехода в чат', (t) async {
    await pump(t);
    await hover(t);
    await t.tap(find.byTooltip('Прочитано'));
    await t.pumpAndSettle();
    expect(events, ['read']);
  });

  test('раннер Windows умеет «allowFocus» и снимает «без фокуса»', () {
    final src = File('windows/runner/child_window.cpp').readAsStringSync();
    expect(src.contains('method == "allowFocus"'), isTrue);
    final i = src.indexOf('void SecretlyChildWindow::AllowFocus()');
    expect(i, greaterThan(0));
    final body = src.substring(i, i + 900);
    expect(body.contains('~static_cast<LONG_PTR>(WS_EX_NOACTIVATE)'), isTrue);
    expect(body.contains('SetForegroundWindow'), isTrue);
    expect(body.contains('no_activate_ = false'), isTrue);
  });

  test('служба уведомлений шлёт ответ тем же путём, что баннер macOS', () {
    final src = File(
      'lib/ui/desktop/services/desktop_notification_service.dart',
    ).readAsStringSync();
    expect(src.contains('onReply: withActions ? (text) => _sendReply(payload, text) : null'), isTrue);
    expect(src.contains('await _sendReply(convoId, response.input ??'), isTrue);
  });
}
