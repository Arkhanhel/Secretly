// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 КАРТОЧКА ССЫЛКИ НА КОМПЬЮТЕРЕ — И ТЕЛЕФОН НЕ ХОДИТ ПО ЧУЖИМ ССЫЛКАМ.
//
// Решение владельца 16.09.2026 («делать сразу третий вариант»): превью
// готовит отправитель. Поле ввода грузит страницу, пока человек пишет, и
// показывает карточку над собой; на отправке карточка уходит в сообщении.
// Получатель в сеть не ходит вовсе.
//
// Здесь закреплено поведение черновика превью, карточка в пузыре, карточка
// над полем ввода, выключатель в настройках и правило телефона.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/links/link_preview_draft.dart';
import 'package:secretly_app/models/link_preview_v1.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/chat/link_preview_card.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _url = 'https://example.com/post';

LinkPreviewV1 _card(String url, {String title = 'Заголовок', Uint8List? thumb}) =>
    LinkPreviewV1(
      url: url,
      siteName: 'example.com',
      title: title,
      description: 'Описание страницы',
      thumbnail: thumb,
    );

Uint8List _jpeg() {
  final image = img.Image(width: 64, height: 36);
  img.fill(image, color: img.ColorRgb8(200, 60, 60));
  return Uint8List.fromList(img.encodeJpg(image));
}

/// Загрузчик, которым управляет тест.
class _Loader {
  final calls = <Uri>[];
  final pending = <String, Completer<LinkPreviewV1?>>{};

  Future<LinkPreviewV1?> call(Uri uri) {
    calls.add(uri);
    return (pending[uri.toString()] = Completer<LinkPreviewV1?>()).future;
  }

  void complete(String url, LinkPreviewV1? value) =>
      pending.remove(url)!.complete(value);
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  group('черновик превью в поле ввода', () {
    late _Loader loader;
    late OutgoingLinkPreviewDraft draft;

    setUp(() {
      loader = _Loader();
      draft = OutgoingLinkPreviewDraft(
        loader: loader.call,
        debounce: const Duration(milliseconds: 5),
      );
    });
    tearDown(() => draft.dispose());

    test('ссылка → грузится → карточка уходит с тем же текстом', () async {
      draft.update('смотри $_url');
      // Пока человек не сделал паузу — ни загрузки, ни полоски.
      expect(draft.loading, isFalse);
      expect(draft.preview, isNull);
      await _settle();
      expect(draft.loading, isTrue);
      expect(loader.calls.single.toString(), _url);
      loader.complete(_url, _card(_url));
      await _settle();
      expect(draft.loading, isFalse);
      expect(draft.preview?.title, 'Заголовок');
      expect(draft.takeFor('смотри $_url')?.url, _url);
      // Ссылку заменили — чужая карточка к новому тексту не уходит.
      expect(draft.takeFor('смотри https://other.example/x'), isNull);
    });

    test('пока человек печатает, страница не грузится', () async {
      draft.update('https://exa');
      draft.update('https://example.co');
      draft.update('https://example.com/post');
      await _settle();
      expect(loader.calls.map((u) => u.toString()), [_url]);
    });

    test('🔴 ответ от прежней ссылки не показывается у новой', () async {
      draft.update('https://first.example/a');
      await _settle();
      draft.update('https://second.example/b');
      loader.complete('https://first.example/a', _card('https://first.example/a'));
      await _settle();
      expect(draft.target.toString(), 'https://second.example/b');
      expect(draft.preview, isNull);
      expect(draft.loading, isTrue, reason: 'вторая ещё грузится');
      // Первая при этом запомнена: вернулись к ней — карточка сразу.
      draft.update('https://first.example/a');
      expect(draft.preview?.url, 'https://first.example/a');
      expect(draft.loading, isFalse);
    });

    test('крестик убирает карточку из ЭТОГО сообщения', () async {
      draft.update(_url);
      await _settle();
      loader.complete(_url, _card(_url));
      await _settle();
      draft.dismiss();
      expect(draft.preview, isNull);
      expect(draft.takeFor(_url), isNull);
      // Следующее сообщение с той же ссылкой — карточка снова предложена.
      draft.reset();
      draft.update(_url);
      expect(draft.preview?.url, _url);
      expect(draft.takeFor(_url)?.url, _url);
    });

    test('неудача не запоминается: та же ссылка потом грузится снова', () async {
      draft.update(_url);
      await _settle();
      loader.complete(_url, null);
      await _settle();
      expect(draft.loading, isFalse);
      expect(draft.preview, isNull);
      draft.update('');
      draft.update(_url);
      await _settle();
      expect(loader.calls, hasLength(2));
    });

    test('карточка от другого адреса не принимается', () async {
      draft.update(_url);
      await _settle();
      loader.complete(_url, _card('https://evil.example/'));
      await _settle();
      expect(draft.preview, isNull);
      expect(draft.takeFor(_url), isNull);
    });
  });

