// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Пачка 21.11.2026: знак «важного пользователя» H2 вместо звёздочки премиума,
// зелёная галочка у имени пользователя над ID, копирование без имён (кроме
// смеси своих и чужих), выделение текста вторым долгим касанием, «скачать
// это / все» в альбоме, реакции в личке без фона и фото, повтор отправки по
// касанию на неотправленное фото, эффект эмодзи над клавиатурой, «Назад» —
// сперва в Чаты. `SECRETLY_SHOTS=папка` — снимок знаков.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/elite_badges.dart';
import 'package:secretly_app/ui/chat/message_text_select_sheet.dart';
import 'package:secretly_app/ui/chat/solo_emoji_fx.dart';
import 'package:secretly_app/ui/home/home_back_guard.dart';
import 'package:secretly_app/ui/widgets/elite_badge_mark.dart';
import 'package:secretly_app/ui/widgets/verified_badges.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();

String _src(String path) => File(path).readAsStringSync();

void main() {
  group('знак «важного пользователя»', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      EliteBadges.instance.resetForTest();
    });

    test('ответ сервера: выдача, снятие; старый сервер ничего не стирает',
        () async {
      final b = EliteBadges.instance;
      b.record('P-1', 'h2', present: true);
      expect(b.badgeOf('P-1'), 'h2');
      // Старый сервер не шлёт поле — запомненное остаётся.
      b.record('P-1', null, present: false);
      expect(b.badgeOf('P-1'), 'h2');
      // Новый сервер прислал null — знак снят.
      b.record('P-1', null, present: true);
      expect(b.badgeOf('P-1'), isNull);
      b.record('P-2', 'H2', present: true);
      await b.flushForTest();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('elite_badges_v1'), ['P-2=h2']);
      // Переживает перезапуск.
      b.resetForTest();
      await b.ensureLoaded();
      expect(b.badgeOf('P-2'), 'h2');
    });

    test('вид по строке сервера; неизвестное не рисуется', () {
      expect(verifiedBadgeStyleFromSlug('h2'), VerifiedBadgeStyle.h2);
      expect(verifiedBadgeStyleFromSlug(' H2 '), VerifiedBadgeStyle.h2);
      expect(verifiedBadgeStyleFromSlug('zz'), isNull);
      expect(verifiedBadgeStyleFromSlug(null), isNull);
    });

    test('H2 по макету: морф 4 с, «щелчок» 2 с, блик 2 с, цвет OKLCH', () {
      expect(morphAt(0), 0);
      expect(morphAt(1.5), 0); // 37 % — ещё галочка
      expect(morphAt(2.0), 1); // 50 % — уже «S»
      expect(morphAt(3.5), 1); // 87 %
      expect(morphAt(4.0), 0); // круг замкнулся
      expect(morphAt(1.8), inExclusiveRange(0, 1));
      expect(popAt(0), 1);
      expect(popAt(1.8), closeTo(1.12, 0.001)); // 90 %
      expect(sweepAt(0), -14);
      expect(sweepAt(1.99), greaterThan(20));
      final white = oklch(1, 0, 0);
      expect(white.r, closeTo(1, 0.01));
      expect(white.g, closeTo(1, 0.01));
      final black = oklch(0, 0, 0);
      expect(black.r, closeTo(0, 0.01));
    });

    testWidgets('все виды рисуются без ошибок; уменьшение движения — стоит',
        (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: _shotKey,
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 10,
                    children: [
                      for (final s in VerifiedBadgeStyle.values)
                        VerifiedBadge(style: s, size: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (final ms in [0, 700, 1700, 2100, 3900]) {
        await t.pump(Duration(milliseconds: ms == 0 ? 0 : 400));
        expect(t.takeException(), isNull, reason: '$ms');
      }
      final dir = _shots;
      if (dir != null && dir.isNotEmpty) {
        await t.runAsync(() async {
          final b =
              _shotKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 2);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/badges.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
      await t.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: VerifiedBadge(size: 30)),
        ),
      );
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('знак рядом с именем — только у выданного профиля', (t) async {
      EliteBadges.instance.record('P-elite', 'h2', present: true);
      await t.pumpWidget(
        const MaterialApp(
          home: Row(
            children: [
              EliteBadgeMark(profileId: 'P-elite'),
              EliteBadgeMark(profileId: 'P-plain'),
            ],
          ),
        ),
      );
      expect(find.byType(VerifiedBadge), findsOneWidget);
      EliteBadges.instance.record('P-elite', null, present: true);
      await t.pump();
      expect(find.byType(VerifiedBadge), findsNothing);
    });

    test('🔴 звёздочки премиума у имён больше нет (телефон)', () {
      for (final f in [
        'lib/ui/personal_chats_screen.dart',
        'lib/ui/contact_details_screen.dart',
        'lib/ui/profile_screen.dart',
      ]) {
        final s = _src(f);
        expect(s.contains('0xFFE8A33D'), isFalse, reason: f);
        expect(s.contains('EliteBadgeMark('), isTrue, reason: f);
      }
    });

    test('🔴 зелёная галочка — у имени пользователя над ID, не в шапке', () {
      final s = _src('lib/ui/contact_details_screen.dart');
      final hero = s.indexOf('EliteBadgeMark(');
      final tag = s.indexOf('icon: AppIcons.tag,');
      final id = s.indexOf('icon: AppIcons.badge,');
      final check = s.indexOf("'contact-verified-check'");
      expect(hero, greaterThan(0));
      expect(check, greaterThan(tag));
      expect(check, lessThan(id));
      // В шапке у имени её больше нет.
      final heroRow = s.substring(hero - 2500, hero + 400);
      expect(heroRow.contains('AppIcons.verified'), isFalse);
    });

    test('🔴 сервер: знак только оператором, отдельно от profile_meta', () {
      final main = _src('../../../server/keys/src/main.rs');
      final store = _src('../../../server/keys/src/store.rs');
      expect(main.contains('.route("/v1/badges/admin/set", post(set_profile_badge))'), isTrue);
      final h = main.indexOf('async fn set_profile_badge(');
      expect(main.substring(h, h + 600).contains('internal_key_matches'), isTrue);
      expect(store.contains('CREATE TABLE IF NOT EXISTS profile_badges'), isTrue);
      // Публикация профиля клиентом знак не трогает.
      final set = store.indexOf('pub async fn profile_meta_set(');
      final setEnd = store.indexOf('pub async fn', set + 10);
      expect(store.substring(set, setEnd).contains('profile_badges'), isFalse);
    });
  });

  group('выделение текста', () {
    testWidgets('лист: «скопировать всё» кладёт весь текст', (t) async {
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
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
      String? result;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showMessageTextSelectSheet(
                  context,
                  text: 'Привет, это длинное сообщение',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      // Пока ничего не выделено — «скопировать выделенное» недоступно.
      final sel = t.widget<FilledButton>(
        find.byKey(const ValueKey('message-text-copy-selected')),
      );
      expect(sel.onPressed, isNull);
      await t.tap(find.byKey(const ValueKey('message-text-copy-all')));
      await t.pumpAndSettle();
      expect(copied, 'Привет, это длинное сообщение');
      expect(result, 'Привет, это длинное сообщение');
    });

    test('🔴 второе долгое касание по выделенному — выделение текста', () {
      final s = _src('lib/ui/chat_screen.dart');
      final at = s.indexOf('Widget _wrapSelectableEventItem(');
      final body = s.substring(at, at + 2600);
      expect(body.contains('if (selected) {'), isTrue);
      expect(body.contains('_openMessageTextSelection(event)'), isTrue);
      expect(body.contains('_toggleSelection(event.eventId);'), isTrue);
      expect(body.contains('_startSelection(event.eventId);'), isTrue);
    });
  });

  group('чат', () {
    final s = _src('lib/ui/chat_screen.dart');

    test('🔴 копирование: имена — только при смеси своих и чужих', () {
      final at = s.indexOf('Future<void> _copyEventsToClipboard(');
      final body = s.substring(at, at + 3200);
      expect(
        body.contains('final mixed = lines.map((l) => l.author).toSet().length > 1;'),
        isTrue,
      );
      expect(body.contains(": lines.map((l) => l.text).join('\\n');"), isTrue);
    });

    test('🔴 реакции в личке — без фона и фото', () {
      expect(s.contains('class _ChatKindScope extends InheritedWidget'), isTrue);
      expect(s.contains('=> _ChatKindScope(\n    isGroup: _isGroupChat,'), isTrue);
      final at = s.indexOf('class _ReactionPills');
      expect(s.substring(at, at + 9000).contains('_ChatKindScope.isGroupOf(context)'), isTrue);
    });

    test('🔴 неотправленное фото: касание — меню повтора', () {
      final at = s.indexOf('Future<void> _openTimelineImageGallery(');
      final body = s.substring(at, at + 900);
      expect(body.contains('MessageLocalState.failed'), isTrue);
      expect(body.contains('_showOutgoingSendStateActions(entry: entry)'), isTrue);
    });

    test('🔴 альбом: «скачать выбранное / все (N)»', () {
      expect(s.contains('Future<String?> _pickDownloadScope(int count)'), isTrue);
      expect(s.contains("ru: 'Скачать все (\$count)'"), isTrue);
      expect(s.contains("ru: 'Скачать выбранное'"), isTrue);
      expect(s.contains('await _saveSelectedMediaAttachments(\n                    _albumDownloadTargets(entry),'), isTrue);
      expect(s.contains("value: 'download_album'"), isTrue);
    });

    test('эффект эмодзи — над поднятой клавиатурой', () {
      const screen = Size(390, 844);
      expect(soloEmojiAreaAboveKeyboard(screen, 0), screen);
      expect(soloEmojiAreaAboveKeyboard(screen, 336), const Size(390, 508));
      // Не схлопывается в ноль.
      expect(soloEmojiAreaAboveKeyboard(screen, 900).height, closeTo(844 / 3, 0.01));
      expect(s.contains('screen: soloEmojiVisibleArea(context, media.size),'), isTrue);
    });
  });

  group('«Назад» — сперва в Чаты', () {
    test('раздел забрал нажатие — оболочка не уходит; отметка не копится',
        () async {
      var moved = 0;
      HomeBackGuard.markConsumed();
      HomeBackGuard.runIfUnclaimed(() => moved++);
      await Future<void>.delayed(Duration.zero);
      expect(moved, 0);
      // Следующее нажатие — уже без отметки.
      HomeBackGuard.runIfUnclaimed(() => moved++);
      await Future<void>.delayed(Duration.zero);
      expect(moved, 1);
      // Порядок обработчиков любой: раздел может отметить и позже оболочки.
      HomeBackGuard.runIfUnclaimed(() => moved++);
      HomeBackGuard.markConsumed();
      await Future<void>.delayed(Duration.zero);
      expect(moved, 1);
    });

    test('🔴 оболочка: выход только из Чатов, иначе — в Чаты', () {
      final s = _src('lib/ui/app_shell.dart');
      expect(s.contains('canPop: !searching && _tab == 0,'), isTrue);
      expect(s.contains('if (mounted && _tab != 0) _setTab(0);'), isTrue);
      for (final f in [
        'lib/ui/chats_screen.dart',
        'lib/ui/contacts_screen.dart',
        'lib/ui/personal_chats_screen.dart',
      ]) {
        expect(_src(f).contains('HomeBackGuard.markConsumed();'), isTrue, reason: f);
      }
    });
  });
}
