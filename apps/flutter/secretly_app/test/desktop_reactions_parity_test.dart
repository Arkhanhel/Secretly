// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 РЕАКЦИИ ПК = РЕАКЦИИ ТЕЛЕФОНА (29.09.2026).
//
// Быстрый ряд ПК был своим (`❤️👍😂😮😢🔥🎉`, с подписью «Mirrors mobile»), а у
// телефона — `❤️🔥😁👍👎🥰👏`. В комнатах с «выбранными реакциями» сервер
// отклонял 😂 😮 😢 🎉 с ПК. Большая сетка — 881 плитка с вариантами тона,
// поиск по шестнадцатеричному коду, и каждая плитка качала анимацию с CDN.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/rooms/room_models.dart';
import 'package:secretly_app/ui/desktop/chat/reactions_popover.dart';
import 'package:secretly_app/ui/emoji/noto_emoji_catalog.dart'
    show kNotoSkinToneVariants;
import 'package:secretly_app/ui/desktop/design/colors.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DColors(colors: kDColorsDark, child: Center(child: child)),
  ),
);

void main() {
  test('быстрый ряд — тот же, что у телефона', () {
    expect(kQuickReactionsRow, roomSelectedReactionEmojis);
  });

  test('правило комнаты отсеивает ряд', () {
    bool onlyHeart(String e) => e == '❤️';
    expect(quickReactionsFor(onlyHeart), ['❤️']);
    expect(quickReactionsFor(null), kQuickReactionsRow);
    expect(quickReactionsFor((_) => false), isEmpty);
  });

  testWidgets('ряд в меню показывает только разрешённое', (t) async {
    await t.pumpWidget(
      _host(QuickReactionRow(onPicked: (_) {}, allowed: (e) => e == '👍')),
    );
    await t.pump();
    // Кнопки ряда рисуют знак (или его анимацию) — считаем по «запасному»
    // тексту, который есть у каждой.
    expect(find.text('👍'), findsWidgets);
    expect(find.text('❤️'), findsNothing);
  });

  group('большая сетка', () {
    final src = File(
      'lib/ui/desktop/chat/reactions_popover.dart',
    ).readAsStringSync();

    test('варианты тона — под базовым знаком', () {
      expect(src.contains('!kNotoSkinToneHidden.contains(e)'), isTrue);
      expect(src.contains('onSecondaryTapDown'), isTrue);
    });

    // 🔴 Меню тона не знало правила комнаты: 👍 разрешён, 👍🏽 — нет, и
    // выбранный тон сервер отклонял.
    test('меню тона — только разрешённое правилом комнаты', () {
      final tones = kNotoSkinToneVariants['👍']!;
      expect(desktopSkinTonesFor('👍', null), tones);
      expect(desktopSkinTonesFor('👍', (e) => e == '👍'), isEmpty);
      expect(desktopSkinTonesFor('👍', (e) => e == tones[2]), [tones[2]]);
      final btn = src.substring(src.indexOf('class _GridEmojiBtnState'));
      expect(btn.contains('desktopSkinTonesFor(widget.emoji, widget.allowed)'), isTrue);
      expect(src.contains('allowed: widget.allowed,\n            );'), isTrue);
    });

    test('поиск по словам, общий с телефоном', () {
      expect(src.contains('filterEmojiByQuery(_allEmojis, _q)'), isTrue);
      expect(src.contains("cp.contains(q)"), isFalse);
    });

    test('плитки — текстом, анимация только по наведению', () {
      final btn = src.substring(src.indexOf('class _GridEmojiBtnState'));
      expect(btn.contains('mode: NotoLottieMode.preview'), isFalse);
      expect(btn.contains('_h\n                      ? NotoEmojiLottie('), isTrue);
    });
  });

  group('🔴 подключено', () {
    test('хозяин передаёт правило комнаты в панель', () {
      final host = File(
        'lib/ui/desktop/app/desktop_chats_section.dart',
      ).readAsStringSync();
      expect(host.contains('_reactionAllowed = policy.isReactionAllowed;'), isTrue);
      expect(host.contains('reactionAllowed: _isDirect ? null : _reactionAllowed'), isTrue);
    });

    test('панель отдаёт правило всем трём путям к реакции', () {
      final panel = File(
        'lib/ui/desktop/chat/chat_thread_panel.dart',
      ).readAsStringSync();
      expect(panel.contains('allowed: widget.reactionAllowed,'), isTrue);
      expect(
        'allowed: widget.reactionAllowed'.allMatches(panel).length +
            'allowed:\n                                                        widget.reactionAllowed'
                .allMatches(panel)
                .length,
        greaterThanOrEqualTo(3),
        reason: 'меню, полный выбор из меню, полный выбор из строки наведения',
      );
      expect(panel.contains('.where(widget.reactionAllowed!)'), isTrue);
    });
  });
}