  group('кэш превью своих сообщений', () {
    test('одна загрузка на много пузырей, неудача не долбит сеть', () async {
      final loader = _Loader();
      final cache = LinkPreviewMemoryCache(loader: loader.call);
      final a = cache.get(Uri.parse(_url));
      final b = cache.get(Uri.parse(_url));
      expect(loader.calls, hasLength(1));
      loader.complete(_url, _card(_url));
      expect((await a)?.url, _url);
      expect((await b)?.url, _url);
      expect(cache.peek(Uri.parse(_url))?.title, 'Заголовок');

      const bad = 'https://bad.example/';
      final c = cache.get(Uri.parse(bad));
      loader.complete(bad, null);
      expect(await c, isNull);
      expect(await cache.get(Uri.parse(bad)), isNull);
      expect(loader.calls, hasLength(2), reason: 'неудачу повторили сразу');
    });
  });

  group('карточка в пузыре', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DesktopUiPrefs.resetForTest();
    });
    tearDown(() {
      DesktopUiPrefs.resetForTest();
      LinkPreviewMemoryCache.resetInstance();
    });

    Widget host(MessageData m) => MaterialApp(
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 760, child: MessageBubble(message: m)),
          ),
        ),
      ),
    );

    testWidgets('🔴 приехавшая карточка видна, время — под ней', (t) async {
      await t.pumpWidget(
        host(
          MessageData(
            id: 'm1',
            authorName: 'Игорь',
            text: 'смотри $_url',
            time: '14:19',
            isTextMessage: true,
            linkPreview: _card(_url, thumb: _jpeg()),
          ),
        ),
      );
      await t.pump();
      expect(find.byType(DesktopLinkPreviewCard), findsOneWidget);
      expect(find.text('example.com'), findsOneWidget);
      expect(find.text('Заголовок'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DesktopLinkPreviewCard),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      // Куда ведёт карточка — видно по наведению.
      expect(find.byTooltip(_url), findsOneWidget);
      final card = t.getRect(find.byType(DesktopLinkPreviewCard));
      final time = t.getRect(find.text('14:19'));
      expect(time.top, greaterThanOrEqualTo(card.bottom - 1));
    });

    testWidgets('🔴 чужое сообщение без карточки ничего не грузит', (t) async {
      final loader = _Loader();
      LinkPreviewMemoryCache.instance = LinkPreviewMemoryCache(
        loader: loader.call,
      );
      await t.pumpWidget(
        host(
          const MessageData(
            id: 'm1',
            authorName: 'Игорь',
            text: 'смотри $_url',
            time: '14:19',
            isTextMessage: true,
          ),
        ),
      );
      await t.pump();
      expect(find.byType(DesktopLinkPreviewCard), findsNothing);
      expect(find.byType(DesktopOwnLinkPreview), findsNothing);
      expect(loader.calls, isEmpty);
    });

    testWidgets('своё прежнее сообщение получает карточку загрузкой', (
      t,
    ) async {
      final loader = _Loader();
      LinkPreviewMemoryCache.instance = LinkPreviewMemoryCache(
        loader: loader.call,
      );
      await t.pumpWidget(
        host(
          MessageData(
            id: 'm1',
            authorName: 'Вы',
            text: 'смотри $_url',
            time: '14:19',
            isSelf: true,
            isTextMessage: true,
            ownLinkPreviewTarget: Uri.parse(_url),
          ),
        ),
      );
      expect(loader.calls, hasLength(1));
      expect(find.byType(DesktopLinkPreviewCard), findsNothing);
      loader.complete(_url, _card(_url));
      await t.pump();
      await t.pump();
      expect(find.byType(DesktopLinkPreviewCard), findsOneWidget);
    });

    testWidgets('🔴 выключенные превью — и своё не грузится', (t) async {
      final loader = _Loader();
      LinkPreviewMemoryCache.instance = LinkPreviewMemoryCache(
        loader: loader.call,
      );
      await DesktopUiPrefs.setLinkPreviews(false);
      await t.pumpWidget(
        host(
          MessageData(
            id: 'm1',
            authorName: 'Вы',
            text: 'смотри $_url',
            time: '14:19',
            isSelf: true,
            isTextMessage: true,
            ownLinkPreviewTarget: Uri.parse(_url),
          ),
        ),
      );
      await t.pump();
      expect(loader.calls, isEmpty);
      expect(find.byType(DesktopLinkPreviewCard), findsNothing);
    });
  });

  group('карточка над полем ввода', () {
    late _Loader loader;
    late OutgoingLinkPreviewDraft draft;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DesktopUiPrefs.resetForTest();
      loader = _Loader();
      draft = OutgoingLinkPreviewDraft(
        loader: loader.call,
        debounce: const Duration(milliseconds: 5),
      );
    });

    Future<List<DesktopComposerSubmission>> pump(WidgetTester t) async {
      t.view.physicalSize = const Size(1200, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final sent = <DesktopComposerSubmission>[];
      await t.pumpWidget(
        MaterialApp(
          home: DColors(
            colors: kDColorsDark,
            child: Scaffold(
              body: ChatThreadPanel(
                header: const ChatHeader(name: 'Пётр'),
                isDirect: true,
                messages: const <MessageData>[],
                onSend: sent.add,
                linkPreviewDraft: draft,
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
      return sent;
    }

    Future<void> type(WidgetTester t, String text) async {
      await t.enterText(find.byType(TextField).last, text);
      await t.pump(const Duration(milliseconds: 20));
    }

    Future<void> send(WidgetTester t) async {
      await t.tap(
        find.byTooltip('Отправить · Enter\nПравая кнопка — отправить позже'),
      );
      await t.pump(const Duration(milliseconds: 50));
    }

    testWidgets('🔴 карточка появляется и уходит вместе с сообщением', (
      t,
    ) async {
      final sent = await pump(t);
      await type(t, 'смотри $_url');
      expect(find.text('Превью ссылки…'), findsOneWidget);
      expect(loader.calls, hasLength(1));
      loader.complete(_url, _card(_url));
      await t.pump();
      expect(find.byType(DesktopLinkPreviewDraftBar), findsOneWidget);
      expect(find.text('Заголовок'), findsOneWidget);

      await send(t);
      expect(sent.single.text, 'смотри $_url');
      expect(sent.single.linkPreview?.url, _url);
      // Поле пусто — карточки нет.
      expect(find.text('Заголовок'), findsNothing);
    });

    testWidgets('🔴 закрытая крестиком карточка не уходит', (t) async {
      final sent = await pump(t);
      await type(t, _url);
      loader.complete(_url, _card(_url));
      await t.pump();
      await t.tap(find.byTooltip('Без превью'));
      await t.pump();
      expect(find.text('Заголовок'), findsNothing);
      await send(t);
      expect(sent.single.linkPreview, isNull);
    });

    testWidgets('не успела загрузиться — сообщение не ждёт', (t) async {
      final sent = await pump(t);
      await type(t, _url);
      await send(t);
      expect(sent, hasLength(1));
      expect(sent.single.linkPreview, isNull);
    });

    testWidgets('без черновика (выключено в настройках) — ни карточки, ни '
        'загрузки', (t) async {
      final sent = <DesktopComposerSubmission>[];
      await t.pumpWidget(
        MaterialApp(
          home: DColors(
            colors: kDColorsDark,
            child: Scaffold(
              body: ChatThreadPanel(
                header: const ChatHeader(name: 'Пётр'),
                isDirect: true,
                messages: const <MessageData>[],
                onSend: sent.add,
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
      await type(t, _url);
      expect(find.byType(DesktopLinkPreviewDraftBar), findsNothing);
      expect(loader.calls, isEmpty);
      await send(t);
      expect(sent.single.linkPreview, isNull);
    });
  });

  group('настройка и правила (по исходникам)', () {
    test('«Превью ссылок» есть в настройках и сохраняется', () async {
      SharedPreferences.setMockInitialValues({});
      DesktopUiPrefs.resetForTest();
      await DesktopUiPrefs.setLinkPreviews(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('desktop_link_previews_v1'), isFalse);
      DesktopUiPrefs.resetForTest();

      final settings = File(
        'lib/ui/desktop/workspace/settings_workspace.dart',
      ).readAsStringSync();
      expect(settings.contains("label: 'Превью ссылок'"), isTrue);
      expect(settings.contains('DesktopUiPrefs.setLinkPreviews(v)'), isTrue);
    });

    test('🔴 окно берёт карточку только из сообщения и только свою грузит', () {
      final section = File(
        'lib/ui/desktop/app/desktop_chats_section.dart',
      ).readAsStringSync();
      expect(
        section.contains(
          'acceptIncomingLinkPreview(payload.linkPreview, raw)',
        ),
        isTrue,
      );
      expect(
        section.contains('ownLinkPreviewTarget: (isSelf && carriedPreview == null)'),
        isTrue,
        reason: 'чужие ссылки окно открывать не должно',
      );
      expect(
        'linkPreview: submission.linkPreview'.allMatches(section).length,
        3,
        reason: 'личка, комната и повтор после проверки контакта',
      );
    });

    test('🔴 телефон не открывает чужие ссылки и отправляет карточку', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      expect(
        src.contains(
          'bool _mayFetchOwnLinkPreview(_TimelineEntry entry) =>\n'
          '      entry.isMe && entry.forwardedFrom == null;',
        ),
        isTrue,
      );
      // Лента берёт карточку только через правило выше.
      expect(src.contains('_linkPreviewFutureForEntry(\n'), isTrue);
      expect(src.contains('_linkPreviewInitialForEntry(\n'), isTrue);
      final bubbleCalls = RegExp(
        r'linkPreviewFuture:\s*_linkPreviewFutureForMessage',
      ).allMatches(src);
      expect(bubbleCalls, isEmpty, reason: 'лента снова грузит чужие ссылки');

      // Отправка: карточка снята ДО очистки поля и уходит во все пять
      // отправок текста (комната ×2, личка ×2, «всё равно отправить»).
      final start = src.indexOf(
        '  Future<void> _sendInner({int? scheduledAtMs}) async {',
      );
      final body = src.substring(start, src.indexOf('\n  }\n', start));
      final take = body.indexOf('_linkPreviewDraft.takeFor(text)');
      final clear = body.indexOf('_text.clear();');
      expect(take, greaterThan(0));
      expect(take, lessThan(clear), reason: 'очистка сбросила бы черновик');
      expect('linkPreview: linkPreview,'.allMatches(body).length, 5);
      // Поле ввода сообщает черновику каждый новый текст — и в избранном,
      // где «печатает» не отправляется.
      final listener = src.substring(
        src.indexOf('  void _onComposerTextChanged() {'),
        src.indexOf('    if (!_canEmitTyping) return;'),
      );
      expect(listener.contains('_linkPreviewDraft.update(_text.text);'), isTrue);
    });

    test('телефонная карточка рисует приехавшую картинку из памяти', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      expect(src.contains('child: _linkPreviewImage('), isTrue);
      expect(src.contains('Image.memory(\n      bytes,'), isTrue);
    });
  });

  test('клавиатурная отправка тоже несёт карточку', () {
    // Enter и кнопка идут одним путём — `_submitComposer`.
    final panel = File(
      'lib/ui/desktop/chat/chat_thread_panel.dart',
    ).readAsStringSync();
    expect(panel.contains('onSend: (txt) => _submitComposer(txt),'), isTrue);
    expect(
      panel.contains('final linkPreview = isEdit ? null : draft?.takeFor(txt);'),
      isTrue,
    );
    expect(LogicalKeyboardKey.enter, isNotNull);
  });
}
