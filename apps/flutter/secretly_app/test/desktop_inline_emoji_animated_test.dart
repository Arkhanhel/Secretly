// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ЭМОДЗИ ВНУТРИ СООБЩЕНИЯ БЫЛИ МЁРТВЫМИ.
//
// Указание владельца 16.09.2026: «сделай чтобы все эмодзи гифки и т д работали
// правильно в пк версии! В мобильной все идеально работает!»
//
// На телефоне каждое анимируемое эмодзи в тексте рисуется проигрывателем Noto
// (`_animateEmojiInSpans` в `chat_screen.dart`); на компьютере оставался
// статичный шрифтовой знак. Одно и то же сообщение выглядело на двух
// устройствах по-разному — и то, ради чего человек эмодзи и ставил, на
// компьютере пропадало.
//
// 🔴 РАЗБИРАЮТСЯ ТОЛЬКО ПРОСТЫЕ КУСКИ ТЕКСТА. У фишки упоминания, у ссылки и у
// спойлера свои обработчики нажатия и своя раскраска: подменить их картинкой
// значило бы отобрать нажатие.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/message_rich_text.dart';
import 'package:secretly_app/ui/desktop/chat/noto_emoji_lottie.dart';

void main() {
  const style = TextStyle(fontSize: 16);

  test('🔴 знак из каталога превращается в проигрыватель', () {
    final out = animateEmojiInSpans(
      const <InlineSpan>[TextSpan(text: 'привет 😂 как дела', style: style)],
      16,
    );
    final players = out.whereType<WidgetSpan>().toList();
    expect(players.length, 1);
    // Проигрыватель лежит в обёртке с прозрачным знаком под ним: так эмодзи
    // выделяется мышью и попадает в копию (16.09.2026).
    expect(players.first.child, isA<SelectableAnimatedEmoji>());
    expect((players.first.child as SelectableAnimatedEmoji).emoji, '😂');
    // Текст вокруг остаётся текстом, а не рассыпается по знакам.
    final texts = out.whereType<TextSpan>().map((s) => s.text).join('|');
    expect(texts, 'привет |  как дела'.replaceFirst('  ', ' '));
  });

  test('без эмодзи ничего не меняется — быстрый путь', () {
    const span = TextSpan(text: 'обычное сообщение', style: style);
    final out = animateEmojiInSpans(const <InlineSpan>[span], 16);
    expect(out.length, 1);
    expect(out.first, isA<TextSpan>());
    expect((out.first as TextSpan).text, 'обычное сообщение');
  });

  test('🔴 кусок с нажатием НЕ трогаем — у него свой обработчик', () {
    // Так выглядят ссылка и фишка упоминания: свой `recognizer`.
    final link = TextSpan(
      text: 'secretlyapp.com 😂',
      style: style,
      recognizer: TapGestureRecognizer(),
    );
    addTearDown(() => link.recognizer!.dispose());
    final out = animateEmojiInSpans(<InlineSpan>[link], 16);
    expect(out.length, 1);
    expect(identical(out.first, link), isTrue);
  });

  test('кусок с детьми не трогаем — это составной пролёт', () {
    const composite = TextSpan(
      children: <InlineSpan>[TextSpan(text: '😂')],
      style: style,
    );
    final out = animateEmojiInSpans(const <InlineSpan>[composite], 16);
    expect(out.length, 1);
    expect(identical(out.first, composite), isTrue);
  });

  test('несколько знаков подряд — несколько проигрывателей', () {
    final out = animateEmojiInSpans(
      const <InlineSpan>[TextSpan(text: '😂🔥', style: style)],
      16,
    );
    expect(out.whereType<WidgetSpan>().length, 2);
  });

  test('рост знака — 1,35 строки, как на телефоне', () {
    final out = animateEmojiInSpans(
      const <InlineSpan>[TextSpan(text: '😂', style: style)],
      20,
    );
    final player =
        out.whereType<WidgetSpan>().first.child as SelectableAnimatedEmoji;
    expect(player.size, closeTo(27.0, 0.01));
  });

  testWidgets('сообщение с эмодзи рисуется без исключения', (t) async {
    await t.pumpWidget(
      MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Text.rich(
            TextSpan(
              children: animateEmojiInSpans(
                const <InlineSpan>[TextSpan(text: 'привет 😂', style: style)],
                16,
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(t.takeException(), isNull);
    // Внутри обёртки — тот самый проигрыватель.
    expect(find.byType(NotoEmojiLottie), findsOneWidget);
  });

  test('🔴 разбор живёт в окне и берёт тот же каталог, что телефон', () {
    final src = File(
      'lib/ui/desktop/chat/message_rich_text.dart',
    ).readAsStringSync();
    expect(src.contains('isAnimatableNotoEmoji(ch)'), isTrue);
    expect(src.contains('NotoLottieMode.looping'), isTrue);
    // И зовётся из настоящей отрисовки сообщения, а не только в проверке.
    expect(src.contains('...animateEmojiInSpans('), isTrue);
  });
}
