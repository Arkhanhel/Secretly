// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ПРИГЛАШЕНИЯ В КОМНАТУ — КАРТОЧКОЙ, КАК НА ТЕЛЕФОНЕ (29.09.2026).
//
// Жалоба владельца: «ссылки-приглашения в группы выглядят не так, как в
// мобильной версии». ПК показывал голый адрес `links.secretlyapp.com/…` и
// карточку ссылки-заглушки «Join room in Secretly», а щелчок по карточке
// открывал браузер. Уже вступившего ПК вёл на экран входа, а не в комнату.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart'
    show buildRoomInviteShareLink;
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/models/link_preview_v1.dart';
import 'package:secretly_app/ui/desktop/app/desktop_chats_section.dart'
    show
        desktopOutgoingLinkPreviewLoader,
        desktopRoomInviteLookupDue,
        desktopRoomInviteTargetFromText,
        kDesktopRoomInviteRetryAfter;
import 'package:secretly_app/ui/desktop/chat/desktop_link_router.dart';
import 'package:secretly_app/ui/desktop/chat/link_preview_card.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/chat/room_invite_card.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: SizedBox(width: 760, child: child)),
  ),
);

const _base = DesktopRoomInviteView(slug: 'abc123', inviterProfileId: 'p1');

DesktopRoomInviteView _loaded({
  bool member = false,
  bool approval = false,
  bool pending = false,
}) => DesktopRoomInviteView(
  slug: 'abc123',
  inviterProfileId: 'p1',
  loaded: true,
  groupId: 'group:r1',
  title: 'Кофе и код',
  memberCount: 12,
  inviterName: 'Игорь',
  alreadyMember: member,
  approvalRequired: approval,
  requestPending: pending,
  historyVisible: true,
);

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('распознавание — правило телефона', () {
    final link = buildRoomInviteShareLink(
      slug: 'abc123',
      createdByProfileId: 'p1',
      groupIdHint: 'r1',
    );

    test('сообщение из одной ссылки — приглашение', () {
      final t = desktopRoomInviteTargetFromText('  $link  ');
      expect(t, isNotNull);
      expect(t!.slug, 'abc123');
      expect(t.inviterProfileId, 'p1');
    });

    test('ссылка внутри фразы остаётся ссылкой', () {
      expect(desktopRoomInviteTargetFromText('заходи $link'), isNull);
      expect(desktopRoomInviteTargetFromText('https://example.com/x'), isNull);
    });
  });

  group('карточка', () {
    testWidgets('пока данные идут — общая подпись и «Вступить»', (t) async {
      await t.pumpWidget(
        _host(
          const DesktopRoomInviteCard(
            invite: _base,
            isSelf: false,
            foreground: Colors.white,
          ),
        ),
      );
      expect(find.text(l10n.desktopRoomInviteCardTitle), findsWidgets);
      expect(find.text(l10n.desktopRoomInviteCardHint), findsOneWidget);
      expect(find.text(l10n.desktopRoomInviteJoin.toUpperCase()), findsOneWidget);
    });

    testWidgets('данные пришли — название, участники, пригласивший', (t) async {
      await t.pumpWidget(
        _host(
          DesktopRoomInviteCard(
            invite: _loaded(),
            isSelf: false,
            foreground: Colors.white,
          ),
        ),
      );
      expect(find.text('Кофе и код'), findsWidgets);
      expect(
        find.textContaining(l10n.desktopRoomMembersCount(12)),
        findsOneWidget,
      );
      expect(
        find.textContaining(l10n.desktopRoomInviteInvitedBy('Игорь')),
        findsOneWidget,
      );
    });

    for (final (label, view) in <(String, DesktopRoomInviteView)>[
      ('уже в комнате', _loaded(member: true)),
      ('заявка отправлена', _loaded(approval: true, pending: true)),
      ('вход по одобрению', _loaded(approval: true)),
      ('вход сразу', _loaded()),
    ]) {
      testWidgets('кнопка: $label', (t) async {
        var opened = 0;
        await t.pumpWidget(
          _host(
            DesktopRoomInviteCard(
              invite: view,
              isSelf: true,
              foreground: Colors.white,
              onOpen: () => opened++,
            ),
          ),
        );
        final expected = view.alreadyMember
            ? l10n.desktopRoomInviteOpenRoom
            : view.requestPending
            ? l10n.desktopRoomInviteOpenRequest
            : view.approvalRequired
            ? l10n.desktopRoomInviteRequestAccess
            : l10n.desktopRoomInviteJoin;
        await t.tap(find.text(expected.toUpperCase()));
        expect(opened, 1);
      });
    }
  });

  testWidgets('🔴 в пузыре — карточка, а не голый адрес', (t) async {
    final link = buildRoomInviteShareLink(
      slug: 'abc123',
      createdByProfileId: 'p1',
    );
    MessageData? opened;
    await t.pumpWidget(
      _host(
        MessageBubble(
          onOpenRoomInvite: (m) => opened = m,
          message: MessageData(
            id: 'm1',
            authorName: 'Игорь',
            text: link,
            time: '12:00',
            roomInvite: _loaded(),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.textContaining('links.secretlyapp.com'), findsNothing);
    expect(find.text('Кофе и код'), findsWidgets);
    await t.tap(find.text(l10n.desktopRoomInviteJoin.toUpperCase()));
    expect(opened?.id, 'm1');
  });

  test('неудачный запрос приглашения — пауза, потом снова', () {
    final now = DateTime(2026, 9, 29, 12);
    expect(desktopRoomInviteLookupDue(failedAt: null, now: now), isTrue);
    expect(
      desktopRoomInviteLookupDue(
        failedAt: now.subtract(const Duration(minutes: 1)),
        now: now,
      ),
      isFalse,
    );
    expect(
      desktopRoomInviteLookupDue(
        failedAt: now.subtract(kDesktopRoomInviteRetryAfter),
        now: now,
      ),
      isTrue,
    );
  });

  group('🔴 подключено', () {
    final host = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();

    test('у приглашения нет карточки ссылки', () {
      expect(host.contains('roomInvite: invite,'), isTrue);
      expect(
        host.contains('linkPreview: invite == null ? carriedPreview : null,'),
        isTrue,
      );
    });

    String body(String source, String signature) {
      final from = source.indexOf(signature);
      expect(from, greaterThan(0), reason: signature);
      return source.substring(from, source.indexOf('\n  }\n', from));
    }

    test('уже вступившего — сразу в комнату', () {
      expect(
        host.contains('memberGroupId: invite.alreadyMember ? invite.groupId : null'),
        isTrue,
      );
      expect(
        body(host, 'Future<void> _openRoomInviteFromChat(')
            .contains('await _openConversation(id);'),
        isTrue,
      );
    });

    // 🔴 «Открыть комнату» и удачный вход из ЛИЧНОГО чата ставили комнату
    // выбранной в разделе «Чаты», где комнат нет: панель переписки пустела.
    test('комната из личного чата открывается путём корня — с разделом «Комнаты»', () {
      expect(
        body(host, 'Future<void> openRoomInvite(RoomInviteTarget target) async {')
            .contains('await _openConversation(groupId);'),
        isTrue,
      );
      final open = body(host, 'Future<void> _openConversation(String convoId) async {');
      expect(
        open.indexOf('widget.onOpenConversation'),
        lessThan(open.indexOf('_selectedId = convoId')),
      );
      final app = File(
        'lib/ui/desktop/app/desktop_production_app.dart',
      ).readAsStringSync();
      expect(
        'onOpenConversation: _openConvoOrReport,'.allMatches(app).length,
        2,
        reason: 'и «Чаты», и «Комнаты»',
      );
    });

    // 🔴 Неудача не запоминалась: каждое обновление ленты заново спрашивало
    // сервер о каждом отозванном или просроченном приглашении.
    test('неудачный запрос приглашения не повторяется на каждом обновлении', () {
      final lookup = body(host, 'DesktopRoomInviteView? _roomInviteFor(String raw) {');
      expect(
        lookup.indexOf('desktopRoomInviteLookupDue('),
        lessThan(lookup.indexOf('_resolveRoomInvite(target, base.cacheKey)')),
      );
      final resolve = body(
        host,
        'Future<void> _resolveRoomInvite(RoomInviteTarget target, String key) async {',
      );
      expect(resolve.contains('_roomInviteFailedAt[key] = DateTime.now();'), isTrue);
      expect(resolve.contains('_roomInviteFailedAt.remove(key);'), isTrue);
      // Нажатие на карточку спрашивает сразу, без паузы.
      expect(
        body(host, 'Future<void> _openRoomInviteFromMessage(MessageData m) async {')
            .contains('_roomInviteFailedAt.remove(invite.cacheKey);'),
        isTrue,
      );
    });

    test('поле ввода не грузит страницы наших адресов', () async {
      expect(
        host.contains('loader: desktopOutgoingLinkPreviewLoader'),
        isTrue,
      );
      final link = Uri.parse(
        buildRoomInviteShareLink(slug: 's', createdByProfileId: 'p'),
      );
      expect(await desktopOutgoingLinkPreviewLoader(link), isNull);
    });
  });

  testWidgets('карточка ссылки на НАШ адрес открывается приложением', (t) async {
    final seen = <Uri>[];
    DesktopLinkRouter.handler = (uri) {
      seen.add(uri);
      return true;
    };
    addTearDown(() => DesktopLinkRouter.handler = null);
    const url = 'https://links.secretlyapp.com/profile/p1';
    await t.pumpWidget(
      _host(
        const DesktopLinkPreviewCard(
          preview: LinkPreviewV1(url: url, siteName: 'links.secretlyapp.com', title: 'Secretly'),
          isSelf: false,
        ),
      ),
    );
    await t.tap(find.byType(DesktopLinkPreviewCard));
    expect(seen.single.toString(), url);
  });
}
