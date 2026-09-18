// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ФОТО, ВИДЕО И ФАЙЛЫ В ЛЕНТЕ — КАК В TELEGRAM.
//
// Указание владельца 16.09.2026 (со скриншотом Telegram для macOS): «все фото
// и видео должны отправляться не в отдельном пузыре, а без него… как должны
// выглядеть медиа, отправленные мной в чате».
//
// Было: каждый снимок — отдельным пузырём с подложкой, подписи не
// показывались вовсе, альбомы не склеивались, файлы качались сами целиком, а
// голосовые с телефона считались музыкой.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_event.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ui/desktop/chat/attachment_kinds.dart';
import 'package:secretly_app/ui/desktop/chat/attachment_save.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/chat/media_albums.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/chat/message_media.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

MessageData _media(
  String id, {
  String group = 'g1',
  String seed = 'dev-a',
  MessageAttachmentKind kind = MessageAttachmentKind.image,
  bool asFile = false,
  String caption = '',
  bool self = false,
  String? path,
  int width = 1600,
  int height = 900,
  int at = 0,
}) => MessageData(
  id: id,
  payloadId: 'p-$id',
  authorName: self ? 'Вы' : 'Пётр',
  authorSeed: seed,
  text: caption,
  time: '12:0$at',
  timestampMs: 1757700000000 + at,
  isSelf: self,
  mediaGroupId: group.isEmpty ? null : group,
  attachment: MessageAttachment(
    kind: kind,
    blobId: 'blob-$id',
    payloadEventId: 'p-$id',
    fileName: asFile ? 'report-$id.pdf' : null,
    mime: kind == MessageAttachmentKind.image
        ? 'image/jpeg'
        : kind == MessageAttachmentKind.video
        ? 'video/mp4'
        : 'application/pdf',
    sizeBytes: 2700000,
    width: width,
    height: height,
    sentAsFile: asFile,
    filePath: path,
  ),
);

