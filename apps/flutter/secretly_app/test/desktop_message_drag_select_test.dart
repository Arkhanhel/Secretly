// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ВЫДЕЛЕНИЕ ПРОТЯГИВАНИЕМ И ВЫДЕЛЕНИЕ ТЕКСТА — КАК В ТЕЛЕГРАМЕ.
//
// Указание владельца 16.09.2026: «выделение работает очень криво! Пузыри
// должны выделяться, если я нажал ЛКМ и даже чуть-чуть провёл на пустом месте
// от пузыря, и при ведении дальше вверх или вниз также должны выделяться
// другие. Так же создай функцию выделения текста в пузырях двойным нажатием…
// сразу при наведении мышкой на текст появляется вместо стрелки значок работы
// с текстом».
//
// Было: только удержание на месте, по одному сообщению; текст не выделялся
// вовсе, курсор над пузырём — рука.

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/link_preview_v1.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

MessageData _msg(String id, String text, {bool self = false, int at = 0}) =>
    MessageData(
      id: id,
      payloadId: id,
      authorName: self ? 'Вы' : 'Пётр',
      text: text,
      time: '12:0$at',
      timestampMs: 1757700000000 + at,
      isSelf: self,
      isTextMessage: true,
    );

final _five = <MessageData>[
  _msg('m1', 'Первое сообщение', at: 1),
  _msg('m2', 'Второе сообщение', at: 2),
  _msg('m3', 'Третье сообщение', at: 3),
  _msg('m4', 'Четвёртое сообщение', at: 4),
  _msg('m5', 'Пятое сообщение', at: 5),
];

Future<void> _pump(
  WidgetTester t, {
  List<MessageData>? messages,
  Size size = const Size(1200, 900),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: ChatThreadPanel(
            header: const ChatHeader(name: 'Пётр'),
            isDirect: true,
            messages: messages ?? _five,
            onDeleteMessage: (_) {},
            onForwardMessage: (_) {},
            onSaveMessage: (_) {},
            onForwardMessages: (_) {},
            onSaveMessages: (_) {},
            onDeleteMessages: (_) {},
          ),
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 400));
}

/// Пустое место строки справа от чужого пузыря.
Offset _besideBubble(WidgetTester t, String text) {
  final r = t.getRect(find.textContaining(text));
  return Offset(r.right + 250, r.center.dy);
}

String? _selectedCount(WidgetTester t) {
  final f = find.textContaining('Выбрано: ');
  if (f.evaluate().isEmpty) return null;
  return (f.evaluate().single.widget as Text).data;
}

Future<TestGesture> _mouseDown(WidgetTester t, Offset at) =>
    t.startGesture(at, kind: PointerDeviceKind.mouse);

