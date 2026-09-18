// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ЭМОДЗИ И ГИФКИ НА КОМПЬЮТЕРЕ — ТЕ ЖЕ, ЧТО НА ТЕЛЕФОНЕ.
//
// УКАЗАНИЕ ВЛАДЕЛЬЦА 16.09.2026: «сделай чтобы все эмодзи гифки и т д работали
// правильно в пк версии! В мобильной все идеально работает!»
//
// НАШЛОСЬ ДВА РАСХОЖДЕНИЯ, И ОБА КРУПНЫЕ.
//
// 1. ПОДБОРЩИК ЭМОДЗИ ЗНАЛ ТРИДЦАТЬ СЕМЬ СИМВОЛОВ. Список `_kEmojiBundle` был
//    вбит в файл руками, со своими словами для поиска. Рядом, в
//    `lib/ui/emoji/noto_emoji_catalog.dart`, лежали ВОСЕМЬСОТ ВОСЕМЬДЕСЯТ ОДИН
//    — с категориями, тонами кожи и двуязычным поиском по основам слов, — и
//    шапка того файла прямо утверждала: «Shared by the mobile + desktop emoji
//    pickers». Общим он не был: телефон брал его, компьютер — нет. Человек,
//    получивший на телефоне 🥑, на компьютере не мог ни ответить тем же, ни
//    найти его.
//
// 2. ВКЛАДКА GIF БЫЛА ЗАГЛУШКОЙ «GIF-ПОИСК СКОРО». На телефоне подборщик
//    гифок живой: категории-иконки, поиск, умеющий русский, подгрузка страниц,
//    недавние.
//
// И третье, без чего первые два не имеют смысла: десктопная сборка НЕ КЛАЛА
// ключ GIPHY. Даже безупречная вкладка показывала бы пустоту.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/gifs/gif_api.dart';
import 'package:secretly_app/ui/emoji/noto_emoji_catalog.dart';

