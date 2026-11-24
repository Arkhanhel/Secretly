// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Переводчик в отдельном чате (22.11.2026, Т-2, Т-4): общие настройки ×
// настройка чата, хранение, облегчённая сборка.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/translation/chat_translation_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const globals = <GlobalTranslationSettings>[
    GlobalTranslationSettings(),
    GlobalTranslationSettings(buttonEnabled: true),
    GlobalTranslationSettings(autoEnabled: true),
    GlobalTranslationSettings(buttonEnabled: true, autoEnabled: true),
  ];

  group('режим: все сочетания', () {
    for (final g in globals) {
      for (final mode in ChatTranslationMode.values) {
        test('кнопка=${g.buttonEnabled} авто=${g.autoEnabled} чат=${mode.name}',
            () {
          final p = resolveTranslationPolicy(
            global: g,
            chat: ChatTranslationSettings(mode: mode),
            appLanguage: 'ru',
            available: true,
          );
          switch (mode) {
            case ChatTranslationMode.inherit:
              expect(p.showButton, g.buttonEnabled);
              // Т-2: автоперевод без кнопки не работает.
              expect(p.auto, g.buttonEnabled && g.autoEnabled);
            case ChatTranslationMode.off:
              expect(p.showButton, isFalse);
              expect(p.auto, isFalse);
            case ChatTranslationMode.button:
              expect(p.showButton, isTrue);
              expect(p.auto, isFalse);
            case ChatTranslationMode.auto:
              expect(p.showButton, isTrue);
              expect(p.auto, isTrue);
          }
        });
      }
    }
  });

  group('языки', () {
    const g = GlobalTranslationSettings(
      buttonEnabled: true,
      source: 'en',
      target: 'de',
    );

    test('как в настройках', () {
      final p = resolveTranslationPolicy(global: g, appLanguage: 'ru');
      expect(p.source, 'en');
      expect(p.target, 'de');
    });

    test('свои у чата: авто-определение и язык приложения', () {
      final p = resolveTranslationPolicy(
        global: g,
        chat: const ChatTranslationSettings(source: 'auto', target: ''),
        appLanguage: 'pt_BR',
      );
      expect(p.source, isNull);
      expect(p.target, 'pt');
    });

    test('свои у чата: конкретные языки', () {
      final p = resolveTranslationPolicy(
        global: const GlobalTranslationSettings(),
        chat: const ChatTranslationSettings(source: 'uk', target: 'en'),
        appLanguage: 'ru',
      );
      expect(p.source, 'uk');
      expect(p.target, 'en');
    });

    test('общий язык перевода пуст — язык приложения', () {
      final p = resolveTranslationPolicy(
        global: const GlobalTranslationSettings(),
        appLanguage: 'uk',
      );
      expect(p.source, isNull);
      expect(p.target, 'uk');
    });
  });

  group('выключатели', () {
    const g = GlobalTranslationSettings(buttonEnabled: true, autoEnabled: true);

    test('облегчённая сборка — переводчика нет ни при какой настройке', () {
      for (final mode in ChatTranslationMode.values) {
        final p = resolveTranslationPolicy(
          global: g,
          chat: ChatTranslationSettings(mode: mode),
          appLanguage: 'ru',
          available: false,
        );
        expect(p, EffectiveTranslationPolicy.disabled);
      }
    });

    test('выключатель настройки чата — чат живёт по общим', () {
      final p = resolveTranslationPolicy(
        global: g,
        chat: const ChatTranslationSettings(mode: ChatTranslationMode.off),
        appLanguage: 'ru',
        overrideEnabled: false,
      );
      expect(p.showButton, isTrue);
      expect(p.auto, isTrue);
      expect(kChatTranslationOverride, isTrue);
    });
  });

  group('хранение', () {
    test('туда и обратно', () {
      const s = ChatTranslationSettings(
        mode: ChatTranslationMode.auto,
        source: 'auto',
        target: '',
      );
      final raw = '{"mode":"auto","source":"auto","target":""}';
      expect(ChatTranslationSettings.fromJsonString(raw), s);
      expect(s.toJson(), {'mode': 'auto', 'source': 'auto', 'target': ''});
    });

    test('мусор — «как в настройках»', () {
      for (final raw in <String?>[
        null,
        '',
        'мусор',
        '[]',
        '42',
        '{"mode":"турбо"}',
        '{"mode":7,"source":5,"target":true}',
      ]) {
        expect(
          ChatTranslationSettings.fromJsonString(raw),
          ChatTranslationSettings.inherit,
          reason: '$raw',
        );
      }
      // Неизвестный код языка отбрасывается, режим остаётся.
      final s = ChatTranslationSettings.fromJsonString(
        '{"mode":"button","source":"<script>","target":"EN"}',
      );
      expect(s.mode, ChatTranslationMode.button);
      expect(s.source, isNull);
      expect(s.target, 'en');
    });

    test('ключ на телефоне; «как в настройках» стирает запись', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const id = 'PEER-1';
      expect(chatTranslationPrefsKey(id), 'chat_translation_v1_PEER-1');
      await saveChatTranslationSettings(
        id,
        const ChatTranslationSettings(mode: ChatTranslationMode.off),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('chat_translation_v1_PEER-1'), isNotNull);
      expect(
        (await loadChatTranslationSettings(id)).mode,
        ChatTranslationMode.off,
      );
      await saveChatTranslationSettings(id, ChatTranslationSettings.inherit);
      expect(prefs.containsKey('chat_translation_v1_PEER-1'), isFalse);
      expect(await loadChatTranslationSettings(id),
          ChatTranslationSettings.inherit);
    });
  });

  group('🔴 провода', () {
    final s = File('lib/ui/chat_screen.dart').readAsStringSync();

    test('авторежим зовёт перевод как «не по нажатию», нажатие — как нажатие',
        () {
      expect(s.contains('userInitiated: false'), isTrue);
      expect(s.contains('userInitiated: true'), isTrue);
    });

    test('смена настроек сбрасывает переводы и отбрасывает старые ответы', () {
      expect(s.contains('_translationGeneration++'), isTrue);
      expect(s.contains('generation != _translationGeneration'), isTrue);
    });

    test('пункт «Перевод» в меню чата и комнаты, не в «Избранном»', () {
      expect(s.contains('context.l10n.chatTranslateMenuItem'), isTrue);
      expect(s.contains("value: 'translation'"), isTrue);
      expect(s.contains("case 'translation':"), isTrue);
      expect(s.contains('!_isFavoritesChat'), isTrue);
    });
  });
}
