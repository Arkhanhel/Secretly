// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ПЕРЕВОДА СООБЩЕНИЙ В ОКНЕ НЕ БЫЛО ВОВСЕ.
//
// Указание владельца 16.09.2026: «доделай перевод сообщений и отложенную
// отправку на ПК».
//
// 🔴 ПОЧЕМУ НЕ ТЕМ ЖЕ СПОСОБОМ, ЧТО НА ТЕЛЕФОНЕ. Телефон переводит через
// Google ML Kit, и в `lib/translation/translation_service.dart` записано
// главное правило: «текст сообщения НИКОГДА не покидает устройство — то же
// обещание, что и сквозное шифрование, никакого облачного переводчика».
// Плагины ML Kit объявлены ровно под две платформы, android и ios; на маке
// вызов ушёл бы в пустоту.
//
// 🔴 ОБЛАЧНЫЙ ПЕРЕВОДЧИК ИСКЛЮЧЁН — он отдал бы наружу ровно то, что
// приложение обещает не отдавать. Поэтому окно зовёт СИСТЕМНЫЙ переводчик
// macOS: он считает на устройстве, моделями, которые человек скачал сам.
//
// Этот файл стережёт три вещи, которые ломаются молча: обещание про
// приватность, разбор настроек (общих с телефоном) и то, что каждый отказ
// получает ВНЯТНОЕ объяснение вместо тишины.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_translation_prefs.dart';
import 'package:secretly_app/ui/desktop/services/desktop_translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = File(
    'lib/ui/desktop/services/desktop_translation_service.dart',
  ).readAsStringSync();
  final bridge = File(
    'macos/Runner/TranslationBridge.swift',
  ).readAsStringSync();

  group('🔴 текст никуда не уходит', () {
    test('в службе нет ни одного сетевого вызова', () {
      for (final forbidden in <String>[
        'http://',
        'https://',
        'package:http',
        'HttpClient',
        'Socket',
      ]) {
        expect(
          service.contains(forbidden),
          isFalse,
          reason: 'перевод обязан считаться на устройстве, а не в облаке '
              '(нашлось «$forbidden»)',
        );
      }
    });

    test('мост считает системным переводчиком, а не чужой службой', () {
      expect(bridge.contains('import Translation'), isTrue);
      expect(bridge.contains('TranslationSession('), isTrue);
      expect(bridge.contains('http'), isFalse);
    });

    test('🔴 без SwiftUI и без самовольной докачки моделей', () {
      // Сессию без вида дал только macOS 26; ниже — честный отказ.
      expect(bridge.contains('installedSource:'), isTrue);
      expect(bridge.contains('#available(macOS 26.0, *)'), isTrue);
      // Скачивание у Apple показывает системное окно и отсюда невозможно —
      // вместо молчаливого ожидания возвращаем «needs_download».
      expect(bridge.contains('needs_download'), isTrue);
      expect(bridge.contains('downloadModel'), isFalse);
    });
  });

  group('🔴 у каждого обращения к системе есть срок', () {
    // Проверено 16.09.2026: `LanguageAvailability.status` МОЖЕТ не ответить
    // вовсе — отдельная программа и программа в бандле ждали его больше
    // минуты и не дождались, при запущенной службе `translationd`. Без срока
    // нажатие «Перевести» повисало бы навсегда, не показывая НИ перевода, НИ
    // отказа, — то есть выглядело бы поломкой окна.
    test('в мосте', () {
      expect(bridge.contains('withDeadline('), isTrue);
      expect(bridge.contains('kTranslationDeadline'), isTrue);
    });

    test('и в службе окна — на случай, если молчит сам мост', () {
      expect(service.contains('static const Duration _deadline'), isTrue);
      expect(
        RegExp(r'\.timeout\(_deadline\)').allMatches(service).length,
        2,
        reason: 'сроком закрыты оба обращения: определение и перевод',
      );
    });

    test('🔴 удачный путь не ждёт медленную справку', () {
      // Сначала пробуем перевести и только потом, ради объяснения отказа,
      // спрашиваем доступность пары — иначе каждое нажатие шло бы через
      // вызов, который как раз и может не ответить.
      final i = bridge.indexOf('private func handleTranslate');
      final body = bridge.substring(i);
      expect(
        body.indexOf('TranslationSession('),
        lessThan(body.indexOf('LanguageAvailability()')),
      );
    });

    test('🔴 эмодзи не участвуют в определении языка', () {
      // В «Congrats!! 🎉» на два слова приходится символ, не принадлежащий
      // никакому языку, и вес его в такой короткой строке непропорционален.
      expect(bridge.contains('stripNoise'), isTrue);
      expect(bridge.contains('isEmojiPresentation'), isTrue);
    });

    test('🔴 мост отдаёт НЕСКОЛЬКО догадок, а не одну', () {
      expect(bridge.contains('languageHypotheses(withMaximum: 3)'), isTrue);
      expect(bridge.contains('.prefix(3)'), isTrue);
    });

    test('🔴 не ответило в срок — это отказ, а не «не поддерживается»', () {
      // Сроком занимается `withDeadline`; выдать «нет ответа» за «язык
      // неизвестен» значило бы навсегда спрятать возможность из-за разовой
      // заминки, поэтому такой случай уходит в `failed`.
      final i = bridge.indexOf('private func handleTranslate');
      final body = bridge.substring(i);
      expect(body.contains('case .installed, .none:'), isTrue);
      expect(body.contains('code: "failed"'), isTrue);
    });
  });

  group('🔴 настройки — ОБЩИЕ с телефоном', () {
    test('ключи те же, что пишет экран настроек телефона', () {
      final settingsScreen = File(
        'lib/ui/settings_screen.dart',
      ).readAsStringSync();
      expect(
        settingsScreen.contains(DesktopTranslationPrefs.kSourceKey),
        isTrue,
        reason: 'свой ключ значил бы: язык выставлен на телефоне, а окно '
            'переводит на другой — и никакой подсказки почему',
      );
      expect(settingsScreen.contains(DesktopTranslationPrefs.kTargetKey), isTrue);
    });

    test('пустой целевой язык — это «язык приложения»', () {
      final s = DesktopTranslationPrefs.resolve(
        rawTarget: '',
        fallbackTarget: 'ru',
      );
      expect(s.target, 'ru');
    });

    test('«auto» и пустое в источнике — одно и то же: определять', () {
      expect(
        DesktopTranslationPrefs.resolve(rawSource: 'auto', rawTarget: 'ru')
            .source,
        isNull,
      );
      expect(
        DesktopTranslationPrefs.resolve(rawSource: '  ', rawTarget: 'ru')
            .source,
        isNull,
      );
    });

    test('закреплённый источник доходит как есть', () {
      final s = DesktopTranslationPrefs.resolve(
        rawSource: 'EN',
        rawTarget: 'ru',
      );
      expect(s.source, 'en');
    });
  });

  group('🔴 каждый отказ объясним', () {
    test('у всякого исхода, кроме удачи и «нечего делать», есть слова', () {
      for (final outcome in DesktopTranslationOutcome.values) {
        final r = DesktopTranslationResult(outcome, 'x');
        final message = r.userMessage;
        if (outcome == DesktopTranslationOutcome.ok ||
            outcome == DesktopTranslationOutcome.sameLanguage) {
          expect(message, isNull, reason: 'тут говорить нечего');
        } else {
          expect(
            message,
            isNotNull,
            reason: 'молчание на нажатие «Перевести» — худший ответ',
          );
        }
      }
    });

    test('🔴 «модель не скачана» ведёт ТУДА, ГДЕ ЕЁ БЕРУТ', () {
      const r = DesktopTranslationResult(
        DesktopTranslationOutcome.needsDownload,
      );
      expect(r.userMessage, contains('Системные настройки'));
      expect(r.userMessage, contains('Языки перевода'));
    });
  });

  group('служба', () {
    setUp(() {
      DesktopTranslationService.instance.clearCacheForTest();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        DesktopTranslationService.channel,
        null,
      );
    });

    void mock(Future<Object?>? Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        DesktopTranslationService.channel,
        handler,
      );
    }

    test('переводит и отдаёт текст', () async {
      final seen = <MethodCall>[];
      mock((call) async {
        seen.add(call);
        if (call.method == 'translate') return 'Привет';
        return null;
      });
      final r = await DesktopTranslationService.instance.translate(
        text: 'Hello',
        targetBcp: 'ru',
        sourceBcp: 'en',
      );
      expect(r.isOk, isTrue);
      expect(r.text, 'Привет');
      expect(seen.single.method, 'translate');
    });

    test('🔴 тот же язык — НЕ переводим и в мост не ходим', () async {
      var calls = 0;
      mock((call) async {
        calls++;
        return 'что угодно';
      });
      final r = await DesktopTranslationService.instance.translate(
        text: 'Привет',
        targetBcp: 'ru',
        sourceBcp: 'ru',
      );
      expect(r.outcome, DesktopTranslationOutcome.sameLanguage);
      expect(calls, 0, reason: 'лишний вызов ради заведомо пустого ответа');
    });

    test('🔴 «ru-RU» и «ru» — один язык, а не два', () async {
      mock((call) async => 'не должно понадобиться');
      final r = await DesktopTranslationService.instance.translate(
        text: 'Привет',
        targetBcp: 'ru-RU',
        sourceBcp: 'ru',
      );
      expect(r.outcome, DesktopTranslationOutcome.sameLanguage);
    });

    test('язык не задан — спрашиваем мост определить', () async {
      final methods = <String>[];
      mock((call) async {
        methods.add(call.method);
        if (call.method == 'detect') return <String>['en'];
        if (call.method == 'translate') return 'Привет';
        return null;
      });
      final r = await DesktopTranslationService.instance.translate(
        text: 'Hello',
        targetBcp: 'ru',
      );
      expect(methods, ['detect', 'translate']);
      expect(r.isOk, isTrue);
    });

    test('язык не определился — так и говорим', () async {
      mock((call) async => call.method == 'detect' ? <String>[] : null);
      final r = await DesktopTranslationService.instance.translate(
        text: '??? 123',
        targetBcp: 'ru',
      );
      expect(r.outcome, DesktopTranslationOutcome.unknownSource);
    });

    test('🔴 код отказа моста превращается в понятный исход', () async {
      for (final pair in <(String, DesktopTranslationOutcome)>[
        ('needs_download', DesktopTranslationOutcome.needsDownload),
        ('unsupported_pair', DesktopTranslationOutcome.unsupported),
        ('unsupported_os', DesktopTranslationOutcome.unsupported),
        ('failed', DesktopTranslationOutcome.failed),
      ]) {
        DesktopTranslationService.instance.clearCacheForTest();
        mock((call) async {
          if (call.method == 'translate') {
            throw PlatformException(code: pair.$1);
          }
          return null;
        });
        final r = await DesktopTranslationService.instance.translate(
          text: 'Hello',
          targetBcp: 'ru',
          sourceBcp: 'en',
        );
        expect(r.outcome, pair.$2, reason: 'код «${pair.$1}»');
      }
    });

    test('🔴 не десктопная сборка — тихо «не умеем», а не падение', () async {
      mock((call) async => throw MissingPluginException());
      final r = await DesktopTranslationService.instance.translate(
        text: 'Hello',
        targetBcp: 'ru',
        sourceBcp: 'en',
      );
      expect(r.outcome, DesktopTranslationOutcome.unsupported);
    });

    test('🔴 неверная догадка о языке НЕ хоронит перевод', () async {
      // Найдено на живом окне 16.09.2026: «Congrats!! 🎉» определилось как
      // каталанский, пара ca→ru системе неизвестна — и человек получал отказ
      // на сообщении, которое переводится безо всяких затруднений.
      final tried = <String>[];
      mock((call) async {
        if (call.method == 'detect') return <String>['ca', 'en', 'it'];
        if (call.method == 'translate') {
          final src = (call.arguments as Map)['source'] as String;
          tried.add(src);
          if (src == 'en') return 'Поздравляю';
          throw PlatformException(code: 'unsupported_pair');
        }
        return null;
      });
      final r = await DesktopTranslationService.instance.translate(
        text: 'Congrats!!',
        targetBcp: 'ru',
      );
      expect(r.isOk, isTrue);
      expect(r.text, 'Поздравляю');
      expect(tried, ['ca', 'en'], reason: 'перебор идёт по убыванию уверенности');
    });

    test('🔴 перебираем ТОЛЬКО неизвестную пару, а не любой отказ', () async {
      // Отсутствие модели или поломка перебором не лечатся: следующая попытка
      // лишь отняла бы у человека ещё несколько секунд.
      var calls = 0;
      mock((call) async {
        if (call.method == 'detect') return <String>['ca', 'en', 'it'];
        if (call.method == 'translate') {
          calls++;
          throw PlatformException(code: 'needs_download');
        }
        return null;
      });
      final r = await DesktopTranslationService.instance.translate(
        text: 'Congrats!!',
        targetBcp: 'ru',
      );
      expect(r.outcome, DesktopTranslationOutcome.needsDownload);
      expect(calls, 1);
    });

    test('🔴 отказ НЕ запоминается — его можно починить и повторить', () async {
      // «Модель не скачана» человек чинит за минуту в системных настройках.
      // Запомнив такой отказ, окно ответило бы тем же и на второе нажатие — и
      // человек, только что поставивший язык, решил бы, что перевод сломан.
      var attempt = 0;
      mock((call) async {
        if (call.method == 'detect') return <String>['en'];
        if (call.method == 'translate') {
          attempt++;
          if (attempt == 1) throw PlatformException(code: 'needs_download');
          return 'Привет';
        }
        return null;
      });
      final first = await DesktopTranslationService.instance.translate(
        text: 'Hello',
        targetBcp: 'ru',
        cacheKey: 'msg-x',
      );
      expect(first.outcome, DesktopTranslationOutcome.needsDownload);
      final second = await DesktopTranslationService.instance.translate(
        text: 'Hello',
        targetBcp: 'ru',
        cacheKey: 'msg-x',
      );
      expect(second.isOk, isTrue, reason: 'вторая попытка обязана состояться');
      expect(second.text, 'Привет');
    });

    test('🔴 повторное нажатие не переводит заново', () async {
      var calls = 0;
      mock((call) async {
        if (call.method == 'detect') return <String>['en'];
        if (call.method == 'translate') {
          calls++;
          return 'Привет';
        }
        return null;
      });
      for (var i = 0; i < 3; i++) {
        await DesktopTranslationService.instance.translate(
          text: 'Hello',
          targetBcp: 'ru',
          sourceBcp: 'en',
          cacheKey: 'msg-1',
        );
      }
      expect(calls, 1);
    });
  });

  group('в переписке', () {
    final panel = File(
      'lib/ui/desktop/chat/chat_thread_panel.dart',
    ).readAsStringSync();
    final bubble = File(
      'lib/ui/desktop/chat/message_bubble.dart',
    ).readAsStringSync();

    test('🔴 пункт есть только у ЧУЖОГО текстового сообщения', () {
      expect(
        panel.contains('onTranslate: (!m.isSelf && m.isTextMessage)'),
        isTrue,
        reason: 'своё переводить незачем — человек сам его написал',
      );
    });

    test('подпись переключается: «Перевести» ↔ «Скрыть перевод»', () {
      final menu = File(
        'lib/ui/desktop/chat/message_context_menu.dart',
      ).readAsStringSync();
      // 19.09.2026: подписи меню уехали в переводы — проверяем, что
      // переключается именно ПАРА подписей, а не одна на оба состояния.
      expect(menu.contains('translationShown'), isTrue);
      expect(menu.contains('l10n.desktopMenuHideTranslation'), isTrue);
      expect(menu.contains('l10n.desktopMenuTranslate'), isTrue);
    });

    test('🔴 оригинал остаётся на месте — перевод ДОБАВЛЯЕТСЯ под ним', () {
      // Порядок в столбце: сам текст, затем перевод, затем подвал со временем.
      final i = bubble.indexOf('Widget _textWithMeta(');
      expect(i, greaterThan(0));
      final body = bubble.substring(i, i + 3000);
      // Текст выделяется мышью (16.09.2026) — он обёрнут в `_selectable`.
      final textAt = body.indexOf('_selectable(c, isSelf, text()),');
      final blockAt = body.indexOf('_translationBlock(c, isSelf, fg),');
      final metaAt = body.indexOf('_metaRow(c, isSelf, fgSoft),', blockAt);
      expect(textAt, greaterThan(0));
      expect(blockAt, greaterThan(textAt));
      expect(metaAt, greaterThan(blockAt));
    });

    test('🔴 с переводом время НЕ вклеивается в текст', () {
      // Строчное время приклеено к низу абзаца — над переводом оно налезло бы
      // прямо на него.
      final i = bubble.indexOf('Widget _textWithMeta(');
      final body = bubble.substring(i, i + 3000);
      expect(body.contains('translated.isEmpty'), isTrue);
      expect(body.contains('!widget.translating'), isTrue);
    });

    test('🔴 пока считается — в пузыре видно, что просьбу услышали', () {
      // Системная служба отвечает не мгновенно. Нажатие, проваливающееся в
      // пустоту, неотличимо от нерабочей кнопки.
      expect(bubble.contains('final bool translating;'), isTrue);
      expect(bubble.contains("'Переводим…'"), isTrue);
      expect(panel.contains('translating: _translateInFlight.contains(m.id)'),
          isTrue);
    });

    test('перевода нет — в пузыре не остаётся ни точки', () {
      final i = bubble.indexOf('Widget _translationBlock(');
      final body = bubble.substring(i, i + 400);
      expect(body.contains('return const SizedBox.shrink();'), isTrue);
    });

    test('🔴 в переписке запоминается только удавшийся перевод', () {
      final i = panel.indexOf('Future<void> _toggleTranslate(');
      final body = panel.substring(i, i + 2600);
      expect(body.contains('_translations.remove(id);'), isTrue);
    });

    test('🔴 состояние перевода НЕ лежит в снимке сообщения', () {
      // `MessageData` — снимок того, что пришло. Перевод — состояние
      // просмотра: положить его туда значило бы однажды перепутать
      // переведённое с полученным.
      expect(bubble.contains('this.translatedText,'), isTrue);
      final i = bubble.indexOf('class MessageData {');
      final j = bubble.indexOf('\n}', i);
      expect(bubble.substring(i, j).contains('translatedText'), isFalse);
    });
  });
}