void main() {
  final popover = File(
    'lib/ui/desktop/chat/emoji_popover.dart',
  ).readAsStringSync();
  final gifTab = File(
    'lib/ui/desktop/chat/gif_picker_tab.dart',
  ).readAsStringSync();
  final buildScript = File(
    'tools/desktop_build_macos.sh',
  ).readAsStringSync();

  group('🔴 подборщик эмодзи', () {
    test('берёт ОБЩИЙ каталог, а не свой списочек', () {
      expect(popover.contains('kNotoCodepoints'), isTrue);
      expect(popover.contains('kNotoCategoryOrder'), isTrue);
      expect(popover.contains('kNotoCategoryLabelsRu'), isTrue);
      expect(
        popover.contains('const _kEmojiBundle ='),
        isFalse,
        reason: 'зашитый список из тридцати семи символов вернулся',
      );
      expect(popover.contains('class _EmojiEntry'), isFalse);
    });

    test('в каталоге по-прежнему сотни символов, а не десятки', () {
      // Если каталог однажды усохнет, эта проверка скажет об этом раньше, чем
      // человек не найдёт нужный знак.
      expect(kNotoCodepoints.length, greaterThan(800));
    });

    test('поиск — общий, тот самый, что умеет русский', () {
      expect(popover.contains('filterEmojiByQuery'), isTrue);
    });

    test('🔴 тона кожи спрятаны под базовый символ', () {
      // Без этого треть сетки — одна и та же рука в пяти оттенках.
      expect(popover.contains('kNotoSkinToneHidden.contains(emoji)'), isTrue);
      // И выбрать их всё-таки можно — правой кнопкой.
      expect(popover.contains('kNotoSkinToneVariants'), isTrue);
      expect(popover.contains('onSecondaryTapDown'), isTrue);
    });

    test('сетка рисует символы текстом, а не восемьюстами анимациями', () {
      // Восемьсот проигрывателей Lottie в одном окне — это восемьсот запросов
      // кадра. Телефон поступает так же; оживают эмодзи уже в переписке.
      expect(popover.contains('NotoEmojiLottie'), isFalse);
    });
  });

  group('🔴 вкладка GIF', () {
    test('заглушки больше нет', () {
      expect(popover.contains('GIF-поиск скоро'), isFalse);
      expect(popover.contains('DesktopGifPickerTab('), isTrue);
    });

    test('правила поиска ОБЩИЕ с телефоном', () {
      // Жалоба «поиск работает только на английском» чинилась в `gifQueryPlan`.
      // Писать здесь свой разбор значило бы починить её один раз из двух.
      expect(gifTab.contains('gifQueryPlan('), isTrue);
      expect(gifTab.contains('fetchGifPage('), isTrue);
    });

    test('🔴 «нет связи» и «ничего не нашлось» — разные сообщения', () {
      expect(gifTab.contains('Связь прервалась'), isTrue);
      expect(gifTab.contains('Ничего не нашлось'), isTrue);
    });

    test('🔴 курсор считается по отданному, а не по показанному', () {
      expect(gifTab.contains('_offset += page.returned'), isTrue);
      expect(gifTab.contains('page.returned'), isTrue);
    });

    test('страница от старого слова не попадёт в новую выдачу', () {
      expect(gifTab.contains('if (seq != _seq'), isTrue);
    });

    test('подгрузка спрашивает ТО ЖЕ слово, каким добыта выдача', () {
      expect(gifTab.contains('query: _resolvedTerm'), isTrue);
      expect(gifTab.contains('lang: _resolvedLang'), isTrue);
    });

    // 16.09.2026: брошенный файл теперь идёт через окно отправки, а гифка
    // из панели — сразу, как в Telegram. Правило «одна правда о том, куда
    // уходит вложение» осталось: обе дороги кончаются в `onSendMedia`.
    test('🔴 отправляет гифку ТОТ ЖЕ путь, что и окно отправки файлов', () {
      final panel = File(
        'lib/ui/desktop/chat/chat_thread_panel.dart',
      ).readAsStringSync();
      expect(panel.contains('onGifFilePicked:'), isTrue);
      expect(panel.contains('(path) => unawaited(_sendGifNow(path))'), isTrue);
      final gif = panel.substring(panel.indexOf('Future<void> _sendGifNow('));
      expect(gif.contains('final send = widget.onSendMedia;'), isTrue);
      final dialog = panel.substring(
        panel.indexOf('Future<void> _openSendDialog('),
      );
      expect(dialog.contains('final send = widget.onSendMedia;'), isTrue);
    });

    test('условие GIPHY: источник назван', () {
      expect(gifTab.contains('Powered by GIPHY'), isTrue);
    });

    test('🔴 сборка окна кладёт ключ GIPHY', () {
      expect(buildScript.contains('GIPHY_API_KEY'), isTrue);
      expect(buildScript.contains('SECRETLY_GIPHY_API_KEY'), isTrue);
    });

    test('без ключа — честная надпись, а не пустая сетка', () {
      expect(gifTab.contains('kGiphyApiKey.isEmpty'), isTrue);
      expect(gifTab.contains('сборка без ключа GIPHY'), isTrue);
    });
  });

  group('разбор ответа GIPHY', () {
    test('берёт мелкую для сетки и полную с потолком для отправки', () {
      const body = '''
      {"data":[{"images":{
        "fixed_width_downsampled":{"url":"https://p/small.gif"},
        "downsized_medium":{"url":"https://p/full.gif"},
        "original":{"url":"https://p/huge.gif"}
      }}],"pagination":{"total_count":100,"count":1}}''';
      final page = parseGifPage(body, offset: 0, limit: 30);
      expect(page.items.length, 1);
      expect(page.items.first.previewUrl, 'https://p/small.gif');
      expect(
        page.items.first.fullUrl,
        'https://p/full.gif',
        reason: 'original без потолка размера — не то, что шлют в переписку',
      );
      expect(page.hasMore, isTrue);
    });

    test('🔴 запись без пригодных ссылок выбрасывается, но КУРСОР её считает', () {
      const body = '''
      {"data":[{"images":{}},{"images":{
        "fixed_width":{"url":"https://p/a.gif"}
      }}],"pagination":{"total_count":100,"count":2}}''';
      final page = parseGifPage(body, offset: 0, limit: 30);
      expect(page.items.length, 1, reason: 'пустую запись показывать нечем');
      expect(
        page.returned,
        2,
        reason: 'курсор по показанным начнёт следующую страницу внахлёст, '
            'и выдача пойдёт по кругу',
      );
    });

    test('мусор вместо ответа — это отказ, а не пустота', () {
      final page = parseGifPage('не json', offset: 0, limit: 30);
      expect(page.failed, isTrue);
    });

    test('неполная страница без счётчиков значит конец', () {
      const body = '{"data":[{"images":{"fixed_width":{"url":"https://p/a.gif"}}}]}';
      final page = parseGifPage(body, offset: 0, limit: 30);
      expect(page.hasMore, isFalse);
    });
  });
}
