// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Переводчик (11.2026): подготовка текста и выбор языка оригинала.
// Чистые функции — без ML Kit.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/translation/translation_service.dart';

void main() {
  group('TranslationText.forDetection', () {
    test('drops links, mentions, emoji and code', () {
      expect(
        TranslationText.forDetection(
          'Привет @alex 👋 смотри https://example.com/x и `rm -rf`',
        ),
        'Привет смотри и',
      );
    });

    test('collapses stretched letters', () {
      expect(TranslationText.forDetection('спасибооооо!!!'), 'спасибоо!!!');
      expect(TranslationText.forDetection('sooooo cool'), 'soo cool');
    });

    test('keeps real double letters', () {
      expect(TranslationText.forDetection('cool длинный'), 'cool длинный');
    });

    test('empty when there are no letters', () {
      expect(TranslationText.forDetection('👍🔥 https://a.b 123'), '');
      expect(TranslationText.forDetection('   '), '');
    });
  });

  group('TranslationText.translatePreserving', () {
    Future<String> fake(String s) async => '<$s>';

    test('keeps links, emoji and spacing in place', () async {
      final out = await TranslationText.translatePreserving(
        'Hi there 👋 see https://ex.com now',
        fake,
      );
      expect(out, '<Hi there> 👋 <see> https://ex.com <now>');
    });

    test('translates line by line and keeps line breaks', () async {
      final out = await TranslationText.translatePreserving(
        'first line\n\nsecond line',
        fake,
      );
      expect(out, '<first line>\n\n<second line>');
    });

    test('sends the collapsed word to the model', () async {
      final seen = <String>[];
      await TranslationText.translatePreserving('thaaaanks', (s) async {
        seen.add(s);
        return s;
      });
      expect(seen, ['thaanks']);
    });

    test('falls back to the original chunk when the model returns empty',
        () async {
      final out = await TranslationText.translatePreserving(
        'hello',
        (s) async => '',
      );
      expect(out, 'hello');
    });
  });

  group('MessageTranslationService.pickSource', () {
    test('foreign top candidate wins', () {
      expect(
        MessageTranslationService.pickSource([('en', 0.9), ('ru', 0.05)], 'ru'),
        'en',
      );
    });

    test('confident target language means «already translated»', () {
      expect(
        MessageTranslationService.pickSource([('ru', 0.8), ('uk', 0.15)], 'ru'),
        'ru',
      );
    });

    test('unsure target falls back to the next plausible language', () {
      // Короткая фраза с опечатками: «ru» впереди, но неуверенно.
      expect(
        MessageTranslationService.pickSource([('ru', 0.4), ('uk', 0.35)], 'ru'),
        'uk',
      );
    });

    test('nothing detected', () {
      expect(MessageTranslationService.pickSource([], 'ru'), isNull);
    });
  });
}
