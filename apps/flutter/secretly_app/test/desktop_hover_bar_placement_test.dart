// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 СТРОКА ДЕЙСТВИЙ — ЦЕЛИКОМ НАД ПУЗЫРЁМ, И ЕЁ МОЖНО ВЫКЛЮЧИТЬ.
//
// Указание владельца 16.09.2026:
//   «при наведении на пузырь высвечивается мини меню! Во-первых, оно должно
//    высвечиваться сразу над пузырём, а не перекрывать его частично,
//    во-вторых, добавь в „Настройках“, чтобы можно было выключить меню при
//    наведении на пузыри. Так же … кнопку „Продолжить в другой теме“ …
//    нужно добавить так же при нажатии правой клавишей на пузыри».
//
// И ещё одно из того же сообщения: в профиле зелёная точка «в сети» на фото
// повторяла подпись «в сети» строкой ниже.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/l10n/app_localizations_ru.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/chat/message_context_menu.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _msg = MessageData(
  id: 'm1',
  payloadId: 'p1',
  authorName: 'Игорь',
  text: 'привет',
  time: '14:19',
);

Future<void> _hover(WidgetTester t) async {
  final g = await t.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: Offset.zero);
  addTearDown(g.removePointer);
  await g.moveTo(t.getCenter(find.textContaining(_msg.text)));
  await t.pumpAndSettle();
}

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 120),
        child: SizedBox(width: 760, child: child),
      ),
    ),
  ),
);

void main() {
  setUp(() {
    // Без подменного хранилища запись настройки ждёт ответа платформы вечно.
    SharedPreferences.setMockInitialValues({});
    DesktopUiPrefs.resetForTest();
  });
  tearDown(DesktopUiPrefs.resetForTest);

  testWidgets('🔴 строка стоит НАД пузырём и не закрывает его', (t) async {
    await t.pumpWidget(
      _host(MessageBubble(message: _msg, onReply: () {}, onReact: (_) {})),
    );
    await _hover(t);
    final reply = find.byIcon(FluentIcons.arrow_reply_24_regular);
    expect(reply, findsOneWidget);

    // Верх пузыря — над именем автора его верхнее поле (10); строка — целиком
    // выше.
    final bubbleTop = t.getRect(find.text('Игорь')).top - 10;
    final barBottom = t.getRect(reply).bottom;
    expect(
      barBottom,
      lessThanOrEqualTo(bubbleTop),
      reason: 'строка снова надвинута на пузырь',
    );
    // …но рядом, а не где-то вверху окна (зазор 4 и поле самой строки).
    expect(bubbleTop - barBottom, lessThan(16));
  });

  testWidgets('🔴 выключенная в настройках строка не всплывает', (t) async {
    await DesktopUiPrefs.setMessageHoverBar(false);
    await t.pumpWidget(
      _host(MessageBubble(message: _msg, onReply: () {}, onReact: (_) {})),
    );
    await _hover(t);
    expect(find.byIcon(FluentIcons.arrow_reply_24_regular), findsNothing);
  });

  testWidgets('включённая обратно — снова всплывает', (t) async {
    await DesktopUiPrefs.setMessageHoverBar(false);
    await DesktopUiPrefs.setMessageHoverBar(true);
    await t.pumpWidget(
      _host(MessageBubble(message: _msg, onReply: () {}, onReact: (_) {})),
    );
    await _hover(t);
    expect(find.byIcon(FluentIcons.arrow_reply_24_regular), findsOneWidget);
  });

  test('🔴 «Продолжить в теме» есть и в меню правой кнопки', () {
    var picked = 0;
    final sections = MessageContextMenu.sections(
        l10n: AppLocalizationsRu(),
      isSelf: false,
      canEdit: false,
      canDelete: true,
      canPin: true,
      onContinueInTopic: () => picked++,
    );
    final items = [for (final s in sections) ...s];
    final item = items.where((i) => i.label == 'Продолжить в теме');
    expect(item, hasLength(1));
    item.single.onTap!();
    expect(picked, 1);

    // Без обработчика — пункта нет (правило окна: без действия нет кнопки).
    final bare = MessageContextMenu.sections(
        l10n: AppLocalizationsRu(),
      isSelf: false,
      canEdit: false,
      canDelete: true,
      canPin: true,
    );
    expect(
      [for (final s in bare) ...s].any((i) => i.label == 'Продолжить в теме'),
      isFalse,
    );
  });

  test('лента передаёт «Продолжить в теме» в меню правой кнопки', () {
    final panel = File(
      'lib/ui/desktop/chat/chat_thread_panel.dart',
    ).readAsStringSync();
    expect(
      panel.contains('_continueInTopic(m, globalPos)'),
      isTrue,
      reason: 'пункт меню не подключён',
    );
  });

  test('настройка есть в «Общих» и сохраняется', () {
    final settings = File(
      'lib/ui/desktop/workspace/settings_workspace.dart',
    ).readAsStringSync();
    // 19.09.2026: подписи настроек уехали в переводы.
    expect(settings.contains('l10n.desktopGeneralHoverMenu'), isTrue);
    expect(settings.contains('DesktopUiPrefs.setMessageHoverBar(v)'), isTrue);
    final prefs = File(
      'lib/ui/desktop/services/desktop_ui_prefs.dart',
    ).readAsStringSync();
    expect(prefs.contains("'desktop_message_hover_bar_v1'"), isTrue);
    expect(prefs.contains('prefs.getBool(_kHoverBar) ?? true'), isTrue);
  });

  test('🔴 на фото в профиле нет зелёной точки — «в сети» написано ниже', () {
    for (final path in [
      'lib/ui/desktop/chat/details/contact_details_view.dart',
      'lib/ui/desktop/chat/details/member_profile_card.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('online: false,'), isTrue, reason: path);
      expect(src.contains('desktopChatsOnline'), isTrue, reason: path);
    }
  });
}