Widget _host(Widget child, {double width = 900}) => MaterialApp(
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

void main() {
  group('склейка альбомов — правило телефона', () {
    test('🔴 подряд, одна группа, одно устройство — одна строка', () {
      final rows = groupMediaAlbums([
        _media('a', at: 1),
        _media('b', at: 2),
        _media('c', at: 3),
      ]);
      expect(rows, hasLength(1));
      expect(rows.single.albumItems!.map((m) => m.id), ['a', 'b', 'c']);
      expect(rows.single.id, 'a');
    });

    test('другое устройство или другая группа — новая строка', () {
      final rows = groupMediaAlbums([
        _media('a'),
        _media('b', seed: 'dev-b'),
        _media('c', group: 'g2'),
        _media('d', group: 'g2'),
      ]);
      expect(rows.map((r) => r.albumItems?.length ?? 1), [1, 1, 2]);
    });

    test('🔴 снимок, отправленный файлом, в фото-альбом не идёт', () {
      final rows = groupMediaAlbums([
        _media('a'),
        _media('b', asFile: true),
        _media('c', asFile: true),
      ]);
      expect(rows, hasLength(2));
      expect(rows[0].albumItems, isNull);
      expect(albumShelfOf(rows[1].albumItems!.first), AlbumShelf.files);
    });

    test('одиночный с номером группы — обычная строка', () {
      final rows = groupMediaAlbums([_media('a')]);
      expect(rows.single.albumItems, isNull);
    });

    test('больше десяти — несколько альбомов, как в Telegram', () {
      final rows = groupMediaAlbums([
        for (var i = 0; i < 13; i++) _media('m$i'),
      ]);
      expect(rows.map((r) => r.albumItems!.length), [10, 3]);
    });

    test('🔴 подпись альбома — у того, у кого она есть', () {
      final row = groupMediaAlbums([
        _media('a'),
        _media('b', caption: 'Отпуск'),
      ]).single;
      expect(row.text, 'Отпуск');
      expect(row.expanded.map((m) => m.id), ['a', 'b']);
    });

    test('доставка альбома — по самому отстающему', () {
      final row = albumRow([
        _media('a').copyWith(delivery: DeliveryStatus.read),
        _media('b').copyWith(delivery: DeliveryStatus.sending),
      ]);
      expect(row.delivery, DeliveryStatus.sending);
    });

    test('ответ на снимок внутри альбома находит альбом', () {
      final rows = groupMediaAlbums([_media('a'), _media('b'), _media('c')]);
      expect(indexOfRowContaining(rows, payloadId: 'p-b'), 0);
      expect(indexOfRowContaining(rows, payloadId: 'нет'), -1);
    });
  });

  group('вид вложения и загрузка', () {
    AttachmentEventV1 att(String mime, {List<int>? waveform, String? name}) =>
        AttachmentEventV1(
          eventId: 'e',
          blobId: 'b',
          fileKeyB64: 'k',
          sizeBytes: 1,
          mime: mime,
          waveform: waveform,
          filename: name,
        );

    test('🔴 голосовое с телефона (audio/mp4 + волна) — голосовое', () {
      expect(
        desktopAttachmentKind(att('audio/mp4', waveform: [1, 2, 3])),
        MessageAttachmentKind.voice,
      );
      expect(
        desktopAttachmentKind(att('audio/mp4')),
        MessageAttachmentKind.audio,
      );
      expect(desktopAttachmentKind(att('audio/opus')), MessageAttachmentKind.voice);
      expect(desktopAttachmentKind(att('image/png')), MessageAttachmentKind.image);
      expect(desktopAttachmentKind(att('application/zip')), MessageAttachmentKind.file);
    });

    test('🔴 файл и песня качаются по нажатию, снимки — сами', () {
      bool auto(MessageAttachmentKind k, {bool asFile = false}) =>
          desktopAutoDownloads(k, sentAsFile: asFile);
      expect(auto(MessageAttachmentKind.image), isTrue);
      expect(auto(MessageAttachmentKind.video), isTrue);
      expect(auto(MessageAttachmentKind.voice), isTrue);
      expect(auto(MessageAttachmentKind.file), isFalse);
      expect(auto(MessageAttachmentKind.audio), isFalse);
      expect(auto(MessageAttachmentKind.image, asFile: true), isFalse);
    });

    test('миниатюра от отправителя: испорченная — не миниатюра', () {
      expect(decodeAttachmentThumb('%%%'), isNull);
      expect(decodeAttachmentThumb(''), isNull);
      expect(decodeAttachmentThumb(base64Encode([1, 2, 3])), [1, 2, 3]);
    });

    test('копия вложения несёт все поля (волна больше не теряется)', () {
      const a = MessageAttachment(
        kind: MessageAttachmentKind.voice,
        blobId: 'b',
        payloadEventId: 'p',
        waveform: [1, 2, 3],
        width: 10,
        height: 20,
        sentAsFile: true,
        videoNote: true,
        musicTitle: 'T',
        musicArtist: 'A',
      );
      final c = a.copyWith(filePath: '/tmp/x', loading: false);
      expect(c.waveform, [1, 2, 3]);
      expect(c.width, 10);
      expect(c.height, 20);
      expect(c.sentAsFile, isTrue);
      expect(c.videoNote, isTrue);
      expect(c.musicTitle, 'T');
      expect(c.musicArtist, 'A');
    });
  });

  group('в ленте', () {
    testWidgets('🔴 снимок без подписи — без пузыря, время поверх кадра', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          MessageBubble(
            message: _media('a', group: ''),
            showPeerIdentity: false,
          ),
        ),
      );
      await t.pump();
      final tile = find.byType(DesktopMediaTile);
      expect(tile, findsOneWidget);
      expect(t.getSize(tile), const Size(430, 242));
      // Пузыря с подложкой чужого сообщения нет.
      final peerBg = kDColorsDark.bubblePeer;
      final bubbles = t.widgetList<Container>(find.byType(Container)).where(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration! as BoxDecoration).color == peerBg,
      );
      expect(bubbles, isEmpty);
      // Время — поверх кадра, в правом нижнем углу.
      final time = t.getRect(find.text('12:00'));
      final media = t.getRect(tile);
      expect(media.contains(time.center), isTrue);
      expect(media.right - time.right, lessThan(20));
    });

    testWidgets('🔴 снимок с подписью — в пузыре, подпись под кадром', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          MessageBubble(
            message: _media('a', group: '', caption: 'Смотри, закат'),
            showPeerIdentity: false,
          ),
        ),
      );
      await t.pump();
      final media = t.getRect(find.byType(DesktopMediaTile));
      final caption = t.getRect(find.textContaining('Смотри, закат'));
      expect(caption.top, greaterThan(media.bottom));
      final peerBg = kDColorsDark.bubblePeer;
      expect(
        t.widgetList<Container>(find.byType(Container)).where(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == peerBg,
        ),
        isNotEmpty,
      );
    });

    testWidgets('в группе у чужого снимка — имя автора над кадром', (t) async {
      await t.pumpWidget(
        _host(MessageBubble(message: _media('a', group: ''))),
      );
      await t.pump();
      expect(find.text('Пётр'), findsWidgets);
      final name = t.getRect(find.text('Пётр').first);
      final media = t.getRect(find.byType(DesktopMediaTile));
      expect(name.bottom, lessThanOrEqualTo(media.top));
    });

    testWidgets('🔴 альбом — сетка, нажатие открывает свой снимок', (t) async {
      final opened = <String>[];
      final row = groupMediaAlbums([
        _media('a', path: '/nonexistent/a.jpg'),
        _media('b', path: '/nonexistent/b.jpg'),
        _media('c', path: '/nonexistent/c.jpg'),
      ]).single;
      await t.pumpWidget(
        _host(
          MessageBubble(
            message: row,
            showPeerIdentity: false,
            onOpenImage: (m) => opened.add(m.id),
          ),
        ),
      );
      await t.pump();
      expect(find.byType(DesktopMediaGrid), findsOneWidget);
      final tiles = find.byType(DesktopMediaTile);
      expect(tiles, findsNWidgets(3));
      await t.tap(tiles.at(2), kind: PointerDeviceKind.mouse);
      await t.pump();
      expect(opened, ['c']);
      // Время — одно на весь альбом.
      expect(find.text('12:00'), findsOneWidget);
    });

    testWidgets('🔴 файл: «Загрузить», а скачанный — «Показать в Finder»', (
      t,
    ) async {
      final downloads = <String>[];
      final reveals = <String>[];
      Widget bubble(MessageData m) => _host(
        MessageBubble(
          message: m,
          showPeerIdentity: false,
          onDownloadAttachment: (x) => downloads.add(x.id),
          onRevealAttachment: (x) => reveals.add(x.id),
        ),
      );
      await t.pumpWidget(bubble(_media('f', group: '', asFile: true,
          kind: MessageAttachmentKind.file)));
      await t.pump();
      expect(find.byType(DesktopFileRow), findsOneWidget);
      expect(find.text('report-f'), findsOneWidget);
      expect(find.text('.pdf'), findsOneWidget);
      await t.tap(find.text('Загрузить'));
      await t.pump();
      expect(downloads, ['f']);

      await t.pumpWidget(
        bubble(
          _media(
            'f',
            group: '',
            asFile: true,
            kind: MessageAttachmentKind.file,
            path: '/nonexistent/x.pdf',
          ),
        ),
      );
      await t.pump();
      expect(find.text('Загрузить'), findsNothing);
      await t.tap(find.text('Показать в Finder'));
      await t.pump();
      expect(reveals, ['f']);
    });

    testWidgets('файлы, отправленные вместе, — стопкой в одном пузыре', (
      t,
    ) async {
      final row = groupMediaAlbums([
        _media('a', asFile: true, kind: MessageAttachmentKind.file),
        _media('b', asFile: true, kind: MessageAttachmentKind.file),
      ]).single;
      await t.pumpWidget(
        _host(MessageBubble(message: row, showPeerIdentity: false)),
      );
      await t.pump();
      final rows = find.byType(DesktopFileRow);
      expect(rows, findsNWidgets(2));
      expect(t.getRect(rows.at(1)).top, greaterThan(t.getRect(rows.at(0)).top));
      expect(find.text('12:00'), findsOneWidget);
    });
  });

  group('действия над альбомом', () {
    Future<List<List<String>>> pumpPanel(
      WidgetTester t,
      List<MessageData> messages,
    ) async {
      t.view.physicalSize = const Size(1400, 1000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final forwarded = <List<String>>[];
      await t.pumpWidget(
        MaterialApp(
          home: DColors(
            colors: kDColorsDark,
            child: Scaffold(
              body: ChatThreadPanel(
                header: const ChatHeader(name: 'Пётр'),
                isDirect: true,
                messages: messages,
                onForwardMessage: (m) => forwarded.add([m.id]),
                onForwardMessages: (l) =>
                    forwarded.add([for (final m in l) m.id]),
                onDeleteMessage: (_) {},
                onDeleteMessages: (_) {},
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 400));
      return forwarded;
    }

    testWidgets('🔴 «Переслать» у альбома пересылает все его снимки', (
      t,
    ) async {
      final rows = groupMediaAlbums([
        _media('a', path: '/nonexistent/a.jpg'),
        _media('b', path: '/nonexistent/b.jpg'),
      ]);
      final forwarded = await pumpPanel(t, rows);
      await t.tapAt(
        t.getCenter(find.byType(DesktopMediaTile).first),
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Переслать'));
      await t.pumpAndSettle();
      expect(forwarded, [
        ['a', 'b'],
      ]);
    });

    testWidgets('выделенный альбом отдаётся действиям всеми снимками', (
      t,
    ) async {
      final rows = groupMediaAlbums([
        _media('a', path: '/nonexistent/a.jpg'),
        _media('b', path: '/nonexistent/b.jpg'),
      ]);
      final forwarded = await pumpPanel(t, rows);
      await t.tapAt(
        t.getCenter(find.byType(DesktopMediaTile).first),
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Выделить'));
      await t.pumpAndSettle();
      expect(find.text('Выбрано: 1'), findsOneWidget);
      await t.tap(find.byTooltip('Переслать'));
      await t.pumpAndSettle();
      expect(forwarded, [
        ['a', 'b'],
      ]);
    });
  });

  group('🔴 время и галочки — всегда в правом нижнем углу', () {
    // Указание владельца 16.09.2026: «сделай, чтобы галочки-индикаторы
    // отправки находились всегда внизу справа пузырей / медиа». Было: у
    // короткой подписи под файлами время вставало сразу за словами.

    /// Видимая подпись времени — вторая: первая спрятана в тексте и только
    /// занимает место.
    Finder visibleTime() => find.text('12:00').last;

    Rect bubbleOf(WidgetTester t) => t.getRect(
      find
          .ancestor(
            of: visibleTime(),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration is BoxDecoration,
            ),
          )
          .first,
    );

    Rect metaOf(WidgetTester t) => t.getRect(
      find.ancestor(of: visibleTime(), matching: find.byType(Row)).first,
    );

    Future<void> pump(WidgetTester t, MessageData m) async {
      await t.pumpWidget(
        _host(MessageBubble(message: m, showPeerIdentity: false)),
      );
      await t.pump();
    }

    testWidgets('короткая подпись под файлами', (t) async {
      await pump(
        t,
        _media(
          'f',
          group: '',
          asFile: true,
          kind: MessageAttachmentKind.file,
          caption: 'ок',
          self: true,
        ),
      );
      final bubble = bubbleOf(t);
      final meta = metaOf(t);
      expect(bubble.right - meta.right, closeTo(13, 1));
      expect(meta.left - bubble.left, greaterThan(150));
      expect(bubble.bottom - meta.bottom, lessThan(12));
    });

    testWidgets('короткая подпись под снимком', (t) async {
      await pump(t, _media('a', group: '', caption: 'ок', self: true));
      final bubble = bubbleOf(t);
      final meta = metaOf(t);
      expect(bubble.width, 430);
      expect(bubble.right - meta.right, closeTo(13, 1));
      expect(bubble.bottom - meta.bottom, lessThan(12));
    });

    testWidgets('короткий ответ под длинной цитатой', (t) async {
      await pump(
        t,
        const MessageData(
          id: 'r',
          payloadId: 'p-r',
          authorName: 'Вы',
          text: 'ок',
          time: '12:00',
          isSelf: true,
          timestampMs: 1757700000000,
          reply: ReplyPreview(
            authorName: 'Пётр',
            text: 'Очень длинная цитата, которая шире короткого ответа',
          ),
        ),
      );
      final bubble = bubbleOf(t);
      final meta = metaOf(t);
      expect(bubble.width, greaterThan(200));
      expect(bubble.right - meta.right, closeTo(13, 1));
    });

    testWidgets('короткий пузырь от этого не растягивается', (t) async {
      await pump(
        t,
        const MessageData(
          id: 's',
          payloadId: 'p-s',
          authorName: 'Вы',
          text: 'ок',
          time: '12:00',
          isSelf: true,
          timestampMs: 1757700000000,
        ),
      );
      final bubble = bubbleOf(t);
      expect(bubble.width, lessThan(160));
      expect(bubble.right - metaOf(t).right, closeTo(13, 1));
    });

    testWidgets('звонок: галочки у правого края', (t) async {
      await t.pumpWidget(
        _host(
          MessageBubble(
            showPeerIdentity: false,
            message: MessageData(
              id: 'c',
              payloadId: 'p-c',
              authorName: 'Вы',
              text: '',
              time: '12:00',
              isSelf: true,
              timestampMs: 1757700000000,
              callEvent: CallEventV1(
                eventId: 'c',
                callId: 'call',
                callAttemptId: 'a',
                convoId: 'peer',
                direction: CallRecordDirection.outgoing,
                scope: CallRecordScope.oneToOne,
                mediaType: CallRecordMediaType.audio,
                result: CallRecordResult.completed,
                startedAtMs: 1757700000000,
                connectedAtMs: 1757700001000,
                endedAtMs: 1757700033000,
                durationMs: 32000,
                endReason: null,
                participantCount: 2,
                hadVideo: false,
                hadScreenShare: false,
                qualitySummary: null,
              ),
            ),
          ),
        ),
      );
      await t.pump();
      final tick = find.byIcon(FluentIcons.checkmark_24_regular);
      expect(tick, findsOneWidget);
      final card = t.getRect(
        find
            .ancestor(
              of: tick,
              matching: find.byWidgetPredicate(
                (w) => w is Container && w.decoration is BoxDecoration,
              ),
            )
            .first,
      );
      final iconRect = t.getRect(tick);
      // Справа от галочки — только поле пузыря.
      expect(card.right - iconRect.right, lessThan(24));
    });
  });

  group('копия в «Загрузки»', () {
    test('🔴 чужое имя не выводит запись из папки', () {
      expect(safeDownloadFileName('../../.ssh/authorized_keys'), 'authorized_keys');
      expect(safeDownloadFileName(r'..\..\evil.exe'), 'evil.exe');
      expect(safeDownloadFileName('.hidden'), 'hidden');
      expect(safeDownloadFileName('a:b?.txt'), 'a_b_.txt');
      expect(safeDownloadFileName(''), 'file');
      final long = safeDownloadFileName('${'я' * 300}.pdf');
      expect(long.length, 120);
      expect(long.endsWith('.pdf'), isTrue);
    });

    test('копия ложится в «Secretly», повтор того же файла не плодит копий', () async {
      final tmp = await Directory.systemTemp.createTemp('secretly-dl');
      addTearDown(() => tmp.delete(recursive: true));
      final src = File('${tmp.path}/blob.bin')
        ..writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
      final downloads = Directory('${tmp.path}/Downloads')..createSync();
      final a = await exportAttachmentToDownloads(
        src,
        'отчёт.pdf',
        downloadsOverride: downloads,
      );
      expect(a.path, '${downloads.path}/Secretly/отчёт.pdf');
      final again = await exportAttachmentToDownloads(
        src,
        'отчёт.pdf',
        downloadsOverride: downloads,
      );
      expect(again.path, a.path);
      // Другой файл с тем же именем — «(1)».
      final other = File('${tmp.path}/other.bin')
        ..writeAsBytesSync(Uint8List.fromList([9, 9, 9, 9]));
      final b = await exportAttachmentToDownloads(
        other,
        'отчёт.pdf',
        downloadsOverride: downloads,
      );
      expect(b.path, '${downloads.path}/Secretly/отчёт (1).pdf');
    });
  });

  group('лента берёт данные из вложения', () {
    final section = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();

    test('🔴 подпись и номер группы — из самого вложения', () {
      expect(section.contains("text: (payload.caption ?? '').trim(),"), isTrue);
      expect(section.contains('mediaGroupId: payload.mediaGroupId,'), isTrue);
      // Лента — склеенные строки и уходящие пачки снизу.
      expect(section.contains('messages: _threadRowsWithUploads(),'), isTrue);
      expect(
        section.contains('_rows = groupMediaAlbums(_applyTopicFilter(_messages));'),
        isTrue,
      );
    });

    test('🔴 старые сообщения при подгрузке — в начало ленты', () {
      // Сторожим ПОРЯДОК, а не всю строку целиком: список может проходить
      // через досчёт (опросы), и это не должно ломать проверку.
      expect(
        section.contains('<MessageData>[...prepended, ..._messages]'),
        isTrue,
      );
    });
  });
}