void main() {
  group('протягивание по пустому месту', () {
    testWidgets('🔴 «даже чуть-чуть» — уже выделение', (t) async {
      await _pump(t);
      final g = await _mouseDown(t, _besideBubble(t, 'Второе'));
      await g.moveBy(const Offset(0, 5));
      await t.pump();
      expect(_selectedCount(t), 'Выбрано: 1');
      await g.up();
      await t.pump();
      // Отпустили — режим остался, отметка на месте.
      expect(_selectedCount(t), 'Выбрано: 1');
    });

    testWidgets('🔴 ведёшь вверх и вниз — отмечается всё между', (t) async {
      await _pump(t);
      final start = _besideBubble(t, 'Второе');
      final g = await _mouseDown(t, start);
      await g.moveTo(_besideBubble(t, 'Четвёртое'));
      await t.pump();
      expect(_selectedCount(t), 'Выбрано: 3');

      // Обратно — лишнее снимается.
      await g.moveTo(_besideBubble(t, 'Третье'));
      await t.pump();
      expect(_selectedCount(t), 'Выбрано: 2');

      // Дальше вверх от начала — отмечаются уже старшие.
      await g.moveTo(_besideBubble(t, 'Первое'));
      await t.pump();
      expect(_selectedCount(t), 'Выбрано: 2');
      await g.up();
      await t.pump();
    });

    testWidgets('курсор ушёл на пузырь — строка всё равно отмечается', (
      t,
    ) async {
      await _pump(t);
      final g = await _mouseDown(t, _besideBubble(t, 'Первое'));
      await g.moveTo(t.getCenter(find.textContaining('Третье')));
      await t.pump();
      expect(_selectedCount(t), 'Выбрано: 3');
      await g.up();
      await t.pump();
    });

    testWidgets('начал на отмеченном — протягивание снимает отметки', (
      t,
    ) async {
      await _pump(t);
      var g = await _mouseDown(t, _besideBubble(t, 'Первое'));
      await g.moveTo(_besideBubble(t, 'Пятое'));
      await t.pump();
      await g.up();
      await t.pump();
      expect(_selectedCount(t), 'Выбрано: 5');

      g = await _mouseDown(t, _besideBubble(t, 'Второе'));
      await g.moveTo(_besideBubble(t, 'Третье'));
      await t.pump();
      await g.up();
      await t.pump();
      expect(_selectedCount(t), 'Выбрано: 3');
    });

    testWidgets('в режиме выделения протягивание идёт и по пузырям', (
      t,
    ) async {
      await _pump(t);
      var g = await _mouseDown(t, _besideBubble(t, 'Первое'));
      await g.moveBy(const Offset(0, 5));
      await g.up();
      await t.pump();
      expect(_selectedCount(t), 'Выбрано: 1');
      // Нажали прямо на текст — в режиме выделения это тоже строка.
      g = await _mouseDown(t, t.getCenter(find.textContaining('Третье')));
      await g.moveTo(t.getCenter(find.textContaining('Пятое')));
      await t.pump();
      await g.up();
      await t.pump();
      expect(_selectedCount(t), 'Выбрано: 4');
    });

    testWidgets('🔴 у края ленты она сама прокручивается и отмечает дальше', (
      t,
    ) async {
      final many = [
        for (var i = 0; i < 40; i++) _msg('x$i', 'Сообщение номер $i', at: 1),
      ];
      await _pump(t, messages: many, size: const Size(1200, 600));
      final state = t.state<ScrollableState>(find.byType(Scrollable).first);
      expect(state.position.pixels, 0);
      final last = _besideBubble(t, 'Сообщение номер 39');
      final g = await _mouseDown(t, last);
      // Ведём выше верхнего края ленты.
      final top = t.getRect(find.byType(ListView)).top;
      await g.moveTo(Offset(last.dx, top - 30));
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(state.position.pixels, greaterThan(0), reason: 'лента стоит');
      final count = int.parse(_selectedCount(t)!.split(' ').last);
      expect(count, greaterThan(8));
      await g.up();
      await t.pump(const Duration(milliseconds: 50));
    });
  });

  group('щелчки и удержание — прежние правила', () {
    testWidgets('короткий щелчок мимо пузыря ничего не выделяет', (t) async {
      await _pump(t);
      final g = await _mouseDown(t, _besideBubble(t, 'Второе'));
      await g.up();
      await t.pump();
      expect(_selectedCount(t), isNull);
    });

    testWidgets('удержание мышью — выделение, дальше можно вести', (t) async {
      await _pump(t);
      final g = await _mouseDown(t, _besideBubble(t, 'Второе'));
      await t.pump(const Duration(milliseconds: 650));
      expect(_selectedCount(t), 'Выбрано: 1');
      await g.moveTo(_besideBubble(t, 'Четвёртое'));
      await t.pump();
      expect(
        _selectedCount(t),
        'Выбрано: 3',
        reason: 'после удержания протягивание должно отмечать, а не снимать',
      );
      await g.up();
      await t.pump();
    });

    testWidgets('🔴 щелчок по карточке ссылки достаётся карточке', (t) async {
      // Протягивание не должно съедать обычные нажатия пузыря: цитату,
      // карточку ссылки, реакцию.
      final launched = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          launched.add('${(call.arguments as Map)['url']}');
          return true;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        ),
      );
      const url = 'https://example.com/post';
      await _pump(
        t,
        messages: [
          _five.first,
          const MessageData(
            id: 'lp',
            payloadId: 'lp',
            authorName: 'Пётр',
            text: 'смотри $url',
            time: '12:09',
            timestampMs: 1757700000009,
            isTextMessage: true,
            linkPreview: LinkPreviewV1(
              url: url,
              siteName: 'example.com',
              title: 'Заголовок карточки',
            ),
          ),
        ],
      );
      final card = t.getCenter(find.text('Заголовок карточки'));

      // Сдвинул — это протягивание: карточка не открывается.
      var g = await _mouseDown(t, card);
      await g.moveBy(const Offset(0, 6));
      await g.up();
      await t.pump(const Duration(milliseconds: 300));
      expect(launched, isEmpty);
      expect(_selectedCount(t), 'Выбрано: 1');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(_selectedCount(t), isNull);

      // Просто щёлкнул — открывается ссылка, выделения нет.
      g = await _mouseDown(t, card);
      await g.up();
      await t.pump(const Duration(milliseconds: 300));
      expect(launched, [url]);
      expect(_selectedCount(t), isNull);
    });
  });

  group('выделение текста', () {
    _macTest('🔴 над текстом — «палочка», над полями пузыря — стрелка', (
      t,
    ) async {
      await _pump(t);
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final text = t.getRect(find.textContaining('Второе'));
      await mouse.moveTo(text.center);
      await t.pump();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.text,
      );
      // Поле пузыря левее текста: там нечего нажимать — не рука.
      await mouse.moveTo(Offset(text.left - 6, text.center.dy));
      await t.pump();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        isNot(SystemMouseCursors.click),
      );
    });

    _macTest('🔴 двойной щелчок выделяет слово, а не сообщения', (t) async {
      final copied = <String>[];
      _mockClipboard(t, copied);
      await _pump(t);
      final at = t.getRect(find.textContaining('Второе')).centerLeft +
          const Offset(12, 0);
      final g = await _mouseDown(t, at);
      await g.up();
      await t.pump(const Duration(milliseconds: 50));
      await g.down(at);
      await g.up();
      await t.pump(const Duration(milliseconds: 300));
      expect(_selectedCount(t), isNull, reason: 'текст ≠ выделение сообщений');

      // ⌘C копирует выделенное слово.
      await t.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyC);
      await t.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await t.pump();
      expect(copied, contains('Второе'));
    });

    _macTest('🔴 правая кнопка по выделенному — «Копировать выделенное»', (
      t,
    ) async {
      final copied = <String>[];
      _mockClipboard(t, copied);
      await _pump(t);
      final rect = t.getRect(find.textContaining('Третье'));
      // Протягиванием по тексту — выделяется текст, не сообщения.
      final g = await _mouseDown(t, rect.centerLeft + const Offset(1, 0));
      await g.moveTo(rect.centerRight - const Offset(1, 0));
      await t.pump();
      await g.up();
      await t.pump(const Duration(milliseconds: 300));
      expect(_selectedCount(t), isNull);

      await t.tapAt(
        rect.center,
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await t.pumpAndSettle();
      expect(find.text('Копировать выделенное'), findsOneWidget);
      expect(find.text('Копировать текст'), findsOneWidget);
      await t.tap(find.text('Копировать выделенное'));
      await t.pumpAndSettle();
      expect(copied.last, 'Третье сообщение');
      // Время в копию не попадает.
      expect(copied.last.contains('12:0'), isFalse);
    });

    _macTest('🔴 живое эмодзи копируется вместе с текстом', (t) async {
      final copied = <String>[];
      _mockClipboard(t, copied);
      await _pump(
        t,
        messages: [
          const MessageData(
            id: 'e1',
            payloadId: 'e1',
            authorName: 'Пётр',
            text: 'Привет 😀 мир',
            time: '12:01',
            timestampMs: 1757700000001,
            isTextMessage: true,
          ),
        ],
      );
      final rect = t.getRect(find.textContaining('Привет'));
      final g = await _mouseDown(t, rect.centerLeft + const Offset(1, 0));
      await g.moveTo(rect.centerRight - const Offset(1, 0));
      await t.pump();
      await g.up();
      await t.pump(const Duration(milliseconds: 300));
      await t.tapAt(
        rect.center,
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Копировать выделенное'));
      await t.pumpAndSettle();
      expect(copied.last, 'Привет 😀 мир');
    });

    _macTest('без выделения пункта «Копировать выделенное» нет', (
      t,
    ) async {
      await _pump(t);
      await t.tapAt(
        t.getCenter(find.textContaining('Третье')),
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await t.pumpAndSettle();
      expect(find.text('Копировать текст'), findsOneWidget);
      expect(find.text('Копировать выделенное'), findsNothing);
    });

    _macTest('Escape и щелчок мимо текста снимают выделение текста', (
      t,
    ) async {
      final copied = <String>[];
      _mockClipboard(t, copied);
      await _pump(t);
      Future<void> selectWord() async {
        final at = t.getRect(find.textContaining('Второе')).centerLeft +
            const Offset(12, 0);
        final g = await _mouseDown(t, at);
        await g.up();
        await t.pump(const Duration(milliseconds: 50));
        await g.down(at);
        await g.up();
        await t.pump(const Duration(milliseconds: 300));
      }

      Future<List<String>> menuItems() async {
        await t.tapAt(
          t.getCenter(find.textContaining('Второе')),
          buttons: kSecondaryButton,
          kind: PointerDeviceKind.mouse,
        );
        await t.pumpAndSettle();
        final items = [
          if (find.text('Копировать выделенное').evaluate().isNotEmpty)
            'выделенное',
        ];
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        return items;
      }

      await selectWord();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(await menuItems(), isEmpty, reason: 'Escape не снял выделение');

      await selectWord();
      final g = await _mouseDown(t, _besideBubble(t, 'Пятое'));
      await g.up();
      await t.pump();
      expect(await menuItems(), isEmpty, reason: 'щелчок мимо не снял');
    });
  });
}

/// Окно владельца — на macOS: там свои клавиши (⌘C) и своё поведение правой
/// кнопки у выделяемого текста.
void _macTest(String name, WidgetTesterCallback body) => testWidgets(
  name,
  body,
  variant: TargetPlatformVariant.only(TargetPlatform.macOS),
);

void _mockClipboard(WidgetTester t, List<String> copied) {
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}
