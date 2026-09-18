// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 Темы комнаты: список хранится, а не вычисляется из видимых сообщений.
//
// НАЙДЕНО ПО ЖАЛОБЕ ВЛАДЕЛЬЦА И ПОДТВЕРЖДЕНО НА ЖИВОМ ТЕЛЕФОНЕ 15.09.2026:
// «в комнате создать тему — при переключении просто пустые чаты, и нет
// синхронизации с ПК».
//
// Причина одна на обе жалобы. Список тем рассылается СКРЫТЫМ СООБЩЕНИЕМ внутри
// переписки, и каждое устройство собирало его заново из ЗАГРУЖЕННОГО ОКНА —
// последних ~200 событий. Отсюда:
//
//   • на компьютере тем «нет» — сообщение со списком не попало в окно;
//   • через двести сообщений темы пропадали У ВСЕХ, а сообщения с их
//     `topic_id` по правилу «неизвестная тема → Общий» уезжали в общий поток,
//     то есть ветка становилась пустой.
//
// Теперь список живёт в базе рядом с историей, а лента осталась каналом
// доставки, а не хранилищем.

import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/ui/room_topic_marks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('формат хранения', () {
    test('◆ список переживает запись и чтение целиком', () {
      const topics = <RoomTopicRef>[
        RoomTopicRef(
          id: 't1',
          title: 'релиз',
          emoji: '🚀',
          mark: 'rocket',
          createdAtMs: 111,
        ),
        RoomTopicRef(id: 't2', title: 'баги', mark: 'bug', createdAtMs: 222),
      ];
      final back = decodeRoomTopicsJson(encodeRoomTopicsJson(topics));
      expect(back.length, 2);
      expect(back.first.id, 't1');
      expect(back.first.title, 'релиз');
      expect(back.first.emoji, '🚀');
      expect(back.first.mark, 'rocket');
      expect(back.first.createdAtMs, 111);
      expect(back.last.mark, 'bug');
    });

    test('🔴 знак доезжает и ПО СЕТИ, а не только до диска', () {
      // Хранение и рассылка собраны из одной формы (`roomTopicToMap`) ровно
      // затем, чтобы поле, добавленное в одном месте, не потерялось в другом.
      const topics = <RoomTopicRef>[
        RoomTopicRef(id: 't1', title: 'созвон', mark: 'call', createdAtMs: 5),
      ];
      final parsed = parseTopicsSyncCommand(buildTopicsSyncCommand(topics));
      expect(parsed, isNotNull);
      expect(parsed!.topics.single.mark, 'call');
    });

    test('мусор не роняет, а даёт пустой список', () {
      expect(decodeRoomTopicsJson('не json'), isEmpty);
      expect(decodeRoomTopicsJson(''), isEmpty);
      expect(decodeRoomTopicsJson('{"a":1}'), isEmpty);
    });

    test('тема без имени или без идентификатора отбрасывается', () {
      expect(decodeRoomTopicsJson('[{"id":"","title":"x"}]'), isEmpty);
      expect(decodeRoomTopicsJson('[{"id":"a","title":"  "}]'), isEmpty);
    });
  });

  group('хранилище тем', () {
    test('◆ сохранённый список читается обратно', () async {
      final db = await AppDb.openForTesting();
      try {
        expect(await db.roomTopicsGet('room-1'), isNull);
        await db.roomTopicsSet(
          roomId: 'room-1',
          topicsJson: '[{"id":"t1","title":"релиз","createdAtMs":1}]',
          syncedAtMs: 1000,
        );
        final row = await db.roomTopicsGet('room-1');
        expect(row, isNotNull);
        expect(row!.syncedAtMs, 1000);
        expect(decodeRoomTopicsJson(row.topicsJson).single.title, 'релиз');
      } finally {
        await db.close();
      }
    });

    test('🔴 СТАРОЕ сообщение не отменяет свежую правку', () async {
      // Лента переигрывается при каждой загрузке. Без этой проверки старый
      // список со дна окна затирал бы тему, созданную секунду назад.
      final db = await AppDb.openForTesting();
      try {
        await db.roomTopicsSet(
          roomId: 'room-1',
          topicsJson: '[{"id":"new","title":"свежая","createdAtMs":2}]',
          syncedAtMs: 2000,
        );
        await db.roomTopicsSet(
          roomId: 'room-1',
          topicsJson: '[{"id":"old","title":"старая","createdAtMs":1}]',
          syncedAtMs: 1000,
        );
        final row = await db.roomTopicsGet('room-1');
        expect(decodeRoomTopicsJson(row!.topicsJson).single.id, 'new');
        expect(row.syncedAtMs, 2000);
      } finally {
        await db.close();
      }
    });

    test('комнаты не мешают друг другу', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.roomTopicsSet(
          roomId: 'a',
          topicsJson: '[{"id":"t","title":"первая","createdAtMs":1}]',
          syncedAtMs: 1,
        );
        await db.roomTopicsSet(
          roomId: 'b',
          topicsJson: '[{"id":"t","title":"вторая","createdAtMs":1}]',
          syncedAtMs: 1,
        );
        expect(
          decodeRoomTopicsJson((await db.roomTopicsGet('a'))!.topicsJson)
              .single
              .title,
          'первая',
        );
        expect(
          decodeRoomTopicsJson((await db.roomTopicsGet('b'))!.topicsJson)
              .single
              .title,
          'вторая',
        );
      } finally {
        await db.close();
      }
    });

    test('🔴 версию схемы таблица не двигает', () {
      final src = File('lib/storage/app_db.dart').readAsStringSync();
      final chain = src.substring(
        src.indexOf('static Future<void> runMigrationsForTest('),
        src.indexOf('static Future<void> _createSchema('),
      );
      expect(chain.contains('room_topics'), isFalse);
      const create = 'CREATE TABLE IF NOT EXISTS room_topics';
      expect(create.allMatches(src).length, 1);
    });
  });

  group('«#» и знак', () {
    test('◆ имя показывается с решёткой', () {
      const topic = RoomTopicRef(id: 't', title: 'релиз');
      expect(roomTopicDisplayTitle(topic), '#релиз');
    });

    test('🔴 решётка не удваивается, если человек написал её сам', () {
      expect(normalizeRoomTopicTitle('#релиз'), 'релиз');
      expect(normalizeRoomTopicTitle('##релиз'), 'релиз');
      expect(normalizeRoomTopicTitle('  # релиз '), 'релиз');
      expect(
        roomTopicDisplayTitle(const RoomTopicRef(id: 't', title: '#релиз')),
        '#релиз',
      );
    });

    test('знак находится по идентификатору', () {
      expect(resolveRoomTopicMark('call')?.icon, FluentIcons.call_24_regular);
      expect(resolveRoomTopicMark('')?.icon, isNull);
      expect(resolveRoomTopicMark(null), isNull);
    });

    test('🔴 ЗНАК ЗАМЕНЯЕТ РЕШЁТКУ, а не приписывается рядом', () {
      // Указание владельца: решётка — это и есть знак по умолчанию, и «формат»
      // темы — один значок перед названием. Две пометки подряд читались бы
      // как два разных признака.
      const plain = RoomTopicRef(id: 't', title: 'релиз');
      const called = RoomTopicRef(id: 't', title: 'созвон', mark: 'call');
      expect(roomTopicIcon(plain), kRoomTopicHashIcon);
      expect(roomTopicIcon(called), FluentIcons.call_24_regular);
      expect(roomTopicIconColor(plain), isNull);
      expect(roomTopicIconColor(called), const Color(0xFF34D399));
    });

    test('🔴 значки — из набора десктопного дизайна, а не системные', () {
      // Один и тот же рисунок на телефоне и на компьютере: у темы один вид,
      // куда бы на неё ни смотрели.
      // У Fluent два начертания — Filled и Regular, — поэтому сверяем семью
      // по началу имени, а не буквально.
      for (final mark in kRoomTopicMarks) {
        expect(
          mark.icon.fontFamily ?? '',
          startsWith('FluentSystemIcons'),
          reason: 'знак ${mark.id} не из набора Fluent',
        );
      }
      expect(
        kRoomTopicHashIcon.fontFamily ?? '',
        startsWith('FluentSystemIcons'),
      );
    });

    test('🔴 незнакомый знак не теряет тему, а просто не рисуется', () {
      // Набор со временем пополнится, и устройство постарше обязано показать
      // ветку без значка, а не выбросить её.
      expect(resolveRoomTopicMark('знак-из-будущего'), isNull);
    });

    test('◆ цвет обещает: звонок зелёный, «срочное» красное', () {
      expect(resolveRoomTopicMark('call')!.color, const Color(0xFF34D399));
      expect(resolveRoomTopicMark('video')!.color, const Color(0xFF34D399));
      expect(resolveRoomTopicMark('alert')!.color, const Color(0xFFF43F5E));
      expect(resolveRoomTopicMark('chat')!.color, isNull);
    });

    test('🔴 цветных МЕНЬШИНСТВО — иначе цвет ничего не значит', () {
      final tinted = kRoomTopicMarks.where((m) => m.isTinted).length;
      expect(tinted, lessThan(kRoomTopicMarks.length / 2));
      expect(kRoomTopicMarks.length, greaterThanOrEqualTo(24));
    });

    test('идентификаторы знаков не повторяются', () {
      final ids = kRoomTopicMarks.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('где это включено', () {
    final mobile = File('lib/ui/chat_screen.dart').readAsStringSync();
    final desktop = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();

    test('🔴 обе стороны читают сохранённый список при открытии комнаты', () {
      expect(mobile.contains('_loadStoredRoomTopics()'), isTrue);
      expect(desktop.contains('_loadStoredRoomTopics()'), isTrue);
    });

    test('🔴 обе стороны КЛАДУТ принятое в базу', () {
      expect(mobile.contains('rememberRoomTopics('), isTrue);
      expect(desktop.contains('rememberRoomTopics('), isTrue);
    });

    test('🔴 рассылка принимает сами темы, а не их пересказ', () {
      // Пересказ полями молча терял знак при любой правке с компьютера.
      final ctrl = File('lib/app/app_controller.dart').readAsStringSync();
      expect(
        ctrl.contains('required List<RoomTopicRef>\n    topics') ||
            ctrl.contains('required List<RoomTopicRef> topics'),
        isTrue,
      );
      expect(
        ctrl.contains('({String id, String title, String emoji, int createdAtMs})'),
        isFalse,
      );
    });

    test('🔴 пустая ВЕТКА больше не выдаётся за пустой чат', () {
      // На живом телефоне внутри только что созданной темы показывался экран
      // знакомства с новым собеседником — ладонь «Помахать» и слова «их
      // видите только вы и собеседник» в комнате на восьмерых.
      expect(mobile.contains('ПУСТАЯ ТЕМА — НЕ ПУСТОЙ ЧАТ'), isTrue);
      expect(mobile.contains('if (canWave && topic == null)'), isTrue);
    });

    test('◆ знак меняется с ОБЕИХ сторон', () {
      expect(mobile.contains("pop('mark')"), isTrue);
      expect(mobile.contains('_pickTopicMark('), isTrue);
      expect(desktop.contains("maybePop('mark')"), isTrue);
      expect(desktop.contains('_pickTopicMark('), isTrue);
    });
  });

  group('◆ «Основа» — такая же ветка', () {
    test('знак основы переживает запись и чтение', () {
      const state = RoomTopicsState(
        topics: <RoomTopicRef>[RoomTopicRef(id: 't', title: 'релиз')],
        baseMark: 'star',
      );
      final back = decodeRoomTopicsState(encodeRoomTopicsState(state));
      expect(back.baseMark, 'star');
      expect(back.topics.single.title, 'релиз');
    });

    test('🔴 знак основы доезжает по сети', () {
      final parsed = parseTopicsSyncCommand(
        buildTopicsSyncCommand(
          const <RoomTopicRef>[RoomTopicRef(id: 't', title: 'релиз')],
          baseMark: 'announce',
        ),
      );
      expect(parsed!.baseMark, 'announce');
    });

    test('🔴 старая запись — голый список — читается по-прежнему', () {
      // Такие записи уже лежат в базах: разбор обязан их понимать, иначе
      // темы исчезнут у тех, кто обновился.
      final back = decodeRoomTopicsState(
        '[{"id":"t","title":"релиз","createdAtMs":1}]',
      );
      expect(back.topics.single.id, 't');
      expect(back.baseMark, '');
    });

    test('у основы есть свой значок и по умолчанию это решётка', () {
      expect(roomTopicIconFor(''), kRoomTopicHashIcon);
      expect(roomTopicIconFor('star'), FluentIcons.star_24_regular);
      expect(roomTopicIconColorFor('star'), isNotNull);
      expect(roomTopicIconColorFor(''), isNull);
    });

    test('🔴 называется «Основа», а не «Общий»', () {
      expect(kRoomBaseTopicTitleRu, 'Основа');
      for (final f in [
        'lib/ui/desktop/chat/room_topics_strip.dart',
        'lib/ui/desktop/chat/details/room_details_view.dart',
      ]) {
        final src = File(f).readAsStringSync();
        final code = src
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(code.contains("'Общий'"), isFalse, reason: f);
      }
    });

    test('◆ знак основы меняется с обеих сторон', () {
      final mobile = File('lib/ui/chat_screen.dart').readAsStringSync();
      final desktop = File(
        'lib/ui/desktop/app/desktop_chats_section.dart',
      ).readAsStringSync();
      expect(mobile.contains('_manageBaseTopic'), isTrue);
      expect(desktop.contains('_manageBaseTopic'), isTrue);
    });
  });

  group('◆ страница комнаты на телефоне', () {
    final src = File('lib/ui/room_details_screen.dart').readAsStringSync();

    test('🔴 заглушка портрета комнаты — из ОБЩЕЙ палитры, а не серая', () {
      // Была плоская `secondaryContainer` с тёмной буквой, хотя в списке
      // комнат та же комната рисуется цветной заглушкой: одна комната
      // выглядела двумя разными. С 17.09.2026 цвета заглушки — общие с
      // компьютером (`AvatarInitials.colors`).
      expect(src.contains('AvatarInitials.colors('), isTrue);
      final i = src.indexOf('class _RoomAvatar');
      final body = src.substring(i, i + 2600);
      expect(body.contains('cs.secondaryContainer'), isFalse);
      expect(body.contains('seed: seed.isNotEmpty ? seed : title'), isTrue);
    });

    test('🔴 портрет участника тоже цветной и с точкой присутствия', () {
      final i = src.indexOf('class _MiniAvatar');
      final body = src.substring(i, i + 3000);
      expect(body.contains('secondaryContainer'), isFalse);
      expect(body.contains('AvatarInitials.fallbackBubble'), isTrue);
      expect(body.contains('Color(0xFF22C55E)'), isTrue);
    });

    test('◆ три вкладки, как в окне на компьютере', () {
      expect(src.contains('class _RoomTabs'), isTrue);
      expect(src.contains('if (_roomTab == 0)'), isTrue);
      expect(src.contains('if (_roomTab == 1)'), isTrue);
      expect(src.contains('if (_roomTab == 2)'), isTrue);
    });

    test('🔴 список людей теперь НА странице, а не за жестом по счётчику', () {
      expect(src.contains('class _RoomMembersPanel'), isTrue);
      expect(src.contains('class _RoomMemberTile'), isTrue);
      // Имя, идентификатор и присутствие — в одной строке.
      final i = src.indexOf('class _RoomMemberTile');
      final body = src.substring(i, (i + 4000).clamp(0, src.length));
      expect(body.contains('online: member.isOnline'), isTrue);
      expect(body.contains('member.profileId'), isTrue);
    });

    test('🔴 строка участника ОТКРЫВАЕТ, а не звонит', () {
      // По списку людей ходят глазами, и промах не должен стоить звонка
      // чужому человеку, который об этом узнает. Тот же урок, что и в журнале
      // звонков на компьютере: строка выбирает, действие — отдельной кнопкой.
      final i = src.indexOf('void _openMemberProfile(');
      expect(i, greaterThan(0));
      final body = src.substring(i, (i + 1200).clamp(0, src.length));
      expect(body.contains('ContactDetailsScreen('), isTrue);
      expect(body.contains('CallManager'), isFalse);
      // Написать — отдельным значком справа.
      expect(src.contains("ru: 'Написать', en: 'Message'"), isTrue);
    });

    test('у себя строка никуда не ведёт', () {
      final i = src.indexOf('class _RoomMembersPanel');
      final body = src.substring(i, (i + 7000).clamp(0, src.length));
      expect(body.contains('m.profileId == myProfileId\n                      ? null'), isTrue);
    });

    test('◆ действие по правам: «Добавить» или «Пригласить»', () {
      final i = src.indexOf('class _RoomMembersPanel');
      final body = src.substring(i, i + 6000);
      expect(body.contains("ru: 'Добавить'"), isTrue);
      expect(body.contains("ru: 'Пригласить'"), isTrue);
      expect(body.contains('if (canAdd)'), isTrue);
      expect(body.contains('if (canInvite)'), isTrue);
    });

    test('🔴 выбор людей больше не безликий список', () {
      // Был `CheckboxListTile` с именем и идентификатором одним весом, без
      // портретов и без присутствия.
      final i = src.indexOf('Future<void> _openAddMembers(');
      final body = src.substring(i, i + 9000);
      expect(body.contains('_MiniAvatar('), isTrue);
      expect(body.contains('onlineByProfileId'), isTrue);
      expect(body.contains("ru: 'Имя или Secretly ID'"), isTrue);
    });
  });
}
