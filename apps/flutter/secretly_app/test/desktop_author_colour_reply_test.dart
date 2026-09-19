// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ЦВЕТ АВТОРА И ЦИТАТА — КАК НА ТЕЛЕФОНЕ И В ТЕЛЕГРАМЕ.
//
// Указание владельца 16.09.2026 со скриншотом телеграма: «как выглядят
// отвеченные смс… каждая деталь».
//
// ЧТО БЫЛО.
//
//   • Цвет имени зависел от РОЛИ: владелец янтарный, все админы одинаково
//     сиреневые. В комнате с тремя админами их имена переставали различаться, а
//     различать людей — ровно то, для чего цвет имени существует. В телеграме и
//     на телефоне цвет закреплён за человеком.
//
//   • Цитата была одной полоской без подложки, и цвет у неё был один на всех —
//     акцентный. На телефоне (`_ReplyQuoteStrip`) она давно телеграмная:
//     подложка оттенка АВТОРА цитаты, полоска и имя того же цвета.
//
// 🔴 КЛЮЧ ЦВЕТА — УСТРОЙСТВО ОТПРАВИТЕЛЯ, потому что так красит телефон
// (`groupAuthorSeed: entry.event.senderDeviceId`). Другой ключ значил бы, что
// Игорь на телефоне зелёный, а на компьютере сиреневый.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/widgets/avatar_initials.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: SizedBox(width: 760, child: child)),
  ),
);

void main() {
  final src = File(
    'lib/ui/desktop/chat/message_bubble.dart',
  ).readAsStringSync();
  final section = File(
    'lib/ui/desktop/app/desktop_chats_section.dart',
  ).readAsStringSync();

  testWidgets('🔴 имя автора красится тем же цветом, что на телефоне', (t) async {
    await t.pumpWidget(
      _host(
        const MessageBubble(
          message: MessageData(
            id: 'm1',
            authorName: 'Игорь',
            authorRole: 'admin',
            authorSeed: 'DEVICE-IGOR',
            text: 'привет',
            time: '12:00',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final name = t.widget<Text>(find.text('Игорь'));
    expect(
      name.style?.color,
      AvatarInitials.nicknameColor(seed: 'DEVICE-IGOR'),
      reason: 'ключ цвета должен совпадать с телефонным',
    );

    // Метка роли — «таблеткой» цвета того же человека, у правого края
    // строки имени, как «админ» в телеграме.
    final nick = AvatarInitials.nicknameColor(seed: 'DEVICE-IGOR');
    final tag = find.text('админ');
    expect(tag, findsOneWidget);
    expect(t.widget<Text>(tag).style?.color, nick.withValues(alpha: 0.9));
    final pill = t.widget<Container>(
      find.ancestor(of: tag, matching: find.byType(Container)).first,
    );
    final deco = pill.decoration! as BoxDecoration;
    expect(deco.color, nick.withValues(alpha: 0.14));
    expect(deco.border, isNull, reason: 'рамки у метки нет');
    expect(
      t.getRect(tag).left,
      greaterThan(t.getRect(find.text('Игорь')).right),
    );
  });

  testWidgets('🔴 два админа — два РАЗНЫХ цвета', (t) async {
    Color colourOf(String seed) =>
        AvatarInitials.nicknameColor(seed: seed);
    // Подбираем пару ключей, которые палитра различает: проверяем не палитру,
    // а то, что окно больше не сводит всех админов к одному цвету.
    var other = 'DEVICE-B';
    for (var i = 0; i < 50; i++) {
      if (colourOf('DEVICE-A') != colourOf('DEVICE-B$i')) {
        other = 'DEVICE-B$i';
        break;
      }
    }
    for (final seed in ['DEVICE-A', other]) {
      await t.pumpWidget(
        _host(
          MessageBubble(
            message: MessageData(
              id: seed,
              authorName: 'Админ',
              authorRole: 'admin',
              authorSeed: seed,
              text: 'привет',
              time: '12:00',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final name = t.widget<Text>(find.text('Админ'));
      expect(name.style?.color, colourOf(seed));
    }
  });

  testWidgets('🔴 цитата — с подложкой цвета АВТОРА цитаты', (t) async {
    await t.pumpWidget(
      _host(
        const MessageBubble(
          showPeerIdentity: false,
          message: MessageData(
            id: 'm1',
            authorName: 'Миша',
            text: 'Бля, ору',
            time: '20:37',
            reply: ReplyPreview(
              authorName: 'Жека Дядя',
              text: 'Я чуть позже подлечу',
              authorSeed: 'DEVICE-ZHEKA',
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    final quoted = t.widget<Text>(find.text('Жека Дядя'));
    expect(
      quoted.style?.color,
      AvatarInitials.nicknameColor(seed: 'DEVICE-ZHEKA'),
    );
    final panel = t.widget<Container>(
      find
          .ancestor(
            of: find.text('Жека Дядя'),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).color != null,
            ),
          )
          .first,
    );
    expect(
      (panel.decoration! as BoxDecoration).color,
      AvatarInitials.replyPanelColor(seed: 'DEVICE-ZHEKA', isMe: false),
      reason: 'подложка — оттенком автора, как на телефоне',
    );
  });

  group('правила', () {
    test('🔴 цвет больше не зависит от роли', () {
      final i = src.indexOf('Color _authorColor(');
      final body = src.substring(i, i + 500);
      expect(body.contains('authorRole'), isFalse);
      expect(body.contains('AvatarInitials.nicknameColor('), isTrue);
    });

    test('🔴 ключ цвета доходит из ленты до КАЖДОГО сообщения и цитаты', () {
      expect(
        section.contains('authorSeed: event.senderDeviceId'),
        isTrue,
      );
      // Превью ответа, переписанное на пути в пузырь, не имеет права его
      // потерять.
      final i = section.indexOf('ReplyPreview? _resolveReplyPreview(');
      final body = section.substring(i, i + 900);
      expect(body.contains('authorSeed: base.authorSeed'), isTrue);
    });

    test('🔴 превью списка: автор своим цветом, своё устройство — «Вы»', () {
      // Ключ цвета автора превью — устройство, как у телефона.
      expect(
        section.contains('previewAuthorSeed: preview?.senderDeviceId'),
        isTrue,
      );
      // Сообщение с телефона того же человека подписывалось «Избранное»:
      // общий склад превью знает «Вы» только для ЭТОГО устройства.
      expect(
        section.contains('previewAuthor: _previewAuthorLabel(preview)'),
        isTrue,
      );
      final i = section.indexOf('String? _previewAuthorLabel(');
      expect(i, greaterThan(0));
      final body = section.substring(i, i + 400);
      expect(body.contains('isOwnDeviceId(deviceId)'), isTrue);
      expect(body.contains('_selfAuthor(l10n)'), isTrue);
    });
  });
}
